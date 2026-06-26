#' Download ICES stomach content data
#'
#' Downloads the four ICES stomach content CSVs
#' (`File_information.csv`, `HaulInformation.csv`, `PredatorInformation.csv`,
#' `PreyInformation.csv`) from stomachdata.ices.dk and writes them to `path`.
#'
#' `year` and `country` are applied server-side (one request per combination).
#' `reporting_org` and `cruise_id` are applied locally after download.
#' Omitting all filters downloads the full database in a single request.
#'
#' Ecoregion filtering is not supported: the ICES API ignores ecoregion
#' parameters and the downloaded CSVs contain no ecoregion column. Filter
#' geographically after [join_stomach_data()] using `lat`/`lon` or
#' `ices_rectangle`.
#'
#' @param path Directory to write the four CSV files to. Created if it does
#'   not exist. Defaults to the current working directory.
#' @param year Integer vector of years, e.g. `2000:2010` or `c(2005, 2010)`.
#' @param country Character vector of ISO country codes, e.g. `c("DK", "NO")`.
#' @param reporting_org Character vector of reporting organisation names.
#' @param cruise_id Character vector of cruise IDs to retain.
#'
#' @return `path`, invisibly.
#' @export
download_stomach <- function(path = ".",
                             year = NULL,
                             country = NULL,
                             reporting_org = NULL,
                             cruise_id = NULL) {
  base_url <- "https://stomachdata.ices.dk/api/download"

  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  years <- if (is.null(year)) list(NULL) else as.list(as.character(year))
  countries <- if (is.null(country)) list(NULL) else as.list(country)
  combos <- expand.grid(yr = seq_along(years), co = seq_along(countries))

  fetch <- function(yr, co) {
    params <- c(
      if (!is.null(yr)) paste0("Year=", yr),
      if (!is.null(co)) paste0("Country=", co)
    )
    url <- if (length(params)) paste0(base_url, "?", paste(params, collapse = "&")) else base_url
    label <- paste(c(yr, co), collapse = " / ")
    if (!nchar(label)) label <- "all data"
    cli::cli_inform("Downloading {label} ...")

    tmp_zip <- tempfile(fileext = ".zip")
    tmp_dir <- tempfile()
    dir.create(tmp_dir)
    on.exit(unlink(c(tmp_zip, tmp_dir), recursive = TRUE))

    ok <- tryCatch(
      {
        utils::download.file(url, tmp_zip, mode = "wb", quiet = TRUE)
        TRUE
      },
      error = function(e) {
        cli::cli_warn(c("!" = "Skipping {label}: server error.", "i" = "URL: {.url {url}}"))
        FALSE
      }
    )
    if (!ok) {
      return(NULL)
    }

    utils::unzip(tmp_zip, exdir = tmp_dir)

    find_csv <- function(pattern) {
      list.files(tmp_dir, pattern, recursive = TRUE, full.names = TRUE)[1]
    }

    fi_path <- find_csv("File_information.csv")
    if (is.na(fi_path)) {
      cli::cli_warn("Skipping {label}: expected CSVs not found in ZIP.")
      return(NULL)
    }

    read_safe <- function(path) {
      df <- readr::read_csv(path, show_col_types = FALSE)
      dplyr::mutate(df, dplyr::across(dplyr::everything(), as.character))
    }
    batch <- list(
      fi   = read_safe(fi_path),
      hi   = read_safe(find_csv("HaulInformation.csv")),
      pred = read_safe(find_csv("PredatorInformation.csv")),
      prey = read_safe(find_csv("PreyInformation.csv"))
    )
    if (nrow(batch$pred) == 0) return(NULL)
    batch
  }

  batches <- purrr::compact(purrr::map2(
    years[combos$yr], countries[combos$co],
    fetch
  ))

  if (!length(batches)) {
    cli::cli_abort(c(
      "No data downloaded.",
      "i" = "Check that the year/country combination exists in the database.",
      "i" = "Available years: 1964-1999, 2001-2009, 2012-2025."
    ))
  }

  fi   <- readr::type_convert(dplyr::bind_rows(lapply(batches, `[[`, "fi")),   col_types = readr::cols())
  hi   <- readr::type_convert(dplyr::bind_rows(lapply(batches, `[[`, "hi")),   col_types = readr::cols())
  pred <- readr::type_convert(dplyr::bind_rows(lapply(batches, `[[`, "pred")), col_types = readr::cols())
  prey <- readr::type_convert(dplyr::bind_rows(lapply(batches, `[[`, "prey")), col_types = readr::cols())

  if (!is.null(reporting_org)) fi <- fi[fi$Reporting_organisation %in% reporting_org, ]
  if (!is.null(cruise_id)) fi <- fi[fi$CruiseID %in% cruise_id, ]

  keep_uploads <- intersect(fi$tblUploadID, hi$tblUploadID)
  fi <- dplyr::distinct(fi[fi$tblUploadID %in% keep_uploads, ])
  hi <- dplyr::distinct(hi[hi$tblUploadID %in% keep_uploads, ])
  pred <- dplyr::distinct(pred[pred$tblUploadID %in% keep_uploads, ])
  prey <- dplyr::distinct(prey[prey$tblPredatorInformationID %in% pred$tblPredatorInformationID, ])

  csv_names <- c(
    "File_information.csv", "HaulInformation.csv",
    "PredatorInformation.csv", "PreyInformation.csv"
  )
  purrr::walk2(
    list(fi, hi, pred, prey), csv_names,
    ~ readr::write_csv(.x, file.path(path, .y))
  )

  cli::cli_inform(c("v" = "4 files written to {.path {path}}"))
  invisible(path)
}
