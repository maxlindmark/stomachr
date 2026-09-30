# Drop regurgitated stomachs and count usable stomachs per record

A predator record can describe a pooled sample of `number` fish, and
`regurgitated` is the number of those stomachs that were regurgitated.
This function adds:

## Usage

``` r
drop_invalid(dat, na_regurgitated = "keep")
```

## Arguments

- dat:

  Tibble from
  [`join_stomach_data()`](https://maxlindmark.github.io/stomachr/reference/join_stomach_data.md)
  or
  [`add_taxonomy()`](https://maxlindmark.github.io/stomachr/reference/add_taxonomy.md).

- na_regurgitated:

  `"keep"` (default) treats `NA` as not regurgitated; `"drop"` drops
  records with `regurgitated = NA`.

## Value

`dat` with regurgitated-only records removed and `n_stomachs` and
`n_empty` columns added.

## Details

- `n_stomachs`: usable stomachs behind the record,
  `number - regurgitated` (`number = NA` is treated as `1`).

- `n_empty`: how many of those `n_stomachs` were empty. `n_stomachs` if
  the record has no prey (`stomach_status == "empty"`), otherwise
  `stomach_empty` capped at `n_stomachs - 1`; `0` for a single fish with
  prey; `NA` for a pooled record with prey and no `stomach_empty`
  reported.

Records with no usable stomachs left (`n_stomachs <= 0`) are dropped.
For single-fish records this is the same as dropping
`regurgitated >= 1`; a pool of 10 with 3 regurgitated is kept with
`n_stomachs = 7`.

Pooled records stay one row each. Use `n_stomachs` as the denominator
for per-fish quantities (e.g. `sum(weight) / sum(n_stomachs)`), or as
`offset(log(n_stomachs))` in a model; see
[`vignette("example-workflow", package = "stomachr")`](https://maxlindmark.github.io/stomachr/articles/example-workflow.md).
To expand pools into one row per implied fish instead, follow with
[`unpool_predators()`](https://maxlindmark.github.io/stomachr/reference/unpool_predators.md).
