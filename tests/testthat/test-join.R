path <- system.file("extdata", package = "stomachr")
dat <- join_stomach_data(path)

# reading and joining the four raw CSVs should produce one sensible predator/prey table
test_that("join_stomach_data() smoke test", {
  expect_s3_class(dat, "data.frame")
  expect_gt(nrow(dat), 0)
  expect_true(all(c(
    "tbl_predator_information_id", "aphia_id_predator", "pred_length",
    "stomach_status", "lat", "lon", "country"
  ) %in% names(dat)))
})
