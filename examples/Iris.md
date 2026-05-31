# Iris Classification with a Decision Tree

This notebook is a port of the [`dataframe` Iris example](https://github.com/mchav/dataframe/blob/main/examples/Iris.ipynb).
We use the internal decision tre module instead of Hasktorch.

## Setup

We depend on `dataframe` (the dataframe library), `dataframe-learn` (the decision
tree), `text` (for the label column type) and `random` (for a reproducible
train/test split).

```haskell
-- cabal: build-depends: dataframe, dataframe-learn, text, random, vector
-- cabal: default-extensions: OverloadedStrings, TypeApplications, ScopedTypeVariables

import qualified DataFrame as D
import qualified DataFrame.Functions as F
import DataFrame.Operators
import qualified DataFrame.DecisionTree as DT
import qualified Data.Text as T
import System.Random (mkStdGen)
```

## Loading the data

The classic Iris dataset ships as a small Parquet file. Each row is one flower
with four `Double` measurements and a `variety` label.

```haskell
df <- D.readParquet "./examples/data/iris.parquet"

df |> D.take 5
   |> D.toMarkdown'
   |> displayMarkdown
```

> <!-- scripths:mime text/markdown -->
> | sepal.length<br>Double | sepal.width<br>Double | petal.length<br>Double | petal.width<br>Double | variety<br>Text |
> | -----------------------|-----------------------|------------------------|-----------------------|---------------- |
> | 5.1                    | 3.5                   | 1.4                    | 0.2                   | Setosa          |
> | 4.9                    | 3.0                   | 1.4                    | 0.2                   | Setosa          |
> | 4.7                    | 3.2                   | 1.3                    | 0.2                   | Setosa          |
> | 4.6                    | 3.1                   | 1.5                    | 0.2                   | Setosa          |
> | 5.0                    | 3.6                   | 1.4                    | 0.2                   | Setosa          |

## Looking at the data

Before modelling, it helps to know the shape and types of every column.

```haskell
df |> D.describeColumns
   |> D.toMarkdown'
   |> displayMarkdown
```

> <!-- scripths:mime text/markdown -->
> | Column Name<br>Text | # Non-null Values<br>Int | # Null Values<br>Int | Type<br>Text |
> | --------------------|--------------------------|----------------------|------------- |
> | variety             | 150                      | 0                    | Text         |
> | petal.width         | 150                      | 0                    | Double       |
> | petal.length        | 150                      | 0                    | Double       |
> | sepal.width         | 150                      | 0                    | Double       |
> | sepal.length        | 150                      | 0                    | Double       |

A summary of the numeric columns shows the ranges each measurement spans.

```haskell
df |> D.summarize
   |> D.toMarkdown'
   |> displayMarkdown
```

> <!-- scripths:mime text/markdown -->
> | Statistic<br>Text | sepal.length<br>Double | sepal.width<br>Double | petal.length<br>Double | petal.width<br>Double |
> | ------------------|------------------------|-----------------------|------------------------|---------------------- |
> | Count             | 150.0                  | 150.0                 | 150.0                  | 150.0                 |
> | Mean              | 5.84                   | 3.06                  | 3.76                   | 1.2                   |
> | Minimum           | 4.3                    | 2.0                   | 1.0                    | 0.1                   |
> | 25%               | 5.1                    | 2.8                   | 1.6                    | 0.3                   |
> | Median            | 5.8                    | 3.0                   | 4.35                   | 1.3                   |
> | 75%               | 6.4                    | 3.3                   | 5.1                    | 1.8                   |
> | Max               | 7.9                    | 4.4                   | 6.9                    | 2.5                   |
> | StdDev            | 0.83                   | 0.44                  | 1.77                   | 0.76                  |
> | IQR               | 1.3                    | 0.5                   | 3.5                    | 1.5                   |
> | Skewness          | 0.31                   | 0.31                  | -0.27                  | -0.1                  |

## Is the dataset balanced?

A severely imbalanced dataset would make accuracy a misleading metric. The Iris
dataset is famously balanced — 50 of each species — which we can confirm with
`frequencies`.

```haskell
df |> D.frequencies (F.col @T.Text "variety")
   |> D.toMarkdown'
   |> displayMarkdown
```

> <!-- scripths:mime text/markdown -->
> | Statistic<br>Text | Setosa<br>Any | Versicolor<br>Any | Virginica<br>Any |
> | ------------------|---------------|-------------------|----------------- |
> | Count             | 50            | 50                | 50               |
> | Percentage (%)    | 33.33%        | 33.33%            | 33.33%           |

## Splitting into training and test sets

`randomSplit` is the equivalent of scikit-learn's `train_test_split`. We hold
out 30% of the data for testing and fix the random seed (42) so the split is
reproducible.

```haskell
let (trainDf, testDf) = D.randomSplit (mkStdGen 42) 0.7 df

(D.dimensions trainDf, D.dimensions testDf)
```

> <!-- scripths:mime text/plain -->
> ((104,5),(46,5))

## Fitting the decision tree

This is the whole "training" step. `fitDecisionTree` takes a configuration, the
target column (`variety`, a `Text` label), and the training frame. It returns an
`Expr Text`: a self-contained expression that predicts the species from the
other columns. Everything else in the frame is treated as a candidate feature.

```haskell
let model = DT.fitDecisionTree DT.defaultTreeConfig (F.col @T.Text "variety") trainDf
```

The fitted model is just data — a tree of `if`/`then`/`else` rules over the
measurement columns. Unlike the neural network's weight matrices, you can read
it directly and see exactly how the tree decides.

```haskell
putStrLn $ D.prettyPrint model
```

> <!-- scripths:mime text/plain -->
> if petal.width .> 0.4
>   then if petal.width .< 1.8
>     then if petal.length .> 4.9
>       then "Virginica"
>       else if sepal.length .< 5.0
>         then "Virginica"
>         else "Versicolor"
>     else "Virginica"
>   else "Setosa"

## Making predictions

Because the model is an expression, we apply it to the test frame the same way
we'd add any derived column: with `D.derive`. Here we add a `predicted` column
next to the true `variety`.

```haskell
let scored = testDf |> D.derive "predicted" model

scored |> D.select ["variety", "predicted"]
       |> D.take 10
       |> D.toMarkdown'
       |> displayMarkdown
```

> <!-- scripths:mime text/markdown -->
> | variety<br>Text | predicted<br>Text |
> | ----------------|------------------ |
> | Setosa          | Setosa            |
> | Setosa          | Setosa            |
> | Setosa          | Setosa            |
> | Setosa          | Setosa            |
> | Setosa          | Setosa            |
> | Setosa          | Setosa            |
> | Setosa          | Versicolor        |
> | Setosa          | Setosa            |
> | Setosa          | Setosa            |
> | Setosa          | Setosa            |

## Measuring accuracy

We mark each test row as correct (1.0) or wrong (0.0) by comparing the true and
predicted labels with `F.eq`, then take the mean — that mean is the accuracy.

```haskell
let withCorrect =
        scored
            |> D.derive
                "is_correct"
                ( F.ifThenElse
                    (F.eq (F.col @T.Text "variety") (F.col @T.Text "predicted"))
                    (F.lit (1.0 :: Double))
                    (F.lit (0.0 :: Double))
                )

putStrLn ("Test accuracy: " ++ show (D.mean (F.col @Double "is_correct") withCorrect))
```

> <!-- scripths:mime text/plain -->
> Test accuracy: 0.8695652173913043

<!-- sabela:cell -->

## Monte Carlo cross-validation

How robust is the decision tree, and does tuning actually help? A single train/test split can mislead — one lucky shuffle and the tuned model looks better (or worse) than it really is. So we repeat the experiment over many random splits and compare the **default** config against a **tuned** one (deeper trees, finer split percentiles) across all of them.
```haskell
-- 20 random 70/30 splits; tuned = deeper trees + finer split percentiles
let nSplits     = 20
let trainFrac   = 0.7
let tunedConfig = DT.defaultTreeConfig { DT.maxTreeDepth = 8, DT.percentiles = [0,5..100] }
```

### Accuracy on one split

For a given config and random seed, we split the data, fit a tree on the training rows, predict `variety` on the held-out rows, and return the fraction predicted correctly.
```haskell
let accuracyFor cfg seed =
        let (tr, te) = D.randomSplit (mkStdGen seed) trainFrac df
            model    = DT.fitDecisionTree cfg (F.col @T.Text "variety") tr
            scored   = te
                |> D.derive "predicted"  model
                |> D.derive "is_correct"
                       (F.ifThenElse
                           (F.eq (F.col @T.Text "variety") (F.col @T.Text "predicted"))
                           (F.lit (1.0 :: Double))
                           (F.lit (0.0 :: Double)))
        in D.mean (F.col @Double "is_correct") scored
```

### Run it across every split

We score both configs on the same 20 seeds — so they face identical splits — and take the per-split difference, tuned minus default.
```haskell
let seeds       = [1 .. nSplits]
let defaultAccs = map (accuracyFor DT.defaultTreeConfig) seeds
let tunedAccs   = map (accuracyFor tunedConfig)          seeds
let diffs       = zipWith (-) tunedAccs defaultAccs
```

### Results

Mean, spread, and range of accuracy for each config, plus the paired difference — how often tuning actually won across the splits.
```haskell
import Text.Printf (printf)

let mean   xs = sum xs / fromIntegral (length xs)
let stddev xs = let m = mean xs in sqrt (mean [(x - m) ^ 2 | x <- xs])
let pct    x  = printf "%.2f%%" (x * 100) :: String

let summarise label accs =
        printf "%s:\n  mean = %s   std = %s   range = [%s, %s]"
            label (pct (mean accs)) (pct (stddev accs)) (pct (minimum accs)) (pct (maximum accs)) :: String

putStrLn (printf "--- Monte Carlo CV (%d random 70/30 splits) ---" nSplits :: String)
putStrLn (summarise "default config" defaultAccs)
putStrLn (summarise "tuned config (depth=8, percentiles every 5%)" tunedAccs)
putStrLn ""
putStrLn (printf "paired (tuned - default):  mean diff = %s   tuned wins %d / %d splits"
            (pct (mean diffs)) (length (filter (> 0) diffs)) nSplits :: String)
```

```haskell
import qualified DataFrame.Display.Web.Plot as Plot

let accDf = D.fromNamedColumns
        [ ("seed",        D.fromList (map (fromIntegral :: Int -> Double) seeds))
        , ("default_acc", D.fromList defaultAccs)
        , ("tuned_acc",   D.fromList tunedAccs)
        ]

Plot.HtmlPlot html <- Plot.line (Plot.mkLine "seed" ["default_acc", "tuned_acc"]) accDf
displayHtml (T.unpack html)
```

> <!-- scripths:mime text/html -->
> <canvas id="chart_VBKxBOjZaLh9b6jvTpjXPl6d3rIunSdpOXOWAXKXV2V9OY8F7my" style="width:100%;max-width:600px;height:400px"></canvas>
> <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.min.js"></script>
> <script>
> setTimeout(function() { new Chart("chart_VBKxBOjZaLh9b6jvTpjXPl6d3rIunSdpOXOWAXKXV2V9OY8F7my", {
>   type: "line",
>   data: {
>     labels: [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0,16.0,17.0,18.0,19.0,20.0],
>     datasets: [
>     {
>       label: "default_acc",
>       data: [0.9130434782608695,0.9433962264150944,0.9736842105263158,0.8695652173913043,0.9387755102040817,0.9782608695652174,0.9347826086956522,0.9523809523809523,0.9777777777777777,0.9787234042553191,0.8974358974358975,0.9215686274509803,1.0,1.0,0.8913043478260869,0.9069767441860465,0.9444444444444444,0.8461538461538461,0.9387755102040817,0.8863636363636364],
>       fill: false,
>       borderColor: "rgb(255, 99, 132)",
>       tension: 0.1
>     },
>     {
>       label: "tuned_acc",
>       data: [0.9565217391304348,0.9433962264150944,0.9210526315789473,0.9565217391304348,0.9591836734693877,0.9565217391304348,0.9565217391304348,0.9285714285714286,0.9333333333333333,0.9787234042553191,0.8974358974358975,0.9215686274509803,1.0,0.975609756097561,0.8913043478260869,0.9302325581395349,0.9444444444444444,0.8974358974358975,0.9591836734693877,0.9545454545454546],
>       fill: false,
>       borderColor: "rgb(54, 162, 235)",
>       tension: 0.1
>     }
>     ]
>   },
>   options: {
>     title: { display: true, text: "default_acc, tuned_acc over seed" },
>     scales: { xAxes: [{ scaleLabel: { display: true, labelString: "seed" } }] }
>   }
> })}, 100);
> </script>

```haskell
let pts       = zip (D.columnAsList (F.col @Double "petal.length") df)
                    (D.columnAsList (F.col @Double "petal.width")  df)
let varieties = D.columnAsList (F.col @T.Text "variety") df
let colorBy   = map (\v -> if v == ("Setosa" :: T.Text) then 0.0
                           else if v == "Versicolor" then 1.0
                           else 2.0 :: Double) varieties

let opts = defScatter
      { soAlpha   = 0.7
      , soRadius  = 5
      , soTitle   = "Iris: petal length vs petal width (colour = variety) — lasso to select"
      , soXLabel  = "petal.length"
      , soYLabel  = "petal.width"
      , soColorBy = colorBy
      }

sel <- display (scatterSelectWith "iris-petal-lasso" opts pts)
```

> <!-- scripths:mime text/html -->
> <div style='font-family:sans-serif'>
> <canvas id='sc_25_iris-petal-lasso' width='560' height='360' style='border:1px solid #e2e2ea;border-radius:6px;cursor:crosshair;max-width:100%'></canvas>
> <div style='color:#889;font-size:11px;margin-top:5px'>drag to lasso-select &middot; double-click to clear &middot; 150 points, 9 selected</div>
> <script>
> (function(){
> var PTS=[[1.4,0.2],[1.4,0.2],[1.3,0.2],[1.5,0.2],[1.4,0.2],[1.7,0.4],[1.4,0.3],[1.5,0.2],[1.4,0.2],[1.5,0.1],[1.5,0.2],[1.6,0.2],[1.4,0.1],[1.1,0.1],[1.2,0.2],[1.5,0.4],[1.3,0.4],[1.4,0.3],[1.7,0.3],[1.5,0.3],[1.7,0.2],[1.5,0.4],[1.0,0.2],[1.7,0.5],[1.9,0.2],[1.6,0.2],[1.6,0.4],[1.5,0.2],[1.4,0.2],[1.6,0.2],[1.6,0.2],[1.5,0.4],[1.5,0.1],[1.4,0.2],[1.5,0.2],[1.2,0.2],[1.3,0.2],[1.4,0.1],[1.3,0.2],[1.5,0.2],[1.3,0.3],[1.3,0.3],[1.3,0.2],[1.6,0.6],[1.9,0.4],[1.4,0.3],[1.6,0.2],[1.4,0.2],[1.5,0.2],[1.4,0.2],[4.7,1.4],[4.5,1.5],[4.9,1.5],[4.0,1.3],[4.6,1.5],[4.5,1.3],[4.7,1.6],[3.3,1.0],[4.6,1.3],[3.9,1.4],[3.5,1.0],[4.2,1.5],[4.0,1.0],[4.7,1.4],[3.6,1.3],[4.4,1.4],[4.5,1.5],[4.1,1.0],[4.5,1.5],[3.9,1.1],[4.8,1.8],[4.0,1.3],[4.9,1.5],[4.7,1.2],[4.3,1.3],[4.4,1.4],[4.8,1.4],[5.0,1.7],[4.5,1.5],[3.5,1.0],[3.8,1.1],[3.7,1.0],[3.9,1.2],[5.1,1.6],[4.5,1.5],[4.5,1.6],[4.7,1.5],[4.4,1.3],[4.1,1.3],[4.0,1.3],[4.4,1.2],[4.6,1.4],[4.0,1.2],[3.3,1.0],[4.2,1.3],[4.2,1.2],[4.2,1.3],[4.3,1.3],[3.0,1.1],[4.1,1.3],[6.0,2.5],[5.1,1.9],[5.9,2.1],[5.6,1.8],[5.8,2.2],[6.6,2.1],[4.5,1.7],[6.3,1.8],[5.8,1.8],[6.1,2.5],[5.1,2.0],[5.3,1.9],[5.5,2.1],[5.0,2.0],[5.1,2.4],[5.3,2.3],[5.5,1.8],[6.7,2.2],[6.9,2.3],[5.0,1.5],[5.7,2.3],[4.9,2.0],[6.7,2.0],[4.9,1.8],[5.7,2.1],[6.0,1.8],[4.8,1.8],[4.9,1.8],[5.6,2.1],[5.8,1.6],[6.1,1.9],[6.4,2.0],[5.6,2.2],[5.1,1.5],[5.6,1.4],[6.1,2.3],[5.6,2.4],[5.5,1.8],[4.8,1.8],[5.4,2.1],[5.6,2.4],[5.1,2.3],[5.1,1.9],[5.9,2.3],[5.7,2.5],[5.2,2.3],[5.0,1.9],[5.2,2.0],[5.4,2.3],[5.1,1.8],];
> var SEL=[52,70,72,77,83,119,126,133,138];
> var CVAL=[0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,2.0,];
> var NAME='iris-petal-lasso';
> var CID=25;
> var W=560,H=360,R=5.0,ALPHA=0.7;
> var COLOR='#4a9eff',SELCOLOR='#e3116c';
> var TITLE='Iris: petal length vs petal width (colour = variety) — lasso to select',XLAB='petal.length',YLAB='petal.width';
> var XB=null,YB=null;
> var cv=document.getElementById('sc_25_iris-petal-lasso');
> if(!cv)return;
> var ctx=cv.getContext('2d');
> if(!PTS.length){return;}
> var hasC=CVAL.length===PTS.length;
> var L=YLAB?52:40,Rm=hasC?54:14,T=TITLE?26:12,B=XLAB?40:26;
> var minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity;
> for(var i=0;i<PTS.length;i++){var p=PTS[i];if(p[0]<minX)minX=p[0];if(p[0]>maxX)maxX=p[0];if(p[1]<minY)minY=p[1];if(p[1]>maxY)maxY=p[1];}
> if(XB){minX=XB[0];maxX=XB[1];}
> if(YB){minY=YB[0];maxY=YB[1];}
> if(minX===maxX){minX-=1;maxX+=1;}
> if(minY===maxY){minY-=1;maxY+=1;}
> var cmin=Infinity,cmax=-Infinity;
> if(hasC){for(var i=0;i<CVAL.length;i++){if(CVAL[i]<cmin)cmin=CVAL[i];if(CVAL[i]>cmax)cmax=CVAL[i];}if(cmin===cmax){cmin-=1;cmax+=1;}}
> function sx(x){return L+(x-minX)/(maxX-minX)*(W-L-Rm);}
> function sy(y){return (H-B)-(y-minY)/(maxY-minY)*(H-B-T);}
> var STOPS=[[68,1,84],[59,82,139],[33,145,140],[94,201,98],[253,231,37]];
> function grad(t){if(t<0)t=0;if(t>1)t=1;var s=t*4,i=Math.floor(s),f=s-i;if(i>=4){i=3;f=1;}var a=STOPS[i],b=STOPS[i+1];return 'rgb('+Math.round(a[0]+(b[0]-a[0])*f)+','+Math.round(a[1]+(b[1]-a[1])*f)+','+Math.round(a[2]+(b[2]-a[2])*f)+')';}
> function colorOf(i){return hasC?grad((CVAL[i]-cmin)/(cmax-cmin)):COLOR;}
> var XS=new Float64Array(PTS.length),YS=new Float64Array(PTS.length);
> for(var i=0;i<PTS.length;i++){XS[i]=sx(PTS[i][0]);YS[i]=sy(PTS[i][1]);}
> var base=document.createElement('canvas');base.width=W;base.height=H;
> var bctx=base.getContext('2d');
> function drawBase(sset){
>   bctx.clearRect(0,0,W,H);
>   if(TITLE){bctx.fillStyle='#222';bctx.font='600 13px sans-serif';bctx.textAlign='center';bctx.fillText(TITLE,W/2,16);}
>   bctx.strokeStyle='#d7d7e0';bctx.lineWidth=1;bctx.beginPath();bctx.moveTo(L,T-4);bctx.lineTo(L,H-B);bctx.lineTo(W-Rm+4,H-B);bctx.stroke();
>   bctx.globalAlpha=ALPHA;
>   for(var i=0;i<PTS.length;i++){if(sset&&sset.has(i))continue;bctx.fillStyle=colorOf(i);bctx.fillRect(XS[i]-R,YS[i]-R,2*R,2*R);}
>   bctx.globalAlpha=1;
>   if(sset){bctx.fillStyle=SELCOLOR;sset.forEach(function(k){var s=R+1;bctx.fillRect(XS[k]-s,YS[k]-s,2*s,2*s);});}
>   bctx.fillStyle='#99a';bctx.font='10px sans-serif';bctx.textAlign='start';
>   bctx.fillText(String(+minX.toFixed(2)),L,H-B+14);bctx.fillText(String(+maxX.toFixed(2)),W-Rm-32,H-B+14);
>   bctx.fillText(String(+maxY.toFixed(2)),4,T+6);bctx.fillText(String(+minY.toFixed(2)),4,H-B);
>   bctx.fillStyle='#556';bctx.font='11px sans-serif';bctx.textAlign='center';
>   if(XLAB)bctx.fillText(XLAB,L+(W-L-Rm)/2,H-6);
>   if(YLAB){bctx.save();bctx.translate(12,T+(H-B-T)/2);bctx.rotate(-Math.PI/2);bctx.fillText(YLAB,0,0);bctx.restore();}
>   if(hasC){var bx=W-Rm+14,bw=10,bh=H-B-T;for(var g=0;g<bh;g++){bctx.fillStyle=grad(1-g/bh);bctx.fillRect(bx,T+g,bw,1);}bctx.fillStyle='#99a';bctx.font='9px sans-serif';bctx.textAlign='start';bctx.fillText(String(+cmax.toFixed(1)),bx-3,T-3);bctx.fillText(String(+cmin.toFixed(1)),bx-3,T+bh+10);}
> }
> function repaint(poly){
>   ctx.clearRect(0,0,W,H);ctx.drawImage(base,0,0);
>   if(poly&&poly.length>1){
>     ctx.strokeStyle=SELCOLOR;ctx.fillStyle='rgba(227,17,108,0.08)';ctx.lineWidth=1.5;
>     ctx.beginPath();ctx.moveTo(poly[0][0],poly[0][1]);
>     for(var i=1;i<poly.length;i++)ctx.lineTo(poly[i][0],poly[i][1]);
>     ctx.closePath();ctx.fill();ctx.stroke();
>   }
> }
> function inPoly(px,py,poly){
>   var c=false;
>   for(var i=0,j=poly.length-1;i<poly.length;j=i++){
>     var xi=poly[i][0],yi=poly[i][1],xj=poly[j][0],yj=poly[j][1];
>     if(((yi>py)!==(yj>py))&&(px<(xj-xi)*(py-yi)/(yj-yi)+xi))c=!c;
>   }
>   return c;
> }
> function pt(e){return [e.offsetX*(cv.width/cv.clientWidth),e.offsetY*(cv.height/cv.clientHeight)];}
> function post(idx){parent.postMessage({type:'widget',cellId:CID,name:NAME,value:'['+idx.join(',')+']'},'*');}
> drawBase(new Set(SEL));repaint(null);
> var drawing=false,poly=[];
> cv.addEventListener('mousedown',function(e){drawing=true;poly=[pt(e)];});
> cv.addEventListener('mousemove',function(e){if(!drawing)return;poly.push(pt(e));repaint(poly);});
> cv.addEventListener('mouseup',function(){if(!drawing)return;drawing=false;if(poly.length<3){repaint(null);return;}var idx=[];for(var i=0;i<PTS.length;i++){if(inPoly(XS[i],YS[i],poly))idx.push(i);}drawBase(new Set(idx));repaint(null);post(idx);});
> cv.addEventListener('dblclick',function(){drawBase(new Set());repaint(null);post([]);});
> })();
> </script>
> </div>

```haskell
import DataFrame.Operations.Subset (selectRows)

let chosen = selectRows sel df
let n      = D.nRows chosen

displayMarkdown $
    "**" ++ show n ++ "** of " ++ show (D.nRows df) ++ " flowers selected"
        ++ (if n == 0 then " — draw a lasso on the plot above to begin." else ":")

chosen |> D.toMarkdown'
       |> displayMarkdown
```

> <!-- scripths:mime text/plain -->
> <!-- MIME:text/markdown -->
> **9** of 150 flowers selected:
> <!-- MIME:text/markdown -->
> | sepal.length<br>Double | sepal.width<br>Double | petal.length<br>Double | petal.width<br>Double | variety<br>Text |
> | -----------------------|-----------------------|------------------------|-----------------------|---------------- |
> | 6.9                    | 3.1                   | 4.9                    | 1.5                   | Versicolor      |
> | 5.9                    | 3.2                   | 4.8                    | 1.8                   | Versicolor      |
> | 6.3                    | 2.5                   | 4.9                    | 1.5                   | Versicolor      |
> | 6.7                    | 3.0                   | 5.0                    | 1.7                   | Versicolor      |
> | 6.0                    | 2.7                   | 5.1                    | 1.6                   | Versicolor      |
> | 6.0                    | 2.2                   | 5.0                    | 1.5                   | Virginica       |
> | 6.2                    | 2.8                   | 4.8                    | 1.8                   | Virginica       |
> | 6.3                    | 2.8                   | 5.1                    | 1.5                   | Virginica       |
> | 6.0                    | 3.0                   | 4.8                    | 1.8                   | Virginica       |

## Confusion matrix

The original example built a confusion matrix by hand. With a `DataFrame` we get
it by grouping on the (actual, predicted) pair and counting. The diagonal
(`variety == predicted`) holds the correct predictions; off-diagonal entries are
the mistakes.

```haskell
scored |> D.groupBy ["variety", "predicted"]
       |> D.aggregate ["count" .= F.count (F.col @T.Text "variety")]
       |> D.sortBy [D.Asc "variety", D.Asc "predicted"]
       |> D.toMarkdown'
       |> displayMarkdown
```

> <!-- scripths:mime text/markdown -->
> | variety<br>Text | predicted<br>Text | count<br>Int |
> | ----------------|-------------------|------------- |
> | Versicolor      | Versicolor        | 14           |
> | Virginica       | Virginica         | 14           |
> | Setosa          | Versicolor        | 2            |
> | Setosa          | Setosa            | 12           |
> | Versicolor      | Virginica         | 4            |

## Conclusion

Decision trees ,on a clean, well-separated
dataset like Iris, are pretty easy and efficient to run.

```haskell
:! cat CHANGELOG.md
```

> <!-- scripths:mime text/plain -->
> # Revision history for sabela
> 
> ## 0.1.0.0 -- YYYY-mm-dd
> 
> * First version. Released on an unsuspecting world.
