#!/usr/bin/env python3
"""Generates tests/LandrixEInvoiceTestInvoiceCompare.pas from the interface
section of source/LandrixEInvoiceInvoice.pas: an all-field comparison of two
TLandrixInvoice, a canonical text dump, a fill procedure that sets every field
and one mutation per leaf (field or list count) for the completeness test;
fill and mutations with one or with two items per list.

Test-only: no public Assign or compare API before the API freeze of 1.0. The parser is strict: a declaration in a model class it
cannot classify stops the generator, so a new field is never left out
silently.

Usage:
  python tools/model/gen-invoice-compare.py           write the unit
  python tools/model/gen-invoice-compare.py --check   exit 1 if it differs
"""

import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MODEL = os.path.join(ROOT, "source", "LandrixEInvoiceInvoice.pas")
OUTPUT = os.path.join(ROOT, "tests", "LandrixEInvoiceTestInvoiceCompare.pas")

ROOT_CLASS = "TLandrixInvoice"
STRING = "TLandrixEInvoiceString"
NUMBERS = {"Currency": "currency", "Double": "double", "TDateTime": "date", "Integer": "integer"}
NULLABLES = {"TLandrixEInvoiceDate": "date", "TLandrixEInvoiceAmount": "currency",
             "TLandrixEInvoiceBoolean": "boolean", "TLandrixEInvoiceQuantity": "double",
             "TLandrixEInvoicePercent": "double", "TLandrixEInvoiceInteger": "integer"}
DIRECTIVES = {"overload", "override", "virtual", "abstract", "reintroduce", "default", "dynamic"}
# how often a class may occur on one path when filling (sub lines: one level)
MAX_NESTING = 2


def fail(msg):
    sys.stderr.write("gen-invoice-compare: " + msg + "\n")
    sys.exit(2)


def strip_comments(text):
    text = re.sub(r"\{[^}]*\}", lambda m: "\n" * m.group(0).count("\n"), text)
    text = re.sub(r"\(\*.*?\*\)", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def split_statements(body):
    """Split at ';' outside parentheses and brackets."""
    out, depth, cur = [], 0, []
    for ch in body:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == ";" and depth == 0:
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    rest = "".join(cur).strip()
    if rest:
        out.append(rest)
    return [s for s in out if s]


def terms_of(raw_body, field):
    """BT/BG identifiers from the English part of the comment before a field."""
    m = re.search(r"\{([^}]*)\}\s*\n\s*" + re.escape(field) + r"\s*[:,]", raw_body)
    if not m:
        return ""
    english = m.group(1).split("DE:")[0]
    ids = re.findall(r"\b(B[TG]-(?:X-|DEX-)?\d+(?:-\d+)?)", english)
    seen = []
    for i in ids:
        if i not in seen:
            seen.append(i)
    return "/".join(seen)


def parse(text):
    iface = text[:text.index("\nimplementation")]
    clean = strip_comments(iface)
    classes, lists = {}, {}
    for m in re.finditer(r"\n  (T\w+) = class(\((\w+)\))?[ \t]*\n(.*?)\n  end;", clean, re.S):
        name, base, body = m.group(1), m.group(3), m.group(4)
        # the declaration with a body, not a forward declaration 'T... = class;'
        raw = re.search(r"\n  " + name + r" = class(\(\w+\))?[ \t]*\n.*?\n  end;", iface, re.S).group(0)
        if base == "TObjectList":
            item = re.search(r"property Items\[[^]]*\]: (\w+) read", body)
            if not item:
                fail("list %s without Items" % name)
            adds = re.findall(r"function (Add\w*)(\(([^)]*)\))?: " + item.group(1) + ";", body)
            if not adds:
                fail("list %s without Add function" % name)
            adds.sort(key=lambda a: len(a[2]))
            fn, _, params = adds[0]
            args = []
            for p in [p for p in params.split(";") if p.strip()]:
                ptype = p.split(":")[1].strip()
                args.append("%s(1)" % ptype)
            lists[name] = {"item": item.group(1), "add": fn + ("(%s)" % ", ".join(args) if args else "")}
            continue
        if base not in (None, "TObject"):
            fail("class %s with unexpected base %s" % (name, base))
        fields = []
        body = re.sub(r"^\s*(strict\s+)?(public|private|protected|published)\s*$", "", body, flags=re.M)
        for st in split_statements(body):
            word = st.split()[0].lower()
            if word == "class" and not re.match(r"^class\s+(procedure|function)\b", st, re.I):
                fail("class-level declaration not supported in %s: %r" % (name, st))
            if word in ("constructor", "destructor", "procedure", "function", "class", "property"):
                continue
            if word in DIRECTIVES:
                continue
            fm = re.match(r"^(\w+(?:\s*,\s*\w+)*)\s*:\s*([\w.]+)$", st)
            if not fm:
                fail("cannot classify in %s: %r" % (name, st))
            for f in [x.strip() for x in fm.group(1).split(",")]:
                fields.append({"name": f, "type": fm.group(2), "terms": terms_of(raw, f)})
        classes[name] = fields
    if ROOT_CLASS not in classes:
        fail("root class missing")
    for cname, fields in classes.items():
        for f in fields:
            t = f["type"]
            if t == STRING:
                f["kind"] = "string"
            elif t in NUMBERS:
                f["kind"] = NUMBERS[t]
            elif t == "Boolean":
                f["kind"] = "boolean"
            elif t in NULLABLES:
                f["kind"] = "nullable"
                f["value"] = NULLABLES[t]
            elif t == "TMemoryStream":
                f["kind"] = "stream"
            elif t in classes:
                f["kind"] = "object"
            elif t in lists:
                f["kind"] = "list"
            elif re.match(r"^TLandrix\w+$", t):
                f["kind"] = "enum"
            else:
                fail("unsupported type %s of %s.%s" % (t, cname, f["name"]))
    return classes, lists


def short(cname):
    return "Invoice" if cname == ROOT_CLASS else cname[len("TLandrixInvoice"):]


def label(f):
    return f["name"] + (" (%s)" % f["terms"] if f["terms"] else "")


def gen(classes, lists):
    L = []
    w = L.append
    w("""{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ GENERATED by tools/model/gen-invoice-compare.py from the interface of
  source/LandrixEInvoiceInvoice.pas - do not edit; change the generator and
  run it again.

  Test helpers for TLandrixInvoice: every field compared (CompareInvoices,
  paths like 'InvoiceLines[2].AllowanceCharges[0].Amount (BT-136)'), a
  canonical text dump of every set field (DumpInvoice), a fill procedure that
  sets every field (FillInvoiceAll; lists get one item or two, sub lines one
  level), and one mutation per leaf for the completeness test
  (InvoiceLeafCount, MutateInvoiceLeaf). Double fields are equal within
  1e-9 relative; attachment data is compared by bytes. }

unit LandrixEInvoiceTestInvoiceCompare;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceInvoice;

{ Adds one line per differing field or list count to ADiffs; empty when equal.
  Lists are compared item by item up to the shorter count. }
procedure CompareInvoices(A, B: TLandrixInvoice; ADiffs: TStrings);

{ One line 'path = value' per set field (strings not empty, numbers and
  enumerations not 0, Boolean True, optional values with a value, data not
  empty, list counts above 0). }
procedure DumpInvoice(A: TLandrixInvoice; ALines: TStrings);

{ Sets every field of AInvoice (expected empty) to a value of its own, with
  AItems (1 or 2) items in every list. }
procedure FillInvoiceAll(AInvoice: TLandrixInvoice; AItems: Integer = 1);

{ Number of leaves of an invoice filled by FillInvoiceAll with AItems. }
function InvoiceLeafCount(AItems: Integer = 1): Integer;

{ Changes leaf AIndex (0 .. InvoiceLeafCount(AItems) - 1) of an invoice
  filled by FillInvoiceAll with AItems; APath is the path CompareInvoices
  reports for it. }
procedure MutateInvoiceLeaf(AInvoice: TLandrixInvoice; AIndex: Integer; out APath: string; AItems: Integer = 1);

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical;

function Num(AValue: Double; ADecimals: Integer): string;
begin
  Result := string(LandrixEInvoiceDecimalToLexical(AValue, ADecimals));
end;

function DateText(AValue: TDateTime): string;
begin
  Result := Num(AValue, 0);
  if AValue <> 0 then
    Result := Result + ' ' + string(LandrixEInvoiceDateToUBL(AValue));
end;

function BoolText(AValue: Boolean): string;
begin
  if AValue then
    Result := 'True'
  else
    Result := 'False';
end;

function SameDouble(A, B: Double): Boolean;
var
  Scale: Double;
begin
  Scale := Abs(A);
  if Abs(B) > Scale then
    Scale := Abs(B);
  if Scale < 1 then
    Scale := 1;
  { an integer factor: Delphi 13 Win64 warns W1066 for the literal 1E-9 }
  Result := Abs(A - B) <= Scale / 1000000000;
end;

function SameData(A, B: TMemoryStream): Boolean;
begin
  if (A = nil) or (B = nil) then
    Result := (A = B) or ((A = nil) and (B.Size = 0)) or ((B = nil) and (A.Size = 0))
  else
    Result := (A.Size = B.Size) and ((A.Size = 0) or CompareMem(A.Memory, B.Memory, Integer(A.Size)));
end;

function DataSize(A: TMemoryStream): Integer;
begin
  if A = nil then
    Result := 0
  else
    Result := Integer(A.Size);
end;

procedure Diff(ADiffs: TStrings; const APath, AValueA, AValueB: string);
begin
  ADiffs.Add(APath + ': ' + AValueA + ' <> ' + AValueB);
end;

procedure AppendData(AData: TMemoryStream; ACount: Integer);
var
  S: AnsiString;
  I: Integer;
begin
  AData.Position := AData.Size;
  for I := 1 to ACount do
  begin
    S := AnsiChar(Ord('a') + Integer(AData.Size) mod 26);
    AData.WriteBuffer(PAnsiChar(S)^, 1);
  end;
end;
""")
    used = sorted(set(f["type"] for fs in classes.values() for f in fs if f["kind"] == "nullable"))
    for t in used:
        v = NULLABLES[t]
        show = {"date": "DateText(AValue.Value)", "currency": "Num(AValue.Value, 4)", "double": "Num(AValue.Value, 9)",
                "boolean": "BoolText(AValue.Value)", "integer": "IntToStr(AValue.Value)"}[v]
        w("function Opt%s(const AValue: %s): string;" % (t[len("TLandrixEInvoice"):], t))
        w("begin")
        w("  if AValue.HasValue then")
        w("    Result := %s" % show)
        w("  else")
        w("    Result := '(none)';")
        w("end;")
        w("")
    order = [ROOT_CLASS] + sorted(c for c in classes if c != ROOT_CLASS)
    # forward declarations
    for c in order:
        w("procedure Compare%sFields(A, B: %s; const APath: string; ADiffs: TStrings); forward;" % (short(c), c))
        w("procedure Dump%sFields(A: %s; const APath: string; ALines: TStrings); forward;" % (short(c), c))
    w("")
    for c in order:
        fields = classes[c]
        need_i = any(f["kind"] == "list" for f in fields)
        w("procedure Compare%sFields(A, B: %s; const APath: string; ADiffs: TStrings);" % (short(c), c))
        if need_i:
            w("var")
            w("  I: Integer;")
        w("begin")
        for f in fields:
            n, k, p = f["name"], f["kind"], "APath + '%s'" % label(f)
            if k == "string":
                w("  if A.%s <> B.%s then" % (n, n))
                w("    Diff(ADiffs, %s, '\"' + string(A.%s) + '\"', '\"' + string(B.%s) + '\"');" % (p, n, n))
            elif k in ("currency", "integer"):
                fmt = "Num(A.%s, 4)" if k == "currency" else "IntToStr(A.%s)"
                w("  if A.%s <> B.%s then" % (n, n))
                w("    Diff(ADiffs, %s, %s, %s);" % (p, fmt % n, fmt.replace("A.", "B.") % n))
            elif k == "double":
                w("  if not SameDouble(A.%s, B.%s) then" % (n, n))
                w("    Diff(ADiffs, %s, Num(A.%s, 9), Num(B.%s, 9));" % (p, n, n))
            elif k == "date":
                w("  if A.%s <> B.%s then" % (n, n))
                w("    Diff(ADiffs, %s, DateText(A.%s), DateText(B.%s));" % (p, n, n))
            elif k == "boolean":
                w("  if A.%s <> B.%s then" % (n, n))
                w("    Diff(ADiffs, %s, BoolText(A.%s), BoolText(B.%s));" % (p, n, n))
            elif k == "enum":
                w("  if A.%s <> B.%s then" % (n, n))
                w("    Diff(ADiffs, %s, IntToStr(Ord(A.%s)), IntToStr(Ord(B.%s)));" % (p, n, n))
            elif k == "nullable":
                v = f["value"]
                if v == "double":
                    same = "SameDouble(A.%s.Value, B.%s.Value)" % (n, n)
                else:
                    same = "(A.%s.Value = B.%s.Value)" % (n, n)
                show = {"date": "DateText(%s.Value)", "currency": "Num(%s.Value, 4)", "double": "Num(%s.Value, 9)",
                        "boolean": "BoolText(%s.Value)", "integer": "IntToStr(%s.Value)"}[v]
                w("  if (A.%s.HasValue <> B.%s.HasValue) or (A.%s.HasValue and not %s) then" % (n, n, n, same))
                w("    Diff(ADiffs, %s, Opt%s(A.%s), Opt%s(B.%s));" % (p, f["type"][len("TLandrixEInvoice"):], n,
                                                              f["type"][len("TLandrixEInvoice"):], n))
            elif k == "stream":
                w("  if not SameData(A.%s, B.%s) then" % (n, n))
                w("    Diff(ADiffs, %s, 'data ' + IntToStr(DataSize(A.%s)), 'data ' + IntToStr(DataSize(B.%s)));" % (p, n, n))
            elif k == "object":
                w("  Compare%sFields(A.%s, B.%s, APath + '%s.', ADiffs);" % (short(f["type"]), n, n, n))
            elif k == "list":
                item = lists[f["type"]]["item"]
                w("  if A.%s.Count <> B.%s.Count then" % (n, n))
                w("    Diff(ADiffs, APath + '%s.Count', IntToStr(A.%s.Count), IntToStr(B.%s.Count));" % (label(f), n, n))
                w("  for I := 0 to Integer(A.%s.Count) - 1 do" % n)
                w("    if I < B.%s.Count then" % n)
                w("      Compare%sFields(A.%s[I], B.%s[I], APath + '%s[' + IntToStr(I) + '].', ADiffs);" % (
                    short(item), n, n, n))
        w("end;")
        w("")
        w("procedure Dump%sFields(A: %s; const APath: string; ALines: TStrings);" % (short(c), c))
        if need_i:
            w("var")
            w("  I: Integer;")
        w("begin")
        for f in fields:
            n, k, p = f["name"], f["kind"], "APath + '%s = '" % label(f)
            if k == "string":
                w("  if A.%s <> '' then" % n)
                w("    ALines.Add(%s + '\"' + string(A.%s) + '\"');" % (p, n))
            elif k == "currency":
                w("  if A.%s <> 0 then" % n)
                w("    ALines.Add(%s + Num(A.%s, 4));" % (p, n))
            elif k == "integer":
                w("  if A.%s <> 0 then" % n)
                w("    ALines.Add(%s + IntToStr(A.%s));" % (p, n))
            elif k == "double":
                w("  if A.%s <> 0 then" % n)
                w("    ALines.Add(%s + Num(A.%s, 9));" % (p, n))
            elif k == "date":
                w("  if A.%s <> 0 then" % n)
                w("    ALines.Add(%s + DateText(A.%s));" % (p, n))
            elif k == "boolean":
                w("  if A.%s then" % n)
                w("    ALines.Add(%s + 'True');" % p)
            elif k == "enum":
                w("  if Ord(A.%s) <> 0 then" % n)
                w("    ALines.Add(%s + IntToStr(Ord(A.%s)));" % (p, n))
            elif k == "nullable":
                show = {"date": "DateText(A.%s.Value)", "currency": "Num(A.%s.Value, 4)", "double": "Num(A.%s.Value, 9)",
                        "boolean": "BoolText(A.%s.Value)", "integer": "IntToStr(A.%s.Value)"}[f["value"]] % n
                w("  if A.%s.HasValue then" % n)
                w("    ALines.Add(%s + %s);" % (p, show))
            elif k == "stream":
                w("  if DataSize(A.%s) > 0 then" % n)
                w("    ALines.Add(%s + 'data ' + IntToStr(DataSize(A.%s)));" % (p, n))
            elif k == "object":
                w("  Dump%sFields(A.%s, APath + '%s.', ALines);" % (short(f["type"]), n, n))
            elif k == "list":
                item = lists[f["type"]]["item"]
                w("  if A.%s.Count > 0 then" % n)
                w("    ALines.Add(APath + '%s.Count = ' + IntToStr(A.%s.Count));" % (label(f), n))
                w("  for I := 0 to Integer(A.%s.Count) - 1 do" % n)
                w("    Dump%sFields(A.%s[I], APath + '%s[' + IntToStr(I) + '].', ALines);" % (short(item), n, n))
        w("end;")
        w("")

    # static expansion for fill and leaves, with one and with two items per
    # list (the values of the second run go on counting: all differ)
    counter = [0]

    def walk(cname, expr, path, stack, items, fill, leaves):
        for f in classes[cname]:
            n, k = f["name"], f["kind"]
            e = "%s.%s" % (expr, n)
            p = path + label(f)
            counter[0] += 1
            v = counter[0]
            if k == "string":
                fill.append("  %s := 'f%d';" % (e, v))
                leaves.append((p, "%s := %s + 'x';" % (e, e)))
            elif k in ("currency", "integer"):
                fill.append("  %s := %d;" % (e, v))
                leaves.append((p, "%s := %s + 1;" % (e, e)))
            elif k == "double":
                fill.append("  %s := %d.5;" % (e, v))
                leaves.append((p, "%s := %s + 1;" % (e, e)))
            elif k == "date":
                fill.append("  %s := %d;" % (e, 40000 + v))
                leaves.append((p, "%s := %s + 1;" % (e, e)))
            elif k == "boolean":
                fill.append("  %s := True;" % e)
                leaves.append((p, "%s := not %s;" % (e, e)))
            elif k == "enum":
                t = f["type"]
                fill.append("  %s := %s(1 mod (Ord(High(%s)) + 1));" % (e, t, t))
                leaves.append((p, "%s := %s((Ord(%s) + 1) mod (Ord(High(%s)) + 1));" % (e, t, e, t)))
            elif k == "nullable":
                val = {"date": str(40000 + v), "currency": str(v), "double": "%d.5" % v,
                       "boolean": "True", "integer": str(v)}[f["value"]]
                fill.append("  %s.SetValue(%s);" % (e, val))
                leaves.append((p, "%s.Clear;" % e))
            elif k == "stream":
                fill.append("  AppendData(%s, 3);" % e)
                leaves.append((p, "AppendData(%s, 1);" % e))
            elif k == "object":
                walk(f["type"], e, path + n + ".", stack, items, fill, leaves)
            elif k == "list":
                info = lists[f["type"]]
                item = info["item"]
                leaves.append((p + ".Count", "%s.%s;" % (e, info["add"])))
                if stack.count(item) + 1 > MAX_NESTING:
                    continue
                for j in range(items):
                    fill.append("  %s.%s;" % (e, info["add"]))
                    walk(item, "%s[%d]" % (e, j), path + n + "[%d]." % j, stack + [item], items, fill, leaves)

    variants = []
    for items in (1, 2):
        fill, leaves = [], []
        walk(ROOT_CLASS, "AInvoice", "", [ROOT_CLASS], items, fill, leaves)
        variants.append((items, fill, leaves))
    w("procedure CompareInvoices(A, B: TLandrixInvoice; ADiffs: TStrings);")
    w("begin")
    w("  CompareInvoiceFields(A, B, '', ADiffs);")
    w("end;")
    w("")
    w("procedure DumpInvoice(A: TLandrixInvoice; ALines: TStrings);")
    w("begin")
    w("  DumpInvoiceFields(A, '', ALines);")
    w("end;")
    w("")
    for items, fill, leaves in variants:
        w("procedure Fill%d(AInvoice: TLandrixInvoice);" % items)
        w("begin")
        L.extend(fill)
        w("end;")
        w("")
        w("procedure Mutate%d(AInvoice: TLandrixInvoice; AIndex: Integer; out APath: string);" % items)
        w("begin")
        w("  case AIndex of")
        for i, (p, st) in enumerate(leaves):
            w("    %d:" % i)
            w("      begin")
            w("        APath := '%s';" % p)
            w("        %s" % st)
            w("      end;")
        w("  else")
        w("    raise Exception.Create('MutateInvoiceLeaf: index ' + IntToStr(AIndex));")
        w("  end;")
        w("end;")
        w("")
    w("procedure CheckItems(AItems: Integer);")
    w("begin")
    w("  if (AItems < 1) or (AItems > 2) then")
    w("    raise Exception.Create('items per list: 1 or 2, not ' + IntToStr(AItems));")
    w("end;")
    w("")
    w("procedure FillInvoiceAll(AInvoice: TLandrixInvoice; AItems: Integer);")
    w("begin")
    w("  CheckItems(AItems);")
    w("  if AItems = 1 then")
    w("    Fill1(AInvoice)")
    w("  else")
    w("    Fill2(AInvoice);")
    w("end;")
    w("")
    w("function InvoiceLeafCount(AItems: Integer): Integer;")
    w("begin")
    w("  CheckItems(AItems);")
    w("  if AItems = 1 then")
    w("    Result := %d" % len(variants[0][2]))
    w("  else")
    w("    Result := %d;" % len(variants[1][2]))
    w("end;")
    w("")
    w("procedure MutateInvoiceLeaf(AInvoice: TLandrixInvoice; AIndex: Integer; out APath: string; AItems: Integer);")
    w("begin")
    w("  CheckItems(AItems);")
    w("  if AItems = 1 then")
    w("    Mutate1(AInvoice, AIndex, APath)")
    w("  else")
    w("    Mutate2(AInvoice, AIndex, APath);")
    w("end;")
    w("")
    w("end.")
    return L


def main(argv):
    args = argv[1:]
    if any(a != "--check" for a in args):
        fail("usage: gen-invoice-compare.py [--check]")
    classes, lists = parse(io.open(MODEL, encoding="utf-8").read())
    text = "\n".join(gen(classes, lists)) + "\n"
    if any(ord(c) > 127 for c in text):
        fail("non-ASCII output")
    data = text.replace("\n", "\r\n").encode("ascii")
    if "--check" in args:
        try:
            current = open(OUTPUT, "rb").read()
        except IOError:
            current = b""
        if current.replace(b"\r\n", b"\n") != data.replace(b"\r\n", b"\n"):
            sys.stderr.write("gen-invoice-compare: not up to date: tests/LandrixEInvoiceTestInvoiceCompare.pas\n")
            return 1
        print("gen-invoice-compare: up to date")
        return 0
    with open(OUTPUT, "wb") as f:
        f.write(data)
    nfields = sum(len(v) for v in classes.values())
    print("gen-invoice-compare: %d classes, %d lists, %d fields" % (len(classes), len(lists), nfields))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
