#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Использование: $0 <readseq> <papka>"
  exit 1
fi

config="$1"
papka="$2"

mkdir $papka

cd /$papka

eval "$(conda shell.bash hook)"

conda activate ARC_env

monitor_PPID2407_2.sh '/media/main/sandbox/ad/tool_biuld_mt_genome_links/ARC/bin/ARC -c '$config'' ${papka}_use_res_ARC.csv
#If you don't want to use monitor_PPID2407_2.sh
#/media/main/sandbox/ad/tool_biuld_mt_genome_links/ARC/bin/ARC -c $config

conda deactivate

eval "$(conda shell.bash hook)"

conda activate
