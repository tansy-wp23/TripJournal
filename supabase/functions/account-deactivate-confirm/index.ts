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

    const outcome = await validateCode(supabase, user.id, "deactivation", code);
    if (outcome.result !== "valid") {
      return json({ error: `invalid_code:${outcome.result}` }, 400);
    }

    // Set the profile to deactivated.
    const { error: updateError } = await supabase
      .from("profiles")
      .update({ status: "deactivated", deactivated_at: new Date().toISOString() })
      .eq("user_id", user.id);
    if (updateError) throw updateError;

    // Terminate all of the user's sessions (Architecture Decision 3).
    await supabase.auth.admin.signOut(user.id);

    return json({ ok: true });
  } catch (err) {
    console.error("account-deactivate-confirm error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});