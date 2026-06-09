import argparse
import json
import os
import sys
from pathlib import Path

import pandas as pd

METRICS = {
    "total_cpu_seconds": "mean",
    "user_cpu_seconds": "mean",
    "system_cpu_seconds": "mean",
    "memory_peak_gb": "mean",
    "run_time": "mean",
}


def load_result_file(path: Path) -> pd.DataFrame | None:
    try:
        if path.stat().st_size == 0:
            print(f"Skipping empty result file: {path}")
            return None
        df = pd.read_csv(path, sep="|", decimal=",", dtype=str).rename(columns=str.strip)
        missing = [column for column in ["node_count", *METRICS.keys()] if column not in df.columns]
        if missing:
            print(f"Skipping malformed result file {path}: missing columns {', '.join(missing)}")
            return None
        for column in ["node_count", *METRICS.keys()]:
            df[column] = pd.to_numeric(df[column], errors="coerce")
        df.dropna(subset=["node_count"], inplace=True)
        for column in METRICS:
            df[column] = df[column].fillna(0)
        if df.empty:
            print(f"Skipping malformed result file {path}: no valid rows")
            return None
        return df
    except Exception as exc:
        print(f"Skipping malformed result file {path}: {exc}")
        return None


def summarize(df: pd.DataFrame) -> dict[str, dict[str, float]]:
    grouped = df.groupby("node_count").agg(METRICS).round(2)
    summary: dict[str, dict[str, float]] = {}
    for metric in METRICS:
        values = grouped[metric]
        summary[metric] = {
            "min": float(values.min()),
            "avg": float(round(values.mean(), 2)),
            "max": float(values.max()),
        }
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate summaries of performance from benchmark result CSV data.")
    parser.add_argument("-d", "--data_directory", type=str, required=True, help="Path to the directory containing CSV files.")
    parser.add_argument("-o", "--output_dir", type=str, default="plots", help="Directory to save summary.json.")
    args = parser.parse_args()

    data_dir = Path(args.data_directory)
    if not data_dir.is_dir():
        print(f"Error: Data directory '{data_dir}' does not exist or is not a directory.", file=sys.stderr)
        return 1

    summaries = {}
    for filepath in sorted(data_dir.iterdir()):
        if filepath.is_file() and filepath.suffix.lower() == ".csv" and ".preserved-" not in filepath.name:
            df = load_result_file(filepath)
            if df is not None:
                summaries[filepath.stem] = summarize(df)

    if not summaries:
        print(f"Error: no valid result CSV files found in '{data_dir}'.", file=sys.stderr)
        return 1

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_file = output_dir / "summary.json"
    with output_file.open("w", encoding="utf-8") as f:
        json.dump(summaries, f, indent=4)
    print(f"Saved summary: {output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
