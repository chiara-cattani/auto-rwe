# =============================================================================
# 08_ai_narrative.R  —  AI-POWERED NARRATIVE GENERATION
#
# Uses the Claude API (Anthropic) to generate an executive evidence narrative
# from the AGGREGATED results only — never from patient-level data.
#
# This is safe by design:
#   - Input:  the evidence object (N, means, CIs, p-values, directions)
#   - NOT:    individual subject records, raw datasets, or identifiable data
#
# Setup:
#   1. Install httr2:   install.packages("httr2")
#   2. Set API key:     Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
#      Or add to .Renviron: ANTHROPIC_API_KEY=sk-ant-...
#
# Usage:
#   source("R/08_ai_narrative.R")
#   narrative <- generate_ai_narrative(results)
#   cat(narrative)
# =============================================================================

library(dplyr)

# =============================================================================
# Main function
# =============================================================================

#' Generate an AI-powered executive narrative from aggregated evidence
#'
#' Sends ONLY the summary statistics from the evidence object to Claude.
#' No patient data is ever transmitted.
#'
#' @param results    Evidence object from run_across_studies().
#' @param audience   "management" (default) or "scientific"
#' @param api_key    Anthropic API key. Defaults to ANTHROPIC_API_KEY env var.
#' @param model      Claude model ID. Defaults to claude-sonnet-4-6.
#'
#' @return Character string: AI-generated narrative.
generate_ai_narrative <- function(results,
                                   audience = "management",
                                   api_key  = Sys.getenv("ANTHROPIC_API_KEY"),
                                   model    = "claude-sonnet-4-6") {

  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop(paste(
      "Package 'httr2' is required for AI narrative generation.",
      "Install it with: install.packages('httr2')"
    ))
  }

  if (nchar(api_key) == 0) {
    stop(paste(
      "ANTHROPIC_API_KEY is not set.",
      "Run: Sys.setenv(ANTHROPIC_API_KEY = 'your-key-here')",
      "Or add ANTHROPIC_API_KEY=your-key to your .Renviron file."
    ))
  }

  if (nrow(results) == 0) {
    return("No results available for narrative generation.")
  }

  # Build the aggregated summary to send (no patient data)
  evidence_summary <- .build_evidence_text(results)

  # Build prompt based on audience
  prompt <- .build_prompt(evidence_summary, audience,
                           results$analysis_family[[1]])

  message("[ai_narrative] Sending aggregated results to Claude API...")

  # Call the Anthropic Messages API
  resp <- httr2::request("https://api.anthropic.com/v1/messages") |>
    httr2::req_headers(
      "x-api-key"         = api_key,
      "anthropic-version" = "2023-06-01",
      "content-type"      = "application/json"
    ) |>
    httr2::req_body_json(list(
      model      = model,
      max_tokens = 900,
      messages   = list(
        list(role = "user", content = prompt)
      )
    )) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  status <- httr2::resp_status(resp)

  if (status != 200) {
    body <- httr2::resp_body_json(resp)
    stop(sprintf(
      "[ai_narrative] API error %d: %s",
      status,
      body$error$message %||% "Unknown error"
    ))
  }

  body <- httr2::resp_body_json(resp)
  narrative <- body$content[[1]]$text

  message("[ai_narrative] Narrative generated successfully.")
  return(narrative)
}

# =============================================================================
# Internal: format evidence object as structured text for the prompt
# =============================================================================
.build_evidence_text <- function(results) {

  header <- sprintf(
    "THERAPEUTIC AREA: %s\nSTUDIES ANALYZED: %d\nPRODUCTS: %s\nPOPULATIONS: %s\n",
    results$analysis_family[[1]],
    nrow(results),
    paste(unique(results$product), collapse = ", "),
    paste(unique(results$population), collapse = ", ")
  )

  study_rows <- apply(results, 1, function(r) {
    sprintf(
      paste0(
        "  Study: %s | Product: %s | Population: %s\n",
        "  N: %s active + %s placebo\n",
        "  Treatment difference: %s (95%% CI: %s to %s)\n",
        "  p-value: %s | Cohen's d: %s | Direction: %s | Strength: %s\n",
        "  Confidence: %s | Analysis window: %s\n",
        "  Subgroup finding: %s"
      ),
      r["study_id"], r["product"], r["population"],
      r["n_active"], r["n_placebo"],
      r["treatment_diff"], r["ci_lower"], r["ci_upper"],
      r["p_value"], r["cohens_d"], r["direction"], r["strength_label"],
      r["confidence_flag"], r["analysis_window"],
      ifelse(is.na(r["subgroup_summary"]) || r["subgroup_summary"] == "No subgroup data",
             "Not available", r["subgroup_summary"])
    )
  })

  paste0(header, "\nPER-STUDY RESULTS:\n",
         paste(study_rows, collapse = "\n\n"))
}

# =============================================================================
# Internal: build the prompt
# =============================================================================
.build_prompt <- function(evidence_summary, audience, family) {

  family_label <- switch(family,
    digestive_health  = "digestive health",
    bone_joint_health = "bone and joint health",
    immune_support    = "immune support",
    family
  )

  if (audience == "management") {
    paste0(
      "You are a clinical evidence analyst at Danone, a global food and beverage company ",
      "known for health-focused products including Activia, Actimel, and Densia.\n\n",

      "Based on the aggregated clinical trial results below, write a concise executive ",
      "briefing (3 short paragraphs) for senior management. The audience are business ",
      "leaders — not scientists.\n\n",

      "Guidelines:\n",
      "- Lead with the headline finding in plain language\n",
      "- Mention the number of studies and products covered\n",
      "- Highlight any subgroup opportunity (e.g. high-symptom consumers respond better)\n",
      "- Close with one sentence on strategic implication for the product portfolio\n",
      "- Avoid p-values, Cohen's d, and statistical jargon\n",
      "- Use confident, positive language where the evidence supports it\n",
      "- If any study shows a weak or null result, acknowledge it honestly\n\n",

      "AGGREGATED CLINICAL EVIDENCE (no patient data):\n",
      "---\n",
      evidence_summary, "\n",
      "---\n\n",
      "Write the executive briefing now."
    )
  } else {
    # Scientific audience
    paste0(
      "You are a biostatistician preparing a scientific evidence summary for an ",
      "internal research team at Danone.\n\n",

      "Based on the aggregated clinical trial results below, write a structured ",
      "scientific summary (3-4 paragraphs) covering:\n",
      "1. Overall evidence direction and consistency across studies\n",
      "2. Effect size interpretation (using Cohen's d thresholds)\n",
      "3. Notable heterogeneity or inconsistency between studies\n",
      "4. Subgroup signals and their implications for future study design\n",
      "5. Limitations and confidence assessment\n\n",

      "AGGREGATED CLINICAL EVIDENCE (no patient data):\n",
      "---\n",
      evidence_summary, "\n",
      "---\n\n",
      "Write the scientific summary now."
    )
  }
}

# =============================================================================
# generate_ai_insights()  — Evidence commentary + strategic recommendations
# =============================================================================

#' Generate AI-powered insights: evidence commentary + business recommendations
#'
#' Sends ONLY aggregated statistics to Claude. Returns a structured list with
#' a commentary section and a parsed list of recommendations.
#'
#' @param results   Evidence object from run_across_studies().
#' @param audience  "management" (default) or "scientific".
#' @param api_key   Anthropic API key.
#' @param model     Claude model ID.
#'
#' @return Named list:
#'   $commentary       Character. Evidence interpretation paragraphs.
#'   $recommendations  List of lists, each with $title and $body.
generate_ai_insights <- function(results,
                                  audience = "management",
                                  api_key  = Sys.getenv("ANTHROPIC_API_KEY"),
                                  model    = "claude-sonnet-4-6") {

  if (!requireNamespace("httr2", quietly = TRUE))
    stop("Package 'httr2' required. Install with: install.packages('httr2')")

  if (nchar(api_key) == 0)
    stop("ANTHROPIC_API_KEY not set. Run: Sys.setenv(ANTHROPIC_API_KEY = 'sk-ant-...')")

  evidence_summary <- .build_evidence_text(results)
  family_label <- switch(results$analysis_family[[1]],
    digestive_health  = "digestive health",
    bone_joint_health = "bone and joint health",
    immune_support    = "immune support",
    results$analysis_family[[1]]
  )

  prompt <- .build_insights_prompt(evidence_summary, audience, family_label)

  message("[ai_insights] Calling Claude API...")

  resp <- httr2::request("https://api.anthropic.com/v1/messages") |>
    httr2::req_headers(
      "x-api-key"         = api_key,
      "anthropic-version" = "2023-06-01",
      "content-type"      = "application/json"
    ) |>
    httr2::req_body_json(list(
      model      = model,
      max_tokens = 1200,
      messages   = list(list(role = "user", content = prompt))
    )) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) != 200) {
    body <- httr2::resp_body_json(resp)
    stop(sprintf("[ai_insights] API error %d: %s",
                 httr2::resp_status(resp),
                 body$error$message %||% "Unknown error"))
  }

  raw_text <- httr2::resp_body_json(resp)$content[[1]]$text
  message("[ai_insights] Response received. Parsing...")

  .parse_insights_response(raw_text)
}

# -----------------------------------------------------------------------------
# Internal: build the insights prompt
# -----------------------------------------------------------------------------
.build_insights_prompt <- function(evidence_summary, audience, family_label) {

  audience_ctx <- if (audience == "management") {
    paste0(
      "You are a strategic advisor presenting to the Executive Committee of Danone, ",
      "a global leader in health-focused food and beverage (Activia, Actimel, Densia, Evian).\n",
      "The audience is senior business leaders — not scientists. Avoid jargon."
    )
  } else {
    paste0(
      "You are a senior scientist presenting to Danone's Clinical and Regulatory Affairs team. ",
      "The audience understands clinical research. You may reference effect sizes and study design."
    )
  }

  paste0(
    audience_ctx, "\n\n",

    "Based on the aggregated clinical trial results below, produce TWO clearly separated sections:\n\n",

    "SECTION 1 — EVIDENCE COMMENTARY\n",
    "Write 2-3 paragraphs interpreting what the evidence collectively means.\n",
    "Cover: overall direction, consistency across studies, ",
    "geographic or population differences, and any study with a weak or null result.\n",
    if (audience == "management")
      "Use plain language. Avoid p-values and Cohen's d.\n\n"
    else
      "Reference effect sizes and statistical significance appropriately.\n\n",

    "SECTION 2 — STRATEGIC RECOMMENDATIONS\n",
    "Propose exactly 5 specific, actionable recommendations for Danone.\n",
    "Each recommendation must be directly grounded in the evidence above — not generic.\n",
    "Think boldly: include product development ideas, targeting strategies, ",
    "future clinical investments, marketing claim opportunities, and portfolio moves.\n",
    "Format each recommendation EXACTLY like this, one per line:\n",
    "REC: [Short title (5-8 words)] | [2-3 sentence explanation of the idea and why the evidence supports it]\n\n",

    "Important: output ONLY the two sections. Use these exact headers:\n",
    "##COMMENTARY##\n",
    "[your commentary here]\n",
    "##RECOMMENDATIONS##\n",
    "[your 5 REC: lines here]\n\n",

    "AGGREGATED CLINICAL EVIDENCE — ", toupper(family_label),
    " (no patient data):\n---\n",
    evidence_summary,
    "\n---\n\nProduce your analysis now."
  )
}

# -----------------------------------------------------------------------------
# Internal: parse Claude's structured response into commentary + recommendations
# -----------------------------------------------------------------------------
.parse_insights_response <- function(raw_text) {

  # Split on section headers
  parts <- strsplit(raw_text, "##COMMENTARY##|##RECOMMENDATIONS##")[[1]]
  parts <- trimws(parts[nchar(trimws(parts)) > 0])

  commentary <- if (length(parts) >= 1) parts[[1]] else raw_text
  rec_block  <- if (length(parts) >= 2) parts[[2]] else ""

  # Parse REC: lines
  rec_lines <- grep("^REC:", strsplit(rec_block, "\n")[[1]], value = TRUE)

  recommendations <- lapply(rec_lines, function(line) {
    # Remove "REC: " prefix
    content <- sub("^REC:\\s*", "", line)
    # Split on " | "
    pieces  <- strsplit(content, "\\s*\\|\\s*")[[1]]
    list(
      title = if (length(pieces) >= 1) trimws(pieces[[1]]) else "Recommendation",
      body  = if (length(pieces) >= 2) trimws(pieces[[2]]) else trimws(content)
    )
  })

  # If no REC: lines found (Claude didn't follow format), fall back gracefully
  if (length(recommendations) == 0 && nchar(rec_block) > 0) {
    recommendations <- list(list(
      title = "See full text",
      body  = rec_block
    ))
  }

  list(commentary = commentary, recommendations = recommendations)
}

# =============================================================================
# Utility
# =============================================================================

#' Check whether AI features are available (API key set + httr2 installed)
ai_narrative_available <- function() {
  requireNamespace("httr2", quietly = TRUE) &&
    nchar(Sys.getenv("ANTHROPIC_API_KEY")) > 0
}
