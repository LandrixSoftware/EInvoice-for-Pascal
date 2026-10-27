#!/usr/bin/env python3
"""Copies the official test material for the semantic sweep (plan, Phase 2
step 3) and the KoSIT end-to-end run (plan, phase 6) from the documentation
folder into tests/data/local/ (git-ignored; the material is never committed).

The committed manifest corpora.json names every file with its SHA-256, so a
run checks that the local copy is complete and unchanged; each corpus folder
also gets a MANIFEST.txt ("sha256  name" per line) that the test runner reads,
so a missing file fails the sweep instead of being skipped. Test runs on WSL
and the Mac see only the repository, therefore the files are copied, not read
from the documentation folder.

Corpora:
  kosit-xr302   KoSIT XRechnung 3.0.2 testsuite (bundle 2026-01-31), all
                instances: standard, extension, technical-cases
  zugferd252    ZUGFeRD 2.5.2 / Factur-X 1.09.2 examples of every profile
  peppol        Peppol BIS Billing 3.0 examples (May 2026), invoices only
  kosit-suite   KoSIT XRechnung 3.0.2 testsuite 2026-08-31, the release that
                matches validator configuration 2026-08-31 in
                addons/java-tools/tools.json (tests/data/local/kosit/instances)
  kosit-rules   the Schematron rule files and their .sch sources from the
                LandrixXML submodule (external/landrix-xml/tests/data/
                schematron, checked there against the configuration's XSLT),
                with their NOTICE.md (tests/data/local/kosit/rules); the
                paths below that folder are kept
  kosit-peppol  the Peppol BIS Billing 3.0.21 schematron PEPPOL-EN16931-UBL.sch
                (May 2026 release), which the validator compiles when it
                loads (tests/data/local/kosit/peppol); its EN16931 rules are
                the en16931-ubl of kosit-rules

Usage:
  python tools/testdata/sync-local.py [--docs <folder>]            copy and verify
  python tools/testdata/sync-local.py [--docs <folder>] --update   rewrite corpora.json
The documentation folder defaults to ../landrix-einvoice-docs next to the
repository (D:/Projekte/landrix-einvoice-docs, see its INHALT.md).
"""

import argparse
import fnmatch
import hashlib
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
MANIFEST = os.path.join(HERE, "corpora.json")
LOCAL = os.path.join(REPO, "tests", "data", "local")

SOURCES = {
    "kosit-xr302": {
        "root": "XRechnung 3.0.2/xrechnung-3.0.2-bundle-2026-01-31/xrechnung-3.0.2-testsuite-2026-01-31/instances",
        "flatten": True,
        "exclude": [],
    },
    "zugferd252": {
        "root": "zugferd25-facturx1009-02/zugferd252de/Beispiele",
        "flatten": False,
        "exclude": [],
    },
    "peppol": {
        "root": "Peppol BIS Billing 3.0 - May 2026 Release/BIS-Billing3-Examples/rules/examples",
        "flatten": False,
        "exclude": ["sales-order-example.xml"],
    },
    "kosit-suite": {
        "root": "XRechnung 3.0.2/xrechnung-3.0.2-testsuite-2026-08-31/instances",
        "flatten": True,
        "exclude": [],
        "target": "kosit/instances",
    },
    "kosit-rules": {
        "root": "external/landrix-xml/tests/data/schematron",
        "base": "repo",
        "keep_paths": True,
        "include": ["NOTICE.md", "rules/*.xml", "sources/*.sch"],
        "exclude": [],
        "target": "kosit/rules",
    },
    "kosit-peppol": {
        "root": "Peppol BIS Billing 3.0 - May 2026 Release",
        "include": ["PEPPOL-EN16931-UBL.sch"],
        "flatten": False,
        "exclude": [],
        "target": "kosit/peppol",
    },
}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def ascii_name(name):
    """Target names stay ASCII: the test runner reads MANIFEST.txt as 8-bit text."""
    for a, b in ((228, "ae"), (246, "oe"), (252, "ue"), (196, "Ae"), (214, "Oe"), (220, "Ue"), (223, "ss")):
        name = name.replace(chr(a), b)
    return "".join(c if ord(c) < 128 else "_" for c in name)


def collect(docs, spec):
    """{target name: source path} for every XML below the corpus root (or the
    files matching "include", relative paths with '*' also matching '/')."""
    base = REPO if spec.get("base") == "repo" else docs
    root = os.path.join(base, spec["root"])
    if not os.path.isdir(root):
        sys.exit("missing: %s" % root)
    out = {}
    for dirpath, _, files in os.walk(root):
        for name in files:
            rel = os.path.relpath(os.path.join(dirpath, name), root).replace(os.sep, "/")
            if "include" in spec:
                if not any(fnmatch.fnmatch(rel, x) for x in spec["include"]):
                    continue
            elif not name.lower().endswith(".xml"):
                continue
            if any(fnmatch.fnmatch(name, x) for x in spec["exclude"]):
                continue
            if spec.get("keep_paths"):
                target = ascii_name(rel)
            else:
                target = ascii_name(rel.replace("/", "_") if spec["flatten"] else name)
            if target in out:
                sys.exit("duplicate target name %s" % target)
            out[target] = os.path.join(dirpath, name)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--docs", default=os.path.join(os.path.dirname(REPO), "landrix-einvoice-docs"))
    ap.add_argument("--update", action="store_true", help="rewrite corpora.json from the documentation folder")
    args = ap.parse_args()

    if args.update:
        data = {}
        for corpus, spec in sorted(SOURCES.items()):
            files = collect(args.docs, spec)
            data[corpus] = {"root": spec["root"], "files": {n: sha256(p) for n, p in sorted(files.items())}}
        with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, indent=1, sort_keys=True)
            f.write("\n")
        print("corpora.json: " + ", ".join("%s %d" % (c, len(d["files"])) for c, d in sorted(data.items())))
        return 0

    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    failed = 0
    for corpus, entry in sorted(manifest.items()):
        files = collect(args.docs, SOURCES[corpus])
        dest = os.path.join(LOCAL, *SOURCES[corpus].get("target", "sweep/" + corpus).split("/"))
        if os.path.isdir(dest):
            shutil.rmtree(dest)
        os.makedirs(dest)
        lines = []
        for name, digest in sorted(entry["files"].items()):
            src = files.get(name)
            if src is None:
                print("missing in the documentation folder: %s/%s" % (corpus, name))
                failed += 1
                continue
            if sha256(src) != digest:
                print("checksum differs: %s/%s" % (corpus, name))
                failed += 1
                continue
            out = os.path.join(dest, *name.split("/"))
            os.makedirs(os.path.dirname(out), exist_ok=True)
            shutil.copyfile(src, out)
            lines.append("%s  %s\n" % (digest, name))
        extra = sorted(set(files) - set(entry["files"]))
        for name in extra:
            print("not in corpora.json (run --update): %s/%s" % (corpus, name))
            failed += 1
        with open(os.path.join(dest, "MANIFEST.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.writelines(lines)
        print("%-12s %3d files -> %s" % (corpus, len(lines), os.path.relpath(dest, REPO)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
