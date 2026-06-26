# Saves North Sea raw CSVs (2015-2025) to inst/extdata/ so the vignette
# can run the pipeline on them with eval=TRUE.
#
# Run once with: source("data-raw/build_example_data.R")

pkgload::load_all()

tmp <- tempfile()
download_stomach(path = tmp, year = 2015:2024)

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
for (f in c(
  "File_information.csv", "HaulInformation.csv",
  "PredatorInformation.csv", "PreyInformation.csv"
)) {
  file.copy(file.path(tmp, f), file.path("inst/extdata", f), overwrite = TRUE)
}

cli::cli_inform(c("v" = "inst/extdata/ written with 4 raw North Sea CSVs"))
