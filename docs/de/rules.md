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
  LX-CC-Regeln laufen nur auf Anfrage, LX-ID-, LX-PL- und LX-DE-Hinweise zählen nie.
- `python tools/check-forbidden.py` (ohne Argumente) schlägt an, wenn eine Kennung aus dem
  Quelltext hier oder in der englischen Liste fehlt, wenn eine Liste eine Kennung nennt, die der
  Quelltext nicht hat (außer sie ist als aufgegeben markiert), oder wenn eine Kennung in einer
  Liste zweimal steht.

Familien: `LX-CC` (Prüfungen von XRechnung-for-Delphi), `LX-PDF` (Hybrid-PDF), `LX-ID` (Kennungen,
Prüfziffern und Zeichen), `LX-PL` (Plausibilität von Daten und Zahlung), `LX-DE` (deutsches
Steuerrecht). Reserviert für geplante Prüfungen: `LX-AR` (Rechnen, wo es keine offizielle Regel
gibt), `LX-AT` (Anhänge).

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

- `pdfEmbedding`: LX-PDF-01 bis LX-PDF-07, LX-PDF-09, LX-PDF-10, LX-PDF-13 und LX-PDF-08 für eine Grenze
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
| LX-PDF-13 | Warnung | die Datei hat Bytes vor `%PDF-` (höchstens 1024, die PDF-Leser hinnehmen; ISO 32000-2, 7.5.2 verlangt den Kopf zuerst); auch bei einer PDF/A-4-Angabe, die die PDF/A-Prüfung nicht abdeckt, und wenn das PDF nicht lesbar ist | unveröffentlicht |

## LX-ID: Kennungen und Zeichen (Hinweise)

Hinweise der Hinweisprüfungen (Familie `eaf_Identifiers`, standardmäßig an): Zeichen (LX-ID-01 bis
LX-ID-05) und Kennungen nach ihrem Schema (LX-ID-06 bis LX-ID-10). Sie erscheinen im
Teil `advisory` einer Validierung, der nie für das Urteil zählt, und sind höchstens Warnungen. Der
Befund nennt den Modellpfad, das erste Zeichen als `U+XXXX` mit seiner Position (in Zeichen) und wie viele es
sind; `found` zeigt den Wert mit den Zeichen maskiert als `<U+XXXX>`. Der Wert wird nie geändert.

Kennungsfelder sind Kennungen, Codes, Verweise, Postleitzahlen, Telefonnummern, E-Mail-Adressen und
Dateinamen; Textfelder sind Namen und Freitexte (auch der Verwendungszweck, BT-83). ASCII-Kennungen:
Umsatzsteuer-Identifikationsnummern (BT-31, BT-48, BT-63), Länder- und Währungscodes, die GTIN
(BT-157 mit Schema 0160), die Gläubiger-Identifikationsnummer (BT-90), der Zahlungsdienstleister
(BT-86), die Mandatsreferenz (BT-89) einer SEPA-Lastschrift (59) und das Konto (BT-84, BT-91) einer
SEPA-Zahlung (58, 59) oder eines, das wie eine IBAN beginnt.

| Kennung | Schweregrad | Befund | Seit |
|---|---|---|---|
| LX-ID-01 | Warnung | ein bidirektionales Steuerzeichen (U+061C, U+200E, U+200F, U+202A bis U+202E, U+2066 bis U+2069) in einem Kennungsfeld | unveröffentlicht |
| LX-ID-02 | Warnung | ein unsichtbares Zeichen (z. B. U+200B bis U+200D, U+2060, U+FEFF, U+00AD, Variantenselektoren, Tag-Zeichen) oder ein Leerzeichen außer U+0020 (z. B. U+00A0, U+2000 bis U+200A, U+3000) in einem Kennungsfeld | unveröffentlicht |
| LX-ID-03 | Warnung | ein C1-Steuerzeichen (U+0080 bis U+009F) in einem beliebigen Textfeld, meist eine falsche Zeichenkodierung | unveröffentlicht |
| LX-ID-04 | Hinweis | ein bidirektionales Steuerzeichen oder unsichtbares Zeichen in einem Namen oder Freitext, wo es berechtigt sein kann | unveröffentlicht |
| LX-ID-05 | Warnung | ein anderes Zeichen außerhalb von ASCII in einer ASCII-Kennung, z. B. ein kyrillischer Buchstabe, der wie ein lateinischer aussieht | unveröffentlicht |
| LX-ID-06 | Warnung | eine GLN (Schema 0088; eine globale Kennung ohne Schema zählt als solche) eines Beteiligten, Orts oder einer elektronischen Adresse, die nicht 13 Ziffern hat oder eine falsche GS1-Prüfziffer (bei Peppol BIS, wo die Regelprüfung im selben Lauf PEPPOL-COMMON-R040 gemeldet hat, nur die Länge) | unveröffentlicht |
| LX-ID-07 | Warnung | eine GTIN (BT-157 mit Schema 0160 oder das GTIN-Feld einer Position ohne BT-157), die nicht 8, 12, 13 oder 14 Ziffern hat oder eine falsche GS1-Prüfziffer | unveröffentlicht |
| LX-ID-08 | Warnung | eine GTIN (Schema 0160) für einen Beteiligten, Ort oder eine Adresse, oder eine GLN (Schema 0088) für einen Artikel | unveröffentlicht |
| LX-ID-09 | Warnung (BT-10 außerhalb von XRechnung: Hinweis) | eine Leitweg-ID (Schema 0204), die nicht der Formatspezifikation 2.0.2 folgt (Form, Grobadressierung aus 2, 3, 5, 8, 9 oder 12 Ziffern, beginnend mit 01 bis 16 oder 99, Prüfziffern MOD 97-10), auch als Artikelkennung, oder eine Käuferreferenz (BT-10), die wie eine Leitweg-ID aussieht (Grobadressierung aus 8 oder mehr Ziffern, oder 99... mit Feinadressierung), aber falsche Prüfziffern hat | unveröffentlicht |
| LX-ID-10 | Hinweis | Käuferreferenz (BT-10) und elektronische Adresse des Käufers (BT-49, Schema 0204) sind verschiedene gültige Leitweg-IDs; die Peppol-ID muss nicht die Leitweg-ID sein (`expected`: BT-49, `found`: BT-10) | unveröffentlicht |

## LX-PL: Plausibilität von Daten und Zahlung (Hinweise)

Hinweise der Hinweisprüfungen (Familie `eaf_Plausibility`, standardmäßig an), im Teil `advisory`
wie LX-ID. Was die Regelprüfung derselben Validierung gemeldet hat, wird nicht wiederholt (die
Regel in Klammern).

| Kennung | Schweregrad | Befund | Seit |
|---|---|---|---|
| LX-PL-01 | Warnung | das Fälligkeitsdatum (BT-9) liegt vor dem Rechnungsdatum (BT-2); nicht bei einer Gutschrift (Typcode 81, 83, 261, 262, 296, 308, 381, 396, 420, 458, 502, 503, 532, auch als anderer Code), einer negativen Summe oder einer im Voraus bezahlten Rechnung (BT-113 über 0 und BT-115 höchstens 0); `expected` das Rechnungsdatum, `found` das Fälligkeitsdatum | unveröffentlicht |
| LX-PL-02 | Warnung | das Konto (BT-84, BT-91) einer SEPA-Zahlung (58, 59) oder eines, das wie eine IBAN beginnt, ist keine IBAN: nicht zwei Großbuchstaben, zwei Prüfziffern und 1 bis 30 Buchstaben oder Ziffern, Kleinbuchstaben, ein Ländercode, der kein ISO-3166-Land ist (XK erlaubt), oder andere Prüfziffern als MOD 97-10 ergibt (`expected` die richtigen; die Länge je Land wird nicht geprüft, die vollständige Tabelle ist das IBAN-Register von SWIFT, das nicht gewerblich kopiert werden darf); nicht für ein Konto, das BR-DE-19, BR-DE-20, DE-R-019 oder DE-R-020 gemeldet hat | unveröffentlicht |
| LX-PL-03 | Warnung | der Zahlungsdienstleister (BT-86) besteht aus Buchstaben und Ziffern mit mindestens einem Buchstaben, ist aber kein BIC: nicht acht oder elf Zeichen in der Form von ISO 9362 (Präfix aus vier Buchstaben oder Ziffern, Ländercode, Ort, optionale Filiale) in Großbuchstaben, oder ein Ländercode, der kein ISO-3166-Land ist (XK erlaubt, XI nicht); nationale Bankleitzahlen, Clearing-Kennungen wie SE:BANKGIRO und indische IFSC bleiben unbeachtet | unveröffentlicht |
| LX-PL-04 | Hinweis | der Kontoinhaber (BT-85) einer Überweisung (30, 58) ist nicht der Verkäufer (BT-27, BT-28; keiner der Namen enthält den anderen, verglichen in Großbuchstaben mit Umlauten als AE, OE, UE und ß als SS; kein Hinweis, wenn ein Name Zeichen außerhalb von Latin-1 hat), und kein Zahlungsempfänger (BG-10: Name, Kennung oder Registernummer) ist genannt | unveröffentlicht |
| LX-PL-05 | Warnung | eine SEPA-Lastschrift (59) ohne Mandatsreferenz (BT-89), Gläubiger-Identifikationsnummer (BT-90; bei UBL auch als Kennung des Zahlungsempfängers oder globale Kennung des Verkäufers mit Schema SEPA) oder belastetes Konto (BT-91); auch mit dem Code der Zahlungsart als anderem Text; nicht nach BR-DE-25-a oder DE-R-025-1 (Mandat, Konto; bei CII auch die Gläubiger-ID), BR-DE-30, BR-DE-31, DE-R-030, DE-R-031, PEPPOL-EN16931-R061 | unveröffentlicht |

## LX-DE: deutsches Steuerrecht (Hinweise)

Hinweise der Hinweisprüfungen (Familie `eaf_German`, rechtlich, nur auf Anforderung: nicht in
`LandrixEInvoiceAdvisoryTechnical`), im Teil `advisory`. Sie beraten; ob ein Dokument eine Rechnung
im Sinne des UStG ist, sagen sie nicht.

| Kennung | Schweregrad | Befund | Seit |
|---|---|---|---|
| LX-DE-01 | Warnung | Verkäufer und Käufer sind in Deutschland (BT-40, BT-55), und das Profil (BT-24) ist MINIMUM oder BASIC WL, nach dem BMF (Schreiben vom 15. Oktober 2025) kein zulässiges E-Rechnungsformat; auch für reines XML; nicht bei einem hybriden PDF, für das BR-HYBRID-DE-01 oder BR-HYBRID-DE-02 es gemeldet hat | unveröffentlicht |
