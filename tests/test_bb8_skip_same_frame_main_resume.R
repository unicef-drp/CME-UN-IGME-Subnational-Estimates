script_path <- file.path("Rcode", "8_10_BB8.R")
script <- readLines(script_path, warn = FALSE)

stopifnot(any(grepl(
  'Sys.getenv("BB8_SKIP_SAME_FRAME_MAIN", "0")',
  script,
  fixed = TRUE
)))
same_frame_nmr_guard_start <- grep(
  "if (!bb8_skip_same_frame_main &&",
  script,
  fixed = TRUE
)[1]
stopifnot(!is.na(same_frame_nmr_guard_start))
same_frame_nmr_guard <- paste(
  script[same_frame_nmr_guard_start + 0:2],
  collapse = " "
)
stopifnot(
  grepl("!bb8_skip_same_frame_main", same_frame_nmr_guard, fixed = TRUE),
  grepl("!bb8_skip_same_frame_nmr", same_frame_nmr_guard, fixed = TRUE),
  grepl("!bb8_repair_admin2_strat_u5_only", same_frame_nmr_guard,
        fixed = TRUE)
)
stopifnot(any(grepl(
  "if (!bb8_skip_same_frame_main) {",
  script,
  fixed = TRUE
)))
stopifnot(any(grepl(
  "retaining completed same-frame main model outputs",
  script,
  fixed = TRUE
)))

message("BB8 same-frame main-model resume guard tests passed.")
