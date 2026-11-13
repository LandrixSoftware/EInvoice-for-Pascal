# Lesen

[English](../reading.md)

```pascal
Doc := TLandrixEInvoice.LoadFromFile('invoice.xml');   // XML oder PDF
try
  WriteLn(string(Doc.Invoice.InvoiceNumber));
finally
  Doc.Free;
end;
```

| Methode | Eingabe |
|---|---|
| `LoadFromFile(AFileName)` | Eine Datei: XML oder ein PDF mit eingebetteter Rechnung (am Inhalt erkannt). |
| `LoadFromStream(AStream)` | Ebenso, ab der aktuellen Position des Streams bis zu seinem Ende. |
| `LoadFromUtf8(ABytes)` | XML als UTF-8-Bytes. Nie ein PDF. |
| `LoadFromText(AText)` | XML als dekodierter UTF-16-Text. Nie ein PDF. |

Alle nehmen ein optionales `AOptions: TLandrixEInvoiceOptions = []`. Für das Lesen:

| Option | Wirkung |
|---|---|
| `eio_InvoiceOnly` | Nur `Invoice` behalten; das Syntaxmodell wird nach der Abbildung freigegeben. |
| `eio_CheckOnRead` | Die Regelprüfung der erkannten Spezifikation ausführen und ihre Befunde zu `Diagnostics` hinzufügen (nichts bei unbekanntem BT-24). |
| `eio_NoPdf` | Die Eingabe als XML behandeln; nie nach einem PDF suchen. |

## Das Dokument

`TLandrixEInvoiceDocument` besitzt alles, was es liefert; geben Sie das Dokument frei, nicht
seine Teile.

| Eigenschaft | Inhalt |
|---|---|
| `Invoice` | Die Rechnung als `TLandrixInvoice`. `DetachInvoice` übergibt sie Ihnen. |
| `CII`, `UBLInvoice`, `UBLCreditNote` | Das Syntaxmodell, aus dem gelesen wurde (eines davon; `nil` mit `eio_InvoiceOnly`). Es behält Inhalt, den das semantische Modell nicht hält. |
| `Diagnostics` | Was das Lesen gefunden hat: unbekannte Elemente, Inhalt, den das Modell nicht hält, unbekannte Codes. |
| `Info` | Wurzelelement, Syntax, BT-24 und BT-23 wie gelesen, die Spezifikation, PDF-Angaben. |

Rechnung und Syntaxmodell sind unabhängige Kopien: Eine Änderung an einem ändert das andere
nicht.

## Welche Spezifikation

Die Spezifikation entscheidet BT-24 (`cbc:CustomizationID`,
`ram:GuidelineSpecifiedDocumentContextParameter/ram:ID`), nie der Inhalt. `Info.SpecFound` ist
True, wenn die Bibliothek die Kennung kennt; `Info.Spec` ist dann der Eintrag. Eine unbekannte
Kennung (z. B. XRechnung 2.x oder reines EN 16931 in UBL) wird trotzdem gelesen, mit einer
Warnung, und `Info.SpecFound` ist False. In CII ist reines EN 16931 (`urn:cen.eu:en16931:2017`)
die Kennung von Factur-X EN 16931 und wird als solche erkannt. Die ZUGFeRD-Kennungen `urn:zugferd.de:2p0:...`, die Factur-X
annimmt, werden erkannt.

## Fehler

Eine Ausnahme gibt es nur, wenn kein Dokument entsteht:

| Ausnahme | Ursache |
|---|---|
| `ELandrixEInvoiceFormatError` | Kein wohlgeformtes XML (mit `Line`, `Column`, `Offset`), keine Rechnungswurzel, ZUGFeRD 1.0. |
| `ELandrixEInvoicePdfError` | Ein PDF ohne eingebettete Rechnung oder eines, das nicht gelesen werden kann. |

Eine fehlende Datei löst die übliche Dateiausnahme der RTL aus.

## Kodierung

`LoadFromFile` und `LoadFromStream` folgen der Kodierungsangabe des XML (UTF-8, UTF-16,
ISO-8859-1 und andere). `LoadFromUtf8` und `LoadFromText` beachten sie nicht: Die Bytes sind
UTF-8, der Text ist bereits dekodiert.

Unter Delphi 6 bis 2007 gehört ein `AnsiString` mit UTF-8-Bytes in `LoadFromUtf8`. An
`LoadFromText` übergeben, wird er über die System-Codepage umgewandelt, und Nicht-ASCII-Zeichen
werden ohne Meldung verfälscht.

## PDF

ZUGFeRD- und Factur-X-PDFs tragen die Rechnung als eingebettete Datei. `LoadFromFile` und
`LoadFromStream` erkennen ein PDF am Inhalt und lesen die eingebettete Rechnung;
`Info.Source` ist `eso_Pdf`, `Info.PdfAttachmentName` der Name der eingebetteten Datei und
`Info.Pdf` die Angaben der Extraktion. Alle eingebetteten Dateien (auch Anhänge der Rechnung)
liefert `TLandrixEInvoicePdfExtractor` in der Unit `LandrixEInvoicePdf`.
