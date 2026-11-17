#!/usr/bin/env python3
"""PDF/A oracle: runs veraPDF on the veraPDF test corpus and the invoice PDFs
and keeps the expected PDF/A-3b results for the native PDF/A check (level 1
of the PDF checker; not built yet).

Two runs:
- The corpus check: every corpus file under the profile it was made for
  (PDF_A-2b: 2b, PDF_A-2u: 2u, PDF_A-3b: 3b, TWG files: by "pdfa2"/"pdfa3" in
  the name, 2b or 3b). A "pass" file must be compliant; a "fail" file must not
  be, and for a veraPDF test suite file one of the failed rules must belong to
  the clause in its name ("6-2-4-3" = clause 6.2.4.3, a clause below it or
  above it). TWG names carry no clause: their fail files must only be
  rejected. This checks the corpus against the oracle, not our code.
- The target run: every corpus file and every invoice PDF of
  tests/data/local/pdf under the PDF/A-3b profile, the target of the native
  check. Its result is tests/data/verapdf-expected.txt, one line per file
  (sorted, tab-separated): path relative to tests/data/local, the first 16
  hex digits of the file's SHA-256, the run status ("normal"), the verdict
  (compliant or noncompliant) and the failed rules as "clause-testNumber"
  separated by spaces (rules of another specification than the profile's
  get "specification:" in front).
A run that did not end normally is never a pass: in either run it is a
problem, and --update refuses to write it. Without --update the target run
is compared with the file line by line, headers included (a difference means
a new veraPDF, changed material or a changed profile); without the invoice
PDFs only the corpus lines are compared, and --update needs them.

The corpus must match the committed tools/testdata/corpora.json (corpus
verapdf, every file with its SHA-256). Known corpus disagreements are listed
in tools/pdfcheck/verapdf-exceptions.txt (path relative to
tests/data/local/verapdf, a reason); an exception only excuses a fail file
that veraPDF rejects under another clause, and an unused line is an error.

Needs addons/java-tools/install-tools.ps1 (veraPDF 1.30.4, Java runtime) and
tools/testdata/sync-local.py (corpus verapdf).

Usage:
  python tools/pdfcheck/verapdf-oracle.py [--java <java>] [--jobs 4] [--keep] [--update]
Raw reports in build/verapdf-oracle/, named after the veraPDF version, the
profile and the files with their SHA-256, so --keep reuses a report only for
the same input. Exit code 0 = no unexpected difference.
"""

import argparse
import concurrent.futures
import glob
import hashlib
import json
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
LOCAL = os.path.join(REPO, "tests", "data", "local")
CORPUS = os.path.join(LOCAL, "verapdf")
INVOICES = os.path.join(LOCAL, "pdf")
CORPORA = os.path.join(REPO, "tools", "testdata", "corpora.json")
EXPECTED = os.path.join(REPO, "tests", "data", "verapdf-expected.txt")
EXCEPTIONS = os.path.join(HERE, "verapdf-exceptions.txt")
WORK = os.path.join(REPO, "build", "verapdf-oracle")
VERSION = "1.30.4"
TARGET = "3b"
TARGET_SPEC = "ISO 19005-3:2012"
FOLDER_FLAVOUR = {"PDF_A-2b": "2b", "PDF_A-2u": "2u", "PDF_A-3b": "3b"}
# a batch that takes longer has hung (100 files take well under a minute)
TIMEOUT = 1800


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


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def corpus_files():
    """{path relative to tests/data/local: intended flavour} of the corpus,
    complete and unchanged against corpora.json."""
    with open(CORPORA, encoding="utf-8") as f:
        pinned = json.load(f)["verapdf"]["files"]
    out = {}
    for name, digest in sorted(pinned.items()):
        if not name.lower().endswith(".pdf"):
            continue
        path = os.path.join(CORPUS, name)
        if not os.path.isfile(path) or sha256(path) != digest:
            sys.exit("corpus missing or changed: %s (run tools/testdata/sync-local.py)" % name)
        top = name.split("/")[0]
        if top in FOLDER_FLAVOUR:
            flavour = FOLDER_FLAVOUR[top]
        elif "-pdfa3-" in name:
            flavour = "3b"
        elif "-pdfa2-" in name:
            flavour = "2b"
        else:
            sys.exit("no flavour for %s" % name)
        out["verapdf/" + name] = flavour
    return out


def batches(files, limit=16000, count=100):
    """Groups of at most count files whose command line stays below the
    Windows limit (32767 characters, paths absolute)."""
    batch, size = [], 0
    for f in files:
        if batch and (size + len(f) + len(LOCAL) + 4 > limit or len(batch) >= count):
            yield batch
            batch, size = [], 0
        batch.append(f)
        size += len(f) + len(LOCAL) + 4
    if batch:
        yield batch


def run(java, files, flavour, label, jobs, keep, hashes):
    """veraPDF on files (paths relative to tests/data/local) with a flavour;
    returns {relative path: (status, verdict, [(specification, clause,
    testNumber)])}."""
    jar = os.path.join(TOOLS, "verapdf", "bin", "cli-%s.jar" % VERSION)
    if not os.path.isfile(jar):
        sys.exit("veraPDF %s missing: run addons/java-tools/install-tools.ps1" % VERSION)
    by_abs = dict((os.path.normcase(os.path.abspath(os.path.join(LOCAL, f))), f) for f in files)
    # veraPDF's own --processes needs its start script; run several JVMs instead
    work = []
    for batch in batches(sorted(files)):
        key = hashlib.sha256(("%s\0%s\0" % (VERSION, flavour) + "".join(
            "%s\0%s\0" % (f, hashes[f]) for f in batch)).encode("utf-8")).hexdigest()[:16]
        work.append((os.path.join(WORK, "%s-%s.xml" % (label, key)), batch))

    def one(item):
        report, batch = item
        if keep and os.path.isfile(report):
            return None
        try:
            with open(report + ".tmp", "wb") as out:
                res = subprocess.run([java, "-jar", jar, "--format", "xml", "-f", flavour,
                                      "--maxfailuresdisplayed", "1"] + [os.path.join(LOCAL, f) for f in batch],
                                     stdout=out, stderr=subprocess.PIPE, timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            return "veraPDF did not finish within %d s: %s" % (TIMEOUT, batch[0])
        # veraPDF exits 1 when a file is not compliant; the report decides
        if res.returncode not in (0, 1):
            return "veraPDF failed (exit %d): %s" % (res.returncode, res.stderr.decode("utf-8", "replace")[-2000:])
        os.replace(report + ".tmp", report)
        return None

    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        for error in pool.map(one, work):
            if error:
                sys.exit(error)
    results = {}
    for report, _ in work:
        for job in ET.parse(report).getroot().iter("job"):
            name = job.findtext("item/name")
            key = by_abs.get(os.path.normcase(os.path.abspath(name or "")))
            if key is None:
                sys.exit("%s: unknown file in the report: %s" % (report, name))
            if key in results:
                sys.exit("%s: file reported twice: %s" % (report, name))
            vr = job.find("validationReport")
            if vr is None:
                status = (job.findtext("taskException/exceptionMessage") or "no validation report").strip()
                results[key] = ("error: " + " ".join(status.split())[:200], "error", [])
                continue
            status = vr.get("jobEndStatus", "")
            rules = sorted(set((r.get("specification"), r.get("clause"), r.get("testNumber"))
                               for r in vr.iter("rule") if r.get("status") == "failed"))
            if status != "normal":
                verdict = "error"
            else:
                verdict = "compliant" if vr.get("isCompliant") == "true" else "noncompliant"
            results[key] = (status, verdict, rules)
    missing = sorted(set(files) - set(results))
    if missing:
        sys.exit("no result for %d file(s), e.g. %s" % (len(missing), missing[0]))
    return results


def load_exceptions():
    out = {}
    if os.path.isfile(EXCEPTIONS):
        for line in open(EXCEPTIONS, encoding="utf-8"):
            line = line.rstrip("\r\n")
            if line and not line.startswith("#"):
                path, _, reason = line.partition("\t")
                if not reason.strip():
                    sys.exit("%s: no reason for %s" % (EXCEPTIONS, path))
                if path in out:
                    sys.exit("%s: listed twice: %s" % (EXCEPTIONS, path))
                out[path] = False
    return out


def file_clause(path):
    m = re.search(r"veraPDF test suite (\d+(?:-\d+)*)-t\d+-(pass|fail)-", path)
    return m.group(1).replace("-", ".") if m else None


def rule_list(rules):
    return " ".join("%s-%s" % (c, t) for _, c, t in rules)


def corpus_check(results, flavours):
    exceptions = load_exceptions()
    problems = []
    for path in sorted(results):
        status, verdict, rules = results[path]
        rel = path[len("verapdf/"):]
        m = re.search(r"-(pass|fail)-[a-z]+\.pdf$", rel)
        if not m:
            problems.append("%s: pass or fail not in the name" % rel)
            continue
        excusable = False
        if verdict == "error":
            finding = "veraPDF did not finish: %s" % status
        elif m.group(1) == "pass":
            finding = None if verdict == "compliant" else "pass file not compliant (%s)" % rule_list(rules)
        elif verdict == "compliant":
            finding = "fail file compliant"
        else:
            clause = file_clause(rel)
            hit = clause is None or any(c == clause or c.startswith(clause + ".") or clause.startswith(c + ".")
                                        for _, c, _ in rules)
            finding = None if hit else "fail file without a failed rule of clause %s (%s)" % (clause, rule_list(rules))
            # the only finding an exception may excuse: rejected, but under another clause
            excusable = not hit
        if rel in exceptions:
            exceptions[rel] = True
            if finding is None:
                problems.append("%s: exception no longer needed" % rel)
            elif not excusable:
                problems.append("%s [%s]: %s (an exception only excuses another clause)" % (rel, flavours[path],
                                                                                           finding))
        elif finding:
            problems.append("%s [%s]: %s" % (rel, flavours[path], finding))
    problems += ["unused exception: %s" % p for p, used in sorted(exceptions.items()) if not used]
    return problems


def rule_text(rules):
    out = []
    for spec, clause, test in rules:
        key = "%s-%s" % (clause, test)
        out.append(key if spec == TARGET_SPEC else "%s:%s" % (spec, key))
    return " ".join(out)


HEADER = ["# veraPDF %s, profile PDF/A-%s; written by tools/pdfcheck/verapdf-oracle.py --update" % (VERSION, TARGET),
          "# path\tsha256[:16]\tstatus\tverdict\tfailed rules (clause-testNumber)"]


def expected_lines(results, hashes):
    return HEADER + ["\t".join((path, hashes[path][:16], status, verdict, rule_text(rules)))
                     for path, (status, verdict, rules) in sorted(results.items())]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--java")
    ap.add_argument("--jobs", type=int, default=4, help="veraPDF processes")
    ap.add_argument("--keep", action="store_true", help="reuse the reports in build/verapdf-oracle")
    ap.add_argument("--update", action="store_true", help="rewrite tests/data/verapdf-expected.txt")
    args = ap.parse_args()
    java = find_java(args.java)
    flavours = corpus_files()
    invoices = ["pdf/" + os.path.basename(f) for f in sorted(glob.glob(os.path.join(INVOICES, "*.pdf")))]
    if not invoices:
        if args.update:
            sys.exit("no invoice PDFs in tests/data/local/pdf: --update needs them")
        print("no invoice PDFs in tests/data/local/pdf; only the corpus lines are compared")
    hashes = dict((f, sha256(os.path.join(LOCAL, f))) for f in list(flavours) + invoices)
    if not args.keep and os.path.isdir(WORK):
        shutil.rmtree(WORK)
    os.makedirs(WORK, exist_ok=True)

    intended = {}
    for flavour in sorted(set(flavours.values())):
        files = [f for f, fl in flavours.items() if fl == flavour]
        intended.update(run(java, files, flavour, "corpus-" + flavour, args.jobs, args.keep, hashes))
    problems = corpus_check(intended, flavours)
    print("corpus check: %d files under their own profile, %d problem(s)" % (len(intended), len(problems)))

    target = run(java, sorted(flavours) + invoices, TARGET, "target-" + TARGET, args.jobs, args.keep, hashes)
    counts = {}
    for path, (status, verdict, _) in sorted(target.items()):
        counts[verdict] = counts.get(verdict, 0) + 1
        if verdict == "error":
            problems.append("%s: veraPDF did not finish under PDF/A-%s: %s" % (path, TARGET, status))
    print("target run (PDF/A-%s): %d files, %s" % (TARGET, len(target), ", ".join(
        "%s %d" % kv for kv in sorted(counts.items()))))
    lines = expected_lines(target, hashes)
    if args.update:
        if problems:
            print("not updated: see the problems")
        else:
            with open(EXPECTED, "w", encoding="utf-8", newline="\n") as f:
                f.write("\n".join(lines) + "\n")
            print("written: %s" % os.path.relpath(EXPECTED, REPO))
    elif not os.path.isfile(EXPECTED):
        problems.append("missing %s: run with --update" % os.path.relpath(EXPECTED, REPO))
    else:
        with open(EXPECTED, encoding="utf-8") as f:
            old = [l.rstrip("\n") for l in f]
        if not invoices:
            old = [l for l in old if not l.startswith("pdf/")]
        if old != lines:
            problems.append("%s differs from this run" % os.path.relpath(EXPECTED, REPO))
            for i, (a, b) in enumerate(zip(old[:len(HEADER)], HEADER)):
                if a != b:
                    problems.append("header line %d: %s" % (i + 1, a))
            old_set, new_set = set(old[len(HEADER):]), set(lines[len(HEADER):])
            for l in sorted(old_set - new_set)[:20]:
                problems.append("expected only: " + l)
            for l in sorted(new_set - old_set)[:20]:
                problems.append("now only:      " + l)
            if len(old) != len(set(old)):
                problems.append("lines repeated in the expected file")
            if old[len(HEADER):] != sorted(old[len(HEADER):]):
                problems.append("expected file not sorted")
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
