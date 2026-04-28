{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

{- | AST-based extraction of top-level definitions and free identifier uses
from a notebook cell's Haskell source.

This replaces the textual heuristic that lived in @Sabela.Topo@. We parse
each cell with @ghc-lib-parser@ (independent of the host GHC version) and
walk the resulting 'GHC.Hs.HsModule' to compute:

* @defs@ — top-level names introduced by the cell. Pulled from the LHS of
  every top-level declaration: function/value bindings, data/newtype/type
  /class names plus their data-constructors and class methods.

* @uses@ — every identifier referenced by the cell that is not bound
  somewhere within the cell itself. Computed as
  @(all 'HsVar' references) \\ (every binding-position name)@. This is a
  scope-conservative approximation: if the same name is bound locally
  (in a @where@, @let@, lambda, do-bind, list-comp generator, etc.) and
  /also/ used at top level, we treat it as bound and produce no
  dependency edge. Trade is intentional — it eliminates the cross-cell
  parameter-collision bug that the previous heuristic produced and that
  motivated this rewrite.

Cell sources are GHCi-style fragments, not modules. The pre-processor
strips @:set@ / @:type@ directives, drops @-- cabal:@ metadata lines, and
rewrites statement-form @let x = e@ and monadic @x \<- e@ into bare
declarations so the GHC parser will accept the result. The whole thing
is then wrapped in a synthetic @module M where { ... }@ and parsed with
'parseModule'. If that fails (incomplete code mid-edit), each chunk is
retried with 'parseDeclaration' and 'parseExpression' independently and
the parseable subset still contributes to @defs@/@uses@.
-}
module Sabela.Parse (
    cellNames,
) where

import qualified Data.Char as Char
import Data.Data (Data)
import Data.Foldable (toList)
import qualified Data.List.NonEmpty as NE
import Data.Maybe (fromMaybe)
import Data.Set (Set)
import qualified Data.Set as S
import Data.Text (Text)
import qualified Data.Text as T

import Data.Generics.Uniplate.Data (universeBi)

import GHC.Driver.Session (
    DynFlags,
    defaultDynFlags,
    xopt_set,
 )
import qualified GHC.Hs as Hs
import qualified GHC.LanguageExtensions.Type as LE
import GHC.Parser.Lexer (ParseResult (..))
import GHC.Types.Name.Occurrence (occNameString)
import GHC.Types.Name.Reader (RdrName, rdrNameOcc)
import GHC.Types.SrcLoc (GenLocated (..), unLoc)

import qualified Language.Haskell.GhclibParserEx.GHC.Parser as P
import Language.Haskell.GhclibParserEx.GHC.Settings.Config (fakeSettings)

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

{- | Extract @(defs, uses)@ from a cell's Haskell source. See module
header for semantics.
-}
cellNames :: Text -> (Set Text, Set Text)
cellNames src =
    let preprocessed = preprocess src
        moduleSrc =
            "module SabelaCell where\n"
                ++ T.unpack (T.unlines preprocessed)
     in case P.parseModule moduleSrc dynFlags of
            POk _ (L _ hsMod) -> extractFromModule hsMod
            PFailed _ -> fallbackPerChunk preprocessed

-- ---------------------------------------------------------------------------
-- Pre-processing: turn REPL fragments into a parseable module body
-- ---------------------------------------------------------------------------

{- | Drop GHCi directives and cabal-metadata lines. Rewrite statement-form
@let@ and monadic @\<-@ into top-level bindings so they parse as decls.
Returns the rewritten lines, ready to be glued together as the body of a
synthetic module.
-}
preprocess :: Text -> [Text]
preprocess src = concatMap rewriteLine (T.lines src)
  where
    rewriteLine raw
        | shouldDrop trimmed = []
        | Just rest <- T.stripPrefix "let " trimmed
        , noTopLevelIn rest =
            [reindent raw rest]
        | Just (binder, rhs) <- splitTopLevelArrow trimmed =
            [reindent raw (binder <> " = " <> rhs)]
        | otherwise = [raw]
      where
        trimmed = T.stripStart raw

    shouldDrop t =
        T.null t
            || ":" `T.isPrefixOf` t
            || "-- cabal:" `T.isPrefixOf` t
            || "--cabal:" `T.isPrefixOf` t

-- | Preserve original leading whitespace when rewriting a line's content.
reindent :: Text -> Text -> Text
reindent original newContent =
    let leading = T.takeWhile (\c -> c == ' ' || c == '\t') original
     in leading <> newContent

{- | A statement-form @let@ has no top-level @in@. We treat any line that
contains @ in @ at depth 0 as the regular expression-form @let ... in
...@ and leave it alone (let the parser handle it inside an expression
context if it ever ends up there).
-}
noTopLevelIn :: Text -> Bool
noTopLevelIn = go (0 :: Int) (0 :: Int) . T.unpack
  where
    -- Track paren depth and bracket depth. Stop at first top-level " in ".
    go _ _ [] = True
    go p b (' ' : 'i' : 'n' : ' ' : _) | p == 0 && b == 0 = False
    go p b ('(' : rest) = go (p + 1) b rest
    go p b (')' : rest) = go (max 0 (p - 1)) b rest
    go p b ('[' : rest) = go p (b + 1) rest
    go p b (']' : rest) = go p (max 0 (b - 1)) rest
    go p b (_ : rest) = go p b rest

{- | If the line is @ident <- rhs@ at top level, return @Just (ident, rhs)@.
We ignore @\<-@ that appears inside parens/brackets (list-comp generator,
do-block continuation, etc.).
-}
splitTopLevelArrow :: Text -> Maybe (Text, Text)
splitTopLevelArrow t =
    case findTopLevelArrow 0 0 (T.unpack t) of
        Nothing -> Nothing
        Just idx ->
            let (lhs, rhs0) = T.splitAt idx t
                rhs = T.drop 2 rhs0 -- drop "<-"
                lhsTrim = T.strip lhs
             in if isSimpleIdent lhsTrim
                    then Just (lhsTrim, T.stripStart rhs)
                    else Nothing
  where
    findTopLevelArrow :: Int -> Int -> String -> Maybe Int
    findTopLevelArrow _ _ [] = Nothing
    findTopLevelArrow p b ('<' : '-' : _) | p == 0 && b == 0 = Just 0
    findTopLevelArrow p b ('(' : rest) =
        succPos <$> findTopLevelArrow (p + 1) b rest
    findTopLevelArrow p b (')' : rest) =
        succPos <$> findTopLevelArrow (max 0 (p - 1)) b rest
    findTopLevelArrow p b ('[' : rest) =
        succPos <$> findTopLevelArrow p (b + 1) rest
    findTopLevelArrow p b (']' : rest) =
        succPos <$> findTopLevelArrow p (max 0 (b - 1)) rest
    findTopLevelArrow p b (_ : rest) = succPos <$> findTopLevelArrow p b rest

    succPos :: Int -> Int
    succPos = (+ 1)

isSimpleIdent :: Text -> Bool
isSimpleIdent t = case T.uncons t of
    Just (c, rest) ->
        (Char.isLower c || c == '_')
            && T.all isIdentChar rest
    Nothing -> False
  where
    isIdentChar c = Char.isAlphaNum c || c == '_' || c == '\''

-- ---------------------------------------------------------------------------
-- Fallback: parse each chunk independently when full-module parse fails
-- ---------------------------------------------------------------------------

{- | If the synthesized module fails to parse, try each non-empty chunk
through 'parseDeclaration' and 'parseExpression' and union the results.
On chunk-level parse failure, retry with just the first line — handles
cases like @"let x = 1\\n  let y = 2"@ where a malformed indented
continuation would otherwise drop the whole chunk's contribution.
-}
fallbackPerChunk :: [Text] -> (Set Text, Set Text)
fallbackPerChunk lns =
    let chunks = splitChunks lns
        contributions = map analyseChunkRobust chunks
        (defs, uses) = foldr combine (S.empty, S.empty) contributions
        finalUses = uses `S.difference` defs
     in (defs, finalUses)
  where
    combine (d, u) (ds, us) = (S.union d ds, S.union u us)

analyseChunkRobust :: Text -> (Set Text, Set Text)
analyseChunkRobust chunk =
    case tryParseChunk chunk of
        Just contrib -> contrib
        Nothing -> case T.lines chunk of
            (firstLine : _ : _) ->
                fromMaybe (S.empty, S.empty) (tryParseChunk firstLine)
            _ -> (S.empty, S.empty)

tryParseChunk :: Text -> Maybe (Set Text, Set Text)
tryParseChunk chunk =
    case P.parseDeclaration (T.unpack chunk) dynFlags of
        POk _ ldecl ->
            let d = unLoc ldecl
             in Just (topLevelDefsFromDecl d, declFreeVars d)
        PFailed _ -> case P.parseExpression (T.unpack chunk) dynFlags of
            POk _ lexpr ->
                let allRefs = collectUses lexpr
                    localBinders = collectBinders lexpr
                 in Just (S.empty, allRefs `S.difference` localBinders)
            PFailed _ -> Nothing

splitChunks :: [Text] -> [Text]
splitChunks = go []
  where
    go acc [] = [unsplit (reverse acc) | not (null acc)]
    go acc (l : ls)
        | T.null (T.strip l) = case acc of
            [] -> go [] ls
            _ -> unsplit (reverse acc) : go [] ls
        | startsAtCol0 l = case acc of
            [] -> go [l] ls
            _ -> unsplit (reverse acc) : go [l] ls
        | otherwise = go (l : acc) ls
    unsplit = T.intercalate "\n"
    startsAtCol0 t = case T.uncons t of
        Just (c, _) -> c /= ' ' && c /= '\t'
        Nothing -> False

-- ---------------------------------------------------------------------------
-- Module-level extraction
-- ---------------------------------------------------------------------------

{- | Top-level extraction. Defs come from each top-level decl's LHS. Uses
are computed **per decl** (not globally over the module), so a parameter
@x@ that's local to one decl doesn't shadow a free @x@ in a sibling
decl's body. References to names this cell defines itself are subtracted
from uses since they're intra-cell, not external dependencies.
-}
extractFromModule :: Hs.HsModule Hs.GhcPs -> (Set Text, Set Text)
extractFromModule m =
    let topDecls = map unLoc (Hs.hsmodDecls m)
        defs = S.unions (map topLevelDefsFromDecl topDecls)
        rawUses = S.unions (map declFreeVars topDecls)
        uses = rawUses `S.difference` defs
     in (defs, uses)

{- | Free variables of a single top-level declaration: every 'HsVar'
reference inside the decl, minus every name bound anywhere within that
same decl (function params, where/let binders, lambda binders, do-binds,
list-comp generators, case patterns).

Per-decl scoping is intentional: it's a coarse approximation of
proper lexical scope but it's *strictly* better than the prior textual
heuristic for the common case where one decl's parameter happens to
collide with a free use in a sibling decl's body.
-}
declFreeVars :: Hs.HsDecl Hs.GhcPs -> Set Text
declFreeVars decl =
    let allRefs = collectUses decl
        localBinders = collectBinders decl
     in allRefs `S.difference` localBinders

-- ---------------------------------------------------------------------------
-- Top-level def extraction
-- ---------------------------------------------------------------------------

topLevelDefsFromDecl :: Hs.HsDecl Hs.GhcPs -> Set Text
topLevelDefsFromDecl = \case
    Hs.ValD _ bind -> bindBinders bind
    Hs.TyClD _ tcd -> tyClBinders tcd
    Hs.SigD{} -> S.empty
    Hs.InstD{} -> S.empty
    Hs.DerivD{} -> S.empty
    Hs.DefD{} -> S.empty
    Hs.ForD{} -> S.empty
    Hs.WarningD{} -> S.empty
    Hs.AnnD{} -> S.empty
    Hs.RuleD{} -> S.empty
    Hs.SpliceD{} -> S.empty
    Hs.DocD{} -> S.empty
    Hs.RoleAnnotD{} -> S.empty
    _ -> S.empty

-- | Names introduced by an 'HsBindLR' (the LHS of a value/function binding).
bindBinders :: Hs.HsBindLR Hs.GhcPs Hs.GhcPs -> Set Text
bindBinders = \case
    Hs.FunBind{Hs.fun_id = lname} -> S.singleton (rdrText (unLoc lname))
    Hs.PatBind{Hs.pat_lhs = lpat} -> patBinders (unLoc lpat)
    _ -> S.empty

{- | Names introduced by a 'TyClDecl': the type/class name itself, every
data constructor it declares, and every method signature in a class body.
-}
tyClBinders :: Hs.TyClDecl Hs.GhcPs -> Set Text
tyClBinders = \case
    Hs.DataDecl{Hs.tcdLName = ln, Hs.tcdDataDefn = ddef} ->
        S.insert (rdrText (unLoc ln)) (dataDefnConstructors ddef)
    Hs.SynDecl{Hs.tcdLName = ln} ->
        S.singleton (rdrText (unLoc ln))
    Hs.ClassDecl{Hs.tcdLName = ln, Hs.tcdSigs = sigs} ->
        S.insert (rdrText (unLoc ln)) (S.unions (map (sigBinders . unLoc) sigs))
    Hs.FamDecl _ fd -> S.singleton (rdrText (unLoc (Hs.fdLName fd)))

dataDefnConstructors :: Hs.HsDataDefn Hs.GhcPs -> Set Text
dataDefnConstructors ddef =
    S.unions [conDeclNames (unLoc lc) | lc <- toList (Hs.dd_cons ddef)]

conDeclNames :: Hs.ConDecl Hs.GhcPs -> Set Text
conDeclNames = \case
    Hs.ConDeclH98{Hs.con_name = ln} -> S.singleton (rdrText (unLoc ln))
    Hs.ConDeclGADT{Hs.con_names = lns} ->
        S.fromList [rdrText (unLoc ln) | ln <- NE.toList lns]

sigBinders :: Hs.Sig Hs.GhcPs -> Set Text
sigBinders = \case
    Hs.TypeSig _ lns _ ->
        S.fromList [rdrText (unLoc ln) | ln <- lns]
    Hs.ClassOpSig _ _ lns _ ->
        S.fromList [rdrText (unLoc ln) | ln <- lns]
    _ -> S.empty

-- ---------------------------------------------------------------------------
-- Pattern binders (recursive)
-- ---------------------------------------------------------------------------

{- | Binders introduced by a single pattern node, ignoring sub-patterns
(uniplate handles the recursion downstream). Splitting the recursion lets
us stay tolerant of GHC AST shape changes across @ghc-lib-parser@ minor
bumps — sub-patterns are reached generically rather than by hand-coded
constructor matching.
-}
patNodeBinders :: Hs.Pat Hs.GhcPs -> Set Text
patNodeBinders = \case
    Hs.VarPat _ ln -> S.singleton (rdrText (unLoc ln))
    Hs.AsPat _ ln _ -> S.singleton (rdrText (unLoc ln))
    Hs.NPlusKPat _ ln _ _ _ _ -> S.singleton (rdrText (unLoc ln))
    _ -> S.empty

-- | Recursive pattern-binder extraction (every level of nesting).
patBinders :: Hs.Pat Hs.GhcPs -> Set Text
patBinders top =
    S.unions
        [patNodeBinders p | p <- universeBi top :: [Hs.Pat Hs.GhcPs]]

-- ---------------------------------------------------------------------------
-- Generic traversals over the AST (uniplate / Data-driven)
-- ---------------------------------------------------------------------------

{- | Every identifier reference (every 'HsVar' occurrence) anywhere in the
sub-tree.
-}
collectUses :: forall a. (Data a) => a -> Set Text
collectUses x =
    S.fromList
        [rdrText (unLoc ln) | Hs.HsVar _ ln <- universeBi x :: [Hs.HsExpr Hs.GhcPs]]

{- | Every name appearing in a binding position in the sub-tree: pattern
binders, function-binding names, type/class/method names, data constructors,
do-block @\<-@ binders, list-comprehension generators (which are pattern
binders inside 'BindStmt'), let binders. We collect them by visiting every
'HsBindLR' / 'Pat' / 'TyClDecl' the AST contains.
-}
collectBinders :: forall a. (Data a) => a -> Set Text
collectBinders x = S.unions [bindersFromBind, bindersFromPat, bindersFromTyCl]
  where
    bindersFromBind =
        S.unions
            [ bindBinders b
            | b <- universeBi x :: [Hs.HsBindLR Hs.GhcPs Hs.GhcPs]
            ]
    bindersFromPat =
        S.unions
            [ patNodeBinders p
            | p <- universeBi x :: [Hs.Pat Hs.GhcPs]
            ]
    bindersFromTyCl =
        S.unions
            [ tyClBinders t
            | t <- universeBi x :: [Hs.TyClDecl Hs.GhcPs]
            ]

-- ---------------------------------------------------------------------------
-- Names
-- ---------------------------------------------------------------------------

-- | Convert an 'RdrName' to its bare @OccName@ as 'Text'.
rdrText :: RdrName -> Text
rdrText = T.pack . occNameString . rdrNameOcc

-- ---------------------------------------------------------------------------
-- DynFlags
-- ---------------------------------------------------------------------------

{- | Parser settings: enable extensions that real Sabela notebooks rely on
so the parser never refuses input the running GHCi would happily accept.
-}
dynFlags :: DynFlags
dynFlags =
    let base = defaultDynFlags fakeSettings
     in foldl xopt_set base extensions

extensions :: [LE.Extension]
extensions =
    [ LE.TypeApplications
    , LE.OverloadedStrings
    , LE.TemplateHaskell
    , LE.TemplateHaskellQuotes
    , LE.DataKinds
    , LE.PolyKinds
    , LE.RankNTypes
    , LE.GADTs
    , LE.GADTSyntax
    , LE.FlexibleContexts
    , LE.FlexibleInstances
    , LE.MultiParamTypeClasses
    , LE.FunctionalDependencies
    , LE.ScopedTypeVariables
    , LE.ConstraintKinds
    , LE.KindSignatures
    , LE.StandaloneDeriving
    , LE.DeriveGeneric
    , LE.DeriveFunctor
    , LE.DeriveFoldable
    , LE.DeriveTraversable
    , LE.GeneralizedNewtypeDeriving
    , LE.LambdaCase
    , LE.MultiWayIf
    , LE.RecordWildCards
    , LE.NamedFieldPuns
    , LE.TupleSections
    , LE.ViewPatterns
    , LE.BangPatterns
    , LE.ExplicitForAll
    , LE.PatternSynonyms
    , LE.ImportQualifiedPost
    , LE.NumericUnderscores
    , LE.BlockArguments
    , LE.OverloadedRecordDot
    , LE.OverloadedRecordUpdate
    , LE.QualifiedDo
    , LE.LinearTypes
    ]
