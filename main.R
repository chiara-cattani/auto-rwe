# =============================================================================
# main.R  —  AutoRWE Platform: End-to-End Demonstration
#
# Run this file from the project root to execute the full prototype pipeline.
# Set your working directory to the AutoRWE folder first:
#   setwd("C:/Users/chiar/Desktop/AutoRWE")
#
# Steps:
#   0. Install / check dependencies
#   1. Source all layers
#   2. Simulate study data (run once)
#   3. Load metadata
#   4. Extract endpoint data (per study)
#   5. Run descriptive analysis
#   6. Run treatment comparison
#   7. Aggregate across studies
#   8. Subgroup analysis
#   9. Generate outputs (table, plot, narrative)
#  10. (Optional) Launch Shiny app
# =============================================================================

# =============================================================================
# 0. Dependencies
# =============================================================================

required_pkgs <- c(
  "dplyr", "tidyr", "readr", "stringr", "purrr",
  "ggplot2", "broom", "shiny"
)
optional_pkgs <- c("gt", "knitr", "rstudioapi")

to_install <- setdiff(required_pkgs, rownames(installed.packages()))
if (length(to_install) > 0) {
  message("Installing missing packages: ", paste(to_install, collapse = ", "))
  install.packages(to_install, repos = "https://cloud.r-project.org")
}

# =============================================================================
# 1. Source all layers (order matters: lower layers first)
# =============================================================================

source("R/simulate_data.R")         # Layer 0: data generation (prototype only)
source("R/01_data_loading.R")       # Layer 1: load_study(), get_dataset()
source("R/02_metadata.R")           # Layer 2: metadata tables + rule parser
source("R/03_endpoint_extraction.R")# Layer 3: get_endpoint_data()
source("R/04_analysis.R")           # Layer 4: analyze_*, compare_*, detect_*
source("R/05_aggregation.R")        # Layer 5: run_across_studies()
source("R/06_output.R")             # Layer 6: table, plot, narrative
source("R/07_shiny_app.R")          # Layer 7: Shiny app (loaded but not started)
source("R/08_ai_narrative.R")       # Layer 8: AI narrative (Claude API)

cat("\n", strrep("=", 65), "\n")
cat("   AutoRWE Platform — Prototype Demo\n")
cat(strrep("=", 65), "\n\n")

# =============================================================================
# 2. Generate synthetic study data (skip if already done)
# =============================================================================

cat("--- Step 2: Simulating study data (9 studies, 3 therapeutic areas)...\n")
simulate_all_studies(base_dir = ".")

# =============================================================================
# 3. Load metadata
# =============================================================================

cat("\n--- Step 3: Loading metadata...\n")
meta <- load_metadata(base_dir = ".")

cat(sprintf("  Studies in catalog     : %d\n", nrow(meta$study_catalog)))
cat(sprintf("  Endpoint mappings      : %d\n", nrow(meta$endpoint_mapping)))
cat(sprintf("  Visit mappings         : %d\n", nrow(meta$visit_mapping)))

# =============================================================================
# 4. Endpoint extraction — single study demo
# =============================================================================

cat("\n--- Step 4: Endpoint extraction (study1, digestive_health)...\n")

ep_study1 <- get_endpoint_data(
  study_id        = "activia_eu_01",
  analysis_family = "digestive_health",
  endpoint_role   = "primary_endpoint",
  base_dir        = "."
)

cat(sprintf("  Rows extracted: %d\n", nrow(ep_study1)))
cat("  Column names  :", paste(names(ep_study1), collapse = ", "), "\n")
cat("  Treatment arms:", paste(unique(ep_study1$treatment), collapse = ", "), "\n")
cat("  Subgroup levels:", paste(unique(ep_study1$subgroup), collapse = ", "), "\n")

# =============================================================================
# 5. Descriptive analysis
# =============================================================================

cat("\n--- Step 5: Descriptive statistics (study1)...\n")
desc_study1 <- analyze_endpoint(ep_study1)
print(desc_study1)

# =============================================================================
# 6. Treatment comparison (single study)
# =============================================================================

cat("\n--- Step 6: Treatment comparison (study1)...\n")
comp_study1 <- compare_treatment(ep_study1)
cat(sprintf(
  "  Diff: %.2f  95%% CI: [%.2f, %.2f]  p=%.4f\n",
  comp_study1$treatment_diff,
  comp_study1$ci_lower,
  comp_study1$ci_upper,
  comp_study1$p_value
))

sig_study1 <- detect_signal(ep_study1)
cat(sprintf(
  "  Cohen's d: %.2f  Direction: %s  Strength: %s  Sig: %s\n",
  sig_study1$cohens_d,
  sig_study1$direction,
  sig_study1$strength_label,
  sig_study1$significance
))

# =============================================================================
# 7. Aggregate across studies — evidence object
# =============================================================================

cat("\n--- Step 7: Aggregating across studies...\n")

study_list <- c("activia_eu_01", "actimel_asia_02", "danone_elderly_03")

results <- run_across_studies(
  analysis_family = "digestive_health",
  study_list      = study_list,
  endpoint_role   = "primary_endpoint",
  base_dir        = "."
)

cat("\nEvidence object (primary columns):\n")
print(results %>% dplyr::select(
  study_id, product, endpoint, treatment_diff,
  ci_lower, ci_upper, p_value, cohens_d,
  direction, strength_label, significance, confidence_flag
))

# =============================================================================
# 8. Subgroup analysis across studies
# =============================================================================

cat("\n--- Step 8: Subgroup analysis...\n")

subgroup_results <- run_subgroup_analysis(
  analysis_family = "digestive_health",
  study_list      = study_list,
  subgroup_var    = "subgroup",
  endpoint_role   = "primary_endpoint",
  base_dir        = "."
)

cat(sprintf(
  "  Subgroup rows: %d | Levels: %s\n",
  nrow(subgroup_results),
  paste(unique(subgroup_results$subgroup_level), collapse = ", ")
))

# =============================================================================
# 9. Generate outputs
# =============================================================================

cat("\n--- Step 9: Generating outputs...\n")

# 9a. Summary table (plain text)
cat("\n[Summary Table]\n")
print(generate_summary_table(results, format = "kable"))

# 9b. Forest plot
cat("\n[Forest Plot] Saving to output/forest_plot.png\n")
dir.create("output", showWarnings = FALSE)
forest_p <- plot_effects(results)
ggplot2::ggsave("output/forest_plot.png", forest_p,
                width = 10, height = 5, dpi = 150)
cat("  Saved: output/forest_plot.png\n")

# 9c. Subgroup plot
if (nrow(subgroup_results) > 0) {
  cat("\n[Subgroup Plot] Saving to output/subgroup_plot.png\n")
  sub_p <- plot_subgroups(subgroup_results)
  ggplot2::ggsave("output/subgroup_plot.png", sub_p,
                  width = 10, height = 7, dpi = 150)
  cat("  Saved: output/subgroup_plot.png\n")
}

# 9d. Text narrative
cat("\n[Evidence Narrative]\n\n")
cat(generate_text_summary(results))
cat("\n")

# =============================================================================
# 10. Launch Shiny app (optional — comment in to run)
# =============================================================================

cat("\n", strrep("=", 65), "\n")
cat("  Demo complete.\n")
cat("  To launch the interactive Shiny app, run:\n")
cat("    launch_app()\n")
cat(strrep("=", 65), "\n\n")

# Uncomment to launch immediately:
 launch_app()
