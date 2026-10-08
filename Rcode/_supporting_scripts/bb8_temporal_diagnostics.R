bb8_get_temporal_diag <- function(fit,
                                  admin_level,
                                  year_label,
                                  field = "time") {
  skip_admin2 <- tolower(
    Sys.getenv("BB8_SKIP_ADMIN2_TEMPORAL_DIAG", "0")
  ) %in% c("1", "true", "yes", "y")

  if (identical(tolower(admin_level), "admin2") && skip_admin2) {
    message(
      "BB8_SKIP_ADMIN2_TEMPORAL_DIAG=1; skipping experimental ",
      "Admin-2 temporal posterior diagnostics."
    )
    return(NULL)
  }

  getDiag(fit, field = field, year_label = year_label)
}
