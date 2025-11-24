#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Использование: $0 <readseq1> <readseq1> <ref> <papka>"
  exit 1
fi

readseq1="$1"
readseq2="$2"
ref="$3"
papka="$4"

mkdir $papka

cd $papka

monitor_PPID2407_2.sh 'MITGARD.py -s '$papka' -1 '$readseq1' -2 '$readseq2' -R '$ref' -M 32G -c 16' ${papka}_use_res_MITGARD.csv
#If you don't want to use monitor_PPID2407_2.sh
#MITGARD.py -s $papka -1 $readseq1 -2 $readseq2 -R $ref -M 32G -c 16

