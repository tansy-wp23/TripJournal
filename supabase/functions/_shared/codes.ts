// Shared helpers for the User Management verification-code Edge Functions.
//
// Phase 6 of USER_MANAGEMENT_IMPLEMENTATION_PLAN.md. Only the sha256 hash of
// a code is ever stored; the plaintext is emailed to the user and never
// persisted.

export const CODE_TTL_MINUTES = 10;
export const MAX_ATTEMPTS = 5;

/** Generate a random 6-digit code (000000–999999). */
export function generateCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

/** sha256 hex digest of a code. */
export async function hashCode(code: string): Promise<string> {
  const data = new TextEncoder().encode(code);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Constant-time comparison of two equal-length hex strings. */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export type CodeValidationResult =
  | "valid"
  | "invalid"
  | "expired"
  | "locked"
  | "not_found";

export interface CodeValidationOutcome {
  result: CodeValidationResult;
  codeId: string | null;
}

/**
 * Validate a submitted code against the latest active (unused, unexpired)
 * code for a user + purpose. Increments attempt_count on a wrong code and
 * locks out after MAX_ATTEMPTS. Marks the code used on success.
 *
 * `db` must be a service-role client (RLS blocks direct client access to
 * verification_codes).
 */
export async function validateCode(
  db: SupabaseClientLike,
  userId: string,
  purpose: string,
  code: string,
): Promise<CodeValidationOutcome> {
  const { data, error } = await db
    .from("verification_codes")
    .select("code_id, code_hash, attempt_count, expires_at, used_at")
    .eq("user_id", userId)
    .eq("purpose", purpose)
    .is("used_at", null)
    .order("created_at", { ascending: false })
    .limit(1);

  if (error != null) throw error;
  if (data == null || data.length === 0) {
    return { result: "not_found", codeId: null };
  }

  const row = data[0];
  const codeId = row.code_id as string;

  if ((row.attempt_count as number) >= MAX_ATTEMPTS) {
    return { result: "locked", codeId };
  }

  const expiresAt = new Date(row.expires_at as string);
  if (expiresAt.getTime() <= Date.now()) {
    return { result: "expired", codeId };
  }

  const expectedHash = row.code_hash as string;
  const actualHash = await hashCode(code);
  if (!timingSafeEqual(actualHash, expectedHash)) {
    await db
      .from("verification_codes")
      .update({ attempt_count: (row.attempt_count as number) + 1 })
      .eq("code_id", codeId);
    return { result: "invalid", codeId };
  }

  await db
    .from("verification_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("code_id", codeId);

  return { result: "valid", codeId };
}

/** Minimal structural type for the supabase-js client methods we use. */
export interface SupabaseClientLike {
  from(table: string): {
    select(columns: string): QueryBuilderLike;
    insert(values: Record<string, unknown>): Promise<{
      error: { message: string } | null;
    }>;
    update(values: Record<string, unknown>): {
      eq(column: string, value: string): Promise<{
        error: { message: string } | null;
      }>;
    };
  };
}

/** Chainable query builder subset (filters then a terminal await). */
export interface QueryBuilderLike {
  eq(column: string, value: string): QueryBuilderLike;
  is(column: string, value: null): QueryBuilderLike;
  order(column: string, options: { ascending: boolean }): QueryBuilderLike;
  limit(count: number): Promise<{
    data: Array<Record<string, unknown>> | null;
    error: { message: string } | null;
  }>;
}
