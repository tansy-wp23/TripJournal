-- Journal persistence: the two columns the models carry but the tables lack.
--
-- Found while implementing SupabaseJournalRepository. `JournalEntry.location`
-- (a GeoTag: lat/lng plus place name, address and place id) and
-- `Meal.photoPath` are both written by shipped UI — the entry location picker
-- and the meal photo / AI food-detection flow — but neither
-- `public.journal_entries` nor `public.meals` has anywhere to put them.
--
-- Without these columns the repository would have to drop both fields on every
-- write. That failure is silent: the entry saves, the app shows the location it
-- still holds in memory, and the loss only surfaces after a restart. Adding the
-- columns is therefore a prerequisite for BACKEND_MODE=supabase, not a
-- nice-to-have.
--
-- Additive and idempotent: both columns are nullable with no default, so
-- existing rows and any code still running against the old shape are unaffected.

-- Stored as a single jsonb blob rather than five scalar columns because GeoTag
-- is written and read as one unit — no query in the app filters or sorts on a
-- part of it, and the map tab reads whole entries. Keys are GeoTag's own
-- `toJson()` names (camelCase: latitude, longitude, placeName,
-- formattedAddress, placeId) so the model stays the single serialization of
-- this type; a second snake_case mapping would be one more thing to drift.
alter table public.journal_entries
  add column if not exists location jsonb;

comment on column public.journal_entries.location is
  'GeoTag as JSON: latitude, longitude, placeName, formattedAddress, placeId. '
  'Null for an entry with no location tagged.';

-- REVERSES A DELIBERATE DECISION -- decided 2026-08-19, keep the column.
--
-- `tripjournal_schema.sql` originally stated: "Food/meal photos: NOT persisted
-- (photo is a transient input to AI detection only) -- meals has no photo
-- column". True when written. The app has since moved past it: `Meal` carries
-- `photoPath` ("the photo is the user's, and a failed guess is no reason to
-- throw it away"), the PDF export prints meal photos, and the trip slideshow
-- has a food-photo toggle.
--
-- Resolved in favour of persisting: the alternative was deleting three shipped
-- features to honour a note the code had already outgrown. The header of
-- `tripjournal_schema.sql` has been updated in the same change so the two no
-- longer contradict each other -- that file is the baseline a fresh project is
-- rebuilt from, and a stale comment there is how this gets re-litigated in six
-- months. Cost accepted: one Storage object per photographed meal.
--
-- Named photo_url, not photo_path, to match `journal_entries.photo_urls` and
-- `trips.cover_photo_url`: once photos live in Supabase Storage the string is a
-- URL, not a device path.
alter table public.meals
  add column if not exists photo_url text;

comment on column public.meals.photo_url is
  'Storage URL of the photo this meal was logged from. Null for a meal typed '
  'in by hand. Kept even when AI detection failed to recognise the food.';
