# Поток: bwa mem -> samtools view (конвертация в BAM) -> samtools sort (сортировка) -> вывод в файл
bwa mem -t 8 -a -M ../../../ref_mt_BM/circular.circular.16284.fasta ../Bpu_D1_trim_filt_1.fq ../Bpu_D1_trim_filt_2.fq 2> bwa.log | samtools view -bS - | samtools sort -@ 4 -T tmp.sort -o aligned.sorted_Bpul.bam -
ls
