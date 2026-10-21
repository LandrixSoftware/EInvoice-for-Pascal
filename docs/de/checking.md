# Prüfen

[English](../checking.md)

```pascal
Errors := TLandrixEInvoice.Check(Invoice, Target, [], Diagnostics);
```

`Check` führt die Prüfungen von `SaveTo*` aus, ohne zu schreiben, und liefert die Anzahl der
Fehler, bei denen `SaveTo*` verweigern würde. Überladungen gibt es für die drei Syntaxmodelle.

## Was geprüft wird

- Die Geschäftsregeln des Ziels: EN 16931 (BR-...), die Rechenregeln (BR-CO-...), die Regeln
  der Steuerkategorien, XRechnung (BR-DE-...), Peppol (PEPPOL-EN16931-...) und die
  Rechenregeln von Factur-X EXTENDED (BR-FXEXT-CO-...). Jeder Verstoß ist ein Eintrag der Art
  `edk_RuleViolation` mit der Regelkennung in `RuleID`.
- Alles, was die Abbildung meldet: Inhalt, den das Ziel oder sein Factur-X-Profil nicht
  aufnehmen kann (`edk_NotAllowed`), fehlender Pflichtinhalt (`edk_MissingElement`), Werte,
  die sich nicht umwandeln lassen.

Die Regelprüfung sagt voraus, was der KoSIT-Validator für das geschriebene Dokument melden
würde. Sie ersetzt den Validator nicht: Schema- und Schematron-Prüfung der offiziellen
Konfiguration bleiben der Maßstab.

## Schwere

Jeder Eintrag hat eine `Severity`: `eds_Error`, `eds_Warning` oder `eds_Info`. Fehler sind das,
worauf `SaveTo*` verweigert. Mit `eio_Strict` zählen auch Inhalt, den das Ziel nicht erlaubt,
und Abgeratenes als Fehler.

```pascal
for I := 0 to Integer(D.Count) - 1 do
  if D[I].Severity = eds_Error then
    WriteLn(string(D[I].RuleID), ' ', string(D[I].Message));
```

`D.ToText` liefert alle Einträge, einen je Zeile.

## Eine gelesene Rechnung prüfen

`eio_CheckOnRead` prüft beim Lesen die Geschäftsregeln der erkannten Spezifikation; die
Verstöße landen in `Doc.Diagnostics`. Oder `Check` mit `Doc.Info.Spec.Target` aufrufen, wie
[examples/CheckInvoice](../../examples/CheckInvoice/CheckInvoice.dpr) es tut.

## Regelkennungen

Regelkennungen sind stabil. Regeln dieser Bibliothek, die die Standards nicht haben, beginnen
mit `LX-` (z. B. LX-CC-04).
