bash
#!/bin/bash
# ==============================================================================
# Supplementary Code S1: Identification of putative numts in O. flavus
# Description: Pipeline for cross-mapping analysis and sequence divergence 
#              between the main mitochondrial contig and a short duplicate.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Map raw reads to the combined reference (main + short contigs)
# Tool: BWA-MEM v0.7.12-r1039
# ------------------------------------------------------------------------------
bwa index combined_ref.fasta
bwa mem -t 4 combined_ref.fasta R1.fastq.gz R2.fastq.gz | \
    samtools view -bS -F 0x100 -q 20 - | \
    samtools sort -@ 4 -o combined_sorted.bam -
samtools index combined_sorted.bam

# ------------------------------------------------------------------------------
# 2. Assess sequence divergence between the two contigs
# Tool: BLASTN
# ------------------------------------------------------------------------------
makeblastdb -in contigs.fasta -dbtype nucl -out contigs_db
blastn -query contigs.fasta -db contigs_db \
    -outfmt "6 qseqid sseqid pident length mismatch gaps" -dust no > blast_results.tsv

# ------------------------------------------------------------------------------
# 3. Calculate mean sequencing depth per contig
# Tool: SAMtools v1.9
# ------------------------------------------------------------------------------
samtools depth -a combined_sorted.bam | \
    awk '{sum[$1]+=$3; n[$1]++} END {for (r in sum) printf "%s\t%.1fx\n", r, sum[r]/n[r]}' > mean_depth.txt

# ------------------------------------------------------------------------------
# 4. Calculate mean mapping quality (MAPQ) per contig
# Tool: SAMtools v1.9 + awk
# ------------------------------------------------------------------------------
samtools view combined_sorted.bam | \
    awk '{sum[$3]+=$5; count[$3]++} END {for (r in sum) printf "%s\t%.1f\n", r, sum[r]/count[r]}' > mean_mapq.txt

# ------------------------------------------------------------------------------
# 5. Calculate proportion of soft-clipped reads (CIGAR contains 'S')
# Tool: SAMtools v1.9 + awk
# ------------------------------------------------------------------------------
samtools view combined_sorted.bam | \
    awk '{total[$3]++; if ($6 ~ /S/) soft[$3]++} END {for (r in total) printf "%s\t%d/%d (%.1f%%)\n", r, soft[r], total[r], (soft[r]/total[r])*100}' > soft_clipping.txt
