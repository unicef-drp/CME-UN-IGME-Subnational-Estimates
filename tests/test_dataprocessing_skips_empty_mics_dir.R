script_text <- paste(readLines(file.path("Rcode", "3_DataProcessing_sf.R"),
                               warn = FALSE),
                     collapse = "\n")

required_fragments <- c(
  "source(file.path(project_home(), \"Rcode/_supporting_scripts/mics_tmp_files.R\"))",
  "mics_files <- select_mics_tmp_files(mics.dir)",
  "if (length(mics_files) == 0)",
  "No MICS tmp files found for ",
  "continuing with DHS only"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = script_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("3_DataProcessing_sf.R should skip MICS key construction when no MICS tmp files exist. Missing: ",
       paste(missing, collapse = ", "))
}

cat("Data processing skips empty MICS directories.\n")
