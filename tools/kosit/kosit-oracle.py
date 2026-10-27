#!/usr/bin/env python3
"""End-to-end oracle for LandrixEInvoiceValidator (plan, phase 6, KoSIT
end-to-end run): the KoSIT XRechnung test suite 2026-08-31 and mutants of
it are validated with the KoSIT validator (the configuration of
addons/java-tools) and with tools/kosit/ValidatorProbe.dpr, and the results
are compared per document:

  scenario          the name of the matched scenario (or none)
  xsd               the XML schema step: code and line:column per message
  sch<n>            each Schematron step: code, level and location per message
  verdict           accept or reject

The mutants (build/kosit-oracle/mutants/) cover what the positive test suite
does not: no matching scenario, a document that is not well-formed, an XML
schema error in UBL and CII, a fatal Schematron message, a customLevel that
promotes a warning to error (UBL-CR-646 in the standard scenario), and a CII
document that two scenarios match (KoSIT then chooses none).
Well-formedness messages are compared by count only (the parsers word and
place them differently). Schematron messages are compared with the level of
the rule set; customLevel shows in the verdict only (the report does not
carry the effective level). Lines are compared as multisets.

--corpus generated runs the 1,219 generated Schematron test documents of
XRechnung 3.0.0 instead (landrix-einvoice-docs, folder "generated" of the
schematron 2.0.0 package, the corpus of tools/rulecheck/rule-oracle.py,
each made to pass or fail one rule); most of them are rejected, so they test
the rejecting side. They are copied to build/kosit-oracle/generated/ (some
names are too long for MAX_PATH below the docs folder; the reports go to
build/kosit-oracle/rep-gen/, the longest path has about 250 characters).
--corpus outputs runs the XRechnung files this library wrote in a test run
(*-ubl-30x.xml, *-cii-30x.xml of build/<toolchain>/cross, cases and sweep;
--toolchain, default fpc322-linux), copied to build/kosit-oracle/outputs/
with the folder as prefix. --corpus all runs the test suite, the generated
documents and the outputs; --update then needs all of them to be clean.

Known differences are listed in tools/kosit/kosit-exceptions.txt
("file<TAB>difference line", '*' in the file name for any text, each with a
reason); an unused line is an error.

Needs tools/testdata/sync-local.py (copies the test suite and the rule files
to tests/data/local/kosit/), addons/java-tools/install-tools.ps1 and the
probe:
  ./tools/build.ps1 fpc322-win64 -Program tools/kosit/ValidatorProbe.dpr -NoRun

Usage:
  python tools/kosit/kosit-oracle.py [--corpus suite|generated|outputs|all] [--toolchain <tc>]
      [--probe <exe>] [--java <java>] [--keep] [--update]
The KoSIT reports are kept in build/kosit-oracle/ (--keep reuses them).
--update rewrites tests/data/kosit-expected.txt, the reference of the test
Validator.KositSuite (the probe's lines for the test suite instances), when
there is no unexpected difference.
Exit code 0 = no unexpected difference.
"""

import argparse
import collections
import fnmatch
import glob
import os
import platform
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.join(REPO, "addons", "java-tools")
CONFIG = os.path.join(TOOLS, "validator-configuration-xrechnung")
LOCAL = os.path.join(REPO, "tests", "data", "local", "kosit")
INSTANCES = os.path.join(LOCAL, "instances")
RULES = os.path.join(LOCAL, "rules", "rules")
EXCEPTIONS = os.path.join(HERE, "kosit-exceptions.txt")
EXPECTED = os.path.join(REPO, "tests", "data", "kosit-expected.txt")
GENERATED = os.path.join(os.path.dirname(REPO), "landrix-einvoice-docs", "XRechnung 3.0.0",
                         "xrechnung-3.0.0-schematron-2.0.0", "generated")
OUT = os.path.join(REPO, "build", "kosit-oracle")
REP = "{http://www.xoev.de/de/validator/varl/1}"
SCN = "{http://www.xoev.de/de/validator/framework/1/scenarios}"

UBL_STANDARD = "urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0"
UBL_EXTENSION = UBL_STANDARD + "#conformant#urn:xeinkauf.de:kosit:extension:xrechnung_3.0"

# name, source instance, list of (old, new) byte replacements, each must occur
MUTANTS = [
    ("m-noscenario-ubl.xml", "standard_01.01a-INVOICE_ubl.xml",
     [(b"<cbc:CustomizationID>" + UBL_STANDARD.encode() + b"</cbc:CustomizationID>",
       b"<cbc:CustomizationID>urn:example:no-scenario</cbc:CustomizationID>")]),
    ("m-notwellformed-ubl.xml", "standard_01.01a-INVOICE_ubl.xml",
     [(b"</ubl:Invoice>", b"</ubl:Invoic>")]),
    ("m-xsd-ubl.xml", "standard_01.01a-INVOICE_ubl.xml",
     [(b"<cbc:IssueDate>", b"<cbc:Unknown>x</cbc:Unknown><cbc:IssueDate>")]),
    ("m-xsd-cii.xml", "standard_01.01a-INVOICE_uncefact.xml",
     [(b"<rsm:ExchangedDocument>", b"<rsm:ExchangedDocument><ram:Unknown>x</ram:Unknown>")]),
    ("m-sch-ubl.xml", "standard_01.01a-INVOICE_ubl.xml",
     [(b"<cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>", b"<cbc:InvoiceTypeCode>999</cbc:InvoiceTypeCode>")]),
    ("m-ambiguous-cii.xml", "standard_01.01a-INVOICE_uncefact.xml",
     [(b"</ram:GuidelineSpecifiedDocumentContextParameter>",
       b"</ram:GuidelineSpecifiedDocumentContextParameter><ram:GuidelineSpecifiedDocumentContextParameter>"
       b"<ram:ID>" + UBL_EXTENSION.encode() + b"</ram:ID></ram:GuidelineSpecifiedDocumentContextParameter>")]),
    ("m-promoted-ubl.xml", "extension_04.01a-INVOICE_ubl.xml",
     [(b"<cbc:CustomizationID>" + UBL_EXTENSION.encode() + b"</cbc:CustomizationID>",
       b"<cbc:CustomizationID>" + UBL_STANDARD.encode() + b"</cbc:CustomizationID>")]),
]


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


def make_mutants(folder):
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
    for name, source, edits in MUTANTS:
        data = open(os.path.join(INSTANCES, source), "rb").read()
        for old, new in edits:
            if data.count(old) != 1:
                sys.exit("mutant %s: %r occurs %d times in %s" % (name, old, data.count(old), source))
            data = data.replace(old, new)
        open(os.path.join(folder, name), "wb").write(data)


def run_kosit(java, files, out):
    jar = glob.glob(os.path.join(TOOLS, "validator", "validator-*-standalone.jar"))
    if not jar or not os.path.isfile(os.path.join(CONFIG, "scenarios.xml")):
        sys.exit("KoSIT validator or XRechnung configuration missing: run addons/java-tools/install-tools.ps1")
    os.makedirs(out, exist_ok=True)
    empty = os.path.join(out, "empty-input.txt")
    open(empty, "w").close()
    for i in range(0, len(files), 100):
        with open(empty) as stdin:
            subprocess.run([java, "-jar", jar[0], "-r", CONFIG, "-s", os.path.join(CONFIG, "scenarios.xml"),
                            "-o", out] + files[i:i + 100], stdin=stdin, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)


def kosit_result(report):
    """The comparable lines of a KoSIT report."""
    root = ET.parse(report).getroot()
    lines = []
    name = root.find(REP + "scenarioMatched/" + SCN + "scenario/" + SCN + "name")
    lines.append("scenario " + (name.text.strip() if name is not None else "none"))
    for step in root.iter(REP + "validationStepResult"):
        sid = step.get("id")
        messages = step.findall(REP + "message")
        if sid == "val-xsd":
            for m in messages:
                lines.append("xsd %s %s:%s" % (m.get("code"), m.get("lineNumber", "0"), m.get("columnNumber", "0")))
        elif sid.startswith("val-sch."):
            for m in messages:
                lines.append("sch%s %s %s %s" % (sid[8:], m.get("code"), m.get("level"), m.get("xpathLocation", "")))
        elif messages:
            lines.append("wf %d" % len(messages))
    assessment = root.find(REP + "assessment")
    accept = assessment is not None and assessment.find(REP + "accept") is not None
    lines.append("verdict " + ("accept" if accept else "reject"))
    return [lines[0]] + sorted(lines[1:-1]) + [lines[-1]]


def probe_output(probe, folders):
    out = subprocess.run([probe, os.path.join(CONFIG, "scenarios.xml"), RULES] + folders,
                         capture_output=True, text=True, encoding="ascii", errors="replace")
    if out.returncode != 0:
        sys.exit("probe failed: " + out.stdout + out.stderr)
    return out


def probe_results(probe, folders):
    """{file: comparable lines} from the probe's output."""
    out = probe_output(probe, folders)
    results = {}
    current = None
    wf = 0
    for line in out.stdout.splitlines():
        if line.startswith("## "):
            current = line[3:]
            results[current] = []
            wf = 0
            continue
        if line.startswith("scenario "):
            text = line[9:]
            results[current].append("scenario " + (text.rsplit(" (matches ", 1)[0] if text != "none" else "none"))
        elif line.startswith("msg "):
            parts = line.split(" ", 6)
            step, code, level, location = parts[1], parts[2], parts[3], parts[6] if len(parts) > 6 else ""
            if step == "xsd":
                results[current].append("xsd %s %s" % (code, parts[5]))
            elif step == "wf":
                wf += 1
            else:
                results[current].append("%s %s %s %s" % (step, code, level, location))
        elif line in ("accepted", "rejected"):
            if wf:
                results[current].append("wf %d" % wf)
            results[current].append("verdict " + ("accept" if line == "accepted" else "reject"))
        elif line.startswith("exception "):
            results[current].append(line)
    for name, lines in results.items():
        results[name] = [lines[0]] + sorted(l for l in lines[1:] if not l.startswith("verdict ")) + \
            [l for l in lines if l.startswith("verdict ")]
    return results


def load_exceptions():
    items = []
    if os.path.isfile(EXCEPTIONS):
        for line in open(EXCEPTIONS, encoding="utf-8"):
            line = line.rstrip("\n")
            if line and not line.startswith("#"):
                pattern, diff = line.split("\t", 1)
                items.append([pattern, diff, False])
    return items


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--probe", default=os.path.join(REPO, "build", "fpc322-win64",
                                                     "ValidatorProbe" + (".exe" if os.name == "nt" else "")))
    ap.add_argument("--java")
    ap.add_argument("--keep", action="store_true", help="reuse the KoSIT reports in build/kosit-oracle")
    ap.add_argument("--update", action="store_true", help="rewrite tests/data/kosit-expected.txt")
    ap.add_argument("--corpus", choices=("suite", "generated", "outputs", "all"), default="suite")
    ap.add_argument("--toolchain", default="fpc322-linux", help="whose outputs --corpus outputs takes")
    args = ap.parse_args()
    if not os.path.isfile(os.path.join(INSTANCES, "MANIFEST.txt")) or not os.path.isdir(RULES):
        sys.exit("missing tests/data/local/kosit: run tools/testdata/sync-local.py")
    if not os.path.isfile(args.probe):
        sys.exit("probe missing: ./tools/build.ps1 fpc322-win64 -Program tools/kosit/ValidatorProbe.dpr -NoRun")
    runs = []
    if args.corpus in ("suite", "all"):
        mutants = os.path.join(OUT, "mutants")
        make_mutants(mutants)
        runs.append(("reports", [INSTANCES, mutants]))
    if args.corpus in ("generated", "all"):
        if not os.path.isdir(GENERATED):
            sys.exit("missing: " + GENERATED)
        # copied: some names are too long for MAX_PATH below the docs folder
        copy = os.path.join(OUT, "generated")
        if not args.keep or not os.path.isdir(copy):
            if os.path.isdir(copy):
                shutil.rmtree(copy)
            os.makedirs(copy)
            for f in glob.glob(os.path.join(GENERATED, "*.xml")):
                shutil.copyfile(f, os.path.join(copy, os.path.basename(f)))
        runs.append(("rep-gen", [copy]))
    if args.corpus in ("outputs", "all"):
        copy = os.path.join(OUT, "outputs")
        if not args.keep or not os.path.isdir(copy):
            if os.path.isdir(copy):
                shutil.rmtree(copy)
            os.makedirs(copy)
            for folder in ("cross", "cases", "sweep"):
                for pattern in ("*-ubl-30x.xml", "*-cii-30x.xml"):
                    for f in glob.glob(os.path.join(REPO, "build", args.toolchain, folder, pattern)):
                        shutil.copyfile(f, os.path.join(copy, folder + "_" + os.path.basename(f)))
        if not glob.glob(os.path.join(copy, "*.xml")):
            sys.exit("no XRechnung output in build/%s (run ./tools/build.ps1 first)" % args.toolchain)
        runs.append(("rep-out", [copy]))
    pairs = []
    ours = {}
    for sub, folders in runs:
        files = []
        for folder in folders:
            files += sorted(glob.glob(os.path.join(folder, "*.xml")))
        reports = os.path.join(OUT, sub)
        if not args.keep or not os.path.isdir(reports):
            if os.path.isdir(reports):
                shutil.rmtree(reports)
            run_kosit(find_java(args.java), files, reports)
        ours.update(probe_results(args.probe, folders))
        pairs += [(f, reports) for f in files]
    exceptions = load_exceptions()
    unexpected = 0
    compared = 0
    for f, reports in pairs:
        name = os.path.basename(f)
        report = os.path.join(reports, name[:-4] + "-report.xml")
        if not os.path.isfile(report):
            print("  no KoSIT report: " + name)
            unexpected += 1
            continue
        theirs = kosit_result(report)
        mine = ours.get(name, ["missing in the probe output"])
        compared += 1
        if theirs == mine:
            continue
        a, b = collections.Counter(theirs), collections.Counter(mine)
        for kind, lines in (("-", list((a - b).elements())), ("+", list((b - a).elements()))):
            for l in lines:
                diff = kind + " " + l
                hit = [e for e in exceptions if fnmatch.fnmatch(name, e[0]) and e[1] == diff]
                if hit:
                    for e in hit:
                        e[2] = True
                else:
                    print("  %s\t%s" % (name, diff))
                    unexpected += 1
    names = [os.path.basename(f) for f, _ in pairs]
    for pattern, diff, used in exceptions:
        # an exception for a corpus that did not run is not unused
        if not used and any(fnmatch.fnmatch(n, pattern) for n in names):
            print("  unused exception: %s\t%s" % (pattern, diff))
            unexpected += 1
    print("%d documents compared (corpus %s); '-' KoSIT only, '+' probe only" % (compared, args.corpus))
    print("no unexpected difference" if unexpected == 0 else "%d unexpected difference(s)" % unexpected)
    if args.update and unexpected == 0 and compared and args.corpus in ("suite", "all"):
        text = probe_output(args.probe, [INSTANCES]).stdout
        with open(EXPECTED, "w", encoding="ascii", newline="") as f:
            f.write("".join(line + chr(10) for line in text.splitlines()))
        print("written: " + os.path.relpath(EXPECTED, REPO))
    return 1 if unexpected or compared == 0 else 0


if __name__ == "__main__":
    sys.exit(main())
