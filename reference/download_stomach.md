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
  ecoregion = NULL,
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

- ecoregion:

  Character vector of ICES ecoregions to filter server-side, e.g.
  `"Greater North Sea"`. One or more of `"Baltic Sea"`, `"Celtic Seas"`,
  `"Greater North Sea"`. See <https://stomachdata.ices.dk/inventory>.

- reporting_org:

  Character vector of reporting organisation names.

- cruise_id:

  Character vector of cruise IDs to retain.

## Value

`path`, invisibly.

## Details

`year`, `country`, and `ecoregion` are applied server-side (one request
per combination). `reporting_org` and `cruise_id` are applied locally
after download. Omitting all filters downloads the full database in a
single request.

Filtering by `ecoregion` restricts which records the API returns, but
the downloaded CSVs contain no ecoregion column. For
finer-than-ecoregion filtering, do it geographically after
[`join_stomach_data()`](https://maxlindmark.github.io/stomachr/reference/join_stomach_data.md)
using `lat`/`lon` or `ices_rectangle`.
