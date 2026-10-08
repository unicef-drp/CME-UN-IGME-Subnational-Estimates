source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

expect_error <- function(expr, pattern) {
  message <- tryCatch(
    {
      force(expr)
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )
  stopifnot(!is.na(message), grepl(pattern, message, ignore.case = TRUE))
}

info <- jsonlite::fromJSON(
  file.path("Info", "DR_Congo_general_info.json"),
  simplifyVector = TRUE
)
stopifnot(isTRUE(info$doCrisisAdj))

for (country in c("Guinea", "Haiti", "Liberia", "Sierra_Leone")) {
  country_info <- jsonlite::fromJSON(
    file.path("Info", paste0(country, "_general_info.json")),
    simplifyVector = TRUE
  )
  stopifnot(isTRUE(country_info$doCrisisAdj))
}

myanmar_info <- jsonlite::fromJSON(
  file.path("Info", "Myanmar_general_info.json"),
  simplifyVector = TRUE
)
stopifnot(isTRUE(myanmar_info$doCrisisAdj))

test_dir <- tempfile("crisis-selector-")
dir.create(test_dir)
base_file <- file.path(test_dir, "country_res_adm1_model_bench.rda")
crisis_file <- file.path(test_dir, "country_res_adm1_model_bench_crisis.rda")
invisible(file.create(base_file))

stopifnot(identical(
  select_crisis_result_file(base_file, enabled = FALSE),
  normalizePath(base_file, winslash = "/", mustWork = TRUE)
))
expect_error(
  select_crisis_result_file(base_file, enabled = TRUE),
  "enabled.*does not exist"
)
invisible(file.create(crisis_file))
stopifnot(identical(
  select_crisis_result_file(base_file, enabled = TRUE),
  normalizePath(crisis_file, winslash = "/", mustWork = TRUE)
))

# The comparison dashboard must apply crisis adjustment only to the selected
# final model. Optional comparison models remain on their ordinary result files.
stopifnot(identical(
  select_comparison_u5_result_file(
    base_file,
    candidate_strata_model = "strat",
    candidate_survey_frame = "same_frame",
    final_strata_model = "unstrat",
    enabled = TRUE
  ),
  normalizePath(base_file, winslash = "/", mustWork = TRUE)
))
stopifnot(identical(
  select_comparison_u5_result_file(
    base_file,
    candidate_strata_model = "unstrat",
    candidate_survey_frame = "all_surveys",
    final_strata_model = "unstrat",
    enabled = TRUE
  ),
  normalizePath(crisis_file, winslash = "/", mustWork = TRUE)
))

flag_environment <- new.env(parent = emptyenv())
stopifnot(!crisis_adjustment_enabled(flag_environment))
assign("doCrisisAdj", FALSE, envir = flag_environment)
stopifnot(!crisis_adjustment_enabled(flag_environment))
assign("doCrisisAdj", TRUE, envir = flag_environment)
stopifnot(crisis_adjustment_enabled(flag_environment))
assign("doCrisisAdj", "yes", envir = flag_environment)
expect_error(crisis_adjustment_enabled(flag_environment), "logical")

report_text <- paste(
  readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE),
  collapse = "\n"
)
summary_text <- paste(
  readLines(file.path("Rcode", "11_CountrySummary.Rmd"), warn = FALSE),
  collapse = "\n"
)
dashboard_text <- paste(
  readLines(file.path("Rcode", "9_Comparison_Plot.R"), warn = FALSE),
  collapse = "\n"
)
stopifnot(
  grepl("select_crisis_result_file", report_text, fixed = TRUE),
  grepl("select_crisis_result_file", summary_text, fixed = TRUE),
  grepl("select_crisis_result_file", dashboard_text, fixed = TRUE),
  grepl("strata.model <- final_model$strata.model", dashboard_text,
        fixed = TRUE),
  !grepl("u5.filename.crisis %in% list.files", report_text, fixed = TRUE)
)

comparison_environment <- new.env(parent = globalenv())
sys.source(
  file.path("Rcode", "12_Previous_Final_Comparison.R"),
  envir = comparison_environment
)
assign("doCrisisAdj", TRUE, envir = comparison_environment)
comparison_result_dir <- file.path(test_dir, "Results", "Test_Country")
dir.create(file.path(comparison_result_dir, "Betabinomial", "U5MR"),
           recursive = TRUE)
comparison_base <- file.path(
  comparison_result_dir, "Betabinomial", "U5MR",
  "Test_Country_res_adm1_strat_u5_bench.rda"
)
comparison_crisis <- sub("[.]rda$", "_crisis.rda", comparison_base)
invisible(file.create(comparison_base, comparison_crisis))
stopifnot(identical(
  comparison_environment$current_admin_result_path(
    res_dir = comparison_result_dir,
    country = "Test_Country",
    outcome = "U5MR",
    admin_level = "Admin1",
    strata_model = "strat",
    benchmarked = TRUE,
    all_surveys = FALSE
  ),
  normalizePath(comparison_crisis, winslash = "/", mustWork = TRUE)
))

unlink(test_dir, recursive = TRUE)
message("Crisis-adjustment configuration tests passed.")
