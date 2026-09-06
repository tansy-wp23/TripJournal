import unittest

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


if __name__ == "__main__":
    unittest.main()
