script_text <- paste(
  readLines(file.path("Rcode", "8_10_BB8.R"), warn = FALSE),
  collapse = "\n"
)

required <- c(
  'Sys.getenv("BB8_REPAIR_ADMIN2_STRAT_U5_ONLY", "0")',
  "if (!bb8_repair_admin2_strat_u5_only)",
  "Validated repaired Admin-2 stratified U5MR result",
  'quit(save = "no", status = 0, runLast = FALSE)'
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
    "Targeted Admin-2 stratified U5MR repair/resume path is incomplete: ",
    paste(missing, collapse = ", ")
  )
}

cat("Admin-2 stratified U5MR has a validated targeted repair path.\n")
