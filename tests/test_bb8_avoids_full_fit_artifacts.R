script_bb8 <- paste(readLines(file.path("Rcode", "8_10_BB8.R"),
                              warn = FALSE),
                    collapse = "\n")

full_stratified_fit_save <- paste0(
  "save\\s*\\(\\s*bb\\.",
  "(natl|adm1|adm2)\\.strat\\.(nmr|u5)(\\.bench)?\\s*,"
)

if (grepl(full_stratified_fit_save, script_bb8, perl = TRUE)) {
  stop("8_10_BB8.R should not save full stratified BB8 fit objects")
}

required_fragments <- c(
  "save(bb.temporals.adm1.strat.nmr",
  "save(bb.hyperpar.adm1.strat.nmr",
  "save(bb.fixed.adm1.strat.nmr",
  "save(bb.res.adm1.strat.nmr",
  "save(bb.temporals.adm1.strat.u5",
  "save(bb.hyperpar.adm1.strat.u5",
  "save(bb.fixed.adm1.strat.u5",
  "save(bb.res.adm1.strat.u5"
)

missing <- required_fragments[!vapply(required_fragments, grepl, logical(1),
                                      x = script_bb8, fixed = TRUE)]
if (length(missing) > 0) {
  stop("8_10_BB8.R should still save compact Admin-1 stratified outputs. Missing: ",
       paste(missing, collapse = ", "))
}

cat("BB8 keeps compact stratified artifacts instead of full fits.\n")
