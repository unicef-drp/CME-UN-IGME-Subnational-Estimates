project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
entrypoint <- file.path(project_dir, "Rcode", "run_country_pipeline.R")
text <- paste(readLines(entrypoint, warn = FALSE), collapse = "\n")

stopifnot(grepl(
  'file.path(project_home(), "Results", country, "Figures", "Summary")',
  text,
  fixed = TRUE
))
stopifnot(grepl("NMR plots:", text, fixed = TRUE))
stopifnot(grepl("U5MR plots:", text, fixed = TRUE))

runner_path <- file.path(
  project_dir,
  "Rcode",
  "_supporting_scripts",
  "pipeline_runner.R"
)
runner_text <- paste(readLines(runner_path, warn = FALSE), collapse = "\n")
final_review_label <- paste(
  "Inspect final data, plots, dashboard, and summary PDF;",
  "summarize any issues"
)

stopifnot(grepl("# Step 14: Inspect final data and plots", text, fixed = TRUE))
stopifnot(grepl(final_review_label, text, fixed = TRUE))
stopifnot(grepl(final_review_label, runner_text, fixed = TRUE))

message("pipeline review paths test passed")
