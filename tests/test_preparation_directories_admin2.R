source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

base_dirs <- country_result_dirs("Results/NoSecondLevel", include_admin2 = FALSE)
admin2_dirs <- country_result_dirs("Results/WithSecondLevel", include_admin2 = TRUE)

if (any(grepl("Admin2", base_dirs, fixed = TRUE))) {
  stop("country_result_dirs() should not include Admin2 folders without admin2.")
}

if (!any(grepl(file.path("Direct", "U5MR", "Admin2"), admin2_dirs, fixed = TRUE)) ||
    !any(grepl(file.path("Direct", "NMR", "Admin2"), admin2_dirs, fixed = TRUE))) {
  stop("country_result_dirs() should include Admin2 direct figure folders when admin2 exists.")
}

cat("Preparation result directories are conditional on admin2 availability.\n")
