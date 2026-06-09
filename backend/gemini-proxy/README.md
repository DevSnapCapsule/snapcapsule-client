# Gemini Proxy — Deploy to Cloud Run

This service reads **`GEMINI_API`** from Google Secret Manager and exposes an HTTP endpoint for the SnapCapsule iOS app (same pattern as the Vision proxy).

## Prerequisites

- Google Cloud project `937348762913` (same as Vision proxy) or your own project
- Secret **`GEMINI_API`** already created in Secret Manager with your Gemini API key value
- `gcloud` CLI installed and authenticated

## 1. Grant Secret Manager access

Replace `PROJECT_ID` and use the Cloud Run service account (default compute SA or a dedicated one):

```bash
export PROJECT_ID=937348762913
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

gcloud secrets add-iam-policy-binding GEMINI_API \
  --project=$PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## 2. Deploy to Cloud Run (europe-west1, matches Vision)

From this directory:

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

Note the URL printed after deploy, e.g.:

```
https://gemini-proxy-937348762913.europe-west1.run.app
```

## 3. Test the proxy

```bash
curl -s -X POST "https://gemini-proxy-937348762913.europe-west1.run.app" \
  -H "Content-Type: application/json" \
  -d '{"transcript":"find me nike related pics"}'
```

Expected: JSON with `searchQuery`, `assistantMessage`, etc.

## 4. iOS app

The app calls this URL by default (hardcoded like Vision). Override with `GeminiProxyURL` in `Config.plist` if your deploy URL differs.

No API key is required in the iOS app when using the proxy.

## Request / response

**POST /**

```json
{ "transcript": "find me photos with a laptop" }
```

**Response**

```json
{
  "searchQuery": "laptop",
  "brand": null,
  "object": "laptop",
  "product": null,
  "scene": null,
  "personContext": null,
  "assistantMessage": "Sure, I'll search for photos that include a laptop."
}
```

**Error**

```json
{ "error": "description" }
```
