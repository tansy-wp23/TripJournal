# Implementation Plan — Inline Notes Editing & Photo Viewing

> Seventh companion file. Builds on the prior six plans. Read `CLAUDE.md` first.
>
> **Purpose:** three confirmed changes:
> 1. **Notes/Reminders inline editor** — tap the notes to edit ONLY the notes
>    (not the full trip form), with Save-confirm + discard-on-back guard
> 2. **Full-screen photo viewer** — tap a daily-journal thumbnail to view the
>    full image, with swipe between photos
> 3. **Multi-select photo upload** — daily journal entries ONLY (not trip cover);
>    enforce the existing 5-photo / 32 MB caps

---

## 1. Notes / Reminders Inline Editor

The trip-level Notes/Reminders field (from `_HOMEPAGE`, decision #4) becomes
directly editable by tapping it — a focused, notes-only edit that does NOT open
the full trip-edit form.

### Behaviour
- On the **trip view**, the Notes/Reminders display is **tappable**.
- Tapping it opens an editor scoped to **only the notes** — a text field for
  `trip.notes` and nothing else. The user cannot change title, dates, or cover
  photo from here.
- This is **distinct from the top-right edit icon**, which still opens the
  **full** trip-edit form (title, dates, cover, notes together). Two paths:
  - Tap notes → quick **notes-only** edit.
  - Tap edit icon → **full trip** edit.

### Save & discard (match the rest of the app — confirmed)
- **Save** the notes → show a confirmation dialog **"Save changes?"** →
  Confirm / Cancel. Confirm persists `trip.notes` via `TripRepository`
  (`updateTrip`); Cancel dismisses, keeping the edited text in the field.
- **Discard guard on back:** track a dirty flag for the notes editor. If the
  user changed the note text and presses back:
  - Dirty → prompt **"Discard changes?"** → Discard / Keep editing.
  - Not dirty → leave silently, no prompt.
- Implement the back-intercept (`PopScope`/`WillPopScope`) on the notes editor,
  same pattern as the entry editor in `_UX_POLISH`.

### Notes
- Respect the notes/text length handling from `_VALIDATION` (the journal/text
  caps). Show a character counter if near the limit.
- Empty notes are allowed (the field is optional).

---

## 2. Full-Screen Photo Viewer (daily journal)

Tapping a photo thumbnail in a daily journal entry opens it full-screen so the
user can actually see the image (thumbnails are small squares from `_UX_POLISH`).

### Behaviour
- In the **entry detail / daily journal**, each photo thumbnail is **tappable**.
- Tapping opens a **full-screen viewer** showing the image **fitted to the
  screen** (`BoxFit.contain` — the WHOLE image, not cropped like the square
  thumbnail).
- **Swipe between photos:** if the entry has multiple photos, the viewer
  supports horizontal swipe to move between them (e.g. a `PageView`), opening at
  the tapped photo's index.
- Dismiss via an **×** / tap-outside / system back → returns to the entry.
- Optional niceties (keep simple if time-constrained): pinch-to-zoom, a page
  indicator (e.g. "2 / 4"). Swipe navigation is the required part.
- Handle a missing/corrupt file with a placeholder in the viewer, not a crash.

---

## 3. Multi-Select Photo Upload — Daily Journal Entries ONLY

Let the user add several photos to a daily entry in one action. **This applies
to daily journal entries only — the trip cover photo stays single-select.**

### Entry photo picker (multi-select)
- Use `image_picker`'s **multi-image** method (e.g. `pickMultiImage`) for the
  daily-entry photo section, so the user can select multiple images at once.
- Append the chosen images to the entry's `photoPaths`.

### Enforce existing caps (from `_VALIDATION`) — must hold via multi-select too
- **Max 5 photos per entry.** The allowance depends on how many the entry
  already has (e.g. 2 existing → up to 3 more).
  - On return from the picker, if the selection would exceed 5, **do not
    silently drop** — accept up to the remaining allowance and **warn**:
    "You can add up to 5 photos per entry." (i.e. take the first N that fit and
    tell the user the rest were not added.)
  - Where the picker supports a selection limit, pass the remaining allowance so
    the user is guided up front; still enforce on return as the backstop.
- **Max 32 MB per photo.** Reject any oversized file with
  "This image is too large (max 32 MB)." Valid files in the same batch still
  get added.

### Trip cover photo — UNCHANGED (do NOT apply multi-select here)
- The trip cover uses the **single-image** picker (one cover image). Multi-select
  must NOT leak into the cover picker. This is a **separate code path** — the
  entry photo section and the cover photo section call different picker methods.
  Leave the cover picker exactly as it is.

---

## Suggested Build Order for Claude Code

```
Phase 1 → Notes inline editor: make trip.notes display tappable → notes-only
          editor (no other fields); Save-confirm dialog; dirty-tracking +
          discard-on-back guard (PopScope); keep the full-trip edit icon path
          separate and intact.
Phase 2 → Full-screen photo viewer: tap entry thumbnail → full-screen fitted
          image (BoxFit.contain); PageView swipe between the entry's photos;
          dismiss returns; corrupt-file placeholder.
Phase 3 → Multi-select upload for ENTRY photos (pickMultiImage); append to
          photoPaths; enforce 5-photo cap (accept up to remaining, warn on
          overflow) and 32 MB per-file limit. Leave trip cover picker as
          single-select — do not modify it.
Phase 4 → Tests: notes editor edits only notes & saves via confirm; back prompts
          discard only when dirty; full-screen viewer opens at tapped index and
          swipes between photos; multi-select respects 5-photo cap (overflow
          warned, not dropped silently) and 32 MB limit; cover picker remains
          single-select.
```

Run + commit after each phase.

---

## Cross-Cutting Notes

- **Notes-only means notes-only** — the inline notes editor must not expose or
  edit title/dates/cover. The full trip-edit form (edit icon) remains the place
  for those.
- **Consistent save/discard behaviour** — the notes editor uses the same
  Save-confirm + dirty/discard-guard pattern as the entry editor; no prompts
  when nothing changed.
- **Full-screen = whole image** (`contain`), unlike the square thumbnail
  (`cover`). Swipe between photos is required; zoom/indicator optional.
- **Multi-select is entry-only.** The trip cover stays single-select on its own
  code path — do not generalise multi-select across the app.
- **Caps always hold** — 5 photos / 32 MB per photo are enforced regardless of
  whether photos are added one-by-one or via multi-select; overflow is warned,
  never silently dropped.

---

*Keep this beside the other six plans in the repo root. Update as decisions
firm up.*
