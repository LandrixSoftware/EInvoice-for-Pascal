# Moving from ZUGFeRD-for-Delphi

[Deutsch](de/compat-zugferd.md)

There is no compatibility layer for `TZUGFeRDInvoiceDescriptor`: moving from ZUGFeRD-for-Delphi
means rewriting the code that fills and reads invoices. This page shows where things are now; a
field-by-field table (descriptor property to business term and field) will follow. Until then,
[Writing](writing.md) and [examples/WriteXRechnung](../examples/WriteXRechnung/WriteXRechnung.dpr)
show how an invoice is filled. ZUGFeRD-for-Delphi stays available under the Apache License 2.0;
this library is licensed under the GPL-3.0-or-later or the Landrix Software Commercial License
([README](../README.md#license)).

## Two models instead of the descriptor

| You need | Use |
|---|---|
| The invoice as EN 16931 describes it, the same for every format | `TLandrixInvoice` (unit `LandrixEInvoiceInvoice`) and the facade `TLandrixEInvoice`: what most programs need ([Getting started](getting-started.md)) |
| Every element of the CII document, including everything Factur-X EXTENDED has | `TLandrixCIIInvoice` (unit `LandrixEInvoiceCII`), generated from the Factur-X EXTENDED schema: the closest to the descriptor |

The facade reads and writes both. A read document holds `Doc.Invoice` and the syntax model it was
read from: `Doc.CII` for CII, `Doc.UBLInvoice` or `Doc.UBLCreditNote` for UBL (none with
`eio_InvoiceOnly`). They are independent copies: changing one does not change the other.

## Reading

| ZUGFeRD-for-Delphi | EInvoice for Pascal |
|---|---|
| `TZUGFeRDInvoiceDescriptor.Load(FileName)` | `Doc := TLandrixEInvoice.LoadFromFile(FileName)`, also for a ZUGFeRD / Factur-X PDF; free `Doc` |
| `Load(Stream)` | `TLandrixEInvoice.LoadFromStream(Stream)` |
| `Load(IXMLDocument)` | none: no MSXML; pass the bytes (`LoadFromUtf8`) or the text (`LoadFromText`) |
| `GetVersion(FileName)` | `Doc.Info`: `SpecFound`, `Spec.Target` (standard, syntax, profile), `CustomizationID` as read |
| the profile of the read descriptor | `Doc.Info.Spec.Target.Profile` (for an XRechnung file, UBL or CII, `Standard` is `est_XRechnung` and `Profile` is `epr_None`: test the standard) |

`Spec.Target` names the release this library supports (Factur-X 1.09), not the release of the
sender: a ZUGFeRD 2.0 file and a 2.3 file give the same target. ZUGFeRD 2.x files of the profiles
MINIMUM, BASIC WL, BASIC, EN 16931, EXTENDED and XRechnung 3.0 are recognised (the
`urn:zugferd.de:2p0:...` identifiers are mapped to the Factur-X ones; EN 16931 uses the same
identifier in both); XRechnung 1.x and 2.x identifiers are unknown. An unknown identifier is
read anyway, with a warning and `SpecFound` False. ZUGFeRD 1.0 is not read
(`ELandrixEInvoiceFormatError`). What the descriptor read leniently is in `Doc.Diagnostics`. See
[Reading](reading.md).

## Writing

`Desc.Save(Stream, Version, Profile, Format, Options)` becomes
`TLandrixEInvoice.SaveToStream(Invoice, Stream, Target, AOptions, ADiagnostics)` (or `SaveToFile`),
with a target from `TLandrixEInvoiceTargets`; `AOptions` (default `[]`) and `ADiagnostics` (default
`nil`) take the place of the format options:

| `TZUGFeRDProfile` | Target |
|---|---|
| `Minimum` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Minimum)` |
| `BasicWL` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_BasicWL)` |
| `Basic` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Basic)` |
| `Comfort` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931)` |
| `Extended` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended)` |
| `XRechnung` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_XRechnung)` (= XRechnung 3.0 CII) |
| `XRechnung1`, `EReporting` | none |
| format `UBL` (XRechnung profile) | `TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)`, or `TLandrixEInvoiceTargets.PeppolBIS('3.0')` |

Written is ZUGFeRD 2.5 / Factur-X 1.09 only: `ZUGFeRD('2.0', ...)` or `('2.3', ...)` gives a target
that writing refuses (`ELandrixEInvoiceTargetError`). Who must still send ZUGFeRD 1.0, 2.0, 2.3,
XRechnung 1.x or 2.x or e-reporting stays with ZUGFeRD-for-Delphi for those. Writing a `TLandrixInvoice`
checks the business rules of the target first and refuses an invoice with errors
([Writing](writing.md)); writing a `TLandrixCIIInvoice` checks the identifiers and, for the Factur-X
profiles, the profile and the Factur-X code lists, not the business rules.

## Checking and totals

| ZUGFeRD-for-Delphi | EInvoice for Pascal |
|---|---|
| `TZUGFeRDInvoiceValidator.Validate(Desc, Version)` (recomputes the totals, returns messages) | `TLandrixEInvoice.Check(Invoice, Target, [], Diagnostics)`: the number of errors, the findings in `Diagnostics`, all business rules of the target including the totals ([Checking](checking.md)) |
| totals computed by the program | `TLandrixEInvoice.CalculateLineAmounts`, `CalculateTotals` ([Writing](writing.md#calculating-amounts)) |
| (the KoSIT or Mustang validator, outside the library) | `TLandrixEInvoiceDocumentValidator`: the KoSIT configurations natively, without Java ([Validating](validation.md)) |

## PDF

Reading takes the invoice out of a ZUGFeRD / Factur-X PDF: `LoadFromFile` raises
`ELandrixEInvoicePdfError` for a PDF without invoice; `TLandrixEInvoicePdfExtractor.ExtractInvoiceFromFile`
only extracts the XML and returns False with the reason in its info. The library does not write
PDF: for a hybrid PDF, your PDF library embeds the XML under the attachment name of the target
(`Spec.AttachmentFileName`: `factur-x.xml`, `xrechnung.xml` for XRechnung CII; XRechnung UBL and Peppol
BIS have none) with the XMP
metadata of `LandrixEInvoicePdfXmpDescription(Target)`. `Spec` is `Doc.Info.Spec` of a read
document or comes from `LandrixEInvoiceFindSpec(Target, Spec)`.

## Differences in the model

- No generics and no `Nullable<T>`: fields are plain values. Where "not set" and zero differ (for
  example optional amounts and dates), small value types take their place
  (`TLandrixEInvoiceAmount`, `TLandrixEInvoiceDate` and others in `LandrixEInvoiceTypes`, with
  `HasValue`, `SetValue`, `Clear`).
- Text is `TLandrixEInvoiceString` (UTF-16 on every compiler). Most dates are `TDateTime`, where 0
  means not set; a few are `TLandrixEInvoiceDate` (for example `OrderDate`, `TaxPointDate`).
- Code lists are enumerations with conversion functions in `LandrixEInvoiceCodes`
  (`LandrixEInvoiceTypeCodeToStr`, `LandrixEInvoiceTypeCodeFromStr` and so on).
- Errors are exceptions of the facade: `ELandrixEInvoiceFormatError` (not readable),
  `ELandrixEInvoiceTargetError` (unknown target), `ELandrixEInvoiceWriteError` (refused for
  errors).
- The library runs on Delphi 6 to 13 and Free Pascal 3.2.2+.
