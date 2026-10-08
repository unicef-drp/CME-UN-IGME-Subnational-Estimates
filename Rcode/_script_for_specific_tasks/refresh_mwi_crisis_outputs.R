project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(project_dir, "Rcode", "_supporting_scripts", "pipeline_runner.R"))

country <- "Malawi"
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
    "FAO/WFP district beneficiary proxy for 2001; within successor districts,",
    "age-specific population only"
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

# Preserve the established Malawi report scope by appending both Admin-1 and
# Admin-2 current sub-area pages. The generic pipeline wrapper defaults to
# Admin-1 only, so this explicit second assembly replaces that shorter output.
step_index <- step_index + 1L
appendix_log <- file.path(
  log_dir,
  sprintf("%02d_country_summary_admin1_admin2.log", step_index)
)
appendix_started_at <- pipeline_time_iso()
appendix_start_time <- proc.time()[["elapsed"]]
appendix_error <- NULL
appendix_result <- tryCatch(
  {
    pipeline_run_with_log({
      comparison_env <- new.env(parent = context)
      sys.source(
        file.path(project_dir, "Rcode", "12_Previous_Final_Comparison.R"),
        envir = comparison_env
      )
      summary_result_dir <- file.path(project_dir, "Results", country)
      core_summary_pdf <- file.path(
        summary_result_dir, "Figures", "Summary", "11_CountrySummary_core.pdf"
      )
      output_summary_pdf <- file.path(
        summary_result_dir,
        country_report_filename(country, report_year)
      )
      previous_final_workbook <- comparison_env$resolve_previous_final_workbook()
      full_appendix <- comparison_env$run_country_summary_comparison_appendix(
        country = country,
        iso3 = get("iso0", envir = context, inherits = TRUE),
        previous_workbook = previous_final_workbook,
        core_summary_pdf = core_summary_pdf,
        output_summary_pdf = output_summary_pdf,
        home_dir = project_dir,
        res_dir = summary_result_dir,
        regions_per_page = 6L,
        strata_model = context$final_model$strata.model,
        benchmarked = identical(context$final_model$bench.model, "bench"),
        all_surveys = identical(context$final_model$strata.model, "unstrat"),
        admin_levels = c("Admin1", "Admin2")
      )
      message(
        "Assembled full current sub-area appendix for: ",
        paste(full_appendix$admin_levels, collapse = ", ")
      )
    }, appendix_log)
    list(
      step_index = step_index,
      step_id = "country_summary_admin1_admin2",
      label = "Append Admin-1 and Admin-2 current sub-area pages",
      script = file.path(
        project_dir,
        "Rcode",
        "_script_for_specific_tasks",
        "refresh_mwi_crisis_outputs.R"
      ),
      status = "completed",
      started_at = appendix_started_at,
      completed_at = pipeline_time_iso(),
      elapsed_seconds = as.numeric(
        proc.time()[["elapsed"]] - appendix_start_time
      ),
      log_file = appendix_log,
      review_label = "Inspect the full Admin-1/Admin-2 report appendix"
    )
  },
  error = function(error) {
    appendix_error <<- conditionMessage(error)
    list(
      step_index = step_index,
      step_id = "country_summary_admin1_admin2",
      label = "Append Admin-1 and Admin-2 current sub-area pages",
      script = file.path(
        project_dir,
        "Rcode",
        "_script_for_specific_tasks",
        "refresh_mwi_crisis_outputs.R"
      ),
      status = "failed",
      started_at = appendix_started_at,
      completed_at = pipeline_time_iso(),
      elapsed_seconds = as.numeric(
        proc.time()[["elapsed"]] - appendix_start_time
      ),
      log_file = appendix_log,
      error = conditionMessage(error),
      review_label = "Inspect the full Admin-1/Admin-2 report appendix"
    )
  }
)
manifest <- append_step_result(manifest, appendix_result)
if (!is.null(appendix_error)) {
  manifest$run_status <- "failed"
  manifest$completed_at <- pipeline_time_iso()
  write_pipeline_outputs(manifest, manifest_file, timing_file)
  stop(appendix_error, call. = FALSE)
}
write_pipeline_outputs(manifest, manifest_file, timing_file)

friendly_pdf <- file.path(
  project_dir,
  "Results",
  country,
  country_report_filename(country, report_year)
)
if (!file.exists(friendly_pdf) || file.info(friendly_pdf)$size <= 0) {
  stop("Final friendly report was not produced: ", friendly_pdf, call. = FALSE)
}

manifest$run_status <- "completed"
manifest$completed_at <- pipeline_time_iso()
manifest$dashboard <- file.path(
  project_dir, "Results", country,
  paste0(country, "_bb8_comparison_dashboard.html")
)
manifest$friendly_pdf <- friendly_pdf
write_pipeline_outputs(manifest, manifest_file, timing_file)

message("Selected Malawi crisis dashboard/report refresh completed.")
message("Manifest: ", manifest_file)

