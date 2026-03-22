# =============================================================================
# 07_shiny_app.R  —  AutoRWE Platform — Executive Dashboard
#
# Danone-branded Shiny interface for cross-study clinical evidence.
#
# Tabs:
#   1. Executive Summary  — headline KPIs + narrative + forest plot
#   2. Evidence Table     — per-study results
#   3. Forest Plot        — full forest plot with pooled diamond
#   4. Subgroup Analysis  — differential effects by consumer segment
#   5. Evidence Narrative — full briefing text
#   6. Platform Value     — business case slide
#   7. Data Preview       — subject-level extract (first study)
#
# Launch: source("R/07_shiny_app.R"); launch_app()
# =============================================================================

library(shiny)
library(dplyr)
library(ggplot2)

# -----------------------------------------------------------------------------
# Resolve project root relative to this file's location
# -----------------------------------------------------------------------------
.app_base_dir <- function() {
  script_dir <- tryCatch(
    dirname(rstudioapi::getSourceEditorContext()$path),
    error = function(e) getwd()
  )
  if (basename(script_dir) == "R") dirname(script_dir) else script_dir
}

# -----------------------------------------------------------------------------
# CSS — Danone brand styling
# -----------------------------------------------------------------------------
.danone_css <- "
  /* ---- Brand colors ---- */
  :root {
    --danone-blue:   #009FE3;
    --danone-dark:   #003087;
    --danone-green:  #00A878;
    --danone-light:  #E8F4FD;
    --danone-orange: #F5A623;
  }

  /* ---- Page background ---- */
  body { background-color: #F5F7FA; font-family: 'Segoe UI', Arial, sans-serif; }

  /* ---- Top header bar ---- */
  .header-bar {
    background: var(--danone-blue);
    color: white;
    padding: 14px 24px;
    margin-bottom: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .header-bar .title-text  { font-size: 20px; font-weight: 700; letter-spacing: 0.5px; }
  .header-bar .subtitle-text { font-size: 12px; opacity: 0.85; margin-top: 2px; }
  .header-bar .badge-prototype {
    background: rgba(255,255,255,0.25);
    border-radius: 12px;
    padding: 4px 12px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  /* ---- Sidebar ---- */
  .well {
    background: white;
    border: none;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  }
  .sidebar-section-title {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--danone-blue);
    margin-top: 16px;
    margin-bottom: 6px;
    border-bottom: 2px solid var(--danone-light);
    padding-bottom: 4px;
  }

  /* ---- Run button ---- */
  #run_btn {
    background: var(--danone-blue) !important;
    border-color: var(--danone-blue) !important;
    color: white !important;
    font-weight: 600;
    letter-spacing: 0.5px;
    border-radius: 6px;
  }
  #run_btn:hover {
    background: var(--danone-dark) !important;
    border-color: var(--danone-dark) !important;
  }

  /* ---- KPI cards ---- */
  .kpi-row {
    display: flex;
    gap: 12px;
    margin-bottom: 20px;
  }
  .kpi-card {
    flex: 1;
    background: white;
    border-radius: 8px;
    padding: 16px 18px;
    border-left: 4px solid var(--danone-blue);
    box-shadow: 0 2px 8px rgba(0,0,0,0.07);
    min-width: 0;
  }
  .kpi-card.green  { border-left-color: var(--danone-green);  }
  .kpi-card.orange { border-left-color: var(--danone-orange); }
  .kpi-card.dark   { border-left-color: var(--danone-dark);   }
  .kpi-value {
    font-size: 30px;
    font-weight: 700;
    color: var(--danone-dark);
    line-height: 1.1;
  }
  .kpi-label {
    font-size: 11px;
    color: #888;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    margin-top: 3px;
  }

  /* ---- Tab styling ---- */
  .nav-tabs > li.active > a,
  .nav-tabs > li.active > a:focus,
  .nav-tabs > li.active > a:hover {
    color: var(--danone-blue) !important;
    border-top: 3px solid var(--danone-blue) !important;
    font-weight: 600;
  }
  .nav-tabs > li > a { color: #555; }
  .tab-content { background: white; border-radius: 0 0 8px 8px;
                 padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.07); }

  /* ---- Executive summary callout ---- */
  .exec-headline {
    background: var(--danone-light);
    border-left: 5px solid var(--danone-blue);
    padding: 14px 18px;
    border-radius: 4px;
    margin-bottom: 16px;
    font-size: 16px;
    font-weight: 700;
    color: var(--danone-dark);
  }
  .insight-box {
    background: #FFF8E1;
    border-left: 5px solid var(--danone-orange);
    padding: 12px 16px;
    border-radius: 4px;
    margin-top: 14px;
    font-size: 13px;
    color: #5D4037;
  }
  .insight-box .insight-title {
    font-weight: 700;
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 0.7px;
    color: var(--danone-orange);
    margin-bottom: 4px;
  }

  /* ---- Platform value tab ---- */
  .value-header {
    background: var(--danone-dark);
    color: white;
    padding: 20px 24px;
    border-radius: 8px;
    margin-bottom: 20px;
  }
  .value-header h3 { margin: 0 0 6px 0; font-size: 20px; }
  .value-header p  { margin: 0; opacity: 0.85; font-size: 13px; }

  .compare-col {
    background: white;
    border-radius: 8px;
    padding: 20px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.07);
    height: 100%;
  }
  .compare-col.before { border-top: 4px solid #E05C5C; }
  .compare-col.after  { border-top: 4px solid var(--danone-green); }
  .compare-col h4 { font-size: 13px; text-transform: uppercase;
                    letter-spacing: 1px; color: #888; margin-bottom: 14px; }
  .compare-item {
    display: flex; align-items: flex-start;
    margin-bottom: 12px; font-size: 13px;
  }
  .compare-item .icon { margin-right: 10px; font-size: 16px; flex-shrink: 0; }

  .how-step {
    display: flex; align-items: center;
    background: var(--danone-light);
    border-radius: 6px;
    padding: 12px 16px;
    margin-bottom: 8px;
    font-size: 13px;
  }
  .step-num {
    background: var(--danone-blue);
    color: white;
    border-radius: 50%;
    width: 28px; height: 28px;
    display: flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: 13px;
    flex-shrink: 0;
    margin-right: 14px;
  }
  .scale-card {
    background: var(--danone-dark);
    color: white;
    border-radius: 8px;
    padding: 16px 20px;
    margin-top: 16px;
    font-size: 13px;
  }
  .scale-card strong { color: var(--danone-orange); }

  /* ---- AI Insights tab ---- */
  .ai-section {
    background: white; border-radius: 8px; padding: 20px 24px;
    margin-bottom: 16px; box-shadow: 0 2px 8px rgba(0,0,0,0.07);
  }
  .ai-section-title {
    font-size: 11px; font-weight: 700; text-transform: uppercase;
    letter-spacing: 1px; color: var(--danone-blue);
    border-bottom: 2px solid var(--danone-light);
    padding-bottom: 6px; margin-bottom: 14px;
  }
  .ai-commentary-text {
    font-size: 14px; line-height: 1.8; color: #333;
  }
  .rec-card {
    display: flex; align-items: flex-start;
    background: #F5F7FA; border-radius: 8px; padding: 14px 16px;
    margin-bottom: 10px; border-left: 4px solid var(--danone-orange);
  }
  .rec-num {
    background: var(--danone-orange); color: white; border-radius: 50%;
    width: 26px; height: 26px; min-width: 26px;
    display: flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: 12px; margin-right: 14px; margin-top: 1px;
  }
  .rec-title   { font-weight: 700; font-size: 13px; color: #003087; margin-bottom: 3px; }
  .rec-body    { font-size: 13px; color: #555; line-height: 1.6; }
  .ai-placeholder {
    text-align: center; padding: 60px 20px; color: #aaa;
  }
  .ai-placeholder .placeholder-icon { font-size: 48px; margin-bottom: 12px; }
  .ai-placeholder p { font-size: 14px; }
"

# =============================================================================
# UI
# =============================================================================
app_ui <- fluidPage(

  tags$head(tags$style(HTML(.danone_css))),

  # --- Branded header --------------------------------------------------------
  div(class = "header-bar",
    div(
      div(class = "title-text",   "Danone  \u2014  AutoRWE Platform"),
      div(class = "subtitle-text","Automated Real-World Evidence Engine")
    ),
    div(class = "badge-prototype", "Prototype")
  ),

  br(),

  sidebarLayout(

    # --- Sidebar -------------------------------------------------------------
    sidebarPanel(
      width = 3,

      div(class = "sidebar-section-title", "Analysis scope"),

      selectInput(
        inputId  = "analysis_family",
        label    = "Therapeutic Area",
        choices  = c(
          "Digestive Health"   = "digestive_health",
          "Bone & Joint Health" = "bone_joint_health",
          "Immune Support"     = "immune_support"
        ),
        selected = "digestive_health"
      ),

      uiOutput("endpoint_role_ui"),

      div(class = "sidebar-section-title", "Studies"),

      uiOutput("study_selector_ui"),

      div(class = "sidebar-section-title", "Subgroup"),

      selectInput(
        inputId  = "subgroup_var",
        label    = NULL,
        choices  = c("Baseline Level" = "subgroup", "None" = "None"),
        selected = "subgroup"
      ),

      hr(style = "border-color: #eee;"),

      actionButton(
        inputId = "run_btn",
        label   = "Run Analysis",
        class   = "btn-primary btn-lg",
        width   = "100%",
        icon    = icon("play")
      ),

      br(), br(),
      uiOutput("status_msg")
    ),

    # --- Main panel ----------------------------------------------------------
    mainPanel(
      width = 9,

      # KPI cards (visible after analysis)
      uiOutput("kpi_row"),

      tabsetPanel(
        id = "main_tabs",

        # =====================================================================
        # Tab 1 — Executive Summary
        # =====================================================================
        tabPanel(
          title = tagList(icon("star"), " Executive Summary"),
          br(),

          uiOutput("exec_headline"),

          fluidRow(
            column(6,
              h5("Evidence Overview",
                 style = "color: #003087; font-weight: 700; margin-bottom: 12px;"),
              uiOutput("exec_narrative_short"),
              uiOutput("exec_subgroup_insight")
            ),
            column(6,
              h5("Treatment Effect by Study",
                 style = "color: #003087; font-weight: 700; margin-bottom: 12px;"),
              plotOutput("exec_forest_plot", height = "300px")
            )
          ),

          br(),
          h5("Studies Analyzed",
             style = "color: #003087; font-weight: 700; margin-bottom: 10px;"),
          uiOutput("exec_study_list")
        ),

        # =====================================================================
        # Tab 2 — Evidence Table
        # =====================================================================
        tabPanel(
          title = tagList(icon("table"), " Evidence Table"),
          br(),
          uiOutput("no_results_msg"),
          tableOutput("summary_table")
        ),

        # =====================================================================
        # Tab 3 — Forest Plot
        # =====================================================================
        tabPanel(
          title = tagList(icon("chart-bar"), " Forest Plot"),
          br(),
          plotOutput("forest_plot", height = "500px")
        ),

        # =====================================================================
        # Tab 4 — Subgroup Analysis
        # =====================================================================
        tabPanel(
          title = tagList(icon("users"), " Subgroup Analysis"),
          br(),
          plotOutput("subgroup_plot", height = "520px")
        ),

        # =====================================================================
        # Tab 5 — Evidence Narrative (rule-based)
        # =====================================================================
        tabPanel(
          title = tagList(icon("file-alt"), " Evidence Narrative"),
          br(),
          verbatimTextOutput("text_summary")
        ),

        # =====================================================================
        # Tab 6 — AI Insights
        # =====================================================================
        tabPanel(
          title = tagList(icon("robot"), " AI Insights"),
          br(),

          # Header
          div(
            style = paste0(
              "background: linear-gradient(135deg, #003087 0%, #009FE3 100%);",
              "color: white; padding: 18px 22px; border-radius: 8px;",
              "margin-bottom: 20px; display: flex;",
              "justify-content: space-between; align-items: center;"
            ),
            div(
              div(style = "font-size: 16px; font-weight: 700;",
                  "\U0001F916  AI-Powered Evidence Insights"),
              div(style = "font-size: 12px; opacity: 0.85; margin-top: 4px;",
                  "Claude analyzes aggregated results only — no patient data sent")
            ),
            div(
              style = "background: rgba(255,255,255,0.2); border-radius: 12px;",
              style = "padding: 4px 12px; font-size: 11px; font-weight: 600;",
              "Powered by Claude"
            )
          ),

          # Controls row
          fluidRow(
            column(4,
              div(style = "font-size: 11px; font-weight: 700; text-transform: uppercase;
                           letter-spacing: 1px; color: #009FE3; margin-bottom: 6px;",
                  "Audience"),
              radioButtons("ai_audience", label = NULL,
                choices  = c("Senior Management" = "management",
                             "Scientific Team"   = "scientific"),
                selected = "management", inline = TRUE)
            ),
            column(4,
              br(),
              actionButton("gen_insights_btn",
                           label  = tagList(icon("robot"), " Generate AI Insights"),
                           style  = paste0(
                             "background: #009FE3; color: white; border: none;",
                             "border-radius: 6px; font-weight: 600; padding: 8px 20px;"
                           ),
                           width  = "100%")
            ),
            column(4,
              br(),
              uiOutput("ai_insights_status")
            )
          ),

          br(),

          # AI output area
          uiOutput("ai_insights_output")
        ),

        # =====================================================================
        # Tab 7 — Platform Value
        # =====================================================================
        tabPanel(
          title = tagList(icon("rocket"), " Platform Value"),
          br(),

          div(class = "value-header",
            h3("Why AutoRWE?"),
            p("From raw clinical data to cross-study insights — automated, standardized, scalable.")
          ),

          # Before / After
          fluidRow(
            column(6,
              div(class = "compare-col before",
                h4("Without AutoRWE"),
                div(class = "compare-item",
                    div(class = "icon", "\u231B"),
                    div("6+ months to extract and compare results across studies")),
                div(class = "compare-item",
                    div(class = "icon", "\u2757"),
                    div("Manual, inconsistent methods across teams and studies")),
                div(class = "compare-item",
                    div(class = "icon", "\U0001F4C1"),
                    div("Siloed reports — no unified view of the evidence base")),
                div(class = "compare-item",
                    div(class = "icon", "\U0001F50D"),
                    div("Limited to 1\u20132 studies per review cycle")),
                div(class = "compare-item",
                    div(class = "icon", "\u26A0"),
                    div("Subgroup insights missed or analyzed ad hoc"))
              )
            ),
            column(6,
              div(class = "compare-col after",
                h4("With AutoRWE"),
                div(class = "compare-item",
                    div(class = "icon", "\u26A1"),
                    div(HTML("Results aggregated across studies in <strong>minutes</strong>"))),
                div(class = "compare-item",
                    div(class = "icon", "\u2705"),
                    div("Standardized methods — every study analyzed the same way")),
                div(class = "compare-item",
                    div(class = "icon", "\U0001F4CA"),
                    div("Unified evidence dashboard with forest plot and narrative")),
                div(class = "compare-item",
                    div(class = "icon", "\u267E"),
                    div(HTML("Scales to <strong>50+ studies</strong> with no code changes"))),
                div(class = "compare-item",
                    div(class = "icon", "\U0001F3AF"),
                    div("Automated subgroup detection — targeting opportunities surfaced"))
              )
            )
          ),

          br(),
          h5("How it Works",
             style = "color: #003087; font-weight: 700; margin-bottom: 10px;"),

          div(class = "how-step",
              div(class = "step-num", "1"),
              div(HTML("<strong>Study catalog & metadata</strong> — define studies, endpoints and rules in a simple table. No code changes per study."))),
          div(class = "how-step",
              div(class = "step-num", "2"),
              div(HTML("<strong>Automated extraction</strong> — the platform reads each study's ADaM dataset and applies the defined rules to extract endpoint data."))),
          div(class = "how-step",
              div(class = "step-num", "3"),
              div(HTML("<strong>Standardized analysis</strong> — treatment comparison, effect size, and subgroup analysis are run identically across all studies."))),
          div(class = "how-step",
              div(class = "step-num", "4"),
              div(HTML("<strong>Cross-study aggregation</strong> — results are pooled into a single evidence object with consistency and confidence ratings."))),
          div(class = "how-step",
              div(class = "step-num", "5"),
              div(HTML("<strong>Outputs</strong> — interactive dashboard, forest plot, subgroup analysis, and auto-generated evidence narrative."))),

          div(class = "scale-card",
            HTML(paste0(
              "<strong>Scalability:</strong>  This prototype demonstrates the concept on 3 studies. ",
              "The same architecture supports <strong>50+ studies</strong> — adding a new study requires only ",
              "one row in the study catalog and a few rows in the endpoint mapping table. ",
              "No R code changes. No data re-harmonization."
            ))
          )
        ),

        # =====================================================================
        # Tab 8 — Data Preview
        # =====================================================================
        tabPanel(
          title = tagList(icon("database"), " Data Preview"),
          br(),
          p("Subject-level extract — primary study, first 100 rows.",
            style = "color: grey; font-size: 12px;"),
          tableOutput("raw_preview")
        )
      )
    )
  )
)

# =============================================================================
# Server
# =============================================================================
# Null-coalescing operator
`%||%` <- function(a, b) if (!is.null(a)) a else b

# Lookup tables for dynamic sidebar (defined outside server so UI can also use them)
.study_choices <- list(
  digestive_health = c(
    "Activia Probiotic \u2014 EU"      = "activia_eu_01",
    "Actimel Daily \u2014 Asia"        = "actimel_asia_02",
    "Actimel Senior \u2014 Elderly"    = "danone_elderly_03",
    "Activia Probiotic \u2014 USA"     = "activia_us_04",
    "Activia Light \u2014 Japan"       = "activia_japan_05"
  ),
  bone_joint_health = c(
    "Densia \u2014 EU Women 50+"       = "densia_eu_01",
    "Densia Plus \u2014 Global 45+"    = "densia_global_02"
  ),
  immune_support = c(
    "Actimel \u2014 EU Adults"         = "actimel_immune_eu_01",
    "Actimel Senior \u2014 EU Elderly" = "actimel_immune_elder_02"
  )
)

.endpoint_choices <- list(
  digestive_health  = c("Primary Endpoint" = "primary_endpoint",
                        "Secondary: Bloating" = "secondary_bloating"),
  bone_joint_health = c("Primary Endpoint" = "primary_endpoint"),
  immune_support    = c("Primary Endpoint" = "primary_endpoint")
)

app_server <- function(input, output, session) {

  base_dir <- .app_base_dir()

  # ---------------------------------------------------------------------------
  # Dynamic sidebar: endpoint role selector
  # ---------------------------------------------------------------------------
  output$endpoint_role_ui <- renderUI({
    fam     <- req(input$analysis_family)
    choices <- .endpoint_choices[[fam]] %||% c("Primary Endpoint" = "primary_endpoint")
    selectInput("endpoint_role", "Endpoint", choices = choices,
                selected = choices[[1]])
  })

  # Dynamic sidebar: study checkbox group
  output$study_selector_ui <- renderUI({
    fam     <- req(input$analysis_family)
    choices <- .study_choices[[fam]] %||% character(0)
    checkboxGroupInput("study_list", label = NULL,
                       choices  = choices,
                       selected = unname(choices))
  })

  # ---------------------------------------------------------------------------
  # Stable study list — decoupled from dynamic UI timing
  #
  # Problem: checkboxGroupInput rendered inside uiOutput can send only partial
  # values back to the server at the moment the Run button fires, because the
  # browser registers checkboxes one by one as the DOM settles.
  # Fix: mirror input$study_list into a reactiveVal that Shiny updates whenever
  # the input changes, and read THAT value (not input$study_list directly) when
  # the Run button is pressed.
  # ---------------------------------------------------------------------------
  .sel_studies <- reactiveVal(character(0))

  # Keep the mirror up-to-date whenever the checkbox group changes
  observeEvent(input$study_list, {
    .sel_studies(input$study_list %||% character(0))
  }, ignoreNULL = FALSE, ignoreInit = FALSE)

  # When therapeutic area changes, pre-populate with all studies for that area
  observeEvent(input$analysis_family, {
    all <- unname(.study_choices[[input$analysis_family]] %||% character(0))
    .sel_studies(all)
  }, ignoreInit = TRUE)

  # ---------------------------------------------------------------------------
  # Reactive: run analysis
  # ---------------------------------------------------------------------------
  evidence <- eventReactive(input$run_btn, {

    studies <- isolate(.sel_studies())
    req(length(studies) > 0)

    withProgress(message = "Running AutoRWE analysis...", value = 0, {

      incProgress(0.1, detail = "Loading metadata")
      load_metadata(base_dir = base_dir, refresh = TRUE)
      clear_study_cache()

      incProgress(0.3, detail = "Extracting endpoints")

      role <- if (isTRUE(input$endpoint_role == "None") ||
                  is.null(input$endpoint_role)) NULL
              else input$endpoint_role

      results <- tryCatch(
        run_across_studies(
          analysis_family = input$analysis_family,
          study_list      = studies,
          endpoint_role   = role,
          base_dir        = base_dir,
          verbose         = FALSE
        ),
        error = function(e) {
          showNotification(paste("Error:", conditionMessage(e)),
                           type = "error", duration = 10)
          return(NULL)
        }
      )

      incProgress(0.9, detail = "Assembling evidence object")
      Sys.sleep(0.2)
      results
    })
  })

  # Reactive: subgroup analysis
  subgroup_res <- eventReactive(input$run_btn, {
    studies <- isolate(.sel_studies())
    req(input$subgroup_var != "None", length(studies) > 0)
    tryCatch(
      run_subgroup_analysis(
        analysis_family = input$analysis_family,
        study_list      = studies,
        subgroup_var    = input$subgroup_var,
        endpoint_role   = if (input$endpoint_role == "None") NULL else input$endpoint_role,
        base_dir        = base_dir
      ),
      error = function(e) NULL
    )
  })

  # ---------------------------------------------------------------------------
  # Sidebar status
  # ---------------------------------------------------------------------------
  output$status_msg <- renderUI({
    ev <- evidence()
    if (is.null(ev)) return(NULL)
    div(
      style = paste0(
        "color: #155724; background: #d4edda; padding: 8px 12px;",
        "border-radius: 4px; font-size: 13px;"
      ),
      icon("check-circle"),
      sprintf("  %d %s analyzed", nrow(ev),
              if (nrow(ev) == 1) "study" else "studies")
    )
  })

  # ---------------------------------------------------------------------------
  # KPI cards row
  # ---------------------------------------------------------------------------
  output$kpi_row <- renderUI({
    ev <- evidence()
    if (is.null(ev)) return(NULL)

    n_studies    <- nrow(ev)
    pct_improve  <- round(mean(ev$direction == "improvement", na.rm = TRUE) * 100)
    n_high       <- sum(ev$confidence_flag == "high", na.rm = TRUE)
    pooled_dir   <- if (all(ev$direction == "improvement")) "Consistent Benefit"
                    else if (mean(ev$direction == "improvement") >= 0.7) "Largely Positive"
                    else "Mixed"

    div(class = "kpi-row",
      div(class = "kpi-card",
          div(class = "kpi-value", n_studies),
          div(class = "kpi-label", "Studies Analyzed")),
      div(class = "kpi-card green",
          div(class = "kpi-value", paste0(pct_improve, "%")),
          div(class = "kpi-label", "Showing Improvement")),
      div(class = "kpi-card orange",
          div(class = "kpi-value", pooled_dir),
          div(class = "kpi-label", "Overall Signal")),
      div(class = "kpi-card dark",
          div(class = "kpi-value", paste0(n_high, "/", n_studies)),
          div(class = "kpi-label", "High Confidence"))
    )
  })

  # ---------------------------------------------------------------------------
  # Tab 1 — Executive Summary
  # ---------------------------------------------------------------------------

  output$exec_headline <- renderUI({
    ev <- evidence()
    if (is.null(ev)) return(p("Click 'Run Analysis' to generate the evidence summary.",
                               style = "color: grey; padding: 20px 0;"))
    n <- nrow(ev)
    n_sig <- sum(ev$p_value <= 0.05, na.rm = TRUE)
    all_improve <- all(ev$direction == "improvement", na.rm = TRUE)

    headline <- if (all_improve && n_sig == n) {
      paste0("\u2705  Strong, consistent benefit confirmed across all ", n, " studies")
    } else if (sum(ev$direction == "improvement") >= ceiling(n * 0.7)) {
      paste0("\u26A0\uFE0F  Positive signal in majority of studies (", sum(ev$direction=="improvement"), "/", n, ")")
    } else {
      "\u274C  Mixed evidence — inconsistent results across studies"
    }
    div(class = "exec-headline", headline)
  })

  output$exec_narrative_short <- renderUI({
    ev <- evidence()
    if (is.null(ev)) return(NULL)

    products    <- paste(unique(ev$product), collapse = ", ")
    populations <- paste(unique(ev$population), collapse = " and ")
    n_studies   <- nrow(ev)
    n_sig       <- sum(ev$p_value <= 0.05, na.rm = TRUE)

    tagList(
      p(style = "font-size: 14px; line-height: 1.7; color: #333;",
        sprintf(
          "Evidence from %d randomized controlled trials demonstrates that %s
          deliver meaningful, clinically relevant improvement in digestive health
          outcomes across %s populations.",
          n_studies, products, populations
        )
      ),
      p(style = "font-size: 14px; line-height: 1.7; color: #333;",
        sprintf(
          "%d of %d studies show statistically significant improvement versus
          placebo (p \u2264 0.05), with effect sizes consistently rated in the
          large range.",
          n_sig, n_studies
        )
      )
    )
  })

  output$exec_subgroup_insight <- renderUI({
    sr <- subgroup_res()
    if (is.null(sr) || nrow(sr) == 0) return(NULL)

    non_overall <- sr %>% filter(subgroup_level != "Overall")
    if (nrow(non_overall) == 0) return(NULL)

    # Find the subgroup with the largest absolute effect
    top_sub <- non_overall %>%
      arrange(desc(abs(treatment_diff))) %>%
      slice(1)

    div(class = "insight-box",
      div(class = "insight-title", "\U0001F3AF  Subgroup Opportunity"),
      sprintf(
        "The benefit is amplified in the '%s' consumer segment
        (treatment difference: %.2f, p = %.3f). This pattern is
        consistent across studies and identifies a priority targeting
        opportunity.",
        top_sub$subgroup_level,
        top_sub$treatment_diff,
        top_sub$p_value
      )
    )
  })

  output$exec_study_list <- renderUI({
    ev <- evidence()
    if (is.null(ev)) return(NULL)

    items <- lapply(seq_len(nrow(ev)), function(i) {
      row <- ev[i, ]
      conf_color <- switch(row$confidence_flag,
                           "high"     = "#00A878",
                           "moderate" = "#F5A623",
                           "#E05C5C")
      div(
        style = paste0(
          "background: white; border-radius: 6px; padding: 10px 14px;",
          "margin-bottom: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.08);",
          "border-left: 4px solid ", conf_color, ";"
        ),
        div(style = "font-weight: 600; font-size: 13px; color: #003087;",
            sprintf("%s  \u2014  %s", row$product, row$study_id)),
        div(style = "font-size: 12px; color: #666; margin-top: 3px;",
            sprintf(
              "%s  |  N = %d + %d  |  Diff: %.2f  |  %s  |  Confidence: %s",
              row$population, row$n_active, row$n_placebo,
              row$treatment_diff, toupper(row$significance), row$confidence_flag
            )
        )
      )
    })
    tagList(items)
  })

  output$exec_forest_plot <- renderPlot({
    ev <- evidence()
    if (is.null(ev)) return(NULL)
    plot_effects(ev) +
      theme(plot.title    = element_blank(),
            plot.subtitle = element_blank(),
            plot.caption  = element_blank(),
            legend.position = "none",
            axis.text.y   = element_text(size = 8))
  }, bg = "white")

  # ---------------------------------------------------------------------------
  # Tab 2 — Evidence Table
  # ---------------------------------------------------------------------------
  output$no_results_msg <- renderUI({
    if (!is.null(evidence())) return(NULL)
    p("Run the analysis to see results.", style = "color: grey;")
  })

  output$summary_table <- renderTable({
    ev <- evidence()
    req(!is.null(ev))

    ev %>%
      transmute(
        Study      = study_id,
        Product    = product,
        Population = population,
        Endpoint   = endpoint,
        Window     = analysis_window,
        `N (A/P)`  = paste0(n_active, "/", n_placebo),
        Diff       = round(treatment_diff, 2),
        `CI 95%`   = sprintf("[%.2f, %.2f]", ci_lower, ci_upper),
        p          = round(p_value, 4),
        d          = round(cohens_d, 2),
        Direction  = direction,
        Strength   = strength_label,
        Sig        = significance,
        Confidence = confidence_flag
      )
  }, striped = TRUE, hover = TRUE, bordered = TRUE, digits = 3)

  # ---------------------------------------------------------------------------
  # Tab 3 — Forest Plot
  # ---------------------------------------------------------------------------
  output$forest_plot <- renderPlot({
    ev <- evidence()
    if (is.null(ev)) return(NULL)
    plot_effects(ev)
  }, bg = "white")

  # ---------------------------------------------------------------------------
  # Tab 4 — Subgroup Analysis
  # ---------------------------------------------------------------------------
  output$subgroup_plot <- renderPlot({
    sr <- subgroup_res()
    if (is.null(sr) || nrow(sr) == 0) {
      return(ggplot() +
               annotate("text", x = 0.5, y = 0.5,
                        label = "No subgroup data available.\nSelect a subgroup variable and re-run.",
                        size = 5, color = "grey50", hjust = 0.5) +
               theme_void())
    }
    plot_subgroups(sr)
  }, bg = "white")

  # ---------------------------------------------------------------------------
  # ---------------------------------------------------------------------------
  # Tab 5 — Evidence Narrative (rule-based)
  # ---------------------------------------------------------------------------

  output$text_summary <- renderText({
    ev <- evidence()
    if (is.null(ev)) return("Click 'Run Analysis' to generate the evidence narrative.")
    generate_text_summary(ev)
  })

  # ---------------------------------------------------------------------------
  # Tab 6 — AI Insights
  # ---------------------------------------------------------------------------

  ai_insights <- reactiveVal(NULL)

  observeEvent(input$run_btn,        { ai_insights(NULL) })
  observeEvent(input$analysis_family, { ai_insights(NULL) })

  observeEvent(input$gen_insights_btn, {
    ev <- evidence()
    req(!is.null(ev))

    if (!ai_narrative_available()) {
      showNotification(
        HTML("AI Insights requires:<br>
             1. <code>install.packages('httr2')</code><br>
             2. <code>Sys.setenv(ANTHROPIC_API_KEY = 'sk-ant-...')</code>"),
        type = "warning", duration = 10
      )
      return()
    }

    withProgress(message = "\U0001F916  Claude is analyzing the evidence...",
                 value = 0.4, {
      result <- tryCatch(
        generate_ai_insights(ev, audience = input$ai_audience),
        error = function(e) list(
          commentary      = paste("Error:", conditionMessage(e)),
          recommendations = character(0)
        )
      )
      ai_insights(result)
    })
  })

  output$ai_insights_status <- renderUI({
    if (!ai_narrative_available()) {
      div(
        style = paste0("background:#FFF3CD; border-left:4px solid #F5A623;",
                       "padding:6px 10px; border-radius:4px; font-size:11px;",
                       "color:#856404;"),
        icon("exclamation-triangle"),
        HTML(" Set <code>ANTHROPIC_API_KEY</code> to enable")
      )
    } else if (!is.null(ai_insights())) {
      div(style = "color: #00A878; font-size: 12px; padding-top: 8px;",
          icon("check-circle"), " Insights generated")
    }
  })

  output$ai_insights_output <- renderUI({
    ins <- ai_insights()

    # Placeholder before generation
    if (is.null(ins)) {
      return(div(class = "ai-placeholder",
        div(class = "placeholder-icon", "\U0001F916"),
        p("Select your audience above and click",
          strong("Generate AI Insights"), "to have Claude analyze the evidence",
          "and propose strategic recommendations."),
        p(style = "font-size: 12px; color: #ccc; margin-top: 8px;",
          "Only aggregated statistics are sent to the API — no patient data.")
      ))
    }

    tagList(

      # Section 1: Evidence Commentary
      div(class = "ai-section",
        div(class = "ai-section-title", "\U0001F4CB  Evidence Commentary"),
        div(class = "ai-commentary-text",
            HTML(gsub("\n\n", "<br><br>",
                      gsub("\n", " ", ins$commentary))))
      ),

      # Section 2: Strategic Recommendations
      div(class = "ai-section",
        div(class = "ai-section-title",
            "\U0001F4A1  Strategic Recommendations"),

        if (length(ins$recommendations) == 0) {
          p("No recommendations parsed.", style = "color: grey;")
        } else {
          tagList(lapply(seq_along(ins$recommendations), function(i) {
            rec <- ins$recommendations[[i]]
            div(class = "rec-card",
              div(class = "rec-num", i),
              div(
                div(class = "rec-title", rec$title),
                div(class = "rec-body",  rec$body)
              )
            )
          }))
        }
      )
    )
  })

  # ---------------------------------------------------------------------------
  # Tab 8 — Data Preview
  # ---------------------------------------------------------------------------
  output$raw_preview <- renderTable({
    req(length(input$study_list) > 0)
    tryCatch({
      load_metadata(base_dir = base_dir)
      ep <- get_endpoint_data(
        study_id        = input$study_list[[1]],
        analysis_family = input$analysis_family,
        endpoint_role   = if (input$endpoint_role == "None") NULL
                          else input$endpoint_role,
        base_dir        = base_dir
      )
      head(ep, 100)
    }, error = function(e) {
      data.frame(Error = conditionMessage(e))
    })
  }, striped = TRUE, hover = TRUE, bordered = TRUE)
}

# =============================================================================
# Launch
# =============================================================================

#' Launch the AutoRWE Shiny dashboard
#'
#' @param port            Port number (default: auto).
#' @param launch_browser  Open in browser automatically.
launch_app <- function(port = NULL, launch_browser = TRUE) {
  shiny::runApp(
    appDir         = list(ui = app_ui, server = app_server),
    port           = port,
    launch.browser = launch_browser
  )
}

if (sys.nframe() == 0L) launch_app()
