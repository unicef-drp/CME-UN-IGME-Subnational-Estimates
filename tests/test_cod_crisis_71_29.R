script_path <- file.path("Data", "Crisis_Adjustment", "prepare_cod_71_29.R")
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
  years = 2000L,
  crisis_d0_5 = 100,
  crisis_d0 = 60,
  crisis_d1_4 = 40,
  pop_0 = 1000,
  pop_1_4 = 4000,
  stringsAsFactors = FALSE
)

areas <- data.frame(
  country = "Democratic Republic of the Congo",
  level = "admin1",
  georepo = c("East A", "East B", "Rest A", "Rest B"),
  region = paste0("admin1_", 1:4),
  years = 2000L,
  allocation_group = c("East", "East", "Rest", "Rest"),
  noncrisis_u5mr = c(0.4, 0.1, 0.2, 0.4),
  area_pop_0_1 = c(100, 300, 200, 200),
  area_pop_1_5 = c(200, 600, 400, 400),
  stringsAsFactors = FALSE
)

allocated <- allocate_cod_crisis_deaths(national, areas, east_share = 0.71)

stopifnot(
  abs(sum(allocated$ed_0_1) - 60) < 1e-10,
  abs(sum(allocated$ed_1_5) - 40) < 1e-10,
  abs(sum(allocated$ed_0_1[allocated$allocation_group == "East"]) / 60 - 0.71) < 1e-10,
  abs(sum(allocated$ed_1_5[allocated$allocation_group == "East"]) / 40 - 0.71) < 1e-10,
  abs(allocated$ed_0_1[allocated$georepo == "East B"] /
      allocated$ed_0_1[allocated$georepo == "East A"] - 3) < 1e-10,
  abs(allocated$ed_1_5[allocated$georepo == "Rest B"] /
      allocated$ed_1_5[allocated$georepo == "Rest A"] - 1) < 1e-10
)

expect_error(
  allocate_cod_crisis_deaths(
    national,
    transform(areas, allocation_group = "East"),
    east_share = 0.71
  ),
  "East and Rest"
)

bad_areas <- areas
bad_areas$area_pop_0_1[bad_areas$allocation_group == "Rest"] <- 0
expect_error(
  allocate_cod_crisis_deaths(national, bad_areas, east_share = 0.71),
  "positive"
)

bad_source <- national[, setdiff(names(national), "crisis_d0")]
expect_error(validate_cod_crisis_source(bad_source), "required")

duplicate_source <- rbind(national, national)
expect_error(validate_cod_crisis_source(duplicate_source), "duplicate")

integration <- prepare_cod_crisis_adjustment(
  project_root = normalizePath(".", winslash = "/", mustWork = TRUE),
  write_output = FALSE,
  quiet = TRUE
)

df <- integration$df_COD
audit <- integration$cod_crisis_allocation_audit
metadata <- integration$cod_crisis_allocation_metadata
current_source <- read_cod_crisis_source(file.path(
  "Data", "Crisis_Adjustment", "Crisis_Under5_deaths_2026.xlsx"
))
country_info <- jsonlite::fromJSON("Info/DR_Congo_general_info.json")
expected_years <- sort(current_source$years[
  current_source$years >= country_info$beg.year &
    current_source$years <= country_info$end.proj.year
])

stopifnot(
  identical(sort(unique(df$years)), expected_years),
  nrow(df[df$level == "admin1", ]) == 26L * length(expected_years),
  nrow(df[df$level == "admin2", ]) == 188L * length(expected_years),
  !anyDuplicated(df[c("level", "region", "years")]),
  all(is.finite(df$ed_0_1)),
  all(is.finite(df$ed_1_5)),
  all(df$ed_0_1 >= 0),
  all(df$ed_1_5 >= 0),
  identical(metadata$allocated_years, expected_years),
  identical(metadata$excluded_source_years, setdiff(current_source$years, expected_years))
)

checks <- aggregate(
  cbind(ed_0_1, ed_1_5) ~ level + years + allocation_group,
  data = audit,
  FUN = sum
)
totals <- aggregate(
  cbind(ed_0_1, ed_1_5) ~ level + years,
  data = audit,
  FUN = sum
)
source_match <- match(totals$years, current_source$years)
stopifnot(
  all(abs(totals$ed_0_1 - current_source$crisis_d0[source_match]) < 1e-7),
  all(abs(totals$ed_1_5 - current_source$crisis_d1_4[source_match]) < 1e-7)
)
east <- checks[checks$allocation_group == "East", ]
east <- merge(east, totals, by = c("level", "years"), suffixes = c("_east", "_total"))

stopifnot(
  all(abs(east$ed_0_1_east / east$ed_0_1_total - 0.71) < 1e-10),
  all(abs(east$ed_1_5_east / east$ed_1_5_total - 0.71) < 1e-10)
)

message("COD crisis 71/29 tests passed.")
