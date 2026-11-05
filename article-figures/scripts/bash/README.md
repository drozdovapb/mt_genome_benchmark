# Supplementary Code S1: Identification of putative numts in *O. flavus*

This Bash script implements a cross-mapping and sequence-divergence pipeline between the main mitochondrial contig and a short duplicate contig, with the aim of identifying putative numts in *O. flavus*.

## 🛠 Requirements

The pipeline requires the following tools:
* **BWA-MEM** v0.7.12-r1039
* **SAMtools** v1.9
* **BLAST+** (`makeblastdb`, `blastn`)

Ensure all tools are available in your `$PATH`.

## 📂 Input Files

Place the following files in the working directory before running the pipeline:
* `combined_ref.fasta` — Combined reference containing the main and short contigs.
* `R1.fastq.gz` — Forward raw reads.
* `R2.fastq.gz` — Reverse raw reads.
* `contigs.fasta` — Contig sequences used for BLASTN comparison.

---

## ⚙ Pipeline Steps

### 1. Map raw reads to the combined reference
Index the combined reference, map reads with BWA-MEM, filter unmapped and low-quality reads, sort, and index the BAM file.

```bash
bwa index combined_ref.fasta
bwa mem -t 4 combined_ref.fasta R1.fastq.gz R2.fastq.gz | \
    samtools view -bS -F 0x100 -q 20 - | \
    samtools sort -@ 4 -o combined_sorted.bam -
samtools index combined_sorted.bam
```

### 2. Assess sequence divergence between the two contigs
Create a BLASTN database from the contigs and perform an all-vs-all BLASTN comparison.

```bash
makeblastdb -in contigs.fasta -dbtype nucl -out contigs_db
blastn -query contigs.fasta -db contigs_db \
    -outfmt "6 qseqid sseqid pident length mismatch gaps" -dust no > blast_results.tsv
```

### 3. Calculate mean sequencing depth per contig
Use `samtools depth` and `awk` to compute the mean coverage for each contig.

```bash
samtools depth -a combined_sorted.bam | \
    awk '{sum[\$1]+=\$3; n[\$1]++} END {for (r in sum) printf "%s\t%.1fx\n", r, sum[r]/n[r]}' > mean_depth.txt
```

### 4. Calculate mean mapping quality (MAPQ) per contig
Use `samtools view` and `awk` to compute the mean MAPQ for each contig.

```bash
samtools view combined_sorted.bam | \
    awk '{sum[\$3]+=\$5; count[\$3]++} END {for (r in sum) printf "%s\t%.1f\n", r, sum[r]/count[r]}' > mean_mapq.txt
```

### 5. Calculate proportion of soft-clipped reads
Count reads whose CIGAR string contains `S` (soft clipping) and report the proportion per contig.

```bash
samtools view combined_sorted.bam | \
    awk '{total[\$3]++; if (\$6 ~ /S/) soft[\$3]++} END {for (r in total) printf "%s\t%d/%d (%.1f%%)\n", r, soft[r], total[r], (soft[r]/total[r])*100}' > soft_clipping.txt
```

---

## 📄 Outputs

The pipeline produces the following files:
* BWA index files for `combined_ref.fasta`
* `combined_sorted.bam` — Sorted BAM file of filtered mapped reads.
* `combined_sorted.bam.bai` — BAM index file.
* BLAST database files for `contigs.fasta` (`contigs_db.*`)
* `blast_results.tsv` — BLASTN results in tabular format.
* `mean_depth.txt` — Mean sequencing depth per contig.
* `mean_mapq.txt` — Mean mapping quality per contig.
* `soft_clipping.txt` — Number and percentage of soft-clipped reads per contig.

