script_text <- paste(readLines("Rcode/8_10_BB8_unstrat_only.R", warn = FALSE), collapse = "\n")

stopifnot(grepl('run_admin2_bb8 <- exists("poly.layer.adm2", inherits = TRUE)',
                script_text, fixed = TRUE))
stopifnot(grepl("if (run_admin2_bb8)", script_text, fixed = TRUE))

expected_stubs <- c(
  "adm2_unstrat_nmr_allsurveys",
  "adm2_unstrat_u5_allsurveys",
  "adm2_unstrat_nmr_allsurveys_bench",
  "adm2_unstrat_u5_allsurveys_bench"
)

for (stub in expected_stubs) {
  stopifnot(grepl(stub, script_text, fixed = TRUE))
}

cat("Unstratified BB8 script includes conditional Admin2 all-survey fits.\n")
