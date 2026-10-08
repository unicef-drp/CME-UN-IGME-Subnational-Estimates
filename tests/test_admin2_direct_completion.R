source('Rcode/_supporting_scripts/admin2_direct_completion.R')
validated <- FALSE
answer <- complete_admin2_direct(
  function() stop('DIRECT_ADMIN2_ONLY_COMPLETE', call. = FALSE),
  function() { validated <<- TRUE; TRUE }
)
stopifnot(validated, identical(answer, TRUE))
for (message in c('cannot open the connection', 'DIRECT_ADMIN2_ONLY_COMPLETE extra')) {
  validated <- FALSE
  err <- tryCatch(complete_admin2_direct(function() stop(message),
    function() { validated <<- TRUE; TRUE }), error = identity)
  stopifnot(inherits(err, 'error'), identical(conditionMessage(err), message), !validated)
}
err <- tryCatch(complete_admin2_direct(
  function() stop('DIRECT_ADMIN2_ONLY_COMPLETE'), function() stop('Missing output')),
  error = identity)
stopifnot(inherits(err, 'error'), conditionMessage(err) == 'Missing output')
err <- tryCatch(complete_admin2_direct(function() NULL, function() FALSE), error = identity)
stopifnot(inherits(err, 'error'))
cat('Admin-2 direct completion handling tests passed.\n')
