# Main reference: Readme on https://github.com/alanamcgovern/UN-Subnational-Estimates

# Step 0: Prepare R and SUMMER package
# Also, make sure you are using the most recent version of the SUMMER available on github: 
# https://github.com/richardli/SUMMER. You can install this by running: devtools::install_github('richardli/SUMMER')

# install SUMMER AND INLA

# install.packages(
# 	'INLA',
# 	repos = c(
# 		CRAN = 'https://cloud.r-project.org',
# 		INLA = 'https://inla.r-inla-download.org/R/stable'
# 	),
# 	dependencies = TRUE
# )

required_packages <- c(
  "spdep",
  "SUMMER",
  "geosphere",
  "stringr",
  "tidyverse",
  "rdhs",
  "sf",
  "haven",
  "INLA"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    sprintf(
      "Missing required package(s): %s. Install them before running this script.",
      paste(missing_packages, collapse = ", ")
    ),
    call. = FALSE
  )
}

USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
dir_subnational <- file.path(dir_SP, "UN IGME Subnational/2026 Round Subnational/UN-Subnational-Estimates-main")
source(file.path(dir_subnational, "Rcode/_supporting_scripts/project_paths.R"))

country_from_args <- function(args) {
  if (length(args) == 0) {
    return("")
  }
  country_flag <- grep("^--country=", args, value = TRUE)
  if (length(country_flag) > 0) {
    return(sub("^--country=", "", country_flag[1]))
  }
  country_index <- match("--country", args)
  if (!is.na(country_index) && country_index < length(args)) {
    return(args[[country_index + 1]])
  }
  positional <- args[!startsWith(args, "-")]
  if (length(positional) > 0) {
    return(positional[1])
  }
  ""
}

if (!exists("country", inherits = FALSE) ||
    length(country) == 0 ||
    is.na(country[1]) ||
    !nzchar(as.character(country[1]))) {
  country <- country_from_args(commandArgs(trailingOnly = TRUE))
}
if (!nzchar(country)) {
  country <- Sys.getenv("UN_SUBNATIONAL_COUNTRY", unset = "")
}
if (!nzchar(country)) {
  stop(
    paste0(
      "Set `country` before sourcing Rcode/1_Preperation.R, ",
      "or provide --country COUNTRY."
    ),
    call. = FALSE
  )
}
load.country.info(country)

home.dir <- project_home()
data.dir <- country_data_dir(home.dir, country)
res.dir  <- file.path(home.dir, "Results", country)
if (exists("poly.path")) {
  poly.path <- resolve_country_data_path(poly.path, data.dir)
}



data_dirs <- country_data_dirs(home.dir, country)
ensure_dirs(data_dirs)


# create a folder for Results to store all the results for each country -----------------------------------------------
# including the fitted R models, figures and tables in .csv etc. No actions if the folder is already there.
results_dirs <- country_result_dirs(res.dir, include_admin2 = has_admin2_layer())
ensure_dirs(results_dirs)
