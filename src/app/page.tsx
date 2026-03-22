'use client'
import { useState, useMemo } from 'react'
import { TherapeuticAreaData } from '@/lib/types'
import { filterData } from '@/lib/analysis'
import digestiveData from '@/data/digestive_health.json'
import boneJointData from '@/data/bone_joint_health.json'
import immuneData from '@/data/immune_support.json'
import KpiCards from '@/components/KpiCards'
import EvidenceTable from '@/components/EvidenceTable'
import ForestPlot from '@/components/ForestPlot'
import SubgroupChart from '@/components/SubgroupChart'
import AiInsights from '@/components/AiInsights'

const AREAS = [
  { id: 'digestive_health',  label: 'Digestive Health', icon: '🦠', data: digestiveData as TherapeuticAreaData },
  { id: 'bone_joint_health', label: 'Bone & Joint',     icon: '🦴', data: boneJointData as TherapeuticAreaData },
  { id: 'immune_support',    label: 'Immune Support',   icon: '🛡️', data: immuneData   as TherapeuticAreaData },
]

const TABS = ['Executive Summary', 'Evidence Table', 'Forest Plot', 'Subgroup Analysis', 'AI Insights', 'Platform Value']

export default function Home() {
  const [selectedArea, setSelectedArea]     = useState('digestive_health')
  const [selectedStudies, setSelectedStudies] = useState<string[]>(
    () => digestiveData.studies.map(s => s.study_id)
  )
  const [activeTab, setActiveTab]           = useState('Executive Summary')
  const [sidebarOpen, setSidebarOpen]       = useState(false)

  const current = AREAS.find(a => a.id === selectedArea)!

  const filteredData = useMemo(
    () => selectedStudies.length > 0 ? filterData(current.data, selectedStudies) : null,
    [current.data, selectedStudies]
  )

  function handleAreaChange(id: string) {
    const area = AREAS.find(a => a.id === id)!
    setSelectedArea(id)
    setSelectedStudies(area.data.studies.map(s => s.study_id))
    setActiveTab('Executive Summary')
    setSidebarOpen(false)
  }

  function toggleStudy(id: string) {
    setSelectedStudies(prev =>
      prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]
    )
  }

  const allStudies = current.data.studies
  const totalN = allStudies
    .filter(s => selectedStudies.includes(s.study_id))
    .reduce((a, s) => a + s.n_subjects, 0)

  return (
    <div className="min-h-screen flex flex-col bg-gray-50">

      {/* ── Header ── */}
      <header className="bg-danone-dark text-white shadow-lg">
        <div className="max-w-screen-xl mx-auto px-4 sm:px-6 py-3 flex items-center gap-3">
          {/* Mobile sidebar toggle */}
          <button
            className="lg:hidden p-2 rounded-md hover:bg-white/10 transition-colors"
            onClick={() => setSidebarOpen(o => !o)}
            aria-label="Toggle filters"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>

          <div className="bg-danone-blue rounded-lg w-9 h-9 flex items-center justify-center shrink-0">
            <span className="text-white font-black text-base leading-none">D</span>
          </div>
          <div className="flex-1">
            <h1 className="text-base font-bold tracking-wide leading-tight">AutoRWE Platform</h1>
            <p className="text-[11px] text-blue-200 leading-tight">Automated Real-World Evidence Engine · Danone Science &amp; Technology</p>
          </div>
          <div className="hidden sm:flex items-center gap-2">
            <span className="text-[10px] font-bold uppercase tracking-widest bg-danone-blue/30 text-blue-100 border border-blue-400/30 px-2 py-0.5 rounded">
              PROTOTYPE
            </span>
            <span className="text-[11px] text-blue-300">{AREAS.length} areas · 9 studies</span>
          </div>
        </div>
      </header>

      <div className="flex-1 max-w-screen-xl mx-auto w-full flex">

        {/* ── Sidebar overlay (mobile) ── */}
        {sidebarOpen && (
          <div
            className="fixed inset-0 z-20 bg-black/40 lg:hidden"
            onClick={() => setSidebarOpen(false)}
          />
        )}

        {/* ── Sidebar ── */}
        <aside className={`
          fixed lg:static inset-y-0 left-0 z-30 w-64 shrink-0
          bg-white border-r border-gray-200 shadow-xl lg:shadow-none
          transform transition-transform duration-200
          ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'}
          lg:translate-x-0 lg:block
          overflow-y-auto flex flex-col
        `}>
          <div className="p-4 space-y-5 flex-1">

            {/* Therapeutic Area */}
            <section>
              <p className="text-[10px] font-bold uppercase tracking-widest text-gray-400 mb-2">
                Therapeutic Area
              </p>
              <div className="space-y-1">
                {AREAS.map(area => (
                  <button
                    key={area.id}
                    onClick={() => handleAreaChange(area.id)}
                    className={`w-full text-left px-3 py-2.5 rounded-lg text-sm font-medium transition-colors flex items-center gap-2.5 ${
                      selectedArea === area.id
                        ? 'bg-danone-dark text-white shadow-sm'
                        : 'text-gray-600 hover:bg-gray-50 hover:text-danone-dark'
                    }`}
                  >
                    <span className="text-base">{area.icon}</span>
                    <span>{area.label}</span>
                  </button>
                ))}
              </div>
            </section>

            {/* Study selector */}
            <section>
              <div className="flex items-center justify-between mb-2">
                <p className="text-[10px] font-bold uppercase tracking-widest text-gray-400">Studies</p>
                <div className="flex gap-2 text-[11px]">
                  <button
                    onClick={() => setSelectedStudies(allStudies.map(s => s.study_id))}
                    className="text-danone-blue font-medium hover:underline"
                  >All</button>
                  <span className="text-gray-300">·</span>
                  <button
                    onClick={() => setSelectedStudies([])}
                    className="text-gray-400 font-medium hover:underline"
                  >Clear</button>
                </div>
              </div>

              <div className="space-y-2.5">
                {allStudies.map(s => {
                  const checked = selectedStudies.includes(s.study_id)
                  return (
                    <label
                      key={s.study_id}
                      className="flex items-start gap-2.5 cursor-pointer group"
                    >
                      <div className="mt-0.5 shrink-0">
                        <div
                          onClick={() => toggleStudy(s.study_id)}
                          className={`w-4 h-4 rounded border-2 flex items-center justify-center transition-colors cursor-pointer ${
                            checked
                              ? 'bg-danone-blue border-danone-blue'
                              : 'border-gray-300 bg-white group-hover:border-danone-blue'
                          }`}
                        >
                          {checked && (
                            <svg className="w-2.5 h-2.5 text-white" fill="none" viewBox="0 0 12 12" stroke="currentColor" strokeWidth="2.5">
                              <path d="M2 6l3 3 5-5" />
                            </svg>
                          )}
                        </div>
                      </div>
                      <div onClick={() => toggleStudy(s.study_id)} className="flex-1">
                        <p className={`text-sm leading-tight transition-colors ${
                          checked ? 'font-medium text-danone-dark' : 'text-gray-500'
                        }`}>
                          {s.product}
                        </p>
                        <p className="text-[10px] text-gray-400 leading-tight mt-0.5">
                          {s.population} · Ph{s.phase} · n={s.n_subjects}
                        </p>
                      </div>
                    </label>
                  )
                })}
              </div>
            </section>
          </div>

          {/* Selection summary footer */}
          <div className="p-4 border-t border-gray-100 bg-gray-50">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs font-semibold text-danone-dark">
                  {selectedStudies.length}/{allStudies.length} studies
                </p>
                <p className="text-[11px] text-gray-500">N = {totalN.toLocaleString()} subjects</p>
              </div>
              {selectedStudies.length > 0 && selectedStudies.length < allStudies.length && (
                <span className="text-[10px] bg-danone-orange/20 text-danone-orange font-bold px-2 py-0.5 rounded-full">
                  FILTERED
                </span>
              )}
              {selectedStudies.length === allStudies.length && (
                <span className="text-[10px] bg-emerald-100 text-emerald-600 font-bold px-2 py-0.5 rounded-full">
                  ALL
                </span>
              )}
            </div>
          </div>
        </aside>

        {/* ── Main content ── */}
        <main className="flex-1 min-w-0 px-4 sm:px-6 py-6 space-y-5">

          {filteredData ? (
            <>
              {/* Selection banner when filtered */}
              {selectedStudies.length < allStudies.length && (
                <div className="bg-danone-orange/10 border border-danone-orange/30 rounded-lg px-4 py-2.5 flex items-center gap-3">
                  <svg className="w-4 h-4 text-danone-orange shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                    <path d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2a1 1 0 01-.293.707L13 13.414V19a1 1 0 01-.553.894l-4 2A1 1 0 017 21v-7.586L3.293 6.707A1 1 0 013 6V4z"/>
                  </svg>
                  <p className="text-sm text-gray-700">
                    Showing <strong className="text-danone-dark">{selectedStudies.length} of {allStudies.length} studies</strong> for {current.label}.
                    Pooled estimates are recomputed for your selection.
                  </p>
                </div>
              )}

              <KpiCards data={filteredData} />

              {/* Tab bar */}
              <div className="border-b border-gray-200">
                <nav className="flex gap-0 overflow-x-auto">
                  {TABS.map(tab => (
                    <button
                      key={tab}
                      onClick={() => setActiveTab(tab)}
                      className={`shrink-0 px-4 py-2.5 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
                        activeTab === tab
                          ? 'border-danone-blue text-danone-blue'
                          : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                      }`}
                    >
                      {tab}
                    </button>
                  ))}
                </nav>
              </div>

              {/* Tab content */}
              {activeTab === 'Executive Summary' && (
                <ExecutiveSummaryTab data={filteredData} fullData={current.data} selectedCount={selectedStudies.length} totalCount={allStudies.length} />
              )}
              {activeTab === 'Evidence Table'    && <EvidenceTable data={filteredData} />}
              {activeTab === 'Forest Plot'        && <ForestPlotTab data={filteredData} />}
              {activeTab === 'Subgroup Analysis'  && <SubgroupTab data={filteredData} />}
              {activeTab === 'AI Insights'        && <AiInsights data={filteredData} />}
              {activeTab === 'Platform Value'     && <PlatformValueTab />}
            </>
          ) : (
            <div className="flex flex-col items-center justify-center py-24 text-center">
              <div className="text-5xl mb-4">📊</div>
              <p className="text-xl font-semibold text-danone-dark mb-2">No studies selected</p>
              <p className="text-gray-500 text-sm">Select at least one study from the left panel to run the analysis.</p>
            </div>
          )}
        </main>
      </div>

      {/* ── Footer ── */}
      <footer className="bg-danone-dark text-white py-5">
        <div className="max-w-screen-xl mx-auto px-6 text-center space-y-1">
          <p className="text-sm text-blue-100 font-medium">AutoRWE Platform · Danone Science &amp; Technology</p>
          <p className="text-[11px] text-blue-300">
            Prototype — synthetic data for demonstration only. AI insights powered by Claude (Anthropic).
          </p>
        </div>
      </footer>
    </div>
  )
}

/* ── Tab sub-components ── */

function ExecutiveSummaryTab({
  data, fullData, selectedCount, totalCount,
}: {
  data: TherapeuticAreaData
  fullData: TherapeuticAreaData
  selectedCount: number
  totalCount: number
}) {
  const narrative = selectedCount === totalCount ? data.narrative : fullData.narrative
  return (
    <div className="space-y-4">
      {selectedCount < totalCount && (
        <p className="text-xs text-gray-400 italic">
          Narrative reflects the full {totalCount}-study analysis. Quantitative tabs show your selection ({selectedCount} studies).
        </p>
      )}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {narrative.map(section => (
          <div
            key={section.title}
            className={`bg-white rounded-xl border shadow-sm p-5 ${
              section.title === 'Headline'
                ? 'sm:col-span-2 lg:col-span-3 border-danone-blue/30 bg-danone-light'
                : section.title === 'Strategic Implication'
                ? 'sm:col-span-2 border-danone-green/30'
                : 'border-gray-100'
            }`}
          >
            <p className={`text-[10px] font-bold uppercase tracking-widest mb-2 ${
              section.title === 'Headline'              ? 'text-danone-blue'  :
              section.title === 'Strategic Implication' ? 'text-danone-green' :
              section.title === 'Confidence Assessment' ? 'text-emerald-600'  :
              'text-danone-dark'
            }`}>
              {section.title}
            </p>
            <p className={`text-sm leading-relaxed text-gray-700 ${
              section.title === 'Headline' ? 'font-semibold text-danone-dark text-base' : ''
            }`}>
              {section.content}
            </p>
          </div>
        ))}
      </div>
    </div>
  )
}

function ForestPlotTab({ data }: { data: TherapeuticAreaData }) {
  return (
    <div className="space-y-3">
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
        <p className="text-xs text-gray-500 leading-relaxed">
          <strong className="text-danone-dark">How to read this chart:</strong> Each square is the
          standardized effect size (Cohen&apos;s d); horizontal lines are 95% confidence intervals.
          {data.pooled.n_studies > 1 && ' The dark diamond is the inverse-variance pooled estimate.'}
          {data.higher_is_better
            ? ' Estimates to the right of the null line (d=0) favor the active arm.'
            : ' Estimates to the left of the null line (d=0) favor the active arm.'}
        </p>
      </div>
      <ForestPlot data={data} />
    </div>
  )
}

function SubgroupTab({ data }: { data: TherapeuticAreaData }) {
  if (data.subgroups.length === 0) {
    return (
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-10 text-center text-gray-400 text-sm">
        No subgroup data available for the current selection.
      </div>
    )
  }
  return (
    <div className="space-y-3">
      <div className="bg-danone-light border border-danone-blue/20 rounded-xl p-4">
        <p className="text-xs text-gray-600 leading-relaxed">
          <strong className="text-danone-dark">Subgroup analysis:</strong> Subjects stratified by baseline severity.{' '}
          <strong className="text-orange-500">Orange</strong> = high-risk / low-function baseline;{' '}
          <strong className="text-danone-blue">blue</strong> = normal baseline.
          The consistently larger effect in high-risk subgroups reveals a precision targeting opportunity.
        </p>
      </div>
      <SubgroupChart data={data} />
    </div>
  )
}

function PlatformValueTab() {
  const before = [
    'Manual literature search: 2–4 weeks per therapeutic area',
    'Ad-hoc R/SAS scripts: no reuse across studies',
    'Evidence dossiers: compiled manually by statisticians',
    'Subgroup insights: identified late or missed entirely',
    'AI-assisted synthesis: not available',
  ]
  const after = [
    'Automated evidence aggregation: minutes per run',
    'Metadata-driven engine: add a study with 1 CSV row',
    'Executive dashboards: auto-generated on demand',
    'Subgroup signals: detected and quantified automatically',
    'Claude AI synthesis: strategic commentary at a click',
  ]
  const steps = [
    { n: '1', title: 'Load Study Catalog',     desc: 'Add a row to the metadata CSV — study ID, product, population, design type.' },
    { n: '2', title: 'Map Endpoints',           desc: 'Define variable names and analysis rules in the endpoint mapping table. No code changes.' },
    { n: '3', title: 'Run Automated Analysis',  desc: 'The engine extracts endpoints, computes effect sizes, and pools across studies.' },
    { n: '4', title: 'Detect Subgroup Signals', desc: 'Automatic stratification by baseline severity reveals precision targeting opportunities.' },
    { n: '5', title: 'Generate Evidence Package', desc: 'One click produces the executive dashboard, forest plot, narrative, and AI insights.' },
  ]
  return (
    <div className="space-y-8">
      <div className="grid sm:grid-cols-2 gap-4">
        <div className="bg-white rounded-xl border border-red-100 shadow-sm overflow-hidden">
          <div className="bg-red-50 px-5 py-3 border-b border-red-100">
            <p className="font-bold text-red-700 text-sm">Without AutoRWE</p>
          </div>
          <ul className="divide-y divide-gray-50">
            {before.map((item, i) => (
              <li key={i} className="px-5 py-3 flex items-start gap-3 text-sm text-gray-600">
                <span className="text-red-400 font-bold mt-0.5">✗</span>{item}
              </li>
            ))}
          </ul>
        </div>
        <div className="bg-white rounded-xl border border-emerald-100 shadow-sm overflow-hidden">
          <div className="bg-emerald-50 px-5 py-3 border-b border-emerald-100">
            <p className="font-bold text-emerald-700 text-sm">With AutoRWE</p>
          </div>
          <ul className="divide-y divide-gray-50">
            {after.map((item, i) => (
              <li key={i} className="px-5 py-3 flex items-start gap-3 text-sm text-gray-600">
                <span className="text-emerald-500 font-bold mt-0.5">✓</span>{item}
              </li>
            ))}
          </ul>
        </div>
      </div>
      <div>
        <h3 className="text-base font-bold text-danone-dark mb-4">How It Works — 5 Steps</h3>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          {steps.map(step => (
            <div key={step.n} className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
              <div className="w-8 h-8 rounded-full bg-danone-dark text-white font-bold text-sm flex items-center justify-center mb-3">
                {step.n}
              </div>
              <p className="font-semibold text-danone-dark text-sm mb-1">{step.title}</p>
              <p className="text-xs text-gray-500 leading-relaxed">{step.desc}</p>
            </div>
          ))}
        </div>
      </div>
      <div className="bg-danone-dark text-white rounded-xl p-6 grid sm:grid-cols-3 gap-6 text-center">
        <div>
          <div className="text-3xl font-black text-danone-blue">50+</div>
          <div className="text-sm text-blue-200 mt-1">Studies scalable with no code changes</div>
        </div>
        <div>
          <div className="text-3xl font-black text-danone-green">∞</div>
          <div className="text-sm text-blue-200 mt-1">Therapeutic areas via metadata extension</div>
        </div>
        <div>
          <div className="text-3xl font-black text-danone-orange">90%</div>
          <div className="text-sm text-blue-200 mt-1">Estimated reduction in evidence synthesis time</div>
        </div>
      </div>
    </div>
  )
}
