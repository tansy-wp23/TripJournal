import { createClient } from "npm:@supabase/supabase-js@2.112.0";

// Server-side home for GEMINI_API_KEY. The key used to ship inside the app
// bundle (`.env` is a Flutter asset, so `unzip app.apk` exposed it verbatim),
// which for a billable credential means anyone holding the APK could spend the
// owner's quota.
//
// Deliberately action-based rather than a passthrough proxy: forwarding an
// arbitrary caller-supplied Gemini body would just move the open door from
// "anyone with the APK" to "any signed-in user", who could then run unrelated
// prompts on the same key. Each action here validates its own inputs, and the
// model and system instructions are pinned server-side where the client cannot
// edit them.

type FetchImplementation = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

type AuthenticatedUser = { id: string };
type Authenticate = (
  authorization: string | null,
) => Promise<AuthenticatedUser | null>;

interface GeminiProxyDependencies {
  fetch?: FetchImplementation;
  authenticate?: Authenticate;
  readEnv?: (name: string) => string | undefined;
  scheduleTimeout?: (callback: () => void, delayMs: number) => unknown;
  cancelTimeout?: (handle: unknown) => void;
  providerTimeoutMs?: number;
  attempts?: number;
  initialRetryDelayMs?: number;
  sleep?: (ms: number) => Promise<void>;
}

const corsHeaders = {
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const defaultGeminiBaseUrl =
  "https://generativelanguage.googleapis.com/v1beta/models";
// Mirrors lib/features/journal/ai/gemini_model.dart. Free-tier quota is granted
// per model *name*, so this is a quota decision as much as a capability one —
// see that file's comment before changing either. Must stay vision-capable for
// food detection.
const defaultTextModel = "gemini-3.6-flash";
// Trip summaries are longer and less latency-sensitive, so they run on the
// cheaper model, exactly as the client did before.
const defaultSummaryModel = "gemini-3.1-flash-lite";
const defaultProviderTimeoutMs = 30_000;
const defaultAttempts = 3;
const defaultInitialRetryDelayMs = 600;

// Ported from the app's old gemini_retry.dart, which existed for a measured
// problem rather than a theoretical one: `503 UNAVAILABLE` ("this model is
// currently experiencing high demand") ran at roughly a coin flip during one
// load spike, turning working features into intermittently broken ones with no
// code change. 429 is retried on the assumption it is a per-minute rate limit,
// which backing off clears; a per-day quota 429 burns the attempts for nothing
// but fails the same way it would have anyway.
//
// Deliberately excludes 400/401/403/404: a bad key, a revoked key or a retired
// model name fail identically every time, so retrying only makes the user wait
// longer for the same answer.
const retryableStatuses = new Set([429, 500, 502, 503, 504]);
// Generous for text, but bounded: an unbounded body is a cost attack.
const maxRequestBytes = 512 * 1024;
// A meal photo after the app's own compression. Anything larger is a sign the
// caller is not the app.
const maxImageBytes = 8 * 1024 * 1024;
const storagePublicPrefix = "/storage/v1/object/public/journal-photos/";

const publicErrors = {
  unauthorized: { status: 401, message: "Authentication is required." },
  invalid_request: { status: 400, message: "The request is invalid." },
  payload_too_large: { status: 413, message: "The request is too large." },
  timeout: {
    status: 504,
    message: "The AI provider timed out. Please try again.",
  },
  provider_error: {
    status: 502,
    message: "The AI provider is unavailable. Please try again.",
  },
  internal_error: {
    status: 500,
    message: "The request could not be completed.",
  },
} as const;

type PublicErrorCode = keyof typeof publicErrors;

class ProxyError extends Error {
  constructor(readonly code: PublicErrorCode) {
    super(code);
  }
}

/// Internal only — signals "worth another attempt", and is converted to a
/// public `provider_error` once the attempts are spent.
class RetryableProviderError extends Error {}

function json(body: unknown, status = 200, headers?: HeadersInit): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...headers },
  });
}

function errorResponse(code: PublicErrorCode): Response {
  const error = publicErrors[code];
  return json({ error: { code, message: error.message } }, error.status);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function nonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function boundedString(value: unknown, maxLength: number): string | null {
  const text = nonEmptyString(value);
  return text != null && text.length <= maxLength ? text : null;
}

function optionalInteger(value: unknown): number | null | undefined {
  if (value === null || value === undefined) return null;
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined;
  return Math.round(value);
}

function requireEnvironment(
  readEnv: (name: string) => string | undefined,
  name: string,
) {
  const value = readEnv(name)?.trim();
  if (!value) throw new ProxyError("internal_error");
  return value;
}

function createSupabaseAuthenticator(
  readEnv: (name: string) => string | undefined,
  fetchImplementation: FetchImplementation,
): Authenticate {
  return async (authorization) => {
    const match = authorization?.match(/^Bearer\s+(.+)$/i);
    const token = match?.[1]?.trim();
    if (!token) return null;

    const supabaseUrl = requireEnvironment(readEnv, "SUPABASE_URL");
    const anonKey = requireEnvironment(readEnv, "SUPABASE_ANON_KEY");
    const client = createClient(supabaseUrl, anonKey, {
      auth: {
        autoRefreshToken: false,
        detectSessionInUrl: false,
        persistSession: false,
      },
      global: { fetch: fetchImplementation },
    });
    const { data: { user }, error } = await client.auth.getUser(token);
    if (error != null || user == null || !nonEmptyString(user.id)) return null;
    return { id: user.id };
  };
}

const systemInstructions = {
  // Copied verbatim from GeminiDailyAdviceService so the tone/safety contract
  // documented on DailyAdviceService still holds — and now lives somewhere the
  // client cannot rewrite it.
  dailyAdvice:
    "You are a supportive, non-clinical daily wellbeing assistant inside a " +
    "travel and health journaling app. Given a day's logged meals, step " +
    "count, and mood, write ONE short, friendly paragraph (2-4 sentences) " +
    "of supportive daily wellbeing advice that considers food, activity, " +
    "and mood together.\n\n" +
    "Rules you MUST follow:\n" +
    "- Never diagnose, and never give medical or clinical instructions.\n" +
    "- Never set an explicit calorie target, and never tell the user to " +
    "restrict or skip meals.\n" +
    "- Never frame exercise as compensation for eating (no \"burn it off\", " +
    "no \"make up for it\").\n" +
    "- Mood suggestions must be gentle and optional-sounding (e.g. \"a " +
    "short walk or reaching out to someone might help\"), never clinical " +
    "or directive.\n" +
    "- Keep it concise, warm, and non-judgemental. Respond with plain " +
    "text only — no bullet points, no headings, no markdown.",
  tripSummary:
    "You write warm, concise travel-journal recaps. Create a 2-4 sentence " +
    "summary based only on the supplied trip and journal entries. Mention " +
    "specific experiences when present, but do not invent facts. Treat mood " +
    "and health details as private reflections: describe them gently, do not " +
    "diagnose or give medical advice. Return plain text only, with no title, " +
    "bullets, or markdown.",
  foodDetection:
    "Identify the single main food item in this photo and estimate its " +
    "calories for the portion shown. Respond with ONLY compact JSON in " +
    'the form {"name": "...", "estimatedCalories": <integer>} — no ' +
    "markdown, no code fences, no explanation.",
} as const;

function dailyAdvicePrompt(body: Record<string, unknown>): string | null {
  const mood = boundedString(body.mood, 40);
  if (mood == null) return null;

  const steps = optionalInteger(body.steps);
  const caloriesEaten = optionalInteger(body.caloriesEaten);
  const caloriesBurned = optionalInteger(body.caloriesBurned);
  if (
    steps === undefined || caloriesEaten === undefined ||
    caloriesBurned === undefined
  ) {
    return null;
  }

  const rawMeals = body.meals;
  if (!Array.isArray(rawMeals) || rawMeals.length > 30) return null;

  const lines = [`Mood: ${mood}`];
  if (steps != null) lines.push(`Steps today: ${steps}`);
  if (caloriesEaten != null) lines.push(`Calories eaten: ${caloriesEaten}`);
  if (caloriesBurned != null) lines.push(`Calories burned: ${caloriesBurned}`);

  if (rawMeals.length === 0) {
    lines.push("Meals logged: none yet today");
  } else {
    lines.push("Meals logged:");
    for (const raw of rawMeals) {
      if (!isRecord(raw)) return null;
      const name = boundedString(raw.name, 200);
      const mealType = boundedString(raw.mealType, 40);
      const calories = optionalInteger(raw.calories);
      if (name == null || mealType == null || calories === undefined) {
        return null;
      }
      const review = boundedString(raw.foodReview, 250);
      const suffix = review == null ? "" : ` — user's note: "${review}"`;
      lines.push(`- ${name} (${mealType}, ~${calories ?? 0} kcal)${suffix}`);
    }
  }
  return lines.join("\n");
}

function tripSummaryPrompt(body: Record<string, unknown>): string | null {
  const trip = body.trip;
  if (!isRecord(trip)) return null;
  const title = boundedString(trip.title, 200);
  const startDate = boundedString(trip.startDate, 40);
  const endDate = boundedString(trip.endDate, 40);
  if (title == null || startDate == null || endDate == null) return null;

  const rawEntries = body.entries;
  // An empty list has nothing to summarise; the client rejects it too.
  if (
    !Array.isArray(rawEntries) || rawEntries.length === 0 ||
    rawEntries.length > 200
  ) {
    return null;
  }

  const lines = [
    `Trip: ${title}`,
    `Dates: ${startDate} to ${endDate}`,
    "Journal entries:",
  ];
  for (const raw of rawEntries) {
    if (!isRecord(raw)) return null;
    const createdAt = boundedString(raw.createdAt, 40);
    const mood = boundedString(raw.mood, 40);
    const entryTitle = boundedString(raw.title, 200);
    if (createdAt == null || mood == null || entryTitle == null) return null;
    // Body may legitimately be empty (a title-only entry).
    const entryBody = typeof raw.body === "string" ? raw.body.slice(0, 5000) : "";

    lines.push(`- ${createdAt} | mood: ${mood}`);
    lines.push(`  Title: ${entryTitle}`);
    lines.push(`  Reflection: ${entryBody}`);
    const placeName = boundedString(raw.placeName, 200);
    if (placeName != null) lines.push(`  Location: ${placeName}`);
  }
  return lines.join("\n");
}

/// Only this project's own public journal-photos objects, and only ones under
/// the caller's own user folder.
///
/// Both halves matter: without the origin check the function is an SSRF gadget
/// that will fetch any URL a caller names, and without the user-folder check
/// one signed-in user could run detection over another user's photos. The
/// `{userId}/{tripId}/{file}` layout is the same one the storage RLS policy
/// (`storage_trip_mutation_allowed`) already relies on.
export function storageObjectUrl(
  value: unknown,
  supabaseUrl: string,
  userId: string,
): string | null {
  const raw = nonEmptyString(value);
  if (raw == null) return null;

  let url: URL;
  let base: URL;
  try {
    url = new URL(raw);
    base = new URL(supabaseUrl);
  } catch {
    return null;
  }

  if (url.protocol !== "https:" && base.protocol === "https:") return null;
  if (url.origin !== base.origin) return null;
  if (url.username !== "" || url.password !== "") return null;
  if (!url.pathname.startsWith(storagePublicPrefix)) return null;

  const objectPath = url.pathname.slice(storagePublicPrefix.length);
  if (objectPath.length === 0) return null;
  // Reject traversal and empty segments before trusting the first segment.
  const segments = objectPath.split("/");
  if (segments.length < 2) return null;
  if (segments.some((s) => s.length === 0 || s === "." || s === "..")) {
    return null;
  }
  if (decodeURIComponent(segments[0]) !== userId) return null;

  return url.toString();
}

function mimeTypeFor(url: string): string {
  const lower = url.toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  return "image/jpeg";
}

function base64FromBytes(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function firstTextPart(payload: unknown): string | null {
  if (!isRecord(payload)) return null;
  const candidates = payload.candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return null;
  const first = candidates[0];
  if (!isRecord(first) || !isRecord(first.content)) return null;
  const parts = first.content.parts;
  if (!Array.isArray(parts) || parts.length === 0) return null;
  const part = parts[0];
  if (!isRecord(part)) return null;
  return nonEmptyString(part.text);
}

// Models sometimes wrap JSON in ```json fences despite being told not to.
function parseDetectedFood(
  text: string,
): { name: string; estimatedCalories: number } | null {
  const cleaned = text.trim().replace(/^```(json)?/i, "").replace(/```$/, "")
    .trim();
  let decoded: unknown;
  try {
    decoded = JSON.parse(cleaned);
  } catch {
    return null;
  }
  if (!isRecord(decoded)) return null;
  const name = nonEmptyString(decoded.name);
  const calories = decoded.estimatedCalories;
  if (name == null || typeof calories !== "number" || !isFinite(calories)) {
    return null;
  }
  return { name, estimatedCalories: Math.round(calories) };
}

export function createGeminiProxyHandler(
  dependencies: GeminiProxyDependencies = {},
) {
  const fetchImplementation = dependencies.fetch ?? globalThis.fetch;
  const readEnv = dependencies.readEnv ?? ((name) => Deno.env.get(name));
  const authenticate = dependencies.authenticate ??
    createSupabaseAuthenticator(readEnv, fetchImplementation);
  const scheduleTimeout = dependencies.scheduleTimeout ??
    ((callback, delayMs) => setTimeout(callback, delayMs));
  const cancelTimeout = dependencies.cancelTimeout ??
    ((handle) => clearTimeout(handle as ReturnType<typeof setTimeout>));
  const providerTimeoutMs = dependencies.providerTimeoutMs ??
    defaultProviderTimeoutMs;
  const attempts = dependencies.attempts ?? defaultAttempts;
  const initialRetryDelayMs = dependencies.initialRetryDelayMs ??
    defaultInitialRetryDelayMs;
  const sleep = dependencies.sleep ??
    ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));

  const geminiBaseUrl =
    (readEnv("GEMINI_BASE_URL")?.trim() || defaultGeminiBaseUrl)
      .replace(/\/+$/, "");
  const textModel = readEnv("GEMINI_TEXT_MODEL")?.trim() || defaultTextModel;
  const summaryModel = readEnv("GEMINI_SUMMARY_MODEL")?.trim() ||
    defaultSummaryModel;

  async function withTimeout<T>(
    run: (signal: AbortSignal) => Promise<T>,
  ): Promise<T> {
    const controller = new AbortController();
    let timedOut = false;
    const handle = scheduleTimeout(() => {
      timedOut = true;
      controller.abort();
    }, providerTimeoutMs);
    try {
      return await run(controller.signal);
    } catch (error) {
      if (
        timedOut ||
        (error instanceof DOMException && error.name === "AbortError")
      ) {
        throw new ProxyError("timeout");
      }
      if (error instanceof ProxyError) throw error;
      throw new ProxyError("provider_error");
    } finally {
      cancelTimeout(handle);
    }
  }

  async function generate(
    model: string,
    requestBody: Record<string, unknown>,
  ): Promise<string> {
    const apiKey = requireEnvironment(readEnv, "GEMINI_API_KEY");
    const url = `${geminiBaseUrl}/${model}:generateContent?key=${
      encodeURIComponent(apiKey)
    }`;

    let delay = initialRetryDelayMs;
    let lastError: unknown;
    for (let attempt = 1; attempt <= attempts; attempt++) {
      const isLast = attempt === attempts;
      try {
        const payload = await withTimeout(async (signal) => {
          const response = await fetchImplementation(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(requestBody),
            signal,
          });
          if (!response.ok) {
            if (!isLast && retryableStatuses.has(response.status)) {
              throw new RetryableProviderError();
            }
            throw new ProxyError("provider_error");
          }
          try {
            return await response.json();
          } catch {
            throw new ProxyError("provider_error");
          }
        });

        const text = firstTextPart(payload);
        if (text == null) throw new ProxyError("provider_error");
        return text;
      } catch (error) {
        // A network drop or timeout is as transient as a 503; give up on it
        // only once the attempts are spent.
        const retryable = error instanceof RetryableProviderError ||
          (error instanceof ProxyError && error.code === "timeout");
        if (isLast || !retryable) {
          if (error instanceof RetryableProviderError) {
            throw new ProxyError("provider_error");
          }
          throw error;
        }
        lastError = error;
      }

      await sleep(delay);
      delay *= 2;
    }

    // Unreachable: the loop either returns or throws on its final attempt.
    throw (lastError instanceof ProxyError
      ? lastError
      : new ProxyError("provider_error"));
  }

  function textRequest(systemInstruction: string, prompt: string) {
    return {
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents: [{ parts: [{ text: prompt }] }],
    };
  }

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return json(
        {
          error: {
            code: "invalid_request",
            message: publicErrors.invalid_request.message,
          },
        },
        405,
        { Allow: "POST, OPTIONS" },
      );
    }

    try {
      const user = await authenticate(request.headers.get("Authorization"));
      if (user == null || nonEmptyString(user.id) == null) {
        return errorResponse("unauthorized");
      }

      const rawBody = await request.text();
      if (rawBody.length > maxRequestBytes) {
        return errorResponse("payload_too_large");
      }

      let body: unknown;
      try {
        body = JSON.parse(rawBody);
      } catch {
        return errorResponse("invalid_request");
      }
      if (!isRecord(body)) return errorResponse("invalid_request");

      const action = body.action;

      if (action === "daily_advice") {
        const prompt = dailyAdvicePrompt(body);
        if (prompt == null) return errorResponse("invalid_request");
        const advice = await generate(
          textModel,
          textRequest(systemInstructions.dailyAdvice, prompt),
        );
        return json({ advice: advice.trim() });
      }

      if (action === "trip_summary") {
        const prompt = tripSummaryPrompt(body);
        if (prompt == null) return errorResponse("invalid_request");
        const summary = await generate(
          summaryModel,
          textRequest(systemInstructions.tripSummary, prompt),
        );
        return json({ summary: summary.trim() });
      }

      if (action === "food_detection") {
        const supabaseUrl = requireEnvironment(readEnv, "SUPABASE_URL");
        const imageUrl = storageObjectUrl(body.imageUrl, supabaseUrl, user.id);
        if (imageUrl == null) return errorResponse("invalid_request");

        const bytes = await withTimeout(async (signal) => {
          const response = await fetchImplementation(imageUrl, {
            method: "GET",
            signal,
          });
          if (!response.ok) throw new ProxyError("provider_error");
          const buffer = await response.arrayBuffer();
          if (buffer.byteLength > maxImageBytes) {
            throw new ProxyError("payload_too_large");
          }
          return new Uint8Array(buffer);
        });

        const text = await generate(textModel, {
          contents: [
            {
              parts: [
                { text: systemInstructions.foodDetection },
                {
                  inline_data: {
                    mime_type: mimeTypeFor(imageUrl),
                    data: base64FromBytes(bytes),
                  },
                },
              ],
            },
          ],
        });

        // A null food is a legitimate outcome, not an error: the client falls
        // back to manual entry, exactly as it did when it called Gemini itself.
        return json({ food: parseDetectedFood(text) });
      }

      if (action === "health") {
        // Deliberately ListModels, not generateContent: the admin screen asks
        // "is the key valid and the API reachable", and this app has been
        // burned twice by free-tier quota exhaustion, so a health check must
        // not spend generation quota. Never reports *why* it failed — that
        // detail would describe the server's own credentials.
        const apiKey = readEnv("GEMINI_API_KEY")?.trim();
        if (!apiKey) return json({ ok: false, configured: false });
        try {
          const ok = await withTimeout(async (signal) => {
            const response = await fetchImplementation(
              `${geminiBaseUrl}?key=${encodeURIComponent(apiKey)}`,
              { method: "GET", signal },
            );
            return response.ok;
          });
          return json({ ok, configured: true });
        } catch {
          return json({ ok: false, configured: true });
        }
      }

      return errorResponse("invalid_request");
    } catch (error) {
      if (error instanceof ProxyError) return errorResponse(error.code);
      return errorResponse("internal_error");
    }
  };
}

export const handler = createGeminiProxyHandler();

if (import.meta.main) {
  Deno.serve(handler);
}
