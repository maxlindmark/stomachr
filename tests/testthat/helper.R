known_join_warnings <- c("outliers in predator size", "PreySequence")

join_example <- function(path = system.file("extdata", package = "stomachr")) {
  withCallingHandlers(
    join_stomach_data(path),
    warning = function(w) {
      if (any(vapply(known_join_warnings, grepl, logical(1), conditionMessage(w), fixed = TRUE))) {
        invokeRestart("muffleWarning")
      }
    }
  )
}
