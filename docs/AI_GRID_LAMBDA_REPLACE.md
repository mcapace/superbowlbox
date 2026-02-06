# AI Grid Lambda: Code and Replace Instructions

Use this to **create a new Lambda** for the AI grid (Claude) and connect it to your **POST /ai-grid** route. Your existing **superbowlbox-ocr** Lambda stays unchanged for Textract.

---

## Step 1: Create the new Lambda

1. In **AWS Console** go to **Lambda** → **Functions** → **Create function**.
2. **Name:** `superbowlbox-ai-grid`
3. **Runtime:** Node.js 20.x
4. **Architecture:** x86_64 (default)
5. **Execution role:** Create a new role with basic Lambda permissions.
6. Click **Create function**.

---

## Step 2: Add the code

1. In the function, open the **Code** tab.
2. Confirm the default file is **index.mjs** or **index.js** (see file name in the left Explorer).
3. **Delete all existing code** in that file.
4. Paste **one** of the two code blocks below.

**If your file is index.mjs** (ESM), use this:

```javascript
export const handler = async (event) => {
  const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' };
  console.log('Request: body length=', event.body?.length ?? 0, 'isBase64=', event.isBase64Encoded);
  try {
    let body = event.body;
    if (event.isBase64Encoded) body = Buffer.from(body, 'base64');
    else if (typeof body === 'string') body = Buffer.from(body, 'utf8');
    if (!body || body.length === 0) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'No image body' }) };
    }
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return { statusCode: 500, headers, body: JSON.stringify({ error: 'ANTHROPIC_API_KEY not set' }) };
    }
    const base64 = body.toString('base64');
    const prompt = `You are reading a football (NFL) pool sheet image. It has:
- A 10×10 grid of squares.
- One team's name/abbreviation for the COLUMNS (usually a header row with digits 0–9).
- Another team's name/abbreviation for the ROWS (usually a column with digits 0–9).
- In each cell, either a player's name or empty.

Extract and return ONLY a single JSON object, no markdown or explanation, with this exact structure:
{
  "homeTeamAbbreviation": "<NFL abbreviation for the COLUMN team, e.g. KC or SF>",
  "awayTeamAbbreviation": "<NFL abbreviation for the ROW team>",
  "homeNumbers": [<10 digits 0-9 in order left to right for the column headers>],
  "awayNumbers": [<10 digits 0-9 in order top to bottom for the row labels>],
  "names": [
    [<10 strings for row 0, left to right; use "" for empty cells>],
    [<row 1>],
    ... 10 rows total
  ]
}

Use standard NFL abbreviations: KC, SF, PHI, BAL, BUF, DET, DAL, GB, NE, SEA, etc. If you cannot read a team, use "UNK". For names, use the exact text as written. Empty cells must be "".
`;

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
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
```

**If your file is index.js** (CommonJS), use this instead (only the first line is different):

```javascript
exports.handler = async (event) => {
  const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' };
  console.log('Request: body length=', event.body?.length ?? 0, 'isBase64=', event.isBase64Encoded);
  try {
    let body = event.body;
    if (event.isBase64Encoded) body = Buffer.from(body, 'base64');
    else if (typeof body === 'string') body = Buffer.from(body, 'utf8');
    if (!body || body.length === 0) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'No image body' }) };
    }
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return { statusCode: 500, headers, body: JSON.stringify({ error: 'ANTHROPIC_API_KEY not set' }) };
    }
    const base64 = body.toString('base64');
    const prompt = `You are reading a football (NFL) pool sheet image. It has:
- A 10×10 grid of squares.
- One team's name/abbreviation for the COLUMNS (usually a header row with digits 0–9).
- Another team's name/abbreviation for the ROWS (usually a column with digits 0–9).
- In each cell, either a player's name or empty.

Extract and return ONLY a single JSON object, no markdown or explanation, with this exact structure:
{
  "homeTeamAbbreviation": "<NFL abbreviation for the COLUMN team, e.g. KC or SF>",
  "awayTeamAbbreviation": "<NFL abbreviation for the ROW team>",
  "homeNumbers": [<10 digits 0-9 in order left to right for the column headers>],
  "awayNumbers": [<10 digits 0-9 in order top to bottom for the row labels>],
  "names": [
    [<10 strings for row 0, left to right; use "" for empty cells>],
    [<row 1>],
    ... 10 rows total
  ]
}

Use standard NFL abbreviations: KC, SF, PHI, BAL, BUF, DET, DAL, GB, NE, SEA, etc. If you cannot read a team, use "UNK". For names, use the exact text as written. Empty cells must be "".
`;

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
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
```

5. Click **Deploy** (orange button).

---

## Step 3: Set the Anthropic API key

1. In the same function, open **Configuration** → **Environment variables** → **Edit**.
2. **Add** → Key: `ANTHROPIC_API_KEY`, Value: your Anthropic API key (from console.anthropic.com).
3. **Save**.

---

## Step 4: Point API Gateway /ai-grid at this Lambda

1. In **AWS Console** go to **API Gateway**.
2. Open the API whose **Invoke URL** is:  
   `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com`
3. In the left menu click **Routes**.
4. Find the route **POST** `/ai-grid`. Click it.
5. In the **Integration** section, click **Edit** (or the integration ID).
6. Under **Integration target**, choose **Lambda function** and select **superbowlbox-ai-grid** (the function you just created). Confirm the region matches.
7. **Save**. If prompted to add permissions so API Gateway can invoke the Lambda, confirm **OK**.

---

## Step 5: Test from the app

1. Build and run the app.
2. Go to **Scan** → pick or skip a game → take or choose a pool sheet image.
3. The app will POST to `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid`; that request will now hit **superbowlbox-ai-grid** and return the grid JSON.

Your **superbowlbox-ocr** Lambda is unchanged and can stay attached to a different route (e.g. `/ocr`) for Textract if you use it elsewhere.
