project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(project_dir, "Rcode/_supporting_scripts/pipeline_runner.R"))

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  message("Skipping timing workbook test because openxlsx is not installed.")
  quit(status = 0)
}

expected_columns <- c(
  "country", "mode", "run_status", "step_index", "step_id", "label", "script",
  "status", "started_at", "completed_at", "elapsed_minutes", "log_file",
  "reason", "error", "review_label"
)

manifest <- list(
  country = "Cameroon",
  mode = "preview",
  run_status = "failed",
  steps = list(
    list(
      step_index = 1,
      step_id = "one",
      label = "One",
      script = "one.R",
      status = "completed",
      started_at = "2026-07-06T10:00:00+0200",
      completed_at = "2026-07-06T10:01:30+0200",
      elapsed_seconds = 90,
      log_file = "one.log"
    ),
    list(
      step_index = 2,
      step_id = "two",
      label = "Two",
      script = "two.R",
      status = "skipped",
      reason = "already available"
    ),
    list(
      step_index = 3,
      step_id = "three",
      label = "Three",
      script = "three.R",
      status = "failed",
      error = "boom",
      review_label = "Check plots"
    )
  )
)

timing_file <- tempfile(fileext = ".xlsx")
write_pipeline_timing_workbook(manifest, timing_file)
stopifnot(file.exists(timing_file))
timing <- openxlsx::read.xlsx(timing_file, sheet = "step_times")
stopifnot(identical(names(timing), expected_columns))
stopifnot(!"elapsed_seconds" %in% names(timing))
stopifnot(timing$elapsed_minutes[1] == 1.5)
stopifnot(is.na(timing$elapsed_minutes[2]))
stopifnot(timing$reason[2] == "already available")
stopifnot(timing$error[3] == "boom")

empty_file <- tempfile(fileext = ".xlsx")
write_pipeline_timing_workbook(
  list(country = "Cameroon", mode = "preview", run_status = "running", steps = list()),
  empty_file
)
empty <- openxlsx::read.xlsx(empty_file, sheet = "step_times")
stopifnot(identical(names(empty), expected_columns))

runner_text <- paste(readLines(file.path(project_dir, "Rcode/_supporting_scripts/pipeline_runner.R"),
                               warn = FALSE),
                     collapse = "\n")
stopifnot(grepl("pipeline_step_times.xlsx", runner_text, fixed = TRUE))
stopifnot(grepl("write_pipeline_outputs(manifest", runner_text, fixed = TRUE))

message("pipeline timing workbook tests passed")
