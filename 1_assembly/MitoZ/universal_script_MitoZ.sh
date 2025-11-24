#!/bin/bash

eval "$(conda shell.bash hook)"

conda activate mitozEnv

if [ "$#" -ne 3 ]; then
  echo "Использование: $0 <readseq1> <readseq2> <papka>"
  exit 1
fi

readseq1="$1"
readseq2="$2"
papka="$3"

mkdir $papka

cd $papka

monitor_PPID2407_2.sh 'mitoz all --outprefix '${papka}'_use_mitoz --clade Arthropoda --requiring_taxa Arthropoda --genetic_code 5 --fq1 '$readseq1' --fq2 '$readseq2' --assembler megahit --skip_filter --memory 32' ${papka}_use_res_mitoz.csv
#If you don't want to use monitor_PPID2407_2.sh
#mitoz all --outprefix ${papka}_use_mitoz --clade Arthropoda --requiring_taxa Arthropoda --genetic_code 5 --fq1 $readseq1 --fq2 $readseq2 --assembler megahit --skip_filter --memory 32

conda deactivate

eval "$(conda shell.bash hook)"

conda activate

