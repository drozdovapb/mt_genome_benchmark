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

monitor_PPID2407_2.sh 'mitofinder -j mt_genom_'${papka}'_posCont -1 '$readseq1' -2 '$readseq2' -r '$ref' -o 5 -p 8 -m 32' ${papka}_use_res_mitofinder.csv
#If you don't want to use monitor_PPID2407_2.sh
#monitor_PPID2407_2.sh mitofinder -j mt_genom_${papka}_posCont -1 $readseq1 -2 $readseq2 -r $ref -o 5 -p 8 -m 32
