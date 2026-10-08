project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(project_dir, "Rcode/_supporting_scripts/pipeline_runner.R"))

setup_steps <- make_pipeline_setup_steps("Cameroon", project_dir)
stopifnot(identical(
  vapply(setup_steps, `[[`, character(1), "id"),
  "preparation"
))
stopifnot(identical(basename(setup_steps[[1]]$script), "1_Preperation.R"))

args <- parse_pipeline_args(c("--country", "Cameroon", "--mode", "production", "--skip-summary"))
stopifnot(args$country == "Cameroon")
stopifnot(args$mode == "production")
stopifnot(identical(args$render_summary, FALSE))

args <- parse_pipeline_args(c("--country=Benin", "--preview"))
stopifnot(args$country == "Benin")
stopifnot(args$mode == "preview")

args <- parse_pipeline_args(character(), country = "Ethiopia")
stopifnot(args$country == "Ethiopia")

missing_country <- try(parse_pipeline_args(character()), silent = TRUE)
stopifnot(inherits(missing_country, "try-error"))
stopifnot(!grepl("default_country", as.character(missing_country), fixed = TRUE))

bad_mode <- try(parse_pipeline_args(c("--mode", "maybe")), silent = TRUE)
stopifnot(inherits(bad_mode, "try-error"))

stopifnot(isTRUE(pipeline_checkpoint("no prompt", mode = "production", prompt = function(...) {
  stop("production mode should not prompt")
})))
stopifnot(isFALSE(pipeline_checkpoint("review", mode = "preview", prompt = function(...) "n")))

info <- new.env(parent = emptyenv())
info$frame_year <- 2005
info$country <- "Cameroon"
info$strata_weight_source <- "survey"
steps <- make_pipeline_steps("Cameroon", info, project_dir, render_summary = FALSE)
step_ids <- vapply(steps, function(step) step$id, character(1))
stopifnot(!"ur_prop" %in% step_ids)
stopifnot(!"ur_thresholding" %in% step_ids)
final_step <- steps[[length(steps)]]
stopifnot(
  identical(final_step$id, "report_plots"),
  isTRUE(final_step$review),
  identical(
    final_step$review_label,
    paste(
      "Inspect final data, plots, dashboard, and summary PDF;",
      "summarize any issues"
    )
  )
)
admin_weights_step <- steps[[match("admin_weights", step_ids)]]
stopifnot(length(admin_weights_step$env) == 0)

pipeline_files <- c(
  file.path(project_dir, "Rcode", "run_country_pipeline.R"),
  file.path(project_dir, "Rcode", "_supporting_scripts", "pipeline_runner.R")
)
pipeline_text <- paste(
  unlist(lapply(pipeline_files, readLines, warn = FALSE)),
  collapse = "\n"
)
stopifnot(!grepl("ADMIN_WEIGHTS_SKIP_100M_COMPARISON", pipeline_text, fixed = TRUE))

info$strata_weight_source <- "frame"
steps <- make_pipeline_steps("Cameroon", info, project_dir, render_summary = FALSE)
step_ids <- vapply(steps, function(step) step$id, character(1))
stopifnot("ur_prop" %in% step_ids)
stopifnot("ur_thresholding" %in% step_ids)

context <- new.env(parent = baseenv())
context$country <- "Unitland"
script <- tempfile(fileext = ".R")
writeLines(c(
  "stopifnot(country == 'Unitland')",
  "leaked_from_step <- TRUE"
), script)
step <- pipeline_step("ordinary", "Ordinary source", script)
result <- run_pipeline_step(step, 1, context, "production", tempdir())
stopifnot(result$status == "completed")
stopifnot(!exists("leaked_from_step", envir = context, inherits = FALSE))

env_script <- tempfile(fileext = ".R")
writeLines("stopifnot(Sys.getenv('PIPELINE_TEST_ENV') == 'temporary')", env_script)
Sys.setenv(PIPELINE_TEST_ENV = "original")
env_step <- pipeline_step(
  "env_restore",
  "Environment restore",
  env_script,
  env = c(PIPELINE_TEST_ENV = "temporary")
)
result <- run_pipeline_step(env_step, 1, context, "production", tempdir())
stopifnot(result$status == "completed")
stopifnot(Sys.getenv("PIPELINE_TEST_ENV") == "original")
Sys.unsetenv("PIPELINE_TEST_ENV")

main_script <- tempfile(fileext = ".R")
main_flag <- normalizePath(tempfile(), winslash = "/", mustWork = FALSE)
writeLines(c(
  "main <- function() {",
  sprintf("  writeLines('yes', %s)", deparse(main_flag)),
  "}"
), main_script)
main_step <- pipeline_step("main", "Main source", main_script, kind = "source_main")
result <- run_pipeline_step(main_step, 1, context, "production", tempdir())
stopifnot(result$status == "completed")
stopifnot(file.exists(main_flag))
stopifnot(identical(readLines(main_flag, warn = FALSE), "yes"))

review_step <- pipeline_step("review", "Review plots", script, review = TRUE)
result <- run_pipeline_step(review_step, 1, context, "preview", tempdir(), prompt = function(...) "n")
stopifnot(result$status == "review_pending")

boundary_dir <- tempfile()
dir.create(boundary_dir)
boundary_context <- new.env(parent = baseenv())
boundary_context$poly.path <- boundary_dir
boundary_context$poly.layer.adm0 <- "adm0"
boundary_context$poly.layer.adm1 <- "adm1"
boundary_context$poly.layer.adm2 <- "adm2"
invisible(file.create(file.path(boundary_dir, c("adm0.shp", "adm1.shp"))))
stopifnot(!georepo_boundaries_available(boundary_context))
invisible(file.create(file.path(boundary_dir, "adm2.shp")))
stopifnot(georepo_boundaries_available(boundary_context))

manifest <- list(
  country = "Quote\"Country",
  mode = "preview",
  run_status = "running",
  steps = list()
)
manifest_file <- tempfile(fileext = ".json")
write_pipeline_manifest(manifest, manifest_file)
manifest_text <- paste(readLines(manifest_file, warn = FALSE), collapse = "\n")
stopifnot(grepl('Quote\\\\"Country', manifest_text))

message("pipeline runner tests passed")
