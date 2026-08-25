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

interface PlacesProxyDependencies {
  fetch?: FetchImplementation;
  authenticate?: Authenticate;
  consumeRateLimit?: ConsumeRateLimit;
  readEnv?: (name: string) => string | undefined;
  scheduleTimeout?: (callback: () => void, delayMs: number) => unknown;
  cancelTimeout?: (handle: unknown) => void;
  providerTimeoutMs?: number;
}

const corsHeaders = {
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const googlePlacesBaseUrl = "https://places.googleapis.com/v1";
const googleGeocodingUrl = "https://maps.googleapis.com/maps/api/geocode/json";
const defaultProviderTimeoutMs = 8_000;

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

function parseSuggestion(value: unknown) {
  if (!isRecord(value)) return null;
  const displayName = isRecord(value.displayName)
    ? nonEmptyString(value.displayName.text)
    : null;
  const placeId = nonEmptyString(value.id);
  if (placeId == null || displayName == null) return null;

  return {
    placeId,
    primaryText: displayName,
    secondaryText: typeof value.formattedAddress === "string"
      ? value.formattedAddress.trim()
      : "",
  };
}

function parseResolvedLocation(value: unknown) {
  if (!isRecord(value) || !isRecord(value.location)) return null;
  const latitude = value.location.latitude;
  const longitude = value.location.longitude;
  const placeName = isRecord(value.displayName)
    ? nonEmptyString(value.displayName.text)
    : null;
  const formattedAddress = nonEmptyString(value.formattedAddress);
  const placeId = nonEmptyString(value.id);
  if (
    !validProviderCoordinate(latitude, longitude) || placeName == null ||
    formattedAddress == null || placeId == null
  ) {
    return null;
  }

  return {
    latitude: latitude as number,
    longitude: longitude as number,
    placeName,
    formattedAddress,
    placeId,
  };
}

function parseReverseLocation(
  value: unknown,
  latitude: number,
  longitude: number,
) {
  if (
    !isRecord(value) || value.status !== "OK" || !Array.isArray(value.results)
  ) {
    return null;
  }
  const first = value.results[0];
  if (!isRecord(first)) return null;

  const formattedAddress = nonEmptyString(first.formatted_address);
  const placeId = nonEmptyString(first.place_id);
  const components = Array.isArray(first.address_components)
    ? first.address_components
    : [];
  const preferredTypes = [
    "point_of_interest",
    "establishment",
    "premise",
    "route",
    "neighborhood",
    "sublocality",
    "locality",
    "postal_town",
    "administrative_area_level_2",
    "administrative_area_level_1",
    "country",
  ];
  let placeName: string | null = null;
  for (const type of preferredTypes) {
    const component = components.find((candidate) =>
      isRecord(candidate) && Array.isArray(candidate.types) &&
      candidate.types.includes(type)
    );
    if (isRecord(component)) {
      placeName = nonEmptyString(component.long_name);
      if (placeName != null) break;
    }
  }
  placeName ??= formattedAddress;
  if (formattedAddress == null || placeId == null || placeName == null) {
    return null;
  }

  return {
    latitude,
    longitude,
    placeName,
    formattedAddress,
    placeId,
  };
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

  async function googleJson(
    input: RequestInfo | URL,
    init: RequestInit,
  ) {
    return await fetchProviderJson(
      fetchImplementation,
      input,
      init,
      providerTimeoutMs,
      scheduleTimeout,
      cancelTimeout,
    );
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
        if (placeId == null || placeId.length > 300) {
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

      const serverKey = requireEnvironment(
        readEnv,
        "GOOGLE_PLACES_SERVER_KEY",
      );

      if (validated.action === "search") {
        const result = await googleJson(
          `${googlePlacesBaseUrl}/places:searchText`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-Goog-Api-Key": serverKey,
              "X-Goog-FieldMask":
                "places.id,places.displayName,places.formattedAddress",
            },
            body: JSON.stringify({
              textQuery: validated.query,
              pageSize: 5,
            }),
          },
        );
        if (!isRecord(result)) {
          throw new ProxyError("provider_error");
        }
        const places = result.places;
        if (places !== undefined && !Array.isArray(places)) {
          throw new ProxyError("provider_error");
        }
        const suggestions = [];
        for (const place of places ?? []) {
          const suggestion = parseSuggestion(place);
          if (suggestion == null) throw new ProxyError("provider_error");
          suggestions.push(suggestion);
          if (suggestions.length === 5) break;
        }
        return json({ suggestions });
      }

      if (validated.action === "resolve") {
        const result = await googleJson(
          `${googlePlacesBaseUrl}/places/${
            encodeURIComponent(validated.placeId)
          }`,
          {
            method: "GET",
            headers: {
              "X-Goog-Api-Key": serverKey,
              "X-Goog-FieldMask": "id,displayName,formattedAddress,location",
            },
          },
        );
        const location = parseResolvedLocation(result);
        if (location == null) throw new ProxyError("provider_error");
        return json({ location });
      }

      const url = new URL(googleGeocodingUrl);
      url.searchParams.set(
        "latlng",
        `${validated.latitude},${validated.longitude}`,
      );
      url.searchParams.set("key", serverKey);
      const result = await googleJson(url, { method: "GET" });
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
