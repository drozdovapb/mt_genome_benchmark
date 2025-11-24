#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Использование: $0 <readseq1> <readseq2> <ref> <papka>"
  exit 1
fi

readseq1="$1"
readseq2="$2"
ref="$3"
papka="$4"

mkdir $papka

cd $papka

monitor_PPID2407_2.sh 'get_organelle_from_reads.py -1 '$readseq1' -2 '$readseq2' -R 10 -F animal_mt -t 16 -s '$ref' -o '${papka}'_rna_getorgan -R 10' ${papka}_use_res_getorganel.csv
#If you don't want to use monitor_PPID2407_2.sh
#/media/main/sandbox/ad/tool_biuld_mt_genome_links/monitor_PPID2407_2.sh get_organelle_from_reads.py -1 $readseq1 -2 $readseq2 -R 10 -F animal_mt -t 16 -s $ref -o ${papka}_rna_getorgan -R 10
