# Umstieg von XRechnung-for-Delphi

[English](../compat-xrechnung.md)

Code, der für XRechnung-for-Delphi geschrieben wurde, übersetzt mit dieser Bibliothek, wenn
sich die uses-Klausel ändert:

| Alte Unit | Neue Unit |
|---|---|
| `intf.Invoice` (Delphi 6: `intfInvoice`) | `LandrixEInvoiceCompatXRechnung` |
| `intf.XRechnung` (Delphi 6: `intfXRechnung`) | `LandrixEInvoiceCompatXRechnungAdapter` |
| `intf.XRechnungPdfExtract` | `LandrixEInvoiceCompatXRechnungPdf` (oder `LandrixEInvoicePdf`) |

`TInvoice` ist `TLandrixInvoice`; das Rechnungsmodell ist also in beiden Fällen dasselbe
Objekt, und Sie können Schritt für Schritt auf die Fassade `TLandrixEInvoice` umstellen. Siehe
[examples/CompatXRechnung](../../examples/CompatXRechnung/CompatXRechnung.dpr).

Die 111 Beispieldateien von XRechnung-for-Delphi entstehen inhaltlich gleich (zwei gewollte
Abweichungen: Factur-X EXTENDED schreibt jede Objektkennung, BT-18, und Peppol BIS schreibt
Positionsgruppen flach statt als `cac:SubInvoiceLine`, siehe [Schreiben](writing.md)). Die Geschäftsfälle stehen in
[examples/BusinessCases](../../examples/BusinessCases/BusinessCases.dpr).

## Unterschiede

- `Save` und `Load` haben einen optionalen letzten Parameter `_Diagnostics`, der die Meldungen
  von Abbildung, Leser und Schreiber aufnimmt. In `LoadFromStream` und `LoadFromFile` folgt er
  auf `_ProcessPdfFiles`; Aufrufe, die Meldungen als viertes Argument übergeben, brauchen
  dazwischen `False`.
- `Load` liefert False nur, wenn das Dokument nicht gelesen werden kann (nicht wohlgeformt,
  unbekanntes Format, Ausnahme); sonst True mit leerem `_Error`.
- `Save` schreibt wie bisher, was die Abbildung ergibt; bei einer nicht schreibbaren Version
  löst es `ELandrixEInvoiceError` aus. Es prüft keine Geschäftsregeln: dafür
  `TLandrixEInvoice.Check` oder die Fassade verwenden.
- Die `ConsistencyCheck`-Codes (`ccOK` ...) sind Unit-Konstanten wie in der Delphi-6-Fassung;
  `TXRechnungInvoiceAdapter.ccOK` übersetzt nicht.
- Unter Delphi 6 bis 2007 liefert `SaveToXMLStr` UTF-8-Bytes (wie die XML-Deklaration sagt),
  und `LoadFromXMLStr` nimmt Bytes in der Kodierung der Deklaration. Wo `String` Unicode ist,
  nimmt `LoadFromXMLStr` dekodierten Text und beachtet die Deklaration nicht.
- Dateinamen sind Unicode, wo `TXRechnungString` Unicode ist (Delphi 2009+, Free Pascal).
  Unter Free Pascal ist `TXRechnungString` ein `UnicodeString`: `_Error` und Dateinamen mit
  diesem Typ deklarieren.
- Keine `IXMLDocument`-Überladungen und keine Java-Validierung; Meldungen sind englisch.
- Wie bisher schreibt `SaveToFile` nichts für einen Dateinamen ohne Ordner.

## Weiter zur Fassade

| Kompatibilitätsschicht | Fassade |
|---|---|
| `TXRechnungInvoiceAdapter.SaveToFile(Inv, XRechnungVersion_30x_UBL, Name)` | `TLandrixEInvoice.SaveToFile(Inv, Name, TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL))` |
| `XRechnungVersion_30x_UNCEFACT` | `TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)` |
| `ZUGFeRDEN16931Version_250` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931)` |
| `ZUGFeRDExtendedVersion_250` | `TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended)` |
| `PeppolBillingVersion_30` | `TLandrixEInvoiceTargets.PeppolBIS('3.0')` |
| `LoadFromFile(Inv, Name, Error)` | `Doc := TLandrixEInvoice.LoadFromFile(Name)` (Ausnahmen statt `Error`) |
| `GetXRechnungVersion(Name)` | `Doc.Info.Spec.Target` nach dem Lesen |
| `ConsistencyCheck(Inv, Version)` | `TLandrixEInvoice.Check(Inv, Target)` (alle Geschäftsregeln) |

Die Fassade prüft vor dem Schreiben die Geschäftsregeln und verweigert eine ungültige
Rechnung; siehe [Schreiben](writing.md).
