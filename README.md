# mt_genome_benchmark
This repository contains reproducible code for a benchmark of most existing tools for animal mitochondrial genome assembly and annotation on the example of Baikal amphipods.

If you:
  * wish to reproduce this analysis, please keep reading;
  * wish to perform a similar analysis using own data, please check out [Procedure 1. Multi-assembler algorith](https://github.com/drozdovapb/mt_genome_benchmark#multi-assembler-algorithm);
  * would like to skip the detail and just go to the recommended procedure for mitochondrial genome assembly, click here: [Procedure 2. Recommended procedure](https://github.com/drozdovapb/mt_genome_benchmark#recommended-procedure).

## Table of contents:
  * [Dependencies](https://github.com/drozdovapb/mt_genome_benchmark#dependencies)
  * [Data](https://github.com/drozdovapb/mt_genome_benchmark#the-sequencing-and-reference-data)
  * [Developed scripts](https://github.com/drozdovapb/mt_genome_benchmark#developed-scripts)
  * [Procedure 1. Assembler benchmark](https://github.com/drozdovapb/mt_genome_benchmark#multi-assembler-algorithm)
  * [Procedure 2. Recommended procedure](https://github.com/drozdovapb/mt_genome_benchmark#recommended-procedure)

## Dependencies

In this work, we used the following mitochondrial genome assemblers (whether you need all or some of them depends on your goals):

* [MITObim](https://github.com/chrishah/MITObim) (Version 1.9.1) - You need to add the executable file to the PATH variable
* [MitoZ](https://github.com/linzhi2013/MitoZ) (Version 3.6) - For this assembler, you need to create a conda environment named "mitozEnv"
* [GetOrganelle](https://github.com/Kinggerm/GetOrganelle) (Version 1.7.4.1) - You need to add the executable file to the PATH variable
* [mtGrasp](https://github.com/bcgsc/mtGrasp) (Version 1.1.8) - For this assembler, you need to create a conda environment named "mtgrasp"
* [Norgal](https://bitbucket.org/kosaidtu/norgal) (Version 1.0.0) - You need to add the executable file to the PATH variable.
* [MEANGS](http://github.com/YanCCscu/meangs) (Version 1.0) - You need to add the executable file to the PATH variable
* [MitoFinder](https://github.com/RemiAllio/MitoFinder_container/) (Version 1.4.1) - You need to add the executable file to the PATH variable
* [ARC](https://github.com/ibest/ARC.git) (Version 1.1.4-beta) - For this assembler, you need to create a conda environment named "ARS_python_2.7"
* [NOVOPlasty](https://github.com/ndierckx/NOVOPlasty.git) (Version 4.3.5) - You need to add the executable file to the PATH variable
* [MITGARD](https://github.com/pedronachtigall/MITGARD) (Version 1.0) - You need to add the executable file to the PATH variable

[Link to how to do it (PATH).](https://askubuntu.com/questions/540344/add-custom-script-to-path)


You can access detailed information about the assembler and installation instructions by following the link—just click on the assembler name. Please note that we did not develop any of those and are not responsible for their maintenance, but we did run all of them and might be able to help with installation and running issues—please [open an issue]([url](https://github.com/drozdovapb/mt_genome_benchmark/issues)) if you need help. In addition, all the credit goes to the authors, so please do not forget to cite corresponding papers if you use any of those.

The following tools were used to evaluate the SCORE of the obtained assemblies:

* [minimap2](https://github.com/lh3/minimap2)
* [bedtools2](https://github.com/arq5x/bedtools2)

## The sequencing and reference data

For testing mitogenome assemblers, we used data from both DNA and RNA sequencing of various amphipod species from Lake Baikal, which are available in NCBI GenBank/DDBJ/ENA. In addition, we assessed the impact on mitogenome assembly of the number of animals used for nucleic acid extraction (either one animal or several animals) and the level of genome coverage.

### Raw reads:

DNA sequencing (DBNseq):
* _[Eulimnogammarus cyaneus](https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=DRR911160&display=metadata)_ (Several animals, DNAseq)!
* _[Eulimnogammarus verrucosus S](https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=DRR911165&display=metadata)_ (DNAseq)!
* _[Baikalogammarus pullus](https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=DRR911159&display=metadata)_ (DNAseq)!
RNA sequencing:
* _[Eulimnogammarus cyaneus](https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=SRR8206017&display=metadata)_ (Several animals, RNAseq)


### References:

* _[Eulimnogammarus cyaneus](https://www.ncbi.nlm.nih.gov/nuccore/NC_033360.1)_ (Complete genome)
* _[Eulimnogammarus cyaneus](https://www.ncbi.nlm.nih.gov/nuccore/NC_033360.1?report=fasta&from=1&to=1534)_ (*COI* full gene)
* _[Eulimnogammarus cyaneus](https://www.ncbi.nlm.nih.gov/nuccore/NC_023104.1)_ (*COI* gene, partial cds)
* _[Eulimnogammarus cyaneus](ссылку)_ (*COI* and *CYTB* full genes, for mitobim)!
* _[Eulimnogammarus verrucosus](https://www.ncbi.nlm.nih.gov/nuccore/NC_023104.1)_ (Complete genome)
* _[Eulimnogammarus verrucosus](ссылку_наши)_ (*COI* full gene)
* _[Eulimnogammarus verrucosus](ссылку_наши)_ (*COI* gene, partial cds)
* _[Baikalogammarus pullus](ссылку_наши)_ (Complete genome)!
* _[Baikalogammarus pullus](ссылку_наши)_ (*COI* full gene)
* _[Baikalogammarus pullus](ссылку_наши)_ (COI* gene, partial cds)

### Reduced genome coverage:
Genome coverage was reduced using the [seqtk](https://github.com/lh3/seqtk) tool with the following command:

```
seqtk sample -s 12345 your.fq 0.01 > 1p_your.fq
```
To reduce the coverage, replace „your.fq“ with the name of your fastq file and change the number „0.01“ to the one you need. In this case, 0.01 corresponds to 1 % of the original coverage.

### Trim and filter reads

```
java -jar trimmomatic-0.39.jar PE -phred33 Sample_1.fq.gz Sample_2.fq.gz Sample_pairedPE_1.fq Sample_upaired_1.fq Sample_pairedPE_2.fq Sample_upaired_2.fq  ILLUMINACLIP:Seq_adapters.fasta:2:7:1
```
## Repository content

### Developed scripts

Each assembler has a slightly different output format. For simplifying the analysis of assemblers, several small tools were written in Bash:
	
#### monitor_PPID2407_2.sh

monitor_PPID2407_2.sh is a tool created to monitor the computer resources used by any running command. Every second, it records the consumed resources and additional parameters (Time, PID, PPID, Username, %CPU, %MEM, RSS, VSZ, Command) and outputs them to a .csv file.

```
#Example of using monitor_PPID2407_2.sh (General command)
The/path/where/it/is/stored/monitor_PPID2407_2.sh 'Your command with all the arguments' out.csv
```

**Example of .csv file output with used resources**

timestamp          | pid    | ppid   | user    | %cpu | %mem| rss_mb| vsz_mb | command|
:-----------------:| :----: | :-----:| :-----: | :--: | :-: | :---: | :----: | :----: |
2025-10-06 20:01:27| 3717589| 3717588| username| 0.0  | 0.0 | 9.59  | 16.58  | python |
2025-10-06 20:01:28| 3717589| 3717588| username| 104.0| 0.0 | 21.50 | 31.58  | python |

#### res_LNS.sh

res_LNS.sh is a tool created to obtain statistical information on terminal mitochondrial genome sequences. This script allows you to search for the necessary files by path pattern and display statistical information about the studied .fasta file: 

* Total length of the sequence. 
* The number of contigs/scaffolds/sequences.
* Parameters COV<small>ref</small> and COV<small>qry</small> or SCORE assemblers from the provided article [Freudenthal, J.A., Pfaff, S., Terhoeven, N. et al.](https://genomebiology.biomedcentral.com/articles/10.1186/s13059-020-02153-6#citeas)
	

**Addition:** res_LNS.sh uses a script from the work mentioned above [evaluate_completeness.sh](https://github.com/chloroExtractorTeam/benchmark/blob/master/code/evaluate_completeness.sh) for calculating COV<small>ref</small> and COV<small>qry</small>. In order to use this script, you will need to install [minimap2](https://github.com/lh3/minimap2) и [bedtools2](https://github.com/arq5x/bedtools2)
	
```
#Example of using res_LNS.sh (General command)
The/path/where/it/is/stored/res_LNS.sh 'pattern/path/to/your/file/*.fasta'
```

#### length_uniq_seq5.sh

length_uniq_seq5.sh is a tool created to analyse the final .fasta file of mitogenome assembly. This script allows for an extensive search for files by pattern, with the ability to specify the search depth, count the number of contigs/scaffolds/sequences, and evaluate the length of each. In the final stage, the script generates a .csv file containing the following information: assembler name, type of data used for mitogenome assembly, reference type, contig number, total number of contigs, contig length.

```
#Example of using lenght_uniq_seq5.sh.
The/path/where/it/is/stored/lenght_uniq_seq4.sh "pattern/*_paths/to/your_*/file/contigs.fasta" "Assembler name" Results_file.csv
```

**Example of .csv file output**

Assembler  | Raw reads  | Reference    | Contig Number | Total Contigs | Contig Lenght|
:--------: | :--------: | :----------: | :-----------: | :-----------: | :----------: |
ARC        | genome     | part_COI_Ecy | 1             | 2             | 7522         |
ARC        | genome     | part_COI_Ecy | 2             | 2             | 5434         |


#### cyclescripts.sh

cyclescripts.sh — this tool allows running mitogenome assemblers with various types of input data. The cyclescripts.sh tool works with a universal script for each of the assemblers, in which the main parameters are replaced with variables. The main parameters for the assemblers are collected into a separate configuration file and are passed to cyclescripts.sh along with the universal assembler script. Thus, cyclescripts.sh takes as input a configuration file with a list of parameters and a universal script for the assembler.

```
#Example of using cyclescripts.sh
The/path/where/it/is/stored/cyclescripts_4.sh The/path/where/it/is/stored/configuration_file.txt The/path/where/it/is/stored/Universal_Assembler's_Script Assembler_name
#If you run cyclescripts.sh without arguments, it will show you a usage example. After launching, you will see: 
Usage: ./cyclescripts_4.sh <config_file> <universal_script> <assembler_name>
assembler_name: ARC, GetOrganelle, MEANGS, MITGARD, MITObim, MitoFinder, MitoZ, NOVOPlasty, Norgal, mtGrasp
```

## Before you begin: test your setup

To evaluate the correct functioning of the tools we have developed, we recommend running a mitochondrial genome assembly on the test data provided in the simulation_data folder.

1. First, you need to create a directory for subsequent work.
	
	Linux command to create a directory:

	```
	mkdir name_your_dir
	```
2. Next, you need to download our repository. This can be done either via a browser or through the terminal.

	Terminal command:
	```
	git clone https://github.com/drozdovapb/mt_genome_benchmark.git
	```

3. Then, navigate into the repository folder, which is named after the repository itself: mt_genome_benchmark. Inside this folder, you will find two subdirectories — 1_assembly and 2_annotation — as well as a README.md file. You need to move into the 1_assembly directory.  
4. Once inside 1_assembly, you must make all the working tools (scripts) executable.

	Linux command:
	```
	chmod +x */*.sh
	```
5. After executing this command, navigate into the Developed_tools directory.
6. In this directory, you will find the executable script run_simulation_data.sh, which you need to run.

	Command to run run_simulation_data.sh:
	```
	./run_simulation_data.sh
	```

7. The simulation takes approximately 5–10 minutes to complete.
8. Once finished, you should find the output files in the respective assembler folders:  
	**ARC**   
	**GetOrganelle**   
	**MITObim**
9. Within each of these folders, you should see three subdirectories indicating the reference used:  
**Bpul** - complete mitogenome reference of *B. pullus*  
**Bpul_COI** - Folmer COI fragment reference of COI *B. pullus*  
**Bpul_Eve** - complete mitogenome reference of the closely related species *E. verrucosus*

These folders contain the results produced by the assemblers used in the test simulation.

## Multi-assembler algorithm

This step-by-step guide describes the generalized benchmarking procedure.

After you have tested your setup in the step titled "Before you begin: test your setup", you already have the downloaded repository and can perform a multiple assembly similar to the one we did. For this you will need:

1. Your sequencing data (raw reads)
2. Reference sequences for those assemblers that require them

### Configuration files and universal scripts

In order to run the Multi-assembler algorithm, you first need to set up the configuration files for each assembler. Example configuration files for each assembler are provided in the correspondingly named folders. You simply need to replace the required fields with those matching your data.

~~~
Example: Modifying the configuration file for the GetOrganelle assembler
The configuration file provided in the repository looks as follows:

#read1=/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/Ecy_D1_trim_filt_1.fq read2=/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/Ecy_D1_trim_filt_2.fq ref=/media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Ecya_ref.fa name=Ecya
#read1=/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/Ecy_D1_trim_filt_1.fq read2=/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/Ecy_D1_trim_filt_2.fq ref=/media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Eve_ref.fa name=Eve

As you can see, it contains four key arguments — read1, read2, ref, name

To make this file functional, you need to specify the full paths to your sequencing data (read1 and read2), the full path to your reference sequence, and a working name for the directory where the results will be saved.
~~~
Thus, you need to modify the configuration files for all assemblers.

~~~
Explanation of mandatory argument keys that may appear in configuration files:

read1 — Path to forward reads;
read2 — Path to reverse reads;
config — Path to the configuration file required by the assembler itself (not to be confused with the configuration file for the Multi-assembler algorithm presented in this work);
name — Name of the directory that will be created during the assembly process and where the results will be saved;
len_ins — Insert length;
ref — Path to the reference sequence;
clade — Group of organisms corresponding to the taxonomy of your species (usually restricted and fixed in the assembler's manual);
genetic_code — Genetic code type (usually restricted and fixed in the assembler's manual);

Explanation of available options that can be used when creating configuration files or using universal assembler scripts: 

threads — Number of threads used for the assembly (default: 4);
memory — Amount of RAM used during the assembly (default: 4);
mode — Assembly mode (if available in the universal script, refer to the assembler's manual);
kbait — k-mer size;
start — Iteration start;
end — Iteration end;
assembler — Assembler type;
organism — Genetic code type (usually restricted and fixed in the assembler's manual);
processors — Number of threads used for the assembly (default: 4);
skip_filter — Skip the filtering step (if the data have already been filtered);

Available options for each assembler can be viewed by running the universal script without any arguments.

~~~

### Running cyclescripts.sh

After you have adapted the configuration files to your data, you need to navigate to the repository folder named Developed_tools. In this folder, you will find cyclescripts.sh, which will allow you to start the multiple assembly process.

~~~
#Example of running cyclescripts.sh (General command)
./cyclescripts.sh path/to/your/configuration/file.txt path/to/the/universal_assembler_script.sh Assembler_name
~~~

cyclescripts.sh will create a logs directory where critical error logs and a general assembler run log will be written; the run log will contain information about the assembly process.

Results for each assembler will be saved into the correspondingly named folders.

The logs that are created will be presented in the following formats:

* errors_Assembler_name2025-10-21_18_27-42.log — A log with launch errors, this is indicated by the «errors» log type, «2025-10-21» is the log creation date in the year-month-day format, «18_27_42» hms is the log creation time in the 24-hour time format.
* script_Assembler_name2025-10-21_18_27-42.log — A log with information about the assembly process, this is indicated by the “script” log type, “2025-10-21” is the log creation date in the year-month-day format, “18_27_42” hms is the log creation time in the 24-hour time format.

**Convenient!** cyclescripts.sh can be added to the PATH variable. [Link to how to do it.](https://askubuntu.com/questions/540344/add-custom-script-to-path)

```
#Example of running cyclescripts.sh (General command)
./cyclescripts.sh path/to/your/configuration/file.txt path/to/the/universal_assembler_script.sh Assembler_name
```

Great! The step to launch cyclescripts.sh is completed.
- [x] Running cyclescripts.sh


### Conclusion

After all the assemblers you are interested in have assembled mitogenomes or something similar for you, you should evaluate the quality of these assemblies. The tools presented above in this repository will help you with this.

## Recommended procedure

We found that the following procedure has maximal efficiency:
<img width="431" height="491" alt="image" src="https://github.com/user-attachments/assets/c80a6c88-0525-45d4-8e6b-612dc1e686fe" />

Let's try with _Gammarus lacustris_—it's a well-studied species (species complex but still), and there is a reference mitochondrial genome available.
## todo try with Gla by the Gla reference!! redo!!

```
(base) drozdovapb@server:~/mt_genomes/mt_genome_benchmark$ ./1_assembly/Developed_tools/cyclescripts.sh ./1_assembly/MITObim/Configuration_file_MITObim.txt ./1_assembly/MITObim/universal_script_MITObim.sh  MITObim

#stopped_here now for G. lacustris


./1_assembly/Developed_tools/cyclescripts.sh ./1_assembly/MitoFinder/Configuration_file_MitoFinder.txt ./1_assembly/MitoFinder/universal_script_MitoFinder.sh MitoFinder


./1_assembly/Developed_tools/cyclescripts.sh ./1_assembly/MITObim/Configuration_file_MITObim.txt ./1_assembly/MitoFinder/universal_script_MitoFinder.sh MitoFinder


reads=/media/main/sandbox/drozdovapb/mt_genomes/test_Gla/Gla_D2_filt_interleaved.fastq.gz ref=/media/main/sandbox/drozdovapb/mt_genomes/mt_genome_benchmark/1_assembly/MitoFinder/Gla/mt_genom_Gla_posCont/mt_genom_Gla_posCont_MitoFinder_megahit_mitfi_Final_Results/mt_genom_Gla_posCont_mtDNA_contig.fasta name=Gla_D2_2


./1_assembly/Developed_tools/cyclescripts.sh ./1_assembly/MITObim/Configuration_file_MITObim.txt ./1_assembly/MITObim/universal_script_MITObim.sh  MITObim

reads=/media/main/sandbox/drozdovapb/mt_genomes/mt_genome_benchmark/Gla/Gla_D2_filt_interleaved.fastq.gz ref=/media/main/sandbox/drozdovapb/mt_genomes/mt_genome_benchmark/1_assembly/MitoFinder/Gla/mt_genom_Gla_posCont/mt_genom_Gla_posCont_MitoFinder_megahit_mitfi_Final_Results/mt_genom_Gla_posCont_mtDNA_contig.fasta name=Gla_D2_2
```

And now let's try with _Gammarus dabanus_, a very poorly studied species with almost no available data.
We will use _E. cyaneus_ as a reference.

first MitoFinder
``` 
  601  ./1_assembly/Developed_tools/cyclescripts.sh ./1_assembly/MitoFinder/Configuration_file_MitoFinder.txt ./1_assembly/MitoFinder/universal_script_MitoFinder.sh MitoFinder
  602  ls /media/main/genome/DNBSeq2023_proj617/result/SSP_617_WGS_Gda-D2/SSP_617_WGS_Gda-D2_trim_filt_1.fq.gz
  603  ls /media/main/genome/DNBSeq2023_proj617/result/SSP_617_WGS_Gda-D2/SSP_617_WGS_Gda-D2_trim_filt_2.fq.gz
  604  ls /media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Ecya_ref.gb
  605  ls
  606  cat errors_2026-05-07_12-55-37.log 
  607  ./1_assembly/Developed_tools/cyclescripts.sh ./1_assembly/MitoFinder/Configuration_file_MitoFinder.txt ./1_assembly/MitoFinder/universal_script_MitoFinder.sh MitoFinder
  608  nano 1_assembly/MitoFinder/Configuration_file_MitoFinder.txt 
  609  ./1_assembly/Developed_tools/cyclescripts.sh ./1_assembly/MitoFinder/Configuration_file_MitoFinder.txt ./1_assembly/MitoFinder/universal_script_MitoFinder.sh MitoFinder
  610  history | tail -10
```

Result:
```
2 genes were found in mtDNA_contig_1
14 genes were found in mtDNA_contig_2
1 gene was found in mtDNA_contig_3
2 genes were found in mtDNA_contig_4
1 gene was found in mtDNA_contig_5
```

Not bad but far from ideal. Let's proceed with MITObim.

```
export read1=/media/main/genome/DNBSeq2023_proj617/result/SSP_617_WGS_Gda-D2/SSP_617_WGS_Gda-D2_trim_filt_1.fq.gz
export read2=/media/main/genome/DNBSeq2023_proj617/result/SSP_617_WGS_Gda-D2/SSP_617_WGS_Gda-D2_trim_filt_2.fq.gz
bbduk.sh -Xmx1G in=$read1 in2=$read2 out=Gda_D2_filt_interleaved.fastq.gz  # important! fq is illegal, should be fastq!
```

```
reads=/media/main/sandbox/drozdovapb/mt_genomes/test_Gda/Gda_D2_filt_interleaved.fastq.gz ref=./1_assembly/MitoFinder/Gda/mt_genom_Gda_posCont/mt_genom_Gda_posCont_MitoFinder_megahit_mitfi_Final_Results/mt_genom_Gda_posCont_mtDNA_contig_2.fasta name=Gda_D2_2
```

## TODO test result

