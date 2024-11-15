#!/bin/bash

# Define input and output directories
input_dir='/volumes/homehpc/storage/finished_projects/UrsaM/comparison_local_HPC/raw_reads_comparison'  # replace with actual path
output_dir='/volumes/homehpc/storage/finished_projects/UrsaM/comparison_local_HPC/usearch_out_HPC'  # replace with actual path
number_threads='8'

# RDP storage (change on local) 
# /volumes/homehpc/storage/DB/RDP/rdp_16s_v18.fa

# Activate the conda environment with USEARCH
eval "$(conda shell.bash hook)"
source activate usearch_env

# Unzip all gzipped files in the input directory
gunzip $input_dir/*.gz

# Rename files by removing _S[0-9]+ patterns in the filenames
rename 's/_S[0-9]+//g' $input_dir/*.fastq

# Clean up old output directory, then create a new one
rm -rf $output_dir
mkdir -p $output_dir
cd $output_dir

# Merge paired reads using a list of sample names stored in samples.list in $input_dir
while read sample; do
    usearch -fastq_mergepairs $input_dir/${sample}*_L001_R1_001.fastq \
            -fastqout $sample.merged.fq \
            -threads $number_threads \
            -fastq_maxdiffs 15 \
            -relabel $sample.
    cat $sample.merged.fq >> merged.fq
done < $input_dir/samples.list

# Strip primers (Fw is 17 nt, Rev is 21 nt)
usearch -fastx_truncate merged.fq -stripleft 17 -stripright 21 -fastqout stripped.fq

# Quality filter
usearch -fastq_filter stripped.fq -fastq_maxee 1.0 -fastaout filtered.fa -relabel Filt -threads $number_threads

# Find unique read sequences and abundances
usearch -fastx_uniques filtered.fa -sizeout -relabel Uniq -fastaout uniques.fa -threads $number_threads

# Denoise: predict biological sequences and filter chimeras
usearch -unoise3 uniques.fa -zotus zotus.fa -relabel Zotu -threads $number_threads

# Make OTU table
usearch -otutab merged.fq -otus zotus.fa -otutabout zotutab_raw.tsv -threads $number_threads

# Predict taxonomy
usearch -sintax zotus.fa -db /volumes/homehpc/storage/DB/RDP/rdp_16s_v18.fa \
        -strand both -tabbedout taxonomy.tsv -sintax_cutoff 0.8 -threads $number_threads



