from pathlib import Path
import unittest
import xml.etree.ElementTree as ET
from itertools import combinations
import textwrap

import activity_diagrams
from activity_diagrams import USE_CASES


class ActivityDiagramDefinitionsTests(unittest.TestCase):
    def test_all_use_cases_are_defined(self):
        """The generator has complete flow data for every required use case."""
        self.assertEqual(
            [item["id"] for item in USE_CASES],
            [f"UC{i}" for i in range(200, 215)],
        )
        self.assertTrue(all(item["main_steps"] for item in USE_CASES))
        self.assertTrue(all(item["alternate_flows"] for item in USE_CASES))
        self.assertEqual(
            USE_CASES[12]["lanes"],
            ["User", "System", "External Sharing Application"],
        )

    def test_uc205_expired_items_are_not_a_load_error_path(self):
        """Expired Trash items remain independently unavailable after data loads."""
        trip_trash = next(item for item in USE_CASES if item["id"] == "UC205")
        alternate_flows = {flow["id"]: flow["steps"] for flow in trip_trash["alternate_flows"]}

        self.assertEqual(alternate_flows["A2"], ["displays load error and Retry"])
        self.assertEqual(
            alternate_flows["A3"],
            [
                "expired items show recovery-period message and cannot start restoration",
            ],
        )
        self.assertIn("recovery period expired", trip_trash["decisions"])


class ActivityDiagramGenerationTests(unittest.TestCase):
    @staticmethod
    def bounds(cell, cells):
        geometry = cell.find("mxGeometry")
        x, y = float(geometry.get("x", 0)), float(geometry.get("y", 0))
        parent = cells.get(cell.get("parent"))
        if parent is not None and parent.get("vertex") == "1":
            px, py, _, _ = ActivityDiagramGenerationTests.bounds(parent, cells)
            x, y = x + px, y + py
        return x, y, x + float(geometry.get("width")), y + float(geometry.get("height"))

    def test_complete_xml_integrity(self):
        """Every exported page has valid identities, links and UML containers."""
        root = activity_diagrams.build_drawio(USE_CASES).getroot()
        self.assertEqual(len(root.findall("diagram")), 15)
        for page, case in zip(root.findall("diagram"), USE_CASES):
            with self.subTest(page=page.get("name")):
                items = list(page.iter("mxCell"))
                cells = {cell.get("id"): cell for cell in items}
                self.assertEqual(len(cells), len(items))
                self.assertEqual(
                    [c.get("value") for c in items if "shape=swimlane" in c.get("style", "")],
                    case["lanes"],
                )
                for cell in items:
                    if cell.get("parent"):
                        self.assertIn(cell.get("parent"), cells)
                    if cell.get("edge") == "1":
                        for end in ("source", "target"):
                            self.assertIn(cell.get(end), cells)
                            self.assertEqual(cells[cell.get(end)].get("vertex"), "1")
                self.assertEqual(sum("shape=startState" in c.get("style", "") for c in items), 1)
                self.assertGreaterEqual(sum("shape=endState" in c.get("style", "") for c in items), 1)
                self.assertEqual(
                    [c.get("value") for c in items if "-alternate-frame-" in c.get("id", "")],
                    [f"Alternate Flow A{i + 1}" for i in range(len(case["alternate_flows"]))],
                )

    def test_nodes_clear_swimlane_headers_and_other_nodes(self):
        """Absolute rectangles do not overlap nodes or the vertical lane title strip."""
        for page in activity_diagrams.build_drawio(USE_CASES).getroot():
            cells = {cell.get("id"): cell for cell in page.iter("mxCell")}
            nodes = [c for c in cells.values() if c.get("vertex") == "1"
                     and "shape=swimlane" not in c.get("style", "")
                     and "-alternate-frame-" not in c.get("id", "")]
            for cell in nodes:
                parent = cells[cell.get("parent")]
                if "shape=swimlane" in parent.get("style", ""):
                    with self.subTest(node=cell.get("id")):
                        self.assertGreaterEqual(float(cell.find("mxGeometry").get("x")), 48)
                        left, top, right, bottom = self.bounds(cell, cells)
                        pl, pt, pr, pb = self.bounds(parent, cells)
                        self.assertLessEqual(right, pr - 10)
                        self.assertLessEqual(bottom, pb)
            for first, second in combinations(nodes, 2):
                ax, ay, ar, ab = self.bounds(first, cells)
                bx, by, br, bb = self.bounds(second, cells)
                with self.subTest(first=first.get("id"), second=second.get("id")):
                    self.assertFalse(max(ax, bx) < min(ar, br) and max(ay, by) < min(ab, bb))

    def test_all_vertices_fit_a4_page(self):
        """All visible nodes and frames fit inside the declared portrait A4 page."""
        for page in activity_diagrams.build_drawio(USE_CASES).getroot():
            model = page.find("mxGraphModel")
            self.assertEqual((model.get("pageWidth"), model.get("pageHeight")), ("827", "1169"))
            cells = {cell.get("id"): cell for cell in page.iter("mxCell")}
            for cell in cells.values():
                if cell.get("vertex") == "1":
                    with self.subTest(node=cell.get("id")):
                        left, top, right, bottom = self.bounds(cell, cells)
                        self.assertGreaterEqual(left, 0)
                        self.assertGreaterEqual(top, 0)
                        self.assertLessEqual(right, 827)
                        self.assertLessEqual(bottom, 1169)

    def test_labels_have_conservative_wrapping_space(self):
        """Actions and central diamond labels reserve space for wrapped text."""
        for page in activity_diagrams.build_drawio(USE_CASES).getroot():
            for cell in page.iter("mxCell"):
                if cell.get("vertex") != "1" or not cell.get("value"):
                    continue
                style = cell.get("style", "")
                if "shape=swimlane" in style or "-alternate-frame-" in cell.get("id", ""):
                    continue
                geometry = cell.find("mxGeometry")
                width, height = float(geometry.get("width")), float(geometry.get("height"))
                diamond = "rhombus" in style
                # Central half of a diamond remains inside its sloped outline.
                usable_width = width * 0.5 if diamond else width - 16
                usable_height = height * 0.5 if diamond else height - 8
                lines = textwrap.wrap(cell.get("value"), width=int(usable_width / (6 if diamond else 7)))
                with self.subTest(node=cell.get("id"), label=cell.get("value")):
                    self.assertLessEqual(len(lines) * (13 if diamond else 15), usable_height)

    def test_alternate_routes_clear_intervening_nodes(self):
        """Long alternate connectors use an explicit clear corridor beside nodes."""
        for page in activity_diagrams.build_drawio(USE_CASES).getroot():
            cells = {cell.get("id"): cell for cell in page.iter("mxCell")}
            nodes = [c for c in cells.values() if c.get("vertex") == "1"
                     and "shape=swimlane" not in c.get("style", "")
                     and "-alternate-frame-" not in c.get("id", "")]
            for edge in cells.values():
                if "-alternate-flow-" not in edge.get("id", ""):
                    continue
                with self.subTest(edge=edge.get("id")):
                    points = [(float(p.get("x")), float(p.get("y")))
                              for p in edge.findall("mxGeometry/Array/mxPoint")]
                    self.assertGreaterEqual(len(points), 2)
                    source = self.bounds(cells[edge.get("source")], cells)
                    target = self.bounds(cells[edge.get("target")], cells)
                    path = [(source[2], (source[1] + source[3]) / 2), *points,
                            (target[2], (target[1] + target[3]) / 2)]
                    for x, y in path:
                        self.assertTrue(0 <= x <= 827 and 0 <= y <= 1169)
                    for (x1, y1), (x2, y2) in zip(path, path[1:]):
                        self.assertTrue(x1 == x2 or y1 == y2)
                        for node in nodes:
                            if node.get("id") in (edge.get("source"), edge.get("target")):
                                continue
                            left, top, right, bottom = self.bounds(node, cells)
                            crosses = (x1 == x2 and left < x1 < right and
                                       max(min(y1, y2), top) < min(max(y1, y2), bottom)) or (
                                       y1 == y2 and top < y1 < bottom and
                                       max(min(x1, x2), left) < min(max(x1, x2), right))
                            self.assertFalse(crosses, node.get("id"))

    def write_generated_file(self, tmp_path: Path) -> ET.Element:
        output = tmp_path / "activity.drawio"
        write_drawio = getattr(activity_diagrams, "write_drawio", None)
        self.assertTrue(callable(write_drawio), "write_drawio must provide the export API")
        write_drawio(output)
        return ET.parse(output).getroot()

    def test_generated_file_has_expected_pages(self):
        """The export contains one named, editable page for every use case."""
        tmp_path = Path(self._testMethodName)
        try:
            tmp_path.mkdir()
            root = self.write_generated_file(tmp_path)
        finally:
            output = tmp_path / "activity.drawio"
            if output.exists():
                output.unlink()
            if tmp_path.exists():
                tmp_path.rmdir()

        self.assertEqual(root.tag, "mxfile")
        self.assertEqual(root.get("pages"), "15")
        self.assertEqual(
            [diagram.get("name") for diagram in root.findall("diagram")],
            [f'{item["id"]} {item["name"]}' for item in USE_CASES],
        )

    def test_every_page_has_required_activity_elements(self):
        """Each page renders UML activity notation and all modeled alternate flows."""
        tmp_path = Path(self._testMethodName)
        try:
            tmp_path.mkdir()
            root = self.write_generated_file(tmp_path)
        finally:
            output = tmp_path / "activity.drawio"
            if output.exists():
                output.unlink()
            if tmp_path.exists():
                tmp_path.rmdir()

        expected_alternate_flows = sum(len(item["alternate_flows"]) for item in USE_CASES)
        alternate_frames = 0
        for page in root.findall("diagram"):
            styles = [cell.get("style", "") for cell in page.iter("mxCell")]
            values = [cell.get("value", "") for cell in page.iter("mxCell")]
            self.assertEqual(len(page.findall("mxGraphModel")), 1)
            self.assertTrue(any("shape=startState" in style for style in styles))
            self.assertTrue(any("shape=endState" in style for style in styles))
            self.assertTrue(any("shape=swimlane" in style for style in styles))
            alternate_frames += sum(
                "strokeColor=#FF0000" in style and "Alternate Flow A" in value
                for style, value in zip(styles, values)
            )

        self.assertEqual(alternate_frames, expected_alternate_flows)

    def test_alternate_activities_are_enclosed_by_their_matching_frames(self):
        """Every alternate action stays inside its own root-level red frame."""
        tmp_path = Path(self._testMethodName)
        try:
            tmp_path.mkdir()
            root = self.write_generated_file(tmp_path)
        finally:
            output = tmp_path / "activity.drawio"
            if output.exists():
                output.unlink()
            if tmp_path.exists():
                tmp_path.rmdir()

        cases_by_id = {item["id"]: item for item in USE_CASES}
        for page in root.findall("diagram"):
            cells = {cell.get("id"): cell for cell in page.iter("mxCell")}
            case = cases_by_id[page.get("id")]
            for alternate_flow in case["alternate_flows"]:
                alternate_id = alternate_flow["id"]
                frame = cells[f'{case["id"]}-alternate-frame-{alternate_id}']
                frame_geometry = frame.find("mxGeometry")
                frame_left = int(frame_geometry.get("x"))
                frame_top = int(frame_geometry.get("y"))
                frame_right = frame_left + int(frame_geometry.get("width"))
                frame_bottom = frame_top + int(frame_geometry.get("height"))
                self.assertIn("strokeColor=#FF0000", frame.get("style", ""))

                alternate_cells = [
                    cell
                    for cell_id, cell in cells.items()
                    if cell_id.startswith(f'{case["id"]}-alternate-{alternate_id}-')
                ]
                self.assertEqual(len(alternate_cells), len(alternate_flow["steps"]))
                for activity in alternate_cells:
                    lane_geometry = cells[activity.get("parent")].find("mxGeometry")
                    activity_geometry = activity.find("mxGeometry")
                    activity_left = int(lane_geometry.get("x")) + int(activity_geometry.get("x"))
                    activity_top = int(lane_geometry.get("y")) + int(activity_geometry.get("y"))
                    activity_right = activity_left + int(activity_geometry.get("width"))
                    activity_bottom = activity_top + int(activity_geometry.get("height"))
                    self.assertGreaterEqual(activity_left, frame_left)
                    self.assertGreaterEqual(activity_top, frame_top)
                    self.assertLessEqual(activity_right, frame_right)
                    self.assertLessEqual(activity_bottom, frame_bottom)


if __name__ == "__main__":
    unittest.main()
