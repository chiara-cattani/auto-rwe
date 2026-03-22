import { TherapeuticAreaData, StudyResult, PooledResult } from './types'

export function computePooled(studies: StudyResult[]): PooledResult {
  if (studies.length === 0) {
    return { cohens_d: 0, ci_lower: 0, ci_upper: 0, n_studies: 0, n_significant: 0, n_subjects_total: 0 }
  }
  if (studies.length === 1) {
    const s = studies[0]
    return {
      cohens_d: s.cohens_d,
      ci_lower: s.ci_lower,
      ci_upper: s.ci_upper,
      n_studies: 1,
      n_significant: s.significant ? 1 : 0,
      n_subjects_total: s.n_subjects,
    }
  }
  // Inverse-variance weighting
  const weights = studies.map(s => {
    const se = (s.ci_upper - s.ci_lower) / (2 * 1.96)
    return se > 0 ? 1 / (se * se) : 1
  })
  const sumW = weights.reduce((a, b) => a + b, 0)
  const pooledD = studies.reduce((acc, s, i) => acc + weights[i] * s.cohens_d, 0) / sumW
  const pooledSE = Math.sqrt(1 / sumW)
  const round2 = (n: number) => Math.round(n * 100) / 100
  return {
    cohens_d: round2(pooledD),
    ci_lower: round2(pooledD - 1.96 * pooledSE),
    ci_upper: round2(pooledD + 1.96 * pooledSE),
    n_studies: studies.length,
    n_significant: studies.filter(s => s.significant).length,
    n_subjects_total: studies.reduce((a, s) => a + s.n_subjects, 0),
  }
}

export function filterData(data: TherapeuticAreaData, selectedIds: string[]): TherapeuticAreaData {
  const studies = data.studies.filter(s => selectedIds.includes(s.study_id))
  const subgroups = data.subgroups.filter(s => selectedIds.includes(s.study_id))
  const pooled = computePooled(studies)
  return { ...data, studies, subgroups, pooled }
}
