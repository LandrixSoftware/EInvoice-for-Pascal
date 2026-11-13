# Validating and showing invoices

[Deutsch](de/validation.md)

The library checks an invoice in two ways, without Java:

| | What | Unit | Status |
|---|---|---|---|
| Rule check | the business rules on the model, before writing | `TLandrixEInvoice.Check` ([Checking](checking.md)) | stable |
| Document validation | an XML or PDF document as it is, against the official KoSIT configurations (XML schema, Schematron) plus the PDF embedding | `TLandrixEInvoiceDocumentValidator` | preview |

Document validation gives the same verdict as the KoSIT validator (Java), checked against its
reports in the repository's tests. It needs the configuration files and rule files described
below; they are not part of the library.

> **Preview.** Document validation, the reports and the invoice rendering live in units marked
> `API: internal` (`LandrixEInvoiceValidator`, `LandrixEInvoiceValidation`,
> `LandrixEInvoiceValidationReport`, `LandrixEInvoiceValidationHtml`, `LandrixEInvoiceRenderHtml`,
> `LandrixEInvoiceRenderMarkdown`). They work and are tested, but names and signatures may change
> before 1.0. [examples/Workbench](../examples/Workbench/WorkbenchMain.pas) uses all of them.

## Getting the KoSIT files

```powershell
./addons/kosit/install-kosit.ps1                          # XRechnung, Peppol BIS, ZUGFeRD
./addons/kosit/install-kosit.ps1 -Modules xrechnung       # only what you need
./addons/kosit/install-kosit.ps1 -Target C:\MyApp\kosit   # straight into your application
```

The script (Windows PowerShell 5.1 or PowerShell 7 on Windows, Linux, macOS) downloads every file
from its publisher, verifies its SHA-256 (pinned in
[addons/kosit/kosit.json](../addons/kosit/kosit.json)) and writes one folder:

| Folder | Content | Module |
|---|---|---|
| `validator-configuration-xrechnung/` | KoSIT configuration XRechnung 3.0.2, release 2026-08-31 | `xrechnung` |
| `validator-configuration-bis/` | KoSIT configuration Peppol BIS Billing 3.0.21 | `bis` |
| `validator-configuration-zugferd/` | ZUGFeRD 2.5.2 / Factur-X 1.09.2 configuration, 2026-10-15, with its Schematron sources | `zugferd` |
| `rules/en16931-ubl.xml`, `en16931-cii.xml`, `xrechnung-ubl.xml`, `xrechnung-cii.xml` | the EN 16931 and XRechnung Schematron, compiled by LandrixXML (copied from the submodule or downloaded from the LandrixXML release) | `xrechnung`, `bis` (UBL only) |
| `rules/PEPPOL-EN16931-UBL.sch` | the Peppol Schematron (OpenPEPPOL, May 2026 release 3.0.21) | `bis` |
| `rules/NOTICE.md` | sources and licences of the four rule files (the notice of the LandrixXML folder they come from; its other sections do not apply here) | `xrechnung`, `bis` |

Why rule files: the KoSIT configurations contain the Schematron as XSLT, which the library does
not run. Each XSLT step of a configuration is mapped to a rule file with the same rules (see
below); the ZUGFeRD configuration ships the Schematron sources itself, which the library compiles
when it loads them.

Without PowerShell: download the three archives and the Peppol file from the URLs in
`kosit.json`, unpack each archive into its folder and copy the four rule files and `NOTICE.md`
from `external/landrix-xml/tests/data/schematron/` (rule files under `rules/`) into `rules/`.

## Validating

```pascal
uses
  SysUtils, LandrixEInvoiceDiagnostics, LandrixEInvoiceValidator, LandrixEInvoiceValidation;

{ the XRechnung and Peppol BIS configurations: XSLT step -> rule file }
procedure MapRules(V: TLandrixEInvoiceValidator; const ARules: string);
begin
  V.RuleFiles.Values['EN16931-UBL-validation.xsl'] := ARules + 'en16931-ubl.xml';
  V.RuleFiles.Values['EN16931-CII-validation.xsl'] := ARules + 'en16931-cii.xml';
  V.RuleFiles.Values['XRechnung-UBL-validation.xsl'] := ARules + 'xrechnung-ubl.xml';
  V.RuleFiles.Values['XRechnung-CII-validation.xsl'] := ARules + 'xrechnung-cii.xml';
  V.RuleFiles.Values['CEN-EN16931-UBL.xslt'] := ARules + 'en16931-ubl.xml';
  V.RuleFiles.Values['PEPPOL-EN16931-UBL.xslt'] := ARules + 'PEPPOL-EN16931-UBL.sch';
end;

{ the ZUGFeRD configuration: Schema/Factur-X-1.09.2_<profile>.xslt -> the .sch of that profile }
procedure MapZUGFeRD(V: TLandrixEInvoiceValidator; const AConfig: string);
const
  Profiles: array[0..4, 0..1] of string = (
    ('MINIMUM', '0_Factur-X_1.09.2_MINIMUM/FACTUR-X_MINIMUM.sch'),
    ('BASICWL', '1_Factur-X_1.09.2_BASICWL/FACTUR-X_BASIC-WL.sch'),
    ('BASIC', '2_Factur-X_1.09.2_BASIC/FACTUR-X_BASIC.sch'),
    ('EN16931', '3_Factur-X_1.09.2_EN16931/FACTUR-X_EN16931.sch'),
    ('EXTENDED', '4_Factur-X_1.09.2_EXTENDED/FACTUR-X_EXTENDED.sch'));
var
  I: Integer;
begin
  for I := 0 to 4 do
    V.RuleFiles.Values['Factur-X-1.09.2_' + Profiles[I, 0] + '.xslt'] :=
      AConfig + 'Schema/factur-x-1.09.2/' + Profiles[I, 1];
end;

var
  Kosit: string;
  XRechnung, Peppol, ZUGFeRD: TLandrixEInvoiceValidator;
  Validator: TLandrixEInvoiceDocumentValidator;
  Res: TLandrixEInvoiceDocumentValidation;
  I: Integer;
begin
  Kosit := 'C:/MyApp/kosit/';                  { the folder install-kosit.ps1 wrote }
  XRechnung := TLandrixEInvoiceValidator.Create;
  Peppol := TLandrixEInvoiceValidator.Create;
  ZUGFeRD := TLandrixEInvoiceValidator.Create;
  Validator := TLandrixEInvoiceDocumentValidator.Create;
  Res := TLandrixEInvoiceDocumentValidation.Create;
  try
    XRechnung.LoadConfiguration(Kosit + 'validator-configuration-xrechnung/scenarios.xml');
    MapRules(XRechnung, Kosit + 'rules/');
    Peppol.LoadConfiguration(Kosit + 'validator-configuration-bis/scenarios.xml');
    MapRules(Peppol, Kosit + 'rules/');
    ZUGFeRD.LoadConfiguration(Kosit + 'validator-configuration-zugferd/scenarios.xml');
    MapZUGFeRD(ZUGFeRD, Kosit + 'validator-configuration-zugferd/');

    { the configuration whose scenarios match the document runs }
    Validator.Options.AddConfiguration(XRechnung, eck_XRechnung);
    Validator.Options.AddConfiguration(Peppol, eck_PeppolBIS);
    Validator.Options.AddConfiguration(ZUGFeRD, eck_ZUGFeRD);

    case Validator.ValidateFile('invoice.xml', Res) of    { XML or ZUGFeRD / Factur-X PDF }
      ev_Accepted: WriteLn('accepted (', string(Res.ScenarioName), ')');
      ev_Rejected: WriteLn('rejected');
      ev_Incomplete: WriteLn('no verdict: no configuration registered');
    end;
    for I := 0 to Res.FindingCount - 1 do
      if not Res[I].Predicted then
        WriteLn(string(Res[I].RuleID), ': ', string(Res[I].Text));
  finally
    Res.Free;
    Validator.Free;
    ZUGFeRD.Free;
    Peppol.Free;
    XRechnung.Free;
  end;
end.
```

- `LoadConfiguration` reads `scenarios.xml` and resolves the XML schemas against its folder.
  `RuleFiles` maps the file name of an XSLT step (without folder) to a rule file; a value ending
  in `.sch` is compiled from ISO Schematron when it is loaded (the Factur-X `.sch` files need
  their `*_codedb.xml` next to them, as the configuration ships them). Fill `RuleFiles` before
  the first validation.
- Schemas and rules are loaded on first use and kept: the first document of a configuration
  takes a few seconds, the next ones milliseconds. Keep the validators for the lifetime of your
  application.
- A missing rule file or a schema that does not load raises `ELandrixEInvoiceError`: a problem of
  the setup, not of the document. A configuration this library cannot run (another
  `acceptMatch`, a scenario without a match expression) is refused by `LoadConfiguration`.
- The validators belong to you: free them after the document validator, never while they are
  registered.
- Choice: a configuration is a candidate when exactly one of its scenarios matches the document
  (with two or more it is skipped); among several candidates ZUGFeRD wins over Peppol BIS, Peppol
  BIS over XRechnung (a Factur-X EN 16931 CII document matches both ZUGFeRD and XRechnung). A
  document no registered configuration takes is rejected, as the KoSIT validator rejects a document
  without scenario (`Res.ConfigurationChoice = ecc_NoMatch`). `Options.Configuration := XRechnung`
  forces one configuration. `Res.ConfigurationChoice` and `Res.CandidateCount` tell how it was
  chosen.
- The sample writes paths with `/`, which Windows accepts too; on Linux and macOS the names are
  case-sensitive, as the script writes them.
- Register only the configurations you installed: `LoadConfiguration` raises for a missing
  `scenarios.xml`.
- `ValidateStream` takes the bytes from a stream, for example an invoice from a database.

## The result

| `Res.Verdict` | Meaning |
|---|---|
| `ev_Accepted` | the KoSIT run accepts the document (for a PDF also the embedding and the XMP metadata) |
| `ev_Rejected` | the KoSIT run rejects it (also XML that is not well-formed), or no registered configuration takes it, or a PDF fails the embedding or metadata check |
| `ev_Incomplete` | no configuration is registered (for a PDF: also when the embedding or metadata check, levels 2 and 3, could not be completed): there is no verdict, even if the rule check finds nothing |

- `Res.Status[Part]` per part: `evp_Read` (reading through the facade), `evp_KoSIT`,
  `evp_ModelCheck` (the library's own rules), `evp_PdfEmbedding` and `evp_PdfMetadata` (PDF
  levels 2 and 3), `evp_PdfA` (PDF/A, level 1: not checked).
- `Res.Findings[I]`: `RuleID`, `Severity`, `Text`, `Location`, `Line`, `Column`, `Part`. Findings of
  the library's own rules are marked `Predicted`: they predict what KoSIT reports and never change
  the verdict. PDF findings have the identifiers BR-HYBRID-... (ZUGFeRD) and LX-PDF-01 to LX-PDF-11
  (own checks).
- Peppol BIS: the configuration has no `acceptMatch`, so every failed assert rejects, a warning
  too. This is how the KoSIT validator decides; its HTML report shows the assessment of its
  stylesheet instead, which rejects on errors only (the repository's `tools/validate.ps1` uses
  that assessment).

Reports:

```pascal
uses LandrixEInvoiceReportHtml, LandrixEInvoiceValidationReport, LandrixEInvoiceValidationHtml;

with TLandrixEInvoiceValidationReportWriter.Create do      { XML, own versioned format }
try
  DocumentName := 'invoice.xml';
  SaveToFile(Res, 'report.xml');
finally
  Free;
end;
with TLandrixEInvoiceValidationHtmlWriter.Create do        { one HTML file, no scripts }
try
  Language := eln_German;
  DocumentName := 'invoice.xml';
  SaveToFile(Res, 'report.html');
finally
  Free;
end;
```

## Showing the invoice

`TLandrixEInvoiceRenderHtmlWriter` writes an invoice as one HTML page, `TLandrixEInvoiceRenderMarkdownWriter`
as CommonMark text (for logs, tickets, mails). Both show every field of the model, empty groups
left out, in English or German, optionally with the business terms (BT-...). They take the
`TLandrixInvoice` or the read `TLandrixEInvoiceDocument` (then with the reading messages).

```pascal
uses LandrixEInvoiceReportHtml, LandrixEInvoiceRenderHtml, LandrixEInvoiceRenderMarkdown;

Html := TLandrixEInvoiceRenderHtmlWriter.Create;
try
  Html.Language := eln_German;
  Html.ShowBusinessTerms := True;
  Html.SaveToFile(Doc, 'invoice.html');      { or Html.WriteToString(Invoice) }
finally
  Html.Free;
end;
```

This replaces the KoSIT visualization (XSLT, Java). A PDF of the invoice is not produced.

## What to ship

| Feature | Needs at run time |
|---|---|
| Reading, writing, rule check, calculation, PDF extraction, PDF check, reports, rendering | nothing: everything is compiled into the program (code lists and rule tables are Pascal units); no DLL, no MSXML, no Java, no data files |
| Document validation with KoSIT | the folder of `install-kosit.ps1` (only the modules you use; the `.installed` markers may be left out), at a path your program passes to `LoadConfiguration` |

On Unix, programs add `cwstring` to their uses clause as usual; the library itself does not need
it.

Licences to ship with an application:

- this library under the GPL-3.0-or-later or the Landrix Software Commercial License (see
  [README](../README.md#license)), with [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md), the texts in
  [LICENSES/](../LICENSES/) and the notices of LandrixXML
  (`external/landrix-xml/THIRD-PARTY-NOTICES.md`);
- when you ship the KoSIT folder, the terms of its contents, which the commercial licence does
  not cover: the KoSIT configurations and the XRechnung Schematron (Apache-2.0, KoSIT), the EN 16931
  validation artefacts and the rule files compiled from them (EUPL-1.2, CEN/TC 434; see
  `rules/NOTICE.md`), the ZUGFeRD configuration (Apache-2.0; its schemas and Schematron under the
  terms of FeRD and FNFE-MPE), the Peppol Schematron (OpenPEPPOL; the file carries only a CEN
  reproduction notice and no licence grant: check OpenPEPPOL's terms before you redistribute it), the UBL schemas (OASIS) and the
  CII schemas (UN/CEFACT).
