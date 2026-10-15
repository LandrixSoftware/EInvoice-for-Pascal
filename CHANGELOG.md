# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Supported invoice standards are documented per release.

## [Unreleased]

### Added
- Project foundation: dual licensing (GPL-3.0-or-later or Landrix Software Commercial
  License), third-party notices, contribution rules, security policy.
- LandrixXML for Pascal as Git submodule in `external/landrix-xml`, pinned to
  release 0.2.0.
- `tools/check-forbidden.py`: checks sources for language features and units that
  Delphi 6 does not support. `cwstring` is allowed in programs (`.dpr`/`.lpr`) only.
- `LandrixEInvoice.inc` with the central compiler switches (`LANDRIXEINVOICE_UNICODE`).
- `LandrixEInvoiceTypes`: `TLandrixEInvoiceString` (`WideString` on Delphi 6-2007,
  `string` on Delphi 2009+ and Free Pascal), `TLandrixEInvoiceChar`,
  `LandrixEInvoiceStringToUtf8`, `LandrixEInvoiceUtf8ToString`, `LandrixEInvoiceVersion`.
- Framework-free console test runner `tests/LandrixEInvoiceTests.dpr`.
- `tools/build.ps1`: builds and runs the tests with the local toolchains.
- CI with Free Pascal 3.2.2 on Linux (manual start only for now).
