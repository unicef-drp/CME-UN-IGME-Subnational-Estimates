source("Rcode/_supporting_scripts/malawi_report_admin_hierarchy.R")

shape_attributes <- data.frame(
  NAME_1 = c("Central Region", "Northern Region"),
  NAME_2 = c("Kasungu", "Chitipa"),
  stringsAsFactors = FALSE
)

repaired <- add_malawi_report_admin1(shape_attributes)

stopifnot(identical(repaired$DHSREGEN, shape_attributes$NAME_1))
stopifnot(identical(repaired$NAME_2, shape_attributes$NAME_2))

bad <- shape_attributes
bad$NAME_1[2] <- NA_character_
err <- try(add_malawi_report_admin1(bad), silent = TRUE)
stopifnot(inherits(err, "try-error"))

message("Malawi report hierarchy tests passed.")
