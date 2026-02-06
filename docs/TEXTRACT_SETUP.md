# Amazon Textract setup for pool sheet OCR

The app can use **Amazon Textract** instead of (or as a fallback to) Apple Vision for reading text from pool sheet images. Textract often handles handwriting and dense grids better.

---

## 1. AWS account and Textract access

1. **Sign in or create an AWS account**  
   https://aws.amazon.com → Sign In / Create account.

2. **Create an IAM user for the app** (recommended; do not use the root user):
   - Open **IAM** → **Users** → **Create user** (e.g. name: `superbowlbox-textract`).
   - **Access type**: Programmatic access (access key).
   - **Permissions**: Attach policy **`AmazonTextractFullAccess`** (or a custom policy that allows `textract:DetectDocumentText` only).
   - Finish and **save the Access Key ID and Secret Access Key** (you won’t see the secret again).

3. **Region**  
   Textract is available in many regions (e.g. `us-east-1`, `us-east-2`, `eu-west-1`). Pick one and use it consistently.

---

## 2. Add the AWS SDK for Swift in Xcode

1. Open **SuperBowlBox.xcodeproj** in Xcode.
2. **File** → **Add Package Dependencies…**
3. In the search field, enter:
   ```text
   https://github.com/awslabs/aws-sdk-swift
   ```
4. Click **Add Package**; when the package list loads, set **Dependency Rule** to “Up to Next Major Version” (e.g. 1.x) and click **Add Package** again.
5. When asked **Choose Package Products**, select:
   - **AWSTextract** (the Textract client for DetectDocumentText).
   - The resolver will pull in **ClientRuntime** and other dependencies automatically.
6. Click **Add Package** and wait for the package to resolve.
7. Ensure the **SuperBowlBox** target is checked so the package is linked to the app.

---

## 3. Put credentials in `Secrets.plist`

**Do not commit real keys.** Use the same `Secrets.plist` pattern as the rest of the app (see `Secrets.example.plist`).

1. Copy `SuperBowlBox/Resources/Secrets.example.plist` to `SuperBowlBox/Resources/Secrets.plist` if you don’t have one.
2. Ensure `Secrets.plist` is in **.gitignore** (so it’s not committed).
3. Add these keys (replace with your values):

| Key | Type | Description |
|-----|------|-------------|
| `AWSRegion` | String | e.g. `us-east-1` |
| `AWSAccessKeyId` | String | IAM user Access Key ID |
| `AWSSecretAccessKey` | String | IAM user Secret Access Key |

Example (snippet):

```xml
<key>AWSRegion</key>
<string>us-east-1</string>
<key>AWSAccessKeyId</key>
<string>AKIA...</string>
<key>AWSSecretAccessKey</key>
<string>...</string>
```

---

## 4. Optional: use environment variables (e.g. for dev)

Instead of (or in addition to) `Secrets.plist`, you can set:

- `AWS_REGION` (e.g. `us-east-1`)
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

In Xcode: **Product** → **Scheme** → **Edit Scheme…** → **Run** → **Arguments** → **Environment Variables**, and add them. Leave **Shared** unchecked so they are not committed.

---

## 5. How the app uses Textract

- When **Textract is configured** (backend URL or region + credentials), the scan flow will call **Textract** for text detection and then use the existing grid/name parsing.
- When Textract is **not** configured, the app continues to use **Apple Vision** only.
- Image is sent to Textract as **document bytes** (base64) in `DetectDocumentText`; no S3 bucket is required.

### OCR limits and name matching

- **You cannot “train” Textract**—it’s a fixed AWS API. The app improves results by **fuzzy name matching**: your name (e.g. “Mike Capace”) is matched to cells using exact spelling first, then by similarity (e.g. “Mike o Copec”) so small OCR/handwriting mistakes still count as your box.
- **Handwritten grids** are harder for OCR; some cells may be read as empty or merged. If “Names on Sheet” is less than 100, Textract didn’t return text for every cell—try a clearer photo, crop to the grid, or good lighting. The app does not train on your sheets; it only matches names from whatever text OCR returns.

---

## 6. Security notes

- **Distributed app (e.g. App Store)**: Do not put AWS keys in the app. Use a **backend** that holds the keys and calls Textract; the app only sends the image to your backend. See **[TEXTRACT_BACKEND_SETUP.md](TEXTRACT_BACKEND_SETUP.md)** for step‑by‑step (Lambda + API Gateway, API contract, and app config with `TextractBackendURL`).
- **Development**: Using keys in `Secrets.plist` or env vars is acceptable if the file and repo are kept private and keys are scoped to Textract only.

---

## 7. Cost

- Amazon Textract **DetectDocumentText** is charged per page (see [Textract pricing](https://aws.amazon.com/textract/pricing/)).
- There is a **Free Tier** for the first 1,000 pages per month for 3 months after sign-up.

---

## 8. After setup

- **TextractConfig** is already in the project and reads `AWSRegion`, `AWSAccessKeyId`, and `AWSSecretAccessKey` from `Secrets.plist` (or env).
- **TextractService** (and wiring it into `VisionService`) still needs to be implemented after the **AWSTextract** package is added. Once that’s done, when Textract is configured the scan flow will use Textract for OCR; otherwise it keeps using Apple Vision.
- To have the integration implemented (TextractService + VisionService switch), add the package as in step 2, then ask to “implement TextractService and use it in VisionService when configured”.

If you see errors, check:

- Credentials and region in `Secrets.plist` (or env).
- IAM user has `textract:DetectDocumentText` (e.g. via `AmazonTextractFullAccess`).
- Device has network access (Textract is a web API).
