# Dashboard Ribbon and Smoothed-Direct Horizon Design

## Goal

Make a dashboard legend click hide both a method's median line and uncertainty band, and prevent unsupported projected Admin-1 smoothed-direct estimates from creating misleading spikes.

## Design

Each Plotly uncertainty-band trace and its corresponding median-line trace will use the same method-specific `legendgroup`. The shared chart layout will explicitly use `groupclick = "togglegroup"`, so the one visible legend item controls every trace in that method group. This applies to national comparison charts and Admin-1 regional charts.

The comparison-data builder will define the last observed-period midpoint from the survey-period boundaries. Admin-1 period and yearly smoothed-direct aggregates will be limited to that cutoff before they enter `natl.all`. For Kenya, the final observed period is 2020-2022, so the cutoff is 2021. This retains the supported diagnostic history and removes the sparse 2022 yearly boundary estimate and the unsupported 2023-2025 projections. BB8 and IGME series remain unchanged through 2025.

## Verification

Static regression tests will require grouped ribbon traces, grouped legend clicks, and the observed-period cutoff in the comparison builder. The Kenya dashboard will be regenerated with `BB8_ADMIN1_ONLY=1`; its RDS bundle must show no Admin-1 smoothed-direct values after 2021 while retaining BB8 and IGME through 2025. The self-contained HTML must contain the grouped Plotly configuration.
