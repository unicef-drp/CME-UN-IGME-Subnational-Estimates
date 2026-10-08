source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

resolved <- resolve_project_path(c("Info", "Rcode"), project_home())
stopifnot(length(resolved) == 2)
stopifnot(all(grepl("/", resolved, fixed = TRUE)))

exists_result <- file.exists(c("Info", "Rcode"))
stopifnot(identical(exists_result, c(TRUE, TRUE)))

cat("Project path helpers resolve vector paths.\n")
