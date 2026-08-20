# Read and join the four ICES stomach content CSVs

Reads `File_information.csv`, `HaulInformation.csv`,
`PredatorInformation.csv`, and `PreyInformation.csv` from `path`, joins
them into a single flat tibble, classifies each stomach as `"food"`,
`"empty"`, or `"unidentified"`, deduplicates exact-duplicate prey rows,
and optionally imputes missing coordinates from ICES rectangle
midpoints. Also warns if any predator's raw `Length`/`IndWgt` is wildly
inconsistent with an isometric length-weight curve (`W = 0.01 * L^3`), a
sign of a unit error (e.g. length in mm instead of cm), and if any
predator's `Number` is `<= 0` (not a valid pooled-sample count) –
neither check fixes anything, both are raw-data sanity checks – see
[`vignette("known-issues", package = "stomachr")`](https://maxlindmark.github.io/stomachr/articles/known-issues.md)
for worked examples of what these have caught in the live database.

## Usage

``` r
join_stomach_data(path, impute_coords = TRUE)
```

## Arguments

- path:

  Path to the directory containing the four ICES CSV files.

- impute_coords:

  If `TRUE` (default), missing `lat`/`lon` are imputed from the ICES
  rectangle midpoint via
  [`mapplots::ices.rect()`](https://rdrr.io/pkg/mapplots/man/ices.rect.html).

## Value

A tibble with one row per prey record per predator. Empty and
unidentified stomachs contribute one `NA` prey row each.
