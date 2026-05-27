{-# LANGUAGE OverloadedStrings #-}

module Sabela.Output where

import Data.Text (Text)
import qualified Data.Text as T
import Sabela.Api (Example (..))

{- | Inline GHCi prelude that defines the Sabela display/widget API.
Safe to re-run before each cell because it uses ':{ :}' blocks rather than
':load', which would reset the entire GHCi context.
-}
displayPrelude :: Text
displayPrelude =
    T.unlines
        [ "import Data.IORef"
        , "import System.IO.Unsafe (unsafePerformIO)"
        , ":{"
        , "data Behavior a = Behavior {bSample :: IO a, bRender :: IO ()}"
        , "instance Functor Behavior where"
        , "    fmap f b = Behavior{bSample = fmap f (bSample b), bRender = bRender b}"
        , "instance Applicative Behavior where"
        , "    pure x = Behavior{bSample = pure x, bRender = pure ()}"
        , "    bf <*> bx = Behavior{bSample = bSample bf <*> bSample bx, bRender = bRender bf >> bRender bx}"
        , "_sabelaWidgetRef :: IORef [(String, String)]"
        , "_sabelaWidgetRef = unsafePerformIO (newIORef [])"
        , "_sabelaCellIdRef :: IORef String"
        , "_sabelaCellIdRef = unsafePerformIO (newIORef \"0\")"
        , "displayMime_ :: String -> String -> IO ()"
        , "displayMime_ t c = putStrLn (\"---MIME:\" ++ t ++ \"---\") >> putStrLn c"
        , "displayHtml :: String -> IO ()"
        , "displayHtml = displayMime_ \"text/html\""
        , "displayMarkdown :: String -> IO ()"
        , "displayMarkdown = displayMime_ \"text/markdown\""
        , "displaySvg :: String -> IO ()"
        , "displaySvg = displayMime_ \"image/svg+xml\""
        , "displayLatex :: String -> IO ()"
        , "displayLatex = displayMime_ \"text/latex\""
        , "displayJson :: String -> IO ()"
        , "displayJson = displayMime_ \"application/json\""
        , "displayImage :: String -> String -> IO ()"
        , "displayImage mime b64 = putStrLn (\"---MIME:\" ++ mime ++ \";base64---\") >> putStrLn b64"
        , "widgetGet :: String -> IO (Maybe String)"
        , "widgetGet name = fmap (lookup name) (readIORef _sabelaWidgetRef)"
        , "widgetRead :: Read a => String -> a -> IO a"
        , "widgetRead name def = fmap (lookup name) (readIORef _sabelaWidgetRef) >>= \\mv -> pure $ case mv of { Nothing -> def; Just s -> case reads s of { [(v,\"\")] -> v; _ -> def } }"
        , "displaySlider :: (Show a, Integral a) => String -> a -> a -> a -> IO ()"
        , "displaySlider name lo hi val = readIORef _sabelaCellIdRef >>= \\cid -> displayHtml $ \"<input type='range' min='\" ++ show lo ++ \"' max='\" ++ show hi ++ \"' value='\" ++ show val ++ \"' oninput=\\\"parent.postMessage({type:'widget',cellId:\" ++ cid ++ \",name:'\" ++ name ++ \"',value:this.value},'*')\\\">\""
        , "displayButton :: String -> String -> IO ()"
        , "displayButton label name = readIORef _sabelaCellIdRef >>= \\cid -> displayHtml $ \"<button onclick=\\\"parent.postMessage({type:'widget',cellId:\" ++ cid ++ \",name:'\" ++ name ++ \"',value:'clicked'},'*')\\\">\""
            <> " ++ label ++ \"</button>\""
        , "displaySelect :: String -> [String] -> String -> IO ()"
        , "displaySelect name opts val = readIORef _sabelaCellIdRef >>= \\cid -> displayHtml $ \"<select onchange=\\\"parent.postMessage({type:'widget',cellId:\" ++ cid ++ \",name:'\" ++ name ++ \"',value:this.value},'*')\\\">\""
            <> " ++ concatMap (\\o -> \"<option\" ++ (if o == val then \" selected\" else \"\") ++ \">\" ++ o ++ \"</option>\") opts ++ \"</select>\""
        , "display :: Behavior a -> IO a"
        , "display b = bRender b >> bSample b"
        , "sample :: Behavior a -> IO a"
        , "sample = bSample"
        , "render :: Behavior a -> IO ()"
        , "render = bRender"
        , "exportBridge :: String -> String -> IO ()"
        , "exportBridge name val = putStrLn (\"---MIME:EXPORT:\" ++ name ++ \"---\") >> putStrLn val >> putStrLn \"---MIME:text/plain---\""
        , "slider :: (Show a, Read a, Integral a) => String -> a -> a -> a -> Behavior a"
        , "slider name def lo hi = Behavior { bSample = widgetRead name def, bRender = widgetRead name def >>= \\val -> readIORef _sabelaCellIdRef >>= \\cid -> displayMime_ \"text/html\" $ \"<input type='range' min='\" ++ show lo ++ \"' max='\" ++ show hi ++ \"' value='\" ++ show val ++ \"' oninput=\\\"parent.postMessage({type:'widget',cellId:\" ++ cid ++ \",name:'\" ++ name ++ \"',value:this.value},'*')\\\">\""
            <> " }"
        , "dropdown :: String -> [String] -> String -> Behavior String"
        , "dropdown name opts def = Behavior { bSample = fmap (maybe def id) (widgetGet name), bRender = fmap (maybe def id) (widgetGet name) >>= \\val -> readIORef _sabelaCellIdRef >>= \\cid -> displayMime_ \"text/html\" $ \"<select onchange=\\\"parent.postMessage({type:'widget',cellId:\" ++ cid ++ \",name:'\" ++ name ++ \"',value:this.value},'*')\\\">\""
            <> " ++ concatMap (\\o -> \"<option\" ++ (if o == val then \" selected\" else \"\") ++ \">\" ++ o ++ \"</option>\") opts ++ \"</select>\" }"
        , "checkbox :: String -> Bool -> Behavior Bool"
        , "checkbox name def = Behavior { bSample = fmap (\\mv -> case mv of { Just \"true\" -> True; Just \"false\" -> False; _ -> def }) (widgetGet name)"
            <> ", bRender = fmap (\\mv -> case mv of { Just \"true\" -> True; Just \"false\" -> False; _ -> def }) (widgetGet name) >>= \\val -> readIORef _sabelaCellIdRef >>= \\cid -> displayMime_ \"text/html\" $ \"<input type='checkbox'\""
            <> " ++ (if val then \" checked\" else \"\") ++ \" onchange=\\\"parent.postMessage({type:'widget',cellId:\" ++ cid ++ \",name:'\" ++ name ++ \"',value:this.checked.toString()},'*')\\\">\""
            <> " }"
        , "textInput :: String -> String -> Behavior String"
        , "textInput name def = Behavior { bSample = fmap (maybe def id) (widgetGet name), bRender = fmap (maybe def id) (widgetGet name) >>= \\val -> readIORef _sabelaCellIdRef >>= \\cid -> displayMime_ \"text/html\" $ \"<input type='text' value='\" ++ val ++ \"' oninput=\\\"parent.postMessage({type:'widget',cellId:\" ++ cid ++ \",name:'\" ++ name ++ \"',value:this.value,sel:this.selectionStart},'*')\\\">\""
            <> " }"
        , "button :: String -> String -> Behavior (Maybe ())"
        , "button label name = Behavior { bSample = fmap (\\mv -> case mv of { Just \"clicked\" -> Just (); _ -> Nothing }) (widgetGet name)"
            <> ", bRender = readIORef _sabelaCellIdRef >>= \\cid -> displayMime_ \"text/html\" $ \"<button onclick=\\\"parent.postMessage({type:'widget',cellId:\" ++ cid ++ \",name:'\" ++ name ++ \"',value:'clicked'},'*')\\\">\""
            <> " ++ label ++ \"</button>\" }"
        ]
        <> scatterDefs
        <> ":}\n"

{- | Interactive scatter-plot selection widget, spliced into 'displayPrelude''s
single @:{ … :}@ block (it reuses 'Behavior', 'widgetRead', 'displayMime_' and
'_sabelaCellIdRef' defined alongside it). It must live in the same block as the
other widgets: a separate trailing @:{ … :}@ block did not survive the server's
repeated prelude reloads across a dependency-triggered GHCi restart.

@scatterSelect name pts@ renders an HTML5 canvas with the points fitted to view
and returns a @Behavior [Int]@ of the lasso-selected indices (positions into
@pts@). Dragging draws a freeform lasso; on mouse-up the selected indices are
posted back via the existing widget bridge as a Haskell-list literal (e.g.
@[0,4,12]@), the cell re-runs, and 'bSample' reads them back. Double-click clears.

@scatterSelectWith name opts pts@ takes a @ScatterOpts@ record (granite-style
record-update over @defScatter@) for styling — colour, alpha, point radius, title,
axis labels, x\/y bounds, canvas size — plus continuous colour-by via
@soColorBy :: [Double]@ (a viridis-ish gradient drawn with a colourbar). Colours are
CSS strings (the prelude is base-only and cannot depend on @granite@).
@scatterSelect name = scatterSelectWith name defScatter@.

The rendered HTML bakes in the current selection (@var SEL=…@) so the highlight
survives the re-run. The canvas is a static fitted view (no pan/zoom), so the
redraw on each selection is cheap and stateless. The embedded JS uses only single
quotes to keep the GHCi-source escaping minimal.
-}
scatterDefs :: Text
scatterDefs =
    T.unlines
        [ "data ScatterOpts = ScatterOpts { soWidth :: Int, soHeight :: Int, soColor :: String, soAlpha :: Double, soRadius :: Double, soSelColor :: String, soTitle :: String, soXLabel :: String, soYLabel :: String, soXBounds :: Maybe (Double, Double), soYBounds :: Maybe (Double, Double), soColorBy :: [Double] }"
        , "defScatter :: ScatterOpts"
        , "defScatter = ScatterOpts { soWidth = 560, soHeight = 360, soColor = \"#4a9eff\", soAlpha = 0.55, soRadius = 2, soSelColor = \"#e3116c\", soTitle = \"\", soXLabel = \"\", soYLabel = \"\", soXBounds = Nothing, soYBounds = Nothing, soColorBy = [] }"
        , "scatterSelect :: String -> [(Double, Double)] -> Behavior [Int]"
        , "scatterSelect name = scatterSelectWith name defScatter"
        , "scatterSelectWith :: String -> ScatterOpts -> [(Double, Double)] -> Behavior [Int]"
        , "scatterSelectWith name opts pts = Behavior { bSample = widgetRead name ([] :: [Int]), bRender = scatterRender name opts pts }"
        , "scatterRender :: String -> ScatterOpts -> [(Double, Double)] -> IO ()"
        , "scatterRender name opts pts = do"
        , "  sel <- widgetRead name ([] :: [Int])"
        , "  cid <- readIORef _sabelaCellIdRef"
        , "  displayMime_ \"text/html\" (scatterHtml name cid opts pts sel)"
        , "scatterHtml :: String -> String -> ScatterOpts -> [(Double, Double)] -> [Int] -> String"
        , "scatterHtml name cid opts pts sel = unlines"
        , "  [ \"<div style='font-family:sans-serif'>\""
        , "  , \"<canvas id='\" ++ elId ++ \"' width='\" ++ show w ++ \"' height='\" ++ show h ++ \"' style='border:1px solid #e2e2ea;border-radius:6px;cursor:crosshair;max-width:100%'></canvas>\""
        , "  , \"<div style='color:#889;font-size:11px;margin-top:5px'>drag to lasso-select &middot; double-click to clear &middot; \" ++ show (length pts) ++ \" points\" ++ (if null sel then \"\" else \", \" ++ show (length sel) ++ \" selected\") ++ \"</div>\""
        , "  , \"<script>\""
        , "  , \"(function(){\""
        , "  , \"var PTS=\" ++ ptsJs ++ \";\""
        , "  , \"var SEL=\" ++ show sel ++ \";\""
        , "  , \"var CVAL=\" ++ cvalJs ++ \";\""
        , "  , \"var NAME='\" ++ name ++ \"';\""
        , "  , \"var CID=\" ++ cid ++ \";\""
        , "  , \"var W=\" ++ show w ++ \",H=\" ++ show h ++ \",R=\" ++ show (soRadius opts) ++ \",ALPHA=\" ++ show (soAlpha opts) ++ \";\""
        , "  , \"var COLOR='\" ++ sanitize (soColor opts) ++ \"',SELCOLOR='\" ++ sanitize (soSelColor opts) ++ \"';\""
        , "  , \"var TITLE='\" ++ sanitize (soTitle opts) ++ \"',XLAB='\" ++ sanitize (soXLabel opts) ++ \"',YLAB='\" ++ sanitize (soYLabel opts) ++ \"';\""
        , "  , \"var XB=\" ++ boundsJs (soXBounds opts) ++ \",YB=\" ++ boundsJs (soYBounds opts) ++ \";\""
        , "  , \"var cv=document.getElementById('\" ++ elId ++ \"');\""
        , "  , \"if(!cv)return;\""
        , "  , \"var ctx=cv.getContext('2d');\""
        , "  , \"if(!PTS.length){return;}\""
        , "  , \"var hasC=CVAL.length===PTS.length;\""
        , "  , \"var L=YLAB?52:40,Rm=hasC?54:14,T=TITLE?26:12,B=XLAB?40:26;\""
        , "  , \"var minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity;\""
        , "  , \"for(var i=0;i<PTS.length;i++){var p=PTS[i];if(p[0]<minX)minX=p[0];if(p[0]>maxX)maxX=p[0];if(p[1]<minY)minY=p[1];if(p[1]>maxY)maxY=p[1];}\""
        , "  , \"if(XB){minX=XB[0];maxX=XB[1];}\""
        , "  , \"if(YB){minY=YB[0];maxY=YB[1];}\""
        , "  , \"if(minX===maxX){minX-=1;maxX+=1;}\""
        , "  , \"if(minY===maxY){minY-=1;maxY+=1;}\""
        , "  , \"var cmin=Infinity,cmax=-Infinity;\""
        , "  , \"if(hasC){for(var i=0;i<CVAL.length;i++){if(CVAL[i]<cmin)cmin=CVAL[i];if(CVAL[i]>cmax)cmax=CVAL[i];}if(cmin===cmax){cmin-=1;cmax+=1;}}\""
        , "  , \"function sx(x){return L+(x-minX)/(maxX-minX)*(W-L-Rm);}\""
        , "  , \"function sy(y){return (H-B)-(y-minY)/(maxY-minY)*(H-B-T);}\""
        , "  , \"var STOPS=[[68,1,84],[59,82,139],[33,145,140],[94,201,98],[253,231,37]];\""
        , "  , \"function grad(t){if(t<0)t=0;if(t>1)t=1;var s=t*4,i=Math.floor(s),f=s-i;if(i>=4){i=3;f=1;}var a=STOPS[i],b=STOPS[i+1];return 'rgb('+Math.round(a[0]+(b[0]-a[0])*f)+','+Math.round(a[1]+(b[1]-a[1])*f)+','+Math.round(a[2]+(b[2]-a[2])*f)+')';}\""
        , "  , \"function colorOf(i){return hasC?grad((CVAL[i]-cmin)/(cmax-cmin)):COLOR;}\""
        , "  , \"var XS=new Float64Array(PTS.length),YS=new Float64Array(PTS.length);\""
        , "  , \"for(var i=0;i<PTS.length;i++){XS[i]=sx(PTS[i][0]);YS[i]=sy(PTS[i][1]);}\""
        , "  , \"var base=document.createElement('canvas');base.width=W;base.height=H;\""
        , "  , \"var bctx=base.getContext('2d');\""
        , "  , \"function drawBase(sset){\""
        , "  , \"  bctx.clearRect(0,0,W,H);\""
        , "  , \"  if(TITLE){bctx.fillStyle='#222';bctx.font='600 13px sans-serif';bctx.textAlign='center';bctx.fillText(TITLE,W/2,16);}\""
        , "  , \"  bctx.strokeStyle='#d7d7e0';bctx.lineWidth=1;bctx.beginPath();bctx.moveTo(L,T-4);bctx.lineTo(L,H-B);bctx.lineTo(W-Rm+4,H-B);bctx.stroke();\""
        , "  , \"  bctx.globalAlpha=ALPHA;\""
        , "  , \"  for(var i=0;i<PTS.length;i++){if(sset&&sset.has(i))continue;bctx.fillStyle=colorOf(i);bctx.fillRect(XS[i]-R,YS[i]-R,2*R,2*R);}\""
        , "  , \"  bctx.globalAlpha=1;\""
        , "  , \"  if(sset){bctx.fillStyle=SELCOLOR;sset.forEach(function(k){var s=R+1;bctx.fillRect(XS[k]-s,YS[k]-s,2*s,2*s);});}\""
        , "  , \"  bctx.fillStyle='#99a';bctx.font='10px sans-serif';bctx.textAlign='start';\""
        , "  , \"  bctx.fillText(String(+minX.toFixed(2)),L,H-B+14);bctx.fillText(String(+maxX.toFixed(2)),W-Rm-32,H-B+14);\""
        , "  , \"  bctx.fillText(String(+maxY.toFixed(2)),4,T+6);bctx.fillText(String(+minY.toFixed(2)),4,H-B);\""
        , "  , \"  bctx.fillStyle='#556';bctx.font='11px sans-serif';bctx.textAlign='center';\""
        , "  , \"  if(XLAB)bctx.fillText(XLAB,L+(W-L-Rm)/2,H-6);\""
        , "  , \"  if(YLAB){bctx.save();bctx.translate(12,T+(H-B-T)/2);bctx.rotate(-Math.PI/2);bctx.fillText(YLAB,0,0);bctx.restore();}\""
        , "  , \"  if(hasC){var bx=W-Rm+14,bw=10,bh=H-B-T;for(var g=0;g<bh;g++){bctx.fillStyle=grad(1-g/bh);bctx.fillRect(bx,T+g,bw,1);}bctx.fillStyle='#99a';bctx.font='9px sans-serif';bctx.textAlign='start';bctx.fillText(String(+cmax.toFixed(1)),bx-3,T-3);bctx.fillText(String(+cmin.toFixed(1)),bx-3,T+bh+10);}\""
        , "  , \"}\""
        , "  , \"function repaint(poly){\""
        , "  , \"  ctx.clearRect(0,0,W,H);ctx.drawImage(base,0,0);\""
        , "  , \"  if(poly&&poly.length>1){\""
        , "  , \"    ctx.strokeStyle=SELCOLOR;ctx.fillStyle='rgba(227,17,108,0.08)';ctx.lineWidth=1.5;\""
        , "  , \"    ctx.beginPath();ctx.moveTo(poly[0][0],poly[0][1]);\""
        , "  , \"    for(var i=1;i<poly.length;i++)ctx.lineTo(poly[i][0],poly[i][1]);\""
        , "  , \"    ctx.closePath();ctx.fill();ctx.stroke();\""
        , "  , \"  }\""
        , "  , \"}\""
        , "  , \"function inPoly(px,py,poly){\""
        , "  , \"  var c=false;\""
        , "  , \"  for(var i=0,j=poly.length-1;i<poly.length;j=i++){\""
        , "  , \"    var xi=poly[i][0],yi=poly[i][1],xj=poly[j][0],yj=poly[j][1];\""
        , "  , \"    if(((yi>py)!==(yj>py))&&(px<(xj-xi)*(py-yi)/(yj-yi)+xi))c=!c;\""
        , "  , \"  }\""
        , "  , \"  return c;\""
        , "  , \"}\""
        , "  , \"function pt(e){return [e.offsetX*(cv.width/cv.clientWidth),e.offsetY*(cv.height/cv.clientHeight)];}\""
        , "  , \"function post(idx){parent.postMessage({type:'widget',cellId:CID,name:NAME,value:'['+idx.join(',')+']'},'*');}\""
        , "  , \"drawBase(new Set(SEL));repaint(null);\""
        , "  , \"var drawing=false,poly=[];\""
        , "  , \"cv.addEventListener('mousedown',function(e){drawing=true;poly=[pt(e)];});\""
        , "  , \"cv.addEventListener('mousemove',function(e){if(!drawing)return;poly.push(pt(e));repaint(poly);});\""
        , "  , \"cv.addEventListener('mouseup',function(){if(!drawing)return;drawing=false;if(poly.length<3){repaint(null);return;}var idx=[];for(var i=0;i<PTS.length;i++){if(inPoly(XS[i],YS[i],poly))idx.push(i);}drawBase(new Set(idx));repaint(null);post(idx);});\""
        , "  , \"cv.addEventListener('dblclick',function(){drawBase(new Set());repaint(null);post([]);});\""
        , "  , \"})();\""
        , "  , \"</script>\""
        , "  , \"</div>\""
        , "  ]"
        , "  where"
        , "    w = soWidth opts"
        , "    h = soHeight opts"
        , "    elId = \"sc_\" ++ cid ++ \"_\" ++ name"
        , "    sanitize = filter (\\c -> c /= '\\'' && c /= '\\\\' && c /= '<')"
        , "    ptsJs = \"[\" ++ concatMap (\\(x,y) -> \"[\" ++ show x ++ \",\" ++ show y ++ \"],\") pts ++ \"]\""
        , "    cvalJs = \"[\" ++ concatMap (\\v -> show v ++ \",\") (soColorBy opts) ++ \"]\""
        , "    boundsJs Nothing = \"null\""
        , "    boundsJs (Just (a,b)) = \"[\" ++ show a ++ \",\" ++ show b ++ \"]\""
        ]

mimeMarkerPrefix :: Text
mimeMarkerPrefix = "---MIME:"

mimeMarkerSuffix :: Text
mimeMarkerSuffix = "---"

parseMimeOutputs :: Text -> [(Text, Text)]
parseMimeOutputs raw =
    let ls = T.lines raw
        (finalMime, finalLines, acc) = foldl step ("text/plain", [], []) ls
        finalBlock = T.unlines (reverse finalLines)
        result =
            if T.null (T.strip finalBlock)
                then acc
                else (T.strip finalMime, finalBlock) : acc
     in reverse result
  where
    step (curMime, curLines, acc) l =
        case T.stripPrefix mimeMarkerPrefix l >>= T.stripSuffix mimeMarkerSuffix of
            Just mime
                | not (T.null (T.strip mime)) ->
                    let block = T.unlines (reverse curLines)
                        acc' =
                            if T.null (T.strip block)
                                then acc
                                else (T.strip curMime, block) : acc
                     in (mime, [], acc')
            _ -> (curMime, l : curLines, acc)

builtinExamples :: [Example]
builtinExamples =
    [ Example
        "Hello World"
        "Print a greeting"
        "Basics"
        "putStrLn \"Hello, Sabela!\""
    , Example
        "Fibonacci"
        "Lazy infinite list"
        "Basics"
        "let fibs = 0 : 1 : zipWith (+) fibs (tail fibs)\n\nmapM_ print (take 15 fibs)"
    , Example
        "List comprehension"
        "Pythagorean triples"
        "Basics"
        "let triples = [(a,b,c) | c <- [1..20], b <- [1..c], a <- [1..b], a*a + b*b == c*c]\n\nprint triples"
    , Example
        "Map & Filter"
        "Higher-order functions"
        "Basics"
        "let xs = [1..20]\n\nprint $ filter even $ map (^2) xs"
    , Example
        "Working with Text"
        "Text manipulation with the text library"
        "Libraries"
        "-- cabal: build-depends: text\nimport qualified Data.Text as T\nimport qualified Data.Text.IO as TIO\n\nlet msg = T.pack \"Hello, World!\"\n\nTIO.putStrLn $ T.toUpper msg\n\nTIO.putStrLn $ T.reverse msg\n\nprint $ T.words msg"
    , Example
        "HTTP Request"
        "Fetch a URL with http-conduit"
        "Libraries"
        "-- cabal: build-depends: http-conduit, bytestring\nimport Network.HTTP.Simple\nimport qualified Data.ByteString.Lazy.Char8 as L8\n\nresponse <- httpLBS \"http://httpbin.org/get\"\n\nL8.putStrLn $ getResponseBody response"
    , Example
        "JSON Parsing"
        "Decode JSON with aeson"
        "Libraries"
        "-- cabal: build-depends: aeson, text, bytestring\n{-# LANGUAGE DeriveGeneric #-}\nimport Data.Aeson\nimport GHC.Generics\nimport qualified Data.ByteString.Lazy.Char8 as L8\n\ndata Person = Person { name :: String, age :: Int } deriving (Show, Generic)\ninstance FromJSON Person\n\nlet json = L8.pack \"{\\\"name\\\": \\\"Alice\\\", \\\"age\\\": 30}\"\n\nprint (decode json :: Maybe Person)"
    , Example
        "HTML Output"
        "Render rich HTML output"
        "Display"
        "displayHtml $ unlines\n  [ \"<div style='font-family: sans-serif; padding: 16px;'>\"\n  , \"  <h2 style='color: #4a9eff;'>Hello from Sabela</h2>\"\n  , \"  <p>This is <strong>rich HTML</strong> output.</p>\"\n  , \"  <ul>\"\n  , \"    <li>Item one</li>\"\n  , \"    <li>Item two</li>\"\n  , \"  </ul>\"\n  , \"</div>\"\n  ]"
    , Example
        "SVG Chart"
        "Draw an SVG bar chart"
        "Display"
        ( T.unlines
            [ "-- cabal: build-depends: text, granite"
            , "{-# LANGUAGE OverloadedStrings #-}"
            , "import qualified Data.Text as T"
            , "import Granite.Svg"
            , ""
            , "displaySvg $ T.unpack (bars [(\"Q1\",12),(\"Q2\",18),(\"Q3\",9),(\"Q4\",15)] defPlot {plotTitle=\"Sales\"})"
            ]
        )
    , Example
        "Markdown Output"
        "Render formatted markdown"
        "Display"
        "displayMarkdown $ unlines\n  [ \"# Analysis Results\"\n  , \"\"\n  , \"The computation found **42** as the answer.\"\n  , \"\"\n  , \"| Metric | Value |\"\n  , \"|--------|-------|\"\n  , \"| Speed  | Fast  |\"\n  , \"| Memory | Low   |\"\n  ]"
    , Example
        "Latex Output"
        "Render latex equations"
        "Display"
        "displayLatex \"x^2 + y^2 = z^2\""
    , Example
        "Layered Plot"
        "Scatter with an OLS best-fit line"
        "Plotting"
        ( T.unlines
            [ "-- cabal: build-depends: text, granite"
            , "{-# LANGUAGE OverloadedStrings #-}"
            , "import qualified Data.Text as T"
            , "import Granite.Color (Color (..))"
            , "import Granite.Data.Frame"
            , "import Granite.Render.Pipeline (renderChartSvg)"
            , "import Granite.Spec"
            , ""
            , "fitX = [0,1,2,3,4,5,6,7,8,9] :: [Double]"
            , "fitY = [1.3,2.5,5.7,6.8,9.4,10.4,13.1,15.3,16.6,19.5]"
            , "fitDf = fromColumns [(\"x\", ColNum fitX), (\"y\", ColNum fitY)]"
            , "fitMap = emptyMapping {aesX = Just (ColumnRef \"x\"), aesY = Just (ColumnRef \"y\")}"
            , "fitPts = (defLayer GeomPoint) {layerMapping = fitMap}"
            , "fitLine = (defLayer GeomLine) {layerMapping = fitMap, layerStat = StatSmooth SmoothLm, layerAesDef = emptyAesDefaults {defColor = Just (NamedColor BrightRed), defLineWidth = Just 2}}"
            , "fitChart = emptyChart {chartData = fitDf, chartLayers = [fitPts, fitLine], chartTitle = Just \"Scatter + OLS fit\", chartSize = SizeChars 60 18}"
            , ""
            , "displaySvg (T.unpack (renderChartSvg fitChart))"
            ]
        )
    , Example
        "Grouped Bars"
        "Multi-series bars with a fill mapping"
        "Plotting"
        ( T.unlines
            [ "-- cabal: build-depends: text, granite"
            , "{-# LANGUAGE OverloadedStrings #-}"
            , "import qualified Data.Text as T"
            , "import Granite.Data.Frame"
            , "import Granite.Render.Pipeline (renderChartSvg)"
            , "import Granite.Spec"
            , ""
            , "barQuarters = concat [replicate 3 q | q <- [\"Q1\",\"Q2\",\"Q3\",\"Q4\"]]"
            , "barProducts = take 12 (cycle [\"Widgets\",\"Gadgets\",\"Gizmos\"])"
            , "barSales = [12,8,4,15,10,6,18,12,8,22,14,10] :: [Double]"
            , "barDf = fromColumns [(\"quarter\", ColCat barQuarters), (\"product\", ColCat barProducts), (\"sales\", ColNum barSales)]"
            , "barLayer = (defLayer GeomBar) {layerMapping = emptyMapping {aesX = Just (ColumnRef \"quarter\"), aesY = Just (ColumnRef \"sales\"), aesGroup = Just (ColumnRef \"product\"), aesFill = Just (ColumnRef \"product\")}, layerStat = StatIdentity, layerPosition = PosDodge 0.25}"
            , "barChart = emptyChart {chartData = barDf, chartLayers = [barLayer], chartTitle = Just \"Sales by quarter\", chartSize = SizeChars 64 18}"
            , ""
            , "displaySvg (T.unpack (renderChartSvg barChart))"
            ]
        )
    , Example
        "Faceted Charts"
        "Small multiples, one panel per series"
        "Plotting"
        ( T.unlines
            [ "-- cabal: build-depends: text, granite"
            , "{-# LANGUAGE OverloadedStrings #-}"
            , "import qualified Data.Text as T"
            , "import Granite.Data.Frame"
            , "import Granite.Render.Pipeline (renderChartSvg)"
            , "import Granite.Spec"
            , ""
            , "facetDf = fromColumns [(\"x\", ColNum [0,1,2,3,0,1,2,3,0,1,2,3]), (\"y\", ColNum [1,4,9,16,0,2,4,6,5,4,3,2]), (\"series\", ColCat (replicate 4 \"A\" <> replicate 4 \"B\" <> replicate 4 \"C\"))]"
            , "facetLayer = (defLayer GeomLine) {layerMapping = emptyMapping {aesX = Just (ColumnRef \"x\"), aesY = Just (ColumnRef \"y\")}}"
            , "facetChart = emptyChart {chartData = facetDf, chartLayers = [facetLayer], chartFacet = FacetWrap (ColumnRef \"series\") (Just 3) Nothing ScalesFixed, chartTitle = Just \"Faceted by series\", chartSize = SizeChars 72 18}"
            , ""
            , "displaySvg (T.unpack (renderChartSvg facetChart))"
            ]
        )
    , Example
        "Interactive Slider"
        "Temperature converter with a live slider"
        "Widgets"
        "c <- display (slider \"celsius\" (20 :: Int) (-40) 120)\nlet f = c * 9 `div` 5 + 32\n    k = c + 273\n\ndisplayHtml $ \"<p><b>\" ++ show c ++ \" \176C</b> = \" ++ show f ++ \" \176F = \" ++ show k ++ \" K</p>\""
    , Example
        "Interactive Dropdown"
        "Shape viewer driven by a select control"
        "Widgets"
        "shape <- display (dropdown \"shape\" [\"Circle\", \"Square\", \"Triangle\"] \"Circle\")\nlet svg = case shape of\n      \"Circle\"   -> \"<circle cx='60' cy='60' r='50' fill='#3498db'/>\"\n      \"Square\"   -> \"<rect x='10' y='10' width='100' height='100' rx='4' fill='#e74c3c'/>\"\n      _          -> \"<polygon points='60,10 110,110 10,110' fill='#2ecc71'/>\"\n\ndisplayHtml $ \"<svg width='120' height='120' xmlns='http://www.w3.org/2000/svg'>\" ++ svg ++ \"</svg>\""
    , Example
        "Interactive Button"
        "Prime sieve with a slider and compute button"
        "Widgets"
        "clicked <- display (button \"Compute primes\" \"go\")\nn <- display (slider \"limit\" (50 :: Int) 2 500)\nlet sieve []     = []\n    sieve (p:xs) = p : sieve [x | x <- xs, x `mod` p /= 0]\n\ncase clicked of\n  Nothing -> displayHtml \"<p>Press the button to compute.</p>\"\n  Just () -> let ps = sieve [2..n] in displayHtml $ \"<p><b>\" ++ show (length ps) ++ \" primes \\8804 \" ++ show n ++ \"</b><br>\" ++ unwords (map show ps) ++ \"</p>\""
    , Example
        "Interactive Checkbox"
        "Gate output behind a checkbox"
        "Widgets"
        "verbose <- display (checkbox \"verbose\" False)\nn <- display (slider \"n\" (1000 :: Int) 1 10000)\n\nif verbose then displayMarkdown (\"Computing sum from 1 to \" ++ show n) else return ()\n\ndisplayHtml $ \"<p>Result: <b>\" ++ show (sum [1..n]) ++ \"</b></p>\""
    , Example
        "Interactive Text Input"
        "Greet a name entered in a text box"
        "Widgets"
        "name <- display (textInput \"name\" \"World\")\ndisplayHtml $ \"<h2>Hello, \" ++ name ++ \"!</h2>\""
    , Example
        "Composed Behaviors"
        "Combine two sliders with liftA2"
        "Widgets"
        "area <- display (liftA2 (*) (slider \"width\" (10 :: Int) 1 100) (slider \"height\" (10 :: Int) 1 100))\ndisplayHtml $ \"<p>Area: <b>\" ++ show area ++ \"</b></p>\""
    , Example
        "Concurrent IO"
        "Async with threads"
        "Advanced"
        "import Control.Concurrent\nimport Control.Monad\n\nmv <- newMVar (0 :: Int)\nlet inc = modifyMVar_ mv (\\n -> pure (n+1))\n\nts <- forM [1..100] (\\_ -> forkIO inc)\n\nmapM_ (\\_ -> threadDelay 1000) ts\nthreadDelay 50000\nresult <- readMVar mv\n\nputStrLn $ \"Counter: \" ++ show result"
    , Example
        "QuickCheck"
        "Property-based testing"
        "Advanced"
        "-- cabal: build-depends: QuickCheck\nimport Test.QuickCheck\n\nlet prop_reverse xs = reverse (reverse xs) == (xs :: [Int])\nquickCheck prop_reverse\n\nlet prop_sort_length xs = length (filter even xs) + length (filter odd xs) == length (xs :: [Int])\n\nquickCheck prop_sort_length"
    , Example
        "File I/O"
        "Read and write files"
        "Advanced"
        "writeFile \"/tmp/sabela-test.txt\" \"Hello from Sabela!\\nLine two.\\n\"\ncontents <- readFile \"/tmp/sabela-test.txt\"\n\nputStrLn contents\n\nputStrLn $ \"Lines: \" ++ show (length (lines contents))"
    ]
