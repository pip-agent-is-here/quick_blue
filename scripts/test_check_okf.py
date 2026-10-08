"""Regression tests for the repository's OKF quality gate."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

import yaml

spec = importlib.util.spec_from_file_location("check_okf", Path(__file__).with_name("check-okf.py"))
assert spec is not None and spec.loader is not None
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class CheckOkfTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.bundle = Path(self.directory.name)
        (self.bundle / "index.md").write_text('---\nokf_version: "0.2"\n---\n\n[Concept](concept.md) - Description.\n')
        (self.bundle / "source.txt").write_text("Implementation reference.\n")
        self.metadata = {
            "type": "Reference", "title": "Concept", "description": "Description.",
            "tags": ["testing"],
            "sources": [{"id": "source", "resource": "source.txt"}],
        }
        self.body = "# Concept\n\nClaim.[^source]\n\n[^source]: Implementation.\n"

    def check(self):
        (self.bundle / "concept.md").write_text(
            "---\n" + yaml.safe_dump(self.metadata) + "---\n\n" + self.body)
        return checker.check(self.bundle)[0]

    def assert_error(self, expected):
        self.assertTrue(any(expected in error for error in self.check()), expected)

    def test_log_and_generated_are_optional(self):
        self.assertEqual([], self.check())

    def test_valid_optional_generated(self):
        self.metadata["generated"] = {"by": "process:checker", "at": "2026-10-08T00:00:00Z"}
        self.assertEqual([], self.check())

    def test_invalid_optional_generated(self):
        for value in (None, "actor", {}, {"by": "invalid", "at": "bad"},
                      {"by": "process:checker", "at": "2026-10-08T00:00:00"}):
            with self.subTest(value=value):
                self.metadata["generated"] = value
                self.assertTrue(self.check())

    def test_required_metadata(self):
        for key in ("type", "title", "description", "tags", "sources"):
            with self.subTest(key=key):
                original = self.metadata.pop(key)
                self.assertTrue(self.check())
                self.metadata[key] = original

    def test_missing_source(self):
        self.metadata["sources"][0]["resource"] = "missing.txt"
        self.assert_error("missing source")

    def test_duplicate_source_ids(self):
        self.metadata["sources"] *= 2
        self.assert_error("source IDs must be unique")

    def test_footnote_join(self):
        self.body += "\n[^unknown]: Unknown source.\n"
        self.assert_error("footnote has no source ID")

    def test_undefined_footnote(self):
        self.body = "Claim.[^source]\n"
        self.assert_error("undefined footnote")

    def test_broken_local_link(self):
        self.body += "\n[Missing](missing.md)\n"
        self.assert_error("broken local link")

    def test_index_coverage(self):
        (self.bundle / "index.md").write_text('---\nokf_version: "0.2"\n---\n')
        self.assert_error("concept absent from indexes")

    def test_reserved_index_metadata(self):
        (self.bundle / "index.md").write_text('---\nokf_version: "0.2"\ntitle: Index\n---\n[Concept](concept.md)\n')
        self.assert_error("root index must declare only")

    def test_optional_log_remains_validated(self):
        log = self.bundle / "log.md"
        log.write_text("# Log\n\n## 2026-10-08\n")
        self.assertEqual([], self.check())
        log.write_text("# Log\n\n## not-a-date\n")
        self.assert_error("invalid log date")

    def test_duplicate_yaml_keys(self):
        self.check()
        path = self.bundle / "concept.md"
        path.write_text(path.read_text().replace("---\n", "---\ntype: Duplicate\n", 1))
        self.assertTrue(any("duplicate YAML key" in error for error in checker.check(self.bundle)[0]))


if __name__ == "__main__":
    unittest.main()
