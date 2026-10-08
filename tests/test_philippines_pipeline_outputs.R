load_single_object <- function(path) {
  if (!file.exists(path)) {
    stop("Required Philippines pipeline output is missing: ", path)
  }
  env <- new.env(parent = emptyenv())
  object_names <- load(path, envir = env)
  if (length(object_names) != 1L) {
    stop("Expected exactly one object in ", path, ".")
  }
  env[[object_names[[1L]]]]
}

country_dir <- file.path("Data", "Countries", "Philippines")
full_data <- load_single_object(
  file.path(country_dir, "Philippines_cluster_dat.rda")
)
same_frame_data <- load_single_object(
  file.path(country_dir, "Philippines_cluster_dat_1frame.rda")
)

stopifnot(
  identical(sort(unique(full_data$survey)), c(2003, 2008, 2017, 2022)),
  identical(sort(unique(same_frame_data$survey)), c(2017, 2022)),
  nrow(full_data) == 314136L,
  nrow(same_frame_data) == 260588L,
  !anyNA(full_data$admin1),
  !anyNA(full_data$admin2),
  length(unique(full_data$admin1)) == 17L,
  length(unique(full_data$admin2)) == 88L
)

adjacency_env <- new.env(parent = emptyenv())
load(
  file.path(
    "Data", "shapeFiles", "ocha_PHL_shp", "Philippines_Amat.rda"
  ),
  envir = adjacency_env
)
stopifnot(
  identical(dim(adjacency_env$admin1.mat), c(17L, 17L)),
  identical(dim(adjacency_env$admin2.mat), c(88L, 88L))
)

weight_dir <- file.path(country_dir, "worldpop")
weight_specs <- list(
  adm1_weights_u1.rda = c(17L, 442L),
  adm1_weights_u5.rda = c(17L, 442L),
  adm2_weights_u1.rda = c(88L, 2288L),
  adm2_weights_u5.rda = c(88L, 2288L)
)
for (filename in names(weight_specs)) {
  weights <- load_single_object(file.path(weight_dir, filename))
  expected <- weight_specs[[filename]]
  stopifnot(
    nrow(weights) == expected[[2L]],
    length(unique(weights$region)) == expected[[1L]],
    identical(sort(unique(weights$years)), 2000:2025),
    all(is.finite(weights$proportion)),
    all(weights$proportion >= 0)
  )
  totals <- aggregate(proportion ~ years, data = weights, FUN = sum)
  stopifnot(max(abs(totals$proportion - 1)) < 1e-8)
}

model_paths <- c(
  file.path(
    "NMR", "Philippines_res_adm1_unstrat_nmr_allsurveys_bench.rda"
  ),
  file.path(
    "NMR", "Philippines_res_adm2_unstrat_nmr_allsurveys_bench.rda"
  ),
  file.path(
    "U5MR", "Philippines_res_adm1_unstrat_u5_allsurveys_bench.rda"
  ),
  file.path(
    "U5MR", "Philippines_res_adm2_unstrat_u5_allsurveys_bench.rda"
  )
)
model_specs <- stats::setNames(c(17L, 88L, 17L, 88L), model_paths)
model_dir <- file.path("Results", "Philippines", "Betabinomial")
for (relative_path in names(model_specs)) {
  result <- load_single_object(file.path(model_dir, relative_path))
  stopifnot(
    inherits(result, "SUMMERprojlist"),
    is.data.frame(result$overall),
    nrow(result$overall) == model_specs[[relative_path]] * 26L,
    length(unique(result$overall$region)) == model_specs[[relative_path]],
    identical(sort(unique(result$overall$time)), 1:26),
    all(is.finite(result$overall$median)),
    all(result$overall$median > 0),
    all(result$overall$median < 1)
  )
}

result_dir <- file.path("Results", "Philippines")
dashboard_path <- file.path(
  result_dir, "Philippines_bb8_comparison_dashboard.html"
)
summary_path <- file.path(result_dir, "Philippines Report 2026.pdf")
stopifnot(
  file.exists(dashboard_path),
  file.info(dashboard_path)$size > 1e6,
  file.exists(summary_path),
  file.info(summary_path)$size > 1e6
)

log_dirs <- list.dirs(
  file.path(result_dir, "logs"),
  recursive = FALSE,
  full.names = TRUE
)
manifest_paths <- file.path(log_dirs, "pipeline_manifest.json")
manifest_paths <- manifest_paths[file.exists(manifest_paths)]
manifest_paths <- manifest_paths[
  order(basename(dirname(manifest_paths)), decreasing = TRUE)
]
stopifnot(length(manifest_paths) > 0L)
manifest_path <- manifest_paths[[1L]]
manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
stopifnot(
  identical(manifest$run_status, "completed"),
  identical(manifest$steps[[12L]]$step_id, "country_summary"),
  identical(manifest$steps[[12L]]$status, "completed")
)

cat("Philippines production pipeline output contract tests passed.\n")
