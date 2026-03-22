'use client'
import { TherapeuticAreaData, SubgroupResult } from '@/lib/types'

interface Props {
  data: TherapeuticAreaData
}

const BLUE = '#009FE3'
const DARK = '#003087'
const GREEN = '#00A878'
const ORANGE = '#F5A623'

const D_MIN = -1.5
const D_MAX = 1.5
const SVG_W = 720
const LABEL_W = 210
const VALUE_W = 130
const PLOT_X = LABEL_W
const PLOT_W = SVG_W - LABEL_W - VALUE_W
const ROW_H = 30
const GROUP_HEADER_H = 28
const HEADER_H = 52
const AXIS_H = 40
const BOTTOM_PAD = 16

function dToX(d: number): number {
  return PLOT_X + ((d - D_MIN) / (D_MAX - D_MIN)) * PLOT_W
}

function fmtP(p: number): string {
  if (p < 0.001) return '<0.001'
  if (p < 0.01) return p.toFixed(3)
  return p.toFixed(2)
}

export default function SubgroupChart({ data }: Props) {
  const { subgroups, higher_is_better } = data
  const NULL_X = dToX(0)

  // Group subgroups by study_id
  const grouped: Record<string, SubgroupResult[]> = {}
  const order: string[] = []
  for (const sg of subgroups) {
    if (!grouped[sg.study_id]) {
      grouped[sg.study_id] = []
      order.push(sg.study_id)
    }
    grouped[sg.study_id].push(sg)
  }

  // Compute total SVG height
  const nRows = subgroups.length + order.length // data rows + group headers
  const SVG_H = HEADER_H + nRows * ROW_H + order.length * (GROUP_HEADER_H - ROW_H) + AXIS_H + BOTTOM_PAD + 10

  // Build rows with y positions
  let currentY = HEADER_H
  type Row =
    | { type: 'group'; label: string; product: string; y: number }
    | { type: 'data'; sg: SubgroupResult; y: number }
  const rows: Row[] = []

  for (const studyId of order) {
    rows.push({ type: 'group', label: studyId, product: grouped[studyId][0].product, y: currentY })
    currentY += GROUP_HEADER_H
    for (const sg of grouped[studyId]) {
      rows.push({ type: 'data', sg, y: currentY + ROW_H / 2 })
      currentY += ROW_H
    }
    currentY += 6 // gap between groups
  }

  const nullLineBottom = currentY - 6

  const tickValues = [-1.5, -1.0, -0.5, 0, 0.5, 1.0, 1.5]

  return (
    <div className="overflow-x-auto bg-white rounded-xl border border-gray-200 shadow-sm p-4">
      <svg width={SVG_W} height={SVG_H + AXIS_H} viewBox={`0 0 ${SVG_W} ${SVG_H + AXIS_H}`} className="font-sans">
        {/* Column headers */}
        <text x={LABEL_W / 2} y={18} textAnchor="middle" fontSize={11} fill={DARK} fontWeight="bold">Study / Subgroup</text>
        <text x={PLOT_X + PLOT_W / 2} y={18} textAnchor="middle" fontSize={11} fill={DARK} fontWeight="bold">Cohen&apos;s d (95% CI)</text>
        <text x={PLOT_X + PLOT_W + VALUE_W / 2} y={18} textAnchor="middle" fontSize={11} fill={DARK} fontWeight="bold">d · p-value</text>

        {/* Direction labels */}
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
          x1={NULL_X} y1={HEADER_H - 6}
          x2={NULL_X} y2={nullLineBottom}
          stroke="#9ca3af" strokeWidth={1} strokeDasharray="4,3"
        />

        {/* Rows */}
        {rows.map((row, i) => {
          if (row.type === 'group') {
            return (
              <g key={`group-${row.label}`}>
                <rect
                  x={0} y={row.y - 4}
                  width={SVG_W} height={GROUP_HEADER_H - 2}
                  fill="#f0f7ff" rx={4}
                />
                <text x={8} y={row.y + 12} fontSize={11} fill={DARK} fontWeight="bold">
                  {row.product}
                </text>
                <text x={8} y={row.y + 22} fontSize={9} fill="#6b7280">
                  {row.label}
                </text>
              </g>
            )
          }

          const { sg, y } = row
          const isHigh = sg.subgroup.toLowerCase().includes('high') || sg.subgroup.toLowerCase().includes('low')
          const cx = dToX(sg.cohens_d)
          const x1 = Math.max(dToX(sg.ci_lower), PLOT_X + 2)
          const x2 = Math.min(dToX(sg.ci_upper), PLOT_X + PLOT_W - 2)
          const color = sg.significant ? (isHigh ? ORANGE : BLUE) : '#9ca3af'
          const sz = 7

          return (
            <g key={`sg-${sg.study_id}-${sg.subgroup}`}>
              <text x={LABEL_W - 8} y={y + 4} textAnchor="end" fontSize={10} fill={isHigh ? ORANGE : '#374151'} fontWeight={isHigh ? '600' : 'normal'}>
                {sg.subgroup}
              </text>
              <text x={LABEL_W - 8} y={y + 14} textAnchor="end" fontSize={8} fill="#9ca3af">
                n={sg.n}
              </text>

              <line x1={x1} y1={y} x2={x2} y2={y} stroke={color} strokeWidth={1.5} />
              <line x1={x1} y1={y - 3} x2={x1} y2={y + 3} stroke={color} strokeWidth={1.5} />
              <line x1={x2} y1={y - 3} x2={x2} y2={y + 3} stroke={color} strokeWidth={1.5} />
              <rect x={cx - sz / 2} y={y - sz / 2} width={sz} height={sz} fill={color} rx={1} />

              <text x={PLOT_X + PLOT_W + 8} y={y + 4} fontSize={10} fill={sg.significant ? DARK : '#9ca3af'} fontWeight="600">
                {sg.cohens_d >= 0 ? '+' : ''}{sg.cohens_d.toFixed(2)}
              </text>
              <text x={PLOT_X + PLOT_W + 8} y={y + 14} fontSize={8} fill={sg.significant ? '#6b7280' : '#9ca3af'}>
                p={fmtP(sg.p_value)}{sg.significant ? ' *' : ' ns'}
              </text>
            </g>
          )
        })}

        {/* X axis */}
        <line
          x1={PLOT_X} y1={SVG_H}
          x2={PLOT_X + PLOT_W} y2={SVG_H}
          stroke="#9ca3af" strokeWidth={1}
        />
        {tickValues.map(d => (
          <g key={d}>
            <line x1={dToX(d)} y1={SVG_H} x2={dToX(d)} y2={SVG_H + 5} stroke="#9ca3af" strokeWidth={1} />
            <text x={dToX(d)} y={SVG_H + 16} textAnchor="middle" fontSize={9} fill="#6b7280">{d}</text>
          </g>
        ))}
        <text x={PLOT_X + PLOT_W / 2} y={SVG_H + AXIS_H - 6} textAnchor="middle" fontSize={10} fill="#6b7280">
          Cohen&apos;s d (standardized effect size)
        </text>
      </svg>

      <div className="flex gap-6 mt-3 justify-center text-xs text-gray-500">
        <span className="flex items-center gap-1.5">
          <span className="inline-block w-3 h-3 rounded-sm" style={{ background: ORANGE }}></span>
          High-risk / Low-function baseline subgroup
        </span>
        <span className="flex items-center gap-1.5">
          <span className="inline-block w-3 h-3 rounded-sm" style={{ background: BLUE }}></span>
          Normal baseline subgroup
        </span>
        <span className="flex items-center gap-1.5">
          <span className="inline-block w-3 h-3 rounded-sm bg-gray-300"></span>
          Not significant (p&ge;0.05)
        </span>
      </div>
    </div>
  )
}
