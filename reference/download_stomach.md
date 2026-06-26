# Download ICES stomach content data

Downloads the four ICES stomach content CSVs (`File_information.csv`,
`HaulInformation.csv`, `PredatorInformation.csv`, `PreyInformation.csv`)
from stomachdata.ices.dk and writes them to `path`.

## Usage

``` r
download_stomach(
  path = ".",
  year = NULL,
  country = NULL,
  reporting_org = NULL,
  cruise_id = NULL
)
```

## Arguments

- path:

  Directory to write the four CSV files to. Created if it does not
  exist. Defaults to the current working directory.

- year:

  Integer vector of years, e.g. `2000:2010` or `c(2005, 2010)`.

- country:

  Character vector of ISO country codes, e.g. `c("DK", "NO")`.

- reporting_org:

  Character vector of reporting organisation names.

- cruise_id:

  Character vector of cruise IDs to retain.

## Value

`path`, invisibly.

## Details

`year` and `country` are applied server-side (one request per
combination). `reporting_org` and `cruise_id` are applied locally after
download. Omitting all filters downloads the full database in a single
request.

Ecoregion filtering is not supported: the ICES API ignores ecoregion
parameters and the downloaded CSVs contain no ecoregion column. Filter
geographically after
[`join_stomach_data()`](https://maxlindmark.github.io/stomachr/reference/join_stomach_data.md)
using `lat`/`lon` or `ices_rectangle`.
