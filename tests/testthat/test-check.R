path <- system.file("extdata", package = "stomachr")
trimmed <- join_example(path) |>
  add_taxonomy() |>
  drop_invalid() |>
  impute_size() |>
  trim_data()

# sense_check() must add a sense_flag column without changing row count -- it flags, drop_flagged() removes
test_that("sense_check() smoke test", {
  out <- sense_check(trimmed)

  expect_s3_class(out, "data.frame")
  expect_true("sense_flag" %in% names(out))
  expect_equal(nrow(out), nrow(trimmed))
})

# dropping flagged rows should remove exactly the flagged ones and none of the rest
test_that("drop_flagged() smoke test", {
  checked <- sense_check(trimmed)
  out <- drop_flagged(checked)

  expect_s3_class(out, "data.frame")
  expect_true(all(is.na(out$sense_flag)))
  expect_lte(nrow(out), nrow(checked))
})

test_that("sense_check() compares pooled stomach weight against n_stomachs fish", {
  toy <- tibble::tibble(
    tbl_predator_information_id = c(1, 2),
    n_stomachs = c(10, 1),
    stomach_status = "food",
    predator_weight = 100,
    prey_weight_all_ind = 150,
    prey_weight_ind = 1,
    prey_length = 1,
    pred_length = 20,
    count_censored = FALSE,
    lat = 55,
    lon = 5
  )

  out <- suppressMessages(sense_check(toy))

  expect_equal(out$sense_flag, c(NA, "stomach_weight"))
})
