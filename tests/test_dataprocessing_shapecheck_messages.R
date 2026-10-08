script <- readLines("Rcode/3_DataProcessing_sf.R", warn = FALSE)
text <- paste(script, collapse = "\n")

stopifnot(grepl("admin1_neighb_file <- file.path\\(", text))
stopifnot(grepl("admin2_neighb_file <- file.path\\(", text))

helpers <- readLines("Rcode/_supporting_scripts/project_paths.R", warn = FALSE)
helpers_text <- paste(helpers, collapse = "\n")

stopifnot(grepl("dev.off <- function", helpers_text, fixed = TRUE))
stopifnot(grepl('message("Saved figure: ", .plot_output_files', helpers_text, fixed = TRUE))

cat("Data-processing ShapeCheck figures use shared save messages.\n")
