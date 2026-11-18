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

--report-input also compares the KoSIT report input of every document
(in:createReportInput, which the KoSIT validator writes with
--serialize-report-input and the probe with -input:, see
LandrixEInvoiceKositReportInput): every element and attribute, the text
with white space normalized, except what differs by nature (engine name,
timestamp, document reference, the text of processing errors), the
well-formedness errors by count only (as above), XML schema messages by code,
line and column (the parsers word them differently), and of the SVRL only
what the report stylesheet reads (svrl:failed-assert and
svrl:successful-report with location, id, flag and role, the location
written as SchXslt does as above, and the svrl:text unchanged); active
patterns, fired and suppressed rules and the other attributes are left
out. The document hash is checked against the SHA-256 of the file, not
against KoSIT: the KoSIT validator 1.6.3 hashes only the first bytes of some
documents (8,230 of 12,988 for ubl-inv-br-de-27-test-145-code--0-1-.xml of
the generated corpus). A processing error "Report input has errors" of
KoSIT is left out: KoSIT checks its report input against its own schema,
which requires an id on svrl:successful-report, and some ZUGFeRD rules
have none; the native report input is not checked against that schema.
Its difference lines start with "input ". The probe's report inputs are in
build/kosit-oracle/<run>/ours/. Run it together with --report: the copied
scenario text (normalized here) and the SVRL elements left out here are
checked only through the report.

--report also compares the KoSIT report itself (LandrixEInvoiceKositReport:
the report stylesheet of the configuration run with the LandrixXML XSLT
engine on the probe's report input; KoSIT runs with --extract-html, the
probe with -report:): the report XML and its HTML page must be equal byte
for byte except the engine name, the timestamp, the document reference and
the document hash (checked with --report-input), the same values where the
embedded HTML page shows them, and the text of the well-formedness and XML
schema messages (the parsers word them differently, Xerces in the language
of the system; their codes and positions are compared above) with the line
and column of a well-formedness error (KoSIT has none; in a report with a
well-formedness message every position cell is left out); Schematron
locations are compared as SchXslt writes them, as above. Its difference
lines start with "report ".

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
      [--probe <exe>] [--java <java>] [--keep] [--update] [--report-input] [--report]
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
import hashlib
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


def run_kosit(java, config, files, out, report_input=False, html=False):
    jar = glob.glob(os.path.join(TOOLS, "validator", "validator-*-standalone.jar"))
    if not jar or not os.path.isfile(os.path.join(config, "scenarios.xml")):
        sys.exit("KoSIT validator or configuration missing: run addons/java-tools/install-tools.ps1")
    os.makedirs(out, exist_ok=True)
    empty = os.path.join(out, "empty-input.txt")
    open(empty, "w").close()
    # the validator writes the report input to the current directory
    extra = (["--serialize-report-input"] if report_input else []) + (["--extract-html"] if html else [])
    for i in range(0, len(files), 100):
        with open(empty) as stdin:
            subprocess.run([java, "-jar", os.path.abspath(jar[0]), "-r", os.path.abspath(config), "-s",
                            os.path.abspath(os.path.join(config, "scenarios.xml")), "-o", os.path.abspath(out)] +
                           extra + [os.path.abspath(f) for f in files[i:i + 100]], stdin=stdin,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=out)


IN = "{http://www.xoev.de/de/validator/framework/1/createreportinput}"
SVRL = "{http://purl.oclc.org/dsdl/svrl}"
SVRL_KEPT = {SVRL + "schematron-output", SVRL + "failed-assert", SVRL + "successful-report", SVRL + "text"}
INPUT_MASKED = {IN + "name", IN + "timestamp", IN + "documentReference", IN + "error", IN + "hashValue"}
SVRL_ATTRIBUTES = ("location", "id", "flag", "role")


def file_hash(path):
    import base64
    import hashlib
    return base64.b64encode(hashlib.sha256(open(path, "rb").read()).digest()).decode()


REPORT_MASKS = [re.compile(r"(<rep:(?:name|timestamp|documentReference|hashValue)>)[^<]*(</rep:)"),
                re.compile(r"(<dd>)\d\d\.\d\d\.\d{4} \d\d:\d\d:\d\d(</dd>)")]


PARSER_MESSAGE = re.compile(r'(<rep:message [^>]*(?:id="val-xml[^"]*"|code="cvc-[^"]*")[^>]*>)(.*?)(</rep:message>)', re.S)


def parser_messages(report_path):
    """The texts of the well-formedness and XML schema messages of a report."""
    try:
        return [m.group(2) for m in PARSER_MESSAGE.finditer(open(report_path, encoding="utf-8").read())]
    except OSError:
        return []


def masked_report(path, messages, well_formedness=False, spaces=None):
    """The report or its HTML page with the values that differ by nature
    replaced (messages: the parser message texts of both reports); None if
    the file is missing."""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return None
    for mask in REPORT_MASKS:
        text = mask.sub(lambda m: m.group(1) + "*" + m.group(2), text)
    # the engine name and the document reference as the page shows them
    text = re.sub(r"(erstellt mit |created with )[^<]*(\.</p>)", lambda m: m.group(1) + "*" + m.group(2), text)
    text = re.sub(r"(<dd>)(?:/?[A-Za-z]:[/\\]|/)[^<]*\.xml(</dd>)", lambda m: m.group(1) + "*" + m.group(2), text)

    def message(m):
        head = m.group(1)
        if 'id="val-xml' in head:
            head = re.sub(r' (?:lineNumber|columnNumber)="[^"]*"', "", head)
        return head + "*" + m.group(3)

    text = PARSER_MESSAGE.sub(message, text)
    # Schematron locations as SchXslt writes them (the XSLT of the Peppol and
    # ZUGFeRD configurations write other forms, as compared above)

    def location(m):
        loc = ISO_STEP.sub(lambda s: "Q{%s}%s[%s]" % (s.group(2), s.group(1), s.group(3)), m.group(2))
        return m.group(1) + readable_location(loc, spaces or {}) + m.group(3)

    text = re.sub(r'( xpathLocation=")([^"]*)(")', location, text)
    text = re.sub(r"(<td>Pfad: )([^<]*)(</td>)", location, text)
    # the position cell of a well-formedness error (KoSIT has none): only
    # in a report with a well-formedness message; empty cells alike
    if well_formedness:
        text = re.sub(r"<td>\s*Zeile: \d+(?: Spalte: \d+)?</td>|<td/>", "<td></td>", text)
    # the texts where the page shows them (the page may break their lines)
    for t in sorted(set(messages), key=len, reverse=True):
        if t.split():
            text = re.sub(r"\s+".join(re.escape(w) for w in t.split()), "*", text)
    return text


def report_lines(theirs_path, ours_path, html, document=None):
    """[] if equal, else a line naming the first difference and the digests
    of both masked reports (an exception then covers exactly this pair)."""
    kind = "html" if html else "xml"
    messages = parser_messages(re.sub(r"\.html$", ".xml", theirs_path)) + \
        parser_messages(re.sub(r"\.html$", ".xml", ours_path))
    xml_theirs = re.sub(r"\.html$", ".xml", theirs_path)
    try:
        well_formedness = 'id="val-xml' in open(xml_theirs, encoding="utf-8").read()
    except OSError:
        well_formedness = False
    spaces = document_namespaces(document) if document else {}
    a = masked_report(theirs_path, messages, well_formedness, spaces)
    b = masked_report(ours_path, messages, well_formedness, spaces)
    if a == b:
        return []
    if a is None or b is None:
        return ["report %s %s" % (kind, "KoSIT has none" if a is None else "the probe has none")]
    i = next((k for k in range(min(len(a), len(b))) if a[k] != b[k]), min(len(a), len(b)))
    return ["report %s differs at %d: KoSIT %r, probe %r (sha256 %s, %s)" % (
        kind, i, a[max(0, i - 30):i + 30], b[max(0, i - 30):i + 30],
        hashlib.sha256(a.encode("utf-8")).hexdigest()[:16], hashlib.sha256(b.encode("utf-8")).hexdigest()[:16])]


def input_lines(path, document=None, check_hash=False):
    """The comparable lines of a KoSIT report input (see --report-input);
    document: the validated file (prefixes of readable locations, and its
    hash with check_hash)."""
    lines = []
    spaces = document_namespaces(document) if document else {}

    def walk(e, where, wellformedness):
        tag = e.tag
        if tag.startswith(SVRL) and tag not in SVRL_KEPT:
            return
        # the expanded name: a wrong namespace is a difference
        here = where + "/" + tag
        if tag == IN + "processingError":
            kept = [x for x in e.findall(IN + "error") if not (x.text or "").startswith("Report input has errors")]
            if not kept:
                return
        if tag == IN + "error" and (e.text or "").startswith("Report input has errors"):
            return
        if tag == IN + "validationResultsWellformedness":
            lines.append("%s %d" % (here, len(e.findall(IN + "xmlSyntaxError"))))
            return
        if tag == IN + "message":
            # Xerces wording differs: the code only
            text = (e.text or "").split(":", 1)[0] if (e.text or "").startswith("cvc-") else "*"
        elif tag == IN + "hashValue" and check_hash:
            text = "*" if (e.text or "") == file_hash(document) else "differs from the file's SHA-256"
        elif tag in INPUT_MASKED:
            text = "*"
        elif tag == SVRL + "text":
            text = repr(e.text or "")
        else:
            text = " ".join((e.text or "").split())
        items = sorted(e.attrib.items())
        if tag == SVRL + "schematron-output":
            items = []
        elif tag in (SVRL + "failed-assert", SVRL + "successful-report"):
            items = [(k, v) for k, v in items if k in SVRL_ATTRIBUTES]
            items = [(k, readable_location(ISO_STEP.sub(lambda m: "Q{%s}%s[%s]" % (m.group(2), m.group(1),
                                                                                     m.group(3)), v), spaces)
                      if k == "location" else v) for k, v in items]
        attrs = " ".join("%s=%s" % (k, " ".join(v.split())) for k, v in items)
        lines.append(("%s [%s] %s" % (here, attrs, text)).rstrip())
        for c in e:
            walk(c, here, wellformedness)

    try:
        walk(ET.parse(path).getroot(), "", False)
    except (OSError, ET.ParseError) as e:
        return ["unreadable %s" % e]
    return lines


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


def probe_output(probe, config, folders, input_dir=None, report=False):
    extra = ["-input:" + input_dir] if input_dir else []
    if input_dir and report:
        extra.append("-report:" + input_dir)
    out = subprocess.run([probe, os.path.join(config, "scenarios.xml"), LOCAL] + probe_args(config) + extra + folders,
                         capture_output=True, text=True, encoding="ascii", errors="replace")
    if out.returncode != 0:
        sys.exit("probe failed: " + out.stdout + out.stderr)
    return out


def probe_results(probe, config, folders, input_dir=None, report=False):
    """{file: comparable lines} from the probe's output."""
    out = probe_output(probe, config, folders, input_dir, report)
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
        elif line.startswith("report accept") or line.startswith("report reject"):
            pass
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
    ap.add_argument("--report-input", action="store_true",
                    help="also compare the KoSIT report input of every document")
    ap.add_argument("--report", action="store_true",
                    help="also compare the KoSIT report and its HTML page")
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
        if not args.keep or not os.path.isdir(reports) or (
                args.report_input and not glob.glob(os.path.join(reports, "*-reportInput.xml"))) or (
                args.report and not glob.glob(os.path.join(reports, "*-report.html"))):
            if os.path.isdir(reports):
                shutil.rmtree(reports)
            run_kosit(find_java(args.java), config, files, reports, args.report_input or args.report,
                      args.report)
        input_dir = None
        if args.report_input or args.report:
            input_dir = os.path.join(reports, "ours")
            if os.path.isdir(input_dir):
                shutil.rmtree(input_dir)
            os.makedirs(input_dir)
        ours.update(probe_results(args.probe, config, folders, input_dir, args.report))
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
        if args.report:
            for html in (False, True):
                stem = name[:-4] + ("-report.html" if html else "-report.xml")
                mine = mine + report_lines(os.path.join(reports, stem), os.path.join(reports, "ours", stem), html, f)
        if args.report_input:
            stem = name[:-4] + "-reportInput.xml"
            theirs = theirs + ["input " + l for l in input_lines(os.path.join(reports, stem), f)]
            mine = mine + ["input " + l for l in input_lines(os.path.join(reports, "ours", stem), f, True)]
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
        # an exception for a corpus that did not run is not unused, nor one
        # for the report input without --report-input or for the report
        # without --report
        if not used and any(fnmatch.fnmatch(n, pattern) for n in names) and (
                args.report_input or not diff.startswith(("- input ", "+ input "))) and (
                args.report or not diff.startswith(("- report ", "+ report "))):
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
