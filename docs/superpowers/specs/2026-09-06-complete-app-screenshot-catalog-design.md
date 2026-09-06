# Complete TripJournal Screenshot Catalog Design

## Goal

Create a Word document that presents the complete TripJournal application through clear mobile screenshots. Each page will show one application page or meaningful function state together with a short English description.

## Output

The existing blank document at `D:\Download\TripJournal ScreenShots.docx` will be populated as a standalone screenshot catalog.

The document will use:

- A title page named **TripJournal Application Screenshots**.
- A short introduction explaining that the catalog covers user and administrator functions.
- Module divider headings.
- One screenshot per page at a readable phone-screen size.
- A concise English screen title and one-sentence description below each screenshot.
- Page numbers and consistent margins, typography, and spacing.

The expected length is approximately 45 to 60 pages, depending on which function states are available in the current account.

## Screenshot Organisation

### Authentication and Guest

- Guest home and Community access.
- User sign-in page.
- Account verification, reactivation, suspension, onboarding, deactivation, and deletion pages when they can be reached without changing the account state.

### Trip Management

- Trips home and search or status filtering.
- Create Trip form and cover-photo controls.
- Trip Details with Entries and Map tabs.
- Edit Trip form.
- Published and private trip action menus.
- Publish and Unpublish confirmation states.
- Share link and Copy trip ID actions.
- Move to Trash confirmation, Recently Deleted, and Restore confirmation states.

### Community and Sharing

- Community trip feed and destination search.
- Open trip by ID dialog.
- Another user's published trip details.
- Community Share link and Copy trip ID menu.
- Unavailable-trip feedback when it can be shown safely.

### Wellness Journal and Location

- Entry timeline, entry search, mood filter, and date filter.
- Create and Edit Entry pages.
- Mood, journal text, photo, health, meal, and AI food-detection controls.
- Location search, current-location action, map pin adjustment, accuracy notice, and confirmed location.
- Entry Details, AI advice, PDF export action, and Move to Trash confirmation.
- Photo viewer, meal detail, and Food Showcase.

### Trip Recap and PDF

- Trip notes or summary editor.
- Trip wellness statistics.
- Trip PDF export action and an available PDF preview or share state.

### Profile and Settings

- Profile overview and Edit Profile.
- Travel interests and personal details.
- Settings overview.
- Theme, journal reminder, health-data status, About, and Legal notices.
- Logout, deactivate-account, and delete-account confirmation or entry states without completing them.

### Admin Management and Monitoring

- Admin sign-in and dashboard.
- User list, search or filters, and user details.
- Suspend and Reactivate confirmation states without changing a real account.
- Monitoring hub, system health, AI request monitoring, failed AI requests, system error log, and audit log.
- Issue report list and issue report details.
- Monitoring report, date filtering, PDF export, and CSV export controls.
- Admin account and sign-out menu.

## Data and Safety Rules

- Capture the user-facing pages from the current Supabase account.
- Perform create or edit actions only inside a trip whose name contains `TEST`.
- Do not complete destructive or account-state-changing actions. Open their confirmation page or dialog, capture it, and cancel.
- Do not suspend, reactivate, deactivate, delete, publish, unpublish, trash, or restore non-TEST real data.
- Do not expose API keys, Supabase session data, signing credentials, or passwords.
- Mask other users' email addresses, IDs, and other personally identifying details in administrator screenshots before they enter the final report.
- If a page cannot be reached without a destructive state change, unavailable role, or new authentication, omit it and list the omission to the user rather than fabricating a screenshot.

## Capture and Editing Workflow

1. Inventory all reachable pages and function states against this specification.
2. Navigate the running Android application and capture screenshots at its native emulator resolution.
3. Use only safe, reversible interactions; cancel confirmation dialogs after capture.
4. Crop screenshots consistently to the application surface and mask private administrator data where required.
5. Insert the screenshots into the Word document in module order with titles and one-sentence descriptions.
6. Render the completed Word document to images and inspect every page for clipping, overlap, unreadable text, or poor screenshot sizing.
7. Correct any layout defects and repeat the render check before delivery.

## Success Criteria

- Every safely reachable TripJournal page and meaningful function state is represented.
- Every screenshot has an accurate English title and short description.
- The user and administrator modules use the same document style.
- No real non-TEST content is changed.
- No private credentials or other users' personal information appear in the final document.
- Every Word page is visually readable and free of layout defects.
