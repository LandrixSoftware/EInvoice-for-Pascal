#!/usr/bin/env python3
"""Builds the source ZIP of a release with the LandrixXML submodule, for the
release page (GitHub's own source archives do not contain submodules).

The ZIP holds `git archive` of the tag and of the submodule commit that tag
names, under one root folder EInvoice-for-Pascal-<version>/ (the submodule in
external/landrix-xml/). `git archive` applies the .gitattributes of the tag
in each repository (CRLF for Pascal sources, export-ignore); core.autocrlf,
core.eol and tar.umask are fixed and global and system attributes switched
off, so files without a line-ending rule keep the bytes they are stored with
and the local Git configuration does not matter. A non-empty
info/attributes in either repository stops the script (Git always reads
it). Every entry carries the commit
time of the tag, so the same tag gives the same entries: names, bytes, times
and modes. The compressed bytes, and so the SHA-256 of the ZIP, also depend
on Python's zlib build (zlib-ng on Windows differs from zlib); the content
digest printed as well does not (SHA-256 over name, mode, time, length and
data of every entry).

Usage:
  python tools/make-release-zip.py <tag> [--out <zip>]
The default output is build/release/EInvoice-for-Pascal-<version>.zip, <version>
the tag without a leading 'v'. Prints the file count, the SHA-256 of the ZIP
and the content digest.
"""

import argparse
import hashlib
import io
import os
import subprocess
import sys
import tarfile
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SUBMODULE = "external/landrix-xml"


# fixed so the ZIP does not depend on the local configuration: line endings
# only from the tag's .gitattributes (files without a rule as stored), no
# global or system attributes, modes 644/755
# core.bigFileThreshold: above it git archive skips the eol conversion of .gitattributes
PINNED = ["-c", "core.autocrlf=false", "-c", "core.eol=lf", "-c", "tar.umask=0022",
          "-c", "core.attributesFile=" + os.devnull, "-c", "core.bigFileThreshold=2047m"]
ENV = dict((k, v) for k, v in os.environ.items()
           if k not in ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_ATTR_SOURCE"))
ENV["GIT_ATTR_NOSYSTEM"] = "1"


def git(cwd, *args):
    res = subprocess.run(["git"] + PINNED + list(args), cwd=cwd, env=ENV, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE)
    if res.returncode != 0:
        sys.exit("git %s failed: %s" % (" ".join(args), res.stderr.decode("utf-8", "replace").strip()))
    return res.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("tag", help="the release tag, e.g. v0.9.0-beta.1")
    ap.add_argument("--out", help="the ZIP file to write")
    args = ap.parse_args()

    commit = git(REPO, "rev-parse", "--verify", "%s^{commit}" % args.tag).decode().strip()
    version = args.tag[1:] if args.tag.startswith("v") else args.tag
    root = "EInvoice-for-Pascal-%s/" % version
    out = args.out or os.path.join(REPO, "build", "release", "EInvoice-for-Pascal-%s.zip" % version)

    # the submodule commit the tag records (a gitlink entry), not the checked-out one
    entry = git(REPO, "ls-tree", commit, SUBMODULE).decode().split()
    if len(entry) < 3 or entry[1] != "commit":
        sys.exit("%s is not a submodule in %s" % (SUBMODULE, args.tag))
    sub_commit = entry[2]
    sub_dir = os.path.join(REPO, SUBMODULE)
    if not os.path.exists(os.path.join(sub_dir, ".git")):
        sys.exit("submodule missing: git submodule update --init")
    if subprocess.run(["git", "cat-file", "-e", sub_commit + "^{commit}"], cwd=sub_dir, env=ENV).returncode != 0:
        sys.exit("submodule commit %s not present: git -C %s fetch" % (sub_commit, SUBMODULE))
    if any(line.split()[1:2] == ["commit"] for line in git(sub_dir, "ls-tree", "-r", sub_commit).decode().splitlines()):
        sys.exit("the submodule has submodules of its own; this script does not include them")

    # the one attribute source Git cannot switch off
    for d in (REPO, sub_dir):
        path = git(d, "rev-parse", "--git-path", "info/attributes").decode().strip()
        path = path if os.path.isabs(path) else os.path.join(d, path)
        if os.path.isfile(path) and open(path, "rb").read().strip():
            sys.exit("%s is not empty; it would change the archive" % path)

    stamp = int(git(REPO, "log", "-1", "--format=%ct", commit).decode().strip())
    date_time = time.gmtime(stamp)[:6]

    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    names = set()
    content = hashlib.sha256()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for cwd, ref, prefix in ((REPO, commit, root), (sub_dir, sub_commit, root + SUBMODULE + "/")):
            data = git(cwd, "archive", "--format=tar", "--prefix=" + prefix, ref)
            with tarfile.open(fileobj=io.BytesIO(data)) as t:
                for m in t.getmembers():
                    if m.isdir() or m.type == tarfile.XGLTYPE:
                        continue
                    if not m.isfile():
                        sys.exit("not a regular file (symbolic link?): " + m.name)
                    if m.name in names:
                        sys.exit("path twice: " + m.name)
                    names.add(m.name)
                    info = zipfile.ZipInfo(m.name, date_time=date_time)
                    info.compress_type = zipfile.ZIP_DEFLATED
                    info.external_attr = (0o100000 | (m.mode & 0o777)) << 16
                    info.create_system = 3
                    data = t.extractfile(m).read()
                    z.writestr(info, data, compresslevel=9)
                    content.update(("%s\0%o\0%s\0%d\0" % (m.name, info.external_attr >> 16, date_time,
                                                         len(data))).encode("utf-8"))
                    content.update(data)
    with open(out, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    print("%s: %d files (submodule %s)\n  SHA-256 %s\n  content %s"
          % (out, len(names), sub_commit[:7], digest, content.hexdigest()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
