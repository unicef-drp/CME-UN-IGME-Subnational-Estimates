script <- paste(
  readLines(file.path(
    "Rcode", "_script_for_specific_tasks", "MICS_DataProcessing.R"
  ), warn = FALSE),
  collapse = "\n"
)

madagascar_start <- regexpr("# Madagascar 2018", script, fixed = TRUE)[1]
dr_congo_start <- regexpr("# DR Congo 2018", script, fixed = TRUE)[1]
stopifnot(madagascar_start > 0L, dr_congo_start > madagascar_start)
madagascar_block <- substr(script, madagascar_start, dr_congo_start - 1L)

stopifnot(grepl("matches the 2014-2021 SALB Admin-2 names", madagascar_block,
                fixed = TRUE))
stopifnot(!grepl('"Alaotra Mangoro" = "Alaotra-Mangoro"', madagascar_block,
                 fixed = TRUE))
stopifnot(!grepl('"Amoron\'i Mania" = "Amoron\'imania"', madagascar_block,
                 fixed = TRUE))
stopifnot(!grepl('"Vatovavy Fitovinany" = "VatovavyFitovinany"',
                 madagascar_block, fixed = TRUE))

source(file.path(
  "Rcode", "_script_for_specific_tasks", "Madagascar_MICS_DataProcessing.R"
))
stopifnot(is.function(prepare_madagascar_mics_2018))

mics_env <- new.env(parent = emptyenv())
load(file.path("Data", "MICS", "Madagascar", "mdg.2018.tmp.rda"),
     envir = mics_env)
stopifnot(exists("dat.tmp", envir = mics_env, inherits = FALSE))
prepared <- get("dat.tmp", envir = mics_env)
expected_names <- sort(c(
  "Alaotra Mangoro", "Amoron'i Mania", "Analamanga", "Analanjirofo",
  "Androy", "Anosy", "Atsimo Andrefana", "Atsimo Atsinanana",
  "Atsinanana", "Betsiboka", "Boeny", "Bongolava", "Diana",
  "Haute Matsiatra", "Ihorombe", "Itasy", "Melaky", "Menabe",
  "Sava", "Sofia", "Vakinankaratra", "Vatovavy Fitovinany"
))
stopifnot(identical(sort(unique(as.character(prepared$admin2.name))),
                    expected_names))

cat("Madagascar MICS preprocessing retains SALB-native Admin-2 names.\n")
