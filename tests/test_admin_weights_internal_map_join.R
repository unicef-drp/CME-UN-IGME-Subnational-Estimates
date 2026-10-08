script <- paste(
  readLines(file.path("Rcode", "5_Admin_Weights_sf.R"), warn = FALSE),
  collapse = "\n"
)

required_code <- c(
  "poly.adm1$regionPlot <- admin1.names$Internal",
  "poly.adm2$regionPlot <- admin2.names$Internal",
  "weight.adm1.u1$regionPlot <- weight.adm1.u1$region",
  "weight.adm1.u5$regionPlot <- weight.adm1.u5$region",
  "weight.adm2.u1$regionPlot <- weight.adm2.u1$region",
  "weight.adm2.u5$regionPlot <- weight.adm2.u5$region",
  'by.geo = "regionPlot"'
)
missing_code <- required_code[
  !vapply(required_code, grepl, logical(1), x = script, fixed = TRUE)
]
if (length(missing_code) > 0L) {
  stop(
    "Admin-weight maps must join on stable internal region IDs: ",
    paste(missing_code, collapse = ", ")
  )
}

message("Admin-weight internal map-join tests passed")
