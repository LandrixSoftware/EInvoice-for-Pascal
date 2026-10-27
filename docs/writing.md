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

## Sub lines (line groups)

Sub lines are written nested where the target has them: XRechnung UBL (as `cac:SubInvoiceLine`,
with the extension identifier) and Factur-X / ZUGFeRD EXTENDED (`ParentLineID`). Everywhere else
(XRechnung CII, the Factur-X profiles below EXTENDED, Peppol BIS, a UBL credit note) the invoice is
written **flat**: a group is replaced by its lines, depth-first, so the sum of the lines (BT-106)
stays the same. The group lines themselves (title, subtotal) and INFORMATION sub lines are left
out; each top-level group is reported as a warning (`edk_NotAllowed`, an error with
`eio_Strict`). The rules are checked on the flat invoice, as it is written; your invoice object is
not changed.

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

## Calculating amounts

Writing never changes amounts. Calculate them on request before writing:

```pascal
TLandrixEInvoice.CalculateLineAmounts(Invoice);   // BT-131 of every line
TLandrixEInvoice.CalculateTotals(Invoice);        // BG-23 and BG-22
```

- `CalculateLineAmounts`: quantity x net price / base quantity (0 counts as 1), rounded to cents
  half away from zero, minus line allowances, plus line charges. A group (a line with sub
  lines) gets the sum of its DETAIL and GROUP sub lines. Skip this call if your line amounts
  come from elsewhere.
- `CalculateTotals`: the VAT breakdown grouped by VAT category and rate (the tax of each group
  rounded once on its taxable amount; existing entries keep their exemption reasons, missing
  ones are added, unused ones removed) and the document totals BT-106 to BT-110, BT-112 and
  BT-115.
  BT-111 (tax currency), BT-113 (prepaid) and BT-114 (rounding) stay as you set them; BT-115
  includes third-party payments.

Both overwrite what they calculate, return the number of errors and leave the invoice unchanged
when there is one (e.g. a line without VAT category, a group whose sub lines have different VAT
rates). The check reports the calculation rules (BR-CO-10 to BR-CO-17) when amounts set by your
program do not add up.
