import sys
import os
import subprocess
import numpy as np
import matplotlib.pyplot as plt
import pysam


def run_command(cmd, step_name):
    print(f"--> Running: {step_name}...")
    try:
        subprocess.run(cmd, check=True, shell=True)
    except subprocess.CalledProcessError as e:
        print(f"Critical error at step '{step_name}': {e}")
        sys.exit(1)


def main(ref_fasta, r1_gz, r2_gz, threads="4", mapq_threshold=20, output_prefix="mt_coverage"):
    bam_output = f"{output_prefix}.sorted.bam"

    # Step 0: Index the reference for bwa (if not indexed yet)
    if not os.path.exists(ref_fasta + ".bwt"):
        run_command(f"bwa index {ref_fasta}", "Indexing reference (bwa index)")
    else:
        print(f"--> bwa index for {ref_fasta} already exists, skipping.")

    # Step 1: Read mapping with filtering
    # -F 0x100 removes secondary alignments (flagged by bwa)
    # -q 20 filters by mapping quality (MAPQ >= 20)
    pipeline_cmd = (
        f"bwa mem -t {threads} {ref_fasta} {r1_gz} {r2_gz} 2> bwa.log | "
        f"samtools view -bS -F 0x100 -q {mapq_threshold} - | "
        f"samtools sort -@ {threads} -o {bam_output} -"
    )
    run_command(pipeline_cmd, "Read alignment (bwa mem) and BAM sorting")

    # Step 2: Index BAM
    run_command(f"samtools index {bam_output}", "Indexing BAM")

    # Step 3: Process BAM and compute coverage across all contigs
    print("--> Computing coverage...")
    bam = pysam.AlignmentFile(bam_output, "rb")
    refs = bam.references
    if not refs:
        print("Error: no sequences found in the reference.")
        return

    total_bases = 0
    total_depth_sum = 0
    total_covered_bases = 0          # for correct percent_covered
    max_coverage_global = 0
    coverage_data = []               # per-position coverage (if single contig)
    coverage_by_ref = {}             # if multiple contigs — store each separately

    for ref_name in refs:
        ref_len = bam.get_reference_length(ref_name)
        if ref_len == 0:
            continue

        coverage = np.zeros(ref_len, dtype=int)
        for pileupcolumn in bam.pileup(ref_name, stepper="all"):
            pos = pileupcolumn.reference_pos
            if 0 <= pos < ref_len:
                coverage[pos] = pileupcolumn.nsegments

        # update global statistics
        total_depth_sum += int(np.sum(coverage))
        total_bases += ref_len
        total_covered_bases += int(np.sum(coverage > 0))
        if coverage.size > 0 and int(np.max(coverage)) > max_coverage_global:
            max_coverage_global = int(np.max(coverage))

        # save coverage
        if len(refs) == 1:
            coverage_data = coverage
        else:
            coverage_by_ref[ref_name] = coverage
            np.savetxt(f"{output_prefix}_{ref_name}.cov", coverage, fmt='%d')
            print(f"Coverage for {ref_name} saved to {output_prefix}_{ref_name}.cov")

    bam.close()

    if total_bases == 0:
        print("Error: total reference length is zero.")
        return

    mean_coverage = total_depth_sum / total_bases
    percent_covered = total_covered_bases / total_bases * 100   # correct calculation

    # Print results
    print("\n" + "=" * 50)
    print(f"MITOCHONDRIAL GENOME COVERAGE ANALYSIS RESULTS")
    print(f"Number of sequences in the reference: {len(refs)}")
    print(f"Total length: {total_bases:,} bp")
    print(f"MEAN DEPTH: {mean_coverage:.2f}x")
    print(f"Maximum coverage: {max_coverage_global}x")
    print(f"Fraction of covered positions (>0x): {percent_covered:.2f}%")
    print("=" * 50 + "\n")

    # Save numeric coverage file (single contig)
    if len(refs) == 1:
        np.savetxt(f"{output_prefix}.cov", coverage_data, fmt='%d')
        print(f"Per-position coverage saved to {output_prefix}.cov")

    # Step 4: Plot (only if a single contig)
    if len(refs) == 1:
        print("--> Generating plot...")
        plt.figure(figsize=(12, 5))
        plt.fill_between(range(len(coverage_data)), coverage_data,
                         color="royalblue", alpha=0.6, label="Read coverage")
        plt.axhline(y=mean_coverage, color="crimson", linestyle="--", linewidth=1.5,
                    label=f"Mean coverage ({mean_coverage:.2f}x)")
        plt.title(f"Coverage distribution of the mitochondrial genome ({refs[0]})",
                  fontsize=14, fontweight='bold')
        plt.xlabel("Genome position (bp)", fontsize=12)
        plt.ylabel("Coverage depth", fontsize=12)
        plt.grid(axis='y', linestyle=':', alpha=0.5)
        plt.legend(loc="upper right", fontsize=10)
        plt.xlim(0, len(coverage_data))
        output_img = f"{output_prefix}.png"
        plt.savefig(output_img, dpi=300, bbox_inches='tight')
        print(f"[Success!] Plot saved to: {os.path.abspath(output_img)}")
    else:
        print("Multiple contigs: no plot generated (separate coverage files saved).")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python run_mt_coverage.py <reference.fasta> <reads_R1.fq.gz> <reads_R2.fq.gz> [threads] [mapq] [output_prefix]")
        print("Example: python run_mt_coverage.py mt_ref.fasta sample_1.fq.gz sample_2.fq.gz 8 20 my_sample")
        sys.exit(1)

    ref = sys.argv[1]
    r1 = sys.argv[2]
    r2 = sys.argv[3]
    threads = sys.argv[4] if len(sys.argv) > 4 else "4"
    mapq = int(sys.argv[5]) if len(sys.argv) > 5 else 20
    prefix = sys.argv[6] if len(sys.argv) > 6 else "mt_coverage"

    main(ref, r1, r2, threads, mapq, prefix)
