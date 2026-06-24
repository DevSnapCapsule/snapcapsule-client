# Shopping Proxy — Deploy to Cloud Run

This service reads **eBay API credentials** from Google Secret Manager and exposes a normalized product search endpoint for the SnapCapsule iOS app. The iOS client never talks to eBay directly — all requests go through this proxy.

## What this service does

1. Accepts a product search query from the iOS app
2. Obtains an eBay OAuth application token (client credentials grant)
3. Calls the eBay Browse API (`/buy/browse/v1/item_summary/search`)
4. Returns a normalized JSON array of products (title, price, image, buy URL, etc.)

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `EBAY_CLIENT_ID` | Yes | — | eBay App ID (Client ID) from [developer.ebay.com](https://developer.ebay.com) |
| `EBAY_CLIENT_SECRET` | Yes | — | eBay Cert ID (Client Secret) |
| `EBAY_ENVIRONMENT` | No | `sandbox` | `sandbox` or `production` — controls which eBay API base URL is used |
| `AFFILIATE_ENABLED` | No | `false` | When `true`, enables affiliate URL tagging (requires campaign ID) |
| `EBAY_CAMPAIGN_ID` | No | — | eBay Partner Network campaign ID (only used when affiliate is enabled) |
| `CACHE_TTL_MINUTES` | No | `30` | In-memory LRU cache TTL for search responses |

## Prerequisites

- Google Cloud project (same as other SnapCapsule proxies)
- `gcloud` CLI installed and authenticated
- eBay developer account with Browse API access

## 1. Create eBay developer credentials

1. Go to [developer.ebay.com](https://developer.ebay.com) and sign in
2. Create an application (or use an existing one)
3. Enable the **Buy APIs** scope (Browse API)
4. Copy the **App ID (Client ID)** and **Cert ID (Client Secret)**
5. Start with **Sandbox** keys for testing

## 2. Store secrets in Secret Manager

```bash
export PROJECT_ID=937348762913

echo -n 'YOUR_SANDBOX_CLIENT_ID' | gcloud secrets create EBAY_CLIENT_ID \
  --data-file=- --project=$PROJECT_ID

echo -n 'YOUR_SANDBOX_CLIENT_SECRET' | gcloud secrets create EBAY_CLIENT_SECRET \
  --data-file=- --project=$PROJECT_ID

echo -n 'sandbox' | gcloud secrets create EBAY_ENVIRONMENT \
  --data-file=- --project=$PROJECT_ID
```

For production, set `EBAY_ENVIRONMENT` to `production` (no trailing spaces or newlines):

```bash
echo -n 'production' | gcloud secrets versions add EBAY_ENVIRONMENT --data-file=- --project=$PROJECT_ID
```

To update an existing secret:

```bash
echo -n 'NEW_VALUE' | gcloud secrets versions add EBAY_CLIENT_ID --data-file=- --project=$PROJECT_ID
```

## 3. Grant Secret Manager access

```bash
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

for SECRET in EBAY_CLIENT_ID EBAY_CLIENT_SECRET EBAY_ENVIRONMENT; do
  gcloud secrets add-iam-policy-binding $SECRET \
    --project=$PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

## 4. Deploy to Cloud Run

From this directory:

```bash
cd backend/shopping-proxy
./deploy.sh
```

Or manually:

```bash
gcloud run deploy shopping-proxy \
  --project=937348762913 \
  --region=europe-west1 \
  --source=. \
  --allow-unauthenticated \
  --set-secrets="EBAY_CLIENT_ID=EBAY_CLIENT_ID:latest,EBAY_CLIENT_SECRET=EBAY_CLIENT_SECRET:latest,EBAY_ENVIRONMENT=EBAY_ENVIRONMENT:latest" \
  --set-env-vars="AFFILIATE_ENABLED=false,CACHE_TTL_MINUTES=30"
```

## 5. Test the proxy

```bash
curl -s "https://shopping-proxy-937348762913.europe-west1.run.app/shopping/search?q=Nike+Air+Max&country=US&limit=5" | head -c 500
```

Expected: JSON array of normalized product objects.

## Sandbox vs Production

| Setting | Sandbox | Production |
|---------|---------|------------|
| `EBAY_ENVIRONMENT` | `sandbox` | `production` |
| API base URL | `https://api.sandbox.ebay.com` | `https://api.ebay.com` |
| Credentials | Sandbox App ID / Cert ID | Production App ID / Cert ID |

**Always test with sandbox keys first.** When ready for production:

1. Create production keys at [developer.ebay.com](https://developer.ebay.com)
2. Update Secret Manager values for `EBAY_CLIENT_ID` and `EBAY_CLIENT_SECRET`
3. Redeploy with `EBAY_ENVIRONMENT=production`

## Monetization is currently OFF

Affiliate tagging is disabled by default (`AFFILIATE_ENABLED=false`). The `applyAffiliateTag()` function in `index.js` is a no-op stub.

To enable monetization later:

1. Join the [eBay Partner Network](https://partnernetwork.ebay.com)
2. Get your campaign ID
3. Set `EBAY_CAMPAIGN_ID` and `AFFILIATE_ENABLED=true` in Cloud Run env vars
4. Update `applyAffiliateTag()` to inject the campaign ID into product URLs

No other code changes are needed — affiliate logic is fully isolated to that one function.

## iOS app integration

Override the default proxy URL with `ShoppingProxyURL` in `Config.plist` if your deploy URL differs. No API keys are needed in the iOS app.

## API reference

**GET /shopping/search**

| Param | Required | Default | Description |
|-------|----------|---------|-------------|
| `q` | Yes | — | Product search query (max 200 chars) |
| `country` | No | `US` | ISO country code (`US`, `GB`, `DE`, `AU`, `IN`) |
| `limit` | No | `20` | Number of results (max 40) |
| `offset` | No | `0` | Pagination offset |

**Response** — JSON array:

```json
[
  {
    "id": "v1|123456789|0",
    "title": "Nike Air Max 90",
    "price": 89.99,
    "currency": "USD",
    "imageUrl": "https://i.ebayimg.com/...",
    "buyUrl": "https://www.ebay.com/itm/...",
    "seller": "sneaker_store",
    "condition": "New",
    "source": "ebay"
  }
]
```

**Error response:**

```json
{
  "error": {
    "code": "INVALID_QUERY",
    "message": "Missing or invalid search query."
  }
}
```

| HTTP Status | Code | Meaning |
|-------------|------|---------|
| 400 | `INVALID_QUERY` | Bad or missing query |
| 429 | `RATE_LIMITED` | Too many requests (30/min per IP) |
| 502 | — | Upstream eBay failure |
| 500 | `INTERNAL_ERROR` | Server error |
