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
  only when asked for, LX-ID hints never count.
- `python tools/check-forbidden.py` (without arguments) fails when an identifier of the source is
  missing here or in the German list, when a list names an identifier the source does not have
  (unless it is marked retired), or when an identifier appears twice in a list.

Families: `LX-CC` (checks of XRechnung-for-Delphi), `LX-PDF` (hybrid PDF), `LX-ID` (identifiers,
check digits and characters). Reserved for planned checks: `LX-PL` (plausibility of dates
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

## LX-ID: identifiers and characters (advisory)

Hints of the advisory checks (family `eaf_Identifiers`, on by default): characters (LX-ID-01 to
LX-ID-05) and identifiers by their scheme (LX-ID-06 to LX-ID-10). They appear in the part
`advisory` of a validation, which never counts for the verdict, and are at most warnings. The
finding names the model path, the first character as `U+XXXX` with its position (counted in characters) and how many there
are; `found` shows the value with the characters masked as `<U+XXXX>`. The value is never changed.

Identifier fields are identifiers, codes, references, postal codes, telephone numbers, e-mail
addresses and file names; text fields are names and free texts (also the remittance information,
BT-83). ASCII identifiers: VAT identifiers (BT-31, BT-48, BT-63), country and currency codes, the
GTIN (BT-157 with scheme 0160), the SEPA creditor identifier (BT-90), the payment service provider
(BT-86), the mandate reference (BT-89) of a SEPA direct debit (59) and the account (BT-84, BT-91) of
a SEPA payment (58, 59) or one that starts like an IBAN.

| Identifier | Severity | Finding | Since |
|---|---|---|---|
| LX-ID-01 | warning | a bidirectional control character (U+061C, U+200E, U+200F, U+202A to U+202E, U+2066 to U+2069) in an identifier field | unreleased |
| LX-ID-02 | warning | an invisible character (e.g. U+200B to U+200D, U+2060, U+FEFF, U+00AD, variation selectors, tag characters) or a space other than U+0020 (e.g. U+00A0, U+2000 to U+200A, U+3000) in an identifier field | unreleased |
| LX-ID-03 | warning | a C1 control character (U+0080 to U+009F) in any text field, usually a wrong character encoding | unreleased |
| LX-ID-04 | info | a bidirectional control or invisible character in a name or free text, where it can be legitimate | unreleased |
| LX-ID-05 | warning | another character outside ASCII in an ASCII identifier, e.g. a Cyrillic letter that looks like a Latin one | unreleased |
| LX-ID-06 | warning | a GLN (scheme 0088; a global identifier without scheme counts as one) of a party, location or electronic address that is not 13 digits or has a wrong GS1 check digit (for Peppol BIS, where the rule check of the same run reported PEPPOL-COMMON-R040, only the length) | unreleased |
| LX-ID-07 | warning | a GTIN (BT-157 with scheme 0160, or the GTIN field of a line without BT-157) that is not 8, 12, 13 or 14 digits or has a wrong GS1 check digit | unreleased |
| LX-ID-08 | warning | a GTIN (scheme 0160) for a party, location or address, or a GLN (scheme 0088) for a trade item | unreleased |
| LX-ID-09 | warning (BT-10 outside XRechnung: info) | a Leitweg-ID (scheme 0204) that does not follow the format specification 2.0.2 (form, coarse address of 2, 3, 5, 8, 9 or 12 digits starting with 01 to 16 or 99, check digits MOD 97-10), also as item identifier, or a buyer reference (BT-10) that looks like a Leitweg-ID (a coarse address of 8 or more digits, or 99... with a fine address) but has wrong check digits | unreleased |
| LX-ID-10 | info | the buyer reference (BT-10) and the electronic address of the buyer (BT-49, scheme 0204) are different valid Leitweg-IDs; the Peppol ID need not be the Leitweg-ID (`expected`: BT-49, `found`: BT-10) | unreleased |
