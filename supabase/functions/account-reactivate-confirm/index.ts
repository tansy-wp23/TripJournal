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
import { validateCode } from "../_shared/codes.ts";

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
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) return json({ error: "Unauthorized" }, 401);

    const { code } = await req.json();
    if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
      return json({ error: "code must be a 6-digit string" }, 400);
    }

    const outcome = await validateCode(supabase, user.id, "reactivation", code);
    if (outcome.result !== "valid") {
      return json({ error: `invalid_code:${outcome.result}` }, 400);
    }

    // Set the profile back to active and clear deactivated_at.
    const { error: updateError } = await supabase
      .from("profiles")
      .update({ status: "active", deactivated_at: null })
      .eq("user_id", user.id);
    if (updateError) throw updateError;

    return json({ ok: true });
  } catch (err) {
    console.error("account-reactivate-confirm error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});