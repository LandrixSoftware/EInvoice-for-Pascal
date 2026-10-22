# Prüfen

[English](../checking.md)

```pascal
Errors := TLandrixEInvoice.Check(Invoice, Target, [], Diagnostics);
```

`Check` führt die Prüfungen von `SaveTo*` aus, ohne zu schreiben, und liefert die Anzahl der
Fehler, bei denen `SaveTo*` verweigern würde. Überladungen gibt es für die drei Syntaxmodelle.

## Was geprüft wird

- Die Geschäftsregeln des Ziels: EN 16931 (BR-...), die Rechenregeln (BR-CO-10 bis
  BR-CO-17), die Regeln der Steuerkategorien (BR-S-..., BR-Z-..., BR-E-..., BR-AE-...,
  BR-IC-..., BR-G-..., BR-O-..., BR-AF-..., BR-AG-..., BR-B-01, BR-B-02, BR-CO-03, BR-CO-04,
  BR-CO-09, BR-CO-18), die übrigen BR-CO-Regeln (Gründe, Verkäuferkennung,
  Zahlungsbedingungen), XRechnung (BR-DE-...), Peppol (PEPPOL-EN16931-...) und die Regeln von
  Factur-X EXTENDED (BR-FXEXT-...). Jeder Verstoß ist ein Eintrag der Art
  `edk_RuleViolation` mit der Regelkennung in `RuleID`.
- Alles, was die Abbildung meldet: Inhalt, den das Ziel oder sein Factur-X-Profil nicht
  aufnehmen kann (`edk_NotAllowed`), fehlender Pflichtinhalt (`edk_MissingElement`), Werte,
  die sich nicht umwandeln lassen.

Die Regelprüfung sagt voraus, was der KoSIT-Validator für das geschriebene Dokument melden
würde. Sie ersetzt den Validator nicht: Schema- und Schematron-Prüfung der offiziellen
Konfiguration bleiben der Maßstab. Noch nicht geprüft werden unter anderem die Codelistenregeln
(BR-CL-...) und die meisten Peppol-Regeln. Die Formatregeln BR-DE-17, BR-DE-19, BR-DE-20
(IBAN-Prüfsumme), BR-DE-27, BR-DE-28 und BR-51 werden geprüft; bis auf BR-51 in CII sind alle
Warnungen.

Die Regeln beurteilen die Rechnung so, wie sie geschrieben würde. Ein Steuersatz, den die
Rechnung nicht setzt, ist 0 und wird als 0 geschrieben; Positionen, Nachlässe und Zuschläge
der Kategorie O werden ohne Satz geschrieben.

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
