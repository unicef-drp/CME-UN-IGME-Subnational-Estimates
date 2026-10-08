helper_path <- file.path(
  "Rcode", "_supporting_scripts", "admin1_national_total_plot.R"
)
if (!file.exists(helper_path)) {
  stop("The shared Admin-1 national-total plotting helper is missing.")
}

env <- new.env(parent = globalenv())
sys.source(helper_path, envir = env)

required <- c(
  "admin1_national_total_filename",
  "prepare_admin1_national_total_data",
  "build_admin1_national_total_plot"
)
stopifnot(all(vapply(required, exists, logical(1), envir = env,
                     inherits = FALSE)))

stopifnot(
  identical(
    env$admin1_national_total_filename(
      "Haiti", "u5", "ar1", "unstrat", "bench"
    ),
    "Haiti_Admin1_u5_NationalTotal_ar1_unstrat_bench.pdf"
  ),
  identical(
    env$admin1_national_total_filename(
      "Haiti", "nmr", "ar1", "unstrat", ""
    ),
    "Haiti_Admin1_nmr_NationalTotal_ar1_unstrat.pdf"
  )
)

admin_data <- data.frame(
  region = rep(c("North", "South"), each = 3L),
  years = factor(rep(2000:2002, times = 2L)),
  median = c(0.04, 0.039, 0.038, 0.05, 0.048, 0.046),
  stringsAsFactors = FALSE
)
igme_frame <- data.frame(
  years = 2000:2002,
  median_nmr = c(0.03, 0.029, 0.028),
  median_u5 = c(0.08, 0.077, 0.074),
  stringsAsFactors = FALSE
)

prepared_nmr <- env$prepare_admin1_national_total_data(
  admin_data,
  igme_frame,
  outcome = "nmr"
)
stopifnot(
  isTRUE(all.equal(prepared_nmr$admin$year, rep(2000:2002, times = 2L))),
  isTRUE(all.equal(prepared_nmr$admin$value, admin_data$median * 1000)),
  identical(unique(prepared_nmr$admin$series), c("North", "South")),
  isTRUE(all.equal(prepared_nmr$national$year, 2000:2002)),
  isTRUE(all.equal(
    prepared_nmr$national$value,
    igme_frame$median_nmr * 1000
  )),
  identical(unique(prepared_nmr$national$series), "National total")
)

prepared_u5 <- env$prepare_admin1_national_total_data(
  admin_data,
  igme_frame,
  outcome = "u5"
)
stopifnot(isTRUE(all.equal(
  prepared_u5$national$value,
  igme_frame$median_u5 * 1000
)))

plot <- env$build_admin1_national_total_plot(
  admin_data,
  igme_frame,
  outcome = "u5",
  country_label = "Haiti"
)
stopifnot(inherits(plot, "ggplot"))
plot_build <- ggplot2::ggplot_build(plot)
stopifnot(
  length(plot_build$data) == 2L,
  length(unique(plot_build$data[[1]]$colour)) == 2L,
  !any(plot_build$data[[1]]$colour == "grey65"),
  all(plot_build$data[[2]]$colour == "#000000"),
  identical(plot$labels$colour, NULL),
  identical(plot$theme$legend.position, "bottom")
)
colour_scale <- plot$scales$get_scales("colour")
stopifnot(
  identical(
    as.vector(colour_scale$get_breaks()),
    c("North", "South", "National total")
  ),
  length(unique(unname(colour_scale$map(c("North", "South"))))) == 2L,
  identical(
    unname(colour_scale$map("National total")),
    "#000000"
  )
)

invalid_outcome <- tryCatch(
  env$prepare_admin1_national_total_data(
    admin_data,
    igme_frame,
    outcome = "admin1"
  ),
  error = identity
)
stopifnot(
  inherits(invalid_outcome, "error"),
  grepl("outcome must be 'nmr' or 'u5'", conditionMessage(invalid_outcome),
        fixed = TRUE)
)

report_script <- paste(
  readLines(file.path("Rcode", "11_Report_Plot.R"), warn = FALSE),
  collapse = "\n"
)
summary_script <- paste(
  readLines(file.path("Rcode", "11_CountrySummary.Rmd"), warn = FALSE),
  collapse = "\n"
)
report_required <- c(
  "admin1_national_total_plot.R",
  "admin1_national_total_filename(",
  "build_admin1_national_total_plot("
)
stopifnot(all(vapply(
  report_required, grepl, logical(1), x = report_script, fixed = TRUE
)))
stopifnot(
  grepl("_Admin1_nmr_NationalTotal_", summary_script, fixed = TRUE),
  grepl("_Admin1_u5_NationalTotal_", summary_script, fixed = TRUE),
  regexpr("_Admin1_nmr_NationalTotal_", summary_script, fixed = TRUE)[1] <
    regexpr("_Admin1_nmr_SpaghettiAll_", summary_script, fixed = TRUE)[1],
  regexpr("_Admin1_u5_NationalTotal_", summary_script, fixed = TRUE)[1] <
    regexpr("_Admin1_u5_SpaghettiAll_", summary_script, fixed = TRUE)[1]
)

cat("Shared Admin-1 national-total charts use official national series.\n")
