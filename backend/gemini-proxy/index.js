/**
 * SnapCapsule Gemini proxy — Cloud Run
 *
 * Reads GEMINI_API from the environment (mount from Google Secret Manager).
 * Accepts POST { "transcript": "..." } and returns structured search intent JSON.
 */

const express = require("express");

const PORT = process.env.PORT || 8080;
const GEMINI_API = process.env.GEMINI_API;
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash-lite";

const SEARCH_INTENT_SYSTEM_PROMPT = `Parse a spoken photo search into JSON only with keys: searchQuery, brand, object, product, scene, personContext, assistantMessage.
Use null for unused fields. No color terms. searchQuery is one combined metadata string. assistantMessage is one short friendly sentence.`;

const PRODUCT_QUERY_SYSTEM_PROMPT = `You generate shopping search queries for e-commerce sites like Amazon and Google Shopping.
Return only a JSON array of strings — no wrapper object, no markdown. Generate at least 2 queries.
The tags are ordered by confidence, most relevant first.
The FIRST query must be specific to the item in the photo, combining the brand (if any) with the most relevant tags.
The SECOND query must be the single most popular, best-selling, or most-searched product shoppers commonly look for — based on the brand (if any), otherwise the most relevant tag.
Each query must read like a real search term a shopper types: natural, specific, and product-focused.
Keep each query under 8 words. No punctuation and no quotes inside query strings.
Avoid vague phrases like "image containing" or "photo of".`;

const app = express();
app.use(express.json({ limit: "32kb" }));

app.get("/", (_req, res) => {
  res.json({ status: "ok", service: "snapcapsule-gemini-proxy" });
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/", async (req, res) => {
  try {
    const transcript = typeof req.body?.transcript === "string"
      ? req.body.transcript.trim()
      : "";

    if (!transcript) {
      res.status(400).json({ error: "Missing or empty transcript." });
      return;
    }

    const text = await callGemini({
      systemPrompt: SEARCH_INTENT_SYSTEM_PROMPT,
      userPrompt: transcript,
      temperature: 0.2,
    });

    const parsed = parseAssistantJSON(text);
    res.json(parsed);
  } catch (error) {
    handleProxyError(res, error, "Gemini proxy error:");
  }
});

app.post("/product-queries", async (req, res) => {
  try {
    const brands = normalizeStringArray(req.body?.brands);
    const tags = normalizeStringArray(req.body?.tags);

    if (brands.length === 0 && tags.length === 0) {
      res.status(400).json({ error: "Missing brands and tags." });
      return;
    }

    const userPrompt = buildProductQueryUserPrompt(brands, tags);
    const text = await callGemini({
      systemPrompt: PRODUCT_QUERY_SYSTEM_PROMPT,
      userPrompt,
      temperature: 0.3,
    });

    const queries = parseQueryArrayJSON(text);
    res.json(queries);
  } catch (error) {
    handleProxyError(res, error, "Product query proxy error:");
  }
});

async function callGemini({ systemPrompt, userPrompt, temperature }) {
  if (!GEMINI_API) {
    throw new ProxyError("GEMINI_API secret is not configured on the server.", 500);
  }

  const geminiUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

  const geminiResponse = await fetch(geminiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": GEMINI_API,
    },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: systemPrompt }],
      },
      contents: [
        {
          role: "user",
          parts: [{ text: userPrompt }],
        },
      ],
      generationConfig: {
        temperature,
        maxOutputTokens: 256,
        responseMimeType: "application/json",
      },
    }),
  });

  const geminiData = await geminiResponse.json();

  if (!geminiResponse.ok) {
    const message =
      geminiData?.error?.message ||
      `Gemini API error (${geminiResponse.status})`;
    throw new ProxyError(message, geminiResponse.status);
  }

  const text = extractGeminiText(geminiData);
  if (!text) {
    throw new ProxyError("Gemini returned an empty response.", 502);
  }

  return text;
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const result = [];
  for (const item of value) {
    if (typeof item !== "string") continue;
    const trimmed = item.trim();
    if (!trimmed) continue;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(trimmed);
  }
  return result;
}

function buildProductQueryUserPrompt(brands, tags) {
  const brandList = brands.join(", ");
  const tagList = tags.join(", ");
  const topTag = tags[0] || "the main item";

  if (brands.length === 0) {
    return `Image tags (most relevant first): [${tagList}]. Query 1: a specific shopping search for this item using the most relevant tags. Query 2: the most popular or most-searched product related to ${topTag} that shoppers buy. Return only a JSON array of strings. Example output: ["brown leather crossbody bag", "best selling crossbody bags women"]`;
  }

  return `Brand: [${brandList}]. Image tags (most relevant first): [${tagList}]. Query 1: a specific shopping search combining the brand with the most relevant tags. Query 2: the most popular or most-searched ${brands[0]} product shoppers buy right now. Return only a JSON array of strings. Example output: ["Nike white running shoes men", "Nike Air Force 1"]`;
}

function parseQueryArrayJSON(text) {
  const trimmed = text.trim();
  let jsonString = trimmed;

  if (!trimmed.startsWith("[")) {
    const start = trimmed.indexOf("[");
    const end = trimmed.lastIndexOf("]");
    if (start === -1 || end === -1) {
      throw new Error("Invalid JSON array from Gemini.");
    }
    jsonString = trimmed.slice(start, end + 1);
  }

  const parsed = JSON.parse(jsonString);
  if (!Array.isArray(parsed)) {
    throw new Error("Expected a JSON array from Gemini.");
  }

  return parsed
    .filter((item) => typeof item === "string")
    .map((item) => sanitizeQueryString(item))
    .filter(Boolean);
}

function sanitizeQueryString(raw) {
  let text = raw.trim().replace(/^["']|["']$/g, "");
  text = text.replace(/[^\w\s]/g, " ").replace(/\s+/g, " ").trim();
  if (!text) return "";
  const words = text.split(" ");
  return words.slice(0, 8).join(" ");
}

class ProxyError extends Error {
  constructor(message, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
  }
}

function handleProxyError(res, error, logPrefix) {
  console.error(logPrefix, error);
  const status = error instanceof ProxyError ? error.statusCode : 500;
  const message = error instanceof Error ? error.message : "Internal server error";
  res.status(status).json({ error: message });
}

function extractGeminiText(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return "";
  return parts.map((part) => part.text || "").join("");
}

function parseAssistantJSON(text) {
  const trimmed = text.trim();
  let jsonString = trimmed;

  if (!trimmed.startsWith("{")) {
    const start = trimmed.indexOf("{");
    const end = trimmed.lastIndexOf("}");
    if (start === -1 || end === -1) {
      throw new Error("Invalid JSON from Gemini.");
    }
    jsonString = trimmed.slice(start, end + 1);
  }

  const parsed = JSON.parse(jsonString);

  return {
    searchQuery: String(parsed.searchQuery ?? ""),
    brand: parsed.brand ?? null,
    object: parsed.object ?? null,
    product: parsed.product ?? null,
    scene: parsed.scene ?? null,
    personContext: parsed.personContext ?? null,
    assistantMessage: String(parsed.assistantMessage ?? "I'll search your photos for that."),
  };
}

app.listen(PORT, () => {
  console.log(`Gemini proxy listening on port ${PORT}`);
});
