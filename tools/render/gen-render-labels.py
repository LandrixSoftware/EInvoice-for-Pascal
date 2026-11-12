#!/usr/bin/env python3
"""Generates source/LandrixEInvoiceRenderLabels.pas from tools/render/labels.json
and the interface of source/LandrixEInvoiceInvoice.pas: one member of
TLandrixEInvoiceRenderField per model path (fields of the root class and of the
objects and list items below it; the sub lines of a line reuse the paths of the
line), with its label in English and German, its business term, its path and
the section of the rendered page that shows it (TLandrixEInvoiceRenderSection,
from 'sections' in labels.json).

Checks (exit 2): every path ends up with a text in both languages; no stale
entry in 'fields' or 'paths'; a path whose model comment names several terms
gets its term from a 'paths' entry; a term is '' or BT-/BG- identifiers joined
with '/'; a term in 'paths' that the model comment of the field does not name
needs a reason ('why'), and a reason without such a term is an error; every
path is in exactly one section (longest matching prefix), every prefix of a
section matches a path, every section has a heading in both languages.

Usage:
  python tools/render/gen-render-labels.py           write the unit
  python tools/render/gen-render-labels.py --check   exit 1 if it differs
"""

import importlib.util
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LABELS = os.path.join(HERE, "labels.json")
OUTPUT = os.path.join(ROOT, "source", "LandrixEInvoiceRenderLabels.pas")
TERM = re.compile(r"^B[TG]-(?:X-|DEX-)?[0-9]+(?:-[0-9]+)?$")


def fail(msg):
    sys.stderr.write("gen-render-labels: " + msg + "\n")
    sys.exit(2)


def model_parser():
    spec = importlib.util.spec_from_file_location(
        "gen_invoice_compare", os.path.join(ROOT, "tools", "model", "gen-invoice-compare.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def no_duplicate_keys(pairs):
    keys = [k for k, _ in pairs]
    for k in keys:
        if keys.count(k) > 1:
            fail("labels.json: duplicate key %r" % k)
    return dict(pairs)


def model_paths(classes, lists, root):
    """[(path, class, field)] depth first; a class already on the path is not
    entered again (sub lines reuse the paths of the line)."""
    out = []

    def walk(cname, prefix, stack):
        for f in classes[cname]:
            if f["kind"] == "object":
                out.append((prefix + f["name"], cname, f))
                if f["type"] not in stack:
                    walk(f["type"], prefix + f["name"] + ".", stack + [f["type"]])
            elif f["kind"] == "list":
                item = lists[f["type"]]["item"]
                out.append((prefix + f["name"] + "[]", cname, f))
                if item not in stack:
                    walk(item, prefix + f["name"] + "[].", stack + [item])
            else:
                out.append((prefix + f["name"], cname, f))

    walk(root, "", [root])
    return out


def literal(s):
    """ASCII Pascal literal; '\\' plus four hex digits for any other character
    (decoded at run time); parts of at most 200 characters."""
    out = []
    for c in s:
        o = ord(c)
        if o > 0xFFFF:
            fail("character outside the BMP in %r" % s)
        if 32 <= o < 127 and c != "\\":
            out.append("''" if c == "'" else c)
        else:
            out.append("\\%04X" % o)
    text = "".join(out)
    parts = []
    while len(text) > 200:
        cut = 200
        while text[cut - 1] == "'" or "\\" in text[max(0, cut - 4):cut]:
            cut -= 1
        parts.append(text[:cut])
        text = text[cut:]
    parts.append(text)
    return " + ".join("'" + p + "'" for p in parts)


def member(path):
    return "erf_" + path.replace("[]", "").replace(".", "_")


SECTION_KEY = re.compile(r"^[a-z]+$")


def prefix_matches(prefix, path):
    """A prefix matches the path itself and everything below it (after '.' or
    '[]'); a prefix ending in '*' matches any path starting with the text
    before the '*'."""
    if prefix.endswith("*"):
        return path.startswith(prefix[:-1])
    return path == prefix or path.startswith(prefix + ".") or path.startswith(prefix + "[]")


def sections_of(data, paths):
    """[(key, en, de)] in page order and {path: key}; fails on a path in no
    section, a prefix without a path, two prefixes of the same length."""
    raw = data.get("sections")
    if not raw:
        fail("labels.json: 'sections' missing")
    order = []
    prefixes = []
    for key, entry in raw.items():
        if not SECTION_KEY.match(key):
            fail("labels.json: bad section key %r (lower-case letters only)" % key)
        for k in entry:
            if k not in ("en", "de", "paths"):
                fail("labels.json: unknown key %r in section %r" % (k, key))
        if not entry.get("en", "").strip() or not entry.get("de", "").strip():
            fail("labels.json: section %r needs 'en' and 'de'" % key)
        if not entry.get("paths"):
            fail("labels.json: section %r without paths" % key)
        order.append((key, entry["en"], entry["de"]))
        for prefix in entry["paths"]:
            if any(prefix == q for q, _ in prefixes):
                fail("labels.json: prefix %r in two sections" % prefix)
            prefixes.append((prefix, key))
    assigned = {}
    for path in paths:
        best = None
        for prefix, key in prefixes:
            if prefix_matches(prefix, path):
                n = len(prefix.rstrip("*"))
                if best is not None and best[0] == n:
                    fail("labels.json: path %r matches %r and %r" % (path, best[1], prefix))
                if best is None or n > best[0]:
                    best = (n, prefix, key)
        if best is None:
            fail("labels.json: path %r is in no section" % path)
        assigned[path] = best[2]
    for prefix, key in prefixes:
        if not any(prefix_matches(prefix, path) for path in paths):
            fail("labels.json: prefix %r of section %r matches no path" % (prefix, key))
    return order, assigned


def section_member(key):
    return "ers_" + key[0].upper() + key[1:]


def build():
    g = model_parser()
    classes, lists = g.parse(io.open(g.MODEL, encoding="utf-8").read())
    data = json.load(io.open(LABELS, encoding="utf-8"), object_pairs_hook=no_duplicate_keys)
    texts = data["fields"]
    overrides = data["paths"]

    wanted = set()
    for cname, fields in classes.items():
        for f in fields:
            wanted.add(cname + "." + f["name"])
    for key in texts:
        if key not in wanted:
            fail("labels.json: stale field %r" % key)
    for key in sorted(wanted):
        t = texts.get(key)
        if not t or not t.get("en", "").strip() or not t.get("de", "").strip():
            fail("labels.json: field %r needs 'en' and 'de'" % key)

    rows = []
    seen = set()
    for path, cname, f in model_paths(classes, lists, g.ROOT_CLASS):
        key = cname + "." + f["name"]
        text = dict(texts[key])
        terms = f["terms"]
        o = overrides.get(path, {})
        for k in o:
            if k not in ("bt", "en", "de", "why"):
                fail("labels.json: unknown key %r in path %r" % (k, path))
        if "en" in o:
            text["en"] = o["en"]
        if "de" in o:
            text["de"] = o["de"]
        if not text["en"].strip() or not text["de"].strip():
            fail("labels.json: path %r needs 'en' and 'de'" % path)
        if "bt" in o:
            bt = o["bt"]
            outside = [x for x in bt.split("/") if x not in terms.split("/")] if bt else []
            if outside and not o.get("why", "").strip():
                fail("labels.json: path %r: %s not in the model comment (%s); give a 'why'" %
                     (path, "/".join(outside), terms or "none"))
            if not outside and "why" in o:
                fail("labels.json: path %r: 'why' without a term outside the model comment" % path)
        else:
            if "why" in o:
                fail("labels.json: path %r: 'why' without 'bt'" % path)
            if "/" in terms:
                fail("labels.json: path %r needs a 'bt' in 'paths' (model terms %s)" % (path, terms))
            bt = terms
        if bt and not all(TERM.match(x) for x in bt.split("/")):
            fail("labels.json: bad term %r in path %r" % (bt, path))
        name = member(path)
        if name.lower() in seen:
            fail("duplicate member %s" % name)
        seen.add(name.lower())
        rows.append({"path": path, "member": name, "bt": bt, "en": text["en"], "de": text["de"]})
    known = set(r["path"] for r in rows)
    for path in overrides:
        if path not in known:
            fail("labels.json: stale path %r" % path)
    order, assigned = sections_of(data, [r["path"] for r in rows])
    for r in rows:
        r["section"] = assigned[r["path"]]
    return rows, order


HEADER = """{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ GENERATED by tools/render/gen-render-labels.py - do not edit. Change
  tools/render/labels.json (or the model) and run the generator again.

  The fields of TLandrixInvoice for rendering an invoice: one member per
  model path (the sub lines of a line use the members of the line), with a
  label in English and German (own wording, not the EN 16931 term names),
  the business term that applies on that path ('' if none; several joined
  with '/' when the content decides, e.g. allowance or charge), the path
  itself (e.g. AccountingSupplierParty.Address.City, InvoiceLines[].Quantity)
  and the section of the page that shows it.

  DE: ERZEUGT von tools/render/gen-render-labels.py - nicht von Hand aendern.
  tools/render/labels.json (oder das Modell) aendern und den Generator erneut
  ausfuehren.

  Die Felder von TLandrixInvoice fuer die Darstellung einer Rechnung: ein
  Wert je Modellpfad (die Unterpositionen einer Position nutzen die Werte der
  Position), mit einer Beschriftung englisch und deutsch (eigene
  Formulierungen, nicht die Begriffsnamen der EN 16931), dem Geschaeftsbegriff,
  der auf diesem Pfad gilt ('' wenn keiner; mehrere mit '/' verbunden, wenn
  der Inhalt entscheidet, z. B. Abschlag oder Zuschlag), dem Pfad selbst
  (z. B. AccountingSupplierParty.Address.City, InvoiceLines[].Quantity) und
  dem Abschnitt der Seite, der es zeigt. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceRenderLabels;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceReportHtml;

type
  { The sections of a rendered invoice, in page order.
    DE: Die Abschnitte einer dargestellten Rechnung, in der Reihenfolge der
    Seite. }
  TLandrixEInvoiceRenderSection = (
@SECTIONS@
  );

  { One member per model path, in model order.
    DE: Ein Wert je Modellpfad, in der Reihenfolge des Modells. }
  TLandrixEInvoiceRenderField = ("""

FUNCS = """
{ The label of AField in ALanguage.
  DE: Die Beschriftung von AField in ALanguage. }
function LandrixEInvoiceRenderFieldLabel(AField: TLandrixEInvoiceRenderField;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
{ The business term of AField (e.g. BT-37), '' if none.
  DE: Der Geschaeftsbegriff von AField (z. B. BT-37), '' wenn keiner. }
function LandrixEInvoiceRenderFieldBT(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
{ The model path of AField, e.g. InvoiceLines[].Quantity.
  DE: Der Modellpfad von AField, z. B. InvoiceLines[].Quantity. }
function LandrixEInvoiceRenderFieldPath(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
{ The section of the page that shows AField.
  DE: Der Abschnitt der Seite, der AField zeigt. }
function LandrixEInvoiceRenderFieldSection(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceRenderSection;
{ The key of ASection as the page marks it (data-section), e.g. 'parties'.
  DE: Der Schluessel von ASection, mit dem die Seite ihn kennzeichnet
  (data-section), z. B. 'parties'. }
function LandrixEInvoiceRenderSectionKey(ASection: TLandrixEInvoiceRenderSection): TLandrixEInvoiceString;
{ The heading of ASection in ALanguage.
  DE: Die Ueberschrift von ASection in ALanguage. }
function LandrixEInvoiceRenderSectionLabel(ASection: TLandrixEInvoiceRenderSection;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;

implementation
"""

DECODER = """{ S with every '\\' plus four hex digits replaced by that character }
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

function LandrixEInvoiceRenderFieldLabel(AField: TLandrixEInvoiceRenderField;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
begin
  if ALanguage = eln_German then
    Result := Decoded(LabelsDe[AField])
  else
    Result := Decoded(LabelsEn[AField]);
end;

function LandrixEInvoiceRenderFieldBT(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
begin
  Result := Decoded(Terms[AField]);
end;

function LandrixEInvoiceRenderFieldPath(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceString;
begin
  Result := Decoded(Paths[AField]);
end;

function LandrixEInvoiceRenderFieldSection(AField: TLandrixEInvoiceRenderField): TLandrixEInvoiceRenderSection;
begin
  Result := Sections[AField];
end;

function LandrixEInvoiceRenderSectionKey(ASection: TLandrixEInvoiceRenderSection): TLandrixEInvoiceString;
begin
  Result := Decoded(SectionKeys[ASection]);
end;

function LandrixEInvoiceRenderSectionLabel(ASection: TLandrixEInvoiceRenderSection;
  ALanguage: TLandrixEInvoiceReportLanguage): TLandrixEInvoiceString;
begin
  if ALanguage = eln_German then
    Result := Decoded(SectionLabelsDe[ASection])
  else
    Result := Decoded(SectionLabelsEn[ASection]);
end;

end.
"""


def generate(rows, order):
    out = [HEADER.replace("@SECTIONS@", ",\n".join("    " + section_member(k) for k, _, _ in order))]
    w = out.append
    for i, r in enumerate(rows):
        w("    %s%s" % (r["member"], "," if i < len(rows) - 1 else ""))
    w("  );")
    w(FUNCS)
    w("const")
    for name, key in (("Paths", "path"), ("Terms", "bt"), ("LabelsEn", "en"), ("LabelsDe", "de")):
        w("  %s: array[TLandrixEInvoiceRenderField] of AnsiString = (" % name)
        for i, r in enumerate(rows):
            w("    %s%s" % (literal(r[key]), "," if i < len(rows) - 1 else ""))
        w("  );")
        w("")
    w("  Sections: array[TLandrixEInvoiceRenderField] of TLandrixEInvoiceRenderSection = (")
    for i, r in enumerate(rows):
        w("    %s%s" % (section_member(r["section"]), "," if i < len(rows) - 1 else ""))
    w("  );")
    w("")
    for name, idx in (("SectionKeys", 0), ("SectionLabelsEn", 1), ("SectionLabelsDe", 2)):
        w("  %s: array[TLandrixEInvoiceRenderSection] of AnsiString = (" % name)
        for i, o in enumerate(order):
            w("    %s%s" % (literal(o[idx]), "," if i < len(order) - 1 else ""))
        w("  );")
        w("")
    w(DECODER)
    text = "\n".join(out)
    if any(ord(c) > 127 for c in text):
        fail("non-ASCII output")
    return text.replace("\r\n", "\n").replace("\n", "\r\n").encode("ascii")


def main(argv):
    args = argv[1:]
    if any(a != "--check" for a in args):
        fail("unknown argument; usage: gen-render-labels.py [--check]")
    rows, order = build()
    data = generate(rows, order)
    if "--check" in args:
        try:
            with open(OUTPUT, "rb") as f:
                current = f.read()
        except IOError:
            current = b""
        if current.replace(b"\r\n", b"\n") != data.replace(b"\r\n", b"\n"):
            sys.stderr.write("gen-render-labels: %s is not up to date; run the generator\n" % OUTPUT)
            return 1
        print("gen-render-labels: up to date (%d fields)" % len(rows))
        return 0
    with open(OUTPUT, "wb") as f:
        f.write(data)
    print("gen-render-labels: wrote %s (%d fields)" % (OUTPUT, len(rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
