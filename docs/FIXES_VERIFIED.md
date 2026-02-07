# Fixes verified – all implemented

This checklist confirms the fixes from our sessions are in the repo. Use it to confirm nothing was reverted.

---

## Scan (AI grid) – AI overrides OCR

- [x] **VisionService**: When `AIGridBackendURL` is set, **only AI** is used for grid/names/rules; OCR (Textract) and on-device Vision are not used. OCR path runs only when AI is not configured.
- [x] **App** (`AIGridBackendService.swift`): Sends `POST application/json` with body `{ "image": "<base64>" }` (no raw binary through API Gateway).
- [x] **Lambda** (`docs/lambda-ai-grid-index.js`): Accepts (1) JSON `{ "image": "<base64>" }`, (2) legacy raw image. Uses `ANTHROPIC_API_KEY` and optional `MODEL` env.
- [x] **VisionService**: Maps `URLError.cannotFindHost` to `VisionError.scanServerUnreachable`; message refers to AIGridBackendURL (AI handles grid, names, rules).
- [x] **Placeholder** (`AIGridConfig`): Only `your-api.example.com` or host containing `your-api-id` are treated as unset; real and local URLs work.

## Payout parse

- [x] **App** (`PayoutParseService.swift`): Unwraps Lambda proxy response (`body` string); catches `cannotFindHost` and throws `PayoutParseError.serverUnreachable`.
- [x] **Lambda** (`docs/lambda-payout-parse-index.js`): Contract and optional `MODEL` env in header comment.
- [x] **Placeholder** (`PayoutParseConfig`): Same narrow placeholder rule as AI grid.

## OCR (Textract) – not used when AI grid is configured

- [x] **App** (`TextractBackendService.swift`): Unwraps Lambda proxy `body` before decoding `BackendOCRResponse`. Used only when `AIGridBackendURL` is not set.
- [x] **Placeholder** (`TextractConfig`): Same narrow placeholder rule.

## Team logos

- [x] **Team.swift**: `espnLogoSlug(for:)` maps e.g. SE→sea, NE/nep/pat→ne; `displayLogoURL` uses it when `logoURL` is nil.
- [x] **NFLScoreService**: Does not set a fallback `logoURL` when API omits it (so `displayLogoURL` uses slug mapping).
- [x] **LogoImageView** (`Views/LogoImageView.swift`): Loads image with User-Agent so ESPN CDN serves; used by `TeamLogoView` and `TeamScoreColumn`.
- [x] **ContentView** (`TeamScoreColumn`): Uses `LogoImageView` (not `AsyncImage`) for featured game logos.
- [x] **CreateFromGameView** (`TeamLogoView`): Uses shared `LogoImageView`.

## Local and live APIs

- [x] **Placeholders** (all configs): Only doc placeholders rejected; `hasPrefix("YOUR_")` for keys (not `contains`).
- [x] **Info.plist**: `NSAppTransportSecurity` exception for `localhost` and `127.0.0.1` so HTTP local APIs work in simulator.
- [x] **Docs**: `LOCAL_AND_LIVE_APIS.md`, `LAMBDAS_OVERVIEW.md`, `DISTRIBUTION_CHECKLIST.md`, `SECRETS_URLS_REFERENCE.md` reference each other where needed.

## UI

- [x] **Featured game / add pool**: Text between logos centered (ContentView game row, CreateFromGameView `GameRowView`).

## Distribution

- [x] **Secrets.example.plist**: Real Lambda base URL (`0lgqfeaqxh...`) for ai-grid, ocr, parse-payout.
- [x] **Docs**: Distribution checklist, Lambdas overview, and secrets URL reference all in place.

---

If you pull or merge and something breaks, re-check this list and the referenced files above.
