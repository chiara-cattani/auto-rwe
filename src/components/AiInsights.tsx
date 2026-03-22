'use client'
import { useState } from 'react'
import { TherapeuticAreaData, AiInsightsResponse } from '@/lib/types'

interface Props {
  data: TherapeuticAreaData
}

export default function AiInsights({ data }: Props) {
  const [result, setResult] = useState<AiInsightsResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function generate() {
    setLoading(true)
    setError(null)
    setResult(null)
    try {
      const res = await fetch('/api/ai-insights', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data }),
      })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.error ?? `Server error ${res.status}`)
      }
      const json: AiInsightsResponse = await res.json()
      setResult(json)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Unknown error')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-6">
      {/* Header card */}
      <div className="bg-danone-light border border-danone-blue/20 rounded-xl p-5 flex flex-col sm:flex-row sm:items-center gap-4">
        <div className="flex-1">
          <h3 className="font-bold text-danone-dark text-base">AI-Generated Strategic Insights</h3>
          <p className="text-sm text-gray-600 mt-1">
            Claude (Anthropic) analyzes the <strong>aggregated study metrics</strong> for{' '}
            <strong>{data.label}</strong> and generates scientific commentary with business
            recommendations. No patient-level data is shared.
          </p>
        </div>
        <button
          onClick={generate}
          disabled={loading}
          className="shrink-0 inline-flex items-center gap-2 px-5 py-2.5 rounded-lg font-semibold text-sm text-white bg-danone-dark hover:bg-danone-blue transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
        >
          {loading ? (
            <>
              <svg className="animate-spin w-4 h-4" viewBox="0 0 24 24" fill="none">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z" />
              </svg>
              Generating...
            </>
          ) : (
            <>
              <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M9.663 17h4.673M12 3v1m6.364 1.636-.707.707M21 12h-1M4 12H3m3.343-5.657-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
              {result ? 'Regenerate' : 'Generate AI Insights'}
            </>
          )}
        </button>
      </div>

      {/* Error */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-4">
          <p className="text-sm font-semibold text-red-700">Failed to generate insights</p>
          <p className="text-sm text-red-600 mt-1">{error}</p>
          {error.includes('ANTHROPIC_API_KEY') && (
            <p className="text-xs text-red-500 mt-2">
              Add your Anthropic API key as the <code className="bg-red-100 px-1 rounded">ANTHROPIC_API_KEY</code>{' '}
              environment variable in Vercel project settings.
            </p>
          )}
        </div>
      )}

      {/* Results */}
      {result && (
        <div className="space-y-5">
          {/* Commentary */}
          <div className="bg-white rounded-xl border border-danone-blue/30 shadow-sm overflow-hidden">
            <div className="bg-danone-dark px-5 py-3 flex items-center gap-2">
              <svg className="w-4 h-4 text-danone-blue" viewBox="0 0 24 24" fill="currentColor">
                <path d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
              </svg>
              <span className="text-white font-semibold text-sm">Scientific Commentary</span>
            </div>
            <div className="px-5 py-4">
              <p className="text-gray-700 text-sm leading-relaxed">{result.commentary}</p>
            </div>
          </div>

          {/* Recommendations */}
          {result.recommendations.length > 0 && (
            <div className="bg-white rounded-xl border border-danone-green/30 shadow-sm overflow-hidden">
              <div className="bg-danone-green px-5 py-3 flex items-center gap-2">
                <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
                <span className="text-white font-semibold text-sm">Strategic Recommendations</span>
              </div>
              <div className="divide-y divide-gray-100">
                {result.recommendations.map((rec, i) => (
                  <div key={i} className="px-5 py-4 flex gap-4">
                    <span className="shrink-0 w-7 h-7 rounded-full bg-danone-light text-danone-dark text-xs font-bold flex items-center justify-center">
                      {i + 1}
                    </span>
                    <div>
                      <p className="font-semibold text-danone-dark text-sm">{rec.title}</p>
                      <p className="text-gray-600 text-sm mt-0.5">{rec.body}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <p className="text-xs text-gray-400 text-center">
            AI insights are generated from aggregated, anonymized study metrics only. Powered by Claude (Anthropic).
            For internal research use. Results may vary between generations.
          </p>
        </div>
      )}

      {/* Placeholder before generation */}
      {!result && !loading && !error && (
        <div className="bg-white rounded-xl border border-dashed border-gray-300 p-10 text-center">
          <div className="text-4xl mb-3">🧠</div>
          <p className="text-gray-500 text-sm">
            Click <strong>Generate AI Insights</strong> to receive strategic commentary and
            business recommendations powered by Claude.
          </p>
          <p className="text-gray-400 text-xs mt-2">
            Analysis covers: {data.pooled.n_studies} studies · {data.pooled.n_subjects_total} subjects · {data.label}
          </p>
        </div>
      )}
    </div>
  )
}
