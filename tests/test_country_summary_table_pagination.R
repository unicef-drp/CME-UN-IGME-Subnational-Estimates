rmd_file <- file.path("Rcode", "11_CountrySummary.Rmd")
lines <- readLines(rmd_file, warn = FALSE)

coefs_line <- grep("^```\\{r coefs,", lines)
stopifnot(length(coefs_line) == 1L)

preceding <- lines[seq_len(coefs_line - 1L)]
preceding <- trimws(preceding[nzchar(trimws(preceding))])
if (!identical(tail(preceding, 1L), "\\clearpage")) {
  stop(
    "The fixed-effects table must start on a new page so its caption cannot overlap the page number.",
    call. = FALSE
  )
}

cat("Country summary fixed-effects table starts on a new page.\n")
