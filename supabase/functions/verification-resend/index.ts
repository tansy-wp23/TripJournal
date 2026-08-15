// verification-resend — invalidate the prior code and send a fresh one.
//
// POST /functions/v1/verification-resend
//   { "purpose": "deactivation" | "reactivation" }
//
// Requires a valid user JWT. Thin wrapper around the same logic as
// verification-send (which already invalidates prior unused codes), so this
// just delegates to it. Kept as a separate endpoint so the client has a
// distinct "resend" semantic and the plan's function list is satisfied.

import { createClient } from "npm:@supabase/supabase-js@2.112.0";
import {
  CODE_TTL_MINUTES,
  generateCode,
  hashCode,
  isRateLimited,
} from "../_shared/codes.ts";
import { sendCodeEmail } from "../_shared/email.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Missing bearer token" }, 401);
    }

    // User-scoped client: identity verification + profile lookup only.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) return json({ error: "Unauthorized" }, 401);

    // Service-role client: bypasses RLS. Only used for verification_codes
    // writes below, always scoped to the verified user.id from above.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { purpose } = await req.json();
    if (purpose !== "deactivation" && purpose !== "reactivation") {
      return json({ error: "purpose must be 'deactivation' or 'reactivation'" }, 400);
    }

    // Rate-limit: one code per user+purpose per window, to prevent
    // OTP/email spam (Phase 8 security pass). Fail-open inside isRateLimited()
    // — a read error never blocks a legitimate send.
    if (await isRateLimited(supabaseAdmin, user.id, purpose)) {
      return json(
        {
          error: "A code was sent too recently. Please wait before requesting another.",
          rate_limited: true,
        },
        429,
      );
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("email")
      .eq("user_id", user.id)
      .single();
    if (profileError || !profile) {
      return json({ error: "Profile not found" }, 404);
    }

    // Invalidate any prior unused codes for this user+purpose.
    await supabaseAdmin
      .from("verification_codes")
      .update({ used_at: new Date().toISOString() })
      .eq("user_id", user.id)
      .eq("purpose", purpose)
      .is("used_at", null);

    const code = generateCode();
    const codeHash = await hashCode(code);
    const expiresAt = new Date(Date.now() + CODE_TTL_MINUTES * 60 * 1000);

    const { error: insertError } = await supabaseAdmin.from("verification_codes").insert({
      user_id: user.id,
      code_hash: codeHash,
      purpose,
      expires_at: expiresAt.toISOString(),
    });
    if (insertError) throw insertError;

    await sendCodeEmail({ to: profile.email, code, purpose });

    return json({ ok: true, expires_at: expiresAt.toISOString() });
  } catch (err) {
    console.error("verification-resend error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});