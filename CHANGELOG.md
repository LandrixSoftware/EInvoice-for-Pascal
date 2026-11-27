# Changelog

All notable changes to this project are documented here: the changes
since the last release in this file, each release in a file of its own
under [docs/changelog](docs/changelog) (moved there when it is released).
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Supported invoice standards are documented per release.

## [Unreleased]

### Added
- `tools/upstream-check.py`: reports upstream releases newer than the pinned versions (CEN EN 16931
  artefacts, KoSIT configurations, Schematron, visualization and validator, Peppol BIS, the ZUGFeRD
  configuration, Mustang, veraPDF, qpdf, the JRE, commonmark.js, Unicode CLDR, LandrixXML) through the
  `gh` CLI, and two files that pin different versions of one download; it changes nothing. Exit code 1
  when something is newer or inconsistent, 2 when a pin or release cannot be read.
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
- PDF/A level 1, stage D, fourth part (overprint and Separation spaces): 6.2.4.2-2 (an ICCBased CMYK space is
  not painted with overprint on and an overprint mode other than 0) and 6.2.4.4-2 (Separation spaces of one
  colourant name have the same alternate space and tint transform), both fully implemented. The content walk keeps
  `/OP`, `/op` and `/OPM` of the graphics state as veraPDF reads them and gives them only to the colour space a paint
  or text operator links directly. Separations are compared document-wide as veraPDF compares their objects; a
  conflict is certain only between two Separations certainly used. Where veraPDF itself stops with an exception
  (a Separation whose alternate space it cannot build, a reference to no object in a compared value, an alternate
  image without its image), no rule of the document is decided. Test `PdfA.Colour2`; all 10 corpus failures of
  these rules are found, no false positives.

### Changed
- LandrixXML 0.5.1 (`a2305e0`, was 0.5.0): fixes of a complete review (many for very large or hostile input),
  XML Schema pattern character classes as in Xerces (the validator of the KoSIT tools), the XSLT prefixes `xs` and
  `fn` bound only where a stylesheet declares them, and a result limit for Schematron. The KoSIT, visualization,
  rule and Peppol oracles show no difference. Reading numbers on 32-bit x86 no longer changes the process-wide
  FPU control word, so the note on threads in `docs/validation.md` drops it.
- Validator: a Schematron step keeps at most `MaxSchematronResults` results (new property of
  `TLandrixEInvoiceValidator`, default 10,000, 0 = no limit, as `MaxErrors` of the XML Schema step); beyond it
  the result gets an error message (`generic-error`; a dynamic error after the limit is a processing error
  instead, and the new `TLandrixEInvoiceValidationResult.Cut` tells both), the document is never accepted, also without
  `acceptMatch` and whatever `customLevel` says; the KoSIT report refuses such a result
  (`ELandrixEInvoiceError`), since the report stylesheets would judge the kept results only. New
  `TLandrixEInvoiceValidationMessage.Cut` marks such messages (also the XML Schema one); the document validation
  reports the KoSIT part of a cut result as incomplete. Before, LandrixXML had no such limit. The KoSIT oracle masks
  only the check time of the report page, also with one-digit day, month or hour.
- `tools/build.ps1`: new set `dev` (before every commit: FPC 3.2.2 Win32/Win64 and Linux with checks, Delphi 6,
  Delphi 13 Win32/Win64). The local toolchains build and run in parallel (`-Jobs`, child processes, output in
  `build/<toolchain>/worker.log`). The new toolchain `x86` (in `dev` and `all`) runs the test runners of the Windows
  toolchains of the call at the same time on a real x86 machine over SSH, in a work tree kept there and brought up to
  date by a manifest; the outputs the cross test and `-Validate` need come back. Without the machine they run locally
  with a warning. The Linux toolchains work in a copy of the tree in the WSL file system (`rsync`, one per checkout)
  instead of on `/mnt/d`. Toolchain names are case-insensitive.
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
- Compiler hints and warnings on FPC 3.2.2 i386 (Int64 subtraction, signed with unsigned) and Delphi 13 Win32/Win64
  (W1072 for NativeInt lengths and counts, W1057 to W1060 for string casts, now byte-wise ASCII conversions); no
  change in behaviour.
- Reading CII: the due date of a cash discount term whose own period (basis date plus days) ends on another date is the
  net due date BT-9 when no net term gives one, as ZUGFeRD EXTENDED invoices write it (`#SKONTO#` term with
  `DueDateDateTime`); it was dropped silently. Further differing dates are reported.

## Releases

- [0.9.0-beta.2](docs/changelog/0.9.0-beta.2.md) - 2026-11-17
- [0.9.0-beta.1](docs/changelog/0.9.0-beta.1.md) - 2026-11-13

[Unreleased]: https://github.com/LandrixSoftware/EInvoice-for-Pascal/compare/v0.9.0-beta.2...HEAD
