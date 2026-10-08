script <- paste(
  readLines(file.path("Rcode", "3_DataProcessing_sf.R"), warn = FALSE),
  collapse = "\n"
)

required_parent_repair <- c(
  "poly.label.adm1 %in% names(poly.adm2)",
  "poly.adm2[[poly.label.adm1]] <- repair_utf8_text("
)
missing_parent_repair <- required_parent_repair[
  !vapply(required_parent_repair, grepl, logical(1), x = script, fixed = TRUE)
]

if (length(missing_parent_repair) > 0L) {
  stop(
    "Admin-2 boundaries must normalize their Admin-1 parent labels before spatial joins: ",
    paste(missing_parent_repair, collapse = ", ")
  )
}

message("Admin-2 parent-label normalization integration test passed")
