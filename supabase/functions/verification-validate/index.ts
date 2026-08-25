// verification-validate — check a submitted code without consuming it.
//
// POST /functions/v1/verification-validate
//   { "purpose": "deactivation" | "reactivation" | "deletion", "code": "123456" }
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

    // User-scoped client: identity verification ONLY. Built with the anon
    // key and the caller's own JWT as Authorization — this is what makes
    // auth.getUser() correctly identify who's calling.
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

    // Service-role client: bypasses RLS for the verification_codes read.
    // IMPORTANT: do NOT override Authorization here. Postgres/PostgREST
    // determines the RLS role from the JWT actually sent in the
    // Authorization header, not from which key was passed to createClient()
    // — overriding it with the user's JWT (as the previous version did)
    // silently defeats the service-role bypass and still hits RLS as
    // 'authenticated'. Leaving Authorization unset here lets the client
    // default to the service role key itself, which carries role:
    // service_role and correctly bypasses RLS.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { purpose, code } = await req.json();
    if (
      purpose !== "deactivation" &&
      purpose !== "reactivation" &&
      purpose !== "deletion"
    ) {
      return json(
        { error: "purpose must be 'deactivation', 'reactivation', or 'deletion'" },
        400,
      );
    }
    if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
      return json({ error: "code must be a 6-digit string" }, 400);
    }

    const outcome = await validateCode(supabaseAdmin, user.id, purpose, code);
    return json({ result: outcome.result });
  } catch (err) {
    console.error("verification-validate error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});