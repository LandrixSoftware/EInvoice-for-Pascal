#!/usr/bin/env python3
"""Reports upstream releases that are newer than the versions this repository
pins (rule sets, validator configurations, oracle tools, LandrixXML).

The script changes nothing. It reads each pin from the file that holds it,
asks GitHub for the newest release through the `gh` CLI (which must be
installed and logged in) and compares the two. Sources without an API (FeRD,
the EU registry of EN 16931 artefacts, BMF) are listed as reminders only.

Pins read:
  addons/kosit/kosit.json       KoSIT configurations, visualization, Peppol commit
  addons/java-tools/tools.json  validator, Mustang, veraPDF, qpdf, JRE, commonmark
  external/landrix-xml/tests/data/schematron/NOTICE.md
                                CEN EN 16931 artefacts, XRechnung Schematron
  tools/codelists/manifest.json Unicode CLDR (names.cldr_version)
  external/landrix-xml          tag of the submodule commit this repository
                                records (not the local checkout)

Usage:
  python tools/upstream-check.py [--only name[,name...]]

Exit code: 0 all pins current, 1 a newer release exists or two files pin
different versions of the same download, 2 a pin or a release could not be
read.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KOSIT_JSON = os.path.join(ROOT, "addons", "kosit", "kosit.json")
TOOLS_JSON = os.path.join(ROOT, "addons", "java-tools", "tools.json")
CODELISTS_JSON = os.path.join(ROOT, "tools", "codelists", "manifest.json")
SUBMODULE = os.path.join(ROOT, "external", "landrix-xml")
NOTICE = os.path.join(SUBMODULE, "tests", "data", "schematron", "NOTICE.md")

# Sources without a release API: printed as reminders.
MANUAL = [
    ("FeRD ZUGFeRD / Factur-X", "https://www.ferd-net.de/download-zugferd"),
    ("EU registry of EN 16931 artefacts (code lists)",
     "https://ec.europa.eu/digital-building-blocks/sites/display/DIGITAL/"
     "Registry+of+supporting+artefacts+to+implement+EN16931"),
    ("BMF letters on e-invoicing", "https://www.bundesfinanzministerium.de"),
]


class CheckError(Exception):
    pass


class Mismatch(Exception):
    pass


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def read_text(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def search(pattern, text, what):
    m = re.search(pattern, text)
    if not m:
        raise CheckError("pin not found: %s" % what)
    return m.group(1)


def version_key(text):
    """Numbers of a version or tag, compared as a tuple
    (v2026-08-31 -> (2026, 8, 31))."""
    nums = re.findall(r"\d+", text)
    if not nums:
        raise CheckError("no version number in %r" % text)
    return tuple(int(n) for n in nums)


def gh(path):
    try:
        out = subprocess.run(["gh", "api", path], capture_output=True,
                             text=True, encoding="utf-8", timeout=60)
    except subprocess.TimeoutExpired:
        raise CheckError("gh api %s: timeout" % path)
    if out.returncode != 0:
        raise CheckError("gh api %s: %s" % (path, out.stderr.strip()))
    try:
        return json.loads(out.stdout)
    except ValueError as e:
        raise CheckError("gh api %s: no JSON (%s)" % (path, e))


def field(obj, key, what):
    if not isinstance(obj, dict) or key not in obj:
        raise CheckError("%s: no %s in the answer" % (what, key))
    return obj[key]


def git(*args):
    out = subprocess.run(["git"] + list(args), capture_output=True, text=True)
    if out.returncode != 0:
        raise CheckError("git %s: %s" % (" ".join(args), out.stderr.strip()))
    return out.stdout.strip()


# --- latest releases ----------------------------------------------------------

def latest_release(repo):
    """Tag of the release GitHub marks as latest (no drafts or pre-releases)."""
    return field(gh("repos/%s/releases/latest" % repo), "tag_name", repo)


def latest_release_with(prefix):
    """latest_release, but the tag must start with prefix; another naming
    scheme stops the check instead of being compared by its numbers."""
    def read(repo):
        tag = latest_release(repo)
        if not tag.startswith(prefix):
            raise CheckError("%s: latest release %s does not start with %s"
                             % (repo, tag, prefix))
        return tag
    return read


def latest_tag(repo, prefix, pattern):
    """Highest tag starting with prefix that matches pattern (for projects
    that publish stable versions as tags only). matching-refs answers with
    all refs at once, it does not page."""
    refs = gh("repos/%s/git/matching-refs/tags/%s" % (repo, prefix))
    if not isinstance(refs, list):
        raise CheckError("%s: tag list expected" % repo)
    tags = [field(r, "ref", repo)[len("refs/tags/"):] for r in refs]
    tags = [t for t in tags if re.match(pattern, t)]
    if not tags:
        raise CheckError("%s: no tag matches %s" % (repo, pattern))
    return max(tags, key=version_key)


def commit_behind(repo, tag, sha):
    """True when the tag has commits the pinned commit lacks (the pin is
    older than the tag or on another branch); False when the pin is the tag
    or a later commit on top of it."""
    cmp = gh("repos/%s/compare/%s...%s" % (repo, urllib.parse.quote(tag, safe=""), sha))
    status = field(cmp, "status", repo)
    if status in ("identical", "ahead"):
        return False
    if status in ("behind", "diverged"):
        return True
    raise CheckError("%s: unknown compare status %s" % (repo, status))


# --- pins -------------------------------------------------------------------

def kosit_config(module):
    for c in load_json(KOSIT_JSON)["configurations"]:
        if c["module"] == module:
            return c["url"]
    raise CheckError("kosit.json: module %s missing" % module)


def tool_urls(name):
    urls = [t["url"] for t in load_json(TOOLS_JSON)["tools"] if t["name"] == name]
    if not urls:
        raise CheckError("tools.json: tool %s missing" % name)
    return urls


def download_tag(url):
    return urllib.parse.unquote(search(r"/releases/download/([^/]+)/", url, url))


def one_tag(urls, what):
    """The release tag of the URLs, which must agree (one tool for several
    platforms, or one configuration in kosit.json and tools.json)."""
    tags = sorted(set(download_tag(u) for u in urls))
    if len(tags) != 1:
        raise Mismatch("%s pinned as %s" % (what, ", ".join(tags)))
    return tags[0]


def pin_config(module, tool):
    return lambda: one_tag([kosit_config(module)] + tool_urls(tool), module)


def pin_tool(name):
    return lambda: one_tag(tool_urls(name), name)


def pin_cen():
    """The UBL and CII packages are pinned separately; both must agree."""
    versions = sorted(set(re.findall(r"/releases/download/validation-([0-9.]+)/",
                                     read_text(NOTICE))))
    if not versions:
        raise CheckError("pin not found: CEN release in LandrixXML NOTICE.md")
    if len(versions) != 1:
        raise Mismatch("CEN packages in LandrixXML NOTICE.md pinned as %s"
                       % ", ".join(versions))
    return versions[0]


def pin_xr_schematron():
    return search(r"xrechnung-[0-9.]+-schematron-([0-9.]+)\.zip", read_text(NOTICE),
                  "XRechnung Schematron in LandrixXML NOTICE.md")


def pin_peppol():
    for r in load_json(KOSIT_JSON)["rules"]:
        m = re.search(r"/peppol-bis-invoice-3/([0-9a-f]{40})/", r.get("url", ""))
        if m:
            return m.group(1)
    raise CheckError("kosit.json: Peppol rules commit missing")


def pin_verapdf():
    for t in load_json(TOOLS_JSON)["tools"]:
        if t["name"] == "verapdf":
            return search(r"([0-9]+\.[0-9]+\.[0-9]+)", t["izpack"]["version"],
                          "veraPDF version in tools.json")
    raise CheckError("tools.json: verapdf missing")


def pin_commonmark():
    return search(r"commonmark@([0-9.]+)/", " ".join(tool_urls("commonmark")),
                  "commonmark version in tools.json")


def pin_cldr():
    """The CLDR version the code list generator reads (major number)."""
    names = load_json(CODELISTS_JSON)["names"]
    version = names["cldr_version"]
    major = version.split(".")[0]
    for entry in names["cldr"].values():
        if not entry["file"].startswith("cldr-%s/" % major):
            raise Mismatch("CLDR %s in manifest.json, but it reads %s"
                           % (version, entry["file"]))
    return major


def pin_landrixxml():
    """The tag of the submodule commit recorded in this repository (the
    gitlink), whatever the local checkout of the submodule is."""
    sha = git("-C", ROOT, "rev-parse", "HEAD:external/landrix-xml")
    tags = [t for t in git("-C", SUBMODULE, "tag", "--points-at", sha).split()
            if re.match(r"^v\d", t)]
    if len(tags) != 1:
        raise CheckError("external/landrix-xml: recorded commit %s has %s release tags"
                         % (sha[:12], len(tags) or "no"))
    tag = tags[0]
    url = load_json(KOSIT_JSON)["landrixxml"]["url"]
    if "/%s/" % tag not in url:
        raise Mismatch("LandrixXML: submodule at %s, kosit.json reads %s" % (tag, url))
    return tag


# --- sources ----------------------------------------------------------------

def strip_prefix(prefix):
    return lambda tag: tag[len(prefix):] if tag.startswith(prefix) else tag


def jdk_version(tag):
    """jdk-21.0.12+7 -> 21.0.12.0.7: the version padded to four parts (a
    respin like 21.0.12.1 is newer than 21.0.12), then the build number."""
    m = re.match(r"^jdk-([0-9.]+)\+(\d+)$", tag)
    if not m:
        raise CheckError("not a JDK release tag: %s" % tag)
    parts = m.group(1).split(".")
    parts += ["0"] * (4 - len(parts))
    return ".".join(parts + [m.group(2)])


SOURCES = [
    # name, repository, pin reader, latest reader (default latest_release),
    # tag -> comparable version (default the tag itself)
    ("cen", "ConnectingEurope/eInvoicing-EN16931", pin_cen,
     latest_release_with("validation-"), strip_prefix("validation-")),
    ("xrechnung-config", "itplr-kosit/validator-configuration-xrechnung",
     pin_config("xrechnung", "validator-configuration-xrechnung"), None, None),
    ("xrechnung-schematron", "itplr-kosit/xrechnung-schematron", pin_xr_schematron,
     None, None),
    ("xrechnung-visualization", "itplr-kosit/xrechnung-visualization",
     pin_config("visualization", "xrechnung-visualization"), None, None),
    ("kosit-validator", "itplr-kosit/validator", pin_tool("validator"), None, None),
    ("bis-config", "itplr-kosit/validator-configuration-bis",
     pin_config("bis", "validator-configuration-bis"), None, None),
    ("peppol", "OpenPEPPOL/peppol-bis-invoice-3", pin_peppol, None, None),
    ("zugferd-config", "LandrixSoftware/validator-configuration-zugferd",
     pin_config("zugferd", "validator-configuration-zugferd"), None, None),
    ("mustang", "ZUGFeRD/mustangproject", pin_tool("mustang"), None, None),
    # veraPDF publishes stable versions (even minor number) as tags only.
    ("verapdf", "veraPDF/veraPDF-apps", pin_verapdf,
     lambda repo: latest_tag(repo, "v1.", r"^v1\.\d*[02468]\.\d+$"), None),
    ("qpdf", "qpdf/qpdf", pin_tool("qpdf"), None, None),
    ("jre", "adoptium/temurin21-binaries", pin_tool("jre"), None, jdk_version),
    ("commonmark", "commonmark/commonmark.js", pin_commonmark, None, None),
    ("cldr", "unicode-org/cldr", pin_cldr, latest_release_with("release-"),
     strip_prefix("release-")),
    ("landrixxml", "landrix/LandrixXML-for-Pascal", pin_landrixxml, None, None),
]


def check(name, repo, pin_reader, latest_reader, normalize):
    """Returns (status, pinned, latest); status is ok, newer, mismatch or error."""
    try:
        pinned = pin_reader()
    except Mismatch as e:
        return "mismatch", str(e), ""
    except (CheckError, OSError, KeyError, TypeError, ValueError) as e:
        return "error", "pin of %s unreadable: %s" % (name, e), ""
    try:
        latest = (latest_reader or latest_release)(repo)
        if name == "peppol":
            # The pin is a commit: newer when the latest tag is not part of it.
            if commit_behind(repo, latest, pinned):
                return "newer", pinned[:12], latest
            return "ok", "%s (%s)" % (pinned[:12], latest), latest
        norm = normalize or (lambda t: t)
        if version_key(norm(latest)) > version_key(norm(pinned)):
            return "newer", pinned, latest
        return "ok", pinned, latest
    except CheckError as e:
        return "error", pinned, str(e)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--only", help="comma-separated source names (default: all)")
    args = ap.parse_args()

    names = [s[0] for s in SOURCES]
    selected = SOURCES
    if args.only:
        wanted = [n.strip() for n in args.only.split(",") if n.strip()]
        unknown = [n for n in wanted if n not in names]
        if unknown:
            ap.error("unknown source %s (known: %s)" % (", ".join(unknown), ", ".join(names)))
        selected = [s for s in SOURCES if s[0] in wanted]

    if not shutil.which("gh"):
        print("upstream-check: the GitHub CLI 'gh' is not on the PATH", file=sys.stderr)
        return 2

    worst = 0
    width = max(len(s[0]) for s in selected)
    for name, repo, pin_reader, latest_reader, normalize in selected:
        status, pinned, latest = check(name, repo, pin_reader, latest_reader, normalize)
        if status == "ok":
            line = "%s  pinned %s" % ("ok".ljust(8), pinned)
        elif status == "newer":
            line = "%s  pinned %s, latest %s  (https://github.com/%s/releases)" % (
                "NEWER".ljust(8), pinned, latest, repo)
            worst = max(worst, 1)
        elif status == "mismatch":
            line = "%s  %s" % ("MISMATCH".ljust(8), pinned)
            worst = max(worst, 1)
        else:
            line = "%s  %s" % ("ERROR".ljust(8), latest or pinned)
            worst = 2
        print("%s  %s" % (name.ljust(width), line))

    if not args.only:
        print()
        print("Check by hand (no release API):")
        for title, url in MANUAL:
            print("  %s: %s" % (title, url))
    return worst


if __name__ == "__main__":
    sys.exit(main())
