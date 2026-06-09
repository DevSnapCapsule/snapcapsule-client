#!/usr/bin/env bash
# Deploy SnapCapsule Gemini proxy to Cloud Run (same project/region as Vision proxy).
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-savvy-droplet-476005-d6}"
REGION="${REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-gemini-proxy}"
SECRET_NAME="${SECRET_NAME:-GEMINI_API}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> SnapCapsule Gemini proxy deploy"
echo "    Project: $PROJECT_ID"
echo "    Region:  $REGION"
echo "    Service: $SERVICE_NAME"
echo ""

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud CLI not found."
  echo "Install: https://cloud.google.com/sdk/docs/install"
  echo "  macOS: brew install --cask google-cloud-sdk"
  exit 1
fi

echo "==> Setting gcloud project..."
gcloud config set project "$PROJECT_ID"

echo "==> Verifying secret '$SECRET_NAME' exists..."
if ! gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "ERROR: Secret '$SECRET_NAME' not found in project $PROJECT_ID."
  echo "Create it in Google Cloud Console → Secret Manager, or run:"
  echo "  echo -n 'YOUR_GEMINI_API_KEY' | gcloud secrets create $SECRET_NAME --data-file=- --project=$PROJECT_ID"
  exit 1
fi

echo "==> Granting Cloud Run access to secret..."
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
RUN_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --member="serviceAccount:${RUN_SA}" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet >/dev/null 2>&1 || true

echo "==> Enabling required APIs (idempotent)..."
gcloud services enable run.googleapis.com secretmanager.googleapis.com cloudbuild.googleapis.com \
  --project="$PROJECT_ID" \
  --quiet

echo "==> Deploying to Cloud Run (this may take a few minutes)..."
gcloud run deploy "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --source=. \
  --allow-unauthenticated \
  --set-secrets="${SECRET_NAME}=${SECRET_NAME}:latest" \
  --set-env-vars="GEMINI_MODEL=gemini-2.5-flash-lite" \
  --quiet

PROXY_URL="$(gcloud run services describe "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format='value(status.url)')"

echo ""
echo "==> Deployed successfully!"
echo "    Proxy URL: $PROXY_URL"
echo ""
echo "==> Testing proxy..."
HTTP_CODE="$(curl -s -o /tmp/gemini-proxy-test.json -w "%{http_code}" -X POST "$PROXY_URL" \
  -H "Content-Type: application/json" \
  -d '{"transcript":"find me nike related pics"}')"

echo "    HTTP $HTTP_CODE"
head -c 500 /tmp/gemini-proxy-test.json 2>/dev/null || true
echo ""
echo ""

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "WARNING: Test request did not return 200. Check Secret Manager value for $SECRET_NAME and Cloud Run logs:"
  echo "  gcloud run services logs read $SERVICE_NAME --project=$PROJECT_ID --region=$REGION --limit=50"
  exit 1
fi

echo "==> Done. iOS app default URL should match:"
echo "    https://gemini-proxy-937348762913.europe-west1.run.app"
echo "    (Update Config.plist GeminiProxyURL if your URL differs)"
