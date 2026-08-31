# TripJournal Action Hierarchy and Interface Polish

## Goal

Complete the TripJournal UI redesign by restructuring actions, icons, headers,
menus, and dense control areas across both the user app and Admin. The result
must communicate priority and purpose without relying on a row of unexplained
icons. Existing behavior, navigation destinations, widget keys, controllers,
repositories, Supabase data, and Light/Dark/System theme support remain intact.

## Confirmed scope

Included:

- Authenticated and guest user screens
- Trip, Entry, Map, Community, Profile, Settings, forms, and supporting screens
- Admin dashboard, user management, issue reports, audit logs, monitoring,
  health, AI requests, and error screens
- App bars, page headers, contextual toolbars, menus, filters, buttons, dialogs,
  empty/error states, touch feedback, and icon semantics
- Android phone layouts first, including narrow and landscape layouts; Web
  remains responsive and usable
- Independent Light and Dark mode validation

Excluded:

- Database, model, repository, controller, authentication, or business-rule
  changes
- New user or Admin capabilities
- A new logo, launcher icon, or third-party icon package
- A separate desktop-only Admin information architecture

## Selected approach

Use one application-wide action hierarchy rather than merely moving excess
icons into overflow menus.

1. **Navigation layer:** back, close, root destinations, and the full page
   title.
2. **Primary action layer:** one obvious action for the page when one exists,
   preferably as a labelled button rather than an icon.
3. **Context layer:** search, filtering, sorting, and view controls placed next
   to the content they affect.
4. **Secondary action layer:** less frequent actions in a labelled overflow
   menu or action sheet.
5. **Destructive layer:** delete, trash, sign-out, suspension, and destructive
   account actions visually separated from routine actions and protected by
   existing confirmations.

An app bar contains the navigation affordance, an untruncated title whenever
space permits, and no more than one trailing primary action or overflow entry.
Standard back and close controls may remain icon-only. Other standalone icons
must have an unambiguous platform-standard meaning plus a tooltip and semantic
label.

## Shared component system

Create focused reusable UI pieces under the existing shared UI structure:

- `AppPageHeader` for an optional eyebrow, title, supporting text, and one
  labelled primary action
- `AppContentToolbar` for search, filter, sort, result count, and active-filter
  feedback
- `AppActionMenu` for labelled secondary actions with consistent icons and
  grouping
- `AppActionTile` for action sheets and navigation cards with icon, title,
  supporting text, and chevron or state
- `AppDestructiveAction` for visually separated destructive menu rows or
  buttons
- shared icon sizes and action-spacing tokens using the existing theme and
  spacing foundations

The components expose callbacks and child content only. They do not read
repositories or own domain state. Existing screens continue to obtain state
from their current providers.

Icons remain Flutter Material vector icons so the app adds no asset or package
dependency. One hierarchy level uses one visual style: outline icons for
routine actions and filled icons only for selected navigation or explicit
status emphasis. Visible icons use shared small, regular, and feature sizes;
all controls retain at least a 48 dp Android touch target.

## User app design

### Trip detail

- App bar: Back, full Trip title, and one `More trip actions` menu.
- Entries/Map remains the local segmented control below the title region.
- Search and Filter move into an Entries content toolbar and disappear on Map
  because they affect Entries only. Active filters show count and a textual
  clear action.
- Edit Trip, publish/unpublish, share link, Export PDF, and Food showcase appear
  as labelled rows in the trip action menu.
- Move to Trash appears after a divider as the final destructive row and keeps
  the existing confirmation.
- Report an issue moves out of the primary action row into the same menu's Help
  section.
- Existing widget keys remain attached to the equivalent interactive controls.

### Entry detail and journal surfaces

- Entry detail shows Edit as the single primary action when appropriate.
- Export and Move to Trash use a labelled overflow menu; destructive treatment
  is separated.
- Timeline row actions remain contextual and do not duplicate page-level
  actions.
- Search and mood/date filters use the shared content toolbar, with visible
  active state and clear action.

### Trips, Community, Profile, Settings, and forms

- Trips and Community keep search/sort/filter controls adjacent to their lists,
  not mixed with account or navigation controls.
- Profile edit remains a clear page-level action; Settings and Recently Deleted
  remain labelled navigation tiles.
- Form app bars contain navigation and title only. Save/Done uses the existing
  labelled primary action location and preserves loading and validation states.
- Place selection keeps Cancel/Confirm semantics explicit; map-only controls
  retain tooltips and accessible names.
- Photo viewers may retain conventional close and playback icons, with labelled
  semantics and consistent target sizes.

## Admin design

Admin uses the same Sky & Aurora theme, component shapes, icon sizing, spacing,
and action rules, while keeping a denser information presentation than the
consumer journal screens.

### Admin dashboard

- App bar: `Admin Dashboard` and one account overflow menu containing Sign out.
- Manage Users, Issue Reports, Audit Log, and Monitoring move from five
  unexplained app-bar icons into labelled dashboard navigation cards.
- Existing metric cards remain data-first. Navigation cards are visually
  distinct from metrics so counts are not mistaken for buttons.
- Health warnings use icon, text, and status colour together; colour is never
  the only signal.

### Admin lists and monitoring

- Search, status/severity/module/date filters, result count, and clear filters
  live in a shared content toolbar below the page header.
- Clear filters becomes a labelled contextual action rather than an isolated
  app-bar glyph.
- Links such as Failed requests become labelled page actions or navigation
  tiles, depending on available width.
- On narrow screens, dense filters collapse into a labelled Filter action and
  bottom sheet. On wider Web layouts they may remain visible inline.
- Status chips use consistent icon, label, colour, and selected treatment.
- Data rows and cards preserve the current information and navigation behavior;
  this work does not alter queries, retries, exports, or administrative actions.

### Admin detail and destructive actions

- User, report, error, and request details use sectioned surfaces with a clear
  reading order.
- Suspend, reactivate, retry, resolve, and similar state-changing actions keep
  visible text and existing confirmations or required remarks.
- Destructive actions are separated from routine navigation and never presented
  as an unlabeled toolbar icon.

## Responsive behavior

- At narrow phone widths, the app bar never competes with a long title for a row
  of actions.
- Page-level actions wrap or move below the title; content toolbars adapt from
  inline controls to labelled compact buttons or sheets.
- Web and tablet widths use a centered maximum content width and can display
  search and filters inline without changing their semantics.
- Landscape layouts preserve safe areas and ensure fixed controls do not cover
  scroll content.
- Dynamic text scaling may increase header height or wrap labelled actions; it
  must not clip titles or reduce touch targets.

## Accessibility and interaction

- Icon-only controls have descriptive tooltips and semantic names.
- Selected, expanded, active-filter, disabled, loading, and destructive states
  are conveyed by more than colour.
- Touch targets are at least 48 by 48 dp on Android with stable pressed feedback.
- Focus and screen-reader order follow the visual order: navigation, title,
  primary action, context controls, then content.
- Menus and sheets use labelled rows; decorative icons beside visible labels do
  not duplicate screen-reader announcements.
- Existing confirmation and error flows remain in place. No operation is
  triggered merely by opening a menu or action sheet.

## Data and error behavior

The redesign does not modify data flow. Existing providers remain the source of
truth and receive the same callbacks. Loading, empty, filtered-empty,
recoverable-error, and unavailable states retain current behavior but use the
shared visual hierarchy. Retry appears only where the existing controller can
retry safely. Administrative mutations and destructive user actions retain all
current confirmations and feedback.

## Testing and verification

- Add widget tests for the shared action components before implementation.
- Update Trip detail tests to assert the reduced app bar, contextual Entries
  toolbar, labelled action menu, and separated destructive action.
- Update Admin dashboard and monitoring tests to assert labelled navigation and
  contextual filtering while preserving existing keys and callbacks.
- Run targeted tests after each user or Admin screen group.
- Run `flutter analyze --no-pub` and the complete Flutter test suite before
  completion.
- Manually verify user and Admin flows on Android in Light and Dark modes.
- Check narrow phone, large phone, landscape, large text, and usable Web widths.
- Do not create or modify cloud data during visual verification.

## Implementation order

1. Shared action hierarchy components and icon/action tokens
2. Trip detail and Entry detail action restructuring
3. Trips, Community, Profile, Settings, forms, and supporting user screens
4. Admin dashboard navigation and account actions
5. Admin list, monitoring, filter, detail, and destructive-action polish
6. Cross-screen responsive, accessibility, Light/Dark, and regression pass
