/**
 * Runtime: Node.js 22.x recommended (Node 20.x EOL in Lambda April 2026).
 * Lambda: parse payout rules with Anthropic (same pattern as ai-grid).
 * Contract:
 *   App sends: POST application/json { "payoutDescription": "<user's free text>" }
 *   Returns: 200 + JSON matching PayoutParseService.Response (poolType, amountsPerPeriod, readableRules, etc.)
 * Env: ANTHROPIC_API_KEY (required). Optional: MODEL (default claude-sonnet-4-20250514).
 * Route: e.g. POST /parse-payout on your API Gateway.
 */

const PROMPT = `You parse football/sports pool payout rules into structured JSON. The app uses your response for the grid header, current winner, and payouts — so output the structure that matches THIS user's description only.

Pools vary. Parse exactly what they wrote — do not assume a type. Common cases:
- Standard quarterly: "byQuarter", pay at end of Q1/Q2/Q3/Q4. Often "equal split" (25% each) or "$X per quarter" (fixedAmount, amountsPerPeriod). quarterNumbers [1,2,3,4].
- Halftime / final only: "halftimeOnly", "finalOnly", or "halftimeAndFinal" (two payouts).
- First score: "firstScoreChange" — ONE payout when the score first changes from 0–0. amountsPerPeriod: [single amount] or equalSplit.
- Per score change: "perScoreChange" only when they clearly say pay per score change / per point, stop at N, remainder to final, no payments for end of quarters/halftime. Then output amountPerChange, maxScoreChanges, totalPoolAmount. Omit quarterNumbers, amountsPerPeriod, payoutStyle.
- Custom: "custom" with customPeriodLabels when they name non-standard periods.

Output ONLY a single valid JSON object, no markdown. Include "readableRules" (REQUIRED): 1–3 clear sentences so the user understands how this pool pays.

Examples:
Standard quarterly: { "poolType": "byQuarter", "quarterNumbers": [1,2,3,4], "payoutStyle": "fixedAmount", "amountsPerPeriod": [25,25,50,25], "totalPoolAmount": 125, "currencyCode": "USD", "readableRules": "This pool pays $25 per quarter; halftime pays $50 (double)." }
Equal split: { "poolType": "byQuarter", "quarterNumbers": [1,2,3,4], "payoutStyle": "equalSplit", "totalPoolAmount": 100, "currencyCode": "USD", "readableRules": "Equal split: 25% per quarter. Total pool $100." }
Per score change (only if they describe it): { "poolType": "perScoreChange", "amountPerChange": 400, "maxScoreChanges": 25, "totalPoolAmount": 10000, "currencyCode": "USD", "readableRules": "..." }

Infer totalPoolAmount when implied. Use currencyCode "USD" if not stated.`;

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

    const model = process.env.MODEL || 'claude-sonnet-4-20250514';
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model,
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
    const raw = body.payoutDescription || '';
    const isFirstScorePool = /first\s*score\s*wins|first\s*(td|fg|field\s*goal|team\s*to\s*score)/i.test(raw) && !/per\s*score\s*change|\$\d+\s*per\s*(score\s*change|point)/i.test(raw);
    const isPerScoreChangePool = /\$?\s*\d+\s*(dollars?)?\s*per\s*(score\s*change|point)|per\s*score\s*change|stop\s*at\s*\d+|remainder\s*to\s*final|no\s*payments?\s*for\s*(end\s*of\s*quarters?|halftime|end\s*of\s*game)/i.test(raw);

    let poolType = json.poolType ?? 'byQuarter';
    let payoutStyle = json.payoutStyle ?? 'equalSplit';
    let amountsPerPeriod = Array.isArray(json.amountsPerPeriod) && json.amountsPerPeriod.length > 0 ? json.amountsPerPeriod : null;
    let amountPerChange = typeof json.amountPerChange === 'number' ? json.amountPerChange : null;
    let maxScoreChanges = typeof json.maxScoreChanges === 'number' ? json.maxScoreChanges : (json.maxScoreChanges === null ? null : undefined);
    let totalPoolAmount = json.totalPoolAmount;

    if (isPerScoreChangePool) {
      poolType = 'perScoreChange';
      if (amountPerChange == null) {
        const m = raw.match(/\$?\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:dollars?)?\s*per\s*(?:score\s*change|point)/i) || raw.match(/(\d+)\s*dollars?\s*per\s*(?:score\s*change|point)/i);
        if (m) amountPerChange = parseFloat(String(m[1]).replace(/,/g, ''));
      }
      if (maxScoreChanges === undefined) {
        const m = raw.match(/stop\s*at\s*(\d+)|(\d+)\s*scoring\s*changes?/i);
        if (m) maxScoreChanges = parseInt(m[1] || m[2], 10);
        else maxScoreChanges = 25;
      }
      if (totalPoolAmount == null) {
        const m = raw.match(/\$?\s*(\d+(?:,\d{3})*)\s*(?:total|pot|pool)|(\d+)\s*per\s*box|total\s*pot\s*\$?\s*(\d+)/i);
        if (m) totalPoolAmount = parseFloat(String(m[1] || m[2] || m[3]).replace(/,/g, ''));
      }
    }

    if (isFirstScorePool && poolType !== 'firstScoreChange') {
      poolType = 'firstScoreChange';
      if (!amountsPerPeriod || amountsPerPeriod.length === 0) {
        const match = raw.match(/\$?\s*(\d+(?:\.\d+)?)/);
        if (match) {
          amountsPerPeriod = [parseFloat(match[1])];
          payoutStyle = 'fixedAmount';
        }
      }
    }

    const hasDollars = /\$|dollar|dollars/.test(inputText);
    if (!isPerScoreChangePool && !isFirstScorePool && hasDollars && (!amountsPerPeriod || payoutStyle === 'equalSplit')) {
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
      poolType,
      quarterNumbers: poolType === 'perScoreChange' ? null : (json.quarterNumbers ?? [1, 2, 3, 4]),
      customPeriodLabels: json.customPeriodLabels ?? null,
      payoutStyle: poolType === 'perScoreChange' ? null : payoutStyle,
      amountsPerPeriod: poolType === 'perScoreChange' ? null : amountsPerPeriod,
      amountPerChange: poolType === 'perScoreChange' ? (amountPerChange ?? 400) : null,
      maxScoreChanges: poolType === 'perScoreChange' ? (maxScoreChanges ?? 25) : null,
      percentagesPerPeriod: json.percentagesPerPeriod ?? null,
      totalPoolAmount: totalPoolAmount ?? json.totalPoolAmount ?? null,
      currencyCode: json.currencyCode ?? 'USD',
      readableRules: typeof json.readableRules === 'string' && json.readableRules.trim() ? json.readableRules.trim() : null,
    };

    return { statusCode: 200, headers, body: JSON.stringify(out) };
  } catch (e) {
    console.error('Lambda error:', e.message, e.stack);
    return { statusCode: 500, headers, body: JSON.stringify({ error: String(e.message) }) };
  }
};
