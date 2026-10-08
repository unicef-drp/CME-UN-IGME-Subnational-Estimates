script <- paste(
  readLines(file.path(
    "Rcode", "_supporting_scripts", "smoothCluster_mod.R"
  ), warn = FALSE),
  collapse = "\n"
)

stopifnot(
  grepl("year.label = year_label", script, fixed = TRUE),
  grepl("year_label = year_label", script, fixed = TRUE),
  grepl("year.range = NA", script, fixed = TRUE),
  grepl("year_range = NA", script, fixed = TRUE)
)

message("smoothCluster_mod SUMMER metadata compatibility tests passed")
