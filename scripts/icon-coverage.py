#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Inventory icon coverage without inventing resource IDs or replacing artwork."""
import argparse
import configparser
import hashlib
import json
import os
from collections import defaultdict
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
EXTENSIONS = {".svg", ".svgz", ".png", ".xpm"}
NAME = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.+-]*$")
# Source candidates, not a QML/C++ parser or a claim of runtime coverage.
# Keep legacy name counts separate from exact private paths and expressions.
REFERENCE = re.compile(
    r'\b(icon\.name|iconName|iconSource|icon|source)\s*(?::|=(?!=))\s*["\']([^"\']+)["\']'
)
QML_FIELD = re.compile(
    r'\b(icon\.name|icon\.source|iconName|iconSource|nativeIconName|fallbackRoleName|roleName|icon|source)\s*'
    r'(?::|=(?!=))\s*(.*)'
)
QUOTED = re.compile(r'["\']([^"\']+)["\']')
ROLE = re.compile(r'^(?:actions|status|devices|apps|emblems|categories|places|mimetypes)/'
                  r'[A-Za-z0-9_.+-]+$')
CPP_THEME = re.compile(r'QIcon::fromTheme\s*\(\s*(?:QStringLiteral\s*\(\s*)?["\']([^"\']+)["\']')
CPP_LITERAL = re.compile(r'QStringLiteral\s*\(\s*"([^"]+)"\s*\)')
CAPTION_CALL = re.compile(r'new\s+CaptionButton\s*\([^;]+?\);', re.S)
GLYPH_PATH_CALL = re.compile(r'glyphPath\s*\(\s*QStringLiteral\s*\(\s*"([^"]+)"\s*\)\s*\)')
ASSET_EXTENSIONS = EXTENSIONS | {".jpg", ".jpeg", ".webp", ".ico"}


def read_ini(path):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        with path.open(encoding="utf-8") as f:
            parser.read_file(f)
    except (OSError, UnicodeError, configparser.Error):
        return None
    return parser


def theme_inventory(theme):
    config = read_ini(theme / "index.theme")
    if config is None or not config.has_section("Icon Theme"):
        raise ValueError("Missing or unreadable icon theme index")
    index = config["Icon Theme"]
    names = defaultdict(list)
    broken = []
    missing_dirs = []
    dirs = set((index.get("Directories", "") + "," +
                index.get("ScaledDirectories", "")).split(",")) - {""}
    for directory in sorted(dirs):
        folder = theme / directory
        if not folder.is_dir():
            missing_dirs.append(directory)
            continue
        for path in sorted(folder.iterdir()):
            if path.suffix.lower() not in EXTENSIONS:
                continue
            rel = path.relative_to(theme).as_posix()
            if path.is_symlink() and not path.exists():
                broken.append(rel)
            elif path.is_file():
                names[path.stem].append(rel)
    return dict(names), broken, missing_dirs


def native_inventory(mapping, manifest, theme, names):
    expected = defaultdict(list)
    for source, targets in mapping["icons"].items():
        for target in targets.split():
            expected[Path(target).name].append((source, target + ".svg"))
    outputs = manifest.get("outputs", {})
    actual = defaultdict(list)
    mismatched = []
    unindexed = []
    indexed_paths = {path for paths in names.values() for path in paths}
    for rel, info in sorted(outputs.items()):
        if not rel.startswith("icons/") or not rel.endswith(".svg"):
            continue
        target = rel.removeprefix("icons/")
        # Do not read arbitrary paths specified by a local manifest.
        if ".." in Path(target).parts or Path(target).is_absolute():
            raise ValueError("Invalid native icon output path")
        path = theme / target
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != info["sha256"]:
            mismatched.append(target)
        elif target not in indexed_paths:
            # Hash parity alone does not make an icon visible to the theme
            # loader. Keep valid but unindexed outputs outside coverage.
            unindexed.append(target)
        else:
            actual[path.stem].append(target)
    return expected, actual, mismatched, unindexed


def qml_candidates(root):
    found = defaultdict(list)
    for path in sorted((root / "plasma").rglob("*.qml")):
        if any(p.startswith("build") for p in path.parts):
            continue
        for line, content in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for match in REFERENCE.finditer(content):
                field, name = match.groups()
                if NAME.fullmatch(name) and not Path(name).suffix.lower() in (
                    EXTENSIONS | {".qml", ".js", ".json", ".jpg", ".webp"}
                ):
                    found[name].append({
                        "file": path.relative_to(root).as_posix(),
                        "line": line, "field": field,
                    })
    return found


def source_candidates(root, expected, names):
    """Collect distinct source sites outside the legacy name inventory.

    Literal private paths are compared by exact context/name. Dynamic
    providers, local images and QIcon theme lookups remain candidates;
    never treat a syntactic match as proof of Windows origin.
    """
    mapped_paths = {path.removesuffix(".svg")
                    for entries in expected.values() for _, path in entries}
    report = defaultdict(list)

    def add(kind, path, line, value, **details):
        report[kind].append({"file": path.relative_to(root).as_posix(),
                             "line": line, "value": value, **details})

    def private_role(path, line, role):
        if ROLE.fullmatch(role):
            add("private_role_mapped" if role in mapped_paths
                else "private_role_unmapped", path, line, role)

    def literal(path, line, value, field=""):
        if value.startswith("windows-modern/native-assets/icons/"):
            role = value.removeprefix("windows-modern/native-assets/icons/").removesuffix(".svg")
            if ROLE.fullmatch(role):
                private_role(path, line, role)
            else:
                add("private_path_expression", path, line, value)
        elif value.startswith("windows-modern/shell-assets/"):
            add("private_shell_asset", path, line, value)
        elif value.startswith("data:image/"):
            add("inline_artwork", path, line, value[:100])
        elif Path(value).suffix.lower() in ASSET_EXTENSIONS:
            add("direct_artwork", path, line, value)
        elif field in ("roleName", "fallbackRoleName", "nativeIconName") and NAME.fullmatch(value):
            alternate = (value.removesuffix("-symbolic") if value.endswith("-symbolic")
                         else value + "-symbolic")
            mapped = value in expected or alternate in expected
            add("private_name_mapped" if mapped else "private_name_unmapped",
                path, line, value)
        elif field and NAME.fullmatch(value) and not Path(value).suffix.lower() in (".qml", ".js", ".json"):
            add("theme_name_candidate", path, line, value,
                mapped=value in expected, bundled=value in names)

    for directory in (root / "plasma", root / "app-decorations"):
        for path in sorted(directory.rglob("*")):
            if path.suffix not in (".qml", ".cpp", ".h") or not path.is_file():
                continue
            if any(part.startswith("build") for part in path.relative_to(root).parts):
                continue
            source = path.read_text(encoding="utf-8")
            if path.name == "windowsmodernchrome.cpp":
                for call in CAPTION_CALL.finditer(source):
                    line = source.count("\n", 0, call.start()) + 1
                    for value in CPP_LITERAL.findall(call.group(0)):
                        if NAME.fullmatch(value):
                            private_role(path, line, "actions/" + value)
                for call in GLYPH_PATH_CALL.finditer(source):
                    line = source.count("\n", 0, call.start()) + 1
                    private_role(path, line, "actions/" + call.group(1))
            for line, raw in enumerate(source.splitlines(), 1):
                content = raw.strip()
                if content.startswith(("//", "/*", "*")):
                    continue
                if path.suffix == ".qml":
                    field = QML_FIELD.search(content)
                    if field:
                        name, expr = field.groups()
                        expr = expr.strip()
                        if expr not in ('""', "''", '"";', "'';"):
                            first = QUOTED.match(expr)
                            if first and (first.group(1).startswith("data:image/")
                                          or not re.search(r'\?\s*["\']|\+\s*', expr)):
                                literal(path, line, first.group(1), name)
                            else:
                                add("dynamic_qml_candidate", path, line, expr[:200], field=name)
                    # A private resolver can occur inside a binding, on a
                    # continuation line, or in a JavaScript assignment.
                    for value in QUOTED.findall(content):
                        if ROLE.fullmatch(value) and "nativeMenuIcon" in content:
                            private_role(path, line, value)
                        elif ROLE.fullmatch(value) and re.search(r'^\s*\?\s*["\']', content):
                            private_role(path, line, value)
                        elif value.startswith(("windows-modern/native-assets/icons/",
                                                "windows-modern/shell-assets/")):
                            literal(path, line, value)
                    continue

                theme = CPP_THEME.search(content)
                if theme:
                    add("cpp_theme_name", path, line, theme.group(1),
                        mapped=theme.group(1) in expected, bundled=theme.group(1) in names)
                elif "QIcon::fromTheme(" in content:
                    add("dynamic_cpp_candidate", path, line, content[:200])
                for value in CPP_LITERAL.findall(content):
                    if ROLE.fullmatch(value):
                        private_role(path, line, value)
                    elif value.startswith(("windows-modern/native-assets/icons/",
                                            "windows-modern/shell-assets/")):
                        literal(path, line, value)

    # QML literal paths can be found both as a field and in the resolver.
    return {kind: list({(row["file"], row["line"], row["value"]): row
                       for row in rows}.values())
            for kind, rows in sorted(report.items())}


def desktop_candidates(data_dirs):
    found = defaultdict(list)
    seen = set()
    for base in data_dirs:
        folder = base / "applications"
        if not folder.is_dir():
            continue
        for path in sorted(folder.rglob("*.desktop")):
            desktop_id = path.relative_to(folder).as_posix().replace("/", "-")
            if desktop_id in seen:
                continue
            seen.add(desktop_id)
            config = read_ini(path)
            if config is None or not config.has_section("Desktop Entry"):
                continue
            entry = config["Desktop Entry"]
            if (entry.get("Type") != "Application" or
                    entry.get("Hidden", "").lower() == "true" or
                    entry.get("NoDisplay", "").lower() == "true"):
                continue
            icon = entry.get("Icon", "").strip()
            if icon:
                found[icon].append(desktop_id)
    return found


def same_name_alternates(names, actual):
    """List files not individually verified alongside a verified icon name."""
    return {
        name: {"verified_files": sorted(set(paths)),
               "unverified_files": sorted(set(names[name]) - set(paths))}
        for name, paths in sorted(actual.items())
        if paths and set(names.get(name, [])) - set(paths)
    }


def classify(name, names, expected, actual):
    if "/" in name:
        return "path_bypasses_theme"
    if name in actual:
        # This is a name-level result: at least one file is verified.
        # Inspect same_name_alternates before claiming complete coverage.
        return "native_hash_verified"
    if name in expected:
        return "native_mapping_not_verified"
    if name in names:
        return "bundled_not_native_verified"
    return "not_in_theme"


KCM_METADATA = re.compile(
    r"(?m)^qt\.core\.plugin\.loader: Found metadata in lib ([^\r\n]+), metadata=\s*"
)


def kcm_candidates(log):
    """Read declared KCM names from Qt's plugin metadata log without loading plugins."""
    decoder = json.JSONDecoder()
    modules = defaultdict(set)
    log_text = log.read_text(encoding="utf-8", errors="replace")
    for match in KCM_METADATA.finditer(log_text):
        path = match.group(1)
        if "/plasma/kcms/" not in path or not path.endswith(".so"):
            continue
        # A malformed KCM record fails the audit rather than silently
        # reducing the inventory. Never copy host paths into the report.
        payload, _ = decoder.raw_decode(log_text, match.end())
        metadata = payload.get("MetaData", {})
        plugin = metadata.get("KPlugin", {})
        icon = plugin.get("Icon", "")
        category = metadata.get("X-KDE-System-Settings-Parent-Category", "")
        if not isinstance(icon, str) or not isinstance(category, str):
            raise ValueError("Invalid KCM icon or category metadata: " + Path(path).stem)
        modules[Path(path).stem].add((icon, category))
    if not modules:
        raise ValueError("No KDE KCM metadata records found")
    return dict(modules)


def kcm_inventory(modules, names, expected, actual):
    by_icon = defaultdict(set)
    rows = []
    for module, variants in sorted(modules.items()):
        for icon, category in sorted(variants):
            if icon:
                by_icon[icon].add(module)
            rows.append({"module": module, "declared_icon": icon, "category": category,
                         "status": classify(icon, names, expected, actual)
                         if icon else "no_icon_declared"})
    return {
        "module_count": len(modules),
        "unique_icon_names": len(by_icon),
        "modules": rows,
        "shared_icon_names": {icon: sorted(ids) for icon, ids in sorted(by_icon.items())
                              if len(ids) > 1},
        "conflicting_metadata": sorted(module for module, variants in modules.items()
                                       if len(variants) > 1),
    }


def shell_inventory(manifest_path):
    """Verify private shell output files separately from the global icon theme."""
    if not manifest_path.is_file():
        return {"manifest_present": False}
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("format") != "windows-modern-shell-assets-v1":
        raise ValueError("Unsupported shell artwork manifest")
    root = manifest_path.parent.resolve()
    outputs = manifest["outputs"]
    required = {f"battery/{code:04x}.svg"
                for code in (*range(0xf849, 0xf852), *range(0xf8d0, 0xf8ed))}
    required.update({"search/light-on.png", "search/light-off.png",
                     "search/dark-on.png", "task-view/light.svg", "task-view/dark.svg"})
    verified, changed = [], []
    for relative, record in sorted(outputs.items()):
        target = Path(relative)
        if target.is_absolute() or ".." in target.parts or not target.parts:
            raise ValueError("Invalid shell artwork output path")
        path = root / target
        if (not path.resolve().is_relative_to(root) or not path.is_file()
                or hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]):
            changed.append(relative)
        else:
            verified.append(relative)
    # Output hashes only prove consistency with the local manifest. Compare
    # its recorded inputs with the owner's independently recorded build audit.
    # A different or incomplete extraction remains usable, but is not an
    # exact match to this reference. Do not change the importer or UI here.
    reference = json.loads((ROOT / "docs/windows11-26h2-resource-audit.json")
                           .read_text(encoding="utf-8"))["windows"]
    recorded_sources = {name.casefold(): digest
                        for name, digest in manifest.get("sources", {}).items()}
    matched_sources, missing_sources, changed_sources = [], [], []
    for name, digest in sorted(reference["source_sha256"].items()):
        actual_digest = recorded_sources.get(name.casefold())
        if actual_digest is None:
            missing_sources.append(name)
        elif actual_digest != digest:
            changed_sources.append(name)
        else:
            matched_sources.append(name)
    # The reference includes both assets which are optional for other builds.
    reference_required = required | {"search/dark-off.png", "account/default.png"}
    reference_missing_outputs = sorted(reference_required - set(verified))
    return {
        "manifest_present": True,
        "declared_source_build": manifest.get("declared_source_build"),
        "reference_build": reference["build"],
        "declared_build_matches_reference": manifest.get("declared_source_build") == reference["build"],
        "reference_sources_matched": matched_sources,
        "reference_sources_missing": missing_sources,
        "reference_sources_changed": changed_sources,
        "reference_outputs_missing_or_changed": reference_missing_outputs,
        "declared_output_count": len(outputs),
        "verified_outputs": verified,
        "missing_or_changed_outputs": changed,
        "required_outputs_missing_from_manifest": sorted(required - outputs.keys()),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installed", action="store_true", help="Audit installed icons and XDG desktop entries")
    parser.add_argument("--theme", type=Path, help="Override icon theme path")
    parser.add_argument("--manifest", type=Path, help="Override local import manifest")
    parser.add_argument("--kcm-metadata", type=Path, help="Read a Qt plugin metadata log from kcmshell6 --list")
    parser.add_argument("--shell-manifest", type=Path, help="Override the private shell artwork manifest path")
    args = parser.parse_args()
    data_home = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    theme = args.theme or (data_home / "icons/windows-modern" if args.installed else ROOT / "icons/windows-modern")
    manifest_path = args.manifest or data_home / "windows-modern/native-assets/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.is_file() else {}
    mapping = json.loads((ROOT / "scripts/native-assets-map.json").read_text(encoding="utf-8"))
    names, broken, missing_dirs = theme_inventory(theme)
    expected, actual, mismatched, unindexed = native_inventory(mapping, manifest, theme, names)
    alternates = same_name_alternates(names, actual)
    qml = qml_candidates(ROOT)
    sources = source_candidates(ROOT, expected, names)
    desktop = desktop_candidates([data_home] + [
        Path(p) for p in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if p
    ]) if args.installed else {}
    kcm = (kcm_inventory(kcm_candidates(args.kcm_metadata), names, expected, actual)
           if args.kcm_metadata is not None else None)
    by_kcm_icon = defaultdict(list)
    if kcm is not None:
        for row in kcm["modules"]:
            if row["declared_icon"]:
                by_kcm_icon[row["declared_icon"]].append(row["module"])
    shell = shell_inventory(args.shell_manifest or
                            data_home / "windows-modern/shell-assets/manifest.json")
    report = defaultdict(list)
    for name in sorted(set(qml) | set(desktop) | set(expected) | set(by_kcm_icon)):
        status = classify(name, names, expected, actual)
        report[status].append({
            "name": name,
            "native_mapping": expected.get(name, []),
            "verified_native_files": actual.get(name, []),
            "unverified_same_name_files": alternates.get(name, {}).get("unverified_files", []),
            "theme_files": names.get(name, []),
            "qml_candidates": qml.get(name, []),
            "desktop_ids": desktop.get(name, []),
            "kcm_modules": sorted(set(by_kcm_icon.get(name, []))),
        })
    print(json.dumps({
        "mode": "installed" if args.installed else "repository",
        "manifest_present": bool(manifest),
        "theme_icon_names": len(names),
        "mapped_native_paths": sum(map(len, expected.values())),
        "verified_native_paths": sum(map(len, actual.values())),
        "broken_theme_links": broken,
        "missing_index_directories": missing_dirs,
        "native_output_missing_or_changed": mismatched,
        "native_output_unindexed": unindexed,
        "same_name_alternates": alternates,
        "same_name_alternate_name_count": len(alternates),
        "same_name_alternate_file_count": sum(len(row["unverified_files"]) for row in alternates.values()),
        "counts": {k: len(v) for k, v in sorted(report.items())},
        "references": dict(sorted(report.items())),
        "kcm_metadata": kcm,
        "shell_artwork": shell,
        "source_reference_counts": {kind: len(rows) for kind, rows in sources.items()},
        "source_references": sources,
        "limitations": [
            "Not in this theme may still resolve through inherited themes.",
            "Bundled does not establish Windows origin; verify the resource before replacing.",
            "QML source and C++ literal scans are heuristic, not complete expression or data-flow analysis.",
            "Exact private role mapping proves a declared source, not local asset presence; direct artwork, native controls and dynamic pixmaps require provenance and live review.",
            "A verified output hash in an indexed directory establishes local import parity, not semantic identity, Windows version or actual runtime icon resolution.",
            "Native name counts mean at least one verified path; same-name alternate files may have different contexts or bytes and are not independently verified.",
            "KCM metadata lists declared icons, not the runtime-resolved theme file or category and page-internal controls.",
            "Private shell manifest hashes establish output parity; reference input hashes are compared with the recorded owner audit, not independently rehashed from the original Windows image."
        ],
    }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
