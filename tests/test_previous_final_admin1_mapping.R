env <- new.env(parent = globalenv())
sys.source(
  file.path("Rcode", "_supporting_scripts", "project_paths.R"),
  envir = env
)
sys.source(
  file.path("Rcode", "12_Previous_Final_Comparison.R"),
  envir = env
)

default_admin_levels <- eval(
  formals(env$run_previous_final_comparison)$admin_levels,
  envir = env
)
stopifnot(identical(default_admin_levels, "Admin1"))

required_crosswalk_functions <- c(
  "normalize_region_name_key",
  "previous_final_crosswalk_path",
  "load_previous_final_region_crosswalk",
  "map_previous_final_regions"
)
stopifnot(all(vapply(
  required_crosswalk_functions,
  exists,
  logical(1),
  envir = env,
  inherits = FALSE
)))

current_lookup <- data.frame(
  region = c("admin1_1", "admin1_6"),
  region_name = c("West", "Centre"),
  stringsAsFactors = FALSE
)
previous <- data.frame(
  admin_level = "Admin1",
  region = "admin1_1",
  region_name = "Centre",
  outcome = "U5MR",
  years = 2010,
  median = 100,
  stringsAsFactors = FALSE
)
crosswalk <- data.frame(
  admin_level = "Admin1",
  previous_internal = "admin1_1",
  previous_name = "Centre",
  current_internal = "admin1_6",
  current_name = "Centre",
  stringsAsFactors = FALSE
)

mapped <- env$map_previous_final_regions(
  previous = previous,
  current_lookup = current_lookup,
  crosswalk = crosswalk,
  admin_level = "Admin1"
)
stopifnot(
  identical(mapped$region, "admin1_6"),
  identical(mapped$region_name, "Centre")
)

name_matched <- env$map_previous_final_regions(
  previous = transform(previous, region_name = "West"),
  current_lookup = current_lookup,
  crosswalk = NULL,
  admin_level = "Admin1"
)
stopifnot(
  identical(name_matched$region, "admin1_1"),
  identical(name_matched$region_name, "West")
)

unmatched_error <- tryCatch(
  env$map_previous_final_regions(
    previous = transform(previous, region_name = "Unknown department"),
    current_lookup = current_lookup,
    crosswalk = NULL,
    admin_level = "Admin1"
  ),
  error = identity
)
stopifnot(
  inherits(unmatched_error, "error"),
  grepl("Unmatched previous-final Admin-1 region", conditionMessage(unmatched_error),
        fixed = TRUE)
)

duplicate_error <- tryCatch(
  env$map_previous_final_regions(
    previous = previous,
    current_lookup = current_lookup,
    crosswalk = rbind(crosswalk, crosswalk),
    admin_level = "Admin1"
  ),
  error = identity
)
stopifnot(
  inherits(duplicate_error, "error"),
  grepl("duplicate previous-region keys", conditionMessage(duplicate_error),
        fixed = TRUE)
)

missing_current_name_error <- tryCatch(
  env$validate_previous_final_region_crosswalk(
    crosswalk[, setdiff(names(crosswalk), "current_name"), drop = FALSE],
    admin_level = "Admin1"
  ),
  error = identity
)
stopifnot(
  inherits(missing_current_name_error, "error"),
  grepl("current_name", conditionMessage(missing_current_name_error), fixed = TRUE)
)

haiti_crosswalk_path <- file.path(
  "Info", "PreviousFinalRegionCrosswalks", "Haiti_2023_to_2026.csv"
)
stopifnot(file.exists(haiti_crosswalk_path))
haiti_crosswalk <- utils::read.csv(
  haiti_crosswalk_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
stopifnot(
  nrow(haiti_crosswalk) == 10L,
  "current_name" %in% names(haiti_crosswalk),
  identical(
    haiti_crosswalk$current_internal[haiti_crosswalk$previous_name == "Ouest"],
    "admin1_1"
  )
)

benin_crosswalk_path <- file.path(
  "Info", "PreviousFinalRegionCrosswalks", "Benin_2023_to_2026.csv"
)
stopifnot(file.exists(benin_crosswalk_path))
benin_crosswalk <- env$load_previous_final_region_crosswalk(
  home_dir = getwd(),
  country = "Benin",
  admin_level = "Admin1"
)
benin_lookup <- env$load_country_admin_lookup(
  home_dir = getwd(),
  country = "Benin",
  admin_level = "Admin1"
)
benin_previous <- data.frame(
  region = benin_crosswalk$previous_internal,
  region_name = benin_crosswalk$previous_name,
  stringsAsFactors = FALSE
)
benin_mapped <- env$map_previous_final_regions(
  previous = benin_previous,
  current_lookup = benin_lookup,
  crosswalk = benin_crosswalk,
  admin_level = "Admin1"
)
stopifnot(
  nrow(benin_crosswalk) == 12L,
  identical(
    benin_mapped$region[benin_previous$region_name == "Atakora"],
    "admin1_2"
  ),
  identical(
    benin_mapped$region[benin_previous$region_name == "Kouffo"],
    "admin1_6"
  ),
  identical(
    benin_mapped$region[benin_previous$region_name == "Donga"],
    "admin1_7"
  )
)

expected_crosswalks <- list(
  Benin = list(rows = 12L, previous = "Kouffo", current = "admin1_6"),
  Haiti = list(rows = 10L, previous = "Ouest", current = "admin1_1"),
  Madagascar = list(rows = 6L, previous = "Toliary", current = "admin1_4"),
  Liberia = list(rows = 15L, previous = "Gbapolu", current = "admin1_3"),
  Sierra_Leone = list(
    rows = 5L,
    previous = "Northwestern Province",
    current = "admin1_2"
  )
)
for (country_name in names(expected_crosswalks)) {
  expectation <- expected_crosswalks[[country_name]]
  crosswalk_path <- file.path(
    "Info", "PreviousFinalRegionCrosswalks",
    paste0(country_name, "_2023_to_2026.csv")
  )
  stopifnot(file.exists(crosswalk_path))
  country_crosswalk <- env$load_previous_final_region_crosswalk(
    home_dir = getwd(),
    country = country_name,
    admin_level = "Admin1"
  )
  current_lookup <- env$load_country_admin_lookup(
    home_dir = getwd(),
    country = country_name,
    admin_level = "Admin1"
  )
  current_match <- match(
    country_crosswalk$current_internal,
    current_lookup$region
  )
  stopifnot(
    nrow(country_crosswalk) == expectation$rows,
    "current_name" %in% names(country_crosswalk),
    all(!is.na(country_crosswalk$current_name)),
    all(nzchar(country_crosswalk$current_name)),
    identical(
      country_crosswalk$current_name,
      current_lookup$region_name[current_match]
    ),
    identical(
      country_crosswalk$current_internal[
        country_crosswalk$previous_name == expectation$previous
      ],
      expectation$current
    )
  )
}

crisis_root <- file.path(tempdir(), "previous_final_crisis_path")
crisis_res <- file.path(crisis_root, "Results", "Testland")
base_u5 <- file.path(
  crisis_res, "Betabinomial", "U5MR",
  "Testland_res_adm1_unstrat_u5_allsurveys_bench.rda"
)
base_nmr <- file.path(
  crisis_res, "Betabinomial", "NMR",
  "Testland_res_adm1_unstrat_nmr_allsurveys_bench.rda"
)
dir.create(dirname(base_u5), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(base_nmr), recursive = TRUE, showWarnings = FALSE)
fixture <- data.frame(region = "admin1_1", years = 2010, median = 0.1)
save(fixture, file = base_u5)
save(fixture, file = base_nmr)
crisis_u5 <- sub("[.]rda$", "_crisis.rda", base_u5)
save(fixture, file = crisis_u5)

env$doCrisisAdj <- TRUE
selected_u5 <- env$current_admin_result_path(
  crisis_res, "Testland", "U5MR", "Admin1",
  strata_model = "unstrat", benchmarked = TRUE, all_surveys = TRUE
)
selected_nmr <- env$current_admin_result_path(
  crisis_res, "Testland", "NMR", "Admin1",
  strata_model = "unstrat", benchmarked = TRUE, all_surveys = TRUE
)
stopifnot(
  identical(basename(selected_u5), basename(crisis_u5)),
  identical(basename(selected_nmr), basename(base_nmr))
)

env$doCrisisAdj <- FALSE
selected_u5_no_crisis <- env$current_admin_result_path(
  crisis_res, "Testland", "U5MR", "Admin1",
  strata_model = "unstrat", benchmarked = TRUE, all_surveys = TRUE
)
stopifnot(identical(basename(selected_u5_no_crisis), basename(base_u5)))

unlink(crisis_root, recursive = TRUE)
cat("Previous-final Admin-1 mapping and crisis selection are identity-safe.\n")
