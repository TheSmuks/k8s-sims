import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import argparse
from scipy.interpolate import make_interp_spline
import seaborn as sns

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
        df['scheduling_success_rate'] = df.apply(
                lambda row: 1.0 if row['unscheduled_pods'] == 0 else 1-(row['unscheduled_pods'].astype(float) / row['pod_count'].astype(float)),
                axis=1
            )
        df['cpu_efficiency'] = df.apply(
            lambda row: (
                float(row['total_cpu_seconds']) / float(row['run_time'])
                if pd.notnull(row['run_time'] and float(row['run_time']) != 0 and pd.notnull(row['total_cpu_seconds']))
                else 0
            ),
            axis=1
        )
        df['cpu_user_system_ratio'] = df.apply(
            lambda row: (
                float(row['user_cpu_seconds']) / float(row['system_cpu_seconds'])
                if float(row['system_cpu_seconds']) != 0 and pd.notnull(row['user_cpu_seconds']) and pd.notnull(row['system_cpu_seconds'])
                else 1
            ),
            axis=1
        )
        df['timeout_reached'] = df['timeout_reached'].astype(bool)
        df['mem_exceeded'] = df['mem_exceeded'].astype(bool)
        df['scheduling_success_rate'].fillna(0, inplace=True)
        df['cpu_efficiency'].fillna(0, inplace=True)
        df['cpu_user_system_ratio'].fillna(0, inplace=True)
        df = df.groupby('node_count', as_index=False).mean()
        df.sort_values(by='node_count', inplace=True)
        return df
    except Exception as e:
        print(f"Error processing file {filepath}: {e}")
        return None

def plot_comparison(data: dict[str, pd.DataFrame], output_dir: str):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    metrics_to_plot = {
        'run_time': 'Run Time (seconds)',
        'pod_count': 'Pod Count',
        'unscheduled_pods': 'Unscheduled Pods Count',
        'total_cpu_seconds': 'Total CPU Seconds',
        'user_cpu_seconds': 'User CPU Seconds',
        'system_cpu_seconds': 'System CPU Seconds',
        'memory_peak_gb': 'Peak Memory (GB)',
        'scheduling_success_rate': 'Scheduling Sucess Rate',
        'cpu_efficiency': 'CPU Efficiency',
        'cpu_user_system_ratio': 'CPU User/System Ratio'
    }
    styles=[':', '--', '-.', '-']
    style_index=0
    simulator_style=dict()
    for simulator in data.keys():
        simulator_style[simulator]=styles[style_index%len(styles)]
        style_index+=1

    for metric_col, y_label in metrics_to_plot.items():
        plt.figure(figsize=(8, 5))
        for simulator, df in data.items():
            if metric_col in df.columns and not df[metric_col].isnull().all():
                x, y = df['node_count'], df[metric_col]
                X_Y_Spline = make_interp_spline(x, y)
                X_ = np.linspace(x.min(), x.max(), 500)
                Y_ = X_Y_Spline(X_)
                curr_style=simulator_style[simulator]
                plt.plot(X_, Y_, linestyle=curr_style, label=simulator)

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


    size_metrics = {'pod_count': 'Pod Count'}
    for metric_col, x_label in size_metrics.items():
        for simulator, df in data.items():
            x, y = df[metric_col], df['run_time']
            curr_style=simulator_style[simulator]
            plt.plot(x, y, linestyle=curr_style, label=simulator)
        plt.xlabel(x_label)
        plt.ylabel("Run Time (seconds)")
        plt.title(f'{x_label} vs. Run Time (seconds) for all simulators')
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plot_filename = os.path.join(output_dir, f'{metric_col}_vs_run_time.png')
        plt.savefig(plot_filename)
        print(f"Saved plot: {plot_filename}")
        plt.close()

    calculated_metrics = ['scheduling_success_rate', 'cpu_efficiency', 'cpu_user_system_ratio']
    for simulator, df in data.items():
        plt.figure(figsize=(10, 8))
        correlation_matrix = df.corr(numeric_only=True)
        correlation_matrix = correlation_matrix.dropna(axis=1, how='all').dropna(axis=0, how='all')
        for metric in calculated_metrics:
            if metric not in correlation_matrix.columns:
                correlation_matrix.loc[metric] = float('nan')
                correlation_matrix[metric] = float('nan')
        sns.heatmap(correlation_matrix, annot=True, fmt=".2f", cmap='coolwarm', center=0,
                square=True, linewidths=0.5, cbar_kws={"shrink": 0.75})

        plt.title(f"{simulator.capitalize()} Correlation Matrix")
        plt.tight_layout()
        plot_filename = os.path.join(output_dir, f'{simulator}_correlation_matrix.png')
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
