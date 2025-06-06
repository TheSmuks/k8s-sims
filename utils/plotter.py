import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import argparse
from scipy.interpolate import make_interp_spline

def load_and_clean_data(filepath:str):
    try:
        df = pd.read_csv(filepath, sep='|', decimal=',')

        cols = [
            'node_count', 'pod_count', 'run_time',
            'total_cpu_seconds', 'user_cpu_seconds', 'system_cpu_seconds',
            'memory_peak_gb', 'unscheduled_pods'
        ]

        for col in cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')
            else:
                df[col] = 0

        df.dropna(subset=['node_count'], inplace=True)

        if 'unscheduled_pods' in df.columns:
            df['unscheduled_pods'].fillna(0, inplace=True)
        else:
            df['unscheduled_pods'] = 0

        df = df.groupby('node_count', as_index=False).mean()
        df.sort_values(by='node_count', inplace=True)
        # df.groupby(['node_count']).mean().dropna().reset_index()
        # df.sort_values(by='node_count', inplace=True)
        print(df)
        return df
    except Exception as e:
        print(f"Error processing file {filepath}: {e}")
        return None

def plot_comparison(data: dict[str, pd.DataFrame], output_dir: str):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    metrics_to_plot = {
        'run_time': 'Run Time (seconds)',
        'pod_count': 'Scheduled Pod Count',
        'unscheduled_pods': 'Unscheduled Pods Count',
        'total_cpu_seconds': 'Total CPU Seconds',
        'user_cpu_seconds': 'User CPU Seconds',
        'system_cpu_seconds': 'System CPU Seconds',
        'memory_peak_gb': 'Peak Memory (GB)'
    }

    for metric_col, y_label in metrics_to_plot.items():
        plt.figure(figsize=(12, 7))
        for simulator, df in data.items():
            if metric_col in df.columns and not df[metric_col].isnull().all():
                x, y = df['node_count'], df[metric_col]
                X_Y_Spline = make_interp_spline(x, y)
                X_ = np.linspace(x.min(), x.max(), 500)
                Y_ = X_Y_Spline(X_)
                plt.plot(X_, Y_, linestyle='-', label=simulator)
            else:
                print(f"Skipping plot for {metric_col} for program {simulator} due to missing data.")

        plt.xlabel('Node Count')
        plt.ylabel(y_label)
        plt.title(f'{y_label} vs. Node Count for all simulators')
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plot_filename = os.path.join(output_dir, f'{metric_col}_vs_node_count.png')
        plt.savefig(plot_filename)
        print(f"Saved plot: {plot_filename}")
        plt.close()

    print(f"\nPlots saved to '{output_dir}' directory.")


def main():
    parser = argparse.ArgumentParser(description="Generate plots from CSV data.")
    parser.add_argument("-d", "--data_directory", type=str, help="Path to the directory containing CSV files.", required=True)
    parser.add_argument("-o", "--output_dir", type=str, default="plots", help="Directory to save generated plots.")
    args = parser.parse_args()

    simulator_data = {}

    if not os.path.isdir(args.data_directory):
        print(f"Error: Data directory '{args.data_directory}' not found.")
        return

    for filename in os.listdir(args.data_directory):
        if filename.lower().endswith(".csv"):
            filepath = os.path.join(args.data_directory, filename)
            simulator = os.path.splitext(filename)[0]
            print(f"Processing {simulator} from {filepath}...")
            df = load_and_clean_data(filepath)
            if df is not None and not df.empty:
                simulator_data[simulator] = df
            else:
                print(f"Error processing {simulator} from {filepath}")

    if not simulator_data:
        print("Error, no data found.")
        return

    plot_comparison(simulator_data, args.output_dir)

if __name__ == '__main__':
    main()
