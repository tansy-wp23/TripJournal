import { createPlacesProxyHandler } from "./index.ts";

type FetchImplementation = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

const endpoint = "https://edge.example.test/places-proxy";
const providerKey = "server-key-that-must-stay-private";

const expectedMessages = {
  unauthorized: "Authentication is required.",
  invalid_request: "The request is invalid.",
  rate_limited: "Too many requests. Please try again shortly.",
  timeout: "The location provider timed out. Please try again.",
  provider_error: "The location provider is unavailable. Please try again.",
  internal_error: "The request could not be completed.",
} as const;

function assert(
  condition: unknown,
  message = "Assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown, message?: string) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(
      message ?? `Expected ${expectedJson}, received ${actualJson}`,
    );
  }
}

function assertCors(response: Response) {
  assertEquals(response.headers.get("cache-control"), "no-store");
  assertEquals(response.headers.get("access-control-allow-origin"), "*");
  assertEquals(
    response.headers.get("access-control-allow-headers"),
    "authorization, x-client-info, apikey, content-type",
  );
  assertEquals(
    response.headers.get("access-control-allow-methods"),
    "POST, OPTIONS",
  );
}

async function assertError(
  response: Response,
  status: number,
  code: keyof typeof expectedMessages,
) {
  assertEquals(response.status, status);
  assertCors(response);
  assertEquals(response.headers.get("content-type"), "application/json");
  const text = await response.text();
  assertEquals(JSON.parse(text), {
    error: { code, message: expectedMessages[code] },
  });
  return text;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function post(
  body: unknown,
  options: { token?: string; raw?: boolean } = {},
) {
  const token = options.token ?? "user-one";
  return new Request(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: options.raw ? String(body) : JSON.stringify(body),
  });
}

function handlerFor(
  options: {
    fetch?: FetchImplementation;
    authenticate?: (
      authorization: string | null,
    ) => Promise<{ id: string } | null>;
    env?: Record<string, string | undefined>;
    now?: () => number;
    scheduleTimeout?: (callback: () => void, delayMs: number) => number;
    cancelTimeout?: (handle: unknown) => void;
    rateLimit?: { maxRequests: number; windowMs: number };
    providerTimeoutMs?: number;
  } = {},
) {
  const env: Record<string, string | undefined> = {
    GOOGLE_PLACES_SERVER_KEY: providerKey,
    SUPABASE_URL: "https://tripjournal.supabase.co",
    SUPABASE_ANON_KEY: "public-anon-key",
    ...options.env,
  };

  return createPlacesProxyHandler({
    fetch: options.fetch ??
      (() => Promise.resolve(jsonResponse({ places: [] }))),
    authenticate: options.authenticate ?? ((authorization: string | null) => {
      if (!authorization?.startsWith("Bearer ")) return Promise.resolve(null);
      return Promise.resolve({ id: authorization.slice("Bearer ".length) });
    }),
    readEnv: (name: string) => env[name],
    now: options.now ?? (() => 1_000),
    scheduleTimeout: options.scheduleTimeout,
    cancelTimeout: options.cancelTimeout,
    rateLimit: options.rateLimit,
    providerTimeoutMs: options.providerTimeoutMs,
  });
}

Deno.test("OPTIONS reaches the handler and returns the complete CORS preflight contract", async () => {
  const response = await handlerFor({
    authenticate: () => {
      throw new Error("preflight must not authenticate");
    },
  })(new Request(endpoint, { method: "OPTIONS" }));

  assertEquals(response.status, 204);
  assertCors(response);
  assertEquals(await response.text(), "");
});

Deno.test("an unauthenticated request returns a generic 401 with CORS", async () => {
  const response = await handlerFor({
    authenticate: () => Promise.resolve(null),
    fetch: () => {
      throw new Error("unauthenticated requests must not call Google");
    },
  })(post({ action: "search", query: "Kuala Lumpur" }));

  await assertError(response, 401, "unauthorized");
});

Deno.test("the production authenticator verifies bearer tokens through Supabase Auth", async () => {
  const authUrl = "https://tripjournal.supabase.co/auth/v1/user";
  const fetchImpl: FetchImplementation = (input, init) => {
    const url = String(input);
    if (url === authUrl) {
      const headers = new Headers(init?.headers);
      if (
        headers.get("authorization") !== "Bearer verified-token" ||
        headers.get("apikey") !== "public-anon-key"
      ) {
        return Promise.resolve(
          jsonResponse({ message: "bad auth request" }, 401),
        );
      }
      return Promise.resolve(jsonResponse({ id: "verified-user" }));
    }
    if (url === "https://places.googleapis.com/v1/places:searchText") {
      return Promise.resolve(jsonResponse({ places: [] }));
    }
    return Promise.resolve(
      jsonResponse({ message: "unexpected endpoint" }, 404),
    );
  };
  const env: Record<string, string> = {
    GOOGLE_PLACES_SERVER_KEY: providerKey,
    SUPABASE_URL: "https://tripjournal.supabase.co",
    SUPABASE_ANON_KEY: "public-anon-key",
  };
  const handler = createPlacesProxyHandler({
    fetch: fetchImpl,
    readEnv: (name: string) => env[name],
    now: () => 1_000,
  });

  const response = await handler(
    post({ action: "search", query: "Kuala Lumpur" }, {
      token: "verified-token",
    }),
  );

  assertEquals(response.status, 200);
  assertCors(response);
  assertEquals(await response.json(), { suggestions: [] });
});

Deno.test("non-POST, malformed JSON, and unsupported actions return invalid_request", async () => {
  const handler = handlerFor();
  const responses = [
    await handler(new Request(endpoint, { method: "GET" })),
    await handler(post("{", { raw: true })),
    await handler(post({ action: "nearby" })),
    await handler(post({ query: "missing action" })),
  ];

  assertEquals(responses[0].headers.get("allow"), "POST, OPTIONS");
  for (const response of responses) {
    await assertError(
      response,
      response === responses[0] ? 405 : 400,
      "invalid_request",
    );
  }
});

Deno.test("search trims the query and accepts inclusive lengths 2 through 120", async () => {
  const trimmedFetch: FetchImplementation = (input, init) => {
    if (
      String(input) !== "https://places.googleapis.com/v1/places:searchText"
    ) {
      return Promise.resolve(
        jsonResponse({ message: "unexpected endpoint" }, 404),
      );
    }
    const body = JSON.parse(String(init?.body));
    const headers = new Headers(init?.headers);
    return Promise.resolve(
      body.textQuery === "KL" &&
        body.maxResultCount === 5 &&
        headers.get("x-goog-api-key") === providerKey &&
        headers.get("x-goog-fieldmask") ===
          "places.id,places.displayName,places.formattedAddress"
        ? jsonResponse({ places: [] })
        : jsonResponse({ message: "invalid Text Search request" }, 400),
    );
  };
  const trimmedResponse = await handlerFor({ fetch: trimmedFetch })(
    post({ action: "search", query: "  KL  " }),
  );
  const lowerBoundary = await handlerFor()(
    post({ action: "search", query: "ab" }),
  );
  const upperBoundary = await handlerFor()(
    post({ action: "search", query: "x".repeat(120) }),
  );

  for (const response of [trimmedResponse, lowerBoundary, upperBoundary]) {
    assertEquals(response.status, 200);
    assertCors(response);
    assertEquals(await response.json(), { suggestions: [] });
  }
});

Deno.test("search rejects non-string queries and trimmed lengths outside 2 through 120", async () => {
  const handler = handlerFor({
    fetch: () => {
      throw new Error("invalid search must not call Google");
    },
  });
  const responses = [
    await handler(post({ action: "search", query: 42 })),
    await handler(post({ action: "search", query: " x " })),
    await handler(post({ action: "search", query: "x".repeat(121) })),
  ];

  for (const response of responses) {
    await assertError(response, 400, "invalid_request");
  }
});

Deno.test("resolve validates and trims placeId before returning the location contract", async () => {
  const fetchImpl: FetchImplementation = (input, init) => {
    const headers = new Headers(init?.headers);
    if (
      String(input) !== "https://places.googleapis.com/v1/places/place-123" ||
      init?.method !== "GET" ||
      headers.get("x-goog-api-key") !== providerKey ||
      headers.get("x-goog-fieldmask") !==
        "id,displayName,formattedAddress,location"
    ) {
      return Promise.resolve(
        jsonResponse({ message: "placeId was not trimmed" }, 404),
      );
    }
    return Promise.resolve(jsonResponse({
      id: "place-123",
      displayName: { text: "Central Market" },
      formattedAddress: "Jalan Hang Kasturi, Kuala Lumpur",
      location: { latitude: 3.1457, longitude: 101.6955 },
    }));
  };
  const valid = await handlerFor({ fetch: fetchImpl })(
    post({ action: "resolve", placeId: "  place-123  " }),
  );
  const invalidHandler = handlerFor({
    fetch: () => {
      throw new Error("invalid place IDs must not call Google");
    },
  });
  const blank = await invalidHandler(
    post({ action: "resolve", placeId: "   " }),
  );
  const nonString = await invalidHandler(
    post({ action: "resolve", placeId: 123 }),
  );
  const tooLong = await invalidHandler(
    post({ action: "resolve", placeId: "p".repeat(301) }),
  );

  assertEquals(valid.status, 200);
  assertCors(valid);
  assertEquals(await valid.json(), {
    location: {
      latitude: 3.1457,
      longitude: 101.6955,
      placeName: "Central Market",
      formattedAddress: "Jalan Hang Kasturi, Kuala Lumpur",
      placeId: "place-123",
    },
  });
  await assertError(blank, 400, "invalid_request");
  await assertError(nonString, 400, "invalid_request");
  await assertError(tooLong, 400, "invalid_request");
});

Deno.test("reverse rejects non-finite or out-of-range coordinates and accepts range boundaries", async () => {
  const invalidHandler = handlerFor({
    fetch: () => {
      throw new Error("invalid coordinates must not call Google");
    },
  });
  const invalidRequests = [
    post({ action: "reverse", latitude: "3.1", longitude: 101.7 }),
    post({ action: "reverse", latitude: 91, longitude: 0 }),
    post({ action: "reverse", latitude: -91, longitude: 0 }),
    post({ action: "reverse", latitude: 0, longitude: 181 }),
    post({ action: "reverse", latitude: 0, longitude: -181 }),
    post('{"action":"reverse","latitude":1e400,"longitude":0}', {
      raw: true,
    }),
  ];

  for (const request of invalidRequests) {
    await assertError(await invalidHandler(request), 400, "invalid_request");
  }

  const valid = await handlerFor({
    fetch: (input, init) => {
      const url = new URL(String(input));
      if (
        url.origin !== "https://maps.googleapis.com" ||
        url.pathname !== "/maps/api/geocode/json" ||
        url.searchParams.get("latlng") !== "-90,180" ||
        url.searchParams.get("key") !== providerKey ||
        init?.method !== "GET"
      ) {
        return Promise.resolve(
          jsonResponse({ status: "INVALID_REQUEST" }, 400),
        );
      }
      return Promise.resolve(jsonResponse({
        status: "OK",
        results: [{
          place_id: "south-pole-dateline",
          formatted_address: "South Pole",
          address_components: [
            { long_name: "90", types: ["street_number"] },
            { long_name: "South Pole", types: ["locality", "political"] },
          ],
        }],
      }));
    },
  })(post({ action: "reverse", latitude: -90, longitude: 180 }));

  assertEquals(valid.status, 200);
  assertCors(valid);
  assertEquals(await valid.json(), {
    location: {
      latitude: -90,
      longitude: 180,
      placeName: "South Pole",
      formattedAddress: "South Pole",
      placeId: "south-pole-dateline",
    },
  });
});

Deno.test("search returns at most five normalized suggestions", async () => {
  const response = await handlerFor({
    fetch: () =>
      Promise.resolve(jsonResponse({
        places: [
          { id: "p1", displayName: { text: "One" }, formattedAddress: "A1" },
          { id: "p2", displayName: { text: "Two" }, formattedAddress: "A2" },
          { id: "p3", displayName: { text: "Three" }, formattedAddress: "A3" },
          { id: "p4", displayName: { text: "Four" }, formattedAddress: "A4" },
          { id: "p5", displayName: { text: "Five" }, formattedAddress: "A5" },
          { id: "p6", displayName: { text: "Six" }, formattedAddress: "A6" },
          { id: "p7", displayName: { text: "Seven" }, formattedAddress: "A7" },
        ],
      })),
  })(post({ action: "search", query: "places" }));

  assertEquals(response.status, 200);
  assertCors(response);
  assertEquals(await response.json(), {
    suggestions: [
      { placeId: "p1", primaryText: "One", secondaryText: "A1" },
      { placeId: "p2", primaryText: "Two", secondaryText: "A2" },
      { placeId: "p3", primaryText: "Three", secondaryText: "A3" },
      { placeId: "p4", primaryText: "Four", secondaryText: "A4" },
      { placeId: "p5", primaryText: "Five", secondaryText: "A5" },
    ],
  });
});

Deno.test("search treats an omitted places field as no matches and rejects malformed places", async () => {
  const noMatches = await handlerFor({
    fetch: () => Promise.resolve(jsonResponse({})),
  })(post({ action: "search", query: "no matches" }));
  const malformed = await handlerFor({
    fetch: () =>
      Promise.resolve(jsonResponse({
        places: [{ id: "missing-display-name" }],
      })),
  })(post({ action: "search", query: "malformed result" }));

  assertEquals(noMatches.status, 200);
  assertCors(noMatches);
  assertEquals(await noMatches.json(), { suggestions: [] });
  await assertError(malformed, 502, "provider_error");
});

Deno.test("the short-window limiter is isolated per user and expires", async () => {
  let now = 10_000;
  const handler = handlerFor({
    now: () => now,
    rateLimit: { maxRequests: 2, windowMs: 1_000 },
  });

  const first = await handler(
    post({ action: "search", query: "KL" }, { token: "user-one" }),
  );
  const second = await handler(
    post({ action: "search", query: "KL" }, { token: "user-one" }),
  );
  const limited = await handler(
    post({ action: "search", query: "KL" }, { token: "user-one" }),
  );
  const otherUser = await handler(
    post({ action: "search", query: "KL" }, { token: "user-two" }),
  );
  now = 11_001;
  const afterWindow = await handler(
    post({ action: "search", query: "KL" }, { token: "user-one" }),
  );

  for (const response of [first, second, otherUser, afterWindow]) {
    assertEquals(response.status, 200);
    assertCors(response);
  }
  await assertError(limited, 429, "rate_limited");
});

Deno.test("provider failures are sanitized and never expose upstream details or the server key", async () => {
  const response = await handlerFor({
    fetch: () =>
      Promise.resolve(
        new Response(
          `Google diagnostic containing query, coordinates, and ${providerKey}`,
          { status: 503 },
        ),
      ),
  })(post({ action: "search", query: "private hotel query" }));

  const text = await assertError(response, 502, "provider_error");
  assert(!text.includes("private hotel query"));
  assert(!text.includes(providerKey));
  assert(!text.includes("Google diagnostic"));
});

Deno.test("AbortController timeouts return a sanitized timeout response with CORS", async () => {
  const fetchImpl: FetchImplementation = (_input, init) =>
    new Promise((_resolve, reject) => {
      const signal = init?.signal;
      if (signal?.aborted) {
        reject(new DOMException("provider detail", "AbortError"));
        return;
      }
      signal?.addEventListener(
        "abort",
        () => reject(new DOMException("provider detail", "AbortError")),
        { once: true },
      );
    });

  const response = await handlerFor({
    fetch: fetchImpl,
    scheduleTimeout: (callback) => {
      queueMicrotask(callback);
      return 1;
    },
    cancelTimeout: () => {},
    providerTimeoutMs: 10,
  })(post({ action: "search", query: "private query" }));

  const text = await assertError(response, 504, "timeout");
  assert(!text.includes("private query"));
  assert(!text.includes("provider detail"));
  assert(!text.includes(providerKey));
});

Deno.test("missing server configuration fails closed with a generic internal error and CORS", async () => {
  const response = await handlerFor({
    env: { GOOGLE_PLACES_SERVER_KEY: undefined },
    fetch: () => {
      throw new Error("missing configuration must not call Google");
    },
  })(post({ action: "search", query: "private query" }));

  const text = await assertError(response, 500, "internal_error");
  assert(!text.includes("GOOGLE_PLACES_SERVER_KEY"));
  assert(!text.includes("private query"));
});
