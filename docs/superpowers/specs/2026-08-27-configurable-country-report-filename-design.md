# Configurable Country Report Filename Design

## Goal

Make every active country-summary render publish its assembled PDF as:

```text
Results/<CountryKey>/<Readable Country> Report <Report Year>.pdf
```

The 2026 round will default to `2026`, while later rounds can supply a different year without editing filename-building code.

## Current State

The repository has two active execution interfaces for the same country pipeline:

- `Rcode/run_country_pipeline.R` is the manual RStudio runbook. Its numbered report blocks can be executed individually.
- `Rcode/_supporting_scripts/pipeline_runner.R` provides the reusable automated `run_country_pipeline()` workflow.

Both interfaces currently construct `Results/<Country>/11_CountrySummary.pdf` independently. The reusable core PDF, `Figures/Summary/11_CountrySummary_core.pdf`, is an internal build artifact and is not part of the public naming change.

## Design

### Shared naming functions

Add shared helpers to `Rcode/_supporting_scripts/pipeline_runner.R`:

- A country display-name helper converts underscores to spaces.
- The display-name helper maps `Cote_dIvoire` to `Cote d'Ivoire` so future output matches the files already renamed in this round.
- A report-year normalizer accepts one scalar four-digit year and rejects missing, non-numeric, fractional, or out-of-range values with a clear error.
- A filename helper combines the normalized display name and year as `<Readable Country> Report <Year>.pdf`.

Both the manual and automated report paths will call the filename helper. No report path may construct the public filename independently.

### Configuration interfaces

The default report year is `2026`.

The manual entrypoint will expose:

```r
report_year <- 2026L
```

Command-line parsing will accept:

```text
--report-year 2027
```

The reusable automated interface will accept:

```r
run_country_pipeline(..., report_year = 2026L)
```

The normalized value will be placed in the pipeline context so the render step and run manifest use the same year. The manifest will record `report_year` for traceability.

### Rendering behavior

For `country = "Burkina_Faso"` and `report_year = 2026`, both active paths will assemble:

```text
Results/Burkina_Faso/Burkina Faso Report 2026.pdf
```

For `country = "Cote_dIvoire"`, the public filename will be:

```text
Results/Cote_dIvoire/Cote d'Ivoire Report 2026.pdf
```

The core render remains:

```text
Results/<CountryKey>/Figures/Summary/11_CountrySummary_core.pdf
```

The comparison-appendix assembly continues to receive an explicit output path; only the path supplied by the pipeline changes.

### Error handling

An invalid report year must fail before the report render begins. Accepted values represent a single whole year from `2000` through `2999`, supplied as an integer, a whole numeric value, or a four-digit character value. Values such as `NA`, `"26"`, `2026.5`, or vectors with multiple elements are rejected.

### Compatibility

- The default produces the filenames already established for the 2026 round.
- Internal comparison and core-PDF tests may continue using arbitrary temporary filenames because they test assembly behavior, not the public pipeline naming contract.
- Active pipeline output checks that explicitly expect `11_CountrySummary.pdf` will be updated to use the new public filename.
- Historical plans and specifications remain unchanged because they document prior behavior.

## Testing

Implementation will follow test-driven development:

1. Add failing unit tests for display-name conversion, the `Cote_dIvoire` override, default and alternate report years, and invalid year values.
2. Add failing interface tests for `--report-year`, the automated function argument, manifest recording, and both active render paths using the shared filename helper.
3. Implement the minimal shared helpers and interface wiring needed to make those tests pass.
4. Run the focused pipeline-runner and manual-entrypoint tests, then run the full repository test suite available for this workflow.
5. Verify source scans show no active public output assignment to `11_CountrySummary.pdf`, while the internal `11_CountrySummary_core.pdf` name remains intact.

Full country-report rendering is not required to validate filename construction because it is expensive and would regenerate unrelated analytical outputs. A focused assembly-path test with temporary PDFs will verify that the resolved public destination is honored without changing report contents.
