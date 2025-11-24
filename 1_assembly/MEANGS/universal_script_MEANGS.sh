#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Использование: $0 <readseq1> <readseq2> <papka> <len_ins>"
  exit 1
fi

readseq1="$1"
readseq2="$2"
papka="$3"
len_ins="$4"

mkdir $papka

cd $papka

monitor_PPID2407_2.sh 'meangs.py -1 '$readseq1' -2 '$readseq2' -o '${papka}'_mt_meangs_quick_base -t 8 -i '$len_ins'' ${papka}_use_res_MEANGS.csv
#If you don't want to use monitor_PPID2407_2.sh
#meangs.py -1 $readseq1 -2 $readseq2 -o ${papka}_mt_meangs_quick_base -t 8 -i $len_ins ${papka}_use_res_MEANGS.csv
