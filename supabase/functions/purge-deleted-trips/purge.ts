export const TRIP_COVERS_BUCKET = "trip-covers";
export const JOURNAL_PHOTOS_BUCKET = "journal-photos";

const RETENTION_MILLISECONDS = 30 * 24 * 60 * 60 * 1000;
const PUBLIC_OBJECT_PREFIX = ["storage", "v1", "object", "public"];

export interface ExpiredTrip {
  id: string;
  coverPhotoUrl: string | null;
}

export interface PurgeGateway {
  listExpiredTrips(cutoffIso: string): Promise<ExpiredTrip[]>;
  listJournalPhotoUrls(tripId: string): Promise<Array<string | null>>;
  removeObjects(bucket: string, paths: string[]): Promise<void>;
  permanentlyDeleteTrip(tripId: string): Promise<void>;
}

export interface PurgeSummary {
  processed: number;
  deleted: number;
  failed: number;
}

export interface StorageObject {
  bucket: string;
  path: string;
}

export class StorageObjectNotFoundError extends Error {
  constructor(public readonly bucket: string, public readonly path: string) {
    super(`Storage object not found: ${bucket}/${path}`);
    this.name = "StorageObjectNotFoundError";
  }
}

interface PurgeOptions {
  gateway: PurgeGateway;
  cutoffIso: string;
  supabaseUrl: string;
}

export async function purgeExpiredTrips(
  { gateway, cutoffIso, supabaseUrl }: PurgeOptions,
): Promise<PurgeSummary> {
  const trips = await gateway.listExpiredTrips(cutoffIso);
  const summary: PurgeSummary = {
    processed: trips.length,
    deleted: 0,
    failed: 0,
  };

  for (const trip of trips) {
    try {
      const journalPhotoUrls = await gateway.listJournalPhotoUrls(trip.id);
      const objects = managedObjectsForTrip(
        trip.coverPhotoUrl,
        journalPhotoUrls,
        supabaseUrl,
      );

      for (const object of objects) {
        try {
          await gateway.removeObjects(object.bucket, [object.path]);
        } catch (error) {
          if (!(error instanceof StorageObjectNotFoundError)) throw error;
        }
      }

      await gateway.permanentlyDeleteTrip(trip.id);
      summary.deleted++;
    } catch {
      summary.failed++;
    }
  }

  return summary;
}

function managedObjectsForTrip(
  coverPhotoUrl: string | null,
  journalPhotoUrls: Array<string | null>,
  supabaseUrl: string,
): StorageObject[] {
  const candidates: Array<StorageObject | null> = [
    parsePublicStorageUrl(
      coverPhotoUrl,
      supabaseUrl,
      TRIP_COVERS_BUCKET,
    ),
    ...journalPhotoUrls.map((url) =>
      parsePublicStorageUrl(url, supabaseUrl, JOURNAL_PHOTOS_BUCKET)
    ),
  ];
  const unique = new Map<string, StorageObject>();

  for (const candidate of candidates) {
    if (candidate == null) continue;
    unique.set(`${candidate.bucket}\u0000${candidate.path}`, candidate);
  }

  return [...unique.values()];
}

export function parsePublicStorageUrl(
  publicUrl: string | null,
  supabaseUrl: string,
  expectedBucket: string,
): StorageObject | null {
  if (publicUrl == null || publicUrl.length === 0) return null;

  let parsedPublicUrl: URL;
  let parsedSupabaseUrl: URL;
  try {
    parsedPublicUrl = new URL(publicUrl);
    parsedSupabaseUrl = new URL(supabaseUrl);
  } catch {
    return null;
  }

  if (
    parsedPublicUrl.username.length > 0 ||
    parsedPublicUrl.password.length > 0 ||
    parsedSupabaseUrl.username.length > 0 ||
    parsedSupabaseUrl.password.length > 0 ||
    parsedPublicUrl.origin !== parsedSupabaseUrl.origin
  ) {
    return null;
  }

  const rawPath = rawPathname(publicUrl);
  if (rawPath == null || rawPath.includes("\\")) return null;
  const rawSegments = rawPath.split("/");
  const prefixLength = PUBLIC_OBJECT_PREFIX.length;

  if (
    rawSegments[0] !== "" ||
    rawSegments.length <= prefixLength + 2 ||
    !PUBLIC_OBJECT_PREFIX.every((segment, index) =>
      rawSegments[index + 1] === segment
    ) ||
    rawSegments[prefixLength + 1] !== expectedBucket
  ) {
    return null;
  }

  const encodedObjectSegments = rawSegments.slice(prefixLength + 2);
  if (encodedObjectSegments.some((segment) => segment.length === 0)) {
    return null;
  }

  const decodedObjectSegments: string[] = [];
  for (const segment of encodedObjectSegments) {
    if (/%2f|%5c/i.test(segment)) return null;

    let decoded: string;
    try {
      decoded = decodeURIComponent(segment);
    } catch {
      return null;
    }

    if (
      decoded.length === 0 ||
      decoded === "." ||
      decoded === ".." ||
      decoded.includes("/") ||
      decoded.includes("\\") ||
      /%[0-9a-f]{2}/i.test(decoded)
    ) {
      return null;
    }
    decodedObjectSegments.push(decoded);
  }

  return {
    bucket: expectedBucket,
    path: decodedObjectSegments.join("/"),
  };
}

function rawPathname(value: string): string | null {
  const schemeEnd = value.indexOf("://");
  if (schemeEnd < 0) return null;
  const authorityStart = schemeEnd + 3;
  const pathStart = value.indexOf("/", authorityStart);
  if (pathStart < 0) return null;

  const queryStart = value.indexOf("?", pathStart);
  const fragmentStart = value.indexOf("#", pathStart);
  let pathEnd = value.length;
  if (queryStart >= 0) pathEnd = Math.min(pathEnd, queryStart);
  if (fragmentStart >= 0) pathEnd = Math.min(pathEnd, fragmentStart);
  return value.slice(pathStart, pathEnd);
}

export interface GatewayInitialization {
  supabaseUrl: string;
  serviceRoleKey: string;
  cutoffIso: string;
}

interface PurgeHandlerDependencies {
  readEnv(name: string): string | undefined;
  clock(): Date;
  createGateway(initialization: GatewayInitialization): PurgeGateway;
}

export function createPurgeHandler(
  dependencies: PurgeHandlerDependencies,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return jsonResponse(
        { error: "Method not allowed." },
        405,
        { allow: "POST" },
      );
    }

    const expectedSecret = dependencies.readEnv("PURGE_CRON_SECRET");
    if (expectedSecret == null || expectedSecret.length === 0) {
      return internalServerError();
    }

    const suppliedSecret = request.headers.get("x-cron-secret") ?? "";
    if (!constantTimeishEquals(suppliedSecret, expectedSecret)) {
      return jsonResponse({ error: "Unauthorized." }, 401);
    }

    try {
      const supabaseUrl = requireEnvironmentValue(
        dependencies,
        "SUPABASE_URL",
      );
      const serviceRoleKey = requireEnvironmentValue(
        dependencies,
        "SUPABASE_SERVICE_ROLE_KEY",
      );
      const normalizedSupabaseUrl = normalizeSupabaseUrl(supabaseUrl);
      const currentTime = dependencies.clock();
      if (!Number.isFinite(currentTime.getTime())) {
        throw new Error("Invalid purge clock.");
      }
      const cutoffIso = new Date(
        currentTime.getTime() - RETENTION_MILLISECONDS,
      ).toISOString();
      const gateway = dependencies.createGateway({
        supabaseUrl: normalizedSupabaseUrl,
        serviceRoleKey,
        cutoffIso,
      });
      const summary = await purgeExpiredTrips({
        gateway,
        cutoffIso,
        supabaseUrl: normalizedSupabaseUrl,
      });
      return jsonResponse(summary, 200);
    } catch {
      return internalServerError();
    }
  };
}

function requireEnvironmentValue(
  dependencies: PurgeHandlerDependencies,
  name: string,
): string {
  const value = dependencies.readEnv(name);
  if (value == null || value.length === 0) {
    throw new Error(`Missing environment value: ${name}`);
  }
  return value;
}

function normalizeSupabaseUrl(value: string): string {
  const parsed = new URL(value);
  if (
    (parsed.protocol !== "https:" && parsed.protocol !== "http:") ||
    parsed.username.length > 0 ||
    parsed.password.length > 0 ||
    parsed.search.length > 0 ||
    parsed.hash.length > 0
  ) {
    throw new Error("Invalid Supabase URL.");
  }
  return parsed.origin;
}

function constantTimeishEquals(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;

  for (let index = 0; index < length; index++) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

function internalServerError(): Response {
  return jsonResponse({ error: "Internal server error." }, 500);
}

function jsonResponse(
  body: PurgeSummary | { error: string },
  status: number,
  additionalHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...additionalHeaders,
    },
  });
}
