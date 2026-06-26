# Saves North Sea raw CSVs (2020-2024, Greater North Sea coordinates) to
# inst/extdata/ so the vignette can run the pipeline on them with eval=TRUE.
#
# Run once with: source("data-raw/build_example_data.R")

pkgload::load_all()
library(dplyr)

tmp <- tempfile()
download_stomach(path = tmp, year = 2020:2024)

fi   <- readr::read_csv(file.path(tmp, "File_information.csv"),    show_col_types = FALSE)
hi   <- readr::read_csv(file.path(tmp, "HaulInformation.csv"),     show_col_types = FALSE)
pred <- readr::read_csv(file.path(tmp, "PredatorInformation.csv"), show_col_types = FALSE)
prey <- readr::read_csv(file.path(tmp, "PreyInformation.csv"),     show_col_types = FALSE)

# Filter hauls to Greater North Sea
hi_ns <- hi |> filter(
  !is.na(ShootLat), !is.na(ShootLong),
  ShootLat >= 51, ShootLat <= 62,
  ShootLong >= -4, ShootLong <= 13
)

pred_ns <- pred |> filter(tblHaulID %in% hi_ns$tblHaulID)
prey_ns <- prey |> filter(tblPredatorInformationID %in% pred_ns$tblPredatorInformationID)
fi_ns   <- fi   |> filter(tblUploadID %in% hi_ns$tblUploadID)

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
readr::write_csv(fi_ns,   "inst/extdata/File_information.csv")
readr::write_csv(hi_ns,   "inst/extdata/HaulInformation.csv")
readr::write_csv(pred_ns, "inst/extdata/PredatorInformation.csv")
readr::write_csv(prey_ns, "inst/extdata/PreyInformation.csv")

cli::cli_inform(c(
  "v" = "inst/extdata/ written ({nrow(pred_ns)} predators, Greater North Sea 2020-2024)"
))
