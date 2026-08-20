# Resolve pooled predator records to one row per predator

`Number` on a `PredatorInformation.csv` record can be greater than 1 –
DATSU documents it as "Number of specimens taken for stomach analyses
(pooled samples)". A pooled record's `pred_length`/`predator_weight`
describe one representative fish, but the prey rows linked to that same
`tbl_predator_information_id` describe the pooled group's combined diet,
not that one fish's. Downstream code that assumes one row is one
predator (diet-per-individual averages,
`n_distinct(tbl_predator_information_id)` counts,
prey-weight-to-predator-weight ratios) is silently wrong for the pooled
fraction of the data unless this is resolved one way or another. See
[`vignette("known-issues", package = "stomachr")`](https://maxlindmark.github.io/stomachr/articles/known-issues.md)
for the evidence.

## Usage

``` r
unpool_predators(dat, method = c("uncount", "filter"))
```

## Arguments

- dat:

  Tibble from
  [`add_taxonomy()`](https://maxlindmark.github.io/stomachr/reference/add_taxonomy.md).
  Must be called before
  [`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md)
  and
  [`impute_size()`](https://maxlindmark.github.io/stomachr/reference/impute_size.md)
  –
  [`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md)'s
  `regurgitated >= 1` rule needs one-fish-per-row to mean what it says
  (see `regurgitated` below), and
  [`impute_size()`](https://maxlindmark.github.io/stomachr/reference/impute_size.md)'s
  weight fallbacks should see the per-individual view, not the pooled
  one.

- method:

  One of `"uncount"` (default) or `"filter"`.

  - `"uncount"`: expands each pooled record (`Number > 1`) into `Number`
    rows, one per implied individual, each carrying a distinct pseudo
    `tbl_predator_information_id` (`"<original_id>_<copy>"`). `count` is
    apportioned across copies so the total stays an integer and sums
    back to the original (e.g. `count = 7, Number = 3` -\> `3, 2, 2`);
    `weight` is recomputed from the apportioned count and the unchanged
    per-item `prey_weight_ind`, so it also sums back exactly to the
    original. `regurgitated` (also a count, DATSU: "Number of stomachs
    regurgitated") is apportioned the same way but capped at 0/1 per
    copy – for `Number = 10, Regurgitated = 3`, 3 of the 10 copies get
    `regurgitated = 1` and 7 get `0`, so a subsequent
    [`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md)
    drops exactly the right fraction instead of the whole group or none
    of it. Predator-level fields (`pred_length`, `predator_weight`,
    etc.) are unchanged and repeated across copies – these are `Number`
    identical copies of one averaged fish, not independent observations.
    Fine for totals and for correctly weighting a pooled group's diet
    pattern by how many fish it represents; not fine if something later
    computes per-individual *variance* and would treat the copies as
    independent samples.

  - `"filter"`: drops every record with `Number > 1` outright, keeping
    only genuine single-fish records. Simpler, loses the pooled fraction
    of the data (about 2.4% of predator records) rather than resolving
    it.

  Either is defensible; doing neither is not – pick the one that fits
  the analysis rather than treating every `tbl_predator_information_id`
  as one fish by default.

## Value

`dat` with one row group per predator individual, an added logical
`unpooled` column (`TRUE` for rows created by `method = "uncount"`,
always `FALSE` under `method = "filter"`), and `number` reset to `1`
throughout.
