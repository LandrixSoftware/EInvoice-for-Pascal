# Third-party notices

## LandrixXML for Pascal

EInvoice-for-Pascal uses LandrixXML for Pascal by Landrix Software,
included as a Git submodule in `external/landrix-xml`.

Original project:
https://github.com/landrix/LandrixXML-for-Pascal

Licensed under the MIT License.
See [LICENSES/MIT.txt](LICENSES/MIT.txt).

LandrixXML contains material derived from third-party works, listed in its own
[THIRD-PARTY-NOTICES.md](external/landrix-xml/THIRD-PARTY-NOTICES.md): tables from the Unicode
Character Database (Copyright (c) 1991-2022 Unicode, Inc., Unicode License V3,
`external/landrix-xml/LICENSES/Unicode-3.0.txt`), the character classes of XML 1.0 (Fourth
Edition) (Copyright (c) 2006 W3C (MIT, ERCIM, Keio), W3C Document License), case mapping tables
computed with SaxonJ-HE 12.9 (no Saxon code), and in its XML Schema
units the error codes, messages and identity constraint matching of Apache Xerces-J 2.12.2
(Copyright 1999-2022 The Apache Software Foundation, Apache License 2.0, see
[LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt); the Xerces NOTICE text is reproduced in the
LandrixXML notices).

## Code lists

The code lists in `tools/codelists/src/` and the code tables generated from them in
`source/LandrixEInvoiceCodes.pas` are taken from the EN 16931 code list values published by
the European Commission (Registry of supporting artefacts to implement EN 16931,
https://ec.europa.eu/digital-building-blocks/sites/display/DIGITAL/Registry+of+supporting+artefacts+to+implement+EN16931).
Source: European Commission. Reuse of Commission documents is governed by Commission
Decision 2011/833/EU. The lists contain codes maintained by UN/CEFACT (UNTDID, UN/ECE
Recommendations 20 and 21), ISO (ISO 3166-1, ISO 4217, ISO/IEC 6523) and other bodies;
versions and checksums are recorded in `tools/codelists/manifest.json`.

## Factur-X / ZUGFeRD schema

`tools/syntaxmodel/cii.json` and the units generated from it
(`source/LandrixEInvoiceCII.pas`, `LandrixEInvoiceCIIReader.pas`, `LandrixEInvoiceCIIWriter.pas`)
describe the structure (element names, namespaces, order, cardinality, attributes) of the
Factur-X 1.09.2 / ZUGFeRD 2.5.2 EXTENDED XML schema, which is based on the UN/CEFACT Cross
Industry Invoice. Factur-X is published by FNFE-MPE (France) and ZUGFeRD by FeRD (Germany).
The schema files themselves are not part of this repository: `tools/syntaxmodel/extract-xsd.py`
downloads them from the release package validation-configuration-zugferd 2.5.2
(https://github.com/LandrixSoftware/validator-configuration-zugferd, Apache License 2.0 for the
validator configuration) and verifies them against the SHA-256 checksums in
`tools/syntaxmodel/manifest.json`. The schema files in that package are the ones published
with the ZUGFeRD 2.5.2 / Factur-X 1.09.2 release (https://www.ferd-net.de/standards/zugferd,
https://fnfe-mpe.org/factur-x/), under the terms of their publishers.

`tools/syntaxmodel/cii-profiles.json` and the unit generated from it
(`source/LandrixEInvoiceCIIProfiles.pas`) record for each CII path the lowest Factur-X profile
that contains it and the profiles in which it is required. They are derived by
`tools/fieldmap/fieldmap.py --export` from the Factur-X 1.09.2 field table published with the
same release (file `1_FACTUR-X 1.09.2 - EN FR.xlsx`; SHA-256 in `tools/fieldmap/manifest.json`).
The table itself is not part of this repository.

`tools/syntaxmodel/cii-codes.json` and the unit generated from it
(`source/LandrixEInvoiceCIICodeRules.pas`) contain the code checks of the Factur-X 1.09.2
schematron of the five profiles (assert identifiers FX-SCH-A-..., their context paths and the
code lists of the code data bases `FACTUR-X_<profile>_codedb.xml`). They are extracted by
`tools/syntaxmodel/extract-xsd.py` from the same release package validation-configuration-zugferd
2.5.2, which is licensed under the Apache License 2.0; the Factur-X 1.09.2 specification
(`0_FACTUR-X 1.09.2 DE.pdf`, disclaimer on page 13) places the document under the same licence.
See [LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt). The schematron and
code data base files themselves are not part of this repository; their checksums are in
`tools/syntaxmodel/manifest.json`.

## OASIS UBL 2.1 schema and EN 16931 UBL rules

`tools/syntaxmodel/ubl.json` and the units generated from it (`source/LandrixEInvoiceUBL.pas`,
`LandrixEInvoiceUBLReader.pas`, `LandrixEInvoiceUBLWriter.pas`) describe the structure of the
OASIS Universal Business Language (UBL) 2.1 Invoice and CreditNote schema, reduced to the positive
list `tools/syntaxmodel/ubl-positive.json`. UBL 2.1 is an OASIS Standard
(https://docs.oasis-open.org/ubl/UBL-2.1.html). The list was derived with the EN 16931 UBL
syntax rules (UBL-CR) of the CEN validation artefacts. The schema and rule files are not part of
this repository: `tools/syntaxmodel/extract-xsd.py` downloads them from the KoSIT validator
configuration XRechnung 3.0.2 (https://github.com/itplr-kosit/validator-configuration-xrechnung,
release v2026-08-31) and verifies them against the SHA-256 checksums in
`tools/syntaxmodel/manifest.json`. The files remain under the terms of their publishers.
