# EInvoice for Pascal

A unified electronic invoicing library for Delphi and Free Pascal supporting XRechnung,
ZUGFeRD / Factur-X, Peppol BIS Billing, UBL and CII.

> **Status:** early development. The repository currently contains the project foundation
> (licensing, contribution rules, tooling). The library code is being built; the API is not
> stable yet and there is no release.

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
