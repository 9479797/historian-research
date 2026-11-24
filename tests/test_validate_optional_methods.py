"""Tests for the optional history methods consistency check."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE_FILE = Path(__file__).resolve().parents[1] / "scripts" / "validate_optional_methods.py"
SPEC = importlib.util.spec_from_file_location("optional_validator", MODULE_FILE)
validator = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(validator)


class OptionalMethodValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for folder in validator.TARGETS:
            (self.root / folder).mkdir(parents=True)
        for method in validator.METHODS:
            for folder in validator.TARGETS:
                (self.root / folder / method).write_text("sample method", encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def test_matching_copies(self):
        self.assertEqual(validator.audit(self.root), [])
        self.assertEqual(validator.main(["check", str(self.root)]), 0)

    def test_changed_copy_is_detected(self):
        target = self.root / validator.TARGETS[1] / validator.METHODS[0]
        target.write_text("different", encoding="utf-8")
        self.assertTrue(any("mismatch" in s for s in validator.audit(self.root)))

    def test_missing_copy_is_detected(self):
        target = self.root / validator.TARGETS[2] / validator.METHODS[1]
        target.unlink()
        self.assertTrue(any("missing" in s for s in validator.audit(self.root)))


if __name__ == "__main__":
    unittest.main()
