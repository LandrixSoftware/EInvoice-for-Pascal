# EInvoice for Pascal

A unified electronic invoicing library for Delphi and Free Pascal supporting XRechnung,
ZUGFeRD / Factur-X, Peppol BIS Billing, UBL and CII.

> **Status:** before release 1.0. Reading, writing and checking work for XRechnung 3.0,
> ZUGFeRD 2.5 / Factur-X 1.09 and Peppol BIS 3.0; the API may still change until 1.0, and
> there is no release yet.

## Goals

- One library for reading and writing electronic invoices according to EN 16931:
  XRechnung (UBL and CII), ZUGFeRD / Factur-X (MINIMUM to EXTENDED) and Peppol BIS Billing.
  MINIMUM and BASIC WL carry no invoice lines; in Germany they do not count as e-invoices
  since 2025, in France they serve as booking aid. The library writes them on request and
  leaves the legal judgement to the application.
- One code base for **Delphi 6 through Delphi 13** and **Free Pascal 3.2.2+**
  (Windows, Linux, macOS).
- Three levels of access:
  - `TLandrixInvoice`: the semantic invoice model (business terms `BT-...` / `BG-...`),
    independent of the syntax. This is the model known as `TInvoice` from
    XRechnung-for-Delphi.
  - `TLandrixCII...` and `TLandrixUBL...`: complete syntax models, generated from the
    schemas, for everything the semantic model does not cover.
- No dependency on MSXML or other XML libraries: XML is handled by
  [LandrixXML for Pascal](https://github.com/LandrixSoftware/LandrixXML-for-Pascal),
  included as a Git submodule.

## Quick start

```pascal
uses
  LandrixEInvoiceTypes, LandrixEInvoiceSpecs, LandrixEInvoiceInvoice, LandrixEInvoice;

// write
TLandrixEInvoice.SaveToFile(Invoice, 'invoice.xml', TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL));

// read XML or a ZUGFeRD / Factur-X PDF
Doc := TLandrixEInvoice.LoadFromFile('invoice.pdf');
try
  WriteLn(string(Doc.Invoice.InvoiceNumber));
finally
  Doc.Free;
end;
```

Writing checks the business rules of the target and refuses an invalid invoice
(`ELandrixEInvoiceWriteError`, nothing written).

## Documentation

- [Getting started](docs/getting-started.md) ([Deutsch](docs/de/getting-started.md)): setup,
  the three models, targets
- [Writing](docs/writing.md), [Reading](docs/reading.md), [Checking](docs/checking.md)
- [Moving from XRechnung-for-Delphi](docs/compat-xrechnung.md)
- [Examples](examples/): console programs for Delphi (`.dpr`) and Lazarus (`.lpi`), including
  the 24 business cases of XRechnung-for-Delphi

## Public API

The facade `TLandrixEInvoice` (unit `LandrixEInvoice`) reads and writes invoices with one call;
the stable units below are covered by semantic versioning from release 1.0 on. Every unit states
its level in a comment before its `unit` line (`API: stable` or `API: internal`), and
`tools/check-forbidden.py` checks that the interface of a stable unit uses no internal unit.

- **Stable:** `LandrixEInvoice` (facade, documents, exceptions), `LandrixEInvoiceTypes`,
  `LandrixEInvoiceInvoice`, `LandrixEInvoiceCodes`, `LandrixEInvoiceDiagnostics`,
  `LandrixEInvoiceSpecs`, `LandrixEInvoiceCII` and `LandrixEInvoiceUBL` (syntax models),
  `LandrixEInvoicePdf`, `LandrixEInvoiceCompatXRechnung`, `LandrixEInvoiceCompatXRechnungAdapter`,
  `LandrixEInvoiceCompatXRechnungPdf`.
- **Internal** (may change in any release): `LandrixEInvoiceMapCII`, `LandrixEInvoiceMapUBL`,
  `LandrixEInvoiceCheck`, `LandrixEInvoiceRules`, `LandrixEInvoiceCalc`, `LandrixEInvoiceLexical`,
  `LandrixEInvoiceFiles`, `LandrixEInvoiceCIIProfiles`, and the readers and writers
  `LandrixEInvoiceCIIReader`, `LandrixEInvoiceCIIWriter`, `LandrixEInvoiceUBLReader`,
  `LandrixEInvoiceUBLWriter`. What they offer is reachable through the facade.

## Getting the sources

```sh
git clone --recurse-submodules https://github.com/LandrixSoftware/EInvoice-for-Pascal.git
```

For an existing clone: `git submodule update --init`.

## Related projects

[XRechnung-for-Delphi](https://github.com/LandrixSoftware/XRechnung-for-Delphi) and
[ZUGFeRD-for-Delphi](https://github.com/LandrixSoftware/ZUGFeRD-for-Delphi) remain available
and maintained. EInvoice-for-Pascal combines their functionality in one library.

## License

EInvoice-for-Pascal is dual-licensed.

You may use the software under either:

- GNU General Public License version 3 or later; or
- the Landrix Software Commercial License.

The commercial license permits integration and distribution
as part of proprietary applications without the copyleft
requirements of the GPL. See [COMMERCIAL-LICENSE.md](COMMERCIAL-LICENSE.md).

Third-party components are listed in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first; it explains
the licensing terms for contributions and the language rules that keep the code compatible
with Delphi 6. Security issues: see [SECURITY.md](SECURITY.md).
