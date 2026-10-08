repair_malawi_kasungu_admin <- function(mod.dat) {
  required_columns <- c(
    "admin1.name", "admin2.name", "admin1.char", "admin1"
  )
  missing_columns <- setdiff(required_columns, names(mod.dat))
  if (length(missing_columns) > 0) {
    stop(
      "Malawi Kasungu repair is missing column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  northern_names <- c("Northern", "Northern Region")
  central_names <- c("Central", "Central Region")
  repair_rows <-
    mod.dat$admin2.name == "Kasungu" &
    mod.dat$admin1.name %in% northern_names

  if (!any(repair_rows, na.rm = TRUE)) {
    return(mod.dat)
  }

  central_key <- unique(mod.dat[
    mod.dat$admin1.name %in% central_names,
    c("admin1.name", "admin1.char", "admin1"),
    drop = FALSE
  ])
  if (nrow(central_key) != 1L) {
    stop(
      "Expected exactly one canonical Central Admin-1 key for Malawi; found ",
      nrow(central_key),
      ".",
      call. = FALSE
    )
  }

  mod.dat[repair_rows, "admin1.name"] <- central_key$admin1.name
  mod.dat[repair_rows, "admin1.char"] <- central_key$admin1.char
  mod.dat[repair_rows, "admin1"] <- central_key$admin1
  mod.dat
}
