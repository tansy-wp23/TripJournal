// admin-reactivate-user — admin-only: reactivate a target user's account
// that was previously suspended by an administrator.
//
// POST /functions/v1/admin-reactivate-user
//   { "targetUserId": "<uuid>" }
//
// Requires a valid admin JWT (profile.role == 'admin' && status == 'active').
// On success: target profile.status -> 'active', deactivated_at cleared,
// and an admin_audit_log row is inserted (PB-05 "record status history").
// No signOut call is needed — the target's session was only gated
// client-side while suspended, never revoked on reactivation (mirrors
// account-reactivate-confirm's own reasoning for self-service
// reactivation).
//
// ADMIN_MODULE_IMPLEMENTATION_PLAN.md Phase 7. Same two-client
// architecture as admin-suspend-user / account-deactivate-confirm.

import { createClient } from "npm:@supabase/supabase-js@2.112.0";

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
      data: { user: caller },
      error: callerError,
    } = await supabase.auth.getUser();
    if (callerError || !caller) return json({ error: "Unauthorized" }, 401);

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { data: callerProfile, error: callerProfileError } = await supabaseAdmin
      .from("profiles")
      .select("role, status")
      .eq("user_id", caller.id)
      .maybeSingle();
    if (callerProfileError) throw callerProfileError;
    if (!callerProfile || callerProfile.role !== "admin" || callerProfile.status !== "active") {
      return json({ error: "Forbidden" }, 403);
    }

    const { targetUserId } = await req.json();
    if (typeof targetUserId !== "string" || targetUserId.length === 0) {
      return json({ error: "targetUserId is required" }, 400);
    }

    const { data: targetProfile, error: targetError } = await supabaseAdmin
      .from("profiles")
      .select("status")
      .eq("user_id", targetUserId)
      .maybeSingle();
    if (targetError) throw targetError;
    if (!targetProfile) return json({ error: "target_not_found" }, 404);

    // Defense-in-depth mirror of admin-suspend-user's checks: the button is
    // already hidden unless status === suspended (Phase 5), but a
    // privileged endpoint shouldn't rely on that alone.
    if (targetProfile.status !== "suspended") {
      return json({ error: "not_suspended" }, 400);
    }

    const { error: updateError } = await supabaseAdmin
      .from("profiles")
      .update({ status: "active", deactivated_at: null })
      .eq("user_id", targetUserId);
    if (updateError) throw updateError;

    const { error: auditError } = await supabaseAdmin.from("admin_audit_log").insert({
      admin_user_id: caller.id,
      target_type: "user",
      target_id: targetUserId,
      action: "reactivate",
    });
    if (auditError) throw auditError;

    return json({ ok: true });
  } catch (err) {
    console.error("admin-reactivate-user error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});
