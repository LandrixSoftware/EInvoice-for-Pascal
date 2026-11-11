#!/usr/bin/env python3
"""Oracle for the PDF reader and checker (plan, PDF level 2): qpdf against
tools/pdfcheck/PdfCheckProbe.dpr on the local PDF corpus.

Per PDF, qpdf (addons/java-tools/qpdf, pinned by install-tools.ps1; on Linux
and macOS qpdf from the PATH) gives the embedded files of the name tree
(--json=2 --json-key=attachments), the content of each (--show-attachment)
and whether the cross-reference table had to be rebuilt (--check). The probe
gives, with -facts=DIR, every file specification of our collector and its
decoded data. Compared per PDF:

  keys       the keys of the name tree (qpdf) and the keys of our file
             specifications reached by the name tree
  spec       per key: object number of the file specification, /F, /UF
  mime       per key: /Subtype of the embedded file stream
  moddate    per key: /Params /ModDate present (taken from the raw stream
             dictionary: qpdf's own date field is null for a time zone
             written as +01'00')
  data       per key: the content, byte for byte (qpdf: the preferred
             stream, /UF before /F; ours: /F before /UF, so a file
             specification with two different streams shows here)
  rebuilt    qpdf rebuilt the cross-reference table (--check reports
             "reconstruct") if and only if the probe reports LX-PDF-02
  probe      the probe reads the PDF (LX-PDF-01 is a difference, so an
             unreadable PDF never passes as two empty name trees)

The corpus has no damaged file, so build/pdf-oracle/mutants/ adds copies of
the first five PDFs with factur-x.xml whose last startxref points nowhere:
both sides must rebuild the table (checked) and still find the same files.

Known differences go to tools/pdfcheck/pdf-exceptions.txt ("file<TAB>check
<TAB>reason"; file may be *); an exception no difference uses fails the run.
Output in build/pdf-oracle/. Build the probe
first: ./tools/build.ps1 fpc322-win64 -Program tools/pdfcheck/PdfCheckProbe.dpr -NoRun
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORPUS = os.path.join(ROOT, 'tests', 'data', 'local', 'pdf')
OUT = os.path.join(ROOT, 'build', 'pdf-oracle')
EXCEPTIONS = os.path.join(ROOT, 'tools', 'pdfcheck', 'pdf-exceptions.txt')


def find_qpdf():
    machine = platform.machine().lower()
    arch = 'aarch64' if machine in ('arm64', 'aarch64') else 'x64'
    if sys.platform == 'win32':
        exe = os.path.join(ROOT, 'addons', 'java-tools', 'qpdf', 'windows-' + arch, 'bin', 'qpdf.exe')
        if os.path.isfile(exe):
            return exe
    exe = shutil.which('qpdf')
    if exe:
        return exe
    sys.exit('qpdf not found: run addons/java-tools/install-tools.ps1 or install qpdf')


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
                    sys.exit('pdf-exceptions.txt: need file<TAB>check<TAB>reason: ' + line)
                result.append((parts[0], parts[1]))
    return result


def excepted(exceptions, used, name, check):
    for item in exceptions:
        if (item[0] == '*' or item[0] == name) and item[1] == check:
            used.add(item)
            return True
    return False


def make_mutants(folder):
    """Copies of the first five PDFs with a factur-x.xml, the last startxref
    replaced by an offset beyond the end of the file."""
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    made = 0
    for name in sorted(os.listdir(CORPUS)):
        if made == 5:
            break
        if not name.lower().endswith('.pdf'):
            continue
        with open(os.path.join(CORPUS, name), 'rb') as f:
            data = f.read()
        if b'factur-x.xml' not in data:
            continue
        at = data.rfind(b'startxref')
        if at < 0:
            continue
        end = at + len(b'startxref')
        while end < len(data) and data[end:end + 1] in (bytes([13]), bytes([10]), b' '):
            end += 1
        stop = end
        while stop < len(data) and data[stop:stop + 1].isdigit():
            stop += 1
        with open(os.path.join(folder, 'm' + name), 'wb') as f:
            f.write(data[:end] + b'99999999' + data[stop:])
        made += 1
    if made < 5:
        sys.exit('only %d mutants: too few PDFs with factur-x.xml readable as bytes' % made)


def run_probe(probe, facts_dir, folders):
    """file name -> {'rules': set of rule ids, 'specs': [dict]}"""
    out = subprocess.run([probe, '-facts=' + facts_dir] + folders, capture_output=True)
    if out.returncode != 0:
        sys.exit('probe failed: ' + out.stderr.decode('utf-8', 'replace'))
    files = {}
    current = None
    # split on LF only: names may hold other line separators of Unicode
    for raw in out.stdout.decode('utf-8', 'replace').split(chr(10)):
        raw = raw.rstrip(chr(13))
        if not raw:
            continue
        if not raw.startswith('  '):
            current = {'rules': set(), 'specs': []}
            files[raw.split('\t')[0]] = current
            continue
        cols = raw[2:].split('\t')
        if cols[0] == 'spec':
            current['specs'].append({
                'index': cols[1], 'routes': cols[2], 'key': cols[3], 'spec': int(cols[4]),
                'f': cols[5], 'uf': cols[6], 'stream': int(cols[7]), 'subtype': cols[8],
                'moddate': cols[9] == '1', 'size': int(cols[10])})
        else:
            current['rules'].add(cols[1])
    return files


def qpdf_attachments(qpdf, pdf):
    out = subprocess.run([qpdf, '--json=2', '--json-key=attachments', pdf], capture_output=True)
    if out.returncode not in (0, 3):
        return None
    try:
        return json.loads(out.stdout.decode('utf-8')).get('attachments', {})
    except ValueError:
        return None


def qpdf_rebuilt(qpdf, pdf):
    out = subprocess.run([qpdf, '--check', pdf], capture_output=True)
    text = (out.stdout + out.stderr).decode('utf-8', 'replace').lower()
    return 'reconstruct' in text


def qpdf_data(qpdf, pdf, key):
    out = subprocess.run([qpdf, '--show-attachment=' + key, pdf], capture_output=True)
    if out.returncode not in (0, 3):
        return None
    return out.stdout


def qpdf_object(qpdf, pdf, ref):
    """The value of the indirect object ref ("26 1 R"; for a stream its
    dictionary), None if qpdf cannot give it."""
    parts = (ref or '').split()
    if len(parts) != 3 or parts[2] != 'R':
        return None
    out = subprocess.run([qpdf, '--json=2', '--json-key=qpdf', '--json-object=%s,%s' % (parts[0], parts[1]), pdf],
                         capture_output=True)
    if out.returncode not in (0, 3):
        return None
    try:
        objects = json.loads(out.stdout.decode('utf-8'))['qpdf'][1]
    except (ValueError, KeyError, IndexError):
        return None
    value = objects.get('obj:' + ref)
    if isinstance(value, dict) and 'stream' in value:
        return value['stream'].get('dict', {})
    if isinstance(value, dict):
        return value.get('value')
    return None


def stream_facts(qpdf, pdf, ref):
    """(subtype, moddate present) from the raw dictionary of stream ref, None
    if qpdf cannot give the dictionary."""
    d = qpdf_object(qpdf, pdf, ref)
    if not isinstance(d, dict):
        return None
    subtype = d.get('/Subtype') or ''
    if isinstance(subtype, str) and subtype.startswith('/'):
        subtype = subtype[1:]
    params = d.get('/Params')
    if isinstance(params, str) and params.endswith(' R'):
        params = qpdf_object(qpdf, pdf, params)
    moddate = (isinstance(params, dict) and isinstance(params.get('/ModDate'), str) and
               params['/ModDate'][:2] in ('u:', 'b:'))
    return subtype, moddate


def ref_num(ref):
    return int(ref.split()[0]) if ref else -1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--toolchain', default='fpc322-win64')
    args = ap.parse_args()
    if not os.path.isfile(os.path.join(CORPUS, 'index.txt')):
        sys.exit('no local PDF corpus in ' + CORPUS)
    qpdf = find_qpdf()
    probe = find_probe(args.toolchain)
    facts_dir = os.path.join(OUT, 'facts')
    shutil.rmtree(facts_dir, ignore_errors=True)
    os.makedirs(facts_dir)
    exceptions = load_exceptions()
    version = subprocess.run([qpdf, '--version'], capture_output=True).stdout.decode().splitlines()[0]
    print(version)

    mutants = os.path.join(OUT, 'mutants')
    make_mutants(mutants)
    ours = run_probe(probe, facts_dir, [CORPUS, mutants])
    diffs = []
    counts = {'pdfs': 0, 'attachments': 0, 'excepted': 0, 'rebuilt': 0}

    used = set()

    def report(name, check, text):
        if excepted(exceptions, used, name, check):
            counts['excepted'] += 1
        else:
            diffs.append(name + '\t' + check + '\t' + text)

    pdfs = [(name, os.path.join(CORPUS, name)) for name in sorted(os.listdir(CORPUS))]
    pdfs += [(name, os.path.join(mutants, name)) for name in sorted(os.listdir(mutants))]
    for name, pdf in pdfs:
        if not name.lower().endswith('.pdf'):
            continue
        counts['pdfs'] += 1
        mine = ours.get(name)
        if mine is None:
            report(name, 'probe', 'no probe output')
            continue
        # a PDF the probe cannot read must not pass as two empty name trees
        if 'LX-PDF-01' in mine['rules']:
            report(name, 'probe', 'the probe cannot read the PDF (LX-PDF-01)')
            continue
        rebuilt = qpdf_rebuilt(qpdf, pdf)
        if rebuilt:
            counts['rebuilt'] += 1
        if pdf.startswith(mutants) and not (rebuilt and 'LX-PDF-02' in mine['rules']):
            report(name, 'mutant', 'not rebuilt: qpdf %s, probe LX-PDF-02 %s' % (rebuilt, 'LX-PDF-02' in mine['rules']))
        if rebuilt != ('LX-PDF-02' in mine['rules']):
            report(name, 'rebuilt', 'qpdf rebuilt: %s, probe LX-PDF-02: %s' % (rebuilt, 'LX-PDF-02' in mine['rules']))
        theirs = qpdf_attachments(qpdf, pdf)
        if theirs is None:
            report(name, 'qpdf', 'qpdf cannot read the PDF')
            continue
        tree = {}
        for spec in mine['specs']:
            if 'tree' in spec['routes'] and spec['key'] not in tree:
                tree[spec['key']] = spec
        if sorted(theirs) != sorted(tree):
            report(name, 'keys', 'qpdf %s, probe %s' % (sorted(theirs), sorted(tree)))
        for key, att in sorted(theirs.items()):
            spec = tree.get(key)
            if spec is None:
                continue
            counts['attachments'] += 1
            names = att.get('names') or {}
            want = (ref_num(att.get('filespec')), names.get('/F', ''), names.get('/UF', ''))
            have = (spec['spec'], spec['f'], spec['uf'])
            if want != have:
                report(name, 'spec', '%s: qpdf %s, probe %s' % (key, want, have))
            facts = stream_facts(qpdf, pdf, att.get('preferredcontents'))
            if facts is None:
                report(name, 'mime', '%s: qpdf cannot give the stream %s' % (key, att.get('preferredcontents')))
                facts = (None, None)
            subtype, moddate = facts
            if subtype is None:
                pass
            elif subtype != spec['subtype']:
                report(name, 'mime', '%s: qpdf %r, probe %r' % (key, subtype, spec['subtype']))
            if moddate is not None and moddate != spec['moddate']:
                report(name, 'moddate', '%s: qpdf %s, probe %s' % (key, moddate, spec['moddate']))
            data = qpdf_data(qpdf, pdf, key)
            bin_file = os.path.join(facts_dir, name + '.' + spec['index'] + '.bin')
            got = None
            if os.path.isfile(bin_file):
                with open(bin_file, 'rb') as f:
                    got = f.read()
            if data is None and got is None:
                report(name, 'data', '%s: neither side can read the content' % key)
            elif data != got:
                report(name, 'data', '%s: qpdf %s bytes, probe %s bytes' % (
                    key, 'no' if data is None else len(data), 'no' if got is None else len(got)))

    for item in exceptions:
        if item not in used:
            diffs.append('%s\t%s\tunused exception' % item)
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'differences.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(diffs) + ('\n' if diffs else ''))
    for line in diffs:
        print('  ' + line)
    print('%d PDFs (%d rebuilt by qpdf), %d attachments compared, %d excepted' % (
        counts['pdfs'], counts['rebuilt'], counts['attachments'], counts['excepted']))
    if diffs:
        print('%d unexpected differences (build/pdf-oracle/differences.txt)' % len(diffs))
        return 1
    print('no unexpected difference')
    return 0


if __name__ == '__main__':
    sys.exit(main())
