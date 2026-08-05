import {
  createPurgeHandler,
  parsePublicStorageUrl,
  type PurgeClaim,
  type PurgeGateway,
} from "./purge.ts";

const supabaseUrl = "https://tripjournal.supabase.co";
const secret = "correct-cron-secret";
const now = new Date("2026-09-04T02:15:00.000Z");

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

class HandlerGateway implements PurgeGateway {
  claims: PurgeClaim[] = [];
  claimFailure: Error | null = null;
  cutoffs: string[] = [];

  claimExpiredTrips(cutoffIso: string): Promise<PurgeClaim[]> {
    this.cutoffs.push(cutoffIso);
    return this.claimFailure == null
      ? Promise.resolve(this.claims)
      : Promise.reject(this.claimFailure);
  }

  removeObjects(): Promise<void> {
    return Promise.resolve();
  }

  permanentlyDeleteTrip(): Promise<void> {
    return Promise.resolve();
  }
}

function handlerFor(
  gateway: HandlerGateway,
  overrides: {
    env?: Record<string, string | undefined>;
    createGateway?: () => PurgeGateway;
  } = {},
) {
  const env: Record<string, string | undefined> = {
    PURGE_CRON_SECRET: secret,
    SUPABASE_URL: supabaseUrl,
    SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
    ...overrides.env,
  };
  return createPurgeHandler({
    readEnv: (name) => env[name],
    clock: () => now,
    createGateway: overrides.createGateway ?? (() => gateway),
  });
}

function post(headerSecret?: string) {
  const headers = new Headers();
  if (headerSecret != null) headers.set("x-cron-secret", headerSecret);
  return new Request("https://edge.example.test/purge", {
    method: "POST",
    headers,
  });
}

Deno.test("rejects missing and incorrect cron secrets before gateway initialization", async () => {
  const gateway = new HandlerGateway();
  let initializationCount = 0;
  const handler = handlerFor(gateway, {
    createGateway: () => {
      initializationCount++;
      return gateway;
    },
  });

  const missing = await handler(post());
  const incorrect = await handler(post(`${secret}-extra`));

  assertEquals(missing.status, 401);
  assertEquals(incorrect.status, 401);
  assertEquals(initializationCount, 0);
  assertEquals(await missing.json(), { error: "Unauthorized." });
});

Deno.test("accepts POST only and returns a JSON 405 response", async () => {
  const response = await handlerFor(new HandlerGateway())(
    new Request("https://edge.example.test/purge", {
      method: "GET",
      headers: { "x-cron-secret": secret },
    }),
  );

  assertEquals(response.status, 405);
  assertEquals(response.headers.get("allow"), "POST");
  assertEquals(
    response.headers.get("content-type"),
    "application/json; charset=utf-8",
  );
  assertEquals(await response.json(), { error: "Method not allowed." });
});

Deno.test("missing server secret fails closed with a generic 500", async () => {
  const response = await handlerFor(new HandlerGateway(), {
    env: { PURGE_CRON_SECRET: undefined },
  })(post(secret));

  assertEquals(response.status, 500);
  assertEquals(await response.text(), '{"error":"Internal server error."}');
});

Deno.test("request-wide environment, initialization, and claim failures return secret-free 500", async () => {
  const missingServiceKey = await handlerFor(new HandlerGateway(), {
    env: { SUPABASE_SERVICE_ROLE_KEY: undefined },
  })(post(secret));
  const failedInitialization = await handlerFor(new HandlerGateway(), {
    createGateway: () => {
      throw new Error(`do not expose ${secret}`);
    },
  })(post(secret));
  const failedClaim = new HandlerGateway();
  failedClaim.claimFailure = new Error("database unavailable");
  const failedClaimResponse = await handlerFor(failedClaim)(post(secret));

  for (
    const response of [
      missingServiceKey,
      failedInitialization,
      failedClaimResponse,
    ]
  ) {
    assertEquals(response.status, 500);
    const body = await response.text();
    assertEquals(body, '{"error":"Internal server error."}');
    assert(!body.includes(secret));
    assert(!body.includes("service-role-key"));
  }
});

Deno.test("parses a canonical current-origin public URL without query or fragment", () => {
  assertEquals(
    parsePublicStorageUrl(
      `${supabaseUrl}/storage/v1/object/public/trip-covers/user/trip/cover%20photo.jpg?download=1#preview`,
      supabaseUrl,
      "trip-covers",
    ),
    { bucket: "trip-covers", path: "user/trip/cover photo.jpg" },
  );
});

Deno.test("rejects foreign origins, unexpected buckets, and noncanonical paths", () => {
  const rejected = [
    "https://attacker.example/storage/v1/object/public/trip-covers/user/trip/cover.jpg",
    "https://attacker.example@tripjournal.supabase.co/storage/v1/object/public/trip-covers/user/trip/cover.jpg",
    `${supabaseUrl}/storage/v1/object/public/journal-photos/user/trip/cover.jpg`,
    `${supabaseUrl}/storage/v1/object/public/trip-covers/user//cover.jpg`,
    `${supabaseUrl}/storage/v1/object/public/trip-covers/user/%2e%2e/cover.jpg`,
    `${supabaseUrl}/storage/v1/object/public/trip-covers/user%2fother/cover.jpg`,
    `${supabaseUrl}/storage/v1/object/public/trip-covers/user%5Cother/cover.jpg`,
    `${supabaseUrl}/storage/v1/object/public/trip-covers/user/%252f/cover.jpg`,
    `${supabaseUrl}/storage/v1/object/public/trip-covers/`,
  ];

  for (const value of rejected) {
    assertEquals(
      parsePublicStorageUrl(value, supabaseUrl, "trip-covers"),
      null,
      `Expected URL to be rejected: ${value}`,
    );
  }
});
