# =============================================================================
# Mitochondrial genome assembly benchmark – visualisation script
# Generates Figures 1 to 5 for the publication.
# Data: all_table_nG.csv (must be in the working directory)
# =============================================================================

# ----- Shared libraries -----
library(ggplot2)
library(dplyr)
library(hrbrthemes)
library(RColorBrewer)
library(ggtext)
library(ggh4x)
library(openxlsx)

# ----- Shared constants -----
ASSEMBLER_LEVELS <- c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder",
                      "mtGrasp", "NOVOplasty", "MEANGS", "MitoZ", "Norgal")

ASSEMBLER_COLORS <- c(
  "#E69F00", "#56B4E9", "#009E73", "#CC79A7", "#0072B2",
  "#D55E00", "#F0E442", "#999999", "#882255", "#661100"
)

SPECIES_LEVELS <- c("B. pullus", "E. cyaneus", "E. verrucosus")
SEED_LEVELS    <- c("Mitogenome", "Related mitogenome", "Folmer region COI", "De novo")

# Reference mitogenome lengths (kb)
SPECIES_LEN <- c(
  "B. pullus"     = 16.284,
  "E. cyaneus"    = 14.370,
  "E. verrucosus" = 15.601
)

# ----- Shared mapping: type_ref_data -> Species + tipeseed -----
REF_MAP <- data.frame(
  type_ref_data = c(
    "full_mt_genom_Ecy", "full_mt_genom_Bpul", "full_mt_genom_EveS_EveS",
    "full_mt_genom_Eve", "full_mt_genom_Bpul_Eve", "full_mt_genom_EveS_Ecy",
    "part_COI_Ecy", "part_COI_Bpul", "part_COI_EveS",
    "de_novo", "de_novo_Bpul", "de_novo_EveS"
  ),
  Species = c(
    "E. cyaneus", "B. pullus", "E. verrucosus",
    "E. cyaneus", "B. pullus", "E. verrucosus",
    "E. cyaneus", "B. pullus", "E. verrucosus",
    "E. cyaneus", "B. pullus", "E. verrucosus"
  ),
  tipeseed = c(
    "Mitogenome", "Mitogenome", "Mitogenome",
    "Related mitogenome", "Related mitogenome", "Related mitogenome",
    "Folmer region COI", "Folmer region COI", "Folmer region COI",
    "De novo", "De novo", "De novo"
  ),
  stringsAsFactors = FALSE
)

# ----- Shared helper functions -----
clean_numeric <- function(x) {
  x[is.na(x) | is.infinite(x) | x < 0] <- 0
  x
}

hline_data_for <- function(species_vec) {
  data.frame(
    species = species_vec,
    value   = as.numeric(SPECIES_LEN[as.character(species_vec)])
  )
}

# Annotation layer set used in Figures 3, 4 main, and 4 supplementary
make_annotation_layers <- function(df, size = 6) {
  if (is.null(df) || nrow(df) == 0) return(NULL)
  list(
    geom_segment(data = df,
                 aes(x = max_len_kb, y = max_score,
                     xend = line_x_end, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8),
    geom_segment(data = df,
                 aes(x = line_x_end, y = label_y,
                     xend = label_x, yend = label_y),
                 color = "black", linewidth = 0.4, linetype = "solid"),
    geom_text(data = df,
              aes(x = label_x, y = label_y,
                  label = paste0(assembler, " (", sum_genes, ")")),
              size = size, color = "black", fontface = "plain",
              hjust = 0, vjust = 0.5, show.legend = FALSE)
  )
}

# =============================================================================
# Load, enrich, save XLSX — one-time setup
# =============================================================================
raw_table <- read.csv("all_table_nG.csv")

# Column positions in all_table_nG.csv (as used across the original script):
#   [2]  assembler
#   [3]  type_input_data
#   [4]  type_ref_data
#   [5]  n_contigs
#   [6]  Time       (minutes)
#   [7]  length     (bp)   -- may be spelled "lenght"
#   [10] Memory     (MB)
#   [21] score
#   [24] genes
col_assembler       <- 2
col_type_input_data <- 3
col_type_ref_data   <- 4
col_n_contigs       <- 5
col_time            <- 6
col_length          <- 7
col_memory          <- 10
col_score           <- 21
col_genes           <- 24

final_table <- data.frame(
  assembler       = raw_table[[col_assembler]],
  type_input_data = raw_table[[col_type_input_data]],
  type_ref_data   = raw_table[[col_type_ref_data]],
  n_contigs       = raw_table[[col_n_contigs]],
  Time            = raw_table[[col_time]]   / 60,    # min -> h
  length          = suppressWarnings(as.numeric(as.character(raw_table[[col_length]]))),
  Memory          = raw_table[[col_memory]] / 1024,  # MB  -> GB
  score           = raw_table[[col_score]],
  genes           = raw_table[[col_genes]],
  stringsAsFactors = FALSE
) %>%
  left_join(REF_MAP, by = "type_ref_data") %>%
  mutate(
    Species    = coalesce(Species,  "none"),
    tipeseed   = coalesce(tipeseed, "none"),
    species    = as.character(Species),
    data_type  = ifelse(grepl("^genome", type_input_data), "genome", "transcriptome"),
    max_score  = score * 100,
    sum_genes  = genes,
    max_len_kb = log10(length / 1000)
  ) %>%
  mutate(
    # ---- Figure membership flags (single source of truth) ----
    in_fig1 = type_input_data == "genome_3x" &
      type_ref_data %in% c("full_mt_genom_Ecy", "de_novo"),
    
    in_fig2 = type_input_data %in% c("genome", "genome_1p", "genome_10p", "genome_16p") &
      type_ref_data %in% c("full_mt_genom_Ecy", "de_novo"),
    
    in_fig3 = (type_input_data == "genome_3x" &
                 type_ref_data %in% c("full_mt_genom_Ecy", "full_mt_genom_Bpul",
                                      "de_novo", "de_novo_Bpul")) |
      (type_input_data == "genome" &
         type_ref_data %in% c("full_mt_genom_EveS_EveS", "de_novo_EveS")) |
      (type_input_data == "transcriptome" &
         type_ref_data %in% c("full_mt_genom_Ecy", "full_mt_genom_EveS_EveS",
                              "full_mt_genom_Bpul", "de_novo_Bpul",
                              "de_novo", "de_novo_EveS")),
    
    in_fig4 = (type_input_data == "genome_3x" &
                 type_ref_data %in% c("full_mt_genom_Ecy", "full_mt_genom_Eve", "part_COI_Ecy",
                                      "full_mt_genom_Bpul", "full_mt_genom_Bpul_Eve", "part_COI_Bpul")) |
      (type_input_data == "genome" &
         type_ref_data %in% c("full_mt_genom_EveS_EveS", "full_mt_genom_EveS_Ecy", "part_COI_EveS")),
    
    in_fig4_suppl = (type_input_data == "genome_3x" &
                       type_ref_data %in% c("full_mt_genom_Ecy", "full_mt_genom_Eve", "part_COI_Ecy", "de_novo",
                                            "full_mt_genom_Bpul", "full_mt_genom_Bpul_Eve", "part_COI_Bpul", "de_novo_Bpul")) |
      (type_input_data == "genome" &
         type_ref_data %in% c("full_mt_genom_EveS_EveS", "full_mt_genom_EveS_Ecy",
                              "part_COI_EveS", "de_novo_EveS")),
    
    in_fig5 = in_fig4_suppl
  ) %>%
  mutate(across(where(is.numeric), clean_numeric))

# ---- Save enriched table (XLSX + CSV) ----
wb <- createWorkbook()
addWorksheet(wb, "results")
writeData(wb, "results", final_table)
setColWidths(wb, "results", cols = 1:ncol(final_table), widths = "auto")
freezePane(wb, "results", firstRow = TRUE)
addFilter(wb, "results", row = 1, cols = 1:ncol(final_table))
saveWorkbook(wb, "all_table_nG_full.xlsx", overwrite = TRUE)

write.csv(final_table, "all_table_nG_full.csv", row.names = FALSE)

# Kept for compatibility with the rest of the script
all_table_nG_new <- final_table

# =============================================================================
# FIGURE 1: E. cyaneus, two reference types
# =============================================================================
mt_result <- final_table %>%
  filter(in_fig1) %>%
  mutate(assembler = factor(assembler, levels = ASSEMBLER_LEVELS))

plot_data <- mt_result %>%
  group_by(assembler) %>%
  summarise(
    n_contigs  = first(n_contigs),
    max_len_kb = first(max_len_kb),
    max_score  = first(max_score),
    sum_genes  = first(sum_genes),
    .groups = "drop"
  )

ggplot(plot_data, aes(x = max_len_kb, y = max_score, color = assembler)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(xintercept = log10(14370/1000), linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_point(aes(size = sum_genes, fill = assembler),
             shape = 21, color = "black",
             stroke = ifelse(plot_data$sum_genes == 15, 2.5, 0.5),
             alpha = 0.8) +
  scale_y_continuous(limits = c(-5, 110), expand = c(0, 0)) +
  scale_x_continuous(
    limits = c(0, 3.47),
    expand = expansion(mult = c(0.02, 0.05)),
    breaks = c(0, 0.7, 1, 1.3, 1.7, 2, 2.3, 2.7, 3, 3.3),
    labels = c("1", "5", "10", "20", "50", "100", "200", "500", "1000", "2000")
  ) +
  scale_size_continuous(range = c(6, 20), name = "Gene count") +
  scale_fill_manual(values = ASSEMBLER_COLORS, name = "Assembler") +
  guides(
    fill = guide_legend(
      override.aes = list(size = 8, alpha = 1, stroke = 0.6, color = "black"),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 16, family = "Helvetica")
    ),
    size = guide_legend(
      override.aes = list(fill = "white", color = "black",
                          stroke = c(0.5, 0.5, 0.5, 2.5), alpha = 1),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 16, family = "Helvetica")
    )
  ) +
  labs(
    title = "*E. cyaneus*",
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

# =============================================================================
# FIGURE 2: E. cyaneus at different coverage depths (4 facets)
# =============================================================================
mt_result <- final_table %>%
  filter(in_fig2) %>%
  mutate(
    assembler       = factor(assembler, levels = ASSEMBLER_LEVELS),
    type_input_data = factor(type_input_data,
                             levels = c("genome", "genome_16p", "genome_10p", "genome_1p"))
  )

plot_data_clean <- mt_result %>%
  group_by(assembler, type_input_data) %>%
  summarise(
    n_contigs  = first(n_contigs),
    max_len_kb = first(max_len_kb),
    max_score  = first(max_score),
    sum_genes  = first(sum_genes),
    .groups = "drop"
  ) %>%
  filter(!is.na(max_len_kb), !is.na(max_score), !is.na(sum_genes),
         !is.na(assembler), !is.na(type_input_data))

# Zero-length points on facet 4 (genome_1p) with callouts
zero_points_facet4 <- plot_data_clean %>%
  filter(type_input_data == "genome_1p", max_len_kb == 0) %>%
  arrange(desc(max_score)) %>%
  mutate(
    label_y    = seq(45, 5, length.out = n()),
    label_x    = 1.75,
    line_x_end = 1.7
  )

ggplot() +
  geom_point(data = plot_data_clean,
             aes(x = max_len_kb, y = max_score, size = sum_genes, fill = assembler),
             shape = 21, color = "black",
             stroke = ifelse(plot_data_clean$sum_genes == 15, 2.5, 0.5),
             alpha = 0.8) +
  geom_segment(data = zero_points_facet4,
               aes(x = max_len_kb, y = max_score, xend = line_x_end, yend = label_y),
               color = "black", linewidth = 0.4, linetype = "solid", alpha = 0.8) +
  geom_segment(data = zero_points_facet4,
               aes(x = line_x_end, y = label_y, xend = label_x, yend = label_y),
               color = "black", linewidth = 0.4, linetype = "solid") +
  geom_text(data = zero_points_facet4,
            aes(x = label_x, y = label_y, label = paste0(assembler, " (", sum_genes, ")")),
            size = 6, color = "black", hjust = 0, vjust = 0.5, show.legend = FALSE) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(xintercept = log10(14370/1000), linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  facet_wrap(~ type_input_data, scales = "free", ncol = 4,
             labeller = labeller(type_input_data = c(
               "genome"     = "Coverage 6× / 166×",
               "genome_16p" = "Coverage 1× / 27×",
               "genome_10p" = "Coverage 0.6× / 17×",
               "genome_1p"  = "Coverage 0.06× / 5×"))) +
  scale_y_continuous(limits = c(-10, 110), expand = c(0, 0)) +
  scale_x_continuous(
    limits = c(-0.1, 3),
    expand = expansion(mult = c(0.01, 0.02)),
    breaks = c(0, 1, 2, 3),
    labels = c("0", "10", "100", "1000")
  ) +
  scale_size_continuous(range = c(5, 15), name = "Gene count") +
  scale_fill_manual(values = ASSEMBLER_COLORS, name = "Assembler") +
  guides(
    fill = guide_legend(
      override.aes = list(size = 8, alpha = 1, stroke = 0.6, color = "black"),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 22, family = "Helvetica")
    ),
    size = guide_legend(
      override.aes = list(fill = "white", color = "black",
                          stroke = c(0.5, 0.5, 0.5, 2.5), alpha = 1),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 18, family = "Helvetica")
    )
  ) +
  labs(x = "Total contig length, kb", y = "Score, %",
       fill = "Assembler", size = "Gene count") +
  theme_ipsum(grid = "XY", axis_title_size = 15) +
  theme(
    legend.position = "bottom",
    legend.box.just = "left",
    legend.direction = "horizontal",
    legend.key.size = unit(1.5, "cm"),
    legend.key.width = unit(1.5, "cm"),
    legend.key.height = unit(1.4, "cm"),
    legend.spacing = unit(2, "cm"),
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
    plot.margin = margin(t = 10, r = 15, b = 5, l = 5)
  )

ggsave("06082026_Fig_2.png", width = 47, height = 18, units = "cm", dpi = 300)

# =============================================================================
# FIGURE 3: DNA (genome) vs RNA (transcriptome) across three species
# =============================================================================
mt_result <- final_table %>%
  filter(in_fig3) %>%
  mutate(assembler = factor(assembler, levels = ASSEMBLER_LEVELS))

plot_data_clean <- mt_result %>%
  group_by(assembler, type_input_data, type_ref_data) %>%
  summarise(
    Species    = first(Species),
    species    = first(species),
    n_contigs  = first(n_contigs),
    max_len_kb = first(max_len_kb),
    max_score  = first(max_score),
    sum_genes  = first(sum_genes),
    data_type  = first(data_type),
    .groups    = "drop"
  ) %>%
  mutate(n_contigs = ifelse(is.na(n_contigs), 0, n_contigs))

hline_data <- hline_data_for(unique(plot_data_clean$species))

# --- Callouts ---

# DNA B. pullus
points_near_intersection <- plot_data_clean %>%
  filter(data_type == "genome", species == "B. pullus",
         abs(max_len_kb - log10(16.284)) < 0.3,
         abs(max_score - 100) < 5) %>%
  arrange(desc(max_score)) %>%
  mutate(label_y = seq(120, 60, length.out = n()),
         label_x = 2.5, line_x_end = 2.45)

# RNA E. cyaneus – successful assemblies
points_near_intersection5 <- plot_data_clean %>%
  filter(data_type == "transcriptome", species == "E. cyaneus",
         abs(max_len_kb - log10(14.370)) < 0.3,
         max_score >= 85, max_score <= 90) %>%
  arrange(desc(max_score)) %>%
  mutate(label_y = seq(105, 95, length.out = n()),
         label_x = 2.8, line_x_end = 2.75)

second_facet_data <- plot_data_clean %>%
  filter(data_type == "genome", species == "E. cyaneus")

target_x2 <- log10(14.370)

points_near_intersection2 <- second_facet_data %>%
  filter(abs(max_len_kb - target_x2) < 0.3,
         abs(max_score - 85) < 10) %>%
  arrange(desc(max_score)) %>%
  mutate(
    label_y    = seq(105, 75, length.out = n()),
    label_x    = 2.8,
    line_x_end = 2.75
  )

# RNA E. cyaneus – zero-length assemblies
points_zero_5 <- plot_data_clean %>%
  filter(data_type == "transcriptome", species == "E. cyaneus", max_len_kb == 0) %>%
  arrange(desc(max_score)) %>%
  mutate(label_y = seq(20, 5, length.out = n()),
         label_x = 2.5, line_x_end = 2.45)

# RNA E. verrucosus – zero-length assemblies
facet6_zero <- plot_data_clean %>%
  filter(data_type == "transcriptome", species == "E. verrucosus", max_len_kb == 0) %>%
  arrange(desc(max_score)) %>%
  mutate(label_y = seq(110, 80, length.out = n()),
         label_x = 2.5, line_x_end = 2.45)

# DNA E. verrucosus – перекрывающиеся GetOrganelle и MitoFinder около score 80
facet5_dna_eve <- plot_data_clean %>%
  filter(data_type == "genome",
         species   == "E. verrucosus",
         assembler %in% c("GetOrganelle", "MitoFinder"),
         abs(max_score - 80) < 10) %>%
  arrange(desc(max_score)) %>%
  mutate(
    label_y    = seq(115, 95, length.out = n()),
    label_x    = 2.5,
    line_x_end = 2.45
  )

ggplot(plot_data_clean, aes(x = max_len_kb, y = max_score, fill = assembler)) +
  geom_point(aes(size = sum_genes),
             shape = 21, color = "black",
             stroke = ifelse(plot_data_clean$sum_genes == 15, 2.5, 0.5),
             alpha = 0.8) +
  make_annotation_layers(points_near_intersection) +
  make_annotation_layers(points_near_intersection5) +
  make_annotation_layers(points_zero_5) +
  make_annotation_layers(facet6_zero) +
  make_annotation_layers(facet5_dna_eve) +
  make_annotation_layers(points_near_intersection2) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(data = hline_data, aes(xintercept = log10(value)),
             linetype = "dashed", color = "gray30", size = 1) +
  facet_grid2(data_type ~ species, scales = "free", axes = "all", remove_labels = "none",
              labeller = labeller(
                data_type = c("genome" = "DNA", "transcriptome" = "RNA"),
                species = c("B. pullus" = "*B. pullus*",
                            "E. cyaneus" = "*E. cyaneus*",
                            "E. verrucosus" = "*E. verrucosus*"))) +
  scale_y_continuous(limits = c(-15, 125), expand = c(0, 0),
                     breaks = c(0, 20, 40, 60, 80, 100)) +
  scale_x_continuous(
    limits = c(-0.2, 4.2),
    expand = expansion(mult = c(0.01, 0.01)),
    breaks = c(0, 0.7, 1.3, 2, 3, 4),
    labels = c("0", "5", "20", "100", "1000", "10000")
  ) +
  scale_size_continuous(range = c(5, 15), name = "Gene count") +
  scale_fill_manual(values = ASSEMBLER_COLORS, name = "Assembler") +
  guides(
    fill = guide_legend(
      override.aes = list(size = 8, alpha = 1, stroke = 0.6, color = "black"),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 22, family = "Helvetica")
    ),
    size = guide_legend(
      override.aes = list(fill = "white", color = "black",
                          stroke = c(0.5, 0.5, 0.5, 2.5), alpha = 1),
      title.position = "top", title.hjust = 0.5,
      label.position = "right",
      label.theme = element_text(size = 22, family = "Helvetica")
    )
  ) +
  labs(x = "Total contig length, kb", y = "Score, %",
       fill = "Assembler", size = "Gene count") +
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

ggsave("17092026_Fig_1_WO_withe.png", width = 45, height = 25, units = "cm", dpi = 300)
ggsave("17092026_Fig_1_WO_withe.svg", width = 45, height = 25, units = "cm", dpi = 300)

# =============================================================================
# FIGURE 4: Effect of seed type – main scatter + 2 bar chart alternatives
# =============================================================================

# ---- Common data prep for Figure 4 (main + bars + supplementary) ----
build_fig4_data <- function(flag) {
  final_table %>%
    filter(.data[[flag]]) %>%
    mutate(
      data_type = "genome",
      species   = factor(species,  levels = SPECIES_LEVELS),
      tipeseed  = factor(tipeseed, levels = SEED_LEVELS),
      assembler = factor(assembler, levels = ASSEMBLER_LEVELS),
      allgenes  = ifelse(sum_genes == 15, "15", "<15")
    ) %>%
    select(assembler, data_type, tipeseed, species,
           n_contigs, max_len_kb, max_score, sum_genes, allgenes) %>%
    distinct()
}

# ---------------------------------------------------------------------------
# 4a. Scatter plot with facet annotations
# ---------------------------------------------------------------------------
plot_data_clean <- build_fig4_data("in_fig4")

hline_data <- hline_data_for(unique(plot_data_clean$species))

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
  if (!is.null(f$exclude)) df <- df %>% filter(!(assembler %in% f$exclude))
  
  df <- df %>% arrange(desc(max_score))
  if (nrow(df) > 0) {
    df <- df %>% mutate(label_y = seq(117, 75, length.out = n()),
                        label_x = 2.55, line_x_end = 2.5)
    points_list[[f$tag]] <- df
  } else {
    points_list[[f$tag]] <- NULL
  }
}

ggplot(plot_data_clean, aes(x = max_len_kb, y = max_score, fill = assembler)) +
  geom_point(aes(size = sum_genes, stroke = ifelse(sum_genes == 15, 2.5, 0.5)),
             shape = 21, color = "black", alpha = 0.8) +
  make_annotation_layers(points_list$f1) +
  make_annotation_layers(points_list$f3) +
  make_annotation_layers(points_list$f5) +
  make_annotation_layers(points_list$f7) +
  make_annotation_layers(points_list$f9) +
  make_annotation_layers(points_list$f11) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(data = hline_data, aes(xintercept = log10(value)),
             linetype = "dashed", color = "gray30", size = 1) +
  facet_grid2(species ~ tipeseed, scales = "free", axes = "all", remove_labels = "none",
              labeller = labeller(
                tipeseed = c("Mitogenome" = "Mitogenome",
                             "Related mitogenome" = "Related mitogenome",
                             "Folmer region COI" = "Folmer region COI",
                             "De novo" = "*De novo*"),
                species = c("B. pullus" = "*B. pullus*",
                            "E. cyaneus" = "*E. cyaneus*",
                            "E. verrucosus" = "*E. verrucosus*"))) +
  scale_y_continuous(limits = c(-20, 125), expand = c(0, 0),
                     breaks = c(0, 20, 40, 60, 80, 100)) +
  scale_x_continuous(limits = c(-0.4, 5.0), expand = expansion(mult = c(0.01, 0.02)),
                     breaks = c(0, 0.7, 1.3, 2, 4),
                     labels = c("0", "5", "20", "100", "10000")) +
  scale_size_continuous(range = c(6, 18), name = "Gene count") +
  scale_fill_manual(values = ASSEMBLER_COLORS, name = "Assembler") +
  guides(
    fill = guide_legend(override.aes = list(size = 10, alpha = 1, stroke = 0.8, color = "black"),
                        title.position = "top", title.hjust = 0.5, label.position = "right",
                        label.theme = element_text(size = 24, family = "Helvetica")),
    size = guide_legend(override.aes = list(fill = "white", color = "black",
                                            stroke = c(0.5, 0.5, 0.5, 2.5), alpha = 1),
                        title.position = "top", title.hjust = 0.5, label.position = "right",
                        label.theme = element_text(size = 24, family = "Helvetica"))
  ) +
  labs(x = "Total contig length, kb", y = "Score, %",
       fill = "Assembler", size = "Gene count") +
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

# ---------------------------------------------------------------------------
# 4b. Bar chart – group by seed (option 1)
# ---------------------------------------------------------------------------
ggplot(plot_data_clean, aes(x = assembler, y = max_score, fill = assembler)) +
  geom_bar(stat = "identity",
           color = ifelse(plot_data_clean$sum_genes == 15, "black", "white")) +
  facet_grid2(species ~ tipeseed, scales = "free", axes = "all", remove_labels = "all",
              labeller = labeller(
                tipeseed = c("Mitogenome" = "Mitogenome",
                             "Related mitogenome" = "Related mitogenome",
                             "Folmer region COI" = "Folmer region COI",
                             "De novo" = "*De novo*"),
                species = c("B. pullus" = "*B. pullus*",
                            "E. cyaneus" = "*E. cyaneus*",
                            "E. verrucosus" = "*E. verrucosus*"))) +
  scale_y_continuous(limits = c(-5, 105), expand = c(0, 0),
                     breaks = c(0, 20, 40, 60, 80, 100)) +
  scale_fill_manual(values = ASSEMBLER_COLORS[1:7], name = "Assembler") +
  labs(x = "Seed type", y = "Score, %", fill = "Assembler") +
  theme_light() +
  theme(
    legend.position = "bottom",
    legend.box = "horizontal", legend.box.just = "left",
    legend.direction = "horizontal",
    legend.key.size = unit(1.8, "cm"),
    legend.key.width = unit(1.8, "cm"),
    legend.key.height = unit(1.6, "cm"),
    legend.spacing = unit(0.3, "cm"), legend.spacing.y = unit(0.3, "cm"),
    legend.margin = margin(t = 8, r = 8, b = 8, l = 8),
    legend.text = element_text(size = 20, family = "Helvetica", margin = margin(l = 6)),
    legend.title = element_text(size = 24, face = "bold", family = "Helvetica", margin = margin(b = 4)),
    strip.text.x = element_markdown(size = 25, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.text.y = element_markdown(size = 25, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.background = element_rect(fill = "gray95", color = "gray60", linewidth = 0.5),
    axis.title.x = element_text(size = 28, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.title.y = element_text(size = 28, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.text.x = element_blank(),
    axis.text.y = element_text(size = 18, family = "Helvetica", color = "black"),
    axis.line.x = element_line(color = "gray60", linewidth = 0.8),
    axis.line.y = element_line(color = "gray60", linewidth = 0.8),
    axis.ticks = element_line(color = "black"),
    panel.spacing = unit(1, "cm"),
    plot.margin = margin(t = 15, r = 40, b = 10, l = 10)
  )

ggsave("Figure_#compare_seeds_alt1.png", width = 45, height = 32, units = "cm", dpi = 300)

# ---------------------------------------------------------------------------
# 4c. Bar chart – group by assembler (option 2)
# ---------------------------------------------------------------------------
ggplot(plot_data_clean, aes(x = tipeseed, y = max_score, fill = assembler)) +
  geom_bar(stat = "identity",
           aes(color = allgenes), linewidth = 1.5) +
  facet_grid2(species ~ assembler, scales = "free", axes = "all", remove_labels = "all",
              labeller = labeller(
                tipeseed = c("Mitogenome" = "Mitogenome",
                             "Related mitogenome" = "Related mitogenome",
                             "Folmer region COI" = "Folmer region COI",
                             "De novo" = "*De novo*"),
                species = c("B. pullus" = "*B. pullus*",
                            "E. cyaneus" = "*E. cyaneus*",
                            "E. verrucosus" = "*E. verrucosus S*"))) +
  geom_text(aes(label = sum_genes), vjust = -0.5, size = 6) +
  scale_y_continuous(limits = c(-5, 125), expand = c(0, 0),
                     breaks = c(0, 20, 40, 60, 80, 100)) +
  scale_fill_manual(values = ASSEMBLER_COLORS[1:7], name = "Assembler", guide = "none") +
  scale_color_manual(values = c("NA", "black"), name = "Gene count") +
  labs(x = "Seed type", y = "Score, %", fill = "Assembler") +
  theme_light() +
  geom_hline(yintercept = 100, linetype = "dashed", color = "grey30", linewidth = 0.8) +
  theme(
    legend.position = "bottom",
    legend.box = "horizontal", legend.box.just = "left",
    legend.direction = "horizontal",
    legend.key.size = unit(1.8, "cm"),
    legend.key.width = unit(1.8, "cm"),
    legend.key.height = unit(1.6, "cm"),
    legend.spacing = unit(0.3, "cm"), legend.spacing.y = unit(0.3, "cm"),
    legend.margin = margin(t = 8, r = 8, b = 8, l = 8),
    legend.text = element_text(size = 20, family = "Helvetica", margin = margin(l = 6)),
    legend.title = element_text(size = 24, face = "bold", family = "Helvetica", margin = margin(b = 4)),
    strip.text.x = element_markdown(size = 25, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.text.y = element_markdown(size = 25, face = "bold", family = "Helvetica", color = "black", hjust = 0.5),
    strip.background = element_rect(fill = "gray95", color = "gray60", linewidth = 0.5),
    axis.title.x = element_text(size = 28, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.title.y = element_text(size = 28, family = "Helvetica", hjust = 0.5, color = "black"),
    axis.text.x = element_text(size = 18, family = "Helvetica", color = "black", angle = -90),
    axis.text.y = element_text(size = 18, family = "Helvetica", color = "black"),
    axis.line.x = element_line(color = "gray60", linewidth = 0.8),
    axis.line.y = element_line(color = "gray60", linewidth = 0.8),
    axis.ticks = element_line(color = "black"),
    panel.spacing = unit(1, "cm"),
    plot.margin = margin(t = 15, r = 40, b = 10, l = 10)
  )

ggsave("Figure_#compare_seeds_alt2.png", width = 60, height = 40, units = "cm", dpi = 300)
ggsave("Figure_#compare_seeds_alt2.svg", width = 60, height = 40, units = "cm")

# ---------------------------------------------------------------------------
# 4d. Supplementary version – includes "Related mitogenome" facet annotations
# ---------------------------------------------------------------------------
plot_data_clean <- build_fig4_data("in_fig4_suppl")

hline_data <- hline_data_for(unique(plot_data_clean$species))

target_facets <- list(
  list(species = "B. pullus", tipeseed = "Mitogenome",
       value = 16.284, tag = "f1", score_min = 80, score_max = 100,
       x_condition = "around", exclude = NULL),
  list(species = "B. pullus", tipeseed = "Folmer region COI",
       value = 16.284, tag = "f3", score_min = 80, score_max = 100,
       x_condition = "around", exclude = NULL),
  list(species = "B. pullus", tipeseed = "Related mitogenome",
       value = 0, tag = "f2", score_min = 0, score_max = 0,
       x_condition = "exact", exclude = NULL),
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
  target_x <- if (f$x_condition == "exact") f$value else log10(f$value)
  df <- plot_data_clean %>%
    filter(species == f$species, tipeseed == f$tipeseed) %>%
    filter(max_score >= f$score_min & max_score <= f$score_max)
  
  if (f$x_condition == "around") {
    df <- df %>% filter(abs(max_len_kb - target_x) < threshold_x)
  } else if (f$x_condition == "left") {
    df <- df %>% filter(max_len_kb <= target_x + 0.3)
  } else if (f$x_condition == "exact") {
    df <- df %>% filter(max_len_kb == target_x)
  }
  if (!is.null(f$exclude)) df <- df %>% filter(!(assembler %in% f$exclude))
  
  df <- df %>% arrange(desc(max_score))
  if (nrow(df) > 0) {
    df <- df %>% mutate(label_y = seq(117, 75, length.out = n()),
                        label_x = 2.55, line_x_end = 2.5)
    points_list[[f$tag]] <- df
  } else {
    points_list[[f$tag]] <- NULL
  }
}

# Zero-length facet 2: labels below axis
if (!is.null(points_list$f2)) {
  n <- nrow(points_list$f2)
  points_list$f2$label_x    <- 2.55
  points_list$f2$line_x_end <- 2.5
  points_list$f2$label_y    <- seq(20, -10, length.out = n)
}

ggplot(plot_data_clean, aes(x = max_len_kb, y = max_score, fill = assembler)) +
  geom_point(aes(size = sum_genes, stroke = ifelse(sum_genes == 15, 2.5, 0.5)),
             shape = 21, color = "black", alpha = 0.8) +
  make_annotation_layers(points_list$f1) +
  make_annotation_layers(points_list$f2) +
  make_annotation_layers(points_list$f3) +
  make_annotation_layers(points_list$f5) +
  make_annotation_layers(points_list$f7) +
  make_annotation_layers(points_list$f9) +
  make_annotation_layers(points_list$f11) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray30", linewidth = 0.8, alpha = 1) +
  geom_vline(data = hline_data, aes(xintercept = log10(value)),
             linetype = "dashed", color = "gray30", size = 1) +
  facet_grid2(species ~ tipeseed, scales = "free", axes = "all", remove_labels = "none",
              labeller = labeller(
                tipeseed = c("Mitogenome" = "Mitogenome",
                             "Related mitogenome" = "Related mitogenome",
                             "Folmer region COI" = "Folmer region COI",
                             "De novo" = "*De novo*"),
                species = c("B. pullus" = "*B. pullus*",
                            "E. cyaneus" = "*E. cyaneus*",
                            "E. verrucosus" = "*E. verrucosus S*"))) +
  scale_y_continuous(limits = c(-20, 125), expand = c(0, 0),
                     breaks = c(0, 20, 40, 60, 80, 100)) +
  scale_x_continuous(limits = c(-0.4, 5.0), expand = expansion(mult = c(0.01, 0.02)),
                     breaks = c(0, 0.7, 1.3, 2, 4),
                     labels = c("0", "5", "20", "100", "10000")) +
  scale_size_continuous(range = c(6, 18), name = "Gene count") +
  scale_fill_manual(values = ASSEMBLER_COLORS, name = "Assembler") +
  guides(
    fill = guide_legend(override.aes = list(size = 10, alpha = 1, stroke = 0.8, color = "black"),
                        title.position = "top", title.hjust = 0.5, label.position = "right",
                        label.theme = element_text(size = 24, family = "Helvetica")),
    size = guide_legend(override.aes = list(fill = "white", color = "black",
                                            stroke = c(0.5, 0.5, 0.5, 2.5), alpha = 1),
                        title.position = "top", title.hjust = 0.5, label.position = "right",
                        label.theme = element_text(size = 24, family = "Helvetica"))
  ) +
  labs(x = "Total contig length, kb", y = "Score, %",
       fill = "Assembler", size = "Gene count") +
  theme_ipsum(grid = "XY", axis_title_size = 18) +
  theme(
    legend.position = "right",
    legend.box = "vertical", legend.box.just = "left",
    legend.direction = "vertical",
    legend.key.size = unit(1.8, "cm"),
    legend.key.width = unit(1.8, "cm"),
    legend.key.height = unit(1.6, "cm"),
    legend.spacing = unit(0.3, "cm"), legend.spacing.y = unit(0.3, "cm"),
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

ggsave("06082026_figure_3.png", width = 55, height = 32, units = "cm", dpi = 300)

# =============================================================================
# FIGURE 5: Computational performance (time and memory)
# =============================================================================
plot_data_clean <- final_table %>%
  filter(in_fig5) %>%
  mutate(
    data_type = "genome",
    species   = factor(species,  levels = SPECIES_LEVELS),
    tipeseed  = factor(tipeseed, levels = SEED_LEVELS),
    assembler = factor(assembler, levels = ASSEMBLER_LEVELS)
  ) %>%
  select(assembler, data_type, tipeseed, species,
         Time, Memory, max_score, sum_genes) %>%
  distinct()

ggplot(plot_data_clean, aes(x = Time, y = Memory, fill = assembler)) +
  geom_point(data = subset(plot_data_clean,
                           tipeseed %in% c("Mitogenome", "Related mitogenome", "Folmer region COI")),
             size = 6, shape = 23, color = "black", alpha = 0.8,
             position = position_jitter(width = 0.06, height = 0.4)) +
  geom_point(data = subset(plot_data_clean, tipeseed == "De novo"),
             size = 6, shape = 23, color = "black", alpha = 0.8) +
  scale_y_continuous(limits = c(-2, 32)) +
  scale_x_continuous(limits = c(-0.5, 12.5)) +
  facet_grid2(species ~ tipeseed, scales = "free", axes = "all", remove_labels = "none",
              labeller = labeller(
                tipeseed = c("Mitogenome" = "Mitogenome",
                             "Related mitogenome" = "Related mitogenome",
                             "Folmer region COI" = "Folmer region COI",
                             "De novo" = "*De novo*"),
                species = c("B. pullus" = "*B. pullus*",
                            "E. cyaneus" = "*E. cyaneus*",
                            "E. verrucosus" = "*E. verrucosus*"))) +
  scale_fill_manual(values = ASSEMBLER_COLORS, name = "Assembler") +
  guides(fill = guide_legend(
    override.aes = list(size = 10, alpha = 1, stroke = 0.8, color = "black"),
    title.position = "top", title.hjust = 0.5, label.position = "right",
    label.theme = element_text(size = 28, family = "Helvetica")
  )) +
  labs(x = "Run-time, h", y = "Resident Set Size, Gb", fill = "Assembler") +
  theme_ipsum(grid = "XY", axis_title_size = 18) +
  theme(
    legend.position = "right",
    legend.box = "vertical", legend.box.just = "left",
    legend.direction = "vertical",
    legend.key.size = unit(1.8, "cm"),
    legend.key.width = unit(1.8, "cm"),
    legend.key.height = unit(1.6, "cm"),
    legend.spacing = unit(0.3, "cm"), legend.spacing.y = unit(0.3, "cm"),
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





# ---- 1. Read data ----
max_contigs <- read.csv("all_max_contigs.csv", stringsAsFactors = FALSE, check.names = FALSE)
big         <- read.xlsx("all_table_nG_full.xlsx", sheet = 1)

cat("max_contigs:", nrow(max_contigs), "rows\n")
cat("big:        ", nrow(big), "rows\n\n")

# ---- 2. Normalize assembler names ----
normalize_assembler <- function(x) {
  x <- trimws(as.character(x))
  recode(x,
         "Getorganel" = "GetOrganelle",
         "mitobim"    = "MITObim",
         "Mitofinder" = "MitoFinder",
         "Mitoz"      = "MitoZ",
         "mtgrasp"    = "mtGrasp",
         .default     = x
  )
}
max_contigs$assembler <- normalize_assembler(max_contigs$assembler)
big$assembler         <- normalize_assembler(big$assembler)

# ---- 3. Coerce key columns to character ----
key_cols <- c("assembler", "type_input_data", "type_ref_data")

max_contigs <- max_contigs %>% mutate(across(all_of(key_cols), ~ trimws(as.character(.x))))
big         <- big         %>% mutate(across(all_of(key_cols), ~ trimws(as.character(.x))))

# ---- 4. Recode max_contigs to match big nomenclature ----
max_contigs <- max_contigs %>%
  mutate(
    type_input_data = recode(type_input_data,
                             "genome_our_rna" = "transcriptome_our"
    ),
    type_ref_data = recode(type_ref_data,
                           "full_COI_EveS_EveS"    = "full_COI_EveS",
                           "part_COI_EveS_EveS"    = "part_COI_EveS",
                           "full_mt_genom_Eve_Eve" = "full_mt_genom_EveS_EveS",
                           "full_mt_genom_Eve_Ecy" = "full_mt_genom_EveS_Ecy",
                           "full_COI_Eve_Eve"      = "full_COI_EveS",
                           "part_COI_Eve_Eve"      = "part_COI_EveS"
    )
  )

# ---- 5. Prepare table for join ----
max_join <- max_contigs %>%
  select(assembler, type_input_data, type_ref_data, MaxContigLength) %>%
  distinct(assembler, type_input_data, type_ref_data, .keep_all = TRUE)

# ---- 6. Merge ----
merged <- big %>%
  left_join(max_join, by = c("assembler", "type_input_data", "type_ref_data"))

cat("Matched:", sum(!is.na(merged$MaxContigLength)), "\n")
cat("No pair: ", sum(is.na(merged$MaxContigLength)), "\n\n")

if (sum(is.na(merged$MaxContigLength)) > 0) {
  cat("Unmatched by type_input_data:\n")
  merged %>% filter(is.na(MaxContigLength)) %>%
    count(type_input_data, sort = TRUE) %>% print()
}

# ---- 7. Save CSV ----
write.csv(merged, "all_table_nG_full_with_max_contig.csv", row.names = FALSE)

# ---- 8. Save XLSX with filter and frozen header ----
wb <- createWorkbook()
addWorksheet(wb, "results")
writeData(wb, "results", merged)
setColWidths(wb, "results", cols = 1:ncol(merged), widths = "auto")
freezePane(wb, "results", firstRow = TRUE)
addFilter(wb, "results", row = 1, cols = 1:ncol(merged))
saveWorkbook(wb, "all_table_nG_full_with_max_contig.xlsx", overwrite = TRUE)

cat("\nDone:\n  all_table_nG_full_with_max_contig.csv\n  all_table_nG_full_with_max_contig.xlsx\n")
