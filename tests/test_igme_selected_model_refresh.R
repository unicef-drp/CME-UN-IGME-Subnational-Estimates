source('Rcode/_supporting_scripts/pipeline_runner.R')
source('Rcode/_supporting_scripts/igme_refresh_runner.R')
root <- normalizePath('.', winslash = '/')
for (branch in c('strat', 'unstrat')) {
  selected <- list(strata.model = branch, bench.model = 'bench', time.model = 'ar1')
  for (adm2 in c(FALSE, TRUE)) {
    contract <- igme_refresh_benchmark_contract(root, 'Fixture', adm2,
                                               final_model = selected)
    stopifnot(nrow(contract) == if (adm2) 4L else 2L,
              identical(unique(contract$family),
                        if (branch == 'strat') 'strat' else 'allsurveys'))
  }
}
stopifnot(inherits(try(igme_refresh_benchmark_contract(root, 'Fixture', FALSE,
  final_model = list(strata.model = 'unknown', bench.model = 'bench')),
  silent = TRUE), 'try-error'))
steps <- make_igme_refresh_steps(root)
stopifnot(identical(steps[[1]]$env[['BB8_REFRESH_SELECTED_ONLY']], '1'))
# Inspect the parsed production gates, not a duplicate implementation.
exprs <- parse('Rcode/8_10_BB8.R')
for (gate in c('bb8_refresh_strat', 'bb8_refresh_allsurveys')) {
  blocks <- Filter(function(x) is.call(x) && identical(x[[1]], as.name('if')) &&
                     identical(x[[2]], as.name(gate)), as.list(exprs))
  stopifnot(length(blocks) == 1L)
  body <- paste(deparse(blocks[[1]][[3]]), collapse = '\n')
  stopifnot(grepl('getBB8', body, fixed = TRUE))
  if (gate == 'bb8_refresh_strat') {
    stopifnot(grepl('bb.res.adm1.strat.nmr.bench', body, fixed = TRUE),
              !grepl('bb.res.adm1.unstrat.nmr.allsurveys.bench', body, fixed = TRUE))
  } else {
    stopifnot(grepl('bb.res.adm1.unstrat.nmr.allsurveys.bench', body, fixed = TRUE),
              !grepl('bb.res.adm1.strat.nmr.bench', body, fixed = TRUE))
  }
}
cat('Selected model refresh tests passed.\n')
