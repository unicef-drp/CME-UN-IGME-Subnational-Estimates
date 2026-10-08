script <- file.path("Rcode", "4_Direct_SmoothDirect_sf.R")
if (!file.exists(script)) {
  stop("Direct-estimate script is missing.")
}

text <- paste(readLines(script, warn = FALSE), collapse = "\n")
stopifnot(
  grepl('Sys.getenv\\("DIRECT_ADMIN2_ONLY"\\)', text),
  grepl("if \\(!direct_admin2_only\\) \\{[[:space:]]*save\\(direct.natl.u5", text),
  grepl("if \\(!direct_admin2_only\\) \\{[[:space:]]*save\\(direct.admin1.u5", text),
  grepl("DIRECT_ADMIN2_ONLY_COMPLETE", text, fixed = TRUE)
)

cat("Direct Admin-2-only recovery hook protects national and Admin-1 files.\n")
