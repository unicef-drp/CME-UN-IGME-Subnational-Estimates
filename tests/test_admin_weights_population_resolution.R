script <- readLines("Rcode/5_Admin_Weights_sf.R", warn = FALSE)
script_text <- paste(script, collapse = "\n")

stopifnot(any(grepl("worldpop_population_age_sex_file(", script, fixed = TRUE)))
stopifnot(any(grepl("worldpop_population_source_name(year)", script, fixed = TRUE)))
stopifnot(any(grepl("ADMIN_WEIGHTS_REBUILD_POPULATION", script, fixed = TRUE)))
stopifnot(any(grepl("prepare_population_rasters <- function(year)", script, fixed = TRUE)))
stopifnot(any(grepl("calculate_population_weights <- function()", script, fixed = TRUE)))
stopifnot(any(grepl("home.dir <- project_home()", script, fixed = TRUE)))
stopifnot(any(grepl("population_dir <- population_raster_dir(country)", script, fixed = TRUE)))
stopifnot(any(grepl('weight_output_dir <- file.path(data.dir, "worldpop")', script, fixed = TRUE)))

legacy_comparison_terms <- c(
  "100m",
  "ADMIN_WEIGHTS_SKIP_100M_COMPARISON",
  "comparison.population.resolution",
  "run.population.resolution.comparison",
  "compare_weight_tables",
  "weight.resolution.comparison",
  "weight.resolution.summary"
)
if (any(vapply(
  legacy_comparison_terms,
  grepl,
  logical(1),
  x = script_text,
  fixed = TRUE
))) {
  stop("Admin weights should contain only the production 1km path.")
}

generic_weight_files <- c(
  "adm1_weights_u1.rda",
  "adm1_weights_u5.rda",
  "adm2_weights_u1.rda",
  "adm2_weights_u5.rda"
)
for (weight_file in generic_weight_files) {
  if (!grepl(weight_file, script_text, fixed = TRUE)) {
    stop("Admin weights should save the generic production file: ", weight_file)
  }
}
if (grepl("adm1_weights_u1_1km.rda", script_text, fixed = TRUE) ||
    grepl("adm1_weights_u5_1km.rda", script_text, fixed = TRUE) ||
    grepl("adm2_weights_u1_1km.rda", script_text, fixed = TRUE) ||
    grepl("adm2_weights_u5_1km.rda", script_text, fixed = TRUE)) {
  stop("Admin weights should not save duplicate _1km.rda production files.")
}

specific_script <- readLines(
  file.path("Rcode", "_script_for_specific_tasks", "build_new_worldpop_u5_weights.R"),
  warn = FALSE
)
stopifnot(any(grepl("raw_worldpop_dir <- worldpop_raw_dir(country)",
                    specific_script, fixed = TRUE)))
stopifnot(any(grepl("population_dir <- population_raster_dir(country)",
                    specific_script, fixed = TRUE)))

cat("Admin weights use only centralized 1km TIFFs and keep weight products country-local.\n")
