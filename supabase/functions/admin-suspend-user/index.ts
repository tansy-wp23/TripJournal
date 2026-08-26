// admin-suspend-user — admin-only: suspend a target user's account.
//
// POST /functions/v1/admin-suspend-user
//   { "targetUserId": "<uuid>", "reason": "<string>" }
//
// Requires a valid admin JWT (profile.role == 'admin' && status == 'active').
// On success: target profile.status -> 'suspended', the target's sessions
// are terminated (auth.admin.signOut — PB-04 "terminate active session"),
// and an admin_audit_log row is inserted (PB-04 "record audit log").
//
// ADMIN_MODULE_IMPLEMENTATION_PLAN.md Phase 7, Architecture Decision 4.
// Mirrors account-deactivate-confirm's two-client architecture (User
// Management module, supabase/functions/account-deactivate-confirm/index.ts):
// a user-scoped anon client for identity verification ONLY, and a
// service-role client for every privileged read/write, so the RLS bypass
// isn't silently defeated by a JWT override.

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

    // User-scoped client: identity verification ONLY.
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

    // Service-role client: bypasses RLS for every privileged step below.
    // Authorization is intentionally left unset (service-role key), NOT
    // overridden with the caller's JWT — overriding it would silently
    // defeat the RLS bypass. Also required for admin.signOut(), which only
    // works with an actual service-role session.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // Verify the caller is an active admin. Not done via the is_admin_user()
    // RPC — the service-role client has no auth.uid() session for that
    // function to evaluate — so the caller's own row is queried directly
    // instead.
    const { data: callerProfile, error: callerProfileError } = await supabaseAdmin
      .from("profiles")
      .select("role, status")
      .eq("user_id", caller.id)
      .maybeSingle();
    if (callerProfileError) throw callerProfileError;
    if (!callerProfile || callerProfile.role !== "admin" || callerProfile.status !== "active") {
      return json({ error: "Forbidden" }, 403);
    }

    const body = await req.json();
    const { targetUserId, reason } = body;
    if (typeof targetUserId !== "string" || targetUserId.length === 0) {
      return json({ error: "targetUserId is required" }, 400);
    }
    if (reason !== undefined && reason !== null && typeof reason !== "string") {
      return json({ error: "reason must be a string" }, 400);
    }

    const { data: targetProfile, error: targetError } = await supabaseAdmin
      .from("profiles")
      .select("role, status")
      .eq("user_id", targetUserId)
      .maybeSingle();
    if (targetError) throw targetError;
    if (!targetProfile) return json({ error: "target_not_found" }, 404);

    // Defense-in-depth: AdminUserDetailScreen (Phase 5) already hides the
    // Suspend button for these cases, but a privileged endpoint must not
    // rely on client-side state alone (ADMIN_MODULE_IMPLEMENTATION_PLAN.md
    // Phase 5 decision 2 — reject with a message, not a silent no-op, in
    // case the caller's screen data is stale).
    if (targetProfile.role === "admin") {
      return json({ error: "cannot_suspend_admin" }, 400);
    }
    if (targetProfile.status === "suspended") {
      return json({ error: "already_suspended" }, 400);
    }

    const now = new Date().toISOString();
    const { error: updateError } = await supabaseAdmin
      .from("profiles")
      .update({ status: "suspended", deactivated_at: now })
      .eq("user_id", targetUserId);
    if (updateError) throw updateError;

    // Terminate the target's active session (PB-04 "terminate active
    // session") — same auth.admin.signOut pattern
    // account-deactivate-confirm uses for self-deactivation.
    await supabaseAdmin.auth.admin.signOut(targetUserId);

    const { error: auditError } = await supabaseAdmin.from("admin_audit_log").insert({
      admin_user_id: caller.id,
      target_type: "user",
      target_id: targetUserId,
      action: "suspend",
      reason: reason ?? null,
    });
    if (auditError) throw auditError;

    return json({ ok: true });
  } catch (err) {
    console.error("admin-suspend-user error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});
