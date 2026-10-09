"""Hermetic subprocess regressions for the built-site quality gate."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class CheckDocsSiteTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.write("scripts/check-docs-site.py", Path(__file__).with_name("check-docs-site.py").read_text())
        self.config()
        self.write("docs/index.md", "# Home\n")
        self.write("docs/concept.md", "# Concept\n")
        self.write("site/index.html", '<a href="concept/#topic">Concept</a>')
        self.write("site/concept/index.html", '<h1 id="topic">Topic</h1><a href="/quick_blue/#home">Home</a>')
        self.write("site/index.html", '<h1 id="home">Home</h1><a href="concept/#topic">Concept</a>')
        self.write("site/assets/search.js", "// search fixture\n")

    def write(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    def config(self, nav='[{Home = "index.md"}, {Section = [{Concept = "concept.md"}]}]'):
        self.write("zensical.toml", '[project]\ndocs_dir = "docs"\nsite_dir = "site"\n'
                   'site_url = "https://example.invalid/quick_blue/"\nnav = ' + nav + '\n')

    def check(self, diagnostic=None):
        for optimized in (False, True):
            with self.subTest(optimized=optimized):
                command = [sys.executable] + (["-O"] if optimized else [])
                result = subprocess.run(command + [str(self.root / "scripts/check-docs-site.py")],
                                        cwd=self.root, capture_output=True, text=True, timeout=10)
                output = result.stdout + result.stderr
                if diagnostic is None:
                    self.assertEqual(result.returncode, 0, output)
                    self.assertIn("2 navigation pages; 2 local HTML links/anchors pass", output)
                else:
                    self.assertEqual(result.returncode, 1, output)
                    self.assertIn(diagnostic, output)
                    self.assertNotIn("links/anchors pass", output)

    def test_valid_site(self):
        self.check()

    def test_encoded_anchor_and_external_links(self):
        self.write("site/index.html", '<h1 id="home"></h1><a href="concept/?q=x#%74opic">OK</a>'
                   '<a href="https://example.invalid/missing">External</a>'
                   '<a href="//example.invalid/missing">External</a>')
        self.check()

    def test_missing_anchor(self):
        self.write("site/index.html", '<a href="concept/#missing">Broken</a>')
        self.check("missing anchor: concept/#missing")

    def test_navigation_coverage(self):
        self.config('[{Home = "index.md"}]')
        self.check("navigation must cover exactly the Markdown bundle")

    def test_extra_navigation_entry(self):
        self.config('["index.md", "concept.md", "ghost.md"]')
        self.check("navigation must cover exactly the Markdown bundle")

    def test_duplicate_navigation(self):
        self.config('["index.md", "concept.md", "concept.md"]')
        self.check("duplicate navigation entries")

    def test_missing_rendered_page(self):
        (self.root / "site/concept/index.html").unlink()
        self.check("missing rendered page: concept.md")

    def test_unbuilt_site(self):
        shutil.rmtree(self.root / "site")
        self.check("build the site first")

    def test_prefix_escape(self):
        self.write("site/index.html", '<a href="/outside.html">Broken</a>')
        # Ensure this tests prefix enforcement, not an absent target.
        self.write("site/outside.html", "Outside")
        self.check("link escapes project prefix: /outside.html")

    def test_encoded_prefix_escape(self):
        self.write("site/index.html", '<a href="/%6futside.html">Broken</a>')
        self.write("site/outside.html", "Outside")
        self.check("link escapes project prefix: /%6futside.html")

    def test_missing_link_target(self):
        self.write("site/index.html", '<a href="missing.html">Broken</a>')
        self.check("index.html: missing link missing.html")

    def test_missing_search_assets(self):
        (self.root / "site/assets/search.js").unlink()
        self.check("search assets missing")


if __name__ == "__main__":
    unittest.main()
