# Community Share Link and Copy Trip ID Design

## Goal

Make the sharing output for a published trip contain only its TripJournal deep link, and provide a separate action that copies only the trip ID.

## Scope

The change applies to the owner-facing Trip Details overflow menu for published trips.

- Keep the existing **Share link** menu item.
- Add **Copy trip ID** immediately beside the existing published-trip actions, in the same overflow menu.
- Do not add the new copy action to the Community Trip Details screen.
- Do not change publishing, unpublishing, Community browsing, or deep-link parsing.

## Interaction Design

### Share link

Selecting **Share link** opens the platform share sheet with exactly:

```text
tripjournal://trip/<trip-id>
```

No trip title, explanatory text, blank lines, or share subject is included.

### Copy trip ID

Selecting **Copy trip ID** copies exactly the underlying trip UUID, without the `tripjournal://trip/` prefix or surrounding text. The app then shows the confirmation message:

```text
Trip ID copied
```

## Visibility

Both **Share link** and **Copy trip ID** are visible only while the trip is published (`isPublic == true`). They disappear after the trip is unpublished.

## Implementation Boundary

- Use the existing `tripLinkFor(trip.id)` helper to generate the share value.
- Use Flutter's clipboard API to copy `trip.id`.
- Extend the existing trip overflow-menu action enum and selection handler.
- Keep the Community public-trip share button unchanged unless required to preserve compilation; this request concerns the owner Trip Details menu.

## Error Handling

Clipboard copying is local and requires no network request. On successful invocation, show the confirmation snackbar. Existing publication and deep-link lookup errors remain unchanged.

## Testing

Automated widget tests will verify that:

1. A published trip shows both **Share link** and **Copy trip ID**.
2. A private trip shows neither action.
3. Selecting **Copy trip ID** places only the raw trip ID on the clipboard and shows `Trip ID copied`.
4. The share payload helper returns only the deep link, preventing explanatory text from returning later.

Relevant existing link, publication, and Trip Details tests will be rerun after implementation.
