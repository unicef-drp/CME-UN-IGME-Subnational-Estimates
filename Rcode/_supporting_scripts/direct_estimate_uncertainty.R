direct_standard_error_bounds <- function(direct) {
  required <- c("mean", "logit.est", "var.est")
  missing <- setdiff(required, names(direct))
  if (length(missing) > 0L) {
    stop(
      "Direct estimates are missing: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (any(direct$var.est < 0, na.rm = TRUE)) {
    stop("Direct-estimate variances must be non-negative.", call. = FALSE)
  }

  se_logit <- sqrt(direct$var.est)
  data.frame(
    se_logit = se_logit,
    lower_1se = stats::plogis(direct$logit.est - se_logit),
    upper_1se = stats::plogis(direct$logit.est + se_logit),
    se_probability = direct$mean * (1 - direct$mean) * se_logit
  )
}
