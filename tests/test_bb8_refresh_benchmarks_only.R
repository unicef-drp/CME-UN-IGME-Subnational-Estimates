bb8_file <- file.path("Rcode", "8_10_BB8.R")
text <- paste(readLines(bb8_file, warn = FALSE), collapse = "\n")

required <- c(
  'Sys.getenv("BB8_REFRESH_BENCHMARKS_ONLY", "0")',
  "if (bb8_refresh_benchmarks_only)",
  "bb8_skip_same_frame_main <- TRUE",
  "bb8_resume_allsurvey_benchmarks <- TRUE",
  "if (!bb8_final_admin2_only && !bb8_refresh_benchmarks_only)"
)
missing <- required[!vapply(required, grepl, logical(1), x = text, fixed = TRUE)]
if (length(missing)) {
  stop(
    "Step 8 is missing benchmark-refresh controls: ",
    paste(missing, collapse = ", ")
  )
}

condition_count <- lengths(regmatches(
  text,
  gregexpr(
    "bb8_refresh_benchmarks_only \\|\\|[[:space:]]*!bb8_resume_allsurvey_benchmarks",
    text,
    perl = TRUE
  )
))
stopifnot(condition_count >= 4L)

stopifnot(lengths(regmatches(
  text,
  gregexpr(
    "Benchmark-only refresh requires saved unbenchmarked",
    text,
    fixed = TRUE
  )
)) >= 2L)

message("BB8 benchmark-only refresh controls are present")
