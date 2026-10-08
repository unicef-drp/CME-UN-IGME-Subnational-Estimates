script <- paste(readLines(file.path("Rcode", "9_Diagnostic_Plots.R"),
                          warn = FALSE),
                collapse = "\n")

required_models <- c(
  "natl_strat_nmr",
  "adm1_strat_nmr",
  "adm1_unstrat_nmr",
  "natl_strat_u5",
  "adm1_strat_u5",
  "adm1_unstrat_u5"
)

missing_models <- required_models[!vapply(required_models, function(model) {
  grepl(paste0('"', model, '"'), script, fixed = TRUE)
}, logical(1))]

if (length(missing_models) > 0) {
  stop("9_Diagnostic_Plots.R should generate diagnostic plots for both NMR and U5MR model sets. Missing: ",
       paste(missing_models, collapse = ", "))
}

if (!grepl("models <- model.candidates[vapply(model.candidates", script, fixed = TRUE)) {
  stop("9_Diagnostic_Plots.R should filter diagnostic candidates to available result files.")
}

if (!grepl("open_plot_pdf <- function(file)", script, fixed = TRUE)) {
  stop("9_Diagnostic_Plots.R should fall back to timestamped output when an existing PDF is locked.")
}

cat("Diagnostic plot model list includes both NMR and U5MR outputs.\n")
