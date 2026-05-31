# Getting to the Data

<hr>

## DataFrames, notebooks, and typed pipelines

_Michael Chavinda, Zurihac 2026_

<!-- sabela:cell -->

## Motivation

Haskell is excellent at building reliable systems.

But for data work, the first question is usually much simpler:

* Can I load the data?
* Can I see it?
* Can I transform it?
* Can I share what I found?
* Can I turn it into a pipeline later?

<!-- sabela:cell -->

## Point

Python won much of data work by reducing the distance between the user and the data.

Haskell, to be a viable alternative, needs to solve both sides:

1. a dataframe abstraction that feels natural for exploration
2. a notebook environment that makes Haskell immediate

<!-- sabela:cell -->

## Journies

1) Data frames and literate programming
2) Types: only when you need them
3) Creating and sharing insights

<!-- sabela:cell -->

## Why data frames matter

* Data frames became important because they made data **accessible**.
* _being able to point Pandas at a CSV was its initial killer application._ - Wes McKinney, [How Open Source, Python, and AI are changing the data future](https://www.youtube.com/watch?v=SMgUDZ9xkHM&t=609s)
* They are both a data structure and an API for exploring and transforming data.

<!-- sabela:cell -->

## But what are they really?

| Name  | Age | Department |
|-------|-----|------------|
| Alice | 34  | Eng        |
| Bob   | 25  | HR         |

They sort of look like a matrix, sort of like a spreadsheet, sort of like a table

<!-- sabela:cell -->

## What are dataframes

<img src="https://i.ibb.co/wrjH9kQG/Screenshot-2026-05-17-at-11-55-42-AM.png" alt="drawing" width="600"/>

<!-- sabela:cell -->

## But what are they really?

<img src="https://i.ibb.co/k2273j0Y/dataframe.png" width=600></img>
```haskell
displayMarkdown "## The Modin formalization"
displayLatex "\\textnormal{A dataframe is tuple } (A_{mn}, R_m, C_n, D_n) \\textnormal{, where } A_{mn} \\textnormal{ is an array of entries from the domain } \\Sigma^{*}, R_m \\newline \\textnormal{,is a vector of row labels from } \\Sigma^{*}, C_n \\textnormal{ is a vector of column labels from } \\Sigma^{*}, \\textnormal{ and } D_n \\textnormal{ is a vector of n} \\newline \\textnormal{domains from } Dom \\textnormal{ one per column, each of which can also be left unspecified.}"
```

> <!-- sabela:mime text/plain -->
> <!-- MIME:text/markdown -->
> ## The Modin formalization
> <!-- MIME:text/latex -->
> \textnormal{A dataframe is tuple } (A_{mn}, R_m, C_n, D_n) \textnormal{, where } A_{mn} \textnormal{ is an array of entries from the domain } \Sigma^{*}, R_m \newline \textnormal{,is a vector of row labels from } \Sigma^{*}, C_n \textnormal{ is a vector of column labels from } \Sigma^{*}, \textnormal{ and } D_n \textnormal{ is a vector of n} \newline \textnormal{domains from } Dom \textnormal{ one per column, each of which can also be left unspecified.}

## Put simply
* A is the underlying data
* R is an "index"
* C is a list of column labels
* D is the schema

<!-- sabela:cell -->

## Why does this definition matter for us?

* Schema and label management are separate and distinct from the actual data transformation.
* A faithful data frame implementation doesn't make the schema static and leaves the underlying dynamic and opaque.

<!-- sabela:cell -->

## Data frames as an API

![data frame API](https://images.ctfassets.net/o7xu9whrs0u9/4amC5zMhas941GjCbgiQvj/52d0c3963cf1544b0d278fbbd8d3fa1d/figure-1.png)
```python
# pip: polars
import polars as pl

df = pl.read_csv("./examples/data/housing.csv")

print(df.filter(pl.col("median_house_value") > 450000)
      .select(["latitude", "longitude", "median_house_value"])
      .sort("median_house_value", descending=True)
      .head(5))
```

> <!-- sabela:mime text/plain -->
> shape: (5, 3)
> ┌──────────┬───────────┬────────────────────┐
> │ latitude ┆ longitude ┆ median_house_value │
> │ ---      ┆ ---       ┆ ---                │
> │ f64      ┆ f64       ┆ f64                │
> ╞══════════╪═══════════╪════════════════════╡
> │ 37.8     ┆ -122.27   ┆ 500001.0           │
> │ 37.87    ┆ -122.25   ┆ 500001.0           │
> │ 37.86    ┆ -122.24   ┆ 500001.0           │
> │ 37.85    ┆ -122.24   ┆ 500001.0           │
> │ 37.83    ┆ -122.23   ┆ 500001.0           │
> └──────────┴───────────┴────────────────────┘




```haskell
-- cabal: build-depends: dataframe
:set -XOverloadedStrings

import qualified DataFrame as D
import Data.Function

df <- D.readCsv "./examples/data/housing.csv"
df & D.filter (D.col "median_house_value") (> 450000.0)
   & D.select ["latitude", "longitude", "median_house_value"]
   & D.sortBy [D.Desc (D.col "median_house_value" :: D.Expr Double)]
   & D.take 5
```

> <!-- sabela:mime text/plain -->
> -----------------------------------------
> latitude | longitude | median_house_value
> ---------|-----------|-------------------
>  Double  |  Double   |       Double      
> ---------|-----------|-------------------
> 37.8     | -122.27   | 500001.0          
> 37.87    | -122.25   | 500001.0          
> 37.86    | -122.24   | 500001.0          
> 37.85    | -122.24   | 500001.0          
> 37.83    | -122.23   | 500001.0

## Implementation

<pre>
-- Closed type universe
data Column = ColInt [Int] | ColString [String] | ...

-- Core object defining actual transformations
data DataFrame = [(String, Column)]

-- A phantom-typed wrapper that delegates operations to the core object
newtype TypedDataFrame (cols :: [Type]) = TDF {unTDF :: DataFrame}
</pre>
```haskell
-- cabal: build-depends: dataframe
:set -XOverloadedStrings
:set -XDataKinds
:set -XTypeApplications

import qualified DataFrame as D
import qualified DataFrame.Typed as T
import Data.Function

df' <- D.readCsv "./examples/data/housing.csv"
tdf = T.unsafeFreeze @'[T.Column "median_house_value" Double, T.Column "latitude" Double, T.Column "longitude" Double] df'
tdf & T.filter (T.col @"median_house_value") (> 450000.0)
    & T.select @["latitude", "longitude", "median_house_value"]
    & T.sortBy [T.desc (T.col @"median_house_value")]
    & T.take 5
```

> <!-- sabela:mime text/plain -->
> -----------------------------------------
> latitude | longitude | median_house_value
> ---------|-----------|-------------------
>  Double  |  Double   |       Double      
> ---------|-----------|-------------------
> 37.8     | -122.27   | 500001.0          
> 37.87    | -122.25   | 500001.0          
> 37.86    | -122.24   | 500001.0          
> 37.85    | -122.24   | 500001.0          
> 37.83    | -122.23   | 500001.0



<!-- sabela:cell -->

# Bringing data frames to Haskell
<hr>

## My journey with both Haskell and data frames

<!-- sabela:cell -->

## My timeline
* 2015 - learned Haskell in a discrete Math class
* 2017 - Started working at Google and joined the Haskell Users Group
* 2024 - Worked on initial version of data frame

<!-- sabela:cell -->

## Why?
** Frames, while extremely powerful, was not ergonomic