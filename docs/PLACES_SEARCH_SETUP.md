# Place search and reverse-geocoding setup

The entry location picker has two independent halves:

- **Dropping a pin** works with no setup at all — tapping the map records the coordinate
  immediately (`lib/features/location/osm_place_picker_map.dart`). Map rendering needs no key
  either; see [`MAP_LOCATION_SETUP.md`](MAP_LOCATION_SETUP.md).
- **Typing a search**, and **naming a dropped pin**, both go through the `places-proxy` Supabase
  Edge Function, which calls OpenStreetMap's **Nominatim** geocoder. Until the function is deployed,
  search shows *"Place search is temporarily unavailable"* and pins silently save as bare
  coordinates with no place name.

This document covers deploying that function.

## Why a server proxy at all, when Nominatim needs no key

Nominatim itself needs no API key — so the proxy isn't hiding a credential the way it did for
Google. It still earns its place for reasons that matter more with a free, shared, best-effort
service than with a paid API:

- **A single, correctly identified caller.** Nominatim's [usage policy](https://operations.osmfoundation.org/policies/nominatim/)
  requires a stable User-Agent with a real contact route, and caps the *whole application* at
  1 request/second — not per user. That's only enforceable from one place; every device calling
  Nominatim directly would each need its own throttle and there'd be no way to keep the aggregate
  under the ceiling.
- **A response cache.** The policy asks that results be cached, not re-fetched on every identical
  query. The proxy keeps an in-memory cache (24h TTL) per instance for exactly this.
- **The existing per-user rate limit and auth requirement** carry over unchanged from before — they
  protect the proxy itself from abuse, independent of what's behind it.

If Nominatim's public instance is ever rate-limiting the app in practice, the fix is
`NOMINATIM_BASE_URL` (below), not removing the proxy.

## 1. Nothing to enable, nothing to enable billing for

There is no Google Cloud project, no API to enable, no billing account. Skip straight to deploying.

## 2. No server key needed by default

Nominatim's public instance (`https://nominatim.openstreetmap.org`) needs no credential. Two
secrets are optional and only needed if the defaults don't fit:

| Secret | Default | When to set it |
|---|---|---|
| `NOMINATIM_BASE_URL` | `https://nominatim.openstreetmap.org` | Point at a self-hosted or paid Nominatim instance once usage outgrows the public instance's policy limits. |
| `NOMINATIM_USER_AGENT` | `TripJournal/1.0 (+https://github.com/tripjournal/tripjournal)` | Change if the contact URL in the default goes stale — the policy requires this to stay accurate. |

## 3. Deploy

Requires owner/admin access to the Supabase project and a `SUPABASE_ACCESS_TOKEN` personal access
token. Run from the **repository root** so `supabase/config.toml` is honoured:

```powershell
npx supabase link --project-ref <project-ref>
npx supabase db push
npx supabase functions deploy places-proxy
```

Apply the database migrations **before** deploying the function — the proxy fails closed when its
durable rate-limit RPC is unavailable, so deploying first would temporarily make every lookup
return a service-unavailable response. If overriding the defaults from Step 2:

```powershell
npx supabase secrets set NOMINATIM_BASE_URL=<your-instance-url>
npx supabase secrets set NOMINATIM_USER_AGENT="TripJournal/1.0 (+https://your-contact-url)"
```

One thing that differs from most other functions in this repo:

- **Do not pass `--no-verify-jwt`.** `supabase/config.toml` sets `verify_jwt = true` for
  `places-proxy`; it is one of the few functions here that requires a signed-in caller. Muscle
  memory from other functions in this repo is wrong for this one.

## 4. Verify

Confirm the function is reachable. Before deployment this returns **404**; after, it returns
**401**, which is the correct response to an unauthenticated call and therefore the success
signal:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  https://<project-ref>.supabase.co/functions/v1/places-proxy \
  -H "Content-Type: application/json" -d '{"action":"search","query":"test"}'
```

Then, in the running app while signed in:

1. Open an entry, add a location, and type at least two characters. Suggestions appear, up to five.
2. Drop a pin somewhere recognisable. The selection should resolve from bare coordinates to a named
   place.
3. Save the entry, reopen it, and confirm the place name persisted.

The function's own test suite needs Deno:

```bash
deno test supabase/functions/places-proxy/places_proxy_test.ts --allow-env
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| *"Place search is temporarily unavailable"* | Function not deployed, or a non-2xx from Nominatim. Probe for 404 first. |
| *"Please sign in to search for places"* | Deployed and reachable, but the caller had no valid Supabase session. |
| *"The place service is temporarily unavailable"* | HTTP 500 from the function — check the function logs; there's no server key to misspell anymore, so this is more likely a Supabase config problem (`SUPABASE_URL`/`SUPABASE_ANON_KEY`). |
| *"Too many place requests"* | The proxy's own durable per-user rate limit: 20 requests per 60 seconds. |
| *"Location search is temporarily unavailable"* | The durable rate-limit RPC or its database is unavailable. Requests fail closed and do not call Nominatim. |
| Results are slow or occasionally time out | The public Nominatim instance has no SLA (see its usage policy) — expected occasionally, not a bug to chase. If it's frequent, move to a paid/self-hosted instance via `NOMINATIM_BASE_URL`. |

Query length is validated at 2–120 characters; shorter input is rejected before any Nominatim call.
A `resolve` `placeId` must match `[NWR]<digits>` (e.g. `N123456`) — the encoded OSM type + id pair
Nominatim's `/lookup` endpoint expects.
