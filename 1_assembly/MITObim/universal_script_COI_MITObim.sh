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

monitor_PPID2407_2.sh 'MITObim.pl -sample '$papka' -ref '$papka' -readpool '$readseq' --quick '$ref' -end 100 &> log' ${papka}_use_res_mitobim.csv
#If you don't want to use monitor_PPID2407_2.sh
#MITObim.pl -sample $papka -ref $papka -readpool $readseq --quick $ref -end 100 &> log
