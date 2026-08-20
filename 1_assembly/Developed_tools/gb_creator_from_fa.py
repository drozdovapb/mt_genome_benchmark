#!/usr/bin/env python3
"""
Script for converting FASTA to GenBank for MitoFinder.
"""

import argparse
from datetime import datetime
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord
from Bio.SeqFeature import SeqFeature, FeatureLocation

def convert_fasta_to_annotated_gb(fasta_path, gb_path, organism, gene_name, transl_table="5", seq_index=0):
    # 1. Read the FASTA file
    records = list(SeqIO.parse(fasta_path, "fasta"))
    if not records:
        raise ValueError(f"No sequences found in file {fasta_path}.")

    if seq_index >= len(records):
        raise IndexError(f"Index {seq_index} is out of range (total sequences: {len(records)}).")

    # Select the desired sequence
    source_record = records[seq_index]
    seq_str = str(source_record.seq).strip()
    seq_len = len(seq_str)

    # Automatically generate the locus name based on the gene name
    locus_name = f"Ref_{gene_name}"
    # Format the current date according to the GenBank standard (e.g., 19-AUG-2026)
    current_date = datetime.now().strftime("%d-%b-%Y").upper()

    # 2. Create a basic GenBank record
    new_record = SeqRecord(
        Seq(seq_str),
        id=locus_name,
        name=locus_name[:16],  # enBank locus name length limit
        description=f"Reference {gene_name} sequence for MitoFinder",
        annotations={
            "molecule_type": "DNA",
            "topology": "linear",
            "data_file_division": "ORG",  # ORG (organelle) — best choice for mitochondria
            "date": current_date,         
            "accessions": [locus_name],         
            "sequence_version": 1,         
            "organism": organism,
            "source": organism,
        }
    )

    features = []

    # 3. SOURCE feature (mandatory for GenBank structure)
    source_feature = SeqFeature(
        FeatureLocation(0, seq_len),
        type="source",
        qualifiers={
            "organism": [organism],
            "mol_type": ["genomic DNA"],
        }
    )
    features.append(source_feature)

    # 4. GENE feature (so MitoFinder knows what this gene is)
    gene_feature = SeqFeature(
        FeatureLocation(0, seq_len),
        type="gene",
        qualifiers={
            "gene": [gene_name]
        }
    )
    features.append(gene_feature)

    # 5. CDS feature (coding sequence, critical for MitoFinder)
    cds_feature = SeqFeature(
        FeatureLocation(0, seq_len),
        type="CDS",
        qualifiers={
            "gene": [gene_name],
            "codon_start": ["1"],
            "transl_table": [str(transl_table)]
        }
    )
    features.append(cds_feature)

    new_record.features = features

    # 6. Safely write to file
    with open(gb_path, "w") as output_handle:
        SeqIO.write(new_record, output_handle, "genbank")
        
    print(f"Conversion completed successfully!")
    print(f"Output file: {gb_path}")
    print(f"Sequence length: {seq_len} bp")
    print(f"Annotated gene: {gene_name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FASTA to annotated GenBank converter for MitoFinder")
    parser.add_argument("-i", "--input", required=True, help="Input FASTA file")
    parser.add_argument("-o", "--output", required=True, help="Output GenBank file (.gb)")
    parser.add_argument("--organism", default="Eulimnogammarus cyaneus", help="Organism name")
    parser.add_argument("--gene", default="COI", help="Gene name (e.g., COX1, ND1, CYTB)")
    parser.add_argument("-t", "--table", default="5", help="Table number of genetic code")
    parser.add_argument("--seq_id", type=int, default=0, help="Sequence index in FASTA (if there are multiple)")

    args = parser.parse_args()
    
    convert_fasta_to_annotated_gb(args.input, args.output, args.organism, args.gene, args.table, args.seq_id)
