# Gemini AI setup (`gemini-proxy`)

All three AI features — daily wellbeing advice, food photo detection, and the
AI trip summary — call Gemini through the **`gemini-proxy` Edge Function**, not
directly. The API key lives in Supabase secrets and never reaches the app.

## Why the key is not in `.env`

`.env` is declared as a Flutter asset in `pubspec.yaml`, so it is bundled into
the APK verbatim:

```
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep '\.env'
      189  ...  assets/flutter_assets/.env
```

Anyone holding the APK can read it. That is fine for `SUPABASE_ANON_KEY` (it is
designed to be public, and RLS does the real work) but not for a **billable**
Gemini credential: an extracted key spends the project owner's quota, and
Google disables keys it detects as leaked.

## Why the function is action-based, not a passthrough

`gemini-proxy` exposes four named actions and builds the Gemini request itself.
It deliberately does **not** forward a caller-supplied Gemini body — that would
just move the open door from "anyone with the APK" to "any signed-in user",
who could then run arbitrary prompts on the same key. Consequences worth
knowing:

- The model names are pinned server-side (`GEMINI_TEXT_MODEL`,
  `GEMINI_SUMMARY_MODEL`), so changing model is a secret change, not an app
  release.
- The tone/safety system instructions live in the function, where the client
  cannot edit them out. The contract they encode is documented on
  `DailyAdviceService` and `TripSummaryService` in the app.
- Changing a prompt means redeploying the function.

## One-time setup

```powershell
# 1. Set the key as a secret (never commit it, never put it in .env)
npx supabase secrets set GEMINI_API_KEY=your-key-from-google-ai-studio

# 2. Deploy. Do NOT pass --no-verify-jwt: an unauthenticated caller here
#    spends your Gemini quota.
npx supabase functions deploy gemini-proxy
```

Optional secrets, all with sensible defaults in the function:

| Secret | Default | Purpose |
|---|---|---|
| `GEMINI_TEXT_MODEL` | `gemini-3.6-flash` | Advice + food detection. Must stay vision-capable. |
| `GEMINI_SUMMARY_MODEL` | `gemini-3.1-flash-lite` | Trip summaries — longer, less latency-sensitive, cheaper. |
| `GEMINI_BASE_URL` | Google's v1beta endpoint | Point at a mock or regional endpoint. |

### Model pinning is a quota decision

Free-tier quota is granted per model *name*, not per key. This project has been
burned twice:

- `gemini-2.0-flash` silently regressed to `429 RESOURCE_EXHAUSTED`
  (`limit: 0`) once Google wound its free tier down, even with billing enabled.
- `gemini-flash-latest` then exhausted its *daily* cap in ordinary use. Probing
  showed the alias returning 429 while `gemini-3.7-flash` — the very model it
  resolves to — answered normally, so an alias carries its own quota bucket.

Pin a concrete version, and verify with a real request before changing it:
being listed by `ListModels` does not mean it is callable (`gemini-2.5-flash`
still lists, but returns 404 "no longer available to new users"). Current names
are at https://ai.google.dev/gemini-api/docs/models — they change.

## Verifying the deploy

A `404` before deploying and a **`401` after** is the success signal — 401 means
the function exists and is correctly refusing unauthenticated callers:

```powershell
curl -i -X POST "https://<project-ref>.supabase.co/functions/v1/gemini-proxy"
```

Then, in the app signed in with `--dart-define=BACKEND_MODE=supabase`:

1. **Admin → System Health → Gemini AI → Test Connection** — asks the function
   whether its key works. It uses `ListModels`, not `generateContent`, so a
   health check never spends generation quota.
2. Open an entry with a health log → **Generate advice**.
3. Add a meal photo → **Detect from photo**.
4. Open a trip with entries → **Generate summary**.

## Behaviour notes

- **Mock mode is unchanged.** With `BACKEND_MODE=mock` (the default, and what
  `flutter test` runs) the locators return the offline mock AI services and
  nothing calls Gemini. AI features therefore need a signed-in Supabase
  session, since the function authenticates the caller.
- **Food detection sends a Storage URL, not bytes.** The function fetches the
  photo itself, which avoids pushing a base64-inflated image through a function
  request. It accepts only `journal-photos` URLs on this project's own origin,
  under the *calling user's* folder — that rejects both SSRF attempts and one
  user reading another's photos.
- **Retries live in the function now.** `503 UNAVAILABLE` ("high demand") was
  measured at roughly a coin flip during one spike; the function retries
  429/5xx with exponential backoff and never retries 400/401/403/404, which
  fail identically every time.
- **Failures degrade, they do not block.** Detection returns no result and the
  user types the meal manually; advice and summaries surface a retry.
