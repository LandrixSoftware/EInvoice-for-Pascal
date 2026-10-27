# Schreiben

[English](../writing.md)

`TLandrixEInvoice` (Unit `LandrixEInvoice`) schreibt eine Rechnung für ein Ziel:

```pascal
TLandrixEInvoice.SaveToFile(Invoice, 'invoice.xml', Target);
TLandrixEInvoice.SaveToStream(Invoice, Stream, Target);
Bytes := TLandrixEInvoice.SaveToUtf8(Invoice, Target);   // TLandrixXmlUtf8
Text := TLandrixEInvoice.SaveToText(Invoice, Target);    // TLandrixEInvoiceString
```

Alle nehmen zwei optionale Parameter: `AOptions: TLandrixEInvoiceOptions = []` und
`ADiagnostics: TLandrixEInvoiceDiagnostics = nil`.

## Was passiert

1. Das Ziel wird aufgelöst. Ein unbekanntes oder nur lesbares Ziel löst
   `ELandrixEInvoiceTargetError` aus, bevor etwas gelesen oder geschrieben wird.
2. Die Geschäftsregeln des Ziels werden geprüft (EN 16931, XRechnung, Peppol,
   Factur-X-Profilregeln), siehe [Prüfen](checking.md).
3. Die Rechnung wird auf das Syntaxmodell abgebildet und im Speicher serialisiert.
4. Bei Fehlern wird `ELandrixEInvoiceWriteError` ausgelöst und **nichts geschrieben**. Die
   Ausnahme besitzt eine Kopie der Meldungen: `E.Diagnostics`.

Meldungen, die keine Fehler sind (Inhalt, den das Ziel nicht aufnehmen kann, eine angewandte
Vorgabe), landen in `ADiagnostics`, wenn Sie eine Liste übergeben.

## Optionen

| Option | Wirkung |
|---|---|
| `eio_Strict` | Inhalt, den das Ziel nicht erlaubt (`edk_NotAllowed`), und Abgeratenes zählen als Fehler. |
| `eio_NoRuleCheck` | Geschäftsregeln überspringen; die Abbildung und ihre Meldungen laufen trotzdem. |
| `eio_WriteDespiteErrors` | Trotz Fehlern schreiben (Notausgang, z. B. um die Ausgabe anzusehen). |
| `eio_InvoiceOnly` | Lesen: das Syntaxmodell nach der Abbildung freigeben. |
| `eio_CheckOnRead` | Lesen: die Geschäftsregeln der erkannten Spezifikation prüfen. |
| `eio_NoPdf` | Lesen: die Eingabe nie als PDF behandeln. |

## Text und Kodierungen

Das XML ist immer UTF-8 mit der Deklaration `encoding="UTF-8"`. `SaveToText` liefert dasselbe
Dokument als UTF-16-Text: als UTF-8 speichern (`LandrixEInvoiceStringToUtf8` oder
`SaveToFile` / `SaveToStream`), nie über eine Codepage. Unter Delphi 6 bis 2007 ist der Text ein
`WideString`; die Zuweisung an einen `string` verliert Zeichen außerhalb der System-Codepage.

## UBL Invoice oder CreditNote

In UBL wird eine Gutschrift (BT-3 = 381) als `CreditNote` geschrieben, jede andere Rechnung als
`Invoice`. CII hat eine Wurzel für beide.

## Unterpositionen (Positionsgruppen)

Unterpositionen werden verschachtelt geschrieben, wo das Ziel sie kennt: XRechnung UBL (als
`cac:SubInvoiceLine`, mit der Kennung der Erweiterung) und Factur-X / ZUGFeRD EXTENDED
(`ParentLineID`). Überall sonst (XRechnung CII, die Factur-X-Profile unter EXTENDED, Peppol BIS,
eine UBL-Gutschrift) wird die Rechnung **flach** geschrieben: eine Gruppe wird durch ihre
Positionen ersetzt, der Tiefe nach, so dass die Summe der Positionen (BT-106) gleich bleibt. Die
Gruppenpositionen selbst (Titel, Zwischensumme) und INFORMATION-Unterpositionen entfallen; je
Gruppe auf oberster Ebene gibt es eine Warnung (`edk_NotAllowed`, mit `eio_Strict` ein Fehler).
Geprüft wird die flache Rechnung, so wie sie geschrieben wird; Ihr Rechnungsobjekt bleibt
unverändert.

## Das Dokument vor dem Schreiben ändern

`ToCII`, `ToUBLInvoice` und `ToUBLCreditNote` liefern das Syntaxmodell einer Rechnung. Ändern
Sie es und schreiben Sie es mit den `SaveTo*`-Überladungen für Syntaxmodelle:

```pascal
CII := TLandrixEInvoice.ToCII(Invoice, Target);
try
  // z. B. Inhalt, den nur Factur-X EXTENDED kennt
  TLandrixEInvoice.SaveToFile(CII, 'factur-x.xml', Target);
finally
  CII.Free;
end;
```

Auch ein Syntaxmodell wird gegen das Ziel geprüft: Inhalt, den sein Factur-X-Profil nicht
enthält, Inhalt, den Schema und Profil verlangen, und dass seine BT-24 zum Ziel gehört. Die
Geschäftsregeln brauchen das semantische Modell und werden für Syntaxmodelle nicht geprüft.

## Beträge berechnen

Das Schreiben ändert nie Beträge. Berechnen Sie sie vor dem Schreiben auf Aufruf:

```pascal
TLandrixEInvoice.CalculateLineAmounts(Invoice);   // BT-131 jeder Position
TLandrixEInvoice.CalculateTotals(Invoice);        // BG-23 und BG-22
```

- `CalculateLineAmounts`: Menge x Nettopreis / Basismenge (0 gilt als 1), halb weg von null auf
  Cent gerundet, minus Positionsnachlässe, plus Positionszuschläge. Eine Gruppe (Position mit
  Unterpositionen) erhält die Summe ihrer DETAIL- und GROUP-Unterpositionen. Lassen Sie diesen
  Aufruf weg, wenn Ihre Positionsbeträge von anderswo kommen.
- `CalculateTotals`: die Steueraufschlüsselung nach Umsatzsteuerkategorie und Satz (die Steuer
  jeder Gruppe einmal auf ihre Bemessungsgrundlage gerundet; vorhandene Einträge behalten ihre
  Befreiungsgründe, fehlende kommen dazu, nicht benutzte werden entfernt) und die Belegsummen
  BT-106 bis BT-110, BT-112 und BT-115. BT-111 (Steuerwährung), BT-113 (Vorauszahlung) und BT-114
  (Rundung) bleiben, wie Sie sie setzen; BT-115 enthält Zahlungen Dritter.

Beide überschreiben, was sie berechnen, liefern die Anzahl der Fehler und lassen die Rechnung
bei einem Fehler unverändert (z. B. eine Position ohne Umsatzsteuerkategorie, eine Gruppe,
deren Unterpositionen verschiedene Steuersätze haben). Die Prüfung meldet die Rechenregeln
(BR-CO-10 bis BR-CO-17), wenn Beträge Ihres Programms nicht aufgehen.
