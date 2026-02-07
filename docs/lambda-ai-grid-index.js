// Accepts: (1) POST application/json with body { "image": "<base64>" } — recommended so API Gateway does not corrupt binary.
//          (2) POST raw image bytes (or base64) with image/jpeg — legacy.
// Requires env: ANTHROPIC_API_KEY. Optional: MODEL (default claude-sonnet-4-20250514).
exports.handler = async (event) => {
  const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' };
  console.log('Request: body length=', event.body?.length ?? 0, 'isBase64=', event.isBase64Encoded);
  try {
    let base64;
    const contentType = (event.headers && (event.headers['Content-Type'] || event.headers['content-type'])) || '';

    if (contentType.includes('application/json')) {
      const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
      base64 = body && body.image;
      if (!base64 || typeof base64 !== 'string') {
        return { statusCode: 400, headers, body: JSON.stringify({ error: 'JSON body must contain "image" (base64 string)' }) };
      }
      base64 = base64.replace(/^data:image\/\w+;base64,/, '').trim();
    } else {
      let body = event.body;
      if (event.isBase64Encoded) body = Buffer.from(body, 'base64');
      else if (typeof body === 'string') body = Buffer.from(body, 'utf8');
      if (!body || body.length === 0) {
        return { statusCode: 400, headers, body: JSON.stringify({ error: 'No image body' }) };
      }
      base64 = body.toString('base64');
    }

    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return { statusCode: 500, headers, body: JSON.stringify({ error: 'ANTHROPIC_API_KEY not set' }) };
    }

    const prompt = `You are reading a football (NFL) pool sheet image. It has:
- A 10x10 grid. COLUMNS (horizontal) have a header row with digits 0-9. ROWS (vertical) have a column with digits 0-9.
- One team is the COLUMN team (header across top). One team is the ROW team (left column).
- Each cell may contain a player name or be empty.

Return ONLY a single JSON object, no markdown, no code fence. Exact structure:
{"homeTeamAbbreviation":"<abbr for COLUMN team>","awayTeamAbbreviation":"<abbr for ROW team>","homeNumbers":[10 digits 0-9 in order left to right],"awayNumbers":[10 digits 0-9 in order top to bottom],"names":[[cell row 0],...[10 rows]]}

Rules:
- homeTeamAbbreviation = the team whose numbers are the COLUMN headers (top row).
- awayTeamAbbreviation = the team whose numbers are the ROW labels (left column).
- names[r][c] = the player name in the cell at row r (0=top), column c (0=left). Use "" for empty cells. Exactly 10 rows, 10 strings per row.
- Use these abbreviations only: KC, SF, PHI, BAL, BUF, DET, DAL, GB, NE, SEA (for Seattle use SEA not SE).`;

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
        max_tokens: 4096,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: base64 } },
              { type: 'text', text: prompt },
            ],
          },
        ],
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
    const names = Array.from({ length: 10 }, (_, r) =>
      Array.from({ length: 10 }, (_, c) => (json.names?.[r]?.[c] ?? '') || '')
    );
    const homeNumbers = Array.isArray(json.homeNumbers) && json.homeNumbers.length === 10 ? json.homeNumbers : Array.from({ length: 10 }, (_, i) => i);
    const awayNumbers = Array.isArray(json.awayNumbers) && json.awayNumbers.length === 10 ? json.awayNumbers : Array.from({ length: 10 }, (_, i) => i);
    const out = {
      homeTeamAbbreviation: String(json.homeTeamAbbreviation ?? 'UNK').trim(),
      awayTeamAbbreviation: String(json.awayTeamAbbreviation ?? 'UNK').trim(),
      homeNumbers,
      awayNumbers,
      names,
    };
    console.log('Success: out keys=', Object.keys(out), 'body length=', JSON.stringify(out).length);
    return { statusCode: 200, headers, body: JSON.stringify(out) };
  } catch (e) {
    console.error('Lambda error:', e.message, e.stack);
    return { statusCode: 500, headers, body: JSON.stringify({ error: String(e.message) }) };
  }
};
