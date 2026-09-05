import { createPlacesProxyHandler } from "./index.ts";

type FetchImplementation = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

const endpoint = "https://edge.example.test/places-proxy";
const nominatimBase = "https://nominatim.openstreetmap.org";

const expectedMessages = {
  unauthorized: "Authentication is required.",
  invalid_request: "The request is invalid.",
  rate_limited: "Too many requests. Please try again shortly.",
  rate_limit_unavailable: "Location search is temporarily unavailable. Please try again.",
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
    scheduleTimeout?: (callback: () => void, delayMs: number) => number;
    cancelTimeout?: (handle: unknown) => void;
    consumeRateLimit?: (
      authorization: string,
    ) => Promise<{ allowed: boolean; remaining: number; retryAfterSeconds: number }>;
    providerTimeoutMs?: number;
    minRequestSpacingMs?: number;
    now?: () => number;
    sleep?: (ms: number) => Promise<void>;
  } = {},
) {
  const env: Record<string, string | undefined> = {
    SUPABASE_URL: "https://tripjournal.supabase.co",
    SUPABASE_ANON_KEY: "public-anon-key",
    ...options.env,
  };

  return createPlacesProxyHandler({
    fetch: options.fetch ??
      (() => Promise.resolve(jsonResponse([]))),
    authenticate: options.authenticate ?? ((authorization: string | null) => {
      if (!authorization?.startsWith("Bearer ")) return Promise.resolve(null);
      return Promise.resolve({ id: authorization.slice("Bearer ".length) });
    }),
    readEnv: (name: string) => env[name],
    scheduleTimeout: options.scheduleTimeout,
    cancelTimeout: options.cancelTimeout,
    consumeRateLimit: options.consumeRateLimit ?? (() =>
      Promise.resolve({ allowed: true, remaining: 19, retryAfterSeconds: 0 })),
    providerTimeoutMs: options.providerTimeoutMs,
    // Real spacing would slow every test by ~1s; tests that specifically
    // exercise throttling override this back to a controlled value.
    minRequestSpacingMs: options.minRequestSpacingMs ?? 0,
    now: options.now,
    sleep: options.sleep,
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
      throw new Error("unauthenticated requests must not call Nominatim");
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
    if (url === "https://tripjournal.supabase.co/rest/v1/rpc/consume_places_rate_limit") {
      const headers = new Headers(init?.headers);
      if (
        init?.method !== "POST" ||
        headers.get("authorization") !== "Bearer verified-token" ||
        headers.get("apikey") !== "public-anon-key"
      ) {
        return Promise.resolve(jsonResponse({ message: "bad limiter request" }, 401));
      }
      return Promise.resolve(jsonResponse({
        allowed: true,
        remaining: 19,
        retry_after_seconds: 0,
      }));
    }
    if (url.startsWith(`${nominatimBase}/search`)) {
      return Promise.resolve(jsonResponse([]));
    }
    return Promise.resolve(
      jsonResponse({ message: "unexpected endpoint" }, 404),
    );
  };
  const env: Record<string, string> = {
    SUPABASE_URL: "https://tripjournal.supabase.co",
    SUPABASE_ANON_KEY: "public-anon-key",
  };
  const handler = createPlacesProxyHandler({
    fetch: fetchImpl,
    readEnv: (name: string) => env[name],
    minRequestSpacingMs: 0,
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
  const trimmedFetch: FetchImplementation = (input) => {
    const url = new URL(String(input));
    if (url.pathname !== "/search") {
      return Promise.resolve(
        jsonResponse({ message: "unexpected endpoint" }, 404),
      );
    }
    return Promise.resolve(
      url.searchParams.get("q") === "KL" &&
        url.searchParams.get("format") === "jsonv2" &&
        url.searchParams.get("limit") === "5"
        ? jsonResponse([])
        : jsonResponse({ message: "invalid search request" }, 400),
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
      throw new Error("invalid search must not call Nominatim");
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

Deno.test("resolve requires an OSM-shaped placeId (letter + digits) and sends it as osm_ids", async () => {
  const fetchImpl: FetchImplementation = (input) => {
    const url = new URL(String(input));
    if (
      url.pathname !== "/lookup" ||
      url.searchParams.get("osm_ids") !== "N123456" ||
      url.searchParams.get("format") !== "jsonv2"
    ) {
      return Promise.resolve(
        jsonResponse({ message: "placeId was not trimmed" }, 404),
      );
    }
    return Promise.resolve(jsonResponse([{
      osm_type: "node",
      osm_id: 123456,
      lat: "3.1457",
      lon: "101.6955",
      name: "Central Market",
      display_name: "Central Market, Jalan Hang Kasturi, Kuala Lumpur",
      address: { road: "Jalan Hang Kasturi" },
    }]));
  };
  const valid = await handlerFor({ fetch: fetchImpl })(
    post({ action: "resolve", placeId: "  N123456  " }),
  );
  const invalidHandler = handlerFor({
    fetch: () => {
      throw new Error("invalid place IDs must not call Nominatim");
    },
  });
  const blank = await invalidHandler(
    post({ action: "resolve", placeId: "   " }),
  );
  const nonString = await invalidHandler(
    post({ action: "resolve", placeId: 123 }),
  );
  // The old Google-shaped id - a real regression case now that the format is enforced.
  const wrongFormat = await invalidHandler(
    post({ action: "resolve", placeId: "ChIJN1t_tDeuEmsRUsoyG83frY4" }),
  );
  const tooManyDigits = await invalidHandler(
    post({ action: "resolve", placeId: `N${"1".repeat(20)}` }),
  );

  assertEquals(valid.status, 200);
  assertCors(valid);
  assertEquals(await valid.json(), {
    location: {
      latitude: 3.1457,
      longitude: 101.6955,
      placeName: "Central Market",
      formattedAddress: "Central Market, Jalan Hang Kasturi, Kuala Lumpur",
      placeId: "N123456",
    },
  });
  await assertError(blank, 400, "invalid_request");
  await assertError(nonString, 400, "invalid_request");
  await assertError(wrongFormat, 400, "invalid_request");
  await assertError(tooManyDigits, 400, "invalid_request");
});

Deno.test("reverse rejects non-finite or out-of-range coordinates and accepts range boundaries", async () => {
  const invalidHandler = handlerFor({
    fetch: () => {
      throw new Error("invalid coordinates must not call Nominatim");
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
    fetch: (input) => {
      const url = new URL(String(input));
      if (
        url.origin !== nominatimBase ||
        url.pathname !== "/reverse" ||
        url.searchParams.get("lat") !== "-90" ||
        url.searchParams.get("lon") !== "180"
      ) {
        return Promise.resolve(jsonResponse({ error: "Unable to geocode" }, 200));
      }
      // Nominatim returns lat/lon as strings - the response must still parse.
      return Promise.resolve(jsonResponse({
        osm_type: "way",
        osm_id: 987654321,
        lat: "-90",
        lon: "180",
        display_name: "South Pole",
        address: { country: "Antarctica" },
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
      placeId: "W987654321",
    },
  });
});

Deno.test("reverse treats a Nominatim {error} body as no result, not a thrown error", async () => {
  const response = await handlerFor({
    fetch: () => Promise.resolve(jsonResponse({ error: "Unable to geocode" })),
  })(post({ action: "reverse", latitude: 0, longitude: 0 }));

  await assertError(response, 502, "provider_error");
});

Deno.test("search returns at most five normalized suggestions", async () => {
  const response = await handlerFor({
    fetch: () =>
      Promise.resolve(jsonResponse([
        { osm_type: "node", osm_id: 1, name: "One", display_name: "A1" },
        { osm_type: "node", osm_id: 2, name: "Two", display_name: "A2" },
        { osm_type: "node", osm_id: 3, name: "Three", display_name: "A3" },
        { osm_type: "node", osm_id: 4, name: "Four", display_name: "A4" },
        { osm_type: "node", osm_id: 5, name: "Five", display_name: "A5" },
        { osm_type: "node", osm_id: 6, name: "Six", display_name: "A6" },
        { osm_type: "node", osm_id: 7, name: "Seven", display_name: "A7" },
      ])),
  })(post({ action: "search", query: "places" }));

  assertEquals(response.status, 200);
  assertCors(response);
  assertEquals(await response.json(), {
    suggestions: [
      { placeId: "N1", primaryText: "One", secondaryText: "A1" },
      { placeId: "N2", primaryText: "Two", secondaryText: "A2" },
      { placeId: "N3", primaryText: "Three", secondaryText: "A3" },
      { placeId: "N4", primaryText: "Four", secondaryText: "A4" },
      { placeId: "N5", primaryText: "Five", secondaryText: "A5" },
    ],
  });
});

Deno.test("search treats an empty result array as no matches and rejects malformed results", async () => {
  const noMatches = await handlerFor({
    fetch: () => Promise.resolve(jsonResponse([])),
  })(post({ action: "search", query: "no matches" }));
  const malformed = await handlerFor({
    fetch: () =>
      Promise.resolve(jsonResponse([
        { osm_type: "node", osm_id: 1 }, // missing display_name
      ])),
  })(post({ action: "search", query: "malformed result" }));
  const nonArray = await handlerFor({
    fetch: () => Promise.resolve(jsonResponse({ not: "an array" })),
  })(post({ action: "search", query: "wrong shape" }));

  assertEquals(noMatches.status, 200);
  assertCors(noMatches);
  assertEquals(await noMatches.json(), { suggestions: [] });
  await assertError(malformed, 502, "provider_error");
  await assertError(nonArray, 502, "provider_error");
});

Deno.test("the durable limiter decision is enforced before calling Nominatim", async () => {
  let calls = 0;
  const handler = handlerFor({
    consumeRateLimit: () => {
      calls += 1;
      return Promise.resolve({
        allowed: calls <= 2,
        remaining: Math.max(0, 2 - calls),
        retryAfterSeconds: calls <= 2 ? 0 : 30,
      });
    },
  });

  const first = await handler(
    post({ action: "search", query: "KL" }, { token: "user-one" }),
  );
  const second = await handler(
    post({ action: "search", query: "KL2" }, { token: "user-one" }),
  );
  const limited = await handler(
    post({ action: "search", query: "KL3" }, { token: "user-one" }),
  );
  for (const response of [first, second]) {
    assertEquals(response.status, 200);
    assertCors(response);
  }
  await assertError(limited, 429, "rate_limited");
  assertEquals(calls, 3);
});

Deno.test("a limiter database failure fails closed without calling Nominatim", async () => {
  let providerCalls = 0;
  const response = await handlerFor({
    consumeRateLimit: () => Promise.reject(new Error("database offline")),
    fetch: () => {
      providerCalls += 1;
      return Promise.resolve(jsonResponse([]));
    },
  })(post({ action: "search", query: "private query" }));

  await assertError(response, 503, "rate_limit_unavailable");
  assertEquals(providerCalls, 0);
});

Deno.test("a cache hit does not call Nominatim a second time", async () => {
  let providerCalls = 0;
  const handler = handlerFor({
    fetch: () => {
      providerCalls += 1;
      return Promise.resolve(jsonResponse([]));
    },
  });

  const first = await handler(post({ action: "search", query: "repeat query" }));
  const second = await handler(post({ action: "search", query: "repeat query" }));

  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(providerCalls, 1);
});

Deno.test("consecutive upstream calls are spaced by the configured minimum", async () => {
  const sleepCalls: number[] = [];
  const currentTime = 1_000; // a fixed clock: nothing "elapses" between calls
  const handler = handlerFor({
    now: () => currentTime,
    sleep: (ms) => {
      sleepCalls.push(ms);
      return Promise.resolve();
    },
    minRequestSpacingMs: 500,
    fetch: () => Promise.resolve(jsonResponse([])),
  });

  await handler(post({ action: "search", query: "first query" }));
  await handler(post({ action: "search", query: "second query" }));

  assertEquals(sleepCalls, [500]);
});

Deno.test("provider failures are sanitized and never expose upstream details", async () => {
  const response = await handlerFor({
    fetch: () =>
      Promise.resolve(
        new Response(
          "Nominatim diagnostic containing the search query",
          { status: 503 },
        ),
      ),
  })(post({ action: "search", query: "private hotel query" }));

  const text = await assertError(response, 502, "provider_error");
  assert(!text.includes("private hotel query"));
  assert(!text.includes("Nominatim diagnostic"));
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
});

Deno.test("missing Supabase configuration fails closed with a generic internal error and CORS", async () => {
  // Exercises the module's own default authenticator (not the test stub),
  // which reads SUPABASE_URL/SUPABASE_ANON_KEY via requireEnvironment.
  const handler = createPlacesProxyHandler({
    readEnv: () => undefined,
    fetch: () => {
      throw new Error("missing configuration must not call Supabase or Nominatim");
    },
  });

  const response = await handler(post({ action: "search", query: "private query" }));

  const text = await assertError(response, 500, "internal_error");
  assert(!text.includes("SUPABASE_URL"));
  assert(!text.includes("private query"));
});
