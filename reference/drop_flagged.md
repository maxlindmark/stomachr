# Remove flagged records

Removes all rows where `sense_flag` is not `NA` (i.e., rows flagged by
[`sense_check()`](https://maxlindmark.github.io/stomachr/reference/sense_check.md)).

## Usage

``` r
drop_flagged(dat)
```

## Arguments

- dat:

  Tibble from
  [`sense_check()`](https://maxlindmark.github.io/stomachr/reference/sense_check.md).

## Value

`dat` with flagged rows removed.
