#!/usr/bin/env python3
"""
analyze_slm_benchmark.py
=========================
Phân tích và trực quan hóa dữ liệu benchmark 7 SLM (Q4_K_M) chạy on-device
trên Samsung Galaxy A03, dựa trên các file Notes_*.json (thực chất là JSON,
đuôi .txt/.json tùy nguồn) được xuất ra từ pipeline benchmark.

Cách dùng:
    python analyze_slm_benchmark.py --input_dir /path/to/notes_json --out_dir ./figures

Yêu cầu:
    pip install pandas matplotlib numpy --break-system-packages

Script sẽ:
  1. Đọc tất cả file Notes_*.json trong input_dir.
  2. Ghép summary + raw_results của từng artifact thành các DataFrame dùng chung.
  3. In ra một số bảng thống kê tổng hợp (tương tự Table 1-4 trong paper).
  4. Vẽ hơn 15 biểu đồ publication-quality (PNG, 300dpi) vào out_dir, gồm:
        01_workload_accuracy_bar.png
        02_fixedset_vs_workload_vs_agreement.png
        03_accuracy_by_level_grouped.png
        04_accuracy_heatmap_model_level.png
        05_ttft_boxplot.png
        06_total_latency_boxplot.png
        07_latency_vs_accuracy_bubble_ram.png
        08_ram_usage_bar.png
        09_init_time_bar.png
        10_battery_consumption_bar.png
        11_tokens_per_sec_bar.png
        12_palette_prediction_distribution_stacked.png
        13_gemma_smollm2_ocean_bias.png (class collapse minh họa)
        14_rule_vs_llm_agreement_by_level.png
        15_ttft_vs_total_latency_scatter.png
        16_accuracy_vs_uniform_random_baseline.png
        17_error_concentration_by_level_adapted.png
        18_correlation_matrix.png

Ghi chú khoa học:
  - Mọi số liệu trực tiếp đọc từ file JSON gốc, KHÔNG suy diễn thêm.
  - Các đường tham chiếu (uniform random 14.84%, best constant label 26.6%)
    được tính lại từ raw_results để đảm bảo nhất quán, có thể chỉnh sửa nếu
    tập dữ liệu benchmark thay đổi.
"""

import argparse
import glob
import json
import os
import sys
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# ----------------------------------------------------------------------------
# Cấu hình chung
# ----------------------------------------------------------------------------

plt.rcParams.update({
    "figure.dpi": 150,
    "savefig.dpi": 300,
    "font.size": 10,
    "axes.titlesize": 12,
    "axes.labelsize": 10,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.autolayout": True,
})

# Nhãn hiển thị gọn cho từng model_id (rút gọn để trục X không bị chồng chữ)
SHORT_NAME_MAP = {
    "custom-cerebras-gpt-111m-instruction.i1-q4_k_m": "Cerebras",
    "custom-gemma-3-270m-it-q4_k_m": "Gemma",
    "custom-pythia-410m-deduped.i1-q4_k_m": "Pythia",
    "custom-qwen2.5-0.5b-instruct-q4_k_m": "Qwen",
    "custom-smollm2-360m-instruct-q4_k_m": "SmolLM2",
    "custom-sutra-instruct-350m-q4_k_m": "Sutra",
}


def short_name(model_id: str) -> str:
    key = model_id.lower()
    if "fineturning" in key or "finetun" in key:
        return "Adapted-SmolLM2"
    return SHORT_NAME_MAP.get(key, model_id[:16])


# Thứ tự hiển thị chuẩn (giống paper): 6 baseline rồi đến adapted cuối cùng
PREFERRED_ORDER = ["Cerebras", "Gemma", "Pythia", "Qwen", "SmolLM2", "Sutra", "Adapted-SmolLM2"]


def ordered(names):
    present = [n for n in PREFERRED_ORDER if n in names]
    extra = [n for n in names if n not in PREFERRED_ORDER]
    return present + extra


# ----------------------------------------------------------------------------
# Đọc dữ liệu
# ----------------------------------------------------------------------------

def load_notes(input_dir: str) -> list[dict]:
    """Đọc tất cả Notes_*.json (hoặc *.txt chứa JSON) trong input_dir."""
    paths = sorted(glob.glob(os.path.join(input_dir, "Notes_*.json")) +
                    glob.glob(os.path.join(input_dir, "Notes_*.txt")))
    if not paths:
        # fallback: bất kỳ .json nào trong thư mục
        paths = sorted(glob.glob(os.path.join(input_dir, "*.json")))
    if not paths:
        sys.exit(f"Không tìm thấy file Notes_*.json/.txt trong {input_dir}")

    records = []
    for p in paths:
        with open(p, "r", encoding="utf-8") as f:
            d = json.load(f)
        d["_source_file"] = os.path.basename(p)
        records.append(d)
    print(f"[load_notes] Đã đọc {len(records)} file từ {input_dir}")
    return records


def build_summary_df(notes: list[dict]) -> pd.DataFrame:
    """Bảng tổng hợp 1 dòng / artifact, tương ứng Table 4 trong paper."""
    rows = []
    for d in notes:
        s = d["on_device"]["summary"]
        model_id = s["model_id"]
        name = short_name(model_id)
        rvl = d.get("rule_vs_llm") or {}
        rows.append({
            "model": name,
            "model_id": model_id,
            "model_raw": s.get("model", model_id),
            "accuracy_workload_pct": s.get("accuracy_pct"),
            "correct_count": s.get("correct_count"),
            "total_cases": s.get("total_cases"),
            "init_time_ms": s.get("init_time_ms"),
            "ttft_mean": s["ttft"]["mean"],
            "ttft_std": s["ttft"]["std"],
            "ttft_p95": s["ttft"]["p95"],
            "total_inf_mean": s["total_inference"]["mean"],
            "total_inf_std": s["total_inference"]["std"],
            "total_inf_p95": s["total_inference"]["p95"],
            "tokens_per_sec_mean": s["tokens_per_sec"]["mean"],
            "ram_mean_mb": s["ram_usage_mb"]["mean"],
            "ram_p95_mb": s["ram_usage_mb"]["p95"],
            "battery_dropped_pct": s.get("battery_dropped_pct"),
            "benchmark_duration_sec": s.get("benchmark_duration_sec"),
            "battery_consumption_rate": s.get("battery_consumption_rate"),
            "fixedset_accuracy_pct": rvl.get("llm_accuracy_pct"),
            "rule_accuracy_pct": rvl.get("rule_accuracy_pct"),
            "agreement_rate_pct": rvl.get("agreement_rate_pct"),
            "source_file": d["_source_file"],
        })
    df = pd.DataFrame(rows)
    df["order_key"] = df["model"].apply(lambda m: PREFERRED_ORDER.index(m) if m in PREFERRED_ORDER else 99)
    df = df.sort_values("order_key").drop(columns="order_key").reset_index(drop=True)
    return df


def build_raw_df(notes: list[dict]) -> pd.DataFrame:
    """Ghép toàn bộ raw_results (200 request/artifact -> ~1400 dòng)."""
    frames = []
    for d in notes:
        s = d["on_device"]["summary"]
        name = short_name(s["model_id"])
        raw = pd.DataFrame(d["on_device"]["raw_results"])
        raw["model"] = name
        raw["model_id"] = s["model_id"]
        frames.append(raw)
    df = pd.concat(frames, ignore_index=True)
    return df


def build_accuracy_by_level_df(notes: list[dict]) -> pd.DataFrame:
    rows = []
    for d in notes:
        s = d["on_device"]["summary"]
        name = short_name(s["model_id"])
        for level, stats in s.get("accuracy_by_category", {}).items():
            rows.append({
                "model": name,
                "level": level,
                "count": stats["count"],
                "correct_count": stats["correct_count"],
                "accuracy_pct": stats["accuracy_pct"],
            })
    return pd.DataFrame(rows)


def build_palette_dist_df(notes: list[dict]) -> pd.DataFrame:
    rows = []
    for d in notes:
        s = d["on_device"]["summary"]
        name = short_name(s["model_id"])
        for palette, stats in s.get("palette_prediction_distribution", {}).items():
            rows.append({
                "model": name,
                "palette": palette,
                "count": stats["count"],
                "pct": stats["pct"],
            })
    return pd.DataFrame(rows)


def build_rule_vs_llm_level_df(notes: list[dict]) -> pd.DataFrame:
    rows = []
    for d in notes:
        s = d["on_device"]["summary"]
        name = short_name(s["model_id"])
        rvl = d.get("rule_vs_llm")
        if not rvl:
            continue
        for level, stats in rvl.get("accuracy_by_category", {}).items():
            rows.append({
                "model": name,
                "level": level,
                "count": stats["count"],
                "rule_accuracy_pct": stats["rule_accuracy_pct"],
                "llm_accuracy_pct": stats["llm_accuracy_pct"],
                "agreement_rate_pct": stats["agreement_rate_pct"],
            })
    return pd.DataFrame(rows)


def compute_reference_baselines(raw_df: pd.DataFrame):
    """Tính lại uniform-random & best-constant-label baseline từ expected_palettes
    trên tập case duy nhất (không lặp lại theo request)."""
    # Lấy tập case duy nhất bất kỳ từ 1 model (case_id + expected_palettes giống nhau giữa các model)
    one_model = raw_df["model"].iloc[0]
    cases = raw_df[raw_df["model"] == one_model].drop_duplicates(subset="case_id")
    accepted_sizes = cases["expected_palettes"].apply(len)
    uniform_random = (1.0 / 10.0) if False else float((accepted_sizes / 10.0).mean()) * 100  # 10 nhãn khả dĩ
    # best constant label: nhãn nào xuất hiện trong accepted set nhiều case nhất
    label_counter = defaultdict(int)
    for palettes in cases["expected_palettes"]:
        for p in palettes:
            label_counter[p] += 1
    best_label, best_count = max(label_counter.items(), key=lambda kv: kv[1])
    best_constant_pct = best_count / len(cases) * 100
    return {
        "n_cases": len(cases),
        "uniform_random_pct": uniform_random,
        "best_constant_label": best_label,
        "best_constant_label_pct": best_constant_pct,
        "label_coverage": dict(sorted(label_counter.items(), key=lambda kv: -kv[1])),
    }


# ----------------------------------------------------------------------------
# Các hàm vẽ biểu đồ
# ----------------------------------------------------------------------------

def savefig(fig, out_dir, name):
    path = os.path.join(out_dir, name)
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> saved {path}")


def plot_workload_accuracy_bar(summary_df, baselines, out_dir):
    df = summary_df.set_index("model").loc[ordered(summary_df["model"])]
    fig, ax = plt.subplots(figsize=(8, 5))
    colors = ["#d62728" if m == "Adapted-SmolLM2" else "#4C72B0" for m in df.index]
    ax.bar(df.index, df["accuracy_workload_pct"], color=colors)
    ax.axhline(baselines["uniform_random_pct"], color="gray", linestyle="--", linewidth=1,
               label=f"Uniform random ({baselines['uniform_random_pct']:.2f}%)")
    ax.axhline(baselines["best_constant_label_pct"], color="crimson", linestyle=":", linewidth=1,
               label=f"Best constant label ({baselines['best_constant_label_pct']:.1f}%)")
    ax.set_ylabel("Workload accuracy (%)")
    ax.set_title("Workload accuracy per SLM artifact (N=200 resampled requests)")
    ax.legend()
    for i, v in enumerate(df["accuracy_workload_pct"]):
        ax.text(i, v + 1, f"{v:.1f}", ha="center", fontsize=9)
    plt.xticks(rotation=20, ha="right")
    savefig(fig, out_dir, "01_workload_accuracy_bar.png")


def plot_fixedset_vs_workload_vs_agreement(summary_df, out_dir):
    df = summary_df.set_index("model").loc[ordered(summary_df["model"])]
    x = np.arange(len(df))
    width = 0.25
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.bar(x - width, df["accuracy_workload_pct"], width, label="Resampled workload acc.")
    ax.bar(x, df["fixedset_accuracy_pct"], width, label="Fixed-set acc.")
    ax.bar(x + width, df["agreement_rate_pct"], width, label="Exact rule agreement")
    ax.set_xticks(x)
    ax.set_xticklabels(df.index, rotation=20, ha="right")
    ax.set_ylabel("%")
    ax.set_title("Workload accuracy vs. fixed-set accuracy vs. rule agreement")
    ax.legend()
    savefig(fig, out_dir, "02_fixedset_vs_workload_vs_agreement.png")


def plot_accuracy_by_level_grouped(level_df, out_dir):
    pivot = level_df.pivot(index="model", columns="level", values="accuracy_pct").loc[
        ordered(level_df["model"].unique())]
    levels = ["L1", "L2", "L3", "L4"]
    pivot = pivot[levels]
    x = np.arange(len(pivot))
    width = 0.2
    fig, ax = plt.subplots(figsize=(9, 5))
    for i, lvl in enumerate(levels):
        ax.bar(x + (i - 1.5) * width, pivot[lvl], width, label=lvl)
    ax.set_xticks(x)
    ax.set_xticklabels(pivot.index, rotation=20, ha="right")
    ax.set_ylabel("Workload accuracy (%)")
    ax.set_title("Accuracy by authored contextual-complexity level (L1-L4)")
    ax.legend(title="Level")
    savefig(fig, out_dir, "03_accuracy_by_level_grouped.png")


def plot_accuracy_heatmap(level_df, out_dir):
    pivot = level_df.pivot(index="model", columns="level", values="accuracy_pct").loc[
        ordered(level_df["model"].unique())][["L1", "L2", "L3", "L4"]]
    fig, ax = plt.subplots(figsize=(6, 5))
    im = ax.imshow(pivot.values, cmap="YlOrRd", aspect="auto", vmin=0, vmax=100)
    ax.set_xticks(range(len(pivot.columns)))
    ax.set_xticklabels(pivot.columns)
    ax.set_yticks(range(len(pivot.index)))
    ax.set_yticklabels(pivot.index)
    for i in range(pivot.shape[0]):
        for j in range(pivot.shape[1]):
            val = pivot.values[i, j]
            ax.text(j, i, f"{val:.1f}", ha="center", va="center",
                     color="white" if val > 50 else "black", fontsize=9)
    ax.set_title("Accuracy heatmap: model x complexity level")
    fig.colorbar(im, ax=ax, label="Accuracy (%)")
    savefig(fig, out_dir, "04_accuracy_heatmap_model_level.png")


def plot_ttft_boxplot(raw_df, out_dir):
    order = ordered(raw_df["model"].unique())
    data = [raw_df.loc[raw_df["model"] == m, "ttft_ms"].dropna() for m in order]
    fig, ax = plt.subplots(figsize=(9, 5))
    bp = ax.boxplot(data, labels=order, showmeans=True, patch_artist=True)
    for patch in bp["boxes"]:
        patch.set_facecolor("#a6cee3")
    ax.set_ylabel("TTFT (ms)")
    ax.set_title("Time-to-first-token distribution (N=200 per artifact)")
    plt.xticks(rotation=20, ha="right")
    savefig(fig, out_dir, "05_ttft_boxplot.png")


def plot_total_latency_boxplot(raw_df, out_dir):
    order = ordered(raw_df["model"].unique())
    data = [raw_df.loc[raw_df["model"] == m, "total_inference_ms"].dropna() for m in order]
    fig, ax = plt.subplots(figsize=(9, 5))
    bp = ax.boxplot(data, labels=order, showmeans=True, patch_artist=True)
    for patch in bp["boxes"]:
        patch.set_facecolor("#fdbf6f")
    ax.set_ylabel("Total inference latency (ms)")
    ax.set_title("Total inference latency distribution (N=200 per artifact)")
    plt.xticks(rotation=20, ha="right")
    savefig(fig, out_dir, "06_total_latency_boxplot.png")


def plot_latency_accuracy_bubble(summary_df, out_dir):
    df = summary_df.set_index("model").loc[ordered(summary_df["model"])]
    fig, ax = plt.subplots(figsize=(8, 6))
    sizes = df["ram_mean_mb"] * 1.2
    colors = ["#d62728" if m == "Adapted-SmolLM2" else "#4C72B0" for m in df.index]
    ax.scatter(df["total_inf_mean"] / 1000.0, df["accuracy_workload_pct"], s=sizes,
               alpha=0.6, c=colors, edgecolors="black")
    for i, m in enumerate(df.index):
        ax.annotate(f"{i+1} {m}", (df["total_inf_mean"].iloc[i] / 1000.0, df["accuracy_workload_pct"].iloc[i]),
                    textcoords="offset points", xytext=(6, 4), fontsize=8)
    ax.set_xlabel("Mean total inference time (s)")
    ax.set_ylabel("Workload accuracy (%)")
    ax.set_title("Accuracy-latency trade-off (bubble area = mean RAM usage)")
    savefig(fig, out_dir, "07_latency_vs_accuracy_bubble_ram.png")


def plot_ram_usage_bar(summary_df, out_dir):
    df = summary_df.set_index("model").loc[ordered(summary_df["model"])]
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(df.index, df["ram_mean_mb"], color="#8172B2", label="Mean RSS")
    ax.errorbar(df.index, df["ram_mean_mb"],
                yerr=[df["ram_mean_mb"] - 0, df["ram_p95_mb"] - df["ram_mean_mb"]],
                fmt="none", ecolor="black", capsize=4, label="P95")
    ax.set_ylabel("RAM / RSS (MB)")
    ax.set_title("Mean resident memory (RSS) per artifact, with P95")
    plt.xticks(rotation=20, ha="right")
    ax.legend()
    savefig(fig, out_dir, "08_ram_usage_bar.png")


def plot_init_time_bar(summary_df, out_dir):
    df = summary_df.set_index("model").loc[ordered(summary_df["model"])]
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(df.index, df["init_time_ms"], color="#55A868")
    ax.set_ylabel("Initialization time (ms)")
    ax.set_title("Model initialization time (single session per artifact)")
    plt.xticks(rotation=20, ha="right")
    savefig(fig, out_dir, "09_init_time_bar.png")


def plot_battery_bar(summary_df, out_dir):
    df = summary_df.set_index("model").loc[ordered(summary_df["model"])]
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(df.index, df["battery_consumption_rate"], color="#C44E52")
    ax.set_ylabel("Normalized battery drop (%/hour)")
    ax.set_title("Coarse battery consumption indicator (descriptive only, not ranked)")
    plt.xticks(rotation=20, ha="right")
    savefig(fig, out_dir, "10_battery_consumption_bar.png")


def plot_tokens_per_sec_bar(summary_df, out_dir):
    df = summary_df.set_index("model").loc[ordered(summary_df["model"])]
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(df.index, df["tokens_per_sec_mean"], color="#64B5CD")
    ax.set_ylabel("Tokens / second (mean)")
    ax.set_title("Token throughput (interpret with caution: output = 2-3 tokens)")
    plt.xticks(rotation=20, ha="right")
    savefig(fig, out_dir, "11_tokens_per_sec_bar.png")


def plot_palette_distribution_stacked(palette_df, out_dir):
    pivot = palette_df.pivot_table(index="model", columns="palette", values="pct", fill_value=0)
    pivot = pivot.loc[ordered(palette_df["model"].unique())]
    fig, ax = plt.subplots(figsize=(10, 6))
    bottom = np.zeros(len(pivot))
    cmap = plt.get_cmap("tab20")
    for i, palette in enumerate(pivot.columns):
        ax.bar(pivot.index, pivot[palette], bottom=bottom, label=palette, color=cmap(i % 20))
        bottom += pivot[palette].values
    ax.set_ylabel("Prediction share (%)")
    ax.set_title("Predicted palette distribution per artifact (workload, N=200)")
    ax.legend(bbox_to_anchor=(1.02, 1), loc="upper left", fontsize=8)
    plt.xticks(rotation=20, ha="right")
    savefig(fig, out_dir, "12_palette_prediction_distribution_stacked.png")


def plot_ocean_bias(palette_df, out_dir):
    """Minh họa hiện tượng class collapse / 'ocean bias' của Gemma & base SmolLM2."""
    targets = [m for m in ["Gemma", "SmolLM2", "Adapted-SmolLM2"] if m in palette_df["model"].unique()]
    if not targets:
        return
    fig, axes = plt.subplots(1, len(targets), figsize=(5 * len(targets), 5), sharey=True)
    if len(targets) == 1:
        axes = [axes]
    for ax, m in zip(axes, targets):
        sub = palette_df[palette_df["model"] == m].sort_values("pct", ascending=False)
        colors = ["#d62728" if p == "ocean" else "#4C72B0" for p in sub["palette"]]
        ax.bar(sub["palette"], sub["pct"], color=colors)
        ax.set_title(m)
        ax.tick_params(axis="x", rotation=60)
    axes[0].set_ylabel("Prediction share (%)")
    fig.suptitle("Class collapse comparison: label diversity per artifact")
    savefig(fig, out_dir, "13_gemma_smollm2_ocean_bias.png")


def plot_rule_vs_llm_by_level(rvl_level_df, out_dir):
    if rvl_level_df.empty:
        print("  (skip 14: no rule_vs_llm data)")
        return
    models = ordered(rvl_level_df["model"].unique())
    fig, axes = plt.subplots(1, len(models), figsize=(5 * len(models), 4.5), sharey=True)
    if len(models) == 1:
        axes = [axes]
    for ax, m in zip(axes, models):
        sub = rvl_level_df[rvl_level_df["model"] == m].set_index("level").loc[["L1", "L2", "L3", "L4"]]
        x = np.arange(4)
        width = 0.35
        ax.bar(x - width / 2, sub["rule_accuracy_pct"], width, label="Rule engine")
        ax.bar(x + width / 2, sub["llm_accuracy_pct"], width, label="LLM (fixed-set)")
        ax.set_xticks(x)
        ax.set_xticklabels(sub.index)
        ax.set_title(m)
    axes[0].set_ylabel("Accuracy (%)")
    axes[0].legend()
    fig.suptitle("Rule engine vs. LLM accuracy by complexity level (fixed 64-case set)")
    savefig(fig, out_dir, "14_rule_vs_llm_agreement_by_level.png")


def plot_ttft_vs_total_latency_scatter(raw_df, out_dir):
    fig, ax = plt.subplots(figsize=(8, 6))
    for m in ordered(raw_df["model"].unique()):
        sub = raw_df[raw_df["model"] == m]
        ax.scatter(sub["ttft_ms"], sub["total_inference_ms"], s=10, alpha=0.4, label=m)
    ax.set_xlabel("TTFT (ms)")
    ax.set_ylabel("Total inference time (ms)")
    ax.set_title("TTFT vs. total inference time (per-request, all artifacts)")
    ax.legend(markerscale=2, fontsize=8)
    savefig(fig, out_dir, "15_ttft_vs_total_latency_scatter.png")


def plot_accuracy_vs_baselines(summary_df, baselines, out_dir):
    df = summary_df.set_index("model").loc[ordered(summary_df["model"])]
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(df.index, df["fixedset_accuracy_pct"], color="#4C72B0", label="Fixed-set accuracy")
    ax.axhline(baselines["uniform_random_pct"], color="gray", linestyle="--",
               label=f"Uniform random ({baselines['uniform_random_pct']:.2f}%)")
    ax.axhline(baselines["best_constant_label_pct"], color="crimson", linestyle=":",
               label=f"Best constant label '{baselines['best_constant_label']}' "
                     f"({baselines['best_constant_label_pct']:.1f}%)")
    ax.set_ylabel("Accuracy (%)")
    ax.set_title("Fixed-set accuracy vs. derived chance-level references")
    plt.xticks(rotation=20, ha="right")
    ax.legend()
    savefig(fig, out_dir, "16_accuracy_vs_uniform_random_baseline.png")


def plot_error_concentration(raw_df, out_dir, model_name="Adapted-SmolLM2"):
    sub = raw_df[raw_df["model"] == model_name]
    if sub.empty:
        print(f"  (skip 17: model {model_name} not found)")
        return
    err = sub[~sub["is_correct"]]
    counts = err.groupby("category").size().reindex(["L1", "L2", "L3", "L4"], fill_value=0)
    totals = sub.groupby("category").size().reindex(["L1", "L2", "L3", "L4"], fill_value=0)
    rate = (counts / totals * 100).fillna(0)
    fig, ax1 = plt.subplots(figsize=(7, 5))
    ax1.bar(counts.index, counts.values, color="#C44E52", alpha=0.8, label="Error count")
    ax1.set_ylabel("Error count (of resampled requests)")
    ax2 = ax1.twinx()
    ax2.plot(rate.index, rate.values, color="black", marker="o", label="Error rate (%)")
    ax2.set_ylabel("Error rate (%)")
    fig.suptitle(f"{model_name}: error concentration by complexity level")
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2, loc="upper right")
    savefig(fig, out_dir, "17_error_concentration_by_level_adapted.png")


def plot_correlation_matrix(summary_df, out_dir):
    cols = ["accuracy_workload_pct", "ttft_mean", "total_inf_mean", "tokens_per_sec_mean",
            "ram_mean_mb", "init_time_ms", "battery_consumption_rate"]
    sub = summary_df[cols].rename(columns={
        "accuracy_workload_pct": "Accuracy",
        "ttft_mean": "TTFT",
        "total_inf_mean": "TotalLatency",
        "tokens_per_sec_mean": "TokensPerSec",
        "ram_mean_mb": "RAM",
        "init_time_ms": "InitTime",
        "battery_consumption_rate": "BatteryRate",
    })
    corr = sub.corr(numeric_only=True)
    fig, ax = plt.subplots(figsize=(6.5, 5.5))
    im = ax.imshow(corr.values, cmap="coolwarm", vmin=-1, vmax=1)
    ax.set_xticks(range(len(corr.columns)))
    ax.set_xticklabels(corr.columns, rotation=45, ha="right")
    ax.set_yticks(range(len(corr.columns)))
    ax.set_yticklabels(corr.columns)
    for i in range(corr.shape[0]):
        for j in range(corr.shape[1]):
            ax.text(j, i, f"{corr.values[i, j]:.2f}", ha="center", va="center", fontsize=8)
    ax.set_title("Correlation matrix across 7 artifacts (n=7, exploratory only)")
    fig.colorbar(im, ax=ax, label="Pearson r")
    savefig(fig, out_dir, "18_correlation_matrix.png")


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def print_summary_tables(summary_df, baselines):
    pd.set_option("display.max_columns", None)
    pd.set_option("display.width", 160)
    print("\n=== Bảng tổng hợp theo artifact (giống Table 4 trong paper) ===")
    cols = ["model", "accuracy_workload_pct", "fixedset_accuracy_pct", "agreement_rate_pct",
            "ttft_mean", "ttft_std", "total_inf_mean", "total_inf_std", "ram_mean_mb",
            "init_time_ms", "battery_consumption_rate"]
    print(summary_df[cols].to_string(index=False))

    print("\n=== Baseline tham chiếu suy từ tập 64 case ===")
    print(f"  Số case: {baselines['n_cases']}")
    print(f"  Uniform-random accuracy (kỳ vọng): {baselines['uniform_random_pct']:.2f}%")
    print(f"  Best constant label: '{baselines['best_constant_label']}' "
          f"({baselines['best_constant_label_pct']:.2f}%)")
    print(f"  Label coverage (số case chấp nhận mỗi nhãn): {baselines['label_coverage']}")


def main():
    parser = argparse.ArgumentParser(description="Phân tích benchmark 7 SLM on-device (Galaxy A03)")
    parser.add_argument("--input_dir", default=".", help="Thư mục chứa Notes_*.json")
    parser.add_argument("--out_dir", default="./figures", help="Thư mục lưu biểu đồ PNG")
    parser.add_argument("--export_csv", action="store_true",
                         help="Xuất thêm summary.csv / raw_results.csv vào out_dir")
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    notes = load_notes(args.input_dir)
    summary_df = build_summary_df(notes)
    raw_df = build_raw_df(notes)
    level_df = build_accuracy_by_level_df(notes)
    palette_df = build_palette_dist_df(notes)
    rvl_level_df = build_rule_vs_llm_level_df(notes)
    baselines = compute_reference_baselines(raw_df)

    print_summary_tables(summary_df, baselines)

    if args.export_csv:
        summary_df.to_csv(os.path.join(args.out_dir, "summary.csv"), index=False)
        raw_df.drop(columns=["expected_palettes"]).to_csv(
            os.path.join(args.out_dir, "raw_results.csv"), index=False)
        print(f"\n[export_csv] Đã ghi summary.csv và raw_results.csv vào {args.out_dir}")

    print("\n=== Đang vẽ biểu đồ ===")
    plot_workload_accuracy_bar(summary_df, baselines, args.out_dir)
    plot_fixedset_vs_workload_vs_agreement(summary_df, args.out_dir)
    plot_accuracy_by_level_grouped(level_df, args.out_dir)
    plot_accuracy_heatmap(level_df, args.out_dir)
    plot_ttft_boxplot(raw_df, args.out_dir)
    plot_total_latency_boxplot(raw_df, args.out_dir)
    plot_latency_accuracy_bubble(summary_df, args.out_dir)
    plot_ram_usage_bar(summary_df, args.out_dir)
    plot_init_time_bar(summary_df, args.out_dir)
    plot_battery_bar(summary_df, args.out_dir)
    plot_tokens_per_sec_bar(summary_df, args.out_dir)
    plot_palette_distribution_stacked(palette_df, args.out_dir)
    plot_ocean_bias(palette_df, args.out_dir)
    plot_rule_vs_llm_by_level(rvl_level_df, args.out_dir)
    plot_ttft_vs_total_latency_scatter(raw_df, args.out_dir)
    plot_accuracy_vs_baselines(summary_df, baselines, args.out_dir)
    plot_error_concentration(raw_df, args.out_dir)
    plot_correlation_matrix(summary_df, args.out_dir)

    print(f"\nHoàn tất. Tất cả biểu đồ đã lưu tại: {os.path.abspath(args.out_dir)}")


if __name__ == "__main__":
    main()