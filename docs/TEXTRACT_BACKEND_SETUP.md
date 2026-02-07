# Textract via backend (for distributed apps)

For an app you distribute (e.g. App Store), **do not put AWS keys in the app**. Use a small backend that holds the keys and calls Textract; the app sends the image to your backend and gets back text blocks.

---

## What to do (overview)

1. **Create an IAM access key for the backend** (not for the app).  
   When AWS asks “Use case”, choose **“Application running on an AWS compute service”** (e.g. Lambda). Save the Access Key ID and Secret Access Key; you’ll put them only in the backend environment (e.g. Lambda env vars), never in the iOS app.

2. **Create a backend** that:
   - Exposes an HTTP endpoint (e.g. `POST /ocr`).
   - Accepts the pool-sheet image (e.g. multipart or base64).
   - Calls Textract `DetectDocumentText` using the IAM key above.
   - Returns the text blocks in the [API contract](#api-contract) below.

3. **Configure the app** with only your backend URL (e.g. in `Secrets.plist` as `TextractBackendURL`). No AWS keys in the app.

4. **Build and run.** The app sends the image to your backend and uses the returned blocks for grid/name parsing.

---

## 1. IAM key for the backend

- IAM → Users → your user (e.g. `superbowlbox-textract`) → **Create access key**.
- **Use case**: **“Application running on an AWS compute service”** (Lambda, ECS, etc.).
- Complete the flow and save **Access Key ID** and **Secret Access Key**.
- These will be set only in your backend (e.g. Lambda environment variables), not in the app.

---

## 2. Step-by-step: Lambda + API Gateway (recommended)

Follow these steps in order. You need an AWS account and the IAM access key you created for the backend (or you’ll give the Lambda an IAM role instead).

### 2.1 Create the Lambda function

1. In the **AWS Console**, open **Lambda** → **Functions** → **Create function**.
2. **Function name**: e.g. `superbowlbox-ocr`.
3. **Runtime**: **Node.js 22.x** (Node 20.x is EOL in Lambda April 2026).
4. **Architecture**: x86_64 (default).
5. **Execution role**: Choose **Create a new role with basic Lambda permissions** (we’ll add Textract next).
6. Click **Create function**.

### 2.2 Give the Lambda permission to call Textract

1. On the function page, open the **Configuration** tab → **Permissions** → click the **Role name** (opens IAM).
2. In IAM, click **Add permissions** → **Attach policies**.
3. Search for **AmazonTextractFullAccess**, select it, **Add permissions**.
   - (Optional) For production, create a custom policy that allows only `textract:DetectDocumentText` on `*`.
4. Close the IAM tab and return to the Lambda function.

### 2.3 Add the Lambda code

Use this **Node.js** handler so you don’t need to add any packages (Lambda includes the AWS SDK v2 by default).

1. In Lambda, **Code** tab → **Code source**.
2. Ensure the handler file is **`index.js`** (rename if it’s `index.mjs`).
3. Replace the file contents with this code. It reads the image from the request body, calls Textract, and returns blocks in the format the app expects:

```javascript
const AWS = require('aws-sdk');
const textract = new AWS.Textract();

function textractBoxToApp(box) {
  // Textract: Left, Top, Width, Height (0-1, top-left origin).
  // App: x, y, width, height (0-1, bottom-left origin).
  return {
    x: box.Left,
    y: 1 - (box.Top + box.Height),
    width: box.Width,
    height: box.Height,
  };
}

exports.handler = async (event) => {
  const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' };
  try {
    let body = event.body;
    if (event.isBase64Encoded) body = Buffer.from(body, 'base64');
    else if (typeof body === 'string') body = Buffer.from(body, 'utf8');
    if (!body || body.length === 0) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'No image body' }) };
    }
    const result = await textract.detectDocumentText({ Document: { Bytes: body } }).promise();
    const blocks = (result.Blocks || [])
      .filter((b) => b.BlockType === 'LINE' || b.BlockType === 'WORD')
      .map((b) => {
        const geom = b.Geometry?.BoundingBox || {};
        const { x, y, width, height } = textractBoxToApp({
          Left: geom.Left ?? 0,
          Top: geom.Top ?? 0,
          Width: geom.Width ?? 0,
          Height: geom.Height ?? 0,
        });
        return {
          text: (b.Text || '').trim(),
          x, y, width, height,
          confidence: b.Confidence != null ? b.Confidence / 100 : 1,
        };
      })
      .filter((b) => b.text.length > 0);
    return { statusCode: 200, headers, body: JSON.stringify({ blocks }) };
  } catch (err) {
    console.error(err);
    return { statusCode: 500, headers, body: JSON.stringify({ error: err.message || 'Textract failed' }) };
  }
};
```

4. Set the **Handler** to `index.handler` (Lambda → **Configuration** → **General configuration** → **Edit** → Handler).
5. **Save** (Ctrl+S / Cmd+S).

### 2.4 Configure the function for binary body

API Gateway may send the raw image as base64. The code above handles `event.isBase64Encoded` and `event.body`. Ensure the integration passes the body through:

1. **Configuration** → **General configuration** → **Edit** → set **Timeout** to **30** seconds (images can take a few seconds).
2. **Configuration** → **Environment variables**: optional. If you use an IAM role for the Lambda (recommended), you don’t need `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`. Set **AWS_REGION** (e.g. `us-east-1`) if the default isn’t your region.
3. Save.

### 2.5 Create the API Gateway HTTP API

1. Open **API Gateway** in the AWS Console → **Create API**.
2. Choose **HTTP API** → **Build**.
3. **Integrations**: **Add integration** → **Lambda** → select your region and the function you created (e.g. `superbowlbox-ocr`) → **Next**.
4. **API name**: e.g. `superbowlbox-ocr-api` → **Next**.
5. **Configure routes**: **Add route**:
   - **Method**: `POST`
   - **Resource path**: `/ocr`
   - **Integration target**: the Lambda you selected.
   Click **Next** → **Create**.
6. **Stages**: After creation, you’ll see a **Default** stage. Note the **Invoke URL** (e.g. `https://abc123xyz.execute-api.us-east-1.amazonaws.com`).
7. Your full OCR URL is: **Invoke URL** + **path** = `https://abc123xyz.execute-api.us-east-1.amazonaws.com/ocr`.

### 2.6 Allow API Gateway to pass the image body to Lambda

1. In **API Gateway** → your API → **Integrations** → click the **POST /ocr** integration.
2. Ensure **Payload format version** is **2.0** (or 1.0; the Lambda code handles both). For **2.0**, the request body is in `event.body` and may be base64 when the client sends binary.
3. If the client sends `Content-Type: image/jpeg`, API Gateway may mark the body as base64. The sample Lambda code decodes it. No extra mapping is required for a simple proxy.
4. **Deploy**: **Stages** → **Default** → **Deploy** (or deploy from **Stages** if you made changes). The **Invoke URL** is what you use in the app.

### 2.7 (Optional) Use your IAM access keys in Lambda

If you prefer not to use a role and want to use your access key instead:

1. **Lambda** → **Configuration** → **Environment variables** → **Edit** → **Add**:
   - `AWS_REGION` = `us-east-1` (or your region)
   - `AWS_ACCESS_KEY_ID` = your access key ID
   - `AWS_SECRET_ACCESS_KEY` = your secret access key
2. **Save**. Then ensure the Lambda execution role still has basic Lambda execution permissions. Prefer using the **role** (2.2) and leave these blank for better security.

### 2.8 Put the URL in the app

1. Copy your full OCR URL: **API Gateway Invoke URL** + `/ocr` (e.g. `https://abc123xyz.execute-api.us-east-1.amazonaws.com/ocr`).
2. In the SuperBowlBox project, open **SuperBowlBox/Resources/Secrets.plist** (create from `Secrets.example.plist` if needed).
3. Set **TextractBackendURL** to that URL (no trailing slash). Leave **AWSAccessKeyId** and **AWSSecretAccessKey** empty.
4. Build and run the app. When you scan a pool sheet, the app will POST the image to your Lambda and use the returned text blocks.

---

## 3. API contract

The app will `POST` the image and expect this response.

**Request (what the app sends)**

- **Method**: `POST`
- **URL**: Your backend base URL including path (e.g. `https://abc123.execute-api.us-east-1.amazonaws.com/ocr`). Set in the app as `TextractBackendURL`.
- **Headers**: `Content-Type: image/jpeg`
- **Body**: Raw image bytes (JPEG, typically compression quality 0.85). No multipart; the entire body is the image.

**Response (JSON)**

- **200 OK**  
  - Body: `{ "blocks": [ { "text": string, "x": number, "y": number, "width": number, "height": number, "confidence": number }, ... ] }`
  - **Bounding box**: Normalized coordinates in `[0, 1]`, **origin bottom-left** (same as Vision):  
    - `x`, `y` = bottom-left corner  
    - `width`, `height` = size  
    So `y = 0` is bottom of image, `y = 1` is top.

- **4xx/5xx**  
  - The app will treat as OCR failure and can fall back to Vision or show an error.

**Textract → contract mapping**

- Textract returns `Block.Geometry.BoundingBox` with `Left`, `Top`, `Width`, `Height` (normalized 0–1, **top-left** origin).
- Convert to bottom-left for the API:  
  - `x = Left`  
  - `y = 1 - (Top + Height)`  
  - `width = Width`, `height = Height`

---

## 4. Configure the app

1. In `Secrets.plist` (or env), set **only**:
   - `TextractBackendURL` = full URL to your OCR endpoint (e.g. `https://your-api.execute-api.us-east-1.amazonaws.com/ocr`).
2. Do **not** set `AWSAccessKeyId` or `AWSSecretAccessKey` in the app for production. Leave them empty or omit them.
3. When `TextractBackendURL` is set, the app will use the backend for OCR (no AWS SDK or keys in the app).

---

## 5. Summary

| Step | Action |
|------|--------|
| 1 | Create IAM access key with use case **“Application running on an AWS compute service”**. |
| 2 | Create Lambda (or your server) that calls Textract and returns blocks in the API contract. |
| 3 | Expose an HTTPS endpoint (e.g. API Gateway + Lambda). |
| 4 | Set `TextractBackendURL` in the app (Secrets.plist or env). No AWS keys in the app. |

This keeps credentials only on the backend and is the right approach for a distributed app.
