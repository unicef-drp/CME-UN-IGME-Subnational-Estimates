helper <- paste(
  readLines(file.path("Rcode", "_supporting_scripts", "getBB8.R"), warn = FALSE),
  collapse = "\n"
)
pipeline <- paste(
  readLines(file.path("Rcode", "8_10_BB8.R"), warn = FALSE),
  collapse = "\n"
)

expected_age_groups <- paste0(
  "age.groups <- c(",
  "'0', '1-11', '12-23', '24-35', '36-47', '48-59'",
  ")"
)
if (!grepl(expected_age_groups, helper, fixed = TRUE)) {
  stop("U5MR BB8 must use the six canonical age groups explicitly.")
}
nmr_resume_guard <- grepl(
  "if (!bb8_skip_same_frame_nmr)",
  pipeline,
  fixed = TRUE
) || grepl(
  "if (!bb8_skip_same_frame_main && !bb8_skip_same_frame_nmr)",
  pipeline,
  fixed = TRUE
)
if (!grepl("BB8_SKIP_SAME_FRAME_NMR", pipeline, fixed = TRUE) ||
    !nmr_resume_guard) {
  stop("BB8 should support resuming after completed same-frame NMR fits.")
}
if (!grepl("BB8_RESUME_ALL_SURVEYS", pipeline, fixed = TRUE) ||
    !grepl("if (!bb8_resume_all_surveys)", pipeline, fixed = TRUE)) {
  stop("BB8 should support resuming after all same-frame models and benchmarks.")
}
if (grepl(
  "load(paste0(country,'_cluster_dat.rda'),\n       envir = .GlobalEnv)",
  pipeline,
  fixed = TRUE
)) {
  stop("All-survey data must load into the current pipeline environment.")
}

cat("BB8 U5MR age groups and same-frame resume switch are explicit.\n")
