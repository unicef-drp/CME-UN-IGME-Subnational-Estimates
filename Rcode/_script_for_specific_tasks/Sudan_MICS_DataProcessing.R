normalize_sudan_admin1 <- function(x) {
  x <- trimws(as.character(x))
  key <- tolower(iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT"))
  key <- gsub("[[:space:]]+", " ", key)
  normalized <- c(
    "northern" = "Northern",
    "river nile" = "River Nile",
    "red sea" = "Red Sea",
    "kassala" = "Kassala",
    "gadarif" = "Gedaref",
    "gedarif" = "Gedaref",
    "gedaref" = "Gedaref",
    "khartoum" = "Khartoum",
    "gezira" = "Aj Jazirah",
    "al jazirah" = "Aj Jazirah",
    "aj jazirah" = "Aj Jazirah",
    "wite nile" = "White Nile",
    "white nile" = "White Nile",
    "sinnar" = "Sennar",
    "sennar" = "Sennar",
    "blue nile" = "Blue Nile",
    "north kordofan" = "North Kordofan",
    "south kordofan" = "South Kordofan",
    "west kordofan" = "West Kordofan",
    "north darfor" = "North Darfur",
    "north darfur" = "North Darfur",
    "west darfor" = "West Darfur",
    "west darfur" = "West Darfur",
    "south darfor" = "South Darfur",
    "south darfur" = "South Darfur",
    "central darfor" = "Central Darfur",
    "central darfur" = "Central Darfur",
    "east darfor" = "East Darfur",
    "east darfur" = "East Darfur"
  )
  unname(normalized[key])
}

sudan_label_names <- function(x) {
  labels <- attr(x, "labels")
  if (is.null(labels)) {
    stop("Expected a labelled Sudan state variable.", call. = FALSE)
  }
  names(labels)[match(as.numeric(x), as.numeric(labels))]
}

build_sudan_mics_tmp <- function(bh, survey_year, output_file, qa) {
  dat.tmp <- SUMMER::getBirths(
    data = bh,
    surveyyear = survey_year,
    variables = c(
      "cluster", "dob", "age_at_death", "interview_cmc", "alive",
      "v005", "urban", "admin1.name"
    ),
    strata = c("urban", "admin1.name"),
    dob = "dob",
    alive = "alive",
    age = "age_at_death",
    date.interview = "interview_cmc",
    age.truncate = 24,
    year.cut = seq(2000, survey_year + 1, 1),
    compact.by = c("cluster", "v005", "urban", "admin1.name"),
    compact = TRUE
  )

  dat.tmp <- dat.tmp[, c(
    "cluster", "age", "time", "total", "died", "v005", "urban",
    "admin1.name"
  )]
  names(dat.tmp) <- c(
    "cluster", "age", "years", "total", "Y", "v005", "urban",
    "admin1.name"
  )
  dat.tmp$survey <- as.integer(survey_year)
  attr(dat.tmp, "sudan_qa") <- qa

  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  save(dat.tmp, file = output_file)
  dat.tmp
}

prepare_sudan_mics <- function(source_file, survey_year, output_file) {
  source <- haven::read_sav(source_file)
  required <- c(
    "HH1", "BH4C", "BH5", "BH9C", "HH6", "HH7", "WDOI",
    "wmweight"
  )
  missing <- setdiff(required, names(source))
  if (length(missing) > 0L) {
    stop(
      "Sudan MICS BH file is missing required variables: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  b5 <- as.numeric(source$BH5)
  b7 <- as.numeric(source$BH9C)
  dead <- b5 == 2
  missing_death_age <- dead & (!is.finite(b7) | b7 < 0)
  admin1.name <- normalize_sudan_admin1(sudan_label_names(source$HH7))
  urban <- ifelse(
    as.numeric(source$HH6) == 1, "urban",
    ifelse(as.numeric(source$HH6) == 2, "rural", NA_character_)
  )
  alive <- ifelse(b5 == 1, "yes", ifelse(dead, "no", NA_character_))

  usable <- !missing_death_age &
    !is.na(alive) & !is.na(urban) & !is.na(admin1.name) &
    is.finite(as.numeric(source$HH1)) &
    is.finite(as.numeric(source$BH4C)) &
    is.finite(as.numeric(source$WDOI)) &
    is.finite(as.numeric(source$wmweight)) &
    as.numeric(source$wmweight) > 0

  bh <- data.frame(
    cluster = as.numeric(source$HH1[usable]),
    dob = as.numeric(source$BH4C[usable]),
    age_at_death = b7[usable],
    interview_cmc = as.numeric(source$WDOI[usable]),
    alive = alive[usable],
    v005 = as.numeric(source$wmweight[usable]),
    urban = urban[usable],
    admin1.name = admin1.name[usable],
    stringsAsFactors = FALSE
  )

  qa <- list(
    source_birth_rows = as.integer(nrow(source)),
    usable_birth_rows = as.integer(nrow(bh)),
    excluded_missing_death_age = as.integer(sum(missing_death_age)),
    excluded_other_required = as.integer(sum(!usable & !missing_death_age)),
    deaths = as.integer(sum(dead & usable)),
    clusters = as.integer(length(unique(bh$cluster))),
    admin1_areas = as.integer(length(unique(bh$admin1.name)))
  )
  build_sudan_mics_tmp(bh, survey_year, output_file, qa)
}

prepare_sudan_mics_2010 <- function(
    source_file = file.path("Data", "MICS", "Sudan", "2010", "bh.sav"),
    output_file = file.path("Data", "MICS", "Sudan", "sdn.2010.tmp.rda")) {
  prepare_sudan_mics(source_file, 2010L, output_file)
}

prepare_sudan_mics_2014 <- function(
    source_file = file.path("Data", "MICS", "Sudan", "2014", "bh.sav"),
    output_file = file.path("Data", "MICS", "Sudan", "sdn.2014.tmp.rda")) {
  prepare_sudan_mics(source_file, 2014L, output_file)
}

if (sys.nframe() == 0L) {
  prepare_sudan_mics_2010()
  prepare_sudan_mics_2014()
}
