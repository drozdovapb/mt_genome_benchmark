# Combine data into a single data frame
ARC_nG <- read.csv("ARC_annotator.csv", sep = ";")
ARC_1_nG <- read.csv("ARC_annotator_1.csv", sep = ";")
Getorganel_nG <- read.csv("Georganell_annotator.csv", sep = ";")
MEANGS_nG <- read.csv("MEANGS_annotator.csv", sep = ";")
MEANGS_E_nG <- read.csv("MEANGS_E_annotator.csv", sep = ";")
MITGARD_nG <- read.csv("MITGARD_annotator.csv", sep = ";")
Mitobim_nG <- read.csv("mitobim_annotator.csv", sep = ";")
Mitobim_1_nG <- read.csv("mitobim_annotator_1.csv", sep = ";")
Mitofinder_nG <- read.csv("Mitofinder_annotator.csv", sep = ";")
Mitofinder_1_nG <- read.csv("Mitofinder_annotator_1.csv", sep = ";")
Mitoz_nG <- read.csv("Mitoz_annotator.csv", sep = ";")
mtgrasp_nG <- read.csv("mtgrasp_annotator.csv", sep = ";")
Norgal_nG <- read.csv("Norgal_annotator.csv", sep = ";")
Norgal_1_nG <- read.csv("Norgal_annotator_1.csv", sep = ";")
NOVOplasty_nG <- read.csv("NOVOplasty_annotator.csv", sep = ";")
# Modify assembler names
ARC_nG$Assembler <- "ARC"
ARC_1_nG$Assembler <- "ARC"
Getorganel_nG$Assembler <- "GetOrganelle"
MEANGS_nG$Assembler <- "MEANGS"
MEANGS_E_nG$Assembler <- "MEANGS"
MITGARD_nG$Assembler <- "MITGARD"
Mitobim_nG$Assembler <- "MITObim"
Mitobim_1_nG$Assembler <- "MITObim"
Mitofinder_nG$Assembler <- "MitoFinder"
Mitofinder_1_nG$Assembler <- "MitoFinder"
Mitoz_nG$Assembler <- "MitoZ"
mtgrasp_nG$Assembler <- "mtGrasp"
Norgal_nG$Assembler <- "Norgal"
Norgal_1_nG$Assembler <- "Norgal"
NOVOplasty_nG$Assembler <- "NOVOplasty"

all_nG <- rbind(ARC_nG, ARC_1_nG, Getorganel_nG, MEANGS_E_nG, MEANGS_nG, MITGARD_nG, Mitobim_nG, Mitobim_1_nG, 
                Mitofinder_nG, Mitofinder_1_nG, Mitoz_nG, mtgrasp_nG, Norgal_nG, Norgal_1_nG, NOVOplasty_nG)

library(xlsx)
all_table <- read.xlsx("Results_file.xlsx", 1)

colnames(all_nG)[4] <- "assembler"

colnames(all_nG)[1] <- colnames(all_table)[2]
colnames(all_nG)[2] <- colnames(all_table)[3]

all_table_nG <- merge(all_table, all_nG, by = c(colnames(all_table)[1], colnames(all_table)[2], colnames(all_table)[3]), all.x = TRUE)

all_table_nG_new <- read.csv("all_table_nG.csv")


# Figure 1

mt_result <- all_table_nG_new

mt_result <- subset(all_table_nG_new, (type_input_data == "genome_3x" & type_ref_data == "full_mt_genom_Ecy") | 
                      (type_input_data == "genome_3x" & type_ref_data == "de_novo"))

mt_result <- mt_result[, c(2, 5, 7, 21, 24)]

mt_result$assembler <- factor(mt_result$assembler, 
                              levels = c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder", "mtGrasp", "NOVOplasty",
                                         "MEANGS", "MitoZ", "Norgal"))

colnames(mt_result)[2] <- "n_contigs"
colnames(mt_result)[3] <- "lenght"
colnames(mt_result)[4] <- "score"
colnames(mt_result)[5] <- "genes"
mt_result$species <- "E. cyaneus"



library(ggplot2)
library(dplyr)
library(hrbrthemes)
library(RColorBrewer)

str(mt_result)
mt_result <- as.data.frame(mt_result)

if("lenght" %in% colnames(mt_result)) {
  colnames(mt_result)[colnames(mt_result) == "lenght"] <- "length"
}

plot_data <- mt_result %>%
  # Filter for the target species
  filter(species == "E. cyaneus") %>%
  # Group by assembler
  group_by(assembler) %>%
  summarize(
    n_contigs = first(n_contigs),
    max_len_kb = log10(length/1000), 
    max_score = score * 100,
    sum_genes = genes,       
    .groups = 'drop'
  )

plot_data <- plot_data %>%
  mutate(across(where(is.numeric), ~ ifelse(is.infinite(.) & . < 0, 0, .)))

plot_data[is.na(plot_data)] <- 0


library(ggtext)

# 2. PLOT CONSTRUCTION (single facet for E. cyaneus)
ggplot(plot_data, aes(x = max_len_kb, y = max_score, color = assembler)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(xintercept = log10(14370/1000), linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_point(aes(size = sum_genes, fill = assembler),
             shape = 21,
             color = "black",
             stroke = ifelse(plot_data$sum_genes == 15, 2.5, 0.5),  # edge stroke thickness
             alpha = 0.8) +
  scale_y_continuous(limits = c(-5, 110), expand = c(0, 0)) +
  # X axis: data are log-transformed, axis labels show rounded raw values
  scale_x_continuous(
    limits = c(0, 3.47),
    expand = expansion(mult = c(0.02, 0.05)),
    breaks = c(0, 0.7, 1, 1.3, 1.7, 2, 2.3, 2.7, 3, 3.3),
    labels = c("1", "5", "10", "20", "50", "100", "200", "500", 
               "1000", "2000")
  ) +
  scale_size_continuous(range = c(6, 20), name = "Gene count") +
  scale_fill_manual(values = c(
    "#E69F00",
    "#56B4E9",
    "#009E73",
    "#CC79A7",
    "#0072B2",
    "#D55E00",
    "#F0E442",
    "#999999",
    "#882255",
    "#661100"
  ), name = "Assembler") +
  guides(
    fill = guide_legend(
      override.aes = list(size = 8, alpha = 1, stroke = 0.6, color = "black"),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 16, family = "Helvetica")
    ),
    size = guide_legend(
      override.aes = list(
        fill = "white",
        color = "black",
        stroke = c(0.5, 0.5, 0.5, 2.5),  # Bold stroke only for 15 genes
        alpha = 1
      ),
      title.position = "top", 
      title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 16, family = "Helvetica")
    )
  ) +
  labs(
    title = "*E. cyaneus*",
    subtitle = NULL,
    x = "Total contig length, kb",
    y = "Score, %",
    fill = "Assembler",
    size = "Gene count"
  ) +
  theme_ipsum(grid = "XY", axis_title_size = 15) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    legend.box.just = "left",
    legend.direction = "vertical",
    legend.key.size = unit(1.8, "cm"),
    legend.key.width = unit(1.8, "cm"),
    legend.key.height = unit(1.6, "cm"),
    legend.spacing = unit(0.2, "cm"),
    legend.spacing.y = unit(0.2, "cm"),
    legend.margin = margin(t = 5, r = 10, b = 5, l = 10),
    legend.text = element_text(size = 18, family = "Helvetica", margin = margin(l = 5)),
    legend.title = element_text(size = 20, face = "bold", family = "Helvetica", margin = margin(b = 3)),
    plot.title = element_markdown(size = 22, face = "bold", family = "Helvetica", hjust = 0),
    plot.subtitle = element_text(size = 18, color = "black", family = "Helvetica", hjust = 0),
    axis.title.x = element_text(size = 20, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.title.y = element_text(size = 20, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.text.x = element_text(size = 16, family = "Helvetica", color = "black"),
    axis.text.y = element_text(size = 16, family = "Helvetica", color = "black"),
    axis.line.x = element_line(color = "gray60", linewidth = 0.8),
    axis.line.y = element_line(color = "gray60", linewidth = 0.8),
    axis.ticks = element_line(color = "black"),
    plot.margin = margin(t = 15, r = 15, b = 10, l = 25)
  )

ggsave("17032026_figure_1.png", width = 35, height = 26, units = "cm", dpi = 300)



#cover
all_table_nG_new <- read.csv("all_table_nG.csv")

mt_result <- all_table_nG_new

mt_result <- subset(all_table_nG_new, (type_input_data == "genome" & type_ref_data == "full_mt_genom_Ecy") | 
                      (type_input_data == "genome_1p" & type_ref_data == "full_mt_genom_Ecy") | 
                      (type_input_data == "genome_10p" & type_ref_data == "full_mt_genom_Ecy") |
                      (type_input_data == "genome_16p" & type_ref_data == "full_mt_genom_Ecy") |
                      (type_input_data == "genome" & type_ref_data == "de_novo") |
                      (type_input_data == "genome_1p" & type_ref_data == "de_novo") |
                      (type_input_data == "genome_10p" & type_ref_data == "de_novo") |
                      (type_input_data == "genome_16p" & type_ref_data == "de_novo"))


mt_result <- mt_result[, c(2, 3, 5, 7, 21, 24)]

mt_result$assembler <- factor(mt_result$assembler, 
                              levels = c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder", "mtGrasp", "NOVOplasty",
                                         "MEANGS", "MitoZ", "Norgal"))

colnames(mt_result)[3] <- "n_contigs"
colnames(mt_result)[4] <- "lenght"
colnames(mt_result)[5] <- "score"
colnames(mt_result)[6] <- "genes"
mt_result$species <- "E. cyaneus"


library(ggplot2)
library(dplyr)
library(hrbrthemes)
library(RColorBrewer)

str(mt_result)
mt_result <- as.data.frame(mt_result)

if("lenght" %in% colnames(mt_result)) {
  colnames(mt_result)[colnames(mt_result) == "lenght"] <- "length"
}

plot_data <- mt_result %>%
  # Filter for the target species
  filter(species == "E. cyaneus") %>%
  # Group by assembler
  group_by(assembler, type_input_data) %>%
  summarize(
    n_contigs = first(n_contigs), 
    max_len_kb = log10(length / 1000),
    max_score = score * 100,
    sum_genes = genes,       
    .groups = 'drop'
  )

plot_data <- plot_data %>%
  mutate(across(where(is.numeric), ~ ifelse(is.infinite(.) & . < 0, 0, .)))


library(ggtext)
library(dplyr)

# Create two data subsets
plot_data_clean <- plot_data %>%
  filter(
    !is.na(max_len_kb),
    !is.na(max_score),
    !is.na(sum_genes),
    !is.na(assembler),
    !is.na(type_input_data)
  )

# Split data: 4th facet (Cover 0.06×) and the rest
plot_data_other <- plot_data_clean %>% 
  filter(type_input_data != "genome_1p")

plot_data_facet4 <- plot_data_clean %>% 
  filter(type_input_data == "genome_1p")

# PLOT CONSTRUCTION 
ggplot() +
  geom_point(data = plot_data_other,
             aes(x = max_len_kb, y = max_score, size = sum_genes, fill = assembler),
             shape = 21,
             color = "black",
             stroke = ifelse(plot_data_other$sum_genes == 15, 2.5, 0.5),
             alpha = 0.8) +
  geom_point(data = plot_data_facet4,
             aes(x = max_len_kb, y = max_score, size = sum_genes, fill = assembler),
             shape = 21,
             color = "black",
             stroke = ifelse(plot_data_facet4$sum_genes == 15, 2.5, 0.5),
             alpha = 0.8) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(xintercept = log10(14370/1000), linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  facet_wrap(~type_input_data, scales = "free", ncol = 2,
             labeller = labeller(type_input_data = c("genome" = "Coverage 6×", "genome_16p" = "Coverage 1×", 
                                                     "genome_10p" = "Coverage 0.6×", "genome_1p" = "Coverage 0.06×"))) +
  scale_y_continuous(limits = c(-10, 110), expand = c(0, 0)) +
  scale_x_continuous(
    limits = c(-0.1, 3),
    expand = expansion(mult = c(0.01, 0.02)),
    breaks = c(0, 0.7, 1, 1.3, 1.7, 2, 2.477121, 2.954243),
    labels = c("0", "5", "10", "20", "50", "100", "300", "900")
  ) +
  
  scale_size_continuous(range = c(5, 15), name = "Gene count") +
  
  scale_fill_manual(values = c(
    "#E69F00", "#56B4E9", "#009E73", "#CC79A7", "#0072B2",
    "#D55E00", "#F0E442", "#999999", "#882255","#661100"
  ), name = "Assembler") + 
  
  guides(
    fill = guide_legend(
      override.aes = list(size = 8, alpha = 1, stroke = 0.6, color = "black"),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 22, family = "Helvetica")
    ),
    size = guide_legend(
      override.aes = list(
        fill = "white",
        color = "black",
        stroke = c(0.5, 0.5, 0.5, 2.5),  # Bold stroke only for 15 genes
        alpha = 1
      ),
      title.position = "top", 
      title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 18, family = "Helvetica")
    )
  ) +
  labs(
    title = "*E. cyaneus*",
    subtitle = NULL,
    x = "Total contigs length, kb",
    y = "Score, %",
    fill = "Assembler",
    size = "Gene count"
  ) +
  theme_ipsum(grid = "XY", axis_title_size = 15) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    legend.box.just = "left",
    legend.direction = "vertical",
    legend.key.size = unit(1.5, "cm"),
    legend.key.width = unit(1.5, "cm"),
    legend.key.height = unit(1.4, "cm"),
    legend.spacing = unit(0.2, "cm"),
    legend.spacing.y = unit(0.2, "cm"),
    legend.margin = margin(t = 5, r = 5, b = 5, l = 5), 
    legend.text = element_text(size = 22, family = "Helvetica", margin = margin(l = 1)),
    legend.title = element_text(size = 24, face = "bold", family = "Helvetica", margin = margin(b = 3)),
    plot.title = element_markdown(size = 28, face = "bold", family = "Helvetica", hjust = 0),
    plot.subtitle = element_text(size = 16, color = "black", family = "Helvetica", hjust = 0),
    strip.text = element_text(size = 20, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.background = element_rect(fill = "gray95", color = "gray60", linewidth = 0.5),
    axis.title.x = element_text(size = 24, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.title.y = element_text(size = 24, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.text.x = element_text(size = 18, family = "Helvetica", color = "black"),
    axis.text.y = element_text(size = 18, family = "Helvetica", color = "black"),
    axis.line.x = element_line(color = "gray60", linewidth = 0.8),
    axis.line.y = element_line(color = "gray60", linewidth = 0.8),
    axis.ticks = element_line(color = "black"),
    panel.spacing = unit(0.8, "cm"),
    plot.margin = margin(t = 10, r = 5, b = 5, l = 5) 
  )

ggsave("23032026_figure_2_2.png", width = 36, height = 25, units = "cm", dpi = 300)

#DNA or RNA
all_table_nG_new <- read.csv("all_table_nG.csv")

mt_result <- all_table_nG_new

mt_result <- subset(all_table_nG_new, (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Ecy") | 
                      (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Bpul") |
                      (type_input_data == "genome_3x"  & type_ref_data == "de_novo") |
                      (type_input_data == "genome_3x"  & type_ref_data == "de_novo_Bpul") |
                      (type_input_data == "genome" & type_ref_data == "full_mt_genom_EveS_EveS") | 
                      (type_input_data == "transcriptome" & type_ref_data == "full_mt_genom_Ecy") |
                      (type_input_data == "transcriptome" & type_ref_data == "full_mt_genom_EveS_EveS") |
                      (type_input_data == "transcriptome" & type_ref_data == "full_mt_genom_Bpul") |
                      (type_input_data == "genome" & type_ref_data == "de_novo_EveS")|
                      (type_input_data == "transcriptome" & type_ref_data == "de_novo_Bpul") |
                      (type_input_data == "transcriptome" & type_ref_data == "de_novo") |
                      (type_input_data == "transcriptome" & type_ref_data == "de_novo_EveS"))


mt_result <- mt_result[, c(2, 3, 4, 5, 7, 21, 24)]

mt_result$assembler <- factor(mt_result$assembler, 
                              levels = c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder", "mtGrasp", "NOVOplasty",
                                         "MEANGS", "MitoZ", "Norgal"))

colnames(mt_result)[4] <- "n_contigs"
colnames(mt_result)[5] <- "lenght"
colnames(mt_result)[6] <- "score"
colnames(mt_result)[7] <- "genes"



mt_result$Species <- ifelse(mt_result$type_ref_data == "full_mt_genom_Ecy", "E. cyaneus",
                            ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul", "B. pullus",
                                   ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_EveS", "E. verrucosus",
                                          ifelse(mt_result$type_ref_data == "full_mt_genom_Eve", "E. cyaneus",
                                                 ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul_Eve", "B. pullus",
                                                        ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_Ecy", "E. verrucosus",
                                                               ifelse(mt_result$type_ref_data == "part_COI_Ecy", "E. cyaneus",
                                                                      ifelse(mt_result$type_ref_data == "part_COI_Bpul", "B. pullus",
                                                                             ifelse(mt_result$type_ref_data == "part_COI_EveS", "E. verrucosus",
                                                                                    ifelse(mt_result$type_ref_data == "de_novo", "E. cyaneus",
                                                                                           ifelse(mt_result$type_ref_data == "de_novo_Bpul", "B. pullus",
                                                                                                  ifelse(mt_result$type_ref_data == "de_novo_EveS", "E. verrucosus", "none"))))))))))))




library(ggplot2)
library(dplyr)
library(hrbrthemes)
library(RColorBrewer)

str(mt_result)
mt_result <- as.data.frame(mt_result)

if("lenght" %in% colnames(mt_result)) {
  colnames(mt_result)[colnames(mt_result) == "lenght"] <- "length"
}

plot_data <- mt_result %>%
  group_by(assembler, type_input_data, type_ref_data) %>%
  summarize(
    Species = Species,
    n_contigs = first(n_contigs),
    max_len_kb = log10(length / 1000),
    max_score = score * 100,
    sum_genes = genes,       
    .groups = 'drop'
  )

plot_data <- plot_data %>%
  mutate(across(where(is.numeric), ~ ifelse(is.infinite(.) & . < 0, 0, .)))

library(ggtext)
library(dplyr)
library(ggh4x)

plot_data_clean <- plot_data

plot_data_clean <- plot_data %>%
  mutate(
    type_input_data = ifelse(type_input_data == "genome_3x", "genome", type_input_data)
  )

plot_data_clean <- plot_data_clean %>%
  mutate(
    max_len_kb = ifelse(max_len_kb < 0, 0, max_len_kb),
    max_score = ifelse(max_score < 0, 0, max_score),
    sum_genes = ifelse(sum_genes < 0, 0, sum_genes),
    max_len_kb = ifelse(is.na(max_len_kb), 0, max_len_kb),
    max_score = ifelse(is.na(max_score), 0, max_score),
    sum_genes = ifelse(is.na(sum_genes), 0, sum_genes),
    n_contigs = ifelse(is.na(n_contigs), 0, n_contigs)
  )

colnames(plot_data_clean)[2] <- "data_type"
colnames(plot_data_clean)[4] <- "species"

hline_data <- plot_data_clean %>%
  group_by(species) %>%
  summarise(m_mpg = c(), .groups = 'drop')

hline_data$value <- ifelse(hline_data$species == "B. pullus", 16.284,
                           ifelse(hline_data$species == "E. cyaneus", 14.370,
                                  ifelse(hline_data$species == "E. verrucosus", 15.601, "none"))) 
str(hline_data)

hline_data$value <- as.numeric(hline_data$value)

library(ggtext)
library(dplyr)
library(ggh4x)

first_facet_data <- subset(plot_data_clean, 
                           data_type == "genome" & species == "B. pullus")

target_x <- log10(16.284)
target_y <- 100
threshold_x <- 0.3
threshold_y <- 5

points_near_intersection <- first_facet_data %>%
  filter(abs(max_len_kb - target_x) < threshold_x & 
           abs(max_score - target_y) < threshold_y) %>%
  arrange(desc(max_score)) %>%
  mutate(
    label_y = seq(120, 60, length.out = n()), 
    label_x = 2.5,
    line_x_end = 2.45
  )

facet5_data <- subset(plot_data_clean, 
                      data_type == "transcriptome" & species == "E. cyaneus")

target_x5 <- log10(14.370)
target_y5 <- 100
threshold_x5 <- 0.3
threshold_y5_low <- 85
threshold_y5_high <- 90

points_near_intersection5 <- facet5_data %>%
  filter(abs(max_len_kb - target_x5) < threshold_x5 &
           max_score >= threshold_y5_low & max_score <= threshold_y5_high) %>%
  arrange(desc(max_score)) %>%
  mutate(
    label_y = seq(105, 95, length.out = n()),  
    label_x = 2.8,
    line_x_end = 2.75
  )

ggplot(plot_data_clean, aes(x = max_len_kb, y = max_score, fill = assembler)) +
  geom_point(aes(size = sum_genes),
             shape = 21,
             color = "black",
             stroke = ifelse(plot_data_clean$sum_genes == 15, 2.5, 0.5),
             alpha = 0.8) +
  
  # Footnotes for the first facet
geom_segment(data = points_near_intersection,
             aes(x = max_len_kb, y = max_score, 
                 xend = line_x_end, yend = label_y),
             color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8) +
  geom_segment(data = points_near_intersection,
               aes(x = line_x_end, y = label_y,
                   xend = label_x, yend = label_y),
               color = "black", linewidth = 0.4, linetype = "solid") +
  geom_text(data = points_near_intersection,
            aes(x = label_x, y = label_y, 
                label = paste0(assembler, " (", sum_genes, ")")),
            size = 6, color = "black", fontface = "plain",
            hjust = 0, vjust = 0.5, show.legend = FALSE) +
  
  # Footnotes for the fifth facet
geom_segment(data = points_near_intersection5,
             aes(x = max_len_kb, y = max_score, 
                 xend = line_x_end, yend = label_y),
             color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8) +
  geom_segment(data = points_near_intersection5,
               aes(x = line_x_end, y = label_y,
                   xend = label_x, yend = label_y),
               color = "black", linewidth = 0.4, linetype = "solid") +
  geom_text(data = points_near_intersection5,
            aes(x = label_x, y = label_y, 
                label = paste0(assembler, " (", sum_genes, ")")),
            size = 6, color = "black", fontface = "plain",
            hjust = 0, vjust = 0.5, show.legend = FALSE) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(data = hline_data, aes(xintercept = log10(value)), linetype = "dashed", color = "gray30", size = 1) +
  facet_grid2(data_type ~ species, 
              scales = "free", 
              axes = "all",
              remove_labels = "none",
              labeller = labeller(
                data_type = c("genome" = "DNA", "transcriptome" = "RNA"),
                species = c(
                  "B. pullus" = "*B. pullus*",
                  "E. cyaneus" = "*E. cyaneus*", 
                  "E. verrucosus" = "*E. verrucosus*"
                )
              )) +
  scale_y_continuous(limits = c(-15, 125), expand = c(0, 0),
                     breaks = c(0, 20, 40, 60, 80, 100)) +
  scale_x_continuous(
    limits = c(-0.2, 4.2),
    expand = expansion(mult = c(0.01, 0.01)),
    breaks = c(0, 0.7, 1.3, 2, 3, 4),
    labels = c("0", "5", "20", "100", "1000", "10000")
  ) +
  scale_size_continuous(range = c(5, 15), name = "Gene count") +
  scale_fill_manual(values = c(
    "#E69F00", "#56B4E9", "#009E73", "#CC79A7", "#0072B2",
    "#D55E00", "#F0E442", "#999999", "#882255", "#661100"
  ), name = "Assembler") + 
  guides(
    fill = guide_legend(
      override.aes = list(size = 8, alpha = 1, stroke = 0.6, color = "black"),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 22, family = "Helvetica")
    ),
    size = guide_legend(
      override.aes = list(
        fill = "white",
        color = "black",
        stroke = c(0.5, 0.5, 0.5, 2.5),
        alpha = 1
      ),
      title.position = "top", 
      title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 22, family = "Helvetica")
    )
  ) +
  labs(
    title = NULL,
    subtitle = NULL,
    x = "Total contig length, kb",
    y = "Score, %",
    fill = "Assembler",
    size = "Gene count"
  ) +
  theme_ipsum(grid = "XY", axis_title_size = 15) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    legend.box.just = "left",
    legend.direction = "vertical",
    legend.key.size = unit(1.5, "cm"),
    legend.key.width = unit(1.5, "cm"),
    legend.key.height = unit(1.4, "cm"),
    legend.spacing = unit(0.2, "cm"),
    legend.spacing.y = unit(0.2, "cm"),
    legend.margin = margin(t = 5, r = 5, b = 5, l = 5),
    legend.text = element_text(size = 22, family = "Helvetica", margin = margin(l = 5)),
    legend.title = element_text(size = 24, face = "bold", family = "Helvetica", margin = margin(b = 3)),
    strip.text.x = element_markdown(size = 24, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.text.y = element_markdown(size = 24, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.background = element_rect(fill = "gray95", color = "gray60", linewidth = 0.5),
    axis.title.x = element_text(size = 24, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.title.y = element_text(size = 24, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.text.x = element_text(size = 18, family = "Helvetica", color = "black"),
    axis.text.y = element_text(size = 18, family = "Helvetica", color = "black"),
    axis.line.x = element_line(color = "gray60", linewidth = 0.8),
    axis.line.y = element_line(color = "gray60", linewidth = 0.8),
    axis.ticks = element_line(color = "black"),
    panel.spacing = unit(0.8, "cm"),
    plot.margin = margin(t = 10, r = 5, b = 5, l = 5)
  )

ggsave("23032026_figure_3_2.png", width = 45, height = 25, units = "cm", dpi = 300)


#seed
all_table_nG_new <- read.csv("all_table_nG.csv")

mt_result <- all_table_nG_new

mt_result <- subset(all_table_nG_new, (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Ecy") |
                      (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Eve") |
                      (type_input_data == "genome_3x"  & type_ref_data == "part_COI_Ecy") |
                      (type_input_data == "genome_3x"  & type_ref_data == "de_novo") |
                      (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Bpul") |
                      (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Bpul_Eve") |
                      (type_input_data == "genome_3x"  & type_ref_data == "part_COI_Bpul") |
                      (type_input_data == "genome_3x"  & type_ref_data == "de_novo_Bpul") |
                      (type_input_data == "genome" & type_ref_data == "full_mt_genom_EveS_EveS") | 
                      (type_input_data == "genome" & type_ref_data == "full_mt_genom_EveS_Ecy") | 
                      (type_input_data == "genome" & type_ref_data == "part_COI_EveS") | 
                      (type_input_data == "genome" & type_ref_data == "de_novo_EveS"))


mt_result <- mt_result[, c(2, 3, 4, 5, 7, 21, 24)]

mt_result$assembler <- factor(mt_result$assembler, 
                              levels = c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder", "mtGrasp", "NOVOplasty",
                                         "MEANGS", "MitoZ", "Norgal"))

colnames(mt_result)[4] <- "n_contigs"
colnames(mt_result)[5] <- "lenght"
colnames(mt_result)[6] <- "score"
colnames(mt_result)[7] <- "genes"



mt_result$Species <- ifelse(mt_result$type_ref_data == "full_mt_genom_Ecy", "E. cyaneus",
                            ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul", "B. pullus",
                                   ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_EveS", "E. verrucosus",
                                          ifelse(mt_result$type_ref_data == "full_mt_genom_Eve", "E. cyaneus",
                                                 ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul_Eve", "B. pullus",
                                                        ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_Ecy", "E. verrucosus",
                                                               ifelse(mt_result$type_ref_data == "part_COI_Ecy", "E. cyaneus",
                                                                      ifelse(mt_result$type_ref_data == "part_COI_Bpul", "B. pullus",
                                                                             ifelse(mt_result$type_ref_data == "part_COI_EveS", "E. verrucosus",
                                                                                    ifelse(mt_result$type_ref_data == "de_novo", "E. cyaneus",
                                                                                           ifelse(mt_result$type_ref_data == "de_novo_Bpul", "B. pullus",
                                                                                                  ifelse(mt_result$type_ref_data == "de_novo_EveS", "E. verrucosus", "none"))))))))))))

mt_result$tipeseed <- ifelse(mt_result$type_ref_data == "full_mt_genom_Ecy", "Mitogenome",
                             ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul", "Mitogenome",
                                    ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_EveS", "Mitogenome",
                                           ifelse(mt_result$type_ref_data == "full_mt_genom_Eve", "Related mitogenome",
                                                  ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul_Eve", "Related mitogenome",
                                                         ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_Ecy", "Related mitogenome",
                                                                ifelse(mt_result$type_ref_data == "part_COI_Ecy", "Folmer region COI",
                                                                       ifelse(mt_result$type_ref_data == "part_COI_Bpul", "Folmer region COI",
                                                                              ifelse(mt_result$type_ref_data == "part_COI_EveS", "Folmer region COI",
                                                                                     ifelse(mt_result$type_ref_data == "de_novo", "De novo",
                                                                                            ifelse(mt_result$type_ref_data == "de_novo_Bpul", "De novo",
                                                                                                   ifelse(mt_result$type_ref_data == "de_novo_EveS", "De novo", "none"))))))))))))



library(ggplot2)
library(dplyr)
library(hrbrthemes)
library(RColorBrewer)

str(mt_result)
mt_result <- as.data.frame(mt_result)

if("lenght" %in% colnames(mt_result)) {
  colnames(mt_result)[colnames(mt_result) == "lenght"] <- "length"
}

plot_data <- mt_result %>%
  group_by(assembler, type_input_data, type_ref_data) %>%
  summarize(
    tipeseed = tipeseed,
    Species = Species,
    n_contigs = first(n_contigs),
    max_len_kb = log10(length / 1000),
    max_score = score * 100,
    sum_genes = genes,       
    .groups = 'drop'
  )

plot_data <- plot_data %>%
  mutate(across(where(is.numeric), ~ ifelse(is.infinite(.) & . < 0, 0, .)))

library(ggtext)
library(dplyr)
library(ggh4x)

plot_data_clean <- plot_data

plot_data_clean <- plot_data %>%
  mutate(
    type_input_data = ifelse(type_input_data == "genome_3x", "genome", type_input_data)
  )

plot_data_clean <- plot_data_clean %>%
  mutate(
    max_len_kb = ifelse(max_len_kb < 0, 0, max_len_kb),
    max_score = ifelse(max_score < 0, 0, max_score),
    sum_genes = ifelse(sum_genes < 0, 0, sum_genes),
    max_len_kb = ifelse(is.na(max_len_kb), 0, max_len_kb),
    max_score = ifelse(is.na(max_score), 0, max_score),
    sum_genes = ifelse(is.na(sum_genes), 0, sum_genes),
    n_contigs = ifelse(is.na(n_contigs), 0, n_contigs)
  )

colnames(plot_data_clean)[2] <- "data_type"
colnames(plot_data_clean)[5] <- "species"


plot_data_clean$species <- factor(plot_data_clean$species, 
                            levels=c("B. pullus", "E. cyaneus", "E. verrucosus"))

plot_data_clean$tipeseed <- factor(plot_data_clean$tipeseed, 
                             levels=c("Mitogenome", "Related mitogenome", "Folmer region COI", "De novo"))


plot_data_clean$assembler <- factor(plot_data_clean$assembler, 
                              levels = c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder", "mtGrasp", "NOVOplasty",
                                         "MEANGS", "MitoZ", "Norgal"))


hline_data <- plot_data_clean %>%
  group_by(species) %>%
  summarise(m_mpg = c(), .groups = 'drop')

hline_data$value <- ifelse(hline_data$species == "B. pullus", 16.284,
                           ifelse(hline_data$species == "E. cyaneus", 14.370,
                                  ifelse(hline_data$species == "E. verrucosus", 15.601, "none"))) 
str(hline_data)

hline_data$value <- as.numeric(hline_data$value)


library(ggtext)
library(dplyr)
library(ggh4x)

threshold_x <- 0.3

target_facets <- list(
  list(species = "B. pullus", tipeseed = "Mitogenome",
       value = 16.284, tag = "f1", score_min = 80, score_max = 100,
       x_condition = "around", exclude = NULL),
  list(species = "B. pullus", tipeseed = "Folmer region COI",
       value = 16.284, tag = "f3", score_min = 80, score_max = 100,
       x_condition = "around", exclude = NULL),
  list(species = "E. cyaneus", tipeseed = "Mitogenome",
       value = 14.370, tag = "f5", score_min = 80, score_max = 100,
       x_condition = "around", exclude = NULL),
  list(species = "E. cyaneus", tipeseed = "Folmer region COI",
       value = 14.370, tag = "f7", score_min = 40, score_max = 80,
       x_condition = "left", exclude = c("ARC", "mtGrasp")),
  list(species = "E. verrucosus", tipeseed = "Mitogenome",
       value = 15.601, tag = "f9", score_min = 60, score_max = 100,
       x_condition = "around", exclude = c("MITObim", "ARC")),
  list(species = "E. verrucosus", tipeseed = "Folmer region COI",
       value = 15.601, tag = "f11", score_min = 40, score_max = 100,
       x_condition = "left", exclude = c("GetOrganelle", "ARC"))
)

points_list <- list()

for (f in target_facets) {
  target_x <- log10(f$value)
  
  df <- plot_data_clean %>%
    filter(species == f$species, tipeseed == f$tipeseed) %>%
    filter(max_score >= f$score_min & max_score <= f$score_max)
  
  if (f$x_condition == "around") {
    df <- df %>% filter(abs(max_len_kb - target_x) < threshold_x)
  } else if (f$x_condition == "left") {
    df <- df %>% filter(max_len_kb <= target_x + 0.3)
  }
  
  if (!is.null(f$exclude)) {
    df <- df %>% filter(!(assembler %in% f$exclude))
  }
  
  df <- df %>% arrange(desc(max_score))
  
  cat("Фасет", f$tag, "найдено точек:", nrow(df), "\n")
  
  if (nrow(df) > 0) {
    df <- df %>%
      mutate(
        label_y = seq(117, 75, length.out = n()),
        label_x = 2.55,
        line_x_end = 2.5
      )
    points_list[[f$tag]] <- df
  } else {
    points_list[[f$tag]] <- NULL
  }
}

ggplot(plot_data_clean, aes(x = max_len_kb, y = max_score, fill = assembler)) +
  
  geom_point(aes(size = sum_genes,
                 stroke = ifelse(sum_genes == 15, 2.5, 0.5)),
             shape = 21,
             color = "black",
             alpha = 0.8) +
  
  # f1
  {if (!is.null(points_list$f1)) list(
    geom_segment(data = points_list$f1, aes(x = max_len_kb, y = max_score, xend = line_x_end, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8),
    geom_segment(data = points_list$f1, aes(x = line_x_end, y = label_y, xend = label_x, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid"),
    geom_text(data = points_list$f1, aes(x = label_x, y = label_y, label = paste0(assembler, " (", sum_genes, ")")),
              size = 6, color = "black", fontface = "plain", hjust = 0, vjust = 0.5, show.legend = FALSE)
  )} +
  # f3
  {if (!is.null(points_list$f3)) list(
    geom_segment(data = points_list$f3, aes(x = max_len_kb, y = max_score, xend = line_x_end, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8),
    geom_segment(data = points_list$f3, aes(x = line_x_end, y = label_y, xend = label_x, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid"),
    geom_text(data = points_list$f3, aes(x = label_x, y = label_y, label = paste0(assembler, " (", sum_genes, ")")),
              size = 6, color = "black", fontface = "plain", hjust = 0, vjust = 0.5, show.legend = FALSE)
  )} +
  # f5
  {if (!is.null(points_list$f5)) list(
    geom_segment(data = points_list$f5, aes(x = max_len_kb, y = max_score, xend = line_x_end, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8),
    geom_segment(data = points_list$f5, aes(x = line_x_end, y = label_y, xend = label_x, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid"),
    geom_text(data = points_list$f5, aes(x = label_x, y = label_y, label = paste0(assembler, " (", sum_genes, ")")),
              size = 6, color = "black", fontface = "plain", hjust = 0, vjust = 0.5, show.legend = FALSE)
  )} +
  # f7
  {if (!is.null(points_list$f7)) list(
    geom_segment(data = points_list$f7, aes(x = max_len_kb, y = max_score, xend = line_x_end, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8),
    geom_segment(data = points_list$f7, aes(x = line_x_end, y = label_y, xend = label_x, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid"),
    geom_text(data = points_list$f7, aes(x = label_x, y = label_y, label = paste0(assembler, " (", sum_genes, ")")),
              size = 6, color = "black", fontface = "plain", hjust = 0, vjust = 0.5, show.legend = FALSE)
  )} +
  # f9
  {if (!is.null(points_list$f9)) list(
    geom_segment(data = points_list$f9, aes(x = max_len_kb, y = max_score, xend = line_x_end, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8),
    geom_segment(data = points_list$f9, aes(x = line_x_end, y = label_y, xend = label_x, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid"),
    geom_text(data = points_list$f9, aes(x = label_x, y = label_y, label = paste0(assembler, " (", sum_genes, ")")),
              size = 6, color = "black", fontface = "plain", hjust = 0, vjust = 0.5, show.legend = FALSE)
  )} +
  # f11
  {if (!is.null(points_list$f11)) list(
    geom_segment(data = points_list$f11, aes(x = max_len_kb, y = max_score, xend = line_x_end, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8),
    geom_segment(data = points_list$f11, aes(x = line_x_end, y = label_y, xend = label_x, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid"),
    geom_text(data = points_list$f11, aes(x = label_x, y = label_y, label = paste0(assembler, " (", sum_genes, ")")),
              size = 6, color = "black", fontface = "plain", hjust = 0, vjust = 0.5, show.legend = FALSE)
  )} +
  
  # Reference lines
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(data = hline_data, aes(xintercept = log10(value)), linetype = "dashed", color = "gray30", size = 1) +
  facet_grid2(species ~ tipeseed, 
              scales = "free", 
              axes = "all",
              remove_labels = "none",
              labeller = labeller(
                tipeseed = c("Mitogenome" = "Mitogenome",
                             "Related mitogenome" = "Related mitogenome",
                             "Folmer region COI" = "Folmer region COI",
                             "De novo" = "*De novo*"),
                species = c("B. pullus" = "*B. pullus*",
                            "E. cyaneus" = "*E. cyaneus*",
                            "E. verrucosus" = "*E. verrucosus*")
              )) +
  scale_y_continuous(limits = c(-20, 125), expand = c(0, 0),
                     breaks = c(0, 20, 40, 60, 80, 100),
                     labels = c("0", "20", "40", "60", "80", "100")) +
  scale_x_continuous(
    limits = c(-0.4, 5.0),
    expand = expansion(mult = c(0.01, 0.02)),
    breaks = c(0, 0.7, 1.3, 2,  4),
    labels = c("0", "5", "20", "100", "10000")
  ) +
  scale_size_continuous(range = c(6, 18), name = "Gene count") +
  scale_fill_manual(values = c(
    "#E69F00", "#56B4E9", "#009E73", "#CC79A7", "#0072B2",
    "#D55E00", "#F0E442", "#999999", "#882255", "#661100"
  ), name = "Assembler") +
  guides(
    fill = guide_legend(
      override.aes = list(size = 10, alpha = 1, stroke = 0.8, color = "black"),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 24, family = "Helvetica")
    ),
    size = guide_legend(
      override.aes = list(fill = "white", color = "black", stroke = c(0.5, 0.5, 0.5, 2.5), alpha = 1),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 24, family = "Helvetica")
    )
  ) +
  labs(
    title = NULL,
    subtitle = NULL,
    x = "Total contig length, kb",
    y = "Score, %",
    fill = "Assembler",
    size = "Gene count"
  ) +
  theme_ipsum(grid = "XY", axis_title_size = 18) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    legend.box.just = "left",
    legend.direction = "vertical",
    legend.key.size = unit(1.8, "cm"),
    legend.key.width = unit(1.8, "cm"),
    legend.key.height = unit(1.6, "cm"),
    legend.spacing = unit(0.3, "cm"),
    legend.spacing.y = unit(0.3, "cm"),
    legend.margin = margin(t = 8, r = 8, b = 8, l = 8),
    legend.text = element_text(size = 20, family = "Helvetica", margin = margin(l = 6)),
    legend.title = element_text(size = 24, face = "bold", family = "Helvetica", margin = margin(b = 4)),
    strip.text.x = element_markdown(size = 25, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.text.y = element_markdown(size = 25, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.background = element_rect(fill = "gray95", color = "gray60", linewidth = 0.5),
    axis.title.x = element_text(size = 28, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.title.y = element_text(size = 28, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.text.x = element_text(size = 18, family = "Helvetica", color = "black"),
    axis.text.y = element_text(size = 18, family = "Helvetica", color = "black"),
    axis.line.x = element_line(color = "gray60", linewidth = 0.8),
    axis.line.y = element_line(color = "gray60", linewidth = 0.8),
    axis.ticks = element_line(color = "black"),
    panel.spacing = unit(1, "cm"),
    plot.margin = margin(t = 15, r = 40, b = 10, l = 10)
  )

ggsave("23032026_figure_4_2.png", width = 55, height = 32, units = "cm", dpi = 300)

#Time and RSS
all_table_nG_new <- read.csv("all_table_nG.csv")

mt_result <- all_table_nG_new

mt_result <- subset(all_table_nG_new, (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Ecy") |
                      (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Eve") |
                      (type_input_data == "genome_3x"  & type_ref_data == "part_COI_Ecy") |
                      (type_input_data == "genome_3x"  & type_ref_data == "de_novo") |
                      (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Bpul") |
                      (type_input_data == "genome_3x"  & type_ref_data == "full_mt_genom_Bpul_Eve") |
                      (type_input_data == "genome_3x"  & type_ref_data == "part_COI_Bpul") |
                      (type_input_data == "genome_3x"  & type_ref_data == "de_novo_Bpul") |
                      (type_input_data == "genome" & type_ref_data == "full_mt_genom_EveS_EveS") | 
                      (type_input_data == "genome" & type_ref_data == "full_mt_genom_EveS_Ecy") | 
                      (type_input_data == "genome" & type_ref_data == "part_COI_EveS") | 
                      (type_input_data == "genome" & type_ref_data == "de_novo_EveS"))


mt_result <- mt_result[, c(2, 3, 4, 6, 10, 21, 24)]

mt_result$assembler <- factor(mt_result$assembler, 
                              levels = c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder", "mtGrasp", "NOVOplasty",
                                         "MEANGS", "MitoZ", "Norgal"))

colnames(mt_result)[4] <- "Time"
colnames(mt_result)[5] <- "Memory"
colnames(mt_result)[6] <- "score"
colnames(mt_result)[7] <- "genes"



mt_result$Species <- ifelse(mt_result$type_ref_data == "full_mt_genom_Ecy", "E. cyaneus",
                            ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul", "B. pullus",
                                   ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_EveS", "E. verrucosus",
                                          ifelse(mt_result$type_ref_data == "full_mt_genom_Eve", "E. cyaneus",
                                                 ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul_Eve", "B. pullus",
                                                        ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_Ecy", "E. verrucosus",
                                                               ifelse(mt_result$type_ref_data == "part_COI_Ecy", "E. cyaneus",
                                                                      ifelse(mt_result$type_ref_data == "part_COI_Bpul", "B. pullus",
                                                                             ifelse(mt_result$type_ref_data == "part_COI_EveS", "E. verrucosus",
                                                                                    ifelse(mt_result$type_ref_data == "de_novo", "E. cyaneus",
                                                                                           ifelse(mt_result$type_ref_data == "de_novo_Bpul", "B. pullus",
                                                                                                  ifelse(mt_result$type_ref_data == "de_novo_EveS", "E. verrucosus", "none"))))))))))))

mt_result$tipeseed <- ifelse(mt_result$type_ref_data == "full_mt_genom_Ecy", "Mitogenome",
                             ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul", "Mitogenome",
                                    ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_EveS", "Mitogenome",
                                           ifelse(mt_result$type_ref_data == "full_mt_genom_Eve", "Related mitogenome",
                                                  ifelse(mt_result$type_ref_data == "full_mt_genom_Bpul_Eve", "Related mitogenome",
                                                         ifelse(mt_result$type_ref_data == "full_mt_genom_EveS_Ecy", "Related mitogenome",
                                                                ifelse(mt_result$type_ref_data == "part_COI_Ecy", "Folmer region COI",
                                                                       ifelse(mt_result$type_ref_data == "part_COI_Bpul", "Folmer region COI",
                                                                              ifelse(mt_result$type_ref_data == "part_COI_EveS", "Folmer region COI",
                                                                                     ifelse(mt_result$type_ref_data == "de_novo", "De novo",
                                                                                            ifelse(mt_result$type_ref_data == "de_novo_Bpul", "De novo",
                                                                                                   ifelse(mt_result$type_ref_data == "de_novo_EveS", "De novo", "none"))))))))))))



library(ggplot2)
library(dplyr)
library(hrbrthemes)
library(RColorBrewer)

str(mt_result)
mt_result <- as.data.frame(mt_result)

if("lenght" %in% colnames(mt_result)) {
  colnames(mt_result)[colnames(mt_result) == "lenght"] <- "length"
}

plot_data <- mt_result %>%
  group_by(assembler, type_input_data, type_ref_data) %>%
  summarize(
    tipeseed = tipeseed,
    Species = Species,
    Time = Time/60, 
    Memory = Memory/1024, 
    max_score = score * 100, 
    sum_genes = genes,       
    .groups = 'drop'
  )

plot_data <- plot_data %>%
  mutate(across(where(is.numeric), ~ ifelse(is.infinite(.) & . < 0, 0, .)))

library(ggtext)
library(dplyr)
library(ggh4x)

plot_data_clean <- plot_data

plot_data_clean <- plot_data %>%
  mutate(
    type_input_data = ifelse(type_input_data == "genome_3x", "genome", type_input_data)
  )

plot_data_clean <- plot_data_clean %>%
  mutate(
    Memory = ifelse(Memory < 0, 0, Memory),
    max_score = ifelse(max_score < 0, 0, max_score),
    sum_genes = ifelse(sum_genes < 0, 0, sum_genes),
    Memory = ifelse(is.na(Memory), 0, Memory),
    max_score = ifelse(is.na(max_score), 0, max_score),
    sum_genes = ifelse(is.na(sum_genes), 0, sum_genes),
    Time = ifelse(is.na(Time), 0, Time)
  )

colnames(plot_data_clean)[2] <- "data_type"
colnames(plot_data_clean)[5] <- "species"


plot_data_clean$species <- factor(plot_data_clean$species, 
                                  levels=c("B. pullus", "E. cyaneus", "E. verrucosus"))

plot_data_clean$tipeseed <- factor(plot_data_clean$tipeseed, 
                                   levels=c("Mitogenome", "Related mitogenome", "Folmer region COI", "De novo"))


plot_data_clean$assembler <- factor(plot_data_clean$assembler, 
                                    levels = c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder", "mtGrasp", "NOVOplasty",
                                               "MEANGS", "MitoZ", "Norgal"))


hline_data <- plot_data_clean %>%
  group_by(species) %>%
  summarise(m_mpg = c(), .groups = 'drop')

hline_data$value <- ifelse(hline_data$species == "B. pullus", 16.284,
                           ifelse(hline_data$species == "E. cyaneus", 14.370,
                                  ifelse(hline_data$species == "E. verrucosus", 15.601, "none"))) 
str(hline_data)

hline_data$value <- as.numeric(hline_data$value)



# PLOT CONSTRUCTION
ggplot(plot_data_clean, aes(x = Time, y = Memory, fill = assembler)) +
  geom_point(data = subset(plot_data_clean, tipeseed %in% c("Mitogenome", "Related mitogenome", "Folmer region COI")),
             size = 6,
             shape = 23,
             color = "black",
             alpha = 0.8,
             position = position_jitter(width = 0.06, height = 0.4)) +
  geom_point(data = subset(plot_data_clean, tipeseed == "De novo"),
             size = 6,
             shape = 23,
             color = "black",
             alpha = 0.8) +
  scale_y_continuous(
    limits = c(-2, 32)
  ) +
  scale_x_continuous(
    limits = c(-0.5, 12.5)
  ) +
  facet_grid2(species ~ tipeseed, 
              scales = "free", 
              axes = "all",
              remove_labels = "none",
              labeller = labeller(
                tipeseed = c(
                  "Mitogenome" = "Mitogenome",
                  "Related mitogenome" = "Related mitogenome", 
                  "Folmer region COI" = "Folmer region COI",
                  "De novo" = "*De novo*"
                ),
                species = c(
                  "B. pullus" = "*B. pullus*",
                  "E. cyaneus" = "*E. cyaneus*", 
                  "E. verrucosus" = "*E. verrucosus*"
                )
              )) +
  
  scale_fill_manual(values = c(
    "#E69F00", "#56B4E9", "#009E73", "#CC79A7", "#0072B2",
    "#D55E00", "#F0E442", "#999999", "#882255", "#661100"
  ), name = "Assembler") +
  guides(
    fill = guide_legend(
      override.aes = list(size = 10, alpha = 1, stroke = 0.8, color = "black"),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 28, family = "Helvetica")
    )
  ) +
  labs(
    title = NULL,
    subtitle = NULL,
    x = "Run-time, h",
    y = "Resident Set Size, Gb",
    fill = "Assembler"
  ) +
  theme_ipsum(grid = "XY", axis_title_size = 18) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    legend.box.just = "left",
    legend.direction = "vertical",
    legend.key.size = unit(1.8, "cm"),
    legend.key.width = unit(1.8, "cm"),
    legend.key.height = unit(1.6, "cm"),
    legend.spacing = unit(0.3, "cm"),
    legend.spacing.y = unit(0.3, "cm"),
    legend.margin = margin(t = 8, r = 8, b = 8, l = 8),
    legend.text = element_text(size = 20, family = "Helvetica", margin = margin(l = 6)),
    legend.title = element_text(size = 24, face = "bold", family = "Helvetica", margin = margin(b = 4)),
    strip.text.x = element_markdown(size = 24, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.text.y = element_markdown(size = 24, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.background = element_rect(fill = "gray95", color = "gray60", linewidth = 0.5),
    axis.title.x = element_text(size = 28, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.title.y = element_text(size = 28, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.text.x = element_text(size = 22, family = "Helvetica", color = "black"),
    axis.text.y = element_text(size = 22, family = "Helvetica", color = "black"),
    axis.line.x = element_line(color = "gray60", linewidth = 0.8),
    axis.line.y = element_line(color = "gray60", linewidth = 0.8),
    axis.ticks = element_line(color = "black"),
    panel.spacing = unit(1, "cm"),
    plot.margin = margin(t = 15, r = 10, b = 10, l = 10)
  )

ggsave("23032026_figure_5_2.png", width = 55, height = 32, units = "cm", dpi = 300)

