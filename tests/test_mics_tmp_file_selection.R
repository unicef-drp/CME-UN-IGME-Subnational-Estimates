helper_file <- file.path(
  "Rcode", "_supporting_scripts", "mics_tmp_files.R"
)
if (!file.exists(helper_file)) {
  stop("Missing MICS temporary-file selector: ", helper_file)
}

source(helper_file)

tmp_dir <- tempfile("mics-tmp-selection-")
dir.create(file.path(tmp_dir, "2018"), recursive = TRUE)
on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

paths <- c(
  file.path(tmp_dir, "gha.2011.tmp.rda"),
  file.path(tmp_dir, "gha.2018.tmp.rda"),
  file.path(tmp_dir, "2018", "gha.2018.geo.tmp.rda")
)
invisible(vapply(paths, file.create, logical(1)))

selected <- select_mics_tmp_files(tmp_dir)
selected_names <- basename(selected)

stopifnot(
  identical(
    selected_names,
    c("gha.2011.tmp.rda", "gha.2018.geo.tmp.rda")
  ),
  !"gha.2018.tmp.rda" %in% selected_names,
  identical(select_mics_tmp_files(tempfile("missing-mics-dir-")), character())
)

cat("MICS temporary-file selection prefers recursive geospatial artifacts.\n")
