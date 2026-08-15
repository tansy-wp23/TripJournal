// account-reactivate-confirm — validate a reactivation code and set the
// profile back to active.
//
// POST /functions/v1/account-reactivate-confirm
//   { "code": "123456" }
//
// Requires a valid user JWT. On success the profile.status becomes 'active'
// and deactivated_at is cleared. No signOut call is needed here — the
// session was never revoked (Architecture Decision 7); it was only gated
// client-side until the code was confirmed.

import { createClient } from "npm:@supabase/supabase-js@2.112.0";
import { consumeCode, validateCode } from "../_shared/codes.ts";

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

    // User-scoped client: identity verification ONLY.
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

    // Service-role client: bypasses RLS. Authorization intentionally left
    // as the default service-role key — do not override with the user's
    // JWT, or the RLS bypass is silently defeated.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { code } = await req.json();
    if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
      return json({ error: "code must be a 6-digit string" }, 400);
    }

    const outcome = await validateCode(supabaseAdmin, user.id, "reactivation", code);
    if (outcome.result !== "valid") {
      return json({ error: `invalid_code:${outcome.result}` }, 400);
    }

    // Set the profile back to active and clear deactivated_at.
    const { error: updateError } = await supabaseAdmin
      .from("profiles")
      .update({ status: "active", deactivated_at: null })
      .eq("user_id", user.id);
    if (updateError) throw updateError;

    // Only mark the code used once the profile update above has succeeded —
    // if it failed, an earlier `throw` already exited, leaving the code
    // valid for the user to retry with, no resend needed.
    if (outcome.codeId) {
      await consumeCode(supabaseAdmin, outcome.codeId);
    }

    return json({ ok: true });
  } catch (err) {
    console.error("account-reactivate-confirm error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});