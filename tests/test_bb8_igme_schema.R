script <- readLines("Rcode/8_10_BB8.R", warn = FALSE)

stopifnot(any(grepl("igme.ests.u5.raw$ISO.Code==iso0", script, fixed = TRUE)))
stopifnot(any(grepl("igme.ests.nmr.raw$ISO.Code==iso0", script, fixed = TRUE)))

if (any(grepl("igme.ests.nmr.raw$iso==iso0", script, fixed = TRUE))) {
  stop("BB8 NMR IGME filter must use current ISO.Code column, not old iso column.")
}

required_dirs <- c(
  'dir.create(file.path("Betabinomial", "NMR"), recursive = TRUE',
  'dir.create(file.path("Betabinomial", "U5MR"), recursive = TRUE'
)

missing_dirs <- required_dirs[!vapply(required_dirs, function(required_dir) {
  any(grepl(required_dir, script, fixed = TRUE))
}, logical(1))]

if (length(missing_dirs) > 0) {
  stop("Missing BB8 output directory setup:\n", paste(missing_dirs, collapse = "\n"))
}

cat("BB8 IGME filters and output directories are ready for current inputs.\n")
