# Prepare the existing standardized MICS birth histories for the subnational
# pipeline. This source is a CMRJack input, not the original MICS BH recode.
USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
source(file.path(Sys.getenv("UN_SUBNATIONAL_HOME", unset = getwd()),
                 "Rcode/_supporting_scripts/project_paths.R"))

library(haven)
library(SUMMER)

project_dir <- project_home()
input_file <- file.path(USERPROFILE, "Dropbox", "IGME Data", "Output CMRJack",
                        "InputForCMRJack", "BH", "MICS", "Congo2014-15.sav")
output_dir <- file.path(project_dir, "Data", "MICS", "Congo")
output_file <- file.path(output_dir, "cog.2015.tmp.rda")
stopifnot(file.exists(input_file), !file.exists(output_file))
bh <- read_sav(input_file)
required <- c("V005", "V008", "V021", "V022", "B3", "B5", "B7", "V101",
              "V102", "HH1", "HH2", "LN", "BHLN")
stopifnot(all(required %in% names(bh)), nrow(bh) == 31640L)
stopifnot(!anyDuplicated(bh[c("HH1", "HH2", "LN", "BHLN")]))
stopifnot(all(as.numeric(bh$B5) %in% 0:1),
          all(as.numeric(bh$V102) %in% 1:2),
          all(is.finite(bh$V005)), all(bh$V005 > 0),
          all(bh$B3 <= bh$V008),
          setequal(as.numeric(bh$V101), 1:12),
          setequal(as.numeric(bh$V022), 1:15),
          all(bh$V021 == bh$HH1))

# Six deceased children have the source's -99 missing age-at-death code.
# Their death dates and exposure cannot be constructed. Exclude these entire
# birth records, retaining a count in provenance; do not invent death ages.
source_birth_count <- nrow(bh)
missing_death_age <- bh$B5 == 0 & bh$B7 < 0
stopifnot(sum(missing_death_age) == 6L,
          all(bh$B7[missing_death_age] == -99))
cat("Excluded deceased births with missing death age:", sum(missing_death_age), "\n")
bh <- bh[!missing_death_age, ]
stopifnot(all(bh$B7[bh$B5 == 0] >= 0))

# CMRJack stores death ages reported in days as days/100 (six days = 0.06).
# SUMMER's getBirths expects completed months and represents neonatal deaths
# with age zero. Passing these day codes through would misclassify neonatal
# deaths after its 0.02-month split. Thirty reported days is one month.
day_coded_death <- bh$B5 == 0 & bh$B7 >= 0 & bh$B7 < 1
day_age <- round(100 * as.numeric(bh$B7[day_coded_death]))
stopifnot(all(day_age >= 0 & day_age <= 30),
          all(as.numeric(bh$B7[bh$B5 == 0 & bh$B7 >= 1]) %% 1 == 0))
bh$B7[day_coded_death] <- floor(day_age / 30)
stopifnot(sum(bh$B5 == 0 & bh$B7 == 0) == sum(day_age < 30))
cat("CMRJack day-coded deaths converted to completed months:", length(day_age), "\n")

# Codes and labels are checked in the saved source; the target names retain
# GeoRepo's spelling (including Point-Noire).
source_labels <- attr(bh$V101, "labels")
expected_labels <- c("KOUILOU", "NIARI", "LEKOUMOU", "BOUENZA", "POOL",
                     "PLATEAUX", "CUVETTE", "CUVETTE OUEST", "SANGHA",
                     "LIKOUALA", "BRAZZAVILLE", "POINTE-NOIRE")
stopifnot(identical(names(source_labels), expected_labels),
          identical(as.integer(source_labels), 1:12))
target_names <- c("Kouilou", "Niari", "L\u00e9koumou", "Bouenza", "Pool",
                  "Plateaux", "Cuvette", "Cuvette-Ouest", "Sangha", "Likouala",
                  "Brazzaville", "Point-Noire")
bh$admin1.name <- target_names[as.integer(bh$V101)]
bh$urban <- ifelse(bh$V102 == 1, "urban", "rural")
bh$alive <- ifelse(bh$B5 == 1, "yes", "no")
bh$cluster <- as.numeric(bh$V021)
bh$v005 <- as.numeric(bh$V005) # Already scaled in CMRJack; do not divide again.

psu <- unique(data.frame(cluster = bh$cluster, stratum = as.numeric(bh$V022),
                         department = bh$admin1.name, urban = bh$urban))
stopifnot(!anyDuplicated(psu$cluster), all(table(psu$stratum) >= 2))
cat("Source births:", nrow(bh), "PSUs:", nrow(psu), "\n")
print(table(psu$department, psu$urban))
print(table(psu$stratum))

# Use the final fieldwork year so observations in Jan-Feb 2015 are retained.
# MICS uses full-year death ages from 36 months, as in existing MICS preparation.
prepared <- getBirths(
  data = bh, surveyyear = 2015,
  variables = c("cluster", "B3", "B7", "V008", "alive", "urban", "v005",
                 "admin1.name"),
  strata = c("admin1.name", "urban"), dob = "B3", alive = "alive", age = "B7",
  date.interview = "V008", age.truncate = 36,
  year.cut = seq(2000, 2016),
  compact.by = c("cluster", "v005", "admin1.name", "urban"), compact = TRUE
)
dat.tmp <- prepared[c("cluster", "age", "time", "total", "died", "v005",
                      "urban", "admin1.name")]
names(dat.tmp)[3:5] <- c("years", "total", "Y")
dat.tmp$survey <- 2015
stopifnot(nrow(dat.tmp) > 0, !anyNA(dat.tmp),
          all(dat.tmp$total > 0), all(dat.tmp$Y >= 0),
          all(dat.tmp$Y <= dat.tmp$total),
          setequal(dat.tmp$admin1.name, target_names),
          max(as.numeric(as.character(dat.tmp$years))) == 2015)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
save(dat.tmp, file = output_file)
verification <- new.env()
load(output_file, envir = verification)
stopifnot(identical(dat.tmp, verification$dat.tmp))
provenance <- list(
  source = normalizePath(input_file, winslash = "/"),
  source_type = "existing standardized CMRJack birth-history SAV",
  source_md5 = unname(tools::md5sum(input_file)),
  survey = "MICS 2014-2015", pipeline_survey_year = 2015,
  raw_births = source_birth_count, usable_births = nrow(bh), raw_psus = nrow(psu),
  excluded_missing_death_age = sum(missing_death_age),
  day_coded_deaths_converted = length(day_age),
  neonatal_deaths_under30_days = sum(day_age < 30),
  death_age_conversion = "CMRJack days/100 to completed months; 0-29 days maps to 0, 30 days maps to 1",
  departments = target_names, sampling_strata = 15,
  weight_scale = "already normalized; retained without additional divisor",
  interview_cmc_range = range(as.numeric(bh$V008)),
  age_truncate_months = 36,
  prepared_rows = nrow(dat.tmp),
  prepared_deaths = sum(dat.tmp$Y),
  prepared_exposure_months = sum(dat.tmp$total),
  prepared_md5 = unname(tools::md5sum(output_file)),
  coordinates = "not provided; assignment uses department identifiers"
)
jsonlite::write_json(provenance, file.path(output_dir, "cog.2015.provenance.json"),
                     pretty = TRUE, auto_unbox = TRUE)
cat("Prepared:", output_file, "\n")
print(provenance[c("prepared_rows", "prepared_deaths", "prepared_exposure_months")])
