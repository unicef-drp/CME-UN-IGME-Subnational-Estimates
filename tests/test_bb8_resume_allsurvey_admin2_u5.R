script_text <- paste(
  readLines(file.path("Rcode", "8_10_BB8.R"), warn = FALSE),
  collapse = "\n"
)

required <- c(
  'Sys.getenv("BB8_RESUME_ALLSURVEY_ADMIN2_U5", "0")',
  "if (!bb8_resume_allsurvey_admin2_u5 && !bb8_resume_allsurvey_benchmarks)",
  "resuming at the Admin-2 all-survey U5MR model"
)

missing <- required[
  !vapply(
    required,
    function(pattern) grepl(pattern, script_text, fixed = TRUE),
    logical(1)
  )
]

if (length(missing)) {
  stop(
    "Admin-2 all-survey U5MR resume path is incomplete: ",
    paste(missing, collapse = ", ")
  )
}

cat("BB8 can resume at the missing Admin-2 all-survey U5MR model.\n")
