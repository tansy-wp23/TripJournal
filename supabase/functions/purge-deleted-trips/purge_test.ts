import {
  createPurgeHandler,
  type ExpiredTrip,
  parsePublicStorageUrl,
  purgeExpiredTrips,
  type PurgeGateway,
  StorageObjectNotFoundError,
} from "./purge.ts";
import { createSupabaseGateway } from "./index.ts";

const supabaseUrl = "https://tripjournal.supabase.co";
const secret = "correct-cron-secret";
const now = new Date("2026-09-04T02:15:00.000Z");
const cutoffIso = "2026-08-05T02:15:00.000Z";

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

class RecordingGateway implements PurgeGateway {
  trips: ExpiredTrip[] = [];
  photoUrls = new Map<string, Array<string | null>>();
  removalFailures = new Map<string, Error>();
  journalFailures = new Map<string, Error>();
  deletionFailures = new Map<string, Error>();
  cutoffs: string[] = [];
  events: string[] = [];

  listExpiredTrips(requestedCutoffIso: string): Promise<ExpiredTrip[]> {
    this.cutoffs.push(requestedCutoffIso);
    return Promise.resolve(this.trips);
  }

  listJournalPhotoUrls(tripId: string): Promise<Array<string | null>> {
    this.events.push(`list:${tripId}`);
    const failure = this.journalFailures.get(tripId);
    if (failure) return Promise.reject(failure);
    return Promise.resolve(this.photoUrls.get(tripId) ?? []);
  }

  removeObjects(bucket: string, paths: string[]): Promise<void> {
    const key = `${bucket}/${paths.join(",")}`;
    this.events.push(`remove:${key}`);
    const failure = this.removalFailures.get(key);
    return failure ? Promise.reject(failure) : Promise.resolve();
  }

  permanentlyDeleteTrip(tripId: string): Promise<void> {
    this.events.push(`delete:${tripId}`);
    const failure = this.deletionFailures.get(tripId);
    return failure ? Promise.reject(failure) : Promise.resolve();
  }
}

function handlerFor(
  gateway: RecordingGateway,
  overrides: {
    env?: Record<string, string | undefined>;
    clock?: () => Date;
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
    readEnv: (name: string) => env[name],
    clock: overrides.clock ?? (() => now),
    createGateway: overrides.createGateway ?? (() => gateway),
  });
}

function post(headerSecret = secret) {
  return new Request("https://edge.example.test/purge-deleted-trips", {
    method: "POST",
    headers: { "x-cron-secret": headerSecret },
  });
}

function capturedRequest(input: RequestInfo | URL, init?: RequestInit) {
  return input instanceof Request ? input : new Request(input, init);
}

Deno.test("rejects missing and incorrect cron secrets without initializing the gateway", async () => {
  const gateway = new RecordingGateway();
  let initializationCount = 0;
  const handler = createPurgeHandler({
    readEnv: (name: string) =>
      ({
        PURGE_CRON_SECRET: secret,
        SUPABASE_URL: supabaseUrl,
        SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
      } as Record<string, string | undefined>)[name],
    clock: () => now,
    createGateway: () => {
      initializationCount++;
      return gateway;
    },
  });

  const missing = await handler(
    new Request("https://edge.example.test/purge-deleted-trips", {
      method: "POST",
    }),
  );
  const incorrect = await handler(post("correct-cron-secret-extra"));

  assertEquals(missing.status, 401);
  assertEquals(incorrect.status, 401);
  assertEquals(initializationCount, 0);
  assertEquals(await missing.json(), { error: "Unauthorized." });
});

Deno.test("accepts POST only and returns JSON for malformed invocation methods", async () => {
  const gateway = new RecordingGateway();
  const response = await handlerFor(gateway)(
    new Request("https://edge.example.test/purge-deleted-trips", {
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

Deno.test("uses the handler clock to supply the exact 30 x 24-hour cutoff", async () => {
  const gateway = new RecordingGateway();
  gateway.trips = [{ id: "expired", coverPhotoUrl: null }];

  const response = await handlerFor(gateway)(post());

  assertEquals(response.status, 200);
  assertEquals(gateway.cutoffs, [cutoffIso]);
  assertEquals(gateway.events, ["list:expired", "delete:expired"]);
  assertEquals(await response.json(), { processed: 1, deleted: 1, failed: 0 });
});

Deno.test("cleans the cover and every journal photo before hard deleting the trip", async () => {
  const gateway = new RecordingGateway();
  gateway.trips = [{
    id: "trip-a",
    coverPhotoUrl:
      `${supabaseUrl}/storage/v1/object/public/trip-covers/user-a/trip-a/cover.jpg`,
  }];
  gateway.photoUrls.set("trip-a", [
    `${supabaseUrl}/storage/v1/object/public/journal-photos/user-a/trip-a/one.jpg`,
    `${supabaseUrl}/storage/v1/object/public/journal-photos/user-a/trip-a/two.jpg`,
  ]);

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 1, failed: 0 });
  assertEquals(gateway.events, [
    "list:trip-a",
    "remove:trip-covers/user-a/trip-a/cover.jpg",
    "remove:journal-photos/user-a/trip-a/one.jpg",
    "remove:journal-photos/user-a/trip-a/two.jpg",
    "delete:trip-a",
  ]);
});

Deno.test("deduplicates canonical object paths and ignores query strings and fragments", async () => {
  const gateway = new RecordingGateway();
  gateway.trips = [{ id: "trip-a", coverPhotoUrl: null }];
  gateway.photoUrls.set("trip-a", [
    `${supabaseUrl}/storage/v1/object/public/journal-photos/user/trip/photo%20one.jpg?download=1`,
    `${supabaseUrl}/storage/v1/object/public/journal-photos/user/trip/%70hoto%20%6Fne.jpg#preview`,
    null,
  ]);

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 1, failed: 0 });
  assertEquals(gateway.events, [
    "list:trip-a",
    "remove:journal-photos/user/trip/photo one.jpg",
    "delete:trip-a",
  ]);
});

Deno.test("treats a missing Storage object as successful idempotent cleanup", async () => {
  const gateway = new RecordingGateway();
  gateway.trips = [{ id: "trip-a", coverPhotoUrl: null }];
  gateway.photoUrls.set("trip-a", [
    `${supabaseUrl}/storage/v1/object/public/journal-photos/user/trip/missing.jpg`,
  ]);
  gateway.removalFailures.set(
    "journal-photos/user/trip/missing.jpg",
    new StorageObjectNotFoundError("journal-photos", "user/trip/missing.jpg"),
  );

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 1, failed: 0 });
  assertEquals(gateway.events.at(-1), "delete:trip-a");
});

Deno.test("retains the database row when a real Storage removal fails", async () => {
  const gateway = new RecordingGateway();
  gateway.trips = [{
    id: "trip-a",
    coverPhotoUrl:
      `${supabaseUrl}/storage/v1/object/public/trip-covers/user/trip/cover.jpg`,
  }];
  gateway.removalFailures.set(
    "trip-covers/user/trip/cover.jpg",
    new Error("storage unavailable"),
  );

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 0, failed: 1 });
  assert(!gateway.events.includes("delete:trip-a"));
});

Deno.test("isolates a failed trip and continues purging later trips", async () => {
  const gateway = new RecordingGateway();
  gateway.trips = [
    {
      id: "bad-trip",
      coverPhotoUrl:
        `${supabaseUrl}/storage/v1/object/public/trip-covers/user/bad/cover.jpg`,
    },
    { id: "good-trip", coverPhotoUrl: null },
  ];
  gateway.removalFailures.set(
    "trip-covers/user/bad/cover.jpg",
    new Error("storage unavailable"),
  );

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 2, deleted: 1, failed: 1 });
  assert(!gateway.events.includes("delete:bad-trip"));
  assert(gateway.events.includes("delete:good-trip"));
});

Deno.test("retains a trip when journal-photo listing or database deletion fails", async () => {
  const gateway = new RecordingGateway();
  gateway.trips = [
    { id: "journal-failure", coverPhotoUrl: null },
    { id: "delete-failure", coverPhotoUrl: null },
  ];
  gateway.journalFailures.set("journal-failure", new Error("query failed"));
  gateway.deletionFailures.set("delete-failure", new Error("delete failed"));

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 2, deleted: 0, failed: 2 });
  assert(!gateway.events.includes("delete:journal-failure"));
});

Deno.test("parses only canonical public object URLs on the current Supabase origin and expected bucket", () => {
  assertEquals(
    parsePublicStorageUrl(
      `${supabaseUrl}/storage/v1/object/public/trip-covers/user/trip/cover%20photo.jpg?x=1#preview`,
      supabaseUrl,
      "trip-covers",
    ),
    { bucket: "trip-covers", path: "user/trip/cover photo.jpg" },
  );

  const rejected = [
    `https://attacker.example/storage/v1/object/public/trip-covers/user/trip/cover.jpg`,
    `https://attacker.example@tripjournal.supabase.co/storage/v1/object/public/trip-covers/user/trip/cover.jpg`,
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

Deno.test("returns a generic 500 only for request-wide initialization and listing failures", async () => {
  const gateway = new RecordingGateway();
  const missingEnv = await handlerFor(gateway, {
    env: { SUPABASE_SERVICE_ROLE_KEY: undefined },
  })(post());
  const failedInitialization = await handlerFor(gateway, {
    createGateway: () => {
      throw new Error(`do not expose ${secret}`);
    },
  })(post());
  const failedListing = await handlerFor(gateway, {
    createGateway: () =>
      Object.assign(gateway, {
        listExpiredTrips: () =>
          Promise.reject(new Error("database unavailable")),
      }),
  })(post());

  for (const response of [missingEnv, failedInitialization, failedListing]) {
    assertEquals(response.status, 500);
    const body = await response.text();
    assertEquals(body, '{"error":"Internal server error."}');
    assert(!body.includes(secret));
    assert(!body.includes("service-role-key"));
  }
});

Deno.test("Supabase gateway queries the exact schema fields with an inclusive expired cutoff", async () => {
  const requests: Request[] = [];
  const gateway = createSupabaseGateway({
    supabaseUrl,
    serviceRoleKey: "service-role-key",
    cutoffIso,
    fetch: (input: RequestInfo | URL, init?: RequestInit) => {
      const request = capturedRequest(input, init);
      requests.push(request);
      const url = new URL(request.url);

      if (url.pathname === "/rest/v1/trips") {
        return Promise.resolve(Response.json([
          { id: "trip-a", cover_photo_url: "https://cover.example/a.jpg" },
        ], { headers: { "content-range": "0-0/*" } }));
      }
      if (url.pathname === "/rest/v1/journal_entries") {
        return Promise.resolve(Response.json([
          { photo_urls: ["https://photo.example/one.jpg", null] },
          { photo_urls: ["https://photo.example/two.jpg"] },
        ], { headers: { "content-range": "0-1/*" } }));
      }
      throw new Error(`Unexpected request: ${request.url}`);
    },
  });

  assertEquals(await gateway.listExpiredTrips(cutoffIso), [{
    id: "trip-a",
    coverPhotoUrl: "https://cover.example/a.jpg",
  }]);
  assertEquals(await gateway.listJournalPhotoUrls("trip-a"), [
    "https://photo.example/one.jpg",
    null,
    "https://photo.example/two.jpg",
  ]);

  const tripsUrl = new URL(requests[0].url);
  assertEquals(tripsUrl.searchParams.get("select"), "id,cover_photo_url");
  assertEquals(tripsUrl.searchParams.get("deleted_at"), `lte.${cutoffIso}`);
  assertEquals(tripsUrl.searchParams.get("order"), "id.asc");
  assertEquals(tripsUrl.searchParams.get("offset"), "0");
  assertEquals(tripsUrl.searchParams.get("limit"), "500");
  const journalUrl = new URL(requests[1].url);
  assertEquals(journalUrl.searchParams.get("select"), "photo_urls");
  assertEquals(journalUrl.searchParams.get("trip_id"), "eq.trip-a");
  assertEquals(journalUrl.searchParams.get("order"), "id.asc");
});

Deno.test("Supabase gateway paginates expired trips without deleting during listing", async () => {
  const pages: string[] = [];
  const firstPage = Array.from({ length: 500 }, (_, index) => ({
    id: `trip-${index.toString().padStart(3, "0")}`,
    cover_photo_url: null,
  }));
  const gateway = createSupabaseGateway({
    supabaseUrl,
    serviceRoleKey: "service-role-key",
    cutoffIso,
    fetch: (input: RequestInfo | URL, init?: RequestInit) => {
      const request = capturedRequest(input, init);
      const url = new URL(request.url);
      pages.push(
        `${url.searchParams.get("offset")}:${url.searchParams.get("limit")}`,
      );
      const body = pages.length === 1
        ? firstPage
        : [{ id: "trip-500", cover_photo_url: null }];
      return Promise.resolve(Response.json(body));
    },
  });

  const trips = await gateway.listExpiredTrips(cutoffIso);

  assertEquals(trips.length, 501);
  assertEquals(trips.at(-1), { id: "trip-500", coverPhotoUrl: null });
  assertEquals(pages, ["0:500", "500:500"]);
});

Deno.test("Supabase gateway maps only authoritative Storage 404 errors to object-not-found", async () => {
  let status = 404;
  const gateway = createSupabaseGateway({
    supabaseUrl,
    serviceRoleKey: "service-role-key",
    cutoffIso,
    fetch: () =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            statusCode: String(status),
            error: "storage_error",
          }),
          {
            status,
            headers: { "content-type": "application/json" },
          },
        ),
      ),
  });

  let missingError: unknown;
  try {
    await gateway.removeObjects("journal-photos", ["user/trip/missing.jpg"]);
  } catch (error) {
    missingError = error;
  }
  assert(missingError instanceof StorageObjectNotFoundError);

  status = 500;
  let realError: unknown;
  try {
    await gateway.removeObjects("journal-photos", ["user/trip/photo.jpg"]);
  } catch (error) {
    realError = error;
  }
  assert(realError instanceof Error);
  assert(!(realError instanceof StorageObjectNotFoundError));
});

Deno.test("Supabase gateway hard delete remains cutoff-guarded and treats an already-absent row idempotently", async () => {
  const requests: Request[] = [];
  const gateway = createSupabaseGateway({
    supabaseUrl,
    serviceRoleKey: "service-role-key",
    cutoffIso,
    fetch: (input: RequestInfo | URL, init?: RequestInit) => {
      const request = capturedRequest(input, init);
      requests.push(request);
      if (request.method === "DELETE") {
        return Promise.resolve(Response.json([]));
      }
      return Promise.resolve(Response.json([]));
    },
  });

  await gateway.permanentlyDeleteTrip("trip-a");

  const deleteUrl = new URL(requests[0].url);
  assertEquals(requests[0].method, "DELETE");
  assertEquals(deleteUrl.pathname, "/rest/v1/trips");
  assertEquals(deleteUrl.searchParams.get("id"), "eq.trip-a");
  assertEquals(deleteUrl.searchParams.get("deleted_at"), `lte.${cutoffIso}`);
  assertEquals(deleteUrl.searchParams.get("select"), "id");
  assertEquals(requests[1].method, "GET");
});
