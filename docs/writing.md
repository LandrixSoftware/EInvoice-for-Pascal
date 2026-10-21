# Writing

[Deutsch](de/writing.md)

`TLandrixEInvoice` (unit `LandrixEInvoice`) writes an invoice for a target:

```pascal
TLandrixEInvoice.SaveToFile(Invoice, 'invoice.xml', Target);
TLandrixEInvoice.SaveToStream(Invoice, Stream, Target);
Bytes := TLandrixEInvoice.SaveToUtf8(Invoice, Target);   // TLandrixXmlUtf8
Text := TLandrixEInvoice.SaveToText(Invoice, Target);    // TLandrixEInvoiceString
```

All of them take two optional parameters: `AOptions: TLandrixEInvoiceOptions = []` and
`ADiagnostics: TLandrixEInvoiceDiagnostics = nil`.

## What happens

1. The target is resolved. An unknown or read-only target raises
   `ELandrixEInvoiceTargetError` before anything is read or written.
2. The business rules of the target are checked (EN 16931, XRechnung, Peppol, Factur-X
   profile rules), see [Checking](checking.md).
3. The invoice is mapped to the syntax model and serialised in memory.
4. With errors, `ELandrixEInvoiceWriteError` is raised and **nothing is written**. The
   exception owns a copy of the messages: `E.Diagnostics`.

Messages that are not errors (content the target cannot hold, a default that was applied) go
to `ADiagnostics` when you pass one.

## Options

| Option | Effect |
|---|---|
| `eio_Strict` | Content the target does not allow (`edk_NotAllowed`) and discouraged content count as errors. |
| `eio_NoRuleCheck` | Skip the business rules; the mapping and its messages still run. |
| `eio_WriteDespiteErrors` | Write even with errors (escape hatch, e.g. to inspect the output). |
| `eio_InvoiceOnly` | Reading: free the syntax model after the mapping. |
| `eio_CheckOnRead` | Reading: check the business rules of the detected specification. |
| `eio_NoPdf` | Reading: never treat the input as PDF. |

## Text and encodings

The XML is always UTF-8 with the declaration `encoding="UTF-8"`. `SaveToText` returns the same
document as UTF-16 text: store it as UTF-8 (`LandrixEInvoiceStringToUtf8`, or use
`SaveToFile` / `SaveToStream`), never through a code page. On Delphi 6 to 2007 the text is a
`WideString`; assigning it to a `string` loses characters outside the system code page.

## UBL Invoice or CreditNote

In UBL a credit note (BT-3 = 381) is written as `CreditNote`, every other invoice as
`Invoice`. CII has one root for both.

## Changing the document before writing

`ToCII`, `ToUBLInvoice` and `ToUBLCreditNote` return the syntax model of an invoice. Change it
and write it with the `SaveTo*` overloads for syntax models:

```pascal
CII := TLandrixEInvoice.ToCII(Invoice, Target);
try
  // e.g. content that only Factur-X EXTENDED has
  TLandrixEInvoice.SaveToFile(CII, 'factur-x.xml', Target);
finally
  CII.Free;
end;
```

A syntax model is checked against the target too: content its Factur-X profile does not
contain, content the schema and the profile require, and that its BT-24 belongs to the target.
The business rules need the semantic model and are not checked for syntax models.

## Totals

The library does not calculate. Line amounts (BT-131), the VAT breakdown (BG-23) and the
document totals (BG-22) come from your program; the check reports the calculation rules
(BR-CO-10 to BR-CO-17) when they do not add up.
