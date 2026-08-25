-- Journal + Health Tracking module — food rating.
--
-- Adds an optional 1–5 star rating to a meal, collected in the same
-- add/edit meal dialog as the existing name/calories/portion fields
-- (`IMPLEMENTATION_PLAN_RATING_LOCATION_SHOWCASE.md` §1). Purely descriptive
-- — nothing averages it into a trip-level score.

alter table public.meals
  add column if not exists rating smallint
    check (rating is null or (rating between 1 and 5));

comment on column public.meals.rating is
  '1-5 whole-star rating the user gives the meal. Null = not rated.';
