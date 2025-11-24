#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "Использование: $0 <readseq> <ref> <papka>"
  exit 1
fi

readseq="$1"
ref="$2"
papka="$3"

mkdir $papka

cd $papka

monitor_PPID2407_2.sh 'MITObim.pl -start 1 -end 30 -sample '$papka' -ref '$papka' -readpool '$readseq' --quick '$ref' &> log' ${papka}_1p_use_res_mitobim.csv
#If you don't want to use monitor_PPID2407_2.sh
#MITObim.pl -start 1 -end 30 -sample $papka -ref $papka -readpool $readseq --quick $ref &> log
