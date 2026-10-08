script <- paste(
  readLines(file.path("Rcode", "_supporting_scripts", "getBB8.R"),
            warn = FALSE),
  collapse = "\n"
)

stopifnot(
  grepl("year.range = beg.year:end.year", script, fixed = TRUE),
  grepl("year.label = beg.year:end.year", script, fixed = TRUE),
  !grepl("year_range = beg.year:end.year", script, fixed = TRUE),
  !grepl("year_label = beg.year:end.year", script, fixed = TRUE)
)

message("getBB8 getSmoothed argument compatibility tests passed")
