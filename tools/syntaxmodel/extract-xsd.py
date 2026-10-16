#!/usr/bin/env python3
"""Downloads the Factur-X EXTENDED schema (not part of the repository),
verifies the checksums of manifest.json and writes the reduced structure
description cii.json: namespaces, the root element and, per schema type,
either its element children (name, namespace, type, minOccurs, maxOccurs)
or its simple content (lexical base and attributes).

Only the XSD subset used by the schema is supported (sequence, choice with
one branch, element with type or anonymous complexType, simpleContent
extension with attributes, simpleType restriction); anything else stops the
extraction.

Usage:
  python tools/syntaxmodel/extract-xsd.py           download (if needed) and extract
  python tools/syntaxmodel/extract-xsd.py --check   exit 1 if cii.json differs
"""

import hashlib
import io
import json
import os
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


def main(argv):
    check = "--check" in argv[1:]
    if any(a != "--check" for a in argv[1:]):
        fail("unknown argument; usage: extract-xsd.py [--check]")
    manifest = json.load(io.open(os.path.join(HERE, "manifest.json"), encoding="utf-8"))
    entry = manifest["cii"]
    schema = Schema(load_files(entry), entry["main"])
    text = json.dumps(schema.describe(), indent=1, sort_keys=False) + "\n"
    out = os.path.join(HERE, entry["output"])
    if check:
        current = io.open(out, encoding="utf-8").read() if os.path.exists(out) else ""
        if current.replace("\r\n", "\n") != text:
            sys.stderr.write("extract-xsd: %s is not up to date\n" % out)
            return 1
        print("extract-xsd: up to date")
        return 0
    io.open(out, "w", encoding="utf-8", newline="\n").write(text)
    print("extract-xsd: wrote %s (%d types)" % (out, len(schema.describe()["types"])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
