#!/usr/bin/env python3
"""OKF v0.2 bundle validator and index generator.

Usage:
  okf.py check [--root knowledge]
  okf.py index [--root knowledge] [--write]

Conformance per OKF SPEC §11:
  - Every non-reserved .md file has parseable YAML frontmatter with non-empty `type`
  - Reserved names: index.md (no frontmatter except root okf_version), log.md (ISO dates)
  - Broken cross-links reported as warnings (spec §6.1: consumers MUST tolerate)

Index generation per §8: one section per concept type, entries with
relative URLs and the concept's description.
"""
import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("error: PyYAML is required (pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

RESERVED = {"index.md", "log.md"}
FRONTMATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def split_frontmatter(path):
    """Return (frontmatter_str, body) or (None, full_text) if no frontmatter."""
    text = path.read_text(encoding="utf-8")
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None, text
    return m.group(1), text[m.end():]


def parse_frontmatter(path):
    """Return (data_dict, body) or raise ValueError with context."""
    fm, body = split_frontmatter(path)
    if fm is None:
        raise ValueError("missing YAML frontmatter block")
    try:
        data = yaml.safe_load(fm)
    except yaml.YAMLError as exc:
        raise ValueError(f"unparseable YAML frontmatter: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError("frontmatter must be a YAML mapping")
    return data, body


def extract_links(body):
    """Yield local markdown link targets (not URLs, not anchors)."""
    for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", body):
        target = target.strip()
        if target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        yield target


def resolve_target(root, origin_dir, target):
    if target.startswith("/"):
        cand = root / target.lstrip("/")
    else:
        cand = (origin_dir / target).resolve()
    try:
        return cand.relative_to(root.resolve())
    except ValueError:
        return None


def check_log(path):
    """Validate log.md: ## YYYY-MM-DD headings, newest first."""
    violations = []
    warnings = []
    _, body = split_frontmatter(path)
    headings = re.findall(r"^##\s+(\d{4}-\d{2}-\d{2})", body, re.MULTILINE)
    for h in headings:
        if not DATE_RE.match(h):
            violations.append(f"{path}: log heading not ISO 8601: {h}")
    if headings != sorted(headings, reverse=True):
        warnings.append(f"{path}: log entries not newest-first")
    return violations, warnings


def check_concept(root, path):
    violations = []
    warnings = []
    try:
        data, body = parse_frontmatter(path)
    except ValueError as exc:
        return [f"{path}: {exc}"], []
    if not data.get("type"):
        violations.append(f"{path}: frontmatter missing non-empty 'type'")
    for target in extract_links(body):
        resolved = resolve_target(root, path.parent, target)
        if resolved is None or not (root / resolved).exists():
            warnings.append(f"{path}: broken link -> {target}")
    return violations, warnings


def check(root):
    violations = []
    warnings = []
    for path in sorted(root.rglob("*.md")):
        rel = path.relative_to(root)
        if path.name == "index.md":
            data, body = split_frontmatter(path)
            if rel != Path("index.md"):
                if data not in (None, ""):
                    violations.append(f"{path}: non-root index.md must not carry frontmatter")
            elif data:
                try:
                    idx = yaml.safe_load(data) or {}
                except yaml.YAMLError:
                    idx = {}
                for key in idx:
                    if key != "okf_version":
                        violations.append(f"{path}: root index.md may only carry okf_version (has '{key}')")
        elif path.name == "log.md":
            v, w = check_log(path)
            violations += v
            warnings += w
        else:
            v, w = check_concept(root, path)
            violations += v
            warnings += w
    return violations, warnings


def gen_index(root, directory, okf_version=None):
    concepts = []
    for path in sorted(directory.glob("*.md")):
        if path.name in RESERVED:
            continue
        try:
            data, _ = parse_frontmatter(path)
        except ValueError:
            continue
        concepts.append((path, data))

    sections = {}
    for path, data in concepts:
        sections.setdefault(data.get("type", "Concepts"), []).append((path, data))

    lines = []
    for ctype in sorted(sections):
        lines.append(f"# {ctype}")
        lines.append("")
        for path, data in sections[ctype]:
            title = data.get("title") or path.stem
            desc = data.get("description") or ""
            lines.append(f"* [{title}]({path.name}) - {desc}")
        lines.append("")

    body = "\n".join(lines).rstrip() + "\n"
    if okf_version is not None:
        return f"---\nokf_version: \"{okf_version}\"\n---\n\n{body}"
    return body


def cmd_index(root, write):
    directories = [root] if not (root / "index.md").exists() else []
    directories += sorted(
        p for p in root.iterdir()
        if p.is_dir() and not p.name.startswith(".")
    )
    for directory in directories:
        okf_version = None
        root_index = directory / "index.md"
        if root_index.exists():
            data, _ = split_frontmatter(root_index)
            if data:
                try:
                    okf_version = (yaml.safe_load(data) or {}).get("okf_version")
                except yaml.YAMLError:
                    okf_version = None
        content = gen_index(root, directory, okf_version)
        if write:
            root_index.write_text(content, encoding="utf-8")
            print(f"wrote {root_index}")
        else:
            print(f"--- {root_index}")
            print(content)


def main():
    parser = argparse.ArgumentParser(description="OKF v0.2 bundle tooling")
    parser.add_argument("command", choices=["check", "index"])
    parser.add_argument("--root", default="knowledge", help="bundle root (default: knowledge)")
    parser.add_argument("--write", action="store_true", help="index: write files instead of printing")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"error: bundle root not found: {root}", file=sys.stderr)
        sys.exit(1)

    if args.command == "check":
        violations, warnings = check(root)
        for w in warnings:
            print(f"warning: {w}")
        for v in violations:
            print(f"error:   {v}")
        if violations:
            print(f"\ncheck failed: {len(violations)} violation(s), {len(warnings)} warning(s)")
            sys.exit(1)
        print(f"\ncheck passed: {len(warnings)} warning(s)")
    else:
        cmd_index(root, args.write)


if __name__ == "__main__":
    main()
