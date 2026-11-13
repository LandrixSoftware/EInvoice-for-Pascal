# Einstieg

[English](../getting-started.md)

EInvoice for Pascal liest, schreibt und prüft elektronische Rechnungen: XRechnung (UBL und
UN/CEFACT CII), ZUGFeRD / Factur-X (CII) und Peppol BIS Billing (UBL). Eine Codebasis übersetzt
mit Delphi 6 bis Delphi 13 und Free Pascal ab 3.2.2. Es gibt kein Package zu installieren: Die
Units kommen in den Suchpfad.

## Einrichtung

1. Quellen mit dem Submodul LandrixXML holen:

   ```
   git clone --recurse-submodules https://github.com/LandrixSoftware/EInvoice-for-Pascal.git
   ```

   In einem bestehenden Klon: `git submodule update --init`. Ein ZIP-Download von GitHub
   enthält das Submodul nicht: dann
   [LandrixXML for Pascal](https://github.com/landrix/LandrixXML-for-Pascal) in der Version, die
   das Submodul nennt (`git submodule status` oder der Link auf GitHub), nach
   `external/landrix-xml` laden.

2. Zwei Ordner in den Suchpfad des Projekts aufnehmen:

   - `source`
   - `external/landrix-xml/source`

   Delphi: *Projekt > Optionen > Delphi-Compiler > Suchpfad* (Delphi 6 und 7: *Projekt >
   Optionen > Verzeichnisse/Bedingungen > Suchpfad* oder der Bibliothekspfad der IDE). Lazarus:
   *Projekt > Projekteinstellungen > Compilereinstellungen > Pfade > Andere Units*.

3. Free Pascal: im Delphi-Modus übersetzen (`{$MODE DELPHI}` im Programm oder `-Mdelphi`).
   Unter Unix `cwstring` als erste Unit des Programms aufnehmen, wenn es Text oder Dateinamen
   mit Nicht-ASCII-Zeichen ausgibt oder verarbeitet; die Bibliothek selbst braucht es nicht.

## Die drei Modelle

| Modell | Units | Wofür |
|---|---|---|
| `TLandrixInvoice` | `LandrixEInvoiceInvoice` | Die Rechnung, wie EN 16931 sie beschreibt: ein Modell für alle Formate. Das füllen und lesen Sie. |
| `TLandrixCII...` | `LandrixEInvoiceCII` | Das CII-Dokument Element für Element, einschließlich allem, was Factur-X EXTENDED kennt. |
| `TLandrixUBL...` | `LandrixEInvoiceUBL` | Das UBL-Dokument Element für Element. |

Die meisten Programme brauchen nur `TLandrixInvoice` und die Fassade `TLandrixEInvoice`
(Unit `LandrixEInvoice`). Die Syntaxmodelle sind für Inhalte da, die das semantische Modell
nicht hält.

## Ziele

Ein Ziel benennt, was geschrieben wird: Standard, Syntax, Profil und Version.

```pascal
TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)
TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)
TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931)    // auch epr_Minimum ... epr_Extended
TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended)
TLandrixEInvoiceTargets.PeppolBIS('3.0')
```

Die Version darf einen Patch-Stand tragen (`'3.0.2'`); es zählen nur Haupt- und Nebenversion.

## Eine erste Rechnung

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
    // ... Verkäufer, Käufer, Positionen, Steueraufschlüsselung, Summen, Zahlung
    TLandrixEInvoice.SaveToFile(Invoice, 'invoice.xml',
      TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL));
  finally
    Invoice.Free;
  end;
end;
```

Das vollständige Programm ist [examples/WriteXRechnung](../../examples/WriteXRechnung/WriteXRechnung.dpr).
Positionsbeträge, Steueraufschlüsselung und Summen werden auf Aufruf berechnet
(`CalculateLineAmounts`, `CalculateTotals`, siehe [Schreiben](writing.md#beträge-berechnen));
das Schreiben selbst ändert nie Beträge.

## Beispiele

Jedes Beispiel hat eine `.dpr` für Delphi und eine `.lpi` für Lazarus. Workbench ist ein
Fenster (VCL und LCL) zum Ausprobieren, die übrigen sind Konsolenprogramme. Sie bauen
aufeinander auf: Zuerst WriteXRechnung ausführen, die anderen lesen dessen
Ausgabe.

| Beispiel | Zeigt |
|---|---|
| [WriteXRechnung](../../examples/WriteXRechnung/WriteXRechnung.dpr) | Rechnung füllen und als XRechnung UBL und CII schreiben |
| [ReadInvoice](../../examples/ReadInvoice/ReadInvoice.dpr) | XML oder PDF lesen, die Dokumentangaben, die Meldungen |
| [CheckInvoice](../../examples/CheckInvoice/CheckInvoice.dpr) | Geschäftsregeln prüfen, strenger Modus, verweigertes Schreiben |
| [ConvertCIIToUBL](../../examples/ConvertCIIToUBL/ConvertCIIToUBL.dpr) | Zwischen den Syntaxen umwandeln |
| [CompatXRechnung](../../examples/CompatXRechnung/CompatXRechnung.dpr) | Code, der für XRechnung-for-Delphi geschrieben wurde |
| [BusinessCases](../../examples/BusinessCases/BusinessCases.dpr) | 24 Geschäftsfälle für jedes passende Ziel (111 Dateien) |
| [Workbench](../../examples/Workbench/Workbench.dpr) | Ein Fenster: Geschäftsfall erzeugen oder XML bzw. PDF öffnen, nativ prüfen (eigene Regeln, KoSIT), zurücklesen, als Text und HTML zeigen |

Workbench: in Delphi `examples/Workbench/Workbench.dproj` öffnen (mit Delphi 13 angelegt; die
Suchpfade sind gesetzt, das Programm landet in `build/Workbench/<Plattform>/<Konfiguration>`), mit
Delphi 6 bis 12 `Workbench.dpr` mit den Suchpfaden `..\..\source`, `..\..\external\landrix-xml\source`
und `..\BusinessCases`, mit Lazarus `Workbench.lpi`. Erzeugen, Öffnen, Regelprüfung und Anzeige
funktionieren sofort. Für die KoSIT-Prüfung einmal `addons/kosit/install-kosit.ps1` ausführen:
Die Workbench findet `addons/kosit` (oder einen Ordner `kosit` neben dem Programm) selbst; ohne
ihn bleibt das Urteil unvollständig. Sie nutzt die Vorschau-Units aus
[Validieren](validation.md).

## Was ausgeliefert werden muss

Lesen, Schreiben, Prüfen und Anzeigen brauchen zur Laufzeit nichts: keine DLL, kein MSXML, kein
Java, keine Datendateien. Nur die KoSIT-Prüfung braucht ihren Konfigurationsordner; siehe
[Was ausgeliefert werden muss](validation.md#was-ausgeliefert-werden-muss), auch zu den Lizenzen.

## Weiterlesen

- [Schreiben](writing.md)
- [Lesen](reading.md)
- [Prüfen](checking.md)
- [Rechnungen validieren und anzeigen](validation.md)
- [Umstieg von XRechnung-for-Delphi](compat-xrechnung.md)
- [Öffentliche API](../../README.md#public-api): welche Units stabil sind
