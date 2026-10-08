# JSON-Only Country Pipeline Design

## Goal

Make the active country pipeline use `Info/<Country>_general_info.json` as its
only country-configuration source. Legacy `Info/*_create_info.R` and
`Info/*_general_info.Rdata` files remain untouched as historical artifacts, but
the active pipeline and its regression tests must not read, generate, or refer
users to them.

## Scope

The change covers the manual country entrypoint, shared country-info loader,
numbered pipeline scripts that load country context, the automated pipeline
runner's setup metadata, optional MICS geospatial preprocessing exposed by the
entrypoint, active configuration tests, and user-facing messages in active
pipeline steps.

Archived code and unrelated ad-hoc scripts are outside this change. The legacy
files themselves will not be modified or deleted.

## Architecture

Add a shared `load.country.info()` function to
`Rcode/_supporting_scripts/project_paths.R`. The function will:

1. Require one non-empty country name.
2. Resolve `Info/<Country>_general_info.json` from the project root or a supplied
   info directory.
3. Fail with the JSON path when the file is missing.
4. Parse the file with `jsonlite` while preserving vectors, nested objects such
   as `final_model`, and explicit JSON `null` values as R `NULL`.
5. Require a named top-level JSON object and verify that its `country` value
   matches the requested country.
6. Assign every top-level field into the requested environment and return the
   normalized JSON path invisibly.

The old `load.country.Rdata()` helper will be removed. There will be no alias or
fallback because retaining one would conceal a legacy configuration path.

## Pipeline Data Flow

`Rcode/run_country_pipeline.R` will no longer contain the country-info generation
Step 0. Its first executable block remains Step 1 and sources
`Rcode/1_Preperation.R`, whose documented input will be the country JSON file.

`Rcode/1_Preperation.R` will call `load.country.info()` before constructing
country data and result directories. `Rcode/3_DataProcessing_sf.R` will use the
same loader for its defensive context refresh. The MICS geospatial preprocessing
helper will also use the shared loader when opening country GeoRepo boundaries.

`make_pipeline_setup_steps()` in the pipeline runner will contain only the
preparation step. It will not create or execute a `_create_info.R` step.

Steps 7a and 7b will direct users to update
`Info/<Country>_general_info.json` when `frame_year` or related stratification
configuration is absent.

## Error Handling

The JSON loader will produce specific errors for an invalid country argument, a
missing JSON file, malformed or non-object JSON, missing `country`, and a country
name mismatch. It will never look for an `.Rdata` file after a JSON failure.

Existing downstream context validation remains responsible for reporting
missing pipeline fields such as boundary layers or projection years. This keeps
file parsing separate from each step's operational requirements.

## Tests

Follow test-driven development:

- Change the shared-loader test first so it requires `load.country.info()`, JSON
  field assignment, nested `final_model` preservation, explicit `NULL` handling,
  useful missing-file errors, and no legacy loader.
- Strengthen the manual-entrypoint test so Step 0 and legacy country-info terms
  are rejected and Step 1 explicitly identifies JSON as its input.
- Update pipeline-runner tests so setup begins with preparation and has no
  country-info generation step.
- Migrate active configuration tests from sourcing `_create_info.R` or loading
  `.Rdata` to reading the checked-in JSON files.
- Add a source-contract scan over active pipeline files to reject
  `_create_info.R`, `_general_info.Rdata`, and `load.country.Rdata` references.
- Run focused tests first, then the relevant project-path, pipeline-runner,
  configuration, preparation, data-processing, MICS, and no-working-directory
  regression tests.

## Working-Tree Safety

Several affected files already contain user changes. Implementation will make
targeted patches against the current working tree, preserve unrelated edits,
and avoid staging or committing implementation changes unless explicitly
requested.
