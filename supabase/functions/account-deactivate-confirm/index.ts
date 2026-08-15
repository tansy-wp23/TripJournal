// account-deactivate-confirm — validate a deactivation code, set the profile
// to deactivated, and terminate the user's sessions.
//
// POST /functions/v1/account-deactivate-confirm
//   { "code": "123456" }
//
// Requires a valid user JWT. On success the profile.status becomes
// 'deactivated' and the user is signed out everywhere (Architecture
// Decision 3 — "terminate session on deactivation" via the Admin API).

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

    // Service-role client: bypasses RLS. Authorization is intentionally
    // left unset/default here (service role key), NOT overridden with the
    // user's JWT — overriding it would silently defeat the RLS bypass.
    // This is also required for admin.signOut(), which only works with an
    // actual service-role session.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { code } = await req.json();
    if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
      return json({ error: "code must be a 6-digit string" }, 400);
    }

    const outcome = await validateCode(supabaseAdmin, user.id, "deactivation", code);
    if (outcome.result !== "valid") {
      return json({ error: `invalid_code:${outcome.result}` }, 400);
    }

    // Set the profile to deactivated.
    const { error: updateError } = await supabaseAdmin
      .from("profiles")
      .update({ status: "deactivated", deactivated_at: new Date().toISOString() })
      .eq("user_id", user.id);
    if (updateError) throw updateError;

    // Terminate all of the user's sessions (Architecture Decision 3).
    await supabaseAdmin.auth.admin.signOut(user.id);

    // Only mark the code used once every side effect above has succeeded —
    // if anything failed, an earlier `throw`/return already exited, leaving
    // the code valid for the user to retry with, no resend needed.
    if (outcome.codeId) {
      await consumeCode(supabaseAdmin, outcome.codeId);
    }

    return json({ ok: true });
  } catch (err) {
    console.error("account-deactivate-confirm error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});