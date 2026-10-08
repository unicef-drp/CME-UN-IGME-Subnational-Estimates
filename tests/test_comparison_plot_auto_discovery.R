source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

helper_path <- file.path("Rcode", "_supporting_scripts", "comparison_helpers.R")
if (!file.exists(helper_path)) {
  stop("Comparison plot should use comparison helpers for model discovery.")
}
source(helper_path)

country <- "Nigeria"
res.dir <- file.path(project_home(), "Results", country)
direct_models <- discover_direct_time_models(res.dir, country)

if (!"ar1" %in% direct_models) {
  stop("Nigeria comparison plot discovery should find available AR1 smoothed-direct output.")
}

axis_test <- data.frame(
  method = c("keep", "drop"),
  median_nmr = c(0.02, 0.5),
  median_u5 = c(0.1, 0.6)
)
u5_limits <- comparison_y_limits(axis_test, "keep", "u5")
if (u5_limits[2] >= 200) {
  stop("Comparison plot y-axis limits should be based only on methods plotted in the panel.")
}

script <- paste(readLines(file.path("Rcode", "6_Comparison_Plot.R"), warn = FALSE),
                collapse = "\n")

if (!grepl("source(file.path(dir_subnational, \"Rcode/_supporting_scripts/comparison_helpers.R\"))", script, fixed = TRUE)) {
  stop("6_Comparison_Plot.R should load comparison helpers.")
}

if (!grepl("require_country_context()", script, fixed = TRUE)) {
  stop("6_Comparison_Plot.R should use the country context loaded by 1_Preperation.R.")
}

if (!grepl("discover_direct_time_models", script, fixed = TRUE)) {
  stop("6_Comparison_Plot.R should scan Results/<country>/Direct for available models.")
}

if (!grepl("comparison_y_limits(natl.all, methods.use", script, fixed = TRUE)) {
  stop("6_Comparison_Plot.R should calculate y-axis limits after choosing panel methods.")
}

if (!grepl("open_plot_pdf(file.path(res.dir", script, fixed = TRUE)) {
  stop("6_Comparison_Plot.R should use open_plot_pdf() so locked PDFs get timestamped fallbacks.")
}

if (grepl("time.model <- c('rw2','ar1')", script, fixed = TRUE) ||
    grepl("time.model <- c('rw2', 'ar1')", script, fixed = TRUE)) {
  stop("6_Comparison_Plot.R should not manually select the smoothed-direct time model.")
}

if (grepl("methods.use <- c(", script, fixed = TRUE)) {
  stop("6_Comparison_Plot.R should build plot method lists from available output, not manual vectors.")
}

cat("Comparison plot discovers available outputs instead of hard-coding model selections.\n")
