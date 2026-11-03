#!/usr/bin/env python3
"""
circular_mt_plot.py

Visualize circular mitochondrial genomes: coverage, MAPQ, strand bias, and 
linearization junction evidence (split reads, folded coverage).
"""

import argparse
import os
import sys
import re
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Patch, Rectangle
from matplotlib.lines import Line2D
from matplotlib.gridspec import GridSpec
import pysam
from Bio import SeqIO


def parse_gb(gb_path, include_trna=True):
    """Parse GenBank features, deduplicating genes/CDS entries."""
    if not os.path.exists(gb_path):
        sys.exit(f"ERROR: {gb_path} not found.")
    with open(gb_path) as f:
        if f.readline().startswith(">"):
            sys.exit("ERROR: FASTA provided, expected GenBank.")
    
    try:
        record = next(SeqIO.parse(gb_path, "genbank"))
    except StopIteration:
        sys.exit("ERROR: Empty GenBank file.")
        
    genome_len = len(record.seq)
    cds_intervals = {(int(f.location.start), int(f.location.end)) for f in record.features if f.type == "CDS"}
    
    genes = []
    for feat in record.features:
        if feat.type == "tRNA":
            if not include_trna: continue
        elif feat.type not in ("gene", "CDS", "rRNA"):
            continue
            
        start, end = int(feat.location.start), int(feat.location.end)
        # Skip 'gene' features that duplicate 'CDS' coordinates
        if feat.type == "gene" and (start, end) in cds_intervals:
            continue

        raw = feat.qualifiers.get("gene", feat.qualifiers.get("product", ["Unknown"]))
        name = str(raw[0]) if isinstance(raw, list) else str(raw)
        prod_raw = feat.qualifiers.get("product", [""])
        product = str(prod_raw[0]) if isinstance(prod_raw, list) else str(prod_raw)

        # Normalize gene nomenclature
        low, low_prod = name.lower(), product.lower()
        if "16s" in low or "large" in low or "rrnl" in low: name = "rrnL"
        elif "12s" in low or "small" in low or "rrns" in low: name = "rrnS"
        elif "cytochrome c oxidase subunit" in low_prod: name = low_prod.replace("cytochrome c oxidase subunit ", "COX").upper()
        elif "cytochrome b" in low_prod: name = "CYTB"
        elif "nadh dehydrogenase subunit" in low_prod: name = low_prod.replace("nadh dehydrogenase subunit ", "ND").upper()
        elif "atp synthase subunit" in low_prod: name = low_prod.replace("atp synthase subunit ", "ATP").upper()

        strand = feat.location.strand if feat.location.strand is not None else 1

        # Handle genes spanning the origin (start > end)
        if start < end:
            genes.append({"name": name, "start": start, "end": end, "strand": strand, "type": feat.type, "product": product})
        else:
            genes.append({"name": name, "start": start, "end": genome_len, "strand": strand, "type": feat.type, "product": product})
            genes.append({"name": name, "start": 0, "end": end, "strand": strand, "type": feat.type, "product": product})

    # Deduplicate
    seen, uniq = set(), []
    for g in genes:
        key = (g["name"], g["start"], g["end"], g["strand"], g["type"])
        if key in seen: continue
        seen.add(key)
        uniq.append(g)
    return uniq, genome_len


def parse_bed(bed_path, include_trna=True):
    """Parse BED file for supplementary annotations."""
    genes = []
    if not os.path.exists(bed_path): return genes
    with open(bed_path) as f:
        for line in f:
            if line.startswith("#") or line.startswith("track") or not line.strip(): continue
            parts = line.strip().split("\t")
            if len(parts) >= 6:
                name = parts[3].upper()
                start, end = int(parts[1]), int(parts[2])
                strand = 1 if parts[5] == "+" else -1
                gtype = "tRNA" if name.startswith("TRN") else "CDS"
                if gtype == "tRNA" and not include_trna: continue
                genes.append({"name": name, "start": start, "end": end, "strand": strand, "type": gtype, "product": name})
    return genes


def find_cox1_start(genes):
    """Locate cox1 start codon for standardized genome orientation."""
    for g in genes:
        if g["name"].upper() == "COX1" or "cytochrome c oxidase subunit i" in g.get("product", "").lower():
            return g["start"]
    return None


def detect_reverse_complement(genes):
    """Determine if the majority of PCGs map to the reverse strand."""
    cox1 = [g for g in genes if g["name"].upper() == "COX1"]
    if cox1: return cox1[0]["strand"] < 0
    pcgs = [g for g in genes if g["type"] == "CDS"]
    if pcgs: return sum(1 for g in pcgs if g["strand"] < 0) > len(pcgs) / 2
    return False


def transform(genes, cov, mapq, cov_fwd, cov_rev, flip=False, shift=0):
    """Apply reverse-complement and/or circular shift to all data tracks."""
    L = len(cov)
    if flip:
        cov = cov[::-1].copy(); mapq = mapq[::-1].copy()
        cov_fwd = cov_fwd[::-1].copy(); cov_rev = cov_rev[::-1].copy()
        genes = [{**g, "start": L - g["end"], "end": L - g["start"], "strand": -g["strand"]} for g in genes]
    if shift:
        shift = shift % L
        cov = np.roll(cov, -shift); mapq = np.roll(mapq, -shift)
        cov_fwd = np.roll(cov_fwd, -shift); cov_rev = np.roll(cov_rev, -shift)
        new_genes = []
        for g in genes:
            ns, ne = (g["start"] - shift) % L, (g["end"] - shift) % L
            if ns < ne: new_genes.append({**g, "start": ns, "end": ne})
            else:
                new_genes.append({**g, "start": ns, "end": L})
                new_genes.append({**g, "start": 0, "end": ne})
        genes = new_genes
    return genes, cov, mapq, cov_fwd, cov_rev


def read_coverage_and_mapq(bam_path):
    """Extract per-base depth, mean MAPQ, and strand-specific coverage from BAM."""
    if not os.path.exists(bam_path): sys.exit(f"ERROR: {bam_path} not found.")
    bam = pysam.AlignmentFile(bam_path, "rb")
    ref = bam.references[0]
    ref_len = bam.get_reference_length(ref)
    
    cov = np.sum(bam.count_coverage(ref, quality_threshold=0), axis=0).astype(int)
    
    sum_mapq = np.zeros(ref_len, dtype=float)
    count_reads = np.zeros(ref_len, dtype=float)
    cov_fwd = np.zeros(ref_len, dtype=int)
    cov_rev = np.zeros(ref_len, dtype=int)

    for read in bam.fetch(ref):
        if read.is_unmapped or read.is_secondary or read.is_supplementary: continue
        start, end = read.reference_start, read.reference_end
        if end is not None:
            sum_mapq[start:end] += read.mapping_quality
            count_reads[start:end] += 1
            if read.is_reverse: cov_rev[start:end] += 1
            else: cov_fwd[start:end] += 1
                
    mean_mapq = np.divide(sum_mapq, count_reads, out=np.zeros_like(sum_mapq), where=count_reads>0)
    bam.close()
    return ref, ref_len, cov, mean_mapq, cov_fwd, cov_rev


def find_spanning_reads(bam_path, ref_len, center_pos, L, shift, flip, window=200, max_reads=30):
    """Identify split reads (SA tags) bridging the linearization junction."""
    bam = pysam.AlignmentFile(bam_path, "rb")
    ref = bam.references[0]
    reads = []
    
    def map_coord(x):
        if flip: x = L - x
        return (x - shift) % L
    
    def rel_pos(x):
        d = (x - center_pos) % L
        if d > L / 2: d -= L
        return d
    
    for read in bam.fetch(ref):
        if len(reads) >= max_reads: break
        if read.is_unmapped or read.is_secondary or read.is_supplementary: continue
        if not read.has_tag("SA"): continue
        
        sa = read.get_tag("SA")
        sa_pos = None
        sa_cigar = None
        # Parse SA tag (format: rname,pos,strand,CIGAR,mapQ,NM;)
        for entry in sa.split(";"):
            if not entry.strip(): continue
            parts = entry.split(",")
            if len(parts) < 6: continue
            try:
                sa_pos = int(parts[1]) - 1 # Convert to 0-based
                sa_cigar = parts[3]
            except (ValueError, IndexError):
                continue
            break
        
        if sa_pos is None or sa_cigar is None: continue
        
        # Check if primary and SA alignments map to opposite ends
        is_primary_end = read.reference_start > ref_len - window
        is_primary_start = (read.reference_end or 0) <= window
        is_sa_end = sa_pos > ref_len - window
        is_sa_start = sa_pos <= window
        
        spans_junction = (
            (is_primary_end and is_sa_start) or
            (is_primary_start and is_sa_end)
        )
        if not spans_junction: continue
        
        # Calculate aligned length from CIGAR string
        sa_len = sum(int(n) for n, op in re.findall(r'(\d+)([MIDNSHP=X])', sa_cigar) if op in ('M', '=', 'X'))
        if sa_len == 0: continue
        
        primary_len = (read.reference_end or 0) - (read.reference_start or 0)
        
        p_start = rel_pos(map_coord(read.reference_start))
        p_end = rel_pos(map_coord((read.reference_end or 0) - 1))
        sa_start_rel = rel_pos(map_coord(sa_pos))
        sa_end_rel = rel_pos(map_coord(sa_pos + sa_len - 1))
        
        reads.append({
            "name": read.query_name, "mapq": read.mapping_quality, "is_reverse": read.is_reverse,
            "primary_start": p_start, "primary_end": p_end,
            "sa_start": sa_start_rel, "sa_end": sa_end_rel,
            "primary_len": primary_len, "sa_len": sa_len,
        })
    bam.close()
    reads.sort(key=lambda r: -r["mapq"])
    return reads


def find_contiguous_regions(mask, min_len=20):
    """Extract contiguous True intervals from a boolean mask."""
    regions, start = [], None
    for i, v in enumerate(mask):
        if v and start is None: start = i
        elif not v and start is not None:
            if i - start >= min_len: regions.append((start, i))
            start = None
    if start is not None and len(mask) - start >= min_len: regions.append((start, len(mask)))
    return regions


def gene_color(g):
    """Assign colors based on mitochondrial complex."""
    name = g["name"].upper()
    if g["type"] == "rRNA" or name in ("RRNL", "RRNS"): return "#9b59b6"
    if any(x in name for x in ("COX", "CYTB", "COB")): return "#e74c3c"
    if "ND" in name: return "#3498db"
    if "ATP" in name: return "#f1c40f"
    return "#95a5a6"


def draw_angular_band(ax, t_s, t_e, r_min, r_max, color, alpha=0.2, zorder=1):
    """Draw a filled band on polar axes, handling 0/2pi wraparound."""
    if t_e < t_s:
        draw_angular_band(ax, t_s, 2 * np.pi, r_min, r_max, color, alpha, zorder)
        draw_angular_band(ax, 0, t_e, r_min, r_max, color, alpha, zorder)
        return
    theta = np.linspace(t_s, t_e, max(10, int((t_e - t_s) * 100)))
    ax.fill_between(theta, r_min, r_max, color=color, alpha=alpha, zorder=zorder, linewidth=0)


def main():
    ap = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    ap.add_argument("bam")
    ap.add_argument("genbank")
    ap.add_argument("output_prefix", nargs="?", default="circular_mt")
    ap.add_argument("--shift", type=int, default=0)
    ap.add_argument("--standardize-cox1", action="store_true")
    ap.add_argument("--include-trna", action="store_true")
    ap.add_argument("--auto-flip", action="store_true")
    ap.add_argument("--highlight-low", action="store_true", default=True)
    ap.add_argument("--no-highlight-low", action="store_false", dest="highlight_low")
    ap.add_argument("--highlight-peaks", action="store_true", default=True)
    ap.add_argument("--no-highlight-peaks", action="store_false", dest="highlight_peaks")
    ap.add_argument("--low-threshold", type=float, default=0.1)
    ap.add_argument("--peak-percentile", type=float, default=99)
    ap.add_argument("--linear", action="store_true")
    ap.add_argument("--bed", help="Supplementary BED annotations")
    ap.add_argument("--simple", action="store_true", help="Output 4-panel view, hide junction")
    ap.add_argument("--min-cov", type=int, default=0, help="Visual floor for circular coverage track")
    ap.add_argument("--svg", action="store_true", help="Export vector SVG")
    args = ap.parse_args()

    print("\n" + "="*60)
    print(" MITOCHONDRIAL GENOME CIRCULAR PLOTTER (v36)")
    print("="*60)
    print(f" BAM:      {args.bam}")
    print(f" GenBank:  {args.genbank}")
    print(f" Output:   {args.output_prefix}")
    print(f" Flags:    {'--simple ' if args.simple else ''}{'--linear ' if args.linear else ''}{'--svg ' if args.svg else ''}--min-cov {args.min_cov}")
    print("-" * 60)

    print("→ Loading data...")
    ref, mt_len, cov, mapq, cov_fwd, cov_rev = read_coverage_and_mapq(args.bam)
    all_genes, gb_len = parse_gb(args.genbank, include_trna=True)
    
    if not all_genes: sys.exit("ERROR: No genes found in GenBank.")
    
    print(f"  Contig: {ref}")
    print(f"  Length: {mt_len:,} bp")
    print(f"  Genes:  {len(all_genes)} (GenBank)")

    if args.bed:
        bed_genes = parse_bed(args.bed, include_trna=args.include_trna)
        existing_names = {g["name"].upper() for g in all_genes}
        added_count = 0
        for bg in bed_genes:
            if bg["name"].upper() not in existing_names:
                all_genes.append(bg)
                existing_names.add(bg["name"].upper())
                added_count += 1
        all_genes.sort(key=lambda x: x["start"])
        print(f"  Genes:  +{added_count} added from BED")

    flipped = False
    if args.auto_flip and detect_reverse_complement(all_genes):
        print("→ Reverse strand detected, flipping orientation.")
        all_genes, cov, mapq, cov_fwd, cov_rev = transform(all_genes, cov, mapq, cov_fwd, cov_rev, flip=True)
        flipped = True

    shift = args.shift
    if args.standardize_cox1:
        cox1_start = find_cox1_start(all_genes)
        if cox1_start is not None:
            shift = cox1_start
            print(f"→ Standardizing to cox1: shift = {shift} bp.")
    if shift:
        all_genes, cov, mapq, cov_fwd, cov_rev = transform(all_genes, cov, mapq, cov_fwd, cov_rev, shift=shift)

    junction_pos = (mt_len - shift) % mt_len
    search_radius = 50
    search_range = (np.arange(junction_pos - search_radius, junction_pos + search_radius) % mt_len)
    real_min_pos = search_range[np.argmin(cov[search_range])]
    
    print(f"→ Junction analysis:")
    print(f"  Theoretical: {junction_pos:,}")
    print(f"  Real min:    {real_min_pos:,}")

    spanning_reads = find_spanning_reads(args.bam, mt_len, real_min_pos, mt_len, shift, flipped, window=200, max_reads=30)
    spanning_count = len(spanning_reads)
    
    print(f"  Split reads (SA): {spanning_count}")
    if spanning_count > 0:
        for rd in spanning_reads[:3]:
            print(f"    - {rd['name'][:35]} | MAPQ={rd['mapq']} | Primary={rd['primary_len']}bp | SA={rd['sa_len']}bp")

    genes = all_genes if args.include_trna else [g for g in all_genes if g["type"] != "tRNA"]
    min_cov = int(cov.min())
    max_cov = int(cov.max())
    mean_cov, median_cov = float(cov.mean()), float(np.median(cov))
    pct_covered = 100.0 * (cov > 0).sum() / mt_len
    
    min_display = min_cov
    if args.min_cov > 0:
        min_display = args.min_cov
        print(f"→ Note: Circular Min coverage forced to {min_display}×")

    print(f"→ Coverage stats:")
    print(f"  Min (raw): {min_cov}× | Min (plot): {min_display}×")
    print(f"  Median: {median_cov:.1f}× | Mean: {mean_cov:.1f}× | Max: {max_cov}×")
    print(f"  Covered: {pct_covered:.1f}%")

    low_regions, peak_regions = [], []
    if args.highlight_low and median_cov > 0:
        low_mask = cov < args.low_threshold * median_cov
        idx = np.arange(mt_len)
        dist = np.abs(idx - junction_pos)
        dist = np.minimum(dist, mt_len - dist)
        low_mask[dist < 50] = False # Mask junction region
        low_regions = find_contiguous_regions(low_mask, min_len=20)
    if args.highlight_peaks and max_cov > 0:
        pthr = np.percentile(cov, args.peak_percentile)
        peak_regions = find_contiguous_regions(cov > pthr, min_len=10)

    print(f"→ Anomalies:")
    print(f"  Low cov regions: {len(low_regions)}")
    print(f"  Peak regions:    {len(peak_regions)}")

    # Geometry setup
    R_tick_labels, R_inner_bg, R_gene_gap, R_gene_width = 350, 550, 8, 70
    
    R_rev_bottom = R_inner_bg
    R_rev_top = R_inner_bg + R_gene_width
    R_fwd_bottom = R_inner_bg + R_gene_width + R_gene_gap
    R_fwd_top = R_inner_bg + 2 * R_gene_width + R_gene_gap
    
    R_trna_base = R_fwd_top + 25
    R_cov_base = R_trna_base + 50
    R_cov_max = R_cov_base + 450

    plt.rcParams["font.family"] = "sans-serif"
    plt.rcParams["font.size"] = 18
    plt.rcParams['svg.fonttype'] = 'none' # Keep text editable in SVG

    # Layout configuration
    if args.linear:
        n_panels = 4 if args.simple else 6
        height_ratios = [12, 1.2, 1.2, 1.2] if args.simple else [12, 1.2, 1.2, 1.2, 1.5, 3]
        fig_size = (22, 26) if args.simple else (22, 38)
        
        fig = plt.figure(figsize=fig_size)
        gs = GridSpec(n_panels, 1, height_ratios=height_ratios, figure=fig, hspace=0.15)
        
        ax = fig.add_subplot(gs[0], projection="polar")
        ax2 = fig.add_subplot(gs[1])
        ax3 = fig.add_subplot(gs[2], sharex=ax2)
        ax4 = fig.add_subplot(gs[3], sharex=ax2)
        
        if not args.simple:
            ax5 = fig.add_subplot(gs[4])
            ax6 = fig.add_subplot(gs[5])
        else:
            ax5, ax6 = None, None
    else:
        fig = plt.figure(figsize=(20, 20))
        ax = fig.add_subplot(111, projection="polar")
        ax2, ax3, ax4, ax5, ax6 = None, None, None, None, None

    ax.set_theta_direction(-1)
    ax.set_theta_offset(np.pi / 2)
    ax.fill_between(np.linspace(0, 2 * np.pi, 400), 0, R_cov_max + 20, color="white", zorder=0)

    # Highlight anomalies
    for s, e in low_regions:
        draw_angular_band(ax, (s / mt_len) * 2 * np.pi, (e / mt_len) * 2 * np.pi, R_cov_base, R_cov_max, color="#e74c3c", alpha=0.15, zorder=1.5)
    for s, e in peak_regions:
        draw_angular_band(ax, (s / mt_len) * 2 * np.pi, (e / mt_len) * 2 * np.pi, R_cov_base, R_cov_max, color="#f39c12", alpha=0.15, zorder=1.5)

    # Genes (PCGs & rRNAs)
    for g in genes:
        is_trna = (g["type"] == "tRNA") or g["name"].lower().startswith("trn") or ("trna" in g.get("product", "").lower())
        if is_trna: continue

        t_s = (g["start"] / mt_len) * 2 * np.pi
        t_e = (g["end"] / mt_len) * 2 * np.pi
        if t_e < t_s: t_e = 2 * np.pi
        r_b, r_t = (R_fwd_bottom, R_fwd_top) if g["strand"] >= 0 else (R_rev_bottom, R_rev_top)
        theta = np.linspace(t_s, t_e, max(50, int((t_e - t_s) * 200)))
        ax.fill_between(theta, r_b, r_t, color=gene_color(g), alpha=0.9, edgecolor="white", linewidth=1.2, zorder=3)
        
        if (g["end"] - g["start"]) > 80:
            t_mid, r_mid = (t_s + t_e) / 2, (r_b + r_t) / 2
            if (g["end"] - g["start"]) <= 250:
                font_sz = 12
                r_mid = (r_t + 25) if g["strand"] >= 0 else (r_b - 25)
            else:
                font_sz = 20
            rot = np.degrees(t_mid)
            if 90 < rot < 270: rot -= 180
            ax.text(t_mid, r_mid, g["name"], ha="center", va="center", fontsize=font_sz, rotation=rot, fontweight="bold", color="black", zorder=5)

    # tRNAs (ticks)
    if args.include_trna:
        for g in genes:
            is_trna = (g["type"] == "tRNA") or g["name"].lower().startswith("trn") or ("trna" in g.get("product", "").lower())
            if not is_trna: continue
            
            t_s = (g["start"] / mt_len) * 2 * np.pi
            t_e = (g["end"] / mt_len) * 2 * np.pi
            if t_e < t_s: t_e = 2 * np.pi
            t_mid = (t_s + t_e) / 2
            ax.plot([t_mid, t_mid], [R_trna_base - 15, R_trna_base + 15], color="#2ecc71", linewidth=4, solid_capstyle="round", zorder=4)

    # Coverage track
    angles = np.linspace(0, 2 * np.pi, mt_len, endpoint=False)
    cov_plot = np.copy(cov)
    if args.min_cov > 0:
        cov_plot[cov_plot < args.min_cov] = args.min_cov
    else:
        cov_plot[cov_plot < 0] = 0
        
    r_cov = (R_cov_base + cov_plot * (R_cov_max - R_cov_base) / max_cov) if max_cov > 0 else np.full(mt_len, R_cov_base)
    
    ax.fill_between(angles, R_cov_base, r_cov, color="#5B8DB8", alpha=0.45, linewidth=0, zorder=2)
    ax.plot(angles, r_cov, color="#2C5F8A", linewidth=1.5, alpha=0.9, zorder=3)
    
    if max_cov > 0:
        r_mean = R_cov_base + mean_cov * (R_cov_max - R_cov_base) / max_cov
        ax.plot(angles, [r_mean] * mt_len, color="crimson", linestyle="--", linewidth=4.0, zorder=4)

    # Junction marker
    if not args.simple:
        j_theta = (junction_pos / mt_len) * 2 * np.pi
        ax.plot([j_theta, j_theta], [R_inner_bg-20, R_cov_max+20], color="black", linestyle="-.", linewidth=2.5, zorder=4)
        ax.text(j_theta, R_cov_max + 40, f"Linearization junction\n({spanning_count} spanning reads)", ha="center", va="bottom", fontsize=11, fontweight="bold", zorder=10, 
                rotation=np.degrees(j_theta) if j_theta < np.pi else np.degrees(j_theta)-180,
                bbox=dict(facecolor='white', alpha=0.8, edgecolor='none', pad=2))

    # Coordinate ticks
    ax.plot(np.linspace(0, 2 * np.pi, 200), [R_tick_labels] * 200, color="#cccccc", linewidth=1.5, zorder=1)
    for pos in np.linspace(0, mt_len, 9, endpoint=False):
        theta = (pos / mt_len) * 2 * np.pi
        ax.plot([theta, theta], [R_tick_labels, R_tick_labels - 25], color="#999999", linewidth=2.0, zorder=2)
        label = f"{pos/1000:.1f} kb" if pos > 0 else "0"
        rot = -np.degrees(theta)
        if 90 < abs(rot) < 270: rot += 180
        ax.text(theta, R_tick_labels - 60, label, ha="center", va="center", fontsize=20, color="#333333", rotation=rot, zorder=3)

    ax.set_xticks([]); ax.set_yticks([])
    ax.spines["polar"].set_visible(False)
    ax.set_ylim(0, R_cov_max + 80)
    
    # Center statistics
    font_size_center = 16 if args.simple else 18
    center_text = (
        f"{mt_len:,} bp\n"
        f"─────────────\n"
        f"Min: {min_display}×   Max: {max_cov}×\n"
        f"Mean: {mean_cov:.1f}×   Median: {median_cov:.1f}×\n"
        f"Covered: {pct_covered:.1f}%"
    )
    ax.text(0, 0, center_text, 
            ha="center", va="center", fontsize=font_size_center, color="#2c3e50", zorder=10, 
            linespacing=1.3, family="sans-serif", bbox=dict(facecolor='white', alpha=0.6, edgecolor='none', pad=8))

    # Legend
    legend = [
        Patch(facecolor="#3498db", edgecolor="black", label="Complex I (nad)"),
        Patch(facecolor="#e74c3c", edgecolor="black", label="Complex III–IV (cob, cox)"),
        Patch(facecolor="#f1c40f", edgecolor="black", label="Complex V (atp)"),
        Patch(facecolor="#9b59b6", edgecolor="black", label="rRNA"),
    ]
    if args.include_trna: 
        legend.append(Line2D([0], [0], color="#2ecc71", linewidth=4, label="tRNA"))
    
    legend.append(Patch(facecolor="#5B8DB8", edgecolor="#2C5F8A", alpha=0.5, label="Coverage"))
    legend.append(Patch(facecolor="white", edgecolor="crimson", linestyle="--", label=f"Mean ({mean_cov:.1f}×)"))
    if low_regions: legend.append(Patch(facecolor="#e74c3c", edgecolor="black", alpha=0.3, label=f"Low coverage (<{args.low_threshold*100:.0f}% median)"))
    if peak_regions: legend.append(Patch(facecolor="#f39c12", edgecolor="black", alpha=0.3, label=f"Peak (>{args.peak_percentile:.0f}th pct)"))
    
    if not args.simple:
        legend.append(Line2D([0], [0], color="black", linestyle="-.", linewidth=2.5, label="Linearization junction"))

    # Linear subpanels
    if ax2 is not None:
        x = np.arange(mt_len)
        
        # Coverage
        ax2.fill_between(x, 0, cov, color="#5B8DB8", alpha=0.5, linewidth=0)
        ax2.plot(x, cov, color="#2C5F8A", linewidth=1.5)
        ax2.axhline(median_cov, color="green", linestyle=":", linewidth=2.5, label=f"Median ({median_cov:.1f}×)")
        for s, e in low_regions: ax2.axvspan(s, e, color="#e74c3c", alpha=0.2)
        for s, e in peak_regions: ax2.axvspan(s, e, color="#f39c12", alpha=0.2)
        if not args.simple: ax2.axvline(junction_pos, color="black", linestyle="-.", linewidth=2.5)
        ax2.set_ylabel("Coverage Depth", fontsize=18, color="#2C5F8A", fontweight="bold")
        ax2.tick_params(axis='y', labelcolor="#2C5F8A", labelsize=18)
        ax2.tick_params(axis='x', labelbottom=False)
        ax2.grid(alpha=0.3)
        ax2.legend(loc="upper right", fontsize=16)

        # MAPQ
        ax3.fill_between(x, 0, mapq, color="darkorange", alpha=0.4, linewidth=0)
        ax3.plot(x, mapq, color="darkorange", linewidth=1.8, label="Mean MAPQ")
        for s, e in low_regions: ax3.axvspan(s, e, color="#e74c3c", alpha=0.2)
        for s, e in peak_regions: ax3.axvspan(s, e, color="#f39c12", alpha=0.2)
        ax3.set_ylim(0, 60)
        ax3.set_ylabel("Mean MAPQ", fontsize=18, color="darkorange", fontweight="bold")
        ax3.tick_params(axis='y', labelcolor="darkorange", labelsize=18)
        ax3.tick_params(axis='x', labelbottom=False)
        ax3.grid(alpha=0.3)
        ax3.legend(loc="upper right", fontsize=16)

        # Strand bias
        ax4.fill_between(x, 0, cov_fwd, color="#1f77b4", alpha=0.6, linewidth=0, label="Forward strand (+)")
        ax4.fill_between(x, 0, -cov_rev, color="#d62728", alpha=0.6, linewidth=0, label="Reverse strand (-)")
        for s, e in low_regions: ax4.axvspan(s, e, color="#e74c3c", alpha=0.2)
        for s, e in peak_regions: ax4.axvspan(s, e, color="#f39c12", alpha=0.2)
        if not args.simple: ax4.axvline(junction_pos, color="black", linestyle="-.", linewidth=2.5)
        ax4.axhline(0, color="black", linewidth=1.5, linestyle="--")
        ax4.set_xlim(0, mt_len)
        ax4.set_xlabel(f"Position (bp), shifted by {shift}", fontsize=18, fontweight="bold")
        ax4.set_ylabel("Strand Coverage\n(+ up / - down)", fontsize=18, fontweight="bold")
        max_strand_cov = max(cov_fwd.max(), cov_rev.max())
        ax4.set_ylim(-max_strand_cov * 1.1, max_strand_cov * 1.1)
        ax4.tick_params(axis='y', labelsize=18)
        ax4.tick_params(axis='x', labelsize=18)
        ax4.grid(alpha=0.3)
        ax4.legend(loc="upper right", fontsize=16)

        if not args.simple:
            # Folded coverage (junction analysis)
            W = 200
            x_fold = np.arange(-W, W)
            idx_fold = (real_min_pos + x_fold) % mt_len
            folded_cov = cov[idx_fold]
            
            ax5.fill_between(x_fold, 0, folded_cov, color="mediumseagreen", alpha=0.5, linewidth=0)
            ax5.plot(x_fold, folded_cov, color="darkgreen", linewidth=2.5)
            ax5.axhline(median_cov, color="green", linestyle=":", linewidth=2.5, label=f"Genome Median ({median_cov:.1f}×)")
            ax5.axvline(0, color="crimson", linestyle="--", linewidth=2.5, label="Junction")
            ax5.set_xlim(-W, W)
            ax5.set_ylim(0, max(folded_cov) * 1.2)
            ax5.set_ylabel("Folded Coverage", fontsize=18, color="darkgreen", fontweight="bold")
            ax5.tick_params(axis='y', labelcolor="darkgreen", labelsize=18)
            ax5.tick_params(axis='x', labelbottom=False)
            ax5.grid(alpha=0.3)
            ax5.legend(loc="upper right", fontsize=16)
            
            # Spanning reads (IGV-like)
            ax6.set_xlim(-W, W)
            n = max(len(spanning_reads), 3)
            ax6.set_ylim(-0.7, n + 0.7)
            ax6.axvspan(-15, 15, color="#ffebee", alpha=0.5, zorder=0)
            
            for i, rd in enumerate(spanning_reads):
                y = i
                color = "#d62728" if rd["is_reverse"] else "#2c7fb8"
                
                # Primary alignment
                ax6.add_patch(Rectangle((rd["primary_start"], y - 0.35), rd["primary_end"] - rd["primary_start"], 0.7,
                                         facecolor=color, edgecolor="black", linewidth=0.8, alpha=0.9, zorder=3))
                
                # SA alignment
                ax6.add_patch(Rectangle((rd["sa_start"], y - 0.35), rd["sa_end"] - rd["sa_start"], 0.7,
                                         facecolor=color, edgecolor="black", linewidth=0.8, alpha=0.4, zorder=3))
                
                # Connect primary and SA
                if rd["primary_end"] < rd["sa_start"]:
                    ax6.plot([rd["primary_end"], rd["sa_start"]], [y, y], color=color, linestyle=":", linewidth=1.5, alpha=0.8, zorder=2)
                elif rd["sa_end"] < rd["primary_start"]:
                    ax6.plot([rd["sa_end"], rd["primary_start"]], [y, y], color=color, linestyle=":", linewidth=1.5, alpha=0.8, zorder=2)
                
                name_short = rd["name"].split(":")[0]
                if len(name_short) > 22: name_short = name_short[:19] + "..."
                ax6.text(-W - 8, y, name_short, ha="right", va="center", fontsize=8, family="monospace", color="#222222")
                ax6.text(W + 8, y, f"MQ={rd['mapq']}  ({rd['primary_len']}+{rd['sa_len']}bp)", ha="left", va="center", 
                         fontsize=8, family="monospace", fontweight="bold", color="#222222")
            
            ax6.axvline(0, color="crimson", linestyle="--", linewidth=2.5)
            ax6.set_ylabel("Spanning reads", fontsize=16, fontweight="bold")
            ax6.set_xlabel(f"Distance from junction (bp)", fontsize=16, fontweight="bold")
            ax6.tick_params(axis='y', left=False, labelleft=False)
            ax6.tick_params(axis='x', labelsize=16)
            ax6.grid(alpha=0.2, axis='x')
            ax6.set_title(f"Reads spanning the junction (N = {spanning_count})  |  Solid = primary, Faded = SA, Dotted = same read", 
                          fontsize=13, fontweight="bold", pad=10, color="#333333")
            
            legend_reads = [
                Patch(facecolor="#2c7fb8", edgecolor="black", label="Forward (primary)"),
                Patch(facecolor="#2c7fb8", edgecolor="black", alpha=0.4, label="Forward (SA part)"),
                Patch(facecolor="#d62728", edgecolor="black", label="Reverse (primary)"),
            ]
            ax6.legend(handles=legend_reads, loc="upper right", fontsize=9, framealpha=0.95)

    fig.subplots_adjust(left=0.06, right=0.94, top=0.98, bottom=0.12)
    fig.legend(handles=legend, loc="lower center", bbox_to_anchor=(0.5, 0.02), ncol=5, fontsize=18, frameon=False)

    print("→ Rendering plots...")
    png = f"{args.output_prefix}.png"
    pdf = f"{args.output_prefix}.pdf"
    
    print(f"→ Saving files...")
    plt.savefig(png, dpi=600, bbox_inches="tight", pad_inches=0.3, facecolor="white")
    plt.savefig(pdf, bbox_inches="tight", pad_inches=0.3, facecolor="white")
    
    svg = None
    if args.svg:
        svg = f"{args.output_prefix}.svg"
        plt.savefig(svg, format="svg", bbox_inches="tight", pad_inches=0.3, facecolor="white")
    
    print("\n" + "="*60)
    print(f" DONE!")
    print(f"   PNG: {os.path.abspath(png)}")
    print(f"   PDF: {os.path.abspath(pdf)}")
    if svg:
        print(f"   SVG: {os.path.abspath(svg)}  (vector format)")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
