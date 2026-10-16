#!/usr/bin/env python3
"""Generates source/LandrixEInvoiceCodes.pas from the code lists in
tools/codelists (manifest.json, members/*.json, src/<source>/*.gc).

The sources are committed byte-exact; their SHA-256 checksums are in the
manifest and are verified before anything is generated. Nothing is
downloaded. The output is deterministic (members sorted by code, ASCII,
CRLF line endings).

Usage:
  python tools/codelists/gen-codelists.py           write the unit
  python tools/codelists/gen-codelists.py --check   exit 1 if the committed
                                                    unit differs
"""

import hashlib
import io
import json
import os
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUTPUT = os.path.join(ROOT, "source", "LandrixEInvoiceCodes.pas")

# Identifiers declared elsewhere in the library that generated members
# must not hide (enumerations of LandrixEInvoiceInvoice).
FOREIGN_PREFIXES = ("iptt_", "ilsrc_")


def fail(msg):
    sys.stderr.write("gen-codelists: " + msg + "\n")
    sys.exit(2)


def ascii_text(s):
    """Folds text to printable ASCII for Pascal comments."""
    s = s.replace("\u00a0", " ")
    for a, b in (("\u2018", "'"), ("\u2019", "'"), ("\u02bb", "'"),
                 ("\u201c", '"'), ("\u201d", '"'), ("\u00a7", "section ")):
        s = s.replace(a, b)
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    s = re.sub(r"[\x00-\x1f\x7f]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


GC_NS = "{http://docs.oasis-open.org/codelist/ns/genericode/1.0/}"


def read_genericode(path):
    """Returns [(code, name)] in file order. Row, Value and SimpleValue may
    be unqualified (as in the EC files) or in the genericode namespace."""
    root = ET.parse(path).getroot()
    rows = []
    for row in list(root.iter("Row")) + list(root.iter(GC_NS + "Row")):
        values = {}
        for value in row.findall("Value") + row.findall(GC_NS + "Value"):
            text = value.findtext("SimpleValue")
            if text is None:
                text = value.findtext(GC_NS + "SimpleValue")
            values[value.get("ColumnRef")] = text or ""
        if "Code" not in values:
            fail("%s: row without Code" % path)
        rows.append((values["Code"], values.get("Name", "")))
    if not rows:
        fail("%s: no rows" % path)
    return rows


def check_doc(where, lines):
    for line in lines:
        if "}" in line or any(ord(c) > 126 or ord(c) < 32 for c in line):
            fail("%s: doc line must be printable ASCII without '}': %r" % (where, line))


def identifier_for(code, lst):
    s = code
    strip = lst.get("strip_prefix")
    if strip and s.startswith(strip):
        s = s[len(strip):]
    s = re.sub(r"[^A-Za-z0-9_]", "_", s)
    return lst["prefix"] + s


def pascal_string(s):
    if any(ord(c) > 126 or ord(c) < 32 for c in s):
        fail("non-ASCII code %r" % s)
    return "'" + s.replace("'", "''") + "'"


def load(manifest):
    # verify the sources
    for name, src in sorted(manifest["sources"].items()):
        for fname, digest in sorted(src["files"].items()):
            path = os.path.join(HERE, "src", name, fname)
            if not os.path.exists(path):
                fail("missing source file %s/%s" % (name, fname))
            if sha256(path) != digest:
                fail("checksum mismatch for %s/%s" % (name, fname))

    lists = []
    seen_ids = {}
    for lst in manifest["lists"]:
        aliases = {}
        docs = {}
        if lst.get("members"):
            data = json.load(io.open(os.path.join(HERE, lst["members"]), encoding="utf-8"))
            for m in data["members"]:
                if m["code"] in aliases:
                    fail("%s: duplicate code %r in members" % (lst["type"], m["code"]))
                aliases[m["code"]] = m["id"]
                if m.get("doc"):
                    check_doc("%s member %s" % (lst["type"], m["id"]), m["doc"])
                    docs[m["code"]] = m["doc"]
        check_doc(lst["type"], lst["doc"])
        if aliases.get("", lst["none"]) != lst["none"]:
            fail("%s: none member differs from the manifest" % lst["type"])

        if lst["source"]:
            src_name, fname = lst["source"].split("/", 1)
            rows = read_genericode(os.path.join(HERE, "src", src_name, fname))
        else:
            rows = [(code, "") for code in aliases if code != ""]
        for extra in lst.get("extra_codes", []):
            rows.append((extra["code"], extra["name"]))

        names = {}
        for code, name in rows:
            if code == "":
                fail("%s: empty code" % lst["type"])
            if code.upper() in (c.upper() for c in names):
                fail("%s: duplicate code %r" % (lst["type"], code))
            names[code] = ascii_text(name)
        for code in aliases:
            if code and code not in names:
                fail("%s: member code %r not in the source" % (lst["type"], code))
        upper_codes = set(c.upper() for c in names)
        for alias, target in lst.get("read_aliases", {}).items():
            if target not in names or alias.upper() in upper_codes:
                fail("%s: bad read alias %r" % (lst["type"], alias))

        members = [{"code": "", "id": lst["none"], "name": "", "doc": []}]
        for code in sorted(names):
            members.append({
                "code": code,
                "id": aliases.get(code) or identifier_for(code, lst),
                "name": names[code],
                "doc": docs.get(code, []),
            })
        for m in members:
            key = m["id"].lower()
            if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", m["id"]):
                fail("invalid identifier %r" % m["id"])
            if key in seen_ids or key.startswith(FOREIGN_PREFIXES):
                fail("identifier %r is not unique" % m["id"])
            seen_ids[key] = lst["type"]
        lst = dict(lst)
        lst["member_list"] = members
        lst["read_aliases"] = lst.get("read_aliases", {})
        lists.append(lst)
    return lists


HEADER = """{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ GENERATED by tools/codelists/gen-codelists.py - do not edit. Change
  tools/codelists/manifest.json or tools/codelists/members/*.json and run
  the generator again.
  Sources: %(sources)s

  Code lists of the invoice model: one enumeration per list and functions
  that convert between members and codes.

  Rules for every list:
  - The first member means "not set"; its code is ''.
  - The members are the complete list of the source. Members that existed
    before keep their names; the others are named after their code. The
    member names are part of the public API and stay stable. The ordinal
    values are not stable between versions: never store them.
  - ...ToStr returns the code of a member. ...FromStr finds the member for a
    code (ASCII case-insensitive) and returns False, with the "not set"
    member, for an empty or unknown code.
  - Restrictions of single target specifications are not part of these
    lists.
  - The comments on the members are the official English names of the
    code lists (no German version exists).
  - Library-own lists (payment terms type, line status reason code) are
    declared in LandrixEInvoiceInvoice.

  DE: ERZEUGT von tools/codelists/gen-codelists.py - nicht von Hand aendern.
  tools/codelists/manifest.json oder tools/codelists/members/*.json aendern
  und den Generator erneut ausfuehren.

  Codelisten des Rechnungsmodells: je Liste eine Aufzaehlung und
  Funktionen zur Umwandlung zwischen Aufzaehlungswert und Code.

  Regeln fuer jede Liste:
  - Das erste Element bedeutet "nicht gesetzt"; sein Code ist ''.
  - Die Werte sind die vollstaendige Liste der Quelle. Bereits vorhandene
    Werte behalten ihre Namen; die anderen heissen nach ihrem Code. Die
    Namen gehoeren zur oeffentlichen API und bleiben stabil. Die
    Ordinalwerte sind zwischen Versionen nicht stabil: nie speichern.
  - ...ToStr liefert den Code eines Werts. ...FromStr sucht den Wert zu einem
    Code (ASCII, ohne Unterscheidung von Gross- und Kleinschreibung) und
    liefert False und den Wert "nicht gesetzt" bei leerem oder unbekanntem
    Code.
  - Einschraenkungen einzelner Zielspezifikationen gehoeren nicht zu diesen
    Listen.
  - Die Kommentare an den Werten sind die offiziellen englischen
    Bezeichnungen der Codelisten (eine deutsche Fassung gibt es nicht).
  - Bibliothekseigene Listen (Art der Zahlungsbedingungen, Untertyp der
    Rechnungsposition) stehen in LandrixEInvoiceInvoice. }

unit LandrixEInvoiceCodes;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes;

type"""


def generate(manifest, lists):
    out = []
    w = out.append
    sources = "; ".join(src["title"] for _, src in sorted(manifest["sources"].items()))
    w(HEADER % {"sources": sources})

    for lst in lists:
        doc = lst["doc"]
        w("  { " + doc[0])
        for line in doc[1:]:
            w("    " + line)
        out[-1] += " }"
        w("  %s = (" % lst["type"])
        members = lst["member_list"]
        for i, m in enumerate(members):
            sep = "," if i < len(members) - 1 else ""
            for j, line in enumerate(m["doc"]):
                prefix = "    { " if j == 0 else "      "
                w(prefix + line + (" }" if j == len(m["doc"]) - 1 else ""))
            if m["code"] == "":
                w("    %s%s" % (m["id"], sep))
            else:
                note = m["code"] if not m["name"] else "%s %s" % (m["code"], m["name"])
                w("    %s%s // %s" % (m["id"], sep, note))
        w("  );")
        w("")

    w("{ Conversion between members and codes, see the rules at the top of the")
    w("  unit.")
    w("  DE: Umwandlung zwischen Werten und Codes, siehe die Regeln am Anfang der")
    w("  Unit. }")
    for lst in lists:
        f = lst["func"]
        w("function LandrixEInvoice%sToStr(Value: %s): TLandrixEInvoiceString;" % (f, lst["type"]))
        w("function LandrixEInvoice%sFromStr(const Code: TLandrixEInvoiceString;" % f)
        w("  out Value: %s): Boolean;" % lst["type"])
    w("")
    w("implementation")
    w("")
    w("const")
    for lst in lists:
        w("  %sCodes: array[%s] of TLandrixEInvoiceString = (" % (lst["func"], lst["type"]))
        members = lst["member_list"]
        for i, m in enumerate(members):
            sep = "," if i < len(members) - 1 else ""
            w("    %s%s" % (pascal_string(m["code"]), sep))
        w("  );")
        w("")
    w("""function AsciiUpper(C: WideChar): WideChar;
begin
  if (C >= 'a') and (C <= 'z') then
    Result := WideChar(Ord(C) - 32)
  else
    Result := C;
end;

{ ASCII case-insensitive comparison; other characters must be equal. }
function SameCode(const A, B: TLandrixEInvoiceString): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  I := 1;
  while Result and (I <= Length(A)) do
  begin
    Result := AsciiUpper(A[I]) = AsciiUpper(B[I]);
    Inc(I);
  end;
end;

{ Each FromStr skips the "not set" member, so '' never matches. }
""")
    for lst in lists:
        f = lst["func"]
        t = lst["type"]
        w("function LandrixEInvoice%sToStr(Value: %s): TLandrixEInvoiceString;" % (f, t))
        w("begin")
        w("  Result := %sCodes[Value];" % f)
        w("end;")
        w("")
        w("function LandrixEInvoice%sFromStr(const Code: TLandrixEInvoiceString;" % f)
        w("  out Value: %s): Boolean;" % t)
        w("var")
        w("  V: %s;" % t)
        w("begin")
        w("  for V := Succ(Low(V)) to High(V) do")
        w("    if SameCode(%sCodes[V], Code) then" % f)
        w("    begin")
        w("      Value := V;")
        w("      Result := True;")
        w("      Exit;")
        w("    end;")
        for alias, target in sorted(lst["read_aliases"].items()):
            target_id = [m["id"] for m in lst["member_list"] if m["code"] == target][0]
            w("  { read alias: %s is read as %s }" % (alias, target))
            w("  if SameCode(%s, Code) then" % pascal_string(alias))
            w("  begin")
            w("    Value := %s;" % target_id)
            w("    Result := True;")
            w("    Exit;")
            w("  end;")
        w("  Value := Low(V);")
        w("  Result := False;")
        w("end;")
        w("")
    w("end.")
    text = "\n".join(out) + "\n"
    if any(ord(c) > 127 for c in text):
        fail("non-ASCII output")
    return text.replace("\n", "\r\n").encode("ascii")


def main(argv):
    args = argv[1:]
    if any(a != "--check" for a in args):
        fail("unknown argument; usage: gen-codelists.py [--check]")
    check = "--check" in args
    manifest = json.load(io.open(os.path.join(HERE, "manifest.json"), encoding="utf-8"))
    lists = load(manifest)
    data = generate(manifest, lists)
    total = sum(len(l["member_list"]) - 1 for l in lists)
    if check:
        try:
            with open(OUTPUT, "rb") as f:
                current = f.read()
        except IOError:
            current = b""
        if current.replace(b"\r\n", b"\n") != data.replace(b"\r\n", b"\n"):
            sys.stderr.write("gen-codelists: %s is not up to date; run the generator\n" % OUTPUT)
            return 1
        print("gen-codelists: up to date (%d lists, %d codes)" % (len(lists), total))
        return 0
    with open(OUTPUT, "wb") as f:
        f.write(data)
    print("gen-codelists: wrote %s (%d lists, %d codes)" % (OUTPUT, len(lists), total))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
