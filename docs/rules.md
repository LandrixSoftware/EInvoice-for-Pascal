# Rules of this library

[Deutsch](de/rules.md)

Most findings carry the identifier of an official rule (BR-..., PEPPOL-..., FX-SCH-A-...,
BR-HYBRID-..., PDF/A clauses). Where the standards have no rule, this library uses its own
identifiers, all starting with `LX-`. This page lists every one of them.

## How the identifiers work

- An identifier is `LX-<family>-<number>`, the number has two digits.
- Identifier and meaning are stable. Text and severity may change in a release.
- A number is never reused or renumbered. A retired rule stays in this list with
  "retired in <version>" at the end of the column Since and keeps its number reserved.
- A rule whose condition becomes broader gets a new number.
- The prefix says nothing about the verdict: where a finding appears decides that (see
  [Validating](validation.md)). LX-PDF errors count for the verdict of a hybrid PDF, LX-CC rules run
  only when asked for.
- `python tools/check-forbidden.py` (without arguments) fails when an identifier of the source is
  missing here or in the German list, when a list names an identifier the source does not have
  (unless it is marked retired), or when an identifier appears twice in a list.

Families: `LX-CC` (checks of XRechnung-for-Delphi), `LX-PDF` (hybrid PDF). Reserved for planned
checks: `LX-ID` (identifiers, check digits, deceptive characters), `LX-PL` (plausibility of dates
and payment), `LX-AR` (arithmetic where no official rule exists), `LX-AT` (attachments), `LX-DE`
(German tax law).

## LX-CC: checks of XRechnung-for-Delphi

The checks of `TXRechnungInvoiceAdapter.ConsistencyCheck` (number = old error code). They are
policies of that library, not published rules: `TLandrixEInvoice.Check` and writing do not run
them; `LandrixEInvoiceCheckRule` and the compatibility layer ask them one by one. Severity: error.

| Identifier | Terms | Applies to | Finding | Since |
|---|---|---|---|---|
| LX-CC-01 | BG-16 | all but Factur-X EN 16931 | no payment instructions (payment means) | 0.9.0-beta.1 |
| LX-CC-02 | BT-3 | XRechnung | invoice type code 84, 261, 383, 386 or 457 | 0.9.0-beta.1 |
| LX-CC-03 | BG-3 | all | more preceding invoice references than the target allows | 0.9.0-beta.1 |
| LX-CC-04 | BG-19 | all | more than one SEPA direct debit (payment means 59) | 0.9.0-beta.1 |
| LX-CC-05 | BG-18 | all | more than one credit card (payment means 54) | 0.9.0-beta.1 |
| LX-CC-06 | BT-31, BT-30 | all | seller without VAT identifier and legal registration identifier | 0.9.0-beta.1 |
| LX-CC-07 | BT-31, BT-32 | all | seller without VAT identifier and tax registration identifier | 0.9.0-beta.1 |
| LX-CC-08 | BG-DEX-09 | all | third-party payments the target does not allow | 0.9.0-beta.1 |
| LX-CC-09 | BT-34, BT-49 | all | electronic address with scheme EM under Peppol, or without scheme where the default EM does not apply | 0.9.0-beta.1 |
| LX-CC-10 | BG-25 | all | delivery note or delivery date per line the target does not allow | 0.9.0-beta.1 |
| LX-CC-11 | BG-DEX-01 | all | an INFORMATION line on the top level or a DETAIL line with sub lines outside Factur-X EXTENDED | 0.9.0-beta.1 |
| LX-CC-12 | BG-DEX-01 | Factur-X EXTENDED | amount of a GROUP line differs from the sum of its DETAIL and GROUP sub lines (BR-FXEXT-08) | 0.9.0-beta.1 |

## LX-PDF: hybrid PDF (ZUGFeRD / Factur-X)

Findings of the PDF checker for what the BR-HYBRID rules do not name. Where they appear in a
validation:

- `pdfEmbedding`: LX-PDF-01 to LX-PDF-07, LX-PDF-09, LX-PDF-10, and LX-PDF-08 for a limit outside
  the XMP metadata;
- `pdfMetadata`: LX-PDF-11, and LX-PDF-08 for a limit in the XMP metadata;
- `pdfA`: LX-PDF-12; this part does not count for the verdict.

An error fails its part and so rejects the PDF. LX-PDF-02, LX-PDF-03 and LX-PDF-08 mean that not
everything was checked: they leave the parts they affect incomplete (LX-PDF-02 and LX-PDF-03 also
`pdfMetadata`, although they are reported under `pdfEmbedding`), and so the verdict, unless an
error rejects the PDF anyway.

| Identifier | Severity | Finding | Since |
|---|---|---|---|
| LX-PDF-01 | error | the PDF cannot be read or decrypted | 0.9.0-beta.1 |
| LX-PDF-02 | warning | the object table was rebuilt by a scan | 0.9.0-beta.1 |
| LX-PDF-03 | info or warning | ZUGFeRD 1.0 or 2.0: recognised, not checked (warning when the invoice cannot be extracted; when a decoding limit stopped it, LX-PDF-08 instead) | 0.9.0-beta.1 |
| LX-PDF-04 | warning | the stream of the embedded invoice has no `/Params /ModDate` | 0.9.0-beta.1 |
| LX-PDF-05 | warning | `/Params /Size` differs from the decoded length | 0.9.0-beta.1 |
| LX-PDF-06 | warning | the invoice XML is not encoded in UTF-8 | 0.9.0-beta.1 |
| LX-PDF-07 | error | another embedded file without `/AFRelationship` or not in the `/AF` of the catalog or of a page (ISO 19005-3, 6.8; `/AF` of annotations, form fields, structure elements and XObjects is not searched yet) | 0.9.0-beta.1 |
| LX-PDF-08 | warning | a limit was reached; not everything was checked | 0.9.0-beta.1 |
| LX-PDF-09 | warning | the MIME type of the invoice is `application/xml`, not `text/xml` | 0.9.0-beta.1 |
| LX-PDF-10 | error | the embedded invoice is UBL, not a CII invoice of a ZUGFeRD profile | 0.9.0-beta.1 |
| LX-PDF-11 | error | the XMP metadata is missing, cannot be decoded, is not well-formed or has no `rdf:RDF` with `rdf:Description` | 0.9.0-beta.1 |
| LX-PDF-12 | warning | the PDF/A check stopped before it was complete | unreleased |
