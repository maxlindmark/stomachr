# Read and join the four ICES stomach content CSVs

Reads `File_information.csv`, `HaulInformation.csv`,
`PredatorInformation.csv`, and `PreyInformation.csv` from `path`, joins
them into a single flat tibble, classifies each stomach as `"food"`,
`"empty"`, or `"unidentified"`, deduplicates exact-duplicate prey rows,
and optionally imputes missing coordinates from ICES rectangle
midpoints.

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
