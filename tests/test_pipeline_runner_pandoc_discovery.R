runner_env <- new.env(parent = globalenv())
sys.source(
  file.path("Rcode", "_supporting_scripts", "pipeline_runner.R"),
  envir = runner_env
)

if (!exists("configure_pipeline_pandoc", envir = runner_env, inherits = FALSE) ||
    !is.function(runner_env$configure_pipeline_pandoc)) {
  stop("pipeline_runner.R should provide configure_pipeline_pandoc().",
       call. = FALSE)
}

old_pandoc <- Sys.getenv("RSTUDIO_PANDOC", unset = NA_character_)
on.exit({
  if (is.na(old_pandoc)) {
    Sys.unsetenv("RSTUDIO_PANDOC")
  } else {
    Sys.setenv(RSTUDIO_PANDOC = old_pandoc)
  }
}, add = TRUE)
Sys.unsetenv("RSTUDIO_PANDOC")

if (!isTRUE(runner_env$configure_pipeline_pandoc()) ||
    !rmarkdown::pandoc_available()) {
  stop("The pipeline should discover an installed Pandoc for CLI rendering.",
       call. = FALSE)
}

cat("Pipeline runner Pandoc discovery regression test passed.\n")

if (!exists("find_pipeline_quarto", envir = runner_env, inherits = FALSE) ||
    !is.function(runner_env$find_pipeline_quarto)) {
  stop("pipeline_runner.R should provide find_pipeline_quarto().",
       call. = FALSE)
}

quarto_path <- runner_env$find_pipeline_quarto()
if (!nzchar(quarto_path) || !file.exists(quarto_path)) {
  stop("The pipeline should discover an installed Quarto for CLI dashboards.",
       call. = FALSE)
}

cat("Pipeline runner Quarto discovery regression test passed.\n")

comparison_script <- paste(
  readLines(file.path("Rcode", "9_Comparison_Plot.R"), warn = FALSE),
  collapse = "\n"
)
if (!grepl("find_pipeline_quarto", comparison_script, fixed = TRUE)) {
  stop(
    "9_Comparison_Plot.R should use portable Quarto discovery for dashboards.",
    call. = FALSE
  )
}

cat("BB8 comparison uses portable Quarto discovery.\n")
