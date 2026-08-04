import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.112.0";

import {
  createPurgeHandler,
  type ExpiredTrip,
  type GatewayInitialization,
  JOURNAL_PHOTOS_BUCKET,
  type PurgeGateway,
  StorageObjectNotFoundError,
  TRIP_COVERS_BUCKET,
} from "./purge.ts";

const PAGE_SIZE = 500;
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
  return new SupabasePurgeGateway(client, options.cutoffIso);
}

class SupabasePurgeGateway implements PurgeGateway {
  constructor(
    private readonly client: SupabaseClient,
    private readonly cutoffIso: string,
  ) {}

  async listExpiredTrips(cutoffIso: string): Promise<ExpiredTrip[]> {
    const trips: ExpiredTrip[] = [];

    for (let from = 0;; from += PAGE_SIZE) {
      const { data, error } = await this.client
        .from("trips")
        .select("id,cover_photo_url")
        .lte("deleted_at", cutoffIso)
        .order("id", { ascending: true })
        .range(from, from + PAGE_SIZE - 1);
      if (error != null) throw error;
      if (!Array.isArray(data)) throw new Error("Malformed trips response.");

      for (const row of data) {
        if (
          !isRecord(row) ||
          typeof row.id !== "string" ||
          !(row.cover_photo_url == null ||
            typeof row.cover_photo_url === "string")
        ) {
          throw new Error("Malformed trip row.");
        }
        trips.push({
          id: row.id,
          coverPhotoUrl: row.cover_photo_url ?? null,
        });
      }

      if (data.length < PAGE_SIZE) return trips;
    }
  }

  async listJournalPhotoUrls(tripId: string): Promise<Array<string | null>> {
    const photoUrls: Array<string | null> = [];

    for (let from = 0;; from += PAGE_SIZE) {
      const { data, error } = await this.client
        .from("journal_entries")
        .select("photo_urls")
        .eq("trip_id", tripId)
        .order("id", { ascending: true })
        .range(from, from + PAGE_SIZE - 1);
      if (error != null) throw error;
      if (!Array.isArray(data)) {
        throw new Error("Malformed journal entries response.");
      }

      for (const row of data) {
        if (!isRecord(row) || !Array.isArray(row.photo_urls)) {
          throw new Error("Malformed journal photo row.");
        }
        for (const photoUrl of row.photo_urls) {
          if (!(photoUrl == null || typeof photoUrl === "string")) {
            throw new Error("Malformed journal photo URL.");
          }
          photoUrls.push(photoUrl);
        }
      }

      if (data.length < PAGE_SIZE) return photoUrls;
    }
  }

  async removeObjects(bucket: string, paths: string[]): Promise<void> {
    if (!MANAGED_BUCKETS.has(bucket)) {
      throw new Error("Refusing to remove from an unmanaged bucket.");
    }
    if (paths.length === 0) return;

    const { error } = await this.client.storage.from(bucket).remove(paths);
    if (error == null) return;
    if (paths.length === 1 && storageErrorStatus(error) === 404) {
      throw new StorageObjectNotFoundError(bucket, paths[0]);
    }
    throw error;
  }

  async permanentlyDeleteTrip(tripId: string): Promise<void> {
    const { data, error } = await this.client
      .from("trips")
      .delete()
      .eq("id", tripId)
      .lte("deleted_at", this.cutoffIso)
      .select("id");
    if (error != null) throw error;
    if (Array.isArray(data) && data.length > 0) return;

    const { data: remainingRows, error: remainingError } = await this.client
      .from("trips")
      .select("deleted_at")
      .eq("id", tripId)
      .limit(1);
    if (remainingError != null) throw remainingError;
    if (Array.isArray(remainingRows) && remainingRows.length === 0) return;

    throw new Error("Trip is no longer eligible for permanent deletion.");
  }
}

function storageErrorStatus(error: unknown): number | null {
  if (!isRecord(error)) return null;
  const status = error.statusCode ?? error.status;
  if (typeof status === "number") return status;
  if (typeof status === "string" && /^\d+$/.test(status)) {
    return Number(status);
  }
  return null;
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
