# Einstieg

[English](../getting-started.md)

EInvoice for Pascal liest, schreibt und prüft elektronische Rechnungen: XRechnung, ZUGFeRD /
Factur-X und Peppol BIS Billing, jeweils in beiden Syntaxen (UBL und UN/CEFACT CII). Eine
Codebasis übersetzt mit Delphi 6 bis Delphi 13 und Free Pascal ab 3.2.2.

## Einrichtung

1. Quellen mit dem Submodul LandrixXML holen:

   ```
   git clone --recurse-submodules https://github.com/LandrixSoftware/EInvoice-for-Pascal.git
   ```

   In einem bestehenden Klon: `git submodule update --init`.

2. Zwei Ordner in den Suchpfad des Projekts aufnehmen:

   - `source`
   - `external/landrix-xml/source`

   Delphi: *Projekt > Optionen > Delphi-Compiler > Suchpfad*. Lazarus: *Projekt >
   Projekteinstellungen > Compilereinstellungen > Pfade > Andere Units*.

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
Die Bibliothek rechnet nicht: Positionsbeträge, Steueraufschlüsselung und Summen setzt Ihr
Programm.

## Beispiele

Jedes Beispiel ist ein Konsolenprogramm mit einer `.dpr` für Delphi und einer `.lpi` für
Lazarus. Sie bauen aufeinander auf: Zuerst WriteXRechnung ausführen, die anderen lesen dessen
Ausgabe.

| Beispiel | Zeigt |
|---|---|
| [WriteXRechnung](../../examples/WriteXRechnung/WriteXRechnung.dpr) | Rechnung füllen und als XRechnung UBL und CII schreiben |
| [ReadInvoice](../../examples/ReadInvoice/ReadInvoice.dpr) | XML oder PDF lesen, die Dokumentangaben, die Meldungen |
| [CheckInvoice](../../examples/CheckInvoice/CheckInvoice.dpr) | Geschäftsregeln prüfen, strenger Modus, verweigertes Schreiben |
| [ConvertCIIToUBL](../../examples/ConvertCIIToUBL/ConvertCIIToUBL.dpr) | Zwischen den Syntaxen umwandeln |
| [CompatXRechnung](../../examples/CompatXRechnung/CompatXRechnung.dpr) | Code, der für XRechnung-for-Delphi geschrieben wurde |
| [BusinessCases](../../examples/BusinessCases/BusinessCases.dpr) | 24 Geschäftsfälle für jedes passende Ziel (111 Dateien) |

## Weiterlesen

- [Schreiben](writing.md)
- [Lesen](reading.md)
- [Prüfen](checking.md)
- [Umstieg von XRechnung-for-Delphi](compat-xrechnung.md)
- [Öffentliche API](../../README.md#public-api): welche Units stabil sind
