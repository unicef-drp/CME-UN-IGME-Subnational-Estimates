source("Rcode/_supporting_scripts/project_paths.R")

messages <- character()
test_pdf <- tempfile(fileext = ".pdf")

withCallingHandlers(
  {
    pdf(test_pdf)
    plot(1, 1)
    dev.off()
  },
  message = function(message_condition) {
    messages <<- c(messages, conditionMessage(message_condition))
    invokeRestart("muffleMessage")
  }
)

expected_pdf <- normalizePath(test_pdf, winslash = "/", mustWork = FALSE)
stopifnot(any(grepl(expected_pdf, messages, fixed = TRUE)))

if (requireNamespace("ggplot2", quietly = TRUE)) {
  messages <- character()
  test_ggsave <- tempfile(fileext = ".pdf")
  plot_object <- ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  
  withCallingHandlers(
    ggsave(filename = test_ggsave, plot = plot_object, width = 2, height = 2),
    message = function(message_condition) {
      messages <<- c(messages, conditionMessage(message_condition))
      invokeRestart("muffleMessage")
    }
  )
  
  expected_ggsave <- normalizePath(test_ggsave, winslash = "/", mustWork = FALSE)
  stopifnot(any(grepl(expected_ggsave, messages, fixed = TRUE)))
}

cat("Plot output helpers message full saved paths.\n")
