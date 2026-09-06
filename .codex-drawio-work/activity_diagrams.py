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
    style = CALL_ACTIVITY_STYLE if label.startswith("call UC") else ACTIVITY_STYLE
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
    activity_x = 53
    activity_width = lane_width - activity_x - 15
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

    previous_id = start_id
    previous_y = 44
    created_steps = []
    node_positions = {}
    last_decision_id = None
    previous_was_decision = False
    for index, step in enumerate(use_case["main_steps"]):
        node_id = f"{page_id}-main-{index}"
        lane_name = _step_lane(step, use_case["lanes"])
        lane_id = lane_ids[lane_name]
        node_y = 82 + index * 61
        is_decision = step.startswith("decision ")
        if is_decision:
            label = step.removeprefix("decision ") + "?"
            add_decision(root, lane_id, node_id, label, activity_x, node_y, width=activity_width)
            last_decision_id = node_id
        else:
            add_activity(root, lane_id, node_id, step, activity_x, node_y, width=activity_width, height=54)
        lane_index = use_case["lanes"].index(lane_name)
        lane_right = lane_left + lane_index * (lane_width + lane_gap) + lane_width
        node_positions[node_id] = (lane_right, lane_top + node_y + (28 if is_decision else 27))
        add_connector(
            root,
            f"{page_id}-flow-{index}",
            previous_id,
            node_id,
            label="yes" if previous_was_decision else "",
        )
        previous_id = node_id
        previous_y = node_y
        previous_was_decision = is_decision
        created_steps.append(node_id)

    end_id = f"{page_id}-end"
    # Main nodes are lane-relative; the end node is root-relative.
    end_y = lane_top + previous_y + 72
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
    add_connector(root, f"{page_id}-finish", previous_id, end_id, label="yes" if previous_was_decision else "")

    alternate_y = 770
    alternate_source = last_decision_id or previous_id
    for index, alternate_flow in enumerate(use_case["alternate_flows"]):
        steps = alternate_flow["steps"]
        frame_height = 110 + 72 * (len(steps) - 1)
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
        prior_id = alternate_source
        for step_index, step in enumerate(steps):
            step_id = f"{page_id}-alternate-{alternate_flow['id']}-{step_index}"
            lane_name = _step_lane(step, use_case["lanes"])
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
            lane_right = lane_left + lane_index * (lane_width + lane_gap) + lane_width
            target_y = alternate_y + 37 + step_index * 72 + 31
            source_right, source_y = node_positions[prior_id]
            corridor_x = max(source_right, lane_right) - 6
            node_positions[step_id] = (lane_right, target_y)
            add_connector(
                root,
                f"{page_id}-alternate-flow-{alternate_flow['id']}-{step_index}",
                prior_id,
                step_id,
                label="no" if step_index == 0 and last_decision_id else "",
                red=True,
                points=[(corridor_x, source_y), (corridor_x, target_y)],
            )
            prior_id = step_id
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
