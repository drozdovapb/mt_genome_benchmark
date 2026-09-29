library(gggenes)
library(GenomicRanges)
library(ggplot2)
library(readr)
library(dplyr)
library(RColorBrewer)

# read bed annotation (in 2_annotation folder)
path_to_bed <- "../2_annotation/annotation.bed"

bed <- read_tsv(
  path_to_bed,
  col_names = FALSE
)

# rename colnames
colnames(bed)[1:6] <-
  c("chrom", "start", "end", "gene", "score", "strand")
# prepare data for labeling
bed$type <- ifelse(
  grepl("^trn", bed$gene),
  "tRNA",
  "other"
)

prots_and_rrn  <- filter(bed, type == "other")
trna <- filter(bed, type == "tRNA")

# label tRNAs with short names
trna$label <- sub("^trn([A-Za-z]).*", "\\1", trna$gene)

# add more colors to palette
more <- colorRampPalette(brewer.pal(12, "Paired"))(17)
# organize data structure for plot
prots_and_rrn <- prots_and_rrn %>%
  filter(!chrom %in% c("GeSeq_drosophila",
                       "AGORA_Drosophila")) %>%
  mutate(chrom = factor(
    chrom,
    levels = c("MFannot",
               "AGORA_Gammarus",
               "AGORA_Ecy", 
               "General_CM",
               "Amphipoda_CM",
               "GeSeq_Ecy",
               "GeSeq_gammarus",
               "MITOS2_refseq89m",
               "MITOS2_refseq63m",
               "MitoZ",
               "Mitofinder_Gpi",
               "Mitofinder",
               "RefSeq"
    )
  ))

ggplot(data = prots_and_rrn,
                    aes(
                      xmin = start,
                      xmax = end,
                      y = chrom,
                      fill = gene,
                      forward = strand == "+"
                    )) +
  geom_gene_arrow() +
  geom_feature(
    data = trna,
    aes(x = start, 
        y = chrom, 
        forward = strand == "+")
  ) +
  geom_feature_label(
    data = trna,
    aes(x = start, 
        y = chrom, 
        label = label, 
        forward = strand == "+")
  ) +
  scale_fill_manual(values = more) +
  labs(x = "Genomic position", y = NULL) +
  theme_genes() + 
  theme(legend.position = "bottom", text = element_text(size=14))

ggsave("Fig5_annotation.svg", device=svg, width=12, height=8)
