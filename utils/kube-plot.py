import argparse
import os
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from scipy.interpolate import make_interp_spline

SIMULATOR_STYLE = {
    "kubemark": {"style": "-", "color": "tab:red"},
    "kwok": {"style": "--", "color": "tab:green"},
    "opensim": {"style": "-.", "color": "tab:orange"},
    "simkube": {"style": ":", "color": "tab:purple"},
    "kube-sched": {"style": "-", "color": "tab:blue"},
    "kubernetes": {"style": "--", "color": "tab:brown"},
}
DEFAULT_STYLES = ["-", "--", "-.", ":"]
DEFAULT_COLORS = ["tab:gray", "tab:pink", "tab:olive", "tab:cyan"]

REQUIRED_COLUMNS = {
    "node_count": 0,
    "pod_count": 0,
    "timeout_reached": 0,
    "mem_exceeded": 0,
    "run_time": 0,
    "total_cpu_seconds": 0,
    "user_cpu_seconds": 0,
    "system_cpu_seconds": 0,
    "memory_peak_gb": 0,
    "unscheduled_pods": 0,
}
NUMERIC_COLUMNS = list(REQUIRED_COLUMNS.keys())


def simulator_style(name: str) -> dict[str, str]:
    if name in SIMULATOR_STYLE:
        return SIMULATOR_STYLE[name]
    index = abs(hash(name)) % len(DEFAULT_STYLES)
    return {"style": DEFAULT_STYLES[index], "color": DEFAULT_COLORS[index % len(DEFAULT_COLORS)]}


def read_result_csv(filepath: Path) -> pd.DataFrame:
    return pd.read_csv(filepath, sep="|", decimal=",", dtype=str).rename(columns=str.strip)


def load_and_clean_data(filepath: str | Path) -> pd.DataFrame | None:
    filepath = Path(filepath)
    try:
        if filepath.stat().st_size == 0:
            print(f"Skipping empty result file: {filepath}")
            return None
        df = read_result_csv(filepath)
        if df.empty:
            print(f"Skipping empty result file: {filepath}")
            return None

        for col, default in REQUIRED_COLUMNS.items():
            if col not in df.columns:
                df[col] = default
            df[col] = pd.to_numeric(df[col], errors="coerce")

        df.dropna(subset=["node_count"], inplace=True)
        if df.empty:
            print(f"Skipping malformed result file with no valid node_count values: {filepath}")
            return None

        df.fillna({"pod_count": 0, "unscheduled_pods": 0}, inplace=True)
        for col in NUMERIC_COLUMNS:
            df[col] = df[col].fillna(0)

        safe_pods = df["pod_count"].replace(0, np.nan)
        df["scheduling_success_rate"] = np.where(
            safe_pods.isna(),
            np.where(df["unscheduled_pods"] == 0, 1.0, 0.0),
            1.0 - (df["unscheduled_pods"] / safe_pods),
        )
        df["scheduling_success_rate"] = df["scheduling_success_rate"].clip(lower=0, upper=1)
        df["cpu_efficiency"] = df["total_cpu_seconds"] / df["run_time"].replace(0, np.nan)
        df["cpu_user_system_ratio"] = df["user_cpu_seconds"] / df["total_cpu_seconds"].replace(0, np.nan)
        df["cpu_system_user_ratio"] = df["system_cpu_seconds"] / df["total_cpu_seconds"].replace(0, np.nan)
        df[["scheduling_success_rate", "cpu_efficiency", "cpu_user_system_ratio", "cpu_system_user_ratio"]] = df[
            ["scheduling_success_rate", "cpu_efficiency", "cpu_user_system_ratio", "cpu_system_user_ratio"]
        ].replace([np.inf, -np.inf], np.nan).fillna(0)

        eff_min, eff_max = df["cpu_efficiency"].min(), df["cpu_efficiency"].max()
        if pd.notna(eff_min) and pd.notna(eff_max) and eff_max > eff_min:
            df["cpu_efficiency"] = (df["cpu_efficiency"] - eff_min) / (eff_max - eff_min)
        else:
            df["cpu_efficiency"] = 0.0

        df = df.groupby("node_count", as_index=False).mean(numeric_only=True)
        df.sort_values(by="node_count", inplace=True)
        return df
    except Exception as exc:
        print(f"Skipping malformed result file {filepath}: {exc}")
        return None


def ensure_output_dir(output_dir: str | Path) -> Path:
    path = Path(output_dir)
    path.mkdir(parents=True, exist_ok=True)
    if not path.is_dir():
        raise ValueError(f"Output path is not a directory: {path}")
    return path


def plot_line_charts(data: dict[str, pd.DataFrame], output_dir: Path) -> None:
    metrics_to_plot = {
        "run_time": "Run Time (seconds) - Lower is better",
        "pod_count": "Pod Count",
        "unscheduled_pods": "Unscheduled Pods Count - Lower is better",
        "total_cpu_seconds": "Total CPU Seconds - Lower is better",
        "user_cpu_seconds": "User CPU Seconds - Lower is better",
        "system_cpu_seconds": "System CPU Seconds - Lower is better",
        "memory_peak_gb": "Peak Memory (GB) - Lower is better",
        "scheduling_success_rate": "Scheduling Success Rate - Higher is better",
        "cpu_efficiency": "CPU Efficiency - Higher is better",
    }
    for metric_col, y_label in metrics_to_plot.items():
        plotted = False
        plt.figure(figsize=(8, 5))
        for simulator, df in data.items():
            if metric_col not in df.columns or df[metric_col].isnull().all():
                print(f"Skipping plot for {metric_col} for {simulator}: missing data.")
                continue
            x = df["node_count"].to_numpy(dtype=float)
            y = df[metric_col].to_numpy(dtype=float)
            style = simulator_style(simulator)
            if len(x) >= 3 and len(np.unique(x)) >= 3:
                spline = make_interp_spline(x, y, k=min(3, len(x) - 1))
                x_smooth = np.linspace(x.min(), x.max(), 200)
                y_smooth = spline(x_smooth)
                plt.plot(x_smooth, y_smooth, linestyle=style["style"], color=style["color"], label=simulator)
            else:
                plt.plot(x, y, marker="o", linestyle=style["style"], color=style["color"], label=simulator)
            plotted = True
        if not plotted:
            plt.close()
            print(f"Not enough data to plot {metric_col}.")
            continue
        plt.xlabel("Node Count")
        plt.ylabel(y_label)
        plt.title(f"{y_label.split(' -')[0]} vs. Node Count for all simulators")
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plot_filename = output_dir / f"{metric_col}_vs_node_count.png"
        plt.savefig(plot_filename)
        print(f"Saved plot: {plot_filename}")
        plt.close()

    plt.figure(figsize=(8, 5))
    plotted = False
    for simulator, df in data.items():
        if {"pod_count", "run_time"}.issubset(df.columns):
            style = simulator_style(simulator)
            plt.plot(df["pod_count"], df["run_time"], marker="o", linestyle=style["style"], color=style["color"], label=simulator)
            plotted = True
    if plotted:
        plt.xlabel("Pod Count")
        plt.ylabel("Run Time (seconds)")
        plt.title("Pod Count vs. Run Time (seconds) for all simulators")
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plot_filename = output_dir / "pod_count_vs_run_time.png"
        plt.savefig(plot_filename)
        print(f"Saved plot: {plot_filename}")
    plt.close()

    for simulator, df in data.items():
        correlation_matrix = df.corr(numeric_only=True).dropna(axis=1, how="all").dropna(axis=0, how="all")
        if correlation_matrix.empty:
            continue
        plt.figure(figsize=(10, 8))
        sns.heatmap(correlation_matrix, annot=True, fmt=".2f", cmap="coolwarm", center=0, square=True, linewidths=0.5, cbar_kws={"shrink": 0.75})
        plt.title(f"{simulator.capitalize()} Correlation Matrix")
        plt.tight_layout()
        plot_filename = output_dir / f"{simulator}_correlation_matrix.png"
        plt.savefig(plot_filename)
        print(f"Saved plot: {plot_filename}")
        plt.close()


def plot_cpu_ratio_bar(data: dict[str, pd.DataFrame], output_dir: Path) -> None:
    simulators = list(data.keys())
    x = np.arange(len(simulators))
    user_ratios = [df["cpu_user_system_ratio"].mean() for df in data.values()]
    system_ratios = [df["cpu_system_user_ratio"].mean() for df in data.values()]
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(x, user_ratios, label="CPU User Time", color="steelblue")
    ax.bar(x, system_ratios, bottom=user_ratios, label="CPU System Time", color="lightgray")
    ax.set_xticks(x)
    ax.set_xticklabels(simulators)
    ax.set_ylabel("Proportion")
    ax.set_title("CPU User/System Time Ratio per Simulator")
    ax.legend()
    plt.grid(True)
    plt.tight_layout()
    plot_filename = output_dir / "cpu_ratio.png"
    plt.savefig(plot_filename)
    print(f"Saved plot: {plot_filename}")
    plt.close(fig)


def plot_bars(melted_df: pd.DataFrame, output_dir: Path, suffix: str) -> None:
    if melted_df.empty:
        return
    plt.figure(figsize=(12, 8))
    palette = {name: simulator_style(name)["color"] for name in melted_df["Simulator"].unique()}
    ax = sns.barplot(data=melted_df, x="Metric", y="Normalized Value", hue="Simulator", palette=palette)
    for container in ax.containers:
        ax.bar_label(container, fmt="%.2f")
    ax.legend()
    plt.title("Simulators Metrics Comparison")
    plt.ylabel("Normalized Value")
    plt.xlabel("")
    plt.tight_layout()
    plot_filename = output_dir / f"bars_{suffix}.png"
    plt.savefig(plot_filename)
    print(f"Saved plot: {plot_filename}")
    plt.close()


def plot_summary_bars(data: dict[str, pd.DataFrame], output_dir: Path) -> None:
    data_list = []
    for simulator, df in data.items():
        selected = df.copy()
        selected["Simulator"] = simulator
        data_list.append(selected)
    combined_df = pd.concat(data_list, ignore_index=True)
    melted_df = combined_df.melt(id_vars="Simulator", var_name="Metric", value_name="Value")

    def normalize(series: pd.Series) -> pd.Series:
        low, high = series.min(), series.max()
        if pd.isna(low) or pd.isna(high) or high <= low:
            return pd.Series(0.0, index=series.index)
        return (series - low) / (high - low)

    melted_df["Normalized Value"] = melted_df.groupby("Metric")["Value"].transform(normalize).fillna(0)
    plot_bars(melted_df[melted_df["Metric"].isin(["run_time", "total_cpu_seconds", "memory_peak_gb", "unscheduled_pods"])], output_dir, "resource_metrics")
    plot_bars(melted_df[melted_df["Metric"].isin(["cpu_efficiency", "scheduling_success_rate"])], output_dir, "calculated_metrics")


def plot_comparison(data: dict[str, pd.DataFrame], output_dir: Path, plot_lines: bool = False, plot_bars_enabled: bool = False) -> None:
    if plot_lines:
        plot_line_charts(data, output_dir)
    if plot_bars_enabled:
        plot_cpu_ratio_bar(data, output_dir)
        plot_summary_bars(data, output_dir)
    print(f"\nPlots saved to '{output_dir}' directory.")


def candidate_result_files(data_directory: Path) -> list[Path]:
    return sorted(
        p for p in data_directory.iterdir()
        if p.is_file() and p.suffix.lower() == ".csv" and ".preserved-" not in p.name
    )


def main() -> int:
    print(r"""
  _  __     _          _____  _       _
 | |/ /    | |        |  __ \| |     | |
 | ' /_   _| |__   ___| |__) | | ___ | |_
 |  <| | | | '_ \ / _ \  ___/| |/ _ \| __|
 | . \ |_| | |_) |  __/ |    | | (_) | |_
 |_|\_\__,_|_.__/ \___|_|    |_|\___/ \__|
-------------------------------------------""")
    parser = argparse.ArgumentParser(description="Generate plots from benchmark result CSV data.")
    parser.add_argument("-d", "--data_directory", type=str, required=True, help="Path to the directory containing result CSV files.")
    parser.add_argument("-o", "--output_dir", type=str, default="plots", help="Directory to save generated plots.")
    parser.add_argument("-l", "--plot_lines", default=False, action="store_true", help="Plot line charts.")
    parser.add_argument("-b", "--plot_bars", default=False, action="store_true", help="Plot bar charts.")
    args = parser.parse_args()

    if not args.plot_bars and not args.plot_lines:
        parser.error("At least -l/--plot_lines or -b/--plot_bars must be provided.")

    data_directory = Path(args.data_directory)
    if not data_directory.is_dir():
        print(f"Error: Data directory '{data_directory}' does not exist or is not a directory.", file=sys.stderr)
        return 1

    try:
        output_dir = ensure_output_dir(args.output_dir)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    files = candidate_result_files(data_directory)
    if not files:
        print(f"Error: no result CSV files found in '{data_directory}'.", file=sys.stderr)
        return 1

    simulator_data: dict[str, pd.DataFrame] = {}
    for filepath in files:
        simulator = filepath.stem
        print(f"Processing {simulator} from {filepath}...")
        df = load_and_clean_data(filepath)
        if df is not None and not df.empty:
            simulator_data[simulator] = df

    if not simulator_data:
        print(f"Error: no valid result data found in '{data_directory}'.", file=sys.stderr)
        return 1

    plot_comparison(simulator_data, output_dir, args.plot_lines, args.plot_bars)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
