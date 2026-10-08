processor_file <- file.path(
  "Rcode", "_script_for_specific_tasks", "Sudan_MICS_DataProcessing.R"
)
if (!file.exists(processor_file)) {
  stop("Missing Sudan MICS processor: ", processor_file, call. = FALSE)
}
source(processor_file)

required_functions <- c(
  "normalize_sudan_admin1",
  "prepare_sudan_mics_2010",
  "prepare_sudan_mics_2014"
)
stopifnot(all(vapply(required_functions, exists, logical(1))))

normalization_fixture <- c(
  "Wite Nile", "North Darfor", "West Darfor", "South Darfor",
  "Central Darfor", "East Darfor", "Gadarif", "Gezira", "Sinnar"
)
stopifnot(identical(
  normalize_sudan_admin1(normalization_fixture),
  c(
    "White Nile", "North Darfur", "West Darfur", "South Darfur",
    "Central Darfur", "East Darfur", "Gedaref", "Aj Jazirah", "Sennar"
  )
))

source_2010 <- file.path(
  "C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents",
  "Country Data/Sudan/2010 MICS-HHS/bh.sav"
)
source_2014 <- file.path(
  "C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents",
  "Country Data/Sudan/2014 MICS/bh.sav"
)
stopifnot(file.exists(source_2010), file.exists(source_2014))

test_dir <- tempfile("sudan_mics_preprocessing_")
dir.create(test_dir, recursive = TRUE)
on.exit(unlink(test_dir, recursive = TRUE, force = TRUE), add = TRUE)

output_2010 <- file.path(test_dir, "sdn.2010.tmp.rda")
output_2014 <- file.path(test_dir, "sdn.2014.tmp.rda")
prepared_2010 <- prepare_sudan_mics_2010(source_2010, output_2010)
prepared_2014 <- prepare_sudan_mics_2014(source_2014, output_2014)

expected_columns <- c(
  "cluster", "age", "years", "total", "Y", "v005", "urban",
  "admin1.name", "survey"
)
stopifnot(
  identical(names(prepared_2010), expected_columns),
  identical(names(prepared_2014), expected_columns),
  identical(unique(prepared_2010$survey), 2010L),
  identical(unique(prepared_2014$survey), 2014L),
  all(is.finite(prepared_2010$v005) & prepared_2010$v005 > 0),
  all(is.finite(prepared_2014$v005) & prepared_2014$v005 > 0),
  all(prepared_2010$urban %in% c("urban", "rural")),
  all(prepared_2014$urban %in% c("urban", "rural"))
)

qa_2010 <- attr(prepared_2010, "sudan_qa")
qa_2014 <- attr(prepared_2014, "sudan_qa")
stopifnot(
  identical(qa_2010$source_birth_rows, 47092L),
  identical(qa_2010$usable_birth_rows, 47092L),
  identical(qa_2010$clusters, 600L),
  identical(qa_2010$admin1_areas, 15L),
  identical(qa_2014$source_birth_rows, 52245L),
  identical(qa_2014$usable_birth_rows, 52245L),
  identical(qa_2014$clusters, 720L),
  identical(qa_2014$admin1_areas, 18L)
)

later_states <- c("West Kordofan", "Central Darfur", "East Darfur")
stopifnot(
  !any(later_states %in% prepared_2010$admin1.name),
  all(later_states %in% prepared_2014$admin1.name),
  setequal(
    setdiff(unique(prepared_2014$admin1.name),
            unique(prepared_2010$admin1.name)),
    later_states
  )
)

cat("Sudan MICS 2010 and 2014 preprocessing contracts pass.\n")
