/**
 * Runtime: Node.js 22.x recommended (Node 20.x EOL in Lambda April 2026).
 * Lambda: parse payout rules with Anthropic (same pattern as ai-grid).
 * Contract:
 *   App sends: POST application/json { "payoutDescription": "<user's free text>" }
 *   Returns: 200 + JSON matching PayoutParseService.Response
 * Env: ANTHROPIC_API_KEY (required). Optional: MODEL (default claude-sonnet-4-20250514).
 * Route: e.g. POST /parse-payout on your API Gateway.
 */

const SYSTEM_PROMPT = `You are a sports pool payout rules parser. Convert the user's free-text rules into structured JSON.

CRITICAL RULES:
1. Extract the EXACT dollar amounts the user specifies. NEVER use default values like $400 or 25 if the user gave different numbers.
2. Parse comma-formatted numbers correctly: "$1,750" = 1750, "$10,000" = 10000.
3. Distinguish between "per box/square" (investment) and "total pot/pool" (total amount).
4. If the user specifies how 0-0 is handled, include it in readableRules.
5. Only include a maxScoreChanges cap if the user explicitly mentions one (e.g., "stop at 25").
6. If the rules are unclear or missing critical info (like payout amounts), set "needsClarification": true and include a "clarificationQuestion" asking what you need to know.

POOL TYPES (use "custom" if none fit):
- "perScoreChange": Pays on every score change. Use amountPerChange, maxScoreChanges (only if specified), totalPoolAmount.
- "byQuarter": Pays at end of Q1, Q2, Q3, Q4 (or Final). Use quarterNumbers and amountsPerPeriod.
- "halftimeAndFinal": Two payouts only.
- "halftimeOnly": Single halftime payout.
- "finalOnly": Single final payout.
- "firstScoreChange": One payout when score first changes from 0-0.
- "custom": Any non-standard rules. Use customPeriodLabels for period names.

OUTPUT: Return ONLY valid JSON. Fields:
- poolType (required)
- needsClarification (boolean - true if rules are unclear, missing amounts, or ambiguous)
- clarificationQuestion (string - question to ask user if needsClarification is true)
- amountPerChange (for perScoreChange - the EXACT amount user specified, or null if not given)
- maxScoreChanges (for perScoreChange - ONLY if user specifies a cap, otherwise null)
- quarterNumbers (for byQuarter, e.g. [1,2,3,4])
- customPeriodLabels (for custom, e.g. ["1st Half", "2nd Half", "OT"])
- amountsPerPeriod (array of dollar amounts in order, or null if not specified)
- payoutStyle ("fixedAmount" if amounts given, "equalSplit" if equal %, "percentage" if % given)
- totalPoolAmount (total pot, NOT per-box amount)
- zeroZeroCounts (boolean - true if 0-0 counts as first payout)
- currencyCode ("USD" default)
- readableRules (1-3 sentences summarizing the rules - REQUIRED even if needsClarification)

EXAMPLES:

Input: "$5 payoff per score change, including starting score of 0-0. Final score winner takes remainder of the pot"
Output: {"poolType":"perScoreChange","amountPerChange":5,"maxScoreChanges":null,"totalPoolAmount":null,"zeroZeroCounts":true,"currencyCode":"USD","readableRules":"$5 per score change. 0-0 counts as the first payout. Final score winner takes any remainder."}

Input: "$125 first quarter, $250 second quarter, $125 third quarter, $500 Final"
Output: {"poolType":"byQuarter","quarterNumbers":[1,2,3,4],"amountsPerPeriod":[125,250,125,500],"totalPoolAmount":1000,"currencyCode":"USD","readableRules":"Quarterly payouts: Q1 $125, Q2 $250, Q3 $125, Final $500. Total $1,000."}

Input: "$500 first quarter, $750 second quarter, $500 third quarter, $1,750 Final"
Output: {"poolType":"byQuarter","quarterNumbers":[1,2,3,4],"amountsPerPeriod":[500,750,500,1750],"totalPoolAmount":3500,"currencyCode":"USD","readableRules":"Quarterly payouts: Q1 $500, Q2 $750, Q3 $500, Final $1,750. Total $3,500."}

Input: "$100 per box, $10,000 total pot. $400 per score change. Stop at 25 scoring changes, remainder to final. 0-0 is not a score change."
Output: {"poolType":"perScoreChange","amountPerChange":400,"maxScoreChanges":25,"totalPoolAmount":10000,"zeroZeroCounts":false,"currencyCode":"USD","readableRules":"$400 per score change. Stops at 25 changes; remainder goes to final score winner. 0-0 does not count. Total pot $10,000."}

Input: "We pay out at halftime and final"
Output: {"poolType":"halftimeAndFinal","needsClarification":true,"clarificationQuestion":"How much does each period pay? (e.g., '$500 halftime, $500 final' or 'split evenly')","payoutStyle":"equalSplit","currencyCode":"USD","readableRules":"Pays at halftime and final. Amounts not specified."}

Input: "Winner of each quarter gets paid, overtime counts as Q5"
Output: {"poolType":"custom","customPeriodLabels":["Q1","Q2","Q3","Q4","OT"],"needsClarification":true,"clarificationQuestion":"What are the payout amounts for each period?","payoutStyle":"equalSplit","currencyCode":"USD","readableRules":"Pays at end of Q1, Q2, Q3, Q4, and OT (as Q5). Amounts not specified."}`;

exports.handler = async (event) => {
  const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' };

  try {
    let body = event.body;
    if (event.isBase64Encoded && body) {
      body = Buffer.from(body, 'base64').toString('utf8');
    }
    if (typeof body === 'string') {
      body = JSON.parse(body);
    }

    if (!body || typeof body.payoutDescription !== 'string' || !body.payoutDescription.trim()) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'Missing payoutDescription' }) };
    }

    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return { statusCode: 500, headers, body: JSON.stringify({ error: 'ANTHROPIC_API_KEY not set' }) };
    }

    const userText = body.payoutDescription.trim();
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
        system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: userText }],
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

    let json;
    try {
      json = JSON.parse(text);
    } catch (e) {
      console.error('JSON parse error:', e.message, 'Raw:', text);
      return { statusCode: 500, headers, body: JSON.stringify({ error: 'Failed to parse AI response', raw: text }) };
    }

    // Post-process and validate
    const result = postProcess(json, userText);

    return { statusCode: 200, headers, body: JSON.stringify(result) };
  } catch (e) {
    console.error('Lambda error:', e.message, e.stack);
    return { statusCode: 500, headers, body: JSON.stringify({ error: String(e.message) }) };
  }
};

/**
 * Post-process Claude's response to ensure correctness.
 * Fixes comma-formatted numbers and validates amounts against user input.
 */
function postProcess(json, userText) {
  const poolType = json.poolType || 'byQuarter';

  // Normalize the result structure
  const result = {
    poolType,
    needsClarification: json.needsClarification || false,
    clarificationQuestion: json.clarificationQuestion || null,
    quarterNumbers: null,
    customPeriodLabels: json.customPeriodLabels || null,
    payoutStyle: null,
    amountsPerPeriod: null,
    amountPerChange: null,
    maxScoreChanges: null,
    percentagesPerPeriod: json.percentagesPerPeriod || null,
    totalPoolAmount: null,
    zeroZeroCounts: json.zeroZeroCounts || null,
    currencyCode: json.currencyCode || 'USD',
    readableRules: json.readableRules || null,
  };

  // Parse totalPoolAmount - look for "total pot/pool" pattern, not "per box"
  if (json.totalPoolAmount != null) {
    result.totalPoolAmount = parseNumber(json.totalPoolAmount);
  } else {
    // Try to extract from user text - look for total pot/pool, not per box
    const totalMatch = userText.match(/\$\s*([\d,]+(?:\.\d+)?)\s*(?:total\s*(?:pot|pool)|pot|pool\s*total)/i);
    if (totalMatch) {
      result.totalPoolAmount = parseNumber(totalMatch[1]);
    }
  }

  // Handle per-score-change pools
  if (poolType === 'perScoreChange') {
    // Extract amount per change from Claude or from user text
    if (json.amountPerChange != null) {
      result.amountPerChange = parseNumber(json.amountPerChange);
    } else {
      // Fallback: extract from user text
      const amtMatch = userText.match(/\$\s*([\d,]+(?:\.\d+)?)\s*(?:dollars?)?\s*(?:per|each)\s*(?:score\s*change|point|payoff)/i)
        || userText.match(/\$\s*([\d,]+(?:\.\d+)?)\s*(?:payoff|payout)\s*per\s*(?:score\s*change|point)/i);
      if (amtMatch) {
        result.amountPerChange = parseNumber(amtMatch[1]);
      }
    }

    // Only set maxScoreChanges if Claude returned it or user explicitly mentioned a cap
    if (json.maxScoreChanges != null) {
      result.maxScoreChanges = json.maxScoreChanges;
    } else {
      // Check if user mentioned a cap
      const capMatch = userText.match(/stop\s*(?:at|after)\s*(\d+)|(\d+)\s*(?:score\s*)?changes?\s*(?:max|cap|limit)/i);
      if (capMatch) {
        result.maxScoreChanges = parseInt(capMatch[1] || capMatch[2], 10);
      }
      // If no cap mentioned, leave as null (not 25 default)
    }

    return result;
  }

  // Handle quarterly pools
  if (poolType === 'byQuarter' || poolType === 'halftimeAndFinal' || poolType === 'halftimeOnly' || poolType === 'finalOnly') {
    result.quarterNumbers = json.quarterNumbers || [1, 2, 3, 4];

    // Parse amountsPerPeriod - handle comma-formatted numbers
    if (Array.isArray(json.amountsPerPeriod) && json.amountsPerPeriod.length > 0) {
      result.amountsPerPeriod = json.amountsPerPeriod.map(parseNumber);
      result.payoutStyle = 'fixedAmount';
    } else {
      // Fallback: try to extract amounts from user text
      const amounts = extractAmountsFromText(userText);
      if (amounts.length > 0) {
        result.amountsPerPeriod = amounts;
        result.payoutStyle = 'fixedAmount';
      } else {
        result.payoutStyle = json.payoutStyle || 'equalSplit';
      }
    }

    // Calculate total if we have amounts but no total
    if (result.amountsPerPeriod && result.totalPoolAmount == null) {
      result.totalPoolAmount = result.amountsPerPeriod.reduce((a, b) => a + b, 0);
    }

    return result;
  }

  // Handle first score change
  if (poolType === 'firstScoreChange') {
    if (Array.isArray(json.amountsPerPeriod) && json.amountsPerPeriod.length > 0) {
      result.amountsPerPeriod = json.amountsPerPeriod.map(parseNumber);
      result.payoutStyle = 'fixedAmount';
    } else {
      result.payoutStyle = 'equalSplit';
    }
    return result;
  }

  // Handle custom pools
  if (poolType === 'custom') {
    result.customPeriodLabels = json.customPeriodLabels || [];
    if (Array.isArray(json.amountsPerPeriod)) {
      result.amountsPerPeriod = json.amountsPerPeriod.map(parseNumber);
      result.payoutStyle = 'fixedAmount';
    } else {
      result.payoutStyle = 'equalSplit';
    }
    return result;
  }

  return result;
}

/**
 * Parse a number that may have commas (e.g., "1,750" -> 1750).
 */
function parseNumber(val) {
  if (typeof val === 'number') return val;
  if (typeof val === 'string') {
    const cleaned = val.replace(/[$,]/g, '').trim();
    const num = parseFloat(cleaned);
    return isNaN(num) ? 0 : num;
  }
  return 0;
}

/**
 * Extract dollar amounts from text, handling comma-formatted numbers.
 * Returns array of numbers in the order they appear.
 */
function extractAmountsFromText(text) {
  const amounts = [];
  // Match $X,XXX or $XXX patterns, including comma-formatted
  const regex = /\$\s*([\d,]+(?:\.\d+)?)/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const num = parseNumber(match[1]);
    if (num > 0) {
      amounts.push(num);
    }
  }
  return amounts;
}
