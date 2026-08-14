// verification-send — generate a 6-digit code, store its hash, and email it.
//
// POST /functions/v1/verification-send
//   { "purpose": "deactivation" | "reactivation" }
//
// Requires a valid user JWT (Authorization: Bearer <access_token>).
// Sends to the authenticated user's email from their Profile row.

import { createClient } from "npm:@supabase/supabase-js@2.112.0";
import { CODE_TTL_MINUTES, generateCode, hashCode } from "../_shared/codes.ts";
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

    const { purpose } = await req.json();
    if (purpose !== "deactivation" && purpose !== "reactivation") {
      return json({ error: "purpose must be 'deactivation' or 'reactivation'" }, 400);
    }

    // Fetch the user's email from their profile.
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("email")
      .eq("user_id", user.id)
      .single();
    if (profileError || !profile) {
      return json({ error: "Profile not found" }, 404);
    }

    // Invalidate any prior unused codes for this user+purpose.
    await supabase
      .from("verification_codes")
      .update({ used_at: new Date().toISOString() })
      .eq("user_id", user.id)
      .eq("purpose", purpose)
      .is("used_at", null);

    const code = generateCode();
    const codeHash = await hashCode(code);
    const expiresAt = new Date(Date.now() + CODE_TTL_MINUTES * 60 * 1000);

    const { error: insertError } = await supabase.from("verification_codes").insert({
      user_id: user.id,
      code_hash: codeHash,
      purpose,
      expires_at: expiresAt.toISOString(),
    });
    if (insertError) throw insertError;

    await sendCodeEmail({ to: profile.email, code, purpose });

    return json({ ok: true, expires_at: expiresAt.toISOString() });
  } catch (err) {
    console.error("verification-send error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});