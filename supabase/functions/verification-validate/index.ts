// verification-validate — check a submitted code without consuming it.
//
// POST /functions/v1/verification-validate
//   { "purpose": "deactivation" | "reactivation", "code": "123456" }
//
// Requires a valid user JWT. Returns { result: "valid" | "invalid" |
// "expired" | "locked" | "not_found" }. Does NOT mark the code used — the
// account-*-confirm functions do that after applying their side effects.

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

    const { purpose, code } = await req.json();
    if (purpose !== "deactivation" && purpose !== "reactivation") {
      return json({ error: "purpose must be 'deactivation' or 'reactivation'" }, 400);
    }
    if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
      return json({ error: "code must be a 6-digit string" }, 400);
    }

    const outcome = await validateCode(supabase, user.id, purpose, code);
    return json({ result: outcome.result });
  } catch (err) {
    console.error("verification-validate error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});