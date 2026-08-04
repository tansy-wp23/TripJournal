import {
  createPurgeHandler,
  type PurgeClaim,
  purgeExpiredTrips,
  type PurgeGateway,
} from "./purge.ts";
import { createSupabaseGateway } from "./index.ts";

const supabaseUrl = "https://tripjournal.supabase.co";
const userId = "00000000-0000-0000-0000-000000000001";
const tripId = "11111111-1111-4111-8111-111111111111";
const claimToken = "22222222-2222-4222-8222-222222222222";
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

function claim(overrides: Partial<PurgeClaim> = {}): PurgeClaim {
  return {
    tripId,
    claimToken,
    userId,
    coverPhotoUrl:
      `${supabaseUrl}/storage/v1/object/public/trip-covers/${userId}/${tripId}/cover.jpg`,
    journalPhotoUrls: [
      `${supabaseUrl}/storage/v1/object/public/journal-photos/${userId}/${tripId}/one.jpg`,
    ],
    ...overrides,
  };
}

class ClaimGateway implements PurgeGateway {
  claims: PurgeClaim[] = [];
  cutoffs: string[] = [];
  events: string[] = [];
  removalFailures = new Map<string, Error>();
  acceptedTokens = new Map<string, string>();

  claimExpiredTrips(cutoff: string): Promise<PurgeClaim[]> {
    this.cutoffs.push(cutoff);
    const claimed = this.claims;
    this.claims = [];
    return Promise.resolve(claimed);
  }

  removeObjects(bucket: string, paths: string[]): Promise<void> {
    const key = `${bucket}/${paths.join(",")}`;
    this.events.push(`remove:${key}`);
    const failure = this.removalFailures.get(key);
    return failure == null ? Promise.resolve() : Promise.reject(failure);
  }

  permanentlyDeleteTrip(id: string, token: string): Promise<void> {
    this.events.push(`delete:${id}:${token}`);
    const accepted = this.acceptedTokens.get(id);
    if (accepted != null && accepted !== token) {
      return Promise.reject(new Error("purge_claim_mismatch"));
    }
    return Promise.resolve();
  }
}

class BatchGateway extends ClaimGateway {
  claimCalls = 0;

  constructor(private readonly batches: PurgeClaim[][]) {
    super();
  }

  override claimExpiredTrips(cutoff: string): Promise<PurgeClaim[]> {
    this.cutoffs.push(cutoff);
    this.claimCalls++;
    return Promise.resolve(this.batches.shift() ?? []);
  }
}

Deno.test("uses the durable claim snapshot and exact token for final deletion", async () => {
  const gateway = new ClaimGateway();
  gateway.claims = [claim()];
  gateway.acceptedTokens.set(tripId, claimToken);

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 1, failed: 0 });
  assertEquals(gateway.events, [
    `remove:trip-covers/${userId}/${tripId}/cover.jpg`,
    `remove:journal-photos/${userId}/${tripId}/one.jpg`,
    `delete:${tripId}:${claimToken}`,
  ]);
});

Deno.test("drains past 100 failed claims so a later batch can still succeed", async () => {
  const failedClaims = Array.from({ length: 100 }, (_, index) => {
    const id = `failed-trip-${index}`;
    return claim({
      tripId: id,
      claimToken: `failed-token-${index}`,
      coverPhotoUrl: null,
      journalPhotoUrls: [],
    });
  });
  const successfulClaim = claim({
    tripId: "later-success",
    claimToken: "later-token",
    coverPhotoUrl: null,
    journalPhotoUrls: [],
  });
  const gateway = new BatchGateway([
    failedClaims,
    [successfulClaim],
    [],
  ]);
  for (const failedClaim of failedClaims) {
    gateway.acceptedTokens.set(failedClaim.tripId, "different-token");
  }

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 101, deleted: 1, failed: 100 });
  assertEquals(gateway.claimCalls, 3);
});

Deno.test("stops draining immediately when the claim RPC returns an empty batch", async () => {
  const gateway = new BatchGateway([[], [claim()]]);

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 0, deleted: 0, failed: 0 });
  assertEquals(gateway.claimCalls, 1);
  assertEquals(gateway.events, []);
});

Deno.test("caps one invocation at ten claim batches even while work remains", async () => {
  const batches = Array.from({ length: 11 }, (_, index) => [claim({
    tripId: `trip-${index}`,
    claimToken: `token-${index}`,
    coverPhotoUrl: null,
    journalPhotoUrls: [],
  })]);
  const gateway = new BatchGateway(batches);

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 10, deleted: 10, failed: 0 });
  assertEquals(gateway.claimCalls, 10);
});

Deno.test("retries a failed durable claim with the same immutable snapshot", async () => {
  const gateway = new ClaimGateway();
  gateway.claims = [claim()];
  const coverKey = `trip-covers/${userId}/${tripId}/cover.jpg`;
  gateway.removalFailures.set(coverKey, new Error("storage unavailable"));

  const failed = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });
  gateway.removalFailures.clear();
  gateway.claims = [claim()];
  const retried = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(failed, { processed: 1, deleted: 0, failed: 1 });
  assertEquals(retried, { processed: 1, deleted: 1, failed: 0 });
  assertEquals(gateway.cutoffs, [
    cutoffIso,
    cutoffIso,
    cutoffIso,
    cutoffIso,
  ]);
  assertEquals(
    gateway.events.filter((event) => event.startsWith("delete:")).length,
    1,
  );
});

Deno.test("rejects a cross-user cover before deleting any object or row", async () => {
  const gateway = new ClaimGateway();
  gateway.claims = [claim({
    coverPhotoUrl:
      `${supabaseUrl}/storage/v1/object/public/trip-covers/99999999-9999-4999-8999-999999999999/${tripId}/cover.jpg`,
  })];

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 0, failed: 1 });
  assertEquals(gateway.events, []);
});

Deno.test("rejects a cross-trip journal photo before deleting any object or row", async () => {
  const gateway = new ClaimGateway();
  gateway.claims = [claim({
    journalPhotoUrls: [
      `${supabaseUrl}/storage/v1/object/public/journal-photos/${userId}/33333333-3333-4333-8333-333333333333/photo.jpg`,
    ],
  })];

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 0, failed: 1 });
  assertEquals(gateway.events, []);
});

Deno.test("prevalidates the entire snapshot before removing an earlier valid object", async () => {
  const gateway = new ClaimGateway();
  gateway.claims = [claim({
    journalPhotoUrls: [
      `${supabaseUrl}/storage/v1/object/public/journal-photos/${userId}/${tripId}/valid.jpg`,
      "https://attacker.example/foreign.jpg",
    ],
  })];

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 0, failed: 1 });
  assertEquals(gateway.events, []);
});

Deno.test("retains the durable claim for every Storage SDK error including ambiguous 404", async () => {
  const gateway = new ClaimGateway();
  gateway.claims = [claim()];
  const ambiguous404 = Object.assign(new Error("not found"), {
    statusCode: "404",
  });
  gateway.removalFailures.set(
    `trip-covers/${userId}/${tripId}/cover.jpg`,
    ambiguous404,
  );

  const summary = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(summary, { processed: 1, deleted: 0, failed: 1 });
  assert(!gateway.events.some((event) => event.startsWith("delete:")));
});

Deno.test("a stale worker token cannot complete a claim owned by a newer worker", async () => {
  const gateway = new ClaimGateway();
  const currentToken = "44444444-4444-4444-8444-444444444444";
  gateway.claims = [claim()];
  gateway.acceptedTokens.set(tripId, currentToken);

  const stale = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });
  gateway.claims = [claim({ claimToken: currentToken })];
  const current = await purgeExpiredTrips({ gateway, cutoffIso, supabaseUrl });

  assertEquals(stale, { processed: 1, deleted: 0, failed: 1 });
  assertEquals(current, { processed: 1, deleted: 1, failed: 0 });
});

Deno.test("handler supplies the exact cutoff to the atomic claim operation", async () => {
  const gateway = new ClaimGateway();
  const handler = createPurgeHandler({
    readEnv: (name) =>
      ({
        PURGE_CRON_SECRET: "secret",
        SUPABASE_URL: supabaseUrl,
        SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
      } as Record<string, string>)[name],
    clock: () => new Date("2026-09-04T02:15:00.000Z"),
    createGateway: () => gateway,
  });

  const response = await handler(
    new Request("https://edge.example.test/purge", {
      method: "POST",
      headers: { "x-cron-secret": "secret" },
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(gateway.cutoffs, [cutoffIso]);
});

Deno.test("Supabase gateway claims through the service-role RPC and maps its immutable snapshot", async () => {
  const captured: Request[] = [];
  const gateway = createSupabaseGateway({
    supabaseUrl,
    serviceRoleKey: "service-role-key",
    cutoffIso,
    fetch: (input, init) => {
      captured.push(
        input instanceof Request ? input : new Request(input, init),
      );
      return Promise.resolve(Response.json([{
        trip_id: tripId,
        claim_token: claimToken,
        owner_id: userId,
        cover_photo_url:
          `${supabaseUrl}/storage/v1/object/public/trip-covers/${userId}/${tripId}/cover.jpg`,
        journal_photo_urls: [
          `${supabaseUrl}/storage/v1/object/public/journal-photos/${userId}/${tripId}/photo.jpg`,
        ],
      }]));
    },
  });

  assertEquals(await gateway.claimExpiredTrips(cutoffIso), [claim({
    journalPhotoUrls: [
      `${supabaseUrl}/storage/v1/object/public/journal-photos/${userId}/${tripId}/photo.jpg`,
    ],
  })]);
  const request = captured[0];
  assert(request != null);
  assertEquals(request.method, "POST");
  assertEquals(
    new URL(request.url).pathname,
    "/rest/v1/rpc/claim_expired_trip_purges",
  );
  assertEquals(await request.clone().json(), {
    p_cutoff: cutoffIso,
    p_limit: 100,
  });
});

Deno.test("Supabase gateway completes only through the exact id and claim-token RPC", async () => {
  const captured: Request[] = [];
  const gateway = createSupabaseGateway({
    supabaseUrl,
    serviceRoleKey: "service-role-key",
    cutoffIso,
    fetch: (input, init) => {
      captured.push(
        input instanceof Request ? input : new Request(input, init),
      );
      return Promise.resolve(Response.json(true));
    },
  });

  await gateway.permanentlyDeleteTrip(tripId, claimToken);

  const request = captured[0];
  assert(request != null);
  assertEquals(
    new URL(request.url).pathname,
    "/rest/v1/rpc/complete_trip_purge",
  );
  assertEquals(await request.clone().json(), {
    p_trip_id: tripId,
    p_claim_token: claimToken,
  });
});
