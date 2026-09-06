"""Structured activity-flow definitions and editable Draw.io export helpers."""

from pathlib import Path
import xml.etree.ElementTree as ET

USE_CASES: list[dict] = [
    {
        "id": "UC200",
        "name": "Create Trip",
        "lanes": ["User", "System"],
        "main_steps": [
            "select Create Trip",
            "display form",
            "call UC207",
            "optionally call UC208",
            "preview",
            "select Save",
            "validate",
            "decision valid",
            "save and display trip",
        ],
        "decisions": ["valid"],
        "alternate_flows": [
            {"id": "A1", "steps": ["returns invalid information to detail entry"]},
            {"id": "A2", "steps": ["reports save failure and offers retry"]},
        ],
        "references": ["UC207 Enter Trip Details", "UC208 Update Cover Photo"],
    },
    {
        "id": "UC201",
        "name": "Edit Trip Details",
        "lanes": ["User", "System"],
        "main_steps": [
            "select Edit",
            "display existing details",
            "call UC207",
            "optionally call UC208",
            "preview",
            "select Save",
            "validate title, overlap and journal-entry date coverage",
            "save and display updated trip",
        ],
        "decisions": ["valid title, overlap and journal-entry date coverage"],
        "alternate_flows": [
            {"id": "A1", "steps": ["returns invalid changes to editing"]},
            {"id": "A2", "steps": ["retains previous information and reports failure"]},
        ],
        "references": ["UC207 Enter Trip Details", "UC208 Update Cover Photo"],
    },
    {
        "id": "UC202",
        "name": "View Trip List",
        "lanes": ["User", "System"],
        "main_steps": [
            "open Home",
            "retrieve active owned trips",
            "decision trips available",
            "display cards",
            "browse",
            "select trip",
            "call UC203",
        ],
        "decisions": ["trips available"],
        "alternate_flows": [
            {"id": "A1", "steps": ["displays empty state and Create Trip option"]},
            {"id": "A2", "steps": ["displays load error and Retry"]},
        ],
        "references": ["UC203 View Trip Details"],
    },
    {
        "id": "UC203",
        "name": "View Trip Details",
        "lanes": ["User", "System"],
        "main_steps": [
            "select trip",
            "retrieve owned active trip",
            "decision accessible",
            "display details and actions",
            "select optional action",
            "open selected function",
        ],
        "decisions": ["accessible"],
        "alternate_flows": [
            {"id": "A1", "steps": ["reports inaccessible trip"]},
            {"id": "A2", "steps": ["offers Retry or Return to List"]},
        ],
        "references": [],
    },
    {
        "id": "UC204",
        "name": "Move Trip to Trash",
        "lanes": ["User", "System"],
        "main_steps": [
            "select Move to Trash",
            "show confirmation",
            "decision confirmed",
            "move trip and related entries to recoverable Trash",
            "remove from active and Community lists",
            "refresh list",
        ],
        "decisions": ["confirmed"],
        "alternate_flows": [
            {"id": "A1", "steps": ["closes confirmation without changes"]},
            {"id": "A2", "steps": ["reports move failure"]},
        ],
        "references": [],
    },
    {
        "id": "UC205",
        "name": "View Trip Trash",
        "lanes": ["User", "System"],
        "main_steps": [
            "open Trip Trash",
            "retrieve owned recoverable trips",
            "decision data loaded",
            "decision trips available",
            "display trips and remaining recovery period",
            "decision recovery period expired",
            "select Restore",
            "call UC213",
        ],
        "decisions": ["data loaded", "trips available", "recovery period expired"],
        "alternate_flows": [
            {"id": "A1", "steps": ["displays empty state"]},
            {"id": "A2", "steps": ["displays load error and Retry"]},
            {
                "id": "A3",
                "steps": [
                    "expired items show recovery-period message and cannot start restoration",
                ],
            },
        ],
        "references": ["UC213 Restore Trip"],
    },
    {
        "id": "UC206",
        "name": "Browse Community Trips",
        "lanes": ["User", "System"],
        "main_steps": [
            "open Community",
            "retrieve public non-trashed trips",
            "decision data loaded",
            "decision trips available or match search",
            "display public cards",
            "browse or search",
            "select trip",
            "call UC214",
        ],
        "decisions": ["data loaded", "trips available or match search"],
        "alternate_flows": [
            {"id": "A1", "steps": ["displays empty state or no matches"]},
            {"id": "A2", "steps": ["displays load error and Retry"]},
        ],
        "references": ["UC214 View Community Trip Details"],
    },
    {
        "id": "UC207",
        "name": "Enter Trip Details",
        "lanes": ["User", "System"],
        "main_steps": [
            "enter title and destination",
            "accept input",
            "select start and end dates",
            "display range",
            "proceed to Save",
            "validate required fields, title length and date order",
            "decision valid",
            "return valid details to UC200 or UC201",
        ],
        "decisions": ["valid"],
        "alternate_flows": [
            {"id": "A1", "steps": ["identifies invalid field and returns to correction"]},
        ],
        "references": ["UC200 Create Trip", "UC201 Edit Trip Details"],
    },
    {
        "id": "UC208",
        "name": "Update Cover Photo",
        "lanes": ["User", "System"],
        "main_steps": [
            "select cover option",
            "display photo sources",
            "decision selection completed",
            "select or capture supported image",
            "preview",
            "save parent form",
            "decision storage successful",
            "associate cover with trip",
        ],
        "decisions": ["selection completed", "storage successful"],
        "alternate_flows": [
            {"id": "A1", "steps": ["keeps the existing cover or no cover"]},
            {"id": "A2", "steps": ["reports update failure and retains the previous cover"]},
        ],
        "references": [],
    },
    {
        "id": "UC209",
        "name": "Search or Filter Trip",
        "lanes": ["User", "System"],
        "main_steps": [
            "open search/filter controls",
            "display controls",
            "enter title/destination or select status",
            "apply criteria",
            "decision matches found",
            "display matching trips",
            "browse results",
        ],
        "decisions": ["matches found"],
        "alternate_flows": [
            {"id": "A1", "steps": ["displays no-results message and Clear option"]},
            {"id": "A2", "steps": ["clears criteria and restores the active list"]},
        ],
        "references": [],
    },
    {
        "id": "UC210",
        "name": "Publish Trip",
        "lanes": ["User", "System"],
        "main_steps": [
            "select Publish to Community",
            "show confirmation",
            "decision confirmed",
            "verify owner, private status and non-trashed state",
            "decision publish successful",
            "mark public and record publisher",
            "include in Community",
            "display Public status",
        ],
        "decisions": ["confirmed", "publish successful"],
        "alternate_flows": [
            {"id": "A1", "steps": ["keeps trip private"]},
            {"id": "A2", "steps": ["reports publication failure"]},
        ],
        "references": [],
    },
    {
        "id": "UC211",
        "name": "Unpublish Trip",
        "lanes": ["User", "System"],
        "main_steps": [
            "select Unpublish",
            "process request",
            "decision successful",
            "mark private",
            "remove from Community",
            "remove Public indicator",
            "confirm change",
        ],
        "decisions": ["successful"],
        "alternate_flows": [
            {"id": "A1", "steps": ["keeps trip public and reports failure"]},
        ],
        "references": [],
    },
    {
        "id": "UC212",
        "name": "Share Published Trip Link",
        "lanes": ["User", "System", "External Sharing Application"],
        "main_steps": [
            "select Share Link",
            "verify trip is public and sharing service exists",
            "prepare title and Trip ID message",
            "open sharing interface",
            "decision user selects target",
            "transfer message to external application",
            "user completes sharing",
            "external application handles delivery",
        ],
        "decisions": ["user selects target"],
        "alternate_flows": [
            {"id": "A1", "steps": ["closes sharing without changes"]},
            {"id": "A2", "steps": ["reports unavailable sharing service"]},
        ],
        "references": [],
    },
    {
        "id": "UC213",
        "name": "Restore Trip",
        "lanes": ["User", "System"],
        "main_steps": [
            "select Restore",
            "display confirmation",
            "decision confirmed",
            "check recovery period",
            "decision not expired",
            "check date overlap",
            "decision no conflict",
            "restore trip and journal entries",
            "remove from Trash",
            "refresh list",
        ],
        "decisions": ["confirmed", "not expired", "no conflict"],
        "alternate_flows": [
            {"id": "A1", "steps": ["reports expired recovery period and prevents restoration"]},
            {
                "id": "A2",
                "steps": [
                    "requests different dates and routes to date editing before restoration can be retried",
                ],
            },
        ],
        "references": [],
    },
    {
        "id": "UC214",
        "name": "View Community Trip Details",
        "lanes": ["User", "System"],
        "main_steps": [
            "select Community trip",
            "retrieve latest public information",
            "decision still public and found",
            "decision load successful",
            "display title, destination, dates, cover, publisher and shared content",
            "review",
            "optionally select Share",
            "call UC212",
        ],
        "decisions": ["still public and found", "load successful"],
        "alternate_flows": [
            {"id": "A1", "steps": ["reports unavailable trip and returns to Community"]},
            {"id": "A2", "steps": ["offers Retry"]},
        ],
        "references": ["UC212 Share Published Trip Link"],
    },
]


# Each main action owns an explicit actor. Alternate triples are source index,
# guard, and rejoin index (or end); no lexical or last-decision inference is used.
FLOW_SPECS = {
    "UC200": {
        "steps": [("select Create Trip", "User"), ("display form", "System"), ("call UC207", "User"),
                  ("decision update cover", "User"), ("optionally call UC208", "User"), ("preview", "System"),
                  ("select Save", "User"), ("validate trip information", "System"), ("decision valid", "System"),
                  ("save trip", "System"), ("decision saved", "System"), ("display saved trip", "System")],
        "alternates": [(8, "no", 2), (10, "no", 6)], "bypasses": [(3, "no", 5)],
    },
    "UC201": {
        "steps": [("select Edit", "User"), ("display existing details", "System"), ("call UC207", "User"),
                  ("decision update cover", "User"), ("optionally call UC208", "User"), ("preview", "System"),
                  ("select Save", "User"), ("validate title, overlap and journal-entry date coverage", "System"),
                  ("decision valid", "System"), ("save changes", "System"), ("decision saved", "System"),
                  ("display updated trip", "System")],
        "alternates": [(8, "no", 2), (10, "no", "end")], "bypasses": [(3, "no", 5)],
    },
    "UC202": {
        "steps": [("open Home", "User"), ("retrieve active owned trips", "System"), ("decision data loaded", "System"),
                  ("decision trips available", "System"), ("display cards", "System"), ("browse", "User"),
                  ("select trip", "User"), ("call UC203", "System")],
        "alternates": [(3, "no", "end"), (2, "no", 1)],
    },
    "UC203": {
        "steps": [("select trip", "User"), ("retrieve owned active trip", "System"), ("decision data loaded", "System"),
                  ("decision accessible", "System"), ("display details and actions", "System"),
                  ("review", "User"), ("decision action selected", "User"), ("open selected function", "System")],
        "alternates": [(3, "no", "end"), (2, "no", 1)], "bypasses": [(6, "no", "end")],
    },
    "UC204": {
        "steps": [("select Move to Trash", "User"), ("show confirmation", "System"), ("decision confirmed", "User"),
                  ("move trip and entries to recoverable Trash", "System"), ("decision moved", "System"),
                  ("remove from active and Community lists", "System"), ("return to trip list", "User"),
                  ("refresh list", "System")],
        "alternates": [(2, "no", "end"), (4, "no", "end")],
    },
    "UC205": {
        "steps": [("open Trip Trash", "User"), ("retrieve owned recoverable trips", "System"), ("decision data loaded", "System"),
                  ("decision trips available", "System"), ("display trips and recovery period", "System"),
                  ("browse deleted trips", "User"), ("decision recovery period expired", "System"),
                  ("select Restore", "User"), ("call UC213", "System")],
        "alternates": [(3, "no", "end"), (2, "no", 1), (6, "yes", "end")], "guards": {6: "no"},
    },
    "UC206": {
        "steps": [("open Community", "User"), ("retrieve public non-trashed trips", "System"), ("decision data loaded", "System"),
                  ("browse or search Community feed", "User"), ("apply criteria", "System"), ("decision trips match", "System"),
                  ("display public cards", "System"), ("select published trip", "User"), ("call UC214", "System")],
        "alternates": [(5, "no", 3), (2, "no", 1)],
    },
    "UC207": {
        "steps": [("enter title and destination", "User"), ("accept input", "System"), ("select start and end dates", "User"),
                  ("display range", "System"), ("proceed to Save", "User"),
                  ("validate required fields, title length and date order", "System"), ("decision valid", "System"),
                  ("return valid details to UC200 or UC201", "System")],
        "alternates": [(6, "no", 0)],
    },
    "UC208": {
        "steps": [("select cover option", "User"), ("display photo sources", "System"),
                  ("select or capture supported image", "User"), ("decision selection completed", "User"),
                  ("preview", "System"), ("save parent form", "User"), ("decision storage successful", "System"),
                  ("associate cover with trip", "System")],
        "alternates": [(3, "no", "end"), (6, "no", "end")],
    },
    "UC209": {
        "steps": [("open search/filter controls", "User"), ("display controls", "System"), ("decision clear criteria", "User"),
                  ("enter title/destination or select status", "User"), ("apply criteria", "System"),
                  ("decision matches found", "System"), ("display matching trips", "System"), ("browse results", "User")],
        "alternates": [(5, "no", 2), (2, "yes", "end")], "guards": {2: "no"},
    },
    "UC210": {
        "steps": [("select Publish to Community", "User"), ("show confirmation", "System"), ("decision confirmed", "User"),
                  ("verify owner, private and non-trashed state", "System"), ("decision publish successful", "System"),
                  ("mark public and record publisher", "System"), ("include in Community", "System"),
                  ("return to trip details", "User"), ("display Public status", "System")],
        "alternates": [(2, "no", "end"), (4, "no", "end")],
    },
    "UC211": {
        "steps": [("select Unpublish", "User"), ("process request", "System"), ("wait for completion", "User"),
                  ("decision successful", "System"), ("mark private", "System"), ("remove from Community", "System"),
                  ("continue viewing trip", "User"), ("remove Public indicator and confirm change", "System")],
        "alternates": [(3, "no", "end")],
    },
    "UC212": {
        "steps": [("select Share Link", "User"), ("verify public trip and sharing service", "System"),
                  ("decision sharing available", "System"), ("prepare title and Trip ID message", "System"),
                  ("open sharing interface", "System"), ("decision user selects target", "User"),
                  ("transfer message to external application", "System"), ("user completes sharing", "User"),
                  ("external application handles delivery", "External Sharing Application")],
        "alternates": [(5, "no", "end"), (2, "no", "end")],
    },
    "UC213": {
        "steps": [("select Restore", "User"), ("display confirmation", "System"), ("decision confirmed", "User"),
                  ("check recovery period", "System"), ("decision not expired", "System"), ("check date overlap", "System"),
                  ("decision no conflict", "System"), ("wait for completion", "User"),
                  ("restore trip and journal entries", "System"), ("remove from Trash", "System"),
                  ("refresh list", "System")],
        "alternates": [(4, "no", "end"), (6, "no", 5)], "bypasses": [(2, "no", "end")],
    },
    "UC214": {
        "steps": [("select Community trip", "User"), ("retrieve latest public information", "System"),
                  ("decision still public and found", "System"), ("decision load successful", "System"),
                  ("display title, destination, dates, cover, publisher and shared content", "System"), ("review", "User"),
                  ("decision share selected", "User"), ("call UC212", "System")],
        "alternates": [(2, "no", "end"), (3, "no", 1)], "bypasses": [(6, "no", "end")],
    },
}

USE_CASE_NAMES = {case["id"]: case["name"] for case in USE_CASES}


def _expand_call_reference(label):
    """Add the referenced use-case name to every call-activity label."""
    for reference_id, reference_name in USE_CASE_NAMES.items():
        token = f"call {reference_id}"
        if token in label:
            return label.replace(token, f"{token} {reference_name}", 1)
    return label


for _case in USE_CASES:
    _spec = FLOW_SPECS[_case["id"]]
    _case["main_steps"] = [_expand_call_reference(label) for label, lane in _spec["steps"]]
    _case["step_lanes"] = [lane for label, lane in _spec["steps"]]
    _case["main_guards"] = {i: "yes" for i, step in enumerate(_case["main_steps"]) if step.startswith("decision ")}
    _case["main_guards"].update(_spec.get("guards", {}))
    _case["bypasses"] = _spec.get("bypasses", [])
    _case["decisions"] = [step.removeprefix("decision ") for step in _case["main_steps"] if step.startswith("decision ")]
    for _alt, (_source, _guard, _destination) in zip(_case["alternate_flows"], _spec["alternates"]):
        _alt.update(source=_source, guard=_guard, destination=_destination, lane="System")
        if _destination != "end":
            _alt["choice"] = "Retry?" if "Retry" in _alt["steps"][0] or "retry" in _alt["steps"][0] else "Correct details?"
    if _case["id"] == "UC206":
        _case["alternate_flows"][0]["choice"] = "Change search?"
    if _case["id"] == "UC209":
        _case["alternate_flows"][0]["choice"] = "Change criteria?"
    if _case["id"] == "UC213":
        _case["alternate_flows"][1]["choice"] = "Edit dates and retry?"
        _case["alternate_flows"][1]["user_action"] = "enter different trip dates"


SWIMLANE_STYLE = (
    "shape=swimlane;horizontal=0;startSize=38;fillColor=#DAE8FC;"
    "strokeColor=#6C8EBF;fontStyle=1;fontSize=14;html=1;rounded=0;"
)
ACTIVITY_STYLE = (
    "rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;"
    "strokeColor=#4D4D4D;fontSize=12;arcSize=12;"
)
CALL_ACTIVITY_STYLE = (
    "rounded=1;whiteSpace=wrap;html=1;fillColor=#E1D5E7;"
    "strokeColor=#9673A6;fontSize=12;arcSize=12;fontStyle=1;"
)
DECISION_STYLE = (
    "rhombus;whiteSpace=wrap;html=1;fillColor=#FFF2CC;"
    "strokeColor=#D6B656;fontSize=11;"
)
MERGE_STYLE = (
    "rhombus;whiteSpace=wrap;html=1;fillColor=#FFFFFF;"
    "strokeColor=#333333;strokeWidth=1.5;"
)
TITLE_STYLE = (
    "text;html=1;align=center;verticalAlign=middle;whiteSpace=wrap;"
    "rounded=0;strokeColor=none;fillColor=none;fontSize=16;fontStyle=1;"
)
START_STYLE = "ellipse;html=1;shape=startState;fillColor=#000000;strokeColor=#FF0000;"
END_STYLE = "ellipse;html=1;shape=endState;fillColor=#000000;strokeColor=#FF0000;"
CONNECTOR_STYLE = (
    "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;"
    "html=1;endArrow=block;endFill=1;strokeColor=#333333;fontSize=11;"
)
ALTERNATE_FRAME_STYLE = (
    "rounded=0;whiteSpace=wrap;html=1;fillColor=none;strokeColor=#FF0000;"
    "strokeWidth=2;verticalAlign=top;align=left;spacingTop=6;spacingLeft=8;"
    "fontColor=#CC0000;fontStyle=1;"
)


def add_cell(
    root,
    *,
    cell_id,
    value="",
    style="",
    parent="1",
    vertex=False,
    edge=False,
    x=None,
    y=None,
    width=None,
    height=None,
    source=None,
    target=None,
    points=None,
):
    """Append one Draw.io cell and its geometry to a graph-model root."""
    attributes = {"id": str(cell_id), "value": value, "style": style, "parent": str(parent)}
    if vertex:
        attributes["vertex"] = "1"
    if edge:
        attributes["edge"] = "1"
    if source is not None:
        attributes["source"] = str(source)
    if target is not None:
        attributes["target"] = str(target)

    cell = ET.SubElement(root, "mxCell", attributes)
    if edge:
        geometry = ET.SubElement(cell, "mxGeometry", {"relative": "1", "as": "geometry"})
        if points:
            point_array = ET.SubElement(geometry, "Array", {"as": "points"})
            for point_x, point_y in points:
                ET.SubElement(point_array, "mxPoint", {"x": str(point_x), "y": str(point_y)})
    elif vertex:
        geometry_attributes = {"as": "geometry"}
        if x is not None:
            geometry_attributes["x"] = str(x)
        if y is not None:
            geometry_attributes["y"] = str(y)
        if width is not None:
            geometry_attributes["width"] = str(width)
        if height is not None:
            geometry_attributes["height"] = str(height)
        ET.SubElement(cell, "mxGeometry", geometry_attributes)
    return cell


def add_activity(root, lane_id, cell_id, label, x, y, width=220, height=52):
    """Add an action, using the call-activity style for cross-use-case calls."""
    style = CALL_ACTIVITY_STYLE if "call UC" in label else ACTIVITY_STYLE
    return add_cell(
        root,
        cell_id=cell_id,
        value=label,
        style=style,
        parent=lane_id,
        vertex=True,
        x=x,
        y=y,
        width=width,
        height=height,
    )


def add_decision(root, lane_id, cell_id, label, x, y, width=120):
    """Add a labeled UML decision node to a swimlane."""
    return add_cell(
        root,
        cell_id=cell_id,
        value=label,
        style=DECISION_STYLE,
        parent=lane_id,
        vertex=True,
        x=x,
        y=y,
        width=width,
        height=56,
    )


def add_connector(root, cell_id, source, target, label="", red=False, points=None):
    """Add an orthogonal control-flow connector between existing cells."""
    style = CONNECTOR_STYLE
    if red:
        style += "strokeColor=#FF0000;exitX=1;exitY=0.5;entryX=1;entryY=0.5;"
    return add_cell(
        root,
        cell_id=cell_id,
        value=label,
        style=style,
        edge=True,
        source=source,
        target=target,
        points=points,
    )


def add_alternate_frame(root, cell_id, label, x, y, width, height):
    """Add the red outlined grouping frame mandated for an alternate flow."""
    return add_cell(
        root,
        cell_id=cell_id,
        value=label,
        style=ALTERNATE_FRAME_STYLE,
        vertex=True,
        x=x,
        y=y,
        width=width,
        height=height,
    )


def _step_lane(step, lanes):
    """Choose the responsible lane using the use-case wording consistently."""
    lower_step = step.lower()
    if len(lanes) == 3 and (
        "external application" in lower_step
        or "external" in lower_step
        or "delivery" in lower_step
    ):
        return lanes[2]
    if lower_step.startswith(("select", "open", "enter", "browse", "review", "accept")):
        return lanes[0]
    if "user completes" in lower_step:
        return lanes[0]
    return lanes[1] if len(lanes) > 1 else lanes[0]


def build_page(use_case):
    """Build one uncompressed, editable activity diagram page for a use case."""
    diagram = ET.Element(
        "diagram",
        {"id": use_case["id"], "name": f'{use_case["id"]} {use_case["name"]}'},
    )
    model = ET.SubElement(
        diagram,
        "mxGraphModel",
        {
            "dx": "1214",
            "dy": "1004",
            "grid": "1",
            "gridSize": "10",
            "guides": "1",
            "tooltips": "1",
            "connect": "1",
            "arrows": "1",
            "fold": "1",
            "page": "1",
            "pageScale": "1",
            "pageWidth": "827",
            "pageHeight": "1169",
            "math": "0",
            "shadow": "0",
        },
    )
    root = ET.SubElement(model, "root")
    ET.SubElement(root, "mxCell", {"id": "0"})
    ET.SubElement(root, "mxCell", {"id": "1", "parent": "0"})

    page_id = use_case["id"]
    lane_width = 240 if len(use_case["lanes"]) == 3 else 365
    lane_gap = 12
    lane_left = 25
    lane_top = 25
    # horizontal=0 reserves a vertical 38px title strip on the left.
    activity_x = 68
    activity_width = lane_width - activity_x - 15
    add_cell(
        root,
        cell_id=f"{page_id}-title",
        value=f'{page_id} {use_case["name"]}',
        style=TITLE_STYLE,
        vertex=True,
        x=25,
        y=0,
        width=777,
        height=22,
    )
    lane_ids = {}
    for index, lane_name in enumerate(use_case["lanes"]):
        lane_id = f"{page_id}-lane-{index}"
        lane_ids[lane_name] = lane_id
        add_cell(
            root,
            cell_id=lane_id,
            value=lane_name,
            style=SWIMLANE_STYLE,
            vertex=True,
            x=lane_left + index * (lane_width + lane_gap),
            y=lane_top,
            width=lane_width,
            height=1100,
        )

    start_id = f"{page_id}-start"
    add_cell(
        root,
        cell_id=start_id,
        style=START_STYLE,
        vertex=True,
        x=lane_left + activity_x + (activity_width - 24) // 2,
        y=44,
        width=24,
        height=24,
    )

    node_positions = {start_id: (lane_left + activity_x + (activity_width - 24) // 2, 44, 24, 24)}
    for index, step in enumerate(use_case["main_steps"]):
        node_id = f"{page_id}-main-{index}"
        lane_name = use_case["step_lanes"][index]
        lane_id = lane_ids[lane_name]
        node_y = 82 + index * 61
        is_decision = step.startswith("decision ")
        if is_decision:
            label = step.removeprefix("decision ") + "?"
            add_decision(root, lane_id, node_id, label, activity_x, node_y, width=activity_width)
        else:
            add_activity(root, lane_id, node_id, step, activity_x, node_y, width=activity_width, height=54)
        lane_index = use_case["lanes"].index(lane_name)
        node_positions[node_id] = (lane_left + lane_index * (lane_width + lane_gap) + activity_x,
                                   lane_top + node_y, activity_width, 56 if is_decision else 54)

    merge_destinations = {
        destination
        for _source, _guard, destination in use_case["bypasses"]
        if destination != "end"
    } | {
        flow["destination"]
        for flow in use_case["alternate_flows"]
        if flow["destination"] != "end"
    }
    merge_nodes = {}
    for destination in sorted(merge_destinations):
        merge_id = f"{page_id}-merge-{destination}"
        lane_name = use_case["step_lanes"][destination]
        lane_index = use_case["lanes"].index(lane_name)
        target_height = 56 if use_case["main_steps"][destination].startswith("decision ") else 54
        merge_x = 48
        merge_y = 82 + destination * 61 + (target_height - 16) / 2
        add_cell(
            root,
            cell_id=merge_id,
            style=MERGE_STYLE,
            parent=lane_ids[lane_name],
            vertex=True,
            x=merge_x,
            y=merge_y,
            width=16,
            height=16,
        )
        node_positions[merge_id] = (
            lane_left + lane_index * (lane_width + lane_gap) + merge_x,
            lane_top + merge_y,
            16,
            16,
        )
        merge_nodes[destination] = merge_id

    end_id = f"{page_id}-end"
    # Main nodes are lane-relative; the end node is root-relative.
    end_y = lane_top + 82 + (len(use_case["main_steps"]) - 1) * 61 + 72
    add_cell(
        root,
        cell_id=end_id,
        style=END_STYLE,
        vertex=True,
        x=lane_left + activity_x + (activity_width - 24) // 2,
        y=end_y,
        width=24,
        height=24,
    )
    node_positions[end_id] = (lane_left + activity_x + (activity_width - 24) // 2, end_y, 24, 24)

    def route(edge_id, source, target, label="", mode="forward", red=False, offset=0):
        sx, sy, sw, sh = node_positions[source]
        tx, ty, tw, th = node_positions[target]
        if mode == "side":
            corridor = 790 - offset
            points = [(corridor, sy + sh / 2), (corridor, ty + th / 2)]
            anchors = "exitX=1;exitY=0.5;entryX=1;entryY=0.5;"
        elif mode == "return":
            corridor = 70 + offset / 2
            points = [(corridor, sy + sh / 2), (corridor, ty - 3), (tx + tw / 2, ty - 3)]
            anchors = "exitX=0;exitY=0.5;entryX=0.5;entryY=0;"
        elif mode == "across":
            points = []
            anchors = "exitX=0;exitY=0.5;entryX=1;entryY=0.5;"
        elif mode == "offer":
            points = [(tx + tw + 20, sy + sh / 2), (tx + tw + 20, ty - 10), (tx + tw / 2, ty - 10)]
            anchors = "exitX=0;exitY=0.5;entryX=0.5;entryY=0;"
        elif mode == "merge":
            points = []
            anchors = "exitX=1;exitY=0.5;entryX=0;entryY=0.5;"
        else:
            middle_y = (sy + sh + ty) / 2
            points = [(sx + sw / 2, middle_y), (tx + tw / 2, middle_y)]
            anchors = "exitX=0.5;exitY=1;entryX=0.5;entryY=0;"
        cell = add_connector(root, edge_id, source, target, label=label, red=red, points=points)
        cell.set("style", CONNECTOR_STYLE + ("strokeColor=#FF0000;" if red else "") + anchors + "labelBackgroundColor=#FFFFFF;")

    previous = start_id
    for index in range(len(use_case["main_steps"])):
        current = f"{page_id}-main-{index}"
        entry = merge_nodes.get(index, current)
        route(f"{page_id}-flow-{index}", previous, entry,
              use_case["main_guards"].get(index - 1, ""))
        if entry != current:
            route(f"{page_id}-merge-flow-{index}", entry, current, mode="merge")
        previous = current
    route(f"{page_id}-finish", previous, end_id, use_case["main_guards"].get(len(use_case["main_steps"]) - 1, ""))
    for index, (source, guard, destination) in enumerate(use_case["bypasses"]):
        route(f"{page_id}-bypass-{index}", f"{page_id}-main-{source}",
              end_id if destination == "end" else merge_nodes[destination], guard, "return", offset=24)

    alternate_y = max(770, end_y + 55)
    for index, alternate_flow in enumerate(use_case["alternate_flows"]):
        steps = alternate_flow["steps"]
        frame_height = 110 + (65 if alternate_flow.get("user_action") else 0)
        frame_id = f"{page_id}-alternate-frame-{alternate_flow['id']}"
        add_alternate_frame(
            root,
            frame_id,
            f"Alternate Flow {alternate_flow['id']}",
            25,
            alternate_y,
            777,
            frame_height,
        )
        prior_id = f"{page_id}-main-{alternate_flow['source']}"
        for step_index, step in enumerate(steps):
            step_id = f"{page_id}-alternate-{alternate_flow['id']}-{step_index}"
            lane_name = alternate_flow["lane"]
            add_activity(
                root,
                lane_ids[lane_name],
                step_id,
                step,
                activity_x,
                alternate_y + 37 + step_index * 72 - lane_top,
                width=activity_width,
                height=62,
            )
            lane_index = use_case["lanes"].index(lane_name)
            node_positions[step_id] = (lane_left + lane_index * (lane_width + lane_gap) + activity_x,
                                       alternate_y + 37 + step_index * 72, activity_width, 62)
            route(f"{page_id}-alternate-flow-{alternate_flow['id']}-{step_index}", prior_id, step_id,
                  alternate_flow["guard"] if step_index == 0 else "", "side", offset=index * 8)
            prior_id = step_id
        alt_id = alternate_flow["id"]
        terminal = f"{page_id}-end-{alt_id}"
        terminal_x = lane_left + lane_width - 39
        terminal_y = alternate_y + (80 if alternate_flow["destination"] != "end" else 56)
        add_cell(root, cell_id=terminal, style=END_STYLE, vertex=True,
                 x=terminal_x, y=terminal_y, width=24, height=24)
        node_positions[terminal] = (terminal_x, terminal_y, 24, 24)
        if alternate_flow["destination"] == "end":
            route(f"{page_id}-complete-{alt_id}", prior_id, terminal, mode="across")
        else:
            choice = f"{page_id}-choice-{alt_id}"
            choice_width = min(220, activity_width - 45)
            label = alternate_flow["choice"]
            if alternate_flow.get("user_action"):
                label = "Retry?"
            add_decision(root, lane_ids["User"], choice, label, activity_x,
                         alternate_y + 40 - lane_top, width=choice_width)
            node_positions[choice] = (lane_left + activity_x, alternate_y + 40, choice_width, 56)
            route(f"{page_id}-offer-{alt_id}", prior_id, choice, mode="offer")
            # User cancellation ends inside the same alternate frame.
            cell = add_connector(root, f"{page_id}-cancel-{alt_id}", choice, terminal, label="no")
            cell.set("style", CONNECTOR_STYLE + "exitX=1;exitY=0.5;entryX=0;entryY=0.5;labelBackgroundColor=#FFFFFF;")
            destination = merge_nodes[alternate_flow["destination"]]
            if alternate_flow.get("user_action"):
                action = f"{page_id}-edit-{alt_id}"
                add_activity(root, lane_ids["User"], action, alternate_flow["user_action"], activity_x,
                             alternate_y + 105 - lane_top, width=activity_width, height=54)
                node_positions[action] = (lane_left + activity_x, alternate_y + 105, activity_width, 54)
                route(f"{page_id}-accept-{alt_id}", choice, action, "yes")
                route(f"{page_id}-rejoin-{alt_id}", action, destination, mode="return", offset=index * 8)
            else:
                route(f"{page_id}-rejoin-{alt_id}", choice, destination, "yes", "return", offset=index * 8)
        alternate_y += frame_height + 10
    return diagram


def build_drawio(use_cases: list[dict]) -> ET.ElementTree:
    """Build an uncompressed Draw.io document from the supplied use cases."""
    mxfile = ET.Element(
        "mxfile",
        {
            "host": "app.diagrams.net",
            "modified": "2026-09-06T00:00:00.000Z",
            "agent": "TripJournal activity diagram generator",
            "version": "26.0.14",
            "pages": str(len(use_cases)),
        },
    )
    for use_case in use_cases:
        mxfile.append(build_page(use_case))
    return ET.ElementTree(mxfile)


def write_drawio(output_path: Path) -> None:
    """Write the complete Trip Management activity diagram document to disk."""
    output_path = Path(output_path)
    tree = build_drawio(USE_CASES)
    ET.indent(tree, space="  ")
    tree.write(output_path, encoding="utf-8", xml_declaration=True)
