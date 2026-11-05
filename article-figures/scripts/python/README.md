# Mitochondrial Genome Scripts

This directory contains two Python scripts for mapping, coverage calculation, and visualization of mitochondrial genomes.

## 🛠 Requirements

### System Dependencies
* **bwa** (v0.7.12+)
* **samtools** (v1.9+)

### Python Libraries
Install the required Python packages using `pip`:
```bash
pip install numpy matplotlib pysam biopython
```

---

## 🏎 1. run_mt_coverage.py

Maps paired-end reads to a mitochondrial reference, filters low-quality alignments, and calculates per-base sequencing depth.

### Usage
```bash
python run_mt_coverage.py <reference.fasta> <reads_R1.fq.gz> <reads_R2.fq.gz> [threads] [mapq] [output_prefix]
```

### Defaults
* `threads`: 4
* `mapq`: 20
* `output_prefix`: `mt_coverage`

### Outputs
* `<prefix>.sorted.bam` & `.bai` — Sorted alignments and index file.
* `<prefix>.cov` — Per-position depth data.
* `<prefix>.png` — Coverage plot.

---

## 📊 2. circular_mt_plot.py

Generates a multi-panel figure (circular map, coverage, MAPQ, strand bias, folded coverage, split reads). Reproduces **Supplementary Figure S3**.

### Usage
```bash
python circular_mt_plot.py <bam> <genbank> <output_prefix> [options]
```

### Key Flags
* `--include-trna` — Show tRNAs as green ticks.
* `--standardize-cox1` — Rotate genome to start at *cox1*.
* `--auto-flip` — Fix reverse-complement assemblies.
* `--linear` — Add linear coverage, MAPQ, and strand panels.
* `--simple` — 4-panel view (hides junction markers and split-read panel).
* `--min-cov <int>` — Visual floor for circular coverage (e.g., 10). Linear panels remain unmodified.
* `--bed <file>` — Add missing annotations (e.g., *ATP8*).
* `--svg` — Export vector SVG.

---

## 💡 Examples

### Supplementary Figure S3A (Simple view + BED file)
```bash
python circular_mt_plot.py Avict.sorted.bam A_victorii.gb S3A_Avict \
  --include-trna \
  --standardize-cox1 \
  --auto-flip \
  --linear \
  --simple \
  --bed Avi.bed \
  --min-cov 10 \
  --svg
```

### Supplementary Figure S3D (Full 6-panel view)
```bash
python circular_mt_plot.py Omel.sorted.bam O_melano.gb S3D_Omel \
  --include-trna \
  --standardize-cox1 \
  --auto-flip \
  --linear \
  --min-cov 10 \
  --svg
```
