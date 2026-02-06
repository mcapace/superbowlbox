# AI Grid Backend (Claude) Setup

The app can use an **AI backend** instead of OCR (Textract/Vision) to read pool sheet images. When you set `AIGridBackendURL` in Secrets, the scanner sends the image to your backend; the backend calls Claude (or a similar vision model) and returns structured pool data. This often works better for handwritten or messy grids.

---

## How to set this up (overview)

1. **Get an Anthropic API key** at [console.anthropic.com](https://console.anthropic.com) (API Keys). You’ll use it only on the backend, never in the app.

2. **Run or deploy a small backend** that accepts the image, calls Claude with the prompt below, and returns the [JSON response](#backend-api-contract) the app expects. Options:
   - **Option A:** Lambda + API Gateway (good for production; same pattern as Textract).
   - **Option B:** A simple Node or Python server on your machine or any host (good for testing).

3. **In the app:** add `AIGridBackendURL` to **Secrets.plist** with your backend URL (e.g. `https://your-api-id.execute-api.us-east-1.amazonaws.com/ai-grid` or `http://your-machine:3000/ai-grid` for local testing).

4. **Build and run.** When you scan a pool sheet, the app will POST the image to that URL and use the returned grid.

**Quick choice:** Use **Option A** (Lambda + API Gateway) if you want a permanent HTTPS URL. Use **Option B** (Node server) to try it on your Mac with the simulator or a device on the same Wi‑Fi.

---

## Option A: Lambda + API Gateway (recommended for production)

### 1. Create the Lambda

1. **AWS Console** → **Lambda** → **Create function**.
2. **Name:** e.g. `superbowlbox-ai-grid`. **Runtime:** Node.js 20.x. **Create function**.

### 2. Add environment variable

- **Configuration** → **Environment variables** → **Edit** → **Add**:
  - Key: `ANTHROPIC_API_KEY`
  - Value: your Anthropic API key (from [console.anthropic.com](https://console.anthropic.com)).

### 3. Lambda code

In **Code** → **Code source**, use **index.mjs** (or **index.js**). Install the Anthropic package: in **Code** → **Configuration** → **General** you can add a layer, or use Lambda’s “Add layer” / “Build with dependencies”. Easiest is to **deploy a zip** that includes `node_modules` (see below) or use the inline approach with `fetch` to call Anthropic’s HTTP API so you don’t need a layer.

**Minimal handler using `fetch`** (no extra packages; Node 18+ has native fetch):

Replace the default handler with this (in **index.mjs**):

```javascript
export const handler = async (event) => {
  const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' };
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
      return { statusCode: res.status, headers, body: JSON.stringify({ error: 'Claude API error', detail: err }) };
    }
    const data = await res.json();
    let text = data.content?.[0]?.text ?? '';
    text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
    const json = JSON.parse(text);
    // Ensure 10x10 names
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
    return { statusCode: 200, headers, body: JSON.stringify(out) };
  } catch (e) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: String(e.message) }) };
  }
};
```

(If your Lambda uses **index.js** with CommonJS, use `exports.handler = async (event) => { ... };` and remove the `export`.)

**Debugging:** If the app says "data could not be read because it is missing", add logging so CloudWatch shows what the Lambda returns. After `const headers = ...` add: `console.log('Image size:', event.body?.length ?? 0, 'base64:', event.isBase64Encoded);` and right before `return { statusCode: 200, ... }` add: `console.log('Out keys:', Object.keys(out), 'body length:', JSON.stringify(out).length);`. On error in the `catch` block add: `console.error('Lambda error:', e.message, e.stack);`. Then run a scan and check the same log stream in CloudWatch for those lines.

### 4. API Gateway

1. **API Gateway** → **Create API** → **HTTP API** → **Build**.
2. **Integrations** → **Add integration** → **Lambda** → select your function. **API name:** e.g. `superbowlbox-ai`.
3. **Routes** → **Add route**: Method **POST**, path `/ai-grid`, integration = your Lambda.
4. **Stages** → **$default** (or create a stage) → copy the **Invoke URL** (e.g. `https://abc123.execute-api.us-east-1.amazonaws.com`).
5. Your app’s **AIGridBackendURL** = Invoke URL + `/ai-grid` (e.g. `https://abc123.execute-api.us-east-1.amazonaws.com/ai-grid`).

### 5. CORS (if you need it from a web client)

In API Gateway, **CORS** for your API: add `Access-Control-Allow-Origin: *` (or your domain). The Lambda response above already includes that header.

---

## Option B: Local or hosted Node server (for testing)

1. Create a folder and `package.json`:

```bash
mkdir ai-grid-server && cd ai-grid-server
npm init -y
npm install @anthropic-ai/sdk
```

2. Save this as **server.mjs** (replace `YOUR_ANTHROPIC_API_KEY` or use env `ANTHROPIC_API_KEY`):

```javascript
import http from 'http';
import { Anthropic } from '@anthropic-ai/sdk';

const PORT = 3000;
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY || 'YOUR_ANTHROPIC_API_KEY' });

const PROMPT = `You are reading a football (NFL) pool sheet image. It has:
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
    ... 10 rows total
  ]
}
Use standard NFL abbreviations: KC, SF, PHI, BAL, BUF, DET, DAL, GB, NE, SEA, etc. If you cannot read a team, use "UNK". Empty cells must be "".
`;

const server = http.createServer(async (req, res) => {
  if (req.method !== 'POST' || req.url !== '/ai-grid') {
    res.writeHead(404); res.end(); return;
  }
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const body = Buffer.concat(chunks);
  if (body.length === 0) {
    res.writeHead(400, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: 'No image' })); return;
  }
  try {
    const msg = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 4096,
      messages: [{
        role: 'user',
        content: [
          { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: body.toString('base64') } },
          { type: 'text', text: PROMPT },
        ],
      }],
    });
    let text = msg.content[0]?.text ?? '';
    text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
    const json = JSON.parse(text);
    const names = Array.from({ length: 10 }, (_, r) =>
      Array.from({ length: 10 }, (_, c) => (json.names?.[r]?.[c] ?? '') || '');
    const out = {
      homeTeamAbbreviation: String(json.homeTeamAbbreviation ?? 'UNK').trim(),
      awayTeamAbbreviation: String(json.awayTeamAbbreviation ?? 'UNK').trim(),
      homeNumbers: Array.isArray(json.homeNumbers) && json.homeNumbers.length === 10 ? json.homeNumbers : Array.from({ length: 10 }, (_, i) => i),
      awayNumbers: Array.isArray(json.awayNumbers) && json.awayNumbers.length === 10 ? json.awayNumbers : Array.from({ length: 10 }, (_, i) => i),
      names,
    };
    res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(out));
  } catch (e) {
    res.writeHead(500, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: String(e.message) }));
  }
});

server.listen(PORT, '0.0.0.0', () => console.log(`AI grid server http://0.0.0.0:${PORT}/ai-grid`));
```

3. Run:

```bash
export ANTHROPIC_API_KEY=your_key_here
node server.mjs
```

4. **From the app:** use your machine’s IP and port. In **Secrets.plist** set **AIGridBackendURL** to `http://YOUR_IP:3000/ai-grid`. (Simulator can use `http://localhost:3000/ai-grid` if the server runs on the same Mac; device needs the Mac’s LAN IP.)

---

## App configuration

1. **Secrets.plist** (not in git): add a key  
   `AIGridBackendURL`  
   with value = your backend URL (e.g. `https://your-api-id.execute-api.us-east-1.amazonaws.com/ai-grid` or `http://YOUR_IP:3000/ai-grid`).

2. When `AIGridBackendURL` is set, the app **uses only the AI path** for scanning (no OCR). If the key is missing or empty, the app uses the existing OCR path (Textract backend or Vision).

## Backend API contract

- **Method:** POST  
- **Content-Type:** `image/jpeg`  
- **Body:** Raw JPEG bytes of the pool sheet image (upright orientation).

**Response:** JSON object with this shape (UTF-8):

```json
{
  "homeTeamAbbreviation": "KC",
  "awayTeamAbbreviation": "SF",
  "homeNumbers": [3, 7, 1, 9, 0, 5, 2, 8, 4, 6],
  "awayNumbers": [1, 4, 0, 7, 3, 9, 2, 5, 8, 6],
  "names": [
    ["Alice", "Bob", "", "Carol", ...],
    ...
  ]
}
```

- **homeTeamAbbreviation** – Team for the **columns** (header row of digits). Use NFL abbreviation: KC, SF, PHI, BAL, BUF, DET, DAL, GB, NE, SEA, etc.
- **awayTeamAbbreviation** – Team for the **rows** (left column of digits).
- **homeNumbers** – Exactly 10 integers 0–9 (order left-to-right for columns).
- **awayNumbers** – Exactly 10 integers 0–9 (order top-to-bottom for rows).
- **names** – 10×10 grid, **row-major**: `names[row][column]`. Row 0 = top row of the grid, column 0 = leftmost. Use `""` for empty cells. Each cell is the player name as written on the sheet.

Return **200** with this JSON. On error, return 4xx/5xx; the app will show an error and the user can retry or use manual entry.

## Example: Claude with image

Your backend can call the Anthropic API with the image and a system/user prompt, then parse Claude’s reply into the JSON above.

1. **Encode the image** (e.g. base64) and send it in a message with `image_url` (Anthropic format) or your provider’s image input.
2. **Prompt** – ask the model to output **only** valid JSON in the exact shape above. Example prompt:

```
You are reading a football (NFL) pool sheet image. It has:
- A 10×10 grid of squares.
- One team’s name/abbreviation for the COLUMNS (usually a header row with digits 0–9).
- Another team’s name/abbreviation for the ROWS (usually a column with digits 0–9).
- In each cell, either a player’s name or empty.

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

Use standard NFL abbreviations: KC, SF, PHI, BAL, BUF, DET, DAL, GB, NE, SEA, etc. If you cannot read a team, use "UNK". For names, use the exact text as written (handwriting or print). Empty cells must be "".
```

3. **Parse** Claude’s response (strip markdown if present), validate arrays length and digits, then return the JSON to the app.

## Security

- Keep your **Anthropic API key** (or other provider key) only on the backend. Do not put it in the app or in git.
- Use HTTPS for `AIGridBackendURL`.
- Optionally add auth (e.g. API key header) and validate it on the backend; the app does not send auth by default, so add it in the app if you need it.

## Optional: env override

For local/testing you can set `AI_GRID_BACKEND_URL` in the run environment; it overrides Secrets if present.
