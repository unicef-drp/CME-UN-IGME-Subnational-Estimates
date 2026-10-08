active_scripts <- file.path(
  "Rcode",
  c(
    "1_Preperation.R",
    "2_download_georepo_shapefiles.R",
    "3_DataProcessing_sf.R",
    "4_Direct_SmoothDirect_sf.R",
    "5_Admin_Weights_sf.R",
    "6_Comparison_Plot.R",
    "7a_UR_prop.R",
    "7b_UR_thresholding_sf.R",
    "8_10_BB8.R",
    "9_Diagnostic_Plots.R",
    "11_Report_Plot.R"
  )
)

lines <- unlist(lapply(active_scripts, function(path) {
  paste0(path, ":", seq_along(readLines(path, warn = FALSE)), ":",
         readLines(path, warn = FALSE))
}), use.names = FALSE)

bad_literal_paths <- grep(
  "paste0\\(['\"](?:U5MR|NMR|Direct|Betabinomial|Figures|Data|Results|UR|worldpop|Population|prepared_dat)/",
  lines,
  value = TRUE,
  perl = TRUE
)

bad_file_calls <- grep(
  "(load|save|source|rast|read\\.csv|write\\.csv|readRDS|saveRDS|pdf|ggsave|dir\\.exists|dir\\.create|file\\.exists|use_path_base)\\([^\\n]*paste0\\([^\\n]*['\"][^'\"]*/",
  lines,
  value = TRUE,
  perl = TRUE
)

bad_directory_assignments <- grep(
  "(data|res)\\.dir\\s*<-\\s*paste0\\([^\\n]*['\"][^'\"]*/",
  lines,
  value = TRUE,
  perl = TRUE
)

bad <- unique(c(bad_literal_paths, bad_file_calls, bad_directory_assignments))
if (length(bad) > 0) {
  stop("File paths still built with paste0():\n", paste(bad, collapse = "\n"))
}

cat("Active scripts use file.path() for file-directory paths.\n")
