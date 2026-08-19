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
`"empty"`, or `"unidentified"`, deduplicates exact-duplicate prey rows
(present in some national submissions), converts prey length from mm to
cm, handles the count sentinel value (9999 = unknown multiplicity), and
optionally imputes missing coordinates from ICES rectangle midpoints
(defaults to `"food"`).

**Known country-specific unit issues** (currently requires manual
correction before proceeding):

There is no predator length or weight unit in the data (only for prey).
We want cm and grams.

- Belgium (`BE`): `pred_length` is in mm – divide by 10
- Denmark (`DK`): `ind_wgt` is in kg – multiply by 1000

**Known data-quality issue, handled automatically:** some submissions
(seen in Celtic Seas data) have corrupt `ICESrectangle` codes
(e.g. `"46E9"` stored as `"46000000000"`, as if Excel read it as
scientific notation).
[`join_stomach_data()`](https://maxlindmark.github.io/stomachr/reference/join_stomach_data.md)
detects codes that don’t match the real `##L#` format and recomputes
them from `ShootLat`/`ShootLong`. How many rows were affected are
printed by the function.

``` r

dat <- join_stomach_data(path)
#> join_stomach_data(): 9,275 predator individuals
#> ✔ 3,932 (42.4%) with identifiable prey
#> ℹ 4,253 (45.9%) empty or regurgitated
#> ℹ 1,090 (11.8%) with prey records but no prey species ID
#>   (cannot contribute to diet composition but can contribute to total prey
#>   weight)
#> ℹ 0 haul locations imputed from ICES rectangle midpoint
#> 

dat <- dat |>
  dplyr::mutate(
    pred_length = dplyr::if_else(country == "BE", pred_length / 10, pred_length),
    ind_wgt     = dplyr::if_else(country == "DK", ind_wgt * 1000, ind_wgt)
  )
```

### Step 3: `drop_invalid()`

Removes predators with `regurgitated >= 1`. Stomach contents of
regurgitated fish are techically not usable. The `na_regurgitated`
argument controls whether `NA` values are treated as not regurgitated
(`"keep"`, default) or regurgitated (`"drop"`).

``` r

dat <- drop_invalid(dat, na_regurgitated = "keep")
#> drop_invalid(): 9,275 -> 8,988 predators (287 dropped, 3.1%)
#> ℹ regurgitated value >= 1 assumed regurgitated
#> ℹ regurgitated == NA assumed not regurgitated (n = 4,427 kept)
#> ℹ Dropped by country:
#>   country   n percent_of_total
#> 1      BE   7             0.1%
#> 2      DK   7             0.1%
#> 3      NL 114             1.2%
#> 4      SE 159             1.7%
#> 
```

### Step 4: `add_taxonomy()`

Joins scientific names and higher taxonomy (class, order, family,
phylum) for both predators and prey from the internal WoRMS lookup. Prey
with `aphia_id_prey = NA` in non-empty stomachs are labelled `"Unknown"`
so their weight is not silently lost.

``` r

dat <- add_taxonomy(dat)
#> add_taxonomy(): WoRMS names resolved
#> ✔ Predator AphiaIDs: 23 unique, 0 unresolved
#> ✔ Prey AphiaIDs: 252 unique, 0 unresolved
#> 
```

### Step 5: `impute_size()`

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
#> Prey: 8,169 records | L/W params (unique AphiaIDs): species: 64, family: 40,
#> order: 31, class: 57, phylum: 16, universal (a=0.01, b=3): 44
#> |-- both weight and length recorded: 1,871 (22.9%)
#> |-- one size recorded, other estimated: 6,207 (76.0%)
#> | |-- had length, estimated weight via L/W: 21 (0.3%)
#> | +-- had weight, estimated length via L/W: 6,186 (75.7%)
#> |-- no size recorded, imputed from other records: 88 (1.1%)
#> | |-- same stomach: mean weight -> length via L/W: 8 (0.1%)
#> | |-- same pred-prey pair: mean weight -> length via L/W: 77 (0.9%)
#> | +-- global species mean: mean weight -> length via L/W: 3 (0.0%)
#> +-- no size info in any record of that species: 3 (0.0%) (diet composition
#> only, weight unusable)
#> 
#> Predator: 14,562 rows | L/W params (unique AphiaIDs): species: 22, family: 1
#> |-- weight and length observed: 14,562 (100.0%)
#> +-- weight observed, length missing: 0 (0.0%)
#> 
```

### Step 6: `trim_data()`

Returns only the analysis-ready columns.

``` r

dat <- trim_data(dat)
#> trim_data(): dropped 33 columns:
#>   ship, gear, haul_no, station_number, fish_id, ind_wgt, number,
#>   measurement_increment, code, maturity_scale, maturity_stage,
#>   preservation_method, stomach_fullness, full_stom_wgt, empty_stom_wgt,
#>   stomach_empty, gen_samp, notes, ident_met, grav_method, prey_sequence,
#>   unit_wgt, weight, unit_lngt, other_items, other_count, predator_rank,
#>   predator_phylum, predator_genus, prey_rank, prey_phylum, prey_genus,
#>   ind_weight_est
#> 
```

### Steps 7–8: `sense_check()` and `drop_flagged()`

[`sense_check()`](https://maxlindmark.github.io/stomachr/reference/sense_check.md)
adds a `sense_flag` column marking implausible records.
[`drop_flagged()`](https://maxlindmark.github.io/stomachr/reference/drop_flagged.md)
removes them. You can inspect flagged records before dropping by
examining `tbl_predator_information_id` in the raw data.

``` r

dat <- sense_check(dat)
#> sense_check(): 14,562 rows
#> ! total stomach content heavier than predator: 1 row (0.0%) across 1 predator
#>   tbl_predator_information_id: 110348
#> ℹ 1 row flagged (0.01%)
#> ℹ Use `drop_flagged()` to remove, or inspect tbl_predator_information_id in raw
#>   data
#> 
dat <- drop_flagged(dat)
#> ✔ drop_flagged(): removed 1 row (0.01%), 14,561 remaining
#> 
```
