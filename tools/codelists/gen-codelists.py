#!/usr/bin/env python3
"""Generates source/LandrixEInvoiceCodes.pas from the code lists in
tools/codelists (manifest.json, members/*.json, src/<source>/*.gc), and
source/LandrixEInvoiceCodeNames.pas with the names of the codes: English
from the genericode Name columns (names-en.json, hand-written, replaces the
few the source cuts off or decorates), German from names-de.json
(hand-written) and, for countries and currencies, from Unicode CLDR
(src/cldr-47).

The sources are committed byte-exact; their SHA-256 checksums are in the
manifest and are verified before anything is generated. Nothing is
downloaded. The output is deterministic (members sorted by code, ASCII,
CRLF line endings).

Usage:
  python tools/codelists/gen-codelists.py           write the units
  python tools/codelists/gen-codelists.py --check   exit 1 if a committed
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
NAMES_OUTPUT = os.path.join(ROOT, "source", "LandrixEInvoiceCodeNames.pas")

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
        raw_names = {}
        source_named = False
        for i, (code, name) in enumerate(rows):
            if code == "":
                fail("%s: empty code" % lst["type"])
            if code.upper() in (c.upper() for c in names):
                fail("%s: duplicate code %r" % (lst["type"], code))
            names[code] = ascii_text(name)
            raw_names[code] = re.sub(r"\s+", " ", name).strip()
            if name and lst["source"] and i < len(rows) - len(lst.get("extra_codes", [])):
                source_named = True
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
        lst["raw_names"] = raw_names
        lst["source_named"] = source_named
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

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixEInvoiceCodes;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes;

type"""


def generate(manifest, lists):
    out = []
    w = out.append
    used = set(l["source"].split("/", 1)[0] for l in lists if l["source"])
    sources = "; ".join(src["title"] for name, src in sorted(manifest["sources"].items()) if name in used)
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


NAMES_HEADER = """{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ GENERATED by tools/codelists/gen-codelists.py - do not edit. Change
  tools/codelists/names-de.json, tools/codelists/names-en.json or the sources
  in tools/codelists/manifest.json and run the generator again.
  Sources: %(sources)s

  The names of the codes, for showing an invoice to a person (the code
  itself stays the identifier and should be shown next to its name).
  English: the names of the official code lists, corrected where they are
  cut off or keep their list form (tools/codelists/names-en.json). German:
  own wording for the
  small lists and the common units (tools/codelists/names-de.json), country
  and currency names from Unicode CLDR %(cldr)s (Unicode License V3, see
  THIRD-PARTY-NOTICES.md); every other code has its English name.

  DE: ERZEUGT von tools/codelists/gen-codelists.py - nicht von Hand aendern.
  tools/codelists/names-de.json, tools/codelists/names-en.json oder die
  Quellen in tools/codelists/manifest.json aendern und den Generator erneut
  ausfuehren.

  Die Namen der Codes, um eine Rechnung einem Menschen zu zeigen (der Code
  selbst bleibt die Kennung und sollte neben seinem Namen stehen).
  Englisch: die Namen der offiziellen Codelisten, berichtigt, wo sie
  abgeschnitten sind oder ihre Listenform behalten
  (tools/codelists/names-en.json). Deutsch: eigene
  Formulierungen fuer die kleinen Listen und die gaengigen Einheiten
  (tools/codelists/names-de.json), Laender- und Waehrungsnamen aus Unicode
  CLDR %(cldr)s (Unicode License V3, siehe THIRD-PARTY-NOTICES.md); jeder andere
  Code hat seinen englischen Namen. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceCodeNames;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceReportHtml;

type
  { The code lists that have names (one per list of LandrixEInvoiceCodes
    whose source names its codes).
    DE: Die Codelisten mit Namen (eine je Liste von LandrixEInvoiceCodes,
    deren Quelle ihre Codes benennt). }
  TLandrixEInvoiceCodeList = ("""


def name_literal(s):
    """A Pascal literal of ASCII characters; '\\' plus four hex digits
    stands for any other character (decoded at run time). Split into parts
    of at most 200 characters (Delphi 6 limits literals to 255)."""
    out = []
    for c in s:
        o = ord(c)
        if o > 0xFFFF:
            fail("character outside the BMP in name %r" % s)
        if 32 <= o < 127 and c != "\\":
            out.append("''" if c == "'" else c)
        elif c in "\t\r\n":
            out.append(" ")
        else:
            out.append("\\%04X" % o)
    text = "".join(out)
    parts = []
    while len(text) > 200:
        cut = 200
        # never split inside an escape or a doubled quote
        while text[cut - 1] == "'" or "\\" in text[max(0, cut - 4):cut]:
            cut -= 1
        parts.append(text[:cut])
        text = text[cut:]
    parts.append(text)
    return " + ".join("'" + p + "'" for p in parts)


def no_duplicate_keys(pairs):
    keys = [k for k, _ in pairs]
    for k in keys:
        if keys.count(k) > 1:
            fail("duplicate key %r" % k)
    return dict(pairs)


def german_names(manifest, lists):
    """{func: {code: name}} from names-de.json and CLDR."""
    cfg = manifest["names"]
    data = json.load(io.open(os.path.join(HERE, cfg["german"]), encoding="utf-8"),
                     object_pairs_hook=no_duplicate_keys)
    by_func = dict((l["func"], l) for l in lists)
    result = {}
    for func, entries in sorted(data["lists"].items()):
        if func not in by_func or not by_func[func]["source_named"]:
            fail("names-de.json: unknown or unnamed list %r" % func)
        if func in cfg["cldr"]:
            fail("names-de.json: %s comes from CLDR" % func)
        codes = by_func[func]["raw_names"]
        for code, name in entries.items():
            if code not in codes:
                fail("names-de.json: %s has no code %r" % (func, code))
            if not name.strip():
                fail("names-de.json: empty name for %s %r" % (func, code))
        result[func] = dict(entries)
    for func, src in sorted(cfg["cldr"].items()):
        src_name, fname = src["file"].split("/", 1)
        doc = json.load(io.open(os.path.join(HERE, "src", src_name, fname), encoding="utf-8"))
        node = doc
        for key in src["path"]:
            node = node[key]
        codes = by_func[func]["raw_names"]
        names = result.setdefault(func, {})
        for code in codes:
            if code in names:
                fail("%s %r both in names-de.json and CLDR" % (func, code))
            value = node.get(code)
            if isinstance(value, dict):
                value = value.get(src.get("field", ""))
            if value:
                names[code] = value
    return result


def english_names(manifest, lists):
    """{func: {code: name}} from names-en.json: the names that replace the
    source's (cut off or in list form); each must differ from the source."""
    data = json.load(io.open(os.path.join(HERE, manifest["names"]["english"]), encoding="utf-8"),
                     object_pairs_hook=no_duplicate_keys)
    by_func = dict((l["func"], l) for l in lists)
    result = {}
    for func, entries in sorted(data["lists"].items()):
        if func not in by_func:
            fail("names-en.json: unknown or unnamed list %r" % func)
        codes = by_func[func]["raw_names"]
        for code, name in entries.items():
            if code not in codes:
                fail("names-en.json: %s has no code %r" % (func, code))
            if not name.strip() or name != re.sub(r"\s+", " ", name).strip():
                fail("names-en.json: empty or badly spaced name for %s %r" % (func, code))
            if name == codes[code]:
                fail("names-en.json: %s %r equals the source; remove the entry" % (func, code))
        result[func] = dict(entries)
    return result


def generate_names(manifest, lists):
    named = [l for l in lists if l["source_named"]]
    german = german_names(manifest, named)
    english = english_names(manifest, named)
    out = []
    w = out.append
    sources = "; ".join(src["title"] for _, src in sorted(manifest["sources"].items()))
    w(NAMES_HEADER % {"sources": sources, "cldr": manifest["names"]["cldr_version"]})
    for i, l in enumerate(named):
        w("    ecl_%s%s" % (l["func"], "," if i < len(named) - 1 else ""))
    w("  );")
    w("")
    w("""{ The name of ACode (ASCII case-insensitive) in AList: German if there is
  one and ALanguage is eln_German, English otherwise; '' for an unknown code.
  DE: Der Name von ACode (ASCII, ohne Unterscheidung von Gross- und
  Kleinschreibung) in AList: deutsch, wenn es einen gibt und ALanguage
  eln_German ist, sonst englisch; '' fuer einen unbekannten Code. }
function LandrixEInvoiceCodeName(AList: TLandrixEInvoiceCodeList; const ACode: TLandrixEInvoiceString;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;

implementation

type
  { De is '' where the English name stands for both }
  TCodeName = record
    Code: AnsiString;
    En: AnsiString;
    De: AnsiString;
  end;

const""")
    total = 0
    for l in named:
        raw = dict(l["raw_names"])
        raw.update(english.get(l["func"], {}))
        de = german.get(l["func"], {})
        codes = sorted(raw)
        w("  %sNames: array[0..%d] of TCodeName = (" % (l["func"], len(codes) - 1))
        for i, code in enumerate(codes):
            sep = "," if i < len(codes) - 1 else ""
            w("    (Code: %s; En: %s; De: %s)%s" % (pascal_string(code), name_literal(raw[code]),
                                                   name_literal(de.get(code, "")), sep))
        w("  );")
        w("")
        total += len(codes)
    w("""{ S with every '\\' plus four hex digits replaced by that character }
function Decoded(const S: AnsiString): TLandrixEInvoiceString;
var
  I, J, N: Integer;

  function Hex(C: AnsiChar): Integer;
  begin
    if C <= '9' then
      Result := Ord(C) - Ord('0')
    else
      Result := Ord(C) - Ord('A') + 10;
  end;

begin
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '\\' then
      Inc(I, 5)
    else
      Inc(I);
    Inc(N);
  end;
  Result := '';
  SetLength(Result, N);
  I := 1;
  J := 1;
  while I <= Length(S) do
  begin
    if S[I] = '\\' then
    begin
      Result[J] := WideChar(Hex(S[I + 1]) shl 12 + Hex(S[I + 2]) shl 8 + Hex(S[I + 3]) shl 4 + Hex(S[I + 4]));
      Inc(I, 5);
    end
    else
    begin
      Result[J] := WideChar(Ord(S[I]));
      Inc(I);
    end;
    Inc(J);
  end;
end;

{ ASCII case-insensitive; other characters must be equal }
function SameCode(const A: AnsiString; const B: TLandrixEInvoiceString): Boolean;
var
  I, X, Y: Integer;
begin
  Result := Length(A) = Length(B);
  I := 1;
  while Result and (I <= Length(A)) do
  begin
    X := Ord(A[I]);
    Y := Ord(B[I]);
    if (X >= Ord('a')) and (X <= Ord('z')) then
      Dec(X, 32);
    if (Y >= Ord('a')) and (Y <= Ord('z')) then
      Dec(Y, 32);
    Result := X = Y;
    Inc(I);
  end;
end;

function Find(const ANames: array of TCodeName; const ACode: TLandrixEInvoiceString;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  if ACode = '' then
    Exit;
  { a while loop: High of an open array is 64-bit on Win64 }
  I := 0;
  while I <= High(ANames) do
  begin
    if SameCode(ANames[I].Code, ACode) then
    begin
      if (ALanguage = eln_German) and (ANames[I].De <> '') then
        Result := Decoded(ANames[I].De)
      else
        Result := Decoded(ANames[I].En);
      Exit;
    end;
    Inc(I);
  end;
end;

function LandrixEInvoiceCodeName(AList: TLandrixEInvoiceCodeList; const ACode: TLandrixEInvoiceString;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
begin
  case AList of""")
    for i, l in enumerate(named):
        if i < len(named) - 1:
            w("    ecl_%s:" % l["func"])
            w("      Result := Find(%sNames, ACode, ALanguage);" % l["func"])
        else:
            w("  else")
            w("    Result := Find(%sNames, ACode, ALanguage);" % l["func"])
    w("  end;")
    w("end;")
    w("")
    w("end.")
    text = "\n".join(out) + "\n"
    if any(ord(c) > 127 for c in text):
        fail("non-ASCII output in the names unit")
    return text.replace("\n", "\r\n").encode("ascii"), len(named), total


def write_or_check(path, data, check, what):
    if check:
        try:
            with open(path, "rb") as f:
                current = f.read()
        except IOError:
            current = b""
        if current.replace(b"\r\n", b"\n") != data.replace(b"\r\n", b"\n"):
            sys.stderr.write("gen-codelists: %s is not up to date; run the generator\n" % path)
            return False
        print("gen-codelists: up to date: %s (%s)" % (os.path.basename(path), what))
        return True
    with open(path, "wb") as f:
        f.write(data)
    print("gen-codelists: wrote %s (%s)" % (path, what))
    return True


def main(argv):
    args = argv[1:]
    if any(a != "--check" for a in args):
        fail("unknown argument; usage: gen-codelists.py [--check]")
    check = "--check" in args
    manifest = json.load(io.open(os.path.join(HERE, "manifest.json"), encoding="utf-8"))
    lists = load(manifest)
    data = generate(manifest, lists)
    total = sum(len(l["member_list"]) - 1 for l in lists)
    names, named, name_count = generate_names(manifest, lists)
    ok = write_or_check(OUTPUT, data, check, "%d lists, %d codes" % (len(lists), total))
    ok = write_or_check(NAMES_OUTPUT, names, check, "%d lists, %d names" % (named, name_count)) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
