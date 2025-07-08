import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import argparse
from scipy.interpolate import make_interp_spline
import seaborn as sns

simulator_style = {
    'kubemark': {'style': '-', 'color': 'tab:red'},
    'kwok': {'style': '--', 'color': 'tab:green'},
    'opensim': {'style': '-.', 'color': 'tab:orange'},
    'simkube': {'style': ':', 'color': 'tab:purple'},
    'kube-sched': {'style': '-', 'color': 'tab:blue'},
    'kubernetes': {'style': '--', 'color': 'tab:brown'}
}

def load_and_clean_data(filepath: str) -> pd.DataFrame | None:
    try:
        df = pd.read_csv(filepath, sep='|', decimal=',')

        required_cols = {
            'node_count': 0, 'pod_count': 0, 'run_time': 0,
            'total_cpu_seconds': 0, 'user_cpu_seconds': 0,
            'system_cpu_seconds': 0, 'memory_peak_gb': 0,
            'unscheduled_pods': 0, 'timeout_reached': False,
            'mem_exceeded': False
        }

        for col, default in required_cols.items():
            if col not in df.columns:
                df[col] = default
            df[col] = pd.to_numeric(df[col], errors='coerce')

        df.dropna(subset=['node_count'], inplace=True)

        df.fillna({'unscheduled_pods': 0}, inplace=True)

        df['scheduling_success_rate'] = np.where(
            df['unscheduled_pods'] == 0,
            1.0,
            1.0 - df['unscheduled_pods'] / df['pod_count'].replace(0, np.nan)
        )

        df['cpu_efficiency'] = (
            df['total_cpu_seconds'] / df['run_time'].replace(0, np.nan)
        )

        df['cpu_user_system_ratio'] = (
            df['user_cpu_seconds'] / df['total_cpu_seconds'].replace(0, np.nan)
        )

        df['cpu_system_user_ratio'] = (
            df['system_cpu_seconds'] / df['total_cpu_seconds'].replace(0, np.nan)
        )

        df['timeout_reached'] = df['timeout_reached'].astype(bool)
        df['mem_exceeded'] = df['mem_exceeded'].astype(bool)

        df[['scheduling_success_rate', 'cpu_efficiency',
            'cpu_user_system_ratio', 'cpu_system_user_ratio']] = df[
            ['scheduling_success_rate', 'cpu_efficiency',
             'cpu_user_system_ratio', 'cpu_system_user_ratio']
        ].fillna(0)

        eff_min, eff_max = df['cpu_efficiency'].min(), df['cpu_efficiency'].max()
        if eff_max > eff_min:
            df['cpu_efficiency'] = (df['cpu_efficiency'] - eff_min) / (eff_max - eff_min)
        else:
            df['cpu_efficiency'] = 0

        df = df.groupby('node_count', as_index=False).mean(numeric_only=True)
        df.sort_values(by='node_count', inplace=True)

        return df

    except Exception as e:
        print(f"Error processing file {filepath}: {e}")
        return None


def plot_line_charts(data: dict[str, pd.DataFrame], output_dir: str):
    global simulator_style
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    metrics_to_plot = {
        'run_time': 'Run Time (seconds) - Lower is better',
        'pod_count': 'Pod Count',
        'unscheduled_pods': 'Unscheduled Pods Count - Lower is better',
        'total_cpu_seconds': 'Total CPU Seconds - Lower is better',
        'user_cpu_seconds': 'User CPU Seconds - Lower is better',
        'system_cpu_seconds': 'System CPU Seconds - Lower is better',
        'memory_peak_gb': 'Peak Memory (GB) - Lower is better',
        'scheduling_success_rate': 'Scheduling Sucess Rate - Higher is better',
        'cpu_efficiency': 'CPU Efficiency - Higher is better',
    }
    # styles=[':', '--', '-.', '-']
    # style_index=0
    # simulator_style=dict()
    # for simulator in data.keys():
    #     simulator_style[simulator]=styles[style_index%len(styles)]
    #     style_index+=1

    for metric_col, y_label in metrics_to_plot.items():
        plotted = False
        plt.figure(figsize=(8, 5))
        for simulator, df in data.items():
            if metric_col in df.columns and not df[metric_col].isnull().all():
                x, y = df['node_count'], df[metric_col]
                if len(x) < 2:
                    continue
                X_Y_Spline = make_interp_spline(x, y)
                X_ = np.linspace(x.min(), x.max(), 500)
                Y_ = X_Y_Spline(X_)
                curr_style=simulator_style[simulator]
                plt.plot(X_, Y_, linestyle=curr_style['style'], color=curr_style['color'], label=simulator)
                plotted = True
            else:
                print(f"Skipping plot for {metric_col} for program {simulator} due to missing data.")
        if not plotted:
            print("Not enough data to plot line charts.")
            return
        plt.xlabel('Node Count')
        plt.ylabel(y_label)
        plt.title(f'{y_label.split(' -')[0]} vs. Node Count for all simulators')
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
            plt.plot(x, y, linestyle=curr_style['style'], color=curr_style['color'], label=simulator)
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

def plot_cpu_ratio_bar(data: dict[str, pd.DataFrame], output_dir: str):
    plt.figure(figsize=(8, 5))
    simulators = data.keys()
    x = np.arange(len(simulators))
    user_ratios = [df['cpu_user_system_ratio'].mean() for df in data.values()]
    system_ratios = [df['cpu_system_user_ratio'].mean() for df in data.values()]
    fig, ax = plt.subplots()
    ax.bar(x, user_ratios, label='CPU User Time', color='steelblue')
    ax.bar(x, system_ratios, bottom=user_ratios, label='CPU System Time', color='lightgray')
    ax.set_xticks(x)
    ax.set_xticklabels(simulators)
    ax.set_ylabel('Proportion')
    ax.set_title('CPU User/System Time Ratio per Simulator')
    ax.legend()
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plot_filename = os.path.join(output_dir, f'cpu_ratio.png')
    plt.savefig(plot_filename)
    print(f"Saved plot: {plot_filename}")
    plt.close()

def plot_bars(melted_df: pd.DataFrame, output_dir: str):
    plt.figure(figsize=(12,8))
    simulator_colors={key:simulator_style[key]['color'] for key in simulator_style.keys() }
    ax = sns.barplot(data=melted_df,x='Metric',y='Normalized Value',hue='Simulator',palette=simulator_colors)
    for container in ax.containers:
        ax.bar_label(container, fmt='%.2f')
    ax.legend()
    plt.title('Simulators Metrics Comparison')
    plt.ylabel('Normalized Value')
    plt.xlabel('')
    plt.xticks(ha='right')
    plt.tight_layout()
    metrics = '_'.join(melted_df['Metric'].unique().tolist())
    plot_filename = os.path.join(output_dir, f'bars_{metrics}.png')
    plt.savefig(plot_filename)
    print(f"Saved plot: {plot_filename}")
    plt.close()


def plot_summary_bars(data: dict[str, pd.DataFrame], output_dir: str):
    data_list = []
    for simulator, df in data.items():
        df['Simulator'] = simulator
        data_list.append(df)
    combined_df = pd.concat(data_list, ignore_index=True)
    melted_df = combined_df.melt(id_vars='Simulator', var_name='Metric', value_name='Value')
    melted_df['Normalized Value'] = melted_df.groupby('Metric')['Value'].transform(
        lambda x: (x-x.min())/(x.max()- x.min() if x.max() > x.min() else 0)
    )
    filtered_cpu_mem_run_pods = melted_df[melted_df['Metric'].isin(['run_time', 'total_cpu_seconds', 'memory_peak_gb', 'unscheduled_pods'])]
    plot_bars(filtered_cpu_mem_run_pods, output_dir)
    filtered_cpu_mem_run = melted_df[melted_df['Metric'].isin(['cpu_efficiency', 'scheduling_success_rate'])]
    plot_bars(filtered_cpu_mem_run, output_dir)

def plot_comparison(data: dict[str, pd.DataFrame], output_dir: str, plot_lines: bool = False, plot_bars: bool = False):
    if plot_lines:
        plot_line_charts(data, output_dir)
    if plot_bars:
        plot_cpu_ratio_bar(data, output_dir)
        plot_summary_bars(data, output_dir)
    print(f"\nPlots saved to '{output_dir}' directory.")

def main():
    print(r"""
  _  __     _          _____  _       _   
 | |/ /    | |        |  __ \| |     | |  
 | ' /_   _| |__   ___| |__) | | ___ | |_ 
 |  <| | | | '_ \ / _ \  ___/| |/ _ \| __|
 | . \ |_| | |_) |  __/ |    | | (_) | |_ 
 |_|\_\__,_|_.__/ \___|_|    |_|\___/ \__|
-------------------------------------------""")
    parser = argparse.ArgumentParser(description="Generate plots from CSV data.")
    parser.add_argument("-d", "--data_directory", type=str, help="Path to the directory containing CSV files.", required=True)
    parser.add_argument("-o", "--output_dir", type=str, default="plots", help="Directory to save generated plots.")
    parser.add_argument("-l", "--plot_lines", default=False, action='store_true', help="Indicates if line chart should be plotted.")
    parser.add_argument("-b", "--plot_bars", default=False, action='store_true', help="Indicates if bar chart should be plotted.")
    args = parser.parse_args()
    if not args.plot_bars and not args.plot_lines:
        parser.error("At least -l/--plot_lines or -b/--plot_bars must be provided.")
    simulator_data = {}

    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)

    if  not os.path.isdir(args.output_dir):
        print(f"Error: Output directory '{args.output_dir}' not found.")
        return

    if not os.path.exists(args.data_directory) and not os.path.isdit(args.data_directory):
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
    plot_comparison(simulator_data, args.output_dir, args.plot_lines, args.plot_bars)

if __name__ == '__main__':
    main()
