# Country-level refresh after a national IGME release update.
#
# Preview (validation and inventory only):
#   Rscript --vanilla Rcode/run_igme_refresh.R --country Cameroon --preview
# Production (authorized replacement and downstream rebuild):
#   Rscript --vanilla Rcode/run_igme_refresh.R --country Cameroon --production

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg)) {
  script_path <- normalizePath(
    sub("^--file=", "", script_arg[[1]]),
    winslash = "/",
    mustWork = TRUE
  )
  project_dir <- dirname(dirname(script_path))
} else {
  project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(
  project_dir, "Rcode", "_supporting_scripts", "pipeline_runner.R"
))
source(file.path(
  project_dir, "Rcode", "_supporting_scripts", "igme_refresh_runner.R"
))

COUNTRY <- "Angola"

args <- parse_igme_refresh_args(
  args = character(),
  country = COUNTRY,
  mode = "production"
)

if (isTRUE(args$help)) {
  cat(
    "Usage: Rscript --vanilla Rcode/run_igme_refresh.R --country COUNTRY [--preview|--production] [--report-year YEAR] [--skip-summary]\n",
    "\n",
    "Preview validates the country configuration and active/staged IGME release,\n",
    "then inventories affected model and report artifacts without changing them.\n",
    "Production backs up exact live targets, promotes a complete newer staged\n",
    "release when present, refreshes only the JSON-selected benchmark family\n",
    "and configured crisis models,\n",
    "then rebuilds the dashboard, diagnostics, report plots, and PDF.\n",
    "The --skip-summary option is preview-only.\n",
    "\n",
    "Examples:\n",
    "  Rscript --vanilla Rcode/run_igme_refresh.R --country Cameroon --preview\n",
    "  Rscript --vanilla Rcode/run_igme_refresh.R --country Cameroon --production\n",
    sep = ""
  )
  quit(status = 0L, save = "no")
}

run_igme_refresh(
  country = args$country,
  mode = args$mode,
  render_summary = args$render_summary,
  report_year = args$report_year,
  project_dir = project_dir
)
