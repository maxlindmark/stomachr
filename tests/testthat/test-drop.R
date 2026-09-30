toy <- tibble::tibble(
  tbl_predator_information_id = c(1, 2, 3, 4, 5, 6),
  country = "NL",
  number = c(1, 1, 10, 10, 5, NA),
  regurgitated = c(0, 1, 3, 10, 0, NA),
  stomach_empty = c(NA, NA, 2, NA, NA, NA),
  stomach_status = c("food", "food", "food", "food", "empty", "empty")
)

test_that("drop_invalid() subtracts regurgitated stomachs instead of dropping pools", {
  out <- suppressMessages(drop_invalid(toy))

  expect_equal(out$tbl_predator_information_id, c(1, 3, 5, 6))
  expect_equal(out$n_stomachs, c(1, 7, 5, 1))
})

test_that("drop_invalid() derives n_empty from stomach_status and stomach_empty", {
  out <- suppressMessages(drop_invalid(toy))

  expect_equal(out$n_empty, c(0, 2, 5, 1))
})

test_that("drop_invalid(na_regurgitated = 'drop') drops NA records", {
  out <- suppressMessages(drop_invalid(toy, na_regurgitated = "drop"))

  expect_false(6 %in% out$tbl_predator_information_id)
})
