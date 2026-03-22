'use client'
import { TherapeuticAreaData } from '@/lib/types'

interface Props {
  data: TherapeuticAreaData
}

function fmt(n: number, decimals = 2): string {
  return n.toFixed(decimals)
}

function fmtP(p: number): string {
  if (p < 0.001) return '<0.001'
  if (p < 0.01) return p.toFixed(3)
  return p.toFixed(2)
}

function fmtChange(n: number): string {
  return n >= 0 ? `+${n.toFixed(1)}` : n.toFixed(1)
}

export default function EvidenceTable({ data }: Props) {
  const { studies, higher_is_better } = data

  return (
    <div className="overflow-x-auto rounded-xl border border-gray-200 shadow-sm">
      <table className="w-full text-sm text-left">
        <thead>
          <tr className="bg-danone-dark text-white">
            <th className="px-4 py-3 font-semibold whitespace-nowrap">Product</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap">Population</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap text-center">N</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap">Phase</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap">Endpoint</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap text-center">Baseline</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap text-center">Active</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap text-center">Placebo</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap text-center">Diff</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap text-center">Cohen's d</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap text-center">p-value</th>
            <th className="px-4 py-3 font-semibold whitespace-nowrap text-center">Result</th>
          </tr>
        </thead>
        <tbody>
          {studies.map((s, i) => {
            const activeFavored = higher_is_better
              ? s.treatment_diff > 0
              : s.treatment_diff < 0

            return (
              <tr
                key={s.study_id}
                className={`border-t border-gray-100 ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50'} hover:bg-danone-light transition-colors`}
              >
                <td className="px-4 py-3 font-medium text-danone-dark whitespace-nowrap">
                  {s.product}
                </td>
                <td className="px-4 py-3 text-gray-600 whitespace-nowrap">{s.population}</td>
                <td className="px-4 py-3 text-center font-mono">{s.n_subjects}</td>
                <td className="px-4 py-3 text-center">
                  <span className={`inline-block px-2 py-0.5 rounded text-xs font-bold ${s.phase === 'III' ? 'bg-danone-blue text-white' : 'bg-danone-orange text-white'}`}>
                    {s.phase}
                  </span>
                </td>
                <td className="px-4 py-3 text-gray-600 text-xs whitespace-nowrap">{s.endpoint}</td>
                <td className="px-4 py-3 text-center font-mono">{fmt(s.baseline_mean)}</td>
                <td className="px-4 py-3 text-center font-mono">{fmtChange(s.active_change)}</td>
                <td className="px-4 py-3 text-center font-mono text-gray-400">{fmtChange(s.placebo_change)}</td>
                <td className={`px-4 py-3 text-center font-mono font-semibold ${activeFavored ? 'text-emerald-600' : 'text-red-500'}`}>
                  {fmtChange(s.treatment_diff)}
                </td>
                <td className="px-4 py-3 text-center font-mono">
                  <span className={`font-semibold ${s.significant ? 'text-danone-dark' : 'text-gray-400'}`}>
                    {s.cohens_d >= 0 ? '+' : ''}{fmt(s.cohens_d)}
                  </span>
                  <span className="block text-xs text-gray-400">
                    [{fmt(s.ci_lower)}, {fmt(s.ci_upper)}]
                  </span>
                </td>
                <td className="px-4 py-3 text-center font-mono">{fmtP(s.p_value)}</td>
                <td className="px-4 py-3 text-center">
                  {s.significant ? (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-700">
                      Significant
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-gray-100 text-gray-500">
                      n.s.
                    </span>
                  )}
                </td>
              </tr>
            )
          })}
        </tbody>
        <tfoot>
          <tr className="border-t-2 border-danone-dark bg-danone-light">
            <td colSpan={2} className="px-4 py-3 font-bold text-danone-dark">
              Pooled Estimate (inverse-variance)
            </td>
            <td className="px-4 py-3 text-center font-mono font-bold text-danone-dark">
              {data.pooled.n_subjects_total}
            </td>
            <td colSpan={6} className="px-4 py-3 text-center text-gray-500 text-xs">—</td>
            <td className="px-4 py-3 text-center font-mono font-bold text-danone-dark">
              {data.pooled.cohens_d >= 0 ? '+' : ''}{fmt(data.pooled.cohens_d)}
              <span className="block text-xs font-normal text-gray-500">
                [{fmt(data.pooled.ci_lower)}, {fmt(data.pooled.ci_upper)}]
              </span>
            </td>
            <td colSpan={2} className="px-4 py-3 text-center">
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-danone-blue text-white">
                {data.pooled.n_significant}/{data.pooled.n_studies} sig.
              </span>
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
  )
}
