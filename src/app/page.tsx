'use client'
import { useState } from 'react'
import { TherapeuticAreaData } from '@/lib/types'
import digestiveData from '@/data/digestive_health.json'
import boneJointData from '@/data/bone_joint_health.json'
import immuneData from '@/data/immune_support.json'
import KpiCards from '@/components/KpiCards'
import EvidenceTable from '@/components/EvidenceTable'
import ForestPlot from '@/components/ForestPlot'
import SubgroupChart from '@/components/SubgroupChart'
import AiInsights from '@/components/AiInsights'

const AREAS = [
  { id: 'digestive_health', label: 'Digestive Health', icon: '🦠', data: digestiveData as TherapeuticAreaData },
  { id: 'bone_joint_health', label: 'Bone & Joint', icon: '🦴', data: boneJointData as TherapeuticAreaData },
  { id: 'immune_support', label: 'Immune Support', icon: '🛡️', data: immuneData as TherapeuticAreaData },
]

const TABS = [
  'Executive Summary',
  'Evidence Table',
  'Forest Plot',
  'Subgroup Analysis',
  'AI Insights',
  'Platform Value',
]

export default function Home() {
  const [selectedArea, setSelectedArea] = useState('digestive_health')
  const [activeTab, setActiveTab] = useState('Executive Summary')

  const current = AREAS.find(a => a.id === selectedArea)!
  const data = current.data

  return (
    <div className="min-h-screen flex flex-col">
      {/* Header */}
      <header className="bg-danone-dark text-white shadow-lg">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center gap-4">
          <div className="bg-danone-blue rounded-lg w-10 h-10 flex items-center justify-center shrink-0">
            <span className="text-white font-black text-lg leading-none">D</span>
          </div>
          <div className="flex-1">
            <h1 className="text-lg font-bold tracking-wide leading-tight">AutoRWE Platform</h1>
            <p className="text-xs text-blue-200 leading-tight">Automated Real-World Evidence Engine · Danone Science &amp; Technology</p>
          </div>
          <div className="hidden sm:block text-right text-xs text-blue-200 leading-relaxed">
            <div className="font-semibold text-white/70 uppercase tracking-widest text-[10px]">Confidential Prototype</div>
            <div>9 Studies · 3 Therapeutic Areas</div>
          </div>
        </div>
      </header>

      <main className="flex-1 max-w-7xl mx-auto w-full px-4 sm:px-6 py-8 space-y-6">

        {/* Therapeutic area selector */}
        <div>
          <p className="text-xs font-semibold uppercase tracking-wider text-gray-400 mb-2">Therapeutic Area</p>
          <div className="flex flex-wrap gap-2">
            {AREAS.map(area => (
              <button
                key={area.id}
                onClick={() => { setSelectedArea(area.id); setActiveTab('Executive Summary') }}
                className={`inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-semibold border transition-all ${
                  selectedArea === area.id
                    ? 'bg-danone-dark text-white border-danone-dark shadow-md'
                    : 'bg-white text-gray-600 border-gray-200 hover:border-danone-blue hover:text-danone-blue'
                }`}
              >
                <span>{area.icon}</span>
                {area.label}
              </button>
            ))}
          </div>
        </div>

        {/* KPI cards */}
        <KpiCards data={data} />

        {/* Tab bar */}
        <div className="border-b border-gray-200">
          <nav className="flex gap-1 overflow-x-auto" aria-label="Tabs">
            {TABS.map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`shrink-0 px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
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
        <div>
          {activeTab === 'Executive Summary' && (
            <div className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {data.narrative.map(section => (
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
                    <p className={`text-xs font-bold uppercase tracking-wider mb-2 ${
                      section.title === 'Headline' ? 'text-danone-blue' :
                      section.title === 'Strategic Implication' ? 'text-danone-green' :
                      section.title === 'Confidence Assessment' ? 'text-emerald-600' :
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
          )}

          {activeTab === 'Evidence Table' && (
            <EvidenceTable data={data} />
          )}

          {activeTab === 'Forest Plot' && (
            <div className="space-y-4">
              <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
                <p className="text-xs text-gray-500 leading-relaxed">
                  <strong className="text-danone-dark">How to read this chart:</strong> Each square represents the
                  standardized effect size (Cohen&apos;s d) for one study; horizontal lines are 95% confidence intervals.
                  The dark diamond at the bottom is the inverse-variance weighted pooled estimate.
                  {data.higher_is_better
                    ? ' Estimates to the right of the null line (d=0) favor the active arm.'
                    : ' Estimates to the left of the null line (d=0) favor the active arm.'}
                </p>
              </div>
              <ForestPlot data={data} />
            </div>
          )}

          {activeTab === 'Subgroup Analysis' && (
            <div className="space-y-4">
              <div className="bg-danone-light border border-danone-blue/20 rounded-xl p-4">
                <p className="text-xs text-gray-600 leading-relaxed">
                  <strong className="text-danone-dark">Subgroup analysis:</strong> Subjects are stratified by baseline
                  severity. The <strong className="text-orange-500">orange markers</strong> represent the
                  high-risk / low-function subgroup; <strong className="text-danone-blue">blue markers</strong> represent
                  the normal-baseline subgroup. This consistently reveals stronger treatment effects in the
                  more severe baseline subgroup across all therapeutic areas.
                </p>
              </div>
              <SubgroupChart data={data} />
            </div>
          )}

          {activeTab === 'AI Insights' && (
            <AiInsights data={data} />
          )}

          {activeTab === 'Platform Value' && (
            <PlatformValueTab />
          )}
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-danone-dark text-white py-6 mt-8">
        <div className="max-w-7xl mx-auto px-6 text-center space-y-1">
          <p className="text-sm text-blue-100 font-medium">AutoRWE Platform · Danone Science &amp; Technology</p>
          <p className="text-xs text-blue-300">
            Confidential prototype. Synthetic study data for demonstration purposes only.
            AI insights powered by Claude (Anthropic). Not for clinical decision-making.
          </p>
        </div>
      </footer>
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
    { n: '1', title: 'Load Study Catalog', desc: 'Add a row to the metadata CSV — study ID, product, population, design type.' },
    { n: '2', title: 'Map Endpoints', desc: 'Define variable names and analysis rules in the endpoint mapping table. No code changes.' },
    { n: '3', title: 'Run Automated Analysis', desc: 'The engine extracts endpoints, computes effect sizes, and pools across studies.' },
    { n: '4', title: 'Detect Subgroup Signals', desc: 'Automatic stratification by baseline severity reveals precision targeting opportunities.' },
    { n: '5', title: 'Generate Evidence Package', desc: 'One click produces the executive dashboard, forest plot, narrative, and AI insights.' },
  ]

  return (
    <div className="space-y-8">
      {/* Before / After */}
      <div className="grid sm:grid-cols-2 gap-4">
        <div className="bg-white rounded-xl border border-red-100 shadow-sm overflow-hidden">
          <div className="bg-red-50 px-5 py-3 border-b border-red-100">
            <p className="font-bold text-red-700 text-sm">Without AutoRWE</p>
          </div>
          <ul className="divide-y divide-gray-50">
            {before.map((item, i) => (
              <li key={i} className="px-5 py-3 flex items-start gap-3 text-sm text-gray-600">
                <span className="text-red-400 font-bold mt-0.5">✗</span>
                {item}
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
                <span className="text-emerald-500 font-bold mt-0.5">✓</span>
                {item}
              </li>
            ))}
          </ul>
        </div>
      </div>

      {/* How it works */}
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

      {/* Scalability card */}
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
