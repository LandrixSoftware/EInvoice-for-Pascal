# Regeln dieser Bibliothek

[English](../rules.md)

Die meisten Befunde tragen die Kennung einer offiziellen Regel (BR-..., PEPPOL-..., FX-SCH-A-...,
BR-HYBRID-..., PDF/A-Abschnitte). Wo die Standards keine Regel haben, verwendet diese Bibliothek
eigene Kennungen, die alle mit `LX-` beginnen. Diese Seite führt jede davon auf.

## Wie die Kennungen funktionieren

- Eine Kennung lautet `LX-<Familie>-<Nummer>`, die Nummer hat zwei Stellen.
- Kennung und Bedeutung sind stabil. Text und Schweregrad können sich in einer Version ändern.
- Eine Nummer wird nie wiederverwendet oder umnummeriert. Eine aufgegebene Regel bleibt in dieser
  Liste, mit „aufgegeben in <Version>“ am Ende der Spalte Seit, und behält ihre Nummer reserviert.
- Eine Regel, deren Bedingung weiter wird, bekommt eine neue Nummer.
- Das Präfix sagt nichts über das Urteil: Das entscheidet, wo ein Befund erscheint (siehe
  [Validieren](validation.md)). LX-PDF-Fehler zählen für das Urteil über ein Hybrid-PDF,
  LX-CC-Regeln laufen nur auf Anfrage.
- `python tools/check-forbidden.py` (ohne Argumente) schlägt an, wenn eine Kennung aus dem
  Quelltext hier oder in der englischen Liste fehlt, wenn eine Liste eine Kennung nennt, die der
  Quelltext nicht hat (außer sie ist als aufgegeben markiert), oder wenn eine Kennung in einer
  Liste zweimal steht.

Familien: `LX-CC` (Prüfungen von XRechnung-for-Delphi), `LX-PDF` (Hybrid-PDF). Reserviert für
geplante Prüfungen: `LX-ID` (Kennungen, Prüfziffern, täuschende Zeichen), `LX-PL` (Plausibilität
von Daten und Zahlung), `LX-AR` (Rechnen, wo es keine offizielle Regel gibt), `LX-AT` (Anhänge),
`LX-DE` (deutsches Steuerrecht).

## LX-CC: Prüfungen von XRechnung-for-Delphi

Die Prüfungen von `TXRechnungInvoiceAdapter.ConsistencyCheck` (Nummer = alter Fehlercode). Sie
sind Vorgaben dieser Bibliothek, keine veröffentlichten Regeln: `TLandrixEInvoice.Check` und das
Schreiben führen sie nicht aus; `LandrixEInvoiceCheckRule` und die Kompatibilitätsschicht fragen
sie einzeln ab. Schweregrad: Fehler.

| Kennung | Begriffe | Gilt für | Befund | Seit |
|---|---|---|---|---|
| LX-CC-01 | BG-16 | alle außer Factur-X EN 16931 | keine Zahlungsanweisungen (Zahlungsart) | 0.9.0-beta.1 |
| LX-CC-02 | BT-3 | XRechnung | Rechnungsart 84, 261, 383, 386 oder 457 | 0.9.0-beta.1 |
| LX-CC-03 | BG-3 | alle | mehr Verweise auf vorausgegangene Rechnungen, als das Ziel erlaubt | 0.9.0-beta.1 |
| LX-CC-04 | BG-19 | alle | mehr als eine SEPA-Lastschrift (Zahlungsart 59) | 0.9.0-beta.1 |
| LX-CC-05 | BG-18 | alle | mehr als eine Kreditkarte (Zahlungsart 54) | 0.9.0-beta.1 |
| LX-CC-06 | BT-31, BT-30 | alle | Verkäufer ohne Umsatzsteuer-Identifikationsnummer und Registernummer | 0.9.0-beta.1 |
| LX-CC-07 | BT-31, BT-32 | alle | Verkäufer ohne Umsatzsteuer-Identifikationsnummer und Steuernummer | 0.9.0-beta.1 |
| LX-CC-08 | BG-DEX-09 | alle | Zahlungen Dritter, die das Ziel nicht erlaubt | 0.9.0-beta.1 |
| LX-CC-09 | BT-34, BT-49 | alle | elektronische Adresse mit Schema EM unter Peppol oder ohne Schema, wo der Standard EM nicht gilt | 0.9.0-beta.1 |
| LX-CC-10 | BG-25 | alle | Lieferschein oder Lieferdatum je Position, die das Ziel nicht erlaubt | 0.9.0-beta.1 |
| LX-CC-11 | BG-DEX-01 | alle | eine INFORMATION-Position auf oberster Ebene oder eine DETAIL-Position mit Unterpositionen außerhalb von Factur-X EXTENDED | 0.9.0-beta.1 |
| LX-CC-12 | BG-DEX-01 | Factur-X EXTENDED | Betrag einer GROUP-Position weicht von der Summe ihrer DETAIL- und GROUP-Unterpositionen ab (BR-FXEXT-08) | 0.9.0-beta.1 |

## LX-PDF: Hybrid-PDF (ZUGFeRD / Factur-X)

Befunde des PDF-Prüfers zu dem, was die BR-HYBRID-Regeln nicht nennen. Wo sie in einer
Validierung erscheinen:

- `pdfEmbedding`: LX-PDF-01 bis LX-PDF-07, LX-PDF-09, LX-PDF-10 und LX-PDF-08 für eine Grenze
  außerhalb der XMP-Metadaten;
- `pdfMetadata`: LX-PDF-11 und LX-PDF-08 für eine Grenze in den XMP-Metadaten;
- `pdfA`: LX-PDF-12; dieser Teil zählt nicht für das Urteil.

Ein Fehler lässt seinen Teil scheitern und lehnt das PDF damit ab. LX-PDF-02, LX-PDF-03 und
LX-PDF-08 bedeuten, dass nicht alles geprüft wurde: Sie lassen die Teile, die sie betreffen,
unvollständig (LX-PDF-02 und LX-PDF-03 auch `pdfMetadata`, obwohl sie unter `pdfEmbedding`
gemeldet werden) und damit das Urteil, sofern nicht ein Fehler das PDF ohnehin ablehnt.

| Kennung | Schweregrad | Befund | Seit |
|---|---|---|---|
| LX-PDF-01 | Fehler | das PDF lässt sich nicht lesen oder entschlüsseln | 0.9.0-beta.1 |
| LX-PDF-02 | Warnung | die Objekttabelle wurde durch Absuchen neu aufgebaut | 0.9.0-beta.1 |
| LX-PDF-03 | Hinweis oder Warnung | ZUGFeRD 1.0 oder 2.0: erkannt, nicht geprüft (Warnung, wenn sich die Rechnung nicht entnehmen lässt; hat eine Grenze beim Dekodieren das verhindert, stattdessen LX-PDF-08) | 0.9.0-beta.1 |
| LX-PDF-04 | Warnung | der Stream der eingebetteten Rechnung hat kein `/Params /ModDate` | 0.9.0-beta.1 |
| LX-PDF-05 | Warnung | `/Params /Size` weicht von der dekodierten Länge ab | 0.9.0-beta.1 |
| LX-PDF-06 | Warnung | die Rechnungs-XML ist nicht in UTF-8 kodiert | 0.9.0-beta.1 |
| LX-PDF-07 | Fehler | eine weitere eingebettete Datei ohne `/AFRelationship` oder nicht im `/AF` des Katalogs oder einer Seite (ISO 19005-3, 6.8; `/AF` von Annotationen, Formularfeldern, Strukturelementen und XObjects wird noch nicht durchsucht) | 0.9.0-beta.1 |
| LX-PDF-08 | Warnung | eine Grenze wurde erreicht; nicht alles wurde geprüft | 0.9.0-beta.1 |
| LX-PDF-09 | Warnung | der MIME-Typ der Rechnung ist `application/xml`, nicht `text/xml` | 0.9.0-beta.1 |
| LX-PDF-10 | Fehler | die eingebettete Rechnung ist UBL, keine CII-Rechnung eines ZUGFeRD-Profils | 0.9.0-beta.1 |
| LX-PDF-11 | Fehler | die XMP-Metadaten fehlen, lassen sich nicht dekodieren, sind nicht wohlgeformt oder haben kein `rdf:RDF` mit `rdf:Description` | 0.9.0-beta.1 |
| LX-PDF-12 | Warnung | die PDF/A-Prüfung brach ab, bevor sie vollständig war | unveröffentlicht |
