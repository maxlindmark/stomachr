# downloading a small slice of real data should write the four expected CSV files
test_that("download_stomach() smoke test", {
  skip_on_cran()

  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))

  result <- tryCatch(
    download_stomach(path = tmp, year = 2023, country = "DK"),
    error = function(e) e,
    warning = function(w) w
  )
  skip_if(
    inherits(result, c("error", "warning")),
    "download_stomach() unavailable (offline or server issue)"
  )

  expect_true(file.exists(file.path(tmp, "File_information.csv")))
  expect_true(file.exists(file.path(tmp, "HaulInformation.csv")))
  expect_true(file.exists(file.path(tmp, "PredatorInformation.csv")))
  expect_true(file.exists(file.path(tmp, "PreyInformation.csv")))
})
