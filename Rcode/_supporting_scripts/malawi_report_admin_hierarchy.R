add_malawi_report_admin1 <- function(poly_adm2,
                                     parent_column = "NAME_1") {
  if (!parent_column %in% names(poly_adm2)) {
    stop("Malawi Admin-2 boundaries are missing parent column: ",
         parent_column, call. = FALSE)
  }

  parent <- as.character(poly_adm2[[parent_column]])
  if (anyNA(parent) || any(!nzchar(trimws(parent)))) {
    stop("Malawi Admin-2 boundaries contain missing Admin-1 parents.",
         call. = FALSE)
  }

  poly_adm2$DHSREGEN <- parent
  poly_adm2
}
