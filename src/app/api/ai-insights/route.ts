import Anthropic from '@anthropic-ai/sdk'
import { NextRequest, NextResponse } from 'next/server'
import { TherapeuticAreaData } from '@/lib/types'

export async function POST(req: NextRequest) {
  if (!process.env.ANTHROPIC_API_KEY) {
    return NextResponse.json(
      { error: 'ANTHROPIC_API_KEY is not configured. Add it in Vercel project settings.' },
      { status: 500 }
    )
  }

  let data: TherapeuticAreaData
  try {
    const body = await req.json()
    data = body.data
    if (!data?.label || !data?.pooled) throw new Error('Invalid payload')
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 })
  }

  const { label, pooled, studies, higher_is_better } = data

  const studyLines = studies
    .map(
      s =>
        `  - ${s.product} (${s.population}, n=${s.n_subjects}, Phase ${s.phase}): ` +
        `d=${s.cohens_d >= 0 ? '+' : ''}${s.cohens_d.toFixed(2)}, ` +
        `p=${s.p_value < 0.001 ? '<0.001' : s.p_value.toFixed(3)}, ` +
        (s.significant ? 'SIGNIFICANT' : 'not significant')
    )
    .join('\n')

  const prompt = `You are a senior scientific strategist at Danone, reviewing real-world evidence from clinical nutrition studies.

Therapeutic Area: ${label}
Total studies: ${pooled.n_studies} RCTs | Total subjects: ${pooled.n_subjects_total}
Significant: ${pooled.n_significant}/${pooled.n_studies} studies
Pooled effect size: Cohen's d = ${pooled.cohens_d >= 0 ? '+' : ''}${pooled.cohens_d.toFixed(2)} (95% CI: ${pooled.ci_lower.toFixed(2)} to ${pooled.ci_upper.toFixed(2)})
Direction: ${higher_is_better ? 'higher values are better (positive d = benefit)' : 'lower values are better (negative d = benefit)'}

Individual study results:
${studyLines}

These are aggregated, anonymized metrics only — no patient-level data.
Provide a concise scientific and strategic response in exactly this format:

##COMMENTARY##
[2–3 sentences: interpret the body of evidence scientifically — effect consistency, magnitude, any notable outliers]

##RECOMMENDATIONS##
REC: [Short title] | [1–2 sentence actionable recommendation for Danone business or research strategy]
REC: [Short title] | [1–2 sentence actionable recommendation]
REC: [Short title] | [1–2 sentence actionable recommendation]
REC: [Short title] | [1–2 sentence actionable recommendation]
REC: [Short title] | [1–2 sentence actionable recommendation]`

  const client = new Anthropic()

  const message = await client.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 900,
    messages: [{ role: 'user', content: prompt }],
  })

  const text = message.content[0].type === 'text' ? message.content[0].text : ''

  const commentaryMatch = text.match(/##COMMENTARY##\s*([\s\S]*?)(?=##RECOMMENDATIONS##|$)/)
  const recsMatch = text.match(/##RECOMMENDATIONS##\s*([\s\S]*)$/)

  const commentary = commentaryMatch?.[1]?.trim() ?? ''
  const recommendations = (recsMatch?.[1] ?? '')
    .split('\n')
    .filter(l => l.trimStart().startsWith('REC:'))
    .map(l => {
      const withoutPrefix = l.replace(/^\s*REC:\s*/, '')
      const pipeIdx = withoutPrefix.indexOf(' | ')
      if (pipeIdx === -1) return { title: withoutPrefix.trim(), body: '' }
      return {
        title: withoutPrefix.slice(0, pipeIdx).trim(),
        body: withoutPrefix.slice(pipeIdx + 3).trim(),
      }
    })

  return NextResponse.json({ commentary, recommendations })
}
