#!/usr/bin/env python3
"""Oracle for the Peppol rules: the unit test sets of OpenPEPPOL
(peppol-bis-invoice-3, rules/unit-UBL-*, the branch whose schematron is
Peppol BIS Billing 3.0.21) hold one fragment per test with the expected
outcome of the rules in its scope ('success': the rule holds, 'error' or
'warning': it fires). Every fragment is written to build/peppol-oracle/docs/
and read and checked with RuleCheckProbe against Peppol BIS 3.0 (-peppol).
For every expected rule the library implements, the verdict must agree:
'missed' means the test expects the rule to fire and the library does not,
'extra' the other way round. Fragments the probe cannot read are listed, not
compared; rules the library does not implement are counted (the rules the mapper
always meets, ALWAYS_MET, are neither compared nor counted).

Known differences are listed in tools/rulecheck/peppol-exceptions.txt
('file<TAB>missed RULE' or 'file<TAB>extra RULE', each with a reason; '*' in
the file name stands for any text); an unused line is an error.

Needs the test sets (see the default of --tests) and the probe:
  ./tools/build.ps1 fpc322-win64 -Program tools/rulecheck/RuleCheckProbe.dpr -NoRun

Usage:
  python tools/rulecheck/peppol-oracle.py [--tests <rules folder>]
      [--probe build/fpc322-win64/RuleCheckProbe.exe] [--unimplemented]
Exit code 0 = no unexpected difference.
"""

import argparse
import fnmatch
import glob
import os
import shutil
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TESTS = os.path.join(os.path.dirname(REPO), "landrix-einvoice-docs", "Peppol BIS Billing 3.0 - May 2026 Release",
                     "peppol-bis-invoice-3-806866bd2bd9", "rules")
EXCEPTIONS = os.path.join(HERE, "peppol-exceptions.txt")
OUT = os.path.join(REPO, "build", "peppol-oracle")
VEFA = "{http://difi.no/xsd/vefa/validator/1.0}"
# the rules the UBL mapper always meets (no row; see the headers of
# LandrixEInvoiceCheck and LandrixEInvoiceCheckPeppol); not compared
ALWAYS_MET = set(["PEPPOL-EN16931-R001", "PEPPOL-EN16931-R004", "PEPPOL-EN16931-R043", "PEPPOL-EN16931-R044",
                  "PEPPOL-EN16931-R051", "PEPPOL-EN16931-R080", "PEPPOL-EN16931-R100", "PEPPOL-EN16931-R101",
                  "PEPPOL-EN16931-F001", "PEPPOL-EN16931-P0101", "DE-R-014", "DE-R-023-2"])

sys.path.insert(0, HERE)
oracle = __import__("rule-oracle")


def extract(tests, docs):
    """{file: {'success': set, 'fire': set}} of every test fragment."""
    cases = {}
    for path in sorted(glob.glob(os.path.join(tests, "unit-UBL-*", "*.xml"))):
        stem = os.path.splitext(os.path.basename(path))[0]
        root = ET.parse(path).getroot()
        if root.tag != VEFA + "testSet":
            sys.exit("%s: no testSet" % path)
        for n, test in enumerate(root.findall(VEFA + "test"), 1):
            expect = test.find(VEFA + "assert")
            documents = [c for c in test if not c.tag.startswith(VEFA)]
            if expect is None or len(documents) != 1:
                sys.exit("%s: test %d has no assert or not one document" % (path, n))
            name = "%s-%02d.xml" % (stem, n)
            if name in cases:
                sys.exit("%s: test name %s occurs twice" % (path, name))
            cases[name] = {
                "success": set(e.text.strip() for e in expect.findall(VEFA + "success")),
                "fire": set(e.text.strip() for e in expect.findall(VEFA + "error")) |
                        set(e.text.strip() for e in expect.findall(VEFA + "warning")),
            }
            ET.ElementTree(documents[0]).write(os.path.join(docs, name), encoding="utf-8", xml_declaration=True)
    return cases


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tests", default=TESTS)
    ap.add_argument("--probe", default=os.path.join(REPO, "build", "fpc322-win64", "RuleCheckProbe.exe"))
    ap.add_argument("--unimplemented", action="store_true", help="list the expected rules the library lacks")
    args = ap.parse_args()
    if not os.path.isdir(args.tests):
        sys.exit("test sets not found: %s" % args.tests)
    if not os.path.isfile(args.probe):
        sys.exit("probe not found: %s (build it, see --help)" % args.probe)
    docs = os.path.join(OUT, "docs")
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(docs)
    cases = extract(args.tests, docs)
    if not cases:
        sys.exit("no test fragments in %s" % args.tests)
    ours, unread = oracle.probe_verdicts_args(args.probe, ["-peppol", docs])
    rules = oracle.implemented_rules()
    exceptions = oracle.load_exceptions(EXCEPTIONS)
    findings = []
    compared = 0
    lacking = {}
    for name in sorted(cases):
        if name not in ours:
            continue
        compared += 1
        expected = cases[name]
        for rid in sorted(expected["success"] | expected["fire"]):
            if rid in ALWAYS_MET:
                continue
            if rid not in rules:
                lacking[rid] = lacking.get(rid, 0) + 1
                continue
            fires = rid in ours[name]
            if fires == (rid in expected["fire"]):
                continue
            finding = ("extra " if fires else "missed ") + rid
            covered = False
            for e in exceptions:
                if fnmatch.fnmatchcase(name, e[0]) and e[1] == finding:
                    e[2] = True
                    covered = True
            if not covered:
                findings.append("%s\t%s" % (name, finding))
    if not compared:
        sys.exit("nothing compared: did the probe read the fragments? Files in %s" % docs)
    print("%d of %d test fragments compared; %d expected rules not implemented" % (compared, len(cases), len(lacking)))
    if args.unimplemented:
        for rid in sorted(lacking):
            print("  not implemented: %s (%d tests)" % (rid, lacking[rid]))
    for u in unread:
        print("  not read: " + u)
    for f in findings:
        print("  " + f)
    unused = [e for e in exceptions if not e[2]]
    for e in unused:
        print("  unused exception: %s\t%s" % (e[0], e[1]))
    if findings or unused:
        print("%d unexpected difference(s), %d unused exception(s)" % (len(findings), len(unused)))
        return 1
    print("no unexpected difference")
    return 0


if __name__ == "__main__":
    sys.exit(main())
