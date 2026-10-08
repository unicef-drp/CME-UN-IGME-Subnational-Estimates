# Every benchmark fit must sit behind the JSON-selected family gate,
# including direct/manual Step 8 and the legacy Step 8b backfill entry point.
check_gates <- function(path, required_families, legacy = FALSE) {
  gates <- list()
  visit <- function(x) {
    if (!is.call(x)) return(invisible(NULL))
    if (identical(x[[1]], as.name('if'))) {
      condition <- paste(deparse(x[[2]]), collapse = ' ')
      if (grepl('final_model$strata.model', condition, fixed = TRUE) &&
          grepl('final_model$bench.model', condition, fixed = TRUE) &&
          startsWith(condition, 'identical(')) {
        gates[[length(gates) + 1L]] <<- x
      }
    }
    parts <- as.list(x)[-1L]
    for (i in seq_along(parts)) {
      if (!identical(parts[[i]], quote(expr = ))) visit(parts[[i]])
    }
  }
  for (x in as.list(parse(path))) visit(x)
  for (family in required_families) {
    matched <- Filter(function(gate) {
      env <- new.env(parent = baseenv())
      env$final_model <- list(strata.model = family, bench.model = 'bench')
      if (!isTRUE(eval(gate[[2]], env))) return(FALSE)
      env$final_model$strata.model <- if (family == 'strat') 'unstrat' else 'strat'
      stopifnot(identical(eval(gate[[2]], env), FALSE))
      env$final_model <- list(strata.model = family, bench.model = 'none')
      stopifnot(identical(eval(gate[[2]], env), FALSE))
      body <- paste(deparse(gate[[3]]), collapse = ' ')
      grepl(if (legacy) 'run_admin1_unstrat_benchmark' else 'benchmark_admin_result', body, fixed = TRUE)
    }, gates)
    stopifnot(length(matched) == 1L)
  }
}
check_gates('Rcode/8_10_BB8.R', c('strat', 'unstrat'))
check_gates('Rcode/8_10_Run_Unstrat_Admin1_Benchmarks.R', 'unstrat', TRUE)
cat('All benchmarking entry points respect final_model.\n')

