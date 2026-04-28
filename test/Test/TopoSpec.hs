{-# LANGUAGE OverloadedStrings #-}

module Test.TopoSpec (spec) where

import Data.List (elemIndex)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import Data.Text (Text)
import Sabela.Model (Cell (..), CellType (..))
import Sabela.SessionTypes (CellLang (..))
import Sabela.Topo
import Test.Hspec

-- | Helper to construct a code cell for testing.
mkCell :: Int -> Text -> Cell
mkCell cid src =
    Cell
        { cellId = cid
        , cellType = CodeCell
        , cellLang = Haskell
        , cellSource = src
        , cellOutputs = []
        , cellError = Nothing
        , cellDirty = False
        }

spec :: Spec
spec = describe "Sabela.Topo" $ do
    describe "computeTopoOrder" $ do
        it "preserves notebook order for a linear chain already in dependency order" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let y = x + 1"
                    , mkCell 3 "let z = y + 1"
                    ]
                (result, redefMap) = computeTopoOrder cells
            map cellId (trOrdered result) `shouldBe` [1, 2, 3]
            redefMap `shouldBe` M.empty
            trCycleIds result `shouldBe` S.empty

        it "puts definer before user for a reverse-order chain" $ do
            -- Notebook order: z uses y (cell 1), y uses x (cell 2), x defined (cell 3)
            let cells =
                    [ mkCell 1 "let z = y + 1"
                    , mkCell 2 "let y = x + 1"
                    , mkCell 3 "let x = 1"
                    ]
                (result, redefMap) = computeTopoOrder cells
            -- x (cell 3) must be first, then y (cell 2), then z (cell 1)
            map cellId (trOrdered result) `shouldBe` [3, 2, 1]
            redefMap `shouldBe` M.empty
            trCycleIds result `shouldBe` S.empty

        it "handles a diamond dependency correctly" $ do
            let cells =
                    [ mkCell 1 "let a = 1"
                    , mkCell 2 "let b = a + 1"
                    , mkCell 3 "let c = a + 2"
                    , mkCell 4 "let d = b + c"
                    ]
                (result, _) = computeTopoOrder cells
                ordered = map cellId (trOrdered result)
            -- a (cell 1) must come first, d (cell 4) must come last
            case ordered of
                (first : rest) -> do
                    first `shouldBe` 1
                    last rest `shouldBe` 4
                [] -> expectationFailure "trOrdered should not be empty"
            trCycleIds result `shouldBe` S.empty

        it "flags the LATER cell when two cells redefine the same name (first-wins)" $ do
            let cells = [mkCell 1 "let x = 1", mkCell 2 "let x = 2"]
                (_, redefMap) = computeTopoOrder cells
            -- Cell 1 owns x. Cell 2 is flagged as a redefinition of x;
            -- it will be skipped at execution time and a redef error
            -- will surface on it.
            redefMap `shouldBe` M.fromList [(2, ["x"])]

        it "detects a simple two-cell cycle" $ do
            let cells =
                    [ mkCell 1 "let a = b + 1"
                    , mkCell 2 "let b = a + 1"
                    ]
                (result, _) = computeTopoOrder cells
            trCycleIds result `shouldBe` S.fromList [1, 2]
            trOrdered result `shouldBe` []

        it "runs non-cycle cells when a cycle exists among other cells" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let a = b + 1"
                    , mkCell 3 "let b = a + 1"
                    ]
                (result, _) = computeTopoOrder cells
            -- cell 1 has no cycle, should run
            map cellId (trOrdered result) `shouldBe` [1]
            -- cells 2 and 3 form a cycle
            trCycleIds result `shouldBe` S.fromList [2, 3]

    describe "selectAffectedTopo" $ do
        it "propagates edit to downstream cells but not unrelated ones" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let y = x + 1"
                    , mkCell 3 "let z = 42"
                    ]
                (result, _) = selectAffectedTopo 1 cells
                orderedIds = map cellId (trOrdered result)
            -- editing cell 1 (x) should affect cell 2 (y = x + 1)
            orderedIds `shouldContain` [1]
            orderedIds `shouldContain` [2]
            -- cell 3 is unrelated
            orderedIds `shouldNotContain` [3]

        it "finds affected cells even when the dep appears later in notebook order" $ do
            -- cell 1 uses y (defined by cell 2), but cell 1 appears first in notebook
            let cells =
                    [ mkCell 1 "let z = y + 1"
                    , mkCell 2 "let y = 1"
                    ]
                -- edit cell 2 (y), which cell 1 depends on
                (result, _) = selectAffectedTopo 2 cells
                orderedIds = map cellId (trOrdered result)
            -- both cells should be in the affected set
            orderedIds `shouldContain` [1]
            orderedIds `shouldContain` [2]
            -- topo order: cell 2 (y) must come before cell 1 (z = y + 1)
            case (elemIndex 2 orderedIds, elemIndex 1 orderedIds) of
                (Just idx2, Just idx1) -> idx2 `shouldSatisfy` (< idx1)
                _ -> expectationFailure "both cells should be in trOrdered"

        it "only re-executes the edited leaf cell with no downstream" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let y = x + 1"
                    , mkCell 3 "let z = y + 1"
                    ]
                (result, _) = selectAffectedTopo 3 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldBe` [3]

        it "re-executes from mid-chain through all downstream" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let y = x + 1"
                    , mkCell 3 "let z = y + 1"
                    ]
                (result, _) = selectAffectedTopo 2 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldContain` [2]
            orderedIds `shouldContain` [3]
            orderedIds `shouldNotContain` [1]

        it "only affects the relevant subtree, not independent cells" $ do
            let cells =
                    [ mkCell 1 "let a = 1"
                    , mkCell 2 "let b = 2"
                    , mkCell 3 "let c = a + 1"
                    , mkCell 4 "let d = b + 1"
                    ]
                (result, _) = selectAffectedTopo 1 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldContain` [1]
            orderedIds `shouldContain` [3]
            orderedIds `shouldNotContain` [2]
            orderedIds `shouldNotContain` [4]

        it "re-executes all cells in a diamond when editing the root" $ do
            let cells =
                    [ mkCell 1 "let a = 1"
                    , mkCell 2 "let b = a + 1"
                    , mkCell 3 "let c = a + 2"
                    , mkCell 4 "let d = b + c"
                    ]
                (result, _) = selectAffectedTopo 1 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldContain` [1]
            orderedIds `shouldContain` [2]
            orderedIds `shouldContain` [3]
            orderedIds `shouldContain` [4]

        it "re-executes only one branch and join in a diamond" $ do
            let cells =
                    [ mkCell 1 "let a = 1"
                    , mkCell 2 "let b = a + 1"
                    , mkCell 3 "let c = a + 2"
                    , mkCell 4 "let d = b + c"
                    ]
                (result, _) = selectAffectedTopo 2 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldContain` [2]
            orderedIds `shouldContain` [4]
            orderedIds `shouldNotContain` [1]
            orderedIds `shouldNotContain` [3]

        it "propagates through a long transitive chain from root" $ do
            let cells =
                    [ mkCell 1 "let a = 1"
                    , mkCell 2 "let b = a + 1"
                    , mkCell 3 "let c = b + 1"
                    , mkCell 4 "let d = c + 1"
                    , mkCell 5 "let e = d + 1"
                    ]
                (result, _) = selectAffectedTopo 1 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldBe` [1, 2, 3, 4, 5]

        it "propagates from mid-chain only to downstream cells" $ do
            let cells =
                    [ mkCell 1 "let a = 1"
                    , mkCell 2 "let b = a + 1"
                    , mkCell 3 "let c = b + 1"
                    , mkCell 4 "let d = c + 1"
                    , mkCell 5 "let e = d + 1"
                    ]
                (result, _) = selectAffectedTopo 3 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldBe` [3, 4, 5]

        it "only re-executes the edited cell when it has no deps or dependents" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let y = 2"
                    , mkCell 3 "let z = 3"
                    ]
                (result, _) = selectAffectedTopo 2 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldBe` [2]

        it "re-executes the edited root and the cell using multiple roots" $ do
            let cells =
                    [ mkCell 1 "let a = 1"
                    , mkCell 2 "let b = 2"
                    , mkCell 3 "let c = a + b"
                    ]
                (result, _) = selectAffectedTopo 1 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldContain` [1]
            orderedIds `shouldContain` [3]
            orderedIds `shouldNotContain` [2]

    describe "cellNames — variable scoping" $ do
        it "does not treat indented lines as definitions" $ do
            let (defs, _) = cellNames "let x = 1\n  let y = 2"
            defs `shouldBe` S.fromList ["x"]

        it "extracts multiple definitions from a multi-line cell" $ do
            let (defs, _) = cellNames "let a = 1\nlet b = 2"
            defs `shouldBe` S.fromList ["a", "b"]

        it "tracks data type definitions" $ do
            let (defs, _) = cellNames "data Foo = Bar | Baz"
            S.member "Foo" defs `shouldBe` True

        it "tracks type alias definitions" $ do
            let (defs, _) = cellNames "type Name = String"
            S.member "Name" defs `shouldBe` True

        it "tracks newtype definitions" $ do
            let (defs, _) = cellNames "newtype Wrapper = Wrap Int"
            S.member "Wrapper" defs `shouldBe` True

        it "tracks class definitions" $ do
            let (defs, _) = cellNames "class MyShow a where"
            S.member "MyShow" defs `shouldBe` True

        it "produces no defs from a comment-only cell" $ do
            let (defs, _) = cellNames "-- just a comment"
            defs `shouldBe` S.empty

        it "does not treat import lines as definitions" $ do
            let (defs, _) = cellNames "import Data.Map"
            defs `shouldBe` S.empty

        it "does not treat pragmas as definitions" $ do
            let (defs, _) = cellNames "{-# LANGUAGE OverloadedStrings #-}"
            defs `shouldBe` S.empty

        it "extracts monadic bind as a definition" $ do
            let (defs, _) = cellNames "x <- readFile \"a\""
            S.member "x" defs `shouldBe` True

        it "treats primed identifiers as distinct names" $ do
            let (defs, uses) = cellNames "x' = x + 1"
            S.member "x'" defs `shouldBe` True
            S.member "x" uses `shouldBe` True
            -- x' and x are separate
            S.member "x" defs `shouldBe` False

    describe "computeTopoOrder — redefinition semantics (first-wins)" $ do
        it "later cell redefining a used name is flagged; downstream binds to first" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let y = x + 1"
                    , mkCell 3 "let x = 2"
                    ]
                (_, redefMap) = computeTopoOrder cells
                (defMap, _) = buildDefMap cells
            -- Cell 1 owns x (first-wins). Cell 2's `y` depends on cell
            -- 1, not cell 3. Cell 3 is flagged.
            M.lookup "x" defMap `shouldBe` Just 1
            M.lookup "y" defMap `shouldBe` Just 2
            redefMap `shouldBe` M.fromList [(3, ["x"])]

        it "three-way redef: only the first cell owns the name; others flagged" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let x = 2"
                    , mkCell 3 "let x = 3"
                    ]
                (defMap, _) = buildDefMap cells
                (_, redefMap) = computeTopoOrder cells
            M.lookup "x" defMap `shouldBe` Just 1
            redefMap `shouldBe` M.fromList [(2, ["x"]), (3, ["x"])]

        it "redef cell drops ALL its defs (even genuinely new ones)" $ do
            -- Cell 2 redefines x (already owned by cell 1) AND
            -- introduces y. Since cell 2 won't run, neither x nor y
            -- ends up in the session — so y must NOT be in defMap.
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let x = 2\nlet y = 1"
                    ]
                (defMap, _) = buildDefMap cells
                (_, redefMap) = computeTopoOrder cells
            redefMap `shouldBe` M.fromList [(2, ["x"])]
            M.lookup "x" defMap `shouldBe` Just 1
            M.lookup "y" defMap `shouldBe` Nothing

    describe "cellNames — literals and comments are not scanned" $ do
        it "does NOT pick up identifiers inside string literals" $ do
            let (_, uses) = cellNames "putStrLn \"foo bar baz\""
            S.member "foo" uses `shouldBe` False
            S.member "bar" uses `shouldBe` False
            S.member "baz" uses `shouldBe` False
            -- real use of putStrLn IS picked up
            S.member "putStrLn" uses `shouldBe` True

        it "does NOT pick up identifiers inside line comments" $ do
            let (defs, uses) = cellNames "y = 1 -- secretName is mentioned here"
            S.member "secretName" uses `shouldBe` False
            S.member "y" defs `shouldBe` True
            S.member "secretName" defs `shouldBe` False

        it "does NOT pick up identifiers inside block comments" $ do
            let (_, uses) =
                    cellNames "x = 1 {- old note about hiddenName -} + 2"
            S.member "hiddenName" uses `shouldBe` False

        it "still picks up real identifiers adjacent to literals" $ do
            let (_, uses) =
                    cellNames "main = putStrLn message >> print result"
            S.member "putStrLn" uses `shouldBe` True
            S.member "message" uses `shouldBe` True
            S.member "print" uses `shouldBe` True
            S.member "result" uses `shouldBe` True

        it "handles multi-line string literals without corrupting later defs" $ do
            let src =
                    "template :: String\n"
                        <> "template = \"defA uses defB\"\n"
                        <> "realDef = 42"
                (defs, uses) = cellNames src
            S.member "template" defs `shouldBe` True
            S.member "realDef" defs `shouldBe` True
            -- The 'defA' and 'defB' tokens inside the string must not
            -- become uses of real identifiers.
            S.member "defA" uses `shouldBe` False
            S.member "defB" uses `shouldBe` False

    describe "cellNames — function parameters are scope-local" $ do
        it "does NOT treat the inline param of `f x = ...` as a free use" $ do
            let (_, uses) = cellNames "isPrime x = x * 2"
            S.member "x" uses `shouldBe` False

        it "two cells each binding `x` do not form a cycle" $ do
            let cells =
                    [ mkCell 1 "isPrime x = x * 2"
                    , mkCell 2 "f x = x + 1"
                    ]
                (result, _) = computeTopoOrder cells
            trCycleIds result `shouldBe` S.empty

        it "params are stripped across indented continuation lines" $ do
            let src =
                    "isPrime n\n"
                        <> "  | n < 2 = False\n"
                        <> "  | n == 2 = True\n"
                        <> "  | otherwise = all (\\d -> n `mod` d /= 0) [2..n-1]"
                (defs, uses) = cellNames src
            S.member "isPrime" defs `shouldBe` True
            -- n is the function parameter; it should not be recorded as a
            -- top-level use of something defined elsewhere.
            S.member "n" uses `shouldBe` False
            -- Real uses (from the body) are preserved.
            S.member "all" uses `shouldBe` True

        it "a FREE mention of `x` outside any binding is still a use" $ do
            -- 'double x = ...' binds x locally. 'main = print (double x)'
            -- uses x at the top level — it must remain in uses.
            let src =
                    "double x = x * 2\n"
                        <> "main = print (double x)"
                (defs, uses) = cellNames src
            S.member "double" defs `shouldBe` True
            S.member "main" defs `shouldBe` True
            S.member "x" uses `shouldBe` True

        it "multiple params on one line are all treated as local" $ do
            let (_, uses) = cellNames "combine a b c = a + b * c"
            S.member "a" uses `shouldBe` False
            S.member "b" uses `shouldBe` False
            S.member "c" uses `shouldBe` False

    describe "computeTopoOrder — cycle edge cases" $ do
        it "detects a three-cell cycle" $ do
            let cells =
                    [ mkCell 1 "let a = b"
                    , mkCell 2 "let b = c"
                    , mkCell 3 "let c = a"
                    ]
                (result, _) = computeTopoOrder cells
            trCycleIds result `shouldBe` S.fromList [1, 2, 3]
            trOrdered result `shouldBe` []

        it "does not block unrelated affected cells when a cycle exists" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let y = x + 1"
                    , mkCell 3 "let a = b"
                    , mkCell 4 "let b = a"
                    ]
                (result, _) = selectAffectedTopo 1 cells
                orderedIds = map cellId (trOrdered result)
            orderedIds `shouldContain` [1]
            orderedIds `shouldContain` [2]
            orderedIds `shouldNotContain` [3]
            orderedIds `shouldNotContain` [4]

        it "does not mark a self-referencing cell as a cycle (self-deps removed)" $ do
            let cells = [mkCell 1 "let x = x + 1"]
                (result, _) = computeTopoOrder cells
            trCycleIds result `shouldBe` S.empty
            map cellId (trOrdered result) `shouldBe` [1]

    describe "Untitled.md scenario: redefining f x in a separate cell" $ do
        -- Mirrors the actual Untitled.md notebook: two cells use (f . g),
        -- two cells define f (the second redefines), one cell defines g.
        -- Under first-wins, cell 2 owns f, cell 3 owns g, cell 5 is
        -- flagged as a redefinition error.
        let cells =
                [ mkCell 1 "(f . g) 45"
                , mkCell 2 "f x = x + 5"
                , mkCell 3 "g x = x + 25"
                , mkCell 4 "(f . g) 50"
                , mkCell 5 "f x = x + 10"
                ]
        it "cell 5's redefinition of f is flagged" $ do
            let (_, redefMap) = computeTopoOrder cells
            redefMap `shouldBe` M.fromList [(5, ["f"])]

        it "cell 2 (the first definer) owns f in defMap" $ do
            let (defMap, _) = buildDefMap cells
            M.lookup "f" defMap `shouldBe` Just 2
            M.lookup "g" defMap `shouldBe` Just 3

        it "downstream cells (1, 4) depend on cell 2 for f, not cell 5" $ do
            let (defMap, _) = buildDefMap cells
                deps = buildDepGraph defMap cells
            M.findWithDefault S.empty 1 deps
                `shouldBe` S.fromList [2, 3]
            M.findWithDefault S.empty 4 deps
                `shouldBe` S.fromList [2, 3]

        it "editing the redef cell (5) flags it but runs nothing else" $ do
            let (result, redefMap) = selectAffectedTopo 5 cells
            redefMap `shouldBe` M.fromList [(5, ["f"])]
            map cellId (trOrdered result) `shouldBe` [5]

        it "editing the canonical definer (cell 2) propagates to cells 1 and 4" $ do
            let (result, _) = selectAffectedTopo 2 cells
                ids = map cellId (trOrdered result)
            ids `shouldContain` [2]
            ids `shouldContain` [1]
            ids `shouldContain` [4]
            ids `shouldNotContain` [5]

    describe "DAG: function-scoped variables across cells" $ do
        -- These cases exercise scope-aware analysis that the prior
        -- textual heuristic could not get right consistently.
        it "two cells each binding x do not produce a dependency edge" $ do
            let cells =
                    [ mkCell 1 "f x = x + 1"
                    , mkCell 2 "g x = x * 2"
                    ]
                (defMap, _) = buildDefMap cells
                deps = buildDepGraph defMap cells
            -- defMap only contains f and g; x is a local param in both.
            S.member "x" (M.keysSet defMap) `shouldBe` False
            M.findWithDefault S.empty 1 deps `shouldBe` S.empty
            M.findWithDefault S.empty 2 deps `shouldBe` S.empty

        it "where-clause locals do not create cross-cell edges" $ do
            let cells =
                    [ mkCell 1 "shout msg = greet msg\n  where greet m = m"
                    , mkCell 2 "describe greet = greet 1"
                    ]
                (defMap, _) = buildDefMap cells
                deps = buildDepGraph defMap cells
            -- Cell 1's `greet` is a where-binder, not a top-level def.
            -- Cell 2 binds `greet` as a function param. Neither is a
            -- top-level name; no edge should connect them.
            M.lookup "greet" defMap `shouldBe` Nothing
            M.findWithDefault S.empty 1 deps `shouldBe` S.empty
            M.findWithDefault S.empty 2 deps `shouldBe` S.empty

        it "do-binders do not shadow a top-level def in a sibling cell" $ do
            let cells =
                    [ mkCell 1 "msg = \"hello\""
                    , mkCell 2 "act = do\n  msg <- getLine\n  putStrLn msg"
                    ]
                (defMap, _) = buildDefMap cells
                deps = buildDepGraph defMap cells
            -- The `msg <- getLine` in cell 2 binds `msg` locally to the
            -- do-block. Cell 2's top-level def is `act`. There must be
            -- no edge from cell 2 to cell 1.
            M.lookup "msg" defMap `shouldBe` Just 1
            S.member 1 (M.findWithDefault S.empty 2 deps) `shouldBe` False

        it "list-comp generators do not create false edges" $ do
            let cells =
                    [ mkCell 1 "x = 99"
                    , mkCell 2 "evens = [n * 2 | n <- [1, 2, 3], let x = n + 1]"
                    ]
                (defMap, _) = buildDefMap cells
                deps = buildDepGraph defMap cells
            M.lookup "x" defMap `shouldBe` Just 1
            -- Cell 2's `let x = n + 1` is a comprehension-local binder;
            -- it does NOT pull in cell 1's x.
            S.member 1 (M.findWithDefault S.empty 2 deps) `shouldBe` False

    describe "DAG: imports and pragmas do not enter the graph" $ do
        it "an `import` line produces no defs and no deps" $ do
            let cells = [mkCell 1 "import Data.Map (Map)"]
                (defMap, _) = buildDefMap cells
                deps = buildDepGraph defMap cells
            defMap `shouldBe` M.empty
            M.findWithDefault S.empty 1 deps `shouldBe` S.empty

        it "a `{-# LANGUAGE ... #-}` pragma cell is empty in the DAG" $ do
            let cells = [mkCell 1 "{-# LANGUAGE OverloadedStrings #-}"]
                (defMap, _) = buildDefMap cells
                deps = buildDepGraph defMap cells
            defMap `shouldBe` M.empty
            M.findWithDefault S.empty 1 deps `shouldBe` S.empty

        it "a `:set -X...` GHCi directive cell is empty in the DAG" $ do
            let cells = [mkCell 1 ":set -XTypeApplications"]
                (defMap, _) = buildDefMap cells
                deps = buildDepGraph defMap cells
            defMap `shouldBe` M.empty
            M.findWithDefault S.empty 1 deps `shouldBe` S.empty

        it "imports + decl: defMap captures only the decl's name" $ do
            let cells =
                    [mkCell 1 "import Data.Text (Text)\ngreet name = name"]
                (defMap, _) = buildDefMap cells
            defMap `shouldBe` M.fromList [("greet", 1)]

    describe "computeTopoOrder — edge cases" $ do
        it "handles a single cell" $ do
            let cells = [mkCell 1 "let x = 1"]
                (result, redefMap) = computeTopoOrder cells
            map cellId (trOrdered result) `shouldBe` [1]
            trCycleIds result `shouldBe` S.empty
            redefMap `shouldBe` M.empty

        it "handles an empty cell list" $ do
            let (result, redefMap) = computeTopoOrder []
            trOrdered result `shouldBe` []
            trCycleIds result `shouldBe` S.empty
            redefMap `shouldBe` M.empty

        it "preserves notebook order for independent cells (stable sort)" $ do
            let cells =
                    [ mkCell 1 "let x = 1"
                    , mkCell 2 "let y = 2"
                    , mkCell 3 "let z = 3"
                    ]
                (result, _) = computeTopoOrder cells
            map cellId (trOrdered result) `shouldBe` [1, 2, 3]
