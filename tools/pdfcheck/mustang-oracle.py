#!/usr/bin/env python3
"""Oracle for the PDF checker, level 3 (plan, PDF level 3): Mustang against
tools/pdfcheck/PdfCheckProbe.dpr on the local PDF corpus.

Mustang (addons/java-tools/mustang, pinned by install-tools.ps1, run with the
Java runtime from addons/java-tools/jre or java from the PATH) validates every
PDF in which the probe found a Factur-X or XRechnung invoice (level 3 ran).
From the PDF part of its report the oracle takes the XMP findings and
compares, per PDF:

  ConformanceLevel  Mustang 11/12 (not found, invalid) against ours:
                    BR-HYBRID-07 at XMP fx:ConformanceLevel, or BR-HYBRID-04
                    "no Factur-X properties"
  DocumentType      Mustang 13/14 against BR-HYBRID-06 (or -04, as above)
  DocumentFileName  Mustang 21/19 against BR-HYBRID-08 (or -04)
  Version           Mustang 15/16 against BR-HYBRID-09 (or -04)
  xmp               Mustang 17 (error) or 28 (no or unparsable XMP) against
                    LX-PDF-11
  pdfa              Mustang 23 (veraPDF finds no PDF/A-3 flavour) against
                    BR-HYBRID-02 at XMP pdfaid:part; not compared when our
                    XMP is unreadable (LX-PDF-11): then neither side can read
                    pdfaid, and veraPDF falls back to PDF/A-1b
  mustang           Mustang gives a report with a PDF part and no fatal or
                    exception entry in it
  probe             level 3 of the probe is complete (passed or failed): an
                    incomplete or skipped level would compare as no finding

Mustang is looser by design: it finds the properties by local name in any
namespace and accepts COMFORT, CIUS, ORDER, ORDER_RESPONSE, ORDER_CHANGE,
ZUGFeRD-invoice.xml, order-x.xml and a fixed list of versions. Where we are
stricter (BR-HYBRID-04/-05, Order-X values, usage rules, duplicates, the
PDF/A conformance level) the difference is expected; such a case in the
corpus goes to the exceptions with its reason. Both compare values exactly,
without trimming white space.

The corpus has few broken XMP packets, so build/mustang-oracle/mutants/ adds
copies of corpus PDFs with an uncompressed XMP in which one value is changed
in place (same length, the cross-reference table stays valid): the document
type, the conformance level, the file name, the version (on factur-x.xml
PDFs), pdfaid:part 3 -> 2 and </rdf:RDF> -> </rdf:RDG> (not well-formed).
The pattern must occur once in the file, the mutated check must pass on the
source PDF on both sides and fail on the mutant on our side (check mutant);
the comparison then shows whether Mustang agrees.

Known differences go to tools/pdfcheck/mustang-exceptions.txt ("file<TAB>check
<TAB>reason"; file may be *); an exception no difference uses fails the run.
Output in build/mustang-oracle/; the reports are cached per Mustang version
and SHA-256 of the PDF in reports/<version>/ and reused with --keep. Build
the probe first: ./tools/build.ps1 fpc322-win64 -Program tools/pdfcheck/PdfCheckProbe.dpr -NoRun
"""

import argparse
import concurrent.futures
import hashlib
import os
import platform
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORPUS = os.path.join(ROOT, 'tests', 'data', 'local', 'pdf')
OUT = os.path.join(ROOT, 'build', 'mustang-oracle')
EXCEPTIONS = os.path.join(ROOT, 'tools', 'pdfcheck', 'mustang-exceptions.txt')
TOOLS = os.path.join(ROOT, 'addons', 'java-tools')
MUSTANG = '2.26.0'
JAR = os.path.join(TOOLS, 'mustang', 'Mustang-CLI-' + MUSTANG + '.jar')
# seconds per Mustang run and per probe run
TIMEOUT = 600

# Mustang section numbers of its PDF part, per compared check
SECTIONS = {
    'ConformanceLevel': ('11', '12'),
    'DocumentType': ('13', '14'),
    'DocumentFileName': ('21', '19'),
    'Version': ('15', '16'),
    'xmp': ('17', '28'),
    'pdfa': ('23',),
}
OURS = {
    'ConformanceLevel': 'BR-HYBRID-07',
    'DocumentType': 'BR-HYBRID-06',
    'DocumentFileName': 'BR-HYBRID-08',
    'Version': 'BR-HYBRID-09',
}

# (mutant tag, pattern with the value as group 2, replacement of the value,
#  the check it breaks, only on PDFs containing this)
MUTATIONS = [
    ('t', rb'(fx:DocumentType>|fx:DocumentType=")(INVOICE)([<"])', b'INVOICQ', 'DocumentType', b''),
    ('c', rb'(fx:ConformanceLevel>|fx:ConformanceLevel=")(EN 16931)([<"])', b'EN 16932', 'ConformanceLevel', b''),
    ('f', rb'(fx:DocumentFileName>|fx:DocumentFileName=")(factur-x[.]xml)([<"])', b'factur-x.xmq',
     'DocumentFileName', b''),
    ('v', rb'(fx:Version>|fx:Version=")(1[.]0)([<"])', b'1.9', 'Version', b'factur-x.xml'),
    ('p', rb'(pdfaid:part>|pdfaid:part=")(3)([<"])', b'2', 'pdfa', b'factur-x.xml'),
    ('x', rb'(</rdf:)(RDF)(>)', b'RDG', 'xmp', b'factur-x.xml'),
]


def find_java():
    machine = platform.machine().lower()
    arch = 'aarch64' if machine in ('arm64', 'aarch64') else 'x64'
    osname = {'win32': 'windows', 'darwin': 'macos'}.get(sys.platform, 'linux')
    exe = os.path.join(TOOLS, 'jre', osname + '-' + arch, 'bin', 'java.exe' if osname == 'windows' else 'java')
    if os.path.isfile(exe):
        return exe
    exe = shutil.which('java')
    if exe:
        return exe
    sys.exit('java not found: run addons/java-tools/install-tools.ps1 or install Java 21')


def find_probe(toolchain):
    name = 'PdfCheckProbe.exe' if sys.platform == 'win32' else 'PdfCheckProbe'
    exe = os.path.join(ROOT, 'build', toolchain, name)
    if not os.path.isfile(exe):
        sys.exit('probe not found: ' + exe + ' (build it, see the docstring)')
    return exe


def load_exceptions():
    result = []
    if os.path.isfile(EXCEPTIONS):
        with open(EXCEPTIONS, encoding='utf-8') as f:
            for line in f:
                line = line.rstrip('\n')
                if not line.strip() or line.startswith('#'):
                    continue
                parts = line.split('\t')
                if len(parts) < 3:
                    sys.exit('mustang-exceptions.txt: need file<TAB>check<TAB>reason: ' + line)
                result.append((parts[0], parts[1]))
    return result


def excepted(exceptions, used, name, check):
    for item in exceptions:
        if (item[0] == '*' or item[0] == name) and item[1] == check:
            used.add(item)
            return True
    return False


def run_probe(probe, folders):
    """file name -> {'kind', 'status3', 'findings': [(rule, path, message)]}"""
    try:
        out = subprocess.run([probe] + folders, capture_output=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        sys.exit('probe did not finish within %d seconds' % TIMEOUT)
    if out.returncode != 0:
        sys.exit('probe failed: ' + out.stderr.decode('utf-8', 'replace'))
    files = {}
    current = None
    for raw in out.stdout.decode('utf-8', 'replace').split(chr(10)):
        raw = raw.rstrip(chr(13))
        if not raw:
            continue
        if not raw.startswith('  '):
            cols = raw.split('\t')
            if len(cols) < 7:
                # the rest of a message with a line break
                continue
            current = {'kind': cols[2], 'status3': cols[5], 'findings': []}
            files[cols[0]] = current
            continue
        cols = raw[2:].split('\t')
        if current is not None and len(cols) >= 3:
            current['findings'].append((cols[1], cols[2], cols[3] if len(cols) > 3 else ''))
    return files


def our_checks(findings):
    """The checks we fail, by the same names as SECTIONS."""
    result = set()
    for rule, path, message in findings:
        if rule == 'BR-HYBRID-04' and 'no Factur-X properties' in message:
            result.update(OURS)
        for prop, our_rule in OURS.items():
            if rule == our_rule and path == 'XMP fx:' + prop:
                result.add(prop)
        if rule == 'LX-PDF-11':
            result.add('xmp')
        if rule == 'BR-HYBRID-02' and path == 'XMP pdfaid:part':
            result.add('pdfa')
    return result


def make_mutants(folder, candidates, ours):
    """Per mutation up to two copies (element and attribute form) of corpus
    PDFs in which the pattern occurs exactly once and whose mutated check
    passes on our side. Returns mutant name -> (source name, check)."""
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    expected = {}
    for tag, pattern, value, check, needs in MUTATIONS:
        rx = re.compile(pattern)
        forms = set()
        for name in candidates:
            if check in our_checks(ours[name]['findings']):
                continue
            with open(os.path.join(CORPUS, name), 'rb') as f:
                data = f.read()
            if needs and needs not in data:
                continue
            found = list(rx.finditer(data))
            if len(found) != 1:
                continue
            form = found[0].group(1)[-1:]
            if form in forms:
                continue
            forms.add(form)
            m = found[0]
            mutant = 'x' + tag + name
            with open(os.path.join(folder, mutant), 'wb') as f:
                f.write(data[:m.start(2)] + value + data[m.end(2):])
            expected[mutant] = (name, check)
            if len(forms) == 2:
                break
        if not forms:
            sys.exit('no PDF for the mutation ' + tag)
    return expected


def run_mustang(java, pdf, reports, keep):
    """The Mustang report of pdf, cached under the SHA-256 of the PDF."""
    with open(pdf, 'rb') as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    report = os.path.join(reports, digest + '.xml')
    if keep and os.path.isfile(report) and os.path.getsize(report) > 0:
        with open(report, encoding='utf-8', errors='replace') as f:
            return f.read()
    try:
        out = subprocess.run([java, '-Xmx1g', '-jar', JAR, '--action', 'validate', '--source', pdf, '--no-notices'],
                             capture_output=True, timeout=TIMEOUT)
        text = out.stdout.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired:
        text = ''
    with open(report, 'w', encoding='utf-8') as f:
        f.write(text)
    return text


def mustang_sections(text):
    """(error sections, fatal or exception entries) of the PDF part of a
    Mustang report; None without a PDF part."""
    m = re.search(r'<pdf>(.*?)</pdf>', text, re.S)
    if not m:
        return None
    return (set(re.findall(r'<error type="(\d+)"', m.group(1))),
            re.findall(r'<(?:fatal|exception)\b[^>]*>', m.group(1)))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--toolchain', default='fpc322-win64')
    ap.add_argument('--keep', action='store_true', help='reuse the cached Mustang reports')
    ap.add_argument('--jobs', type=int, default=max(1, (os.cpu_count() or 2) // 2))
    args = ap.parse_args()
    if not os.path.isfile(os.path.join(CORPUS, 'index.txt')):
        sys.exit('no local PDF corpus in ' + CORPUS)
    if not os.path.isfile(JAR):
        sys.exit('Mustang not found: ' + JAR + ' (run addons/java-tools/install-tools.ps1)')
    java = find_java()
    probe = find_probe(args.toolchain)
    exceptions = load_exceptions()
    reports = os.path.join(OUT, 'reports', MUSTANG)
    os.makedirs(reports, exist_ok=True)

    corpus = run_probe(probe, [CORPUS])
    checked = sorted(n for n, v in corpus.items() if v['kind'] in ('factur-x', 'xrechnung'))
    mutants = os.path.join(OUT, 'mutants')
    expected = make_mutants(mutants, checked, corpus)
    ours = dict(corpus)
    ours.update(run_probe(probe, [mutants]))
    pdfs = [(n, os.path.join(CORPUS, n)) for n in checked]
    pdfs += [(n, os.path.join(mutants, n)) for n in sorted(expected)]
    print('Mustang %s: %d PDFs with level 3 and %d mutants, %d jobs' % (MUSTANG, len(checked), len(expected),
                                                                       args.jobs))

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {name: pool.submit(run_mustang, java, pdf, reports, args.keep) for name, pdf in pdfs}
        theirs = {name: mustang_sections(fut.result()) for name, fut in futures.items()}

    diffs = []
    counts = {'excepted': 0, 'agree': 0}
    used = set()

    def report(name, check, text):
        if excepted(exceptions, used, name, check):
            counts['excepted'] += 1
        else:
            diffs.append(name + '\t' + check + '\t' + text)

    for name, _ in pdfs:
        mine = ours.get(name)
        if mine is None:
            report(name, 'probe', 'no probe output')
            continue
        if mine['status3'] not in ('passed', 'failed'):
            report(name, 'probe', 'level 3 is ' + mine['status3'])
            continue
        parsed = theirs[name]
        if parsed is None:
            report(name, 'mustang', 'no PDF part in the Mustang report')
            continue
        sections, fatal = parsed
        if fatal:
            report(name, 'mustang', 'Mustang: ' + ' '.join(fatal))
        fails = our_checks(mine['findings'])
        if name in expected:
            source, check = expected[name]
            if check not in fails:
                report(name, 'mutant', 'the probe does not fail ' + check)
            if theirs.get(source) is None or any(n in theirs[source][0] for n in SECTIONS[check]):
                report(name, 'mutant', 'Mustang does not pass ' + check + ' on the source ' + source)
        for check, numbers in sorted(SECTIONS.items()):
            if check == 'pdfa' and 'xmp' in fails:
                continue
            m_bad = any(n in sections for n in numbers)
            o_bad = check in fails
            if m_bad == o_bad:
                counts['agree'] += 1
            else:
                report(name, check, 'Mustang %s, ours %s' % ('fails' if m_bad else 'passes',
                                                              'fails' if o_bad else 'passes'))

    for item in exceptions:
        if item not in used:
            diffs.append('%s\t%s\tunused exception' % item)
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'differences.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(diffs) + ('\n' if diffs else ''))
    for line in diffs:
        print('  ' + line)
    print('%d PDFs, %d checks agree, %d excepted' % (len(pdfs), counts['agree'], counts['excepted']))
    if diffs:
        print('%d unexpected differences (build/mustang-oracle/differences.txt)' % len(diffs))
        return 1
    print('no unexpected difference')
    return 0


if __name__ == '__main__':
    sys.exit(main())
