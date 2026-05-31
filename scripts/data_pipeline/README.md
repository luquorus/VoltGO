# Data Pipeline For Thesis AI

This folder provides a minimal reproducible pipeline for:

- extracting booking and station data from PostgreSQL (Docker),
- generating feature-ready CSV artifacts,
- augmenting sparse time slots with controlled synthetic rows,
- producing train/validation/test splits for experiments.

## Files

- `extract_ai_dataset.sql` - SQL query for raw AI dataset.
- `export_ai_dataset.ps1` - exports dataset CSV from Docker Postgres.
- `build_splits.ps1` - creates train/val/test CSV files by time.

## Usage (Windows PowerShell)

1) Export raw dataset:

```powershell
cd scripts/data_pipeline
./export_ai_dataset.ps1
```

2) Build splits:

```powershell
./build_splits.ps1
```

## Output

Generated under `data/ai/`:

- `raw_booking_dataset.csv`
- `train.csv`
- `val.csv`
- `test.csv`

## Notes

- Time-based split is used to avoid leakage.
- Synthetic balancing is intentionally lightweight and transparent.
- This pipeline is designed for reproducibility, not heavy ML training.
