library(sf)

source(file.path("Rcode", "_supporting_scripts", "admin_boundary_merges.R"))

make_square <- function(xmin, ymin, xmax, ymax) {
  st_polygon(list(rbind(
    c(xmin, ymin),
    c(xmax, ymin),
    c(xmax, ymax),
    c(xmin, ymax),
    c(xmin, ymin)
  )))
}

poly.adm1 <- st_sf(
  NAME_1 = c("Other", "Vatovavy", "Fitovinany"),
  geometry = st_sfc(
    make_square(0, 0, 1, 1),
    make_square(1, 0, 2, 1),
    make_square(2, 0, 3, 1)
  ),
  crs = 4326
)

poly.adm2 <- st_sf(
  NAME_1 = c("Vatovavy", "Fitovinany", "Other"),
  NAME_2 = c("District A", "District B", "District C"),
  geometry = st_sfc(
    make_square(1, 0, 1.5, 1),
    make_square(2, 0, 2.5, 1),
    make_square(0, 0, 0.5, 1)
  ),
  crs = 4326
)

merged <- apply_admin1_name_merges(
  poly.adm1,
  poly.adm2,
  poly.label.adm1 = "NAME_1",
  admin1_name_merges = list(
    "Vatovavy Fitovinany" = c("Vatovavy", "Fitovinany")
  )
)

stopifnot(nrow(merged$poly.adm1) == 2)
stopifnot("Vatovavy Fitovinany" %in% merged$poly.adm1$NAME_1)
stopifnot(!any(c("Vatovavy", "Fitovinany") %in% merged$poly.adm1$NAME_1))
stopifnot(sum(merged$poly.adm2$NAME_1 == "Vatovavy Fitovinany") == 2)
stopifnot(all(merged$poly.adm2$NAME_2 == c("District A", "District B", "District C")))

cat("Admin1 merge rules dissolve admin1 polygons and recode admin2 parents.\n")
