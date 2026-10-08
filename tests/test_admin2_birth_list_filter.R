source(file.path("Rcode", "_supporting_scripts", "survey_list_filters.R"))

births.list <- list(
  data.frame(admin2.char = c(NA_character_, NA_character_), value = 1:2),
  data.frame(admin2.char = c("admin2_1", NA_character_), value = 3:4)
)
births.list.nmr <- list(
  data.frame(admin2.char = NA_character_, value = 1),
  data.frame(admin2.char = "admin2_1", value = 3)
)
survey_years <- c(2018, 2021)

filtered <- filter_admin2_birth_lists(births.list, births.list.nmr, survey_years)

stopifnot(length(filtered$births.list) == 1)
stopifnot(length(filtered$births.list.nmr) == 1)
stopifnot(identical(filtered$survey_years, 2021))
stopifnot(nrow(filtered$births.list[[1]]) == 1)
stopifnot(nrow(filtered$births.list.nmr[[1]]) == 1)
stopifnot(identical(filtered$births.list[[1]]$admin2.char, "admin2_1"))

cat("Admin2 birth-list filtering keeps only surveys and rows with admin2 assignments.\n")
