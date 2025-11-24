# mt_genome_benchmark
This repository contains reproducible code for a small benchmark of all most tools for animal mitochondrial genome assembly and annotation on the example of Baikal amphipods

## Used mitogenome assemblers

In our work, we used the following mitochondrial genome assemblers:

* [MITObim](https://github.com/chrishah/MITObim) (Version 1.9.1)
* [MitoZ](https://github.com/linzhi2013/MitoZ) (Version 3.6)
* [GetOrganelle](https://github.com/Kinggerm/GetOrganelle) (Version 1.7.4.1)
* [mtGrasp](https://github.com/bcgsc/mtGrasp) (Version 1.1.8)
* [Norgal](https://bitbucket.org/kosaidtu/norgal) (Version 1.0.0)
* [MEANGS](http://github.com/YanCCscu/meangs) (Version 1.0)
* [MitoFinder](https://github.com/RemiAllio/MitoFinder_container/) (Version 1.4.1)
* [ARC](https://github.com/ibest/ARC.git) (Version 1.1.4-beta)
* [NOVOPlasty](https://github.com/ndierckx/NOVOPlasty.git) (Version 4.3.5)
* [MITGARD](https://github.com/pedronachtigall/MITGARD) (Version 1.0)

You can access detailed information about the assembler and installation instructions by following the link — just click on the assembler’s name.

## The sequencing and reference data

For testing mitogenome assemblers, we used data from both DNA and RNA sequencing of various amphipod species from Lake Baikal, which are available in GenBank. In addition, we assessed the impact on mitogenome assembly of the number of animals used for nucleic acid extraction (either one animal or several animals) and the level of genome coverage.

### Raw reads:

* _[Eulimnogammarus cyaneus](https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=SRR31211521&display=metadata)_ (One animal, DNAseq)
* _[Eulimnogammarus cyaneus](ссылку)_ (Several animals, DNAseq)!
* _[Eulimnogammarus cyaneus](https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=SRR3467057&display=metadata)_ (One animal, RNAseq)
* _[Eulimnogammarus cyaneus](https://trace.ncbi.nlm.nih.gov/Traces/?view=run_browser&acc=SRR8206017&display=metadata)_ (Several animals, RNAseq)
* _[Eulimnogammarus verrucosus](ссылку)_ (DNAseq)!
* _[Baikalogammarus pullus](ссылку)_ (DNAseq)!

### References:

* _[Eulimnogammarus cyaneus](https://www.ncbi.nlm.nih.gov/nuccore/NC_033360.1)_ (Complete genome)
* _[Eulimnogammarus cyaneus](https://www.ncbi.nlm.nih.gov/nuccore/NC_033360.1?report=fasta&from=1&to=1534)_ (*COI* full gene)
* _[Eulimnogammarus cyaneus](https://www.ncbi.nlm.nih.gov/nuccore/NC_023104.1)_ (*COI* gene, partial cds)
* _[Eulimnogammarus cyaneus](ссылку)_ (*COI* and *CYTB* full genes, for mitobim)!
* _[Eulimnogammarus verrucosus](https://www.ncbi.nlm.nih.gov/nuccore/NC_023104.1)_ (Complete genome)
* _[Baikalogammarus pullus](ссылку)_ (Complete genome)!

### Reduced genome coverage:
Genome coverage was reduced using the [seqtk](https://github.com/lh3/seqtk) tool with the following command:

```
seqtk sample -s 12345 your.fq 0.01 > 1p_your.fq
```
To reduce the coverage, replace „your.fq“ with the name of your fastq file and change the number „0.01“ to the one you need. In this case, 0.01 corresponds to 1 % of the original coverage.

## Developed tools

For simplifying the analysis of assemblers, several small tools were written in Bash:
	
### monitor_PPID2407_2.sh

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

### res_LNS.sh

res_LNS.sh is a tool created to obtain statistical information on terminal mitochondrial genome sequences. This script allows you to search for the necessary files by path pattern and display statistical information about the studied .fasta file: 

* Total length of the sequence. 
* The number of contigs/scaffolds/sequences.
* Parameters COV<small>ref</small> and COV<small>qry</small> or SCORE assemblers from the provided article [Freudenthal, J.A., Pfaff, S., Terhoeven, N. et al.](https://genomebiology.biomedcentral.com/articles/10.1186/s13059-020-02153-6#citeas)
	

**Addition:** res_LNS.sh uses a script from the work mentioned above [evaluate_completeness.sh](https://github.com/chloroExtractorTeam/benchmark/blob/master/code/evaluate_completeness.sh) for calculating COV<small>ref</small> and COV<small>qry</small>. In order to use this script, you will need to install [minimap2](https://github.com/lh3/minimap2) и [bedtools2](https://github.com/arq5x/bedtools2)
	
```
#Example of using res_LNS.sh (General command)
The/path/where/it/is/stored/res_LNS.sh 'pattern/path/to/your/file/*.fasta'
```

### lenght_uniq_seq5.sh

lenght_uniq_seq5.sh is a tool created to analyse the final .fasta file of mitogenome assembly. This script allows for an extensive search for files by pattern, with the ability to specify the search depth, count the number of contigs/scaffolds/sequences, and evaluate the length of each. In the final stage, the script generates a .csv file containing the following information: assembler name, type of data used for mitogenome assembly, reference type, contig number, total number of contigs, contig length.

```
#Example of using lenght_uniq_seq5.sh.
The/path/where/it/is/stored/lenght_uniq_seq4.sh "pattern/*_paths/to/your_*/file/contigs.fasta" "Assembler name" Results_file.csv
```

**Example of .csv file output**

Assembler  | Raw reads  | Reference    | Contig Number | Total Contigs | Contig Lenght|
:--------: | :--------: | :----------: | :-----------: | :-----------: | :----------: |
ARC        | genome     | part_COI_Ecy | 1             | 2             | 7522         |
ARC        | genome     | part_COI_Ecy | 2             | 2             | 5434         |


### cyclescripts.sh

cyclescripts.sh — this tool allows running mitogenome assemblers with various types of input data. The cyclescripts.sh tool works with a universal script for each of the assemblers, in which the main parameters are replaced with variables. The main parameters for the assemblers are collected into a separate configuration file and are passed to cyclescripts.sh along with the universal assembler script. Thus, cyclescripts.sh takes as input a configuration file with a list of parameters and a universal script for the assembler.

```
#Example of using cyclescripts.sh
The/path/where/it/is/stored/cyclescripts.sh The/path/where/it/is/stored/configuration_file.txt The/path/where/it/is/stored/Universal_Assembler's_Script
```

**Configuration file**

A configuration file in .txt format consists of lines of actual arguments that will be passed to the universal assembler script. Therefore, it is closely related to the variables available in the assembler script and is fully dependent on the settings of the universal script. The functionality of cyclescripts.sh allows skipping commented lines (#), thereby providing the opportunity to create one common configuration file and, if necessary, to run repeated assemblies of target datasets by skipping unnecessary ones through line commenting.

```
#Exemple configuration file
#/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/EC_interleaved.fastq /media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Ecya_ref.fa Ecya
/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/EC_interleaved.fastq /media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Eve_ref.fa Eve
#/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/1p_merge.fastq /media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Ecya_ref.fa Ecya_1p
/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/1p_merge.fastq /media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Eve_ref.fa Eve_1p
#/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/10p_merge.fastq /media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Ecya_ref.fa Ecya_10p
```
The presented configuration file was created for the [MITObim](https://github.com/chrishah/MITObim) assembler and contains the following parameters:

* **/media/main/sandbox/ad/mt_BM/reads_mt_BM/DNA/EC_interleaved.fastq** — Path to raw reads.
* **/media/main/sandbox/ad/mt_BM/ref_mt_BM/mt_genom_Ecya_ref.fa** — Path to the reference.
* **Ecya** - The name of the directory that will be created for the output files of the assembler with the given arguments.

This formatting of the configuration file will allow cyclescripts.sh to skip lines 1, 2, 4, 6 and run only the 3rd and 5th sets of arguments.



## Multi-assembler algorithm


### Steps for executing the algorithm

1. Installing assemblers and setting up the workspace.
2. Downloading and setting up additional tools and universal scripts for the assemblers of your choice from this repository.
3. Creating configuration files for the assemblers of your choice.
4. Running cyclescripts.sh.


### 1. Installing assemblers and setting up the workspace
To install the assemblers on your computer, follow the installation instructions on the web pages of the presented assemblers in this repository:

* [MITObim](https://github.com/chrishah/MITObim) (Version 1.9.1)
* [MitoZ](https://github.com/linzhi2013/MitoZ) (Version 3.6)
* [GetOrganelle](https://github.com/Kinggerm/GetOrganelle) (Version 1.7.4.1)
* [mtGrasp](https://github.com/bcgsc/mtGrasp) (Version 1.1.8)
* [Norgal](https://bitbucket.org/kosaidtu/norgal) (Version 1.0.0)
* [MEANGS](http://github.com/YanCCscu/meangs) (Version 1.0)
* [MitoFinder](https://github.com/RemiAllio/MitoFinder_container/) (Version 1.4.1)
* [ARC](https://github.com/ibest/ARC.git) (Version 1.1.4-beta)
* [NOVOPlasty](https://github.com/ndierckx/NOVOPlasty.git) (Version 4.3.5)
* [MITGARD](https://github.com/pedronachtigall/MITGARD) (Version 1.0)

After you have successfully installed the mitogenome assemblers, you need to create a directory (folder) in which you will carry out further work. For example, mt_Assemblers. Next, within this directory, you should create subfolders named after the assemblers you have installed.

Great! The installation and setup step is complete.

- [X] Installing assemblers and setting up the workspace.

### 2. Downloading and configuring additional tools and universal scripts for the assemblers you have chosen from this repository.

1. First, you need to download the additional tools listed above and save them in the mt_Assemblers folder.
	
* [monitor_PPID2407_2.sh](ссылка_на_скрипт_в_репозитории)
* [res_LNS.sh](ссылка_на_скрипт_в_репозитории)
* [lenght_uniq_seq5.sh](ссылка_на_скрипт_в_репозитории)
* [evaluate_completeness.sh](https://github.com/chloroExtractorTeam/benchmark/blob/master/code/evaluate_completeness.sh)
* [cyclescripts.sh](ссылка_на_скрипт_в_репозитории)

**Addition:**: If you want to evaluate the SCORE of your assemblies, you need to install the following as well:

* [minimap2](https://github.com/lh3/minimap2)
* [bedtools2](https://github.com/arq5x/bedtools2)
	
2. You can use additional tools by specifying the full path to the script. However, you can also add the script to the PATH variable and then use only its name to launch it. [Here](https://askubuntu.com/questions/540344/add-custom-script-to-path) is the instruction on how to do it.
3. Next, for each of the assemblers, it is necessary to download the universal launch script from the namesake folders of this repository or from the link below and save it in your folders named after the assemblers.

* [universal_script_MITObim.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MITObim/universal_script_MITObim.sh)
* [universal_script_COI_MITObim.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MITObim/universal_script_COI_MITObim.sh)
* [universal_script_MitoZ.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MitoZ/universal_script_MitoZ.sh)
* [universal_script_GetOrganelle.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/GetOrganelle/universal_script_GetOrganelle.sh)
* [universal_script_mtGrasp.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/mtGrasp/universal_script_mtGrasp.sh)
* [universal_script_Norgal.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/Norgal/universal_script_Norgal.sh)
* [universal_script_MEANGS.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MEANGS/universal_script_MEANGS.sh)
* [universal_script_MitoFinder.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MitoFinder/universal_script_MitoFinder.sh)
* [universal_script_ARC.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/ARC/universal_script_ARC.sh)
* [universal_script_NOVOPlasty.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/NOVOPlasty/universal_script_NOVOPlasty.sh)
* [universal_script_MITGARD.sh](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MITGARD/universal_script_MITGARD.sh)

**Important!** Each universal script uses monitor_PPID2407_2.sh within itself. To avoid issues, you should add this tool to the PATH variable before running the universal assembler scripts.[Link to how to do it.](https://askubuntu.com/questions/540344/add-custom-script-to-path) However, if you do not want to use resource monitoring, you should open the universal script in a text editor and modify the commented lines.

```
#Example of modifying the ARC script
##To use monitor_PPID2407_2.sh
monitor_PPID2407_2.sh '/media/main/sandbox/ad/tool_biuld_mt_genome_links/ARC/bin/ARC -c '$config'' ${papka}_use_res_ARC.csv

#monitor_PPID2407_2.sh для оценки потребления ресурсов сборщиком ARC
/media/main/sandbox/ad/tool_biuld_mt_genome_links/ARC/bin/ARC -c $config

##To AVOID using monitor_PPID2407_2.sh.
#monitor_PPID2407_2.sh '/media/main/sandbox/ad/tool_biuld_mt_genome_links/ARC/bin/ARC -c '$config'' ${papka}_use_res_ARC.csv

monitor_PPID2407_2.sh для оценки потребления ресурсов сборщиком ARC
/media/main/sandbox/ad/tool_biuld_mt_genome_links/ARC/bin/ARC -c $config
```

Great! The step of installing additional tools and downloading universal scripts is completed.

- [x] Downloading and configuring additional tools and universal scripts for the assemblers you have chosen from this repository



## 3. Creating configuration files for the assemblers you have chosen

Configuration files differ for each assembler in the number of arguments, so it is important to take this into account when creating a configuration file. Since the files are individual for each assembler, the simplest way to create such a file with your input data is to download it from the appropriate assembler folder and format it by inserting your data instead of the examples. Sample files and argument descriptions are available in this repository.

**Links to configuration files and parameter descriptions:**

* [Configuration_file_MITObim.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MITObim/Configuration_file_MITObim.txt)
* [Configuration_file_MITObim_COI.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MITObim/Configuration_file_MITObim_COI.txt) 
* [Configuration_file_MitoZ.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MitoZ/Configuration_file_MitoZ.txt) 
* [Configuration_file_GetOrganelle.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/GetOrganelle/Configuration_file_GetOrganelle.txt)
* [Configuration_file_mtGrasp.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/mtGrasp/Configuration_file_mtGrasp.txt)
* [Configuration_file_Norgal.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/Norgal/Configuration_file_Norgal.txt)
* [Configuration_file_MEANGS.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MEANGS/Configuration_file_MEANGS.txt)
* [Configuration_file_MitoFinder.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MitoFinder/Configuration_file_MitoFinder.txt)
* [Configuration_file_ARC.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/ARC/Configuration_file_ARC.txt)
* [Configuration_file_NOVOPlasty.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/NOVOPlasty/Configuration_file_NOVOPlasty.txt)
* [Configuration_file_MITGARD.txt](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/MITGARD/Configuration_file_MITGARD.txt)
* [Description_of_parameters.xlsx](https://github.com/drozdovapb/mt_genome_benchmark/blob/main/1_assembly/Description_of_parameters.xlsx)

Great! The step of creating configuration files is completed.

- [x] Creating configuration files for the assemblers you have chosen

## 4. Running cyclescripts.sh

The cyclescripts.sh script is best run in a separate folder, as it creates logs, and if there are many launch options, there will accordingly be many logs. cyclescripts.sh creates a log of critical errors and a general log of the assembler launch, which will contain information about the assembly process.

The logs that are created will be presented in the following formats:

* errors_2025-10-21_18_27-42.log — A log with launch errors, this is indicated by the «errors» log type, «2025-10-21» is the log creation date in the year-month-day format, «18_27_42» hms is the log creation time in the 24-hour time format.
* script_2025-10-21_18_27-42.log — A log with information about the assembly process, this is indicated by the “script” log type, “2025-10-21” is the log creation date in the year-month-day format, “18_27_42” hms is the log creation time in the 24-hour time format.

**Convenient!** cyclescripts.sh can be added to the PATH variable. [Link to how to do it.](https://askubuntu.com/questions/540344/add-custom-script-to-path)

```
#Example of running cyclescripts.sh (General command)
./cyclescripts.sh The/path/to/your/configuration/file.txt The/path/to/the/universal_assembler_script.sh
```

Great! The step to launch cyclescripts.sh is completed.
- [x] Running cyclescripts.sh


## Conclusion

After all the assemblers you are interested in have assembled mitogenomes or something similar for you, you should evaluate the quality of these assemblies. The tools presented above in this repository will help you with this.
