'use client'
import { TherapeuticAreaData } from '@/lib/types'

interface Props {
  data: TherapeuticAreaData
}

const BLUE = '#009FE3'
const DARK = '#003087'
const GREEN = '#00A878'

const D_MIN = -1.5
const D_MAX = 1.5
const SVG_W = 780
const LABEL_W = 215
const VALUE_W = 155
const PLOT_X = LABEL_W
const PLOT_W = SVG_W - LABEL_W - VALUE_W
const ROW_H = 38
const HEADER_H = 56
const AXIS_H = 42
const BOTTOM_PAD = 16

function dToX(d: number): number {
  return PLOT_X + ((d - D_MIN) / (D_MAX - D_MIN)) * PLOT_W
}

function fmtP(p: number): string {
  if (p < 0.001) return '<0.001'
  if (p < 0.01) return p.toFixed(3)
  return p.toFixed(2)
}

function fmtD(d: number): string {
  return (d >= 0 ? '+' : '') + d.toFixed(2)
}

export default function ForestPlot({ data }: Props) {
  const { studies, pooled, higher_is_better } = data
  const N = studies.length
  const NULL_X = dToX(0)

  const SVG_H = HEADER_H + N * ROW_H + 20 + ROW_H + AXIS_H + BOTTOM_PAD

  const tickValues = [-1.5, -1.0, -0.5, 0, 0.5, 1.0, 1.5]

  return (
    <div className="overflow-x-auto bg-white rounded-xl border border-gray-200 shadow-sm p-4">
      <svg
        width={SVG_W}
        height={SVG_H}
        viewBox={`0 0 ${SVG_W} ${SVG_H}`}
        className="font-sans"
      >
        {/* Column headers */}
        <text x={LABEL_W / 2} y={18} textAnchor="middle" fontSize={11} fill={DARK} fontWeight="bold">Study / Product</text>
        <text x={PLOT_X + PLOT_W / 2} y={18} textAnchor="middle" fontSize={11} fill={DARK} fontWeight="bold">Cohen&apos;s d (95% CI)</text>
        <text x={PLOT_X + PLOT_W + VALUE_W / 2} y={18} textAnchor="middle" fontSize={11} fill={DARK} fontWeight="bold">d [95% CI] · p</text>

        {/* Directional labels */}
        {higher_is_better ? (
          <>
            <text x={PLOT_X + 6} y={36} fontSize={9} fill="#999">Favors Placebo</text>
            <text x={PLOT_X + PLOT_W - 6} y={36} textAnchor="end" fontSize={9} fill={GREEN}>Favors Active</text>
          </>
        ) : (
          <>
            <text x={PLOT_X + 6} y={36} fontSize={9} fill={GREEN}>Favors Active</text>
            <text x={PLOT_X + PLOT_W - 6} y={36} textAnchor="end" fontSize={9} fill="#999">Favors Placebo</text>
          </>
        )}
        <line x1={PLOT_X + 6} y1={40} x2={PLOT_X + PLOT_W - 6} y2={40} stroke="#e5e7eb" strokeWidth={1} />

        {/* Null line */}
        <line
          x1={NULL_X} y1={HEADER_H - 8}
          x2={NULL_X} y2={HEADER_H + N * ROW_H + 18}
          stroke="#9ca3af" strokeWidth={1} strokeDasharray="4,3"
        />

        {/* Study rows */}
        {studies.map((s, i) => {
          const y = HEADER_H + i * ROW_H + ROW_H / 2
          const cx = dToX(s.cohens_d)
          const x1 = Math.max(dToX(s.ci_lower), PLOT_X + 2)
          const x2 = Math.min(dToX(s.ci_upper), PLOT_X + PLOT_W - 2)
          const color = s.significant ? (higher_is_better ? GREEN : BLUE) : '#9ca3af'
          const sz = 8

          return (
            <g key={s.study_id}>
              <text x={LABEL_W - 8} y={y - 2} textAnchor="end" fontSize={11} fill={DARK} fontWeight="600">
                {s.product}
              </text>
              <text x={LABEL_W - 8} y={y + 12} textAnchor="end" fontSize={9} fill="#6b7280">
                {s.population} · n={s.n_subjects} · Ph{s.phase}
              </text>

              {/* CI whiskers */}
              <line x1={x1} y1={y} x2={x2} y2={y} stroke={color} strokeWidth={1.5} />
              <line x1={x1} y1={y - 4} x2={x1} y2={y + 4} stroke={color} strokeWidth={1.5} />
              <line x1={x2} y1={y - 4} x2={x2} y2={y + 4} stroke={color} strokeWidth={1.5} />
              {/* Point estimate square */}
              <rect x={cx - sz / 2} y={y - sz / 2} width={sz} height={sz} fill={color} rx={1} />

              {/* Value column */}
              <text x={PLOT_X + PLOT_W + 8} y={y - 2} fontSize={11} fill={s.significant ? DARK : '#9ca3af'} fontWeight={s.significant ? '600' : 'normal'}>
                {fmtD(s.cohens_d)} [{s.ci_lower.toFixed(2)}, {s.ci_upper.toFixed(2)}]
              </text>
              <text x={PLOT_X + PLOT_W + 8} y={y + 12} fontSize={9} fill={s.significant ? GREEN : '#9ca3af'}>
                p={fmtP(s.p_value)}{s.significant ? '  *' : '  ns'}
              </text>
            </g>
          )
        })}

        {/* Separator before pooled */}
        <line
          x1={PLOT_X} y1={HEADER_H + N * ROW_H + 8}
          x2={PLOT_X + PLOT_W} y2={HEADER_H + N * ROW_H + 8}
          stroke="#d1d5db" strokeWidth={1}
        />

        {/* Pooled diamond */}
        {(() => {
          const py = HEADER_H + N * ROW_H + 22 + ROW_H / 2
          const cx = dToX(pooled.cohens_d)
          const x1 = Math.max(dToX(pooled.ci_lower), PLOT_X + 2)
          const x2 = Math.min(dToX(pooled.ci_upper), PLOT_X + PLOT_W - 2)
          const dh = 9
          const pts = `${x1},${py} ${cx},${py - dh} ${x2},${py} ${cx},${py + dh}`
          return (
            <g>
              <text x={LABEL_W - 8} y={py - 2} textAnchor="end" fontSize={11} fill={DARK} fontWeight="bold">
                Pooled Estimate
              </text>
              <text x={LABEL_W - 8} y={py + 12} textAnchor="end" fontSize={9} fill="#6b7280">
                {pooled.n_studies} studies · N={pooled.n_subjects_total.toLocaleString()}
              </text>
              <polygon points={pts} fill={DARK} opacity={0.85} />
              <text x={PLOT_X + PLOT_W + 8} y={py - 2} fontSize={11} fill={DARK} fontWeight="bold">
                {fmtD(pooled.cohens_d)} [{pooled.ci_lower.toFixed(2)}, {pooled.ci_upper.toFixed(2)}]
              </text>
              <text x={PLOT_X + PLOT_W + 8} y={py + 12} fontSize={9} fill={GREEN}>
                {pooled.n_significant}/{pooled.n_studies} significant
              </text>
            </g>
          )
        })()}

        {/* X axis */}
        <line
          x1={PLOT_X} y1={SVG_H - AXIS_H}
          x2={PLOT_X + PLOT_W} y2={SVG_H - AXIS_H}
          stroke="#9ca3af" strokeWidth={1}
        />
        {tickValues.map(d => (
          <g key={d}>
            <line
              x1={dToX(d)} y1={SVG_H - AXIS_H}
              x2={dToX(d)} y2={SVG_H - AXIS_H + 5}
              stroke="#9ca3af" strokeWidth={1}
            />
            <text x={dToX(d)} y={SVG_H - AXIS_H + 16} textAnchor="middle" fontSize={9} fill="#6b7280">
              {d}
            </text>
          </g>
        ))}
        <text
          x={PLOT_X + PLOT_W / 2} y={SVG_H - 4}
          textAnchor="middle" fontSize={10} fill="#6b7280"
        >
          Cohen&apos;s d (standardized effect size)
        </text>
      </svg>

      <p className="text-xs text-gray-400 mt-3 text-center">
        Squares represent point estimates; horizontal lines show 95% confidence intervals.
        Diamond represents inverse-variance pooled estimate. Dashed line at d=0 (no effect).
      </p>
    </div>
  )
}
