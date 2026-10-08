# Configurable Country Report Filename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make both active country-summary render paths publish `<Readable Country> Report <Report Year>.pdf`, with a configurable year that defaults to 2026.

**Architecture:** Put year validation, country display-name normalization, and public filename construction in shared helpers in `pipeline_runner.R`. Thread one normalized `report_year` through CLI parsing, the automated pipeline context and manifest, and the manual runbook; keep `11_CountrySummary_core.pdf` as the internal build artifact.

**Tech Stack:** R 4.6.1, base R scripts and assertions, `rmarkdown`, the existing previous-final PDF assembly workflow, PowerShell verification commands.

---

## Working-tree safety

The current workspace already contains unrelated modifications in both production files and several tests. Before every edit, capture `git diff -- <file>`; after every edit, inspect the same path and confirm only intended hunks were added. Do not stage or commit implementation files in this workspace unless a cached diff proves that no pre-existing user changes are included. The plan document itself may be committed independently.

## File map

- Create `tests/test_country_report_filename.R`: focused behavioral coverage for display names, report-year validation, CLI parsing, automated manifest propagation, and automated render-path wiring.
- Modify `Rcode/_supporting_scripts/pipeline_runner.R`: own the shared naming functions, parse `--report-year`, propagate it through `run_country_pipeline()`, record it in manifests, and use it for automated public output paths.
- Modify `tests/test_manual_country_pipeline_entrypoint.R`: assert the manual interface exposes and propagates the report year and uses the shared filename helper in both report blocks.
- Modify `Rcode/run_country_pipeline.R`: expose the manual default and CLI option, then use the shared helper for Steps 12 and 13.
- Modify `tests/test_philippines_pipeline_outputs.R`: update the country-specific acceptance check to the new 2026 public filename.
- Leave `Rcode/12_Previous_Final_Comparison.R` and its temporary-file tests unchanged: they already accept an explicit output path and do not own the public naming contract.

### Task 1: Define and test the shared filename contract

**Files:**
- Create: `tests/test_country_report_filename.R`
- Modify: `Rcode/_supporting_scripts/pipeline_runner.R:120-195`

- [ ] **Step 1: Write the failing helper and parser test**

Create `tests/test_country_report_filename.R` with:

```r
project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
runner_file <- file.path(
  project_dir, "Rcode", "_supporting_scripts", "pipeline_runner.R"
)
source(runner_file)

stopifnot(
  identical(country_report_display_name("Burkina_Faso"), "Burkina Faso"),
  identical(country_report_display_name("South Africa"), "South Africa"),
  identical(country_report_display_name("Cote_dIvoire"), "Cote d'Ivoire"),
  identical(normalize_report_year(2026L), 2026L),
  identical(normalize_report_year(2027), 2027L),
  identical(normalize_report_year("2028"), 2028L),
  identical(
    country_report_filename("Burkina_Faso", 2026L),
    "Burkina Faso Report 2026.pdf"
  ),
  identical(
    country_report_filename("Cote_dIvoire", "2027"),
    "Cote d'Ivoire Report 2027.pdf"
  )
)

invalid_years <- list(
  NA_integer_, "26", 2026.5, c(2026L, 2027L), "year", 1999L, 3000L
)
for (invalid_year in invalid_years) {
  result <- try(normalize_report_year(invalid_year), silent = TRUE)
  stopifnot(
    inherits(result, "try-error"),
    grepl("four-digit year from 2000 through 2999", as.character(result),
          fixed = TRUE)
  )
}

args <- parse_pipeline_args(
  c("--country", "Cameroon", "--report-year", "2027")
)
stopifnot(identical(args$report_year, 2027L))

args <- parse_pipeline_args(
  c("--country=Benin", "--report-year=2028")
)
stopifnot(identical(args$report_year, 2028L))

default_args <- parse_pipeline_args(character(), country = "Ethiopia")
stopifnot(identical(default_args$report_year, 2026L))

bad_args <- try(
  parse_pipeline_args(c("--country", "Cameroon", "--report-year", "26")),
  silent = TRUE
)
stopifnot(inherits(bad_args, "try-error"))

message("country report filename helper tests passed")
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_country_report_filename.R
```

Expected: FAIL with `could not find function "country_report_display_name"`.

- [ ] **Step 3: Add the minimal shared helpers**

In `Rcode/_supporting_scripts/pipeline_runner.R`, immediately after `normalize_pipeline_mode()`, add:

```r
country_report_display_name <- function(country) {
  if (length(country) != 1L || is.na(country) || !nzchar(as.character(country))) {
    stop("Country must be one non-empty value.", call. = FALSE)
  }
  country <- as.character(country)
  if (identical(country, "Cote_dIvoire")) {
    return("Cote d'Ivoire")
  }
  gsub("_", " ", country, fixed = TRUE)
}

normalize_report_year <- function(report_year = 2026L) {
  valid <- length(report_year) == 1L &&
    !is.na(report_year) &&
    grepl("^[0-9]{4}$", as.character(report_year))
  value <- suppressWarnings(as.numeric(report_year))
  valid <- valid && is.finite(value) && value == floor(value) &&
    value >= 2000 && value <= 2999
  if (!valid) {
    stop(
      "Report year must be one four-digit year from 2000 through 2999.",
      call. = FALSE
    )
  }
  as.integer(value)
}

country_report_filename <- function(country, report_year = 2026L) {
  paste0(
    country_report_display_name(country),
    " Report ",
    normalize_report_year(report_year),
    ".pdf"
  )
}
```

- [ ] **Step 4: Parse and return the report year**

Change the parser signature to:

```r
parse_pipeline_args <- function(args = commandArgs(trailingOnly = TRUE),
                                country = "",
                                mode = Sys.getenv("UN_SUBNATIONAL_MODE", unset = "preview"),
                                render_summary = TRUE,
                                report_year = 2026L) {
```

Add these cases after the mode cases and before summary flags:

```r
    } else if (arg == "--report-year") {
      report_year <- next_arg(i, arg)
      i <- i + 1L
    } else if (grepl("^--report-year=", arg)) {
      report_year <- sub("^--report-year=", "", arg)
```

Return the normalized year in the parser result:

```r
  list(
    country = country,
    mode = normalize_pipeline_mode(mode),
    render_summary = isTRUE(render_summary),
    report_year = normalize_report_year(report_year),
    help = help
  )
```

- [ ] **Step 5: Run the helper test and existing parser tests**

Run:

```powershell
$rscript = 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe'
& $rscript tests/test_country_report_filename.R
if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $rscript tests/test_pipeline_runner.R
```

Expected: both scripts exit `0` and print their pass messages.

- [ ] **Step 6: Inspect the Task 1 diff checkpoint**

Run:

```powershell
git diff --check -- Rcode/_supporting_scripts/pipeline_runner.R tests/test_country_report_filename.R
git diff -- Rcode/_supporting_scripts/pipeline_runner.R tests/test_country_report_filename.R
```

Expected: no whitespace errors; helper/parser hunks are present and all pre-existing runner changes remain intact. Do not commit if unrelated runner hunks would be included.

### Task 2: Propagate the year through the automated runner

**Files:**
- Modify: `tests/test_country_report_filename.R`
- Modify: `Rcode/_supporting_scripts/pipeline_runner.R:490-525,776-825`

- [ ] **Step 1: Add failing automated-path tests**

Append to `tests/test_country_report_filename.R` before the final `message()`:

```r
runner_text <- paste(readLines(runner_file, warn = FALSE), collapse = "\n")
stopifnot(
  grepl(
    "country_report_filename(country, report_year)",
    runner_text,
    fixed = TRUE
  ),
  !grepl(
    'output_summary_pdf <- file.path(output_dir, "11_CountrySummary.pdf")',
    runner_text,
    fixed = TRUE
  ),
  identical(formals(run_country_pipeline)$report_year, quote(2026L))
)

local({
  original_setup <- make_pipeline_setup_steps
  original_steps <- make_pipeline_steps
  original_writer <- write_pipeline_outputs
  on.exit({
    assign("make_pipeline_setup_steps", original_setup, envir = .GlobalEnv)
    assign("make_pipeline_steps", original_steps, envir = .GlobalEnv)
    assign("write_pipeline_outputs", original_writer, envir = .GlobalEnv)
  })

  assign(
    "make_pipeline_setup_steps",
    function(...) list(),
    envir = .GlobalEnv
  )
  assign(
    "make_pipeline_steps",
    function(...) list(),
    envir = .GlobalEnv
  )
  assign(
    "write_pipeline_outputs",
    function(...) invisible(TRUE),
    envir = .GlobalEnv
  )

  pipeline_dir <- tempfile("report_year_pipeline_")
  dir.create(pipeline_dir)
  manifest <- run_country_pipeline(
    country = "Test_Country",
    mode = "production",
    render_summary = FALSE,
    report_year = "2027",
    project_dir = pipeline_dir,
    prompt = function(...) stop("production run should not prompt")
  )
  stopifnot(
    identical(manifest$report_year, 2027L),
    identical(manifest$country, "Test_Country")
  )
})
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_country_report_filename.R
```

Expected: FAIL because the automated render still builds `11_CountrySummary.pdf` and `run_country_pipeline()` has no `report_year` argument.

- [ ] **Step 3: Use the shared name in automated rendering**

In the `render_rmd` branch of `source_pipeline_script()`, get the year and replace the public path assignment:

```r
    report_year <- get("report_year", envir = context, inherits = TRUE)
```

```r
    output_summary_pdf <- file.path(
      output_dir,
      country_report_filename(country, report_year)
    )
```

Do not change:

```r
core_summary_pdf <- file.path(
  summary_build_dir, "11_CountrySummary_core.pdf"
)
```

- [ ] **Step 4: Propagate and record the normalized year**

Change the automated function signature and setup to:

```r
run_country_pipeline <- function(country,
                                 mode = "preview",
                                 render_summary = TRUE,
                                 report_year = 2026L,
                                 project_dir = pipeline_project_dir(),
                                 prompt = readline) {
  mode <- normalize_pipeline_mode(mode)
  report_year <- normalize_report_year(report_year)
```

Add to the context:

```r
  context$report_year <- report_year
```

Add to the manifest beside `render_summary`:

```r
    report_year = report_year,
```

- [ ] **Step 5: Run the focused tests and verify GREEN**

Run:

```powershell
$rscript = 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe'
& $rscript tests/test_country_report_filename.R
if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $rscript tests/test_pipeline_runner.R
```

Expected: both scripts exit `0`; the focused test reports that the manifest contains `2027L`.

- [ ] **Step 6: Inspect the Task 2 diff checkpoint**

Run:

```powershell
git diff --check -- Rcode/_supporting_scripts/pipeline_runner.R tests/test_country_report_filename.R
git diff -- Rcode/_supporting_scripts/pipeline_runner.R tests/test_country_report_filename.R
```

Expected: the automated path has one public filename-helper call, the manifest records the year, and no unrelated working-tree hunk is altered.

### Task 3: Wire the manual runbook to the same contract

**Files:**
- Modify: `tests/test_manual_country_pipeline_entrypoint.R`
- Modify: `Rcode/run_country_pipeline.R:1-40,196-252`

- [ ] **Step 1: Add failing manual-interface assertions**

In `tests/test_manual_country_pipeline_entrypoint.R`, after the existing country/runner-source assertions, add:

```r
report_year_assignment <- grep(
  "^report_year\\s*<-\\s*2026L$",
  trimmed
)
stopifnot(
  length(report_year_assignment) == 1L,
  report_year_assignment < runner_source,
  grepl("report_year = report_year", text, fixed = TRUE),
  grepl("report_year <- args$report_year", text, fixed = TRUE),
  grepl("--report-year YEAR", text, fixed = TRUE),
  sum(grepl(
    "country_report_filename(country, report_year)",
    lines,
    fixed = TRUE
  )) == 2L,
  !grepl(
    'output_summary_pdf <- file.path(summary_result_dir, "11_CountrySummary.pdf")',
    text,
    fixed = TRUE
  )
)
```

- [ ] **Step 2: Run the manual test and verify RED**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_manual_country_pipeline_entrypoint.R
```

Expected: FAIL because the runbook does not yet define or propagate `report_year`.

- [ ] **Step 3: Expose the manual default and CLI option**

At the top of `Rcode/run_country_pipeline.R`, add:

```r
report_year <- 2026L
```

Pass it into parsing:

```r
args <- parse_pipeline_args(
  country = country,
  mode = mode,
  render_summary = render_summary,
  report_year = report_year
)
```

Change the help text to include the option:

```r
    "Usage: Rscript Rcode/run_country_pipeline.R [--country COUNTRY] [--mode preview|production] [--report-year YEAR] [--skip-summary]\n",
```

After parsing, assign:

```r
report_year <- args$report_year
```

- [ ] **Step 4: Use the shared helper in Steps 12 and 13**

In both report blocks, replace the old public path assignment with:

```r
  output_summary_pdf <- file.path(
    summary_result_dir,
    country_report_filename(country, report_year)
  )
```

Update the Step 12 comment to:

```r
# Results/<Country>/<Readable Country> Report <Report Year>.pdf.
```

Keep both internal `11_CountrySummary_core.pdf` assignments unchanged.

- [ ] **Step 5: Run manual and automated regression tests**

Run:

```powershell
$rscript = 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe'
& $rscript tests/test_manual_country_pipeline_entrypoint.R
if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $rscript tests/test_country_report_filename.R
if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $rscript tests/test_pipeline_runner.R
```

Expected: all three scripts exit `0` and print their pass messages.

- [ ] **Step 6: Inspect the Task 3 diff checkpoint**

Run:

```powershell
git diff --check -- Rcode/run_country_pipeline.R tests/test_manual_country_pipeline_entrypoint.R
git diff -- Rcode/run_country_pipeline.R tests/test_manual_country_pipeline_entrypoint.R
```

Expected: only the report-year interface, shared output naming, comments, and test assertions are added to the pre-existing runbook work.

### Task 4: Update the active country output check and verify the workflow

**Files:**
- Modify: `tests/test_philippines_pipeline_outputs.R:96-106`
- Verify: `tests/test_previous_final_comparison.R`

- [ ] **Step 1: Confirm the Philippines check is RED against renamed outputs**

Run:

```powershell
& 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe' tests/test_philippines_pipeline_outputs.R
```

Expected: FAIL at the summary-file assertion because `Results/Philippines/11_CountrySummary.pdf` no longer exists.

- [ ] **Step 2: Update the expected public filename**

In `tests/test_philippines_pipeline_outputs.R`, replace:

```r
summary_path <- file.path(result_dir, "11_CountrySummary.pdf")
```

with:

```r
summary_path <- file.path(result_dir, "Philippines Report 2026.pdf")
```

- [ ] **Step 3: Run the Philippines check and PDF-assembly regression**

Run:

```powershell
$rscript = 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe'
& $rscript tests/test_philippines_pipeline_outputs.R
if ($LASTEXITCODE) { exit $LASTEXITCODE }
& $rscript tests/test_previous_final_comparison.R
```

Expected: both scripts exit `0`. The comparison test may continue to use `11_CountrySummary.pdf` as a temporary arbitrary destination.

- [ ] **Step 4: Run the complete focused suite**

Run:

```powershell
$rscript = 'C:\Users\yanliu\AppData\Local\Programs\R\R-4.6.1\bin\Rscript.exe'
$tests = @(
  'tests/test_country_report_filename.R',
  'tests/test_pipeline_runner.R',
  'tests/test_manual_country_pipeline_entrypoint.R',
  'tests/test_philippines_pipeline_outputs.R',
  'tests/test_previous_final_comparison.R'
)
foreach ($test in $tests) {
  & $rscript $test
  if ($LASTEXITCODE) { throw "Test failed: $test" }
}
```

Expected: five scripts exit `0` with no warnings or errors attributable to this change.

- [ ] **Step 5: Verify the source and artifact contracts**

Run:

```powershell
$activeFiles = @(
  'Rcode/run_country_pipeline.R',
  'Rcode/_supporting_scripts/pipeline_runner.R'
)
$activeText = ($activeFiles | ForEach-Object {
  Get-Content -LiteralPath $_ -Raw
}) -join "`n"
if ($activeText -match 'output_summary_pdf\s*<-\s*file\.path\([^\n]+"11_CountrySummary\.pdf"') {
  throw 'An active public output path still uses 11_CountrySummary.pdf.'
}
if (([regex]::Matches(
  $activeText,
  'country_report_filename\(country, report_year\)'
)).Count -ne 3) {
  throw 'Expected one automated and two manual filename-helper calls.'
}
if (([regex]::Matches(
  $activeText,
  '11_CountrySummary_core\.pdf'
)).Count -lt 3) {
  throw 'Internal core-summary filename was unexpectedly removed.'
}
'SOURCE CONTRACT PASSED'
```

Expected: `SOURCE CONTRACT PASSED`.

- [ ] **Step 6: Review all scoped diffs without staging unrelated work**

Run:

```powershell
$scoped = @(
  'Rcode/_supporting_scripts/pipeline_runner.R',
  'Rcode/run_country_pipeline.R',
  'tests/test_country_report_filename.R',
  'tests/test_manual_country_pipeline_entrypoint.R',
  'tests/test_philippines_pipeline_outputs.R'
)
git diff --check -- $scoped
git status --short -- $scoped
git diff -- $scoped
```

Expected: no whitespace errors; every requested behavior is visible. Do not stage or commit the implementation unless isolated staged hunks can be reviewed independently from the pre-existing modifications.

## Completion criteria

- Default output: `<Readable Country> Report 2026.pdf`.
- Alternate CLI and programmatic years produce the same filename pattern.
- `Cote_dIvoire` produces `Cote d'Ivoire` and underscores elsewhere become spaces.
- Invalid years fail before rendering.
- Both active generation paths use the same helper.
- The automated manifest records the normalized report year.
- `11_CountrySummary_core.pdf` remains internal and unchanged.
- All five focused verification scripts pass.
- No unrelated working-tree changes are staged, overwritten, or reverted.
