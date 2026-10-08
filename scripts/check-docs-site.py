#!/usr/bin/env python3
"""Verify explicit navigation coverage and local links in a built Zensical site."""
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
import sys
import tomllib
from urllib.parse import unquote, urlsplit


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.links = []
        self.ids = set()
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])


def main():
    root = Path(__file__).resolve().parents[1]
    config = tomllib.loads((root / "zensical.toml").read_text())["project"]
    docs = root / config["docs_dir"]
    site = root / config["site_dir"]
    prefix = urlsplit(config["site_url"]).path
    entries = []

    def walk(value):
        if isinstance(value, str):
            entries.append(value)
        elif isinstance(value, list):
            for item in value:
                walk(item)
        elif isinstance(value, dict):
            for item in value.values():
                walk(item)

    walk(config["nav"])
    expected = {str(p.relative_to(docs)) for p in docs.rglob("*.md")}
    assert set(entries) == expected, "navigation must cover exactly the Markdown bundle"
    assert all(n == 1 for n in Counter(entries).values()), "duplicate navigation entries"
    pages = {p.resolve(): Page(p.read_text()) for p in site.rglob("*.html")}
    assert pages, "build the site first"
    for entry in entries:
        path = Path(entry)
        output = site / (path.with_suffix(".html") if path.name == "index.md"
                         else path.with_suffix("") / "index.html")
        assert output.resolve() in pages, f"missing rendered page: {entry}"
    checked = 0
    for path, page in pages.items():
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                continue
            local = unquote(url.path)
            if local.startswith("/"):
                assert local.startswith(prefix), f"link escapes project prefix: {link}"
                target = site / local[len(prefix):]
            else:
                target = path.parent / local if local else path
            if target.is_dir():
                target /= "index.html"
            target = target.resolve()
            assert target.is_file(), f"{path.relative_to(site)}: missing link {link}"
            if url.fragment and target in pages:
                assert unquote(url.fragment) in pages[target].ids, f"missing anchor: {link}"
            checked += 1
    assert any("search" in str(p.relative_to(site)).lower() for p in site.rglob("*")
               if p.is_file()), "search assets missing"
    print(f"Site: {len(entries)} navigation pages; {checked} local HTML links/anchors pass; search assets present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
