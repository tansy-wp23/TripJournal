# Place search and reverse-geocoding setup

The entry location picker has two independent halves:

- **Dropping a pin** works with no setup beyond the map rendering key. Tapping the map records the
  coordinate immediately (`lib/features/location/place_picker_screen.dart:100-106`).
- **Typing a search**, and **naming a dropped pin**, both go through the `places-proxy` Supabase
  Edge Function. Until it is deployed, search shows *"Place search is temporarily unavailable"* and
  pins silently save as bare coordinates with no place name.

This document covers deploying that function. For the map **tiles**, see
[`MAP_LOCATION_SETUP.md`](MAP_LOCATION_SETUP.md) — a separate concern with separate keys.

## Why a server proxy at all

The Places key is a *server* credential. Routing through an Edge Function keeps it off every user's
device, lets the function require a signed-in Supabase user, and applies a per-user rate limit that a
client-side key could not. The function never logs request bodies and never echoes provider text back
to the client, so queries and coordinates stay out of error paths.

## 1. Enable two Google APIs

`supabase/functions/places-proxy/index.ts` calls two different Google products on two different hosts:

| Action | Endpoint | Product to enable |
|---|---|---|
| `search` | `places.googleapis.com/v1/places:searchText` | **Places API (New)** |
| `resolve` | `places.googleapis.com/v1/places/{id}` | **Places API (New)** |
| `reverse` | `maps.googleapis.com/maps/api/geocode/json` | **Geocoding API** |

Enable **both**. Note that "Places API (New)" is a distinct product from the legacy "Places API" —
enabling the legacy one will not serve these endpoints.

Enabling only Places leaves search working while every dropped pin stays unnamed, because naming a
pin is the Geocoding call. That asymmetry is the fastest way to diagnose a half-finished setup.

Enabling an API and permitting a key to call it are **two separate switches**, and both are needed.
Google distinguishes them in the error: `SERVICE_DISABLED` means the API is not enabled on the
project, while `API_KEY_SERVICE_BLOCKED` means the key's API restriction list excludes it. The proxy
strips those details before replying, so read them by calling Google directly with the key.

Billing must be enabled on the Cloud project, as with the rendering keys.

## 2. Create a server key

This key lives on Supabase's servers and is never shipped to a device, so its restrictions differ
from the Android rendering key:

1. **APIs & Services → Credentials → + Create Credentials → API key.**
2. **Application restrictions: None.** An Android/package restriction would break it — the caller is
   a Supabase server, not the app. IP restriction is impractical because Edge Function egress
   addresses are not stable.
3. **API restrictions: Restrict key**, selecting exactly *Places API (New)* and *Geocoding API*.

With no application restriction available, the API restriction is the entire security boundary. Do
not leave this key unrestricted, and do not reuse the Android rendering key here.

## 3. Set the secret and deploy

Requires owner/admin access to the Supabase project and a `SUPABASE_ACCESS_TOKEN` personal access
token. Run from the **repository root** so `supabase/config.toml` is honoured:

```powershell
npx supabase link --project-ref <project-ref>
npx supabase secrets set GOOGLE_PLACES_SERVER_KEY=<the-server-key>
npx supabase functions deploy places-proxy
```

Set the secret **before** deploying, so the function is never briefly live without its key.

Two things that differ from the other functions in this repo:

- **Do not pass `--no-verify-jwt`.** `supabase/config.toml` sets `verify_jwt = true` for
  `places-proxy`; it is the only function here that requires a signed-in caller. Every other function
  was deployed with that flag, so the muscle memory is wrong for this one.
- **The secret name must match exactly.** A misspelling surfaces as an opaque HTTP 500 with the
  variable name deliberately withheld from the response body, making it indistinguishable from any
  other internal error without reading the function logs.

## 4. Verify

Confirm the function is reachable. Before deployment this returns **404**; after, it returns **401**,
which is the correct response to an unauthenticated call and therefore the success signal:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  https://<project-ref>.supabase.co/functions/v1/places-proxy \
  -H "Content-Type: application/json" -d '{"action":"search","query":"test"}'
```

Then, in the running app while signed in:

1. Open an entry, add a location, and type at least two characters. Suggestions appear, up to five.
2. Drop a pin somewhere recognisable. The selection should resolve from bare coordinates to a named
   place — this exercises the Geocoding half.
3. Save the entry, reopen it, and confirm the place name persisted.

The function's own test suite needs Deno:

```bash
deno test supabase/functions/places-proxy/places_proxy_test.ts --allow-env
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| *"Place search is temporarily unavailable"* | Function not deployed, or a non-2xx from Google. Probe for 404 first. |
| *"Please sign in to search for places"* | Deployed and reachable, but the caller had no valid Supabase session. |
| *"The place service is temporarily unavailable"* | HTTP 500 from the function — most often a missing or misspelled `GOOGLE_PLACES_SERVER_KEY`. |
| Search works, pins stay unnamed | Geocoding API not enabled. |
| Search fails while Geocoding works | The legacy *Places API* was enabled instead of *Places API (New)*. They are adjacent entries in the console and easy to confuse. |
| *"Too many place requests"* | Per-user rate limit, 20 requests per 60 seconds. It is held in memory per isolate, so it resets on cold start. |

Query length is validated at 2–120 characters; shorter input is rejected before any Google call.
