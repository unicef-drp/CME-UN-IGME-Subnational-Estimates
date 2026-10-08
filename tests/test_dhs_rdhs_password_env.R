script_text <- paste(readLines(file.path("Rcode", "3_DataProcessing_sf.R"),
                               warn = FALSE),
                     collapse = "\n")

required_fragments <- c(
  'rdhs_password <- resolve_rdhs_password()',
  'DHS password is unavailable.',
  'rdhs_config_path <- "rdhs.json"',
  'prompt = nzchar(rdhs_password)',
  'password_prompt = FALSE'
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = script_text, fixed = TRUE)]
if (length(missing) > 0) {
  stop("DHS setup should use RDHS_USER_PASS noninteractively when available. Missing: ",
       paste(missing, collapse = ", "))
}

if (grepl('password = rdhs_password', script_text, fixed = TRUE)) {
  stop("DHS setup must remain compatible with rdhs 0.8.1, whose set_rdhs_config() has no password argument.")
}

if (!grepl('unlink(rdhs_config_path)', script_text, fixed = TRUE)) {
  stop("The temporary rdhs config containing the in-memory credential must be removed after client setup.")
}

cat("DHS setup honors RDHS_USER_PASS for noninteractive downloads.\n")
