script_text <- paste(readLines("Rcode/11_Report_Plot.R", warn = FALSE), collapse = "\n")

stopifnot(grepl("adm1_on_adm2 <- paste0(\"poly.adm2[['\",", script_text, fixed = TRUE))
stopifnot(!grepl("adm1_on_adm2 <- paste0(poly.label.adm2, \"$\",", script_text, fixed = TRUE))

cat("Report plots derive Admin2 parent labels from the Admin1 column on poly.adm2.\n")
