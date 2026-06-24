#!/usr/bin/env bash
# Deploy SnapCapsule Shopping proxy to Cloud Run (same project/region as other proxies).
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-savvy-droplet-476005-d6}"
REGION="${REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-shopping-proxy}"

REQUIRED_SECRETS=(EBAY_CLIENT_ID EBAY_CLIENT_SECRET EBAY_ENVIRONMENT)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> SnapCapsule Shopping proxy deploy"
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

for SECRET_NAME in "${REQUIRED_SECRETS[@]}"; do
  echo "==> Verifying secret '$SECRET_NAME' exists..."
  if ! gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "ERROR: Secret '$SECRET_NAME' not found in project $PROJECT_ID."
    echo "Create it in Google Cloud Console → Secret Manager, or run:"
    echo "  echo -n 'YOUR_VALUE' | gcloud secrets create $SECRET_NAME --data-file=- --project=$PROJECT_ID"
    exit 1
  fi
done

echo "==> Granting Cloud Run access to secrets..."
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
RUN_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

for SECRET_NAME in "${REQUIRED_SECRETS[@]}"; do
  gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --member="serviceAccount:${RUN_SA}" \
    --role="roles/secretmanager.secretAccessor" \
    --quiet >/dev/null 2>&1 || true
done

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
  --set-secrets="EBAY_CLIENT_ID=EBAY_CLIENT_ID:latest,EBAY_CLIENT_SECRET=EBAY_CLIENT_SECRET:latest,EBAY_ENVIRONMENT=EBAY_ENVIRONMENT:latest" \
  --set-env-vars="AFFILIATE_ENABLED=false,CACHE_TTL_MINUTES=30" \
  --quiet

echo "==> Disabling invoker IAM check for public access..."
if ! gcloud run services update "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --no-invoker-iam-check \
  --quiet 2>/tmp/shopping-proxy-iam.err; then
  echo "WARNING: Could not disable invoker IAM check automatically."
  echo "    Run this manually (or ask a project owner):"
  echo ""
  echo "  gcloud run services update $SERVICE_NAME \\"
  echo "    --project=$PROJECT_ID \\"
  echo "    --region=$REGION \\"
  echo "    --no-invoker-iam-check"
  echo ""
  cat /tmp/shopping-proxy-iam.err 2>/dev/null || true
  echo ""
fi

PROXY_URL="$(gcloud run services describe "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format='value(status.url)')"

echo ""
echo "==> Deployed successfully!"
echo "    Proxy URL: $PROXY_URL"
echo ""
echo "==> Testing proxy health..."
HTTP_CODE="$(curl -s -o /tmp/shopping-proxy-test.json -w "%{http_code}" "$PROXY_URL/health")"

echo "    Health HTTP $HTTP_CODE"
cat /tmp/shopping-proxy-test.json 2>/dev/null || true
echo ""
echo ""

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "WARNING: Health check did not return 200."
  if [[ "$HTTP_CODE" == "403" ]]; then
    echo "    HTTP 403 usually means the service is not publicly invokable yet."
    echo "    Run:"
    echo ""
    echo "  gcloud run services update $SERVICE_NAME \\"
    echo "    --project=$PROJECT_ID \\"
    echo "    --region=$REGION \\"
    echo "    --no-invoker-iam-check"
    echo ""
  fi
  echo "    Cloud Run logs:"
  echo "  gcloud run services logs read $SERVICE_NAME --project=$PROJECT_ID --region=$REGION --limit=50"
  exit 1
fi

echo "==> Testing product search (eBay production)..."
SEARCH_CODE="$(curl -s -o /tmp/shopping-proxy-search.json -w "%{http_code}" \
  "$PROXY_URL/shopping/search?q=headphones&country=US&limit=3")"

echo "    Search HTTP $SEARCH_CODE"
head -c 400 /tmp/shopping-proxy-search.json 2>/dev/null || true
echo ""
echo ""

if [[ "$SEARCH_CODE" != "200" ]]; then
  echo "WARNING: Search test did not return 200. Check eBay credentials and Cloud Run logs:"
  echo "  gcloud run services logs read $SERVICE_NAME --project=$PROJECT_ID --region=$REGION --limit=50"
  exit 1
fi

echo "==> Done. Point the iOS app at this URL via Config.plist ShoppingProxyURL:"
echo "    $PROXY_URL"
