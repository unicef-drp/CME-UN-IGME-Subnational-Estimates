# Philippines OCHA Boundary Override Design

## Objective

Use the OCHA/HDX Philippines administrative boundaries, sourced from NAMRIA and PSA, for the Philippines only. Replace the defective GeoRepo geography in the Philippines pipeline without changing the default boundary source or behavior for any other country.

## Approved scope

- Apply the override only to `Philippines` (`PHL`).
- Include OCHA Admin-0, Admin-1, and Admin-2.
- Preserve the existing GeoRepo Philippines directory as a rollback source.
- Keep all shared statistical methods, model defaults, benchmarking, survey selection, and report behavior unchanged.
- Rerun every boundary-dependent stage, beginning with survey spatial processing.
- Do not update the country-list workbook.

## Source and provenance

The source dataset is [Philippines - Subnational Administrative Boundaries](https://data.humdata.org/dataset/cod-ab-phl). HDX identifies NAMRIA and PSA as the source agencies and OCHA as the preparer.

The country-specific preparation process will query the HDX CKAN metadata endpoint for dataset `cod-ab-phl`, select the resource whose format is `SHP`, and record:

- dataset page and CKAN metadata URLs;
- resource identifier, name, URL, byte size, hash, and modification date;
- dataset metadata modification date, version, source agencies, and license;
- normalized layer names and feature counts;
- validation results and preparation timestamp.

The downloaded archive is disposable. After successful normalization and verification, it will be removed from the temporary directory. Only normalized pipeline layers and provenance metadata will remain in the project.

## Architecture

### Country-specific preparation script

Create `Rcode/_script_for_specific_tasks/Philippines_OCHA_Boundaries.R`. It will be the only source-specific production code added for this override.

The script will:

1. Resolve the project root through the existing path helpers.
2. Accept an optional `PHILIPPINES_OCHA_SHP_ZIP` environment variable for an already-downloaded source archive; otherwise download the current HDX SHP resource to a temporary directory.
3. Extract only the source package needed for normalization.
4. Read `phl_admin0`, `phl_admin1`, and `phl_admin2`.
5. Normalize the pipeline columns:
   - Admin-0: `NAME_0 = "Philippines"`;
   - Admin-1: `NAME_0 = "Philippines"`, `NAME_1 = adm1_name`;
   - Admin-2: `NAME_0 = "Philippines"`, `NAME_1 = adm1_name`, `NAME_2 = adm2_name`.
6. Preserve OCHA codes and source attributes where the shapefile field-name limit permits.
7. Repair only invalid polygon geometry with the existing `sf` validity approach; do not simplify, dissolve, redraw, or manually shift boundaries.
8. Write a staging directory, validate it, then materialize the final directory only after all checks pass.
9. Write `ocha_download_metadata.json` beside the normalized layers.
10. Remove only the temporary download/extraction directory created by this invocation.

The script will expose pure normalization and validation functions so focused tests can run without downloading the 928 MB source archive.

### Normalized boundary contract

The final directory will be:

`Data/shapeFiles/ocha_PHL_shp`

It will contain these pipeline layers:

- `ocha_PHL_0`;
- `ocha_PHL_1`;
- `ocha_PHL_2`;
- `ocha_download_metadata.json`.

The existing `Data/shapeFiles/georepo_PHL_shp` directory will not be renamed, overwritten, or deleted.

### Philippines configuration

Update `Info/Philippines_general_info.json` to use:

- `poly.path = "../shapeFiles/ocha_PHL_shp"`;
- `poly.layer.adm0 = "ocha_PHL_0"`;
- `poly.layer.adm1 = "ocha_PHL_1"`;
- `poly.layer.adm2 = "ocha_PHL_2"`;
- `poly.label.adm1 = "NAME_1"`;
- `poly.label.adm2 = "NAME_2"`;
- `boundary_source = "OCHA HDX (NAMRIA/PSA)"`;
- `boundary_source_url = "https://data.humdata.org/dataset/cod-ab-phl"`.

The JSON loader already preserves additional named fields, so the provenance fields require no shared loader change. Existing countries retain their current GeoRepo paths and behavior.

### Pipeline integration

The normal pipeline checks whether all configured shapefiles exist. Once `ocha_PHL_0/1/2` are prepared, Step 2 is skipped and the configured OCHA layers are consumed by the unchanged downstream scripts.

No generic OCHA dispatcher, new global boundary abstraction, or country-independent source behavior will be added. This keeps the exception isolated and reverse-compatible.

The runner's historical Step 2 identifier may still mention GeoRepo when it records the skip. The authoritative Philippines JSON and `ocha_download_metadata.json` will identify the actual source. Changing the shared runner wording is outside this override.

## Validation contract

The prepared layers must satisfy all of the following before the Philippines configuration is switched:

- Admin-0 has exactly one non-empty feature.
- Admin-1 has exactly 17 features and 17 unique OCHA Admin-1 codes.
- Admin-2 has exactly 88 features and 88 unique OCHA Admin-2 codes.
- Every Admin-2 row has a non-empty Admin-1 parent code and parent name.
- The set of Admin-2 parent names is contained in the normalized Admin-1 names.
- All geometries are polygonal, non-empty, readable, and valid after allowed repair.
- The normalized CRS is WGS 84 (`EPSG:4326`).
- NCR exists exactly once as `National Capital Region (NCR)`.
- NCR area is between 500 and 700 square kilometres.
- All 126 DHS 2022 clusters whose survey Admin-1 name is `National Capital Region` fall within the OCHA NCR geometry.
- The normalized layers can be reopened from their final shapefile paths.

Any failed check stops before replacing the staging directory or changing downstream outputs.

## Test strategy

Follow red-green-refactor for production-code changes.

1. Add a focused test for synthetic OCHA Admin-0/1/2 inputs. It must initially fail because the Philippines normalizer does not exist, then pass after the minimal country-specific preparation functions are implemented.
2. Extend `tests/test_philippines_pipeline_config.R` so it initially fails on the existing GeoRepo paths and passes only with the approved OCHA paths and provenance fields.
3. Add an integration verification test that runs when the normalized OCHA layers are present. It checks the 1/17/88 feature contract, hierarchy, CRS, validity, NCR area, and DHS NCR point assignment.
4. Run the relevant existing path, configuration, and boundary-preparation regressions to confirm that all other countries continue to use their existing sources.

Network access will not be required by the automated unit tests. The large HDX download is an explicit preparation action, not a test fixture.

## Output invalidation and rerun

The failed Philippines run at `Results/Philippines/logs/20260802_133357` remains as historical evidence and will not be altered.

Because boundaries affect spatial assignment, adjacency, direct estimates, population weights, models, and reports, the new production run will begin from Step 3 after OCHA preparation. It will not reuse GeoRepo-derived country cluster files, adjacency matrices, direct estimates, weights, or model outputs as valid inputs.

The rerun will retain the approved Philippines survey scope:

- DHS 2003, 2008, 2017, and 2022;
- DHS 2013 excluded because GPS was not collected;
- 2017 and 2022 treated as the shared-frame surveys;
- Admin-1 plus available Admin-2;
- survey-derived strata weights;
- unstratified final model with AR1 time effect and benchmarked output.

The new run receives its own timestamped manifest and logs. Existing failed-run logs are preserved. Since no validated Philippines final deliverable exists, downstream files may be regenerated without duplicating the entire failed output tree as a rollback copy.

## Final inspection

After execution, verify the generated data and plots rather than relying on file existence:

- confirm every expected Admin-1, including NCR, receives survey clusters and population weights;
- inspect Admin-2 parent assignments and identify genuinely sparse areas;
- confirm annual population weights are finite, non-negative, and normalized;
- inspect pre-BB8 maps for missing or misassigned regions;
- inspect model comparison output for benchmark gaps, discontinuities, and missing series;
- inspect representative first, middle, and last Admin-1 and Admin-2 plots for NMR and U5MR;
- confirm the unstratified model is printed by default;
- inspect every page of the country-summary PDF and its final sub-area appendix;
- summarize any data, model, boundary, or presentation issue before reporting completion.

## Failure handling and rollback

- If HDX download or extraction fails, retain the existing GeoRepo directory and stop before changing the Philippines JSON.
- If OCHA normalization or validation fails, discard only the staging/temp directory and report the exact failed contract.
- If the pipeline fails after switching, keep the OCHA normalized layers, new manifest, and valid upstream artifacts; classify downstream outputs as unvalidated.
- Rollback consists of restoring the prior GeoRepo paths in `Info/Philippines_general_info.json`; the GeoRepo boundary directory remains intact throughout.

## Completion criteria

The override is complete only when:

1. the OCHA preparation and provenance files exist;
2. all focused and relevant regression tests pass;
3. the Philippines production pipeline completes through the final PDF;
4. NCR is represented at Admin-1 and contributes to weights and estimates;
5. Admin-2 outputs use the normalized OCHA hierarchy;
6. final data and plots have been inspected and issues summarized;
7. no other country configuration or boundary behavior changed.
