root <- normalizePath(
  file.path(getwd()),
  winslash = "/",
  mustWork = TRUE
)

helper_path <- file.path(root, "Rcode", "_supporting_scripts", "project_paths.R")
stopifnot(file.exists(helper_path))
source(helper_path)

scan_dirs <- c(file.path(root, "Rcode"), file.path(root, "Info"))
r_files <- unlist(lapply(scan_dirs, list.files, pattern = "\\.R$", recursive = TRUE, full.names = TRUE))
pattern <- paste0("se", "twd\\(")
hits <- unlist(lapply(r_files, function(path) {
  matches <- grep(pattern, readLines(path, warn = FALSE), value = TRUE)
  if (length(matches) == 0) {
    return(character())
  }
  paste0(path, ": ", matches)
}))

if (length(hits) > 0) {
  stop("Working-directory changes remain:\n", paste(hits, collapse = "\n"))
}

shape_path <- resolve_country_data_path("../shapeFiles/georepo_NGA_shp",
                                        country_data_dir(project_home(), "Nigeria"))
expected_shape_path <- file.path(project_home(), "Data", "shapeFiles", "georepo_NGA_shp")
stopifnot(normalizePath(shape_path, winslash = "/", mustWork = FALSE) ==
            normalizePath(expected_shape_path, winslash = "/", mustWork = FALSE))

scratch_dir <- tempfile("path-helper-")
dir.create(scratch_dir)
use_path_base(scratch_dir)
path_helper_probe <- data.frame(value = 42)
save(path_helper_probe, file = "probe.rda")
rm(path_helper_probe)
load("probe.rda")
stopifnot(identical(path_helper_probe$value, 42))

cat("No working-directory changes remain; project path helper resolves relative data paths.\n")
