# Reading

[Deutsch](de/reading.md)

```pascal
Doc := TLandrixEInvoice.LoadFromFile('invoice.xml');   // XML or PDF
try
  WriteLn(string(Doc.Invoice.InvoiceNumber));
finally
  Doc.Free;
end;
```

| Method | Input |
|---|---|
| `LoadFromFile(AFileName)` | A file: XML, or a PDF with an embedded invoice (detected by content). |
| `LoadFromStream(AStream)` | Same, from the current position of the stream to its end. |
| `LoadFromUtf8(ABytes)` | XML as UTF-8 bytes. Never a PDF. |
| `LoadFromText(AText)` | XML as decoded UTF-16 text. Never a PDF. |

All take an optional `AOptions: TLandrixEInvoiceOptions = []`. For reading:

| Option | Effect |
|---|---|
| `eio_InvoiceOnly` | Keep only `Invoice`; the syntax model is freed after mapping. |
| `eio_CheckOnRead` | Run the rule check of the detected specification and add its findings to `Diagnostics` (nothing when BT-24 is unknown). |
| `eio_NoPdf` | Treat the input as XML; never look for a PDF. |

## The document

`TLandrixEInvoiceDocument` owns everything it returns; free the document, not its parts.

| Property | Content |
|---|---|
| `Invoice` | The invoice as `TLandrixInvoice`. `DetachInvoice` hands it over to you. |
| `CII`, `UBLInvoice`, `UBLCreditNote` | The syntax model it was read from (one of them; `nil` with `eio_InvoiceOnly`). It keeps content the semantic model does not hold. |
| `Diagnostics` | What reading found: unknown elements, content the model does not hold, unknown codes. |
| `Info` | Root element, syntax, BT-24 and BT-23 as read, the specification, PDF details. |

Invoice and syntax model are independent copies: changing one does not change the other.

## Which specification

The specification is decided by BT-24 (`cbc:CustomizationID`,
`ram:GuidelineSpecifiedDocumentContextParameter/ram:ID`), never by the content.
`Info.SpecFound` is True when the library knows the identifier; `Info.Spec` is the entry
then. An unknown identifier (e.g. XRechnung 2.x, or plain EN 16931 in UBL) is read anyway,
with a warning, and `Info.SpecFound` is False. In CII, plain EN 16931 (`urn:cen.eu:en16931:2017`)
is the identifier of Factur-X EN 16931 and is recognised as such. The ZUGFeRD identifiers `urn:zugferd.de:2p0:...`
that Factur-X accepts are recognised.

## Errors

An exception is raised only when there is no document:

| Exception | Cause |
|---|---|
| `ELandrixEInvoiceFormatError` | Not well-formed XML (with `Line`, `Column`, `Offset`), no invoice root, ZUGFeRD 1.0. |
| `ELandrixEInvoicePdfError` | A PDF without an embedded invoice, or one that cannot be read. |

A missing file raises the usual file exception of the RTL.

## Encoding

`LoadFromFile` and `LoadFromStream` follow the encoding declaration of the XML (UTF-8,
UTF-16, ISO-8859-1 and others). `LoadFromUtf8` and `LoadFromText` do not consult it: the bytes
are UTF-8, the text is already decoded.

On Delphi 6 to 2007, an `AnsiString` holding UTF-8 bytes belongs in `LoadFromUtf8`. Passed to
`LoadFromText`, it is converted through the system code page and non-ASCII characters are
garbled without a message.

## PDF

ZUGFeRD and Factur-X PDFs carry the invoice as an embedded file. `LoadFromFile` and
`LoadFromStream` detect a PDF by its content and read the embedded invoice; `Info.Source` is
`eso_Pdf`, `Info.PdfAttachmentName` the name of the embedded file and `Info.Pdf` the facts of
the extraction. All embedded files (attachments of the invoice too) are available through
`TLandrixEInvoicePdfExtractor` in unit `LandrixEInvoicePdf`.
