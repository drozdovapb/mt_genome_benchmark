#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Использование: $0 <config> <papka>"
  exit 1
fi

config="$1"
papka="$2"

mkdir $papka

cd $papka

monitor_PPID2407_2.sh 'perl NOVOPlasty4.3.5.pl -c '$config'' ${papka}_use_res_Novoplasty.csv
#If you don't want to use monitor_PPID2407_2.sh
#perl NOVOPlasty4.3.5.pl -c $config
