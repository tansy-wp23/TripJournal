import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.112.0";

import {
  createPurgeHandler,
  type GatewayInitialization,
  JOURNAL_PHOTOS_BUCKET,
  type PurgeClaim,
  type PurgeGateway,
  TRIP_COVERS_BUCKET,
} from "./purge.ts";

const CLAIM_BATCH_SIZE = 100;
const MANAGED_BUCKETS = new Set([TRIP_COVERS_BUCKET, JOURNAL_PHOTOS_BUCKET]);

type FetchImplementation = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

interface SupabaseGatewayOptions extends GatewayInitialization {
  fetch?: FetchImplementation;
}

export function createSupabaseGateway(
  options: SupabaseGatewayOptions,
): PurgeGateway {
  const client = createClient(options.supabaseUrl, options.serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
    global: options.fetch == null ? undefined : { fetch: options.fetch },
  });
  return new SupabasePurgeGateway(client);
}

class SupabasePurgeGateway implements PurgeGateway {
  constructor(private readonly client: SupabaseClient) {}

  async claimExpiredTrips(cutoffIso: string): Promise<PurgeClaim[]> {
    const { data, error } = await this.client.rpc(
      "claim_expired_trip_purges",
      { p_cutoff: cutoffIso, p_limit: CLAIM_BATCH_SIZE },
    );
    if (error != null) throw error;
    if (!Array.isArray(data)) {
      throw new Error("Malformed purge claims response.");
    }

    return data.map((row) => {
      if (
        !isRecord(row) ||
        typeof row.trip_id !== "string" ||
        typeof row.claim_token !== "string" ||
        typeof row.owner_id !== "string" ||
        !(row.cover_photo_url == null ||
          typeof row.cover_photo_url === "string") ||
        !Array.isArray(row.journal_photo_urls) ||
        !row.journal_photo_urls.every((url) =>
          url == null || typeof url === "string"
        )
      ) {
        throw new Error("Malformed purge claim row.");
      }
      return {
        tripId: row.trip_id,
        claimToken: row.claim_token,
        userId: row.owner_id,
        coverPhotoUrl: row.cover_photo_url ?? null,
        journalPhotoUrls: row.journal_photo_urls,
      };
    });
  }

  async removeObjects(bucket: string, paths: string[]): Promise<void> {
    if (!MANAGED_BUCKETS.has(bucket)) {
      throw new Error("Refusing to remove from an unmanaged bucket.");
    }
    if (paths.length === 0) return;

    const { error } = await this.client.storage.from(bucket).remove(paths);
    if (error != null) throw error;
  }

  async permanentlyDeleteTrip(
    tripId: string,
    claimToken: string,
  ): Promise<void> {
    const { data, error } = await this.client.rpc("complete_trip_purge", {
      p_trip_id: tripId,
      p_claim_token: claimToken,
    });
    if (error != null) throw error;
    if (data !== true) throw new Error("Purge completion was not confirmed.");
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export const handler = createPurgeHandler({
  readEnv: (name) => Deno.env.get(name),
  clock: () => new Date(),
  createGateway: createSupabaseGateway,
});

if (import.meta.main) {
  Deno.serve(handler);
}
