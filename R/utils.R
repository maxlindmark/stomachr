# Format a count with thousands separators for display in cli messages.
fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
