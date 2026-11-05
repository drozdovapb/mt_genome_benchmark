## R Scripts for Figure Generation

This directory contains two R scripts used to generate the main and supplementary figures for the manuscript, as well as the enriched metadata tables.

### 🛠 Requirements

You need **R** (v4.0+) and the following packages installed:  
`ggplot2`, `dplyr`, `tidyr`, `hrbrthemes`, `RColorBrewer`, `ggtext`, `ggh4x`, `openxlsx`, `patchwork`, `ggpubr`, `ggeasy`.

Install them via R console:
```R
install.packages(c("ggplot2", "dplyr", "tidyr", "hrbrthemes", "RColorBrewer", "ggtext", "ggh4x", "openxlsx", "patchwork", "ggpubr", "ggeasy"))
```

### 📂 Data Preparation
Before running the scripts, ensure the following raw data files are in your working directory:
* `all_table_nG.csv` — Main assembly benchmark results.
* `H_azt_cov.xlsx` — *H. azteca* coverage data.
* `exp_mtCoverge.xlsx` — Coverage ratio data.
* `all_max_contigs.csv` — Max contig lengths.

---

### 📜 Scripts

#### 1. figure_generation_main.R
Generates Figures 1–3 (and supplementary panels) and processes the main assembly data.

* **What it does:** Cleans and merges the raw tables, calculates derived metrics (e.g., log-transformed lengths, missing flags), and plots the main benchmark results (scatter plots, lollipop charts).
* **Outputs:**
  * **Figures:** `fig01defghi.svg`, `fig02b.svg`, `fig03.svg`, `coverage_ratio_plots_R.svg`, `figS01.png`
  * **Tables:** `all_table_nG_full.xlsx` and `all_table_nG_full_with_max_contig.xlsx`

#### 2. figure_generation_stats.R
Generates Figures 4 and 5, which focus on computational performance (time/memory) and assembly quality statistics (violin plots).

* **What it does:** Reads the enriched table (`all_table_nG_full_with_max_contig.csv`) produced by the first script and plots distributions of memory usage, run time, scores, and gene counts.
* **Outputs:**
  * **Figures:** `fig04.svg`, `fig05ab.svg`, `fig05c.png`
