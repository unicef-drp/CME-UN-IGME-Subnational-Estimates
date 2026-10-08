project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
runner_file <- file.path(
  project_dir, "Rcode", "_supporting_scripts", "pipeline_runner.R"
)
source(runner_file)

stopifnot(
  identical(country_report_display_name("Burkina_Faso"), "Burkina Faso"),
  identical(country_report_display_name("South Africa"), "South Africa"),
  identical(country_report_display_name("Cote_dIvoire"), "Cote d'Ivoire"),
  identical(normalize_report_year(2026L), 2026L),
  identical(normalize_report_year(2027), 2027L),
  identical(normalize_report_year("2028"), 2028L),
  identical(
    country_report_filename("Burkina_Faso", 2026L),
    "Burkina Faso Report 2026.pdf"
  ),
  identical(
    country_report_filename("Cote_dIvoire", "2027"),
    "Cote d'Ivoire Report 2027.pdf"
  )
)

invalid_years <- list(
  NA_integer_, "26", 2026.5, c(2026L, 2027L), "year", 1999L, 3000L
)
for (invalid_year in invalid_years) {
  result <- try(normalize_report_year(invalid_year), silent = TRUE)
  stopifnot(
    inherits(result, "try-error"),
    grepl("four-digit year from 2000 through 2999", as.character(result),
          fixed = TRUE)
  )
}

args <- parse_pipeline_args(
  c("--country", "Cameroon", "--report-year", "2027")
)
stopifnot(identical(args$report_year, 2027L))

args <- parse_pipeline_args(
  c("--country=Benin", "--report-year=2028")
)
stopifnot(identical(args$report_year, 2028L))

default_args <- parse_pipeline_args(character(), country = "Ethiopia")
stopifnot(identical(default_args$report_year, 2026L))

bad_args <- try(
  parse_pipeline_args(c("--country", "Cameroon", "--report-year", "26")),
  silent = TRUE
)
stopifnot(inherits(bad_args, "try-error"))

runner_text <- paste(readLines(runner_file, warn = FALSE), collapse = "\n")
stopifnot(
  grepl(
    "country_report_filename(country, report_year)",
    runner_text,
    fixed = TRUE
  ),
  !grepl(
    'output_summary_pdf <- file.path(output_dir, "11_CountrySummary.pdf")',
    runner_text,
    fixed = TRUE
  ),
  identical(formals(run_country_pipeline)$report_year, quote(2026L))
)

local({
  original_setup <- make_pipeline_setup_steps
  original_steps <- make_pipeline_steps
  original_writer <- write_pipeline_outputs
  on.exit({
    assign("make_pipeline_setup_steps", original_setup, envir = .GlobalEnv)
    assign("make_pipeline_steps", original_steps, envir = .GlobalEnv)
    assign("write_pipeline_outputs", original_writer, envir = .GlobalEnv)
  })

  assign(
    "make_pipeline_setup_steps",
    function(...) list(),
    envir = .GlobalEnv
  )
  assign(
    "make_pipeline_steps",
    function(...) list(),
    envir = .GlobalEnv
  )
  assign(
    "write_pipeline_outputs",
    function(...) invisible(TRUE),
    envir = .GlobalEnv
  )

  pipeline_dir <- tempfile("report_year_pipeline_")
  dir.create(pipeline_dir)
  manifest <- run_country_pipeline(
    country = "Test_Country",
    mode = "production",
    render_summary = FALSE,
    report_year = "2027",
    project_dir = pipeline_dir,
    prompt = function(...) stop("production run should not prompt")
  )
  stopifnot(
    identical(manifest$report_year, 2027L),
    identical(manifest$country, "Test_Country")
  )
})

runbook_file <- file.path(project_dir, "Rcode", "run_country_pipeline.R")
runbook_lines <- readLines(runbook_file, warn = FALSE)
runbook_text <- paste(runbook_lines, collapse = "\n")
runbook_trimmed <- trimws(runbook_lines)
report_year_assignment <- grep(
  "^report_year\\s*<-\\s*2026L$",
  runbook_trimmed
)
runner_source <- grep(
  'source\\(file.path\\("Rcode", "_supporting_scripts", "pipeline_runner.R"\\)\\)',
  runbook_trimmed
)
stopifnot(
  length(report_year_assignment) == 1L,
  length(runner_source) == 1L,
  report_year_assignment < runner_source,
  grepl("report_year = report_year", runbook_text, fixed = TRUE),
  grepl("report_year <- args$report_year", runbook_text, fixed = TRUE),
  grepl("--report-year YEAR", runbook_text, fixed = TRUE),
  sum(grepl(
    "country_report_filename(country, report_year)",
    runbook_lines,
    fixed = TRUE
  )) == 2L,
  !grepl(
    'output_summary_pdf <- file.path(summary_result_dir, "11_CountrySummary.pdf")',
    runbook_text,
    fixed = TRUE
  )
)

refresh_file <- file.path(
  project_dir,
  "Rcode",
  "_script_for_specific_tasks",
  "refresh_dr_congo_crisis_outputs.R"
)
refresh_text <- paste(readLines(refresh_file, warn = FALSE), collapse = "\n")
stopifnot(
  grepl(
    "country_report_filename(country, report_year)",
    refresh_text,
    fixed = TRUE
  ),
  !grepl("11_CountrySummary.pdf", refresh_text, fixed = TRUE),
  !grepl("canonical_pdf", refresh_text, fixed = TRUE)
)

message("country report filename helper tests passed")
