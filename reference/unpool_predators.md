# Expand pooled predator records into one row per implied fish

Optional. By default the pipeline keeps pooled records
(`n_stomachs > 1`) as one row each, and `n_stomachs` can be used as a
denominator or model offset. This function instead expands each pooled
record into `n_stomachs` synthetic individuals:

## Usage

``` r
unpool_predators(dat)
```

## Arguments

- dat:

  Tibble from
  [`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md).

## Value

`dat` with pooled records expanded, `tbl_predator_information_id` as
character (`"<id>_<copy>"` for copies), `number`, `n_stomachs` set to
`1`, `n_empty` to `0`/`1`, `regurgitated` to `0` (unless `NA`), and an
added logical `unpooled` column marking the copies.

## Details

- `n_stomachs - n_empty` fed copies share the record's prey. `count` and
  `other_count` are split as evenly as possible (`7` over 3 copies -\>
  `3, 2, 2`); `weight` is `prey_weight_ind * count` where available,
  otherwise split evenly, as is `other_wgt`. Totals sum back to the
  original record.

- `n_empty` copies get no prey and `stomach_status = "empty"`.
  `n_empty = NA` is treated as `0`.

Predator-level fields are repeated across copies. The even split is an
assumption, not data: totals and means are unchanged, but between-fish
variance is understated, the number of independent observations is
overstated, and frequency of occurrence is biased upward for the pooled
records.
