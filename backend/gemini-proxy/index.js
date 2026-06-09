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

const SYSTEM_PROMPT = `Parse a spoken photo search into JSON only with keys: searchQuery, brand, object, product, scene, personContext, assistantMessage.
Use null for unused fields. No color terms. searchQuery is one combined metadata string. assistantMessage is one short friendly sentence.`;

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
    if (!GEMINI_API) {
      res.status(500).json({ error: "GEMINI_API secret is not configured on the server." });
      return;
    }

    const transcript = typeof req.body?.transcript === "string"
      ? req.body.transcript.trim()
      : "";

    if (!transcript) {
      res.status(400).json({ error: "Missing or empty transcript." });
      return;
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
          parts: [{ text: SYSTEM_PROMPT }],
        },
        contents: [
          {
            role: "user",
            parts: [{ text: transcript }],
          },
        ],
        generationConfig: {
          temperature: 0.2,
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
      res.status(geminiResponse.status).json({ error: message });
      return;
    }

    const text = extractGeminiText(geminiData);
    if (!text) {
      res.status(502).json({ error: "Gemini returned an empty response." });
      return;
    }

    const parsed = parseAssistantJSON(text);
    res.json(parsed);
  } catch (error) {
    console.error("Gemini proxy error:", error);
    res.status(500).json({
      error: error instanceof Error ? error.message : "Internal server error",
    });
  }
});

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
