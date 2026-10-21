# Contributing to EInvoice-for-Pascal

Thank you for your interest in contributing to **EInvoice-for-Pascal**.

Bug reports, test cases, documentation improvements and pull requests are welcome.
Please read the following guidelines before submitting code.

By submitting a pull request or other contribution, you agree to the contribution licensing terms described below.

## Project scope

EInvoice-for-Pascal is a Pascal library for reading, writing and processing electronic invoices, including:

* XRechnung
* ZUGFeRD / Factur-X
* Peppol BIS Billing
* UBL and CII invoice documents
* embedded invoice data in PDF files

The library supports Delphi 6 through Delphi 13 and Free Pascal 3.2.2 and later from one code base.

## Before submitting a pull request

Please:

1. Keep changes focused on a single issue or feature where possible.
2. Avoid unrelated formatting or whitespace changes.
3. Follow the style of the surrounding source code.
4. Add or update tests for functional changes.
5. Make sure existing tests still pass.
6. Run `python tools/check-forbidden.py` and fix every reported violation, and `python tools/codelists/gen-codelists.py --check` (generated code lists up to date).
7. Clearly describe what was changed and why.

Changes affecting generated invoice XML should, where applicable, be tested against the official or commonly used validation tools for the respective invoice format (for example the KoSIT validator for XRechnung).

Generated units (syntax models, code lists) must not be edited by hand. Change the generator or its input under `tools/` and regenerate.

## Compatibility

All library code must compile unchanged with Delphi 6 through Delphi 13 and Free Pascal 3.2.2+. The language subset is the same as in [LandrixXML for Pascal](https://github.com/LandrixSoftware/LandrixXML-for-Pascal):

* Units: only `SysUtils`, `Classes`, `Contnrs`, `Types` (Delphi only; Delphi 13 needs it for `TList.TDirection`), LandrixXml units and own units. Unqualified unit names; unit names contain no dot.
* Not allowed: generics, anonymous methods, `for ... in`, `Exit(Value)`, `strict private/protected`, records with methods, class and record helpers, operator overloading, `inline`, `class var`, nested types, inline `var` declarations, `{$REGION}`.
* Old-style `object` types are allowed only as value types without a VMT (no constructors, destructors, virtual, dynamic, abstract or override methods), as used by the optional value types `TLandrixEInvoiceAmount` etc.: zeroed memory must mean "not set". Such a type must not be exactly 8 bytes in size: Delphi 13 Win64 passes 8-byte objects wrongly as value or `const` parameters (records are not affected).
* Not allowed: `TStringBuilder`, `TEncoding`, `TFormatSettings`, `PosEx`, `CharInSet`, `RawByteString`, `NativeInt`, `NativeUInt`, `TBytes`, `UInt64`, `UTF8ToString`.
* `{$IF}` is always closed with `{$IFEND}`; `CompilerVersion` comparisons use float constants (`20.0`).
* No dependency on the current locale. Numbers and dates are converted with the locale-independent helpers.
* Source files contain only ASCII characters; use `#$xx` constants for other characters.

`tools/check-forbidden.py` checks these rules.

Where differences between Delphi and Free Pascal are required, use conditional compilation in the central include file and keep the common implementation shared.

Changes that intentionally break the public API should be discussed before implementation.

## File headers

Every new source file starts with this header:

```pascal
{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}
```

A library unit in `source/` also states its API level in a comment directly before its `unit` line, `{ API: stable. ...}` or `{ API: internal. ...}` (English, then `DE:`); the interface section of a stable unit may use only stable units of this library. `tools/check-forbidden.py` checks both; the README lists the units per level. Generated units get the comment from their generator.

Files that contain code derived from other projects need a different header and an entry in `THIRD-PARTY-NOTICES.md`; see **Third-party code** below.

## Comments and documentation

Code is written in English: identifiers, test messages and purely technical comments.

The code is documented directly in the source, in English and German:

* In the library sources (`source/`), every public declaration in an `interface` section and every business rule in an implementation (business terms `BT-...`/`BG-...`, profile rules, special cases) has a comment block: first English, then a paragraph starting with `DE:` in German.
* Purely technical comments inside implementations are English only, and so are tests and tools.
* Self-explanatory code needs no comment.
* Sources stay ASCII-only, so German umlauts are written as `ae`, `oe`, `ue` and `ss`.

```pascal
{ Optional monetary amount (Currency, four decimals).
  DE: Optionaler Geldbetrag (Currency, vier Nachkommastellen). }
```

New public APIs should contain enough documentation to make their intended use and any relevant invoice-standard restrictions understandable.

Where practical, references to EN 16931 business terms or groups such as `BT-...` and `BG-...` are encouraged.

## Licensing of the project

EInvoice-for-Pascal is dual-licensed.

Users may use the project under either:

1. the **GNU General Public License version 3 or later (GPL-3.0-or-later)**; or
2. the **Landrix Software Commercial License**.

The commercial license allows the library to be used as part of proprietary applications without the copyleft requirements of the GPL.

## Licensing of contributions

To preserve this dual-licensing model, contributions must be available for use under both licensing options.

By intentionally submitting a contribution for inclusion in EInvoice-for-Pascal, you agree to the following terms:

You retain the copyright in your contribution.

You grant **Landrix Software GmbH & Co. KG** a perpetual, worldwide, non-exclusive, irrevocable, royalty-free license to:

* use,
* reproduce,
* modify,
* prepare derivative works of,
* publicly display,
* publicly perform,
* distribute,
* sublicense, and
* otherwise incorporate

your contribution, in source or binary form, as part of EInvoice-for-Pascal and related versions of the project.

This license includes the explicit right to distribute and sublicense your contribution:

* under the GNU General Public License version 3 or any later version;
* under the Landrix Software Commercial License; and
* as part of commercial or proprietary distributions of EInvoice-for-Pascal offered by Landrix Software.

This grant does **not** transfer ownership of your copyright to Landrix Software.

## Patent license

Where you own or control patent claims that would necessarily be infringed by your contribution alone or by its combination with the project as submitted, you grant Landrix Software and recipients of the contribution a perpetual, worldwide, non-exclusive, royalty-free patent license to make, use, offer for sale, sell, import and otherwise use the contribution as part of the project.

This patent grant applies only to patent claims that you have the right to license.

## Your authority to contribute

By submitting a contribution, you represent that:

* you created the contribution yourself or otherwise have the legal right to submit it under these terms;
* the contribution does not knowingly include code or other material that you are not authorized to provide;
* you have the authority to grant the rights described above.

If your contribution was created as part of your employment or on behalf of a company or other organization, you are responsible for ensuring that you are authorized to submit it under these terms.

Please do not submit code copied from another project unless its license is compatible with this project and its origin and license are clearly identified.

## Third-party code

If a contribution contains or is derived from third-party code, please state this clearly in the pull request and provide:

* the original project or source;
* the copyright holder, where known;
* the applicable license;
* a link to the original source where possible.

Do not submit GPL-only third-party code if Landrix Software would not also have the right to include that code in the commercially licensed version of the project.

Permissively licensed code, such as code under the MIT, BSD or Apache License 2.0, may be acceptable, but applicable attribution and redistribution requirements must be preserved.

## Test data

Never submit real invoices or files containing personal data, bank details or credentials. Test files must use synthetic data and be redistributable.

## Automated or AI-assisted contributions

Code created with automated development tools or generative AI may be submitted, but the contributor remains responsible for the contribution.

In particular, you must ensure that:

* you have the right to submit the resulting code;
* no incompatible third-party code has been reproduced;
* the contribution has been reviewed and tested;
* the contribution complies with the licensing terms above.

Automated generation does not remove the contributor's responsibility for correctness, security or licensing.

## Pull request acceptance

Submission of a pull request does not guarantee that it will be merged.

Landrix Software may request changes, additional tests or documentation before accepting a contribution.

Once a contribution has been accepted into the project, the rights granted under the **Licensing of contributions** section are irrevocable.

## Questions

If you are unsure whether a contribution can be submitted under these terms, please open an issue before submitting the code or contact:

**Landrix Software GmbH & Co. KG**
[info@landrix.de](mailto:info@landrix.de)
