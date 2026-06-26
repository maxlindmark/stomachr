# Flag implausible records

Adds a `sense_flag` column (pipe-separated string of active checks) to
mark rows that fail any of the following checks:

## Usage

``` r
sense_check(dat)
```

## Arguments

- dat:

  Tibble from
  [`trim_data()`](https://maxlindmark.github.io/stomachr/reference/trim_data.md).

## Value

`dat` with an added `sense_flag` column (`NA` = no flag).

## Details

- `prey_length`: prey longer than predator

- `prey_weight`: individual prey heavier than predator

- `stomach_weight`: total stomach content weight exceeds predator weight

- `pred_length`: predator length \<= 0 or \>= 999 (sentinel value)

- `count_censored`: count was the 9999 sentinel (unknown multiplicity)

- `coord_outlier`: lat/lon outside plausible bounds covering the North
  Sea, Baltic, and Celtic Sea region (lat 45-72, lon -20 to 30)
