script <- paste(
  readLines(file.path("Rcode", "8_10_BB8.R"), warn = FALSE),
  collapse = "\n"
)

stopifnot(
  grepl(
    "_fit_adm2_unstrat_nmr_allsurveys_bench.txt",
    script,
    fixed = TRUE
  ),
  !grepl(
    "_fit_adm2 _unstrat_nmr_allsurveys_bench.txt",
    script,
    fixed = TRUE
  )
)

message("Admin-2 BB8 fit-summary filename test passed")
