#!/usr/bin/env python3
"""Check the docs/ OKF 0.2 bundle and repository documentation quality policy.

Requires PyYAML (scripts/requirements-docs.txt). Local paths are checked;
external URLs and semantic/hardware claims require separate review.
"""

import argparse
from datetime import date, datetime
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

import yaml


class UniqueLoader(yaml.SafeLoader):
    """Reject duplicate YAML keys instead of silently hiding an old value."""


def mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)


def check(bundle):
    errors = []
    documents = sorted(bundle.rglob("*.md"))
    indexed = set()
    concepts = set()
    links = 0

    def require(condition, path, message):
        if not condition:
            errors.append(f"{path.relative_to(bundle)}: {message}")

    def target(path, resource):
        parts = urlsplit(resource)
        if parts.scheme or parts.netloc:
            return None
        local = unquote(parts.path)
        resolved = (bundle / local.lstrip("/") if local.startswith("/")
                    else path.parent / local).resolve()
        if resolved.is_dir():
            resolved /= "index.md"
        return resolved

    if not documents:
        return ["bundle contains no Markdown documents"], 0, 0
    require((bundle / "index.md").is_file(), bundle / "index.md", "missing root index")
    for path in documents:
        text = path.read_text(encoding="utf-8")
        metadata = None
        body = text
        if text.startswith("---\n"):
            match = re.match(r"\A---\n(.*?)\n---\n(.*)\Z", text, re.S)
            if not match:
                require(False, path, "unclosed frontmatter")
                continue
            try:
                metadata = yaml.load(match[1], Loader=UniqueLoader)
            except (yaml.YAMLError, ValueError, TypeError) as error:
                require(False, path, f"invalid YAML: {error}")
                continue
            body = match[2]
            require(isinstance(metadata, dict), path, "frontmatter must be a mapping")
            if not isinstance(metadata, dict):
                continue

        if path.name == "index.md":
            if path == bundle / "index.md":
                require(metadata == {"okf_version": "0.2"}, path,
                        'root index must declare only okf_version: "0.2"')
            else:
                require(metadata is None, path, "nested index must not have frontmatter")
        elif path.name == "log.md":
            require(metadata is None, path, "log must not have frontmatter")
            headings = re.findall(r"^## (.+)$", body, re.M)
            dates = []
            for heading in headings:
                try:
                    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", heading):
                        raise ValueError("not YYYY-MM-DD")
                    dates.append(date.fromisoformat(heading))
                except ValueError:
                    require(False, path, f"invalid log date: {heading}")
            require(bool(dates) and dates == sorted(set(dates), reverse=True), path,
                    "log dates must be unique and newest first")
        else:
            concepts.add(path.resolve())
            require(isinstance(metadata, dict), path, "concept requires YAML frontmatter")
            if not isinstance(metadata, dict):
                continue
            for key in ("type", "title", "description"):
                require(isinstance(metadata.get(key), str) and bool(metadata[key].strip()),
                        path, f"missing non-empty {key}")
            require(isinstance(metadata.get("tags"), list) and
                    all(isinstance(tag, str) and tag for tag in metadata["tags"]),
                    path, "tags must be a string list")
            generated = metadata.get("generated")
            if "generated" in metadata:
                require(isinstance(generated, dict), path, "generated must be a mapping")
            if isinstance(generated, dict):
                actor = generated.get("by", "")
                require(isinstance(actor, str) and bool(re.fullmatch(
                    r"(?:human:[^\s]+|process:[^\s]+|[^\s/]+/[^\s/]+)", actor)),
                    path, "invalid generated actor")
                try:
                    instant = datetime.fromisoformat(str(generated.get("at", "")).replace("Z", "+00:00"))
                    require(instant.utcoffset() is not None, path, "generated.at needs UTC offset")
                except ValueError:
                    require(False, path, "generated.at must be ISO 8601")
            sources = metadata.get("sources", [])
            require(isinstance(sources, list) and bool(sources), path, "sources required by repo policy")
            ids = set()
            if isinstance(sources, list):
                for source in sources:
                    if not isinstance(source, dict):
                        require(False, path, "source must be a mapping")
                        continue
                    resource = source.get("resource")
                    require(isinstance(resource, str) and bool(resource), path, "source needs resource")
                    if isinstance(resource, str) and resource:
                        resolved = target(path, resource)
                        require(resolved is None or resolved.is_file(), path,
                                f"missing source: {resource}")
                    source_id = source.get("id")
                    require(isinstance(source_id, str) and source_id not in ids, path,
                            "source IDs must be unique strings")
                    ids.add(source_id)
            for label in set(re.findall(r"\[\^([^\]]+)\]", body)):
                require(label in ids, path, f"footnote has no source ID: {label}")
                require(bool(re.search(r"^\[\^" + re.escape(label) + r"\]:", body, re.M)),
                        path, f"undefined footnote: {label}")

        # Ignore code fences: examples may contain illustrative Markdown paths.
        prose = re.sub(r"```.*?```", "", body, flags=re.S)
        for resource in re.findall(r"\[[^\]\n]+\]\(([^)\s]+)\)", prose):
            resolved = target(path, resource)
            if resolved is not None:
                links += 1
                require(resolved.is_file(), path, f"broken local link: {resource}")
                if path.name == "index.md":
                    indexed.add(resolved)
    for path in sorted(concepts - indexed):
        require(False, path, "concept absent from indexes")
    return errors, len(concepts), links


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", nargs="?", type=Path,
                        default=Path(__file__).resolve().parents[1] / "docs")
    args = parser.parse_args()
    errors, concepts, links = check(args.bundle.resolve())
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"OKF 0.2: {concepts} concepts; {links} local links; metadata, sources and indexes pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
