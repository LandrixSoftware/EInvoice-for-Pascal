# Rechnungen validieren und anzeigen

[English](../validation.md)

Die Bibliothek prüft eine Rechnung auf zwei Arten, ohne Java:

| | Was | Unit | Status |
|---|---|---|---|
| Regelprüfung | die Geschäftsregeln am Modell, vor dem Schreiben | `TLandrixEInvoice.Check` ([Prüfen](checking.md)) | stabil |
| Dokumentvalidierung | ein XML- oder PDF-Dokument, wie es ist, gegen die offiziellen KoSIT-Konfigurationen (XML-Schema, Schematron) samt PDF-Einbettung | `TLandrixEInvoiceDocumentValidator` | Vorschau |

Die Dokumentvalidierung kommt zum selben Urteil wie der KoSIT-Validator (Java); die Tests des
Repositorys vergleichen sie mit dessen Berichten. Sie braucht die unten beschriebenen
Konfigurations- und Regeldateien; diese gehören nicht zur Bibliothek.

> **Vorschau.** Dokumentvalidierung, Berichte und Darstellung der Rechnung liegen in Units mit
> der Markierung `API: internal` (`LandrixEInvoiceValidator`, `LandrixEInvoiceValidation`,
> `LandrixEInvoiceValidationReport`, `LandrixEInvoiceValidationHtml`, `LandrixEInvoiceRenderHtml`,
> `LandrixEInvoiceRenderMarkdown`). Sie funktionieren und sind getestet, Namen und Signaturen können
> sich aber bis 1.0 noch ändern. [examples/Workbench](../../examples/Workbench/WorkbenchMain.pas) nutzt
> sie alle.

## Die KoSIT-Dateien besorgen

```powershell
./addons/kosit/install-kosit.ps1                          # XRechnung, Peppol BIS, ZUGFeRD
./addons/kosit/install-kosit.ps1 -Modules xrechnung       # nur, was gebraucht wird
./addons/kosit/install-kosit.ps1 -Target C:\MyApp\kosit   # direkt in die eigene Anwendung
```

Das Skript (Windows PowerShell 5.1 oder PowerShell 7 unter Windows, Linux, macOS) lädt jede Datei
beim Herausgeber, prüft ihre SHA-256 (festgeschrieben in
[addons/kosit/kosit.json](../../addons/kosit/kosit.json)) und schreibt einen Ordner:

| Ordner | Inhalt | Modul |
|---|---|---|
| `validator-configuration-xrechnung/` | KoSIT-Konfiguration XRechnung 3.0.2, Stand 2026-08-31 | `xrechnung` |
| `validator-configuration-bis/` | KoSIT-Konfiguration Peppol BIS Billing 3.0.21 | `bis` |
| `validator-configuration-zugferd/` | Konfiguration ZUGFeRD 2.5.2 / Factur-X 1.09.2, Stand 2026-10-15, mit ihren Schematron-Quellen | `zugferd` |
| `rules/en16931-ubl.xml`, `en16931-cii.xml`, `xrechnung-ubl.xml`, `xrechnung-cii.xml` | die Schematron von EN 16931 und XRechnung, von LandrixXML übersetzt (aus dem Submodul kopiert oder vom LandrixXML-Release geladen) | `xrechnung`, `bis` (nur UBL) |
| `rules/PEPPOL-EN16931-UBL.sch` | die Peppol-Schematron (OpenPEPPOL, Mai-2026-Release 3.0.21) | `bis` |
| `rules/NOTICE.md` | Herkunft und Lizenzen der vier Regeldateien (der Hinweis des LandrixXML-Ordners, aus dem sie kommen; seine übrigen Abschnitte gelten hier nicht) | `xrechnung`, `bis` |

Warum Regeldateien: Die KoSIT-Konfigurationen enthalten die Schematron als XSLT, das die
Bibliothek nicht ausführt. Jeder XSLT-Schritt einer Konfiguration wird einer Regeldatei mit
denselben Regeln zugeordnet (siehe unten); die ZUGFeRD-Konfiguration bringt die
Schematron-Quellen selbst mit, die Bibliothek übersetzt sie beim Laden.

Ohne PowerShell: die drei Archive und die Peppol-Datei von den URLs in `kosit.json` laden, jedes
Archiv in seinen Ordner entpacken und die vier Regeldateien und `NOTICE.md` aus
`external/landrix-xml/tests/data/schematron/` (Regeldateien unter `rules/`) nach `rules/` kopieren.

## Validieren

```pascal
uses
  SysUtils, LandrixEInvoiceDiagnostics, LandrixEInvoiceValidator, LandrixEInvoiceValidation;

{ die Konfigurationen XRechnung und Peppol BIS: XSLT-Schritt -> Regeldatei }
procedure MapRules(V: TLandrixEInvoiceValidator; const ARules: string);
begin
  V.RuleFiles.Values['EN16931-UBL-validation.xsl'] := ARules + 'en16931-ubl.xml';
  V.RuleFiles.Values['EN16931-CII-validation.xsl'] := ARules + 'en16931-cii.xml';
  V.RuleFiles.Values['XRechnung-UBL-validation.xsl'] := ARules + 'xrechnung-ubl.xml';
  V.RuleFiles.Values['XRechnung-CII-validation.xsl'] := ARules + 'xrechnung-cii.xml';
  V.RuleFiles.Values['CEN-EN16931-UBL.xslt'] := ARules + 'en16931-ubl.xml';
  V.RuleFiles.Values['PEPPOL-EN16931-UBL.xslt'] := ARules + 'PEPPOL-EN16931-UBL.sch';
end;

{ die ZUGFeRD-Konfiguration: Schema/Factur-X-1.09.2_<Profil>.xslt -> die .sch dieses Profils }
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
  Kosit := 'C:/MyApp/kosit/';                  { der Ordner, den install-kosit.ps1 geschrieben hat }
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

    { es läuft die Konfiguration, deren Szenarien zum Dokument passen }
    Validator.Options.AddConfiguration(XRechnung, eck_XRechnung);
    Validator.Options.AddConfiguration(Peppol, eck_PeppolBIS);
    Validator.Options.AddConfiguration(ZUGFeRD, eck_ZUGFeRD);

    case Validator.ValidateFile('rechnung.xml', Res) of   { XML oder ZUGFeRD-/Factur-X-PDF }
      ev_Accepted: WriteLn('angenommen (', string(Res.ScenarioName), ')');
      ev_Rejected: WriteLn('abgelehnt');
      ev_Incomplete: WriteLn('kein Urteil: keine Konfiguration registriert');
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

- `LoadConfiguration` liest `scenarios.xml` und löst die XML-Schemas gegen dessen Ordner auf.
  `RuleFiles` ordnet den Dateinamen eines XSLT-Schritts (ohne Ordner) einer Regeldatei zu; ein
  Wert auf `.sch` wird beim Laden aus ISO-Schematron übersetzt (die Factur-X-`.sch` brauchen ihre
  `*_codedb.xml` daneben, wie die Konfiguration sie mitbringt). `RuleFiles` vor der ersten
  Validierung füllen.
- Schemas und Regeln werden beim ersten Gebrauch geladen und behalten: Das erste Dokument einer
  Konfiguration dauert einige Sekunden, die weiteren Millisekunden. Die Validatoren für die
  Laufzeit der Anwendung behalten.
- Eine fehlende Regeldatei oder ein Schema, das nicht lädt, löst `ELandrixEInvoiceError` aus: ein
  Problem der Einrichtung, nicht des Dokuments. Eine Konfiguration, die diese Bibliothek nicht
  ausführen kann (anderes `acceptMatch`, Szenario ohne match-Ausdruck), lehnt
  `LoadConfiguration` ab.
- Die Validatoren gehören dem Aufrufer: nach dem Dokumentvalidator freigeben, nie solange sie
  registriert sind.
- Wahl: Eine Konfiguration ist Kandidat, wenn genau eines ihrer Szenarien zum Dokument passt (bei
  zwei oder mehr fällt sie heraus); unter mehreren Kandidaten hat ZUGFeRD Vorrang vor Peppol BIS,
  Peppol BIS vor XRechnung (ein Factur-X-EN-16931-CII-Dokument passt zu ZUGFeRD und zu XRechnung).
  Ein Dokument, das keine registrierte Konfiguration nimmt, wird abgelehnt, wie der
  KoSIT-Validator ein Dokument ohne Szenario ablehnt (`Res.ConfigurationChoice = ecc_NoMatch`).
  `Options.Configuration := XRechnung` erzwingt eine Konfiguration. `Res.ConfigurationChoice` und
  `Res.CandidateCount` sagen, wie gewählt wurde.
- Das Beispiel schreibt Pfade mit `/`, das auch Windows annimmt; unter Linux und macOS zählt die
  Groß- und Kleinschreibung, so wie das Skript die Namen anlegt.
- Nur die installierten Konfigurationen registrieren: `LoadConfiguration` löst bei fehlender
  `scenarios.xml` eine Ausnahme aus.
- `ValidateStream` nimmt die Bytes aus einem Stream, etwa eine Rechnung aus einer Datenbank.

## Das Ergebnis

| `Res.Verdict` | Bedeutung |
|---|---|
| `ev_Accepted` | der KoSIT-Lauf nimmt das Dokument an (bei einem PDF auch Einbettung und XMP-Metadaten) |
| `ev_Rejected` | der KoSIT-Lauf lehnt ab (auch nicht wohlgeformtes XML), oder keine registrierte Konfiguration nimmt das Dokument, oder ein PDF fällt bei Einbettung oder Metadaten durch |
| `ev_Incomplete` | keine Konfiguration registriert (bei einem PDF auch, wenn die Prüfung von Einbettung oder Metadaten, Ebenen 2 und 3, nicht abgeschlossen werden konnte): es gibt kein Urteil, auch wenn die Regelprüfung nichts findet |

- `Res.Status[Teil]` je Teil: `evp_Read` (Lesen über die Fassade), `evp_KoSIT`, `evp_ModelCheck`
  (die eigenen Regeln der Bibliothek), `evp_PdfEmbedding` und `evp_PdfMetadata` (PDF-Ebenen 2 und
  3), `evp_PdfA` (PDF/A, Ebene 1: nicht geprüft).
- `Res.Findings[I]`: `RuleID`, `Severity`, `Text`, `Location`, `Line`, `Column`, `Part`. Befunde der
  eigenen Regeln sind als `Predicted` markiert: Sie sagen voraus, was KoSIT meldet, und ändern das
  Urteil nie. PDF-Befunde haben die Kennungen BR-HYBRID-... (ZUGFeRD) und LX-PDF-01 bis LX-PDF-11
  (eigene Prüfungen).
- Peppol BIS: Die Konfiguration hat kein `acceptMatch`, deshalb lehnt jede fehlgeschlagene
  Assertion ab, auch eine Warnung. So entscheidet der KoSIT-Validator; sein HTML-Bericht zeigt
  stattdessen die Bewertung seines Stylesheets, die nur bei Fehlern ablehnt (das Skript
  `tools/validate.ps1` des Repositorys nutzt diese Bewertung).

Berichte:

```pascal
uses LandrixEInvoiceReportHtml, LandrixEInvoiceValidationReport, LandrixEInvoiceValidationHtml;

with TLandrixEInvoiceValidationReportWriter.Create do      { XML, eigenes versioniertes Format }
try
  DocumentName := 'rechnung.xml';
  SaveToFile(Res, 'bericht.xml');
finally
  Free;
end;
with TLandrixEInvoiceValidationHtmlWriter.Create do        { eine HTML-Datei, ohne Skripte }
try
  Language := eln_German;
  DocumentName := 'rechnung.xml';
  SaveToFile(Res, 'bericht.html');
finally
  Free;
end;
```

## Die Rechnung anzeigen

`TLandrixEInvoiceRenderHtmlWriter` schreibt eine Rechnung als eine HTML-Seite,
`TLandrixEInvoiceRenderMarkdownWriter` als CommonMark-Text (für Protokolle, Tickets, Mails). Beide
zeigen jedes Feld des Modells, leere Gruppen weggelassen, englisch oder deutsch, auf Wunsch mit
den Business Terms (BT-...). Sie nehmen die `TLandrixInvoice` oder das gelesene
`TLandrixEInvoiceDocument` (dann mit den Lesemeldungen).

```pascal
uses LandrixEInvoiceReportHtml, LandrixEInvoiceRenderHtml, LandrixEInvoiceRenderMarkdown;

Html := TLandrixEInvoiceRenderHtmlWriter.Create;
try
  Html.Language := eln_German;
  Html.ShowBusinessTerms := True;
  Html.SaveToFile(Doc, 'rechnung.html');     { oder Html.WriteToString(Invoice) }
finally
  Html.Free;
end;
```

Das ersetzt die KoSIT-Visualisierung (XSLT, Java). Ein PDF der Rechnung entsteht nicht.

## Was ausgeliefert werden muss

| Funktion | Braucht zur Laufzeit |
|---|---|
| Lesen, Schreiben, Regelprüfung, Berechnung, PDF-Extraktion, PDF-Prüfung, Berichte, Darstellung | nichts: alles ist ins Programm übersetzt (Codelisten und Regeltabellen sind Pascal-Units); keine DLL, kein MSXML, kein Java, keine Datendateien |
| Dokumentvalidierung mit KoSIT | den Ordner von `install-kosit.ps1` (nur die genutzten Module; die Marker `.installed` dürfen fehlen), unter einem Pfad, den das Programm an `LoadConfiguration` übergibt |

Unter Unix nehmen Programme wie üblich `cwstring` in die uses-Liste; die Bibliothek selbst braucht
es nicht.

Lizenzen, die mit einer Anwendung ausgeliefert werden:

- diese Bibliothek unter GPL-3.0-or-later oder der Landrix Software Commercial License (siehe
  [README](../../README.md#license)), mit [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md), den
  Texten in [LICENSES/](../../LICENSES/) und den Hinweisen von LandrixXML
  (`external/landrix-xml/THIRD-PARTY-NOTICES.md`);
- wer den KoSIT-Ordner mitliefert, die Bedingungen seines Inhalts, die die kommerzielle Lizenz
  nicht abdeckt: KoSIT-Konfigurationen und XRechnung-Schematron (Apache-2.0, KoSIT), die
  Validierungsartefakte der EN 16931 und die daraus übersetzten Regeldateien (EUPL-1.2, CEN/TC 434;
  siehe `rules/NOTICE.md`), die ZUGFeRD-Konfiguration (Apache-2.0; ihre Schemas und Schematron
  unter den Bedingungen von FeRD und FNFE-MPE), die Peppol-Schematron (OpenPEPPOL; die Datei
  trägt nur einen Vermerk des CEN, keine Lizenz: vor dem Weitergeben die Bedingungen von OpenPEPPOL
  prüfen), die
  UBL-Schemas (OASIS) und die CII-Schemas (UN/CEFACT).
