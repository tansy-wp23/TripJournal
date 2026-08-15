# User Management module

Authentication, account lifecycle, profile management, and the reusable
verification-code (OTP) component for TripJournal.

## Architecture at a glance

Supabase Auth owns **Google OAuth + sessions + the `auth.users` / `auth.identities`
tables**. This module owns only the two things Supabase Auth has no concept of:

| Entity | Where it lives | Why it's custom |
|---|---|---|
| `Profile` | `public.profiles` | Holds `status` (active/deactivated/suspended) and app-specific fields (display name, avatar, role). Supabase Auth only knows email + identity. |
| `VerificationCode` | `public.verification_codes` | One-time codes emailed to confirm an action (deactivation/reactivation). Supabase Auth has no OTP feature. |

**`LinkedProvider` and `Session` are deliberately NOT built as custom tables** —
Supabase Auth's `auth.identities` (linked providers) and its own session/JWT/refresh
token handling replace them. We don't duplicate what Supabase Auth does correctly.

## How sign-in / deactivation / reactivation work

1. **Sign-in** — `SupabaseAuthRepository` uses the **native ID-token flow**
   (`GoogleSignIn().signIn()` → `supabase.auth.signInWithIdToken(...)`), *not*
   `signInWithOAuth`/deep links. This is the only Google provider.
2. **Profile lookup** — `SupabaseProfileRepository.getProfile()` fetches the
   `Profile` row by `auth.uid()`. A Postgres `handle_new_user` trigger
   (SECURITY DEFINER) auto-creates an `active` profile on first Google sign-up;
   `createProfileIfMissing()` is only a defensive client-side fallback.
3. **Branch on `status`** — in `AuthController.status`:
   - `active` → `AuthStatus.authenticated` → app.
   - `deactivated` → `AuthStatus.deactivated` → reactivation code-entry screen.
   - `suspended` (admin-imposed) → `AuthStatus.suspended` → blocked (self-service
     reactivation must not clear an admin action).
4. **Code entry** — `CodeEntryScreen` is reusable for both purposes
   (`VerificationPurpose.deactivation` / `.reactivation`). Wrong code vs. expired
   code are distinct UI states via the `CodeValidationResult` enum.
5. **Confirm** — `account-deactivate-confirm` (sets `deactivated`, then
   `auth.admin.signOut()` everywhere) and `account-reactivate-confirm` (sets
   `active`, clears `deactivated_at` — no sign-out, the session was only gated).

## Client-side vs. server-side responsibility

- **Supabase Auth** issues the JWT and knows the user is who they say they are.
- **The App (`AuthController.status`)** is the *client-side gate*: a deactivated user
  still has a valid session, so the app fetches `Profile.status` right after sign-in
  and refuses to navigate them in. This is Architecture Decision 7.
- **RLS** (`profiles`) restricts each user to their own row.

## The repository layer

Screens/controllers depend on abstract interfaces (`AuthRepository`,
`ProfileRepository`, `VerificationCodeRepository`,
`AccountLifecycleRepository`, `ProfileAvatarStorage`). `lib/data/` holds both the
mock implementations (offline / tests) and the real `Supabase*` implementations.
The single swap point is `lib/data/user_management_repository_locator.dart`.

## Edge Functions (privileged server logic)

`verify_jwt = false` in `supabase/config.toml` — each function verifies the caller's
JWT itself via `auth.getUser()`. Each uses a **two-client** pattern:

- an **anon-key + user-JWT** client for identity verification only; and
- a **service-role client** (no JWT override) for `verification_codes` reads/writes
  and `auth.admin.signOut()`.

Overriding `Authorization` with the user JWT on the service-role client silently
defeats the RLS bypass (PostgREST then applies the JWT's `authenticated` role) —
do **not** do that.

Codes are **sha256-hashed** before storage (never plaintext). `validateCode()` is
non-destructive; only the `account-*-confirm` functions call `consumeCode()`
*after* their side effects succeed.

## Cross-module: excluding deactivated / suspended users

A deactivated user still holds a valid Supabase session/JWT (Supabase Auth doesn't
know about `Profile.status`). Any module whose RLS only checks `auth.uid()` would
still let them read/write data. The shared `is_active_user()` Postgres function
(Phase 8) fixes this:

```sql
-- add to your table's RLS policy:
... and is_active_user()
```

**Module owners, please adopt it** on your data tables (trips, journal entries,
health logs, etc.). Note: this module's *own* `profiles` **SELECT** policy is
intentionally *not* gated by `is_active_user()` — `AuthController` must be able to
read a `deactivated`/`suspended` user's own profile to apply the client-side gate.
Only `profiles` UPDATE is gated (a non-active user can't mutate their row;
reactivation is server-side).

## Security notes

- OTP: 6 digits (10^6 ≈ 20 bits of entropy), 10-minute TTL — see "Open issues"
  below for the entropy trade-off.
- `attempt_count` lockout after 5 wrong attempts on `verification-validate`.
- `verification-send` / `verification-resend` are **rate-limited** (one code per
  user+purpose per 60s) to prevent email spamming.

## Testing

- Mock-backed unit tests for all four repositories (`test/mock_*_repository_test.dart`).
- Controller tests (`test/auth_controller_test.dart`) for the sign-in status routing.
- Widget tests for the OTP input (`test/otp_code_input_test.dart`) and code-entry
  screen (`test/code_entry_screen_test.dart`).
- Real-Supabase tests (`test/supabase_profile_repository_test.dart`,
  `test/supabase_verification_code_repository_test.dart`,
  `test/profile_supabase_mapper_test.dart`) use a mock HTTP client, so they never
  touch `Supabase.instance`.

## Open issues / deferred (Phase 8 stretch items)

- **Stronger deactivation gate (stretch):** a Supabase Auth Hook ("Customize Access
  Token") can reject token issuance for `deactivated`/`suspended` users server-side,
  which is stronger than the client-side + RLS approach. **Deferred** — adds real
  complexity (a Postgres function in the token-minting path) for a free-tier agent.
- **OTP entropy:** 6 digits is low; a longer code or a fallback (e.g. 8 digits, or
  TOTP) would improve security. Left as-is for MVP to match a "6-digit code" UX.
- **Rate-limiting** is on send/resend only (attempt_count covers validate). Consider
  account-wide send caps if abuse is observed.
- **FuncReq audit:** `USER_MANAGEMENT_IMPLEMENTATION_PLAN.md` references a
  `FuncReq.md` (checklist 1.1.1–1.3.4) but **no such file exists in the repo** — the
  end-to-end requirements traceability is incomplete. Flagged for the team.
