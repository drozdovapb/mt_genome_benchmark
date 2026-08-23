# Mitochondrial genome annotation

## Annotation workflow

### mt-tRNA annotation with covariance models

To do predictions with covariance models (CMs), we used [Infernal](http://eddylab.org/infernal/) suite. 
Pack of scripts was used to run mitogenome tRNA annotation, published [here](https://github.com/julie-tooi/competitive_mttrna_search)

>Mitogenome is circular, so it is important to elongate genomic fasta with start sequence (for example for 100b), creating an overlap

Otherwise some genomic features can be missed.

**General CM set**

Links to curated sets of mt-tRNAs CMs can be found in [MITOS repository](https://gitlab.com/Bernt/MITOS)
We used set [refseq63m.tar.bz2](https://zenodo.org/records/4284483) available at Zenodo platform.

First step - make an annotation per CM:
```
python mitoannotation.py -i Mitogenome_E_cyaneus_elongated.fasta \
-o /path/to/E_cyaneus_annotation \
-c /path/to/folder/with/cms -t 6
```

And collect data in one report:
```
python collect_annotation_results.py -i /path/to/E_cyaneus_annotation \
-o E_cyaneus_annotation_results.tsv
```

Report can be filtered and annotated with anticodons, file with mitochondrial genetic code can be found [here](https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi)

```
python filter_results.py -i E_cyaneus_annotation_results.tsv \
-o E_cyaneus_annotation_results.tsv \
-f 20 -t /path/to/transl_table5.txt
```

After filtering each locus can me manually inspected. The idea is that for each locus we select a hit with highest score, but sometimes mt-tRNAs can have equal or close high score in different locus (for example, because of duplication events)

**Specific CM set**

Most accurate annotation for mt-tRNAs is possible with clade-specific CM set. It is available for [Amphipods](https://github.com/barnsys/trna_data) 

After downloading, all CMs should be updated to version compatible with Infernal:
```
cmconvert Amphipoda_X.cm > trn_X.cm
```

Then, same workflow as for reference set can be applied:
```
python mitoannotation.py -i Mitogenome_E_cyaneus_elongated.fasta \
-o /path/to/E_cyaneus_annotation \
-c /path/to/folder/with/cms -t 6

python collect_annotation_results.py -i /path/to/E_cyaneus_annotation \
-o E_cyaneus_annotation_results.tsv

python filter_results.py -i E_cyaneus_annotation_results.tsv \
-o E_cyaneus_annotation_results.tsv \
-f 20 -t /path/to/transl_table5.txt
```
With following results inspection.

Specific CM set can be created with tRNA databases, for example [tRNAdb](https://tdb.bioinf.uni-leipzig.de/)

mt-tRNA from specific clade can be retrieved in the form of alignment with sequence and secondary structure. With this information consensus secondary structure can be found and alignment in .sto format can be produced.

Next steps include CM build with Infernal with following calibration:

```
cmbuild trnX.cm trnX_alignment.sto
cmcalibrate trnX.cm
```

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


