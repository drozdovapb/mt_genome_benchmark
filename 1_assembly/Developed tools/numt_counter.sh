#!/usr/bin/env bash
# numt_counter.sh

set -u 

usage() {
    echo "Usage: $0 -s SPECIES -b BAM -m MITO_FASTA -1 R1_FASTQ -2 R2_FASTQ -l MIN_COV -u MAX_COV [-d OUTDIR] [-t THREADS] [-L MIN_LEN] [-M MAX_MT_COV]"
    echo "  -s SPECIES          Species name"
    echo "  -b BAM              Sorted and indexed BAM (alignment to mitogenome)"
    echo "  -m MITO_FASTA       Reference mitochondrial genome (FASTA)"
    echo "  -1 R1_FASTQ         Original FASTQ, read 1 (can be .gz)"
    echo "  -2 R2_FASTQ         Original FASTQ, read 2"
    echo "  -l MIN_COV          Minimum contig coverage for NUMT"
    echo "  -u MAX_COV          Maximum contig coverage for NUMT"
    echo "  -d OUTDIR           Output directory (default: numt_results_\${SPECIES})"
    echo "  -t THREADS          Number of threads (default: 4)"
    echo "  -L MIN_LEN          Minimum alignment length (default: 100)"
    echo "  -M MAX_MT_COV       Coverage above which a contig is considered mtDNA (default: 100)"
    echo "  -h                  Show this help"
    exit 1
}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

check_deps() {
    for dep in samtools seqtk spades.py minimap2 bedtools; do
        command -v "$dep" &>/dev/null || { log "Error: $dep is not installed"; exit 1; }
    done
}

# --- Argument parsing ---
SPECIES=""
BAM=""
MITO=""
R1=""
R2=""
MIN_COV=""
MAX_COV=""
OUTDIR=""
THREADS=4
MIN_LEN=100
MAX_MT_COV=100

while getopts "s:b:m:1:2:l:u:d:t:L:M:h" opt; do
    case "$opt" in
        s) SPECIES="$OPTARG" ;;
        b) BAM="$OPTARG" ;;
        m) MITO="$OPTARG" ;;
        1) R1="$OPTARG" ;;
        2) R2="$OPTARG" ;;
        l) MIN_COV="$OPTARG" ;;
        u) MAX_COV="$OPTARG" ;;
        d) OUTDIR="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        L) MIN_LEN="$OPTARG" ;;
        M) MAX_MT_COV="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check mandatory parameters
if [ -z "$SPECIES" ] || [ -z "$BAM" ] || [ -z "$MITO" ] || [ -z "$R1" ] || [ -z "$R2" ] || [ -z "$MIN_COV" ] || [ -z "$MAX_COV" ]; then
    log "Error: not all mandatory parameters are provided."
    usage
fi

if [ ! -f "$BAM" ]; then
    log "Error: BAM file $BAM not found."
    exit 1
fi
if [ ! -f "${BAM}.bai" ]; then
    log "Error: BAM index ${BAM}.bai not found. Run 'samtools index $BAM'"
    exit 1
fi

if [ ! -f "$MITO" ]; then
    log "Error: mitochondrial reference $MITO not found."
    exit 1
fi

if [ ! -f "$R1" ] || [ ! -f "$R2" ]; then
    log "Error: one of the FASTQ files not found: $R1 / $R2"
    exit 1
fi

OUTDIR="${OUTDIR:-numt_results_${SPECIES}}"
mkdir -p "$OUTDIR"
cd "$OUTDIR" || { log "Cannot enter $OUTDIR"; exit 1; }

log "=== Processing species $SPECIES ==="
log "Parameters: MIN_COV=$MIN_COV, MAX_COV=$MAX_COV, MIN_LEN=$MIN_LEN, MAX_MT_COV=$MAX_MT_COV, THREADS=$THREADS"
check_deps

# 1. Collect candidate read names
log "Collecting candidate read names..."
samtools view -f 1 -F 4 -h "$BAM" | samtools view -S - | cut -f1 > anom1.txt
samtools view -f 1 -F 8 -h "$BAM" | samtools view -S - | cut -f1 > anom2.txt
samtools view -q 1 -h "$BAM" | samtools view -q 19 -S - | cut -f1 > lowmq.txt
samtools view -f 0x100 -h "$BAM" | samtools view -S - | cut -f1 > secondary.txt
samtools view -h "$BAM" | grep "SA:" | cut -f1 > chimeric.txt

cat anom1.txt anom2.txt lowmq.txt secondary.txt chimeric.txt 2>/dev/null | sort -u > candidates.txt
NUM_CAND=$(wc -l < candidates.txt)
log "Found $NUM_CAND unique names."
if [ "$NUM_CAND" -eq 0 ]; then
    echo "0" > numt_count.txt
    log "No candidates. Exiting."
    exit 0
fi
rm -f anom1.txt anom2.txt lowmq.txt secondary.txt chimeric.txt

# 2. Extract FASTQ
log "Extracting FASTQ..."
seqtk subseq "$R1" candidates.txt > cand_R1.fastq
seqtk subseq "$R2" candidates.txt > cand_R2.fastq
rm candidates.txt

# 3. Assembly
log "Running SPAdes..."
spades.py -1 cand_R1.fastq -2 cand_R2.fastq -o assembly --only-assembler -t "$THREADS" &> spades.log
if [ ! -f assembly/contigs.fasta ]; then
    log "Error: SPAdes did not produce contigs."
    exit 1
fi

# 4. Align to mitogenome
log "Aligning contigs to mitogenome..."
minimap2 -x asm5 -t "$THREADS" "$MITO" assembly/contigs.fasta > contigs_to_mito.paf

# 5. Extract coverage from contig names
log "Extracting contig coverage..."
grep '^>' assembly/contigs.fasta | sed 's/>//' | awk '{
    if (match($0, /cov_([0-9.]+)/, a)) print $1, a[1]
    else print $1, "NA"
}' > contig_cov.txt

# 6. Add coverage to PAF
awk 'NR==FNR{cov[$1]=$2; next} $1 in cov {print $0, cov[$1]}' contig_cov.txt contigs_to_mito.paf > paf_with_cov.txt

# 7. Filter by coverage and length (numeric comparison!)
log "Filtering: coverage [$MIN_COV..$MAX_COV], length >= $MIN_LEN"
awk -v min="$MIN_COV" -v max="$MAX_COV" -v minlen="$MIN_LEN" '{
    cov = $NF+0
    len = $4-$3
    if (cov >= min && cov <= max && len >= minlen) print $0
}' paf_with_cov.txt > filtered.paf

# 8. Remove contigs representing full mtDNA (coverage > MAX_MT_COV)
log "Removing contigs with coverage > $MAX_MT_COV (likely mtDNA)..."
awk -v max_mt="$MAX_MT_COV" '($NF+0) > max_mt' paf_with_cov.txt | cut -f1 | sort -u > high_cov_contigs.txt
grep -v -f high_cov_contigs.txt filtered.paf > final.paf

# 9. Cluster remaining alignments
log "Clustering alignments..."
if [ -s final.paf ]; then
    awk '{print $6"\t"$8"\t"$9"\t"$1}' final.paf > mito_intervals.bed
    bedtools merge -i mito_intervals.bed -c 4 -o distinct > merged.bed
    NUMT_COUNT=$(wc -l < merged.bed)
else
    NUMT_COUNT=0
    touch merged.bed
fi

echo "$NUMT_COUNT" > numt_count.txt
log "Found NUMT loci: $NUMT_COUNT"
log "Results are in $OUTDIR"
