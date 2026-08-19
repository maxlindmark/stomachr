# Saves North Sea raw CSVs (2020-2024, Greater North Sea ecoregion) to
# inst/extdata/ so the vignette can run the pipeline on them with eval=TRUE.
#
# Run once with: source("data-raw/build_example_data.R")

pkgload::load_all()

tmp <- tempfile()
download_stomach(path = tmp, year = 2020:2024, ecoregion = "Greater North Sea")

fi   <- readr::read_csv(file.path(tmp, "File_information.csv"),    show_col_types = FALSE)
hi   <- readr::read_csv(file.path(tmp, "HaulInformation.csv"),     show_col_types = FALSE)
pred <- readr::read_csv(file.path(tmp, "PredatorInformation.csv"), show_col_types = FALSE)
prey <- readr::read_csv(file.path(tmp, "PreyInformation.csv"),     show_col_types = FALSE)

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
readr::write_csv(fi,   "inst/extdata/File_information.csv")
readr::write_csv(hi,   "inst/extdata/HaulInformation.csv")
readr::write_csv(pred, "inst/extdata/PredatorInformation.csv")
readr::write_csv(prey, "inst/extdata/PreyInformation.csv")

cli::cli_inform(c(
  "v" = "inst/extdata/ written ({nrow(pred)} predators, Greater North Sea ecoregion, 2020-2024)"
))
