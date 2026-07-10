# mt_genome_benchmark
This repository contains reproducible code for a benchmark of most existing tools for animal mitochondrial genome assembly and annotation on the example of Baikal amphipods.

If you:
  * wish to reproduce assembler benchmark or perform a similar analysis using own data, please check out [Procedure 1. Multi-assembler algorithm](https://github.com/drozdovapb/mt_genome_benchmark/tree/main/1_assembly/README.md);
  * would like to skip the detail and just go to the recommended procedure for mitochondrial genome assembly (command-line interface), keep reading. 

## Recommended procedure

We found that the following procedure has maximal efficiency:
<img width="431" height="491" alt="image" src="https://github.com/user-attachments/assets/c80a6c88-0525-45d4-8e6b-612dc1e686fe" />

### Dependencies

This pipeline has been tested in several Linux distributions.

 - (_optional_) `NCBI sratools` (https://github.com/ncbi/sra-tools) for downloading raw reads from NCBI;
 - `BBTools` (https://bbmap.org/) for read manipulation;
 - (_optional_) FastQC (https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) for checking read quality;
 - MitoFinder, which can be installed in two ways:
   - for direct compilation (https://github.com/RemiAllio/MitoFinder); we highly recommend creating a reserved conda environment using python 2.7.
   - or as a Singularity containter (https://github.com/RemiAllio/MitoFinder_container/); requires Singularity.
 - MITObim (https://github.com/chrishah/MITObim).
  

Particular versions used in this work are available in the [full procedure](https://github.com/drozdovapb/mt_genome_benchmark/tree/main/1_assembly/README.md), but in general this procedure should work with any recent version.

### Data

  - Short genome reads the studied organism. 
    - In this demonstration it will be *Ommatogammarus flavus* `DRR911170`, which can be downloaded like this: `fasterq-dump DRR911170`.
  - Assembly of a related mitochondrial genome in .fasta and genbank formats. The reference does not have to be very close. However, the closer the genome, the faster the analysis it will be and the better the chance of assembling a complete genome is. 
    - In this demonstration we use *Eulimnogammarus cyaneus*. The studied species are separated by a phylogenetic distance close to 0.5 substitutions/site and have split up ~15 million years ago based on the analysis of 15 mitochondrial genes. Reference *E. cyaneus* genome (Romanova et al., 2016) is available from NCBI Genbank in [fasta](https://www.ncbi.nlm.nih.gov/nuccore/KX341964.1?report=fasta) and [genbank](https://www.ncbi.nlm.nih.gov/nuccore/KX341964.1?report=genbank) formats. We will save these files as `KX341964_Ecy_mt_genome.fa` and `KX341964_Ecy_mt_genome.gb`, respectively.

### Procedure

> [!IMPORTANT]
> **Execution Guide:**
> Before running the pipeline, it is recommended to copy all the commands into a local text editor. Replace the placeholder paths (/PATH/YOUR/READS_1.fq.gz) and output filenames (NAME_YOUR_READS_1_TRIM.fq.gz) with your actual data. Since the code block includes line breaks, editing it in a text file first is much easier than doing it directly in the terminal.

#### 1. Read preprocessing

  - Download reads using SRA/DRA/ERA accession number if necessary (see above).
  - Perform adapter and quality trimming. The necessity of this step depends on the quality of the reads, which can be checked with FastQC. However, always performing it is a safe and effort-saving strategy. Again, the exact adapter sequences depend on the particular reagents used for preparing the sequencing library, but using the code below will deal with most popular choices.

```
#download adapter sequences
curl -O -# https://raw.githubusercontent.com/BioInfoTools/BBMap/refs/heads/master/resources/adapters.fa
#trim adapters and filter reads by quality:
bbduk.sh -Xmx1G in=/PATH/YOUR/READS_1.fq.gz in2=/PATH/YOUR/READS_2.fq.gz out=NAME_YOUR_READS_1_TRIM.fq.gz out2=NAME_YOUR_READS_2_TRIM.fq.gz \
 ktrim=r k=23 mink=11 hdist=1 ref=adapters.fa
```
#### 2. *De novo* assembly with MitoFinder

  - Filter reads: optional but greatly reduces computational load, so highly recommended if performing the analysis using a personal computer. If RAM usage is not a concern, skip this step and change -1 and -2 arguments in the mitofinder run to the filtered reads above.

```
bbduk.sh in=/PATH/YOUR/NAME_YOUR_READS_1_TRIM.fq.gz in2=/PATH/YOUR/NAME_YOUR_READS_2_TRIM.fq.gz \
 ref=/PATH/YOUR/REFERENCE_SEQ.fa outm=NAME_YOUR_READS_1_TRIM_FILT.fq.gz outm2=NAME_YOUR_READS_2_TRIM_FILT.fq.gz \
 k=17 rcomp=t qhdist=0 -Xmx2g
```
  - Run MitoFinder. If it was installed via a conda environment, first activate it.
 
```
#Run if Mitofinder has been installed in the conda environment. If this is not the case, skip this line.
conda activate mitofinder
#Run MitoFinder
mitofinder -j run_name -1 /PATH/YOUR/NAME_YOUR_READS_1_TRIM_FILT.fq.gz -2 /PATH/YOUR/NAME_YOUR_READS_2_TRIM_FILT.fq.gz -o 5 -r /PATH/YOUR/REFERENCE.gb
```
  - Check the result by inspecting the log file. If the expected number of genes (15 genes for Metazoa) and a circular mitochondrial genome (in case the genome of the studied organism is expected to be circular) were found, this is the finished mitochondrial genome assembly. The annotation results are found in the folder named as `<samplename>_MitoFinder_megahit_mitfi_Final_Results/`.
    - In this case, we will find that MitoFinder found four mitochondrial contigs with 12, 3, 2, and 1 genes (some genes were found twice) and did not find any evidence of circularization.

#### 3. Run additional assembly step with MITObim

  - Preprocess reads: for MITObim, reads need to be interleaved, and this file needs to have the `fastq.gz` extension. Please note that at this stage we need the adapter and quality-trimmed reads **not** filtered to match the reference.

```
bbduk.sh -Xmx1G in=/PATH/YOUR/NAME_YOUR_READS_1_TRIM_FILT.fq.gz in2=/PATH/YOUR/NAME_YOUR_READS_2_TRIM_FILT.fq.gz out=NAME_YOUR_READS_FILT_INTERLEAVED.fastq.gz
```
  - Run MITObim using the largest contig from the MitoFinder assembly (in this case, we will save it to a file `Ofl_mf_largest_mtDNA_contig.fasta`):

```
MITObim.pl -start 1 -end 30 -sample NAME -ref REF_NAME -readpool NAME_YOUR_READS_FILT_INTERLEAVED.fastq.gz --kbait 31 --quick Ofl_mf_largest_mtDNA_contig.fasta
```
   - Tip 1: `MITObim.pl` needs to be in your `$PATH` for this command, or you can provide full path to the script.
   - Tip 2:  MITObim relies on MIRA, which must also be added to your `$PATH`.
   - Tip 3: if you are running a non-English locale and receive an error connected to that, execute the following command: `#if you are running in a non-English locale and 
#export LC_ALL=C`.

  - Annotate the MITObim assembly result with MitoFinder. The final assembly can be found in the `iteration*` folder with the largest number and has the name ending with `noIUPAC.fasta`.
    - Tip: if using MitoFinder in a conda environment, do not forget to activate it again if it was deactivated.
    - Tip: `-o 5` corresponds to the genetic code (in this case, 5 for invertebrate mitochondrial) and depends on the studied taxon. 


```
mitofinder -a iteration15/NAME_it15_noIUPAC.fasta -r /PATH/YOUR/REFERENCE.gb -o 5 -j NAME_YOUR_ANNOTATION
```

  - Inspect the log file and the `<samplename>_MitoFinder_megahit_mitfi_Final_Results/` folder to assess circularization and assembly quality, as well the found genes.
