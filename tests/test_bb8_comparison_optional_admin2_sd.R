script_text <- paste(
  readLines(file.path("Rcode", "9_Comparison_Plot.R"), warn = FALSE),
  collapse = "\n"
)

required_fragments <- c(
  "admin2.sd.nmr.file <- file.path",
  "admin2.sd.u5.file <- file.path",
  "if (file.exists(admin2.sd.nmr.file))",
  "if (file.exists(admin2.sd.u5.file))",
  "Skipping missing Admin-2 period smoothed-direct NMR",
  "Skipping missing Admin-2 period smoothed-direct U5MR"
)
missing <- required_fragments[!vapply(
  required_fragments,
  grepl,
  logical(1),
  x = script_text,
  fixed = TRUE
)]
if (length(missing) > 0) {
  stop(
    "BB8 comparison must guard optional Admin-2 smoothed-direct outcomes independently: ",
    paste(missing, collapse = ", ")
  )
}

paired_guard <-
  "file.exists(admin2.sd.nmr.file) && file.exists(admin2.sd.u5.file)"
if (grepl(paired_guard, script_text, fixed = TRUE)) {
  stop("NMR and U5MR Admin-2 smoothed-direct files must not require each other.")
}

cat("BB8 comparison treats optional Admin-2 smoothed-direct outcomes independently.\n")
