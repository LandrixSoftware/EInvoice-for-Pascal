# Umstieg von ZUGFeRD-for-Delphi

[English](../compat-zugferd.md)

Für `TZUGFeRDInvoiceDescriptor` gibt es keine Kompatibilitätsschicht: Der Umstieg von
ZUGFeRD-for-Delphi heißt, den Code neu zu schreiben, der Rechnungen füllt und liest. Diese Seite
zeigt, wo die Dinge jetzt liegen; eine Tabelle Feld für Feld (Eigenschaft des Descriptors zu
Business Term und Feld) folgt. Bis dahin zeigen [Schreiben](writing.md) und
[examples/WriteXRechnung](../../examples/WriteXRechnung/WriteXRechnung.dpr), wie eine Rechnung
gefüllt wird. ZUGFeRD-for-Delphi bleibt unter der Apache License 2.0 verfügbar; diese Bibliothek
steht unter GPL-3.0-or-later oder der Landrix Software Commercial License
([README](../../README.md#license)).

## Zwei Modelle statt des Descriptors

| Sie brauchen | Nehmen Sie |
|---|---|
| Die Rechnung, wie EN 16931 sie beschreibt, gleich für jedes Format | `TLandrixInvoice` (Unit `LandrixEInvoiceInvoice`) und die Fassade `TLandrixEInvoice`: das, was die meisten Programme brauchen ([Einstieg](getting-started.md)) |
| Jedes Element des CII-Dokuments, einschließlich allem, was Factur-X EXTENDED hat | `TLandrixCIIInvoice` (Unit `LandrixEInvoiceCII`), aus dem Factur-X-EXTENDED-Schema generiert: am nächsten am Descriptor |

Die Fassade liest und schreibt beide. Ein gelesenes Dokument hält `Doc.Invoice` und das
Syntaxmodell, aus dem gelesen wurde: `Doc.CII` bei CII, `Doc.UBLInvoice` oder `Doc.UBLCreditNote`
bei UBL (keines mit `eio_InvoiceOnly`). Es sind unabhängige Kopien: Eine Änderung an einem ändert
das andere nicht.

## Lesen

| ZUGFeRD-for-Delphi | EInvoice for Pascal |
|---|---|
| `TZUGFeRDInvoiceDescriptor.Load(FileName)` | `Doc := TLandrixEInvoice.LoadFromFile(FileName)`, auch für ein ZUGFeRD-/Factur-X-PDF; `Doc` freigeben |
| `Load(Stream)` | `TLandrixEInvoice.LoadFromStream(Stream)` |
| `Load(IXMLDocument)` | keiner: kein MSXML; die Bytes (`LoadFromUtf8`) oder den Text (`LoadFromText`) übergeben |
| `GetVersion(FileName)` | `Doc.Info`: `SpecFound`, `Spec.Target` (Standard, Syntax, Profil), `CustomizationID` wie gelesen |
| das Profil des gelesenen Descriptors | `Doc.Info.Spec.Target.Profile` (bei einer XRechnung-Datei, UBL oder CII, ist `Standard` `est_XRechnung` und `Profile` `epr_None`: den Standard prüfen) |

`Spec.Target` nennt den Stand, den diese Bibliothek unterstützt (Factur-X 1.09), nicht den Stand
des Absenders: Eine ZUGFeRD-2.0- und eine 2.3-Datei ergeben dasselbe Ziel. ZUGFeRD-2.x-Dateien
der Profile MINIMUM, BASIC WL, BASIC, EN 16931, EXTENDED und XRechnung 3.0 werden erkannt (die
Kennungen `urn:zugferd.de:2p0:...` werden auf die Factur-X-Kennungen abgebildet; EN 16931 hat in
beiden dieselbe Kennung); Kennungen von XRechnung 1.x und 2.x sind unbekannt. Eine unbekannte Kennung wird trotzdem gelesen, mit einer Warnung und `SpecFound` False.
ZUGFeRD 1.0 wird nicht gelesen (`ELandrixEInvoiceFormatError`). Was der Descriptor nachsichtig
gelesen hat, steht in `Doc.Diagnostics`. Siehe [Lesen](reading.md).

## Schreiben

`Desc.Save(Stream, Version, Profile, Format, Options)` wird zu
`TLandrixEInvoice.SaveToStream(Invoice, Stream, Target, AOptions, ADiagnostics)` (oder
`SaveToFile`), mit einem Ziel aus `TLandrixEInvoiceTargets`; `AOptions` (Vorgabe `[]`) und
`ADiagnostics` (Vorgabe `nil`) treten an die Stelle der Format-Optionen:

| `TZUGFeRDProfile` | Ziel |
|---|---|
| `Minimum` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Minimum)` |
| `BasicWL` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_BasicWL)` |
| `Basic` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Basic)` |
| `Comfort` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931)` |
| `Extended` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended)` |
| `XRechnung` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_XRechnung)` (= XRechnung 3.0 CII) |
| `XRechnung1`, `EReporting` | keines |
| Format `UBL` (Profil XRechnung) | `TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)` oder `TLandrixEInvoiceTargets.PeppolBIS('3.0')` |

Geschrieben wird nur ZUGFeRD 2.5 / Factur-X 1.09: `ZUGFeRD('2.0', ...)` oder `('2.3', ...)` ergibt
ein Ziel, das das Schreiben ablehnt (`ELandrixEInvoiceTargetError`). Wer weiterhin ZUGFeRD 1.0,
2.0, 2.3, XRechnung 1.x oder 2.x oder E-Reporting senden muss, bleibt dafür bei ZUGFeRD-for-Delphi. Das
Schreiben einer `TLandrixInvoice` prüft zuerst die Geschäftsregeln des Ziels und verweigert eine
Rechnung mit Fehlern ([Schreiben](writing.md)); das Schreiben einer `TLandrixCIIInvoice` prüft
die Kennungen und bei den Factur-X-Profilen Profil und Factur-X-Codelisten, nicht die Geschäftsregeln.

## Prüfen und Summen

| ZUGFeRD-for-Delphi | EInvoice for Pascal |
|---|---|
| `TZUGFeRDInvoiceValidator.Validate(Desc, Version)` (rechnet die Summen nach, liefert Meldungen) | `TLandrixEInvoice.Check(Invoice, Target, [], Diagnostics)`: die Zahl der Fehler, die Befunde in `Diagnostics`, alle Geschäftsregeln des Ziels einschließlich der Summen ([Prüfen](checking.md)) |
| Summen, die das Programm rechnet | `TLandrixEInvoice.CalculateLineAmounts`, `CalculateTotals` ([Schreiben](writing.md#beträge-berechnen)) |
| (der KoSIT- oder Mustang-Validator, außerhalb der Bibliothek) | `TLandrixEInvoiceDocumentValidator`: die KoSIT-Konfigurationen nativ, ohne Java ([Validieren](validation.md)) |

## PDF

Das Lesen holt die Rechnung aus einem ZUGFeRD-/Factur-X-PDF: `LoadFromFile` löst bei einem PDF
ohne Rechnung `ELandrixEInvoicePdfError` aus; `TLandrixEInvoicePdfExtractor.ExtractInvoiceFromFile`
holt nur das XML heraus und liefert False mit dem Grund in seiner Info. Die Bibliothek schreibt kein
PDF: Für ein hybrides PDF bettet Ihre PDF-Bibliothek das XML unter dem Anhangsnamen des Ziels ein
(`Spec.AttachmentFileName`: `factur-x.xml`, `xrechnung.xml` bei XRechnung CII; XRechnung UBL und
Peppol BIS haben keinen), mit den
XMP-Metadaten von `LandrixEInvoicePdfXmpDescription(Target)`. `Spec` ist `Doc.Info.Spec` eines
gelesenen Dokuments oder kommt aus `LandrixEInvoiceFindSpec(Target, Spec)`.

## Unterschiede im Modell

- Keine Generics und kein `Nullable<T>`: Felder sind einfache Werte. Wo „nicht gesetzt“ und null
  sich unterscheiden (etwa bei optionalen Beträgen und Datumswerten), stehen kleine Werttypen
  (`TLandrixEInvoiceAmount`, `TLandrixEInvoiceDate` und weitere in `LandrixEInvoiceTypes`, mit
  `HasValue`, `SetValue`, `Clear`).
- Text ist `TLandrixEInvoiceString` (UTF-16 auf jedem Compiler). Die meisten Datumswerte sind
  `TDateTime`, 0 heißt nicht gesetzt; einige wenige sind `TLandrixEInvoiceDate` (etwa `OrderDate`,
  `TaxPointDate`).
- Codelisten sind Aufzählungen mit Umwandlungsfunktionen in `LandrixEInvoiceCodes`
  (`LandrixEInvoiceTypeCodeToStr`, `LandrixEInvoiceTypeCodeFromStr` usw.).
- Fehler sind Ausnahmen der Fassade: `ELandrixEInvoiceFormatError` (nicht lesbar),
  `ELandrixEInvoiceTargetError` (unbekanntes Ziel), `ELandrixEInvoiceWriteError` (wegen Fehlern
  verweigert).
- Die Bibliothek läuft unter Delphi 6 bis 13 und Free Pascal ab 3.2.2.
