# Trip Management Activity Diagrams Design

## Objective

Replace the existing contents of `D:\Download\activitydg (1).drawio` with fifteen editable UML activity diagrams based on the final UC200-UC214 use case description tables in the assessment report. Each use case will occupy one Draw.io page.

## Page Structure

- Use A4 portrait pages with one diagram per page.
- Name each page using the use case ID and name, for example `UC200 Create Trip`.
- Use vertical swimlanes titled `User` and `System`.
- Add an `External Sharing Application` swimlane only for UC212.
- Place the diagram title above the swimlanes.
- Keep actions short and use the same terminology as the use case tables.

## Visual Conventions

- Start node: solid black circle with a red outline, matching the existing diagram.
- End node: UML final-state circle with a red outline, matching the existing diagram.
- Activity: white rectangular node with a dark border and slightly rounded corners.
- Decision and merge: diamond nodes with labelled outgoing conditions.
- Main-flow connectors: dark orthogonal arrows.
- Swimlane headers: light blue fill with bold black text.
- Alternate flows: enclose each alternate branch inside a transparent rectangle with a red border. Label the top-left corner `Alternate Flow A1`, `Alternate Flow A2`, and so on.
- Use red only for alternate-flow frames and the existing start/end outline convention. Error actions remain readable black text on white nodes.

## Flow Modelling Rules

- Model the Basic Flow in numbered sequence across the User and System lanes.
- Convert validation, availability, confirmation and ownership checks into decisions only where they change the path.
- Use Message Section wording only as short system feedback actions when a branch requires it.
- Apply Constraint Section rules as decision conditions rather than separate activity nodes.
- Show referenced use cases as call activities labelled with their use case ID and name; do not duplicate the referenced diagram.
- Return corrective alternate paths to the nearest valid user action where appropriate. Cancellation, inaccessible data and unrecoverable errors end the current use case.

## Pages

1. UC200 Create Trip
2. UC201 Edit Trip Details
3. UC202 View Trip List
4. UC203 View Trip Details
5. UC204 Move Trip to Trash
6. UC205 View Trip Trash
7. UC206 Browse Community Trips
8. UC207 Enter Trip Details
9. UC208 Update Cover Photo
10. UC209 Search or Filter Trip
11. UC210 Publish Trip
12. UC211 Unpublish Trip
13. UC212 Share Published Trip Link
14. UC213 Restore Trip
15. UC214 View Community Trip Details

## Alternate Flow Coverage

- UC200: invalid information; save failure.
- UC201: invalid updated information; save failure.
- UC202: empty trip list; loading failure.
- UC203: unavailable trip; loading failure.
- UC204: cancellation; move failure.
- UC205: empty Trash; loading failure or expired recovery period.
- UC206: empty Community feed; loading failure.
- UC207: invalid required details.
- UC208: cancelled or unavailable photo selection; storage failure.
- UC209: no matching results; clear criteria.
- UC210: cancellation; publication failure.
- UC211: unpublish failure.
- UC212: sharing cancellation; unavailable sharing service.
- UC213: expired recovery period; conflicting trip dates.
- UC214: trip no longer public or unavailable; loading failure.

## Deliverable and Safety

- Create a timestamped backup of the original Draw.io file before replacement.
- Keep all nodes, labels, swimlanes, frames and connectors editable.
- Validate the generated XML and confirm that the final file contains exactly fifteen pages with the expected names.
- Export all pages to images or PDF for visual inspection before delivery when a compatible renderer is available.
