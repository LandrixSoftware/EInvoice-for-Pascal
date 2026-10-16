# Third-party notices

## LandrixXML for Pascal

EInvoice-for-Pascal uses LandrixXML for Pascal by Landrix Software,
included as a Git submodule in `external/landrix-xml`.

Original project:
https://github.com/LandrixSoftware/LandrixXML-for-Pascal

Licensed under the MIT License.
See [LICENSES/MIT.txt](LICENSES/MIT.txt).

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
