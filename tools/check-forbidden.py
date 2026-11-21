#!/usr/bin/env python3
"""Check Pascal sources for language features and units that Delphi 6 lacks.

Rules: the same language subset as LandrixXml (see CONTRIBUTING.md). Exits with code 1 if any violation is
found, 0 otherwise.

A line may opt out of the identifier checks with the marker comment
``// check-forbidden: allow`` (only for conditional compatibility code, e.g.
``NativeInt`` inside a ``{$IF CompilerVersion >= 20.0}`` branch).

API levels: every unit in source/ carries one marker comment
``{ API: stable.`` or ``{ API: internal.`` before its unit line, and the
interface section of a stable unit uses only stable units of this library
(internal units may change in any release, so a stable signature must not
depend on them).

Own rule identifiers: every identifier ``LX-<family>-<nn>`` that a unit in
source/ names in a string literal is listed in docs/rules.md and
docs/de/rules.md, and the lists name no identifier the sources do not have
(checked when the default paths are used).

Usage: python tools/check-forbidden.py [path ...]
Default paths: source, tests, examples.
"""

import os
import re
import sys

ALLOW_MARKER = "check-forbidden: allow"
EXTENSIONS = (".pas", ".inc", ".dpr", ".lpr")

# types: Delphi 13 needs it for TList.TDirection (hint H2443 at inherited Extract)
ALLOWED_UNITS = {"sysutils", "classes", "contnrs", "types"}
# Only in programs (.dpr/.lpr), never in library units: cwstring installs the
# Unix wide string manager that applications need for lossless conversions.
PROGRAM_UNITS = {"cwstring"}
OWN_UNIT_PREFIXES = ("landrixxml", "landrixeinvoice")
# Only in the GUI example examples/Workbench: the VCL and LCL units both
# frameworks name alike (Windows and ShellAPI for the VCL branch, Interfaces
# and LCLIntf for the LCL branch), and its own form unit.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUI_EXAMPLE_DIR = os.path.normcase(os.path.join(ROOT, "examples", "Workbench")) + os.sep
GUI_UNITS = {"interfaces", "lclintf", "windows", "shellapi", "forms", "controls", "dialogs",
             "stdctrls", "extctrls", "comctrls", "workbenchmain"}
# The XSLT engine of LandrixXML stays optional: in source/ only these units
# may use it, so a program that only reads and writes invoices does not link
# it (tools, tests and examples may).
SOURCE_DIR = os.path.normcase(os.path.join(ROOT, "source")) + os.sep
XSLT_UNIT_PREFIX = "landrixxmlxslt"
XSLT_USERS = {"landrixeinvoicekositreport.pas", "landrixeinvoicekositvisualization.pas"}

FORBIDDEN_IDENTIFIERS = [
    "TStringBuilder", "TEncoding", "TFormatSettings", "PosEx", "CharInSet",
    "RawByteString", "NativeInt", "NativeUInt", "TBytes", "UInt64",
    "UTF8ToString",
]

# (regex on comment-free code, message)
FORBIDDEN_PATTERNS = [
    (r"\bfor\s+(var\s+)?\w+\s+in\b", "for ... in"),
    (r"\bExit\s*\(", "Exit(Value)"),
    (r"\bstrict\s+(private|protected)\b", "strict private/protected"),
    (r"\breference\s+to\b", "anonymous method type (reference to)"),
    (r"(:=|\(|,)\s*(procedure|function)\b", "anonymous method"),
    (r"\b(class|record|type)\s+helper\b", "class/record helper"),
    (r"\bclass\s+operator\b", "operator overloading"),
    (r"^\s*operator\b", "operator overloading"),
    (r"\binline\b", "inline"),
    (r"\bclass\s+var\b", "class var"),
    (r"\bclass\s+(property|const|threadvar)\b", "class property/const"),
    (r"\bclass\s+(sealed|abstract)\b", "class sealed/abstract"),
    (r";\s*(static|final)\s*;", "static/final method directive"),
    (r"\bDefault\s*\(", "Default()"),
    (r"\bvar\s+\w+\s*(:\s*[\w.]+\s*)?:=", "inline variable declaration"),
    (r"\b(generic|specialize)\b", "generics"),
    (r"\b[A-Za-z_]\w*\s*<\s*[A-Za-z_][\w.]*(\s*,\s*[A-Za-z_][\w.]*)*\s*>", "generics"),
]


SAME_LINE_ONLY = {"class/record helper", "operator overloading", "class var", "class property/const",
                  "class sealed/abstract", "generics"}


class Violation(object):
    def __init__(self, path, line, message):
        self.path = path
        self.line = line
        self.message = message

    def __str__(self):
        return "%s:%d: %s" % (self.path, self.line, self.message)


def strip_comments(text):
    """Return (code, directives).

    code has comments and string literals replaced by spaces (newlines kept,
    so line numbers stay valid). directives is a list of (line, text) for
    every compiler directive {$...}.
    """
    out = []
    directives = []
    i = 0
    n = len(text)
    line = 1

    def blank(s):
        return "".join(c if c == "\n" else " " for c in s)

    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            out.append(c)
            i += 1
        elif c == "'":
            j = i + 1
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        j += 2
                        continue
                    break
                if text[j] == "\n":
                    break
                j += 1
            out.append("'" + " " * (j - i - 1) + "'")
            i = j + 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            if j < 0:
                j = n
            out.append(" " * (j - i))
            i = j
        elif c == "{":
            j = text.find("}", i)
            if j < 0:
                j = n - 1
            chunk = text[i:j + 1]
            if chunk.startswith("{$"):
                directives.append((line, chunk))
            line += chunk.count("\n")
            out.append(blank(chunk))
            i = j + 1
        elif text.startswith("(*", i):
            j = text.find("*)", i)
            if j < 0:
                j = n - 2
            chunk = text[i:j + 2]
            if chunk.startswith("(*$"):
                # the same directive as {$...}
                directives.append((line, "{" + chunk[2:-2] + "}"))
            line += chunk.count("\n")
            out.append(blank(chunk))
            i = j + 2
        else:
            out.append(c)
            i += 1
    return "".join(out), directives


def check_directives(path, directives, violations):
    stack = []
    for line, d in directives:
        m = re.match(r"\{\$(\w+)", d)
        if not m:
            continue
        name = m.group(1).upper()
        if name == "REGION" or name == "ENDREGION":
            violations.append(Violation(path, line, "{$%s}" % name))
        elif name == "IF":
            stack.append(("IF", line))
        elif name in ("IFDEF", "IFNDEF", "IFOPT"):
            stack.append(("IFDEF", line))
        elif name == "ENDIF":
            if not stack:
                violations.append(Violation(path, line, "unbalanced {$ENDIF}"))
            elif stack.pop()[0] == "IF":
                violations.append(Violation(path, line, "{$IF} closed with {$ENDIF}; use {$IFEND}"))
        elif name == "IFEND":
            if not stack:
                violations.append(Violation(path, line, "unbalanced {$IFEND}"))
            elif stack.pop()[0] != "IF":
                violations.append(Violation(path, line, "{$IFDEF} closed with {$IFEND}; use {$ENDIF}"))
    for kind, line in stack:
        if not path.lower().endswith(".inc"):
            violations.append(Violation(path, line, "unclosed {$%s}" % kind))


def check_uses(path, code, violations):
    for m in re.finditer(r"\buses\b(.*?);", code, re.IGNORECASE | re.DOTALL):
        line = code.count("\n", 0, m.start()) + 1
        for item in m.group(1).split(","):
            name = item.strip().split()[0] if item.strip() else ""
            if not name:
                continue
            low = name.lower()
            if "." in name:
                violations.append(Violation(path, line, "qualified unit name: %s" % name))
            elif low in PROGRAM_UNITS and path.lower().endswith((".dpr", ".lpr")):
                continue
            elif low in GUI_UNITS and os.path.normcase(os.path.abspath(path)).startswith(GUI_EXAMPLE_DIR):
                continue
            elif low not in ALLOWED_UNITS and not low.startswith(OWN_UNIT_PREFIXES):
                violations.append(Violation(path, line, "unit not allowed: %s" % name))
            elif (low.startswith(XSLT_UNIT_PREFIX) and
                  os.path.normcase(os.path.abspath(path)).startswith(SOURCE_DIR) and
                  os.path.basename(path).lower() not in XSLT_USERS):
                violations.append(Violation(path, line, "XSLT unit outside the KoSIT report and visualization units: %s"
                                            % name))


def block_bodies(code, opener):
    """Yield (start, body) for declaration blocks starting with opener regex
    and ending at the matching 'end' (counting nested record/class/object)."""
    tokens = re.compile(r"\b(record|class|object|interface|end|case|try|begin|asm)\b|[A-Za-z_]\w*|.", re.IGNORECASE | re.DOTALL)
    for m in re.finditer(opener, code, re.IGNORECASE):
        depth = 1
        pos = m.end()
        tm = tokens.search(code, pos)
        while tm is not None and depth > 0:
            word = (tm.group(1) or "").lower()
            if word in ("record",):
                depth += 1
            elif word == "class":
                after = code[tm.end():tm.end() + 40]
                if re.match(r"\s*(\(|\b(private|protected|public|published)\b|[A-Za-z_]\w*\s*[:;(])", after) and not re.match(r"\s*(of|function|procedure|constructor|destructor|property|var|operator)\b", after):
                    depth += 1
            elif word == "end":
                depth -= 1
            pos = tm.end()
            if depth == 0:
                break
            tm = tokens.search(code, pos)
        yield m.start(), code[m.end():pos]


def check_blocks(path, code, violations):
    for start, body in block_bodies(code, r"=\s*(packed\s+)?record\b"):
        if re.search(r"\b(procedure|function|constructor|destructor|property|class)\b", body, re.IGNORECASE):
            line = code.count("\n", 0, start) + 1
            violations.append(Violation(path, line, "record with methods"))
    for start, body in block_bodies(code, r"=\s*class\b(?!\s*(of\b|;|\([\w\s,.]*\)\s*;))"):
        # a nested section starts a line ("type" alone, or "const X = ...");
        # "const" as a parameter modifier does not count
        # optionally preceded by a visibility keyword on the same line
        # ("public const X = ...", "private type")
        vis = r"(?:(?:strict\s+)?(?:public|private|protected|published)\s+)?"
        if re.search(r"^\s*" + vis + r"(type|const|var)\s*$|^\s*" + vis + r"(type|const)\s+\w+\s*=", body, re.IGNORECASE | re.MULTILINE):
            line = code.count("\n", 0, start) + 1
            violations.append(Violation(path, line, "nested type/const/var section in class"))
    # old-style objects are allowed only as value types without a VMT
    # (optional values): zeroed memory must be a valid "not set" state
    for start, body in block_bodies(code, r"=\s*(packed\s+)?object\b"):
        m = re.search(r"\b(constructor|destructor|virtual|dynamic|abstract|override)\b", body, re.IGNORECASE)
        if m:
            line = code.count("\n", 0, start) + 1
            violations.append(Violation(path, line, "object type with %s (no VMT allowed)" % m.group(1).lower()))


def check_file(path, violations):
    with open(path, "rb") as f:
        raw = f.read()
    for idx, b in enumerate(raw):
        if b > 127:
            line = raw.count(b"\n", 0, idx) + 1
            violations.append(Violation(path, line, "non-ASCII byte in source (use #$xx constants)"))
            break
    text = raw.decode("latin-1")
    raw_lines = text.split("\n")
    code, directives = strip_comments(text)
    code_lines = code.split("\n")

    check_directives(path, directives, violations)
    check_uses(path, code, violations)
    check_blocks(path, code, violations)

    ident_re = re.compile(r"\b(%s)\b" % "|".join(FORBIDDEN_IDENTIFIERS), re.IGNORECASE)
    pattern_res = [(re.compile(p, re.IGNORECASE), msg) for p, msg in FORBIDDEN_PATTERNS]
    for no, cl in enumerate(code_lines, 1):
        allowed = ALLOW_MARKER in raw_lines[no - 1]
        if not allowed:
            for m in ident_re.finditer(cl):
                violations.append(Violation(path, no, "forbidden identifier: %s" % m.group(1)))
        for rx, msg in pattern_res:
            if rx.search(cl):
                violations.append(Violation(path, no, msg))
    # a construct split across lines (Pascal reads a line break as blank);
    # not for patterns whose words may legally meet across a line break
    # (a class body opening with property, var or const; a type named Helper;
    # comparisons in two arguments such as A < B, C > D)
    for rx, msg in pattern_res:
        if msg in SAME_LINE_ONLY:
            continue
        for m in rx.finditer(code):
            if "\n" in m.group(0):
                violations.append(Violation(path, code.count("\n", 0, m.start()) + 1, msg))


API_MARKER = re.compile(r"\{ API: (stable|internal)\.")


def check_api(files, violations):
    """API markers of the library units and the uses of stable interfaces.
    The levels of all units in the folder of a checked unit are read, so a
    single file can be checked too."""
    checked = set(os.path.abspath(f) for f in files
                  if os.path.basename(os.path.dirname(os.path.abspath(f))) == "source"
                  and f.lower().endswith(".pas"))
    folders = set(os.path.dirname(f) for f in checked)
    units = {}
    for folder in folders:
        for fn in sorted(os.listdir(folder)):
            if not fn.lower().endswith(".pas"):
                continue
            path = os.path.join(folder, fn)
            with open(path, encoding="latin-1") as f:
                text = f.read()
            markers = list(API_MARKER.finditer(text))
            level = None
            if len(markers) == 1:
                end = text.find("}", markers[0].end())
                if end >= 0 and re.match(r"\s*unit\b", text[end + 1:], re.IGNORECASE):
                    level = markers[0].group(1)
            if level is None:
                if path in checked:
                    violations.append(Violation(path, 1, "needs exactly one API marker directly before the unit line "
                                                "({ API: stable. or { API: internal.)"))
                continue
            units[fn[:-4].lower()] = (path, level, text)
    for name, (path, level, text) in sorted(units.items()):
        if level != "stable" or path not in checked:
            continue
        code, _ = strip_comments(text)
        m = re.search(r"\binterface\b(.*?)\bimplementation\b", code, re.IGNORECASE | re.DOTALL)
        if not m:
            continue
        u = re.search(r"\buses\b(.*?);", m.group(1), re.IGNORECASE | re.DOTALL)
        if not u:
            continue
        for item in u.group(1).split(","):
            used = item.strip().split()[0].lower() if item.strip() else ""
            if used in units and units[used][1] != "stable":
                line = code.count("\n", 0, m.start(1) + u.start()) + 1
                violations.append(Violation(path, line, "stable unit uses internal unit %s in its interface" %
                                            item.strip().split()[0]))


RULE_LITERAL = re.compile(r"LX-[A-Z]+-[0-9]{2}")
RULE_ROW = re.compile(r"^\|\s*(LX-[^|\s]*)\s*\|(.*)$", re.MULTILINE)
# the column Since: a version, "unreleased", and "retired in <version>" at the end of a retired rule
SINCE_EN = re.compile(r"^(unreleased|[0-9][^\s,]*)(, retired in [0-9][^\s,]*)?$")
SINCE_DE = re.compile(r"^(unver\u00f6ffentlicht|[0-9][^\s,]*)(, aufgegeben in [0-9][^\s,]*)?$")


def pascal_strings(text):
    """Yield (line, value) for every string literal of a Pascal source, outside comments."""
    i = 0
    n = len(text)
    line = 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
        elif c == "{":
            j = text.find("}", i + 1)
            j = n if j < 0 else j + 1
            line += text.count("\n", i, j)
            i = j
        elif text.startswith("(*", i):
            j = text.find("*)", i + 2)
            j = n if j < 0 else j + 2
            line += text.count("\n", i, j)
            i = j
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif c == "'":
            j = i + 1
            value = []
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        value.append("'")
                        j += 2
                        continue
                    break
                if text[j] == "\n":
                    break
                value.append(text[j])
                j += 1
            yield line, "".join(value)
            i = j + 1
        else:
            i += 1


def check_rule_registry(root, violations):
    """The own rule identifiers of source/ against the lists in docs/rules.md and docs/de/rules.md.
    An identifier is a complete string literal 'LX-<family>-<nn>'; a literal that starts with 'LX-'
    but is no complete identifier is reported (identifiers are never built at run time)."""
    in_source = {}
    folder = os.path.join(root, "source")
    for fn in sorted(os.listdir(folder)):
        if not fn.lower().endswith(".pas"):
            continue
        path = os.path.join(folder, fn)
        with open(path, encoding="latin-1") as f:
            text = f.read()
        for number, value in pascal_strings(text):
            if not value.startswith("LX-"):
                continue
            if RULE_LITERAL.fullmatch(value):
                in_source.setdefault(value, (path, number))
            else:
                violations.append(Violation(path, number, "'%s' is no complete rule identifier "
                                            "(LX-<family>-<two digits>)" % value))
    lists = []
    for doc, since_form in ((os.path.join(root, "docs", "rules.md"), SINCE_EN),
                            (os.path.join(root, "docs", "de", "rules.md"), SINCE_DE)):
        if not os.path.isfile(doc):
            violations.append(Violation(doc, 1, "list of the own rule identifiers is missing"))
            continue
        with open(doc, encoding="utf-8") as f:
            text = f.read()
        listed = {}
        retired = set()
        since_of = {}
        for m in RULE_ROW.finditer(text):
            rule = m.group(1)
            number = text.count("\n", 0, m.start()) + 1
            if not RULE_LITERAL.fullmatch(rule):
                violations.append(Violation(doc, number, "'%s' is no complete rule identifier" % rule))
                continue
            if rule in listed:
                violations.append(Violation(doc, number, "rule %s is listed twice (first in line %d)" %
                                            (rule, listed[rule])))
                continue
            listed[rule] = number
            since = m.group(2).rstrip().rstrip("|").split("|")[-1].strip()
            form = since_form.match(since)
            if form is None:
                violations.append(Violation(doc, number, "rule %s: the column Since '%s' is no version, "
                                            "unreleased or '<version>, retired in <version>'" % (rule, since)))
                continue
            since_of[rule] = (form.group(1), (form.group(2) or "").split(" in ")[-1])
            if form.group(2):
                retired.add(rule)
        for rule, (path, number) in sorted(in_source.items()):
            if rule not in listed:
                violations.append(Violation(path, number, "rule %s is not listed in %s" % (rule, doc)))
            elif rule in retired:
                violations.append(Violation(doc, listed[rule], "rule %s is marked retired but %s has it" %
                                            (rule, path)))
        for rule, number in sorted(listed.items()):
            if rule not in in_source and rule not in retired:
                violations.append(Violation(doc, number, "rule %s is listed but no unit in source/ has it "
                                            "(mark it retired)" % rule))
        lists.append((doc, listed, retired, since_of))
    if len(lists) == 2:
        (doc_en, listed_en, retired_en, since_en), (doc_de, listed_de, retired_de, since_de) = lists
        for rule in sorted(set(listed_en) ^ set(listed_de)):
            violations.append(Violation(doc_de, 1, "rule %s is in only one of the two lists" % rule))
        for rule in sorted((retired_en ^ retired_de) & set(listed_en) & set(listed_de)):
            violations.append(Violation(doc_de, listed_de[rule], "rule %s is retired in only one of the two lists" %
                                        rule))
        unreleased = {"unreleased": "", "unver\u00f6ffentlicht": ""}
        for rule in sorted(set(since_en) & set(since_de)):
            en = (unreleased.get(since_en[rule][0], since_en[rule][0]), since_en[rule][1])
            de = (unreleased.get(since_de[rule][0], since_de[rule][0]), since_de[rule][1])
            if en != de:
                violations.append(Violation(doc_de, listed_de[rule], "rule %s: the column Since differs from the "
                                            "English list" % rule))


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    paths = argv[1:] or [os.path.join(root, d) for d in ("source", "tests", "examples")]
    files = []
    for p in paths:
        if not os.path.exists(p):
            print("check-forbidden: no such file or folder: %s" % p)
            return 2
        if os.path.isfile(p):
            files.append(p)
        elif os.path.isdir(p):
            for dirpath, dirnames, filenames in os.walk(p):
                dirnames[:] = [d for d in dirnames if d not in ("local", "build", "data")]
                for fn in sorted(filenames):
                    if fn.lower().endswith(EXTENSIONS):
                        files.append(os.path.join(dirpath, fn))
    if not files:
        print("check-forbidden: no file to check")
        return 1
    violations = []
    for f in files:
        check_file(f, violations)
    check_api(files, violations)
    if not argv[1:]:
        check_rule_registry(root, violations)
    for v in violations:
        print(v)
    print("check-forbidden: %d file(s), %d violation(s)" % (len(files), len(violations)))
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
