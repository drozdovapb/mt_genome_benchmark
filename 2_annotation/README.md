# Mitochondrial genome annotation

## Trying to predict PolyA by alignment of RNAseq reads

Using the idea published in https://link.springer.com/article/10.1186/s12915-022-01373-5#availability-of-data-and-materials
Code taken from https://github.com/gcarbajosa/Mitochondrial_RNA_Cleavage


```
cat SRA_Acc_List_RNAseq.txt | xargs -I {} fasterq-dump --split-files {}
#stopped_here, still running (all Ecy SRA RNAseq)


## so far try with one file. SRR8205908

cd ~/mt_genomes/Annotation_by_transcriptomes/Ecy/1_try_1sample
trim_galore --quality 0 --stringency 3 --output_dir . --paired ../0_raw_reads/SRR8205908_1.fastq ../0_raw_reads/SRR8205908_2.fastq

	Total reads processed:             38725878
	Reads with adapters:                8357611 (21.6%)

	=== Summary (Read 2) ===

	Total reads processed:             38725878
	Reads with adapters:                7957031 (20.5%)

	=== Paired-end validation ===

	Pairs analyzed:                    38725878
	Pairs removed:                        10318 (0.0%)


perl /media/secondary/apps/prinseq-lite-0.20.4/prinseq-lite.pl -fastq SRR8205908_1_val_1.fq -fastq2 SRR8205908_2_val_2.fq -out_good SRR8205908_prinseq -min_len 20 -trim_tail_left 5 -trim_tail_right 5

# alignment with STAR
/media/secondary/apps/STAR-2.7.10b/bin/Linux_x86_64/STAR --runThreadN 8 --runMode genomeGenerate --genomeDir genomeDir/ --genomeFastaFiles ../ --genomeSAindexNbases 6
/media/secondary/apps/STAR-2.7.10b/bin/Linux_x86_64/STAR --runThreadN 8 --alignEndsType EndToEnd --outSAMtype BAM SortedByCoordinate --genomeDir genomeDir/ --readFilesIn SRR8205908_prinseq_1.fastq SRR8205908_prinseq_2.fastq --outFileNamePrefix Ecy_SRR8205908_STAR

# get ratios
perl ../../Mitochondrial_RNA_Cleavage/get_linear_cleavage_ratio_PE.pl Ecy_SRR8205908_STARAligned.sortedByCoord.out.bam Ecy_SRR8205908.my_out_cleavage >Ecy_SRR8205908_my_out_cleavage.log 2>Ecy_SRR8205908_my_out_cleavage.err


