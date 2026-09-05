import { createClient } from "npm:@supabase/supabase-js@2.112.0";

type FetchImplementation = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

type AuthenticatedUser = { id: string };
type Authenticate = (
  authorization: string | null,
) => Promise<AuthenticatedUser | null>;
type RateLimitDecision = {
  allowed: boolean;
  remaining: number;
  retryAfterSeconds: number;
};
type ConsumeRateLimit = (
  authorization: string,
) => Promise<RateLimitDecision>;

interface CacheEntry {
  expiresAt: number;
  value: unknown;
}

interface PlacesProxyDependencies {
  fetch?: FetchImplementation;
  authenticate?: Authenticate;
  consumeRateLimit?: ConsumeRateLimit;
  readEnv?: (name: string) => string | undefined;
  scheduleTimeout?: (callback: () => void, delayMs: number) => unknown;
  cancelTimeout?: (handle: unknown) => void;
  providerTimeoutMs?: number;
  cache?: Map<string, CacheEntry>;
  now?: () => number;
  cacheTtlMs?: number;
  cacheMaxEntries?: number;
  minRequestSpacingMs?: number;
  sleep?: (ms: number) => Promise<void>;
}

const corsHeaders = {
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const defaultNominatimBaseUrl = "https://nominatim.openstreetmap.org";
// Nominatim's usage policy requires a stable User-Agent identifying the app with a
// contact route - a generic HTTP-client default gets silently blocked.
const defaultNominatimUserAgent =
  "TripJournal/1.0 (+https://github.com/tripjournal/tripjournal)";
const defaultProviderTimeoutMs = 8_000;
const defaultCacheTtlMs = 24 * 60 * 60 * 1000;
const defaultCacheMaxEntries = 500;
// Nominatim's usage policy caps the whole application at 1 request/second.
const defaultMinRequestSpacingMs = 1_000;

const publicErrors = {
  unauthorized: {
    status: 401,
    message: "Authentication is required.",
  },
  invalid_request: {
    status: 400,
    message: "The request is invalid.",
  },
  rate_limited: {
    status: 429,
    message: "Too many requests. Please try again shortly.",
  },
  rate_limit_unavailable: {
    status: 503,
    message: "Location search is temporarily unavailable. Please try again.",
  },
  timeout: {
    status: 504,
    message: "The location provider timed out. Please try again.",
  },
  provider_error: {
    status: 502,
    message: "The location provider is unavailable. Please try again.",
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

function json(body: unknown, status = 200, headers?: HeadersInit): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...headers,
    },
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

function validCoordinate(value: unknown, minimum: number, maximum: number) {
  return typeof value === "number" && Number.isFinite(value) &&
    value >= minimum && value <= maximum;
}

function validProviderCoordinate(latitude: unknown, longitude: unknown) {
  return validCoordinate(latitude, -90, 90) &&
    validCoordinate(longitude, -180, 180);
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
    const {
      data: { user },
      error,
    } = await client.auth.getUser(token);
    if (error != null || user == null || !nonEmptyString(user.id)) return null;
    return { id: user.id };
  };
}

function createSupabaseRateLimiter(
  readEnv: (name: string) => string | undefined,
  fetchImplementation: FetchImplementation,
): ConsumeRateLimit {
  return async (authorization) => {
    try {
      const supabaseUrl = requireEnvironment(readEnv, "SUPABASE_URL");
      const anonKey = requireEnvironment(readEnv, "SUPABASE_ANON_KEY");
      const response = await fetchImplementation(
        `${supabaseUrl}/rest/v1/rpc/consume_places_rate_limit`,
        {
          method: "POST",
          headers: {
            Authorization: authorization,
            apikey: anonKey,
            "Content-Type": "application/json",
          },
          body: "{}",
        },
      );
      if (!response.ok) throw new ProxyError("rate_limit_unavailable");

      const raw = await response.json();
      const value = Array.isArray(raw) ? raw[0] : raw;
      if (
        !isRecord(value) || typeof value.allowed !== "boolean" ||
        typeof value.remaining !== "number" ||
        typeof value.retry_after_seconds !== "number"
      ) {
        throw new ProxyError("rate_limit_unavailable");
      }
      return {
        allowed: value.allowed,
        remaining: value.remaining,
        retryAfterSeconds: value.retry_after_seconds,
      };
    } catch (error) {
      if (error instanceof ProxyError) throw error;
      throw new ProxyError("rate_limit_unavailable");
    }
  };
}

async function fetchProviderJson(
  fetchImplementation: FetchImplementation,
  input: RequestInfo | URL,
  init: RequestInit,
  timeoutMs: number,
  scheduleTimeout: (callback: () => void, delayMs: number) => unknown,
  cancelTimeout: (handle: unknown) => void,
): Promise<unknown> {
  const controller = new AbortController();
  let timedOut = false;
  const timeoutHandle = scheduleTimeout(() => {
    timedOut = true;
    controller.abort();
  }, timeoutMs);

  try {
    const response = await fetchImplementation(input, {
      ...init,
      signal: controller.signal,
    });
    if (!response.ok) throw new ProxyError("provider_error");
    try {
      return await response.json();
    } catch {
      throw new ProxyError("provider_error");
    }
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
    cancelTimeout(timeoutHandle);
  }
}

// Nominatim place ids aren't stable integers the way Google's are - the stable
// identifier is the (osm_type, osm_id) pair. Encode it as a single string
// ("N123456") so it round-trips through the existing string-typed `placeId`
// contract, and is directly usable as `/lookup`'s `osm_ids` parameter value.
function osmPlaceId(value: Record<string, unknown>): string | null {
  const type = typeof value.osm_type === "string"
    ? value.osm_type[0]?.toUpperCase()
    : null;
  const id = typeof value.osm_id === "number" ? String(value.osm_id) : null;
  return type != null && "NWR".includes(type) && id != null
    ? `${type}${id}`
    : null;
}

const validOsmPlaceId = /^[NWR]\d{1,19}$/;

const placeNamePreference = [
  "tourism",
  "attraction",
  "building",
  "amenity",
  "shop",
  "road",
  "neighbourhood",
  "suburb",
  "city_district",
  "village",
  "town",
  "city",
  "county",
  "state",
  "country",
];

function placeNameFromNominatim(value: Record<string, unknown>): string | null {
  const name = nonEmptyString(value.name);
  if (name != null) return name;
  if (isRecord(value.address)) {
    for (const key of placeNamePreference) {
      const candidate = nonEmptyString(value.address[key]);
      if (candidate != null) return candidate;
    }
  }
  return nonEmptyString(value.display_name);
}

function parseSuggestion(value: unknown) {
  if (!isRecord(value)) return null;
  const placeId = osmPlaceId(value);
  const formattedAddress = nonEmptyString(value.display_name);
  if (placeId == null || formattedAddress == null) return null;

  return {
    placeId,
    primaryText: placeNameFromNominatim(value) ?? formattedAddress,
    secondaryText: formattedAddress,
  };
}

// `/lookup` returns an array (it accepts multiple comma-separated osm_ids); we
// always request exactly one, so the first element is the result.
function parseResolvedLocation(value: unknown) {
  if (!Array.isArray(value) || value.length === 0) return null;
  const first = value[0];
  if (!isRecord(first)) return null;

  // Nominatim returns lat/lon as strings, not numbers.
  const latitude = Number(first.lat);
  const longitude = Number(first.lon);
  const placeId = osmPlaceId(first);
  const formattedAddress = nonEmptyString(first.display_name);
  const placeName = placeNameFromNominatim(first);
  if (
    !validProviderCoordinate(latitude, longitude) || placeId == null ||
    formattedAddress == null || placeName == null
  ) {
    return null;
  }

  return { latitude, longitude, placeName, formattedAddress, placeId };
}

// `/reverse` returns a single object, with an `error` string field on failure
// (never a non-2xx status for "no result at these coordinates").
function parseReverseLocation(
  value: unknown,
  latitude: number,
  longitude: number,
) {
  if (!isRecord(value) || typeof value.error === "string") return null;

  const placeId = osmPlaceId(value);
  const formattedAddress = nonEmptyString(value.display_name);
  const placeName = placeNameFromNominatim(value);
  if (placeId == null || formattedAddress == null || placeName == null) {
    return null;
  }

  return { latitude, longitude, placeName, formattedAddress, placeId };
}

export function createPlacesProxyHandler(
  dependencies: PlacesProxyDependencies = {},
) {
  const fetchImplementation = dependencies.fetch ?? globalThis.fetch;
  const readEnv = dependencies.readEnv ?? ((name) => Deno.env.get(name));
  const authenticate = dependencies.authenticate ??
    createSupabaseAuthenticator(readEnv, fetchImplementation);
  const consumeRateLimit = dependencies.consumeRateLimit ??
    createSupabaseRateLimiter(readEnv, fetchImplementation);
  const scheduleTimeout = dependencies.scheduleTimeout ??
    ((callback, delayMs) => setTimeout(callback, delayMs));
  const cancelTimeout = dependencies.cancelTimeout ??
    ((handle) => clearTimeout(handle as ReturnType<typeof setTimeout>));
  const providerTimeoutMs = dependencies.providerTimeoutMs ??
    defaultProviderTimeoutMs;

  // Configurable so self-hosting Nominatim (required past low volume, per its
  // usage policy) is a secret change, not a code change.
  const nominatimBaseUrl =
    (readEnv("NOMINATIM_BASE_URL")?.trim() || defaultNominatimBaseUrl)
      .replace(/\/+$/, "");
  const nominatimUserAgent = readEnv("NOMINATIM_USER_AGENT")?.trim() ||
    defaultNominatimUserAgent;

  // ponytail: per-instance in-memory cache and throttle, no cross-instance
  // coordination. Deno Deploy can run many instances, so both are best-effort
  // against the *policy* ceilings, not a hard guarantee. Move to a shared
  // Postgres-backed cache/limiter (the pattern consume_places_rate_limit
  // already uses per-user), or self-host Nominatim via NOMINATIM_BASE_URL,
  // before this sees real production traffic.
  const cache = dependencies.cache ?? new Map<string, CacheEntry>();
  const now = dependencies.now ?? (() => Date.now());
  const cacheTtlMs = dependencies.cacheTtlMs ?? defaultCacheTtlMs;
  const cacheMaxEntries = dependencies.cacheMaxEntries ?? defaultCacheMaxEntries;
  const minRequestSpacingMs = dependencies.minRequestSpacingMs ??
    defaultMinRequestSpacingMs;
  const sleep = dependencies.sleep ??
    ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));
  let nextAvailableAt = 0;

  async function throttle() {
    const currentTime = now();
    const wait = Math.max(0, nextAvailableAt - currentTime);
    nextAvailableAt = Math.max(currentTime, nextAvailableAt) +
      minRequestSpacingMs;
    if (wait > 0) await sleep(wait);
  }

  async function nominatimJson(url: URL): Promise<unknown> {
    const key = url.toString();
    const cached = cache.get(key);
    const currentTime = now();
    if (cached != null && cached.expiresAt > currentTime) return cached.value;

    await throttle();
    const value = await fetchProviderJson(
      fetchImplementation,
      url,
      { method: "GET", headers: { "User-Agent": nominatimUserAgent } },
      providerTimeoutMs,
      scheduleTimeout,
      cancelTimeout,
    );

    cache.set(key, { expiresAt: currentTime + cacheTtlMs, value });
    if (cache.size > cacheMaxEntries) {
      const oldestKey = cache.keys().next().value;
      if (oldestKey !== undefined) cache.delete(oldestKey);
    }
    return value;
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

      let body: unknown;
      try {
        body = await request.json();
      } catch {
        return errorResponse("invalid_request");
      }
      if (!isRecord(body)) return errorResponse("invalid_request");

      const action = body.action;
      if (action !== "search" && action !== "resolve" && action !== "reverse") {
        return errorResponse("invalid_request");
      }

      let validated:
        | { action: "search"; query: string }
        | { action: "resolve"; placeId: string }
        | { action: "reverse"; latitude: number; longitude: number };

      if (action === "search") {
        if (typeof body.query !== "string") {
          return errorResponse("invalid_request");
        }
        const query = body.query.trim();
        if (query.length < 2 || query.length > 120) {
          return errorResponse("invalid_request");
        }
        validated = { action, query };
      } else if (action === "resolve") {
        const placeId = nonEmptyString(body.placeId);
        if (placeId == null || !validOsmPlaceId.test(placeId)) {
          return errorResponse("invalid_request");
        }
        validated = { action, placeId };
      } else {
        if (
          !validCoordinate(body.latitude, -90, 90) ||
          !validCoordinate(body.longitude, -180, 180)
        ) {
          return errorResponse("invalid_request");
        }
        validated = {
          action,
          latitude: body.latitude as number,
          longitude: body.longitude as number,
        };
      }

      const authorization = request.headers.get("Authorization") ?? "";
      let limitDecision: RateLimitDecision;
      try {
        limitDecision = await consumeRateLimit(authorization);
      } catch {
        throw new ProxyError("rate_limit_unavailable");
      }
      if (!limitDecision.allowed) return errorResponse("rate_limited");

      if (validated.action === "search") {
        const url = new URL(`${nominatimBaseUrl}/search`);
        url.searchParams.set("q", validated.query);
        url.searchParams.set("format", "jsonv2");
        url.searchParams.set("limit", "5");
        url.searchParams.set("addressdetails", "1");
        const result = await nominatimJson(url);
        if (!Array.isArray(result)) throw new ProxyError("provider_error");
        const suggestions = [];
        for (const place of result) {
          const suggestion = parseSuggestion(place);
          if (suggestion == null) throw new ProxyError("provider_error");
          suggestions.push(suggestion);
          if (suggestions.length === 5) break;
        }
        return json({ suggestions });
      }

      if (validated.action === "resolve") {
        const url = new URL(`${nominatimBaseUrl}/lookup`);
        url.searchParams.set("osm_ids", validated.placeId);
        url.searchParams.set("format", "jsonv2");
        url.searchParams.set("addressdetails", "1");
        const result = await nominatimJson(url);
        const location = parseResolvedLocation(result);
        if (location == null) throw new ProxyError("provider_error");
        return json({ location });
      }

      const url = new URL(`${nominatimBaseUrl}/reverse`);
      url.searchParams.set("format", "jsonv2");
      url.searchParams.set("lat", String(validated.latitude));
      url.searchParams.set("lon", String(validated.longitude));
      url.searchParams.set("addressdetails", "1");
      const result = await nominatimJson(url);
      const location = parseReverseLocation(
        result,
        validated.latitude,
        validated.longitude,
      );
      if (location == null) throw new ProxyError("provider_error");
      return json({ location });
    } catch (error) {
      if (error instanceof ProxyError) return errorResponse(error.code);
      return errorResponse("internal_error");
    }
  };
}

export const handler = createPlacesProxyHandler();

if (import.meta.main) {
  Deno.serve(handler);
}
