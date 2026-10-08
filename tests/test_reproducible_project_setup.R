script_files <- list.files("Rcode",
                           pattern = "\\.(R|Rmd)$",
                           recursive = TRUE,
                           full.names = TRUE)

lines <- unlist(lapply(script_files, function(path) {
  paste0(path, ":", seq_along(readLines(path, warn = FALSE)), ":",
         readLines(path, warn = FALSE))
}), use.names = FALSE)

user_specific_hits <- grep(
  "C:/Users|OneDrive - UNICEF|Documents - Child Mortality",
  lines,
  value = TRUE,
  perl = TRUE
)

if (length(user_specific_hits) > 0) {
  stop("User-specific absolute paths remain in R scripts:\n",
       paste(user_specific_hits, collapse = "\n"))
}

project_helper <- readLines("Rcode/_supporting_scripts/project_paths.R", warn = FALSE)
stopifnot(any(grepl("dir_subnational", project_helper, fixed = TRUE)))
stopifnot(any(grepl("UN_SUBNATIONAL_HOME", project_helper, fixed = TRUE)))

setup_scripts <- c(
  "Rcode/1_Preperation.R",
  "Rcode/3_DataProcessing_sf.R",
  "Rcode/4_Direct_SmoothDirect_sf.R",
  "Rcode/5_Admin_Weights_sf.R",
  "Rcode/6_Comparison_Plot.R",
  "Rcode/7a_UR_prop.R",
  "Rcode/7b_UR_thresholding_sf.R",
  "Rcode/8_10_BB8.R",
  "Rcode/9_Diagnostic_Plots.R",
  "Rcode/11_Report_Plot.R"
)

for (path in setup_scripts) {
  setup <- paste(head(readLines(path, warn = FALSE), 60), collapse = "\n")
  if (!grepl('USERPROFILE <- Sys.getenv\\("USERPROFILE"\\)', setup) ||
      !grepl('source\\(file.path\\(USERPROFILE, "Dropbox/UNICEF Work/profile.R"\\)\\)', setup) ||
      !grepl('dir_subnational <- file.path\\(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main"\\)', setup) ||
      !grepl('source\\(file.path\\(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"\\)\\)', setup)) {
    stop("Reproducible project setup block is missing from ", path)
  }
}

cat("R scripts use reproducible profile-based project setup.\n")
