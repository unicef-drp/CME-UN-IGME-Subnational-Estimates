helper_path <- file.path(
  "Rcode",
  "_supporting_scripts",
  "bb8_temporal_diagnostics.R"
)

if (!file.exists(helper_path)) {
  stop("Missing BB8 temporal-diagnostics helper: ", helper_path)
}

source(helper_path)

old_value <- Sys.getenv("BB8_SKIP_ADMIN2_TEMPORAL_DIAG", unset = NA_character_)
on.exit({
  if (is.na(old_value)) {
    Sys.unsetenv("BB8_SKIP_ADMIN2_TEMPORAL_DIAG")
  } else {
    Sys.setenv(BB8_SKIP_ADMIN2_TEMPORAL_DIAG = old_value)
  }
}, add = TRUE)

diag_calls <- 0L
getDiag <- function(fit, field, year_label) {
  diag_calls <<- diag_calls + 1L
  list(fit = fit, field = field, year_label = year_label)
}

Sys.unsetenv("BB8_SKIP_ADMIN2_TEMPORAL_DIAG")
default_result <- bb8_get_temporal_diag(
  fit = "default-fit",
  admin_level = "Admin2",
  year_label = 2000:2001
)
stopifnot(diag_calls == 1L)
stopifnot(identical(default_result$fit, "default-fit"))

Sys.setenv(BB8_SKIP_ADMIN2_TEMPORAL_DIAG = "1")
skipped_result <- bb8_get_temporal_diag(
  fit = "admin2-fit",
  admin_level = "Admin2",
  year_label = 2000:2001
)
stopifnot(diag_calls == 1L)
stopifnot(is.null(skipped_result))

admin1_result <- bb8_get_temporal_diag(
  fit = "admin1-fit",
  admin_level = "Admin1",
  year_label = 2000:2001
)
stopifnot(diag_calls == 2L)
stopifnot(identical(admin1_result$fit, "admin1-fit"))

cat("Admin-2 temporal diagnostics are opt-in skippable and default-compatible.\n")
