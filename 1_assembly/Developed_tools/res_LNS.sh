#!/bin/bash

#Checking for an argument
if [ "$#" -ne 2 ]; then
  echo "Please specify the file search pattern (for example: *.fasta) and the path to the reference"
  exit 1
fi

#Search for files by pattern
files=($1)

#Reference
ref=$2

#Processing of each file
for file_path in "${files[@]}"; do
  #Checking the existence of a file
  if [ ! -f "$file_path" ]; then
    echo "The $file_path file was not found. Skip it."
    continue
  fi

  #Extracting the directory name
  dir_name=$(dirname "$file_path")

  #Information output
  echo "========================================"
  echo "Файл: $file_path"
  echo "Папка: $dir_name"
  echo "----------------------------------------"

  #awk command for calculating the total length of sequences
  awk_result=$(awk '/^>/ {if (seqlen){print seqlen}; print ;seqlen=0;next; } { seqlen += length($0)}END{print seqlen}' "$file_path" | grep -v ">" | awk '{ sum += $1 } END { print sum}')
  echo "Total length of sequences: $awk_result"

  #The grep command for counting headers
  grep_result=$(grep -c "^>" "$file_path")
  echo "Number of headings (>): $grep_result"

  #awk command for calculating the total length of sequences
  score_result=$(evaluate_completeness.sh $ref "$file_path")
  echo "Score: $score_result"

  echo "========================================"
  echo
done

