# =============================================================================
# FIGURE X: statistics to start discussion
# =============================================================================

library(ggpubr)
library(ggeasy)
library(hrbrthemes)
library(ggtext)

## this is duplicated
ASSEMBLER_LEVELS <- c("ARC", "GetOrganelle", "MITGARD", "MITObim", "MitoFinder",
                      "mtGrasp", "NOVOplasty", "MEANGS", "MitoZ", "Norgal")

ASSEMBLER_COLORS <- c(
  "#E69F00", "#56B4E9", "#009E73", "#CC79A7", "#0072B2",
  "#D55E00", "#F0E442", "#999999", "#882255", "#661100"
)
##

custom_theme <- theme_ipsum(grid = "XY", axis_title_size = 18) +
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

final_table <- read.csv("all_table_nG_full_with_max_contig.csv")

# Kept for compatibility with the rest of the script
all_table_nG_new <- final_table
#all_table_nG_new <- read.csv("all_table_nG.csv")


## DNA and RNA
final_table %>% mutate(assembler = factor(assembler, levels = ASSEMBLER_LEVELS)) %>%
  mutate(
  for_comparison = (## Ecy & Bpu DNA
                    type_input_data == "genome_3x" &
                    type_ref_data %in% c("full_mt_genom_Ecy", "full_mt_genom_Eve", "part_COI_Ecy", "de_novo",
                                        "full_mt_genom_Bpul", "full_mt_genom_Bpul_Eve", "part_COI_Bpul", "de_novo_Bpul")) |
                    ## Eve DNA    
                    (type_input_data == "genome" &
                           type_ref_data %in% c("full_mt_genom_EveS_EveS", "full_mt_genom_EveS_Ecy",
                          "part_COI_EveS", "de_novo_EveS")) | 
                    ## Ecy RNA
                  (type_input_data == "transcriptome" &
                     species == "E. cyaneus")
#                     type_ref_data %in% c("full_mt_genom_EveS_EveS", "full_mt_genom_EveS_Ecy",
#                                          "part_COI_EveS", "de_novo_EveS")) | 
                    ) -> final_table

final_table %>% dplyr::filter(for_comparison) -> plot_data_violins

pRSS <- 
  ggplot(plot_data_violins, aes(x = assembler, y = Memory)) + 
  geom_violin(scale = "width", 
              #quantile.linetype = "solid", quantile.colour = "red", quantiles=0.5,
              aes(col=assembler)) + 
  geom_jitter(width = 0.1, alpha=.5, height = 0,
              aes(shape = data_type), fill="lightgrey") + 
  theme_ipsum(grid = "XY", axis_title_size = 15) + 
  scale_color_manual(values=ASSEMBLER_COLORS, guide='none') + 
  scale_shape_manual(values=c("circle", "asterisk")) + 
  scale_y_reverse() + 
  geom_vline(xintercept = 7.5, linetype = "dashed") + 
  xlab("Assembler") + ylab("Resident set size, Gb") + 
  #custom_theme + 
  theme(axis.title.x = element_text(hjust = 0.5), axis.title.y = element_text(hjust = 0.5),
        legend.position = "bottom")
#ggsave("RSS.png", width = 24, height=12, units="cm")

pTime <- 
  ggplot(plot_data_violins, aes(x = assembler, y = Time)) + 
  geom_violin(scale = "width", 
              #quantile.linetype = "solid", quantile.colour = "red", quantiles=0.5,
              aes(col=assembler)) + 
  geom_jitter(width = 0.1, alpha=.5, height = 0,
              aes(shape = data_type), fill="lightgrey") + 
  theme_ipsum(grid = "XY", axis_title_size = 15) + 
  scale_color_manual(values=ASSEMBLER_COLORS, guide='none') + 
  scale_shape_manual(values=c("circle", "asterisk")) + 
  scale_y_reverse() + 
  geom_vline(xintercept = 7.5, linetype = "dashed") + 
  xlab("Assembler") + ylab("Time, h") + 
  #custom_theme + 
  theme(axis.title.x = element_text(hjust = 0.5), axis.title.y = element_text(hjust = 0.5),
        legend.position = "bottom") 
pRSS

ggarrange(pRSS + easy_remove_x_axis(), pTime, ncol=1, heights=c(1, 1.5),
          common.legend = TRUE, legend = "bottom")

ggsave("resources.png", width = 24, height=18, units="cm")
ggsave("resources.svg", width = 24, height=18, units="cm")


## DNA only 
plot_data_violins %>% dplyr::filter(data_type == "genome") -> plot_data_violins_DNA

pScores <- 
  ggplot(plot_data_violins_DNA, aes(x = assembler, y = score)) + 
  geom_violin(scale = "width", quantile.linetype = "solid", 
              quantile.colour = "red", quantiles=0.5,
              aes(col=assembler)) + 
  geom_jitter(width = 0.1, alpha=.5, height = 0,
              shape="circle", fill="lightgrey") + 
  theme_ipsum(grid = "XY", axis_title_size = 15) + 
  scale_color_manual(values=ASSEMBLER_COLORS, guide='none') + 
  geom_vline(xintercept = 7.5, linetype = "dashed") + 
  xlab("Assembler") + ylab("Score") + 
  theme(axis.title.x = element_text(hjust = 0.5), axis.title.y = element_text(hjust = 0.5),
        legend.position = "bottom")
#ggsave("assemblers_total_score_comparison.png", width = 24, height=12, units="cm")

pGenes <- 
  ggplot(plot_data_violins_DNA, aes(x = assembler, y = genes)) + 
  geom_violin(scale = "width", quantile.linetype = "solid", 
              quantile.colour = "red", quantiles=0.5,
              aes(col=assembler)) + 
  geom_jitter(width = 0.1, alpha=.5, height = 0,
              shape="circle", fill="lightgrey") + 
  theme_ipsum(grid = "XY", axis_title_size = 15) + 
  scale_color_manual(values=ASSEMBLER_COLORS, guide='none') + 
  #scale_shape_manual(values=c("circle", "asterisk")) + 
  geom_vline(xintercept = 7.5, linetype = "dashed") + 
  xlab("Assembler") + ylab("Number of genes") + 
  theme(axis.title.x = element_text(hjust = 0.5), axis.title.y = element_text(hjust = 0.5),
        legend.position = "bottom")


plot_data_violins_DNA$ref_length <- NA
plot_data_violins_DNA[plot_data_violins_DNA$species == "E. cyaneus", "ref_length" ] <- 14370
plot_data_violins_DNA[plot_data_violins_DNA$species == "E. verrucosus", "ref_length" ] <- 15601
plot_data_violins_DNA[plot_data_violins_DNA$species == "B. pullus", "ref_length" ] <- 16284

plot_data_violins_DNA$RelMaxContig <- 
  (plot_data_violins_DNA$MaxContigLength - plot_data_violins_DNA$ref_length) / 
  plot_data_violins_DNA$ref_length * 100

ggarrange(pScores, pGenes, ncol=1)
ggsave("scores.png", width = 24, height=18, units="cm")
ggsave("scores.svg", width = 24, height=18, units="cm")

pLargestContig <- 
  ggplot(plot_data_violins_DNA, aes(x = assembler, y = RelMaxContig)) + 
  geom_violin(scale = "width", quantile.linetype = "solid", 
              quantile.colour = "red", quantiles=0.5,
              aes(col=assembler)) + 
  geom_jitter(width = 0.1, alpha=.5, height = 0,
              shape="circle", fill="lightgrey") + 
  theme_ipsum(grid = "XY", axis_title_size = 15) + 
  scale_color_manual(values=ASSEMBLER_COLORS, guide='none') + 
  #scale_shape_manual(values=c("circle", "asterisk")) + 
  geom_vline(xintercept = 7.5, linetype = "dashed") + 
  xlab("Assembler") + ylab("Deviation from reference length, %") + 
  theme(axis.title.x = element_text(hjust = 0.5), axis.title.y = element_text(hjust = 0.5),
        legend.position = "bottom")
pLargestContig
ggsave("Deviation from reference length.png", width = 24, height=18, units="cm")



plot_data_violins_DNA$ref_length <- NA
plot_data_violins_DNA[plot_data_violins_DNA$species == "E. cyaneus", "ref_length" ] <- 14370
plot_data_violins_DNA[plot_data_violins_DNA$species == "E. verrucosus", "ref_length" ] <- 15601
plot_data_violins_DNA[plot_data_violins_DNA$species == "B. pullus", "ref_length" ] <- 16284