source(file.path(
  "Rcode", "_supporting_scripts", "malawi_admin_repair.R"
))

already_correct <- data.frame(
  admin1.name = "Central Region",
  admin2.name = "Kasungu",
  admin1.char = "admin1_1",
  admin1 = 1,
  stringsAsFactors = FALSE
)
stopifnot(identical(
  repair_malawi_kasungu_admin(already_correct),
  already_correct
))

needs_repair <- data.frame(
  admin1.name = c("Central Region", "Northern Region", "Southern Region"),
  admin2.name = c("Dedza", "Kasungu", "Zomba"),
  admin1.char = c("admin1_1", "admin1_2", "admin1_3"),
  admin1 = c(1, 2, 3),
  stringsAsFactors = FALSE
)
repaired <- repair_malawi_kasungu_admin(needs_repair)
stopifnot(
  identical(repaired$admin1.name, c(
    "Central Region", "Central Region", "Southern Region"
  )),
  identical(repaired$admin1.char, c(
    "admin1_1", "admin1_1", "admin1_3"
  )),
  identical(repaired$admin1, c(1, 1, 3))
)

message("Malawi Kasungu Admin-1 repair tests passed")
