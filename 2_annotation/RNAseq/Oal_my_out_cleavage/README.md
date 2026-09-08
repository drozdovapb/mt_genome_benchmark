Idea:
https://github.com/gcarbajosa/Mitochondrial_RNA_Cleavage from https://link.springer.com/article/10.1186/s12915-022-01373-5#availability-of-data-and-materials

- starts with trim_galore but I took already trimmed

- the prinseq:

`perl /media/secondary/apps/prinseq-lite-0.20.4/prinseq-lite.pl -fastq Oal_SRR3467085_filt_1.fq -fastq2 Oal_SRR3467085_filt_2.fq -out_good Oal_SRR3467085_prinseq -min_len 20 -trim_tail_left 5 -trim_tail_right 5`

```
 Input and filter stats:
		Input sequences (file 1): 41,324,274
		Input bases (file 1): 4,124,369,741
		Input mean length (file 1): 99.81
		Input sequences (file 2): 41,324,274
		Input bases (file 2): 4,125,620,780
		Input mean length (file 2): 99.84
		Good sequences (pairs): 41,300,237
		Good bases (pairs): 8,248,552,458
		Good mean length (pairs): 199.72
		Good sequences (singletons file 1): 3,811 (0.01%)
		Good bases (singletons file 1): 118,560
		Good mean length (singletons file 1): 31.11
		Good sequences (singletons file 2): 7,433 (0.02%)
		Good bases (singletons file 2): 725,283
		Good mean length (singletons file 2): 97.58
		Bad sequences (file 1): 20,226 (0.05%)
		Bad bases (file 1): 304,227
		Bad mean length (file 1): 15.04
		Bad sequences (file 2): 16,604 (0.04%)
		Bad bases (file 2): 256,519
		Bad mean length (file 2): 15.45
		Sequences filtered by specified parameters:
		trim_tail_left: 62
		min_len: 36768
```

Alignment:

`/media/secondary/apps/STAR-2.7.10b/bin/Linux_x86_64/STAR --runThreadN 8 --runMode genomeGenerate --genomeDir genomeDir/ --genomeFastaFiles Oal_mt_contig.fa --genomeSAindexNbases 6`

    ```
    STAR version: 2.7.10b   compiled: 2022-11-01T09:53:26-04:00 :/home/dobin/data/STAR/STARcode/STAR.master/source
Jun 03 21:21:31 ..... started STAR run
Jun 03 21:21:31 ... starting to generate Genome files
Jun 03 21:21:31 ... starting to sort Suffix Array. This may take a long time...
Jun 03 21:21:31 ... sorting Suffix Array chunks and saving them to disk...
Jun 03 21:21:31 ... loading chunks from disk, packing SA...
Jun 03 21:21:31 ... finished generating suffix array
Jun 03 21:21:31 ... generating Suffix Array index
Jun 03 21:21:31 ... completed Suffix Array index
Jun 03 21:21:31 ... writing Genome to disk ...
Jun 03 21:21:31 ... writing Suffix Array to disk ...
Jun 03 21:21:31 ... writing SAindex to disk
Jun 03 21:21:31 ..... finished successfully
```

`/media/secondary/apps/STAR-2.7.10b/bin/Linux_x86_64/STAR --runThreadN 8 --alignEndsType EndToEnd --outSAMtype BAM SortedByCoordinate --genomeDir genomeDir/ --readFilesIn Oal_SRR3467085_prinseq_1.fastq Oal_SRR3467085_prinseq_2.fastq --outFileNamePrefix Oal_SRR_STAR`

And perl scripts:

`perl Mitochondrial_RNA_Cleavage/get_linear_cleavage_ratio_PE.pl Oal_SRR_STARAligned.sortedByCoord.out.bam my_out_cleavage >my_out_cleavage.log 2>my_out_cleavage.err`

Here it stopped working, should be: 

`perl get_himalaya_ratios.checkCov.pl --ratiosFile=rat_filename --everestOutfile=eve_out_filename --himalayaOutfile=him_out_filename >him_out_filename.log 2>him_out_filename.err`
