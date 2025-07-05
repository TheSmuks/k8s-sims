import pandas as pd
import argparse
import os
import json

def main():
    parser = argparse.ArgumentParser(description="Generate plots from CSV data.")
    parser.add_argument("-d", "--data_directory", type=str, help="Path to the directory containing CSV files.", required=True)
    parser.add_argument("-o", "--output_dir", type=str, default="plots", help="Directory to save generated plots.")
    args = parser.parse_args()

    if not os.path.isdir(args.data_directory):
        print(f"Error: Data directory '{args.data_directory}' not found.")
        return

    summaries = dict()
    metrics = {
        "total_cpu_seconds": "mean",
        "user_cpu_seconds": "mean",
        "system_cpu_seconds": "mean",
        "memory_peak_gb": "mean",
        "run_time": "mean"
    }
    for filename in os.listdir(args.data_directory):
        if filename.lower().endswith(".csv"):
            filepath = os.path.join(args.data_directory, filename)
            simulator = os.path.splitext(filename)[0]
            df = pd.read_csv(filepath, sep="|")
            grouped = df.groupby("node_count").agg(metrics).round(2)
            summary = dict()
            for metric in metrics.keys():
                summary[metric] = {
                    "min": grouped[metric].min(),
                    "avg": grouped[metric].mean().round(2),
                    "max": grouped[metric].max(),
                }
            summaries[simulator] = summary
    output_file = os.path.join(args.output_dir, "summary.json")
    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)
    with open(output_file, "w") as f:
        json.dump(summaries, f, indent=4)

if __name__ == "__main__":
    main()