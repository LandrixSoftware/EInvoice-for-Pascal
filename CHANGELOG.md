# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Supported invoice standards are documented per release.

## [Unreleased]

### Added
- The document validation takes a file with up to 1024 bytes before `%PDF-` as a PDF, as PDF readers do
  (unless it starts like XML), and reports the bytes as LX-PDF-13 (warning, `pdfEmbedding`), also for a
  PDF/A-4 claim and when the PDF cannot be read; before, such a file went the XML way. `IsPdfStream`
  is unchanged, so `TLandrixEInvoice.LoadFromStream` and the Workbench still read such a file as XML.
- Advisory checks: internal unit `LandrixEInvoiceAdvisory` (`LandrixEInvoiceAdvise`, families
  `TLandrixEInvoiceAdvisoryFamilies`, default `LandrixEInvoiceAdvisoryTechnical`). The document
  validation runs them on the invoice as read (`Options.Advisory`) and shows their hints in the new
  part `evp_Advisory`: infos and warnings only, never part of the verdict, `evr_Incomplete` (with a
  warning) when they stop, never `evr_Failed`. The XML report counts them apart (`findings/@advisory`,
  part `advisory`), the HTML report and the Workbench show them. First family `eaf_Identifiers`:
  LX-ID-01 to LX-ID-05 report bidirectional control and invisible characters and spaces other than
  U+0020 in identifiers (bidirectional control and invisible characters in names and texts only as an
  info), C1 control characters in every field, and characters outside ASCII in identifiers whose
  scheme is ASCII (VAT identifiers, country and currency codes, GTIN, BIC, SEPA creditor identifier,
  the mandate reference of a SEPA direct debit, an IBAN), with the model path, the code point and the
  value masked as `<U+XXXX>`; surrogate pairs count as one character. LX-ID-06 to LX-ID-10 check
  identifiers by their scheme: GLN (0088, 13 digits and GS1 check digit; for Peppol BIS no second
  report of PEPPOL-COMMON-R040), GTIN (0160 at BT-157 and the GTIN field: 8, 12, 13 or 14 digits and
  check digit), a GTIN for a party or a GLN for an item, the Leitweg-ID (0204, format specification
  2.0.2 with MOD 97-10 check digits, also BT-10 when it looks like one) and a buyer reference that
  differs from the buyer's Leitweg-ID. Expected and found check digits are in `Expected` and `Found`.
  `LandrixEInvoiceIdentifiers` has the new building blocks `LandrixEInvoiceGS1CheckDigit` and
  `LandrixEInvoiceLeitwegIDProblem`. A second family `eaf_Plausibility` (LX-PL-01 to LX-PL-05,
  on by default) reports a due date before the invoice date, an IBAN with wrong form, country code or check digits
  (`LandrixEInvoiceIBANCheckDigits`; no length per country, the IBAN registry of SWIFT may not be copied for
  profit), a BIC of wrong form, an account holder who is not the seller
  without a payee (info) and a SEPA direct debit without mandate reference, creditor identifier or
  debited account. A third family `eaf_German` (LX-DE, legal, only on request) reports MINIMUM or
  BASIC WL between German parties also for plain XML (LX-DE-01: no permitted e-invoice format
  according to the BMF). `LandrixEInvoiceAdvise` takes the rule identifiers the rule check reported and
  does not repeat them.
- `docs/rules.md` (and the German `docs/de/rules.md`) lists the library's own rule identifiers
  (LX-CC-01 to LX-CC-12, LX-PDF-01 to LX-PDF-13, LX-ID-01 to LX-ID-10, LX-PL-01 to LX-PL-05, LX-DE-01) with severity, scope and the version they came
  with, and how they are kept stable; `tools/check-forbidden.py` fails when the sources and the
  lists disagree. The warning that the PDF/A check stopped has its own identifier LX-PDF-12 instead
  of LX-PDF-01 (a broader condition gets a new number).
- Rule details: `TLandrixEInvoiceDiagnostic` has new fields `Terms`, `Expected`, `Found` and
  `Calculation` and the methods `Assign` and `AddCopy` (the facade and the XRechnung adapter copy
  every field). The calculation rules BR-CO-10 to BR-CO-17, BR-FXEXT-CO-10 to BR-FXEXT-CO-13,
  BR-FXEXT-CO-15, BR-FXEXT-CO-16, BR-DEX-09 and PEPPOL-EN16931-R040, R046 and R120 report the
  expected and the found value, how
  the expected value came about and the model path of the first wrong place (e.g.
  `InvoiceLines[0].LineAmount`); R041, R042, R110, R111, R121 and R130 report the path. The
  validation findings carry the same fields, the XML report writes them (see report version 2), the
  HTML report and the Workbench show them. The rule check through the facade judges the caller's invoice, so its paths fit the
  caller's invoice; paths into lines the target writes flat are left out. Numbers and dates that
  cannot be written count only where they are written (not in group lines or INFORMATION lines
  the flat copy leaves out), also for direct calls of the check.
- PDF/A oracle (preparation of the native PDF/A-3b check, level 1 of the PDF checker):
  `addons/java-tools/install-tools.ps1` installs the veraPDF 1.30.4 command line (its IzPack
  installer unattended, the command line pack only), `tools/testdata/sync-local.py` the veraPDF
  test corpus 1.30.4 for PDF/A-2 and -3 (corpus `verapdf`, 1,072 PDFs, CC BY 4.0), and
  `tools/pdfcheck/verapdf-oracle.py` checks the corpus against veraPDF under each file's own
  profile and writes `tests/data/verapdf-expected.txt`: the PDF/A-3b result of every corpus file
  and invoice PDF, the target of the native check.
- Raw PDF syntax facts for the native PDF/A check (step 2, `API: internal`): the PDF object
  layer reports, when a receiver is set before `Load`, what the parser sees (numbers, strings,
  names, streams with the end their `/Length` gives, the envelope `n g obj ... endobj` of every
  object, every xref section with its trailer, every break of the xref chain and every piece of
  malformed syntax it recovers from). `LandrixEInvoicePdfSyntax` collects them for every object
  in use, also unreferenced ones, plus header line and the bytes after `%%EOF`; whatever could
  not be observed marks the facts incomplete. Normal reading is unchanged.
  `tools/pdfcheck/PdfCheckProbe.dpr -syntax` prints a summary per file (1,599 of the 1,600
  corpus and invoice PDFs complete; the rules follow in step 3).
- Native PDF/A-3b check, level 1 of the PDF checker (`API: internal`): `LandrixEInvoicePdfARules` checks
  the rules of clause 6.1 (file structure) on the raw syntax facts, numbered as in the veraPDF profile
  (finding IDs `PDFA-6.1.2-1` etc.). A registry states per rule whether it is fully implemented (header,
  trailer, `%%EOF`, xref, stream length and line ends, external streams, filters, object envelopes,
  permissions, object count, page boundaries), partial (hexadecimal strings and the limits of numbers,
  strings and names: content streams are not read yet) or not yet implemented. `TLandrixEInvoicePdfChecker`
  runs it as level 1 (`epl_PdfA`) after levels 2 and 3, not for a PDF/A-4 claim (its rules are not
  implemented): a violation gives `eps_Failed`, otherwise `eps_Incomplete`, never `eps_Passed`. The document validator shows the findings and
  status under `evp_PdfA`; PDF/A does not count for the verdict. `PdfCheckProbe -pdfa` prints the failed
  rules; the test `PdfA.VeraPdf` compares the rules with `tests/data/verapdf-expected.txt` over the local
  corpora (1,600 PDFs: no rule fails that veraPDF passes, no fully implemented rule passes that veraPDF
  fails; accepted differences in `tests/data/pdfa-exceptions.txt`, none so far). The corpus has no
  veraPDF failure of 6.1.3-3, 6.1.7.2-1, 6.1.13-2 and 6.1.13-7; the first three are covered by
  `PdfA.Violations` only. The validator's test PDFs now carry a binary comment and `/ID`.
- PDF/A level 1, stage B: the rules of clauses 6.3 (annotations: types, flags, appearances), 6.4
  (interactive forms: no actions on widgets and fields, NeedAppearances, XFA, NeedsRendering) and 6.5
  (actions: permitted types and named actions, no additional actions on catalog and pages), found where
  veraPDF finds them (the `/Annots` of the pages; `/A`, the named `/AA` events, a dictionary
  `/OpenAction`, outline items and `/Next` chains; the AcroForm fields). The signature rules 6.4.3 are not
  implemented yet. Tests `PdfA.Interactive` and `PdfA.Interactive2` (every rule and the details of
  veraPDF's reading); `PdfA.VeraPdf` agrees with veraPDF on all 1,600 PDFs.
- PDF/A level 1, rest of stage A: the rules of clauses 6.8 (embedded files: MIME type, `/F` and `/UF`,
  `/AFRelationship`, associated files), 6.9 (optional content configurations: name, unique names, `/Order`
  lists every group, no `/AS`), 6.10 (no `/AlternatePresentations`, no `/PresSteps`) and 6.11 (no
  `/Requirements`), read as veraPDF reads them: file specifications are the `/Type /Filespec` dictionaries
  of all objects and the values of the EmbeddedFiles name tree; a file specification counts as associated
  only when it is indirect and named in an `/AF` array. 6.8-2 to 6.8-4 stay partial until content streams
  are read; a missing association is reported only when no `/AF` array and no `/Properties` array names
  the file specification. Test `PdfA.Files`; `PdfA.VeraPdf` still agrees with veraPDF on all 1,600 PDFs.
- PDF/A level 1, stage C, first part: an XMP reader of its own (internal unit `LandrixEInvoicePdfXmp`) that reads
  a packet as the RDF grammar of the XMP Specification (2005) and veraPDF's parser do (xpacket header, encoding,
  original prefixes, simple values, structures, arrays, qualifiers, qualified values) and calls a packet invalid
  only for forms that parser rejects; whatever it cannot decide leaves the rules incomplete. With it the rules of
  6.6.2.1 (catalog metadata stream, no bytes and encoding in the xpacket header, valid packet, UTF-8; for the
  catalog's packet and every metadata stream another dictionary names) and 6.6.4 (pdfaid present, part 3,
  conformance A, B or U, the prefix pdfaid). The validator's PDF without XMP now also shows PDFA-6.6.2.1-1.
  Test `PdfA.Metadata`; `PdfA.VeraPdf` still agrees with veraPDF on all 1,600 PDFs.
- PDF/A level 1, stage C, second part: the extension schema rules 6.6.2.3.2 and 6.6.2.3.3 (the
  `pdfaExtension:schemas` container a Bag, every schema, property, value type and field with its required fields,
  the prefixes as written, Seq where required, no foreign fields, category external or internal, value types known),
  on the catalog's packet and every further one, read as veraPDF reads them: `rdf:Alt` counts as Seq, "URI" means
  any simple value, a structure or array where a value is read counts as '', a value type is known if it is built in
  or defined by the schema of the same namespace URI (type names simplified as veraPDF does: case, "Closed Choice
  of", "Bag", "Seq"); a further packet takes the types of the main packet's schema with the same URI, a schema of
  its own all built-in types. Where veraPDF's reading is not established (characters beyond ASCII or line ends in a
  type name, limits) the rule stays incomplete. Test `PdfA.Extension`; `PdfA.VeraPdf` still agrees with veraPDF on
  all 1,600 PDFs, all corpus failures of these rules found.
- PDF/A level 1, stage C, last part: rule 6.6.2.3.1 (every XMP property predefined or defined by an extension
  schema; its value of the defined type), with the predefined schemas and value types built from the XMP
  Specification (2005), chapter 4, and PDF Association TechNote 0010 (A020): 277 properties in 14 namespaces (with
  pdfaid) and 20 structured types. Read as veraPDF reads them: top-level properties of every packet; the definition
  of this packet, then of the main packet, then the predefined one; simple types by their lexical form (Boolean,
  Integer, Real, Date, MIMEType, GPSCoordinate; the text types any simple value), Lang Alt, bag/seq/alt arrays item
  by item, structures field by field (missing fields allowed); choice vocabularies and ranges unchecked. Where
  veraPDF reads less strictly than the specification (xmp:Rating and the Colorant fields A and B as Real, XPath, the
  time fields of Marker) or a property occurs in several packets with different answers, the rule stays incomplete
  rather than failed. With this stage all 33 rules of clause 6.6 are checked. Test `PdfA.Properties`; `PdfA.VeraPdf`
  still agrees with veraPDF on all 1,600 PDFs, all 305 corpus failures of 6.6.2.3.1 found.
- PDF/A level 1, content streams (internal unit `LandrixEInvoicePdfContent`): the content streams veraPDF reads (page
  `/Contents`, also as an array; form XObjects called with `Do`; tiling patterns selected with `scn`/`SCN`; all glyph
  procedures of a Type 3 font that shows text; the normal, down and rollover appearances of annotations) are
  tokenized as veraPDF does, and the operands each operator passes on (a table of all 71 operators: `w` its last
  operand, `cm` all numbers, `TJ` its array, inline dictionaries with keys and values, ...) count for 6.1.6-1/-2
  and 6.1.13-1 to -5. New: 6.1.10-1 (inline image filters), 6.1.13-8 (`q` nested at most 28 levels per stream),
  file specifications inside inline dictionaries and the association through `/AF /Name BDC` (6.8-2 to -4); a
  file specification named only in a `/Properties` array is no longer counted as associated. These rules are now
  fully implemented. A stream veraPDF might read differently (Flate data that is not a clean zlib stream, other
  filters, encryption, a number on a limit, a stream reached in several contexts with different results) leaves
  the rule incomplete. 6.1.13-3 now measures strings as veraPDF does (UTF-16 code units of the bytes decoded as
  UTF-8), also in objects. `PdfCheckProbe -pdfa` also prints the fully implemented rules that stayed undecided
  (`pdfa-open`). Resources, colour spaces (defaults, aliases, one-element arrays, pattern spaces), fonts, the start
  state of forms, tiling patterns and Type 3 glyphs and the page tree (pages counted through `/Count`, resources
  inherited from the actual parent) follow veraPDF; a broken page tree, a catalog not reached from `/Root` or a limit
  leaves the content rules incomplete, and so does a tiling pattern veraPDF reads without `scn` (where a colour space
  is expected), an uncoloured tiling pattern or a pattern space with an underlying space (veraPDF then changes the
  start state of the stream's tiling patterns). The object parser now reads dictionaries as veraPDF does (a repeated key
  replaces the value in place, null removes the entry, also against an older trailer), checks generations in object
  headers and along reference chains, keeps integer tokens exact and takes no exponent, `Inf` or `NaN` as a number.
  For 6.8-4 an `/AF` entry names the object at the end of its reference chain, and owners count as veraPDF builds
  them (annotations, XObjects, fonts, structure elements). Tests `PdfA.Content` to `PdfA.Content9`; `PdfA.VeraPdf`
  still agrees with veraPDF on all 1,600 PDFs, and the seven corpus failures in content streams it missed before are
  found.
- PDF/A level 1, stage D, first part: the graphics rules 6.2.2-1 (operators ISO 32000-1 does not define, also between
  `BX` and `EX`), 6.2.5-1 to -6 (`/TR`, `/TR2`, `/HTP` of an ExtGState; halftone type, `/HalftoneName` and
  `/TransferFunction` per colorant, Type 5 halftones included), 6.2.6-1 (rendering intents of `ri`, of an ExtGState
  `/RI` and of an image `/Intent`), 6.2.8-1 to -5 (`/Alternates`, `/OPI`, `/Interpolate` and `BitsPerComponent` of
  images, inline images, their `/Mask` and `/SMask` streams and alternates), 6.2.9-1 to -3 (form XObjects with `/OPI`,
  `/PS`, `/Subtype2 /PS` or `/Ref`, PostScript XObjects) and 6.2.10-1 (blend modes; of an array its first name), all
  fully implemented. They judge the objects veraPDF builds from the content it reads: the ExtGState a `gs` selects, the
  XObject a `Do` calls (also an image dictionary that is no stream), every annotation appearance stream as a form
  whatever its `/Subtype` (an `/AP` that is a stream gives none, also for the earlier content rules); unused resources
  are not judged. A halftone veraPDF may meet first under another colorant leaves 6.2.5-6 incomplete; an alternate
  dictionary without an image stream anywhere in the file (veraPDF throws on it) leaves every content rule incomplete,
  and so does a content stream with a name ending in an unfinished `#` escape or with an ASCII85 string `<~...~>`. The
  content lexer now ends an inline image at `EI` before another `EI` and reads a real `/L` by its integer part.
  Test `PdfA.Graphics`; `PdfA.VeraPdf` agrees with veraPDF on all 1,600 PDFs and finds all 36 corpus failures of these
  rules.
- PDF/A level 1, stage D, second part (output intents): 6.2.3-1 (the `/DestOutputProfile` of every catalog output
  intent is a printer or monitor profile for RGB, CMYK or Gray below ICC version 5, judged from the header bytes
  veraPDF reads, not from `/N`), 6.2.3-2 (all indirect `/DestOutputProfile` references are the same object) and
  6.2.3-3 (no `/DestOutputProfileRef` in a PDF/X output intent), all fully implemented. References lead only to the
  object in use with their generation. The profile header is decided only where veraPDF certainly reads the same
  bytes (no filter or `FlateDecode` alone, intact zlib data, no decode parameters, an integer `/Length`, at least 20
  unfiltered bytes, not encrypted, no external file); otherwise 6.2.3-1 is incomplete, and so are the three rules
  for a reference chain too long to follow. The colour space of the PDF/A output profile is kept for the colour
  rules that follow. Test `PdfA.OutputIntents`; 4 of the 5 corpus failures of these rules are found, the fifth (a
  damaged profile stream) stays incomplete.
- PDF/A level 1, stage D, third part (colour spaces in content): 6.2.4.3-2, -3 and -4 (DeviceRGB, DeviceCMYK and
  DeviceGray only with an output intent that allows them; an output intent colour space that cannot be read leaves
  them incomplete), 6.2.4.2-1 (ICC input profiles: input, display, output or colour space profile for RGB, CMYK,
  Gray or Lab below version 5), 6.1.13-9 (at most 32 DeviceN colourants) and 6.2.4.4-1 (every DeviceN colourant
  is in `/Colorants` or a process component), all fully implemented. The content walk keeps the fill and stroke
  colour space and the text rendering mode and follows the links veraPDF makes: colour, painting and text operators,
  `sh`, images (stencil masks with the fill space, also after `d1`), inline images, page, form and appearance
  groups, Indexed bases, Separation and DeviceN alternates, process spaces and colourants, with `/Default*` spaces
  and aliases resolved as veraPDF does. Objects veraPDF validates once by identity (indirect images, shadings,
  colour space arrays, groups) count as certain only when every context they are reached in agrees; routes not
  modelled (soft masks, alternate images, shading patterns, JPEG 2000, 3D annotations) leave the findings
  uncertain. Test `PdfA.Colour`; no false positives in the corpus, 210 of 213 expected failures found, the other three
  stay incomplete.

### Changed
- Code lists: EN 16931 code list values version 18 of the European Commission (valid from 2026-11-15)
  instead of version 17. New members: electronic address scheme 9960, ICD 0249 to 0251 and the 18
  Spanish exemption reasons `VATEX-ES-*`. The rule check keeps judging them as the validators of
  today do (CEN 1.3.16, which does not list them) until they move to CEN 1.3.17.
- CII writer (from `TLandrixInvoice`): what CEN 1.3.17 will reject is still written, with an info: a
  second payment card (CII-SR-495) or a second debited account (CII-SR-496) in the CII as written. An
  attachment without MIME code or file name (CII-DT-105, CII-DT-106) was already reported as missing.
- Diagnostics: the business terms of a rule violation (and of the values the rule check and the
  calculation cannot write or judge) are in the new field `Terms`, no longer in `Path`. For the
  rule check `Path` is now the model path of the violation, or empty; reading and writing keep
  the element path. `ToText` shows the terms where the path stood, so its output is unchanged
  for entries without a path.
- Validation report version 2.0 (internal unit `LandrixEInvoiceValidationReport`): namespace
  `urn:landrix:einvoice:validation-report:2`, schema `schemas/landrix-einvoice-validation-report-2.xsd`;
  version 1 is no longer written (its schema stays in the repository). Verdict, parts, PDF facts and
  findings are below `document` (one is written; the schema allows several). A finding has its path
  in `location` for every part and the business terms of the rule check in the attribute `terms`
  (version 1.0 had the terms in `location`). Standard, profile, hybrid kind and the configuration
  choice and kind are open lists (a consumer treats an unknown value as "other"); verdict, status,
  severity and part stay closed. The element `recipient` and the attribute `finding/@recipient` are
  reserved for recipient profiles and not written yet. `document/@sha256` and `pdf/@invoiceSha256`
  hold the SHA-256 of the validated bytes and of the embedded invoice (`DocumentSha256`,
  `InvoiceSha256` of `TLandrixEInvoiceDocumentValidation`).
- Commercial license: a German version, which prevails; the price is 950 EUR per company; one commercial
  license covers EInvoice-for-Pascal and XRechnung-for-Delphi together.
- Peppol rules: the Peppol Schematron 3.0.22 (OpenPEPPOL October 2026 hotfix, RFC-607) replaces 3.0.21.
  PEPPOL-EN16931-P0112 now also restricts the invoice type code 389 to German parties, and allows 384
  between two Slovak parties as well (Slovakia by the VAT identifier prefix, for the seller also that of
  the tax representative, else the postal country). The pin in `addons/kosit/kosit.json` and the
  OpenPEPPOL unit tests of `tools/rulecheck/peppol-oracle.py` follow; the KoSIT configuration Peppol BIS
  stays at 3.0.21 until KoSIT publishes a newer one, so for 384 between Slovak parties whose postal
  addresses are not both in Germany the native validation accepts what the KoSIT validator rejects (documented in the validation guide; the oracle
  lists the differences in `tools/kosit/kosit-exceptions.txt`). `kosit-oracle.py` no longer reports
  exceptions for `--report` differences as unused when it runs without `--report`, and a report
  difference carries the digests of both masked reports, so an exception covers exactly that pair.
- Validation guide: the validators are not thread-safe (schemas and rules load on first use); give
  each thread its own validators and result objects, or let one thread at a time validate; the
  remaining 32-bit x86 effect on the FPU control word is described there.

### Fixed
- Reading CII: the due date of a cash discount term whose own period (basis date plus days) ends on another date is the
  net due date BT-9 when no net term gives one, as ZUGFeRD EXTENDED invoices write it (`#SKONTO#` term with
  `DueDateDateTime`); it was dropped silently. Further differing dates are reported.

## [0.9.0-beta.2] - 2026-11-17

Second pre-release: the KoSIT originals (report and visualization) with the XSLT engine of
LandrixXML 0.5.0, and a release ZIP that contains the submodule. Supported invoice standards
are those of 0.9.0-beta.1.

### Added
- The KoSIT originals with the XSLT engine of LandrixXML (preview, `API: internal`):
  `LandrixEInvoiceKositReportInput` writes the KoSIT report input (`in:createReportInput`, with the
  SVRL of every Schematron step), `LandrixEInvoiceKositReport` runs the configuration's report
  stylesheet on it and extracts the HTML page, as the KoSIT validator does with
  `--extract-html`, and `LandrixEInvoiceKositVisualization` runs the KoSIT XRechnung
  visualization (UBL / CII to XR to HTML). Only these two units link the XSLT engine
  (`tools/check-forbidden.py` checks it). `TLandrixEInvoiceValidator.KeepSvrl` and
  `NoScenarioReportFile`; the scenario has `ScenarioXml` and `ReportFile`; the result has
  `Timestamp`, `DocumentHash`, `DocumentReference`, `ScenarioXml`, `ReportFile` and `Steps`
  (`TLandrixEInvoiceValidationStepResult`); `TLandrixEInvoiceDocumentValidation` keeps the KoSIT
  result (`Kosit`) and the checked XML (`InvoiceXml`). Tests `Kosit.*` with an own report
  stylesheet in `tests/data/validator/`.
- `tools/kosit/kosit-oracle.py --report-input` compares the report input with the KoSIT
  validator's (`--serialize-report-input`), `--report` the report and its HTML page byte for byte
  (engine, time, reference, parser messages and location forms masked); suite, Peppol BIS,
  ZUGFeRD and the generated corpus agree. The KoSIT validator 1.6.3 hashes only the first bytes
  of some documents; the oracle checks the hash against the file.
- `tools/kosit/viz-oracle.py` compares `LandrixEInvoiceKositVisualization` (through
  `XsltProbe visualize`) with Saxon byte for byte: XR form and HTML page, German and English.
  The 99 test instances of the visualization and the KoSIT test suite agree, and so do the
  1,096 local UBL and CII examples; 17 of them are refused by both engines (an error raised by
  the stylesheet).
- `tools/make-release-zip.py <tag>`: the source ZIP of a release with the LandrixXML submodule
  (GitHub's source archives leave it out), one root folder. The entries do not depend on the
  machine or the local Git configuration (line endings only from `.gitattributes`, the tag's
  commit time, fixed modes); a content digest is printed besides the SHA-256 of the ZIP, whose
  compressed bytes depend on Python's zlib build. The ZIP of `v0.9.0-beta.1` builds and passes the
  tests on its own.
- `addons/kosit/install-kosit.ps1`: module `visualization` (KoSIT XRechnung visualization
  2026-01-31).
- Workbench: buttons for the KoSIT report and the KoSIT visualization.
- `tools/kosit/XsltProbe.dpr`: loads the KoSIT report stylesheets and the XRechnung visualization
  with the LandrixXML XSLT engine and runs a chain of stylesheets (load test on every toolchain);
  `visualize` runs `LandrixEInvoiceKositVisualization` (99 invoices, XR and HTML in German and
  English, equal to Saxon byte for byte).

### Changed
- LandrixXML 0.5.0 (`4264bf9`): XSLT 2.0 engine, SVRL into an open writer, raw Schematron message
  text. Rules compiled from `.sch` at run time (Peppol BIS, ZUGFeRD) drop static text that is
  only white space between `value-of` parts, as SchXslt does, so a few messages lose a space.
  `addons/kosit/install-kosit.ps1` downloads the rule files from that tag.
- The probes `FieldMapProbe`, `ValidatorProbe`, `MarkdownProbe`, `CIICodeProbe` and
  `RuleCheckProbe` carry the licence header like every other source.

## [0.9.0-beta.1] - 2026-11-13

First public pre-release. The API may still change until 1.0; units marked `API: internal`
(among them the validation and rendering units, documented as a preview) may change in any
release.

Supported invoice standards: XRechnung 3.0.2 (UBL and CII), ZUGFeRD 2.5.2 / Factur-X 1.09.2
(MINIMUM, BASIC WL, BASIC, EN 16931, EXTENDED), Peppol BIS Billing 3.0.21. Reading
also accepts the ZUGFeRD 2.x identifiers. Validation configurations: KoSIT XRechnung 3.0.2
(2026-08-31), KoSIT Peppol BIS 3.0.21, ZUGFeRD 2.5.2 (2026-10-15). Compilers: Delphi 6 to 13,
Free Pascal 3.2.2 and later. LandrixXML 0.4.0.

### Added
- Project foundation: dual licensing (GPL-3.0-or-later or Landrix Software Commercial
  License), third-party notices, contribution rules, security policy.
- LandrixXML for Pascal as Git submodule in `external/landrix-xml`, pinned to
  release 0.2.0 plus the fixes for the Delphi 13 macOS ARM64 and FPC aarch64-darwin
  diagnostics (`5f8c579`), then to `525642c` (XPath 2.0, XML Schema and Schematron engines, exact
  decimal and IEEE double arithmetic, Unicode normalization, third-party notices), then to `67c374b`
  (release 0.3.0: XML Schema validation as Xerces does it, faster XPath, DOM names copied without
  `Move`), then to `85f63f5` (faster XML Schema validation of large documents, indexed attribute
  comparisons in XPath steps, small integers to doubles without big-integer division), then to `a9a2a8e`
  (release 0.4.0).
- `tools/check-forbidden.py`: checks sources for language features and units that
  Delphi 6 does not support. `cwstring` is allowed in programs (`.dpr`/`.lpr`) only; old-style
  `object` types must not have a VMT.
- `LandrixEInvoice.inc` with the central compiler switches (`LANDRIXEINVOICE_UNICODE`).
- `LandrixEInvoiceTypes`: `TLandrixEInvoiceString` (UTF-16 on every compiler: `WideString`
  on Delphi 6-2007, `string` on Delphi 2009+, `UnicodeString` on Free Pascal; lossless
  regardless of the system code page), `TLandrixEInvoiceChar` (`WideChar`),
  `LandrixEInvoiceStringToUtf8`, `LandrixEInvoiceUtf8ToString`, `LandrixEInvoiceVersion`.
- Optional value types that distinguish "not set" from an explicit zero:
  `TLandrixEInvoiceAmount`, `TLandrixEInvoiceDate`, `TLandrixEInvoiceQuantity`,
  `TLandrixEInvoicePercent`, `TLandrixEInvoiceInteger`, `TLandrixEInvoiceBoolean`, with
  factories `LandrixEInvoiceAmount(...)` / `LandrixEInvoiceNoAmount` etc.
- `ELandrixEInvoiceError`, base class of the library's own exceptions.
- `TLandrixEInvoiceListIndex`: index type of the model's lists (`NativeInt` from Delphi 12 on,
  `Integer` before and on Free Pascal).
- `LandrixEInvoiceCodes`: code lists of the model with `...ToStr` / `...FromStr` functions,
  generated by `tools/codelists/gen-codelists.py` from the EN 16931 code list values of the
  European Commission (version 17, valid from 2026-05-15): invoice type, payment means, unit
  of measure (UN/ECE Rec. 20 and 21), attachment MIME type, allowance and charge reasons,
  VAT category and note subject as complete lists (existing members keep their names, new
  members are named after their code, e.g. `iuc_XBX`), the fixed attachment document type,
  and the new lists country, currency, electronic address scheme (EAS), identifier scheme
  (ICD), VAT exemption reason (VATEX), reference code qualifier (UNTDID 1153) and item
  classification scheme (UNTDID 7143). Ordinal values are not stable between versions.
- `LandrixEInvoiceInvoice`: the semantic invoice model `TLandrixInvoice` with lines, parties,
  payment, tax and attachment classes, taken over from `TInvoice` of XRechnung-for-Delphi
  with `TLandrix...` names and unchanged enumeration member names. Changes against
  XRechnung-for-Delphi: text fields are `TLandrixEInvoiceString`, date fields `TDateTime`;
  `TInvoiceEmptyLeitwegID.NON_EXISTENT` is the constant `LandrixEInvoiceLeitwegIDNonExistent`;
  the helper classes are the functions `LandrixEInvoiceUnitCodeFromUnitOfMeasure` and
  `LandrixEInvoiceAttachmentTypeFromFilename`; `EmbedDataFromText` writes UTF-8 without BOM
  (was UTF-16LE with BOM) and has an overload for `TLandrixEInvoiceString`;
  `EmbedDataFromFile` no longer retries on locked files; invalid Base64 raises
  `ELandrixXmlError`; `TryAddAttachmentByExtension` sets the attachment to nil on failure.
- `TLandrixInvoice.Clear` resets every field and list and clears the parties and the delivery
  information; new `Clear`
  methods on `TLandrixInvoiceLine`, `TLandrixInvoiceAccountingParty`,
  `TLandrixInvoiceAddress` and `TLandrixInvoiceDeliveryInformation`.
- Targets and specification directory: `TLandrixEInvoiceTarget` (standard, syntax, profile,
  version) with the factories `TLandrixEInvoiceTargets.XRechnung/FacturX/ZUGFeRD/PeppolBIS`
  (ZUGFeRD 2.5 = Factur-X 1.09), and `LandrixEInvoiceSpecs` with entries for XRechnung 3.0
  UBL and CII, Factur-X 1.09 EN16931 and EXTENDED and Peppol BIS Billing 3.0 (identifiers,
  default business process, syntax and norm version, PDF attachment name, KoSIT code list
  versions of XRechnung 3.0.2), found by target (`LandrixEInvoiceFindSpec`, versions matched by
  major.minor) or by the identifiers of a read document (`LandrixEInvoiceDetectSpec`, also
  reports the XRechnung extension).
- `LandrixEInvoiceCompatXRechnung`: the model names of XRechnung-for-Delphi (`TInvoice`,
  `TInvoiceLine`, ..., enumeration members, `TInvoiceListItemType`,
  `TInvoiceEmptyLeitwegID.NON_EXISTENT`, `TInvoiceUnitCodeHelper`,
  `TInvoiceAttachmentTypeHelper`, and `TInvoiceEmptyLeitwegID_NON_EXISTENT` of the Delphi 6
  version) for existing code that replaces `intf.Invoice` (`intfInvoice` in the Delphi 6
  version) in its uses clauses. `TInvoiceEmptyLeitwegID.NON_EXISTENT` is a class function now,
  so it can no longer be used in constant expressions; `ClassName` returns the new names
  (`TLandrixInvoice`). Reading and writing (`TXRechnungInvoiceAdapter`) will follow.
- CII syntax model generated from the Factur-X 1.09.2 EXTENDED schema: `LandrixEInvoiceCII`
  (one class per schema type, `TLandrixCIIInvoice` as root; values as text, values with
  attributes as records such as `TLandrixCIIAmount`; optional children created on access,
  present means not `IsEmpty`), `LandrixEInvoiceCIIReader` (`LandrixEInvoiceReadCII` on the
  LandrixXml pull reader: unknown and repeated elements, unknown attributes, stray text and
  invalid values are reported and skipped) and `LandrixEInvoiceCIIWriter`
  (`LandrixEInvoiceWriteCII` on the LandrixXml streaming writer: schema order, only set values;
  required element-content children are written even when empty; missing required values are
  reported). Generated by
  `tools/syntaxmodel/gen-syntaxmodel.py` from `tools/syntaxmodel/cii.json`, which
  `tools/syntaxmodel/extract-xsd.py` extracts from the downloaded and checksum-verified schema.
- UBL syntax model generated from the UBL 2.1 schema, reduced to the positive list
  `tools/syntaxmodel/ubl-positive.json` (47 aggregate types: the EN 16931 UBL binding, the
  XRechnung extension and everything the examples and code of XRechnung-for-Delphi and
  ZUGFeRD-for-Delphi use): `LandrixEInvoiceUBL` with the roots `TLandrixUBLInvoice` and
  `TLandrixUBLCreditNote`, `LandrixEInvoiceUBLReader` (`LandrixEInvoiceReadUBLInvoice`,
  `LandrixEInvoiceReadUBLCreditNote`) and `LandrixEInvoiceUBLWriter`
  (`LandrixEInvoiceWriteUBLInvoice`, `LandrixEInvoiceWriteUBLCreditNote`; root element in its
  default namespace). Same design as CII. Identifiers, codes, amounts, quantities, measures and
  binary objects keep all attributes of the schema; other values are plain text.
  `ext:UBLExtensions` (e.g. signatures) is skipped as a whole and never written.
  `extract-xsd.py --report` compares the positive list with the EN 16931 UBL rules.
- `LandrixEInvoiceDiagnostics`: `TLandrixEInvoiceDiagnostics`, the list of reader and writer
  diagnostics with kind, element path, line, column and offset; `edk_SkippedExtension` for
  skipped extension blocks.
- Mapping between the invoice model and the CII syntax model (`LandrixEInvoiceMapCII`:
  `LandrixEInvoiceInvoiceToCII`, `LandrixEInvoiceCIIToInvoice`), one method per business group.
  Writing follows the rule table of the target specification (`LandrixEInvoiceRules`: content a
  specification forbids, e.g. delivery data per line outside Factur-X EXTENDED, is left out and
  reported);
  reading reports every element and attribute the invoice model cannot hold (`edk_NotMapped`),
  values that cannot be converted (`edk_ConversionFailed`) and unknown codes, which are kept in
  the new `...Other` fields of the model (`edk_UnknownCode`). Totals are taken from the model as
  they are. Line breaks in free text are written as LF. The output equals the 67 CII golden files
  of XRechnung-for-Delphi (XRechnung 3.0 CII, Factur-X 1.09 EN16931 and EXTENDED).
- Mapping between the invoice model and the UBL syntax model (`LandrixEInvoiceMapUBL`:
  `LandrixEInvoiceInvoiceToUBLInvoice`, `LandrixEInvoiceInvoiceToUBLCreditNote`,
  `LandrixEInvoiceUBLInvoiceToInvoice`, `LandrixEInvoiceUBLCreditNoteToInvoice`, root choice
  `LandrixEInvoiceUBLRootFor` with `TLandrixEInvoiceUBLRoot`: a credit note (381) becomes
  `ubl:CreditNote`). Same reporting as for CII. The XRechnung extension identifier is written
  only when the invoice has extension content (sub lines, embedded XML attachments, third-party
  payments, the XR01 to XR03 schemes), never on a credit note. The output equals the 44 UBL
  golden files of XRechnung-for-Delphi (XRechnung 3.0 UBL, Peppol BIS Billing 3.0); the 21
  XRechnung scenarios convert between UBL and CII through the invoice model.
- `LandrixEInvoiceCompatXRechnungAdapter`: the facade of XRechnung-for-Delphi
  (`TXRechnungInvoiceAdapter`, `TXRechnungVersion`, `TXRechnungValidationHelper.GetXRechnungVersion`,
  `ConsistencyCheck` codes), replaces `intf.XRechnung` next to `LandrixEInvoiceCompatXRechnung`
  (replaces `intf.Invoice`). The original test cases and example generator of XRechnung-for-Delphi
  compile against both units and produce output equal to the 111 golden files. Differences: the
  `cc...` codes are unit constants (as in the Delphi 6 version), Save and Load take an optional
  last parameter `_Diagnostics`, Load returns False only for documents that cannot be read, on
  Delphi 6 to 2007 `SaveToXMLStr` returns UTF-8 bytes, no `IXMLDocument` overloads and no Java
  validation; messages are English. The PDF entries of the old facade are back:
  `LoadFromPdfStream`, `LoadFromPdfFile` and `_ProcessPdfFiles` on `LoadFromStream`,
  `LoadFromFile` and `GetXRechnungVersion`; in `LoadFromStream` and `LoadFromFile`
  `_Diagnostics` follows `_ProcessPdfFiles`, so calls passing diagnostics as fourth argument
  need `False` in between.
- `LandrixEInvoicePdf`: extraction of the embedded invoice and of all embedded files from a
  ZUGFeRD, Factur-X or XRechnung PDF in plain Pascal (`TLandrixEInvoicePdfExtractor`,
  `TLandrixEInvoicePdfAttachment`, `TLandrixEInvoicePdfAttachmentList`,
  `TLandrixEInvoicePdfExtractInfo`), ported from XRechnung-for-Delphi and now available on
  Delphi 6 to 2007 as well. It follows the xref chain (incremental updates, hybrid files, object
  streams), rebuilds a broken object table by a scan, decodes FlateDecode with an own inflate
  (no compiler zlib), LZWDecode, ASCIIHexDecode, ASCII85Decode and RunLengthDecode with
  predictors, and reads RC4-encrypted files with an empty user password. Damaged or hostile
  input gives False with an English `Info.Error`; embedded files left out because a filter
  failed or a size limit was reached are counted in `Info.SkippedAttachments` with
  `Info.Warning` (the old unit left them out silently). Attachment data and the extracted
  invoice are streams instead of `TBytes`; file names in UTF-8 text strings (PDF 2.0) and the
  PDFDocEncoding characters outside Latin-1 are decoded.
- `LandrixEInvoiceCompatXRechnungPdf`: the old names of `intf.XRechnungPdfExtract`
  (`TXRechnungPdfExtractor` with `TBytes` results, `TXRechnungPdfAttachmentList`,
  `pakInvoice` ...); `TXRechnungPdfAttachment.Data` is a `TMemoryStream`.
- `LandrixEInvoiceLexical`: locale-independent conversion between typed values and the lexical
  text of the syntax models with fixed rules per business term (amounts 2 decimals, prices 2 or 4,
  quantities 4, base quantities up to 6, percentages 2; UBL and CII dates).
- `LandrixEInvoiceCalc`: shared business layer (line status of sub lines, sub line tree from
  CII parent line references, the XRechnung text form of payment terms).
- `LandrixEInvoiceRules`: rule table of the target specifications (CII and UBL).
- Diagnostics: kinds `edk_ConversionFailed`, `edk_UnknownCode`, `edk_NotMapped`, `edk_NotAllowed`,
  a severity per entry (`eds_Info`, `eds_Warning`, `eds_Error`) and `HasErrors`.
- Invoice model: a `...Other` text field next to each enumeration field with an external code
  (e.g. `UnitCodeOther`); a set enumeration wins when writing.
- Generated syntax models: `ListFilledChildren` on every class.
- `TLandrixEInvoiceStringList`: list of `TLandrixEInvoiceString` (UTF-16 on every compiler), used
  for repeated plain text such as `cbc:Note`.
- Framework-free console test runner `tests/LandrixEInvoiceTests.dpr`.
- `tools/build.ps1`: builds and runs the tests with the local toolchains. After the runs, each
  local toolchain reads the scenario outputs the next one wrote (cross test: Delphi reads what
  Free Pascal wrote and the other way round, Ansi and Unicode string models included), and the
  outputs of all these toolchains must be byte-identical. `-Validate` adds the KoSIT validation
  of the scenario output.
- `addons/java-tools/install-tools.ps1` (PowerShell 7, Windows, Linux, macOS): downloads the KoSIT
  validator 1.6.3, the configurations for XRechnung 3.0.2, Peppol BIS Billing 3.0.21 and
  ZUGFeRD 2.5.2, and the Temurin 21 JRE of the current platform; every download pinned by URL and
  SHA-256 in `tools.json`.
- `tools/validate.ps1`: validates invoice files with these tools, the configuration chosen by file
  name; all 111 scenario outputs are accepted.
- `tools/fieldmap/fieldmap.py` with the probe `FieldMapProbe.dpr`: measures which paths of the
  Factur-X field table (per profile, checksum in `manifest.json`; the table is not part of the
  repository) reach `TLandrixInvoice`, using a synthetic EXTENDED document with every path and
  the local CII corpus for frequencies. `--export` writes `tools/syntaxmodel/cii-profiles.json`.
- `tools/build.ps1 -Validate` also validates the reduced Factur-X profiles
  (`build/<toolchain>/profiles/`, test `CIIProfiles.WriteScenarios`).
- Invoice model, from a field comparison against the Factur-X 1.09.2 table: payee (BG-10),
  seller tax representative (BG-11) and invoicee (BG-X-36, EXTENDED) as the new class
  `TLandrixInvoiceParty` (`PayeeParty`, `TaxRepresentativeParty`, `InvoiceeParty`); VAT point
  date and code (`TaxPointDate`, `TaxPointDateCode`, BT-7/BT-8; CII writes the UNTDID 2475 codes),
  VAT total in the accounting currency (`TaxAmountTotalInTaxCurrency`, BT-111), scheme of the
  legal registration (`CompanyIDSchemeID`, BT-30-1/BT-47-1), contact department
  (`ContactDepartment`, BT-41-0/BT-56-0, CII only and only without a person name), item standard
  identifier with any scheme (`StandardItemIdentifier`/`...SchemeID`, BT-157; takes precedence
  over `GlobalID_EAN_GTIN`), scheme of the invoiced object identifier (`SchemeID`, BT-18-1, named as in
  XRechnung-for-Delphi);
  EXTENDED only: test indicator, document name, order dates of the document and the line,
  deliver to contact, a text per cash discount level. New date, amount and boolean fields use
  the optional value types. Targets that do not know a field leave it out and report it.
- BT-71 without scheme is written as plain identifier (CII `ram:ID`, UBL `cbc:ID` without
  `schemeID`) and read from `ram:ID`; with a scheme it stays a global identifier.
- Factur-X payment terms are read in any order (a net term after the discount terms no longer
  drops them), each discount term with its text.
- The VAT point date code (BT-8) is left out with a warning when the VAT point date (BT-7) is
  set, since both are mutually exclusive (BR-CO-3).
- Factur-X 1.09 / ZUGFeRD 2.5 MINIMUM, BASIC WL and BASIC: specification entries (read and
  write). The generated unit `LandrixEInvoiceCIIProfiles` (from
  `tools/syntaxmodel/cii-profiles.json`, derived from the Factur-X field table) knows the lowest
  profile of every CII path: `LandrixEInvoiceCIIMinProfile`, `LandrixEInvoiceCIIAllowed`,
  `LandrixEInvoiceCIIRequired` (required over the whole ancestor chain) and
  `LandrixEInvoicePruneCII`, which removes from a CII model what a profile does not contain and
  reports each path once with its count. The CII mapping prunes for every Factur-X profile below
  EXTENDED; totals are not recalculated. `LandrixEInvoiceWriteCII` takes the profile as optional last
  parameter (default `epr_Extended`) and reports missing required content only where the profile
  contains it. The KoSIT validator accepts all 66 scenario outputs in
  the three profiles.
- Semantic sweep over the official test material (test `Sweep.Official`): the KoSIT XRechnung
  3.0.2 testsuite, the ZUGFeRD 2.5.2 examples of every profile and the Peppol BIS examples, copied
  by `tools/testdata/sync-local.py` into the git-ignored `tests/data/local/sweep/` (file names
  and SHA-256 in `tools/testdata/corpora.json`). Every file is read, written in its detected
  specification, read again and compared field by field; findings fail unless
  `tests/data/sweep-exceptions.txt` lists them with a reason.
- `tools/model/gen-invoice-compare.py` generates the test unit `LandrixEInvoiceTestInvoiceCompare`
  from the model declarations: comparison of all 206 fields of `TLandrixInvoice`, a canonical
  dump, a fill procedure and one mutation per leaf; tests show that every leaf is detected and
  that `Clear` resets every field.
- `tools/testdata/xr-compare.py`: independent oracle for the sweep. It turns sources and outputs
  into the syntax-neutral XR form of the KoSIT XRechnung visualization (now pinned in
  `addons/java-tools/tools.json`) and compares them business term by business term, also for
  XRechnung written in the other syntax (`build/<toolchain>/sweep-cross/`); known differences in
  `tests/data/xr-exceptions.txt`. `tools/build.ps1 -Validate` runs it.
- Business test cases per business group (`tests/LandrixEInvoiceTestBusinessCases.pas`, 24
  cases), written from EN 16931 and its bindings: VAT categories Z, E, G, AE, K, O and mixed rates
  with a line allowance, document allowance and charge, prepaid and rounding amount, tax currency,
  payment means 10/30/42/57/97/ZZZ, SEPA direct debit, payment card, cash discount, contact
  department, payee and tax representative, delivery, credit note with preceding invoice, notes,
  referenced and embedded attachment, line details, gross price, negative line. Each runs through
  XRechnung UBL and CII, Peppol and Factur-X EN16931 and EXTENDED with hand-written expectations on
  the XML (element paths from the bindings) and a field-by-field read-back; `tools/build.ps1
  -Validate` lets the KoSIT validator check all 145 outputs.
- UBL: the scheme of the delivery location (BT-71-1) is read only with an identifier; a delivery
  without location no longer clears the default scheme.
- Card payments: codes 48 and 55 are written as payment card (BG-18) like 54 (BR-DE-24).
- CII: BT-84 without IBAN is read from and written to `ram:ProprietaryID`; BT-86 is written next
  to a direct debit; BT-149 is read from the gross price when the net price has none.
- UBL: any tax scheme other than VAT is the tax registration (BT-32), as in the KoSIT examples.
- The base amount of a line allowance or charge (BT-137/BT-142) is written also without a
  percentage.
- MINIMUM: totals the profile does not contain are not written when they are 0.
- CII: XRechnung declares the extension (BT-24) when the invoice has content the extension allows
  in CII (embedded XML attachment, schemes XR01 to XR03), as UBL does; a credit note may use it.
- Factur-X EXTENDED: third-party payments (BG-DEX-09) are written and read as financial
  adjustments (`ram:SpecifiedFinancialAdjustment`, BR-FXEXT-CO-16).
- `tools/build.ps1 -Validate` lets the KoSIT validator check the sweep outputs as well.
- `LandrixEInvoicePdfXmpDescription` (XMP `rdf:Description` for a Factur-X / ZUGFeRD PDF/A-3 per
  target, all Factur-X profiles and XRechnung CII) and `LandrixEInvoicePdfXmpSchema` (XMP extension
  schema); the compatibility adapter has `ZUGFERD_INVOICE_PDF_FILENAME_FACTURX`,
  `ZUGFERD_INVOICE_PDF_FILENAME_XRECHNUNG`, `ZUGFERD_INVOICE_PDF_XMP_INFO`,
  `ZUGFERD_INVOICE_PDF_SCHEMA`, `TXRechnungInvoiceAdapter.ZUGFeRDPdfXmpInfo` and `ZUGFeRDPdfFilename`
  as in XRechnung-for-Delphi.

- `LandrixEInvoiceIsBlank` (empty or XML white space only).
- `LandrixEInvoiceCheck`: business rule checks of an invoice against a target.
  `LandrixEInvoiceCheckInvoice` runs every rule that applies, `LandrixEInvoiceCheckRule` one rule
  by its identifier; a violation is reported as the new diagnostic kind `edk_RuleViolation` with the
  rule in the new field `TLandrixEInvoiceDiagnostic.RuleID` (official identifiers such as BR-DE-15,
  `LX-...` for rules of this library; identifiers are stable). The checks of
  `TXRechnungInvoiceAdapter.ConsistencyCheck` are the rules `LX-CC-01` to `LX-CC-12` (number = old
  code); they serve the compatibility layer only. Further rules follow during phase 2.
- Official rules in `LandrixEInvoiceCheck` (required business terms per target): EN 16931 BR-02 to
  BR-65 where the invoice model can violate them (the mappers always meet BR-01, the totals and the
  other amounts), per Factur-X profile as its Schematron has them; XRechnung BR-DE-1 to BR-DE-31
  (the required terms and payment groups; BR-DE-26 as a warning); PEPPOL-EN16931-R003 (Peppol),
  R010, R020 and R061 (Peppol and XRechnung). The rules judge the invoice as the mappers would write
  it; where UBL and CII differ, each follows the validator of its syntax (e.g. BR-61 in UBL only,
  BR-DE-23-b, BR-DE-24-b, BR-DE-25-b in CII only, BR-DE-30/31 by syntax). Code list and format
  rules follow.
- Calculation rules in `LandrixEInvoiceCheck`: BR-CO-10 to BR-CO-17 on the amounts as written (two
  decimals; BR-CO-17 with the tolerance of its Schematron, strict in UBL, inclusive in CII),
  Factur-X EXTENDED BR-CO-14 and BR-FXEXT-CO-10 to 13, 15 and 16 (0.01 per amount, DETAIL lines only), and
  BR-DEX-09 for XRechnung UBL invoices with third-party payments (BR-CO-16 gives way there, as
  in the KoSIT extension scenario).
- VAT category rules in `LandrixEInvoiceCheck`: BR-S, BR-Z, BR-E, BR-AE, BR-IC, BR-G, BR-O, BR-AF
  and BR-AG (01 to 10, BR-IC-11/12, BR-O-11 to 14), BR-B-01, BR-B-02, BR-CO-03, BR-CO-04, BR-CO-09
  and BR-CO-18, each with the context and tolerance of the Schematron of its syntax (e.g.
  BR-S-08 within 1 per rate in UBL, exact in CII; BR-CO-09 with SS in UBL and AN in CII) and per
  Factur-X profile as its Schematron has them. The rule oracle knows them; categories, rates and
  amounts are judged as written.
- The remaining BR-CO rules in `LandrixEInvoiceCheck`: BR-CO-21 to BR-CO-24 (reasons of
  allowances and charges), BR-CO-26 (seller identifier; UBL does not count scheme SEPA) and, for
  Factur-X EXTENDED, BR-CO-25 (due date or payment terms), BR-FXEXT-CO-04 and BR-FXEXT-S-01 to
  BR-FXEXT-AG-01. BR-CO-05 to BR-CO-08 always hold in the Schematron, BR-CO-19 and BR-CO-20 in
  the written document.
- Format rules in `LandrixEInvoiceCheck`, as warnings: BR-DE-17 (supported invoice type codes),
  BR-DE-19 and BR-DE-20 (IBAN of a SEPA credit transfer or direct debit, with the check sum of
  KoSIT's `xr:checkIBAN`), BR-DE-27 (at least three digits in the seller telephone) and BR-DE-28
  (seller email pattern); BR-51 (card number at most 10 characters) as a warning in UBL and an
  error in CII. `LandrixEInvoiceCheckRule` runs every row of an identifier.
- Code list rules in `LandrixEInvoiceCheck` for XRechnung and Peppol: BR-CL-01 to BR-CL-26
  against the lists of the validators (XRechnung 3.0.2, Peppol BIS 3.0.21), which differ slightly
  from the library's code lists (STD, AN in CII, B, EAS 0219/0220, fewer note subjects in UBL),
  on the codes as the mappers write them; BR-CL-21 and BR-CL-23 are warnings in XRechnung, and
  the XRechnung extension leaves out BR-CL-10, 11, 21, 24, 25 and 26 as its scenario does.
- The rules that only the Peppol BIS 3.0.21 schematron contains, in the internal unit
  `LandrixEInvoiceCheckPeppol` (run by `LandrixEInvoiceCheckInvoice` and `LandrixEInvoiceCheckRule`
  for Peppol): the other PEPPOL-EN16931 rules (R002, R007, P0100, P0104 to P0112, CL001 to CL008),
  PEPPOL-COMMON-R040 to R057 and the national rules of Germany, Denmark, Greece, Iceland, Italy,
  the Netherlands, Norway and Sweden. The internal unit `LandrixEInvoiceIdentifiers` holds the
  identifier formats and check digits (GLN, modulus 11, Belgian, Italian, Swedish, Australian and
  Greek numbers, the KoSIT IBAN check) and the telephone and email patterns of BR-DE-27/28.
  `tools/rulecheck/peppol-oracle.py` compares the rules with the OpenPEPPOL unit tests of the
  release; `RuleCheckProbe` takes `-peppol`.
- BR-DE-18 in `LandrixEInvoiceCheck` (XRechnung): a cash discount line with negative days or
  percent breaks the `#SKONTO#` pattern; the line check is shared with DE-R-018 of Peppol.
- UBL-SR-29 in `LandrixEInvoiceCheck` (XRechnung and Peppol, UBL): at most one party identifier
  with scheme SEPA, counted as the UBL writer fills them (BT-29/BT-46 global identifiers, BT-90,
  BT-60 with its scheme).
- Unit of measure text `Satz` maps to `SET`, as in XRechnung-for-Delphi `a4a1b17`.
- Internal unit `LandrixEInvoiceValidator`: validates an XML document as the KoSIT validator does with a
  validator configuration (`scenarios.xml`): the one scenario whose match expression holds (none for zero
  or several, as KoSIT), XML schema, the Schematron
  steps on a schema-valid document, levels with `customLevel`, accept or reject as the configuration's
  report stylesheet; engines of LandrixXML, Schematron rule files mapped by the XSLT file name.
  `ValidateStream` validates a document from a stream (read once into memory), with the same results
  as `Validate` on a file (test `Validator.Stream`, and over the KoSIT test suite).
  `tools/kosit/kosit-oracle.py` compares it with the KoSIT validator on the XRechnung test suite
  2026-08-31 and seven mutants (`tools/kosit/ValidatorProbe.dpr`); `tools/testdata/sync-local.py` copies the
  test suite and the rule files of the LandrixXML submodule to `tests/data/local/kosit/`. With
  `--corpus generated` it runs the 1,219 generated Schematron test documents of XRechnung 3.0.0 too,
  with `--corpus outputs` the XRechnung files a test run wrote. The test `Validator.Outputs`, last in the
  run, validates every XRechnung output of the run (cross, cases, sweep) natively; each must be accepted.
  Peppol BIS (`--corpus peppol`, configuration 3.0.21): the EN16931 rules are those of `en16931-ubl.xml`
  (same source), the Peppol rules are compiled from `PEPPOL-EN16931-UBL.sch` when loaded (`sync-local.py`
  copies it to `tests/data/local/kosit/peppol/`). A scenario without `acceptMatch` (Peppol) accepts as
  KoSIT does then: schema-valid and no failed assert of any level. Compared with KoSIT on the Peppol
  examples, five mutants, the OpenPEPPOL unit test documents (also with an inserted `CustomizationID`)
  and the Peppol outputs of a test run (1,294 documents, no difference). Tests
  `Validator.WithoutAcceptMatch` and `Validator.PeppolOutputs` (every `*-peppol.xml` output of the run).
  `tools/validate.ps1` still judges Peppol files by the report's assessment (error-level messages only).
  ZUGFeRD 2.5.2 / Factur-X 1.09.2 (`--corpus zugferd`): the configuration ships the Schematron source of each
  profile next to its XSLT; the validator compiles it. Compared with KoSIT on the ZUGFeRD examples, the CII
  examples of `tests/data/local/cii` and `cii-invalid`, five mutants and the ZUGFeRD outputs of a test run
  (677 documents, no difference; the configuration's readable locations are compared in the SchXslt form).
  Test `Validator.ZugferdOutputs` (every `*-cii*-25.xml` output of the run, about one minute per toolchain).
- Internal unit `LandrixEInvoiceValidation` (phase 6, validator entry): `TLandrixEInvoiceDocumentValidator`
  validates an XML document from a file or stream with a KoSIT configuration the caller loads
  (`Options.Configuration`), reads it through the facade and runs the own rule check
  (`LandrixEInvoiceCheckInvoice`, `Options.ModelCheck`). The result (`TLandrixEInvoiceDocumentValidation`)
  holds the verdict (`ev_Accepted`, `ev_Rejected`, `ev_Incomplete`), a status per part (reading, KoSIT, rule
  check) and one flat list of findings; only the KoSIT run decides the verdict, the findings of the own rule
  check are marked as predictions. Tests `Validation.Xml` and `Validation.KositSuite` (same verdict and KoSIT
  findings as the engine over the KoSIT test suite).
- `LandrixEInvoiceValidation` without a KoSIT configuration (`Options.Configuration` nil, now the default):
  no KoSIT run, the verdict is `ev_Incomplete`; reading reports a document that is not well-formed, the own rule
  check runs as before.
- `LandrixEInvoiceValidation` validates hybrid PDFs (ZUGFeRD, Factur-X; told by the content): levels 2 and 3 of
  `LandrixEInvoicePdfCheck` (embedding, XMP), then KoSIT, reading and the own rule check on the embedded invoice;
  reading feeds the second pass of the PDF checker (profile and country rules). New parts `evp_PdfEmbedding`,
  `evp_PdfMetadata` and `evp_PdfA` (PDF/A is not checked, always not run); `Pdf` gives the PDF checker's result.
  For a PDF levels 2 and 3 decide with KoSIT: rejected if one of them fails, incomplete if one did not run or is
  incomplete. Tests `Validation.Pdf`, `Validation.PdfKosit` and `Validation.PdfCorpus` (528 local PDFs).
  `TLandrixEInvoicePdfChecker.CheckStream` and the PDF object layer pass `EOutOfMemory` on instead of reporting
  LX-PDF-01.
- Validation report as XML: internal unit `LandrixEInvoiceValidationReport` with
  `TLandrixEInvoiceValidationReportWriter` (`DocumentName`, `WriteToStream`, `SaveToFile`); own format 1.0,
  namespace `urn:landrix:einvoice:validation-report:1`, schema `schemas/landrix-einvoice-validation-report-1.xsd`
  (closed enumerations, wildcards for additions of a minor version). The report holds the document, the
  specification the library assigns, the verdict, every part with its status, the PDF facts and the flat list of
  findings (counts without the predictions); no timestamp, so the same result gives the same bytes. Characters
  XML does not allow are replaced by U+FFFD and marked `sanitized`. New: `ConfigurationName` of the result and
  `Step` of a finding (KoSIT well-formedness, XML schema or Schematron). Every report written by the tests is
  checked against the schema and read back; tests `Validation.Report` (golden reports in
  `tests/data/validation-report/`), `Validation.ReportSanitize` and `Validation.ReportSchema`.
- Validation report as HTML: internal unit `LandrixEInvoiceValidationHtml` with
  `TLandrixEInvoiceValidationHtmlWriter` (`DocumentName`, `Language`, `WriteToStream`, `SaveToFile`) writes one
  self-contained page (CSS inline, no script, nothing loaded from elsewhere; also well-formed XML) with the verdict,
  the document, the parts, the PDF facts and the findings. Labels in English or German
  (`TLandrixEInvoiceReportLanguage`: `eln_English`, `eln_German`). The sanitizing of the XML report is shared as
  `LandrixEInvoiceReportSanitize`. Every page of the validation tests is read back in both languages; test
  `Validation.Html` and golden pages in `tests/data/validation-report/`.
- Internal unit `LandrixEInvoiceReportHtml` with what the report writers share: `TLandrixEInvoiceReportLanguage`
  (moved from `LandrixEInvoiceValidationHtml`), `LandrixEInvoiceReportSanitize` (moved from
  `LandrixEInvoiceValidationReport`) and `TLandrixEInvoiceHtmlBuilder` (UTF-8 page with sanitized, escaped text). The
  output of both validation reports is unchanged.
- Names of codes for showing an invoice: internal unit `LandrixEInvoiceCodeNames`, generated by
  `tools/codelists/gen-codelists.py`, with `TLandrixEInvoiceCodeList` (one `ecl_` member per code list with names)
  and `LandrixEInvoiceCodeName(AList, ACode, ALanguage)`. English names from the EN 16931 code lists (14 lists,
  4,780 codes); German names hand-written for VAT categories, invoice types, payment means, allowance reasons and the
  common units (`tools/codelists/names-de.json`), country and currency names from Unicode CLDR 47.0.0 (Unicode
  License V3); English otherwise. Test `Codes.Names`.
- Labels of the model fields for rendering invoices: internal unit `LandrixEInvoiceRenderLabels`, generated by
  `tools/render/gen-render-labels.py` from `tools/render/labels.json` and the interface of `LandrixEInvoiceInvoice`,
  with `TLandrixEInvoiceRenderField` (one `erf_` member per model path, 293) and `LandrixEInvoiceRenderFieldLabel`
  (English and German, own wording), `LandrixEInvoiceRenderFieldBT` (the business term on that path) and
  `LandrixEInvoiceRenderFieldPath`. The generator fails on a field without labels, a path whose term is ambiguous,
  a malformed term or a stale entry; `--check` fails when the unit is out of date. Test `Render.Labels`.
- An invoice as an HTML page for people: internal unit `LandrixEInvoiceRenderHtml` with
  `TLandrixEInvoiceRenderHtmlWriter` (`DocumentName`, `Language`, `ShowBusinessTerms`; `WriteToStream` and
  `SaveToFile` for a `TLandrixInvoice` or a read `TLandrixEInvoiceDocument`). One self-contained page (CSS inline, no
  script, nothing loaded, no links; also well-formed XML) in sections: invoice details, parties, references, lines
  (sub lines nested in their line), allowances and charges, VAT breakdown, totals, payment, notes, supporting
  documents; for a read document also its origin and what reading did not take over (unknown or repeated content,
  skipped extensions, values that could not be converted, content without a place in the model). Every set field
  appears once, labelled, in an element marked with its model path (`data-field`) and business term (`data-bt`);
  empty sections and groups are left out; nothing is computed. Values are formatted in the internal unit
  `LandrixEInvoiceRender`: amounts with at least two and at most the four stored decimals, other numbers as stored,
  dates `DD.MM.YYYY` (German) or `YYYY-MM-DD` (English), codes with their names, currency by its code. The sections
  come from `"sections"` in `tools/render/labels.json` (`TLandrixEInvoiceRenderSection`,
  `LandrixEInvoiceRenderFieldSection`). Tests `Render.Format`, `Render.Html`, `Render.Mutations` (one mutation per
  field of the model: the page must change in the elements marked with that field, in its section; exceptions in
  `tools/render/render-exceptions.txt`), `Render.Golden` (pages in `tests/data/render/`) and `Render.Corpus` (every
  local golden, CII, UBL and sweep file in both languages, read back as XML).
- The invoice page titles a credit note (BT-3 = 381) "Credit note" / "Gutschrift"; the VAT columns of allowances
  and charges on line level appear only when an item has a category or a rate. German names for 42 common charge
  reasons (UNTDID 7161, e.g. FC "Fracht") in `tools/codelists/names-de.json`; the others stay English.
- The UBL reader takes a SEPA creditor identifier only from the payee as BT-90 (the EN 16931 UBL binding allows it
  there); one in the tax representative is reported instead of moving to the seller.
- Rule check: BR-54 also checks UBL sub lines (its context `//cac:AdditionalItemProperty` reaches
  `cac:SubInvoiceLine`, the other line rules do not); BR-17 in UBL compares the payee only with the seller
  identifiers that are written, not with one the target leaves out beside a global identifier.
- `TLandrixInvoiceAllowanceCharge.TaxExemptionReason` and `TaxExemptionReasonCode` (BT-173, BT-174: VAT exemption
  reason and code of a document level allowance or charge, Factur-X EXTENDED only): the CII reader takes them over
  instead of reporting them as not mapped, the CII writer writes them in EXTENDED; other targets report them
  (writer rule `LandrixEInvoiceRuleAllowanceChargeTaxExemptionReason`). The invoice page shows them in two columns
  of the allowance table when an item has them.
- `Render.Mutations`, `Model.CompareComplete` and `Model.Assign` also run with two items in every list
  (`FillInvoiceAll`, `InvoiceLeafCount` and `MutateInvoiceLeaf` of the generated test unit take the number of items,
  1 or 2): a mutation of the second item must change exactly that item on the page (list items are told apart by
  their position), so a mix-up between the items of one list shows.
- English code names corrected where the EN 16931 code lists cut them off or keep their list form, in the new
  hand-written `tools/codelists/names-en.json` (90 entries; the generator fails on an entry equal to the source): 47
  names completed from UNTDID (payment means, e.g. 63 "...endorsed by a third party", note subjects, reference
  qualifiers, item classifications), countries without the article of the ISO list form ("Netherlands" instead of
  "Netherlands (the)"), invoice types 471-503 without ", invoice type, Corrected", and the units minute and second
  without "[unit of time]". Payment means 32/33 and 41/43 had the same English and German names; they now say credit
  and debit (Gutschrift, Lastschrift).
- `LandrixEInvoiceValidation` chooses the KoSIT configuration per document among registered ones
  (`Options.AddConfiguration(Configuration, Kind)`, `ClearConfigurations`, `ConfigurationCount`; kinds
  `TLandrixEInvoiceConfigurationKind`): a configuration is a candidate when exactly one of its scenarios matches
  (`TLandrixEInvoiceValidator.CountMatches`, match expressions only); with several candidates the kind decides
  (ZUGFeRD, Peppol BIS, XRechnung, other; then the order of registration), so a Factur-X EN16931 (Comfort) CII
  document runs the ZUGFeRD configuration instead of the generic EN16931 scenario of the XRechnung one. Inside a
  configuration KoSIT's rule stays (several matching scenarios: none). No candidate is rejected as KoSIT does
  without a scenario; a warning tells when the chosen kind does not fit the specification read (BT-24).
  `Options.Configuration` still wins. The result names the choice (`ConfigurationChoice`, `ConfigurationKind`,
  `CandidateCount`), the XML report in optional attributes of the KoSIT part (`configurationChoice`,
  `configurationKind`, `candidates`), the HTML page in its details. `tools/kosit/kosit-oracle.py --corpus auto`
  compares the candidates with the KoSIT validator over the local corpora (probe option `-matches`).
- Peppol rules in `LandrixEInvoiceCheck` for XRechnung and Peppol (the rules the XRechnung
  schematron contains as well): PEPPOL-EN16931-R005, R040 to R042 (allowance and charge
  percentage, base amount and amount), R046 (net price), R053 to R055 (VAT totals), R110, R111
  (line period), R120 (line net amount; a warning in XRechnung, an error in Peppol), R121 and
  R130 (base quantity). Amounts, prices and quantities are compared exactly as written, with the
  tolerance of the schematron and the price division as the validator's Saxon computes it.
- Factur-X code checks: the generated unit `LandrixEInvoiceCIICodeRules` checks a CII syntax
  model against the 366 code asserts of the Factur-X 1.09.2 schematron (FX-SCH-A-..., one
  identifier per profile, with the contexts allowance or charge, document type code, @listID and
  VAT total currency) and reports them as `edk_RuleViolation`; `LandrixEInvoiceCheckCII` and the
  facade (`Check`, `SaveTo*`, also for a CII model passed directly; not with `eio_NoRuleCheck`)
  run it. `tools/syntaxmodel/extract-xsd.py` extracts the asserts and code lists to
  `tools/syntaxmodel/cii-codes.json`; `tools/rulecheck/fx-code-oracle.py` compares the check
  with the KoSIT validator on the local CII examples and mutants of them.
- XRechnung extension: the mappers also declare it for XR01 to XR03 as scheme of a legal
  registration (BT-30, BT-47, BT-61), the payee identifier (BT-60) or the item standard identifier
  (BT-157), which KoSIT allows in the extension only (BR-DEX-04 to BR-DEX-06); before, such an
  invoice was written as standard XRechnung, where BR-CL-10 and BR-CL-11 fail and BR-CL-21 warns.
  The extension codes are now recognized only in upper case, as KoSIT compares them: `xr01`
  declared the extension and then failed BR-DEX-04 to BR-DEX-08.
- `LandrixEInvoiceCheckCII`, `LandrixEInvoiceCheckUBLInvoice` and `LandrixEInvoiceCheckUBLCreditNote`:
  check the required content of a syntax model for a target as the writer reports it, returning
  the number of errors.
- `LandrixEInvoiceCIIRequiredBelowParent`: whether a CII path is required in a Factur-X profile
  wherever its parent exists. `tools/syntaxmodel/cii-profiles.json` has this as a fourth column
  (`tools/fieldmap/fieldmap.py --export`).
- `tools/rulecheck/rule-oracle.py` with `RuleCheckProbe`: compares the rule checks with the KoSIT
  validator on the 1,219 Schematron test documents of XRechnung 3.0.0; known differences (content
  the model cannot hold) are listed with reasons in `tools/rulecheck/oracle-exceptions.txt`.
- `LandrixEInvoiceCheckCIIProfile`: reports what `LandrixEInvoicePruneCII` would remove from a CII
  model, as errors, without changing the model.
- `LandrixEInvoiceFiles`: `LandrixEInvoiceOpenFile`, `LandrixEInvoiceFileExists` and
  `LandrixEInvoiceDirectoryExists` take UTF-16 file names on every compiler (Delphi 6-2007 through
  `CreateFileW`, Free Pascal through the Unicode or UTF-8 file functions).
- Facade `LandrixEInvoice`: `TLandrixEInvoice.SaveToFile/SaveToStream/SaveToUtf8` (invoice or
  syntax model), `ToCII/ToUBLInvoice/ToUBLCreditNote`, `Check` and `LoadFromFile/LoadFromStream/
  LoadFromUtf8` returning a `TLandrixEInvoiceDocument` (invoice, syntax model, diagnostics,
  `TLandrixEInvoiceDocumentInfo`). Writing checks the business rules and refuses on errors
  (`ELandrixEInvoiceWriteError`, nothing written); options `TLandrixEInvoiceOptions` (strict mode,
  no rule check, write despite errors, check on read, invoice only, no PDF). Exceptions
  `ELandrixEInvoiceTargetError`, `ELandrixEInvoiceFormatError`, `ELandrixEInvoicePdfError`.
- `TLandrixEInvoice.CalculateLineAmounts` (BT-131 from quantity, net price, base quantity and
  line allowances and charges; groups as the sum of their sub lines) and `CalculateTotals` (VAT
  breakdown by category and rate, document totals BT-106 to BT-110, BT-112 and BT-115), on request,
  rounded half away from zero; they return the number of errors and leave the invoice unchanged
  then. Test `Calculate.SweepOracle` recalculates the sweep invoices
  (`tests/data/calc-exceptions.txt`).
- `TLandrixEInvoice.LoadFromText` (XML as decoded UTF-16 text; the encoding declaration is not
  consulted) and `SaveToText` (as `SaveToUtf8`, as text that keeps `encoding="UTF-8"`).
- `Assign` on `TLandrixInvoice` and its parts: a deep copy (owned objects, lists and attachment
  data are copied).
- Examples in `examples/` (console programs, `.dpr` for Delphi and `.lpi` for Lazarus):
  WriteXRechnung, ReadInvoice, CheckInvoice, ConvertCIIToUBL, CompatXRechnung and
  BusinessCases, which writes the 24 business cases of XRechnung-for-Delphi for every target
  they fit (111 files). `tools/build.ps1` compiles and runs them after the tests.
- Documentation in `docs/` (English) and `docs/de/` (German): getting started, writing,
  reading, checking, moving from XRechnung-for-Delphi; README with a quick start.
- API levels: every unit states `API: stable` or `API: internal` before its `unit` line; the
  README lists both groups and `tools/check-forbidden.py` checks that stable interfaces use no
  internal unit.
- Internal unit `LandrixEInvoicePdfCheck` (phase 6, level 2 of the PDF validator): `TLandrixEInvoicePdfChecker`
  checks how a ZUGFeRD 2.5.2 / Factur-X 1.09.2 PDF embeds the invoice XML against the business rules for hybrid
  documents BR-HYBRID-12 (name tree and `/AF`, file specification, embedded file stream, MIME type, well-formed
  XML, one invoice only), BR-HYBRID-13 (file name, compared exactly) and BR-HYBRID-11 (the `/AFRelationship`
  values of the table, without profile and country), plus own findings LX-PDF-01 to LX-PDF-09 (PDF not
  readable, object table rebuilt, ZUGFeRD 1.0/2.0 recognised but not checked, `/ModDate` missing, `/Size`
  differs, not UTF-8, other embedded files without `/AFRelationship` or `/AF`, a limit reached,
  `application/xml`, which every hybrid example of ZUGFeRD 2.5.2 uses, as a warning only). The result
  (`TLandrixEInvoicePdfCheckResult`) holds a status per level, the findings and the invoice bytes; a rebuilt
  object table never passes. A second pass, `CheckInvoiceFacts`, takes the target and the seller and buyer
  countries of the extracted invoice, which the caller reads through the facade
  (`TLandrixEInvoicePdfInvoiceFacts`), and adds BR-HYBRID-11 per profile and country (the column of a country
  only when seller and buyer are both in it), BR-HYBRID-13 for file name and profile (`xrechnung.xml` if and
  only if XRECHNUNG), BR-HYBRID-DE-01/02, BR-HYBRID-FR-01 and LX-PDF-10 (a UBL invoice in the PDF).
  `tools/pdfcheck/PdfCheckProbe.dpr` runs both passes over a folder.
- `LandrixEInvoicePdfCheck`, level 3: when level 2 found a Factur-X or XRechnung invoice, the checker reads
  the XMP metadata of the catalog (element and attribute form) and reports BR-HYBRID-02 (the PDF/A part the
  XMP claims), BR-HYBRID-03 to -05 (extension schema, namespace, prefix `fx`), BR-HYBRID-06 to -10
  (`fx:DocumentType`, `fx:ConformanceLevel`, `fx:DocumentFileName`, `fx:Version` against their code lists;
  `EN16931` without a blank is an error; for XRECHNUNG a version like `3.0` is accepted, a version other than
  `1.0` is a warning), BR-HYBRID-14 (`fx:DocumentFileName` and the embedded name) and LX-PDF-11 (no readable
  XMP); `CheckInvoiceFacts` adds BR-HYBRID-15 (`fx:ConformanceLevel` and the profile of the invoice). The
  values read are in the result (`XmpDocumentType`, `XmpDocumentFileName`, `XmpVersion`,
  `XmpConformanceLevel`, `PdfAPart`, `PdfAConformance`); every level has its own status.
- `tools/pdfcheck/pdf-oracle.py`: compares the PDF reader with qpdf 12.4.2 (pinned for Windows x64 and
  ARM64 in `addons/java-tools/tools.json`; elsewhere `qpdf` from the `PATH`) on the local PDF corpus and
  five mutants with a broken `startxref`: the keys of the name tree, per file the file specification, `/F`,
  `/UF`, MIME type, `/ModDate` and the content byte for byte, and whether the cross-reference table had to
  be rebuilt. `PdfCheckProbe -facts=DIR` prints the file specifications of the collector for it.
  Exceptions in `tools/pdfcheck/pdf-exceptions.txt` (none).
- `tools/pdfcheck/mustang-oracle.py`: compares level 3 of the PDF checker with Mustang 2.26.0 (pinned in
  `addons/java-tools/tools.json`, run with the pinned Java runtime) on every corpus PDF with a Factur-X or
  XRechnung invoice and on mutants with one XMP value changed in place: per PDF whether each side rejects
  `fx:ConformanceLevel`, `fx:DocumentType`, `fx:DocumentFileName`, `fx:Version`, the XMP packet and the PDF/A
  part. Exceptions in `tools/pdfcheck/mustang-exceptions.txt` (none).
- An invoice as Markdown for logs, tickets, mails and terminals: internal unit `LandrixEInvoiceRenderMarkdown` with
  `TLandrixEInvoiceRenderMarkdownWriter` (same properties and methods as the HTML writer, from
  `TLandrixEInvoiceRenderWriter`). Same content as the HTML page (the shared walk); CommonMark core only: `#` title,
  `##` sections, `###` parties, a bold line before a top-level list, `- **Label:** value` per value, list items and
  table rows as `*` items carrying their first value, sub lines nested. Text from the invoice is escaped, a value with line breaks
  goes verbatim into a fenced code block; UTF-8 without BOM, LF, no time stamp. Tests `Markdown.Writer`,
  `Markdown.Escaping`, `Markdown.Events` (every line against what the walk calls for, stated by a recording target:
  title, headings, list lines, bare bullets and values with their nesting depth, section, label and value, the
  document section included), `Markdown.Mutations` (every model mutation with one and two items changes the text
  and still matches the walk), `Markdown.Golden` (`tests/data/render/*.md`), `Markdown.Corpus` (every local file, both languages).
- `tools/render/md-oracle.py` with `tools/render/MarkdownProbe.dpr` and `tools/render/md-walk.js`: parses the Markdown
  of the filled, golden and hostile invoices and of every local corpus file with commonmark.js 0.31.2 (the
  CommonMark reference implementation, pinned in `addons/java-tools/tools.json`, run with Node.js): no HTML, link,
  image, emphasis or inline code node; the parsed headings and items give the same kinds, nesting depths, sections,
  labels and values as the walk (white space at the edges of a one-line value and blank lines of a longer one
  excepted, which rendered CommonMark does not show). Exceptions in
  `tools/render/md-exceptions.txt` (none).
- Example `examples/Workbench`: a window in the spirit of the sample project of XRechnung-for-Delphi, native only
  (no Java, no validation service, no browser control). It creates the overall example with its options or one of
  25 cases (the business cases and their variants) for XRechnung UBL or CII, ZUGFeRD EN 16931 or EXTENDED or Peppol BIS, or opens an XML
  invoice or a ZUGFeRD / Factur-X PDF; it shows the XML, checks it with `TLandrixEInvoiceDocumentValidator` (the
  library's own rules, and KoSIT with the folder of `addons/kosit/install-kosit.ps1` it finds or is given), reads it back and
  writes it again (byte comparison), shows the invoice as Markdown and opens the invoice and the check report as
  HTML in the default browser. Interface German (default) or English, the choice also sets the language of the
  invoice and the report. One unit for Delphi 6 to 13 (VCL, `.dfm`, `Workbench.dproj` with the search paths and
  the output in `build/Workbench/`) and Lazarus (LCL, `.lfm`, `Workbench.lpi`).
  `tools/build.ps1` compiles it with Delphi without running it (the FPC toolchains have no LCL) and compiles every
  Delphi example in its own folder; `tools/check-forbidden.py` allows the GUI units in this example only. The single
  business cases of `LandrixEInvoiceExampleScenarios` are now in its interface.
- `addons/kosit/install-kosit.ps1`: installs what the native KoSIT check needs, without Java, into one folder to
  ship with an application: the KoSIT configurations XRechnung 3.0.2 (2026-08-31) and Peppol BIS Billing 3.0.21,
  the ZUGFeRD 2.5.2 / Factur-X 1.09.2 configuration (2026-10-15), the LandrixXML rule files (from the submodule or
  the LandrixXML release) and the Peppol Schematron 3.0.21 (OpenPEPPOL). Modules `xrechnung`, `bis`, `zugferd`;
  every file pinned by URL and SHA-256 in `addons/kosit/kosit.json`; Windows PowerShell 5.1 or PowerShell 7.
- Documentation: `docs/validation.md` (and German) on document validation, the KoSIT files, the rule file
  mapping, the verdict, reports, HTML and Markdown rendering, what to ship and the licences of the KoSIT
  material; these units are documented as a preview (marked `API: internal`, names may change before 1.0).
  Getting started: syntaxes per standard, ZIP download without submodule, Delphi 6/7 search path, Workbench
  setup, what to ship. Reading: the reading options; plain EN 16931 in CII is Factur-X EN 16931. README:
  the syntax models as they are (CII EXTENDED, UBL positive list), the preview units.
- `docs/compat-xrechnung.md` (and German) as a step-by-step guide: steps, what is gone and what replaces it
  (`TXRechnungHelper` code conversions, `TZUGFeRDAdditionalContent`, `IXMLDocument`, the Java helper with the
  native validation and rendering), behaviour changes of reading, writing and the model, the old sample project
  (Workbench, BusinessCases), and the move to the facade.
- `docs/compat-zugferd.md` (and German): moving from ZUGFeRD-for-Delphi (no compatibility layer): the two models
  instead of the descriptor, reading, writing with the profile table, checking, PDF, differences in the model and
  the licence. A field-by-field table follows.

### Changed
- Factur-X EN16931 CII writes one preceding invoice reference (BG-3, `ram:InvoiceReferencedDocument`), as
  XRechnung CII already did; further ones are left out with a warning and reported by LX-CC-03. The KoSIT
  XRechnung configuration validates this profile against CII D16B, which allows one (as XRechnung-for-Delphi
  `163eacf`). BASIC, BASIC WL and EXTENDED keep several.
- BT-113 (prepaid amount, UBL `cbc:PrepaidAmount`, CII `ram:TotalPrepaidAmount`) is written only when it is not
  0: the element is optional and receivers showed 0.00 as a prepayment (as XRechnung-for-Delphi `4caa0a1`).
- The object layer of the PDF reader (lexer, stream filters, decryption, objects, document) moved from
  `LandrixEInvoicePdf` into the new internal unit `LandrixEInvoicePdfObjects`, for the PDF checks of
  phase 6; the extraction is unchanged. Its collector (`TLandrixEInvoicePdfCollector`) keeps every
  file specification as found: the routes (name tree, `/AF`), path and key in the name tree, `/Type`, `/F`,
  `/UF`, `/AFRelationship`, the embedded file stream with `/Type`, `/Subtype` and `/Params`, a second file
  specification on the same stream, structural problems of the name tree (key order, `/Limits`) and whether a
  limit stopped the collection; the
  document gives access to the trailer `/Info`, the catalog `/Metadata` and `/Version`. The extractor builds
  its attachment list from it as before.
- Sub lines (line groups) are written flat where the target does not nest them: XRechnung CII, the
  Factur-X profiles below EXTENDED, Peppol BIS and UBL credit notes get the lines of a group,
  depth-first, instead of the group (before: the group line alone in CII and credit notes, and
  `cac:SubInvoiceLine` in Peppol, which UBL-CR-646 flags and the KoSIT validator rejects). The
  group lines and INFORMATION sub lines are left out; each top-level group is reported
  (`edk_NotAllowed`). New internal unit
  `LandrixEInvoiceSubLines`; the facade, the mappers and the checks work on the same flat copy, so
  the rules judge the invoice as written. LX-CC-11 no longer reports sub lines of such a target
  (the compatibility adapter returns `ccOK` instead of `ccSubInvoiceLinesNotSupported` there).
- The compatibility adapter reads and writes through the facade `TLandrixEInvoice` (writing without
  business rule check and despite errors, as before); an unknown specification identifier now also
  adds a warning to its diagnostics. A failed load leaves the invoice unchanged (before, it was
  cleared or partly filled); XML errors of files, streams and text all start with 'Not valid XML: '.
- The compatibility adapter opens files through `LandrixEInvoiceFiles`: on Free Pascal file names
  outside the system code page are no longer lost.
- `LandrixEInvoiceCheckCII` reports content the Factur-X profile does not contain as an error
  (`edk_NotAllowed`) instead of ignoring it.
- Invoice and line periods (BG-14, BG-26) are compared as dates, as BR-29/BR-30 do: a period that
  starts later on the day it ends is written; a period that ends on an earlier date is still left
  out, now with a warning.
- The writers write a payee, tax representative or invoicee only when a field other than a scheme
  holds text other than white space, as the rule checks assume.
- An account name (BT-85) next to a direct debit is reported when the writers leave it out.
- `tools/validate.ps1` shows the effective level of each message: the configuration's `customLevel`
  for the matched scenario applies (e.g. CII-SR-465 is an error in XRechnung), information is not
  listed.
- Payment means code 49 (direct debit) is written like 59: the account is the debited account
  (BT-91, UBL `cac:PaymentMandate/cac:PayerFinancialAccount`, CII `ram:PayerPartyDebtorFinancialAccount`)
  and UBL writes the mandate reference (BT-89), which Peppol requires (PEPPOL-EN16931-R061); the UBL
  writer dropped it before. BR-DE-30/31 treat 49 as a direct debit group.
- With a direct debit (49, 59) the readers report a credit transfer account (BG-17) instead of
  reading it as the debited account (BT-91); UBL reads the mandate's payer account instead.
- The ZUGFeRD identifiers `urn:zugferd.de:2p0:...` (BT-24), which Factur-X 1.09 accepts for
  MINIMUM, BASIC WL, BASIC and EXTENDED, are recognised when reading; written is always the
  Factur-X identifier.
- Factur-X EXTENDED takes several invoiced object identifiers (BT-18); the other targets keep the
  first (CII-SR-458, UBL-SR-04).
- The scenario unit moved from the tests to `examples/BusinessCases/LandrixEInvoiceExampleScenarios.pas`;
  its four attachments are in the repository (`examples/BusinessCases/attachments/`), so the
  golden-file, cross and profile tests no longer need local attachments.
  `tools/check-forbidden.py` checks `examples/` instead of the missing `samples/`.
- Compatibility layer: where `String` is Unicode (Delphi 2009+, Free Pascal),
  `LoadFromXMLStr` and `GetXRechnungVersionFromString` read the text as decoded and no longer
  follow its encoding declaration, which garbled non-ASCII text declared as e.g. ISO-8859-1;
  an unpaired surrogate makes `LoadFromXMLStr` return False instead of raising.
- UBL: the creditor identifier (BT-90) is written in the payee (`cac:PayeeParty`) when a payee is
  written, as in the XRechnung example `direct-debit-bt-90-payee`, otherwise in the seller.
- The CII writer also reports content that the schema leaves optional but the Factur-X profile
  requires below an existing parent, e.g. the invoiced quantity, its unit code, the net price and
  the line total of a line in BASIC (BR-22, BR-23, BR-26, BR-24). The profile pruning treats blank
  text as absent, as the writers do.
- Text that consists of XML white space only counts as absent, as `normalize-space()` in the
  Schematron rules (new `LandrixEInvoiceIsBlank`): the generated CII and UBL writers do not write
  such text (a required element is reported as missing), the mappers treat it like an empty field
  (no defaults or fallbacks from it, a blank note is no note). The syntax models still write back
  what they read, including elements with attributes and no text.
- Unit code XSA is `iuc_sack` (as in XRechnung-for-Delphi); the free texts sack, saecke and sck
  mean XSA (sack) instead of XBG, beutel is XBG (bag).
- Factur-X EXTENDED logistics service charges (BT-X-271 to BT-X-274) are read as document level
  charges (BG-21) and reported as information; the totals and the VAT breakdown include them, so
  leaving them out made every written invoice inconsistent.
- Third-party payments (BG-DEX-09) left out by a target are an error, no longer a warning: the
  amount due still includes them, so the output violates BR-CO-16.
- Cash discount outside Factur-X EXTENDED: the net note follows the `#SKONTO#` lines (BR-DE-18
  allows free text after them) instead of being dropped; reading puts only the other lines into
  the net note (XRechnung-for-Delphi kept the whole text there, so `PaymentTermNetNote` of the
  compatibility layer no longer contains the `#SKONTO#` lines).
- XRechnung UBL: a third-party payment without type (BT-DEX-001) or description (BT-DEX-003)
  takes the other one, with a warning; without both it is an error (BR-DEX-10, BR-DEX-12).
- Prices (`GrossPriceAmount`, `DiscountOnTheGrossPrice`, `NetPriceAmount`; BT-146 to BT-148) are
  `Double` instead of `Currency`: EN 16931 does not limit their decimals and the KoSIT testsuite
  has prices with 5 and 9 decimals. `LandrixEInvoicePriceToLexical` takes a `Double` and writes
  more than 4 decimals only when the value needs them.
- The readers no longer derive the VAT accounting currency (BT-6) from a VAT total in the invoice
  currency; `TaxCurrencyCode` stays empty then.
- CII-SR-450 (buyer identifier and global identifier not together) applies to XRechnung CII only;
  the Factur-X schematron has no such rule.
- UBL: a contact department without a person name is written as the contact point
  (`cac:Contact/cbc:Name`, BT-41/BT-56) instead of being left out; XRechnung requires BT-41
  (BR-DE-5), and a valid CII invoice whose seller contact is a department became invalid UBL.
- The rule check (`LandrixEInvoiceCheckInvoice`, also `eio_CheckOnRead` and the validator) no longer raises for a
  number the writers cannot format (NaN, infinite, 1e23 and above): each such number the writers write is an
  error of its own (`edk_ConversionFailed`, path = business term), a rule that cannot judge it holds, and with a
  NaN no rule runs (its comparisons differ between compilers). VAT rates are compared exactly as written (two
  decimals, any size) in the VAT category rules, BR-S-09 and BR-CO-17; before, a rate above the `Currency` range
  became 0, taxable amount x rate could overflow, and BR-CO-17 rounded `-0.5` away from 0 unlike XPath. Cent
  amounts of the rules cover the whole `Currency` range.
- The rule check no longer raises for a date the writers cannot format either (NaN or outside 0001-9999, as a
  caller can set it): each such date the writers write (a plain date above 0, an optional one with a value, a
  delivery note or despatch advice date only with its number) is an error of its own (`edk_ConversionFailed`, path = business term), and a NaN date always is and stops every rule.
  The rules that compare or format such a date hold (BR-29, BR-30, PEPPOL-EN16931-R110/R111, IS-R-008 to -010,
  GR-R-001-3).
- The walk through the invoice moved from `LandrixEInvoiceRenderHtml` into the new internal unit
  `LandrixEInvoiceRenderWalk`, to be shared by further output formats: `TLandrixEInvoiceRenderTarget` (abstract
  receiver of the walk, one subclass per format; groups wait for their first value, so empty ones leave nothing) and
  `TLandrixEInvoiceRenderWriter` (`DocumentName`, `Language`, `ShowBusinessTerms`, `WriteToStream`, `SaveToFile` and
  the new `WriteToString`), from which `TLandrixEInvoiceRenderHtmlWriter` descends. The pages stay byte-identical
  (checked on every local corpus document and every model mutation with one and two items per list, both languages,
  with and without business terms).

[Unreleased]: https://github.com/LandrixSoftware/EInvoice-for-Pascal/compare/v0.9.0-beta.2...HEAD
[0.9.0-beta.2]: https://github.com/LandrixSoftware/EInvoice-for-Pascal/compare/v0.9.0-beta.1...v0.9.0-beta.2
[0.9.0-beta.1]: https://github.com/LandrixSoftware/EInvoice-for-Pascal/releases/tag/v0.9.0-beta.1
