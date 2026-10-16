# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Supported invoice standards are documented per release.

## [Unreleased]

### Added
- Project foundation: dual licensing (GPL-3.0-or-later or Landrix Software Commercial
  License), third-party notices, contribution rules, security policy.
- LandrixXML for Pascal as Git submodule in `external/landrix-xml`, pinned to
  release 0.2.0.
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
- `LandrixEInvoiceCodes`: code lists of the model (invoice type, payment means, unit of
  measure, attachment MIME type and document type, allowance and charge reasons, VAT
  category, note subject) with `...ToStr` / `...FromStr` functions.
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
- Framework-free console test runner `tests/LandrixEInvoiceTests.dpr`.
- `tools/build.ps1`: builds and runs the tests with the local toolchains.
- CI with Free Pascal 3.2.2 on Linux (manual start only for now).
