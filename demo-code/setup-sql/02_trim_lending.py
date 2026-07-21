#!/usr/bin/env python3
"""Trim LendingClub dataset to 5k rows and 12 columns for the POC."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import pandas as pd

KEEP_COLUMNS = [
    "id",
    "loan_amnt",
    "term",
    "int_rate",
    "grade",
    "sub_grade",
    "emp_length",
    "home_ownership",
    "annual_inc",
    "purpose",
    "loan_status",
    "issue_d",
]


def require_demo_venv() -> None:
    expected = Path(__file__).resolve().parent.parent / ".venv"
    active = Path(sys.prefix).resolve()
    if active != expected.resolve():
        raise SystemExit(
            "ERROR: .venv is not active for this demo. "
            "Run: source scripts/00_setup_venv.sh"
        )


def main() -> None:
    require_demo_venv()

    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Path to raw LendingClub CSV")
    parser.add_argument("--output", required=True, help="Path to trimmed CSV")
    parser.add_argument("--rows", type=int, default=5000, help="Sample row count")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(input_path, low_memory=False)
    existing = [c for c in KEEP_COLUMNS if c in df.columns]
    trimmed = df[existing].head(args.rows).copy()
    trimmed.to_csv(output_path, index=False)

    print(f"Wrote {len(trimmed)} rows with {len(existing)} columns to {output_path}")


if __name__ == "__main__":
    main()
