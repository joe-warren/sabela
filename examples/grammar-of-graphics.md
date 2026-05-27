# Plotting with the grammar of graphics

`granite` recently grew a second, richer API. The functions in
`Granite.Svg` (`bars`, `pie`, `lineGraph`, ...) are still there and still
handy for one-liners, but the new `Granite.Spec` interface describes a
chart the way *ggplot2* and *Vega* do — as **data + layers + scales +
coordinates + facets**. That little bit of extra structure buys a lot:
you can stack several geometries on the same axes, fit a regression
line, split a plot into small multiples, or bend the coordinate system
into polar space, all without leaving Haskell.

A `Chart` is built from a few pieces:

> `Chart = data + layers + scales + coord + facet + theme + size`


<!-- sabela:cell -->



- **data** — a `DataFrame` of named columns (`ColNum` for numbers,
  `ColCat` for categories)
- **layers** — one or more `Layer`s, each pairing a `Geom`
  (`GeomPoint`, `GeomLine`, `GeomBar`, …) with an aesthetic mapping
  that says which column drives `aesX`, `aesY`, `aesFill`, and so on
- **stat** — an optional transform applied before drawing
  (`StatBin`, `StatDensity`, `StatSmooth`, `StatBoxplot`)
- **scales / coord / facet** — how data maps to the screen

The pipeline turns that spec into a backend-agnostic scene, then
`renderChartSvg` emits the SVG we hand to `displaySvg`. (Its sibling,
`renderChartTerminal`, draws the same chart in braille characters if you
ever want it in a plain terminal.)



```haskell
-- cabal: build-depends: text, granite
{-# LANGUAGE OverloadedStrings #-}

import qualified Data.Text as T
import Granite.Color (Color (..))
import Granite.Data.Frame
import Granite.Render.Pipeline (renderChartSvg)
import Granite.Spec

-- A tiny helper so each cell below ends with one tidy call.
draw chart = displaySvg (T.unpack (renderChartSvg chart))
```



## Scatter with a best-fit line

The headline feature is **layering**. Here two layers share one data
frame: raw points on the bottom, and on top a line whose
`StatSmooth SmoothLm` runs an ordinary-least-squares regression and
draws the fit. Swap in `SmoothLoess` or `SmoothMovingAvg` for a
different smoother.



```haskell
:set -XOverloadedStrings

scatterFit =
    let xs    = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9] :: [Double]
        noise = [8, -0.5, 0.7, -0.2, 0.4, -0.6, 0.1, 0.3, -0.4, 0.5]
        ys    = [2 * x + 1 + n | (x, n) <- zip xs noise]
        df    = fromColumns [("x", ColNum xs), ("y", ColNum ys)]
        m     = emptyMapping
                    { aesX = Just (ColumnRef "x")
                    , aesY = Just (ColumnRef "y")
                    }
        points = (defLayer GeomPoint) {layerMapping = m}
        fit =
            (defLayer GeomLine)
                { layerMapping = m
                , layerStat = StatSmooth SmoothLm
                , layerAesDef =
                    emptyAesDefaults
                        { defColor = Just (NamedColor BrightRed)
                        , defLineWidth = Just 2
                        }
                }
     in emptyChart
            { chartData = df
            , chartLayers = [points, fit]
            , chartTitle = Just "Measured vs. fitted"
            , chartSize = SizeChars 60 18
            }

draw scatterFit
```

> <!-- sabela:mime image/svg+xml -->
> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 288" width="600" height="288" font-family="system-ui, -apple-system, sans-serif">
> <rect width="100%" height="100%" fill="white"/>
> <line x1="55" y1="260.20" x2="480" y2="260.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="55" y1="34" x2="55" y2="260.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="74.32" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="160.18" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="246.04" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">4.0</text>
> <text x="331.89" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">6.0</text>
> <text x="417.75" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">8.0</text>
> <text x="49" y="223.34" text-anchor="end" fill="#7f8c8d" font-size="11">5.0</text>
> <text x="49" y="162.86" text-anchor="end" fill="#7f8c8d" font-size="11">10.0</text>
> <text x="49" y="102.38" text-anchor="end" fill="#7f8c8d" font-size="11">15.0</text>
> <text x="49" y="41.90" text-anchor="end" fill="#7f8c8d" font-size="11">20.0</text>
> <circle cx="74.32" cy="171.29" r="3" fill="#3498db"/>
> <circle cx="117.25" cy="249.92" r="3" fill="#3498db"/>
> <circle cx="160.18" cy="211.21" r="3" fill="#3498db"/>
> <circle cx="203.11" cy="197.90" r="3" fill="#3498db"/>
> <circle cx="246.04" cy="166.45" r="3" fill="#3498db"/>
> <circle cx="288.96" cy="154.36" r="3" fill="#3498db"/>
> <circle cx="331.89" cy="121.70" r="3" fill="#3498db"/>
> <circle cx="374.82" cy="95.09" r="3" fill="#3498db"/>
> <circle cx="417.75" cy="79.36" r="3" fill="#3498db"/>
> <circle cx="460.68" cy="44.28" r="3" fill="#3498db"/>
> <polyline points="74.32,235.29 117.25,216.15 160.18,197.01 203.11,177.87 246.04,158.73 288.96,139.59 331.89,120.44 374.82,101.30 417.75,82.16 460.68,63.02" fill="none" stroke="#e74c3c" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
> <text x="267.50" y="26" text-anchor="middle" fill="#7f8c8d" font-size="14">Measured vs. fitted</text>
> <rect x="495" y="39" width="12" height="12" fill="#3498db"/>
> <text x="511" y="49" text-anchor="start" fill="#7f8c8d" font-size="11">series 0</text>
> <rect x="495" y="56" width="12" height="12" fill="#9b59b6"/>
> <text x="511" y="66" text-anchor="start" fill="#7f8c8d" font-size="11">series 1</text>
> </svg>



## Grouped bars

Long-format data — one row per *quarter × product* — plus
`layerPosition = PosDodge` places the three products side-by-side
within each quarter. Switch `PosDodge` to `PosStack` and the same data
stacks instead.



```haskell
groupedBars =
    let quarters = concat [replicate 3 q | q <- ["Q1", "Q2", "Q3", "Q4"]]
        products = take 12 (cycle ["Widgets", "Gadgets", "Gizmos"])
        sales    = [12, 8, 4, 15, 10, 6, 18, 12, 8, 22, 14, 10] :: [Double]
        df =
            fromColumns
                [ ("quarter", ColCat quarters)
                , ("product", ColCat products)
                , ("sales", ColNum sales)
                ]
        layer =
            (defLayer GeomBar)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "quarter")
                        , aesY = Just (ColumnRef "sales")
                        , aesGroup = Just (ColumnRef "product")
                        , aesFill = Just (ColumnRef "product")
                        }
                , layerStat = StatIdentity
                , layerPosition = PosDodge 0.25
                }
     in emptyChart
            { chartData = df
            , chartLayers = [layer]
            , chartTitle = Just "Unit sales by quarter"
            , chartSize = SizeChars 64 18
            }

draw groupedBars
```

> <!-- sabela:mime image/svg+xml -->
> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 288" width="640" height="288" font-family="system-ui, -apple-system, sans-serif">
> <rect width="100%" height="100%" fill="white"/>
> <line x1="55" y1="260.20" x2="520" y2="260.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="55" y1="34" x2="55" y2="260.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="116.12" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">Q1</text>
> <text x="230.37" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">Q2</text>
> <text x="344.63" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">Q3</text>
> <text x="458.88" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">Q4</text>
> <text x="49" y="253.58" text-anchor="end" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="49" y="160.11" text-anchor="end" fill="#7f8c8d" font-size="11">10.0</text>
> <text x="49" y="66.64" text-anchor="end" fill="#7f8c8d" font-size="11">20.0</text>
> <rect x="76.14" y="137.75" width="22.85" height="112.17" fill="#3498db"/>
> <rect x="104.70" y="175.14" width="22.85" height="74.78" fill="#3498db"/>
> <rect x="133.26" y="212.53" width="22.85" height="37.39" fill="#3498db"/>
> <rect x="190.39" y="109.71" width="22.85" height="140.21" fill="#3498db"/>
> <rect x="218.95" y="156.45" width="22.85" height="93.47" fill="#3498db"/>
> <rect x="247.51" y="193.84" width="22.85" height="56.08" fill="#3498db"/>
> <rect x="304.64" y="81.67" width="22.85" height="168.25" fill="#3498db"/>
> <rect x="333.20" y="137.75" width="22.85" height="112.17" fill="#3498db"/>
> <rect x="361.76" y="175.14" width="22.85" height="74.78" fill="#3498db"/>
> <rect x="418.89" y="44.28" width="22.85" height="205.64" fill="#3498db"/>
> <rect x="447.45" y="119.06" width="22.85" height="130.86" fill="#3498db"/>
> <rect x="476.01" y="156.45" width="22.85" height="93.47" fill="#3498db"/>
> <text x="287.50" y="26" text-anchor="middle" fill="#7f8c8d" font-size="14">Unit sales by quarter</text>
> <rect x="535" y="39" width="12" height="12" fill="#3498db"/>
> <text x="551" y="49" text-anchor="start" fill="#7f8c8d" font-size="11">product</text>
> </svg>



## Small multiples (faceting)

`FacetWrap` splits the data into a grid of panels by a categorical
column — the quickest way to compare a shape across groups without
cramming every series onto one set of axes.



```haskell
faceted =
    let df =
            fromColumns
                [ ("x", ColNum [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3])
                , ("y", ColNum [1, 4, 9, 16, 0, 2, 4, 6, 5, 4, 3, 2])
                , ("series", ColCat (replicate 4 "A" <> replicate 4 "B" <> replicate 4 "C"))
                ]
        layer =
            (defLayer GeomLine)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "x")
                        , aesY = Just (ColumnRef "y")
                        }
                }
     in emptyChart
            { chartData = df
            , chartLayers = [layer]
            , chartFacet = FacetWrap (ColumnRef "series") (Just 3) Nothing ScalesFixed
            , chartTitle = Just "One panel per series"
            , chartSize = SizeChars 72 18
            }

draw faceted
```

> <!-- sabela:mime image/svg+xml -->
> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 288" width="720" height="288" font-family="system-ui, -apple-system, sans-serif">
> <rect width="100%" height="100%" fill="white"/>
> <line x1="60" y1="246.20" x2="231.67" y2="246.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="60" y1="66" x2="60" y2="246.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="67.80" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="119.82" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">1.0</text>
> <text x="171.84" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="223.86" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">3.0</text>
> <text x="54" y="241.68" text-anchor="end" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="54" y="190.48" text-anchor="end" fill="#7f8c8d" font-size="11">5.0</text>
> <text x="54" y="139.29" text-anchor="end" fill="#7f8c8d" font-size="11">10.0</text>
> <text x="54" y="88.10" text-anchor="end" fill="#7f8c8d" font-size="11">15.0</text>
> <polyline points="67.80,227.77 119.82,197.05 171.84,145.86 223.86,74.19" fill="none" stroke="#3498db" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
> <text x="145.83" y="62" text-anchor="middle" fill="#555555" font-size="11">A</text>
> <line x1="241.67" y1="246.20" x2="413.33" y2="246.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="241.67" y1="66" x2="241.67" y2="246.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="249.47" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="301.49" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">1.0</text>
> <text x="353.51" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="405.53" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">3.0</text>
> <text x="235.67" y="241.68" text-anchor="end" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="235.67" y="190.48" text-anchor="end" fill="#7f8c8d" font-size="11">5.0</text>
> <text x="235.67" y="139.29" text-anchor="end" fill="#7f8c8d" font-size="11">10.0</text>
> <text x="235.67" y="88.10" text-anchor="end" fill="#7f8c8d" font-size="11">15.0</text>
> <polyline points="249.47,238.01 301.49,217.53 353.51,197.05 405.53,176.58" fill="none" stroke="#3498db" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
> <text x="327.50" y="62" text-anchor="middle" fill="#555555" font-size="11">B</text>
> <line x1="423.33" y1="246.20" x2="595" y2="246.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="423.33" y1="66" x2="423.33" y2="246.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="431.14" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="483.16" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">1.0</text>
> <text x="535.18" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="587.20" y="261.20" text-anchor="middle" fill="#7f8c8d" font-size="11">3.0</text>
> <text x="417.33" y="241.68" text-anchor="end" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="417.33" y="190.48" text-anchor="end" fill="#7f8c8d" font-size="11">5.0</text>
> <text x="417.33" y="139.29" text-anchor="end" fill="#7f8c8d" font-size="11">10.0</text>
> <text x="417.33" y="88.10" text-anchor="end" fill="#7f8c8d" font-size="11">15.0</text>
> <polyline points="431.14,186.82 483.16,197.05 535.18,207.29 587.20,217.53" fill="none" stroke="#3498db" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
> <text x="509.17" y="62" text-anchor="middle" fill="#555555" font-size="11">C</text>
> <text x="327.50" y="26" text-anchor="middle" fill="#7f8c8d" font-size="14">One panel per series</text>
> <rect x="615" y="39" width="12" height="12" fill="#3498db"/>
> <text x="631" y="49" text-anchor="start" fill="#7f8c8d" font-size="11">series 0</text>
> </svg>



## A line with a confidence band

Two layers again, but order matters: the translucent `GeomRibbon`
(reading `aesYmin`/`aesYmax`) is drawn first so the solid `GeomLine`
lands on top of it. `defAlpha` makes the band see-through.



```haskell
forecast =
    let xs  = [0, 0.5 .. 6.0] :: [Double]
        ys  = map sin xs
        los = map (\x -> sin x - 0.3) xs
        his = map (\x -> sin x + 0.3) xs
        df =
            fromColumns
                [ ("x", ColNum xs)
                , ("y", ColNum ys)
                , ("lo", ColNum los)
                , ("hi", ColNum his)
                ]
        ribbon =
            (defLayer GeomRibbon)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "x")
                        , aesYmin = Just (ColumnRef "lo")
                        , aesYmax = Just (ColumnRef "hi")
                        }
                , layerAesDef =
                    emptyAesDefaults
                        { defColor = Just (NamedColor BrightCyan)
                        , defAlpha = Just 0.3
                        }
                }
        line =
            (defLayer GeomLine)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "x")
                        , aesY = Just (ColumnRef "y")
                        }
                , layerAesDef =
                    emptyAesDefaults
                        { defColor = Just (NamedColor BrightBlue)
                        , defLineWidth = Just 2
                        }
                }
     in emptyChart
            { chartData = df
            , chartLayers = [ribbon, line]
            , chartTitle = Just "Estimate +/- 0.3 band"
            , chartSize = SizeChars 60 16
            }

draw forecast
```

> <!-- sabela:mime image/svg+xml -->
> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 256" width="600" height="256" font-family="system-ui, -apple-system, sans-serif">
> <rect width="100%" height="100%" fill="white"/>
> <line x1="55" y1="228.20" x2="480" y2="228.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="55" y1="34" x2="55" y2="228.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="74.32" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="203.11" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="331.89" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">4.0</text>
> <text x="460.68" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">6.0</text>
> <text x="49" y="204.01" text-anchor="end" fill="#7f8c8d" font-size="11">-1.0</text>
> <text x="49" y="135.45" text-anchor="end" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="49" y="66.89" text-anchor="end" fill="#7f8c8d" font-size="11">1.0</text>
> <polygon points="74.32,111.22 106.52,78.35 138.71,53.52 170.91,42.83 203.11,48.87 235.30,70.18 267.50,101.54 299.70,135.27 331.89,163.10 364.09,178.24 396.29,176.96 428.48,159.59 460.68,130.37 460.68,171.51 428.48,200.72 396.29,218.10 364.09,219.37 331.89,204.24 299.70,176.40 267.50,142.68 235.30,111.32 203.11,90.01 170.91,83.96 138.71,94.66 106.52,119.48 74.32,152.35" fill="#1abc9c" stroke="#1abc9c" stroke-width="1" fill-opacity="0.40"/>
> <polyline points="74.32,131.78 106.52,98.91 138.71,74.09 170.91,63.40 203.11,69.44 235.30,90.75 267.50,122.11 299.70,155.83 331.89,183.67 364.09,198.80 396.29,197.53 428.48,180.16 460.68,150.94" fill="none" stroke="#3498db" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
> <text x="267.50" y="26" text-anchor="middle" fill="#7f8c8d" font-size="14">Estimate +/- 0.3 band</text>
> <rect x="495" y="39" width="12" height="12" fill="#3498db"/>
> <text x="511" y="49" text-anchor="start" fill="#7f8c8d" font-size="11">series 0</text>
> <rect x="495" y="56" width="12" height="12" fill="#9b59b6"/>
> <text x="511" y="66" text-anchor="start" fill="#7f8c8d" font-size="11">series 1</text>
> </svg>



## Annotated heatmap

A `GeomTile` shades each cell along a cold→hot gradient when `aesFill`
maps to a numeric column; a second `GeomText` layer prints the value on
top. This is the recipe for a labelled correlation matrix.



```haskell
heatmap =
    let coords =
            [ (fromIntegral x, fromIntegral y, sin (fromIntegral x / 2) + cos (fromIntegral y / 2))
            | x <- [0 .. 4 :: Int]
            , y <- [0 .. 4 :: Int]
            ]
        labels = [T.pack (show (round (z * 10) :: Int)) | (_, _, z) <- coords]
        df =
            fromColumns
                [ ("x", ColNum [x | (x, _, _) <- coords])
                , ("y", ColNum [y | (_, y, _) <- coords])
                , ("z", ColNum [z | (_, _, z) <- coords])
                , ("label", ColCat labels)
                ]
        tile =
            (defLayer GeomTile)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "x")
                        , aesY = Just (ColumnRef "y")
                        , aesFill = Just (ColumnRef "z")
                        }
                , layerStat = StatIdentity
                }
        label =
            (defLayer GeomText)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "x")
                        , aesY = Just (ColumnRef "y")
                        , aesLabel = Just (ColumnRef "label")
                        }
                , layerStat = StatIdentity
                }
     in emptyChart
            { chartData = df
            , chartLayers = [tile, label]
            , chartTitle = Just "Annotated heatmap"
            , chartSize = SizeChars 48 18
            }

draw heatmap
```

> <!-- sabela:mime image/svg+xml -->
> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 288" width="480" height="288" font-family="system-ui, -apple-system, sans-serif">
> <rect width="100%" height="100%" fill="white"/>
> <line x1="55" y1="260.20" x2="360" y2="260.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="55" y1="34" x2="55" y2="260.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="91.97" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="207.50" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="323.03" y="275.20" text-anchor="middle" fill="#7f8c8d" font-size="11">4.0</text>
> <text x="49" y="236.45" text-anchor="end" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="49" y="150.77" text-anchor="end" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="49" y="65.08" text-anchor="end" fill="#7f8c8d" font-size="11">4.0</text>
> <rect x="63.09" y="211.36" width="57.77" height="42.84" fill="#2ecc71"/>
> <rect x="63.09" y="168.52" width="57.77" height="42.84" fill="#2ecc71"/>
> <rect x="63.09" y="125.68" width="57.77" height="42.84" fill="#1abc9c"/>
> <rect x="63.09" y="82.84" width="57.77" height="42.84" fill="#3498db"/>
> <rect x="63.09" y="40.00" width="57.77" height="42.84" fill="#2980b9"/>
> <rect x="120.85" y="211.36" width="57.77" height="42.84" fill="#f1c40f"/>
> <rect x="120.85" y="168.52" width="57.77" height="42.84" fill="#f1c40f"/>
> <rect x="120.85" y="125.68" width="57.77" height="42.84" fill="#2ecc71"/>
> <rect x="120.85" y="82.84" width="57.77" height="42.84" fill="#1abc9c"/>
> <rect x="120.85" y="40.00" width="57.77" height="42.84" fill="#3498db"/>
> <rect x="178.62" y="211.36" width="57.77" height="42.84" fill="#e74c3c"/>
> <rect x="178.62" y="168.52" width="57.77" height="42.84" fill="#e74c3c"/>
> <rect x="178.62" y="125.68" width="57.77" height="42.84" fill="#f1c40f"/>
> <rect x="178.62" y="82.84" width="57.77" height="42.84" fill="#2ecc71"/>
> <rect x="178.62" y="40.00" width="57.77" height="42.84" fill="#1abc9c"/>
> <rect x="236.38" y="211.36" width="57.77" height="42.84" fill="#e74c3c"/>
> <rect x="236.38" y="168.52" width="57.77" height="42.84" fill="#e74c3c"/>
> <rect x="236.38" y="125.68" width="57.77" height="42.84" fill="#f1c40f"/>
> <rect x="236.38" y="82.84" width="57.77" height="42.84" fill="#2ecc71"/>
> <rect x="236.38" y="40.00" width="57.77" height="42.84" fill="#1abc9c"/>
> <rect x="294.15" y="211.36" width="57.77" height="42.84" fill="#e74c3c"/>
> <rect x="294.15" y="168.52" width="57.77" height="42.84" fill="#e74c3c"/>
> <rect x="294.15" y="125.68" width="57.77" height="42.84" fill="#f1c40f"/>
> <rect x="294.15" y="82.84" width="57.77" height="42.84" fill="#2ecc71"/>
> <rect x="294.15" y="40.00" width="57.77" height="42.84" fill="#1abc9c"/>
> <text x="91.97" y="232.78" text-anchor="middle" fill="#9b59b6" font-size="11">10</text>
> <text x="91.97" y="189.94" text-anchor="middle" fill="#9b59b6" font-size="11">9</text>
> <text x="91.97" y="147.10" text-anchor="middle" fill="#9b59b6" font-size="11">5</text>
> <text x="91.97" y="104.26" text-anchor="middle" fill="#9b59b6" font-size="11">1</text>
> <text x="91.97" y="61.42" text-anchor="middle" fill="#9b59b6" font-size="11">-4</text>
> <text x="149.73" y="232.78" text-anchor="middle" fill="#9b59b6" font-size="11">15</text>
> <text x="149.73" y="189.94" text-anchor="middle" fill="#9b59b6" font-size="11">14</text>
> <text x="149.73" y="147.10" text-anchor="middle" fill="#9b59b6" font-size="11">10</text>
> <text x="149.73" y="104.26" text-anchor="middle" fill="#9b59b6" font-size="11">6</text>
> <text x="149.73" y="61.42" text-anchor="middle" fill="#9b59b6" font-size="11">1</text>
> <text x="207.50" y="232.78" text-anchor="middle" fill="#9b59b6" font-size="11">18</text>
> <text x="207.50" y="189.94" text-anchor="middle" fill="#9b59b6" font-size="11">17</text>
> <text x="207.50" y="147.10" text-anchor="middle" fill="#9b59b6" font-size="11">14</text>
> <text x="207.50" y="104.26" text-anchor="middle" fill="#9b59b6" font-size="11">9</text>
> <text x="207.50" y="61.42" text-anchor="middle" fill="#9b59b6" font-size="11">4</text>
> <text x="265.27" y="232.78" text-anchor="middle" fill="#9b59b6" font-size="11">20</text>
> <text x="265.27" y="189.94" text-anchor="middle" fill="#9b59b6" font-size="11">19</text>
> <text x="265.27" y="147.10" text-anchor="middle" fill="#9b59b6" font-size="11">15</text>
> <text x="265.27" y="104.26" text-anchor="middle" fill="#9b59b6" font-size="11">11</text>
> <text x="265.27" y="61.42" text-anchor="middle" fill="#9b59b6" font-size="11">6</text>
> <text x="323.03" y="232.78" text-anchor="middle" fill="#9b59b6" font-size="11">19</text>
> <text x="323.03" y="189.94" text-anchor="middle" fill="#9b59b6" font-size="11">18</text>
> <text x="323.03" y="147.10" text-anchor="middle" fill="#9b59b6" font-size="11">14</text>
> <text x="323.03" y="104.26" text-anchor="middle" fill="#9b59b6" font-size="11">10</text>
> <text x="323.03" y="61.42" text-anchor="middle" fill="#9b59b6" font-size="11">5</text>
> <text x="207.50" y="26" text-anchor="middle" fill="#7f8c8d" font-size="14">Annotated heatmap</text>
> <rect x="375" y="39" width="12" height="12" fill="#3498db"/>
> <text x="391" y="49" text-anchor="start" fill="#7f8c8d" font-size="11">series 0</text>
> <rect x="375" y="56" width="12" height="12" fill="#9b59b6"/>
> <text x="391" y="66" text-anchor="start" fill="#7f8c8d" font-size="11">series 1</text>
> </svg>



## Bending the axes: a polar rose

`CoordPolar` projects one aesthetic onto an angle and the other onto a
radius. Feed it `r = |sin(3θ)|` and you get a three-petalled rose — the
same `GeomLine` layer you'd use on Cartesian axes, just reinterpreted.



```haskell
rose =
    let n = 64 :: Int
        pts =
            [ (theta, abs (sin (3 * theta)))
            | i <- [0 .. n]
            , let theta = (fromIntegral i / fromIntegral n) * 2 * pi
            ]
        df =
            fromColumns
                [ ("theta", ColNum [t | (t, _) <- pts])
                , ("r", ColNum [r | (_, r) <- pts])
                ]
        layer =
            (defLayer GeomLine)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "theta")
                        , aesY = Just (ColumnRef "r")
                        }
                }
     in emptyChart
            { chartData = df
            , chartLayers = [layer]
            , chartCoord = CoordPolar ThetaX 0 PolarCCW
            , chartTitle = Just "r = |sin(3 theta)|"
            , chartSize = SizeChars 44 22
            }

draw rose
```

> <!-- sabela:mime image/svg+xml -->
> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 440 352" width="440" height="352" font-family="system-ui, -apple-system, sans-serif">
> <rect width="100%" height="100%" fill="white"/>
> <polyline points="193.52,179.10 193.49,179.69 193.41,180.27 193.26,180.85 193.06,181.40 192.81,181.94 192.51,182.45 192.16,182.92 191.76,183.36 191.32,183.76 190.85,184.11 190.34,184.41 189.80,184.66 189.25,184.86 188.67,185.01 188.09,185.09 187.50,185.12 186.91,185.09 186.33,185.01 185.75,184.86 185.20,184.66 184.66,184.41 184.15,184.11 183.68,183.76 183.24,183.36 182.84,182.92 182.49,182.45 182.19,181.94 181.94,181.40 181.74,180.85 181.59,180.27 181.51,179.69 181.48,179.10 181.51,178.51 181.59,177.93 181.74,177.35 181.94,176.80 182.19,176.26 182.49,175.75 182.84,175.28 183.24,174.84 183.68,174.44 184.15,174.09 184.66,173.79 185.20,173.54 185.75,173.34 186.33,173.19 186.91,173.11 187.50,173.08 188.09,173.11 188.67,173.19 189.25,173.34 189.80,173.54 190.34,173.79 190.85,174.09 191.32,174.44 191.76,174.84 192.16,175.28 192.51,175.75 192.81,176.26 193.06,176.80 193.26,177.35 193.41,177.93 193.49,178.51 193.52,179.10" fill="none" stroke="#bdc3c7" stroke-width="0.50" stroke-linejoin="round" stroke-linecap="round"/>
> <polyline points="253.75,179.10 253.43,185.59 252.48,192.02 250.90,198.33 248.71,204.45 245.93,210.33 242.58,215.91 238.71,221.13 234.35,225.95 229.53,230.31 224.31,234.18 218.73,237.53 212.85,240.31 206.73,242.50 200.42,244.08 193.99,245.03 187.50,245.35 181.01,245.03 174.58,244.08 168.27,242.50 162.15,240.31 156.27,237.53 150.69,234.18 145.47,230.31 140.65,225.95 136.29,221.13 132.42,215.91 129.07,210.33 126.29,204.45 124.10,198.33 122.52,192.02 121.57,185.59 121.25,179.10 121.57,172.61 122.52,166.18 124.10,159.87 126.29,153.75 129.07,147.87 132.42,142.29 136.29,137.07 140.65,132.25 145.47,127.89 150.69,124.02 156.27,120.67 162.15,117.89 168.27,115.70 174.58,114.12 181.01,113.17 187.50,112.85 193.99,113.17 200.42,114.12 206.73,115.70 212.85,117.89 218.73,120.67 224.31,124.02 229.53,127.89 234.35,132.25 238.71,137.07 242.58,142.29 245.93,147.87 248.71,153.75 250.90,159.87 252.48,166.18 253.43,172.61 253.75,179.10" fill="none" stroke="#bdc3c7" stroke-width="0.50" stroke-linejoin="round" stroke-linecap="round"/>
> <polyline points="313.98,179.10 313.37,191.50 311.55,203.77 308.53,215.81 304.35,227.50 299.04,238.72 292.66,249.37 285.27,259.34 276.93,268.53 267.74,276.87 257.77,284.26 247.12,290.64 235.90,295.95 224.21,300.13 212.17,303.15 199.90,304.97 187.50,305.58 175.10,304.97 162.83,303.15 150.79,300.13 139.10,295.95 127.88,290.64 117.23,284.26 107.26,276.87 98.07,268.53 89.73,259.34 82.34,249.37 75.96,238.72 70.65,227.50 66.47,215.81 63.45,203.77 61.63,191.50 61.02,179.10 61.63,166.70 63.45,154.43 66.47,142.39 70.65,130.70 75.96,119.48 82.34,108.83 89.73,98.86 98.07,89.67 107.26,81.33 117.23,73.94 127.88,67.56 139.10,62.25 150.79,58.07 162.83,55.05 175.10,53.23 187.50,52.62 199.90,53.23 212.17,55.05 224.21,58.07 235.90,62.25 247.12,67.56 257.77,73.94 267.74,81.33 276.93,89.67 285.27,98.86 292.66,108.83 299.04,119.48 304.35,130.70 308.53,142.39 311.55,154.43 313.37,166.70 313.98,179.10" fill="none" stroke="#bdc3c7" stroke-width="0.50" stroke-linejoin="round" stroke-linecap="round"/>
> <polyline points="187.50,179.10 314.63,141.77" fill="none" stroke="#bdc3c7" stroke-width="0.50" stroke-linejoin="round" stroke-linecap="round"/>
> <polyline points="187.50,179.10 120.18,64.98" fill="none" stroke="#bdc3c7" stroke-width="0.50" stroke-linejoin="round" stroke-linecap="round"/>
> <polyline points="187.50,179.10 93.34,272.32" fill="none" stroke="#bdc3c7" stroke-width="0.50" stroke-linejoin="round" stroke-linecap="round"/>
> <polyline points="187.50,179.10 300.94,247.57" fill="none" stroke="#bdc3c7" stroke-width="0.50" stroke-linejoin="round" stroke-linecap="round"/>
> <polyline points="320,179.10 319.36,192.09 317.45,204.95 314.29,217.56 309.91,229.81 304.35,241.56 297.67,252.71 289.92,263.16 281.19,272.79 271.56,281.52 261.11,289.27 249.96,295.95 238.21,301.51 225.96,305.89 213.35,309.05 200.49,310.96 187.50,311.60 174.51,310.96 161.65,309.05 149.04,305.89 136.79,301.51 125.04,295.95 113.89,289.27 103.44,281.52 93.81,272.79 85.08,263.16 77.33,252.71 70.65,241.56 65.09,229.81 60.71,217.56 57.55,204.95 55.64,192.09 55,179.10 55.64,166.11 57.55,153.25 60.71,140.64 65.09,128.39 70.65,116.64 77.33,105.49 85.08,95.04 93.81,85.41 103.44,76.68 113.89,68.93 125.04,62.25 136.79,56.69 149.04,52.31 161.65,49.15 174.51,47.24 187.50,46.60 200.49,47.24 213.35,49.15 225.96,52.31 238.21,56.69 249.96,62.25 261.11,68.93 271.56,76.68 281.19,85.41 289.92,95.04 297.67,105.49 304.35,116.64 309.91,128.39 314.29,140.64 317.45,153.25 319.36,166.11 320,179.10" fill="none" stroke="#ecf0f1" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"/>
> <text x="324.23" y="142.62" text-anchor="middle" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="115.09" y="60.03" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="86.23" y="283.02" text-anchor="middle" fill="#7f8c8d" font-size="11">4.0</text>
> <text x="309.50" y="256.40" text-anchor="middle" fill="#7f8c8d" font-size="11">6.0</text>
> <text x="196.52" y="177.10" text-anchor="start" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="256.75" y="177.10" text-anchor="start" fill="#7f8c8d" font-size="11">0.5</text>
> <text x="316.98" y="177.10" text-anchor="start" fill="#7f8c8d" font-size="11">1.0</text>
> <polyline points="193.28,177.40 225.64,164.09 252.73,146.45 271.84,127.00 281.41,108.80 281.16,94.97 272.11,88.23 256.36,90.45 236.80,102.38 216.61,123.45 198.80,151.83 192.83,162.09 198.58,128.17 197.77,97.30 191.29,72.99 181.01,57.98 169.50,53.91 159.61,61.06 153.97,78.36 154.60,103.51 162.52,133.36 177.59,164.28 168.98,156.11 143.89,133.90 118.58,119.38 96.45,113.44 80.72,115.74 73.93,124.76 77.59,138.10 91.90,152.87 115.72,166.15 146.67,175.45 181.48,179.10 146.67,182.75 115.72,192.05 91.90,205.33 77.59,220.10 73.93,233.44 80.72,242.46 96.45,244.76 118.58,238.82 143.89,224.30 168.98,202.09 177.59,193.92 162.52,224.84 154.60,254.69 153.97,279.84 159.61,297.14 169.50,304.29 181.01,300.22 191.29,285.21 197.77,260.90 198.58,230.03 192.83,196.11 198.80,206.37 216.61,234.75 236.80,255.82 256.36,267.75 272.11,269.97 281.16,263.23 281.41,249.40 271.84,231.20 252.73,211.75 225.64,194.11 193.28,180.80" fill="none" stroke="#3498db" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
> <text x="187.50" y="26" text-anchor="middle" fill="#7f8c8d" font-size="14">r = |sin(3 theta)|</text>
> <rect x="335" y="39" width="12" height="12" fill="#3498db"/>
> <text x="351" y="49" text-anchor="start" fill="#7f8c8d" font-size="11">series 0</text>
> </svg>



## Log-scale axes

Exponential growth flattens into a straight line once you set
`scaleY = SLog Base10`. The default scale options produce "nice"
integer-power ticks (1, 10, 100, …).



```haskell
logScatter =
    let xs = [1 .. 6] :: [Double]
        ys = [3, 30, 80, 200, 700, 2100] :: [Double]
        df = fromColumns [("x", ColNum xs), ("y", ColNum ys)]
        layer =
            (defLayer GeomPoint)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "x")
                        , aesY = Just (ColumnRef "y")
                        }
                }
     in emptyChart
            { chartData = df
            , chartLayers = [layer]
            , chartScales = defScales {scaleY = SLog Base10 defScaleOpts}
            , chartTitle = Just "Growth on a log axis"
            , chartSize = SizeChars 56 16
            }

draw logScatter
```

> <!-- sabela:mime image/svg+xml -->
> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 560 256" width="560" height="256" font-family="system-ui, -apple-system, sans-serif">
> <rect width="100%" height="100%" fill="white"/>
> <line x1="55" y1="228.20" x2="440" y2="228.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="55" y1="34" x2="55" y2="228.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="142.50" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="282.50" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">4.0</text>
> <text x="422.50" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">6.0</text>
> <text x="49" y="190.59" text-anchor="end" fill="#7f8c8d" font-size="11">10.0</text>
> <text x="49" y="128.54" text-anchor="end" fill="#7f8c8d" font-size="11">100.0</text>
> <text x="49" y="66.49" text-anchor="end" fill="#7f8c8d" font-size="11">1000.0</text>
> <circle cx="72.50" cy="219.37" r="3" fill="#3498db"/>
> <circle cx="142.50" cy="157.32" r="3" fill="#3498db"/>
> <circle cx="212.50" cy="130.89" r="3" fill="#3498db"/>
> <circle cx="282.50" cy="106.19" r="3" fill="#3498db"/>
> <circle cx="352.50" cy="72.43" r="3" fill="#3498db"/>
> <circle cx="422.50" cy="42.83" r="3" fill="#3498db"/>
> <text x="247.50" y="26" text-anchor="middle" fill="#7f8c8d" font-size="14">Growth on a log axis</text>
> <rect x="455" y="39" width="12" height="12" fill="#3498db"/>
> <text x="471" y="49" text-anchor="start" fill="#7f8c8d" font-size="11">series 0</text>
> </svg>



## Distribution = histogram + density

Stat transforms shine here. `StatBin` buckets the raw sample into
counts; `StatDensity` runs a Gaussian kernel density estimate. Layer
them and you get the classic "distplot".



```haskell
distribution =
    let sample =
            [ 1.0, 1.2, 1.3, 1.5, 1.7, 2.0, 2.1, 2.3
            , 2.5, 2.8, 3.0, 3.1, 3.3, 3.7, 3.9, 4.0
            ]
        df = fromColumns [("x", ColNum sample)]
        hist =
            (defLayer GeomHistogram)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "x")
                        , aesY = Just (ColumnRef "count")
                        }
                , layerStat = StatBin (BinByCount 8)
                }
        kde =
            (defLayer GeomDensity)
                { layerMapping =
                    emptyMapping
                        { aesX = Just (ColumnRef "x")
                        , aesY = Just (ColumnRef "density")
                        }
                , layerStat = StatDensity
                }
     in emptyChart
            { chartData = df
            , chartLayers = [hist, kde]
            , chartTitle = Just "Sample distribution"
            , chartSize = SizeChars 60 16
            }

draw distribution
```

> <!-- sabela:mime image/svg+xml -->
> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 256" width="600" height="256" font-family="system-ui, -apple-system, sans-serif">
> <rect width="100%" height="100%" fill="white"/>
> <line x1="55" y1="228.20" x2="480" y2="228.20" stroke="#ecf0f1" stroke-width="1"/>
> <line x1="55" y1="34" x2="55" y2="228.20" stroke="#ecf0f1" stroke-width="1"/>
> <text x="127.18" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="239.44" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="351.69" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">4.0</text>
> <text x="463.95" y="243.20" text-anchor="middle" fill="#7f8c8d" font-size="11">6.0</text>
> <text x="49" y="223.04" text-anchor="end" fill="#7f8c8d" font-size="11">0.0</text>
> <text x="49" y="164.19" text-anchor="end" fill="#7f8c8d" font-size="11">1.0</text>
> <text x="49" y="105.34" text-anchor="end" fill="#7f8c8d" font-size="11">2.0</text>
> <text x="49" y="46.49" text-anchor="end" fill="#7f8c8d" font-size="11">3.0</text>
> <rect x="185.41" y="42.83" width="16.84" height="176.55" fill="#3498db"/>
> <rect x="206.46" y="101.68" width="16.84" height="117.70" fill="#3498db"/>
> <rect x="227.51" y="101.68" width="16.84" height="117.70" fill="#3498db"/>
> <rect x="248.56" y="160.52" width="16.84" height="58.85" fill="#3498db"/>
> <rect x="269.60" y="101.68" width="16.84" height="117.70" fill="#3498db"/>
> <rect x="290.65" y="101.68" width="16.84" height="117.70" fill="#3498db"/>
> <rect x="311.70" y="160.52" width="16.84" height="58.85" fill="#3498db"/>
> <rect x="332.75" y="42.83" width="16.84" height="176.55" fill="#3498db"/>
> <polyline points="82.74,219.33 85.65,219.31 88.56,219.30 91.47,219.28 94.38,219.25 97.29,219.21 100.20,219.17 103.10,219.12 106.01,219.05 108.92,218.98 111.83,218.88 114.74,218.77 117.65,218.64 120.56,218.49 123.47,218.31 126.38,218.11 129.29,217.88 132.20,217.61 135.11,217.31 138.02,216.98 140.93,216.61 143.84,216.20 146.75,215.76 149.66,215.28 152.57,214.77 155.48,214.22 158.39,213.64 161.30,213.03 164.21,212.40 167.12,211.75 170.03,211.09 172.94,210.42 175.85,209.74 178.76,209.06 181.67,208.40 184.57,207.75 187.48,207.11 190.39,206.50 193.30,205.92 196.21,205.38 199.12,204.86 202.03,204.38 204.94,203.95 207.85,203.55 210.76,203.19 213.67,202.87 216.58,202.59 219.49,202.35 222.40,202.14 225.31,201.97 228.22,201.82 231.13,201.71 234.04,201.62 236.95,201.55 239.86,201.50 242.77,201.47 245.68,201.45 248.59,201.45 251.50,201.46 254.41,201.48 257.32,201.50 260.23,201.54 263.14,201.58 266.05,201.63 268.95,201.69 271.86,201.76 274.77,201.83 277.68,201.91 280.59,201.99 283.50,202.09 286.41,202.19 289.32,202.31 292.23,202.44 295.14,202.58 298.05,202.73 300.96,202.90 303.87,203.09 306.78,203.29 309.69,203.52 312.60,203.76 315.51,204.02 318.42,204.31 321.33,204.61 324.24,204.94 327.15,205.29 330.06,205.67 332.97,206.07 335.88,206.50 338.79,206.95 341.70,207.42 344.61,207.92 347.52,208.43 350.43,208.96 353.33,209.51 356.24,210.06 359.15,210.63 362.06,211.20 364.97,211.77 367.88,212.33 370.79,212.89 373.70,213.43 376.61,213.96 379.52,214.47 382.43,214.96 385.34,215.42 388.25,215.86 391.16,216.27 394.07,216.64 396.98,216.99 399.89,217.31 402.80,217.59 405.71,217.85 408.62,218.08 411.53,218.28 414.44,218.45 417.35,218.61 420.26,218.74 423.17,218.85 426.08,218.95 428.99,219.03 431.90,219.10 434.80,219.15 437.71,219.20 440.62,219.23 443.53,219.26 446.44,219.29 449.35,219.31 452.26,219.32" fill="none" stroke="#9b59b6" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
> <text x="267.50" y="26" text-anchor="middle" fill="#7f8c8d" font-size="14">Sample distribution</text>
> <rect x="495" y="39" width="12" height="12" fill="#3498db"/>
> <text x="511" y="49" text-anchor="start" fill="#7f8c8d" font-size="11">series 0</text>
> <rect x="495" y="56" width="12" height="12" fill="#9b59b6"/>
> <text x="511" y="66" text-anchor="start" fill="#7f8c8d" font-size="11">series 1</text>
> </svg>



## Where to go next

Everything here is just records, so the natural next move is to factor
out the parts you reuse — a `themed` chart, a `withTitle` helper, a
function that turns a `DataFrame` column pair into a layer. Because a
`Chart` is plain data you can build it up programmatically, map over a
list of datasets to produce a gallery, or pattern-match a widget value
to switch geoms live. The full catalogue of geoms, stats, and
coordinate systems lives in `granite`'s own `docs/tutorial.md`.
