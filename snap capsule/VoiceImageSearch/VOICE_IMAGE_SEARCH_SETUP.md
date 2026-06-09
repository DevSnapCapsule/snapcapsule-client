# Voice Image Search — Proxy Setup

Voice search uses a **Cloud Run proxy** (same pattern as Google Vision). The iOS app never sees your Gemini API key.

## Architecture

```
iPhone app  →  POST { "transcript": "..." }
           →  https://gemini-proxy-937348762913.europe-west1.run.app
           →  Cloud Run reads GEMINI_API from Secret Manager
           →  Google Gemini API
           →  JSON search intent back to the app
```

## What you need to do

### 1. Secret Manager (you already did this)

Create secret **`GEMINI_API`** with your Gemini API key as the value.

### 2. Deploy the proxy

```bash
cd backend/gemini-proxy

gcloud run deploy gemini-proxy \
  --project=937348762913 \
  --region=europe-west1 \
  --source=. \
  --allow-unauthenticated \
  --set-secrets=GEMINI_API=GEMINI_API:latest \
  --set-env-vars=GEMINI_MODEL=gemini-2.5-flash-lite
```

See `backend/gemini-proxy/README.md` for IAM and testing steps.

### 3. iOS app — nothing else required

The app already calls:

`https://gemini-proxy-937348762913.europe-west1.run.app`

Override only if your deploy URL differs — set `GeminiProxyURL` in `Config.plist`:

```bash
cp "snap capsule/Config.plist.example" "snap capsule/Config.plist"
```

No `GeminiAPIKey` in the app is needed.

## Test

```bash
curl -s -X POST "https://gemini-proxy-937348762913.europe-west1.run.app" \
  -H "Content-Type: application/json" \
  -d '{"transcript":"find me nike related pics"}'
```

Then run the app → **Voice** tab → speak a search query.
