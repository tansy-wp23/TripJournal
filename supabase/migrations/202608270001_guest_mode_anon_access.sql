-- ============================================================================
-- Guest mode: allow the Supabase anon role to read public trips and their
-- child data (entries, health logs, meals). This enables unauthenticated
-- users to browse the community feed (Guest Mode + Deep Link Sharing plan,
-- Phase 1).
--
-- Strategy: replace the existing TO authenticated public SELECT policies
-- (from migration 202608260001) with policies that cover both authenticated
-- and anon, using the exact same USING clauses. Also grant SELECT to anon
-- on each table.
-- ============================================================================

-- 1. Grant anon SELECT on the relevant tables.
--    (authenticated already has SELECT from prior migrations.)
GRANT SELECT ON TABLE public.trips TO anon;
GRANT SELECT ON TABLE public.journal_entries TO anon;
GRANT SELECT ON TABLE public.health_logs TO anon;
GRANT SELECT ON TABLE public.meals TO anon;

-- 2. Replace trips public policy to include anon
DROP POLICY IF EXISTS "trips_select_public" ON public.trips;
CREATE POLICY "trips_select_public" ON public.trips
  FOR SELECT
  TO authenticated, anon
  USING (
    is_public = true
    AND deleted_at IS NULL
  );

-- 3. Replace journal_entries public policy to include anon
DROP POLICY IF EXISTS "entries_select_public" ON public.journal_entries;
CREATE POLICY "entries_select_public" ON public.journal_entries
  FOR SELECT
  TO authenticated, anon
  USING (
    EXISTS (
      SELECT 1 FROM public.trips AS t
      WHERE t.id = trip_id
        AND t.is_public = true
        AND t.deleted_at IS NULL
    )
  );

-- 4. Replace health_logs public policy to include anon
DROP POLICY IF EXISTS "health_logs_select_public" ON public.health_logs;
CREATE POLICY "health_logs_select_public" ON public.health_logs
  FOR SELECT
  TO authenticated, anon
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

-- 5. Replace meals public policy to include anon
DROP POLICY IF EXISTS "meals_select_public" ON public.meals;
CREATE POLICY "meals_select_public" ON public.meals
  FOR SELECT
  TO authenticated, anon
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

-- Existing owner-scoped policies (_select_own / _insert_own / _update_own /
-- _delete_own) are untouched. They use auth.uid() = user_id, which is NULL
-- for anon, so anon can never see private data or write anything — the
-- GRANT SELECT above only enables reads, and anon has no INSERT/UPDATE/
-- DELETE grant on any of these tables.
