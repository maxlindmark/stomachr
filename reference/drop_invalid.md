# Drop invalid (regurgitated) predator records

Removes predators where `regurgitated >= 1`. Stomach contents of
regurgitated fish are scientifically unusable for diet analysis.

## Usage

``` r
drop_invalid(dat, na_regurgitated = "keep")
```

## Arguments

- dat:

  Tibble from
  [`join_stomach_data()`](https://maxlindmark.github.io/stomachr/reference/join_stomach_data.md).

- na_regurgitated:

  `"keep"` (default) treats `NA` as not regurgitated; `"drop"` treats
  `NA` as regurgitated.

## Value

`dat` with regurgitated predators removed.
