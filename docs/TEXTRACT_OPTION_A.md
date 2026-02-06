# Option A: Lambda + API Gateway (no keys in Lambda)

Use the Lambda **IAM role** to call Textract. Do **not** put any access key or secret in Lambda or in the app.

---

## 1. Create the Lambda function

1. **AWS Console** → **Lambda** → **Functions** → **Create function**.
2. **Function name**: `superbowlbox-ocr` (or any name).
3. **Runtime**: **Node.js 20.x** (or 18.x).
4. **Execution role**: **Create a new role with basic Lambda permissions**.
5. Click **Create function**.

---

## 2. Give the Lambda role permission to call Textract

1. In the Lambda function: **Configuration** tab → **Permissions** → click the **Role name** (opens IAM in a new tab).
2. In IAM: **Add permissions** → **Attach policies**.
3. Search **AmazonTextractFullAccess** → select it → **Add permissions**.
4. Close the IAM tab and return to the Lambda function.

Do **not** add `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` to Lambda environment variables.

---

## 3. Add the Lambda code

Use **Node.js 18.x or 20.x** (the old `aws-sdk` v2 is not available in those runtimes). Use this code with **@aws-sdk/client-textract** (v3), which is included in the runtime:

1. In Lambda: **Code** tab → **Code source**.
2. Make sure the file is **index.js** (rename from `index.mjs` if needed).
3. Replace the entire file contents with:

```javascript
const { TextractClient, DetectDocumentTextCommand } = require('@aws-sdk/client-textract');

const textract = new TextractClient({ region: process.env.AWS_REGION || 'us-east-1' });

function textractBoxToApp(box) {
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
    if (!body) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'No body' }) };
    }
    if (event.isBase64Encoded) body = Buffer.from(body, 'base64');
    else if (typeof body === 'string') body = Buffer.from(body, 'utf8');
    if (body.length === 0) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'Empty image' }) };
    }
    const result = await textract.send(new DetectDocumentTextCommand({ Document: { Bytes: body } }));
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
    console.error('OCR error:', err.code, err.message);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: err.message || 'Textract failed', code: err.code }),
    };
  }
};
```

4. **Configuration** → **General configuration** → **Edit** → set **Handler** to `index.handler` → **Save**.
5. **Configuration** → **General configuration** → **Edit** → set **Timeout** to **30** seconds → **Save**.
6. **Set region** (recommended): **Configuration** → **Environment variables** → **Edit** → **Add** → Key `AWS_REGION`, Value `us-east-1` (or your API region) → **Save**. This ensures Textract is called in the correct region.

---

## 4. Create the API Gateway HTTP API

1. **AWS Console** → **API Gateway** → **Create API**.
2. Choose **HTTP API** → **Build**.
3. **Add integration**: **Lambda** → select your region and the function `superbowlbox-ocr` → **Next**.
4. **API name**: e.g. `superbowlbox-ocr-api` → **Next**.
5. **Configure routes**: **Add route**:
   - **Method**: `POST`
   - **Resource path**: `/ocr`
   - **Integration target**: your Lambda function.
   Click **Next** → **Create**.
6. After creation, open **Stages** → **Default** and copy the **Invoke URL** (e.g. `https://abc123xyz.execute-api.us-east-1.amazonaws.com`).

Your full OCR URL is: **Invoke URL** + `/ocr` → e.g. `https://abc123xyz.execute-api.us-east-1.amazonaws.com/ocr`.

---

## 5. Configure the app

1. In the SuperBowlBox Xcode project, open **SuperBowlBox/Resources/Secrets.plist** (or create it from **Secrets.example.plist**).
2. Set **TextractBackendURL** to your full OCR URL (e.g. `https://abc123xyz.execute-api.us-east-1.amazonaws.com/ocr`). No trailing slash.
3. Leave **AWSAccessKeyId** and **AWSSecretAccessKey** empty (or omit them).
4. Build and run the app. When you scan a pool sheet, the app will send the image to your Lambda and use the returned text.

---

## Summary

| Step | What you do |
|------|-------------|
| 1 | Create Lambda (new role, basic permissions). |
| 2 | Attach **AmazonTextractFullAccess** to that role. No keys in Lambda. |
| 3 | Paste the Node.js code, handler `index.handler`, timeout 30 s. |
| 4 | Create HTTP API, route **POST** `/ocr` → Lambda, copy Invoke URL. |
| 5 | Set **TextractBackendURL** in `Secrets.plist` to `InvokeURL/ocr`. |

No access key in the app and none in Lambda—Option A only.

---

## Troubleshooting: HTTP 500 from OCR

A 500 means the Lambda ran but threw an error. Do this first:

### 1. Check CloudWatch Logs (see the real error)

1. **AWS Console** → **Lambda** → **Functions** → **superbowlbox-ocr**.
2. Open the **Monitor** tab → **View CloudWatch logs** (or **Logs** → **View logs in CloudWatch**).
3. Open the latest **log stream** (each scan creates one).
4. Look at the error line (e.g. `AccessDeniedException`, `InvalidParameterException`, or a stack trace). That tells you what failed.

### 2. Common causes and fixes

| If you see… | Fix |
|-------------|-----|
| **AccessDeniedException** or **User is not authorized** | The Lambda role cannot call Textract. In Lambda → **Configuration** → **Permissions** → click the **Role name** → **Add permissions** → **Attach policies** → attach **AmazonTextractFullAccess** → **Add permissions**. |
| **Runtime.ImportModuleError** or **Cannot find module 'aws-sdk'** | Node 18/20 Lambda no longer bundle the old AWS SDK v2. Use the **SDK v3** code below (Section 3) so the Lambda uses `@aws-sdk/client-textract`, which is available in the Node 18/20 runtime. |
| **Cannot find module** or **handler not found** | Use **index.js** (not index.mjs), paste the full Option A code, and set **Handler** to `index.handler`. |
| **event.body is null** or **body.length === 0** | API Gateway may not be passing the body. In **API Gateway** → your API → **Integrations** → select **POST /ocr** → ensure the integration is **Lambda proxy** (or that the request body is passed through). Redeploy the API if you change it. |
| **InvalidParameterException** or **Unsupported document** | Image may be too large (Textract limit 5MB for document bytes) or not valid JPEG. In the app, the image is sent as JPEG; if the photo is very large, consider resizing before upload (or reduce quality further). |
| **Region / endpoint** issues | Set Lambda **Environment variable** `AWS_REGION` = `us-east-1` (or the region where your API and Lambda run). |

### 3. Lambda code for Node 18/20 (use AWS SDK v3)

Node 18/20 Lambda runtimes **do not** include the old `aws-sdk` (v2). Use this code, which uses **@aws-sdk/client-textract** (included in the runtime):

```javascript
const { TextractClient, DetectDocumentTextCommand } = require('@aws-sdk/client-textract');

const textract = new TextractClient({ region: process.env.AWS_REGION || 'us-east-1' });

function textractBoxToApp(box) {
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
    if (!body) {
      console.error('event.body is missing');
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'No body' }) };
    }
    if (event.isBase64Encoded) body = Buffer.from(body, 'base64');
    else if (typeof body === 'string') body = Buffer.from(body, 'utf8');
    if (body.length === 0) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'Empty image' }) };
    }
    console.log('Body length:', body.length);
    const result = await textract.send(new DetectDocumentTextCommand({ Document: { Bytes: body } }));
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
    console.error('OCR error:', err.code || err.name, err.message);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: err.message || 'Textract failed', code: err.code || err.name }),
    };
  }
};
```

After updating: set env var **AWS_REGION** = `us-east-1` (or your region), **Deploy** the function, then try the app again and check CloudWatch if it still returns 500.
