comparison_scripts <- file.path(
  "Rcode",
  c("6_Comparison_Plot.R", "9_Comparison_Plot.R")
)

for (script_path in comparison_scripts) {
  script <- paste(readLines(script_path, warn = FALSE), collapse = "\n")
  compact_script <- gsub("[[:space:]]+", " ", script)
  if (!grepl(
    "vapply( methods, exists, logical(1), envir = environment(), inherits = FALSE )",
    compact_script,
    fixed = TRUE
  )) {
    stop(
      basename(script_path),
      " must discover comparison objects in its source environment."
    )
  }
  if (grepl("sapply(methods,exists)", script, fixed = TRUE)) {
    stop(
      basename(script_path),
      " still relies on caller-frame object discovery."
    )
  }
}

cat("Comparison method discovery is stable in isolated pipeline environments.\n")
