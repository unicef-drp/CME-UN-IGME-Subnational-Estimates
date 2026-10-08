script <- readLines("Rcode/4_Direct_SmoothDirect_sf.R", warn = FALSE)
helper <- readLines("Rcode/_supporting_scripts/project_paths.R", warn = FALSE)

stopifnot(any(grepl("project_paths.R", head(script, 30), fixed = TRUE)))

pdf_calls <- grep("\\bpdf\\s*\\(", script, value = TRUE)
dev_off_lines <- grep("\\bdev\\.off\\s*\\(", script)
message_lines <- grep('message\\("Saved figure: ", last_plot_file\\(\\)\\)', script)

stopifnot(length(pdf_calls) > 0)
stopifnot(length(pdf_calls) == length(dev_off_lines))
stopifnot(length(dev_off_lines) == length(message_lines))
stopifnot(all(script[dev_off_lines + 1] == 'message("Saved figure: ", last_plot_file())'))
stopifnot(any(grepl("un_subnational_auto_plot_messages = FALSE", script, fixed = TRUE)))
stopifnot(!any(grepl("grDevices::pdf|ggplot2::ggsave", script)))
stopifnot(any(grepl("dev.off <- function", helper, fixed = TRUE)))
stopifnot(any(grepl("last_plot_file <- function", helper, fixed = TRUE)))

cat("Direct and smoothed-direct plot outputs message after every dev.off().\n")
