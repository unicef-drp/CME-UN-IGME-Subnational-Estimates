# Step 4 uses this exact legacy sentinel to end DIRECT_ADMIN2_ONLY mode.
# Never swallow other errors, and never accept completion without validation.
complete_admin2_direct <- function(run, validate) {
  tryCatch(run(), error = function(e) {
    if (!identical(conditionMessage(e), 'DIRECT_ADMIN2_ONLY_COMPLETE')) stop(e)
  })
  if (!isTRUE(validate())) stop('Admin-2 direct output validation failed.', call. = FALSE)
  TRUE
}
