export interface StudyResult {
  study_id: string
  product: string
  population: string
  n_subjects: number
  phase: string
  endpoint: string
  endpoint_var: string
  higher_is_better: boolean
  baseline_mean: number
  active_change: number
  placebo_change: number
  treatment_diff: number
  cohens_d: number
  ci_lower: number
  ci_upper: number
  p_value: number
  significant: boolean
}

export interface SubgroupResult {
  study_id: string
  product: string
  subgroup: string
  cohens_d: number
  ci_lower: number
  ci_upper: number
  p_value: number
  n: number
  significant: boolean
}

export interface PooledResult {
  cohens_d: number
  ci_lower: number
  ci_upper: number
  n_studies: number
  n_significant: number
  n_subjects_total: number
}

export interface NarrativeSection {
  title: string
  content: string
}

export interface TherapeuticAreaData {
  therapeutic_area: string
  label: string
  endpoint_description: string
  higher_is_better: boolean
  studies: StudyResult[]
  pooled: PooledResult
  subgroups: SubgroupResult[]
  narrative: NarrativeSection[]
}

export interface AiRecommendation {
  title: string
  body: string
}

export interface AiInsightsResponse {
  commentary: string
  recommendations: AiRecommendation[]
}
