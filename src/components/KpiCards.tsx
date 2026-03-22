'use client'
import { TherapeuticAreaData } from '@/lib/types'

interface Props {
  data: TherapeuticAreaData
}

function Card({ label, value, sub, accent }: { label: string; value: string; sub: string; accent: string }) {
  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5 flex flex-col gap-1">
      <span className="text-xs font-semibold uppercase tracking-wider text-gray-400">{label}</span>
      <span className={`text-3xl font-bold ${accent}`}>{value}</span>
      <span className="text-xs text-gray-500">{sub}</span>
    </div>
  )
}

function confidenceLabel(nSig: number, nTotal: number): string {
  const pct = nSig / nTotal
  if (pct >= 0.8) return 'High'
  if (pct >= 0.5) return 'Moderate'
  return 'Low'
}

function confidenceColor(nSig: number, nTotal: number): string {
  const pct = nSig / nTotal
  if (pct >= 0.8) return 'text-emerald-600'
  if (pct >= 0.5) return 'text-amber-500'
  return 'text-red-500'
}

export default function KpiCards({ data }: Props) {
  const { pooled, higher_is_better } = data
  const pct = Math.round((pooled.n_significant / pooled.n_studies) * 100)
  const dSign = pooled.cohens_d >= 0 ? '+' : ''
  const dLabel = `${dSign}${pooled.cohens_d.toFixed(2)}`
  const dSub = higher_is_better
    ? `Favors active (higher is better)`
    : `Favors active (lower is better)`

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <Card
        label="Studies Analyzed"
        value={String(pooled.n_studies)}
        sub="Randomized controlled trials"
        accent="text-danone-dark"
      />
      <Card
        label="Total Subjects"
        value={pooled.n_subjects_total.toLocaleString()}
        sub="Across all studies"
        accent="text-danone-blue"
      />
      <Card
        label="Pooled Effect Size"
        value={dLabel}
        sub={dSub}
        accent={Math.abs(pooled.cohens_d) >= 0.5 ? 'text-emerald-600' : 'text-amber-500'}
      />
      <Card
        label="Evidence Strength"
        value={confidenceLabel(pooled.n_significant, pooled.n_studies)}
        sub={`${pooled.n_significant}/${pooled.n_studies} studies significant (${pct}%)`}
        accent={confidenceColor(pooled.n_significant, pooled.n_studies)}
      />
    </div>
  )
}
