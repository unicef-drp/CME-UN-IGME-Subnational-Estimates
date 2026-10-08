extract_projection_period_block <- function(path) {
  lines <- readLines(path, warn = FALSE)
  marker <- grep("# ? not sure what for", lines, fixed = TRUE)
  next_section <- grep(
    "##### function to organize posterior draws",
    lines,
    fixed = TRUE
  )

  stopifnot(length(marker) == 1L, length(next_section) == 1L)
  parse(text = lines[(marker + 1L):(next_section - 1L)])
}

run_projection_period_block <- function(path) {
  env <- new.env(parent = baseenv())
  env$beg.year <- 2000L
  env$end.year <- 2025L
  env$end.year.1frame <- 2019L
  env$end.proj.year <- 2025L
  env$beg.period.years <- c(2000L, seq(2002L, 2025L, 3L))
  env$end.period.years <- c(2001L, seq(2004L, 2025L, 3L))

  eval(extract_projection_period_block(path), envir = env)
  env
}

for (path in file.path(
  "Rcode",
  c("6_Comparison_Plot.R", "9_Comparison_Plot.R")
)) {
  result <- run_projection_period_block(path)
  expected_panes <- (
    result$beg.period.years + result$end.period.years
  ) / 2

  stopifnot(
    length(result$beg.proj.years) == 0L,
    length(result$end.proj.years) == 0L,
    identical(result$pane.years, expected_panes),
    length(result$pred.period.idx) == 0L
  )
}

message("Comparison plots handle a survey at the projection horizon.")
