## Supplementary Code S3: Numt Identification

This script reproduces the pipeline for identifying putative nuclear mitochondrial insertions (numts) in *O. flavus*, as described in the Methods section. 

It performs cross-mapping of raw reads to a combined reference (main mitochondrial contig + short duplicate contig), calculates sequence divergence, and extracts mapping statistics.

### 🛠 Requirements

Ensure the following tools are installed and available in your `$PATH`:
* **bwa** (v0.7.12+)
* **samtools** (v1.9+)
* **blast+** (specifically `makeblastdb` and `blastn`)

### 📂 Input Files

Before running the script, place these files in your working directory:
* `combined_ref.fasta` — Contains both the main and short contigs.
* `R1.fastq.gz`, `R2.fastq.gz` — Raw paired-end sequencing reads.
* `contigs.fasta` — The two contigs alone, used for the BLAST alignment.

---

### 🚀 Usage

Run the script directly from the command line:
```bash
bash Supplementary_Code_S1.sh
```

---

### ⚙ Workflow Summary

1. **Mapping:** Aligns reads to the combined reference using `bwa mem` and filters secondary/low-quality alignments using `samtools view -F 0x100 -q 20`.
2. **BLAST:** Assesses sequence divergence between the two contigs using `blastn` to check identity, mismatches, and gaps.
3. **Depth:** Calculates mean coverage per contig using `samtools depth -a`.
4. **MAPQ:** Extracts and averages mapping quality per contig using `samtools view`.
5. **Soft-clipping:** Counts reads with `S` in their CIGAR string to demonstrate alignment competition.

---

### 📄 Output Files

The script generates the following output files:
* `combined_sorted.bam` & `.bai` — Sorted alignments and index file.
* `blast_results.tsv` — Sequence identity, mismatches, and gaps between contigs.
* `mean_depth.txt` — Mean sequencing depth per contig.
* `mean_mapq.txt` — Mean MAPQ per contig.
* `soft_clipping.txt` — Proportion of soft-clipped reads (CIGAR contains 'S') per contig.


