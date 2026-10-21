#!/usr/bin/env python3
"""Generates the CII and UBL syntax models with their readers and writers
from tools/syntaxmodel/cii.json and ubl.json (written by extract-xsd.py):

  source/LandrixEInvoiceCII.pas         classes, value records, lists
  source/LandrixEInvoiceCIIReader.pas   LandrixEInvoiceReadCII
  source/LandrixEInvoiceCIIWriter.pas   LandrixEInvoiceWriteCII
  source/LandrixEInvoiceCIIProfiles.pas Factur-X profile per path, pruning
                                        (from cii-profiles.json)
  source/LandrixEInvoiceUBL.pas         the same for UBL Invoice and CreditNote
  source/LandrixEInvoiceUBLReader.pas   LandrixEInvoiceReadUBLInvoice/CreditNote
  source/LandrixEInvoiceUBLWriter.pas   LandrixEInvoiceWriteUBLInvoice/CreditNote

Mapping of schema types (plan, decisions on phase 1.4):
- element content           -> class TLandrixCII<Name>; children created on
                               first access (never nil), IsEmpty, Clear
- simple content, attributes -> record TLandrixCII<Name> (Value + attributes,
                               present if any field is not '')
- simple content, none       -> TLandrixEInvoiceString ('' = absent)
- one-child wrapper (DateTimeType ...) -> flattened to the record/string of
                               its only child
- repeated children          -> TLandrixCII<Name>List, repeated plain text
                               TLandrixEInvoiceStringList
All values are lexical text. Deterministic ASCII output with CRLF.

Usage:
  python tools/syntaxmodel/gen-syntaxmodel.py           write the units
  python tools/syntaxmodel/gen-syntaxmodel.py --check   exit 1 if they differ
"""

import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

SYNTAXES = [
    {
        "syn": "CII",
        "json": "cii.json",
        "source": "tools/syntaxmodel/cii.json (Factur-X 1.09.2 EXTENDED schema)",
        "source_de": "tools/syntaxmodel/cii.json (Schema Factur-X 1.09.2 EXTENDED)",
        "what": "the CII invoice",
        "what_de": "die CII-Rechnung",
        # schema type -> Pascal name without prefix
        "type_renames": {"rsm:CrossIndustryInvoiceType": "Invoice"},
        # (schema type, element name) -> Pascal name of the child
        "name_overrides": {
            ("ram:ProductClassificationType", "ClassName"): "ClassificationName",  # TObject.ClassName
        },
        # root type -> (reader function, writer procedure, writer parameter)
        "entries": {"rsm:CrossIndustryInvoiceType": ("LandrixEInvoiceReadCII", "LandrixEInvoiceWriteCII",
                                                     "AInvoice")},
        "root_prefixed": True,
        # Factur-X profiles per path (tools/fieldmap/fieldmap.py --export)
        "profiles": "cii-profiles.json",
    },
    {
        "syn": "UBL",
        "json": "ubl.json",
        "source": "tools/syntaxmodel/ubl.json (UBL 2.1 schema, reduced to\n  tools/syntaxmodel/ubl-positive.json)",
        "source_de": "tools/syntaxmodel/ubl.json (Schema UBL 2.1, beschraenkt auf\n  tools/syntaxmodel/ubl-positive.json)",
        "what": "the UBL invoice and credit note",
        "what_de": "die UBL-Rechnung und -Gutschrift",
        "type_renames": {"udt:IdentifierType": "ID"},
        "name_overrides": {},
        "entries": {"inv:InvoiceType": ("LandrixEInvoiceReadUBLInvoice", "LandrixEInvoiceWriteUBLInvoice",
                                        "AInvoice"),
                    "cn:CreditNoteType": ("LandrixEInvoiceReadUBLCreditNote",
                                          "LandrixEInvoiceWriteUBLCreditNote", "ACreditNote")},
        "root_prefixed": False,
    },
]

# set per syntax by use_syntax()
CFG = SYNTAXES[0]
PREFIX = "TLandrixCII"
# identifiers a child must not use (methods of the classes, TObject members)
RESERVED_MEMBERS = {"create", "destroy", "free", "clear", "isempty", "classname",
                    "classtype", "classinfo", "classparent", "instancesize",
                    "dispatch", "fieldaddress", "inheritsfrom", "methodaddress",
                    "methodname", "newinstance", "freeinstance", "afterconstruction",
                    "beforedestruction", "defaulthandler", "safecallexception",
                    "getinterface", "getinterfaceentry", "getinterfacetable",
                    "initinstance", "cleanupinstance", "equals", "gethashcode",
                    "tostring", "count", "items", "add", "delete"}
PASCAL_KEYWORDS = {"and", "array", "as", "asm", "begin", "case", "class", "const",
                   "constructor", "destructor", "div", "do", "downto", "else", "end",
                   "except", "exports", "file", "finalization", "finally", "for",
                   "function", "goto", "if", "implementation", "in", "inherited",
                   "initialization", "inline", "interface", "is", "label", "library",
                   "mod", "nil", "not", "object", "of", "or", "out", "packed",
                   "procedure", "program", "property", "raise", "record", "repeat",
                   "resourcestring", "set", "shl", "shr", "string", "then",
                   "threadvar", "to", "try", "type", "unit", "until", "uses", "var",
                   "while", "with", "xor", "operator", "self", "result"}

HEADER_TEMPLATE = """{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ GENERATED by tools/syntaxmodel/gen-syntaxmodel.py from
  %(source)s - do not
  edit; change the generator and run it again.
  DE: ERZEUGT von tools/syntaxmodel/gen-syntaxmodel.py aus
  %(source_de)s - nicht von
  Hand aendern; den Generator aendern und erneut ausfuehren.
"""
HEADER = ""


def use_syntax(cfg):
    global CFG, PREFIX, HEADER
    CFG = cfg
    PREFIX = "TLandrix" + cfg["syn"]
    HEADER = HEADER_TEMPLATE % {"source": cfg["source"], "source_de": cfg["source_de"]}


def syn_text(text):
    """Syntax-specific names in the shared templates (written for CII)."""
    if CFG["syn"] == "CII":
        return text
    for a, b in (("TCIIReader", "TUBLReader"), ("TCIIWriter", "TUBLWriter"),
                 ("LandrixCIINamespace", "LandrixUBLNamespace"),
                 ("LandrixEInvoiceCII", "LandrixEInvoiceUBL"),
                 ("one CII document", "one UBL document")):
        text = text.replace(a, b)
    return text


def fail(msg):
    sys.stderr.write("gen-syntaxmodel: " + msg + "\n")
    sys.exit(2)


# --------------------------------------------------------------------------
# model analysis
# --------------------------------------------------------------------------

class Model(object):
    def __init__(self, data):
        self.ns = data["namespaces"]
        self.roots = data.get("roots") or [data["root"]]
        self.skip = data.get("skip", [])
        self.types = data["types"]
        self.kind = {}       # schema type -> class | record | string | wrapper
        self.pascal = {}     # schema type -> Pascal type name (class/record)
        self.wrapped = {}    # wrapper type -> (inner child, inner kind)
        self.lexical = {}    # simple schema type -> lexical base
        self.analyse()

    def type_name(self, schema_type):
        base = schema_type.split(":", 1)[1].split("/")[0]
        if base.endswith("Type"):
            base = base[:-4]
        base = CFG["type_renames"].get(schema_type, base)
        return PREFIX + base

    def analyse(self):
        for name, t in sorted(self.types.items()):
            if "/" in name:
                continue
            if t["kind"] == "simple":
                self.lexical[name] = t["base"]
                self.kind[name] = "record" if t["attributes"] else "string"
            elif self.is_wrapper(name, t):
                self.kind[name] = "wrapper"
            else:
                self.kind[name] = "class"
        for name, t in sorted(self.types.items()):
            if "/" in name:
                self.lexical[name] = t["base"]
        # wrappers: the inner child decides the representation
        for name in sorted(self.kind):
            if self.kind[name] != "wrapper":
                continue
            child = self.types[name]["children"][0]
            ct = child["type"]
            if ct.startswith("xs:"):
                self.wrapped[name] = (child, "string", {"xs:boolean": "boolean"}.get(ct, "string"))
            else:
                inner = self.types[ct]
                if inner["kind"] != "simple":
                    fail("wrapper %s with complex child" % name)
                self.wrapped[name] = (child, "record" if inner["attributes"] else "string",
                                      inner["base"])
        seen = {}
        for name, k in self.kind.items():
            if k == "class" or k == "record" or (k == "wrapper" and self.wrapped[name][1] == "record"):
                p = self.type_name(name)
                if p.lower() in seen:
                    fail("Pascal name %s for %s and %s" % (p, name, seen[p.lower()]))
                seen[p.lower()] = name
                self.pascal[name] = p
        for k in ("class", "record"):
            for t in self.repeated_types(k):
                lp = (self.pascal[t] + "List").lower()
                if lp in seen:
                    fail("list type %sList collides with %s" % (self.pascal[t], seen[lp]))
        for name, k in self.kind.items():
            if k != "class":
                continue
            names = set()
            for c in self.types[name]["children"]:
                c["pname"] = CFG["name_overrides"].get((name, c["name"]), c["name"])
                low = c["pname"].lower()
                if low in names or low in RESERVED_MEMBERS or low in PASCAL_KEYWORDS:
                    fail("child name %s of %s not usable" % (c["pname"], name))
                names.add(low)

    @staticmethod
    def is_wrapper(name, t):
        if t["kind"] != "complex" or len(t["children"]) != 1:
            return False
        c = t["children"][0]
        return c["max"] == 1 and c["min"] == 1 and (
            c["type"].startswith("xs:") or "/" in c["type"])

    def child_kind(self, child):
        """class | record | string for a child slot (wrappers resolved)."""
        ct = child["type"]
        if ct.startswith("xs:"):
            return "string"
        k = self.kind[ct]
        if k == "wrapper":
            return self.wrapped[ct][1]
        return k

    def child_pascal(self, child):
        ct = child["type"]
        k = self.child_kind(child)
        if k == "string":
            return "TLandrixEInvoiceString"
        return self.pascal[ct]

    def record_fields(self, schema_type):
        """[(pascal field, xml attribute name, required)] of a record type."""
        if self.kind.get(schema_type) == "wrapper":
            schema_type = self.wrapped[schema_type][0]["type"]
        attrs = self.types[schema_type]["attributes"]
        return [(a["name"][0].upper() + a["name"][1:], a["name"], a["required"]) for a in attrs]

    def lexical_of(self, child):
        ct = child["type"]
        if ct.startswith("xs:"):
            return {"xs:boolean": "boolean", "xs:decimal": "decimal",
                    "xs:base64Binary": "base64"}.get(ct, "string")
        if self.kind[ct] == "wrapper":
            return self.wrapped[ct][2]
        return self.lexical[ct]

    def classes(self):
        return sorted((n for n, k in self.kind.items() if k == "class"),
                      key=lambda n: self.pascal[n])

    def records(self):
        out = {}
        for n, k in self.kind.items():
            if k == "record" or (k == "wrapper" and self.wrapped[n][1] == "record"):
                out[self.pascal[n]] = n
        return [out[p] for p in sorted(out)]

    def repeated_types(self, kind):
        out = set()
        for n in self.classes():
            for c in self.types[n]["children"]:
                if c["max"] != 1 and self.child_kind(c) == kind:
                    out.add(c["type"])
        return sorted(out, key=lambda n: self.pascal[n])

    def qname(self, child):
        return "%s:%s" % (child["ns"], child["name"])

    def uses_lexical(self, lexical):
        return any(self.lexical_of(c) == lexical for n in self.classes()
                   for c in self.types[n]["children"] if self.child_kind(c) != "class") or \
            any(self.lexical[n] == lexical for n in self.records() if n in self.lexical)

    def child_namespaces(self):
        """Prefixes used by elements below the roots (declared on the root)."""
        roots = set(r["ns"] for r in self.roots)
        used = set()
        for n in self.classes():
            for c in self.types[n]["children"]:
                used.add(c["ns"])
                if not c["type"].startswith("xs:") and self.kind.get(c["type"]) == "wrapper":
                    used.add(self.wrapped[c["type"]][0]["ns"])
        return sorted(p for p in used if p not in roots)


def doc(lines, indent):
    out = []
    for i, line in enumerate(lines):
        out.append(indent + ("{ " if i == 0 else "  ") + line)
    out[-1] += " }"
    return out


def cardinality(c):
    if c["max"] != 1:
        r = "repeated" if c["min"] == 0 else "repeated, at least %d" % c["min"]
        if c["max"] > 1:
            r += ", at most %s, not checked" % c["max"]
        return r
    return "required" if c["min"] >= 1 else "optional"


def cardinality_de(c):
    if c["max"] != 1:
        r = "wiederholbar" if c["min"] == 0 else "wiederholbar, mindestens %d" % c["min"]
        if c["max"] > 1:
            r += ", hoechstens %s, nicht geprueft" % c["max"]
        return r
    return "Pflicht" if c["min"] >= 1 else "optional"


# --------------------------------------------------------------------------
# model unit
# --------------------------------------------------------------------------

def gen_model(m):
    L = []
    w = L.append
    w(HEADER + ('''
  %(syn)s syntax model: %(what)s as object tree, one class per schema
  type with element content.''' % {"syn": CFG["syn"], "what": CFG["what"]}) + """ All values are text exactly as in the XML
  (e.g. '100.00'); typed conversion belongs to the mapping. Children are
  created on first access and never nil; an element counts as present if it
  is not empty (IsEmpty). Values with attributes are records; a record is
  present if any of its fields is not ''. Text '' means absent.

""" + ('''  DE: %(syn)s-Syntaxmodell: %(what_de)s als Objektbaum, eine Klasse je
  Schematyp mit Elementinhalt.''' % {"syn": CFG["syn"], "what_de": CFG["what_de"]}) + """ Alle Werte sind Text genau wie im XML (z. B.
  '100.00'); die typisierte Umwandlung gehoert zur Abbildung. Unterobjekte
  werden beim ersten Zugriff angelegt und sind nie nil; ein Element gilt als
  vorhanden, wenn es nicht leer ist (IsEmpty). Werte mit Attributen sind
  Records; ein Record ist vorhanden, wenn eines seiner Felder nicht '' ist.
  Text '' bedeutet nicht vorhanden. }

unit LandrixEInvoice%(syn)s;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  Contnrs,
  LandrixEInvoiceTypes;

const
  { Namespace URIs of %(syn)s. DE: Namensraum-URIs von %(syn)s. }""" % {"syn": CFG["syn"]})
    for prefix, uri in sorted(m.ns.items()):
        w("  Landrix%sNamespace%s = '%s';" % (CFG["syn"], prefix.upper(), uri))
    w("")
    w("type")
    # records
    for n in m.records():
        p = m.pascal[n]
        fields = m.record_fields(n)
        src = n if m.kind[n] != "wrapper" else "%s (flattened %s)" % (n, m.wrapped[n][0]["name"])
        L.extend(doc(["Value of %s: Value is the element text, the other fields" % src,
                      "are its attributes.",
                      "DE: Wert von %s: Value ist der Elementtext, die" % src,
                      "uebrigen Felder sind seine Attribute."], "  "))
        w("  %s = record" % p)
        w("    Value: TLandrixEInvoiceString;")
        for f, a, req in fields:
            w("    %s: TLandrixEInvoiceString; // %s%s" % (f, a, " (required)" if req else ""))
        w("  end;")
        w("")
    # forward declarations of classes
    for n in m.classes():
        w("  %s = class;" % m.pascal[n])
    w("")
    # record lists
    for n in m.repeated_types("record"):
        p = m.pascal[n]
        L.extend(doc(["List of %s values." % p, "DE: Liste von %s-Werten." % p], "  "))
        w("  %sList = class(TObject)" % p)
        w("  private")
        w("    FItems: array of %s;" % p)
        w("    FCount: TLandrixEInvoiceListIndex;")
        w("    function GetItem(Index: TLandrixEInvoiceListIndex): %s;" % p)
        w("    procedure SetItem(Index: TLandrixEInvoiceListIndex; const AValue: %s);" % p)
        w("  public")
        w("    procedure Add(const AValue: %s);" % p)
        w("    procedure Delete(Index: TLandrixEInvoiceListIndex);")
        w("    procedure Clear;")
        w("    property Count: TLandrixEInvoiceListIndex read FCount;")
        w("    property Items[Index: TLandrixEInvoiceListIndex]: %s read GetItem write SetItem; default;" % p)
        w("  end;")
        w("")
    # class lists
    for n in m.repeated_types("class"):
        p = m.pascal[n]
        L.extend(doc(["List of %s (owns its items)." % p, "DE: Liste von %s (besitzt ihre Eintraege)." % p], "  "))
        w("  %sList = class(TObjectList)" % p)
        w("  protected")
        w("    function GetItem(Index: TLandrixEInvoiceListIndex): %s;" % p)
        w("  public")
        w("    { Appends a new item and returns it. DE: Haengt einen neuen Eintrag an")
        w("      und liefert ihn. }")
        w("    function Add: %s;" % p)
        w("    property Items[Index: TLandrixEInvoiceListIndex]: %s read GetItem; default;" % p)
        w("  end;")
        w("")
    # classes
    for n in m.classes():
        p = m.pascal[n]
        children = m.types[n]["children"]
        L.extend(doc(["%s type %s." % (CFG["syn"], n), "DE: %s-Typ %s." % (CFG["syn"], n)], "  "))
        w("  %s = class(TObject)" % p)
        objs = [c for c in children if m.child_kind(c) == "class" or c["max"] != 1]
        if objs:
            w("  private")
            for c in objs:
                w("    F%s: %s;" % (c["pname"], field_type(m, c)))
            for c in objs:
                w("    function Get%s: %s;" % (c["pname"], field_type(m, c)))
        w("  public")
        for c in children:
            if c in objs:
                continue
            L.extend(doc(["%s, %s." % (m.qname(c), cardinality(c)),
                          "DE: %s, %s." % (m.qname(c), cardinality_de(c))], "    "))
            w("    %s: %s;" % (c["pname"], field_type(m, c)))
        w("    destructor Destroy; override;")
        w("    { Removes all content; child objects are freed, references to them")
        w("      become invalid. DE: Entfernt allen Inhalt; Unterobjekte werden")
        w("      freigegeben, Verweise darauf werden ungueltig. }")
        w("    procedure Clear;")
        w("    { True if nothing is set. DE: True, wenn nichts gesetzt ist. }")
        w("    function IsEmpty: Boolean;")
        w("    { Adds the qualified names of the children that are set (e.g.")
        w("      'ram:Name') to AList, in schema order; used to report content that")
        w("      a mapping does not take over.")
        w("      DE: Fuegt die qualifizierten Namen der gesetzten Kinder (z. B.")
        w("      'ram:Name') in Schema-Reihenfolge an AList an; dient dazu, Inhalt")
        w("      zu melden, den eine Abbildung nicht uebernimmt. }")
        w("    procedure ListFilledChildren(AList: TLandrixEInvoiceStringList);")
        for c in objs:
            L.extend(doc(["%s, %s (created on first access)." % (m.qname(c), cardinality(c)),
                          "DE: %s, %s (beim ersten Zugriff angelegt)." % (m.qname(c), cardinality_de(c))], "    "))
            w("    property %s: %s read Get%s;" % (c["pname"], field_type(m, c), c["pname"]))
        w("  end;")
        w("")
    w("implementation")
    w("")
    w("uses")
    w("  LandrixEInvoiceLexical;")
    w("")
    # record helpers
    for n in m.records():
        p = m.pascal[n]
        w("function %sIsEmpty(const R: %s): Boolean;" % (p[len("TLandrix"):], p))
        w("begin")
        # blank text counts as absent; attributes keep a read element alive
        # (the syntax model writes back what it read)
        cond = ["LandrixEInvoiceIsBlank(R.Value)"] + ["(R.%s = '')" % f for f, _, _ in m.record_fields(n)]
        w("  Result := " + " and ".join(cond) + ";")
        w("end;")
        w("")
        w("procedure %sClear(var R: %s);" % (p[len("TLandrix"):], p))
        w("begin")
        w("  R.Value := '';")
        for f, _, _ in m.record_fields(n):
            w("  R.%s := '';" % f)
        w("end;")
        w("")
    for n in m.repeated_types("record"):
        p = m.pascal[n]
        lp = p + "List"
        w("""function %(lp)s.GetItem(Index: TLandrixEInvoiceListIndex): %(p)s;
begin
  if (Index < 0) or (Index >= FCount) then
    raise ELandrixEInvoiceError.Create('%(lp)s index out of range');
  Result := FItems[Index];
end;

procedure %(lp)s.SetItem(Index: TLandrixEInvoiceListIndex; const AValue: %(p)s);
begin
  if (Index < 0) or (Index >= FCount) then
    raise ELandrixEInvoiceError.Create('%(lp)s index out of range');
  FItems[Index] := AValue;
end;

procedure %(lp)s.Add(const AValue: %(p)s);
begin
  if FCount = Length(FItems) then
    SetLength(FItems, FCount * 2 + 4);
  FItems[FCount] := AValue;
  Inc(FCount);
end;

procedure %(lp)s.Delete(Index: TLandrixEInvoiceListIndex);
var
  I: TLandrixEInvoiceListIndex;
begin
  if (Index < 0) or (Index >= FCount) then
    raise ELandrixEInvoiceError.Create('%(lp)s index out of range');
  for I := Index to FCount - 2 do
    FItems[I] := FItems[I + 1];
  Dec(FCount);
  %(short)sClear(FItems[FCount]);
end;

procedure %(lp)s.Clear;
begin
  FItems := nil;
  FCount := 0;
end;
""" % {"lp": lp, "p": p, "short": p[len("TLandrix"):]})
    for n in m.repeated_types("class"):
        p = m.pascal[n]
        lp = p + "List"
        w("""function %(lp)s.GetItem(Index: TLandrixEInvoiceListIndex): %(p)s;
begin
  Result := %(p)s(inherited Items[Index]);
end;

function %(lp)s.Add: %(p)s;
begin
  Result := %(p)s.Create;
  inherited Add(Result);
end;
""" % {"lp": lp, "p": p})
    for n in m.classes():
        p = m.pascal[n]
        children = m.types[n]["children"]
        objs = [c for c in children if m.child_kind(c) == "class" or c["max"] != 1]
        w("{ %s }" % p)
        w("")
        for c in objs:
            ft = field_type(m, c)
            w("function %s.Get%s: %s;" % (p, c["pname"], ft))
            w("begin")
            w("  if F%s = nil then" % c["pname"])
            w("    F%s := %s.Create;" % (c["pname"], ft))
            w("  Result := F%s;" % c["pname"])
            w("end;")
            w("")
        w("destructor %s.Destroy;" % p)
        w("begin")
        for c in objs:
            w("  F%s.Free;" % c["pname"])
        w("  inherited;")
        w("end;")
        w("")
        w("procedure %s.Clear;" % p)
        w("begin")
        for c in children:
            k = m.child_kind(c)
            if c in objs:
                w("  F%s.Free;" % c["pname"])
                w("  F%s := nil;" % c["pname"])
            elif k == "record":
                w("  %sClear(%s);" % (m.pascal[c["type"]][len("TLandrix"):], c["pname"]))
            else:
                w("  %s := '';" % c["pname"])
        w("end;")
        w("")
        w("function %s.IsEmpty: Boolean;" % p)
        w("begin")
        conds = []
        for c in children:
            k = m.child_kind(c)
            if c["max"] != 1:
                conds.append("((F%s = nil) or (F%s.Count = 0))" % (c["pname"], c["pname"]))
            elif k == "class":
                conds.append("((F%s = nil) or F%s.IsEmpty)" % (c["pname"], c["pname"]))
            elif k == "record":
                conds.append("%sIsEmpty(%s)" % (m.pascal[c["type"]][len("TLandrix"):], c["pname"]))
            else:
                conds.append("LandrixEInvoiceIsBlank(%s)" % c["pname"])
        w("  Result := " + (" and\n    ".join(conds) if conds else "True") + ";")
        w("end;")
        w("")
        w("procedure %s.ListFilledChildren(AList: TLandrixEInvoiceStringList);" % p)
        w("begin")
        for c in children:
            k = m.child_kind(c)
            if c["max"] != 1:
                cond = "(F%s <> nil) and (F%s.Count > 0)" % (c["pname"], c["pname"])
            elif k == "class":
                cond = "(F%s <> nil) and not F%s.IsEmpty" % (c["pname"], c["pname"])
            elif k == "record":
                cond = "not %sIsEmpty(%s)" % (m.pascal[c["type"]][len("TLandrix"):], c["pname"])
            else:
                cond = "not LandrixEInvoiceIsBlank(%s)" % c["pname"]
            w("  if %s then" % cond)
            w("    AList.Add('%s');" % m.qname(c))
        w("end;")
        w("")
    w("end.")
    return L


def field_type(m, c):
    k = m.child_kind(c)
    if c["max"] != 1 and k == "string":
        return "TLandrixEInvoiceStringList"
    if c["max"] != 1:
        return m.pascal[c["type"]] + "List"
    if k == "string":
        return "TLandrixEInvoiceString"
    return m.pascal[c["type"]]


# --------------------------------------------------------------------------
# reader unit
# --------------------------------------------------------------------------

READER_RUNTIME = """type
  { Reads one CII document into the model; one method per schema type. }
  TCIIReader = class(TObject)
  private
    FReader: TLandrixXmlReader;
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    procedure Report(AKind: TLandrixEInvoiceDiagnosticKind; const AMessage: TLandrixEInvoiceString);
    function IsElement(const ANamespace: TLandrixXmlUtf8; const ALocalName: TLandrixXmlUtf8): Boolean;
    procedure SkipUnknown;
    procedure SkipDuplicate;
    procedure CheckNoAttributes(AllowSchemaLocation: Boolean);
    function AttributeValue(const ALocalName: TLandrixXmlUtf8;
      const AKnown: array of TLandrixXmlUtf8): TLandrixEInvoiceString;
    function ReadLeaf(const ALexical: string): TLandrixEInvoiceString;
    procedure CheckLexical(const AValue: TLandrixEInvoiceString; const ALexical: string);
%(decls)s
  public
    constructor Create(AReader: TLandrixXmlReader; ADiagnostics: TLandrixEInvoiceDiagnostics);
  end;

constructor TCIIReader.Create(AReader: TLandrixXmlReader; ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  inherited Create;
  FReader := AReader;
  FDiagnostics := ADiagnostics;
end;

procedure TCIIReader.Report(AKind: TLandrixEInvoiceDiagnosticKind; const AMessage: TLandrixEInvoiceString);
begin
  FDiagnostics.AddDiagnostic(AKind, FReader.ElementPathW, FReader.Line, FReader.Column,
    FReader.Offset, AMessage);
end;

function TCIIReader.IsElement(const ANamespace: TLandrixXmlUtf8; const ALocalName: TLandrixXmlUtf8): Boolean;
begin
  Result := LandrixXmlSpanEquals(FReader.LocalNameSpan, ALocalName) and
    LandrixXmlSpanEquals(FReader.NamespaceUriSpan, ANamespace);
end;

procedure TCIIReader.SkipUnknown;
begin
%(skipext)s  Report(edk_UnknownElement, 'unknown element ' + FReader.NamespaceUriW + ' ' +
    FReader.LocalNameW + ' skipped');
  FReader.Skip;
end;

procedure TCIIReader.SkipDuplicate;
begin
  Report(edk_DuplicateElement, 'element ' + FReader.LocalNameW +
    ' may occur only once; the first occurrence is kept');
  FReader.Skip;
end;

{ Namespace declarations are always allowed, xsi attributes only where
  AllowSchemaLocation is set (the root element); others are reported. }
procedure TCIIReader.CheckNoAttributes(AllowSchemaLocation: Boolean);
var
  I: Integer;
begin
  for I := 0 to FReader.AttributeCount - 1 do
  begin
    if FReader.IsNamespaceDeclaration(I) then
      Continue;
    if AllowSchemaLocation and LandrixXmlSpanEquals(FReader.AttributeNamespaceUriSpan(I),
      'http://www.w3.org/2001/XMLSchema-instance') then
      Continue;
    Report(edk_UnknownAttribute, 'unknown attribute ' +
      LandrixXmlUtf8ToWide(FReader.AttributeNameUtf8(I)) + ' ignored');
  end;
end;

{ Value of the unprefixed attribute ALocalName ('' if absent). Attributes
  that are not in AKnown and not namespace declarations are reported (only
  when ALocalName is the first entry of AKnown, so each is reported once). }
function TCIIReader.AttributeValue(const ALocalName: TLandrixXmlUtf8;
  const AKnown: array of TLandrixXmlUtf8): TLandrixEInvoiceString;
var
  I, J: Integer;
  Known: Boolean;
begin
  Result := '';
  for I := 0 to FReader.AttributeCount - 1 do
  begin
    if FReader.IsNamespaceDeclaration(I) then
      Continue;
    if (FReader.AttributeNamespaceUriSpan(I).Len = 0) and
       LandrixXmlSpanEquals(FReader.AttributeLocalNameSpan(I), ALocalName) then
    begin
      Result := FReader.AttributeValueW(I);
      Continue;
    end;
    if (Length(AKnown) = 0) or (AKnown[0] <> ALocalName) then
      Continue;
    Known := False;
    if FReader.AttributeNamespaceUriSpan(I).Len = 0 then
      for J := 0 to Integer(High(AKnown)) do
        if LandrixXmlSpanEquals(FReader.AttributeLocalNameSpan(I), AKnown[J]) then
          Known := True;
    if not Known then
      Report(edk_UnknownAttribute, 'unknown attribute ' +
        LandrixXmlUtf8ToWide(FReader.AttributeNameUtf8(I)) + ' ignored');
  end;
end;

function IsXmlSpace(C: WideChar): Boolean;
begin
  Result := (C = ' ') or (C = #9) or (C = #10) or (C = #13);
end;

function TrimXml(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  First, Last: Integer;
begin
  First := 1;
  Last := Length(S);
  while (First <= Last) and IsXmlSpace(S[First]) do
    Inc(First);
  while (Last >= First) and IsXmlSpace(S[Last]) do
    Dec(Last);
  Result := Copy(S, First, Last - First + 1);
end;

function IsDecimal(const S: TLandrixEInvoiceString): Boolean;
var
  I, Digits: Integer;
  Dot: Boolean;
begin
  Result := False;
  I := 1;
  if (I <= Length(S)) and ((S[I] = '+') or (S[I] = '-')) then
    Inc(I);
  Digits := 0;
  Dot := False;
  while I <= Length(S) do
  begin
    if (S[I] >= '0') and (S[I] <= '9') then
      Inc(Digits)
    else if (S[I] = '.') and not Dot then
      Dot := True
    else
      Exit;
    Inc(I);
  end;
  Result := Digits > 0;
end;

%(datefunc)sfunction IsBase64(const S: TLandrixEInvoiceString): Boolean;
var
  U: TLandrixXmlUtf8;
  DecodedSize, BadOffset: Integer;
begin
  U := LandrixXmlWideToUtf8(S);
  Result := LandrixXmlValidateBase64Buf(PAnsiChar(U), Length(U), DecodedSize, BadOffset);
end;

procedure TCIIReader.CheckLexical(const AValue: TLandrixEInvoiceString; const ALexical: string);
var
  V: TLandrixEInvoiceString;
  Ok: Boolean;
begin
  if AValue = '' then
    Exit;
  Ok := True;
  V := TrimXml(AValue);
  if ALexical = 'decimal' then
    Ok := IsDecimal(V)
  else if ALexical = 'boolean' then
    Ok := (V = 'true') or (V = 'false') or (V = '1') or (V = '0')
  else if ALexical = 'base64' then
    Ok := IsBase64(AValue)%(datecheck)s;
  if not Ok then
    Report(edk_InvalidValue, 'value "' + AValue + '" is no valid ' +
      TLandrixEInvoiceString(ALexical) + '; kept as text');
end;

{ On a start element: returns its text (text and CDATA joined) and stops on
  its end element. Child elements are reported and skipped. }
function TCIIReader.ReadLeaf(const ALexical: string): TLandrixEInvoiceString;
begin
  Result := '';
  if FReader.IsEmptyElement then
  begin
    FReader.Read;
    Exit;
  end;
  while FReader.Read do
    case FReader.TokenType of
      xttEndElement:
        Break;
      xttStartElement:
        SkipUnknown;
      xttText, xttCData:
        Result := Result + FReader.ValueW;
    else
      ; { comments and processing instructions are skipped }
    end;
  CheckLexical(Result, ALexical);
end;
"""


DATE_FUNC = """function IsDigitRun(const S: TLandrixEInvoiceString; AFrom, ACount: Integer): Boolean;
var
  K: Integer;
begin
  Result := False;
  if AFrom + ACount - 1 > Length(S) then
    Exit;
  for K := AFrom to AFrom + ACount - 1 do
    if (S[K] < '0') or (S[K] > '9') then
      Exit;
  Result := True;
end;

{ xsd:date: [-]YYYY-MM-DD with an optional time zone (Z or +hh:mm, -hh:mm). }
function IsXsdDate(const S: TLandrixEInvoiceString): Boolean;
var
  I, N: Integer;
begin
  Result := False;
  N := Length(S);
  I := 1;
  if (N > 0) and (S[1] = '-') then
    I := 2;
  if not (IsDigitRun(S, I, 4) and (I + 4 <= N) and (S[I + 4] = '-') and
    IsDigitRun(S, I + 5, 2) and (I + 7 <= N) and (S[I + 7] = '-') and IsDigitRun(S, I + 8, 2)) then
    Exit;
  I := I + 10;
  if I > N then
    Result := True
  else if S[I] = 'Z' then
    Result := I = N
  else
    Result := ((S[I] = '+') or (S[I] = '-')) and (N = I + 5) and IsDigitRun(S, I + 1, 2) and
      (S[I + 3] = ':') and IsDigitRun(S, I + 4, 2);
end;

"""


CII_READER_DECL = """{ Reads a CII invoice. AReader must be loaded and positioned before the root
  element (e.g. directly after LoadFromStream); it is read to the end of the
  document. Diagnostics are added to ADiagnostics (nil: discarded). Raises
  ELandrixEInvoiceError if the root element is not rsm:CrossIndustryInvoice,
  ELandrixXmlError for XML that is not well-formed. The caller frees the
  result.
  DE: Liest eine CII-Rechnung. AReader muss geladen sein und vor dem
  Wurzelelement stehen (z. B. direkt nach LoadFromStream); er wird bis zum
  Dokumentende gelesen. Meldungen kommen in ADiagnostics (nil: verworfen).
  Loest ELandrixEInvoiceError aus, wenn das Wurzelelement nicht
  rsm:CrossIndustryInvoice ist, ELandrixXmlError bei nicht wohlgeformtem
  XML. Der Aufrufer gibt das Ergebnis frei. }
function LandrixEInvoiceReadCII(AReader: TLandrixXmlReader;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixCIIInvoice;

"""

MOVE_TO_ROOT_MULTI = """{ Moves to the root element and checks its name; raises otherwise. }
procedure MoveToRoot(AReader: TLandrixXmlReader; const ALocalName, ANamespace: TLandrixXmlUtf8);
begin
  while AReader.TokenType <> xttStartElement do
    if not AReader.Read then
      raise ELandrixEInvoiceError.Create('No root element');
  if not (LandrixXmlSpanEquals(AReader.LocalNameSpan, ALocalName) and
    LandrixXmlSpanEquals(AReader.NamespaceUriSpan, ANamespace)) then
    raise ELandrixEInvoiceError.Create('Root element ' + AReader.ElementPath +
      ' is not ' + LandrixXmlUtf8ToString(ALocalName) + ' in ' +
      LandrixXmlUtf8ToString(ANamespace));
end;
"""


def reader_entry_decl(m, r):
    fn = CFG["entries"][r["type"]][0]
    rp = m.pascal[r["type"]]
    if len(m.roots) == 1:
        return CII_READER_DECL[:-1]
    return """{ Reads a %(syn)s %(name)s (root element %(name)s in namespace
  %(uri)s).
  AReader must be loaded and positioned before the root element (e.g.
  directly after LoadFromStream); it is read to the end of the document.
  Diagnostics are added to ADiagnostics (nil: discarded). Raises
  ELandrixEInvoiceError if the root element is a different one,
  ELandrixXmlError for XML that is not well-formed. The caller frees the
  result.
  DE: Liest ein %(syn)s-Dokument %(name)s (Wurzelelement %(name)s im
  Namensraum
  %(uri)s).
  AReader muss geladen sein und vor dem Wurzelelement
  stehen (z. B. direkt nach LoadFromStream); er wird bis zum Dokumentende
  gelesen. Meldungen kommen in ADiagnostics (nil: verworfen). Loest
  ELandrixEInvoiceError aus, wenn das Wurzelelement ein anderes ist,
  ELandrixXmlError bei nicht wohlgeformtem XML. Der Aufrufer gibt das
  Ergebnis frei. }
function %(fn)s(AReader: TLandrixXmlReader;
  ADiagnostics: TLandrixEInvoiceDiagnostics): %(rp)s;
""" % {"syn": CFG["syn"], "name": r["name"], "uri": m.ns[r["ns"]], "fn": fn, "rp": rp}


def reader_entry_impl(m, r):
    fn = CFG["entries"][r["type"]][0]
    rp = m.pascal[r["type"]]
    return """function %(fn)s(AReader: TLandrixXmlReader;
  ADiagnostics: TLandrixEInvoiceDiagnostics): %(rp)s;
var
  Own: TLandrixEInvoiceDiagnostics;
  R: T%(syn)sReader;
begin
  MoveToRoot(AReader, '%(name)s', NS_%(ns)s);
  Own := nil;
  if ADiagnostics = nil then
  begin
    Own := TLandrixEInvoiceDiagnostics.Create;
    ADiagnostics := Own;
  end;
  try
    R := T%(syn)sReader.Create(AReader, ADiagnostics);
    try
      Result := %(rp)s.Create;
      try
        R.Read%(short)s(Result, True);
        { the rest (comments, processing instructions) must be well-formed too }
        while AReader.Read do
          ;
      except
        Result.Free;
        raise;
      end;
    finally
      R.Free;
    end;
  finally
    Own.Free;
  end;
end;
""" % {"fn": fn, "rp": rp, "syn": CFG["syn"], "name": r["name"], "ns": r["ns"].upper(),
       "short": rp[len(PREFIX):]}


def gen_reader(m):
    L = []
    w = L.append
    w(HEADER + """
  Reader of the %(syn)s syntax model on the LandrixXml pull reader: recursive
  descent with one method per schema type, children recognized by namespace
  URI and local name only (order does not matter). Unknown elements, second
  occurrences of single elements, unknown attributes, unexpected text and
  invalid values are reported in the diagnostics and skipped or kept as
  text; reading continues.

  DE: Leser des %(syn)s-Syntaxmodells auf dem Pull-Reader von LandrixXml:
  rekursiver Abstieg mit einer Methode je Schematyp, Unterelemente werden
  nur an Namensraum-URI und lokalem Namen erkannt (die Reihenfolge spielt
  keine Rolle). Unbekannte Elemente, weitere Vorkommen von Einzelelementen,
  unbekannte Attribute, unerwarteter Text und ungueltige Werte werden in den
  Meldungen festgehalten und uebersprungen bzw. als Text behalten; das Lesen
  geht weiter. }

unit LandrixEInvoice%(syn)sReader;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixXmlReader,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoice%(syn)s;
""" % {"syn": CFG["syn"]})
    for r in m.roots:
        w(reader_entry_decl(m, r))
    w("""implementation

uses
  LandrixXmlBase,
  LandrixEInvoiceTypes;

const""")
    for prefix, uri in sorted(m.ns.items()):
        w("  NS_%s = '%s';" % (prefix.upper(), uri))
    w("")
    decls = []
    for n in m.classes():
        decls.append("    procedure Read%s(AObject: %s; AIsRoot: Boolean);" % (m.pascal[n][len(PREFIX):], m.pascal[n]))
    for n in m.records():
        decls.append("    procedure Read%s(var AValue: %s);" % (m.pascal[n][len(PREFIX):], m.pascal[n]))
    wrappers_str = sorted((n for n in m.kind if m.kind[n] == "wrapper" and m.wrapped[n][1] == "string"))
    for n in wrappers_str:
        decls.append("    function ReadWrapped%s: TLandrixEInvoiceString;" % n.split(":")[1].replace("/", "_"))
    for t in m.repeated_types("record"):
        fields = "; ".join(["Value: ''"] + ["%s: ''" % f for f, _, _ in m.record_fields(t)])
        w("  Empty%s: %s = (%s);" % (m.pascal[t][len(PREFIX):], m.pascal[t], fields))
    w("")
    skipext = ""
    for sk in m.skip:
        skipext += ("  if IsElement(NS_%s, '%s') then\n"
                    "  begin\n"
                    "    Report(edk_SkippedExtension, 'extension block ' + FReader.LocalNameW +\n"
                    "      ' skipped (not kept, never written)');\n"
                    "    FReader.Skip;\n"
                    "    Exit;\n"
                    "  end;\n") % (sk["ns"].upper(), sk["name"])
    uses_date = m.uses_lexical("date")
    L.extend(syn_text(READER_RUNTIME % {
        "decls": "\n".join(decls),
        "skipext": skipext,
        "datefunc": DATE_FUNC if uses_date else "",
        "datecheck": "\n  else if ALexical = 'date' then\n    Ok := IsXsdDate(V)" if uses_date else "",
    }).split("\n"))
    # record readers
    for n in m.records():
        p = m.pascal[n]
        fields = m.record_fields(n)
        known = ", ".join("'%s'" % a for _, a, _ in fields)
        w("procedure TCIIReader.Read%s(var AValue: %s);" % (p[len(PREFIX):], p))
        if m.kind[n] == "wrapper":
            inner, _, lex = m.wrapped[n]
            w("var")
            w("  Seen: Boolean;")
            w("begin")
            w("  CheckNoAttributes(False);")
            w("  Seen := False;")
            w("  if FReader.IsEmptyElement then")
            w("  begin")
            w("    FReader.Read;")
            w("    Exit;")
            w("  end;")
            w("  while FReader.Read do")
            w("    case FReader.TokenType of")
            w("      xttEndElement:")
            w("        Break;")
            w("      xttStartElement:")
            w("        if IsElement(NS_%s, '%s') then" % (inner["ns"].upper(), inner["name"]))
            w("        begin")
            w("          if Seen then")
            w("            SkipDuplicate")
            w("          else")
            w("          begin")
            w("            Seen := True;")
            for f, a, _ in fields:
                w("            AValue.%s := AttributeValue('%s', [%s]);" % (f, a, known))
            w("            AValue.Value := ReadLeaf('%s');" % lex)
            w("          end;")
            w("        end")
            w("        else")
            w("          SkipUnknown;")
            w("      xttText, xttCData:")
            w("        if not FReader.IsWhitespace then")
            w("          Report(edk_UnexpectedText, 'unexpected text ignored');")
            w("    else")
            w("      ; { comments and processing instructions are skipped }")
            w("    end;")
            w("end;")
        else:
            w("begin")
            for f, a, _ in fields:
                w("  AValue.%s := AttributeValue('%s', [%s]);" % (f, a, known))
            w("  AValue.Value := ReadLeaf('%s');" % m.lexical[n])
            w("end;")
        w("")
    for n in wrappers_str:
        inner, _, lex = m.wrapped[n]
        w("function TCIIReader.ReadWrapped%s: TLandrixEInvoiceString;" % n.split(":")[1].replace("/", "_"))
        w("var")
        w("  Seen: Boolean;")
        w("begin")
        w("  Result := '';")
        w("  CheckNoAttributes(False);")
        w("  Seen := False;")
        w("  if FReader.IsEmptyElement then")
        w("  begin")
        w("    FReader.Read;")
        w("    Exit;")
        w("  end;")
        w("  while FReader.Read do")
        w("    case FReader.TokenType of")
        w("      xttEndElement:")
        w("        Break;")
        w("      xttStartElement:")
        w("        if IsElement(NS_%s, '%s') then" % (inner["ns"].upper(), inner["name"]))
        w("        begin")
        w("          if Seen then")
        w("            SkipDuplicate")
        w("          else")
        w("          begin")
        w("            Seen := True;")
        w("            CheckNoAttributes(False);")
        w("            Result := ReadLeaf('%s');" % lex)
        w("          end;")
        w("        end")
        w("        else")
        w("          SkipUnknown;")
        w("      xttText, xttCData:")
        w("        if not FReader.IsWhitespace then")
        w("          Report(edk_UnexpectedText, 'unexpected text ignored');")
        w("    else")
        w("      ; { comments and processing instructions are skipped }")
        w("    end;")
        w("end;")
        w("")
    # class readers
    for n in m.classes():
        p = m.pascal[n]
        children = m.types[n]["children"]
        singles = [c for c in children if c["max"] == 1]
        w("procedure TCIIReader.Read%s(AObject: %s; AIsRoot: Boolean);" % (p[len(PREFIX):], p))
        var_lines = []
        if singles:
            var_lines.append("  Seen: array[0..%d] of Boolean;" % max(len(children) - 1, 0))
            var_lines.append("  I: Integer;")
        for t in sorted(set(c["type"] for c in children if m.child_kind(c) == "record" and c["max"] != 1)):
            var_lines.append("  Rec%s: %s;" % (m.pascal[t][len(PREFIX):], m.pascal[t]))
        if var_lines:
            w("var")
            L.extend(var_lines)
        w("begin")
        if singles:
            w("  for I := Low(Seen) to High(Seen) do")
            w("    Seen[I] := False;")
        w("  CheckNoAttributes(AIsRoot);")
        w("  if FReader.IsEmptyElement then")
        w("  begin")
        w("    FReader.Read;")
        w("    Exit;")
        w("  end;")
        w("  while FReader.Read do")
        w("    case FReader.TokenType of")
        w("      xttEndElement:")
        w("        Break;")
        w("      xttStartElement:")
        first = True
        for i, c in enumerate(children):
            k = m.child_kind(c)
            ct = c["type"]
            cond = "IsElement(NS_%s, '%s')" % (c["ns"].upper(), c["name"])
            w("        %sif %s then" % ("" if first else "else ", cond))
            first = False
            w("        begin")
            if c["max"] == 1:
                w("          if Seen[%d] then" % i)
                w("            SkipDuplicate")
                w("          else")
                w("          begin")
                w("            Seen[%d] := True;" % i)
                ind = "            "
            else:
                ind = "          "
            if k == "class":
                if c["max"] == 1:
                    w(ind + "Read%s(AObject.%s, False);" % (m.pascal[ct][len(PREFIX):], c["pname"]))
                else:
                    w(ind + "Read%s(AObject.%s.Add, False);" % (m.pascal[ct][len(PREFIX):], c["pname"]))
            elif k == "record":
                if c["max"] == 1:
                    w(ind + "Read%s(AObject.%s);" % (m.pascal[ct][len(PREFIX):], c["pname"]))
                else:
                    rn = "Rec%s" % m.pascal[ct][len(PREFIX):]
                    w(ind + "%s := Empty%s;" % (rn, m.pascal[ct][len(PREFIX):]))
                    w(ind + "Read%s(%s);" % (m.pascal[ct][len(PREFIX):], rn))
                    w(ind + "AObject.%s.Add(%s);" % (c["pname"], rn))
            else:
                if not ct.startswith("xs:") and m.kind[ct] == "wrapper":
                    w(ind + "AObject.%s := ReadWrapped%s;" % (c["pname"], ct.split(":")[1].replace("/", "_")))
                elif c["max"] != 1:
                    w(ind + "CheckNoAttributes(False);")
                    w(ind + "AObject.%s.Add(ReadLeaf('%s'));" % (c["pname"], m.lexical_of(c)))
                else:
                    w(ind + "CheckNoAttributes(False);")
                    w(ind + "AObject.%s := ReadLeaf('%s');" % (c["pname"], m.lexical_of(c)))
            if c["max"] == 1:
                w("          end;")
            w("        end")
        if children:
            w("        else")
            w("          SkipUnknown;")
        else:
            w("        SkipUnknown;")
        w("      xttText, xttCData:")
        w("        if not FReader.IsWhitespace then")
        w("          Report(edk_UnexpectedText, 'unexpected text ignored');")
        w("    else")
        w("      ; { comments and processing instructions are skipped }")
        w("    end;")
        w("end;")
        w("")
    if len(m.roots) == 1:
        root = m.roots[0]
        rp = m.pascal[root["type"]]
        w("""{ Moves to the root element and checks its name; raises otherwise. }
procedure MoveToRoot(AReader: TLandrixXmlReader);
begin
  while AReader.TokenType <> xttStartElement do
    if not AReader.Read then
      raise ELandrixEInvoiceError.Create('No root element');
  if not (LandrixXmlSpanEquals(AReader.LocalNameSpan, '%(name)s') and
    LandrixXmlSpanEquals(AReader.NamespaceUriSpan, NS_%(ns)s)) then
    raise ELandrixEInvoiceError.Create('Root element ' + AReader.ElementPath +
      ' is not %(ns_lower)s:%(name)s');
end;

function LandrixEInvoiceReadCII(AReader: TLandrixXmlReader;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixCIIInvoice;
var
  Own: TLandrixEInvoiceDiagnostics;
  R: TCIIReader;
begin
  MoveToRoot(AReader);
  Own := nil;
  if ADiagnostics = nil then
  begin
    Own := TLandrixEInvoiceDiagnostics.Create;
    ADiagnostics := Own;
  end;
  try
    R := TCIIReader.Create(AReader, ADiagnostics);
    try
      Result := %(rp)s.Create;
      try
        R.Read%(short)s(Result, True);
        { the rest (comments, processing instructions) must be well-formed too }
        while AReader.Read do
          ;
      except
        Result.Free;
        raise;
      end;
    finally
      R.Free;
    end;
  finally
    Own.Free;
  end;
end;

end.""" % {"name": root["name"], "ns": root["ns"].upper(), "ns_lower": root["ns"], "rp": rp,
               "short": rp[len(PREFIX):]})
    else:
        w(MOVE_TO_ROOT_MULTI)
        for r in m.roots:
            w(reader_entry_impl(m, r))
        w("end.")
    return L


# --------------------------------------------------------------------------
# writer unit
# --------------------------------------------------------------------------

def profile_required(m):
    """Children and attributes the schema leaves optional but a Factur-X
    profile requires below their parent (cii-profiles.json, fourth column):
    ({(parent type, qname)}, {(record type, attribute)}). Empty for UBL."""
    elems, attrs = set(), set()
    if not CFG.get("profiles"):
        return elems, attrs
    data = json.load(io.open(os.path.join(HERE, CFG["profiles"]), encoding="utf-8"))
    root = m.roots[0]
    top = "/%s:%s" % (root["ns"], root["name"])
    for row in data["paths"]:
        path, here = row[0], row[3]
        if not here or not path.startswith(top + "/"):
            continue
        t = root["type"]
        segs = path[len(top) + 1:].split("/")
        for i, seg in enumerate(segs):
            last = i == len(segs) - 1
            if seg.startswith("@"):
                if last and t in m.pascal and m.kind.get(t) != "class":
                    for _, a, req in m.record_fields(t):
                        if a == seg[1:] and not req:
                            attrs.add((t, a))
                t = None
                break
            if m.kind.get(t) == "wrapper" and m.qname(m.wrapped[t][0]) == seg:
                continue
            if m.kind.get(t) != "class":
                t = None
                break
            child = None
            for c in m.types[t]["children"]:
                if m.qname(c) == seg:
                    child = c
            if child is None:
                t = None
                break
            if last and child["min"] == 0:
                elems.add((t, seg))
            t = child["type"]
    return elems, attrs


def writer_needs_path(m):
    """Schema types whose Write method uses APath: required children or
    attributes (by the schema or a Factur-X profile), or children whose
    methods need it."""
    memo = {}
    elems, attrs = profile_required(m)

    def needs(t):
        if t in memo:
            return memo[t]
        memo[t] = False
        if m.kind.get(t) == "class":
            r = False
            for c in m.types[t]["children"]:
                k = m.child_kind(c)
                # a required single object is always written, it reports nothing itself
                if (c["min"] >= 1 and not (k == "class" and c["max"] == 1)) or (t, m.qname(c)) in elems:
                    r = True
                elif k in ("class", "record") and needs(c["type"]):
                    r = True
        elif t in m.pascal:
            r = any(req or (t, a) in attrs for _, a, req in m.record_fields(t))
        else:
            r = False
        memo[t] = r
        return r
    return set(t for t in list(m.kind) if needs(t))


CII_WRITER_HEAD = """
  Writer of the CII syntax model on the LandrixXml streaming writer: schema
  order, only set values (text '' and empty optional objects are not
  written; required objects are written even when empty, which the schema
  allows when their type has no required content), the prefixes rsm, ram,
  qdt and udt declared once on the root element. Missing required values,
  elements and attributes are reported in the diagnostics, nothing is
  invented; checks per target specification belong to the caller.

  DE: Schreiber des CII-Syntaxmodells auf dem Streaming-Writer von
  LandrixXml: Schema-Reihenfolge, nur gesetzte Werte (Text '' und leere
  optionale Objekte werden nicht geschrieben; Pflichtobjekte auch leer, was
  das Schema erlaubt, wenn ihr Typ keinen Pflichtinhalt hat), die Praefixe
  rsm, ram, qdt und udt einmal am Wurzelelement deklariert. Fehlende
  Pflichtwerte, -elemente und -attribute werden in den Meldungen
  festgehalten, nichts wird erfunden; Pruefungen je Zielspezifikation
  gehoeren zum Aufrufer. }

"""

UBL_WRITER_HEAD = """
  Writer of the UBL syntax model on the LandrixXml streaming writer: schema
  order, only set values (text '' and empty optional objects are not
  written; required objects are written even when empty, which the schema
  allows when their type has no required content), the root element in its
  default namespace and the prefixes cac and cbc declared once on it.
  Missing required values, elements and attributes are reported in the
  diagnostics, nothing is invented; checks per target specification belong
  to the caller.

  DE: Schreiber des UBL-Syntaxmodells auf dem Streaming-Writer von
  LandrixXml: Schema-Reihenfolge, nur gesetzte Werte (Text '' und leere
  optionale Objekte werden nicht geschrieben; Pflichtobjekte auch leer, was
  das Schema erlaubt, wenn ihr Typ keinen Pflichtinhalt hat), das
  Wurzelelement in seinem Standard-Namensraum, die Praefixe cac und cbc
  einmal daran deklariert. Fehlende Pflichtwerte, -elemente und -attribute
  werden in den Meldungen festgehalten, nichts wird erfunden; Pruefungen je
  Zielspezifikation gehoeren zum Aufrufer. }

"""

CII_WRITER_DECL = """{ Writes AInvoice (not nil) as root element to AWriter (the writer writes
  the XML declaration itself; call AWriter.EndDocument afterwards).
  Diagnostics are added to ADiagnostics (nil: discarded). A missing
  required element or attribute is reported only if the Factur-X profile
  AProfile contains it (LandrixEInvoiceCIIAllowed); the default
  epr_Extended reports everything the EXTENDED schema requires.
  DE: Schreibt AInvoice (nicht nil) als Wurzelelement nach AWriter (die
  XML-Deklaration schreibt der Writer selbst; danach AWriter.EndDocument
  aufrufen). Meldungen kommen in ADiagnostics (nil: verworfen). Ein
  fehlendes Pflichtelement oder -attribut wird nur gemeldet, wenn das
  Factur-X-Profil AProfile es enthaelt (LandrixEInvoiceCIIAllowed); die
  Vorgabe epr_Extended meldet alles, was das EXTENDED-Schema verlangt. }
procedure LandrixEInvoiceWriteCII(AInvoice: TLandrixCIIInvoice; AWriter: TLandrixXmlWriter;
  ADiagnostics: TLandrixEInvoiceDiagnostics; AProfile: TLandrixEInvoiceProfile = epr_Extended);
"""


def writer_entry_decl(m, r):
    fn, wn, par = CFG["entries"][r["type"]]
    if len(m.roots) == 1:
        return CII_WRITER_DECL
    return """{ Writes %(par)s (not nil) as root element %(name)s to AWriter (the writer
  writes the XML declaration itself; call AWriter.EndDocument afterwards).
  Diagnostics are added to ADiagnostics (nil: discarded).
  DE: Schreibt %(par)s (nicht nil) als Wurzelelement %(name)s nach AWriter
  (die XML-Deklaration schreibt der Writer selbst; danach
  AWriter.EndDocument aufrufen). Meldungen kommen in ADiagnostics (nil:
  verworfen). }
procedure %(wn)s(%(par)s: %(rp)s; AWriter: TLandrixXmlWriter;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
""" % {"par": par, "name": r["name"], "wn": wn, "rp": m.pascal[r["type"]]}


def writer_entry_impl(m, r, np, w):
    fn, wn, par = CFG["entries"][r["type"]]
    rp = m.pascal[r["type"]]
    syn = CFG["syn"]
    w("procedure %s(%s: %s; AWriter: TLandrixXmlWriter;" % (wn, par, rp))
    if CFG["syn"] == "CII":
        w("  ADiagnostics: TLandrixEInvoiceDiagnostics; AProfile: TLandrixEInvoiceProfile);")
    else:
        w("  ADiagnostics: TLandrixEInvoiceDiagnostics);")
    w("var")
    w("  Own: TLandrixEInvoiceDiagnostics;")
    w("  W: T%sWriter;" % syn)
    w("begin")
    w("  Own := nil;")
    w("  W := nil;")
    w("  try")
    w("    if ADiagnostics = nil then")
    w("    begin")
    w("      Own := TLandrixEInvoiceDiagnostics.Create;")
    w("      ADiagnostics := Own;")
    w("    end;")
    w("    W := T%sWriter.Create(AWriter, ADiagnostics%s);" % (syn, ", AProfile" if syn == "CII" else ""))
    if CFG["root_prefixed"]:
        w("    AWriter.StartElementNs(Landrix%sNamespace%s, '%s', '%s');" % (syn, r["ns"].upper(), r["ns"], r["name"]))
        path = "/%s:%s" % (r["ns"], r["name"])
    else:
        w("    AWriter.StartElementNs(Landrix%sNamespace%s, '', '%s');" % (syn, r["ns"].upper(), r["name"]))
        path = "/%s" % r["name"]
    for prefix in m.child_namespaces():
        w("    AWriter.DeclareNamespace('%s', Landrix%sNamespace%s);" % (prefix, syn, prefix.upper()))
    w("    W.Write%s(%s%s);" % (rp[len(PREFIX):], par, (", '%s'" % path) if r["type"] in np else ""))
    w("    AWriter.EndElement;")
    w("  finally")
    w("    W.Free;")
    w("    Own.Free;")
    w("  end;")
    w("end;")
    w("")


def gen_writer(m):
    L = []
    w = L.append
    np = writer_needs_path(m)
    elems, attrs = profile_required(m)
    cii = CFG["syn"] == "CII"
    w(HEADER + (CII_WRITER_HEAD if cii else UBL_WRITER_HEAD) + """unit LandrixEInvoice%(syn)sWriter;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixXmlWriter,
%(types)s  LandrixEInvoiceDiagnostics,
  LandrixEInvoice%(syn)s;
""" % {"syn": CFG["syn"], "types": "  LandrixEInvoiceTypes," + chr(10) if cii else ""})
    for r in m.roots:
        w(writer_entry_decl(m, r))
    if cii:
        w("""implementation

uses
  LandrixXmlBase,
  LandrixEInvoiceLexical,
  LandrixEInvoiceCIIProfiles;

type
  TCIIWriter = class(TObject)
  private
    FWriter: TLandrixXmlWriter;
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FProfile: TLandrixEInvoiceProfile;
    procedure Missing(const APath: TLandrixEInvoiceString);
    procedure MissingInProfile(const APath: TLandrixEInvoiceString);""")
    else:
        w("""implementation

uses
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceLexical;

type
  TCIIWriter = class(TObject)
  private
    FWriter: TLandrixXmlWriter;
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    procedure Missing(const APath: TLandrixEInvoiceString);""")
    for n in m.classes():
        w("    procedure Write%s(AObject: %s%s);" % (m.pascal[n][len(PREFIX):], m.pascal[n],
                                                  "; const APath: TLandrixEInvoiceString" if n in np else ""))
    for n in m.records():
        w("    procedure Write%s(const AQName: TLandrixXmlUtf8; const AValue: %s%s);" % (
            m.pascal[n][len(PREFIX):], m.pascal[n], "; const APath: TLandrixEInvoiceString" if n in np else ""))
    if cii:
        w("""  public
    constructor Create(AWriter: TLandrixXmlWriter; ADiagnostics: TLandrixEInvoiceDiagnostics;
      AProfile: TLandrixEInvoiceProfile);
  end;

constructor TCIIWriter.Create(AWriter: TLandrixXmlWriter; ADiagnostics: TLandrixEInvoiceDiagnostics;
  AProfile: TLandrixEInvoiceProfile);
begin
  inherited Create;
  FWriter := AWriter;
  FDiagnostics := ADiagnostics;
  FProfile := AProfile;
end;

{ only what the target profile contains is reported }
procedure TCIIWriter.Missing(const APath: TLandrixEInvoiceString);
begin
  if LandrixEInvoiceCIIAllowed(APath, FProfile) then
    FDiagnostics.AddDiagnostic(edk_MissingElement, APath, 0, 0, 0, 'required element or attribute missing');
end;

{ optional in the schema, required by the Factur-X profile below its parent
  DE: im Schema optional, im Factur-X-Profil unter seinem Elternelement
  Pflicht }
procedure TCIIWriter.MissingInProfile(const APath: TLandrixEInvoiceString);
begin
  if LandrixEInvoiceCIIRequiredBelowParent(APath, FProfile) then
    FDiagnostics.AddDiagnostic(edk_MissingElement, APath, 0, 0, 0, 'element or attribute required by the ' +
      'profile missing');
end;
""")
    else:
        w("""  public
    constructor Create(AWriter: TLandrixXmlWriter; ADiagnostics: TLandrixEInvoiceDiagnostics);
  end;

constructor TCIIWriter.Create(AWriter: TLandrixXmlWriter; ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  inherited Create;
  FWriter := AWriter;
  FDiagnostics := ADiagnostics;
end;

procedure TCIIWriter.Missing(const APath: TLandrixEInvoiceString);
begin
  FDiagnostics.AddDiagnostic(edk_MissingElement, APath, 0, 0, 0, 'required element or attribute missing');
end;
""")
    for n in m.records():
        p = m.pascal[n]
        w("function %sIsEmpty(const R: %s): Boolean;" % (p[len("TLandrix"):], p))
        w("begin")
        # blank text counts as absent; attributes keep a read element alive
        # (the syntax model writes back what it read)
        cond = ["LandrixEInvoiceIsBlank(R.Value)"] + ["(R.%s = '')" % f for f, _, _ in m.record_fields(n)]
        w("  Result := " + " and ".join(cond) + ";")
        w("end;")
        w("")
    for n in m.records():
        p = m.pascal[n]
        fields = m.record_fields(n)
        w("procedure TCIIWriter.Write%s(const AQName: TLandrixXmlUtf8; const AValue: %s%s);" % (
            p[len(PREFIX):], p, "; const APath: TLandrixEInvoiceString" if n in np else ""))
        w("begin")
        if m.kind[n] == "wrapper":
            inner = m.wrapped[n][0]
            w("  FWriter.StartElement(AQName);")
            w("  FWriter.StartElement('%s:%s');" % (inner["ns"], inner["name"]))
            path_inner = "APath + '/%s:%s'" % (inner["ns"], inner["name"])
        else:
            w("  FWriter.StartElement(AQName);")
            path_inner = "APath"
        for f, a, req in fields:
            w("  if AValue.%s <> '' then" % f)
            w("    FWriter.AttributeW('%s', AValue.%s)" % (a, f))
            if req:
                w("  else")
                w("    Missing(%s + '/@%s')" % (path_inner, a))
            elif (n, a) in attrs:
                w("  else")
                w("    MissingInProfile(%s + '/@%s')" % (path_inner, a))
            w("  ;")
        w("  if not LandrixEInvoiceIsBlank(AValue.Value) then")
        w("    FWriter.TextW(AValue.Value);")
        if m.kind[n] == "wrapper":
            w("  FWriter.EndElement;")
        w("  FWriter.EndElement;")
        w("end;")
        w("")
    for n in m.classes():
        p = m.pascal[n]
        children = m.types[n]["children"]
        w("procedure TCIIWriter.Write%s(AObject: %s%s);" % (p[len(PREFIX):], p,
                                                          "; const APath: TLandrixEInvoiceString" if n in np else ""))
        needs_i = any(c["max"] != 1 for c in children)
        if needs_i:
            w("var")
            w("  I: TLandrixEInvoiceListIndex;")
        w("begin")
        for c in children:
            k = m.child_kind(c)
            ct = c["type"]
            q = m.qname(c)
            cpath = "APath + '/%s'" % q
            short = m.pascal[ct][len(PREFIX):] if ct in m.pascal else ""
            if k == "class":
                if c["max"] == 1 and c["min"] >= 1:
                    # required: written even when empty (valid when the type has
                    # no required content; otherwise the method reports it)
                    w("  FWriter.StartElement('%s');" % q)
                    w("  Write%s(AObject.%s%s);" % (short, c["pname"], (", " + cpath) if ct in np else ""))
                    w("  FWriter.EndElement;")
                elif c["max"] == 1:
                    w("  if not AObject.%s.IsEmpty then" % c["pname"])
                    w("  begin")
                    w("    FWriter.StartElement('%s');" % q)
                    w("    Write%s(AObject.%s%s);" % (short, c["pname"], (", " + cpath) if ct in np else ""))
                    w("    FWriter.EndElement;")
                    w("  end")
                    if c["min"] >= 1:
                        w("  else")
                        w("    Missing(%s)" % cpath)
                    elif (n, q) in elems:
                        w("  else")
                        w("    MissingInProfile(%s)" % cpath)
                    w("  ;")
                else:
                    w("  for I := 0 to AObject.%s.Count - 1 do" % c["pname"])
                    w("  begin")
                    w("    FWriter.StartElement('%s');" % q)
                    w("    Write%s(AObject.%s[I]%s);" % (short, c["pname"], (", " + cpath) if ct in np else ""))
                    w("    FWriter.EndElement;")
                    w("  end;")
                    if c["min"] >= 1:
                        w("  if AObject.%s.Count = 0 then" % c["pname"])
                        w("    Missing(%s);" % cpath)
                    elif (n, q) in elems:
                        w("  if AObject.%s.Count = 0 then" % c["pname"])
                        w("    MissingInProfile(%s);" % cpath)
            elif k == "record":
                rshort = m.pascal[ct][len("TLandrix"):]
                if c["max"] == 1:
                    w("  if not %sIsEmpty(AObject.%s) then" % (rshort, c["pname"]))
                    w("    Write%s('%s', AObject.%s%s)" % (short, q, c["pname"], (", " + cpath) if ct in np else ""))
                    if c["min"] >= 1:
                        w("  else")
                        w("    Missing(%s)" % cpath)
                    elif (n, q) in elems:
                        w("  else")
                        w("    MissingInProfile(%s)" % cpath)
                    w("  ;")
                else:
                    w("  for I := 0 to AObject.%s.Count - 1 do" % c["pname"])
                    w("    Write%s('%s', AObject.%s[I]%s);" % (short, q, c["pname"], (", " + cpath) if ct in np else ""))
                    if c["min"] >= 1:
                        w("  if AObject.%s.Count = 0 then" % c["pname"])
                        w("    Missing(%s);" % cpath)
                    elif (n, q) in elems:
                        w("  if AObject.%s.Count = 0 then" % c["pname"])
                        w("    MissingInProfile(%s);" % cpath)
            elif c["max"] != 1:
                w("  for I := 0 to AObject.%s.Count - 1 do" % c["pname"])
                w("    FWriter.ElementW('%s', AObject.%s[I]);" % (q, c["pname"]))
                if c["min"] >= 1:
                    w("  if AObject.%s.Count = 0 then" % c["pname"])
                    w("    Missing(%s);" % cpath)
                elif (n, q) in elems:
                    w("  if AObject.%s.Count = 0 then" % c["pname"])
                    w("    MissingInProfile(%s);" % cpath)
            else:
                w("  if not LandrixEInvoiceIsBlank(AObject.%s) then" % c["pname"])
                if not ct.startswith("xs:") and m.kind[ct] == "wrapper":
                    inner = m.wrapped[ct][0]
                    w("  begin")
                    w("    FWriter.StartElement('%s');" % q)
                    w("    FWriter.ElementW('%s:%s', AObject.%s);" % (inner["ns"], inner["name"], c["pname"]))
                    w("    FWriter.EndElement;")
                    w("  end")
                else:
                    w("    FWriter.ElementW('%s', AObject.%s)" % (q, c["pname"]))
                if c["min"] >= 1:
                    w("  else")
                    w("    Missing(%s)" % cpath)
                elif (n, q) in elems:
                    w("  else")
                    w("    MissingInProfile(%s)" % cpath)
                w("  ;")
        w("end;")
        w("")
    for r in m.roots:
        writer_entry_impl(m, r, np, w)
    w("end.")
    return L


# --------------------------------------------------------------------------
# profile unit (CII only)
# --------------------------------------------------------------------------

PROFILE_ENUM = {"MINIMUM": "epr_Minimum", "BASIC WL": "epr_BasicWL", "BASIC": "epr_Basic",
                "EN16931": "epr_EN16931", "EXTENDED": "epr_Extended"}

PROFILES_HEAD = """{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ GENERATED by tools/syntaxmodel/gen-syntaxmodel.py from
  tools/syntaxmodel/cii-profiles.json (derived from the Factur-X 1.09.2
  field table by tools/fieldmap/fieldmap.py --export) and
  tools/syntaxmodel/cii.json - do not edit; change the generator and run it
  again.
  DE: ERZEUGT von tools/syntaxmodel/gen-syntaxmodel.py aus
  tools/syntaxmodel/cii-profiles.json (abgeleitet aus der
  Factur-X-1.09.2-Feldtabelle von tools/fieldmap/fieldmap.py --export) und
  tools/syntaxmodel/cii.json - nicht von Hand aendern; den Generator aendern
  und erneut ausfuehren.

  Factur-X profiles of the CII paths: the profiles nest (MINIMUM in BASIC WL
  in BASIC in EN16931 in EXTENDED), so a path is allowed in a profile if
  the lowest profile containing it is not higher. Paths are written without
  list index, e.g.
  '/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:Name', attributes as
  '.../@schemeID'. The EXTENDED schema decides for EXTENDED and for targets
  without a Factur-X profile.

  DE: Factur-X-Profile der CII-Pfade: die Profile sind geschachtelt (MINIMUM
  in BASIC WL in BASIC in EN16931 in EXTENDED), ein Pfad ist also in einem
  Profil erlaubt, wenn das niedrigste Profil, das ihn enthaelt, nicht hoeher
  ist. Pfade stehen ohne Listenindex, z. B.
  '/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:Name', Attribute als
  '.../@schemeID'. Fuer EXTENDED und fuer Ziele ohne Factur-X-Profil
  entscheidet das EXTENDED-Schema. }

unit LandrixEInvoiceCIIProfiles;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceCII;

{ Lowest Factur-X profile that contains APath; epr_None if the field table
  does not know the path (then only the EXTENDED schema allows it).
  DE: Niedrigstes Factur-X-Profil, das APath enthaelt; epr_None, wenn die
  Feldtabelle den Pfad nicht kennt (dann erlaubt ihn nur das
  EXTENDED-Schema). }
function LandrixEInvoiceCIIMinProfile(const APath: TLandrixEInvoiceString): TLandrixEInvoiceProfile;

{ True if APath is allowed in AProfile. For MINIMUM, BASIC WL, BASIC and
  EN16931 the field table decides (an unknown path is not allowed); for
  every other profile (EXTENDED, epr_None, epr_XRechnung) the result is
  True, the schema decides.
  DE: True, wenn APath in AProfile erlaubt ist. Fuer MINIMUM, BASIC WL, BASIC
  und EN16931 entscheidet die Feldtabelle (ein unbekannter Pfad ist nicht
  erlaubt); fuer alle anderen Profile (EXTENDED, epr_None, epr_XRechnung)
  ist das Ergebnis True, das Schema entscheidet. }
function LandrixEInvoiceCIIAllowed(const APath: TLandrixEInvoiceString;
  AProfile: TLandrixEInvoiceProfile): Boolean;

{ True if APath is required in the Factur-X profile AProfile over the whole
  ancestor chain (the path and every element above it have at least one
  occurrence in that profile); False for unknown paths and for profiles
  outside MINIMUM .. EXTENDED.
  DE: True, wenn APath im Factur-X-Profil AProfile ueber die ganze
  Ahnenkette Pflicht ist (der Pfad und jedes Element darueber kommen in dem
  Profil mindestens einmal vor); False fuer unbekannte Pfade und fuer
  Profile ausserhalb von MINIMUM .. EXTENDED. }
function LandrixEInvoiceCIIRequired(const APath: TLandrixEInvoiceString;
  AProfile: TLandrixEInvoiceProfile): Boolean;

{ True if APath is required in the Factur-X profile AProfile wherever its
  parent element exists (cardinality 1.. below the parent in the field
  table); False for unknown paths and for profiles outside MINIMUM ..
  EXTENDED. The CII writer reports such a path when it is missing.
  DE: True, wenn APath im Factur-X-Profil AProfile ueberall Pflicht ist, wo
  sein Elternelement existiert (Kardinalitaet 1.. unter dem Elternelement
  in der Feldtabelle); False fuer unbekannte Pfade und fuer Profile
  ausserhalb von MINIMUM .. EXTENDED. Der CII-Writer meldet einen solchen
  Pfad, wenn er fehlt. }
function LandrixEInvoiceCIIRequiredBelowParent(const APath: TLandrixEInvoiceString;
  AProfile: TLandrixEInvoiceProfile): Boolean;

{ Removes from AInvoice (not nil) everything the Factur-X profile AProfile
  does not contain, at the highest element that is not allowed, and reports
  each removed path once with the number of removed occurrences
  (edk_NotAllowed, warning) in ADiagnostics (nil: discarded). Totals are not
  recalculated. Returns the number of removed elements and attributes; 0 for
  profiles outside MINIMUM .. EN16931.
  DE: Entfernt aus AInvoice (nicht nil) alles, was das Factur-X-Profil
  AProfile nicht enthaelt, am hoechsten nicht erlaubten Element, und meldet
  jeden entfernten Pfad einmal mit der Anzahl entfernter Vorkommen
  (edk_NotAllowed, Warnung) in ADiagnostics (nil: verworfen). Summen werden
  nicht neu berechnet. Liefert die Anzahl entfernter Elemente und
  Attribute; 0 fuer Profile ausserhalb von MINIMUM .. EN16931. }
function LandrixEInvoicePruneCII(AInvoice: TLandrixCIIInvoice; AProfile: TLandrixEInvoiceProfile;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

{ Reports what LandrixEInvoicePruneCII would remove from AInvoice (not nil)
  without changing it: each path at the highest element the Factur-X
  profile AProfile does not contain, once with the number of occurrences
  (edk_NotAllowed, error) in ADiagnostics (nil: discarded). Returns the
  number of occurrences; 0 for profiles outside MINIMUM .. EN16931.
  DE: Meldet, was LandrixEInvoicePruneCII aus AInvoice (nicht nil) entfernen
  wuerde, ohne es zu aendern: jeden Pfad am hoechsten Element, das das
  Factur-X-Profil AProfile nicht enthaelt, einmal mit der Anzahl der
  Vorkommen (edk_NotAllowed, Fehler) in ADiagnostics (nil: verworfen).
  Liefert die Anzahl der Vorkommen; 0 fuer Profile ausserhalb von MINIMUM ..
  EN16931. }
function LandrixEInvoiceCheckCIIProfile(AInvoice: TLandrixCIIInvoice; AProfile: TLandrixEInvoiceProfile;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;

implementation

uses
  SysUtils,
  LandrixEInvoiceLexical;

type
  TProfileSet = set of TLandrixEInvoiceProfile;

  TPathEntry = record
    Path: string;
    MinProfile: TLandrixEInvoiceProfile;
    Required: TProfileSet;
    RequiredBelowParent: TProfileSet;
  end;

"""

PROFILES_BODY = """
const
  CheckedProfiles = [epr_Minimum, epr_BasicWL, epr_Basic, epr_EN16931];

function ProfileName(AProfile: TLandrixEInvoiceProfile): string;
begin
  case AProfile of
    epr_Minimum: Result := 'MINIMUM';
    epr_BasicWL: Result := 'BASIC WL';
    epr_Basic: Result := 'BASIC';
    epr_EN16931: Result := 'EN16931';
  else
    Result := 'EXTENDED';
  end;
end;

{ ordinal comparison; the table is sorted by code point }
function ComparePath(const A: TLandrixEInvoiceString; const B: string): Integer;
var
  I, N: Integer;
begin
  N := Length(A);
  if Length(B) < N then
    N := Length(B);
  for I := 1 to N do
    if Ord(A[I]) <> Ord(B[I]) then
    begin
      Result := Ord(A[I]) - Ord(B[I]);
      Exit;
    end;
  Result := Length(A) - Length(B);
end;

function FindPath(const APath: TLandrixEInvoiceString): Integer;
var
  Lo, Hi, Mid, C: Integer;
begin
  Lo := Low(Paths);
  Hi := High(Paths);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    C := ComparePath(APath, Paths[Mid].Path);
    if C = 0 then
    begin
      Result := Mid;
      Exit;
    end;
    if C < 0 then
      Hi := Mid - 1
    else
      Lo := Mid + 1;
  end;
  Result := -1;
end;

function LandrixEInvoiceCIIMinProfile(const APath: TLandrixEInvoiceString): TLandrixEInvoiceProfile;
var
  I: Integer;
begin
  I := FindPath(APath);
  if I < 0 then
    Result := epr_None
  else
    Result := Paths[I].MinProfile;
end;

function LandrixEInvoiceCIIAllowed(const APath: TLandrixEInvoiceString;
  AProfile: TLandrixEInvoiceProfile): Boolean;
var
  MinProfile: TLandrixEInvoiceProfile;
begin
  if not (AProfile in CheckedProfiles) then
  begin
    Result := True;
    Exit;
  end;
  MinProfile := LandrixEInvoiceCIIMinProfile(APath);
  Result := (MinProfile <> epr_None) and (MinProfile <= AProfile);
end;

function LandrixEInvoiceCIIRequired(const APath: TLandrixEInvoiceString;
  AProfile: TLandrixEInvoiceProfile): Boolean;
var
  I: Integer;
begin
  I := FindPath(APath);
  Result := (I >= 0) and (AProfile in Paths[I].Required);
end;

function LandrixEInvoiceCIIRequiredBelowParent(const APath: TLandrixEInvoiceString;
  AProfile: TLandrixEInvoiceProfile): Boolean;
var
  I: Integer;
begin
  I := FindPath(APath);
  Result := (I >= 0) and (AProfile in Paths[I].RequiredBelowParent);
end;

{ --- pruning ------------------------------------------------------------- }

type
  TCIIPruner = class(TObject)
  private
    FProfile: TLandrixEInvoiceProfile;
    FRemove: Boolean;
    FPaths: array of TLandrixEInvoiceString;
    FCounts: array of Integer;
    FTotal: Integer;
    function Keep(const APath: TLandrixEInvoiceString; ACount: Integer): Boolean;
"""


def gen_profiles(m, data):
    order = data["profiles"]
    if [PROFILE_ENUM.get(p) for p in order] != list(PROFILE_ENUM.values()):
        fail("cii-profiles.json: unexpected profile list %s" % order)
    rows = data["paths"]
    if [r[0] for r in rows] != sorted(r[0] for r in rows):
        fail("cii-profiles.json: paths not sorted")
    L = []
    w = L.append
    w(PROFILES_HEAD.rstrip("\n"))
    w("const")
    w("  Paths: array[0..%d] of TPathEntry = (" % (len(rows) - 1))
    for i, (path, low, req, here) in enumerate(rows):
        if len(path) > 250 or "'" in path:
            fail("path not usable as literal: %s" % path)
        w("    (Path: '%s';" % path)
        w("     MinProfile: %s; Required: [%s];" % (PROFILE_ENUM[low], ", ".join(PROFILE_ENUM[p] for p in req)))
        w("     RequiredBelowParent: [%s])%s" % (
            ", ".join(PROFILE_ENUM[p] for p in here), "," if i < len(rows) - 1 else ""))
    w("  );")
    w(PROFILES_BODY.rstrip("\n"))
    for n in m.classes():
        w("    procedure Prune%s(AObject: %s; const APath: TLandrixEInvoiceString);" % (
            m.pascal[n][len(PREFIX):], m.pascal[n]))
    w("""  end;

function TCIIPruner.Keep(const APath: TLandrixEInvoiceString; ACount: Integer): Boolean;
var
  I: Integer;
begin
  Result := LandrixEInvoiceCIIAllowed(APath, FProfile);
  if Result then
    Exit;
  Inc(FTotal, ACount);
  for I := 0 to Integer(Length(FPaths)) - 1 do
    if FPaths[I] = APath then
    begin
      Inc(FCounts[I], ACount);
      Exit;
    end;
  I := Integer(Length(FPaths));
  SetLength(FPaths, I + 1);
  SetLength(FCounts, I + 1);
  FPaths[I] := APath;
  FCounts[I] := ACount;
end;
""")
    single = set()
    with_fields = set()
    for n in m.classes():
        for c in m.types[n]["children"]:
            if m.child_kind(c) == "record":
                if c["max"] == 1:
                    single.add(c["type"])
                if m.record_fields(c["type"]):
                    with_fields.add(c["type"])
    for n in m.records():
        if n not in single:
            continue
        p = m.pascal[n]
        short = p[len("TLandrix"):]
        w("function %sIsEmpty(const R: %s): Boolean;" % (short, p))
        w("begin")
        # as in the model: blank text is absent, attributes keep the value
        cond = ["LandrixEInvoiceIsBlank(R.Value)"] + ["(R.%s = '')" % f for f, _, _ in m.record_fields(n)]
        w("  Result := " + " and ".join(cond) + ";")
        w("end;")
        w("")
        w("procedure %sClear(var R: %s);" % (short, p))
        w("begin")
        w("  R.Value := '';")
        for f, _, _ in m.record_fields(n):
            w("  R.%s := '';" % f)
        w("end;")
        w("")
    for n in m.records():
        if n not in with_fields:
            continue
        p = m.pascal[n]
        fields = m.record_fields(n)
        w("{ attributes of a kept %s value; True if one was removed }" % p)
        w("function Prune%sFields(APruner: TCIIPruner; var R: %s;" % (p[len(PREFIX):], p))
        w("  const APath: TLandrixEInvoiceString): Boolean;")
        w("begin")
        w("  Result := False;")
        inner = ""
        if m.kind[n] == "wrapper":
            inner = "/%s:%s" % (m.wrapped[n][0]["ns"], m.wrapped[n][0]["name"])
        for f, a, _ in fields:
            w("  if (R.%s <> '') and not APruner.Keep(APath + '%s/@%s', 1) and APruner.FRemove then" % (f, inner, a))
            w("  begin")
            w("    R.%s := '';" % f)
            w("    Result := True;")
            w("  end;")
        w("end;")
        w("")
    for n in m.classes():
        p = m.pascal[n]
        children = m.types[n]["children"]
        w("procedure TCIIPruner.Prune%s(AObject: %s; const APath: TLandrixEInvoiceString);" % (p[len(PREFIX):], p))
        loops = [c for c in children if c["max"] != 1 and (
            m.child_kind(c) == "class" or (m.child_kind(c) == "record" and c["type"] in with_fields))]
        if loops:
            w("var")
            w("  I: TLandrixEInvoiceListIndex;")
            for c in loops:
                if m.child_kind(c) == "record":
                    w("  R%s: %s;" % (c["pname"], m.pascal[c["type"]]))
        w("begin")
        for c in children:
            k = m.child_kind(c)
            pn = c["pname"]
            cpath = "APath + '/%s'" % m.qname(c)
            if k == "string" and c["max"] != 1:
                w("  if (AObject.%s.Count > 0) and not Keep(%s, Integer(AObject.%s.Count)) and FRemove then" % (pn, cpath, pn))
                w("    AObject.%s.Clear;" % pn)
            elif k == "string":
                w("  if not LandrixEInvoiceIsBlank(AObject.%s) and not Keep(%s, 1) and FRemove then" % (pn, cpath))
                w("    AObject.%s := '';" % pn)
            elif k == "record" and c["max"] == 1:
                short = m.pascal[c["type"]][len(PREFIX):]
                rshort = m.pascal[c["type"]][len("TLandrix"):]
                w("  if not %sIsEmpty(AObject.%s) then" % (rshort, pn))
                if c["type"] in with_fields:
                    w("    if Keep(%s, 1) then" % cpath)
                    w("      Prune%sFields(Self, AObject.%s, %s)" % (short, pn, cpath))
                    w("    else if FRemove then")
                    w("      %sClear(AObject.%s);" % (rshort, pn))
                else:
                    w("    if not Keep(%s, 1) and FRemove then" % cpath)
                    w("      %sClear(AObject.%s);" % (rshort, pn))
            elif k == "record" and c["type"] not in with_fields:
                w("  if (AObject.%s.Count > 0) and not Keep(%s, Integer(AObject.%s.Count)) and FRemove then" % (pn, cpath, pn))
                w("    AObject.%s.Clear;" % pn)
            elif k == "record":
                short = m.pascal[c["type"]][len(PREFIX):]
                w("  if AObject.%s.Count > 0 then" % pn)
                w("    if Keep(%s, Integer(AObject.%s.Count)) then" % (cpath, pn))
                w("      for I := 0 to AObject.%s.Count - 1 do" % pn)
                w("      begin")
                w("        R%s := AObject.%s[I];" % (pn, pn))
                w("        if Prune%sFields(Self, R%s, %s) then" % (short, pn, cpath))
                w("          AObject.%s[I] := R%s;" % (pn, pn))
                w("      end")
                w("    else if FRemove then")
                w("      AObject.%s.Clear;" % pn)
            elif c["max"] == 1:
                short = m.pascal[c["type"]][len(PREFIX):]
                w("  if not AObject.%s.IsEmpty then" % pn)
                w("    if Keep(%s, 1) then" % cpath)
                w("      Prune%s(AObject.%s, %s)" % (short, pn, cpath))
                w("    else if FRemove then")
                w("      AObject.%s.Clear;" % pn)
            else:
                short = m.pascal[c["type"]][len(PREFIX):]
                w("  if AObject.%s.Count > 0 then" % pn)
                w("    if Keep(%s, Integer(AObject.%s.Count)) then" % (cpath, pn))
                w("      for I := 0 to AObject.%s.Count - 1 do" % pn)
                w("        Prune%s(AObject.%s[I], %s)" % (short, pn, cpath))
                w("    else if FRemove then")
                w("      AObject.%s.Clear;" % pn)
        w("end;")
        w("")
    root = m.roots[0]
    path = "/%s:%s" % (root["ns"], root["name"])
    w("""{ Runs the pruner over AInvoice; ARemove = False only reports.
  DE: Laesst den Pruner ueber AInvoice laufen; ARemove = False meldet nur. }
function RunPruner(AInvoice: TLandrixCIIInvoice; AProfile: TLandrixEInvoiceProfile;
  ADiagnostics: TLandrixEInvoiceDiagnostics; ARemove: Boolean): Integer;
var
  Pruner: TCIIPruner;
  I: Integer;
  Suffix: string;
  Item: TLandrixEInvoiceDiagnostic;
begin
  Result := 0;
  if not (AProfile in CheckedProfiles) then
    Exit;
  if ARemove then
    Suffix := ' occurrence(s) left out: not in Factur-X profile '
  else
    Suffix := ' occurrence(s) not in Factur-X profile ';
  Pruner := TCIIPruner.Create;
  try
    Pruner.FProfile := AProfile;
    Pruner.FRemove := ARemove;
    Pruner.PruneInvoice(AInvoice, '%s');
    if ADiagnostics <> nil then
      for I := 0 to Integer(Length(Pruner.FPaths)) - 1 do
      begin
        Item := ADiagnostics.AddDiagnostic(edk_NotAllowed, Pruner.FPaths[I], 0, 0, 0,
          TLandrixEInvoiceString(IntToStr(Pruner.FCounts[I]) + Suffix + ProfileName(AProfile)));
        if ARemove then
          Item.Severity := eds_Warning
        else
          Item.Severity := eds_Error;
      end;
    Result := Pruner.FTotal;
  finally
    Pruner.Free;
  end;
end;

function LandrixEInvoicePruneCII(AInvoice: TLandrixCIIInvoice; AProfile: TLandrixEInvoiceProfile;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := RunPruner(AInvoice, AProfile, ADiagnostics, True);
end;

function LandrixEInvoiceCheckCIIProfile(AInvoice: TLandrixCIIInvoice; AProfile: TLandrixEInvoiceProfile;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := RunPruner(AInvoice, AProfile, ADiagnostics, False);
end;

end.""" % path)
    return L


# --------------------------------------------------------------------------

def finish(lines):
    text = syn_text("\n".join(lines) + "\n")
    if any(ord(c) > 127 for c in text):
        fail("non-ASCII output")
    text = re.sub(r"\n +;\n", ";\n", text)
    return text.replace("\n", "\r\n").encode("ascii")


def main(argv):
    args = argv[1:]
    if any(a != "--check" for a in args):
        fail("unknown argument; usage: gen-syntaxmodel.py [--check]")
    check = "--check" in args
    outputs = {}
    counts = []
    for cfg in SYNTAXES:
        use_syntax(cfg)
        data = json.load(io.open(os.path.join(HERE, cfg["json"]), encoding="utf-8"))
        m = Model(data)
        base = "source/LandrixEInvoice" + cfg["syn"]
        outputs[base + ".pas"] = finish(gen_model(m))
        outputs[base + "Reader.pas"] = finish(gen_reader(m))
        outputs[base + "Writer.pas"] = finish(gen_writer(m))
        if cfg.get("profiles"):
            pdata = json.load(io.open(os.path.join(HERE, cfg["profiles"]), encoding="utf-8"))
            outputs[base + "Profiles.pas"] = finish(gen_profiles(m, pdata))
        counts.append("%s %d classes, %d records" % (cfg["syn"], len(m.classes()), len(m.records())))
    stale = []
    for rel, data_out in sorted(outputs.items()):
        path = os.path.join(ROOT, rel)
        if check:
            try:
                with open(path, "rb") as f:
                    current = f.read()
            except IOError:
                current = b""
            if current.replace(b"\r\n", b"\n") != data_out.replace(b"\r\n", b"\n"):
                stale.append(rel)
        else:
            with open(path, "wb") as f:
                f.write(data_out)
    if check:
        if stale:
            sys.stderr.write("gen-syntaxmodel: not up to date: %s\n" % ", ".join(stale))
            return 1
        print("gen-syntaxmodel: up to date")
        return 0
    print("gen-syntaxmodel: wrote %d units (%s)" % (len(outputs), "; ".join(counts)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
