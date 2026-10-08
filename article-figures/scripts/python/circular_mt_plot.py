#!/usr/bin/env python3
"""
circular_mt_plot.py — circular map of the mt-genome with coverage.
Enlarged image, more space in the center, tRNA excluded.
"""

import sys
import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import pysam
from Bio import SeqIO


# =============================================================================
# 1. Parse GenBank (skip tRNA)
# =============================================================================
def parse_gb(gb_path, shift=0):
    if not os.path.exists(gb_path):
        print(f"ERROR: {gb_path} not found.")
        sys.exit(1)

    with open(gb_path) as f:
        if f.readline().startswith(">"):
            print("WARNING: FASTA instead of GenBank.")
            return [], 0

    try:
        record = next(SeqIO.parse(gb_path, "genbank"))
        genome_len = len(record.seq)
    except StopIteration:
        return [], 0

    genes = []
    feature_types_seen = set()

    for record in SeqIO.parse(gb_path, "genbank"):
        for feat in record.features:
            feature_types_seen.add(feat.type)

            # === Skip tRNA by feature type ===
            if feat.type == "tRNA":
                continue
            if feat.type not in ("gene", "CDS", "rRNA"):
                continue

            raw = feat.qualifiers.get("gene",
                    feat.qualifiers.get("product", ["Unknown"]))
            name = str(raw[0]) if isinstance(raw, list) else str(raw)

            prod_raw = feat.qualifiers.get("product", [""])
            product = str(prod_raw[0]) if isinstance(prod_raw, list) else str(prod_raw)

            low = name.lower()
            low_prod = product.lower()

            # === Skip tRNA by name/product ===
            if "trna" in low or "trna" in low_prod:
                continue
            if low.startswith("trn") or low_prod.startswith("trn"):
                continue
            if "trna" in product.lower():
                continue

            # Abbreviations
            if "16s" in low or "large" in low:
                name = "rrnL"
            elif "12s" in low or "small" in low:
                name = "rrnS"
            elif "cytochrome c oxidase subunit" in low:
                name = low.replace("cytochrome c oxidase subunit ", "COX")
            elif "cytochrome b" in low:
                name = "CYTB"
            elif "nadh dehydrogenase subunit" in low:
                name = low.replace("nadh dehydrogenase subunit ", "ND")
            elif "atp synthase subunit" in low:
                name = low.replace("atp synthase subunit ", "ATP")

            start  = int(feat.location.start)
            end    = int(feat.location.end)
            strand = feat.location.strand if feat.location.strand is not None else 1

            new_start = (start - shift) % genome_len
            new_end   = (end   - shift) % genome_len

            if new_start < new_end:
                genes.append({
                    "name": name, "start": new_start, "end": new_end,
                    "strand": strand, "type": feat.type,
                })
            else:
                genes.append({
                    "name": name, "start": new_start, "end": genome_len,
                    "strand": strand, "type": feat.type,
                })
                genes.append({
                    "name": name, "start": 0, "end": new_end,
                    "strand": strand, "type": feat.type,
                })

    uniq = []
    for g in genes:
        if not any(u["start"] == g["start"] and u["end"] == g["end"]
                   and u["name"] == g["name"] for u in uniq):
            uniq.append(g)

    n_cds  = sum(1 for g in uniq if g["type"] in ("gene", "CDS"))
    n_rrna = sum(1 for g in uniq if g["type"] == "rRNA")
    print(f"Feature types in GB: {sorted(feature_types_seen)}")
    print(f"Loaded for plotting: {len(uniq)} "
          f"(CDS/gene: {n_cds}, rRNA: {n_rrna}; shift: {shift} bp)")
    return uniq, genome_len


# =============================================================================
# 2. Coverage from BAM
# =============================================================================
def read_coverage(bam_path):
    if not os.path.exists(bam_path) or not os.path.exists(bam_path + ".bai"):
        print(f"ERROR: missing {bam_path} or .bai")
        sys.exit(1)
    bam = pysam.AlignmentFile(bam_path, "rb")
    ref = bam.references[0]
    ref_len = bam.get_reference_length(ref)
    counts = bam.count_coverage(ref, quality_threshold=0)
    cov = np.sum(counts, axis=0).astype(int)
    bam.close()
    return ref, ref_len, cov


# =============================================================================
# 3. Gene color
# =============================================================================
def gene_color(gene):
    name = gene["name"].upper()
    gtype = gene.get("type", "").lower()

    if gtype == "rrna" or name in ("RRNL", "RRNS"):
        return "#9b59b6"
    if "COX" in name or "CYTB" in name or "COB" in name:
        return "#e74c3c"
    if "ND" in name or "NAD" in name:
        return "#3498db"
    if "ATP" in name:
        return "#f1c40f"
    return "#95a5a6"


# =============================================================================
# 4. Main function
# =============================================================================
def main(bam_path, gb_path, out_prefix="circular_mt", shift=0):
    ref, mt_length, cov = read_coverage(bam_path)
    genes, gb_len = parse_gb(gb_path, shift=shift)

    if gb_len and gb_len != mt_length:
        print(f"WARNING: GenBank length ({gb_len}) ≠ BAM length ({mt_length}).")

    mean_cov    = float(np.mean(cov))
    median_cov  = float(np.median(cov))
    max_cov     = int(np.max(cov))
    pct_covered = float(np.sum(cov > 0) / mt_length * 100)

    print(f"Reference: {ref}, {mt_length} bp")
    print(f"Mean: {mean_cov:.1f}×, Median: {median_cov:.1f}×, Max: {max_cov}×")
    print(f"Covered: {pct_covered:.1f}%\n")

    plt.rcParams["font.family"] = "Helvetica"
    plt.rcParams["font.size"] = 10

    # ==================== LARGE FIGURE ====================
    fig = plt.figure(figsize=(16, 16))
    ax = fig.add_subplot(111, projection="polar")
    ax.set_theta_direction(-1)
    ax.set_theta_offset(np.pi / 2)

    # ==================== GEOMETRY (extended) ====================
    R_tick_labels   = 180        # ← was 80, increased 2.25×
    R_inner_bg      = 240        # inner radius of the gene ring
    R_gene_gap      = 4
    R_gene_width    = 36         # thickness of one ring
    R_after_genes   = R_inner_bg + 2*R_gene_width + R_gene_gap
    R_cov_base      = R_after_genes + 55
    R_cov_max       = R_cov_base + 180

    R_fwd_bottom = R_inner_bg + R_gene_width + R_gene_gap
    R_fwd_top    = R_inner_bg + 2*R_gene_width + R_gene_gap
    R_rev_bottom = R_inner_bg
    R_rev_top    = R_inner_bg + R_gene_width

    # ==================== WHITE BACKGROUND ====================
    theta_bg = np.linspace(0, 2*np.pi, 400)
    ax.fill_between(theta_bg, 0, R_cov_max + 40,
                    color="white", zorder=0)

    # ==================== GENES (two rings) ====================
    for gene in genes:
        t_start = (gene["start"] / mt_length) * 2 * np.pi
        t_end   = (gene["end"]   / mt_length) * 2 * np.pi
        color   = gene_color(gene)

        if gene["strand"] >= 0:
            r_bottom, r_top = R_fwd_bottom, R_fwd_top
        else:
            r_bottom, r_top = R_rev_bottom, R_rev_top

        ax.fill_between(np.linspace(t_start, t_end, 100),
                        r_bottom, r_top,
                        color=color, alpha=0.9,
                        edgecolor="white", linewidth=0.6,
                        zorder=3)

        # Labels for large genes
        if (gene["end"] - gene["start"]) > 250:
            t_mid = (t_start + t_end) / 2
            r_mid = (r_bottom + r_top) / 2
            rot = np.degrees(t_mid)
            if 90 < rot < 270:
                rot -= 180
            ax.text(t_mid, r_mid, gene["name"],
                    ha="center", va="center",
                    fontsize=11, rotation=rot,
                    fontweight="bold", color="black",
                    zorder=5)

    # ==================== COVERAGE ====================
    angles = np.linspace(0, 2*np.pi, mt_length)
    r_cov = R_cov_base + cov * (R_cov_max - R_cov_base) / max_cov

    ax.fill_between(angles, R_cov_base, r_cov,
                    color="#5B8DB8", alpha=0.45,
                    linewidth=0, zorder=2)
    ax.plot(angles, r_cov, color="#2C5F8A",
            linewidth=0.6, alpha=0.8, zorder=3)

    r_mean = R_cov_base + mean_cov * (R_cov_max - R_cov_base) / max_cov
    ax.plot(angles, [r_mean]*mt_length,
            color="crimson", linestyle="--",
            linewidth=2.0, zorder=4)

    # ==================== COORDINATE SCALE ====================
    ax.plot(np.linspace(0, 2*np.pi, 200),
            [R_tick_labels]*200,
            color="#cccccc", linewidth=0.6, zorder=1)

    n_ticks = 9
    tick_positions = np.linspace(0, mt_length, n_ticks, endpoint=False)
    for pos in tick_positions:
        theta = (pos / mt_length) * 2 * np.pi
        ax.plot([theta, theta], [R_tick_labels, R_tick_labels - 10],
                color="#999999", linewidth=1.0, zorder=2)
        label = f"{pos/1000:.1f} kb" if pos > 0 else "0"
        rot_deg = -np.degrees(theta)
        if 90 < abs(rot_deg) < 270:
            rot_deg += 180
        ax.text(theta, R_tick_labels - 28, label,
                ha="center", va="center",
                fontsize=11, color="#555555",
                rotation=rot_deg, zorder=3)

    ax.set_xticks([])
    ax.set_yticks([])
    ax.spines["polar"].set_visible(False)
    ax.set_ylim(0, R_cov_max + 60)

    # ==================== STATISTICS IN THE CENTER ====================
    plt.text(0, 0,
             f"{ref}\n\n"
             f"{mt_length:,} bp\n"
             f"Mean: {mean_cov:.1f}×\n"
             f"Median: {median_cov:.1f}×\n"
             f"Max: {max_cov}×\n"
             f"Covered: {pct_covered:.1f}%",
             ha="center", va="center",
             fontsize=14, color="#2c3e50",
             zorder=10,
             linespacing=1.5)

    # ==================== LEGEND AT THE BOTTOM ====================
    legend_elements = [
        Patch(facecolor="#3498db", edgecolor="black", label="Complex I (nad)"),
        Patch(facecolor="#e74c3c", edgecolor="black", label="Complex III–IV (cob, cox)"),
        Patch(facecolor="#f1c40f", edgecolor="black", label="Complex V (atp)"),
        Patch(facecolor="#9b59b6", edgecolor="black", label="rRNA"),
        Patch(facecolor="#5B8DB8", edgecolor="#2C5F8A", alpha=0.5, label="Coverage"),
        Patch(facecolor="white", edgecolor="crimson", linestyle="--",
              label=f"Mean coverage ({mean_cov:.1f}×)"),
    ]

    fig.legend(handles=legend_elements,
               loc="lower center",
               bbox_to_anchor=(0.5, 0.01),
               ncol=3, fontsize=12,
               frameon=False)

    plt.tight_layout()
    png = f"{out_prefix}.png"
    pdf = f"{out_prefix}.pdf"
    plt.savefig(png, dpi=600, bbox_inches="tight",
                pad_inches=0.3, facecolor="white")
    plt.savefig(pdf, bbox_inches="tight",
                pad_inches=0.3, facecolor="white")
    print(f"Saved:\n  {os.path.abspath(png)}\n  {os.path.abspath(pdf)}")


# =============================================================================
# 5. Entry point
# =============================================================================
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python circular_mt_plot.py <bam> <genbank> "
              "[output_prefix] [shift]")
        sys.exit(1)

    bam_path = sys.argv[1]
    gb_path  = sys.argv[2]
    prefix   = sys.argv[3] if len(sys.argv) > 3 else "circular_mt"
    shift    = int(sys.argv[4]) if len(sys.argv) > 4 else 0

    main(bam_path, gb_path, prefix, shift)
