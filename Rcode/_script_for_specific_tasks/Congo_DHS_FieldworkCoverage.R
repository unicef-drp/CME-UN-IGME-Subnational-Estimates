# Run after Step 3, before any estimation. Retain Jan-Feb 2012 observations
# from DHS 2011-2012 while preserving the catalogue survey identifier (2011).
USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
project_dir <- normalizePath(Sys.getenv("UN_SUBNATIONAL_HOME", unset = getwd()),
                             winslash = "/", mustWork = TRUE)
source(file.path(project_dir, "Rcode/_supporting_scripts/project_paths.R"))
source(file.path(project_dir, "Rcode/_supporting_scripts/dhs_admin1_recode.R"))
source(file.path(project_dir, "Rcode/_supporting_scripts/urban_frame_matching.R"))
library(SUMMER)
info <- jsonlite::fromJSON(file.path(project_dir, "Info/Congo_general_info.json"))
data_dir <- country_data_dir(project_dir, "Congo")
input <- file.path(project_dir, "Data/DHS/Congo/2011/CGBR61SV/CGBR61FL.SAV")
raw <- haven::read_sav(input)
names(raw) <- tolower(names(raw))
stopifnot(nrow(raw) == 31948L, !anyDuplicated(raw[c("caseid", "bidx")]),
          all(raw$b5 %in% 0:1), all(raw$v025 %in% 1:2))
raw$b5 <- factor(ifelse(raw$b5 == 1, "yes", "no"), levels = c("yes", "no"))
raw$v025 <- factor(ifelse(raw$v025 == 1, "urban", "rural"),
                    levels = c("urban", "rural"))
raw <- harmonize_dhs_cluster_urbanicity(raw)$data
raw$v024 <- dhs_labelled_admin1_names(raw$v024, "v024")
last_year <- max(floor((as.numeric(raw$v008) - 1) / 12) + 1900)
stopifnot(last_year == 2012)
boundaries <- sf::st_read(file.path(project_dir, "Data/shapeFiles/georepo_COG_shp"),
                          layer = "georepo_COG_1", quiet = TRUE)
geo_names <- repair_utf8_text(boundaries$NAME_1)
convert <- function(end_year) {
  x <- getBirths(data = raw, surveyyear = end_year,
                  year.cut = seq(info$beg.year, end_year + 1),
                  cmc.adjust = 0, compact = TRUE)
  x <- x[c("v001", "v024", "time", "total", "age", "v005", "v025", "strata", "died")]
  x <- attach_dhs_admin1_from_recode(x, geo_names, info$dhs_admin1_from_recode, 2011)
  x <- x[c("v001", "age", "time", "total", "died", "v005", "v025",
             "LONGNUM", "LATNUM", "strata", "admin1", "admin1.char", "admin1.name")]
  names(x)[1:7] <- c("cluster", "age", "years", "total", "Y", "v005", "urban")
  x$survey <- 2011
  x$survey.type <- "DHS"
  x
}
old <- convert(2011)
new <- convert(last_year)
cluster_order <- unique(old$cluster)
stopifnot(length(cluster_order) == 384, setequal(new$cluster, cluster_order))
old$cluster <- match(old$cluster, cluster_order)
new$cluster <- match(new$cluster, cluster_order)
load(file.path(data_dir, "Congo_cluster_dat.rda"))
columns <- names(old)
canonical <- function(x) {
  x <- as.data.frame(lapply(x[columns], function(y) {
    if (is.factor(y)) as.character(y) else y
  }), stringsAsFactors = FALSE)
  x$years <- as.character(x$years)
  x <- x[do.call(order, x[setdiff(columns, c("LONGNUM", "LATNUM"))]), ]
  rownames(x) <- NULL
  x
}
existing <- mod.dat[mod.dat$survey == 2011, ]
already_full <- any(as.character(existing$years) == "2012")
already_scaled <- max(existing$v005) < 1000
if (already_scaled) existing$v005 <- existing$v005 * 1000000
reference <- if (already_full) new else old
stopifnot(isTRUE(all.equal(canonical(existing), canonical(reference),
                           check.attributes = FALSE)))
# The extension must leave every observation through 2011 unchanged.
stopifnot(isTRUE(all.equal(canonical(old), canonical(new[as.character(new$years) != "2012", ]),
                           check.attributes = FALSE)))
new$survey.id <- unique(mod.dat$survey.id[mod.dat$survey == 2011])
new$v005 <- new$v005 / 1000000
mics <- mod.dat[mod.dat$survey == 2015, ]
new$years <- as.numeric(as.character(new$years))
mics$years <- as.numeric(as.character(mics$years))
new <- new[names(mod.dat)]
mod.dat <- rbind(new, mics)
stopifnot(setequal(mod.dat$survey, c(2011, 2015)),
          !anyDuplicated(unique(mod.dat[c("cluster", "survey")])$cluster),
          setequal(mod.dat$admin1.name, geo_names),
          all(is.na(mod.dat$LONGNUM)), all(is.na(mod.dat$LATNUM)))
save(mod.dat, file = file.path(data_dir, "Congo_cluster_dat.rda"))
save(mod.dat, file = file.path(data_dir, "Congo_cluster_dat_1frame.rda"))
provenance <- list(
  survey = "DHS 2011-2012", catalogue_survey_year = 2011,
  fieldwork_end_year = last_year, source = input,
  source_md5 = unname(tools::md5sum(input)), raw_births = nrow(raw),
  psus = 384, departments = 12,
  unchanged_observations_through_2011 = TRUE,
  additional_2012_deaths = sum(new$Y[new$years == 2012]),
  additional_2012_exposure_months = sum(new$total[new$years == 2012]),
  prepared_dhs_rows = nrow(new), prepared_dhs_deaths = sum(new$Y),
  prepared_dhs_exposure_months = sum(new$total),
  weight_scale = "raw DHS v005 divided by 1000000 once, matching normalized MICS weights for pooled survey strata",
  note = "Run this country preparation after every standard Step 3 rerun."
)
jsonlite::write_json(provenance, file.path(data_dir, "Congo_DHS_fieldwork_provenance.json"),
                     pretty = TRUE, auto_unbox = TRUE)
print(provenance)
