// account-delete-confirm — validate a deletion code and permanently delete
// the user's account.
//
// POST /functions/v1/account-delete-confirm
//   { "code": "123456" }
//
// Requires a valid user JWT. On success the auth.users row is deleted, which
// cascades to profiles and verification_codes automatically (both have
// `on delete cascade` FKs from the Phase 6 migration). The code is only
// consumed AFTER the delete succeeds, so a failed delete leaves the code
// valid for a retry without a resend.
//
// Cross-module risk (flagged in PROGRESS.md): deletion only cascades cleanly
// if every module's tables that reference auth.users.id also specify
// `on delete cascade` (or an explicit anonymization strategy) on their own
// FKs. If Trip/Journal/Health Log don't, deleting a user could either fail
// outright or leave orphaned rows. This module can't fix that unilaterally —
// same category of cross-module dependency as the is_active_user() flag from
// Phase 8.

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
    // JWT, or the RLS bypass is silently defeated. This is also required
    // for admin.deleteUser(), which only works with an actual service-role
    // session.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { code } = await req.json();
    if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
      return json({ error: "code must be a 6-digit string" }, 400);
    }

    const outcome = await validateCode(supabaseAdmin, user.id, "deletion", code);
    if (outcome.result !== "valid") {
      return json({ error: `invalid_code:${outcome.result}` }, 400);
    }

    // Permanently delete the user. This cascades to profiles and
    // verification_codes (both have `on delete cascade` FKs).
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(
      user.id,
    );
    if (deleteError) throw deleteError;

    // Only mark the code used once the delete above has succeeded — if it
    // failed, an earlier `throw` already exited, leaving the code valid for
    // the user to retry with, no resend needed.
    if (outcome.codeId) {
      await consumeCode(supabaseAdmin, outcome.codeId);
    }

    return json({ ok: true });
  } catch (err) {
    console.error("account-delete-confirm error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});