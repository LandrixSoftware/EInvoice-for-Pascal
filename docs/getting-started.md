# Getting started

[Deutsch](de/getting-started.md)

EInvoice for Pascal reads, writes and checks electronic invoices: XRechnung, ZUGFeRD /
Factur-X and Peppol BIS Billing, in both syntaxes (UBL and UN/CEFACT CII). One code base
compiles with Delphi 6 through Delphi 13 and Free Pascal 3.2.2 or later.

## Setup

1. Get the sources with the LandrixXML submodule:

   ```
   git clone --recurse-submodules https://github.com/LandrixSoftware/EInvoice-for-Pascal.git
   ```

   In an existing clone: `git submodule update --init`.

2. Add two folders to the search path of your project:

   - `source`
   - `external/landrix-xml/source`

   Delphi: *Project > Options > Delphi Compiler > Search path*. Lazarus: *Project > Project
   Options > Compiler Options > Paths > Other unit files*.

3. Free Pascal: compile in Delphi mode (`{$MODE DELPHI}` in the program, or `-Mdelphi`). On
   Unix, add `cwstring` as the first unit of the program if it prints or handles file names
   with non-ASCII characters; the library itself does not need it.

## The three models

| Model | Units | Use it for |
|---|---|---|
| `TLandrixInvoice` | `LandrixEInvoiceInvoice` | The invoice as EN 16931 describes it: one model for every format. This is what you fill and read. |
| `TLandrixCII...` | `LandrixEInvoiceCII` | The CII document element by element, including everything Factur-X EXTENDED has. |
| `TLandrixUBL...` | `LandrixEInvoiceUBL` | The UBL document element by element. |

Most programs only need `TLandrixInvoice` and the facade `TLandrixEInvoice`
(unit `LandrixEInvoice`). The syntax models are there when you need content the semantic
model does not hold.

## Targets

A target names what to write: standard, syntax, profile and version.

```pascal
TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)
TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)
TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931)    // also epr_Minimum ... epr_Extended
TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended)
TLandrixEInvoiceTargets.PeppolBIS('3.0')
```

The version may carry a patch level (`'3.0.2'`); only major and minor count.

## A first invoice

```pascal
uses
  LandrixEInvoiceTypes, LandrixEInvoiceCodes, LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice, LandrixEInvoice;

var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Invoice.InvoiceNumber := 'RE-2026-0001';
    Invoice.InvoiceIssueDate := EncodeDate(2026, 10, 21);
    Invoice.InvoiceTypeCode := itc_CommercialInvoice;
    Invoice.InvoiceCurrencyCode := 'EUR';
    // ... seller, buyer, lines, VAT breakdown, totals, payment
    TLandrixEInvoice.SaveToFile(Invoice, 'invoice.xml',
      TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL));
  finally
    Invoice.Free;
  end;
end;
```

The complete program is [examples/WriteXRechnung](../examples/WriteXRechnung/WriteXRechnung.dpr).
Line amounts, the VAT breakdown and the totals are calculated on request
(`CalculateLineAmounts`, `CalculateTotals`, see [Writing](writing.md#calculating-amounts));
writing itself never changes amounts.

## Examples

Every example is a console program with a `.dpr` for Delphi and an `.lpi` for Lazarus. They
build on each other: run WriteXRechnung first, the others read its output.

| Example | Shows |
|---|---|
| [WriteXRechnung](../examples/WriteXRechnung/WriteXRechnung.dpr) | Filling an invoice and writing XRechnung UBL and CII |
| [ReadInvoice](../examples/ReadInvoice/ReadInvoice.dpr) | Reading XML or PDF, the document info, the messages |
| [CheckInvoice](../examples/CheckInvoice/CheckInvoice.dpr) | Checking the business rules, strict mode, refused writes |
| [ConvertCIIToUBL](../examples/ConvertCIIToUBL/ConvertCIIToUBL.dpr) | Converting between the syntaxes |
| [CompatXRechnung](../examples/CompatXRechnung/CompatXRechnung.dpr) | Code written for XRechnung-for-Delphi |
| [BusinessCases](../examples/BusinessCases/BusinessCases.dpr) | 24 business cases for every target they fit (111 files) |

## Further reading

- [Writing](writing.md)
- [Reading](reading.md)
- [Checking](checking.md)
- [Moving from XRechnung-for-Delphi](compat-xrechnung.md)
- [Public API](../README.md#public-api): which units are stable
