helper_env <- new.env(parent = baseenv())
sys.source(
  file.path("Rcode", "_supporting_scripts", "urban_frame_matching.R"),
  envir = helper_env
)

latin1_label <- function(bytes) {
  value <- rawToChar(as.raw(bytes))
  Encoding(value) <- "UTF-8"
  value
}

invalid_name <- latin1_label(c(
  0x5a, 0x6f, 0x75, 0x6e, 0x64, 0x77, 0xe9, 0x6f, 0x67, 0x6f
))
repaired_name <- helper_env$repair_utf8_text(invalid_name)
expected_name <- rawToChar(as.raw(c(
  0x5a, 0x6f, 0x75, 0x6e, 0x64, 0x77, 0xc3, 0xa9, 0x6f, 0x67, 0x6f
)))
Encoding(expected_name) <- "UTF-8"

stopifnot(
  !validUTF8(invalid_name),
  validUTF8(repaired_name),
  identical(repaired_name, expected_name)
)

script <- paste(
  readLines(file.path("Rcode", "3_DataProcessing_sf.R"), warn = FALSE),
  collapse = "\n"
)
required_integration <- c(
  "Rcode/_supporting_scripts/urban_frame_matching.R",
  "poly.adm1[[poly.label.adm1]] <- repair_utf8_text(",
  "poly.adm2[[poly.label.adm2]] <- repair_utf8_text("
)
missing_integration <- required_integration[
  !vapply(required_integration, grepl, logical(1), x = script, fixed = TRUE)
]
if (length(missing_integration) > 0L) {
  stop(
    "DHS data processing must repair GeoRepo label encoding before joins: ",
    paste(missing_integration, collapse = ", ")
  )
}

message("GeoRepo UTF-8 boundary-label processing tests passed")
