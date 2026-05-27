# Interactive Widgets

Widgets are HTML controls — sliders, dropdowns, buttons, checkboxes, text inputs — that live inside a cell's output and trigger re-execution when the user interacts with them. No JavaScript on your part: Sabela generates the control, bridges the value back to Haskell, and re-runs the cell automatically.

## The Behavior type

Every widget is a `Behavior a` — a value that knows how to *render* itself and how to *sample* its current value:

```haskell
-- data Behavior a = Behavior { bSample :: IO a, bRender :: IO () }
-- instance Functor     Behavior
-- instance Applicative Behavior
```

The single verb `display` renders the control **and** returns the current value:

```haskell
-- display :: Behavior a -> IO a
```

## slider

```haskell
-- slider :: (Show a, Read a) => String -> a -> a -> a -> Behavior a
--           name               default  lo    hi
```

A range slider that re-runs the cell as the user drags (debounced to avoid flooding).

```haskell
c <- display (slider "celsius" (20 :: Int) (-40) 120)
let f = c * 9 `div` 5 + 32; k = c + 273

displayHtml $ unlines
  [ "<p style='font-size:1.4em;margin:4px 0'><b>" ++ show c ++ " &#8451;</b></p>"
  , "<p style='color:#888;margin:4px 0'>" ++ show f ++ " &#8457; &nbsp; " ++ show k ++ " K</p>"
  ]
```

## dropdown

```haskell
-- dropdown :: String -> [String] -> String -> Behavior String
--             name     options     default
```

A select control that re-runs on each change.

```haskell
shape <- display (dropdown "shape" ["Circle", "Square", "Triangle"] "Circle")

let svg = case shape of
      "Circle"   -> "<circle cx='60' cy='60' r='50' fill='#3498db'/>"
      "Square"   -> "<rect x='10' y='10' width='100' height='100' rx='4' fill='#e74c3c'/>"
      _          -> "<polygon points='60,10 110,110 10,110' fill='#2ecc71'/>"

displayHtml $ "<svg width='120' height='120' xmlns='http://www.w3.org/2000/svg'>" ++ svg ++ "</svg>"
```

## button

```haskell
-- button :: String -> String -> Behavior (Maybe ())
--           label    name
-- Nothing = not clicked, Just () = clicked since last run
```

A button that re-runs on each click. `Nothing` on the first run (before clicking); `Just ()` after.

```haskell
clicked <- display (button "Roll dice" "go")

let result = case clicked of
      Nothing -> "Click the button to roll."
      Just () -> "You rolled: " ++ show (42 :: Int)

displayHtml $ "<p>" ++ result ++ "</p>"
```

## checkbox

```haskell
-- checkbox :: String -> Bool -> Behavior Bool
--             name     default
```

```haskell
verbose <- display (checkbox "verbose" False)
n <- display (slider "n" (1000 :: Int) 1 10000)

if verbose then displayMarkdown ("Computing sum from 1 to " ++ show n) else return ()

displayHtml $ "<p>Result: <b>" ++ show (sum [1..n]) ++ "</b></p>"
```

## textInput

```haskell
-- textInput :: String -> String -> Behavior String
--              name     default
```

```haskell
name <- display (textInput "name" "World")

displayHtml $ "<h2>Hello, " ++ name ++ "!</h2>"
```

## scatterSelect

```haskell
-- scatterSelect :: String -> [(Double, Double)] -> Behavior [Int]
--                  name      points
```

An interactive scatter plot. Drag on the canvas to draw a freeform **lasso** — the
points inside become the selection; double-click to clear. `scatterSelect` returns
the **indices** of the selected points (positions into the `points` list you
passed), so any cell that uses the result re-runs when the selection changes. The
plot is a plain `<canvas>` with no external libraries and comfortably handles tens
of thousands of points (downsample beyond ~50k).

```haskell
let pts = [(x, sin x + x / 6) | x <- map (/ 4) [0 .. 80 :: Double]]
sel <- display (scatterSelect "wave" pts)

displayHtml $ "<p><b>" ++ show (length sel) ++ "</b> selected: "
           ++ show (take 12 sel) ++ "</p>"
```

### Styling & colour (`scatterSelectWith`)

For granite-style plot options, use `scatterSelectWith name opts pts` with a
`ScatterOpts` record — built by record-update over `defScatter`, exactly like
granite's `defPlot { … }`:

```haskell
-- defScatter :: ScatterOpts   (every field optional; these are the defaults)
--   soWidth  = 560     soHeight   = 360        -- canvas size, px
--   soColor  = "#4a9eff"   soAlpha = 0.55      -- base point colour / opacity
--   soRadius = 2           soSelColor = "#e3116c"
--   soTitle  = ""      soXLabel = ""   soYLabel = ""
--   soXBounds = Nothing    soYBounds = Nothing -- Just (lo,hi) to override the fit
--   soColorBy = []         -- [Double]: shade points by a value (gradient + colourbar)
```

Colours are **CSS strings** (`"tomato"`, `"#4a9eff"`, `"rgb(74,158,255)"`) — the
prelude is dependency-free so it can't use `Granite.Color`. Drop the alpha to tame
overplotting, and add a title/axis labels:

```haskell
let opts = defScatter { soColor = "tomato", soAlpha = 0.3, soRadius = 3
                      , soTitle = "Income vs value"
                      , soXLabel = "median income", soYLabel = "house value" }
sel <- display (scatterSelectWith "wave" opts pts)
```

Colour points by a third variable — Sabela maps it through a viridis-style gradient
and draws a colourbar:

```haskell
sel <- display (scatterSelectWith "wave" defScatter { soColorBy = sizes } pts)
--                                                     ^ sizes :: [Double], one per point
```

`scatterSelect name = scatterSelectWith name defScatter`, so the zero-config form
keeps working everywhere.

### Filtering a DataFrame by the selection

The indices line up with the rows of the `DataFrame` you built the points from
(same order). `dataframe` has no "rows by index" primitive, so define a small
helper once:

```haskell
-- cabal: build-depends: dataframe, text, containers
-- cabal: default-extensions: OverloadedStrings, TypeApplications
import qualified DataFrame as D
import qualified DataFrame.Functions as F
import DataFrame ((|>))
import qualified Data.IntSet as IntSet

selectRows :: [Int] -> D.DataFrame -> D.DataFrame
selectRows idxs df =
    let keep    = IntSet.fromList idxs
        n       = D.nRows df
        withRow = D.insert "_row" [0 .. n - 1 :: Int] df
     in withRow
            |> D.filter (F.col @Int "_row") (`IntSet.member` keep)
            |> D.select (filter (/= "_row") (D.columnNames withRow))
```

Then select-then-filter is two cells. The plot binds `sel`:

```haskell
let pts = zip (D.columnAsList (F.col @Double "median_income")     df)
              (D.columnAsList (F.col @Double "median_house_value") df)
sel <- display (scatterSelect "housing" pts)
```

…and a downstream cell reacts to it automatically:

```haskell
let chosen = selectRows sel df
displayMarkdown $ "Selected **" ++ show (D.nRows chosen) ++ "** of "
               ++ show (D.nRows df) ++ " rows"
```

See `examples/scatter-selection.md` for a complete, runnable version.

> **Note** — `scatterSelect` bakes the current selection into the canvas, so the
> highlight survives the cell re-run. Exporting a notebook to a standalone module
> does not yet freeze `scatterSelect` to a static value (the same limitation that
> applies to `fmap`/`liftA2`-composed widgets).

## Combining with fmap and liftA2

`Behavior` is `Functor` and `Applicative`, so standard Prelude functions work directly.

**`fmap`** — derive a value from one widget without binding:

```haskell
f' <- display (fmap (\c -> c * 9 `div` 5 + 32) (slider "celsius" (20 :: Int) (-40) 120))

displayHtml $ "<p>" ++ show f' ++ " &#8457;</p>"
```

**`liftA2`** — combine two widgets:

```haskell
area <- display (liftA2 (*) (slider "width" (10 :: Int) 1 100) (slider "height" (10 :: Int) 1 100))

displayHtml $ "<p>Area: <b>" ++ show area ++ "</b></p>"
```

**`pure`** — a constant behavior that renders nothing:

```haskell
x <- display (pure (42 :: Int))

displayHtml $ "<p>Always: " ++ show x ++ "</p>"
```

## DataFrame example

```haskell
-- cabal: build-depends: dataframe, text
:set -XOverloadedStrings
import qualified DataFrame as D
import qualified Data.Text as T
import DataFrame ((|>))

v <- display (slider "rows" (10 :: Int) 1 20)

D.empty |> D.insert "x" [1..100]
        |> D.insert "y" [101..200]
        |> D.take v
        |> D.toMarkdown
        |> T.unpack
        |> displayMarkdown
```

## sample and render separately

For the rare case where you need to read a value without rendering, or render without reading:

```haskell
-- sample :: Behavior a -> IO a   -- read current value, no output
-- render :: Behavior a -> IO ()  -- render control, discard value
```

## Reactivity and re-execution

- **Slider** — re-runs as the user drags, debounced at 150 ms.
- **Dropdown / Button / Checkbox / TextInput** — re-runs on each discrete change.
- Widget state persists for the lifetime of the session. Pressing **Reset** clears all values back to their defaults.
- Only the cell that owns the widget re-executes. Other cells are unaffected unless they depend on definitions from this cell.

## Low-level API (still available)

The original imperative helpers remain for backward compatibility:

```haskell
-- widgetGet    :: String -> IO (Maybe String)
-- widgetRead   :: (Show a, Read a) => String -> a -> IO a
-- displaySlider :: String -> a -> a -> a -> IO ()
-- displaySelect :: String -> [String] -> String -> IO ()
-- displayButton :: String -> String -> IO ()
```
