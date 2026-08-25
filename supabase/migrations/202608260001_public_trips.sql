-- ============================================================================
-- Public trip publishing: adds is_public visibility, publisher identity
-- snapshot, and cross-user SELECT policies for trips + child tables.
-- ============================================================================

-- 1. New columns on trips table
ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS is_public              boolean      NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS published_at           timestamptz,
  ADD COLUMN IF NOT EXISTS publisher_display_name text,
  ADD COLUMN IF NOT EXISTS publisher_avatar_url   text;

-- Partial index for the community feed query (only public, non-deleted trips)
CREATE INDEX IF NOT EXISTS trips_public_published_idx
  ON public.trips (published_at DESC)
  WHERE is_public = true AND deleted_at IS NULL;

-- 2. Grant clients permission to UPDATE the new columns.
--    Existing grant (from 202608050002) only covers: title, cover_photo_url,
--    start_date, end_date, notes. Without this, client-side updates to
--    is_public silently fail.
GRANT UPDATE (is_public, published_at, publisher_display_name, publisher_avatar_url)
  ON TABLE public.trips TO authenticated;

-- Also grant update on summary (it was in tripEditableFieldsToSupabaseRow but
-- was not in the column grant — it worked only because the mock didn't enforce
-- column grants. If summary updates already work in Supabase mode, this is a
-- no-op safe idempotent grant).
GRANT UPDATE (summary) ON TABLE public.trips TO authenticated;

-- 3. RLS: any signed-in user can SELECT public, non-deleted trips
DROP POLICY IF EXISTS "trips_select_public" ON public.trips;
CREATE POLICY "trips_select_public" ON public.trips
  FOR SELECT
  TO authenticated
  USING (
    is_public = true
    AND deleted_at IS NULL
  );

-- 4. RLS: any signed-in user can SELECT journal entries belonging to public trips
DROP POLICY IF EXISTS "entries_select_public" ON public.journal_entries;
CREATE POLICY "entries_select_public" ON public.journal_entries
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.trips AS t
      WHERE t.id = trip_id
        AND t.is_public = true
        AND t.deleted_at IS NULL
    )
  );

-- 5. RLS: health_logs of entries belonging to public trips
DROP POLICY IF EXISTS "health_logs_select_public" ON public.health_logs;
CREATE POLICY "health_logs_select_public" ON public.health_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.journal_entries AS e
      JOIN public.trips AS t ON t.id = e.trip_id
      WHERE e.id = entry_id
        AND t.is_public = true
        AND t.deleted_at IS NULL
    )
  );

-- 6. RLS: meals of health_logs of entries belonging to public trips
DROP POLICY IF EXISTS "meals_select_public" ON public.meals;
CREATE POLICY "meals_select_public" ON public.meals
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.health_logs AS hl
      JOIN public.journal_entries AS e ON e.id = hl.entry_id
      JOIN public.trips AS t ON t.id = e.trip_id
      WHERE hl.id = health_log_id
        AND t.is_public = true
        AND t.deleted_at IS NULL
    )
  );
