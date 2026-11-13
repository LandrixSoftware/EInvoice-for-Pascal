#!/usr/bin/env python3
"""Independent oracle for the semantic sweep: turns the
source files and the outputs of the sweep into the syntax-neutral XR form of
the KoSIT XRechnung visualization (cii-xr.xsl, ubl-invoice-xr.xsl,
ubl-creditnote-xr.xsl, run by the Saxon inside the KoSIT validator) and
compares both business term by business term. A difference means that the
read -> model -> write round trip changed the meaning of the document,
independent of how the library maps it.

Inputs: build/<toolchain>/sweep-source/, sweep/ and sweep-cross/ of a test
run (test Sweep.Official): each output is compared with its source, the
outputs in sweep-cross/ (XRechnung written in the other syntax, named
'<source without .xml>-x<suffix>') too; exceptions of these carry the label
'cross <file name>'.
Values are compared after normalisation: surrounding white space; amounts,
prices, quantities and percentages by value (100 = 100.00), everything else
exactly; repeated groups regardless of their order. The value 0 on one side
only counts as absent for the optional amounts, prices and percentages in
ZERO_EQUALS_ABSENT and quantity and price of sub lines, whose 0 the model
cannot tell from "absent". A note '#CODE#text' (XRechnung
UBL) counts as BT-21 CODE and BT-22 text; an added BT-13 'NA' is no
difference (UBL needs it next to BT-14); a CII BT-8 (UNTDID 2475) counts as
its UNTDID 2005 equivalent; a BG-24 that only repeats BT-18 (the UBL
stylesheet does so) is left out. In exception prefixes '*' stands for any
text. Known differences are listed in tests/data/xr-exceptions.txt
('file<TAB>finding prefix', each with a reason); an unused line is an error.

Needs addons/java-tools/install-tools.ps1 (validator, xrechnung-visualization,
Java runtime).

Usage:
  python tools/testdata/xr-compare.py [--toolchain fpc322-win64] [--java <java>]
Exit code 0 = no unexpected difference.
"""

import argparse
import collections
import decimal
import glob
import os
import re
import platform
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.join(REPO, "addons", "java-tools")
EXCEPTIONS = os.path.join(REPO, "tests", "data", "xr-exceptions.txt")
XR = "urn:ce.eu:en16931:2017:xoev-de:kosit:standard:xrechnung-1"


def find_java(explicit):
    if explicit:
        return explicit
    osname = {"Windows": "windows", "Darwin": "macos"}.get(platform.system(), "linux")
    arch = "aarch64" if platform.machine().lower() in ("arm64", "aarch64") else "x64"
    exe = "java.exe" if osname == "windows" else "java"
    for c in (os.path.join(TOOLS, "jre", "%s-%s" % (osname, arch), "bin", exe),
              os.path.join(TOOLS, "jre", "%s-%s" % (osname, arch), "Contents", "Home", "bin", exe)):
        if os.path.isfile(c):
            return c
    return shutil.which("java") or sys.exit("no Java runtime: run addons/java-tools/install-tools.ps1")


def root_name(path):
    for _, elem in ET.iterparse(path, events=("start",)):
        return elem.tag.split("}")[-1]


def stylesheet(root):
    name = {"CrossIndustryInvoice": "cii-xr.xsl", "Invoice": "ubl-invoice-xr.xsl",
            "CreditNote": "ubl-creditnote-xr.xsl"}[root]
    return os.path.join(TOOLS, "xrechnung-visualization", "xsl", name)


def transform(java, files, work):
    """XR form of every file: {file name: path of its XR document}."""
    jar = glob.glob(os.path.join(TOOLS, "validator", "validator-*-standalone.jar"))
    if not jar:
        sys.exit("KoSIT validator missing: run addons/java-tools/install-tools.ps1")
    groups = {}
    for f in files:
        groups.setdefault(stylesheet(root_name(f)), []).append(f)
    out = {}
    for i, (xsl, members) in enumerate(sorted(groups.items())):
        src = os.path.join(work, "in%d" % i)
        dst = os.path.join(work, "out%d" % i)
        os.makedirs(src)
        os.makedirs(dst)
        for f in members:
            shutil.copyfile(f, os.path.join(src, os.path.basename(f)))
        res = subprocess.run([java, "-cp", jar[0], "net.sf.saxon.Transform", "-s:" + src, "-xsl:" + xsl,
                              "-o:" + dst], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if res.returncode != 0:
            sys.exit("XR transformation failed:\n" + res.stdout.decode("utf-8", "replace")[-3000:])
        for f in members:
            out[os.path.basename(f)] = os.path.join(dst, os.path.basename(f))
    return out


# EN 16931 terms of type amount, unit price, quantity or percentage: only
# these are compared by value (identifiers like postcodes keep leading zeros)
NUMERIC = set("BT-%d" % n for n in (92, 93, 94, 96, 99, 100, 101, 103, 106, 107, 108, 109, 110, 111, 112,
                                     113, 114, 115, 116, 117, 119, 129, 131, 136, 137, 138, 141, 142, 143,
                                     146, 147, 148, 149, 152)) | {"BT-DEX-002"}
# optional amounts, prices and percentages whose 0 the model cannot tell from
# "absent" (Currency/Double fields): totals BT-107, BT-108, BT-110, BT-113,
# BT-114; base amounts and percentages of allowances and charges (BT-93/94,
# BT-100/101, BT-137/138, BT-142/143); gross price BT-148 and its discount
# BT-147; the breakdown rate BT-119 (category O without rate); BT-129 and
# BT-146 of sub lines (BG-DEX-01). The line rate BT-152 is not among them.
ZERO_EQUALS_ABSENT = ("BT-93", "BT-94", "BT-100", "BT-101", "BT-107", "BT-108", "BT-110", "BT-113", "BT-114",
                      "BT-119", "BT-137", "BT-138", "BT-142", "BT-143", "BT-147", "BT-148")
SUB_LINE_ZERO = ("BT-129", "BT-146")


def norm(tid, text):
    t = " ".join((text or "").split())
    if tid in NUMERIC:
        try:
            return format(decimal.Decimal(t).normalize(), "f")
        except decimal.InvalidOperation:
            pass
    return t


def zero_equals_absent(term):
    """True for 'path = 0' of a term whose 0 the model cannot keep apart from
    a missing value."""
    path, _, value = term.partition(" = ")
    if value != "0":
        return False
    tid = path.rsplit("/", 1)[-1]
    return tid in ZERO_EQUALS_ABSENT or (tid in SUB_LINE_ZERO and "BG-DEX-01" in path)


def terms(path, cii):
    """Flattened XR document: ['BG-25[2]/BT-129 = 10', ...]. Repeated groups
    are numbered after sorting them by their content, so their order does not
    count (sub lines may come before or after their parent line)."""

    def canon(elem):
        tid = elem.get("{%s}id" % XR) or elem.tag.split("}")[-1]
        if not len(elem):
            value = norm(tid, elem.text)
            # XR joins several payment terms with ';' in document order; their
            # order means nothing
            if tid in ("BT-9", "BT-20"):
                value = ";".join(sorted(value.split(";")))
            # XR keeps the code list of the syntax: CII writes UNTDID 2475,
            # UBL UNTDID 2005 for the VAT point date code
            if tid == "BT-8" and cii:
                value = {"5": "3", "29": "35", "72": "432"}.get(value, "cii:" + value)
            return (tid, value, ())
        children = [canon(c) for c in elem]
        # XRechnung UBL carries the note subject code in the text ('#ADU#...'),
        # CII in its own element: compare both as BT-21 and BT-22
        if tid == "BG-1" and not any(c[0] == "BT-21" for c in children):
            for k, (ctid, value, sub) in enumerate(children):
                m = re.match(r"^#(\w+)#(.*)$", value, re.S)
                if ctid == "BT-22" and m:
                    children[k] = ("BT-22", m.group(2), ())
                    children.append(("BT-21", m.group(1), ()))
        return (tid, "", tuple(sorted(children)))

    out = []

    def walk(node, prefix):
        counts = {}
        for tid, value, children in node:
            if children:
                counts[tid] = counts.get(tid, 0) + 1
                walk(children, "%s%s[%d]/" % (prefix, tid, counts[tid]))
            else:
                out.append("%s%s = %s" % (prefix, tid, value))

    top = canon(ET.parse(path).getroot())[2]
    # the UBL stylesheet lists the invoiced object identifier (BT-18) also as
    # a supporting document (BG-24 with BT-122 only), the CII stylesheet not
    objects = set(v for t, v, c in top if t == "BT-18")
    top = tuple(x for x in top if not (x[0] == "BG-24" and len(x[2]) == 1 and x[2][0][0] == "BT-122"
                                       and x[2][0][1] in objects))
    walk(top, "")
    return out


def matches(finding, prefix):
    """Prefix match; '*' in the prefix stands for any text."""
    pattern = "".join(".*" if c == "*" else re.escape(c) for c in prefix)
    return re.match(pattern, finding, re.S) is not None


def load_exceptions():
    items = []
    if not os.path.isfile(EXCEPTIONS):
        return items
    for n, line in enumerate(open(EXCEPTIONS, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "\t" not in line or not line.split("\t", 1)[1].strip():
            sys.exit("xr-exceptions.txt line %d: 'file<TAB>prefix' expected" % n)
        name, prefix = line.split("\t", 1)
        items.append([name, prefix, False])
    return items


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--toolchain", default="fpc322-win64")
    ap.add_argument("--java")
    args = ap.parse_args()
    # findings may hold any character; the Windows console code page must not abort the run
    sys.stdout.reconfigure(errors="backslashreplace")
    build = os.path.join(REPO, "build", args.toolchain)
    srcdir, outdir = os.path.join(build, "sweep-source"), os.path.join(build, "sweep")
    crossdir = os.path.join(build, "sweep-cross")
    # (label, source, output): same specification, then the other syntax
    # (sweep-cross/<source without .xml>-x<suffix>)
    pairs = []
    if os.path.isdir(srcdir) and os.path.isdir(outdir):
        for n in sorted(set(os.listdir(srcdir)) & set(os.listdir(outdir))):
            pairs.append((n, os.path.join(srcdir, n), os.path.join(outdir, n)))
    if os.path.isdir(crossdir):
        for n in sorted(os.listdir(crossdir)):
            src = os.path.join(srcdir, n.rsplit("-x-", 1)[0] + ".xml")
            if not os.path.isfile(src):
                sys.exit("cross output without source: %s" % n)
            pairs.append(("cross " + n, src, os.path.join(crossdir, n)))
    if not pairs:
        sys.exit("no sweep output in %s (run the tests first)" % build)
    work = os.path.join(build, "xr")
    if os.path.isdir(work):
        shutil.rmtree(work)
    java = find_java(args.java)
    xr = {}
    # one run per folder: the names are unique within a folder
    for tag, folder in (("source", srcdir), ("output", outdir), ("cross", crossdir)):
        group = sorted(set(f for _, a, b in pairs for f in (a, b) if os.path.dirname(f) == folder))
        if group:
            out = transform(java, group, os.path.join(work, tag))
            for f in group:
                xr[f] = out[os.path.basename(f)]
    exceptions = load_exceptions()
    failed = 0
    for label, src, dst in pairs:
        n = label
        a = collections.Counter(terms(xr[src], root_name(src) == "CrossIndustryInvoice"))
        b = collections.Counter(terms(xr[dst], root_name(dst) == "CrossIndustryInvoice"))
        # a value 0 on one side only is no difference: amounts and quantities of
        # the model do not tell "absent" from 0
        lost = ["lost " + x for x in sorted((a - b).elements()) if not zero_equals_absent(x)]
        # UBL needs an order reference identifier next to BT-14: 'NA' (Peppol)
        added = ["added " + x for x in sorted((b - a).elements())
                 if not zero_equals_absent(x) and x != "BT-13 = NA"]
        findings = []
        for f in lost + added:
            hits = [e for e in exceptions if e[0] == n and matches(f, e[1])]
            for e in hits:
                e[2] = True
            if not hits:
                findings.append(f)
        if findings:
            failed += 1
            print("  " + n)
            for f in findings:
                print("    " + f)
    for e in exceptions:
        if not e[2]:
            failed += 1
            print("  unused exception: %s %s" % (e[0], e[1]))
    print("xr-compare: %d pairs, %d with unexpected differences" % (len(pairs), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
