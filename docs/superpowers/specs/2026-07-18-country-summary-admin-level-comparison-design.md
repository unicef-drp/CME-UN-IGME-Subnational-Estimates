# Country-summary comparison levels and pagination

## Goal

Regenerate the Ghana and Guinea country-summary PDFs in A4 portrait format with the previous-final comparison appendix included. The appendix must plot Admin 1 and, when comparison inputs exist, Admin 2, using six regions per page.

## Output design

- Keep one public deliverable per country: `Results/<Country>/11_CountrySummary.pdf`.
- Retain the existing portrait A4 core summary.
- Append comparison sections in this order: Admin 1 U5MR, Admin 1 NMR, Admin 2 U5MR, Admin 2 NMR.
- Use a two-column by three-row facet grid, giving six regions per page.
- Keep incomplete final pages in the same grid and blank unused panels.
- Include Admin 2 only when the 2023-final workbook and current model outputs contain that level. Ghana therefore remains Admin 1 only; Guinea includes Admin 1 and Admin 2.

## Implementation

Generalize the comparison helpers in `Rcode/12_Previous_Final_Comparison.R` to accept an administrative level instead of hard-coding Admin 1. Resolve model and direct-result filenames for the requested level, attach the level to exported comparison data, and build one appendix PDF in the specified section order. Admin 1 remains required; unavailable Admin 2 inputs are skipped with an informative message.

Set all pipeline entry points to six regions per page. Preserve the existing temporary-build and atomic final-PDF assembly behavior so an open public PDF cannot corrupt the new output.

## Error handling

- Fail when required Admin 1 previous-final or current model data are absent.
- Treat Admin 2 as optional and include it only when both previous-final and current model files are available.
- Permit missing direct-series files for an otherwise available level by plotting model comparisons without survey-direct overlays and reporting the omission.
- Continue using the locked-file fallback when Windows prevents replacing an open public PDF.

## Verification

- Add regression tests for Admin 1 and Admin 2 selection, generic result paths, six-region pagination, a 2x3 facet layout, section titles, and pipeline defaults.
- Run the comparison and summary-path tests.
- Regenerate both country PDFs.
- Confirm all pages are A4 portrait, comparison section titles are present in the correct order, Ghana has only Admin 1 comparisons, and Guinea has both levels.
- Render representative full and partial comparison pages to PNG and inspect for clipping, overlap, and legibility.
