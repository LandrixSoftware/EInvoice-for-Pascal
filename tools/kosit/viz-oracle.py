#!/usr/bin/env python3
"""Oracle for LandrixEInvoiceKositVisualization: runs the KoSIT XRechnung
visualization on a set of invoices twice, with the XSLT engine of LandrixXML
(XsltProbe visualize) and with Saxon (the one inside the KoSIT validator),
and compares the results byte for byte: the XR form (cii-xr.xsl,
ubl-invoice-xr.xsl, ubl-creditnote-xr.xsl) and the HTML page
(xrechnung-html.xsl), in German and English.

Default corpus: the test instances of the visualization release
(addons/java-tools/xrechnung-visualization/test/instances) and the KoSIT
XRechnung test suite (tests/data/local/kosit/instances); folders given on the
command line replace it (every *.xml with the root CrossIndustryInvoice,
Invoice or CreditNote; other files are skipped). A document both engines
refuse (an error raised by the stylesheet, such as two VAT rates in a sub
line) counts as agreement and is listed with both messages; a document only
one engine refuses, or one the probe reports nothing for, is a problem.
Both engines use the same xsl/ folder: that of addons/kosit (module
visualization of install-kosit.ps1) if it is installed, else that of
addons/java-tools.

Needs the probe (./tools/build.ps1 fpc322-win64 -Program tools/kosit/XsltProbe.dpr
-NoRun), addons/java-tools/install-tools.ps1 (validator, xrechnung-visualization,
Java runtime) and, for the default corpus, tools/testdata/sync-local.py.

Usage:
  python tools/kosit/viz-oracle.py [--probe <exe>] [--java <java>] [--xsl <folder>] [<folder>...]
Output in build/viz-oracle/. Exit code 0 = every result identical.
"""

import argparse
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
WORK = os.path.join(REPO, "build", "viz-oracle")
DEFAULT_CORPUS = [os.path.join(TOOLS, "xrechnung-visualization", "test", "instances"),
                  os.path.join(REPO, "tests", "data", "local", "kosit", "instances")]
STYLESHEETS = {"CrossIndustryInvoice": "cii-xr.xsl", "Invoice": "ubl-invoice-xr.xsl",
               "CreditNote": "ubl-creditnote-xr.xsl"}


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


def default_xsl():
    for c in (os.path.join(REPO, "addons", "kosit", "xrechnung-visualization", "xsl"),
              os.path.join(TOOLS, "xrechnung-visualization", "xsl")):
        if os.path.isfile(os.path.join(c, "xrechnung-html.xsl")):
            return c
    sys.exit("no visualization: run addons/kosit/install-kosit.ps1 or addons/java-tools/install-tools.ps1")


def root_name(path):
    try:
        for _, elem in ET.iterparse(path, events=("start",)):
            return elem.tag.split("}")[-1]
    except ET.ParseError:
        return None


def saxon(java, jar, src, xsl, dst, params=()):
    """Runs Saxon on a folder; returns {name without extension: message} of
    the files it failed on (it goes on with the others)."""
    res = subprocess.run([java, "-cp", jar, "net.sf.saxon.Transform", "-s:" + src, "-xsl:" + xsl,
                          "-o:" + dst] + list(params), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    text = res.stdout.decode("utf-8", "replace")
    failed = dict((os.path.splitext(m.group(1))[0], m.group(2).strip())
                  for m in re.finditer(r"^While processing (.+?\.xml): (.*)$", text, re.M))
    if res.returncode != 0 and not failed:
        sys.exit("Saxon failed (%s):\n%s" % (os.path.basename(xsl), text[-3000:]))
    return failed


def batches(files, limit=16000):
    """The files in groups whose command line stays below the Windows limit
    (32767 characters)."""
    batch, size = [], 0
    for f in files:
        if batch and size + len(f) + 3 > limit:
            yield batch
            batch, size = [], 0
        batch.append(f)
        size += len(f) + 3
    if batch:
        yield batch


def first_difference(a, b):
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i
    return n


def compare(expected, actual, label, problems):
    if not os.path.isfile(expected):
        problems.append("%s: Saxon wrote no %s" % (label, os.path.basename(expected)))
        return False
    if not os.path.isfile(actual):
        problems.append("%s: the probe wrote no %s" % (label, os.path.basename(actual)))
        return False
    a = open(expected, "rb").read()
    b = open(actual, "rb").read()
    if a == b:
        return True
    i = first_difference(a, b)
    problems.append("%s: differs at byte %d: Saxon %r, probe %r" % (label, i, a[max(0, i - 20):i + 40],
                                                                  b[max(0, i - 20):i + 40]))
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--probe", default=os.path.join(REPO, "build", "fpc322-win64",
                                                     "XsltProbe" + (".exe" if os.name == "nt" else "")))
    ap.add_argument("--java")
    ap.add_argument("--xsl", help="the xsl/ folder of the visualization")
    ap.add_argument("folders", nargs="*", help="folders with invoices (default: see above)")
    args = ap.parse_args()
    if not os.path.isfile(args.probe):
        sys.exit("missing probe %s: ./tools/build.ps1 fpc322-win64 -Program tools/kosit/XsltProbe.dpr -NoRun"
                 % args.probe)
    jar = glob.glob(os.path.join(TOOLS, "validator", "validator-*-standalone.jar"))
    if not jar:
        sys.exit("KoSIT validator missing: run addons/java-tools/install-tools.ps1")
    java = find_java(args.java)
    xsl = args.xsl or default_xsl()
    folders = args.folders or DEFAULT_CORPUS
    for d in folders:
        if not os.path.isdir(d):
            sys.exit("missing folder %s (default corpus: install-tools.ps1 and sync-local.py)" % d)

    groups = {}
    names = {}
    seen = {}
    for d in folders:
        for f in sorted(glob.glob(os.path.join(d, "*.xml"))):
            root = root_name(f)
            if root not in STYLESHEETS:
                continue
            name = os.path.splitext(os.path.basename(f))[0]
            # the outputs of all folders share one folder, which may ignore case
            if name.lower() in seen:
                sys.exit("file name twice: %s and %s" % (seen[name.lower()], f))
            seen[name.lower()] = f
            names[name] = f
            groups.setdefault(STYLESHEETS[root], []).append(f)
    if not names:
        sys.exit("no invoices found")

    if os.path.isdir(WORK):
        shutil.rmtree(WORK)
    xr = os.path.join(WORK, "saxon-xr")
    os.makedirs(xr)
    xr_failed = {}
    for i, (sheet, members) in enumerate(sorted(groups.items())):
        src = os.path.join(WORK, "in%d" % i)
        os.makedirs(src)
        for f in members:
            shutil.copyfile(f, os.path.join(src, os.path.basename(f)))
        xr_failed.update(saxon(java, jar[0], src, os.path.join(xsl, sheet), xr))
    files = dict((os.path.basename(names[n]), n) for n in names)

    problems = []
    for lang in ("de", "en"):
        html = os.path.join(WORK, "saxon-html-" + lang)
        os.makedirs(html)
        html_failed = saxon(java, jar[0], xr, os.path.join(xsl, "xrechnung-html.xsl"), html, ["lang=" + lang])
        out = os.path.join(WORK, "probe-" + lang)
        os.makedirs(out)
        lines = []
        for batch in batches([names[n] for n in sorted(names)]):
            res = subprocess.run([args.probe, "visualize", xsl, out] + (["-en"] if lang == "en" else []) + batch,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            lines += res.stdout.decode("utf-8", "replace").splitlines()
            # 1 = some file failed, reported in its line; anything else is a crash
            if res.returncode not in (0, 1):
                problems.append("%s: probe exit code %d" % (lang, res.returncode))
        probe_ok = set()
        probe_error = {}
        for line in lines:
            if not line.strip():
                continue
            word, _, rest = line.partition(" ")
            # the file name may contain spaces: take the known name it starts with
            hit = [f for f in files if rest == f or rest.startswith(f + " ")]
            if word in ("ok", "error") and hit:
                f = max(hit, key=len)
                if word == "ok":
                    probe_ok.add(files[f])
                else:
                    probe_error[files[f]] = rest[len(f):].strip()
            else:
                problems.append("%s: probe: %s" % (lang, line))
        same_xr = same_html = 0
        both_failed = []
        for n in sorted(names):
            label = "%s %s" % (lang, n)
            saxon_fails = n in xr_failed or n in html_failed
            if saxon_fails:
                if n in probe_error:
                    both_failed.append("%s: Saxon: %s | probe: %s"
                                       % (label, xr_failed.get(n) or html_failed.get(n), probe_error[n]))
                elif n in probe_ok:
                    problems.append("%s: Saxon fails (%s), the probe does not"
                                    % (label, "XR" if n in xr_failed else "HTML"))
                else:
                    problems.append("%s: Saxon fails, the probe reported nothing" % label)
                if n in xr_failed:
                    continue
            elif n not in probe_ok:
                problems.append("%s: the probe fails, Saxon does not: %s"
                                % (label, probe_error.get(n, "no output")))
                continue
            same_xr += compare(os.path.join(xr, n + ".xml"), os.path.join(out, n + ".xr.xml"),
                               label + " XR", problems)
            if not saxon_fails:
                same_html += compare(os.path.join(html, n + ".html"), os.path.join(out, n + ".html"),
                                     label + " HTML", problems)
        print("%s: %d invoices, XR identical %d, HTML identical %d, both engines fail %d"
              % (lang, len(names), same_xr, same_html, len(both_failed)))
        for line in both_failed:
            print("  " + line)
    for p in problems:
        print(p)
    print("%d problem(s); xsl %s" % (len(problems), xsl))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
