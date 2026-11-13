# Moving from XRechnung-for-Delphi

[Deutsch](de/compat-xrechnung.md)

The compatibility units keep the names of XRechnung-for-Delphi (`TInvoice`,
`TXRechnungInvoiceAdapter`, `TXRechnungVersion`, the enumeration members), so most code compiles
after the uses clause changes. This page lists the steps, what is gone and what behaves
differently. [examples/CompatXRechnung](../examples/CompatXRechnung/CompatXRechnung.dpr) shows
the compatibility layer at work.

## Steps

1. **Get the library** with its submodule and add `source` and `external/landrix-xml/source` to
   the search path ([Getting started](getting-started.md#setup)). Remove the old units from the
   search path, together with `intfMSXML2_TLB` (Delphi 6) and the `Distribution` folder of Java
   tools: nothing of it is needed any more.
2. **Change the uses clauses:**

   | Old unit | New unit |
   |---|---|
   | `intf.Invoice` (Delphi 6: `intfInvoice`) | `LandrixEInvoiceCompatXRechnung` |
   | `intf.XRechnung` (Delphi 6: `intfXRechnung`) | `LandrixEInvoiceCompatXRechnungAdapter` |
   | `intf.XRechnungPdfExtract` | `LandrixEInvoiceCompatXRechnungPdf` |
   | `intf.XRechnungVersionInfo` | `LandrixEInvoiceTypes`: `LandrixEInvoiceVersion` (the library's own version number; product name and release date have no counterpart) |
   | `intf.XRechnungHelper`, `intf.XRechnung_3_0`, `intf.XRechnungXmlShim`, `intf.XRechnungValidationHelperJava` | none, see below |

3. **Fix what no longer compiles** with the table [What is gone](#what-is-gone).
4. **Check the string types.** Text fields of the model are `TLandrixEInvoiceString`: `string` on
   Delphi 2009 and later, `WideString` on Delphi 6 to 2007, `UnicodeString` on Free Pascal. On
   Free Pascal declare `_Error` and file names as `TXRechnungString`.
5. **Replace the Java helper** with the native functions ([table](#validation-and-visualization)).
6. **Compare the output.** The tests compare the output with the 111 example files of
   XRechnung-for-Delphi; it differs deliberately in two points: Factur-X EXTENDED writes every
   invoiced object identifier (BT-18), and line groups are written flat where the target has
   none (Peppol BIS, XRechnung CII, Factur-X below EXTENDED, UBL credit notes; see
   [Sub lines](writing.md#sub-lines-line-groups)). Read the [behaviour changes](#behaviour-changes).
7. **Optionally move on to the facade** ([table](#moving-on-to-the-facade)), step by step: `TInvoice` is
   `TLandrixInvoice`, the same object for both.

## What is gone

| Old | New |
|---|---|
| `TXRechnungHelper` (in `intf.XRechnung`): `InvoiceTypeCodeToStr`, `...FromStr` and the other code conversions | `LandrixEInvoiceTypeCodeToStr`, `LandrixEInvoiceTypeCodeFromStr(Code, out Value): Boolean` and the same for every code list in `LandrixEInvoiceCodes`; the line status (`InvoiceLineStatusReasonCode...`) in `LandrixEInvoiceInvoice` |
| `TXRechnungHelper.AmountToStr`, `DateToStrUBLFormat` and the other number and date formats | no public replacement: the library writes the XML formats itself |
| `TXRechnungHelper.ReadPaymentTerms` | none needed: reading fills the payment terms and cash discounts of the model from the `#SKONTO#` text |
| `TXRechnungXMLHelper` (`intf.XRechnungHelper`, MSXML) | none: no MSXML |
| `TXRechnungValidationHelper.GetXRechnungVersion(IXMLDocument)` and other `IXMLDocument` overloads | `GetXRechnungVersion(Stream)`, `GetXRechnungVersionFromString`; for reading streams, files and strings |
| `{$DEFINE ZUGFeRD_Support}`, `TZUGFeRDAdditionalContent`, `_AdditionalContent` | the CII syntax model of the read document (`Doc.CII`, set for CII documents), which holds everything Factur-X EXTENDED has; the invoicee is in the model and logistics charges are read as allowances and charges (BG-21). There is no `TZUGFeRDInvoiceDescriptor`, and ZUGFeRD 1.0, which this switch could read, is not read any more |
| `TXRechnungPdfAttachment.Data` as `TBytes` | a `TMemoryStream` owned by the attachment (the extractor functions still return `TBytes`) |
| `TInvoiceEmptyLeitwegID.NON_EXISTENT` in constant expressions | a class function now; in constants use `LandrixEInvoiceLeitwegIDNonExistent` |
| `TXRechnungInvoiceAdapter.ccOK` and the other `ConsistencyCheck` codes as class members | unit constants (`ccOK`, as in the Delphi 6 version) |
| `GetXRechnungValidationHelperJava` | see the next table |

## Validation and visualization

The Java helper is not needed any more; validation and display run in the program
([Validating and showing invoices](validation.md)).

| Java helper (`intf.XRechnungValidationHelperJava`) | Native |
|---|---|
| `Validate`, `ValidateFile` (KoSIT validator, XML and HTML report) | `TLandrixEInvoiceDocumentValidator` with the KoSIT files of `addons/kosit/install-kosit.ps1`; reports `TLandrixEInvoiceValidationReportWriter` (XML) and `TLandrixEInvoiceValidationHtmlWriter` (HTML) |
| `Visualize`, `VisualizeFile`, `PeppolVisualize`, `PeppolVisualizeFile`, `MustangVisualizeFile` (HTML) | `TLandrixEInvoiceRenderHtmlWriter`, `TLandrixEInvoiceRenderMarkdownWriter`: the library's own layout, English or German |
| `MustangValidateFile` | partly: the PDF check of `TLandrixEInvoiceDocumentValidator` (embedding and XMP metadata); PDF/A is not checked |
| `VisualizeAsPdf`, `VisualizeFileAsPdf`, `MustangVisualizeFileAsPdf`, `MustangCombinePdfAndXML`, `MustangUpgradeToPDFA3Only` | none: the library does not write PDF. It gives the XMP metadata and the attachment name for a PDF library of your choice (`ZUGFeRDPdfXmpInfo`, `ZUGFeRDPdfFilename` of the adapter; `LandrixEInvoicePdfXmpDescription(Target)` and `Spec.AttachmentFileName` in `LandrixEInvoiceSpecs`) |
| `ValitoolValidate`, `ValitoolValidateDirectory` | none |

The configuration methods of the helper (`SetJavaRuntimeEnvironmentPath`, `SetValidatorLibPath` and
so on) go with it. The native units are a preview: documented and tested, but their names may
change before 1.0.

The sample project of XRechnung-for-Delphi (`Samples/XRechnungProject`) is replaced by
[examples/Workbench](../examples/Workbench/Workbench.dpr) (a window, without Java) and
[examples/BusinessCases](../examples/BusinessCases/BusinessCases.dpr) (the business cases of
`XRechnungUnit2TestCases.pas`, written for every target).

## Behaviour changes

Reading and writing:

- `Save` and `Load` take an optional last parameter `_Diagnostics` that receives the messages
  of mapping, reader and writer. In `LoadFromStream` and `LoadFromFile` it follows
  `_ProcessPdfFiles`, so calls that pass diagnostics as fourth argument need `False` in between.
- `Load` returns False when the document cannot be read (not well-formed, unknown format, a PDF
  without invoice, exception), for nil arguments, an empty file name, a missing file and an empty
  XML string; otherwise True with an empty `_Error`. A failed load leaves the invoice unchanged.
  Messages are English; XML errors start with `Not valid XML: ` (from a PDF:
  `Embedded file <name>: Not valid XML: `).
- `Save` writes what the mapping produced, as before; it raises `ELandrixEInvoiceError` for a
  version that cannot be written. It does not check the business rules: use
  `TLandrixEInvoice.Check` or the facade for that.
- On Delphi 6 to 2007, `SaveToXMLStr` returns UTF-8 bytes (as the XML declaration says) and
  `LoadFromXMLStr` takes bytes in the encoding of the declaration. Where `String` is Unicode,
  `LoadFromXMLStr` takes decoded text and does not consult the declaration.
- File names are Unicode where `TXRechnungString` is Unicode (Delphi 2009+, Free Pascal).
- As before, `SaveToFile` writes nothing for a file name without folder.
- `PaymentTermNetNote` no longer contains the `#SKONTO#` lines of a cash discount; they are in
  the payment terms of the model.
- `ConsistencyCheck` returns `ccOK` instead of `ccSubInvoiceLinesNotSupported` (11) for line groups
  in a target that has none: they are written flat, and the diagnostics report each group
  (`edk_NotAllowed`). Code 11 remains for INFORMATION lines on the top level and for DETAIL lines with
  sub lines outside Factur-X EXTENDED.

The model:

- The prices `GrossPriceAmount`, `DiscountOnTheGrossPrice` and `NetPriceAmount` (BT-148, BT-147,
  BT-146) are `Double` instead of `Currency`: code that passes them as `var` parameters or to
  `Currency` routines needs a change.
- `EmbedDataFromText` writes UTF-8 without BOM (was UTF-16LE with BOM on Delphi 2009 and later,
  ANSI on Delphi 6); `EmbedDataFromFile` no longer retries on locked files; invalid Base64 raises
  `ELandrixXmlError`; `TryAddAttachmentByExtension` sets the attachment to nil on failure.
- `ClassName` returns the new names (`TLandrixInvoice`).
- Store enumerations by their code (`LandrixEInvoice...ToStr`), not by their ordinal value: the
  ordinals of the code lists are not stable between versions.

## Moving on to the facade

| Compatibility layer | Facade |
|---|---|
| `TXRechnungInvoiceAdapter.SaveToFile(Inv, XRechnungVersion_30x_UBL, Name)` | `TLandrixEInvoice.SaveToFile(Inv, Name, TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL))` |
| `XRechnungVersion_30x_UNCEFACT` | `TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)` |
| `ZUGFeRDEN16931Version_250` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931)` |
| `ZUGFeRDExtendedVersion_250` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended)` |
| `PeppolBillingVersion_30` | `TLandrixEInvoiceTargets.PeppolBIS('3.0')` |
| `LoadFromFile(Inv, Name, Error)` | `Doc := TLandrixEInvoice.LoadFromFile(Name)` (exceptions instead of `Error`); the invoice is `Doc.Invoice`, `Doc.DetachInvoice` hands it over; free `Doc` (`try ... finally Doc.Free; end`) |
| `GetXRechnungVersion(Name)` | after reading: `if Doc.Info.SpecFound then Target := Doc.Info.Spec.Target` |
| `ConsistencyCheck(Inv, Version, Code)` | `TLandrixEInvoice.Check(Inv, Target) = 0` (all business rules, with diagnostics) |

The facade checks the business rules before writing and refuses an invalid invoice; see
[Writing](writing.md). The compatibility layer writes with `[eio_NoRuleCheck,
eio_WriteDespiteErrors]`; pass these options to keep its tolerance.
