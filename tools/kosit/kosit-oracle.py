#!/usr/bin/env python3
"""End-to-end oracle for LandrixEInvoiceValidator (KoSIT
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
with the folder as prefix.
--corpus peppol runs the Peppol BIS configuration of addons/java-tools
(validator-configuration-bis) instead: the Peppol examples (the corpus
peppol of tools/testdata/sync-local.py), the documents of the OpenPEPPOL
unit tests (as tools/rulecheck/peppol-oracle.py writes them, copied to
build/kosit-oracle/peppol-unit/), the Peppol files of a test run
(*-peppol.xml of build/<toolchain>/cross, cases and sweep) and mutants of
base-example.xml (build/kosit-oracle/peppol-mutants/: no scenario, not
well-formed, an XML schema error, a fatal and a warning-only Schematron
message). Its scenarios have no acceptMatch; KoSIT then accepts a
schema-valid document without any failed assert (the report's valid
attribute), not by the report's assessment, so that is the verdict there.
--corpus zugferd runs the ZUGFeRD 2.5.2 / Factur-X 1.09.2 configuration of
addons/java-tools (validator-configuration-zugferd): the ZUGFeRD examples
(corpus zugferd252 of sync-local.py), the CII examples in tests/data/local/cii
and cii-invalid, the ZUGFeRD files of a test run (*-cii*-25.xml of
build/<toolchain>/cross, cases and sweep) and mutants of E05_01_Einfach.xml
(build/kosit-oracle/zugferd-mutants/: no scenario, not well-formed, an XML
schema error, a fatal Schematron message, the generic EN16931 scenario).
The configuration ships its own Schematron sources: each Factur-X-*.xslt of
its Schema folder imports the XSLT of one profile, and the .sch next to that
XSLT's folder is mapped to it and compiled. The configuration writes
locations in the readable form /rsm:CrossIndustryInvoice/ram:x[1]; the
oracle writes them as SchXslt does.
--corpus all runs every corpus; --update then needs all of them to be clean.

--corpus auto checks the choice among several configurations
(TLandrixEInvoiceDocumentValidator with registered configurations): the
documents of the corpora suite, peppol and zugferd (without the unit test
fragments and the outputs; copied with a prefix to build/kosit-oracle/auto/)
run through each of the three configurations, in KoSIT and in the probe with
-matches; a configuration is a candidate where KoSIT chose a scenario and
where the probe counts exactly one match, and these must agree. The script
then lists the documents with several candidates and the configuration the
precedence picks (ZUGFeRD, Peppol BIS, XRechnung). It is not part of all.

Known differences are listed in tools/kosit/kosit-exceptions.txt
("file<TAB>difference line", '*' in the file name for any text, each with a
reason); an unused line is an error.

Needs tools/testdata/sync-local.py (copies the test suite and the rule files
to tests/data/local/kosit/, the Peppol schematron to
tests/data/local/kosit/peppol/), addons/java-tools/install-tools.ps1 and the
probe:
  ./tools/build.ps1 fpc322-win64 -Program tools/kosit/ValidatorProbe.dpr -NoRun

Usage:
  python tools/kosit/kosit-oracle.py [--corpus suite|generated|outputs|peppol|zugferd|all] [--toolchain <tc>]
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
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.join(REPO, "addons", "java-tools")
CONFIG = os.path.join(TOOLS, "validator-configuration-xrechnung")
CONFIG_BIS = os.path.join(TOOLS, "validator-configuration-bis")
CONFIG_ZF = os.path.join(TOOLS, "validator-configuration-zugferd")
LOCAL = os.path.join(REPO, "tests", "data", "local", "kosit")
INSTANCES = os.path.join(LOCAL, "instances")
RULES = os.path.join(LOCAL, "rules", "rules")
PEPPOL_RULES = os.path.join(LOCAL, "peppol", "PEPPOL-EN16931-UBL.sch")
PEPPOL_EXAMPLES = os.path.join(REPO, "tests", "data", "local", "sweep", "peppol")
ZF_EXAMPLES = os.path.join(REPO, "tests", "data", "local", "sweep", "zugferd252")
CII_EXAMPLES = [os.path.join(REPO, "tests", "data", "local", d) for d in ("cii", "cii-invalid")]
EXCEPTIONS = os.path.join(HERE, "kosit-exceptions.txt")
EXPECTED = os.path.join(REPO, "tests", "data", "kosit-expected.txt")
GENERATED = os.path.join(os.path.dirname(REPO), "landrix-einvoice-docs", "XRechnung 3.0.0",
                         "xrechnung-3.0.0-schematron-2.0.0", "generated")
OUT = os.path.join(REPO, "build", "kosit-oracle")
REP = "{http://www.xoev.de/de/validator/varl/1}"
SCN = "{http://www.xoev.de/de/validator/framework/1/scenarios}"
# a location step of the ISO skeleton (the XSLT of the Peppol configuration),
# *:name[namespace-uri()='ns'][n]; written as SchXslt does, Q{ns}name[n]
ISO_STEP = re.compile(r"\*:([^\[/]+)\[namespace-uri\(\)='([^']*)'\]\[(\d+)\]")

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

PEPPOL_ID = b"urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0"
UBL_CBC = b"urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
ZF_ID = b"<ram:ID>urn:cen.eu:en16931:2017</ram:ID>"

# the same for the ZUGFeRD configuration, from ZF_EXAMPLES (profile EN16931)
ZF_MUTANTS = [
    ("m-noscenario-zf.xml", "E05_01_Einfach.xml", [(ZF_ID, b"<ram:ID>urn:example:no-scenario</ram:ID>")]),
    ("m-notwellformed-zf.xml", "E05_01_Einfach.xml",
     [(b"</rsm:CrossIndustryInvoice>", b"</rsm:CrossIndustryInvoic>")]),
    ("m-xsd-zf.xml", "E05_01_Einfach.xml",
     [(b"<rsm:ExchangedDocument>", b"<rsm:ExchangedDocument><ram:Unknown>x</ram:Unknown>")]),
    ("m-fatal-zf.xml", "E05_01_Einfach.xml",
     [(b"<ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>",
       b"<ram:InvoiceCurrencyCode>XXX</ram:InvoiceCurrencyCode>")]),
    # an EN16931 specialisation of no known profile: the generic scenario
    ("m-generic-zf.xml", "E05_01_Einfach.xml",
     [(ZF_ID, b"<ram:ID>urn:cen.eu:en16931:2017#compliant#urn:example:cius</ram:ID>")]),
]

# a step of the readable location (ISO skeleton, get-full-path-3): the name
# with the prefix of the document (none for the default namespace); the root
# step has no position
NAME_STEP = re.compile(r"/(?:([A-Za-z_][\w.-]*):)?([A-Za-z_][\w.-]*)(\[\d+\])?")


# the start tag of the root element after the XML declaration
ROOT_TAG = re.compile(rb"<[A-Za-z][^>]*>")

# the same for the Peppol configuration, from PEPPOL_EXAMPLES
PEPPOL_MUTANTS = [
    ("m-noscenario-peppol.xml", "base-example.xml",
     [(b"<cbc:CustomizationID>" + PEPPOL_ID + b"</cbc:CustomizationID>",
       b"<cbc:CustomizationID>urn:example:no-scenario</cbc:CustomizationID>")]),
    ("m-notwellformed-peppol.xml", "base-example.xml", [(b"</Invoice>", b"</Invoic>")]),
    ("m-xsd-peppol.xml", "base-example.xml",
     [(b"<cbc:IssueDate>", b"<cbc:Unknown>x</cbc:Unknown><cbc:IssueDate>")]),
    ("m-fatal-peppol.xml", "base-example.xml",
     [(b"<cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>",
       b"<cbc:DocumentCurrencyCode>XXX</cbc:DocumentCurrencyCode>")]),
    # PEPPOL-COMMON-R054 (flag warning) only: KoSIT rejects it
    ("m-warning-peppol.xml", "base-example.xml",
     [(b'<cbc:EndpointID schemeID="0002">FR23342</cbc:EndpointID>',
       b'<cbc:EndpointID schemeID="0106">123</cbc:EndpointID>')]),
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


def make_mutants(folder, mutants=MUTANTS, sources=INSTANCES):
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
    for name, source, edits in mutants:
        data = open(os.path.join(sources, source), "rb").read()
        for old, new in edits:
            if data.count(old) != 1:
                sys.exit("mutant %s: %r occurs %d times in %s" % (name, old, data.count(old), source))
            data = data.replace(old, new)
        open(os.path.join(folder, name), "wb").write(data)


def run_kosit(java, config, files, out):
    jar = glob.glob(os.path.join(TOOLS, "validator", "validator-*-standalone.jar"))
    if not jar or not os.path.isfile(os.path.join(config, "scenarios.xml")):
        sys.exit("KoSIT validator or configuration missing: run addons/java-tools/install-tools.ps1")
    os.makedirs(out, exist_ok=True)
    empty = os.path.join(out, "empty-input.txt")
    open(empty, "w").close()
    for i in range(0, len(files), 100):
        with open(empty) as stdin:
            subprocess.run([java, "-jar", jar[0], "-r", config, "-s", os.path.join(config, "scenarios.xml"),
                            "-o", out] + files[i:i + 100], stdin=stdin, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)


def document_namespaces(document):
    """{prefix: namespace} of the document ('' for the default namespace)."""
    spaces = {}
    try:
        for _, (prefix, uri) in ET.iterparse(document, events=("start-ns",)):
            spaces.setdefault(prefix, uri)
    except ET.ParseError:
        pass
    return spaces


def readable_location(location, spaces):
    """A readable location written as SchXslt does; others unchanged."""
    if not location.startswith("/") or location.startswith("/Q{") or "*:" in location:
        return location
    steps = NAME_STEP.findall(location)
    joined = "".join("/%s%s%s" % (p + ":" if p else "", n, i) for p, n, i in steps)
    if joined != location or any(p not in spaces for p, _, _ in steps if p):
        return location
    return "".join("/Q{%s}%s%s" % (spaces.get(p, ""), n, i or "[1]") for p, n, i in steps)


def kosit_result(report, document=None):
    """The comparable lines of a KoSIT report (document: the validated file,
    for the prefixes of readable locations)."""
    spaces = document_namespaces(document) if document else {}
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
                location = ISO_STEP.sub(lambda s: "Q{%s}%s[%s]" % (s.group(2), s.group(1), s.group(3)),
                                      m.get("xpathLocation", ""))
                location = readable_location(location, spaces)
                lines.append("sch%s %s %s %s" % (sid[8:], m.get("code"), m.get("level"), location))
        elif messages:
            lines.append("wf %d" % len(messages))
    scenario = root.find(REP + "scenarioMatched/" + SCN + "scenario")
    if scenario is not None and scenario.find(SCN + "acceptMatch") is None:
        # no acceptMatch: KoSIT accepts a schema-valid document without any
        # failed assert. The report's valid attribute stands in for that: the
        # report stylesheet sets it from the message levels, which equals
        # KoSIT's rule only while every failed assert has level warning or
        # error and no successful report has (true for Peppol BIS 3.0.21:
        # flags fatal and warning only, no reports, no customLevel); check
        # that again for another configuration without acceptMatch
        accept = root.get("valid") == "true"
    else:
        assessment = root.find(REP + "assessment")
        accept = assessment is not None and assessment.find(REP + "accept") is not None
    lines.append("verdict " + ("accept" if accept else "reject"))
    return [lines[0]] + sorted(lines[1:-1]) + [lines[-1]]


def zugferd_maps():
    """<xslt>=<sch> arguments of the probe for the ZUGFeRD configuration: each
    Factur-X-*.xslt imports a profile's XSLT in <profile>/_XSLT_*/, the
    Schematron source lies in <profile>/."""
    maps = []
    for wrapper in sorted(glob.glob(os.path.join(CONFIG_ZF, "Schema", "Factur-X-*.xslt"))):
        try:
            imp = ET.parse(wrapper).getroot().find("{http://www.w3.org/1999/XSL/Transform}import")
        except ET.ParseError as e:
            sys.exit("%s: %s" % (wrapper, e))
        if imp is None:
            sys.exit("no xsl:import in " + wrapper)
        xslt = os.path.join(os.path.dirname(wrapper), *imp.get("href").split("/"))
        name = os.path.splitext(os.path.basename(xslt))[0] + ".sch"
        sch = os.path.join(os.path.dirname(os.path.dirname(xslt)), name)
        if not os.path.isfile(sch):
            sys.exit("no Schematron source for %s: %s" % (wrapper, sch))
        maps.append(os.path.basename(wrapper) + "=" + sch)
    if not maps:
        sys.exit("no Factur-X-*.xslt in " + CONFIG_ZF)
    return maps


def probe_args(config):
    return zugferd_maps() if config == CONFIG_ZF else []


def probe_output(probe, config, folders):
    out = subprocess.run([probe, os.path.join(config, "scenarios.xml"), LOCAL] + probe_args(config) + folders,
                         capture_output=True, text=True, encoding="ascii", errors="replace")
    if out.returncode != 0:
        sys.exit("probe failed: " + out.stdout + out.stderr)
    return out


def probe_results(probe, config, folders):
    """{file: comparable lines} from the probe's output."""
    out = probe_output(probe, config, folders)
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


# the configurations of --corpus auto in the order of precedence
AUTO_CONFIGS = [("zugferd", CONFIG_ZF), ("peppol", CONFIG_BIS), ("xrechnung", CONFIG)]


def check_auto(args):
    """--corpus auto: the candidates of KoSIT and of the probe agree."""
    for path in (PEPPOL_EXAMPLES, ZF_EXAMPLES):
        if not os.path.isdir(path):
            sys.exit("missing examples: run tools/testdata/sync-local.py")
    docs = os.path.join(OUT, "auto")
    if not args.keep or not os.path.isdir(docs):
        if os.path.isdir(docs):
            shutil.rmtree(docs)
        os.makedirs(docs)
        sources = [("suite", INSTANCES), ("peppol", PEPPOL_EXAMPLES), ("zugferd", ZF_EXAMPLES)]
        mutants = os.path.join(OUT, "mutants")
        make_mutants(mutants)
        sources.append(("suite-m", mutants))
        mutants = os.path.join(OUT, "peppol-mutants")
        make_mutants(mutants, PEPPOL_MUTANTS, PEPPOL_EXAMPLES)
        sources.append(("peppol-m", mutants))
        mutants = os.path.join(OUT, "zugferd-mutants")
        make_mutants(mutants, ZF_MUTANTS, ZF_EXAMPLES)
        sources.append(("zugferd-m", mutants))
        sources += [(os.path.basename(d), d) for d in CII_EXAMPLES if os.path.isdir(d)]
        for prefix, folder in sources:
            for f in glob.glob(os.path.join(folder, "*.xml")):
                shutil.copyfile(f, os.path.join(docs, prefix + "_" + os.path.basename(f)))
    files = sorted(glob.glob(os.path.join(docs, "*.xml")))
    candidates = collections.defaultdict(list)
    unexpected = 0
    for kind, config in AUTO_CONFIGS:
        reports = os.path.join(OUT, "auto-" + kind)
        if not args.keep or not os.path.isdir(reports):
            if os.path.isdir(reports):
                shutil.rmtree(reports)
            run_kosit(find_java(args.java), config, files, reports)
        out = subprocess.run([args.probe, os.path.join(config, "scenarios.xml"), LOCAL] + probe_args(config) +
                             ["-matches", docs], capture_output=True, text=True, encoding="ascii",
                             errors="replace")
        if out.returncode != 0:
            sys.exit("probe failed: " + out.stdout + out.stderr)
        matches = {}
        current = None
        for line in out.stdout.splitlines():
            if line.startswith("## "):
                current = line[3:]
            elif line.startswith("matches "):
                matches[current] = int(line[8:])
            elif line.startswith("exception "):
                print("  %s\t%s: probe %s" % (current, kind, line))
                unexpected += 1
        for f in files:
            name = os.path.basename(f)
            report = os.path.join(reports, name[:-4] + "-report.xml")
            # without a fallback scenario (ZUGFeRD) KoSIT writes no report
            # when no scenario matches
            theirs = os.path.isfile(report) and kosit_result(report)[0] != "scenario none"
            if name not in matches:
                print("  %s\t%s: no count from the probe" % (name, kind))
                unexpected += 1
                continue
            mine = matches[name] == 1
            if theirs != mine:
                print("  %s\t%s: KoSIT %s, probe %s matches" % (name, kind, "chose a scenario" if theirs else
                                                                "chose none", matches.get(name)))
                unexpected += 1
            if theirs:
                candidates[name].append(kind)
    by_set = collections.Counter(tuple(c) for c in candidates.values())
    none = len(files) - len(candidates)
    print("candidates per document (%d documents, %d without a candidate):" % (len(files), none))
    for kinds, count in sorted(by_set.items(), key=lambda x: (-len(x[0]), x[0])):
        print("  %-28s %5d  -> %s" % ("+".join(kinds), count, kinds[0]))
    several = sorted(n for n, c in candidates.items() if len(c) > 1)
    for name in several[:20]:
        print("  several: %s (%s)" % (name, "+".join(candidates[name])))
    if len(several) > 20:
        print("  ... %d more with several candidates" % (len(several) - 20))
    print("no unexpected difference" if unexpected == 0 else "%d unexpected difference(s)" % unexpected)
    return 1 if unexpected or not files else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--probe", default=os.path.join(REPO, "build", "fpc322-win64",
                                                     "ValidatorProbe" + (".exe" if os.name == "nt" else "")))
    ap.add_argument("--java")
    ap.add_argument("--keep", action="store_true", help="reuse the KoSIT reports in build/kosit-oracle")
    ap.add_argument("--update", action="store_true", help="rewrite tests/data/kosit-expected.txt")
    ap.add_argument("--corpus", choices=("suite", "generated", "outputs", "peppol", "zugferd", "all", "auto"),
                    default="suite")
    ap.add_argument("--toolchain", default="fpc322-linux",
                    help="whose outputs the corpora outputs, peppol and zugferd take")
    args = ap.parse_args()
    if not os.path.isfile(os.path.join(INSTANCES, "MANIFEST.txt")) or not os.path.isdir(RULES):
        sys.exit("missing tests/data/local/kosit: run tools/testdata/sync-local.py")
    if not os.path.isfile(args.probe):
        sys.exit("probe missing: ./tools/build.ps1 fpc322-win64 -Program tools/kosit/ValidatorProbe.dpr -NoRun")
    if args.corpus == "auto":
        return check_auto(args)
    runs = []
    if args.corpus in ("suite", "all"):
        mutants = os.path.join(OUT, "mutants")
        make_mutants(mutants)
        runs.append(("reports", CONFIG, [INSTANCES, mutants]))
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
        runs.append(("rep-gen", CONFIG, [copy]))
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
        runs.append(("rep-out", CONFIG, [copy]))
    if args.corpus in ("peppol", "all"):
        if not os.path.isfile(PEPPOL_RULES) or not os.path.isdir(PEPPOL_EXAMPLES):
            sys.exit("missing Peppol schematron or examples: run tools/testdata/sync-local.py")
        mutants = os.path.join(OUT, "peppol-mutants")
        make_mutants(mutants, PEPPOL_MUTANTS, PEPPOL_EXAMPLES)
        unit = os.path.join(OUT, "peppol-unit")
        if not args.keep or not os.path.isdir(unit):
            if os.path.isdir(unit):
                shutil.rmtree(unit)
            os.makedirs(unit)
            sys.path.insert(0, os.path.join(os.path.dirname(HERE), "rulecheck"))
            __import__("peppol-oracle").extract(__import__("peppol-oracle").TESTS, unit)
            # most fragments have no CustomizationID and match no scenario;
            # a copy with it (id- prefix) runs scenario choice and XML schema
            for f in glob.glob(os.path.join(unit, "*.xml")):
                data = open(f, "rb").read()
                if b"CustomizationID" not in data:
                    start = ROOT_TAG.search(data)
                    tag = b'<CustomizationID xmlns="' + UBL_CBC + b'">' + PEPPOL_ID + b"</CustomizationID>"
                    data = data[:start.end()] + tag + data[start.end():]
                    open(os.path.join(unit, "id-" + os.path.basename(f)), "wb").write(data)
        copy = os.path.join(OUT, "peppol-out")
        if not args.keep or not os.path.isdir(copy):
            if os.path.isdir(copy):
                shutil.rmtree(copy)
            os.makedirs(copy)
            for folder in ("cross", "cases", "sweep"):
                for f in glob.glob(os.path.join(REPO, "build", args.toolchain, folder, "*-peppol.xml")):
                    shutil.copyfile(f, os.path.join(copy, folder + "_" + os.path.basename(f)))
        runs.append(("rep-peppol", CONFIG_BIS, [PEPPOL_EXAMPLES, mutants, unit, copy]))
    if args.corpus in ("zugferd", "all"):
        if not os.path.isdir(ZF_EXAMPLES):
            sys.exit("missing ZUGFeRD examples: run tools/testdata/sync-local.py")
        mutants = os.path.join(OUT, "zugferd-mutants")
        make_mutants(mutants, ZF_MUTANTS, ZF_EXAMPLES)
        copy = os.path.join(OUT, "zugferd-out")
        if not args.keep or not os.path.isdir(copy):
            if os.path.isdir(copy):
                shutil.rmtree(copy)
            os.makedirs(copy)
            for folder in ("cross", "cases", "sweep"):
                for f in glob.glob(os.path.join(REPO, "build", args.toolchain, folder, "*-cii*-25.xml")):
                    shutil.copyfile(f, os.path.join(copy, folder + "_" + os.path.basename(f)))
        runs.append(("rep-zugferd", CONFIG_ZF, [ZF_EXAMPLES, mutants, copy] +
                     [d for d in CII_EXAMPLES if os.path.isdir(d)]))
    pairs = []
    ours = {}
    for sub, config, folders in runs:
        files = []
        for folder in folders:
            files += sorted(glob.glob(os.path.join(folder, "*.xml")))
        # results and reports are keyed by the file name
        if len(set(os.path.basename(f) for f in files)) != len(files):
            sys.exit("file names of run %s are not unique" % sub)
        reports = os.path.join(OUT, sub)
        if not args.keep or not os.path.isdir(reports):
            if os.path.isdir(reports):
                shutil.rmtree(reports)
            run_kosit(find_java(args.java), config, files, reports)
        ours.update(probe_results(args.probe, config, folders))
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
        theirs = kosit_result(report, f)
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
        text = probe_output(args.probe, CONFIG, [INSTANCES]).stdout
        with open(EXPECTED, "w", encoding="ascii", newline="") as f:
            f.write("".join(line + chr(10) for line in text.splitlines()))
        print("written: " + os.path.relpath(EXPECTED, REPO))
    return 1 if unexpected or compared == 0 else 0


if __name__ == "__main__":
    sys.exit(main())
