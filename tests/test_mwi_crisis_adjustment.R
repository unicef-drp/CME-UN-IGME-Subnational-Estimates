script_path <- file.path(
  "Data", "Crisis_Adjustment", "prepare_mwi_fao_proxy.R"
)
stopifnot(file.exists(script_path))
source(script_path, local = FALSE)

expect_error <- function(expr, pattern) {
  message <- tryCatch(
    {
      force(expr)
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )
  stopifnot(!is.na(message), grepl(pattern, message, ignore.case = TRUE))
}

national <- data.frame(
  country = "Malawi",
  years = 2001L,
  crisis_d0_5 = 100,
  crisis_d0 = 60,
  crisis_d1_4 = 40,
  pop_0 = 1000,
  pop_1_4 = 4000,
  stringsAsFactors = FALSE
)

district_proxy <- data.frame(
  admin1_georepo = c("Central Region", "Northern Region"),
  source_district = c("A", "B"),
  beneficiaries = c(75, 25),
  stringsAsFactors = FALSE
)

successor_crosswalk <- data.frame(
  source_district = c("A", "A", "B"),
  georepo = c("A Rural", "A City", "B"),
  stringsAsFactors = FALSE
)

current_areas <- data.frame(
  country = "Malawi",
  georepo = c("A Rural", "A City", "B"),
  region = paste0("admin2_", 1:3),
  admin1_georepo = c("Central Region", "Central Region", "Northern Region"),
  admin1_region = c("admin1_1", "admin1_1", "admin1_2"),
  years = 2001L,
  pop_0 = c(200, 100, 100),
  pop_1_4 = c(300, 400, 300),
  stringsAsFactors = FALSE
)

allocated <- allocate_mwi_crisis_deaths(
  national = national,
  district_proxy = district_proxy,
  successor_crosswalk = successor_crosswalk,
  current_areas = current_areas
)

admin2 <- allocated$admin2_audit
admin1 <- allocated$admin1_audit

stopifnot(
  abs(sum(admin2$ed_0_1) - 60) < 1e-10,
  abs(sum(admin2$ed_1_5) - 40) < 1e-10,
  abs(sum(admin1$ed_0_1) - 60) < 1e-10,
  abs(sum(admin1$ed_1_5) - 40) < 1e-10,
  abs(admin1$ed_0_1[admin1$georepo == "Central Region"] - 45) < 1e-10,
  abs(admin1$ed_1_5[admin1$georepo == "Central Region"] - 30) < 1e-10,
  abs(admin2$ed_0_1[admin2$georepo == "A Rural"] /
      admin2$ed_0_1[admin2$georepo == "A City"] - 2) < 1e-10,
  abs(admin2$ed_1_5[admin2$georepo == "A Rural"] /
      admin2$ed_1_5[admin2$georepo == "A City"] - 0.75) < 1e-10
)

expect_error(
  allocate_mwi_crisis_deaths(
    national = national,
    district_proxy = rbind(district_proxy, district_proxy[1, ]),
    successor_crosswalk = successor_crosswalk,
    current_areas = current_areas
  ),
  "duplicate"
)

expect_error(
  allocate_mwi_crisis_deaths(
    national = national,
    district_proxy = district_proxy,
    successor_crosswalk = successor_crosswalk[-1, ],
    current_areas = current_areas
  ),
  "crosswalk"
)

integration <- prepare_mwi_crisis_adjustment(
  project_root = normalizePath(".", winslash = "/", mustWork = TRUE),
  write_output = FALSE,
  quiet = TRUE
)

df <- integration$df_MWI
admin1_audit <- integration$mwi_crisis_admin1_audit
admin2_audit <- integration$mwi_crisis_admin2_audit
metadata <- integration$mwi_crisis_allocation_metadata

stopifnot(
  identical(
    names(df),
    c("country", "level", "georepo", "region", "years", "ed_0_1", "ed_1_5")
  ),
  identical(sort(unique(df$years)), 2001L),
  nrow(df[df$level == "admin1", ]) == 3L,
  nrow(df[df$level == "admin2", ]) == 32L,
  !anyDuplicated(df[c("level", "region", "years")]),
  all(is.finite(df$ed_0_1)),
  all(is.finite(df$ed_1_5)),
  all(df$ed_0_1 >= 0),
  all(df$ed_1_5 >= 0),
  identical(metadata$allocated_years, 2001L),
  identical(metadata$source_district_count, 27L),
  identical(metadata$current_admin2_count, 32L),
  identical(metadata$total_proxy_beneficiaries, 3188337),
  grepl("proxy", metadata$method, ignore.case = TRUE),
  grepl("not observed excess mortality", metadata$limitations,
        ignore.case = TRUE)
)

for (level in c("admin1", "admin2")) {
  level_df <- df[df$level == level, ]
  stopifnot(
    abs(sum(level_df$ed_0_1) - 22017) < 1e-7,
    abs(sum(level_df$ed_1_5) - 14780) < 1e-7
  )
}

expected_region_beneficiaries <- c(
  "Central Region" = 1444808,
  "Northern Region" = 214983,
  "Southern Region" = 1528546
)
admin1_beneficiaries <- setNames(
  admin1_audit$proxy_beneficiaries,
  admin1_audit$georepo
)
stopifnot(identical(
  as.numeric(admin1_beneficiaries[names(expected_region_beneficiaries)]),
  as.numeric(expected_region_beneficiaries)
))

expected_admin2_names <- c(
  "Kasungu", "Nkhotakota", "Ntchisi", "Dowa", "Salima", "Lilongwe",
  "Lilongwe City", "Mchinji", "Dedza", "Ntcheu", "Chitipa", "Karonga",
  "Nkhata Bay", "Rumphi", "Mzimba", "Likoma", "Mzuzu City", "Mangochi",
  "Machinga", "Zomba", "Chiradzulu", "Mwanza", "Neno", "Thyolo",
  "Mulanje", "Phalombe", "Chikwawa", "Nsanje", "Balaka",
  "Blantyre City", "Blantyre", "Zomba City"
)
stopifnot(setequal(admin2_audit$georepo, expected_admin2_names))

test_output <- tempfile(fileext = ".rda")
written <- prepare_mwi_crisis_adjustment(
  project_root = normalizePath(".", winslash = "/", mustWork = TRUE),
  output_path = test_output,
  write_output = TRUE,
  quiet = TRUE
)
saved <- new.env(parent = emptyenv())
load(test_output, envir = saved)
stopifnot(
  all(c(
    "df_MWI", "mwi_crisis_admin1_audit", "mwi_crisis_admin2_audit",
    "mwi_crisis_allocation_metadata"
  ) %in% ls(saved)),
  identical(saved$df_MWI, written$df_MWI)
)
unlink(test_output)

readme_text <- paste(
  readLines(file.path("Data", "Crisis_Adjustment", "README.md"), warn = FALSE),
  collapse = "\n"
)
stopifnot(
  grepl("prepare_mwi_fao_proxy.R", readme_text, fixed = TRUE),
  grepl("crisis_MWI.rda", readme_text, fixed = TRUE),
  grepl("not observed excess mortality", readme_text, fixed = TRUE)
)

message("Malawi crisis-adjustment preparation tests passed.")
