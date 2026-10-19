#!/usr/bin/env python3
"""Measure which Factur-X fields reach TLandrixInvoice (field comparison, plan Phase 2).

Steps:
1. Read the Factur-X field table (xlsx, one sheet per profile; checksum from
   manifest.json) into fields.json: every XPath with its business term, type
   and cardinality per profile.
2. Build one synthetic EXTENDED document holding every element and attribute
   path of the table once (synth-extended.xml).
3. Run FieldMapProbe on that document and on the CII corpus
   (tests/data/local/cii, optional). The probe reads each file, maps it to
   TLandrixInvoice and prints every diagnostic.
4. Join both: a path counts as not mapped when the synthetic document reports
   it (or a parent) as NotMapped; the corpus adds how many real files use it.
   Writes coverage.json and coverage.txt and prints the report.

One document cannot hold every combination: a few paths stay reported because
their alternative sits in the same place (BT-71 as ram:ID besides the
GlobalID, BT-60 likewise, card and account in one payment means). OVERRIDES
gives placeholders that would cause other false gaps a fitting value.

The field table is not in the repository. It ships in the documentation folder
of the ZUGFeRD 2.5.2 / Factur-X 1.09.2 package (see manifest.json).

Build the probe first (any local toolchain), e.g.:
  ./tools/build.ps1 fpc322-win64 -Program tools/fieldmap/FieldMapProbe.dpr -NoRun

Usage:
  python tools/fieldmap/fieldmap.py --table "<path>/1_FACTUR-X 1.09.2 - EN FR.xlsx"
      [--probe build/fpc322-win64/FieldMapProbe.exe] [--corpus tests/data/local/cii]
      [--out build/fieldmap] [--any-table]
Output goes to build/fieldmap/ (git-ignored).
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from xml.sax.saxutils import escape, quoteattr

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ROOT = "/rsm:CrossIndustryInvoice"
PROFILES = ["MINIMUM", "BASIC WL", "BASIC", "EN16931", "EXTENDED"]

XLSX_NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
           "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships"}

CII_NS = ('xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" '
          'xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" '
          'xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100" '
          'xmlns:qdt="urn:un:unece:uncefact:data:standard:QualifiedDataType:100"')
EXTENDED_GUIDELINE = "urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended"


# --- 1. field table -------------------------------------------------------

def _col_index(ref):
    n = 0
    for ch in re.match(r"[A-Z]+", ref).group(0):
        n = n * 26 + ord(ch) - 64
    return n - 1


def read_xlsx(path, wanted):
    """Return {sheet name: rows} for the wanted sheets; rows are lists of strings."""
    z = zipfile.ZipFile(path)
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in root.findall("m:si", XLSX_NS):
            shared.append("".join(t.text or "" for t in si.iter("{%s}t" % XLSX_NS["m"])))
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    target = {r.get("Id"): r.get("Target") for r in rels}
    sheets = {}
    for s in wb.find("m:sheets", XLSX_NS):
        if s.get("name") not in wanted:
            continue
        t = target[s.get("{%s}id" % XLSX_NS["r"])].lstrip("/")
        if not t.startswith("xl/"):
            t = "xl/" + t
        rows = []
        for row in ET.fromstring(z.read(t)).iter("{%s}row" % XLSX_NS["m"]):
            cells = {}
            for c in row.findall("m:c", XLSX_NS):
                v = c.find("m:v", XLSX_NS)
                if c.get("t") == "s" and v is not None:
                    val = shared[int(v.text)]
                elif c.get("t") == "inlineStr":
                    val = "".join(x.text or "" for x in c.iter("{%s}t" % XLSX_NS["m"]))
                else:
                    val = (v.text or "") if v is not None else ""
                cells[_col_index(c.get("r"))] = val
            rows.append([cells.get(i, "") for i in range(max(cells) + 1)] if cells else [])
        sheets[s.get("name")] = rows
    missing = [w for w in wanted if w not in sheets]
    if missing:
        sys.exit("sheets missing in the table: %s" % ", ".join(missing))
    return sheets


def extract_fields(table, manifest):
    spec = manifest["table"]
    names = spec["sheets"]
    sheets = read_xlsx(table, set(names.values()))
    fields = {}
    order = []
    for prof in PROFILES:
        rows = sheets[names[prof]]
        head = rows[spec["header_row"]]
        ci = {h.strip(): i for i, h in enumerate(head) if h}
        i_id, i_bt, i_type = ci["ID"], ci["Business Term"], ci["Type"]
        i_card = ci["XML Cardinality"]
        i_ext = ci["EXT PROFILES\nCardinality"]
        i_xp = [i for i, h in enumerate(head) if h.startswith("Xpath")][-1]
        for r in rows[spec["header_row"] + 1:]:
            r = r + [""] * (len(head) - len(r))
            xp = (r[i_xp] or "").strip()
            if not xp.startswith("/rsm:"):
                continue
            f = fields.get(xp)
            if f is None:
                f = {"id": r[i_id].strip(), "bt": " ".join(r[i_bt].split()), "type": r[i_type].strip(),
                     "xpath": xp, "card": {}, "profiles": []}
                fields[xp] = f
                order.append(xp)
            card = (r[i_ext] if prof == "EXTENDED" else r[i_card]).strip()
            if prof not in f["profiles"]:
                f["profiles"].append(prof)
                f["card"][prof] = card
            elif card.startswith("0"):
                # several rows share the path (e.g. BT-110/BT-111): optional if any row is
                f["card"][prof] = card
    return [fields[k] for k in order]


# --- 2. synthetic EXTENDED document ---------------------------------------

class Node:
    def __init__(self, name, path):
        self.name = name
        self.path = path
        self.children = []
        self.index = {}
        self.attrs = {}
        self.text = None


def _value_for(name):
    n = name.split(":")[-1]
    if n in ("DateTimeString", "DateString"):
        return "20260101"
    if n.endswith("Amount"):
        return "1.00"
    if n.endswith("Quantity") or n.endswith("Numeric"):
        return "1"
    if n.endswith("Percent"):
        return "19"
    if n == "Indicator":
        return "true"
    if n.endswith("CountryID"):
        return "DE"
    if n.endswith("CurrencyCode"):
        return "EUR"
    return "X1"


def _attr_value(name):
    return {"format": "102", "currencyID": "EUR", "unitCode": "C62"}.get(name[1:], "X1")


# Values a placeholder would turn into a false gap (path suffix -> value).
OVERRIDES = {
    # VAT identifiers: scheme VA, as EN 16931 binds them (FC would be the tax number)
    "/ram:SpecifiedTaxRegistration/ram:ID/@schemeID": "VA",
    # EN 16931 knows discounts on the gross price only (BT-147)
    "/ram:GrossPriceProductTradePrice/ram:AppliedTradeAllowanceCharge/ram:ChargeIndicator/udt:Indicator": "false",
    # the scheme of an invoiced object (BT-18-1, BT-128-1) needs type code 130
    "/ram:AdditionalReferencedDocument/ram:TypeCode": "130",
}


def _override(path, default):
    for suffix, value in OVERRIDES.items():
        if path.endswith(suffix):
            return value
    return default


def build_synthetic(fields):
    root = Node("rsm:CrossIndustryInvoice", ROOT)
    for f in fields:
        if "EXTENDED" not in f["profiles"]:
            continue
        for xp in f["xpath"].split("\n"):
            xp = xp.strip()
            if not xp.startswith(ROOT):
                continue
            node = root
            for p in [s for s in xp.split("/") if s][1:]:
                if p.startswith("@"):
                    node.attrs[p] = _override(node.path + "/" + p, _attr_value(p))
                    break
                if p not in node.index:
                    child = Node(p, node.path + "/" + p)
                    node.index[p] = child
                    node.children.append(child)
                node = node.index[p]

    def finish(node):
        for c in node.children:
            finish(c)
        if not node.children and node.text is None:
            node.text = _override(node.path, _value_for(node.name))

    finish(root)
    # the guideline drives profile detection
    context = root.index["rsm:ExchangedDocumentContext"]
    context.index["ram:GuidelineSpecifiedDocumentContextParameter"].index["ram:ID"].text = EXTENDED_GUIDELINE

    out = ['<?xml version="1.0" encoding="UTF-8"?>']

    def emit(node, top=False):
        attrs = "".join(" %s=%s" % (k[1:], quoteattr(v)) for k, v in node.attrs.items())
        if top:
            attrs = " " + CII_NS + attrs
        if node.children:
            out.append("<%s%s>" % (node.name, attrs))
            for c in node.children:
                emit(c)
            out.append("</%s>" % node.name)
        else:
            out.append("<%s%s>%s</%s>" % (node.name, attrs, escape(node.text or ""), node.name))

    emit(root, True)
    return "\n".join(out)


# --- 3. probe ----------------------------------------------------------------

def run_probe(probe, target):
    """Return diagnostics as [file, kind, path, message]."""
    res = subprocess.run([probe, target], stdout=subprocess.PIPE, check=True)
    rows = []
    for line in res.stdout.decode("utf-8", errors="replace").splitlines():
        p = line.split("\t")
        if len(p) >= 3:
            rows.append((p + [""])[:4])
    return rows


# --- 4. join -------------------------------------------------------------------

def lowest_profile(f):
    for p in PROFILES:
        if p in f["profiles"]:
            return p
    return "?"


def join(fields, synth, corpus):
    unmapped = [r[2] for r in synth if r[1] == "NotMapped"]
    corpus_files = defaultdict(set)
    for r in corpus:
        if r[1] == "NotMapped":
            corpus_files[r[2]].add(r[0])

    rows = []
    for f in fields:
        if f["type"] not in ("E", "A"):
            continue
        xp = f["xpath"].split("\n")[0].strip()
        hit = next((p for p in unmapped if xp == p or xp.startswith(p + "/")), None)
        files = set()
        for p, fs in corpus_files.items():
            if xp == p or xp.startswith(p + "/") or p.startswith(xp + "/"):
                files |= fs
        rows.append({"id": f["id"], "bt": f["bt"], "xpath": xp, "lowest": lowest_profile(f),
                     "profiles": f["profiles"], "card": f["card"], "mapped": hit is None,
                     "reportedAt": hit or "", "corpusFiles": len(files)})
    return rows, corpus_files


def report(rows, corpus_files, corpus_count):
    lines = ["Field coverage of TLandrixInvoice against the Factur-X table",
             "corpus files: %d" % corpus_count, "",
             "lowest profile: mapped / not mapped"]
    summary = defaultdict(lambda: [0, 0])
    for r in rows:
        summary[r["lowest"]][0 if r["mapped"] else 1] += 1
    for p in PROFILES:
        lines.append("  %-9s %4d %4d" % (p, summary[p][0], summary[p][1]))

    lines += ["", "NOT MAPPED below EXTENDED:"]
    for r in rows:
        if not r["mapped"] and r["lowest"] != "EXTENDED":
            lines.append("  %-12s %-9s %-40s %s  (corpus %d)" % (r["id"], r["lowest"], r["bt"][:40],
                                                                  r["xpath"][len(ROOT):], r["corpusFiles"]))

    groups = defaultdict(list)
    for r in rows:
        if not r["mapped"] and r["lowest"] == "EXTENDED":
            groups[r["reportedAt"]].append(r)
    lines += ["", "NOT MAPPED, EXTENDED only, by reported path (fields, corpus files):"]
    for p, rs in sorted(groups.items(), key=lambda kv: (-max(x["corpusFiles"] for x in kv[1]), kv[0])):
        lines.append("  %3d fields %3d files  %s  [%s]" % (
            len(rs), max(x["corpusFiles"] for x in rs), p[len(ROOT):],
            ", ".join(sorted(set(x["id"] for x in rs)))[:80]))

    known = set(r["xpath"] for r in rows)
    lines += ["", "reported in the corpus, not in the table:"]
    for p, fs in sorted(corpus_files.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        if not any(k == p or k.startswith(p + "/") for k in known):
            lines.append("  %3d %s" % (len(fs), p))
    return "\n".join(lines) + "\n"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--table", required=True, help="Factur-X field table (xlsx)")
    ap.add_argument("--probe", default=os.path.join(REPO, "build", "fpc322-win64", "FieldMapProbe.exe"))
    ap.add_argument("--corpus", default=os.path.join(REPO, "tests", "data", "local", "cii"))
    ap.add_argument("--out", default=os.path.join(REPO, "build", "fieldmap"))
    ap.add_argument("--any-table", action="store_true", help="accept a table with another checksum")
    args = ap.parse_args()

    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
        manifest = json.load(f)
    digest = sha256(args.table)
    if digest != manifest["table"]["sha256"]:
        msg = "table checksum %s differs from manifest.json" % digest
        if not args.any_table:
            sys.exit(msg + " (use --any-table for another version)")
        print("warning: " + msg)
    if not os.path.isfile(args.probe):
        sys.exit("probe not found: %s (build it, see --help)" % args.probe)
    os.makedirs(args.out, exist_ok=True)

    fields = extract_fields(args.table, manifest)
    with open(os.path.join(args.out, "fields.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(fields, f, indent=1, ensure_ascii=False)
    print("%d table paths; by profile set: %s" % (
        len(fields), Counter(", ".join(f["profiles"]) for f in fields).most_common(6)))

    synth_path = os.path.join(args.out, "synth-extended.xml")
    with open(synth_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(build_synthetic(fields))
    synth = run_probe(args.probe, synth_path)

    corpus = []
    corpus_count = 0
    if os.path.isdir(args.corpus):
        corpus_count = len([n for n in os.listdir(args.corpus) if n.lower().endswith(".xml")])
        corpus = run_probe(args.probe, args.corpus)
    else:
        print("corpus folder missing, frequencies are 0: %s" % args.corpus)

    for name, rows in (("synth-diag.tsv", synth), ("corpus-diag.tsv", corpus)):
        with open(os.path.join(args.out, name), "w", encoding="utf-8", newline="\n") as f:
            f.writelines("\t".join(r) + "\n" for r in rows)

    rows, corpus_files = join(fields, synth, corpus)
    with open(os.path.join(args.out, "coverage.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rows, f, indent=1, ensure_ascii=False)
    text = report(rows, corpus_files, corpus_count)
    with open(os.path.join(args.out, "coverage.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    sys.stdout.write(text)
    print("written to %s" % args.out)


if __name__ == "__main__":
    main()
