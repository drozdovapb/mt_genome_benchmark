#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "Использование: $0 <readseq1> <readseq2> <papka>"
  exit 1
fi

readseq1="$1"
readseq2="$2"
papka="$3"

mkdir $papka

cd $papka

monitor_PPID2407_2.sh 'python norgal.py -i '$readseq1' '$readseq2' -o '${papka}'_norgal_output -t 8 --blast' ${papka}_use_res_Norgal.csv
#If you don't want to use monitor_PPID2407_2.sh
#python norgal.py -i $readseq1 $readseq2 -o ${papka}_norgal_output -t 8 --blast
