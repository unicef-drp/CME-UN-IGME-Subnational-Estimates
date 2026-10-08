script <- readLines("Rcode/4_Direct_SmoothDirect_sf.R", warn = FALSE)

required_dirs <- c(
  'ensure_output_dir("Figures", "Direct")',
  'ensure_output_dir("Figures", "SmoothedDirect")',
  'ensure_output_dir("Figures", "SmoothedDirect", "U5MR")',
  'ensure_output_dir("Figures", "SmoothedDirect", "NMR")'
)

missing_dirs <- required_dirs[!vapply(required_dirs, function(required_dir) {
  any(grepl(required_dir, script, fixed = TRUE))
}, logical(1))]

if (length(missing_dirs) > 0) {
  stop("Missing figure output directory setup:\n", paste(missing_dirs, collapse = "\n"))
}

forbidden_paths <- c(
  'file.path("Figures", "Direct", "U5MR", "Admin2"',
  'file.path("Figures", "Direct", "NMR", "Admin2"',
  'ensure_output_dir("Figures", "Direct", "U5MR", "Admin2")',
  'ensure_output_dir("Figures", "Direct", "NMR", "Admin2")'
)

remaining_forbidden <- forbidden_paths[vapply(forbidden_paths, function(forbidden_path) {
  any(grepl(forbidden_path, script, fixed = TRUE))
}, logical(1))]

if (length(remaining_forbidden) > 0) {
  stop("Admin2 direct figures should be saved directly under Figures/Direct:\n",
       paste(remaining_forbidden, collapse = "\n"))
}

cat("Direct and smoothed-direct figure directories are created before plotting without nested Admin2 direct folders.\n")
