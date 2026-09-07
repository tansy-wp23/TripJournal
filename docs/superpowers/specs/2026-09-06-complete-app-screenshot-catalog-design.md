# Complete TripJournal Page Screenshot Catalog Design

## Goal

Create a Word document that presents every safely reachable TripJournal page through clear mobile screenshots. Each catalog page will contain one application screenshot, an English title, and one short English description.

## Output

The existing blank document at `D:\Download\TripJournal ScreenShots.docx` will become a standalone screenshot catalog with:

- A title page named **TripJournal Application Screenshots**.
- A short introduction explaining the User and Admin coverage.
- Pages grouped by module.
- One mobile screenshot per Word page.
- A concise English page title and one-sentence description.
- Consistent margins, typography, image sizing, and page numbers.

The expected length is approximately 30 to 40 pages.

## Page Coverage

### Authentication and Guest

- Guest Home.
- User Sign In.
- Profile Onboarding, verification, reactivation, or suspension pages only when naturally reachable without changing the current account state.

### Trip Management and Community

- Trips Home.
- Create Trip.
- Edit Trip Details.
- Trip Details Entries tab.
- Trip Details Map tab.
- Recently Deleted Trips.
- Community Trips.
- Community Trip Details.

### Wellness Journal Location and Recap

- Create Journal Entry.
- Edit Journal Entry.
- Journal Entry Details.
- Place Picker.
- Photo Viewer.
- Food Showcase.
- Trip Notes and Summary.
- Trip Wellness Summary.

### Profile and Settings

- User Profile.
- Edit Profile.
- Settings.
- Deactivate Account.
- Delete Account.
- About or Legal content only if the app presents it as an independent page; temporary dialogs are not separate catalog entries.

### Admin Management and Monitoring

- Administrator Sign In.
- Administrator Dashboard.
- Admin Account.
- User Management.
- User Account Details.
- System Monitoring.
- System Health.
- AI Request Monitoring.
- Failed AI Requests.
- System Error Log.
- Administrator Audit Log.
- Issue Reports.
- Issue Report Details.
- Monitoring Report.

## Excluded Function States

The catalog will not create separate screenshots for temporary interface states, including:

- Overflow menus.
- Search fields or filter sheets after expansion.
- Publish, Unpublish, Delete, Restore, Suspend, or other confirmation dialogs.
- Share link, Copy trip ID, save, or export confirmation messages.
- Camera and gallery source sheets.
- Other transient snackbars, pop-ups, and system share surfaces.

Full-screen tabs that present materially different page content, such as Entries and Map within Trip Details, remain separate screenshots.

## Data and Safety Rules

- Capture user pages from the current Supabase account.
- Do not modify existing real trips.
- If content must be created for a missing page, create or edit data only inside a trip whose title contains `TEST`.
- Do not complete destructive or account-state-changing actions.
- Do not expose API keys, Supabase session data, signing credentials, or passwords.
- Avoid showing another user's personal information in Admin screenshots. Search for the current account where possible; otherwise omit the unsafe page.
- If a page cannot be reached without destructive changes, unavailable permissions, or another person's credentials, omit it and report the omission instead of fabricating a screenshot.

## Capture and Editing Workflow

1. Inventory the independent pages against this specification.
2. Navigate the installed Android APK and capture each page at the emulator's native resolution.
3. Use only safe, reversible navigation and avoid temporary function-state captures.
4. Insert screenshots into the Word document in module order with an English title and one-sentence description.
5. Render the completed document and inspect every page for readability and layout defects.
6. Correct any defects and repeat the render check before delivery.

## Success Criteria

- Every safely reachable independent User and Admin page is represented once.
- Entries and Map receive separate screenshots because they present different full-page content.
- No temporary menu, dialog, filter, or confirmation state receives its own page.
- Every screenshot has an accurate English title and short description.
- No existing real trip or account state is changed.
- No private credentials or another user's personal information appear in the final document.
- Every Word page is readable and free of clipping, overlap, or broken pagination.
