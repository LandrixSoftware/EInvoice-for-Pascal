# Umstieg von XRechnung-for-Delphi

[English](../compat-xrechnung.md)

Die Kompatibilitäts-Units behalten die Namen von XRechnung-for-Delphi (`TInvoice`,
`TXRechnungInvoiceAdapter`, `TXRechnungVersion`, die Aufzählungswerte); der meiste Code übersetzt
deshalb, sobald die uses-Klausel geändert ist. Diese Seite nennt die Schritte, was wegfällt und was
sich anders verhält. [examples/CompatXRechnung](../../examples/CompatXRechnung/CompatXRechnung.dpr)
zeigt die Kompatibilitätsschicht in Aktion.

## Schritte

1. **Bibliothek holen** mit ihrem Submodul und `source` und `external/landrix-xml/source` in den
   Suchpfad aufnehmen ([Einstieg](getting-started.md#einrichtung)). Die alten Units aus dem
   Suchpfad nehmen, ebenso `intfMSXML2_TLB` (Delphi 6) und den Ordner `Distribution` mit den
   Java-Werkzeugen: davon wird nichts mehr gebraucht.
2. **uses-Klauseln ändern:**

   | Alte Unit | Neue Unit |
   |---|---|
   | `intf.Invoice` (Delphi 6: `intfInvoice`) | `LandrixEInvoiceCompatXRechnung` |
   | `intf.XRechnung` (Delphi 6: `intfXRechnung`) | `LandrixEInvoiceCompatXRechnungAdapter` |
   | `intf.XRechnungPdfExtract` | `LandrixEInvoiceCompatXRechnungPdf` |
   | `intf.XRechnungVersionInfo` | `LandrixEInvoiceTypes`: `LandrixEInvoiceVersion` (die eigene Versionsnummer der Bibliothek; Produktname und Release-Datum haben keine Entsprechung) |
   | `intf.XRechnungHelper`, `intf.XRechnung_3_0`, `intf.XRechnungXmlShim`, `intf.XRechnungValidationHelperJava` | keine, siehe unten |

3. **Beheben, was nicht mehr übersetzt**, mit der Tabelle [Was wegfällt](#was-wegfällt).
4. **Stringtypen prüfen.** Textfelder des Modells sind `TLandrixEInvoiceString`: `string` ab
   Delphi 2009, `WideString` unter Delphi 6 bis 2007, `UnicodeString` unter Free Pascal. Unter
   Free Pascal `_Error` und Dateinamen als `TXRechnungString` deklarieren.
5. **Den Java-Helper ersetzen** durch die nativen Funktionen ([Tabelle](#prüfen-und-anzeigen)).
6. **Die Ausgabe vergleichen.** Die Tests vergleichen die Ausgabe mit den 111 Beispieldateien von
   XRechnung-for-Delphi; sie weicht gewollt in zwei Punkten ab: Factur-X EXTENDED schreibt jede
   Objektkennung (BT-18), und Positionsgruppen werden flach geschrieben, wo das Ziel keine hat
   (Peppol BIS, XRechnung CII, Factur-X unter EXTENDED, UBL-Gutschriften; siehe
   [Unterpositionen](writing.md#unterpositionen-positionsgruppen)). Die
   [geänderten Verhaltensweisen](#geändertes-verhalten) lesen.
7. **Auf Wunsch auf die Fassade umstellen** ([Tabelle](#weiter-zur-fassade)), Schritt für Schritt:
   `TInvoice` ist `TLandrixInvoice`, dasselbe Objekt für beide.

## Was wegfällt

| Alt | Neu |
|---|---|
| `TXRechnungHelper` (in `intf.XRechnung`): `InvoiceTypeCodeToStr`, `...FromStr` und die übrigen Code-Umwandlungen | `LandrixEInvoiceTypeCodeToStr`, `LandrixEInvoiceTypeCodeFromStr(Code, out Value): Boolean` und dasselbe für jede Codeliste in `LandrixEInvoiceCodes`; der Positionsstatus (`InvoiceLineStatusReasonCode...`) in `LandrixEInvoiceInvoice` |
| `TXRechnungHelper.AmountToStr`, `DateToStrUBLFormat` und die übrigen Zahlen- und Datumsformate | kein öffentlicher Ersatz: die Bibliothek schreibt die XML-Formate selbst |
| `TXRechnungHelper.ReadPaymentTerms` | nicht nötig: das Lesen füllt Zahlungsbedingungen und Skonti des Modells aus dem `#SKONTO#`-Text |
| `TXRechnungXMLHelper` (`intf.XRechnungHelper`, MSXML) | keiner: kein MSXML |
| `TXRechnungValidationHelper.GetXRechnungVersion(IXMLDocument)` und weitere `IXMLDocument`-Überladungen | `GetXRechnungVersion(Stream)`, `GetXRechnungVersionFromString`; zum Lesen Streams, Dateien und Strings |
| `{$DEFINE ZUGFeRD_Support}`, `TZUGFeRDAdditionalContent`, `_AdditionalContent` | das CII-Syntaxmodell des gelesenen Dokuments (`Doc.CII`, bei CII-Dokumenten gesetzt), das alles hält, was Factur-X EXTENDED hat; der Rechnungsempfänger steht im Modell, Logistikkosten werden als Zu- und Abschläge gelesen (BG-21). Einen `TZUGFeRDInvoiceDescriptor` gibt es nicht, und ZUGFeRD 1.0, das dieser Schalter lesen konnte, wird nicht mehr gelesen |
| `TXRechnungPdfAttachment.Data` als `TBytes` | ein `TMemoryStream`, der dem Anhang gehört (die Extraktor-Funktionen liefern weiter `TBytes`) |
| `TInvoiceEmptyLeitwegID.NON_EXISTENT` in konstanten Ausdrücken | jetzt eine Klassenfunktion; in Konstanten `LandrixEInvoiceLeitwegIDNonExistent` verwenden |
| `TXRechnungInvoiceAdapter.ccOK` und die übrigen `ConsistencyCheck`-Codes als Klassenelemente | Unit-Konstanten (`ccOK`, wie in der Delphi-6-Fassung) |
| `GetXRechnungValidationHelperJava` | siehe die nächste Tabelle |

## Prüfen und anzeigen

Der Java-Helper wird nicht mehr gebraucht; Prüfung und Anzeige laufen im Programm
([Rechnungen validieren und anzeigen](validation.md)).

| Java-Helper (`intf.XRechnungValidationHelperJava`) | Nativ |
|---|---|
| `Validate`, `ValidateFile` (KoSIT-Validator, XML- und HTML-Bericht) | `TLandrixEInvoiceDocumentValidator` mit den KoSIT-Dateien von `addons/kosit/install-kosit.ps1`; Berichte `TLandrixEInvoiceValidationReportWriter` (XML) und `TLandrixEInvoiceValidationHtmlWriter` (HTML) |
| `Visualize`, `VisualizeFile`, `PeppolVisualize`, `PeppolVisualizeFile`, `MustangVisualizeFile` (HTML) | `TLandrixEInvoiceRenderHtmlWriter`, `TLandrixEInvoiceRenderMarkdownWriter`: eigenes Layout der Bibliothek, englisch oder deutsch |
| `MustangValidateFile` | teilweise: die PDF-Prüfung von `TLandrixEInvoiceDocumentValidator` (Einbettung und XMP-Metadaten); PDF/A wird nicht geprüft |
| `VisualizeAsPdf`, `VisualizeFileAsPdf`, `MustangVisualizeFileAsPdf`, `MustangCombinePdfAndXML`, `MustangUpgradeToPDFA3Only` | keiner: die Bibliothek schreibt kein PDF. Sie liefert XMP-Metadaten und Anhangsnamen für eine PDF-Bibliothek Ihrer Wahl (`ZUGFeRDPdfXmpInfo`, `ZUGFeRDPdfFilename` des Adapters; `LandrixEInvoicePdfXmpDescription(Target)` und `Spec.AttachmentFileName` in `LandrixEInvoiceSpecs`) |
| `ValitoolValidate`, `ValitoolValidateDirectory` | keiner |

Die Einstellmethoden des Helpers (`SetJavaRuntimeEnvironmentPath`, `SetValidatorLibPath` usw.)
fallen mit ihm weg. Die nativen Units sind eine Vorschau: dokumentiert und getestet, ihre Namen
können sich aber bis 1.0 noch ändern.

Das Beispielprojekt von XRechnung-for-Delphi (`Samples/XRechnungProject`) ersetzen
[examples/Workbench](../../examples/Workbench/Workbench.dpr) (ein Fenster, ohne Java) und
[examples/BusinessCases](../../examples/BusinessCases/BusinessCases.dpr) (die Geschäftsfälle aus
`XRechnungUnit2TestCases.pas`, für jedes Ziel geschrieben).

## Geändertes Verhalten

Lesen und Schreiben:

- `Save` und `Load` haben einen optionalen letzten Parameter `_Diagnostics`, der die Meldungen
  von Abbildung, Leser und Schreiber aufnimmt. In `LoadFromStream` und `LoadFromFile` folgt er auf
  `_ProcessPdfFiles`; Aufrufe, die die Meldungen als viertes Argument übergeben, brauchen
  dazwischen `False`.
- `Load` liefert False, wenn das Dokument nicht lesbar ist (nicht wohlgeformt, unbekanntes
  Format, ein PDF ohne Rechnung, Ausnahme), bei nil-Argumenten, leerem Dateinamen, fehlender Datei
  und leerem XML-Text; sonst True mit leerem `_Error`. Ein gescheitertes Laden lässt die Rechnung
  unverändert. Meldungen sind englisch; XML-Fehler beginnen mit `Not valid XML: ` (aus einem PDF:
  `Embedded file <Name>: Not valid XML: `).
- `Save` schreibt wie bisher, was die Abbildung ergibt; für eine Version, die sich nicht schreiben
  lässt, löst es `ELandrixEInvoiceError` aus. Es prüft die Geschäftsregeln nicht: dafür
  `TLandrixEInvoice.Check` oder die Fassade.
- Unter Delphi 6 bis 2007 liefert `SaveToXMLStr` UTF-8-Bytes (wie die XML-Deklaration sagt), und
  `LoadFromXMLStr` nimmt Bytes in der Kodierung der Deklaration. Wo `String` Unicode ist, nimmt
  `LoadFromXMLStr` dekodierten Text und beachtet die Deklaration nicht.
- Dateinamen sind Unicode, wo `TXRechnungString` Unicode ist (Delphi 2009+, Free Pascal).
- Wie bisher schreibt `SaveToFile` nichts für einen Dateinamen ohne Ordner.
- `PaymentTermNetNote` enthält die `#SKONTO#`-Zeilen eines Skontos nicht mehr; sie stehen in den
  Zahlungsbedingungen des Modells.
- `ConsistencyCheck` liefert `ccOK` statt `ccSubInvoiceLinesNotSupported` (11) für
  Positionsgruppen in einem Ziel ohne Gruppen: sie werden flach geschrieben, und die Meldungen
  nennen jede Gruppe (`edk_NotAllowed`). Code 11 bleibt für INFORMATION-Positionen auf oberster
  Ebene und für DETAIL-Positionen mit Unterpositionen außerhalb von Factur-X EXTENDED.

Das Modell:

- Die Preise `GrossPriceAmount`, `DiscountOnTheGrossPrice` und `NetPriceAmount` (BT-148, BT-147,
  BT-146) sind `Double` statt `Currency`: Code, der sie als `var`-Parameter oder an
  `Currency`-Routinen übergibt, muss angepasst werden.
- `EmbedDataFromText` schreibt UTF-8 ohne BOM (bisher UTF-16LE mit BOM ab Delphi 2009, ANSI unter
  Delphi 6); `EmbedDataFromFile` versucht es bei gesperrten Dateien nicht mehr erneut; ungültiges
  Base64 löst `ELandrixXmlError` aus; `TryAddAttachmentByExtension` setzt den Anhang bei einem
  Fehlschlag auf nil.
- `ClassName` liefert die neuen Namen (`TLandrixInvoice`).
- Aufzählungen über ihren Code speichern (`LandrixEInvoice...ToStr`), nicht über ihren Ordinalwert:
  die Ordinalwerte der Codelisten sind zwischen Versionen nicht stabil.

## Weiter zur Fassade

| Kompatibilitätsschicht | Fassade |
|---|---|
| `TXRechnungInvoiceAdapter.SaveToFile(Inv, XRechnungVersion_30x_UBL, Name)` | `TLandrixEInvoice.SaveToFile(Inv, Name, TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL))` |
| `XRechnungVersion_30x_UNCEFACT` | `TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)` |
| `ZUGFeRDEN16931Version_250` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931)` |
| `ZUGFeRDExtendedVersion_250` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended)` |
| `PeppolBillingVersion_30` | `TLandrixEInvoiceTargets.PeppolBIS('3.0')` |
| `LoadFromFile(Inv, Name, Error)` | `Doc := TLandrixEInvoice.LoadFromFile(Name)` (Ausnahmen statt `Error`); die Rechnung ist `Doc.Invoice`, `Doc.DetachInvoice` übergibt sie; `Doc` freigeben (`try ... finally Doc.Free; end`) |
| `GetXRechnungVersion(Name)` | nach dem Lesen: `if Doc.Info.SpecFound then Target := Doc.Info.Spec.Target` |
| `ConsistencyCheck(Inv, Version, Code)` | `TLandrixEInvoice.Check(Inv, Target) = 0` (alle Geschäftsregeln, mit Meldungen) |

Die Fassade prüft vor dem Schreiben die Geschäftsregeln und verweigert eine ungültige Rechnung;
siehe [Schreiben](writing.md). Die Kompatibilitätsschicht schreibt mit `[eio_NoRuleCheck,
eio_WriteDespiteErrors]`; mit diesen Optionen bleibt ihre Nachsicht erhalten.
