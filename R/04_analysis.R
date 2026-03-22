# =============================================================================
# 04_analysis.R  —  ANALYSIS LAYER
#
# All functions accept the standardized tibble from get_endpoint_data()
# and return structured, named lists or tibbles.
#
# Public functions:
#   analyze_endpoint(data)          -> descriptive stats per treatment arm
#   compare_treatment(data)         -> treatment difference, CI, p-value
#   analyze_subgroup(data, subgrp)  -> per-subgroup treatment comparisons
#   detect_signal(data)             -> effect size, direction, strength score
# =============================================================================

library(dplyr)
library(tidyr)
library(broom)

# =============================================================================
# 1. analyze_endpoint()
# =============================================================================

#' Descriptive statistics per treatment arm
#'
#' @param data  Standardized tibble from get_endpoint_data().
#' @return Tibble with one row per treatment arm:
#'         study_id, endpoint, treatment, n, mean_baseline, sd_baseline,
#'         mean_value, sd_value, mean_change, sd_change
analyze_endpoint <- function(data) {

  if (nrow(data) == 0) {
    warning("[analyze_endpoint] Empty data supplied.")
    return(.empty_descriptive())
  }

  data %>%
    group_by(study_id, analysis_family, endpoint, endpoint_role,
             analysis_window, treatment) %>%
    summarise(
      n             = sum(!is.na(change)),
      mean_baseline = round(mean(baseline, na.rm = TRUE), 2),
      sd_baseline   = round(sd(baseline,   na.rm = TRUE), 2),
      mean_value    = round(mean(value,     na.rm = TRUE), 2),
      sd_value      = round(sd(value,       na.rm = TRUE), 2),
      mean_change   = round(mean(change,    na.rm = TRUE), 2),
      sd_change     = round(sd(change,      na.rm = TRUE), 2),
      .groups       = "drop"
    )
}

.empty_descriptive <- function() {
  tibble(
    study_id = character(), analysis_family = character(),
    endpoint = character(), endpoint_role = character(),
    analysis_window = character(), treatment = character(),
    n = integer(), mean_baseline = numeric(), sd_baseline = numeric(),
    mean_value = numeric(), sd_value = numeric(),
    mean_change = numeric(), sd_change = numeric()
  )
}

# =============================================================================
# 2. compare_treatment()
# =============================================================================

#' Treatment comparison: difference in change from baseline
#'
#' Uses a linear model: change ~ treatment
#' Reference (intercept) = Placebo arm (alphabetically last is moved to ref).
#'
#' @param data  Standardized tibble from get_endpoint_data().
#' @return Single-row tibble:
#'         study_id, endpoint, reference_trt, active_trt,
#'         n_active, n_placebo,
#'         mean_change_active, mean_change_placebo,
#'         treatment_diff, ci_lower, ci_upper, p_value, se
compare_treatment <- function(data) {

  if (nrow(data) == 0 || length(unique(data$treatment)) < 2) {
    warning("[compare_treatment] Need at least 2 treatment arms.")
    return(.empty_comparison())
  }

  # Identify reference arm (Placebo / Control / comparator)
  arms     <- sort(unique(data$treatment))
  ref_arm  <- .pick_reference(arms)
  act_arm  <- setdiff(arms, ref_arm)[[1]]

  # Relevel so reference arm is the intercept
  data <- data %>%
    mutate(treatment = relevel(factor(treatment), ref = ref_arm))

  fit  <- lm(change ~ treatment, data = data)
  coef <- broom::tidy(fit, conf.int = TRUE, conf.level = 0.95)

  # Extract active vs reference coefficient
  act_coef_name <- paste0("treatment", act_arm)
  act_row <- coef %>% filter(term == act_coef_name)

  if (nrow(act_row) == 0) {
    warning("[compare_treatment] Could not find treatment coefficient in model.")
    return(.empty_comparison())
  }

  # Descriptive stats per arm
  desc <- data %>%
    group_by(treatment) %>%
    summarise(
      n           = sum(!is.na(change)),
      mean_change = round(mean(change, na.rm = TRUE), 3),
      .groups     = "drop"
    )

  n_active  <- desc %>% filter(treatment == act_arm) %>% pull(n)
  n_placebo <- desc %>% filter(treatment == ref_arm) %>% pull(n)
  mc_active  <- desc %>% filter(treatment == act_arm) %>% pull(mean_change)
  mc_placebo <- desc %>% filter(treatment == ref_arm) %>% pull(mean_change)

  tibble(
    study_id           = data$study_id[[1]],
    analysis_family    = data$analysis_family[[1]],
    endpoint           = data$endpoint[[1]],
    endpoint_role      = data$endpoint_role[[1]],
    analysis_window    = data$analysis_window[[1]],
    reference_trt      = ref_arm,
    active_trt         = act_arm,
    n_active           = n_active,
    n_placebo          = n_placebo,
    mean_change_active = mc_active,
    mean_change_placebo = mc_placebo,
    treatment_diff     = round(act_row$estimate,    3),
    se                 = round(act_row$std.error,   3),
    ci_lower           = round(act_row$conf.low,    3),
    ci_upper           = round(act_row$conf.high,   3),
    p_value            = round(act_row$p.value,     4),
    higher_is_better   = data$higher_is_better[[1]]
  )
}

# Pick reference arm: prefers "Placebo", then "Control", then alphabetical last
.pick_reference <- function(arms) {
  for (candidate in c("Placebo", "Control", "Comparator", "Vehicle")) {
    if (candidate %in% arms) return(candidate)
  }
  sort(arms)[[length(arms)]]
}

.empty_comparison <- function() {
  tibble(
    study_id = character(), analysis_family = character(),
    endpoint = character(), endpoint_role = character(),
    analysis_window = character(),
    reference_trt = character(), active_trt = character(),
    n_active = integer(), n_placebo = integer(),
    mean_change_active = numeric(), mean_change_placebo = numeric(),
    treatment_diff = numeric(), se = numeric(),
    ci_lower = numeric(), ci_upper = numeric(),
    p_value = numeric(), higher_is_better = logical()
  )
}

# =============================================================================
# 3. analyze_subgroup()
# =============================================================================

#' Treatment comparison stratified by a subgroup variable
#'
#' Runs compare_treatment() within each level of subgroup_var.
#'
#' @param data         Standardized tibble from get_endpoint_data().
#' @param subgroup_var Character column name to stratify on (default: "subgroup").
#' @return Tibble with one row per subgroup level, all compare_treatment() columns
#'         plus subgroup_var and subgroup_level.
analyze_subgroup <- function(data, subgroup_var = "subgroup") {

  if (!subgroup_var %in% names(data)) {
    warning(sprintf(
      "[analyze_subgroup] Column '%s' not found. Returning overall comparison.",
      subgroup_var
    ))
    return(compare_treatment(data) %>% mutate(subgroup_var = NA, subgroup_level = "Overall"))
  }

  levels_present <- unique(data[[subgroup_var]])
  levels_present <- levels_present[!is.na(levels_present)]

  if (length(levels_present) < 1) {
    warning("[analyze_subgroup] No non-NA subgroup levels found.")
    return(compare_treatment(data) %>% mutate(subgroup_var = NA, subgroup_level = "Overall"))
  }

  results <- lapply(levels_present, function(lvl) {
    sub_data <- data %>% filter(.data[[subgroup_var]] == lvl)
    if (length(unique(sub_data$treatment)) < 2) return(NULL)
    compare_treatment(sub_data) %>%
      mutate(subgroup_var   = subgroup_var,
             subgroup_level = as.character(lvl))
  })

  # Append overall
  overall <- compare_treatment(data) %>%
    mutate(subgroup_var = subgroup_var, subgroup_level = "Overall")

  bind_rows(c(list(overall), results))
}

# =============================================================================
# 4. detect_signal()
# =============================================================================

#' Compute effect size and classify signal strength
#'
#' Uses Cohen's d (standardized mean difference) against the pooled SD
#' of change from baseline.
#'
#' @param data  Standardized tibble from get_endpoint_data().
#' @return Single-row tibble:
#'         study_id, endpoint, effect_size (Cohen's d), direction,
#'         strength_score, strength_label, significance
detect_signal <- function(data) {

  comp <- compare_treatment(data)

  if (nrow(comp) == 0) {
    return(.empty_signal())
  }

  # Pooled SD of change
  pooled_sd <- data %>%
    group_by(treatment) %>%
    summarise(
      n  = sum(!is.na(change)),
      sd = sd(change, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    summarise(
      pooled_sd = sqrt(sum((n - 1) * sd^2) / (sum(n) - n()))
    ) %>%
    pull(pooled_sd)

  # Cohen's d (absolute; sign handled separately)
  cohens_d <- if (is.na(pooled_sd) || pooled_sd == 0) NA_real_
              else abs(comp$treatment_diff) / pooled_sd

  # Direction: is the active arm moving in the desired direction?
  higher_better <- isTRUE(comp$higher_is_better)
  diff_sign     <- sign(comp$treatment_diff)

  direction <- if (is.na(diff_sign)) {
    "unknown"
  } else if ((higher_better && diff_sign > 0) ||
             (!higher_better && diff_sign < 0)) {
    "improvement"
  } else if (diff_sign == 0) {
    "no_effect"
  } else {
    "worsening"
  }

  # Strength score (0–1) based on Cohen's d thresholds
  strength_score <- if (is.na(cohens_d)) 0
                    else min(cohens_d / 1.2, 1.0)   # caps at d=1.2 -> score=1.0

  strength_label <- dplyr::case_when(
    is.na(cohens_d)       ~ "unknown",
    cohens_d >= 0.8       ~ "large",
    cohens_d >= 0.5       ~ "moderate",
    cohens_d >= 0.2       ~ "small",
    TRUE                  ~ "negligible"
  )

  significance <- dplyr::case_when(
    comp$p_value <= 0.001 ~ "***",
    comp$p_value <= 0.01  ~ "**",
    comp$p_value <= 0.05  ~ "*",
    comp$p_value <= 0.10  ~ ".",
    TRUE                  ~ "ns"
  )

  tibble(
    study_id        = comp$study_id,
    analysis_family = comp$analysis_family,
    endpoint        = comp$endpoint,
    endpoint_role   = comp$endpoint_role,
    analysis_window = comp$analysis_window,
    treatment_diff  = comp$treatment_diff,
    ci_lower        = comp$ci_lower,
    ci_upper        = comp$ci_upper,
    p_value         = comp$p_value,
    cohens_d        = round(cohens_d, 3),
    direction       = direction,
    strength_score  = round(strength_score, 3),
    strength_label  = strength_label,
    significance    = significance,
    n_active        = comp$n_active,
    n_placebo       = comp$n_placebo
  )
}

.empty_signal <- function() {
  tibble(
    study_id = character(), analysis_family = character(),
    endpoint = character(), endpoint_role = character(),
    analysis_window = character(),
    treatment_diff = numeric(), ci_lower = numeric(), ci_upper = numeric(),
    p_value = numeric(), cohens_d = numeric(),
    direction = character(), strength_score = numeric(),
    strength_label = character(), significance = character(),
    n_active = integer(), n_placebo = integer()
  )
}
