# Community Trip Sharing Parity Design

## Goal

Make sharing another user's published trip behave like sharing the owner's own published trip.

## User Interface

Replace the single Share icon in `PublicTripViewScreen` with a More options menu. The menu contains:

- **Share link** — opens the device sharing interface with only `tripjournal://trip/<trip-id>`.
- **Copy trip ID** — copies only the raw Trip ID to the clipboard and displays `Trip ID copied`.

The public trip remains read-only. No edit, publish, unpublish, or delete actions are added.

## Behaviour

Both actions use the selected public trip's existing ID. Sharing must not add the trip title, instructions, a subject, or any other text. Copying must not include the URI scheme or surrounding text.

## Error Handling

The existing Community loading and unavailable-trip behaviour remains unchanged. Clipboard confirmation is displayed only after copying completes. Link delivery remains the responsibility of the selected external sharing application.

## Testing

Widget tests will verify that:

1. The public trip screen exposes both menu actions.
2. **Share link** sends only the direct TripJournal link and no subject.
3. **Copy trip ID** copies only the raw ID and displays the confirmation message.
4. The public trip screen still has no edit, add, or delete actions.

## Scope

This change is limited to Community public-trip sharing. It does not change trip visibility, deep-link routing, Community lookup, or the owner's existing sharing behaviour.
