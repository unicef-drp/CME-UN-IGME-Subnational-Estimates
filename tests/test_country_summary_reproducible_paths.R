script <- paste(readLines(file.path("Rcode", "11_CountrySummary.Rmd"),
                          warn = FALSE),
                collapse = "\n")

if (!grepl('title: "`r paste(gsub(\'_\', \' \', country), \'Country Summary\')`"',
           script, fixed = TRUE)) {
  stop("11_CountrySummary.Rmd should include the prepared country name in its title.")
}

if (!grepl("geometry: a4paper, margin=0.5in", script, fixed = TRUE) ||
    grepl("geometry: a4paper, landscape", script, fixed = TRUE)) {
  stop("11_CountrySummary.Rmd should render the core summary on A4 portrait paper.")
}

if (!grepl('summary_full_width <- "0.95\\\\linewidth"', script, fixed = TRUE) ||
    !grepl('summary_half_width <- "0.46\\\\linewidth"', script, fixed = TRUE) ||
    !grepl('summary_square_width <- "0.68\\\\linewidth"', script, fixed = TRUE)) {
  stop("11_CountrySummary.Rmd should size figures relative to the A4 portrait line width.")
}

if (grepl("rstudioapi::getActiveDocumentContext()", script, fixed = TRUE)) {
  stop("11_CountrySummary.Rmd should not require RStudio to locate the project.")
}

required <- c(
  'source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))',
  'source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))',
  'home.dir <- project_home()'
)

missing <- required[!vapply(required, grepl, logical(1), x = script, fixed = TRUE)]
if (length(missing) > 0) {
  stop("11_CountrySummary.Rmd missing reproducible path setup:\n",
       paste(missing, collapse = "\n"))
}

if (grepl("end.proj.year <- 2024", script, fixed = TRUE)) {
  stop("11_CountrySummary.Rmd should not hard-code the 2024 projection end year.")
}

if (grepl("medianmap_20002024", script, fixed = TRUE)) {
  stop("11_CountrySummary.Rmd should build selected-year map filenames from plot.years.")
}

context_pos <- regexpr("require_country_context()", script, fixed = TRUE)
years_reset_pos <- gregexpr("plot.years <- 2000:end.proj.year", script, fixed = TRUE)[[1]]

if (context_pos[1] < 0 ||
    all(years_reset_pos < context_pos[1])) {
  stop("11_CountrySummary.Rmd should reset plot.years after loading the prepared country context.")
}

cat("Country summary Rmd uses reproducible project paths outside RStudio.\n")
