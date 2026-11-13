#!/usr/bin/env python3
"""Negative oracle for the business rule checks: the
KoSIT schematron test documents of XRechnung 3.0.0 (folder 'generated' of
the schematron 2.0.0 package, 1,219 documents, each made to pass or fail one
rule) are validated with the KoSIT validator and read and checked with
RuleCheckProbe (LandrixEInvoiceCheckInvoice). For every rule the library
implements, both verdicts must agree: 'missed' means KoSIT reports the rule
and the library does not, 'extra' the other way round. Documents KoSIT
rejects on schema level (no schematron result) and documents the library
cannot read are listed, not compared.

Known differences are listed in tools/rulecheck/oracle-exceptions.txt
('file<TAB>missed RULE' or 'file<TAB>extra RULE', each with a reason; '*'
in the file name stands for any text); an unused line is an error.

Needs addons/java-tools/install-tools.ps1 (validator, XRechnung
configuration, Java runtime) and the probe:
  ./tools/build.ps1 fpc322-win64 -Program tools/rulecheck/RuleCheckProbe.dpr -NoRun

Usage:
  python tools/rulecheck/rule-oracle.py [--docs <generated folder>]
      [--probe build/fpc322-win64/RuleCheckProbe.exe] [--java <java>] [--keep]
The KoSIT reports are kept in build/rule-oracle/ (--keep reuses them).
Exit code 0 = no unexpected difference.
"""

import argparse
import fnmatch
import glob
import os
import platform
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.join(REPO, "addons", "java-tools")
CHECK_UNIT = os.path.join(REPO, "source", "LandrixEInvoiceCheck.pas")
PEPPOL_UNIT = os.path.join(REPO, "source", "LandrixEInvoiceCheckPeppol.pas")
EXCEPTIONS = os.path.join(HERE, "oracle-exceptions.txt")
DOCS = os.path.join(os.path.dirname(REPO), "landrix-einvoice-docs", "XRechnung 3.0.0",
                    "xrechnung-3.0.0-schematron-2.0.0", "generated")
OUT = os.path.join(REPO, "build", "rule-oracle")


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


def implemented_rules():
    """Identifiers of the non-legacy rows of the check tables
    (LandrixEInvoiceCheck and LandrixEInvoiceCheckPeppol)."""
    text = open(CHECK_UNIT, encoding="utf-8").read()
    rows = re.findall(r"\(ID: '([^']+)';[^()]*?Legacy: (True|False);", text)
    rules = set(i for i, legacy in rows if legacy == "False")
    # every value of TCheckRuleIndex must have a row here
    enum = re.search(r"TCheckRuleIndex = \(([^)]*)\)", text)
    count = len(enum.group(1).split(",")) if enum else -1
    if len(rows) != count:
        sys.exit("%d check rows found, TCheckRuleIndex has %d: adjust implemented_rules" % (len(rows), count))
    # the VAT category rules BR-<group>-01 to BR-<group>-<last> and BR-FXEXT-<group>-01 have no rows
    groups = re.search(r"VatGroupIDs: array\[TVatGroup\] of string = \(([^)]*)\)", text)
    last = re.search(r"VatGroupLast: array\[TVatGroup\] of Integer = \(([^)]*)\)", text)
    if not groups or not last:
        sys.exit("VatGroupIDs or VatGroupLast not found: adjust implemented_rules")
    ids = [g.strip().strip("'") for g in groups.group(1).split(",")]
    lasts = [int(n) for n in last.group(1).split(",")]
    for group, count in zip(ids, lasts):
        rules.update("BR-%s-%02d" % (group, n) for n in range(1, count + 1))
        rules.add("BR-FXEXT-%s-01" % group)
    # the rules only the Peppol schematron has (own enum and rows)
    peppol = open(PEPPOL_UNIT, encoding="utf-8").read()
    rows = re.findall(r"\(ID: '([^']+)'; Severity: ", peppol)
    enum = re.search(r"TPeppolRuleIndex = \(([^)]*)\)", peppol)
    count = len(enum.group(1).split(",")) if enum else -1
    if len(rows) != count:
        sys.exit("%d Peppol rows found, TPeppolRuleIndex has %d: adjust implemented_rules" % (len(rows), count))
    rules.update(rows)
    return rules


def validate(java, docs, out):
    jar = glob.glob(os.path.join(TOOLS, "validator", "validator-*-standalone.jar"))
    cfg = os.path.join(TOOLS, "validator-configuration-xrechnung")
    if not jar or not os.path.isfile(os.path.join(cfg, "scenarios.xml")):
        sys.exit("KoSIT validator or XRechnung configuration missing: run addons/java-tools/install-tools.ps1")
    files = sorted(glob.glob(os.path.join(docs, "*.xml")))
    os.makedirs(out, exist_ok=True)
    empty = os.path.join(out, "empty-input.txt")
    open(empty, "w").close()
    # in chunks: the Windows command line has a length limit
    for i in range(0, len(files), 200):
        with open(empty) as stdin:
            subprocess.run([java, "-jar", jar[0], "-r", cfg, "-s", os.path.join(cfg, "scenarios.xml"), "-o", out]
                           + files[i:i + 200], stdin=stdin, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def custom_levels():
    """{scenario name: {rule code: level}} of the XRechnung configuration:
    the report keeps the level of the schematron, the configuration's
    customLevel changes it for the assessment."""
    path = os.path.join(TOOLS, "validator-configuration-xrechnung", "scenarios.xml")
    text = open(path, encoding="utf-8").read()
    levels = {}
    for scenario in re.findall(r"<scenario>([\s\S]*?)</scenario>", text):
        name = re.search(r"<name>([^<]*)</name>", scenario).group(1).strip()
        levels[name] = dict((c.strip(), l) for l, c in
                            re.findall(r'<customLevel level="(\w+)">([^<]*)</customLevel>', scenario))
    return levels


def kosit_verdicts(docs, out):
    """{file: set of rule codes at level error or warning} for documents with
    a schematron result, and the list of documents without one."""
    result = {}
    skipped = []
    levels = custom_levels()
    for f in sorted(glob.glob(os.path.join(docs, "*.xml"))):
        name = os.path.basename(f)
        report = os.path.join(out, name[:-4] + "-report.xml")
        if not os.path.isfile(report):
            skipped.append(name + " (no report)")
            continue
        text = open(report, encoding="utf-8").read()
        scenario = re.search(r"<rep:scenarioMatched>[\s\S]*?<s:name>([^<]*)</s:name>", text)
        custom = levels.get(scenario.group(1).strip(), {}) if scenario else {}
        # level "information" (also by customLevel, e.g. BR-CO-16 in the
        # extension scenario) does not reject a document
        codes = set(code for level, code in re.findall(r'<rep:message [^>]*level="(\w+)"[^>]*code="([^"]+)"', text)
                    if custom.get(code, level) in ("error", "warning"))
        if 'id="val-sch.' not in text:
            skipped.append(name + " (no schematron result)")
            continue
        result[name] = codes
    return result, skipped


def probe_verdicts(probe, docs):
    return probe_verdicts_args(probe, [docs])


def probe_verdicts_args(probe, args):
    res = subprocess.run([probe] + args, stdout=subprocess.PIPE, check=True)
    result = {}
    unread = []
    for line in res.stdout.decode("utf-8", "replace").splitlines():
        parts = line.rstrip("\r").split("\t")
        if len(parts) < 2:
            continue
        if parts[1] != "ok":
            unread.append("%s (%s %s)" % (parts[0], parts[1], parts[2] if len(parts) > 2 else ""))
            continue
        result[parts[0]] = set(parts[2].split()) if len(parts) > 2 else set()
    return result, unread


def load_exceptions(path=EXCEPTIONS):
    items = []
    if os.path.isfile(path):
        for line in open(path, encoding="utf-8"):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            if "\t" not in line:
                sys.exit("%s: no tab in line: %s" % (path, line))
            name, finding = line.split("\t", 1)
            items.append([name, finding, False])
    return items


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--docs", default=DOCS)
    ap.add_argument("--probe", default=os.path.join(REPO, "build", "fpc322-win64", "RuleCheckProbe.exe"))
    ap.add_argument("--java")
    ap.add_argument("--keep", action="store_true", help="reuse the KoSIT reports of an earlier run")
    args = ap.parse_args()
    if not os.path.isdir(args.docs):
        sys.exit("test documents not found: " + args.docs)
    if not os.path.isfile(args.probe):
        sys.exit("probe not found: %s (build it, see --help)" % args.probe)
    rules = implemented_rules()
    if not args.keep or not os.path.isdir(OUT):
        if os.path.isdir(OUT):
            shutil.rmtree(OUT)
        validate(find_java(args.java), args.docs, OUT)
    kosit, skipped = kosit_verdicts(args.docs, OUT)
    ours, unread = probe_verdicts(args.probe, args.docs)
    exceptions = load_exceptions()
    findings = []
    compared = 0
    for name in sorted(kosit):
        if name not in ours:
            continue
        compared += 1
        for rule in sorted(rules):
            k = rule in kosit[name]
            o = rule in ours[name]
            if k == o:
                continue
            finding = ("missed " if k else "extra ") + rule
            covered = False
            for e in exceptions:
                if fnmatch.fnmatchcase(name, e[0]) and e[1] == finding:
                    e[2] = True
                    covered = True
            if not covered:
                findings.append("%s\t%s" % (name, finding))
    hits = {}
    for name in kosit:
        for rule in kosit[name] & rules:
            hits[rule] = hits.get(rule, 0) + 1
    print("%d documents compared, %d rules; KoSIT reports %d of them at least once" %
          (compared, len(rules), len(hits)))
    print("not covered by the test documents: " + " ".join(sorted(rules - set(hits))))
    for s in skipped:
        print("  skipped: " + s)
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
