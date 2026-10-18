#!/usr/bin/env python3
"""Downloads the Factur-X EXTENDED schema and the UBL 2.1 schema (not part
of the repository), verifies the checksums of manifest.json and writes the
reduced structure descriptions cii.json and ubl.json: namespaces, the root
element(s) and, per schema type, either its element children (name,
namespace, type, minOccurs, maxOccurs) or its simple content (lexical base
and attributes).

CII: only the XSD subset used by the Factur-X schema is supported
(sequence, choice with one branch, element with type or anonymous
complexType, simpleContent extension with attributes, simpleType
restriction); anything else stops the extraction.

UBL: only the children named in the positive list ubl-positive.json are
kept (type -> child elements); order, cardinality and types come from the
XSD. cbc elements are folded into their unqualified data type (udt); the
attribute types of the manifest keep all attributes of their CCTS core
component type (restrictions in udt override them, e.g. a required
currencyID), the other data types are plain text. ext:UBLExtensions is never
kept. Entries that are not children of their type, missing required
children and listed aggregate types without an entry stop the extraction.

Usage:
  python tools/syntaxmodel/extract-xsd.py            download (if needed) and extract
  python tools/syntaxmodel/extract-xsd.py --check    exit 1 if a JSON file differs
  python tools/syntaxmodel/extract-xsd.py --report   compare ubl-positive.json with the
                                                     EN 16931 UBL binding (report only)
"""

import hashlib
import html
import io
import json
import os
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
DOWNLOAD = os.path.join(HERE, "download")
XS = "{http://www.w3.org/2001/XMLSchema}"

BUILTIN = {
    "xs:decimal": "decimal",
    "xs:token": "token",
    "xs:string": "string",
    "xs:base64Binary": "base64",
    "xs:boolean": "boolean",
}


def fail(msg):
    sys.stderr.write("extract-xsd: " + msg + "\n")
    sys.exit(2)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def load_files(entry):
    os.makedirs(DOWNLOAD, exist_ok=True)
    zip_path = os.path.join(DOWNLOAD, os.path.basename(entry["url"].split("?")[0]))
    if not os.path.exists(zip_path):
        sys.stderr.write("extract-xsd: downloading %s\n" % entry["url"])
        with urllib.request.urlopen(entry["url"]) as r:
            data = r.read()
        with open(zip_path, "wb") as f:
            f.write(data)
    with open(zip_path, "rb") as f:
        data = f.read()
    if sha256(data) != entry["zip_sha256"]:
        fail("checksum mismatch for %s" % zip_path)
    files = {}
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for name, digest in entry["files"].items():
            content = z.read(entry["folder"] + name)
            if sha256(content) != digest:
                fail("checksum mismatch for %s" % name)
            files[name] = content
    return files


class Schema(object):
    def __init__(self, files, main):
        self.files = files
        self.prefix_of = {}       # namespace URI -> prefix used in the schema
        self.types = {}           # "prefix:Name" -> description
        self.root = None
        self.load(main)

    def qname(self, text, nsmap):
        prefix, _, local = text.rpartition(":")
        if prefix == "xs":
            return "xs:" + local
        uri = nsmap.get(prefix)
        if uri is None:
            fail("unknown prefix in %r" % text)
        return self.prefix_of[uri] + ":" + local

    def load(self, name):
        data = self.files[name]
        nsmap = dict(ev[1] for ev in ET.iterparse(io.BytesIO(data), events=["start-ns"]))
        root = ET.fromstring(data)
        tns = root.get("targetNamespace")
        if root.get("elementFormDefault") != "qualified":
            fail("%s: elementFormDefault must be qualified" % name)
        for prefix, uri in nsmap.items():
            if uri == tns:
                self.prefix_of[uri] = prefix
        prefix = self.prefix_of[tns]
        for child in root:
            tag = child.tag
            if tag == XS + "import":
                uri = child.get("namespace")
                for p, u in nsmap.items():
                    if u == uri:
                        self.prefix_of[uri] = p
                if child.get("schemaLocation") not in self.files:
                    fail("missing import %s" % child.get("schemaLocation"))
        for child in root:
            if child.tag == XS + "import":
                if not any(t.startswith(self.prefix_of[child.get("namespace")] + ":") for t in self.types):
                    self.load(child.get("schemaLocation"))
        for child in root:
            tag = child.tag
            if tag == XS + "import":
                continue
            elif tag == XS + "element":
                self.root = {"name": child.get("name"), "ns": prefix,
                             "type": self.qname(child.get("type"), nsmap)}
            elif tag == XS + "complexType":
                self.types[prefix + ":" + child.get("name")] = self.complex_type(
                    child, nsmap, prefix, prefix + ":" + child.get("name"))
            elif tag == XS + "simpleType":
                restriction = child.find(XS + "restriction")
                if restriction is None or len(list(restriction)) != 0:
                    fail("unsupported simpleType %s" % child.get("name"))
                self.types[prefix + ":" + child.get("name")] = {
                    "kind": "restriction", "base": self.qname(restriction.get("base"), nsmap)}
            else:
                fail("unsupported top-level %s" % tag)

    def complex_type(self, node, nsmap, prefix, path):
        items = list(node)
        if len(items) != 1:
            fail("%s: expected one content model" % path)
        model = items[0]
        if model.tag in (XS + "sequence", XS + "choice"):
            if model.tag == XS + "choice" and len(list(model)) != 1:
                fail("%s: choice with more than one branch" % path)
            children = []
            for el in model:
                if el.tag != XS + "element":
                    fail("%s: unsupported particle %s" % (path, el.tag))
                child = {"name": el.get("name"), "ns": prefix,
                         "min": int(el.get("minOccurs", "1")),
                         "max": -1 if el.get("maxOccurs") == "unbounded" else int(el.get("maxOccurs", "1"))}
                if el.get("type"):
                    child["type"] = self.qname(el.get("type"), nsmap)
                else:
                    anon = el.find(XS + "complexType")
                    if anon is None:
                        fail("%s/%s: element without type" % (path, el.get("name")))
                    anon_name = path + "/" + el.get("name")
                    self.types[anon_name] = self.complex_type(anon, nsmap, prefix, anon_name)
                    child["type"] = anon_name
                children.append(child)
            return {"kind": "complex", "children": children}
        if model.tag == XS + "simpleContent":
            ext = model.find(XS + "extension")
            if ext is None or len(list(model)) != 1:
                fail("%s: unsupported simpleContent" % path)
            attributes = []
            for a in ext:
                if a.tag != XS + "attribute":
                    fail("%s: unsupported %s" % (path, a.tag))
                attributes.append({"name": a.get("name"),
                                   "required": a.get("use") == "required",
                                   "default": a.get("default")})
            return {"kind": "simple", "base": self.qname(ext.get("base"), nsmap),
                    "attributes": attributes}
        fail("%s: unsupported content model %s" % (path, model.tag))

    def lexical_base(self, name):
        seen = set()
        while name not in BUILTIN:
            if name in seen or name not in self.types:
                fail("cannot resolve base %s" % name)
            seen.add(name)
            name = self.types[name]["base"]
        return BUILTIN[name]

    def describe(self):
        uris = {p: u for u, p in self.prefix_of.items()}
        types = {}
        for name, t in sorted(self.types.items()):
            if t["kind"] == "restriction":
                continue  # folded into the simple types that use it
            if t["kind"] == "simple":
                types[name] = {"kind": "simple", "base": self.lexical_base(t["base"]),
                               "attributes": t["attributes"]}
            else:
                for c in t["children"]:
                    if c["type"].startswith("xs:"):
                        if c["type"] not in BUILTIN:
                            fail("unsupported built-in %s" % c["type"])
                    elif c["type"] not in self.types:
                        fail("unknown type %s" % c["type"])
                types[name] = t
        return {"namespaces": dict(sorted(uris.items())), "root": self.root, "types": types}


UBL_BUILTIN = {
    "xsd:decimal": "decimal",
    "xsd:string": "string",
    "xsd:normalizedString": "string",
    "xsd:base64Binary": "base64",
    "xsd:boolean": "boolean",
    "xsd:date": "date",
    "xsd:time": "time",
    "xsd:dateTime": "dateTime",
}


class UblSchema(object):
    """UBL 2.1 Invoice and CreditNote, reduced to a positive list."""

    def __init__(self, files, entry, positive):
        self.files = files
        self.prefix_of = entry["prefixes"]          # namespace URI -> prefix
        self.attribute_types = set(entry["attribute_types"])
        self.positive = positive["types"]
        self.elements = {}    # "cbc:Note" -> type qname
        self.complex = {}     # "cac:PartyType" -> [(element qname, min, max)]
        self.simple = {}      # "udt:TextType" -> (kind, base qname, {attribute: required})
        self.roots = []
        self.loaded = set()
        for name in entry["main"]:
            self.load(name)

    def qname(self, text, nsmap):
        prefix, _, local = text.rpartition(":")
        uri = nsmap.get(prefix)
        if uri == "http://www.w3.org/2001/XMLSchema":
            return "xsd:" + local
        if uri not in self.prefix_of:
            fail("unknown namespace of %r" % text)
        return self.prefix_of[uri] + ":" + local

    def load(self, name):
        if name in self.loaded:
            return
        self.loaded.add(name)
        data = self.files[name]
        nsmap = dict(ev[1] for ev in ET.iterparse(io.BytesIO(data), events=["start-ns"]))
        root = ET.fromstring(data)
        tns = root.get("targetNamespace")
        prefix = self.prefix_of[tns]
        nsmap[""] = nsmap.get("", tns)
        for child in root:
            if child.tag == XS + "import":
                uri = child.get("namespace")
                if self.prefix_of.get(uri) == "ext":
                    continue  # extensions are never kept
                target = os.path.normpath(os.path.join(os.path.dirname(name),
                                                       child.get("schemaLocation"))).replace(os.sep, "/")
                if target not in self.files:
                    fail("missing import %s" % target)
                self.load(target)
        for child in root:
            tag = child.tag
            if tag in (XS + "import", XS + "annotation"):
                continue
            if tag == XS + "element":
                qn = prefix + ":" + child.get("name")
                self.elements[qn] = self.qname(child.get("type"), nsmap)
                if name in self.roots_files():
                    self.roots.append({"name": child.get("name"), "ns": prefix,
                                       "type": self.elements[qn]})
            elif tag == XS + "complexType":
                self.complex_type(prefix + ":" + child.get("name"), child, nsmap)
            else:
                fail("%s: unsupported top-level %s" % (name, tag))

    def roots_files(self):
        return [n for n in self.files if "/maindoc/" in n]

    def complex_type(self, qn, node, nsmap):
        items = [c for c in node if c.tag != XS + "annotation"]
        if len(items) != 1:
            fail("%s: expected one content model" % qn)
        model = items[0]
        if model.tag == XS + "sequence":
            children = []
            for el in model:
                if el.tag == XS + "annotation":
                    continue
                if el.tag != XS + "element" or not el.get("ref"):
                    fail("%s: unsupported particle" % qn)
                mx = el.get("maxOccurs", "1")
                children.append((self.qname(el.get("ref"), nsmap), int(el.get("minOccurs", "1")),
                                 -1 if mx == "unbounded" else int(mx)))
            self.complex[qn] = children
            return
        if model.tag != XS + "simpleContent":
            fail("%s: unsupported content model" % qn)
        derivation = [c for c in model if c.tag != XS + "annotation"]
        if len(derivation) != 1 or derivation[0].tag not in (XS + "extension", XS + "restriction"):
            fail("%s: unsupported simpleContent" % qn)
        d = derivation[0]
        attributes = {}
        for a in d:
            if a.tag == XS + "annotation":
                continue
            if a.tag != XS + "attribute":
                fail("%s: unsupported %s" % (qn, a.tag))
            attributes[a.get("name")] = a.get("use") == "required"
        kind = "extension" if d.tag == XS + "extension" else "restriction"
        self.simple[qn] = (kind, self.qname(d.get("base"), nsmap), attributes)

    def resolve_simple(self, qn):
        """(udt type, lexical base, [attributes]) of a cbc element type."""
        kind, base, attrs = self.simple[qn]
        if qn.startswith("cbc:"):
            if attrs or kind != "extension" or not base.startswith("udt:"):
                fail("%s: cbc type is not a plain extension of a udt type" % qn)
            return self.resolve_simple(base)
        # walk udt -> ccts -> built-in, collecting attributes (nearest wins)
        chain = []
        t = qn
        while t not in UBL_BUILTIN:
            if t not in self.simple:
                fail("cannot resolve %s" % t)
            chain.append(self.simple[t])
            t = self.simple[t][1]
        merged = []
        seen = {}
        for _, _, a in reversed(chain):
            for name, req in a.items():
                if name in seen:
                    merged[seen[name]]["required"] = req
                else:
                    seen[name] = len(merged)
                    merged.append({"name": name, "required": req, "default": None})
        if qn not in self.attribute_types:
            merged = []
        return qn, UBL_BUILTIN[t], merged

    def describe(self):
        types = {}
        listed = self.positive
        for t in [r["type"] for r in self.roots]:
            if t not in listed:
                fail("root type %s not in the positive list" % t)
        for t, wanted in sorted(listed.items()):
            if t not in self.complex:
                fail("positive list: unknown aggregate type %s" % t)
            xsd_children = [c for c in self.complex[t] if not c[0].startswith("ext:")]
            names = [c[0] for c in xsd_children]
            for w in wanted:
                if w not in names:
                    fail("positive list: %s is no child of %s" % (w, t))
            children = []
            for el, mn, mx in xsd_children:
                if el not in wanted:
                    if mn >= 1:
                        fail("positive list: required child %s of %s missing" % (el, t))
                    continue
                et = self.elements[el]
                if el.startswith("cac:"):
                    if et not in listed:
                        fail("positive list: type %s of %s/%s has no entry" % (et, t, el))
                    ctype = et
                else:
                    ctype, base, attrs = self.resolve_simple(et)
                    types[ctype] = {"kind": "simple", "base": base, "attributes": attrs}
                ns, _, local = el.partition(":")
                children.append({"name": local, "ns": ns, "type": ctype, "min": mn, "max": mx})
            types[t] = {"kind": "complex", "children": children}
        uris = {p: u for u, p in self.prefix_of.items() if p in ("inv", "cn", "cac", "cbc", "ext")}
        roots = [r for r in self.roots if r["type"] in listed]
        return {"namespaces": dict(sorted(uris.items())), "roots": roots,
                "skip": [{"ns": "ext", "name": "UBLExtensions"}],
                "types": dict(sorted(types.items()))}

    def en16931_report(self, rules_xsl):
        """Children allowed by the EN 16931 UBL binding (XSD minus the
        UBL-CR rules) compared with the positive list. Report only."""
        forbidden, anywhere = set(), set()
        for m in re.finditer(r'<xsl:if test="([^"]*)">\s*<svrl:failed-assert[^>]*?id="UBL-CR-\d+"',
                             rules_xsl, re.S):
            t = html.unescape(m.group(1))
            mm = re.fullmatch(r"not\(not\((.+)\)\)", t)
            if not mm or re.search(r"[@\[ ]", mm.group(1)):
                continue
            alts = [mm.group(1)]
            while any("(" in a for a in alts):
                nxt = []
                for a in alts:
                    g = re.search(r"\(([^()]*)\)", a)
                    if not g:
                        nxt.append(a)
                        continue
                    nxt.extend(a[:g.start()] + o + a[g.end():] for o in g.group(1).split("|"))
                alts = nxt
            for a in alts:
                (anywhere if a.startswith("//") else forbidden).add(a.lstrip("/"))

        def blocked(rel):
            return rel in forbidden or any(rel == a or rel.endswith("/" + a) for a in anywhere)

        allowed = {}

        def walk(t, rel, stack):
            for el, _, _ in self.complex.get(t, []):
                if el.startswith("ext:"):
                    continue
                r = rel + "/" + el if rel else el
                if blocked(r):
                    continue
                allowed.setdefault(t, set()).add(el)
                et = self.elements[el]
                if el.startswith("cac:") and et in self.complex and et not in stack:
                    walk(et, r, stack + [et])

        for r in self.roots:
            walk(r["type"], "", [r["type"]])
        missing = [(t, c) for t in sorted(allowed) for c in sorted(allowed[t])
                   if c not in self.positive.get(t, [])]
        extra = [(t, c) for t in sorted(self.positive) for c in self.positive[t]
                 if c not in allowed.get(t, set())]
        return missing, extra


def load_positive(entry):
    return json.load(io.open(os.path.join(HERE, entry["positive_list"]), encoding="utf-8"))


def write_or_check(entry, data, check):
    text = json.dumps(data, indent=1, sort_keys=False) + "\n"
    out = os.path.join(HERE, entry["output"])
    if check:
        current = io.open(out, encoding="utf-8").read() if os.path.exists(out) else ""
        if current.replace("\r\n", "\n") != text:
            sys.stderr.write("extract-xsd: %s is not up to date\n" % out)
            return 1
        print("extract-xsd: %s up to date" % entry["output"])
        return 0
    io.open(out, "w", encoding="utf-8", newline="\n").write(text)
    print("extract-xsd: wrote %s (%d types)" % (out, len(data["types"])))
    return 0


def main(argv):
    args = argv[1:]
    if any(a not in ("--check", "--report") for a in args) or len(args) > 1:
        fail("unknown argument; usage: extract-xsd.py [--check | --report]")
    check = "--check" in args
    manifest = json.load(io.open(os.path.join(HERE, "manifest.json"), encoding="utf-8"))
    ubl_entry = manifest["ubl"]
    ubl_files = load_files(ubl_entry)
    ubl = UblSchema(ubl_files, ubl_entry, load_positive(ubl_entry))
    if "--report" in args:
        rules = ubl_files[ubl_entry["en16931_rules"]].decode("utf-8")
        missing, extra = ubl.en16931_report(rules)
        print("EN 16931 children missing from the positive list: %d" % len(missing))
        for t, c in missing:
            print("  %s %s" % (t, c))
        print("positive list entries outside the EN 16931 binding: %d" % len(extra))
        for t, c in extra:
            print("  %s %s" % (t, c))
        return 0
    cii_entry = manifest["cii"]
    result = write_or_check(cii_entry, Schema(load_files(cii_entry), cii_entry["main"]).describe(), check)
    return write_or_check(ubl_entry, ubl.describe(), check) or result


if __name__ == "__main__":
    sys.exit(main(sys.argv))
