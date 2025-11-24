#!/bin/bash

eval "$(conda shell.bash hook)"

conda activate mtgrasp

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

monitor_PPID2407_2.sh 'mtgrasp.py -r1 '$readseq1' -r2 '$readseq2' -o '${papka}'_mtgraps -m 5 -r '$ref' -nsub' ${papka}_use_res_mygraps.csv
#If you don't want to use monitor_PPID2407_2.sh
#mtgrasp.py -r1 $readseq1 -r2 $readseq2 -o ${papka}_mtgraps -m 5 -r $ref -nsub

eval "$(conda shell.bash hook)"

conda deactivate
conda activate

