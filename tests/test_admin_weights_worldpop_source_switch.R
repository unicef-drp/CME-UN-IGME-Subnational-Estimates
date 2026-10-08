old_worldpop_home <- Sys.getenv("UN_SUBNATIONAL_WORLDPOP_HOME", unset = NA_character_)
on.exit({
  if (is.na(old_worldpop_home)) {
    Sys.unsetenv("UN_SUBNATIONAL_WORLDPOP_HOME")
  } else {
    Sys.setenv(UN_SUBNATIONAL_WORLDPOP_HOME = old_worldpop_home)
  }
}, add = TRUE)

test_root <- tempfile("worldpop-source-switch-")
Sys.setenv(UN_SUBNATIONAL_WORLDPOP_HOME = test_root)

source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))

expected_2014 <- file.path(
  normalizePath(test_root, winslash = "/", mustWork = FALSE),
  "Global1_2000_2020_aligned",
  "Ethiopia_extracted",
  "2014",
  "ETH",
  "eth_f_1_2014_constrained_1km.tif"
)
expected_2015 <- file.path(
  normalizePath(test_root, winslash = "/", mustWork = FALSE),
  "Global2_2015_2030",
  "Ethiopia",
  "eth_m_01_2015_CN_1km_R2025A_UA_v1.tif"
)

actual_2014 <- worldpop_population_age_sex_file(
  year = 2014,
  sex = "f",
  age = 1,
  country = "Ethiopia",
  iso0 = "ETH"
)
actual_2015 <- worldpop_population_age_sex_file(
  year = 2015,
  sex = "m",
  age = 1,
  country = "Ethiopia",
  iso0 = "ETH"
)

stopifnot(identical(actual_2014, expected_2014))
stopifnot(identical(actual_2015, expected_2015))
stopifnot(identical(worldpop_population_source_name(2014),
                    "Global1_2000_2020_aligned"))
stopifnot(identical(worldpop_population_source_name(2015),
                    "Global2_2015_2030"))

cat("Admin weights switch WorldPop sources between 2014 and 2015.\n")
