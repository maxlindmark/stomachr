# Workflow

`stomachr` provides a tidy pipeline for downloading, reading, cleaning,
and preparing ICES stomach content data for various diet analysis. The
data come from the [ICES stomach content
database](https://stomachdata.ices.dk) and follow the new four-table
exchange format, joined by `tblUploadID`, `tblHaulID`, and
`tblPredatorInformationID`.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("maxlindmark/stomachr")
```

## Workflow

### Step 1: Download

You can download the data from the portal and go to Step 2. Or you can
call
[`download_stomach()`](https://maxlindmark.github.io/stomachr/reference/download_stomach.md),
which downloads data from the ICES API and writes the four CSVs to a
local directory (which you control via `path`). You can filter by
`year`, `country`, and `ecoregion` (one of `"Baltic Sea"`,
`"Celtic Seas"`, `"Greater North Sea"`).

``` r

path <- "data/raw"
download_stomach(path)
```

For example, to restrict to specific years, countries, or ecoregions:

``` r

download_stomach(path, year = 2000:2010, country = c("DK", "NO", "SE"))
download_stomach(path, ecoregion = "Greater North Sea")
```

In this vignette we run the pipeline on raw CSVs bundled with the
package in `inst/extdata/`, as if you had downloaded them yourself. They
were produced with, seen
[here](https://github.com/maxlindmark/stomachr/blob/master/data-raw/build_example_data.R):

``` r

download_stomach(path, year = 2020:2024, ecoregion = "Greater North Sea")
```

``` r

library(stomachr)
path <- system.file("extdata", package = "stomachr")
```

### Step 2: `join_stomach_data()`

The next step is to join the four CSVs. This means attaching haul and
file metadata to predators, classifying each stomach as `"food"`,
`"empty"`, or `"unidentified"`, and optionally imputes missing
coordinates from ICES rectangle midpoints (defaults to `"food"`).

**Known country-specific unit issues** (currently requires manual
correction before proceeding). All five fixes below are worked examples
in the [known issues
vignette](https://maxlindmark.github.io/stomachr/articles/known-issues.html)
([`vignette("known-issues", package = "stomachr")`](https://maxlindmark.github.io/stomachr/articles/known-issues.md)
locally).

- Belgium (`BE`): `pred_length` is in mm – divide by 10
- Denmark (`DK`): `ind_wgt` is in kg – multiply by 1000
- Sweden, one upload (`tbl_upload_id == "8337"`, cod, Baltic Sea):
  `pred_length` is in mm – divide by 10 (not a country-wide issue like
  the two above – Sweden’s other uploads are fine)
- Same Sweden upload: uses a legacy `regurgitated` code confirmed by
  ICES stomach analysts (`1` = intact, `2` = regurgitated, instead of
  the usual `0`/`NA` = not regurgitated, `1` = regurgitated) – shift it
  by `-1` before
  [`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md),
  or it wrongly discards good records
- Norway (`NO`): `number` is populated above `1` on many records despite
  each one being a single individually-measured fish (own `Length`, own
  `IndWgt`, `Regurgitated`/`StomachEmpty` capped at 0/1, prey-weight
  ratios that get *worse* when divided by `Number`) – treated as a
  data-entry error, not real pooling; force it to `1`

These things are not fixed internally in the join function, in case the
database gets corrected.

This following error is though corrected internally, because ices
rectangle is filled in. Some submissions (seen in Celtic Seas data) have
corrupt `ICESrectangle` codes (e.g. `"46E9"` stored as `"46000000000"`,
as if Excel read it as scientific notation).
[`join_stomach_data()`](https://maxlindmark.github.io/stomachr/reference/join_stomach_data.md)
detects codes that don’t match the real `##L#` format and recomputes
them from `ShootLat`/`ShootLong`. How many rows were affected are
printed by the function.

``` r

dat <- join_stomach_data(path)
#> Warning: ! There are outliers in predator size compared to a W=0.01*L^3 that indicate
#>   input errors. Check raw data.
#> ℹ 2,705 of 8,886 predator record flagged (|log10(observed weight / predicted
#>   weight)| > 1.5)
#> join_stomach_data(): 8,886 predator individuals
#> ✔ 3,845 (43.3%) with identifiable prey
#> ℹ 4,084 (46.0%) empty or regurgitated
#> ℹ 957 (10.8%) with prey records but no prey species ID
#>   (cannot contribute to diet composition but can contribute to total prey
#>   weight)
#> ℹ 0 haul locations imputed from ICES rectangle midpoint
#> 

dat <- dat |>
  dplyr::mutate(
    pred_length  = dplyr::if_else(country == "BE" | tbl_upload_id == "8337", pred_length / 10, pred_length),
    ind_wgt      = dplyr::if_else(country == "DK", ind_wgt * 1000, ind_wgt),
    regurgitated = dplyr::if_else(tbl_upload_id == "8337", regurgitated - 1, regurgitated),
    number       = dplyr::if_else(country == "NO", 1, number)
  )
```

### Step 3: `add_taxonomy()`

Joins scientific names and higher taxonomy (class, order, family,
phylum) for both predators and prey from the internal WoRMS lookup. Prey
with `aphia_id_prey = NA` in non-empty stomachs are labelled `"Unknown"`
so their weight is not silently lost.

``` r

dat <- add_taxonomy(dat)
#> add_taxonomy(): WoRMS names resolved
#> ✔ Predator AphiaIDs: 23 unique, 0 unresolved
#> ✔ Prey AphiaIDs: 254 unique, 0 unresolved
#> 
```

### Step 4: `unpool_predators()`

Some `PredatorInformation` records have `Number > 1`: not one fish, but
a pooled group of that many ([file format
documentation](https://datsu.ices.dk/web/selRep.aspx?Dataset=157):
“Number of specimens taken for stomach analyses (pooled samples)”. If
you want to look at prey weigths in stomachs, e.g. for feeding rates,
it’s important that they are filtered or expanded, so that 1 row = 1
individual predator.

- `method = "uncount"` (default): expands each pooled record into
  `Number` rows (one pseudo-individual per implied fish), distributing
  `count`/`weight`/`regurgitated` so they sum back to the original
  totals (Example: for `Number = 10, Regurgitated = 3`, 3 of the 10
  copies get `regurgitated = 1`, so
  [`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md)
  below drops exactly those 3, not all 10 or none). Note, these aren’t
  independent observations, so treat them accordingly for anything
  computing per-individual variance.
- `method = "filter"`: drops `Number > 1` records outright instead.

This has to run before
[`drop_invalid()`](https://maxlindmark.github.io/stomachr/reference/drop_invalid.md),
not after – otherwise a partially-regurgitated pooled group gets dropped
(or kept) as a whole before it can be resolved per implied individual.

``` r

dat <- unpool_predators(dat, method = "uncount")
```

### Step 5: `drop_invalid()`

Removes predators with `regurgitated >= 1`. Stomach contents of
regurgitated fish are not really usable. The `na_regurgitated` argument
controls whether `NA` values are treated as not regurgitated (`"keep"`,
default) or regurgitated (`"drop"`).

``` r

dat <- drop_invalid(dat, na_regurgitated = "keep")
#> drop_invalid(): 8,886 -> 8,559 predators (327 dropped, 3.7%)
#> ℹ regurgitated value >= 1 assumed regurgitated
#> ℹ regurgitated == NA assumed not regurgitated (n = 3,927 kept)
#> ℹ Dropped by country:
#>   country   n percent_of_total
#> 1      BE  18             0.2%
#> 2      DK   6             0.1%
#> 3      NL 114             1.3%
#> 4      NO  30             0.3%
#> 5      SE 159             1.8%
#> 
```

### Step 6: `impute_size()`

Estimates missing prey weight and/or length via L/W parameters or
observed means, and estimates missing predator weight from length. Also
creates the final `predator_weight` column (observed weight if
available, otherwise estimated from length). L/W parameters are looked
up from the internal table (FishBase for fish, Robinson 2010 for
invertebrates) with hierarchical fallback: species -\> family -\> order
-\> class -\> phylum -\> universal (a = 0.01, b = 3).

Future versions of this package could fit mixed models instead and
impute weights in a more clever way, accounting also for size, etc!

- `which`: impute `"prey"`, `"pred"`, or `"both"` (default)
- `method`: `"lw_params"` (default) uses the bundled L/W table;
  `"observations"` uses mean sizes from other records of the same
  species
- `size`: impute `"weight"`, `"length"`, or `"both"` (default)
- `fill_if_no_size`: if `TRUE` (default), prey with no recorded size
  borrow from other records of the same species before applying L/W

``` r

dat <- impute_size(dat, which = "both", method = "lw_params", size = "both")
#> impute_size(): which = "both" | method = "lw_params" | size = "both" |
#> fill_if_no_size = TRUE
#> 
#> Prey: 7,985 records | L/W params (unique AphiaIDs): species: 65, family: 39,
#> order: 30, class: 58, phylum: 16, universal (a=0.01, b=3): 46
#> |-- both weight and length recorded: 1,767 (22.1%)
#> |-- one size recorded, other estimated: 6,099 (76.4%)
#> | |-- had length, estimated weight via L/W: 24 (0.3%)
#> | +-- had weight, estimated length via L/W: 6,075 (76.1%)
#> |-- no size recorded, imputed from other records: 115 (1.4%)
#> | |-- same stomach: mean weight -> length via L/W: 8 (0.1%)
#> | |-- same pred-prey pair: mean weight -> length via L/W: 104 (1.3%)
#> | +-- global species mean: mean weight -> length via L/W: 3 (0.0%)
#> +-- no size info in any record of that species: 4 (0.1%) (diet composition
#> only, weight unusable)
#> 
#> Predator: 13,935 rows | L/W params (unique AphiaIDs): species: 22, family: 1
#> |-- weight and length observed: 13,935 (100.0%)
#> +-- weight observed, length missing: 0 (0.0%)
#> 
```

### Step 7: `trim_data()`

Returns only the analysis-ready columns.

``` r

dat <- trim_data(dat)
#> trim_data(): dropped 32 columns:
#>   ship, gear, haul_no, station_number, fish_id, ind_wgt, measurement_increment,
#>   code, maturity_scale, maturity_stage, preservation_method, stomach_fullness,
#>   full_stom_wgt, empty_stom_wgt, stomach_empty, gen_samp, notes, ident_met,
#>   grav_method, prey_sequence, unit_wgt, weight, unit_lngt, other_items,
#>   other_count, predator_rank, predator_phylum, predator_genus, prey_rank,
#>   prey_phylum, prey_genus, ind_weight_est
#> 
```

### Steps 8–9: `sense_check()` and `drop_flagged()`

[`sense_check()`](https://maxlindmark.github.io/stomachr/reference/sense_check.md)
adds a `sense_flag` column marking implausible records.
[`drop_flagged()`](https://maxlindmark.github.io/stomachr/reference/drop_flagged.md)
removes them. You can inspect flagged records before dropping by
examining `tbl_predator_information_id` in the raw data.

``` r

dat <- sense_check(dat)
#> sense_check(): 13,935 rows
#> ! prey longer than predator (same unit assumed): 1 row (0.0%) across 1 predator
#>   tbl_predator_information_id: 110462
#> ! total stomach content heavier than predator: 1 row (0.0%) across 1 predator
#>   tbl_predator_information_id: 110348
#> ℹ 2 rows flagged (0.01%)
#> ℹ Use `drop_flagged()` to remove, or inspect tbl_predator_information_id in raw
#>   data
#> 
dat <- drop_flagged(dat)
#> ✔ drop_flagged(): removed 2 rows (0.01%), 13,933 remaining
#> 
```
