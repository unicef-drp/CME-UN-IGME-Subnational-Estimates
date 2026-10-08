script_path <- file.path("Rcode", "3_DataProcessing_sf.R")
stopifnot(file.exists(script_path))

expressions <- parse(script_path)
last_expression <- expressions[[length(expressions)]]
expected <- quote(message("Data processing completed successfully for ", country, "."))

stopifnot(identical(last_expression, expected))

cat("Data-processing script ends with a successful-completion message.\n")
