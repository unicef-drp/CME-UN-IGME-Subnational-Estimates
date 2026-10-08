# Integration check for the prepared Congo inputs (run after both preparations).
USERPROFILE <- Sys.getenv("USERPROFILE")
source(file.path(USERPROFILE, "Dropbox/UNICEF Work/profile.R"))
source("Rcode/_supporting_scripts/project_paths.R")
load("Data/Countries/Congo/Congo_cluster_dat.rda")
info <- jsonlite::fromJSON("Info/Congo_general_info.json")
stopifnot(info$iso0 == "COG", isTRUE(info$doCrisisAdj),
          is.null(info$poly.layer.adm2),
          setequal(mod.dat$survey, c(2011, 2015)),
          all(is.na(mod.dat$LONGNUM)), all(is.na(mod.dat$LATNUM)),
          all(mod.dat$Y >= 0), all(mod.dat$Y <= mod.dat$total),
          all(is.finite(mod.dat$v005)), all(mod.dat$v005 > 0))
geo <- sf::st_read("Data/shapeFiles/georepo_COG_shp/georepo_COG_1.shp", quiet = TRUE)
for (survey_year in c(2011, 2015)) {
  x <- mod.dat[mod.dat$survey == survey_year, ]
  stopifnot(setequal(x$admin1.name, geo$NAME_1),
            max(as.numeric(as.character(x$years))) == if (survey_year == 2011) 2012 else 2015,
            max(x$v005) < 10)
}
bh <- haven::read_sav(file.path(USERPROFILE, "Dropbox/IGME Data/Output CMRJack",
                               "InputForCMRJack/BH/MICS/Congo2014-15.sav"))
# Independent bridge from source death-age units to prepared neonatal deaths.
# getBirths must retain every reported death before 30 days for births in scope.
source_neonatal <- sum(bh$B5 == 0 & bh$B7 >= 0 & bh$B7 < .30 & bh$B3 >= 1201)
prepared_neonatal <- sum(mod.dat$Y[mod.dat$survey == 2015 & mod.dat$age == "0"])
stopifnot(source_neonatal == prepared_neonatal)
cat("Congo inputs retain both surveys, all 12 departments, final fieldwork years,\n",
     "compatible weight units, and", source_neonatal, "MICS neonatal deaths in scope.\n")
