# Moving from XRechnung-for-Delphi

[Deutsch](de/compat-xrechnung.md)

Code written for XRechnung-for-Delphi compiles against this library when the uses clause
changes:

| Old unit | New unit |
|---|---|
| `intf.Invoice` (Delphi 6: `intfInvoice`) | `LandrixEInvoiceCompatXRechnung` |
| `intf.XRechnung` (Delphi 6: `intfXRechnung`) | `LandrixEInvoiceCompatXRechnungAdapter` |
| `intf.XRechnungPdfExtract` | `LandrixEInvoiceCompatXRechnungPdf` (or `LandrixEInvoicePdf`) |

`TInvoice` is `TLandrixInvoice`, so the invoice model is the same object either way and you can
move to the facade `TLandrixEInvoice` step by step. See
[examples/CompatXRechnung](../examples/CompatXRechnung/CompatXRechnung.dpr).

The 111 example files of XRechnung-for-Delphi are produced with the same content (two
deliberate differences: Factur-X EXTENDED writes every invoiced object identifier, BT-18, and
Peppol BIS writes line groups flat instead of as `cac:SubInvoiceLine`, see
[Writing](writing.md)).
The business cases are in [examples/BusinessCases](../examples/BusinessCases/BusinessCases.dpr).

## Differences

- `Save` and `Load` take an optional last parameter `_Diagnostics` that receives the messages
  of mapping, reader and writer. In `LoadFromStream` and `LoadFromFile` it follows
  `_ProcessPdfFiles`, so calls that pass diagnostics as fourth argument need `False` in between.
- `Load` returns False only when the document cannot be read (not well-formed, unknown
  format, exception); otherwise True with an empty `_Error`.
- `Save` writes what the mapping produced, as before; it raises `ELandrixEInvoiceError` for a
  version that cannot be written. It does not check the business rules: use
  `TLandrixEInvoice.Check` or the facade for that.
- The `ConsistencyCheck` codes (`ccOK` ...) are unit constants, as in the Delphi 6 version;
  `TXRechnungInvoiceAdapter.ccOK` does not compile.
- On Delphi 6 to 2007, `SaveToXMLStr` returns UTF-8 bytes (as the XML declaration says) and
  `LoadFromXMLStr` takes bytes in the encoding of the declaration. Where `String` is Unicode,
  `LoadFromXMLStr` takes decoded text and does not consult the declaration.
- File names are Unicode where `TXRechnungString` is Unicode (Delphi 2009+, Free Pascal).
  On Free Pascal `TXRechnungString` is `UnicodeString`: declare `_Error` and file names with
  that type.
- No `IXMLDocument` overloads and no Java validation; messages are English.
- As before, `SaveToFile` writes nothing for a file name without folder.

## Moving on to the facade

| Compatibility layer | Facade |
|---|---|
| `TXRechnungInvoiceAdapter.SaveToFile(Inv, XRechnungVersion_30x_UBL, Name)` | `TLandrixEInvoice.SaveToFile(Inv, Name, TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL))` |
| `XRechnungVersion_30x_UNCEFACT` | `TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)` |
| `ZUGFeRDEN16931Version_250` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931)` |
| `ZUGFeRDExtendedVersion_250` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended)` |
| `PeppolBillingVersion_30` | `TLandrixEInvoiceTargets.PeppolBIS('3.0')` |
| `LoadFromFile(Inv, Name, Error)` | `Doc := TLandrixEInvoice.LoadFromFile(Name)` (exceptions instead of `Error`) |
| `GetXRechnungVersion(Name)` | `Doc.Info.Spec.Target` after reading |
| `ConsistencyCheck(Inv, Version)` | `TLandrixEInvoice.Check(Inv, Target)` (all business rules) |

The facade checks the business rules before writing and refuses an invalid invoice; see
[Writing](writing.md).
