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


if __name__ == "__main__":
    unittest.main()
