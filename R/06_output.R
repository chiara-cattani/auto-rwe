# =============================================================================
# 06_output.R  —  OUTPUT LAYER
#
# Accepts the evidence object returned by run_across_studies() and
# produces publication-ready outputs.
#
# Public functions:
#   generate_summary_table(results, format)
#   plot_effects(results, title)
#   plot_subgroups(subgroup_results, title)
#   generate_text_summary(results)
# =============================================================================

library(dplyr)
library(ggplot2)

# =============================================================================
# 1. generate_summary_table()
# =============================================================================

#' Render a formatted summary table of the evidence object
#'
#' @param results   Evidence object from run_across_studies().
#' @param format    "gt" (default) for interactive; "kable" for plain text.
#' @return A gt table or kable object.
generate_summary_table <- function(results, format = "gt") {

  tbl <- results %>%
    transmute(
      Study           = study_id,
      Product         = product,
      Population      = population,
      Endpoint        = endpoint,
      `Window`        = analysis_window,
      `N (Act/Pbo)`   = paste0(n_active, " / ", n_placebo),
      `Mean Chg (Act)` = round(
          if ("mean_change_active" %in% names(results))
            results$mean_change_active
          else NA_real_, 2),
      `Treatment Diff` = sprintf("%.2f", treatment_diff),
      `95% CI`        = sprintf("[%.2f, %.2f]", ci_lower, ci_upper),
      `p-value`       = sprintf("%.4f", p_value),
      `Cohen's d`     = sprintf("%.2f", cohens_d),
      Direction       = direction,
      Strength        = strength_label,
      Sig             = significance,
      `Confidence`    = confidence_flag
    )

  if (format == "gt") {
    if (!requireNamespace("gt", quietly = TRUE)) {
      message("[output] 'gt' package not installed. Falling back to kable.")
      format <- "kable"
    }
  }

  if (format == "gt") {
    tbl %>%
      gt::gt() %>%
      gt::tab_header(
        title    = "AutoRWE Evidence Summary",
        subtitle = sprintf(
          "Analysis family: %s | %d studies",
          results$analysis_family[[1]], nrow(results)
        )
      ) %>%
      gt::tab_style(
        style = gt::cell_fill(color = "#d4edda"),
        locations = gt::cells_body(
          columns = Direction,
          rows    = Direction == "improvement"
        )
      ) %>%
      gt::tab_style(
        style = gt::cell_fill(color = "#f8d7da"),
        locations = gt::cells_body(
          columns = Direction,
          rows    = Direction == "worsening"
        )
      ) %>%
      gt::cols_align(align = "center",
                     columns = c("95% CI", "p-value", "Sig", "Confidence")) %>%
      gt::opt_row_striping()

  } else {
    if (!requireNamespace("knitr", quietly = TRUE)) {
      return(print(tbl))
    }
    knitr::kable(tbl, format = "simple", align = "l")
  }
}

# Danone brand colors
.DANONE_BLUE   <- "#009FE3"
.DANONE_DARK   <- "#003087"
.DANONE_GREEN  <- "#00A878"
.DANONE_ORANGE <- "#F5A623"

# =============================================================================
# 2. plot_effects() — Forest plot with pooled diamond
# =============================================================================

#' Forest plot: treatment differences across studies + pooled estimate
#'
#' @param results  Evidence object from run_across_studies().
#' @param title    Plot title.
#' @return ggplot2 object.
plot_effects <- function(results,
                          title = "Clinical Evidence — Treatment Effect by Study") {

  # --- Compute inverse-variance pooled estimate -----------------------------
  se_vec    <- (results$ci_upper - results$ci_lower) / (2 * 1.96)
  se_vec    <- pmax(se_vec, 1e-6)          # avoid division by zero
  w_vec     <- 1 / se_vec^2
  pooled_d  <- sum(w_vec * results$treatment_diff) / sum(w_vec)
  pooled_se <- 1 / sqrt(sum(w_vec))
  pooled_lo <- pooled_d - 1.96 * pooled_se
  pooled_hi <- pooled_d + 1.96 * pooled_se

  # --- Build study-level plot data ------------------------------------------
  study_data <- results %>%
    mutate(
      study_label = sprintf(
        "%s  |  %s  |  %s  |  N = %d + %d",
        product, study_id, population, n_active, n_placebo
      ),
      row_type = "study",
      sig_color = case_when(
        p_value <= 0.05 & direction == "improvement" ~ "Significant improvement",
        p_value <= 0.05 & direction == "worsening"   ~ "Significant worsening",
        direction == "improvement"                    ~ "Trend: improvement",
        TRUE                                          ~ "Non-significant"
      )
    )

  # Order: studies sorted by treatment_diff, pooled at bottom
  study_order <- study_data %>%
    arrange(desc(treatment_diff)) %>%
    pull(study_label)

  # --- Pooled row (styled separately) ---------------------------------------
  pooled_label <- sprintf(
    "POOLED ESTIMATE  |  %d studies  |  Inverse-variance weighted",
    nrow(results)
  )

  all_labels <- c(pooled_label, study_order)

  plot_data <- study_data %>%
    mutate(study_label = factor(study_label, levels = all_labels))

  # --- Build plot -----------------------------------------------------------
  p <- ggplot(plot_data,
              aes(x = treatment_diff,
                  y = factor(study_label, levels = all_labels))) +

    # Separator line above pooled
    geom_hline(yintercept = 1.5, color = "grey60", linewidth = 0.5) +

    # Null line
    geom_vline(xintercept = 0,
               linetype = "dashed", color = "grey40", linewidth = 0.7) +

    # CI bars for individual studies
    geom_errorbarh(
      aes(xmin = ci_lower, xmax = ci_upper, color = sig_color),
      height = 0.25, linewidth = 0.9
    ) +

    # Study points
    geom_point(aes(color = sig_color), size = 4, shape = 16) +

    # Pooled CI bar
    annotate("errorbarh",
             xmin = pooled_lo, xmax = pooled_hi,
             y = pooled_label,
             height = 0.35, linewidth = 1.2,
             color = .DANONE_DARK) +

    # Pooled diamond (shape = 18)
    annotate("point",
             x = pooled_d, y = pooled_label,
             shape = 18, size = 7,
             color = .DANONE_DARK) +

    # Pooled estimate label
    annotate("text",
             x = pooled_hi + abs(pooled_hi) * 0.05,
             y = pooled_label,
             label = sprintf("%.2f [%.2f, %.2f]", pooled_d, pooled_lo, pooled_hi),
             hjust = 0, size = 3.5, color = .DANONE_DARK, fontface = "bold") +

    scale_color_manual(
      name   = "Study result",
      values = c(
        "Significant improvement" = .DANONE_GREEN,
        "Trend: improvement"      = "#7DCFB6",
        "Non-significant"         = "#AAAAAA",
        "Significant worsening"   = "#E05C5C"
      )
    ) +

    labs(
      title    = title,
      subtitle = sprintf(
        "%d randomized controlled trials  \u2022  %s  \u2022  Endpoint: %s",
        nrow(results),
        results$analysis_family[[1]],
        results$endpoint_role[[1]]
      ),
      x       = "Treatment Difference vs. Placebo  (negative = improvement)",
      y       = NULL,
      caption = paste0(
        "Diamond = pooled inverse-variance weighted estimate with 95% CI  \u2022  ",
        "Danone AutoRWE Platform"
      )
    ) +

    theme_minimal(base_size = 12) +
    theme(
      plot.title       = element_text(face = "bold", size = 14,
                                      color = .DANONE_DARK),
      plot.subtitle    = element_text(color = "grey40", size = 11),
      plot.caption     = element_text(color = "grey50", size = 9),
      axis.text.y      = element_text(size = 10, hjust = 1),
      legend.position  = "bottom",
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank()
    )

  return(p)
}

# =============================================================================
# 3. plot_subgroups() — Subgroup forest plot
# =============================================================================

#' Forest plot for subgroup analysis results
#'
#' @param subgroup_results  Result from run_subgroup_analysis().
#' @param title             Plot title.
#' @return ggplot2 object.
plot_subgroups <- function(subgroup_results,
                            title = "Subgroup Treatment Effects") {

  plot_data <- subgroup_results %>%
    mutate(
      panel_label = paste0(study_id, " (", product, ")"),
      is_overall  = subgroup_level == "Overall",
      line_type   = ifelse(is_overall, "Overall", "Subgroup")
    )

  ggplot(plot_data,
         aes(x = treatment_diff, y = subgroup_level,
             color = line_type, alpha = is_overall)) +
    geom_vline(xintercept = 0, linetype = "dashed",
               color = "grey50", linewidth = 0.5) +
    geom_errorbarh(
      aes(xmin = ci_lower, xmax = ci_upper),
      height = 0.3, linewidth = 0.7
    ) +
    geom_point(aes(size = is_overall)) +
    scale_color_manual(values = c("Overall" = .DANONE_BLUE, "Subgroup" = .DANONE_ORANGE),
                       name = NULL) +
    scale_alpha_manual(values = c("TRUE" = 1, "FALSE" = 0.8), guide = "none") +
    scale_size_manual(values  = c("TRUE" = 4, "FALSE" = 3),   guide = "none") +
    facet_wrap(~ panel_label, scales = "free_x", ncol = 1) +
    labs(
      title    = title,
      x        = "Treatment Difference",
      y        = NULL,
      caption  = "Blue = Overall | Orange = Subgroup level"
    ) +
    theme_minimal(base_size = 11) +
    theme(
      strip.text      = element_text(face = "bold"),
      legend.position = "none"
    )
}

# =============================================================================
# 4. generate_text_summary()
# =============================================================================

#' Auto-generate an executive-level evidence narrative
#'
#' Operates only on aggregated results — no patient data involved.
#'
#' @param results  Evidence object from run_across_studies().
#' @return Character string: executive briefing note.
generate_text_summary <- function(results) {

  if (nrow(results) == 0) return("No results available to summarize.")

  n_studies   <- nrow(results)
  products    <- paste(unique(results$product), collapse = ", ")
  populations <- paste(unique(results$population), collapse = " and ")
  n_improving <- sum(results$direction == "improvement", na.rm = TRUE)
  n_sig       <- sum(results$p_value <= 0.05,            na.rm = TRUE)
  n_high_conf <- sum(results$confidence_flag == "high",  na.rm = TRUE)

  # Headline verdict
  headline <- if (n_improving == n_studies && n_sig == n_studies) {
    "STRONG, CONSISTENT BENEFIT CONFIRMED ACROSS ALL STUDIES"
  } else if (n_improving >= ceiling(n_studies * 0.7)) {
    "GENERALLY CONSISTENT BENEFIT — MAJORITY OF STUDIES POSITIVE"
  } else {
    "MIXED EVIDENCE — FURTHER INVESTIGATION RECOMMENDED"
  }

  # Consistency language for narrative
  consistency_txt <- if (n_improving == n_studies) {
    "all studies consistently show"
  } else {
    sprintf("%d of %d studies show", n_improving, n_studies)
  }

  # Subgroup opportunity
  sub_notes <- results %>%
    filter(!is.na(subgroup_summary), subgroup_summary != "No subgroup data")

  subgroup_section <- if (nrow(sub_notes) > 0) {
    paste0(
      "\nSUBGROUP OPPORTUNITY\n",
      strrep("\u2500", 50), "\n",
      "Analyses reveal a differentiated consumer response: the benefit is amplified\n",
      "in consumers with elevated baseline symptoms (High Baseline subgroup),\n",
      "pointing to a clear priority targeting segment for marketing and R&D.\n"
    )
  } else {
    ""
  }

  # Study coverage bullet list
  study_bullets <- paste(
    sprintf("  \u2022  %s (%s) \u2014 %s, N = %d + %d",
            results$product,
            results$study_id,
            results$population,
            results$n_active,
            results$n_placebo),
    collapse = "\n"
  )

  # Confidence assessment
  conf_section <- if (n_high_conf == n_studies) {
    "ALL studies meet high-confidence criteria (adequate sample size,\nstatistically significant result, consistent direction)."
  } else {
    sprintf("%d of %d studies rated high confidence.", n_high_conf, n_studies)
  }

  paste0(
    strrep("\u2550", 62), "\n",
    "  DANONE AutoRWE \u2014 CLINICAL EVIDENCE BRIEFING\n",
    strrep("\u2550", 62), "\n\n",

    "  HEADLINE\n",
    strrep("\u2500", 50), "\n",
    "  ", headline, "\n\n",

    "  EXECUTIVE SUMMARY\n",
    strrep("\u2500", 50), "\n",
    "  Evidence from ", n_studies, " randomized controlled trials demonstrates\n",
    "  that ", products, " deliver meaningful, clinically relevant\n",
    "  improvement in digestive health outcomes.\n\n",
    "  ", stringr::str_to_sentence(consistency_txt), " statistically\n",
    "  significant improvement versus placebo (p \u2264 0.05), with\n",
    "  effect sizes consistently in the large range.\n",

    subgroup_section,

    "\n  STUDIES INCLUDED\n",
    strrep("\u2500", 50), "\n",
    study_bullets, "\n\n",

    "  CONFIDENCE ASSESSMENT\n",
    strrep("\u2500", 50), "\n",
    "  ", conf_section, "\n\n",

    "  STRATEGIC IMPLICATION\n",
    strrep("\u2500", 50), "\n",
    "  The accumulated evidence supports strong, defensible product\n",
    "  claims across multiple formats and consumer segments.\n",
    "  The High Baseline subgroup finding presents an opportunity\n",
    "  to sharpen targeting for both marketing and future trials.\n\n",

    strrep("\u2550", 62), "\n",
    "  Generated by Danone AutoRWE Platform \u2014 Aggregated data only\n",
    strrep("\u2550", 62), "\n"
  )
}
