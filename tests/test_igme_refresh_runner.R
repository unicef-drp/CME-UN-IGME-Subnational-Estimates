project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(
  project_dir, "Rcode", "_supporting_scripts", "pipeline_runner.R"
))
source(file.path(
  project_dir, "Rcode", "_supporting_scripts", "igme_refresh_runner.R"
))

args <- parse_igme_refresh_args(c("--country", "Cameroon"))
stopifnot(
  identical(args$country, "Cameroon"),
  identical(args$mode, "preview"),
  identical(args$report_year, 2026L),
  isTRUE(args$render_summary),
  isFALSE(args$help)
)

args <- parse_igme_refresh_args(c(
  "--country=Burkina_Faso", "--production", "--report-year=2027",
  "--skip-summary"
))
stopifnot(
  identical(args$country, "Burkina_Faso"),
  identical(args$mode, "production"),
  identical(args$report_year, 2027L),
  isFALSE(args$render_summary)
)

stopifnot(inherits(
  try(parse_igme_refresh_args(character()), silent = TRUE),
  "try-error"
))
stopifnot(inherits(
  try(parse_igme_refresh_args(c("--country", "Cameroon", "--wat")),
      silent = TRUE),
  "try-error"
))

steps <- make_igme_refresh_steps(project_dir, render_summary = TRUE)
stopifnot(identical(
  vapply(steps, `[[`, character(1), "id"),
  c(
    "bb8_refresh", "bb8_comparison", "diagnostics", "report_plots",
    "country_summary"
  )
))
stopifnot(
  identical(steps[[2]]$env[["BB8_ADMIN1_ONLY"]], "0"),
  identical(steps[[3]]$env[["BB8_ADMIN1_ONLY"]], "0"),
  identical(steps[[4]]$env[["BB8_ADMIN1_ONLY"]], "0"),
  identical(steps[[5]]$env[["BB8_ADMIN1_ONLY"]], "0"),
  identical(steps[[5]]$env[["RSTUDIO_PANDOC"]], "")
)
stopifnot(identical(
  unname(steps[[1]]$env),
  c("0", "0", "1", "0", "0", "0", "0", "1", "1", "0", "1")
))
stopifnot(identical(
  names(steps[[1]]$env),
  c(
    "BB8_ADMIN1_ONLY",
    "BB8_SKIP_SAME_FRAME_NMR",
    "BB8_SKIP_SAME_FRAME_MAIN",
    "BB8_RESUME_ALL_SURVEYS",
    "BB8_REPAIR_ADMIN2_STRAT_U5_ONLY",
    "BB8_RESUME_STRAT_ADMIN2_U5",
    "BB8_RESUME_ALLSURVEY_ADMIN2_U5",
    "BB8_REFRESH_BENCHMARKS_ONLY",
    "BB8_RESUME_ALLSURVEY_BENCHMARKS",
    "BB8_FINAL_ADMIN2_ONLY",
    "BB8_REFRESH_SELECTED_ONLY"
  )
))
old_inherited_flag <- Sys.getenv("BB8_FINAL_ADMIN2_ONLY", unset = NA_character_)
Sys.setenv(BB8_FINAL_ADMIN2_ONLY = "1")
with_step_env(steps[[1]]$env, {
  stopifnot(
    identical(Sys.getenv("BB8_FINAL_ADMIN2_ONLY"), "0"),
    identical(Sys.getenv("BB8_ADMIN1_ONLY"), "0"),
    identical(Sys.getenv("BB8_REFRESH_BENCHMARKS_ONLY"), "1")
  )
})
if (is.na(old_inherited_flag)) {
  Sys.unsetenv("BB8_FINAL_ADMIN2_ONLY")
} else {
  Sys.setenv(BB8_FINAL_ADMIN2_ONLY = old_inherited_flag)
}
old_pandoc_env <- Sys.getenv("RSTUDIO_PANDOC", unset = NA_character_)
Sys.setenv(RSTUDIO_PANDOC = "sentinel-pandoc")
with_step_env(steps[[5]]$env, {
  stopifnot(identical(Sys.getenv("RSTUDIO_PANDOC"), ""))
})
stopifnot(identical(Sys.getenv("RSTUDIO_PANDOC"), "sentinel-pandoc"))
if (is.na(old_pandoc_env)) {
  Sys.unsetenv("RSTUDIO_PANDOC")
} else {
  Sys.setenv(RSTUDIO_PANDOC = old_pandoc_env)
}

contract <- igme_refresh_benchmark_contract(
  project_dir,
  "Cameroon",
  has_admin2 = TRUE
)
stopifnot(
  nrow(contract) == 8L,
  identical(sort(unique(contract$level)), c("adm1", "adm2")),
  identical(sort(unique(contract$outcome)), c("nmr", "u5")),
  all(grepl("_bench[.]rda$", contract$output_path)),
  !any(grepl("_bench[.]rda$", contract$base_path))
)
stopifnot(nrow(igme_refresh_benchmark_contract(
  project_dir,
  "Admin1_Only",
  has_admin2 = FALSE
)) == 4L)

niger_info <- load_igme_refresh_info(project_dir, "Niger")
stopifnot(isFALSE(igme_refresh_has_admin2(niger_info$values)))

crisis_steps <- make_igme_refresh_steps(
  project_dir,
  render_summary = TRUE,
  crisis_adjustment = TRUE
)
stopifnot(identical(
  vapply(crisis_steps, `[[`, character(1), "id"),
  c(
    "bb8_refresh", "crisis_adjustment", "bb8_comparison", "diagnostics",
    "report_plots", "country_summary"
  )
))
stopifnot(
  identical(crisis_steps[[2]]$kind, "source_main"),
  grepl(
    "refresh_country_crisis_adjustment.R$",
    crisis_steps[[2]]$script
  )
)
haiti_crisis_preflight <- igme_refresh_crisis_preflight(project_dir, "Haiti")
guinea_crisis_preflight <- igme_refresh_crisis_preflight(project_dir, "Guinea")
stopifnot(
  !any(grepl("crisis_HTI[.]rda$", haiti_crisis_preflight$inputs)),
  any(grepl("crisis_GIN[.]rda$", guinea_crisis_preflight$inputs)),
  inherits(
    try(igme_refresh_crisis_preflight(project_dir, "Unsupported"),
        silent = TRUE),
    "try-error"
  )
)

crisis_runner <- file.path(
  project_dir,
  "Rcode",
  "_supporting_scripts",
  "refresh_country_crisis_adjustment.R"
)
stopifnot(file.exists(crisis_runner))

crisis_dispatch_fixture <- tempfile("crisis_dispatch_")
dir.create(
  file.path(crisis_dispatch_fixture, "Data", "Crisis_Adjustment"),
  recursive = TRUE
)
writeLines(
  c(
    "apply_four_country_crisis_adjustments <- function(",
    "    project_root, write_output, overwrite, countries) {",
    "  stopifnot(isTRUE(write_output), isTRUE(overwrite))",
    "  writeLines(countries, file.path(project_root, 'crisis_called.txt'))",
    "}"
  ),
  file.path(
    crisis_dispatch_fixture,
    "Data",
    "Crisis_Adjustment",
    "apply_four_country_crisis_adjustments.R"
  )
)
crisis_context <- new.env(parent = globalenv())
crisis_context$project_dir <- crisis_dispatch_fixture
crisis_context$country <- "Haiti"
source_pipeline_script(
  pipeline_step(
    "crisis_adjustment",
    "Test country-scoped crisis dispatch",
    crisis_runner,
    kind = "source_main"
  ),
  crisis_context
)
stopifnot(identical(
  readLines(file.path(crisis_dispatch_fixture, "crisis_called.txt")),
  "Haiti"
))

source(crisis_runner, local = FALSE)
stopifnot(
  identical(country_crisis_adjustment_family("DR_Congo"), "cod"),
  identical(country_crisis_adjustment_family("Myanmar"), "myanmar"),
  identical(country_crisis_adjustment_family("Guinea"), "four_country"),
  identical(country_crisis_adjustment_family("Haiti"), "four_country"),
  identical(country_crisis_adjustment_family("Liberia"), "four_country"),
  identical(
    country_crisis_adjustment_family("Sierra_Leone"),
    "four_country"
  ),
  inherits(
    try(country_crisis_adjustment_family("Unsupported"), silent = TRUE),
    "try-error"
  )
)

write_release <- function(dir, suffix = "", mtime = Sys.time()) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  years <- c("X2000.5", "X2001.5")
  for (name in igme_release_names()) {
    indicator <- if (grepl("nmr", name, fixed = TRUE)) {
      "Neonatal Mortality Rate"
    } else {
      "Under-five Mortality Rate"
    }
    dat <- data.frame(
      Country.Name = rep("Cameroon", 3),
      ISO.Code = rep("CMR", 3),
      Quantile = c("Lower", "Median", "Upper"),
      Indicator = rep(indicator, 3),
      Subgroup = rep("Total", 3),
      Note1 = "",
      Note2 = "",
      Note3 = "",
      Note4 = "",
      check.names = FALSE
    )
    dat[[years[[1]]]] <- c(10, 20, 30) + nchar(suffix)
    dat[[years[[2]]]] <- c(9, 19, 29) + nchar(suffix)
    path <- file.path(dir, name)
    write.csv(dat, path, row.names = FALSE, na = "")
    Sys.setFileTime(path, mtime)
  }
  invisible(dir)
}

fixture <- tempfile("igme_refresh_")
active <- file.path(fixture, "active")
staged <- file.path(fixture, "staged")
old_time <- as.POSIXct("2026-09-01 12:00:00", tz = "UTC")
new_time <- as.POSIXct("2026-09-02 12:00:00", tz = "UTC")
write_release(active, mtime = old_time)
write_release(staged, mtime = old_time)

validation <- validate_igme_release(active, "CMR", 2000:2001)
stopifnot(
  length(validation$files) == 4L,
  all(vapply(validation$files, `[[`, logical(1), "readable"))
)
stopifnot(identical(
  classify_staged_igme_release(active, staged)$status,
  "identical"
))

write_release(staged, suffix = "new", mtime = new_time)
stopifnot(identical(
  classify_staged_igme_release(active, staged)$status,
  "promote"
))

write_release(active, suffix = "newer", mtime = new_time + 3600)
stopifnot(identical(
  classify_staged_igme_release(active, staged)$status,
  "ignore"
))

write_release(active, suffix = "baseline", mtime = old_time)
write_release(staged, suffix = "new", mtime = new_time)
Sys.setFileTime(
  file.path(staged, igme_release_names()[[1]]),
  old_time - 3600
)
stopifnot(inherits(
  try(classify_staged_igme_release(active, staged), silent = TRUE),
  "try-error"
))

backup_root <- file.path(fixture, "backup")
source_root <- file.path(fixture, "source")
dir.create(file.path(source_root, "nested"), recursive = TRUE)
source_file <- file.path(source_root, "nested", "artifact.txt")
writeLines("artifact", source_file)
backup <- copy_verified_backup(source_file, source_root, backup_root)
stopifnot(
  file.exists(backup$backup_path),
  identical(backup$source_sha256, backup$backup_sha256),
  identical(
    normalizePath(backup$backup_path, winslash = "/"),
    normalizePath(
      file.path(backup_root, "nested", "artifact.txt"),
      winslash = "/"
    )
  )
)

outside <- tempfile("outside_")
writeLines("outside", outside)
stopifnot(inherits(
  try(copy_verified_backup(outside, source_root, backup_root), silent = TRUE),
  "try-error"
))

target_project <- file.path(fixture, "target_project")
target_result <- file.path(target_project, "Results", "Cameroon")
dir.create(
  file.path(target_result, "Betabinomial", "NMR"),
  recursive = TRUE
)
dir.create(file.path(target_result, "Figures", "Summary"), recursive = TRUE)
dir.create(file.path(target_result, "Figures", "Trends"), recursive = TRUE)
dir.create(
  file.path(target_result, "Figures", "CurrentSubarea"),
  recursive = TRUE
)
dir.create(
  file.path(target_result, "Figures", "PreviousFinalComparison"),
  recursive = TRUE
)
target_files <- c(
  file.path(
    target_result, "Betabinomial", "NMR",
    "Cameroon_res_adm1_unstrat_nmr_allsurveys_bench.rda"
  ),
  file.path(
    target_result, "Betabinomial", "NMR",
    "Cameroon_res_adm1_unstrat_nmr_allsurveys.rda"
  ),
  file.path(target_result, "Figures", "Summary", "summary.pdf"),
  file.path(target_result, "Figures", "Trends", "trend.pdf"),
  file.path(target_result, "Figures", "CurrentSubarea", "current.pdf"),
  file.path(
    target_result,
    "Figures",
    "PreviousFinalComparison",
    "previous.pdf"
  ),
  file.path(target_result, "Cameroon_bb8_comparison_dashboard.html"),
  file.path(target_result, "Cameroon_bb8_comparison_data.rds"),
  file.path(target_result, "Cameroon Report 2026.pdf")
)
invisible(lapply(target_files, writeLines, text = "fixture"))
targets <- discover_igme_refresh_targets(target_project, "Cameroon", 2026L)
stopifnot(
  length(targets) == 8L,
  any(grepl("allsurveys_bench.rda$", targets)),
  !any(grepl("allsurveys.rda$", targets)),
  any(grepl("CurrentSubarea/current.pdf$", targets)),
  any(grepl("PreviousFinalComparison/previous.pdf$", targets))
)

fresh_file <- file.path(fixture, "fresh_artifact.txt")
writeLines("old", fresh_file)
old_artifact_time <- as.POSIXct("2026-09-01 10:00:00", tz = "UTC")
Sys.setFileTime(fresh_file, old_artifact_time)
fresh_before <- file_inventory(fresh_file)
stopifnot(inherits(
  try(
    validate_fresh_artifacts(
      fresh_file,
      fresh_before,
      run_started_at = old_artifact_time + 3600
    ),
    silent = TRUE
  ),
  "try-error"
))
writeLines("new", fresh_file)
fresh_validation <- validate_fresh_artifacts(
  fresh_file,
  fresh_before,
  run_started_at = old_artifact_time + 3600
)
stopifnot(
  length(fresh_validation) == 1L,
  isTRUE(fresh_validation[[1]]$fresh)
)

if (requireNamespace("qpdf", quietly = TRUE)) {
  two_page_pdf <- file.path(fixture, "two_page.pdf")
  grDevices::pdf(two_page_pdf)
  plot.new()
  plot.new()
  grDevices::dev.off()
  pdf_validation <- validate_pdf_artifact(two_page_pdf, minimum_pages = 2L)
  stopifnot(identical(pdf_validation$page_count, 2L))
  stopifnot(inherits(
    try(validate_pdf_artifact(two_page_pdf, minimum_pages = 3L), silent = TRUE),
    "try-error"
  ))
}

preview_project <- file.path(fixture, "preview_project")
dir.create(file.path(preview_project, "Info"), recursive = TRUE)
dir.create(file.path(preview_project, "Results", "Cameroon"), recursive = TRUE)
preview_active <- file.path(preview_project, "Data", "IGME")
write_release(preview_active, suffix = "preview", mtime = new_time)
writeLines(
  c(
    "{",
    '  "country": "Cameroon",',
    '  "iso0": "CMR",',
    '  "beg.year": 2000,',
    '  "end.proj.year": 2001,',
    paste0(
      '  "final_model": {"strata.model": "unstrat", ',
      '"time.model": "ar1", "sd.time.model": "ar1", ',
      '"bench.model": "bench"}'
    ),
    "}"
  ),
  file.path(preview_project, "Info", "Cameroon_general_info.json")
)
step_called <- FALSE
preview <- run_igme_refresh(
  country = "Cameroon",
  mode = "preview",
  project_dir = preview_project,
  preflight_validator = function(...) list(valid = TRUE),
  step_executor = function(...) {
    step_called <<- TRUE
    stop("Preview must not execute pipeline steps.")
  }
)
stopifnot(
  identical(preview$run_status, "preview_ready"),
  isFALSE(step_called),
  !"backup_dir" %in% names(preview),
  !"result_backups" %in% names(preview),
  file.exists(preview$manifest_file)
)
stopifnot(inherits(
  try(
    run_igme_refresh(
      country = "Cameroon",
      mode = "production",
      render_summary = FALSE,
      project_dir = preview_project,
      preflight_validator = function(...) list(valid = TRUE),
      step_executor = function(...) stop("must not execute")
    ),
    silent = TRUE
  ),
  "try-error"
))

fake_result <- list(
  draws.est.overall = list(
    list(years = 2000L, region = "admin1_1", draws = rep(0.02, 1000)),
    list(years = 2001L, region = "admin1_1", draws = rep(0.01, 1000))
  )
)
fake_result_path <- file.path(fixture, "fake_res_adm1_unstrat_nmr_bench.rda")
fake_result_object <- fake_result
save(fake_result_object, file = fake_result_path)
result_validation <- validate_benchmark_result_file(fake_result_path)
stopifnot(
  identical(result_validation$draw_count, 1000L),
  identical(result_validation$cell_count, 2L),
  isTRUE(result_validation$readable)
)
stopifnot(inherits(
  try(
    validate_benchmark_result_file(
      fake_result_path,
      expected_object = "wrong_result_object"
    ),
    silent = TRUE
  ),
  "try-error"
))

fake_result$draws.est.overall[[1]]$draws <- rep(0.02, 999)
fake_bad_path <- file.path(fixture, "bad_res_adm1_unstrat_nmr_bench.rda")
fake_bad_object <- fake_result
save(fake_bad_object, file = fake_bad_path)
stopifnot(inherits(
  try(validate_benchmark_result_file(fake_bad_path), silent = TRUE),
  "try-error"
))

gap_rows <- summarize_benchmark_gaps(
  model = "fixture_nmr",
  outcome = "nmr",
  national_draws = list(
    `2000` = c(0.018, 0.020, 0.022),
    `2001` = c(0.011, 0.012, 0.013)
  ),
  igme_targets = data.frame(
    year = 2000:2001,
    igme = c(0.019, 0.020)
  )
)

rollback_active <- file.path(fixture, "rollback_active")
rollback_staged <- file.path(fixture, "rollback_staged")
rollback_backup <- file.path(fixture, "rollback_backup")
write_release(rollback_active, suffix = "rollback-old", mtime = old_time)
write_release(rollback_staged, suffix = "rollback-new", mtime = new_time)
rollback_original_hashes <- vapply(
  file.path(rollback_active, igme_release_names()),
  file_sha256,
  character(1)
)
rollback_backups <- backup_igme_refresh_paths(
  file.path(rollback_active, igme_release_names()),
  rollback_active,
  rollback_backup
)
rollback_active_paths <- normalizePath(
  file.path(rollback_active, igme_release_names()),
  winslash = "/",
  mustWork = FALSE
)
activation_attempt <- 0L
failing_copy <- function(from, to, overwrite = FALSE, copy.date = FALSE) {
  normalized_to <- normalizePath(to, winslash = "/", mustWork = FALSE)
  if (tolower(normalized_to) %in% tolower(rollback_active_paths)) {
    activation_attempt <<- activation_attempt + 1L
    if (activation_attempt == 2L) return(FALSE)
  }
  file.copy(from, to, overwrite = overwrite, copy.date = copy.date)
}
stopifnot(inherits(
  try(
    promote_staged_igme_release(
      rollback_staged,
      rollback_active,
      rollback_backups,
      copy_file = failing_copy
    ),
    silent = TRUE
  ),
  "try-error"
))
stopifnot(identical(
  unname(vapply(
    file.path(rollback_active, igme_release_names()),
    file_sha256,
    character(1)
  )),
  unname(rollback_original_hashes)
))
stopifnot(activation_attempt == 2L)

rollback_absent_active <- file.path(fixture, "rollback_absent_active")
rollback_absent_staged <- file.path(fixture, "rollback_absent_staged")
dir.create(rollback_absent_active, recursive = TRUE)
write_release(
  rollback_absent_staged,
  suffix = "rollback-absent-new",
  mtime = new_time
)
rollback_absent_paths <- normalizePath(
  file.path(rollback_absent_active, igme_release_names()),
  winslash = "/",
  mustWork = FALSE
)
absent_activation_attempt <- 0L
failing_absent_copy <- function(from, to, overwrite = FALSE,
                                copy.date = FALSE) {
  normalized_to <- normalizePath(to, winslash = "/", mustWork = FALSE)
  if (tolower(normalized_to) %in% tolower(rollback_absent_paths)) {
    absent_activation_attempt <<- absent_activation_attempt + 1L
    if (absent_activation_attempt == 2L) return(FALSE)
  }
  file.copy(from, to, overwrite = overwrite, copy.date = copy.date)
}
stopifnot(inherits(
  try(
    promote_staged_igme_release(
      rollback_absent_staged,
      rollback_absent_active,
      backups = list(),
      copy_file = failing_absent_copy
    ),
    silent = TRUE
  ),
  "try-error"
))
stopifnot(
  absent_activation_attempt == 2L,
  !any(file.exists(rollback_absent_paths))
)
stopifnot(
  identical(gap_rows$threshold_per_1000, rep(2, 2)),
  isFALSE(gap_rows$review_required[[1]]),
  isTRUE(gap_rows$review_required[[2]]),
  isTRUE(all.equal(gap_rows$absolute_gap_per_1000, c(1, 8)))
)
stopifnot(
  identical(benchmark_gap_threshold("u5"), 5),
  identical(benchmark_gap_threshold("nmr"), 2)
)

median_targets <- read_igme_median_targets(
  file.path(active, "igme2026_nmr_nocrisis.csv"),
  "CMR",
  2000:2001
)
stopifnot(
  identical(median_targets$year, 2000:2001),
  all(is.finite(median_targets$igme))
)
weight.adm1.u1 <- data.frame(
  region = rep("admin1_1", 2),
  proportion = rep(1, 2),
  years = 2000:2001
)
weight_path <- file.path(fixture, "adm1_weights_u1.rda")
save(weight.adm1.u1, file = weight_path)
file_gap_rows <- benchmark_gap_rows_from_files(
  result_path = fake_result_path,
  weight_path = weight_path,
  igme_path = file.path(active, "igme2026_nmr_nocrisis.csv"),
  iso3 = "CMR",
  years = 2000:2001,
  outcome = "nmr",
  helper_path = file.path(
    project_dir, "Rcode", "_supporting_scripts", "admin_benchmark_helpers.R"
  )
)
stopifnot(
  nrow(file_gap_rows) == 2L,
  all(file_gap_rows$model == tools::file_path_sans_ext(
    basename(fake_result_path)
  ))
)

validation_project <- file.path(fixture, "validation_project")
dir.create(file.path(validation_project, "Info"), recursive = TRUE)
dir.create(
  file.path(validation_project, "Rcode", "_supporting_scripts"),
  recursive = TRUE
)
stopifnot(file.copy(
  file.path(
    project_dir,
    "Rcode",
    "_supporting_scripts",
    "admin_benchmark_helpers.R"
  ),
  file.path(
    validation_project,
    "Rcode",
    "_supporting_scripts",
    "admin_benchmark_helpers.R"
  )
))
write_release(
  file.path(validation_project, "Data", "IGME"),
  suffix = "validation",
  mtime = old_time
)
writeLines(
  c(
    "{",
    '  "country": "Cameroon",',
    '  "iso0": "CMR",',
    '  "beg.year": 2000,',
    '  "end.proj.year": 2001,',
    paste0(
      '  "final_model": {"strata.model": "unstrat", ',
      '"time.model": "ar1", "sd.time.model": "ar1", ',
      '"bench.model": "bench"}'
    ),
    "}"
  ),
  file.path(validation_project, "Info", "Cameroon_general_info.json")
)
validation_contract <- igme_refresh_benchmark_contract(
  validation_project,
  "Cameroon",
  has_admin2 = FALSE
)
validation_weights <- data.frame(
  region = rep("admin1_1", 2),
  proportion = rep(1, 2),
  years = 2000:2001
)
dir.create(dirname(validation_contract$weight_path[[1]]), recursive = TRUE)
for (path in unique(validation_contract$weight_path)) {
  weight.object <- validation_weights
  save(weight.object, file = path)
}
valid_output_result <- list(
  draws.est.overall = list(
    list(years = 2000L, region = "admin1_1", draws = rep(0.02, 1000)),
    list(years = 2001L, region = "admin1_1", draws = rep(0.019, 1000))
  )
)
save_validation_results <- function(modified_time) {
  for (index in seq_len(nrow(validation_contract))) {
    dir.create(dirname(validation_contract$output_path[[index]]),
               recursive = TRUE, showWarnings = FALSE)
    output_environment <- new.env(parent = emptyenv())
    assign(
      validation_contract$output_object[[index]],
      valid_output_result,
      envir = output_environment
    )
    save(
      list = validation_contract$output_object[[index]],
      envir = output_environment,
      file = validation_contract$output_path[[index]]
    )
    Sys.setFileTime(validation_contract$output_path[[index]], modified_time)
  }
}
validation_result_dir <- file.path(
  validation_project,
  "Results",
  "Cameroon"
)
validation_dashboard <- file.path(
  validation_result_dir,
  "Cameroon_bb8_comparison_dashboard.html"
)
validation_bundle <- file.path(
  validation_result_dir,
  "Cameroon_bb8_comparison_data.rds"
)
validation_pdf <- file.path(
  validation_result_dir,
  "Cameroon Report 2026.pdf"
)
validation_figures <- c(
  file.path(validation_result_dir, "Figures", "Trends", "NMR", "nmr.pdf"),
  file.path(validation_result_dir, "Figures", "Trends", "U5MR", "u5.pdf"),
  file.path(
    validation_result_dir, "Figures", "Summary", "NMR",
    "Cameroon_natl_unstrat_ar1_nmr_Spaghetti.pdf"
  ),
  file.path(
    validation_result_dir, "Figures", "Summary", "U5MR",
    "Cameroon_natl_unstrat_ar1_u5_Spaghetti.pdf"
  ),
  file.path(
    validation_result_dir,
    "Figures",
    "CurrentSubarea",
    "appendix.pdf"
  )
)
dir.create(validation_result_dir, recursive = TRUE)
save_validation_results(old_time)
writeLines("<html><body>old</body></html>", validation_dashboard)
saveRDS(list(country = "Cameroon"), validation_bundle)
for (path in validation_figures) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines("old plot", path)
}
grDevices::pdf(validation_pdf)
plot.new()
plot.new()
grDevices::dev.off()
validation_artifacts <- c(
  validation_contract$output_path,
  validation_dashboard,
  validation_bundle,
  validation_pdf,
  validation_figures
)
Sys.setFileTime(validation_artifacts, old_time)
validation_before <- file_inventory(validation_artifacts)
stopifnot(inherits(
  try(
    validate_igme_refresh_outputs(
      validation_project,
      "Cameroon",
      pre_run_inventory = validation_before,
      run_started_at = old_time + 3600,
      log_dir = file.path(validation_project, "stale_validation_log")
    ),
    silent = TRUE
  ),
  "try-error"
))

validation_started <- Sys.time()
fresh_time <- validation_started + 2
save_validation_results(fresh_time)
writeLines("<html><body>fresh</body></html>", validation_dashboard)
saveRDS(list(country = "Cameroon"), validation_bundle)
for (path in validation_figures) writeLines("fresh plot", path)
grDevices::pdf(validation_pdf)
plot.new()
plot.new()
grDevices::dev.off()
Sys.setFileTime(
  c(validation_dashboard, validation_bundle, validation_pdf,
    validation_figures),
  fresh_time
)
full_validation <- validate_igme_refresh_outputs(
  validation_project,
  "Cameroon",
  pre_run_inventory = validation_before,
  run_started_at = validation_started,
  log_dir = file.path(validation_project, "fresh_validation_log")
)
stopifnot(
  length(full_validation$benchmark_results) == 2L,
  length(full_validation$benchmark_freshness) == 2L,
  identical(full_validation$report_pdf$page_count, 2L),
  length(full_validation$diagnostic_plots) >= 2L,
  length(full_validation$report_plots) >= 2L,
  length(full_validation$appendix) >= 1L
)

production_project <- file.path(fixture, "production_project")
dir.create(file.path(production_project, "Info"), recursive = TRUE)
production_active <- file.path(production_project, "Data", "IGME")
production_staged <- file.path(production_active, "staged")
write_release(production_active, suffix = "old", mtime = old_time)
write_release(production_staged, suffix = "new-release", mtime = new_time)
writeLines(
  c(
    "{",
    '  "country": "Cameroon",',
    '  "iso0": "CMR",',
    '  "beg.year": 2000,',
    '  "end.proj.year": 2001,',
    paste0(
      '  "final_model": {"strata.model": "unstrat", ',
      '"time.model": "ar1", "sd.time.model": "ar1", ',
      '"bench.model": "bench"}'
    ),
    "}"
  ),
  file.path(production_project, "Info", "Cameroon_general_info.json")
)
production_result <- file.path(production_project, "Results", "Cameroon")
dir.create(
  file.path(production_result, "Betabinomial", "NMR"),
  recursive = TRUE
)
old_benchmark <- file.path(
  production_result, "Betabinomial", "NMR",
  "Cameroon_res_adm1_unstrat_nmr_allsurveys_bench.rda"
)
writeLines("old benchmark", old_benchmark)
executed_steps <- character()
mock_step_executor <- function(step, step_index, context, mode, log_dir,
                               prompt = readline) {
  executed_steps <<- c(executed_steps, step$id)
  list(
    step_index = step_index,
    step_id = step$id,
    label = step$label,
    script = step$script,
    status = "completed",
    log_file = file.path(log_dir, paste0(step$id, ".log"))
  )
}
old_refresh_env <- Sys.getenv("BB8_REFRESH_BENCHMARKS_ONLY", unset = NA_character_)
production <- run_igme_refresh(
  country = "Cameroon",
  mode = "production",
  render_summary = TRUE,
  project_dir = production_project,
  step_executor = mock_step_executor,
  preflight_validator = function(...) list(valid = TRUE),
  output_validator = function(...) list(valid = TRUE)
)
stopifnot(
  identical(production$run_status, "completed_pending_visual_review"),
  identical(
    executed_steps,
    c(
      "preparation", "bb8_refresh", "bb8_comparison", "diagnostics",
      "report_plots", "country_summary"
    )
  ),
  !"backup_dir" %in% names(production),
  !"result_backups" %in% names(production),
  !dir.exists(file.path(production_result, "backups")),
  identical(
    file_sha256(file.path(production_active, igme_release_names()[[1]])),
    file_sha256(file.path(production_staged, igme_release_names()[[1]]))
  ),
  identical(
    Sys.getenv("BB8_REFRESH_BENCHMARKS_ONLY", unset = NA_character_),
    old_refresh_env
  )
)

crisis_production_project <- file.path(fixture, "crisis_production_project")
dir.create(file.path(crisis_production_project, "Info"), recursive = TRUE)
write_release(
  file.path(crisis_production_project, "Data", "IGME"),
  suffix = "crisis",
  mtime = new_time
)
writeLines(
  c(
    "{",
    '  "country": "Haiti",',
    '  "iso0": "CMR",',
    '  "beg.year": 2000,',
    '  "end.proj.year": 2001,',
    '  "doCrisisAdj": true,',
    paste0(
      '  "final_model": {"strata.model": "unstrat", ',
      '"time.model": "ar1", "sd.time.model": "ar1", ',
      '"bench.model": "bench"}'
    ),
    "}"
  ),
  file.path(crisis_production_project, "Info", "Haiti_general_info.json")
)
dir.create(
  file.path(crisis_production_project, "Results", "Haiti"),
  recursive = TRUE
)
executed_crisis_steps <- character()
crisis_production <- run_igme_refresh(
  country = "Haiti",
  mode = "production",
  render_summary = TRUE,
  project_dir = crisis_production_project,
  step_executor = function(step, step_index, context, mode, log_dir,
                           prompt = readline) {
    executed_crisis_steps <<- c(executed_crisis_steps, step$id)
    list(
      step_index = step_index,
      step_id = step$id,
      label = step$label,
      script = step$script,
      status = "completed",
      log_file = file.path(log_dir, paste0(step$id, ".log"))
    )
  },
  preflight_validator = function(...) list(valid = TRUE),
  output_validator = function(...) list(valid = TRUE)
)
stopifnot(
  identical(crisis_production$run_status, "completed_pending_visual_review"),
  identical(
    executed_crisis_steps,
    c(
      "preparation", "bb8_refresh", "crisis_adjustment",
      "bb8_comparison", "diagnostics", "report_plots", "country_summary"
    )
  )
)

entrypoint <- file.path(project_dir, "Rcode", "run_igme_refresh.R")
stopifnot(file.exists(entrypoint))
entrypoint_text <- paste(readLines(entrypoint, warn = FALSE), collapse = "\n")
stopifnot(
  grepl("parse_igme_refresh_args", entrypoint_text, fixed = TRUE),
  grepl("run_igme_refresh", entrypoint_text, fixed = TRUE),
  grepl("--production", entrypoint_text, fixed = TRUE)
)

update_script_path <- file.path(
  project_dir,
  "Data",
  "IGME",
  "update results file.R"
)
update_script <- paste(
  readLines(update_script_path, warn = FALSE),
  collapse = "\n"
)
parse(update_script_path)
stopifnot(
  grepl('file.path("Data", "IGME", c(', update_script, fixed = TRUE),
  grepl('source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))',
        update_script, fixed = TRUE),
  grepl('overwrite = TRUE', update_script, fixed = TRUE),
  !grepl('sys.nframe()', update_script, fixed = TRUE)
)

readme <- paste(
  readLines(file.path(project_dir, "README.md"), warn = FALSE),
  collapse = "\n"
)
stopifnot(
  grepl("run_igme_refresh.R --country", readme, fixed = TRUE),
  grepl("completed_pending_visual_review", readme, fixed = TRUE)
)

message("IGME refresh runner tests passed")
