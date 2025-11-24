#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <depth_embedding> <path_pattern> <constant_argument> <output_csv>"
    echo "Example: $0 3 \"use_getorganel/*/contigs.fasta\" \"Project_X\" results.csv"
    exit 1
fi

maxdepth="$1"
path_pattern="$2"
const_arg="$3"
output_csv="$4"

#A header with two columns of paths
echo "Assembler,Raw_reads,Reference,Contig_Number,Total_Contigs,Contig_Lenght" > "$output_csv"

process_fasta() {
    local file="$1"
    local total_contigs=$(grep -c '^>' "$file" || echo "0")
    local counter=1

    awk '/^>/ {
        if (seqlen) {print seqlen}
        seqlen=0
        next
    }
    {
        seqlen += length($0)
    }
    END {
        if (seqlen) {print seqlen}
    }' "$file" | while read -r length; do
        safe_path=$(printf "%s" "$file" | sed 's/"/""/g')
        #Adding two identical columns
        echo "\"$const_arg\",\"$safe_path\",\"$safe_path\",$counter,$total_contigs,$length" >> "$output_csv"
        ((counter++))
    done
}

# Correctness check maxdepth
if ! [[ "$maxdepth" =~ ^[0-9]+$ ]]; then
    echo "Error: The nesting depth must be a positive integer." >&2
    exit 1
fi

find . -maxdepth "$maxdepth" -type f -path "./$path_pattern" -print0 | while IFS= read -r -d $'\0' file; do
    if [ -f "$file" ]; then
        process_fasta "$file"
    else
        echo "Warning: A non-existent file was missed: $file" >&2
    fi
done

