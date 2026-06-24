/**
 * SnapCapsule Shopping proxy — Cloud Run
 *
 * Reads EBAY_CLIENT_ID and EBAY_CLIENT_SECRET from the environment
 * (mounted from Google Secret Manager). Exposes eBay Browse API search
 * with normalized product responses.
 */

const express = require("express");

const PORT = process.env.PORT || 8080;
const EBAY_CLIENT_ID = process.env.EBAY_CLIENT_ID;
const EBAY_CLIENT_SECRET = process.env.EBAY_CLIENT_SECRET;
const EBAY_ENVIRONMENT = (process.env.EBAY_ENVIRONMENT || "sandbox").trim().toLowerCase();
const AFFILIATE_ENABLED = process.env.AFFILIATE_ENABLED === "true";
const EBAY_CAMPAIGN_ID = process.env.EBAY_CAMPAIGN_ID || "";
const CACHE_TTL_MINUTES = parseInt(process.env.CACHE_TTL_MINUTES || "30", 10);

const EBAY_BASE_URL =
  EBAY_ENVIRONMENT === "production"
    ? "https://api.ebay.com"
    : "https://api.sandbox.ebay.com";

// Only marketplaces supported by the eBay Browse API. Country codes not listed
// here (e.g. IN — eBay India is not supported by Browse and returns HTTP 409)
// fall back to the US marketplace so the app always gets results.
const MARKETPLACE_MAP = {
  US: "EBAY_US",
  GB: "EBAY_GB",
  DE: "EBAY_DE",
  AU: "EBAY_AU",
  CA: "EBAY_CA",
  FR: "EBAY_FR",
  IT: "EBAY_IT",
  ES: "EBAY_ES",
  AT: "EBAY_AT",
  BE: "EBAY_BE",
  CH: "EBAY_CH",
  IE: "EBAY_IE",
  NL: "EBAY_NL",
  PL: "EBAY_PL",
  HK: "EBAY_HK",
  MY: "EBAY_MY",
  PH: "EBAY_PH",
  SG: "EBAY_SG",
  TW: "EBAY_TW",
  TH: "EBAY_TH",
  VN: "EBAY_VN",
};

const DEFAULT_MARKETPLACE_ID = "EBAY_US";

function resolveMarketplaceId(country) {
  return MARKETPLACE_MAP[String(country || "").toUpperCase()] || DEFAULT_MARKETPLACE_ID;
}

// ── OAuth token cache ────────────────────────────────────────────────────────

let cachedToken = null;
let tokenExpiresAt = 0;

async function getEbayToken() {
  const now = Date.now();
  if (cachedToken && now < tokenExpiresAt - 60_000) {
    return cachedToken;
  }

  if (!EBAY_CLIENT_ID || !EBAY_CLIENT_SECRET) {
    throw new ProxyError("eBay credentials are not configured on the server.", 500);
  }

  const credentials = Buffer.from(`${EBAY_CLIENT_ID}:${EBAY_CLIENT_SECRET}`).toString("base64");
  const tokenUrl = `${EBAY_BASE_URL}/identity/v1/oauth2/token`;

  let response;
  try {
    response = await fetch(tokenUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: `Basic ${credentials}`,
      },
      body: "grant_type=client_credentials&scope=https://api.ebay.com/oauth/api_scope",
    });
  } catch {
    throw new ProxyError("Unable to reach eBay authentication service.", 502);
  }

  let data;
  try {
    data = await response.json();
  } catch {
    throw new ProxyError("Invalid response from eBay authentication service.", 502);
  }

  if (!response.ok) {
    console.error("eBay OAuth token fetch failed with status", response.status);
    throw new ProxyError("Failed to authenticate with eBay.", 502);
  }

  if (!data.access_token) {
    throw new ProxyError("Failed to authenticate with eBay.", 502);
  }

  cachedToken = data.access_token;
  const expiresIn = typeof data.expires_in === "number" ? data.expires_in : 7200;
  tokenExpiresAt = now + expiresIn * 1000;

  return cachedToken;
}

// ── Affiliate hook (disabled by default) ─────────────────────────────────────

/**
 * Affiliate tagging disabled per product decision. To enable:
 * 1. Join eBay Partner Network at partnernetwork.ebay.com
 * 2. Get your campaign ID
 * 3. Set EBAY_CAMPAIGN_ID and AFFILIATE_ENABLED=true in Secret Manager
 * 4. Update this function to inject the campaign ID into the URL
 */
function applyAffiliateTag(buyUrl, source) {
  if (!AFFILIATE_ENABLED || source !== "ebay") {
    return buyUrl;
  }
  // Placeholder — implement campaign ID injection when monetization is enabled.
  void EBAY_CAMPAIGN_ID;
  return buyUrl;
}

// ── Provider abstraction ─────────────────────────────────────────────────────

/**
 * @typedef {Object} NormalizedProduct
 * @property {string} id
 * @property {string} title
 * @property {number} price
 * @property {string} currency
 * @property {string} imageUrl
 * @property {string} buyUrl
 * @property {string} seller
 * @property {string} condition
 * @property {string} source
 */

/** @type {ProductSearchProvider} */
const ebayProvider = {
  name: "ebay",

  async searchProducts(query, country, limit, offset) {
    const token = await getEbayToken();
    const requestedMarketplaceId = resolveMarketplaceId(country);

    let result = await this.browse(token, query, limit, offset, requestedMarketplaceId);

    // eBay returns 409 when the marketplace is valid syntactically but not
    // supported by the Browse API for these credentials. Retry once on the
    // default US marketplace so the user still gets results.
    if (result.status === 409 && requestedMarketplaceId !== DEFAULT_MARKETPLACE_ID) {
      console.log("Marketplace not supported, retrying on default marketplace");
      result = await this.browse(token, query, limit, offset, DEFAULT_MARKETPLACE_ID);
    }

    if (!result.ok) {
      console.error("eBay Browse API error, status:", result.status);
      throw new ProxyError("eBay search request failed.", 502);
    }

    const items = Array.isArray(result.data.itemSummaries) ? result.data.itemSummaries : [];
    return items.map(normalizeEbayItem).filter(Boolean);
  },

  async browse(token, query, limit, offset, marketplaceId) {
    const params = new URLSearchParams({
      q: query,
      limit: String(limit),
      offset: String(offset),
    });

    const searchUrl = `${EBAY_BASE_URL}/buy/browse/v1/item_summary/search?${params}`;

    let response;
    try {
      response = await fetch(searchUrl, {
        headers: {
          Authorization: `Bearer ${token}`,
          "X-EBAY-C-MARKETPLACE-ID": marketplaceId,
          Accept: "application/json",
        },
      });
    } catch {
      throw new ProxyError("Unable to reach eBay search service.", 502);
    }

    let data;
    try {
      data = await response.json();
    } catch {
      throw new ProxyError("Invalid response from eBay search service.", 502);
    }

    return { ok: response.ok, status: response.status, data };
  },
};

/**
 * Amazon Creators API provider — not yet implemented.
 * Implement this interface to add Amazon product search without changing
 * the endpoint contract or iOS client code.
 */
/** @type {ProductSearchProvider} */
const amazonProvider = {
  name: "amazon",

  async searchProducts(_query, _country, _limit, _offset) {
    throw new ProxyError("Amazon product search is not yet implemented.", 501);
  },
};

/** @typedef {{ name: string, searchProducts: (query: string, country: string, limit: number, offset: number) => Promise<NormalizedProduct[]> }} ProductSearchProvider */

const providers = {
  ebay: ebayProvider,
  amazon: amazonProvider,
};

function normalizeEbayItem(item) {
  if (!item || typeof item !== "object") return null;

  const id = typeof item.itemId === "string" ? item.itemId : "";
  const title = typeof item.title === "string" ? item.title : "";
  const imageUrl =
    typeof item.image?.imageUrl === "string" ? item.image.imageUrl : "";
  const rawPrice = item.price?.value;
  const price = rawPrice != null ? parseFloat(String(rawPrice)) : NaN;
  const currency =
    typeof item.price?.currency === "string" ? item.price.currency : "USD";
  const buyUrl =
    typeof item.itemWebUrl === "string" ? item.itemWebUrl : "";
  const seller =
    typeof item.seller?.username === "string" ? item.seller.username : "";
  const condition =
    typeof item.condition === "string" ? item.condition : "";

  if (!imageUrl && (isNaN(price) || price <= 0)) return null;
  if (!id || !title) return null;

  const taggedUrl = applyAffiliateTag(buyUrl, "ebay");

  return {
    id,
    title,
    price: isNaN(price) ? 0 : price,
    currency,
    imageUrl,
    buyUrl: taggedUrl,
    seller,
    condition,
    source: "ebay",
  };
}

// ── LRU cache ────────────────────────────────────────────────────────────────

class LRUCache {
  constructor(maxSize, ttlMs) {
    this.maxSize = maxSize;
    this.ttlMs = ttlMs;
    this.cache = new Map();
  }

  get(key) {
    const entry = this.cache.get(key);
    if (!entry) return undefined;

    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return undefined;
    }

    this.cache.delete(key);
    this.cache.set(key, entry);
    return entry.value;
  }

  set(key, value) {
    if (this.cache.has(key)) {
      this.cache.delete(key);
    }
    while (this.cache.size >= this.maxSize) {
      const oldest = this.cache.keys().next().value;
      this.cache.delete(oldest);
    }
    this.cache.set(key, {
      value,
      expiresAt: Date.now() + this.ttlMs,
    });
  }
}

const responseCache = new LRUCache(200, CACHE_TTL_MINUTES * 60 * 1000);

// ── Rate limiting (per IP) ───────────────────────────────────────────────────

const rateLimitWindowMs = 60_000;
const rateLimitMax = 30;
const rateLimitBuckets = new Map();

function checkRateLimit(ip) {
  const now = Date.now();
  let bucket = rateLimitBuckets.get(ip);

  if (!bucket || now - bucket.windowStart > rateLimitWindowMs) {
    bucket = { windowStart: now, count: 0 };
    rateLimitBuckets.set(ip, bucket);
  }

  bucket.count += 1;

  if (bucket.count > rateLimitMax) {
    return false;
  }
  return true;
}

// Periodic cleanup of stale rate-limit buckets
setInterval(() => {
  const now = Date.now();
  for (const [ip, bucket] of rateLimitBuckets) {
    if (now - bucket.windowStart > rateLimitWindowMs * 2) {
      rateLimitBuckets.delete(ip);
    }
  }
}, rateLimitWindowMs * 2).unref();

// ── Input validation ─────────────────────────────────────────────────────────

function sanitizeQuery(raw) {
  if (typeof raw !== "string") return "";
  let text = raw.trim();
  if (!text) return "";
  text = text.replace(/[^\w\s\-']/g, " ").replace(/\s+/g, " ").trim();
  return text.slice(0, 200);
}

function parseLimit(raw) {
  const parsed = parseInt(raw, 10);
  if (isNaN(parsed) || parsed < 1) return 20;
  return Math.min(parsed, 40);
}

function parseOffset(raw) {
  const parsed = parseInt(raw, 10);
  if (isNaN(parsed) || parsed < 0) return 0;
  return parsed;
}

function parseCountry(raw) {
  if (typeof raw !== "string" || !raw.trim()) return "US";
  const code = raw.trim().toUpperCase();
  return code.length === 2 ? code : "US";
}

// ── Express app ──────────────────────────────────────────────────────────────

const app = express();

app.get("/", (_req, res) => {
  res.json({ status: "ok", service: "snapcapsule-shopping-proxy" });
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.get("/shopping/search", async (req, res) => {
  try {
    const clientIp =
      req.headers["x-forwarded-for"]?.toString().split(",")[0]?.trim() ||
      req.socket.remoteAddress ||
      "unknown";

    if (!checkRateLimit(clientIp)) {
      sendError(res, 429, "RATE_LIMITED", "Too many requests. Please try again later.");
      return;
    }

    const query = sanitizeQuery(req.query.q);
    if (!query) {
      sendError(res, 400, "INVALID_QUERY", "Missing or invalid search query.");
      return;
    }

    const country = parseCountry(req.query.country);
    const limit = parseLimit(req.query.limit);
    const offset = parseOffset(req.query.offset);
    const providerName = typeof req.query.provider === "string" ? req.query.provider : "ebay";

    const provider = providers[providerName];
    if (!provider) {
      sendError(res, 400, "INVALID_PROVIDER", "Unknown product search provider.");
      return;
    }

    const cacheKey = `${providerName}:${query.toLowerCase()}:${country}:${limit}:${offset}`;
    const cached = responseCache.get(cacheKey);
    if (cached) {
      console.log("Cache hit for search request");
      res.json(cached);
      return;
    }

    const products = await provider.searchProducts(query, country, limit, offset);
    responseCache.set(cacheKey, products);
    res.json(products);
  } catch (error) {
    handleProxyError(res, error, "Shopping proxy error:");
  }
});

// ── Error handling ───────────────────────────────────────────────────────────

class ProxyError extends Error {
  constructor(message, statusCode = 500, code = "INTERNAL_ERROR") {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }
}

function sendError(res, status, code, message) {
  res.status(status).json({ error: { code, message } });
}

function handleProxyError(res, error, logPrefix) {
  console.error(logPrefix, error instanceof Error ? error.message : error);

  if (error instanceof ProxyError) {
    sendError(res, error.statusCode, error.code, error.message);
    return;
  }

  sendError(res, 500, "INTERNAL_ERROR", "An unexpected error occurred.");
}

app.listen(PORT, () => {
  console.log(`Shopping proxy listening on port ${PORT} (${EBAY_ENVIRONMENT})`);
});
