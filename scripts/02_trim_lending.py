"""Sample and trim LendingClub accepted loans for POC loading."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

COLUMNS = [
    "id",
    "loan_amnt",
    "term",
    "int_rate",
    "installment",
    "grade",
    "sub_grade",
    "emp_length",
    "home_ownership",
    "annual_inc",
    "purpose",
    "loan_status",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Path to accepted_2007_to_2018Q4.csv")
    parser.add_argument("--output", default="data/lendingclub_5k.csv")
    parser.add_argument("--rows", type=int, default=5000)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    df = pd.read_csv(input_path, low_memory=False)
    trimmed = df[COLUMNS].dropna(subset=["id", "loan_status"]).head(args.rows)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    trimmed.to_csv(output_path, index=False)
    print(f"Wrote {len(trimmed)} rows to {output_path}")


if __name__ == "__main__":
    main()
