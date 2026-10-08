script <- paste(readLines(file.path("Rcode", "_script_for_specific_tasks",
                                    "MICS_DataProcessing.R"),
                          warn = FALSE),
                collapse = "\n")

if (!grepl("Laos 2023", script, fixed = TRUE) ||
    !grepl("lao.2023.tmp.rda", script, fixed = TRUE)) {
  stop("MICS_DataProcessing.R does not include the Laos 2023 MICS block.")
}

expected_hh7_to_admin1 <- c(
  "1" = 15, "2" = 10, "3" = 7, "4" = 9, "5" = 2, "6" = 8,
  "7" = 5, "8" = 16, "9" = 18, "10" = 14, "11" = 3,
  "12" = 6, "13" = 12, "14" = 11, "15" = 13, "16" = 4,
  "17" = 1, "18" = 17
)
mapping_literals <- paste0("\"", names(expected_hh7_to_admin1), "\" = ",
                           unname(expected_hh7_to_admin1))
missing_mapping_literals <- mapping_literals[
  !vapply(mapping_literals, grepl, logical(1), x = script, fixed = TRUE)
]
if (length(missing_mapping_literals) > 0) {
  stop("Laos HH7-to-admin1 mapping is missing expected entries: ",
       paste(missing_mapping_literals, collapse = ", "))
}

tmp_file <- file.path("Data", "MICS", "Laos", "lao.2023.tmp.rda")
if (!file.exists(tmp_file)) {
  stop("Prepared Laos MICS 2023 file is missing: ", tmp_file)
}

tmp_env <- new.env(parent = emptyenv())
load(tmp_file, envir = tmp_env)
if (!exists("dat.tmp", envir = tmp_env, inherits = FALSE)) {
  stop("Expected dat.tmp in ", tmp_file)
}

dat.tmp <- get("dat.tmp", envir = tmp_env)
expected_tmp_cols <- c("cluster", "age", "years", "total", "Y", "v005",
                       "urban", "admin1.name", "survey")
missing_tmp_cols <- setdiff(expected_tmp_cols, names(dat.tmp))
if (length(missing_tmp_cols) > 0) {
  stop("Laos MICS 2023 tmp data is missing columns: ",
       paste(missing_tmp_cols, collapse = ", "))
}

if (!identical(sort(unique(dat.tmp$survey)), 2023)) {
  stop("Laos MICS 2023 tmp data should only contain survey year 2023.")
}

if (!all(c("urban", "rural") %in% unique(dat.tmp$urban))) {
  stop("Laos MICS 2023 tmp data should include both urban and rural rows.")
}

cluster_file <- file.path("Data", "MICS", "Laos", "Laos_cluster_dat.rda")
if (!file.exists(cluster_file)) {
  stop("Combined Laos MICS cluster file is missing: ", cluster_file)
}

cluster_env <- new.env(parent = emptyenv())
load(cluster_file, envir = cluster_env)
if (!exists("mod.dat", envir = cluster_env, inherits = FALSE)) {
  stop("Expected mod.dat in ", cluster_file)
}

mod.dat <- get("mod.dat", envir = cluster_env)
surveys <- sort(unique(mod.dat$survey))
if (!all(c(2017, 2023) %in% surveys)) {
  stop("Combined Laos MICS data should include 2017 and 2023; found: ",
       paste(surveys, collapse = ", "))
}

expected_admin_names <- data.frame(
  admin1 = 1:18,
  admin1.name = c(
    "Attapeu", "Bokeo", "Bolikhamxai", "Champasack", "Houaphan",
    "Khammouan", "Louangnamtha", "Louangphabang", "Oudomxai",
    "Phongsaly", "Salavan", "Savannakhet", "Sekong",
    "Vientiane", "Vientiane Capital", "Xaignabouly",
    "Xaisomboon", "Xiengkhouang"
  )
)
actual_admin_names <- unique(mod.dat[, c("admin1", "admin1.name")])
actual_admin_names <- actual_admin_names[order(actual_admin_names$admin1), ]
rownames(actual_admin_names) <- NULL
if (!identical(actual_admin_names, expected_admin_names)) {
  stop("Combined Laos admin IDs and final names do not match expected GeoRepo-style names.")
}

check_hh7_labels <- function(bh_file, expected_labels) {
  if (!requireNamespace("haven", quietly = TRUE)) {
    stop("Package 'haven' is required to verify Laos HH7 labels.")
  }

  bh <- haven::read_sav(bh_file)
  labels <- attr(bh$HH7, "labels")
  actual_labels <- data.frame(
    hh7_label = names(labels),
    hh7_code = as.integer(labels)
  )
  expected_labels <- data.frame(
    hh7_label = names(expected_labels),
    hh7_code = as.integer(expected_labels)
  )

  if (!identical(actual_labels, expected_labels)) {
    stop("Unexpected HH7 labels in ", bh_file)
  }
}

expected_hh7_labels_2017 <- c(
  "VIENTIANE CAPITAL" = 1, "PHONGSALY" = 2, "LUANGNAMTHA" = 3,
  "OUDOMXAY" = 4, "BOKEO" = 5, "LUANGPRABANG" = 6,
  "HUAPHANH" = 7, "XAYABURY" = 8, "XIENGKHUANG" = 9,
  "VIENTIANE" = 10, "BORIKHAMXAY" = 11, "KHAMMUA" = 12,
  "SAVANNAKHET" = 13, "SARAVANE" = 14, "SEKONG" = 15,
  "CHAMPASACK" = 16, "ATTAPEU" = 17, "XAYSOMBOUNE" = 18
)
expected_hh7_labels_2023 <- expected_hh7_labels_2017
names(expected_hh7_labels_2023)[12] <- "KHAMMUAN"
names(expected_hh7_labels_2023)[18] <- "XAYSOMBOUN"
check_hh7_labels(file.path("Data", "MICS", "Laos", "lao_2017_bh.sav"),
                 expected_hh7_labels_2017)
check_hh7_labels(file.path("Data", "MICS", "Laos", "2023", "bh.sav"),
                 expected_hh7_labels_2023)

required_cols <- c("cluster", "age", "years", "total", "Y", "v005",
                   "urban", "admin1.name", "admin1.char", "admin1",
                   "strata", "LONGNUM", "LATNUM", "survey.type", "survey")
missing_cols <- setdiff(required_cols, names(mod.dat))
if (length(missing_cols) > 0) {
  stop("Combined Laos MICS data is missing columns: ",
       paste(missing_cols, collapse = ", "))
}

laos_2023 <- mod.dat[mod.dat$survey == 2023, ]
if (nrow(laos_2023) == 0) {
  stop("Combined Laos MICS data has no 2023 rows.")
}

if (anyNA(laos_2023$admin1) || anyNA(laos_2023$admin1.char) ||
    anyNA(laos_2023$strata)) {
  stop("Combined Laos MICS 2023 rows have missing admin IDs or strata.")
}

if (!all(laos_2023$survey.type == "MICS")) {
  stop("Combined Laos MICS 2023 rows should have survey.type == 'MICS'.")
}

run_cluster_file <- file.path("Data", "Countries", "Laos", "Laos_cluster_dat.rda")
run_cluster_1frame_file <- file.path("Data", "Countries", "Laos",
                                     "Laos_cluster_dat_1frame.rda")
source(file.path("Rcode", "_supporting_scripts", "project_paths.R"))
info_env <- new.env(parent = emptyenv())
load.country.info("Laos", envir = info_env)

for (run_file in c(run_cluster_file, run_cluster_1frame_file)) {
  if (!file.exists(run_file)) {
    stop("Run-ready Laos cluster file is missing: ", run_file)
  }

  run_env <- new.env(parent = emptyenv())
  load(run_file, envir = run_env)
  if (!exists("mod.dat", envir = run_env, inherits = FALSE)) {
    stop("Expected mod.dat in ", run_file)
  }

  run_mod_dat <- get("mod.dat", envir = run_env)
  run_surveys <- sort(unique(run_mod_dat$survey))
  expected_surveys <- if (identical(run_file, run_cluster_1frame_file)) {
    info_env$surveys_1frame
  } else {
    c(2017, 2023)
  }
  if (!all(expected_surveys %in% run_surveys)) {
    stop(run_file, " should include ",
         paste(expected_surveys, collapse = " and "), "; found: ",
         paste(run_surveys, collapse = ", "))
  }
}

if (!exists("end.proj.year", envir = info_env, inherits = FALSE) ||
    get("end.proj.year", envir = info_env) < 2025) {
  stop("Laos info should project through at least 2025 for the 2026 round.")
}

cat("Laos MICS 2023 preprocessing artifacts are present and mergeable.\n")
