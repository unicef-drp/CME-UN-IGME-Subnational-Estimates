env <- new.env(parent = baseenv())
sys.source(
  file.path("Rcode", "_supporting_scripts", "direct_smoothing_inputs.R"),
  envir = env
)

input <- data.frame(
  region = c("regular", "zero", "rounded_zero", "missing"),
  mean = c(0.04, 0.08, 0.13, NA_real_),
  lower = c(0.03, 0.08, 0.13, NA_real_),
  upper = c(0.05, 0.08, 0.13, NA_real_),
  logit.est = c(-3.18, -2.44, -1.90, NA_real_),
  var.est = c(0.04, 0, 1e-22, NA_real_),
  logit.prec = c(25, Inf, 1e22, NA_real_)
)

sanitized <- env$exclude_degenerate_direct_variances(
  input,
  variance_floor = 1e-12,
  label = "test"
)

stopifnot(identical(attr(sanitized, "excluded_degenerate_variances"), 2L))
stopifnot(isTRUE(all.equal(
  unclass(sanitized[1, ]),
  unclass(input[1, ]),
  check.attributes = FALSE
)))
stopifnot(all(is.na(sanitized[2:3, c(
  "mean", "lower", "upper", "logit.est", "var.est", "logit.prec"
)])))
stopifnot(all(is.na(sanitized[4, c(
  "mean", "lower", "upper", "logit.est", "var.est", "logit.prec"
)])))

cat("Degenerate direct-estimate variances are excluded from smoothing inputs.\n")
