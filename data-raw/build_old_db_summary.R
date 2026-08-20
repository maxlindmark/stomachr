# Aggregates the old (pre-relaunch) ICES stomach database export down to a
# tiny year/country/ecoregion predator-count summary, bundled in
# inst/extdata/ so the "Comparison against the old database" section of the
# database-overview vignette can run anywhere -- not just locally, where the
# 131MB raw export (my-scripts/StomachDataFullOutput.csv, gitignored) lives.
#
# Only the OLD side needs bundling: the new-database side is downloaded live
# in the vignette every time it runs. The old export is a fixed historical
# snapshot that will never change, so this summary never goes stale.
#
# Run once (or again if you get a newer copy of the old export) with:
#   source("data-raw/build_old_db_summary.R")

pkgload::load_all()
library(dplyr)

old_path <- "my-scripts/StomachDataFullOutput.csv"

old <- readr::read_csv(
  old_path,
  col_select = c(ICES_SampleID, year, Country, Latitude, Longitude),
  na = c("NA", "NULL", ""),
  show_col_types = FALSE
)

country_map <- c(
  "Belgium" = "BE", "Germany" = "DE", "Denmark" = "DK", "France" = "FR",
  "United Kingdom" = "GB", "Ireland" = "IE", "Latvia" = "LV",
  "The Netherlands" = "NL", "Norway" = "NO", "Poland" = "PL", "Sweden" = "SE"
)

old_pred <- old |>
  distinct(ICES_SampleID, year, Country, Latitude, Longitude) |>
  mutate(
    country = unname(country_map[Country]),
    ecoregion = case_when(
      Longitude >= 13 ~ "Baltic Sea",
      Longitude >= 9 & Latitude < 56 ~ "Baltic Sea",
      TRUE ~ "Greater North Sea"
    )
  ) |>
  filter(!is.na(country))

old_db_summary <- old_pred |>
  count(ecoregion, year, country, name = "n_old")

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
readr::write_csv(old_db_summary, "inst/extdata/old_database_summary.csv")

cli::cli_inform(c(
  "v" = "inst/extdata/old_database_summary.csv written ({nrow(old_db_summary)} rows, {sum(old_db_summary$n_old)} predators, years {min(old_pred$year)}-{max(old_pred$year)})"
))
