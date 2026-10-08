project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(project_dir, "Rcode", "_supporting_scripts", "pipeline_runner.R"))

country <- "Sudan"
mode <- "production"
report_year <- 2026L
run_id <- Sys.getenv("CRISIS_REFRESH_RUN_ID", unset = format(Sys.time(), "%Y%m%d_%H%M%S"))
log_dir <- file.path(
  project_dir, "Results", country, "logs", run_id
)
manifest_file <- file.path(log_dir, "pipeline_manifest.json")
timing_file <- file.path(log_dir, "pipeline_step_times.xlsx")

old_env <- set_pipeline_env(project_dir, country, mode)
old_wd <- getwd()
on.exit({
  restore_env(old_env)
  setwd(old_wd)
}, add = TRUE)
setwd(project_dir)

context <- new.env(parent = globalenv())
context$project_dir <- project_dir
context$country <- country
context$report_year <- report_year

manifest <- list(
  country = country,
  mode = mode,
  render_summary = TRUE,
  report_year = report_year,
  run_status = "running",
  started_at = pipeline_time_iso(),
  completed_at = NULL,
  log_dir = log_dir,
  manifest_file = manifest_file,
  timing_file = timing_file,
  crisis_method = paste(
    "Darfur-only 2004-2005; within Darfur,",
    "age-specific population only; 2025 uses full-year recorded all-age conflict fatality shares"
  ),
  steps = list()
)
write_pipeline_outputs(manifest, manifest_file, timing_file)

run_and_record <- function(step, step_index) {
  result <- run_pipeline_step(
    step = step,
    step_index = step_index,
    context = context,
    mode = mode,
    log_dir = log_dir,
    prompt = readline
  )
  manifest <<- append_step_result(manifest, result)
  if (identical(result$status, "failed")) {
    manifest$run_status <<- "failed"
    manifest$completed_at <<- pipeline_time_iso()
    write_pipeline_outputs(manifest, manifest_file, timing_file)
    stop(
      "Refresh failed at step '", step$id, "': ", result$error,
      call. = FALSE
    )
  }
  write_pipeline_outputs(manifest, manifest_file, timing_file)
  invisible(result)
}

step_index <- 1L
run_and_record(make_pipeline_setup_steps(country, project_dir)[[1]], step_index)

step_index <- step_index + 1L
run_and_record(pipeline_step(
  "crisis_adjustment", "Prepare and apply Sudan 2004-2005 and 2025 crisis adjustments",
  file.path(project_dir, "Rcode", "_supporting_scripts", "refresh_country_crisis_adjustment.R"),
  kind = "source_main"
), step_index)

all_steps <- make_pipeline_steps(
  country = country,
  info = context,
  project_dir = project_dir,
  render_summary = TRUE
)
selected_ids <- c("bb8_comparison", "diagnostics", "report_plots", "country_summary")
selected_steps <- all_steps[vapply(
  all_steps,
  function(step) step$id %in% selected_ids,
  logical(1)
)]
selected_steps <- selected_steps[match(
  selected_ids,
  vapply(selected_steps, function(step) step$id, character(1))
)]

for (step in selected_steps) {
  step_index <- step_index + 1L
  run_and_record(step, step_index)
}

friendly_pdf <- file.path(
  project_dir,
  "Results",
  country,
  country_report_filename(country, report_year)
)
# The summary assembler uses this fallback when the standard PDF is open.
report_candidates <- c(friendly_pdf, sub('[.]pdf$', '_with_comparison.pdf', friendly_pdf))
report_candidates <- report_candidates[file.exists(report_candidates)]
if (length(report_candidates)) {
  friendly_pdf <- report_candidates[which.max(as.numeric(file.info(report_candidates)$mtime))]
}
if (!file.exists(friendly_pdf) || file.info(friendly_pdf)$size <= 0) {
  stop("Final friendly report was not produced: ", friendly_pdf, call. = FALSE)
}

manifest$run_status <- "completed_with_scenario_assumptions"
manifest$authoritative_national_input <- "Data/Crisis_Adjustment/Crisis_Under5_deaths_2026.xlsx"
manifest$recent_war_adjustment_years <- 2025L
manifest$intentionally_unadjusted_recent_years <- 2023:2024
manifest$publication_blockers <- character(0)
manifest$scenario_assumptions <- c("2025 uses UK Home Office section 13.3.5 tabulation of ACLED all-age recorded direct-conflict fatalities as geographic weights; these are not child mortality measurements and do not describe indirect deaths.", "Historical Darfur-only allocation is an approved scenario; exact historical direct/indirect source attribution remains unverified.", "Model intervals do not include additional crisis-death or geographic-allocation uncertainty.")
manifest$completed_at <- pipeline_time_iso()
manifest$dashboard <- file.path(
  project_dir, "Results", country,
  paste0(country, "_bb8_comparison_dashboard.html")
)
manifest$friendly_pdf <- friendly_pdf
write_pipeline_outputs(manifest, manifest_file, timing_file)

message("Selected Sudan crisis dashboard/report refresh completed.")
message("Manifest: ", manifest_file)
