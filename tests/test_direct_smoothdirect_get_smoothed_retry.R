script <- readLines("Rcode/4_Direct_SmoothDirect_sf.R", warn = FALSE)

stopifnot(any(grepl("get_smoothed_with_retry <- function", script, fixed = TRUE)))
stopifnot(any(grepl("retry_inla_step <- function", script, fixed = TRUE)))

retry_calls <- grep("get_smoothed_with_retry\\(", script, value = TRUE)
direct_calls <- grep("<-\\s*getSmoothed\\s*\\(", script, value = TRUE, perl = TRUE)

stopifnot(length(retry_calls) >= 12)
stopifnot(any(grepl("retry_inla_step(\"admin1 period U5MR\"", script, fixed = TRUE)))
stopifnot(any(grepl("retry_inla_step(\"admin1 period NMR\"", script, fixed = TRUE)))
if (length(direct_calls) > 0) {
  stop("Direct getSmoothed() assignment remains:\n", paste(direct_calls, collapse = "\n"))
}

cat("Smoothed-direct result extraction uses retry wrapper for INLA marginal failures.\n")
