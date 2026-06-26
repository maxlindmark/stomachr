# Impute missing prey and predator sizes

Estimates missing prey weight and/or length via L/W parameters or
observed means, and estimates missing predator weight from length.

## Usage

``` r
impute_size(
  dat,
  which = c("both", "prey", "pred"),
  method = c("lw_params", "observations"),
  size = c("both", "weight", "length"),
  fill_if_no_size = TRUE
)
```

## Arguments

- dat:

  Tibble from
  [`add_taxonomy()`](https://maxlindmark.github.io/stomachr/reference/add_taxonomy.md).

- which:

  One of `"both"` (default), `"prey"`, or `"pred"`.

- method:

  One of `"lw_params"` (default) or `"observations"`.

- size:

  One of `"both"` (default), `"weight"`, or `"length"`.

- fill_if_no_size:

  If `TRUE` (default), prey records with neither weight nor length
  borrow a size from the same stomach, same predator-prey pair, or
  global species mean, then apply L/W.

## Value

`dat` with imputed size columns and `prey_lw_source` / `pred_lw_source`
provenance columns. Internal L/W parameter columns are dropped.
