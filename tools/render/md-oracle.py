#!/usr/bin/env python3
"""Oracle for the Markdown rendering: commonmark.js against
tools/render/MarkdownProbe.dpr.

The probe writes the Markdown of every case (the filled invoice with one and
two items per list, the golden and the hostile invoices of the tests, the
latter with a hostile document name, every readable local corpus file;
English, and German with business terms) and the lines the walk calls for
(kind, nesting depth, section, label, value; see TEvent in
tests/LandrixEInvoiceTestRenderMarkdown.pas). commonmark.js 0.31.2, the
CommonMark reference implementation (addons/java-tools/commonmark, pinned by
install-tools.ps1), parses each text with Node.js (tools/render/md-walk.js).
Checked per case:

  nodes   the parsed text holds only headings, lists, items, paragraphs,
          strong and plain text, code blocks and the closing rule: no HTML,
          no link, no image, no emphasis or inline code (escaping holds)
  lines   the title, the level 3 headings, the bold lines, the list lines
          and bare item bullets, and the labelled items give, in order and
          including the document section, the same kind, nesting depth,
          section, label and value as the walk (sanitized like the writer
          does, line breaks as LF). White space at the start and end of a
          one-line value or heading, and lines of only white space in a
          longer value, are ignored: the text keeps them, but CommonMark does
          not show them (commonmark.js also drops a no-break space there)

Exceptions in tools/render/md-exceptions.txt ("case<TAB>check<TAB>reason";
case may be *); an exception no difference uses fails the run. Output in
build/md-oracle/. Build the probe first:
./tools/build.ps1 fpc322-win64 -Program tools/render/MarkdownProbe.dpr -NoRun
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'build', 'md-oracle')
COMMONMARK = os.path.join(ROOT, 'addons', 'java-tools', 'commonmark', 'commonmark.js')
WALK = os.path.join(ROOT, 'tools', 'render', 'md-walk.js')
EXCEPTIONS = os.path.join(ROOT, 'tools', 'render', 'md-exceptions.txt')
TSV_ESCAPES = {'\\': '\\', 't': '\t', 'n': '\n', 'r': '\r'}


def unescape_tsv(s):
    out = []
    i = 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s):
            out.append(TSV_ESCAPES[s[i + 1]])
            i += 2
        else:
            out.append(s[i])
            i += 1
    return ''.join(out)


def sanitize(s):
    """As LandrixEInvoiceReportSanitize: characters XML 1.0 does not allow
    become U+FFFD; then CR LF and CR become LF."""
    out = []
    for ch in s:
        c = ord(ch)
        if c in (9, 10, 13) or 0x20 <= c <= 0xD7FF or 0xE000 <= c <= 0xFFFD or c >= 0x10000:
            out.append(ch)
        else:
            out.append('�')
    return ''.join(out).replace('\r\n', '\n').replace('\r', '\n')


def visible(v):
    """v as rendered CommonMark shows it: a one-line text without
    surrounding white space, a longer one with its lines of only white space
    empty."""
    if '\n' not in v:
        return v.strip()
    return '\n'.join(line if line.strip() else '' for line in v.split('\n'))


def load_exceptions():
    result = {}
    if not os.path.isfile(EXCEPTIONS):
        return result
    with open(EXCEPTIONS, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 3 or not parts[2].strip():
                sys.exit('md-exceptions.txt: a reason is required: ' + line)
            result[(parts[0], parts[1])] = False
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--toolchain', default='fpc322-win64')
    args = ap.parse_args()

    exe = os.path.join(ROOT, 'build', args.toolchain, 'MarkdownProbe' + ('.exe' if os.name == 'nt' else ''))
    if not os.path.isfile(exe):
        sys.exit('probe missing: ' + exe)
    if not os.path.isfile(COMMONMARK):
        sys.exit('commonmark.js missing: run addons/java-tools/install-tools.ps1')
    node = shutil.which('node')
    if not node:
        sys.exit('node not found on the PATH')

    cases = os.path.join(OUT, 'cases')
    if os.path.isdir(cases):
        shutil.rmtree(cases)
    subprocess.run([exe, ROOT, cases], check=True)

    names = {}
    with open(os.path.join(cases, 'index.txt'), encoding='utf-8') as f:
        for line in f:
            no, name = line.rstrip('\n').split('\t', 1)
            names[no] = name
    listing = os.path.join(OUT, 'list.txt')
    with open(listing, 'w', encoding='utf-8', newline='\n') as f:
        for no in names:
            f.write(os.path.join(cases, no + '.md') + '\n')
    run = subprocess.run([node, WALK, COMMONMARK, listing], check=True, capture_output=True)

    exceptions = load_exceptions()
    findings = []

    def finding(name, check, text):
        for key in ((name, check), ('*', check)):
            if key in exceptions:
                exceptions[key] = True
                return
        findings.append(name + '\t' + check + '\t' + text)

    # split on LF only: a value may hold U+0085, U+2028 or U+2029, which
    # JSON.stringify writes raw and str.splitlines would split on
    for line in run.stdout.decode('utf-8').split('\n'):
        if not line:
            continue
        r = json.loads(line)
        no = os.path.splitext(os.path.basename(r['file']))[0]
        name = names[no]
        if r['nodes']:
            finding(name, 'nodes', ', '.join(r['nodes']))
        expected = []
        with open(os.path.join(cases, no + '.tsv'), encoding='utf-8', newline='') as f:
            for row in f.read().split('\n'):
                if row:
                    kind, depth, section, label, value = [unescape_tsv(x) for x in row.split('\t')]
                    expected.append([kind, int(depth), section, visible(sanitize(label)), visible(sanitize(value))])
        actual = [[a[0], a[1], a[2], visible(a[3]), visible(a[4])] for a in r['lines']]
        for i in range(max(len(expected), len(actual))):
            e = expected[i] if i < len(expected) else None
            a = actual[i] if i < len(actual) else None
            if e != a:
                finding(name, 'lines', 'line %d: expected %r, parsed %r' % (i + 1, e, a))
                break

    for key, used in exceptions.items():
        if not used:
            findings.append('\t'.join(key) + '\tunused exception')
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'findings.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(''.join(x + '\n' for x in findings))
    print('%d cases, %d finding(s); %s' % (len(names), len(findings), os.path.join(OUT, 'findings.txt')))
    for x in findings[:20]:
        print('  ' + x)
    return 1 if findings else 0


if __name__ == '__main__':
    sys.exit(main())
