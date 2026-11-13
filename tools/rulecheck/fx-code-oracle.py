#!/usr/bin/env python3
"""Oracle for the Factur-X code asserts (LandrixEInvoiceCIICodeRules): the
local CII example files (tests/data/local/cii and cii-invalid, git-ignored:
the CII examples of the XRechnung-for-Delphi and ZUGFeRD-for-Delphi test data,
which the maintainers keep locally; without them the oracle has no documents) are validated with the KoSIT validator and the ZUGFeRD 2.5.2
configuration and read and checked with CIICodeProbe. For every document
whose scenario is a Factur-X 1.09.2 profile, the FX-SCH-A code asserts of
that profile (tools/syntaxmodel/cii-codes.json) must agree: 'missed' means
KoSIT reports the assert and the library does not, 'extra' the other way
round. Documents of another scenario, documents KoSIT rejects on schema
level (no schematron result) and documents the probe cannot read are
listed, not compared.

The examples are valid, so they hardly fail a code assert. Each compared
document is therefore also mutated twice: every value a code assert of
any profile checks (except BT-24, which selects the scenario) is replaced
by 'X9X' (mutation x; not @currencyID: two VAT totals in the invoice
currency X9X make the KoSIT schematron report nothing at all) or written
in lower case (mutation l); the mutants are compared the same way (in
build/fx-code-oracle/mutants/).

Known differences are listed in tools/rulecheck/fx-code-exceptions.txt
('file<TAB>missed ID' or 'file<TAB>extra ID', each with a reason; '*' in
the file name stands for any text); an unused line is an error.

Needs addons/java-tools/install-tools.ps1 (validator, ZUGFeRD configuration,
Java runtime) and the probe:
  ./tools/build.ps1 fpc322-win64 -Program tools/rulecheck/CIICodeProbe.dpr -NoRun

Usage:
  python tools/rulecheck/fx-code-oracle.py [--probe build/fpc322-win64/CIICodeProbe.exe]
      [--java <java>] [--keep] [folder ...]
The KoSIT reports are kept in build/fx-code-oracle/ (--keep reuses them).
Exit code 0 = no unexpected difference.
"""

import argparse
import fnmatch
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.join(REPO, "addons", "java-tools")
CONFIG = os.path.join(TOOLS, "validator-configuration-zugferd")
CODES = os.path.join(REPO, "tools", "syntaxmodel", "cii-codes.json")
EXCEPTIONS = os.path.join(HERE, "fx-code-exceptions.txt")
FOLDERS = [os.path.join(REPO, "tests", "data", "local", "cii"), os.path.join(REPO, "tests", "data", "local", "cii-invalid")]
OUT = os.path.join(REPO, "build", "fx-code-oracle")

sys.path.insert(0, HERE)
oracle = __import__("rule-oracle")

# scenario name of the ZUGFeRD configuration -> profile of cii-codes.json
SCENARIOS = {
    "ZUGFeRD 2.5.2/Factur-X 1.09.2 - MINIMUM": "MINIMUM",
    "ZUGFeRD 2.5.2/Factur-X 1.09.2 - BasicWL": "BASIC WL",
    "ZUGFeRD 2.5.2/Factur-X 1.09.2 - Basic": "BASIC",
    "ZUGFeRD 2.5.2/Factur-X 1.09.2 - Comfort (EN16931)": "EN16931",
    "ZUGFeRD 2.5.2/Factur-X 1.09.2 - EN16931 (CII) Extended": "EXTENDED",
}
PREFIXES = {
    "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100": "rsm",
    "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100": "ram",
    "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100": "udt",
    "urn:un:unece:uncefact:data:standard:QualifiedDataType:100": "qdt",
}


def validate(java, files, out):
    jar = glob.glob(os.path.join(TOOLS, "validator", "validator-*-standalone.jar"))
    if not jar or not os.path.isfile(os.path.join(CONFIG, "scenarios.xml")):
        sys.exit("KoSIT validator or ZUGFeRD configuration missing: run addons/java-tools/install-tools.ps1")
    os.makedirs(out, exist_ok=True)
    empty = os.path.join(out, "empty-input.txt")
    open(empty, "w").close()
    for i in range(0, len(files), 200):
        with open(empty) as stdin:
            subprocess.run([java, "-jar", jar[0], "-r", CONFIG, "-s", os.path.join(CONFIG, "scenarios.xml"),
                            "-o", out] + files[i:i + 200], stdin=stdin, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)


def kosit_verdicts(files, out, ids):
    """{file: (profile, set of code assert ids)} for documents of a Factur-X
    scenario with a schematron result, and the list of the others."""
    result = {}
    skipped = []
    for f in files:
        name = os.path.basename(f)
        report = os.path.join(out, name[:-4] + "-report.xml")
        if not os.path.isfile(report):
            skipped.append(name + " (no report)")
            continue
        text = open(report, encoding="utf-8").read()
        scenario = re.search(r"<rep:scenarioMatched>[\s\S]*?<s:name>([^<]*)</s:name>", text)
        profile = SCENARIOS.get(scenario.group(1).strip()) if scenario else None
        if profile is None:
            skipped.append(name + " (scenario %s)" % (scenario.group(1).strip() if scenario else "none"))
            continue
        if 'id="val-sch.' not in text:
            skipped.append(name + " (no schematron result)")
            continue
        codes = set(c for c in re.findall(r'<rep:message [^>]*code="([^"]+)"', text) if c in ids)
        result[name] = (profile, codes)
    return result, skipped


def load_exceptions():
    items = []
    if os.path.isfile(EXCEPTIONS):
        for line in open(EXCEPTIONS, encoding="utf-8"):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            if "\t" not in line:
                sys.exit("%s: no tab in line: %s" % (EXCEPTIONS, line))
            name, finding = line.split("\t", 1)
            items.append([name, finding, False])
    return items


def qname(tag):
    uri, _, local = tag[1:].partition("}")
    return PREFIXES.get(uri, "?") + ":" + local


def mutate(source, target, keys, kind):
    """Writes source with every checked value changed; False if none."""
    ET.register_namespace("rsm", "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100")
    for uri, prefix in PREFIXES.items():
        ET.register_namespace(prefix, uri)
    tree = ET.parse(source)
    changed = [0]

    def change(value):
        if kind == "x":
            return "X9X"
        return value.lower()

    def walk(el, path):
        p = path + "/" + qname(el.tag)
        if p in keys and el.text and el.text.strip() and len(el) == 0:
            new = change(el.text)
            if new != el.text:
                el.text = new
                changed[0] += 1
        for name in list(el.attrib):
            if "}" in name:
                continue
            # mutation x keeps @currencyID: two VAT totals in the invoice
            # currency X9X make the KoSIT schematron report nothing at all
            if kind == "x" and name == "currencyID":
                continue
            if p + "/@" + name in keys and el.attrib[name]:
                new = change(el.attrib[name])
                if new != el.attrib[name]:
                    el.attrib[name] = new
                    changed[0] += 1
        for child in el:
            walk(child, p)

    walk(tree.getroot(), "")
    if not changed[0]:
        return False
    tree.write(target, encoding="utf-8", xml_declaration=True)
    return True


def compare(kosit, ours, profile_of, exceptions):
    findings = []
    hits = set()
    compared = 0
    for name in sorted(kosit):
        if name not in ours:
            continue
        compared += 1
        profile, k_ids = kosit[name]
        o_ids = set(i for i in ours[name] if profile_of.get(i) == profile)
        hits |= k_ids
        for rid in sorted(k_ids ^ o_ids):
            finding = ("missed " if rid in k_ids else "extra ") + rid
            covered = False
            for e in exceptions:
                if fnmatch.fnmatchcase(name, e[0]) and e[1] == finding:
                    e[2] = True
                    covered = True
            if not covered:
                findings.append("%s\t%s" % (name, finding))
    return compared, hits, findings


def probe_all(probe, folders):
    ours, unread = {}, []
    for d in folders:
        o, u = oracle.probe_verdicts(probe, d)
        ours.update(o)
        unread += u
    return ours, unread


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--probe", default=os.path.join(REPO, "build", "fpc322-win64", "CIICodeProbe.exe"))
    ap.add_argument("--java")
    ap.add_argument("--keep", action="store_true", help="reuse the KoSIT reports of an earlier run")
    ap.add_argument("folders", nargs="*", default=FOLDERS)
    args = ap.parse_args()
    files = sorted(f for d in args.folders for f in glob.glob(os.path.join(d, "*.xml")))
    if not files:
        sys.exit("no test documents in %s" % ", ".join(args.folders))
    if not os.path.isfile(args.probe):
        sys.exit("probe not found: %s (build it, see --help)" % args.probe)
    rules = json.load(open(CODES, encoding="utf-8"))["rules"]
    profile_of = dict((r[1], r[0]) for r in rules)
    # BT-24 selects the KoSIT scenario; it stays unchanged
    keys = set(r[2] for r in rules if not r[2].endswith("/ram:GuidelineSpecifiedDocumentContextParameter/ram:ID"))
    mutants_dir = os.path.join(OUT, "mutants")
    reports_dir = os.path.join(OUT, "reports")
    mutant_reports = os.path.join(OUT, "mutant-reports")
    fresh = not args.keep or not os.path.isdir(reports_dir)
    if fresh:
        if os.path.isdir(OUT):
            shutil.rmtree(OUT)
        validate(oracle.find_java(args.java), files, reports_dir)
    kosit, skipped = kosit_verdicts(files, reports_dir, set(profile_of))
    ours, unread = probe_all(args.probe, args.folders)
    by_name = dict((os.path.basename(f), f) for f in files)
    if fresh:
        os.makedirs(mutants_dir)
        mutant_files = []
        for name in sorted(kosit):
            if name not in ours:
                continue
            for kind in ("x", "l"):
                target = os.path.join(mutants_dir, name[:-4] + "-" + kind + ".xml")
                if mutate(by_name[name], target, keys, kind):
                    mutant_files.append(target)
        validate(oracle.find_java(args.java), mutant_files, mutant_reports)
    mutant_files = sorted(glob.glob(os.path.join(mutants_dir, "*.xml")))
    m_kosit, m_skipped = kosit_verdicts(mutant_files, mutant_reports, set(profile_of))
    m_ours, m_unread = probe_all(args.probe, [mutants_dir])
    exceptions = load_exceptions()
    compared, hits, findings = compare(kosit, ours, profile_of, exceptions)
    m_compared, m_hits, m_findings = compare(m_kosit, m_ours, profile_of, exceptions)
    # without reports (e.g. the validator did not start) nothing would be compared
    if not compared or not m_compared:
        sys.exit("nothing compared (%d documents, %d mutants): did the KoSIT validator run? Reports in %s" %
                 (compared, m_compared, OUT))
    print("%d documents and %d mutants compared, %d code asserts; KoSIT reports %d of them at least once" %
          (compared, m_compared, len(profile_of), len(hits | m_hits)))
    for s in skipped + ["mutant " + s for s in m_skipped]:
        print("  skipped: " + s)
    for u in unread + ["mutant " + u for u in m_unread]:
        print("  not read: " + u)
    for f in findings + m_findings:
        print("  " + f)
    unused = [e for e in exceptions if not e[2]]
    for e in unused:
        print("  unused exception: %s\t%s" % (e[0], e[1]))
    if findings or m_findings or unused:
        print("%d unexpected difference(s), %d unused exception(s)" % (len(findings) + len(m_findings), len(unused)))
        return 1
    print("no unexpected difference")
    return 0


if __name__ == "__main__":
    sys.exit(main())
