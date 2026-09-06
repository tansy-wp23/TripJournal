from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

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


if __name__ == "__main__":
    unittest.main()
