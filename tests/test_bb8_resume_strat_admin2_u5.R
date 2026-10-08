script_text <- paste(
  readLines(file.path("Rcode", "8_10_BB8.R"), warn = FALSE),
  collapse = "\n"
)

required <- c(
  'Sys.getenv("BB8_RESUME_STRAT_ADMIN2_U5", "0")',
  "if (!bb8_resume_strat_admin2_u5)",
  "resuming at the Admin-2 stratified U5MR benchmark"
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
    "Admin-2 stratified U5MR benchmark resume path is incomplete: ",
    paste(missing, collapse = ", ")
  )
}

cat("BB8 can resume at the missing Admin-2 stratified U5MR benchmark.\n")
