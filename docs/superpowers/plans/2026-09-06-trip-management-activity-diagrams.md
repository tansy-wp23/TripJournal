# Trip Management Activity Diagrams Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `D:\Download\activitydg (1).drawio` with fifteen editable activity-diagram pages that correspond one-to-one with UC200-UC214 in the final report.

**Architecture:** A small Python generator will build uncompressed Draw.io XML from structured per-use-case flow definitions. Shared functions will create A4 pages, swimlanes, UML activity nodes, decisions, orthogonal connectors and red alternate-flow frames. Structural tests will parse the generated XML and verify page names, node types, flow coverage and editability before the original file is replaced.

**Tech Stack:** Python 3 standard library, Draw.io `mxfile`/`mxGraphModel` XML, `unittest`, optional diagrams.net-compatible rendering.

## Global Constraints

- The final Draw.io file must contain exactly fifteen pages named for UC200-UC214.
- Every page must be A4 portrait and contain one activity diagram.
- Every diagram must contain `User` and `System` swimlanes; UC212 must also contain `External Sharing Application`.
- Alternate flows must be enclosed in transparent rectangles with red borders and labelled `Alternate Flow A1`, `Alternate Flow A2`, and so on.
- Main flow connectors must use dark orthogonal arrows.
- Start and final-state nodes must retain the original red-outline convention.
- Referenced use cases must appear as call activities without duplicating their internal flow.
- The original Draw.io file must be backed up before replacement.
- All generated nodes, text, frames and connectors must remain editable in Draw.io.

---

### Task 1: Encode the fifteen use-case flows

**Files:**
- Create: `.codex-drawio-work/activity_diagrams.py`
- Test: `.codex-drawio-work/test_activity_diagrams.py`

**Interfaces:**
- Produces: `USE_CASES: list[dict]`, where each dictionary contains `id`, `name`, `lanes`, `main_steps`, `decisions`, `alternate_flows`, and `references`.
- Consumes: UC200-UC214 Basic Flow, Alternate Flow, Message and Constraint sections from `D:\Download\202605 Final Assessment Deliverable Template.docx`.

- [ ] **Step 1: Write the flow-definition test**

```python
def test_all_use_cases_are_defined():
    assert [item["id"] for item in USE_CASES] == [f"UC{i}" for i in range(200, 215)]
    assert all(item["main_steps"] for item in USE_CASES)
    assert all(item["alternate_flows"] for item in USE_CASES)
    assert USE_CASES[12]["lanes"] == ["User", "System", "External Sharing Application"]
```

- [ ] **Step 2: Run the test and confirm the definitions are missing**

Run:

```powershell
& 'C:\Users\nicho\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest .codex-drawio-work/test_activity_diagrams.py -v
```

Expected: failure because `USE_CASES` has not been defined.

- [ ] **Step 3: Add the exact flow definitions**

Encode the following page-level paths:

- UC200: select Create Trip; display form; call UC207; optionally call UC208; preview; select Save; validate; decision valid; save and display trip. A1 returns invalid information to detail entry. A2 reports save failure and offers retry.
- UC201: select Edit; display existing details; call UC207; optionally call UC208; preview; select Save; validate title, overlap and journal-entry date coverage; save and display updated trip. A1 returns invalid changes to editing. A2 retains previous information and reports failure.
- UC202: open Home; retrieve active owned trips; decision trips available; display cards; browse; select trip; call UC203. A1 displays empty state and Create Trip option. A2 displays load error and Retry.
- UC203: select trip; retrieve owned active trip; decision accessible; display details and actions; select optional action; open selected function. A1 reports inaccessible trip. A2 offers Retry or Return to List.
- UC204: select Move to Trash; show confirmation; decision confirmed; move trip and related entries to recoverable Trash; remove from active and Community lists; refresh list. A1 closes confirmation without changes. A2 reports move failure.
- UC205: open Trip Trash; retrieve owned recoverable trips; decision data loaded; decision trips available; display trips and remaining recovery period; select Restore; call UC213. A1 displays empty state. A2 displays load error and Retry; expired items show recovery-period message and cannot start restoration.
- UC206: open Community; retrieve public non-trashed trips; decision data loaded; decision trips available or match search; display public cards; browse or search; select trip; call UC214. A1 displays empty state or no matches. A2 displays load error and Retry.
- UC207: enter title and destination; accept input; select start and end dates; display range; proceed to Save; validate required fields, title length and date order; decision valid; return valid details to UC200 or UC201. A1 identifies invalid field and returns to correction.
- UC208: select cover option; display photo sources; decision selection completed; select or capture supported image; preview; save parent form; decision storage successful; associate cover with trip. A1 keeps the existing cover or no cover. A2 reports update failure and retains the previous cover.
- UC209: open search/filter controls; display controls; enter title/destination or select status; apply criteria; decision matches found; display matching trips; browse results. A1 displays no-results message and Clear option. A2 clears criteria and restores the active list.
- UC210: select Publish to Community; show confirmation; decision confirmed; verify owner, private status and non-trashed state; decision publish successful; mark public and record publisher; include in Community; display Public status. A1 keeps trip private. A2 reports publication failure.
- UC211: select Unpublish; process request; decision successful; mark private; remove from Community; remove Public indicator; confirm change. A1 keeps trip public and reports failure.
- UC212: select Share Link; verify trip is public and sharing service exists; prepare title and Trip ID message; open sharing interface; decision user selects target; transfer message to external application; user completes sharing; external application handles delivery. A1 closes sharing without changes. A2 reports unavailable sharing service.
- UC213: select Restore; display confirmation; decision confirmed; check recovery period; decision not expired; check date overlap; decision no conflict; restore trip and journal entries; remove from Trash; refresh list. A1 reports expired recovery period and prevents restoration. A2 requests different dates and routes to date editing before restoration can be retried.
- UC214: select Community trip; retrieve latest public information; decision still public and found; decision load successful; display title, destination, dates, cover, publisher and shared content; review; optionally select Share; call UC212. A1 reports unavailable trip and returns to Community. A2 offers Retry.

- [ ] **Step 4: Run the flow-definition test**

Run the unittest command from Step 2.

Expected: all flow-definition tests pass.

- [ ] **Step 5: Commit the structured definitions and tests**

```powershell
git add -- .codex-drawio-work/activity_diagrams.py .codex-drawio-work/test_activity_diagrams.py
git commit -m "docs: define trip activity diagram flows"
```

---

### Task 2: Generate editable Draw.io pages with the approved style

**Files:**
- Modify: `.codex-drawio-work/activity_diagrams.py`
- Modify: `.codex-drawio-work/test_activity_diagrams.py`
- Modify: `D:\Download\activitydg (1).drawio`
- Create: `D:\Download\activitydg (1) Backup Before Trip Redesign.drawio`

**Interfaces:**
- Consumes: `USE_CASES` from Task 1.
- Produces: `build_drawio(use_cases: list[dict]) -> xml.etree.ElementTree.ElementTree` and `write_drawio(output_path: Path) -> None`.

- [ ] **Step 1: Write structural generation tests**

```python
def test_generated_file_has_expected_pages(tmp_path):
    output = tmp_path / "activity.drawio"
    write_drawio(output)
    root = ET.parse(output).getroot()
    assert root.tag == "mxfile"
    assert root.get("pages") == "15"
    assert [d.get("name") for d in root.findall("diagram")] == [
        f'{item["id"]} {item["name"]}' for item in USE_CASES
    ]

def test_every_page_has_required_activity_elements(tmp_path):
    output = tmp_path / "activity.drawio"
    write_drawio(output)
    for page in ET.parse(output).getroot().findall("diagram"):
        styles = [cell.get("style", "") for cell in page.iter("mxCell")]
        values = [cell.get("value", "") for cell in page.iter("mxCell")]
        assert any("shape=startState" in style for style in styles)
        assert any("shape=endState" in style for style in styles)
        assert any("shape=swimlane" in style for style in styles)
        assert any("strokeColor=#FF0000" in style for style in styles)
        assert any("Alternate Flow A" in value for value in values)
```

- [ ] **Step 2: Run the tests and confirm generation is missing**

Run the Task 1 unittest command.

Expected: generation tests fail because `write_drawio` has not been implemented.

- [ ] **Step 3: Implement shared XML builders**

Implement focused helpers with these signatures:

```python
def add_cell(root, *, cell_id, value="", style="", parent="1", vertex=False, edge=False,
             x=None, y=None, width=None, height=None, source=None, target=None): ...
def add_activity(root, lane_id, cell_id, label, x, y, width=220, height=52): ...
def add_decision(root, lane_id, cell_id, label, x, y): ...
def add_connector(root, cell_id, source, target, label="", red=False, points=None): ...
def add_alternate_frame(root, cell_id, label, x, y, width, height): ...
def build_page(use_case): ...
def build_drawio(use_cases): ...
def write_drawio(output_path): ...
```

Use uncompressed `<diagram><mxGraphModel><root>...</root></mxGraphModel></diagram>` pages. Set `pageWidth="827"`, `pageHeight="1169"`, `page="1"`, `grid="1"`, `guides="1"`, `connect="1"`, and `arrows="1"`.

- [ ] **Step 4: Apply the approved visual styles**

Use these Draw.io style strings:

```text
Swimlane: shape=swimlane;horizontal=0;startSize=38;fillColor=#DAE8FC;strokeColor=#6C8EBF;fontStyle=1;fontSize=14;html=1;rounded=0;
Activity: rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#4D4D4D;fontSize=12;arcSize=12;
Call activity: rounded=1;whiteSpace=wrap;html=1;fillColor=#E1D5E7;strokeColor=#9673A6;fontSize=12;arcSize=12;fontStyle=1;
Decision: rhombus;whiteSpace=wrap;html=1;fillColor=#FFF2CC;strokeColor=#D6B656;fontSize=11;
Start: ellipse;html=1;shape=startState;fillColor=#000000;strokeColor=#FF0000;
End: ellipse;html=1;shape=endState;fillColor=#000000;strokeColor=#FF0000;
Connector: edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;endArrow=block;endFill=1;strokeColor=#333333;fontSize=11;
Alternate frame: rounded=0;whiteSpace=wrap;html=1;fillColor=none;strokeColor=#FF0000;strokeWidth=2;verticalAlign=top;align=left;spacingTop=6;spacingLeft=8;fontColor=#CC0000;fontStyle=1;
```

- [ ] **Step 5: Back up and replace the Draw.io file**

Resolve and verify both absolute paths before copying. Copy the original file to `D:\Download\activitydg (1) Backup Before Trip Redesign.drawio`, then write the generated XML to `D:\Download\activitydg (1).drawio`.

- [ ] **Step 6: Run all structural tests**

Run the Task 1 unittest command.

Expected: all tests pass, the target file parses as XML, and every alternate branch has a red frame.

- [ ] **Step 7: Commit the generator and tests only**

```powershell
git add -- .codex-drawio-work/activity_diagrams.py .codex-drawio-work/test_activity_diagrams.py
git commit -m "docs: generate trip activity diagrams"
```

Do not add the external `D:\Download` Draw.io artifact to the repository.

---

### Task 3: Validate layout and final deliverable

**Files:**
- Inspect: `D:\Download\activitydg (1).drawio`
- Inspect: `.codex-drawio-work/activity_diagrams.py`
- Inspect: `.codex-drawio-work/test_activity_diagrams.py`

**Interfaces:**
- Consumes: the generated Draw.io file from Task 2.
- Produces: a validated fifteen-page editable deliverable and a retained backup of the original file.

- [ ] **Step 1: Run a complete XML audit**

Check exact page count and names, unique cell IDs, valid edge source/target IDs, swimlane counts, one start and at least one end node per page, and sequential alternate labels matching each use case definition.

- [ ] **Step 2: Export or open the file for visual inspection**

Use an available diagrams.net renderer or open the file in Draw.io. Inspect every page for clipped labels, overlapping nodes, connectors crossing text, alternate branches outside their red frames, and content outside A4 bounds.

- [ ] **Step 3: Correct layout defects and rerun the audit**

Adjust only the affected page coordinates or frame dimensions, regenerate the file, and rerun the complete XML audit until all pages pass.

- [ ] **Step 4: Confirm unrelated user files remain unchanged**

Run:

```powershell
git status --short
```

Expected: the existing user modification to `web/index.html` is still present and untouched. The final Draw.io file and its backup remain outside the repository.
