/**
 * Lambda: parse payout rules with Anthropic (same pattern as grid-analyze).
 * App sends: POST { "payoutDescription": "e.g. $25 per quarter, halftime pays double" }
 * Returns: JSON matching PayoutParseService.Response for leader/earnings logic.
 */

const PROMPT = `You parse football/sports pool payout rules into structured JSON. The app uses this to show who's winning and what each period pays — so the structure must match how the pool actually pays.

CRITICAL: If the user mentions specific dollar amounts (e.g. "$25 per quarter", "halftime pays double", "$50 final"), you MUST set:
  "payoutStyle": "fixedAmount"
  "amountsPerPeriod": [array of dollar amounts in period order]
Do NOT use "equalSplit" or leave amountsPerPeriod null when the user describes dollar amounts per period.

Output ONLY a single valid JSON object, no markdown or explanation:
{
  "poolType": "byQuarter",
  "quarterNumbers": [1, 2, 3, 4],
  "customPeriodLabels": null,
  "payoutStyle": "fixedAmount",
  "amountsPerPeriod": [25, 25, 50, 25],
  "percentagesPerPeriod": null,
  "totalPoolAmount": 125,
  "currencyCode": "USD"
}

Rules:
- poolType: byQuarter | halftimeOnly | finalOnly | halftimeAndFinal | firstScoreChange | custom
  - byQuarter = pay at end of Q1,Q2,Q3,Q4 → quarterNumbers [1,2,3,4]
  - halftimeOnly = one payout at halftime. finalOnly = one at game end. halftimeAndFinal = two. firstScoreChange = first score wins.
  - custom = use customPeriodLabels e.g. ["Q1","Q2","Halftime","Final"]
- payoutStyle: equalSplit | fixedAmount | percentage
  - When user says "$X per quarter" or "Q1 $25, Q2 $25, halftime $50" etc. → use fixedAmount and set amountsPerPeriod to the dollar amounts in period order.
  - "halftime pays double" with $25/quarter → e.g. [25, 25, 50, 25] (Q1,Q2,halftime,Q3,Q4 or match the periods they describe).
  - percentage = only when they say "equal split" or "25% each" etc. → use percentagesPerPeriod.
  - equalSplit = only when no specific amounts are given.
- amountsPerPeriod must be an array of numbers (dollars), one per period, in order. Never null when user specifies dollar amounts.
- Infer totalPoolAmount when implied (e.g. 4x$25 = 100). currencyCode "USD" if not stated.`;

exports.handler = async (event) => {
  const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' };
  try {
    let body = event.body;
    if (event.isBase64Encoded && body) body = Buffer.from(body, 'base64').toString('utf8');
    if (typeof body === 'string') body = JSON.parse(body);
    if (!body || typeof body.payoutDescription !== 'string') {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'Missing payoutDescription' }) };
    }

    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return { statusCode: 500, headers, body: JSON.stringify({ error: 'ANTHROPIC_API_KEY not set' }) };
    }

    const userMessage = `Parse these pool payout rules into the JSON format:\n\n"${body.payoutDescription}"`;

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 2048,
        messages: [{ role: 'user', content: userMessage }],
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error('Claude API error:', res.status, err);
      return { statusCode: res.status, headers, body: JSON.stringify({ error: 'Claude API error', detail: err }) };
    }

    const data = await res.json();
    let text = data.content?.[0]?.text ?? '';
    text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
    const json = JSON.parse(text);
    const inputText = (body.payoutDescription || '').toLowerCase();

    // If user text mentions dollars but Claude returned equalSplit / no amounts, infer fixedAmount
    const hasDollars = /\$|dollar|dollars/.test(inputText);
    let payoutStyle = json.payoutStyle ?? 'equalSplit';
    let amountsPerPeriod = Array.isArray(json.amountsPerPeriod) && json.amountsPerPeriod.length > 0
      ? json.amountsPerPeriod
      : null;

    if (hasDollars && (!amountsPerPeriod || payoutStyle === 'equalSplit')) {
      // Extract numbers that look like dollar amounts (after $ or "X dollars")
      const numbers = (body.payoutDescription || '').match(/\$?\s*(\d+(?:\.\d+)?)\s*(?:dollars?)?/gi);
      if (numbers && numbers.length >= 1) {
        const amounts = numbers.slice(0, 8).map((s) => {
          const n = parseFloat(String(s).replace(/[^\d.]/g, ''));
          return isNaN(n) ? 0 : n;
        }).filter((n) => n > 0);
        if (amounts.length >= 1) {
          // If we got one number and it's "per quarter" style, repeat for 4 quarters (or 2 for halftime+final)
          const byQuarter = /quarter|q1|q2|q3|q4|per (?:period|box)/i.test(body.payoutDescription || '');
          const halftimeDouble = /halftime.*double|double.*halftime/i.test(body.payoutDescription || '');
          if (byQuarter && amounts.length === 1 && amounts[0] > 0) {
            const base = amounts[0];
            amountsPerPeriod = halftimeDouble ? [base, base, base * 2, base] : [base, base, base, base];
          } else if (amounts.length >= 2) {
            amountsPerPeriod = amounts;
          }
          if (amountsPerPeriod) payoutStyle = 'fixedAmount';
        }
      }
    }

    const out = {
      poolType: json.poolType ?? 'byQuarter',
      quarterNumbers: json.quarterNumbers ?? [1, 2, 3, 4],
      customPeriodLabels: json.customPeriodLabels ?? null,
      payoutStyle,
      amountsPerPeriod,
      percentagesPerPeriod: json.percentagesPerPeriod ?? null,
      totalPoolAmount: json.totalPoolAmount ?? null,
      currencyCode: json.currencyCode ?? 'USD',
    };

    return { statusCode: 200, headers, body: JSON.stringify(out) };
  } catch (e) {
    console.error('Lambda error:', e.message, e.stack);
    return { statusCode: 500, headers, body: JSON.stringify({ error: String(e.message) }) };
  }
};
