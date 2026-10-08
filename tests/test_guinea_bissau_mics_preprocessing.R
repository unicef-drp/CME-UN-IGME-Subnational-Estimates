script_file <- file.path(
  "Rcode", "_script_for_specific_tasks",
  "Guinea_Bissau_MICS_DataProcessing.R"
)
if (!file.exists(script_file)) {
  stop("Missing Guinea-Bissau MICS preprocessing script: ", script_file)
}
source(script_file)

expected_admin1 <- sort(c(
  "Bafat\u00e1", "Biombo", "Bissau", "Bolama", "Cacheu", "Gab\u00fa",
  "Oio", "Quinara", "Tombali"
))

observed_labels <- c(
  "Tombali", "Quinara", "Oio", "Biombo", "Bijagos/Bubaque",
  "Bolama/Bijag\u00f3s", "Bafata", "Bafat\u00e1", "Gab\u00fa", "Cacheu", "SAB"
)
expected_labels <- c(
  "Tombali", "Quinara", "Oio", "Biombo", "Bolama", "Bolama",
  "Bafat\u00e1", "Bafat\u00e1", "Gab\u00fa", "Cacheu", "Bissau"
)
stopifnot(identical(
  normalize_guinea_bissau_admin1(observed_labels),
  expected_labels
))

check_output <- function(output_file, survey_year, expected_qa) {
  output_env <- new.env(parent = emptyenv())
  load(output_file, envir = output_env)
  stopifnot(exists("dat.tmp", envir = output_env, inherits = FALSE))
  dat.tmp <- get("dat.tmp", envir = output_env, inherits = FALSE)

  required <- c(
    "cluster", "age", "years", "total", "Y", "v005", "urban",
    "admin1.name", "survey"
  )
  stopifnot(
    all(required %in% names(dat.tmp)),
    nrow(dat.tmp) > 0L,
    identical(sort(unique(dat.tmp$survey)), survey_year),
    identical(sort(unique(as.character(dat.tmp$admin1.name))),
              expected_admin1),
    identical(sort(unique(as.character(dat.tmp$urban))),
              c("rural", "urban")),
    all(is.finite(dat.tmp$v005)),
    all(dat.tmp$v005 > 0),
    all(is.finite(dat.tmp$total)),
    all(dat.tmp$total >= 0),
    all(is.finite(dat.tmp$Y)),
    all(dat.tmp$Y >= 0),
    all(dat.tmp$Y <= dat.tmp$total)
  )

  qa <- attr(dat.tmp, "guinea_bissau_qa")
  stopifnot(is.list(qa))
  for (field in names(expected_qa)) {
    stopifnot(identical(qa[[field]], expected_qa[[field]]))
  }
}

source_2010 <- file.path(
  "Data", "MICS", "Guinea-Bissau", "2010", "GuineaBissau2010.sav"
)
source_2014 <- file.path(
  "Data", "MICS", "Guinea-Bissau", "2014", "bh.sav"
)
stopifnot(file.exists(source_2010), file.exists(source_2014))

output_2010 <- tempfile(fileext = ".tmp.rda")
output_2014 <- tempfile(fileext = ".tmp.rda")
on.exit(unlink(c(output_2010, output_2014)), add = TRUE)

prepare_guinea_bissau_mics_2010(
  source_file = source_2010,
  output_file = output_2010
)
check_output(
  output_2010,
  survey_year = 2010,
  expected_qa = list(
    source_birth_rows = 23553L,
    usable_birth_rows = 23535L,
    excluded_missing_death_age = 18L,
    clusters = 399L,
    admin1_areas = 9L
  )
)

prepare_guinea_bissau_mics_2014(
  source_file = source_2014,
  output_file = output_2014
)
check_output(
  output_2014,
  survey_year = 2014,
  expected_qa = list(
    source_birth_rows = 27607L,
    usable_birth_rows = 27607L,
    excluded_missing_death_age = 0L,
    clusters = 341L,
    admin1_areas = 9L
  )
)

cat("Guinea-Bissau 2010 and 2014 Admin-1 MICS preprocessing is valid.\n")
