qmd <- paste(readLines("Rcode/9_Comparison_Plot.qmd", warn = FALSE), collapse = "\n")

if (!grepl('hovermode\\s*=\\s*"closest"', qmd)) {
  stop("BB8 dashboard charts should use closest-point hover so tooltips stay readable.")
}

if (!grepl("hoverlabel\\s*=\\s*list", qmd)) {
  stop("BB8 dashboard charts should set readable Plotly hoverlabel styling.")
}

if (grepl("title = list\\(text = title_text", qmd)) {
  stop("BB8 dashboard chart titles should not be embedded inside Plotly figures.")
}

if (grepl("bb8-figure-title", qmd, fixed = TRUE) ||
    grepl("external_title_plot", qmd, fixed = TRUE) ||
    grepl("htmltools::tagList", qmd, fixed = TRUE)) {
  stop("BB8 dashboard chart titles should be Quarto headings, not cell-output headings.")
}

expected_chart_headings <- c(
  "# Stratified vs unstratified",
  "# benchmarked versus unbenchmarked",
  "# Direct estimates",
  "## Raw direct estimates",
  "## Smoothed direct estimates",
  "# All Available Methods",
  "## Available method table"
)

missing_headings <- expected_chart_headings[
  !vapply(expected_chart_headings, grepl, logical(1), x = qmd, fixed = TRUE)
]
if (length(missing_headings) > 0) {
  stop(
    "BB8 dashboard sections should render as requested Quarto headings: ",
    paste(missing_headings, collapse = "; ")
  )
}

if (!grepl("::: {.panel-tabset}", qmd, fixed = TRUE)) {
  stop("BB8 dashboard should use Quarto tabsets for U5MR/NMR chart switching.")
}

first_u5mr <- regexpr("## U5MR", qmd, fixed = TRUE)[[1]]
first_nmr <- regexpr("## NMR", qmd, fixed = TRUE)[[1]]
if (first_u5mr < 0 || first_nmr < 0 || first_u5mr > first_nmr) {
  stop("BB8 dashboard tabs should default to U5MR by placing U5MR before NMR.")
}

if (!grepl('plot_excluded_methods <- c("natl.sd.yearly")', qmd, fixed = TRUE)) {
  stop("BB8 dashboard should explicitly exclude natl.sd.yearly from plotted methods.")
}

if (!grepl(
  "filter(outcome == outcome_name, !method %in% plot_excluded_methods)",
  qmd,
  fixed = TRUE
)) {
  stop("BB8 dashboard timeseries plots should remove excluded methods before plotting.")
}

if (!grepl("y = 1.08", qmd, fixed = TRUE) ||
    !grepl('yanchor = "bottom"', qmd, fixed = TRUE)) {
  stop("BB8 dashboard charts should place legends above the plot so they are visible without scrolling.")
}

if (!grepl("margin = list(l = 100, r = 40, t = 135, b = 90)", qmd, fixed = TRUE)) {
  stop("BB8 dashboard charts should reserve top margin for the visible legend.")
}

if (!grepl(".plotly.html-widget", qmd, fixed = TRUE) ||
    !grepl("height: 780px !important", qmd, fixed = TRUE)) {
  stop("BB8 dashboard plot widgets should be tall enough to avoid internal vertical scrolling.")
}

if (!grepl("dashboard_plot_height <- 780L", qmd, fixed = TRUE) ||
    !grepl("height = dashboard_plot_height", qmd, fixed = TRUE)) {
  stop("BB8 dashboard Plotly layout height should match the taller widget height.")
}

if (!grepl('palette["igme"] <- "#D62728"', qmd, fixed = TRUE)) {
  stop("Every dashboard comparison chart should render the IGME series in red.")
}

if (!grepl("dashboard_line_width <- 3", qmd, fixed = TRUE) ||
    !grepl("dashboard_igme_line_width <- 5", qmd, fixed = TRUE)) {
  stop("Dashboard charts should define normal and emphasized IGME line widths.")
}

if (!grepl(
  'line_width <- if (identical(method_name, "igme"))',
  qmd,
  fixed = TRUE
) || !grepl(
  "dashboard_igme_line_width else dashboard_line_width",
  qmd,
  fixed = TRUE
)) {
  stop("Comparison charts should widen only the IGME method trace.")
}

if (!grepl("make_timeseries <- function(data, outcome_name, ribbon_methods = \"igme\")", qmd, fixed = TRUE)) {
  stop("BB8 dashboard timeseries helper should allow sections to choose uncertainty ribbon methods.")
}

if (!grepl("ribbon_methods = benchmarked_stratified_methods", qmd,
           fixed = TRUE) ||
    !grepl("ribbon_methods = unbenchmarked_stratified_methods", qmd,
           fixed = TRUE)) {
  stop(paste(
    "Stratified vs unstratified charts should draw uncertainty bands for",
    "both benchmarked and unbenchmarked displayed methods."
  ))
}

if (!grepl("ribbon_methods = benchmark_methods", qmd, fixed = TRUE)) {
  stop("Benchmarked versus unbenchmarked charts should draw uncertainty bands for the displayed methods.")
}

legendgroup_hits <- gregexpr("legendgroup = method_name", qmd, fixed = TRUE)[[1]]
if (identical(legendgroup_hits, -1L) || length(legendgroup_hits) < 4L) {
  stop(paste(
    "Every dashboard line and uncertainty-band trace should share its",
    "method-specific Plotly legend group."
  ))
}

if (!grepl('groupclick = "togglegroup"', qmd, fixed = TRUE)) {
  stop("Dashboard legend clicks should toggle each line and uncertainty band together.")
}

direct_plot_start <- regexpr("make_direct_plot <- function", qmd, fixed = TRUE)[[1]]
direct_plot_end <- regexpr("direct_estimates_df <- build_direct_estimates", qmd, fixed = TRUE)[[1]]
if (direct_plot_start < 0 || direct_plot_end < 0 || direct_plot_end <= direct_plot_start) {
  stop("Could not find the raw direct estimate plot helper.")
}
direct_plot_helper <- substr(qmd, direct_plot_start, direct_plot_end - 1)
if (grepl('mode = "markers"', direct_plot_helper, fixed = TRUE) ||
    grepl('mode = "lines+markers"', direct_plot_helper, fixed = TRUE)) {
  stop("Raw direct estimate plots should be line-only, without dot markers.")
}

if (!grepl("datatable_options_for\\s*<-\\s*function", qmd)) {
  stop("BB8 dashboard tables should build options through a helper that can set defaults.")
}

if (!grepl('list\\(search\\s*=\\s*"U5MR"\\)', qmd)) {
  stop("BB8 dashboard tables with an outcome column should default-filter to U5MR.")
}

datatable_calls <- gregexpr("DT::datatable\\(", qmd)[[1]]
if (identical(datatable_calls, -1L) || length(datatable_calls) != 1) {
  stop("The dashboard should render exactly one table.")
}

if (!grepl("options\\s*=\\s*datatable_options_for\\(available_method_table\\)", qmd)) {
  stop("The available method table should use the default U5MR table options.")
}
