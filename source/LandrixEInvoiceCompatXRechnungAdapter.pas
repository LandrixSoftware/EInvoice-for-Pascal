{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Compatibility with XRechnung-for-Delphi, second part (unit intf.XRechnung,
  intfXRechnung in its Delphi 6 version): the facade TXRechnungInvoiceAdapter
  with TXRechnungVersion, the version detection of TXRechnungValidationHelper
  and the ConsistencyCheck codes. Existing code compiles after replacing
  intf.XRechnung (or intfXRechnung) by LandrixEInvoiceCompatXRechnungAdapter
  and intf.Invoice by LandrixEInvoiceCompatXRechnung.

  Differences to the old unit:
  - The ConsistencyCheck codes (ccOK ...) are unit constants, as in the
    Delphi 6 version; TXRechnungInvoiceAdapter.ccOK does not compile.
  - Save and Load take an optional last parameter _Diagnostics that
    receives the messages of mapping, reader and writer. Save writes what
    the mapping produced, as before; Load returns False only when the
    document cannot be read (not well-formed, unknown format, exception).
    In LoadFromStream and LoadFromFile it follows _ProcessPdfFiles, so old
    calls with that flag compile unchanged.
  - On Delphi 6 to 2007 SaveToXMLStr returns UTF-8 bytes (as the XML
    declaration says) and LoadFromXMLStr takes bytes in the encoding of the
    declaration. Where String is Unicode, LoadFromXMLStr takes decoded text
    and does not consult the encoding declaration.
  - No IXMLDocument overloads, no Java validation. The PDF extraction is
    LandrixEInvoicePdf (old names: LandrixEInvoiceCompatXRechnungPdf).
  - Messages are English.
  - As before, SaveToFile writes nothing for a file name without folder.
    File names are opened through LandrixEInvoiceFiles, so Unicode names
    are kept where TXRechnungString is Unicode (Delphi 2009+, FPC).

  DE: Kompatibilitaet mit XRechnung-for-Delphi, zweiter Teil (Unit
  intf.XRechnung, in der Delphi-6-Fassung intfXRechnung): die Fassade
  TXRechnungInvoiceAdapter mit TXRechnungVersion, die Versionserkennung von
  TXRechnungValidationHelper und die ConsistencyCheck-Codes. Bestehender
  Code kompiliert, wenn intf.XRechnung (oder intfXRechnung) durch
  LandrixEInvoiceCompatXRechnungAdapter und intf.Invoice durch
  LandrixEInvoiceCompatXRechnung ersetzt wird.

  Unterschiede zur alten Unit:
  - Die ConsistencyCheck-Codes (ccOK ...) sind Unit-Konstanten wie in der
    Delphi-6-Fassung; TXRechnungInvoiceAdapter.ccOK kompiliert nicht.
  - Save und Load haben einen optionalen letzten Parameter _Diagnostics,
    der die Meldungen von Abbildung, Leser und Schreiber aufnimmt. Save
    schreibt wie bisher, was die Abbildung ergibt; Load liefert False nur,
    wenn das Dokument nicht gelesen werden kann (nicht wohlgeformt,
    unbekanntes Format, Ausnahme). In LoadFromStream und LoadFromFile folgt
    er auf _ProcessPdfFiles, damit alte Aufrufe mit diesem Schalter
    unveraendert kompilieren.
  - Unter Delphi 6 bis 2007 liefert SaveToXMLStr UTF-8-Bytes (wie die
    XML-Deklaration sagt), LoadFromXMLStr nimmt Bytes in der Kodierung der
    Deklaration. Wo String Unicode ist, nimmt LoadFromXMLStr dekodierten
    Text und beachtet die Kodierungsangabe nicht.
  - Keine IXMLDocument-Ueberladungen, keine Java-Validierung. Die
    PDF-Extraktion ist LandrixEInvoicePdf (alte Namen:
    LandrixEInvoiceCompatXRechnungPdf).
  - Meldungen sind englisch.
  - Wie bisher schreibt SaveToFile nichts fuer einen Dateinamen ohne
    Ordner. Dateinamen werden ueber LandrixEInvoiceFiles geoeffnet,
    Unicode-Namen bleiben also erhalten, wo TXRechnungString Unicode ist
    (Delphi 2009+, FPC). }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixEInvoiceCompatXRechnungAdapter;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice;

type
  { The String of the old units: they were compiled in DELPHIUNICODE mode
    under FPC, so out parameters match the callers' variables.
    DE: Das String der alten Units: sie wurden unter FPC im Modus
    DELPHIUNICODE uebersetzt, so passen out-Parameter zu den Variablen der
    Aufrufer. }
  {$IFDEF FPC}
  TXRechnungString = UnicodeString;
  {$ELSE}
  TXRechnungString = string;
  {$ENDIF}

  { Formats of XRechnung-for-Delphi, in the old order. Written are
    XRechnungVersion_30x_UBL, XRechnungVersion_30x_UNCEFACT,
    ZUGFeRDEN16931Version_250, ZUGFeRDExtendedVersion_250 and
    PeppolBillingVersion_30.
    DE: Formate von XRechnung-for-Delphi in der alten Reihenfolge.
    Geschrieben werden XRechnungVersion_30x_UBL,
    XRechnungVersion_30x_UNCEFACT, ZUGFeRDEN16931Version_250,
    ZUGFeRDExtendedVersion_250 und PeppolBillingVersion_30. }
  TXRechnungVersion = (
    XRechnungVersion_Unknown,
    XRechnungVersion_30x_UBL,
    XRechnungVersion_30x_UNCEFACT,
    ZUGFeRDEN16931Version_250,
    ZUGFeRDExtendedVersion_250,
    PeppolBillingVersion_30,
    { ZUGFeRD 1 (root CrossIndustryDocument), neither read nor written.
      DE: ZUGFeRD 1 (Wurzel CrossIndustryDocument), weder gelesen noch
      geschrieben. }
    ZUGFeRDExtendedVersion_1_NotSupported,
    { Older XRechnung versions and other EN 16931 CIUS in UBL; read only.
      DE: Aeltere XRechnung-Versionen und andere EN-16931-CIUS in UBL; nur
      gelesen. }
    XRechnungVersion_2x_ReadingOnly
  );

const
  { Results of TXRechnungInvoiceAdapter.ConsistencyCheck.
    DE: Ergebnisse von TXRechnungInvoiceAdapter.ConsistencyCheck. }
  ccOK = 0;
  { No payment instruction (not required for ZUGFeRD EN16931).
    DE: Keine Zahlungsanweisung (fuer ZUGFeRD EN16931 nicht noetig). }
  ccNoPaymentsCount = 1;
  { Invoice type not supported by XRechnung (84, 261, 383, 386, 457).
    DE: Rechnungsart in XRechnung nicht unterstuetzt (84, 261, 383, 386,
    457). }
  ccInvoiceTypeNotSupported = 2;
  { More preceding invoices than the format allows (rule table).
    DE: Mehr vorausgegangene Rechnungen, als das Format erlaubt
    (Regel-Tabelle). }
  ccTooManyPrecedingInvoices = 3;
  { More than one SEPA direct debit. DE: Mehr als eine SEPA-Lastschrift. }
  ccTooManySEPADirectDebit = 4;
  { More than one credit card. DE: Mehr als eine Kreditkarte. }
  ccTooManyCreditCard = 5;
  { Seller without VAT identifier (BT-31) and legal registration (BT-30).
    DE: Verkaeufer ohne USt-IdNr. (BT-31) und Registernummer (BT-30). }
  ccNoBT31BT30 = 6;
  { Seller without VAT identifier (BT-31) and tax number (BT-32).
    DE: Verkaeufer ohne USt-IdNr. (BT-31) und Steuernummer (BT-32). }
  ccNoBT31BT32 = 7;
  { Third-party payments (BG-DEX-09) the format does not allow (rule table).
    DE: Zahlungen Dritter (BG-DEX-09), die das Format nicht erlaubt
    (Regel-Tabelle). }
  ccPrepaidPaymentNotSupported = 8;
  { Peppol: electronic address with scheme EM or without scheme.
    DE: Peppol: elektronische Adresse mit Schema EM oder ohne Schema. }
  ccNoEMUnderPeppol = 9;
  { Delivery note or date per line outside Factur-X EXTENDED (rule table).
    DE: Lieferschein oder Lieferdatum je Position ausserhalb von Factur-X
    EXTENDED (Regel-Tabelle). }
  ccLineDeliveryOnlyExtended = 10;
  { Sub lines the format does not allow (rule table), or INFORMATION lines
    on the top level or DETAIL lines with sub lines outside EXTENDED.
    DE: Unterpositionen, die das Format nicht erlaubt (Regel-Tabelle), oder
    INFORMATION-Positionen auf oberster Ebene bzw. DETAIL-Positionen mit
    Unterpositionen ausserhalb von EXTENDED. }
  ccSubInvoiceLinesNotSupported = 11;
  { EXTENDED: amount of a GROUP line differs from the sum of its sub lines
    (BR-FXEXT-08). DE: EXTENDED: Betrag einer GROUP-Position ungleich der
    Summe ihrer Unterpositionen (BR-FXEXT-08). }
  ccSubInvoiceLineAmountMismatch = 12;

  { Name of the invoice in a Factur-X / ZUGFeRD PDF (also XRechnung CII
    outside the profile XRECHNUNG). DE: Name der Rechnung in einem
    Factur-X-/ZUGFeRD-PDF (auch XRechnung CII ausserhalb des Profils
    XRECHNUNG). }
  ZUGFERD_INVOICE_PDF_FILENAME_FACTURX = 'factur-x.xml';
  { Name of the invoice in a PDF with the profile XRECHNUNG (CII).
    DE: Name der Rechnung in einem PDF mit dem Profil XRECHNUNG (CII). }
  ZUGFERD_INVOICE_PDF_FILENAME_XRECHNUNG = 'xrechnung.xml';
  { XMP description for the profile EXTENDED only; other profiles:
    TXRechnungInvoiceAdapter.ZUGFeRDPdfXmpInfo (core:
    LandrixEInvoicePdfXmpDescription).
    DE: XMP-Beschreibung nur fuer das Profil EXTENDED; andere Profile:
    TXRechnungInvoiceAdapter.ZUGFeRDPdfXmpInfo (Kern:
    LandrixEInvoicePdfXmpDescription). }
  ZUGFERD_INVOICE_PDF_XMP_INFO =
    '<rdf:Description xmlns:fx="urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#" rdf:about="">' + #10 +
    '<fx:DocumentType>INVOICE</fx:DocumentType>' + #10 +
    '<fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>' + #10 +
    '<fx:Version>1.0</fx:Version>' + #10 +
    '<fx:ConformanceLevel>EXTENDED</fx:ConformanceLevel></rdf:Description>';
  { XMP extension schema (prefix fx); same as LandrixEInvoicePdfXmpSchema.
    DE: XMP-Erweiterungsschema (Praefix fx); gleich
    LandrixEInvoicePdfXmpSchema. }
  ZUGFERD_INVOICE_PDF_SCHEMA = LandrixEInvoicePdfXmpSchema;

type
  { Version detection. DE: Versionserkennung. }
  TXRechnungValidationHelper = class(TObject)
  public
    { Format of a file, a stream (its position is kept) or an XML text, by
      root element and specification identifier (BT-24) as in
      XRechnung-for-Delphi; XRechnungVersion_Unknown if not readable.
      DE: Format einer Datei, eines Datenstroms (seine Position bleibt
      erhalten) oder eines XML-Texts, nach Wurzelelement und
      Spezifikationskennung (BT-24) wie in XRechnung-for-Delphi;
      XRechnungVersion_Unknown, wenn nicht lesbar. }
    { With _ProcessPdfFiles a ZUGFeRD or Factur-X PDF is recognized and the
      version of its embedded invoice returned.
      DE: Mit _ProcessPdfFiles wird ein ZUGFeRD- oder Factur-X-PDF erkannt
      und die Version seiner eingebetteten Rechnung geliefert. }
    class function GetXRechnungVersion(const _Filename: TXRechnungString;
      _ProcessPdfFiles: Boolean = False): TXRechnungVersion; overload;
    class function GetXRechnungVersion(_Stream: TStream; _ProcessPdfFiles: Boolean = False): TXRechnungVersion; overload;
    class function GetXRechnungVersionFromString(const _XML: TXRechnungString): TXRechnungVersion;
  end;

  { Reading and writing as in XRechnung-for-Delphi.
    DE: Lesen und Schreiben wie in XRechnung-for-Delphi. }
  TXRechnungInvoiceAdapter = class(TObject)
  public
    { Checks what XRechnung-for-Delphi checked before writing _Version;
      _ErrorCode is the first failing cc... code (ccOK if none).
      DE: Prueft, was XRechnung-for-Delphi vor dem Schreiben von _Version
      pruefte; _ErrorCode ist der erste verletzte cc...-Code (ccOK, wenn
      keiner). }
    class function ConsistencyCheck(_Invoice: TLandrixInvoice; _Version: TXRechnungVersion): Boolean; overload;
    class function ConsistencyCheck(_Invoice: TLandrixInvoice; _Version: TXRechnungVersion;
      out _ErrorCode: Integer): Boolean; overload;
    { XMP description (rdf:Description) for a ZUGFeRD / Factur-X PDF/A-3 per
      version: EN 16931 and EXTENDED (factur-x.xml), XRECHNUNG for
      XRechnungVersion_30x_UNCEFACT (xrechnung.xml); '' for UBL and other
      versions. Delegates to LandrixEInvoicePdfXmpDescription.
      DE: XMP-Beschreibung (rdf:Description) fuer ein ZUGFeRD-/Factur-X-
      PDF/A-3 je Version: EN 16931 und EXTENDED (factur-x.xml), XRECHNUNG
      fuer XRechnungVersion_30x_UNCEFACT (xrechnung.xml); '' fuer UBL und
      andere Versionen. Gibt an LandrixEInvoicePdfXmpDescription weiter. }
    class function ZUGFeRDPdfXmpInfo(_Version: TXRechnungVersion): TXRechnungString;
    { Name of the invoice in the PDF for _Version ('' for UBL and other
      versions). DE: Name der Rechnung im PDF fuer _Version ('' fuer UBL und
      andere Versionen). }
    class function ZUGFeRDPdfFilename(_Version: TXRechnungVersion): TXRechnungString;
    { Without due date: issue date + 30 days, or one day after the longest
      cash discount period if that is later.
      DE: Ohne Faelligkeitsdatum: Rechnungsdatum + 30 Tage, oder einen Tag
      nach der laengsten Skontofrist, wenn diese spaeter endet. }
    class procedure CorrectDueDateIfNotDefined(_Invoice: TLandrixInvoice);

    { Write _Invoice as _Version (UTF-8 without BOM). Raise
      ELandrixEInvoiceError for a version that cannot be written. SaveToFile
      does nothing if the folder does not exist.
      DE: Schreiben _Invoice als _Version (UTF-8 ohne BOM). Loesen
      ELandrixEInvoiceError bei einer nicht schreibbaren Version aus.
      SaveToFile tut nichts, wenn der Ordner nicht existiert. }
    class procedure SaveToStream(_Invoice: TLandrixInvoice; _Version: TXRechnungVersion; _Stream: TStream;
      _Diagnostics: TLandrixEInvoiceDiagnostics = nil);
    class procedure SaveToFile(_Invoice: TLandrixInvoice; _Version: TXRechnungVersion;
      const _Filename: TXRechnungString; _Diagnostics: TLandrixEInvoiceDiagnostics = nil);
    class procedure SaveToXMLStr(_Invoice: TLandrixInvoice; _Version: TXRechnungVersion;
      out _XML: TXRechnungString; _Diagnostics: TLandrixEInvoiceDiagnostics = nil);

    { Replace the content of _Invoice with an invoice in UBL or CII (any
      known root, also with an unknown specification identifier). False
      with _Error if the document cannot be read.
      DE: Ersetzen den Inhalt von _Invoice durch eine Rechnung in UBL oder
      CII (jede bekannte Wurzel, auch mit unbekannter
      Spezifikationskennung). False mit _Error, wenn das Dokument nicht
      gelesen werden kann. }
    { With _ProcessPdfFiles a PDF (recognized by %PDF- at the start) is read
      through LoadFromPdfStream / LoadFromPdfFile.
      DE: Mit _ProcessPdfFiles wird ein PDF (erkannt an %PDF- am Anfang)
      ueber LoadFromPdfStream / LoadFromPdfFile gelesen. }
    class function LoadFromStream(_Invoice: TLandrixInvoice; _Stream: TStream; out _Error: TXRechnungString;
      _ProcessPdfFiles: Boolean = False; _Diagnostics: TLandrixEInvoiceDiagnostics = nil): Boolean;
    class function LoadFromFile(_Invoice: TLandrixInvoice; const _Filename: TXRechnungString;
      out _Error: TXRechnungString; _ProcessPdfFiles: Boolean = False;
      _Diagnostics: TLandrixEInvoiceDiagnostics = nil): Boolean;
    class function LoadFromXMLStr(_Invoice: TLandrixInvoice; const _XML: TXRechnungString;
      out _Error: TXRechnungString; _Diagnostics: TLandrixEInvoiceDiagnostics = nil): Boolean;

    { Read the invoice embedded in a ZUGFeRD or Factur-X PDF (see
      LandrixEInvoicePdf); _AttachmentName is the name of the embedded file,
      e.g. factur-x.xml. The stream is read from its position to the end.
      DE: Lesen die in ein ZUGFeRD- oder Factur-X-PDF eingebettete Rechnung
      (siehe LandrixEInvoicePdf); _AttachmentName ist der Name der
      eingebetteten Datei, z. B. factur-x.xml. Der Datenstrom wird ab seiner
      Position bis zum Ende gelesen. }
    class function LoadFromPdfStream(_Invoice: TLandrixInvoice; _Stream: TStream; out _Error: TXRechnungString;
      out _AttachmentName: TXRechnungString; _Diagnostics: TLandrixEInvoiceDiagnostics = nil): Boolean;
    class function LoadFromPdfFile(_Invoice: TLandrixInvoice; const _Filename: TXRechnungString;
      out _Error: TXRechnungString; out _AttachmentName: TXRechnungString;
      _Diagnostics: TLandrixEInvoiceDiagnostics = nil): Boolean;
  end;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceCheck,
  LandrixEInvoicePdf,
  LandrixEInvoiceFiles,
  LandrixEInvoice;

{ --- helpers ---------------------------------------------------------------- }

function CompatText(const S: string): TXRechnungString;
begin
  Result := TXRechnungString(S);
end;

{ The folder of a file name with its trailing delimiter, as ExtractFilePath;
  '' without folder. }
function FolderOf(const S: TXRechnungString): TXRechnungString;
var
  I: Integer;
begin
  I := Length(S);
  while (I > 0) and (S[I] <> '/') and (S[I] <> PathDelim) and
    ((S[I] <> ':') or (PathDelim = '/')) do
    Dec(I);
  Result := Copy(S, 1, I);
end;

{ The XML text of the caller as bytes: UTF-8 of the Unicode text, or the
  bytes as they are where String is an AnsiString.
  DE: Der XML-Text des Aufrufers als Bytes: UTF-8 des Unicode-Texts oder
  die Bytes, wie sie sind, wo String ein AnsiString ist. }
function XmlBytes(const S: TXRechnungString): TLandrixXmlUtf8;
begin
  {$IF Defined(FPC) or Defined(LANDRIXEINVOICE_UNICODE)}
  Result := LandrixEInvoiceStringToUtf8(TLandrixEInvoiceString(S));
  {$ELSE}
  Result := S;
  {$IFEND}
end;

function XmlText(const S: TLandrixXmlUtf8): TXRechnungString;
begin
  {$IF Defined(FPC) or Defined(LANDRIXEINVOICE_UNICODE)}
  Result := TXRechnungString(LandrixEInvoiceUtf8ToString(S));
  {$ELSE}
  Result := S;
  {$IFEND}
end;

function LowerAscii(const S: TLandrixXmlUtf8): AnsiString;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    if (S[I] >= 'A') and (S[I] <= 'Z') then
      Result[I] := AnsiChar(Ord(S[I]) + 32)
    else
      Result[I] := AnsiChar(S[I]);
end;

function ContainsAscii(const AText, ASub: AnsiString): Boolean;
begin
  Result := Pos(ASub, AText) > 0;
end;

{ Advances AReader to the root element; False if there is none.
  DE: Bewegt AReader auf das Wurzelelement; False, wenn es keines gibt. }
function MoveToRoot(AReader: TLandrixXmlReader): Boolean;
begin
  while AReader.TokenType <> xttStartElement do
    if not AReader.Read then
    begin
      Result := False;
      Exit;
    end;
  Result := True;
end;

{ On a start element: moves to its child with ALocalName (False at the end
  of the parent). DE: Auf einem Startelement: geht zu dessen Kind mit
  ALocalName (False am Ende des Elternelements). }
function MoveToChild(AReader: TLandrixXmlReader; const ALocalName: TLandrixXmlUtf8): Boolean;
begin
  Result := False;
  if AReader.IsEmptyElement then
    Exit;
  while AReader.Read do
    case AReader.TokenType of
      xttStartElement:
        if LandrixXmlSpanEquals(AReader.LocalNameSpan, ALocalName) then
        begin
          Result := True;
          Exit;
        end
        else
          AReader.Skip;
      xttEndElement:
        Exit;
    else
      ;
    end;
end;

{ Format by root element and BT-24, as TXRechnungValidationHelper did:
  substrings of the lower-case identifier.
  DE: Format nach Wurzelelement und BT-24, wie TXRechnungValidationHelper es
  tat: Teiltexte der klein geschriebenen Kennung. }
function VersionOf(AReader: TLandrixXmlReader): TXRechnungVersion;
var
  ID: AnsiString;
begin
  Result := XRechnungVersion_Unknown;
  if not MoveToRoot(AReader) then
    Exit;
  if LandrixXmlSpanEquals(AReader.LocalNameSpan, 'Invoice') or
     LandrixXmlSpanEquals(AReader.LocalNameSpan, 'CreditNote') then
  begin
    if not MoveToChild(AReader, 'CustomizationID') then
      Exit;
    ID := LowerAscii(AReader.ReadElementTextUtf8);
    if ContainsAscii(ID, 'xrechnung_3.0') then
      Result := XRechnungVersion_30x_UBL
    else if ContainsAscii(ID, 'billing:3.0') then
      Result := PeppolBillingVersion_30
    else if ContainsAscii(ID, 'urn:cen.eu:en16931:2017') then
      Result := XRechnungVersion_2x_ReadingOnly;
  end
  else if LandrixXmlSpanEquals(AReader.LocalNameSpan, 'CrossIndustryInvoice') then
  begin
    if not (MoveToChild(AReader, 'ExchangedDocumentContext') and
            MoveToChild(AReader, 'GuidelineSpecifiedDocumentContextParameter') and
            MoveToChild(AReader, 'ID')) then
      Exit;
    ID := LowerAscii(AReader.ReadElementTextUtf8);
    if ContainsAscii(ID, 'xrechnung_3.0') then
      Result := XRechnungVersion_30x_UNCEFACT
    else if ID = 'urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended' then
      Result := ZUGFeRDExtendedVersion_250
    else if ContainsAscii(ID, 'urn:cen.eu:en16931:2017') then
      Result := ZUGFeRDEN16931Version_250;
  end
  else if LandrixXmlSpanEquals(AReader.LocalNameSpan, 'CrossIndustryDocument') then
    Result := ZUGFeRDExtendedVersion_1_NotSupported;
end;

{ The specification entry a writable version stands for.
  DE: Der Spezifikationseintrag, fuer den eine schreibbare Version steht. }
function SpecOf(AVersion: TXRechnungVersion; out ASpec: TLandrixEInvoiceSpec): Boolean;
var
  Target: TLandrixEInvoiceTarget;
begin
  case AVersion of
    XRechnungVersion_30x_UBL: Target := TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL);
    XRechnungVersion_30x_UNCEFACT: Target := TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII);
    ZUGFeRDEN16931Version_250: Target := TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931);
    ZUGFeRDExtendedVersion_250: Target := TLandrixEInvoiceTargets.FacturX('1.09', epr_Extended);
    PeppolBillingVersion_30: Target := TLandrixEInvoiceTargets.PeppolBIS('3.0');
  else
    begin
      { a target without entry: ASpec becomes the empty entry }
      LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.PeppolBIS(''), ASpec);
      Result := False;
      Exit;
    end;
  end;
  Result := LandrixEInvoiceFindSpec(Target, ASpec);
end;

{ Maps and writes _Invoice through the facade as before: no business rule
  check, written despite errors (they are in the diagnostics); the old
  SaveDocument raised for other versions.
  DE: Bildet ab und schreibt _Invoice wie bisher ueber die Fassade: ohne
  Pruefung der Geschaeftsregeln, trotz Fehlern geschrieben (sie stehen in
  den Meldungen); das alte SaveDocument loeste bei anderen Versionen eine
  Ausnahme aus. }
function SaveToUtf8(AInvoice: TLandrixInvoice; AVersion: TXRechnungVersion;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  Spec: TLandrixEInvoiceSpec;
begin
  if not SpecOf(AVersion, Spec) then
    raise ELandrixEInvoiceError.Create('TXRechnungInvoiceAdapter: version ' + IntToStr(Ord(AVersion)) +
      ' cannot be written');
  Result := TLandrixEInvoice.SaveToUtf8(AInvoice, Spec.Target, [eio_NoRuleCheck, eio_WriteDespiteErrors],
    ADiagnostics);
end;

{ Reads the XML in AStream (from its position) or, with AStream = nil, the
  decoded text AText through the facade into AInvoice, which stays
  unchanged on failure; XML errors start with 'Not valid XML: '.
  DE: Liest das XML in AStream (ab seiner Position) oder, mit AStream =
  nil, den dekodierten Text AText ueber die Fassade in AInvoice, das bei
  einem Fehler unveraendert bleibt; XML-Fehler beginnen mit
  'Not valid XML: '. }
function ReadXml(AInvoice: TLandrixInvoice; AStream: TStream; const AText: TLandrixEInvoiceString;
  out AError: TXRechnungString; ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;
const
  NotWellFormed = 'Not well-formed XML: ';
var
  Doc: TLandrixEInvoiceDocument;
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixEInvoiceDiagnostic;
  Text: string;
begin
  Result := False;
  AError := '';
  try
    if AStream <> nil then
      Doc := TLandrixEInvoice.LoadFromStream(AStream, [eio_NoPdf])
    else
      Doc := TLandrixEInvoice.LoadFromText(AText, [eio_NoPdf]);
    try
      AInvoice.Assign(Doc.Invoice);
      if ADiagnostics <> nil then
        for I := 0 to Doc.Diagnostics.Count - 1 do
        begin
          Item := ADiagnostics.AddDiagnostic(Doc.Diagnostics[I].Kind, Doc.Diagnostics[I].Path,
            Doc.Diagnostics[I].Line, Doc.Diagnostics[I].Column, Doc.Diagnostics[I].Offset,
            Doc.Diagnostics[I].Message);
          Item.Severity := Doc.Diagnostics[I].Severity;
          Item.RuleID := Doc.Diagnostics[I].RuleID;
        end;
    finally
      Doc.Free;
    end;
    Result := True;
  except
    on E: ELandrixEInvoiceFormatError do
    begin
      Text := E.Message;
      if Copy(Text, 1, Length(NotWellFormed)) = NotWellFormed then
        Text := 'Not valid XML: ' + Copy(Text, Length(NotWellFormed) + 1, Length(Text));
      AError := CompatText(Text);
    end;
    on E: Exception do
      AError := CompatText(E.ClassName + ': ' + E.Message);
  end;
end;

function ReadXmlStream(AInvoice: TLandrixInvoice; AStream: TStream; out AError: TXRechnungString;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;
begin
  Result := ReadXml(AInvoice, AStream, '', AError, ADiagnostics);
end;

{ --- TXRechnungValidationHelper --------------------------------------------- }

class function TXRechnungValidationHelper.GetXRechnungVersion(const _Filename: TXRechnungString;
  _ProcessPdfFiles: Boolean): TXRechnungVersion;
var
  Stream: TStream;
begin
  Result := XRechnungVersion_Unknown;
  if not LandrixEInvoiceFileExists(_Filename) then
    Exit;
  try
    Stream := LandrixEInvoiceOpenFile(_Filename, efm_Read);
    try
      Result := GetXRechnungVersion(Stream, _ProcessPdfFiles);
    finally
      Stream.Free;
    end;
  except
    on Exception do
      Result := XRechnungVersion_Unknown;
  end;
end;

class function TXRechnungValidationHelper.GetXRechnungVersion(_Stream: TStream;
  _ProcessPdfFiles: Boolean): TXRechnungVersion;
var
  R: TLandrixXmlReader;
  Position: Int64;
  Xml: TMemoryStream;
  Name: TLandrixEInvoiceString;
  Info: TLandrixEInvoicePdfExtractInfo;
begin
  Result := XRechnungVersion_Unknown;
  if _Stream = nil then
    Exit;
  Position := _Stream.Position;
  if _ProcessPdfFiles and TLandrixEInvoicePdfExtractor.IsPdfStream(_Stream) then
  begin
    Xml := TMemoryStream.Create;
    try
      if TLandrixEInvoicePdfExtractor.ExtractInvoiceFromStream(_Stream, Xml, Name, Info) then
      begin
        Xml.Position := 0;
        Result := GetXRechnungVersion(Xml, False);
      end;
    finally
      Xml.Free;
      _Stream.Position := Position;
    end;
    Exit;
  end;
  R := TLandrixXmlReader.Create;
  try
    try
      R.LoadFromStream(_Stream);
      Result := VersionOf(R);
    except
      on Exception do
        Result := XRechnungVersion_Unknown;
    end;
  finally
    R.Free;
    _Stream.Position := Position;
  end;
end;

class function TXRechnungValidationHelper.GetXRechnungVersionFromString(const _XML: TXRechnungString): TXRechnungVersion;
var
  R: TLandrixXmlReader;
  Bytes: TLandrixXmlUtf8;
begin
  Result := XRechnungVersion_Unknown;
  if _XML = '' then
    Exit;
  R := TLandrixXmlReader.Create;
  try
    try
      Bytes := XmlBytes(_XML);
      { as LoadFromXMLStr: Unicode text without the encoding declaration
        DE: wie LoadFromXMLStr: Unicode-Text ohne die Kodierungsangabe }
      {$IF Defined(FPC) or Defined(LANDRIXEINVOICE_UNICODE)}
      R.LoadFromUtf8(Bytes);
      {$ELSE}
      R.LoadFromBuffer(PAnsiChar(Bytes)^, Length(Bytes));
      {$IFEND}
      Result := VersionOf(R);
    except
      on Exception do
        Result := XRechnungVersion_Unknown;
    end;
  finally
    R.Free;
  end;
end;

{ --- ConsistencyCheck --------------------------------------------------------- }

class function TXRechnungInvoiceAdapter.ZUGFeRDPdfXmpInfo(_Version: TXRechnungVersion): TXRechnungString;
var
  Spec: TLandrixEInvoiceSpec;
begin
  if SpecOf(_Version, Spec) then
    Result := LandrixEInvoicePdfXmpDescription(Spec.Target)
  else
    Result := '';
end;

class function TXRechnungInvoiceAdapter.ZUGFeRDPdfFilename(_Version: TXRechnungVersion): TXRechnungString;
var
  Spec: TLandrixEInvoiceSpec;
begin
  if SpecOf(_Version, Spec) then
    Result := Spec.AttachmentFileName
  else
    Result := '';
end;

class function TXRechnungInvoiceAdapter.ConsistencyCheck(_Invoice: TLandrixInvoice;
  _Version: TXRechnungVersion): Boolean;
var
  ErrorCode: Integer;
begin
  Result := ConsistencyCheck(_Invoice, _Version, ErrorCode);
end;

{ The checks of XRechnung-for-Delphi in their order: the rules LX-CC-01 to
  LX-CC-12 of LandrixEInvoiceCheck, LX-CC-nn being the old code nn. A
  version that cannot be written (Unknown, ZUGFeRD 1, XRechnung 2.x) is
  checked against the empty entry, so third-party payments and line
  delivery data fail as before.
  DE: Die Pruefungen von XRechnung-for-Delphi in ihrer Reihenfolge: die
  Regeln LX-CC-01 bis LX-CC-12 aus LandrixEInvoiceCheck, LX-CC-nn ist der
  alte Code nn. Eine nicht schreibbare Version (Unknown, ZUGFeRD 1,
  XRechnung 2.x) wird gegen den leeren Eintrag geprueft, Zahlungen Dritter
  und Lieferdaten je Position scheitern also wie bisher. }
class function TXRechnungInvoiceAdapter.ConsistencyCheck(_Invoice: TLandrixInvoice;
  _Version: TXRechnungVersion; out _ErrorCode: Integer): Boolean;
const
  RuleIDs: array[ccNoPaymentsCount..ccSubInvoiceLineAmountMismatch] of string = (
    'LX-CC-01', 'LX-CC-02', 'LX-CC-03', 'LX-CC-04', 'LX-CC-05', 'LX-CC-06',
    'LX-CC-07', 'LX-CC-08', 'LX-CC-09', 'LX-CC-10', 'LX-CC-11', 'LX-CC-12');
var
  Spec: TLandrixEInvoiceSpec;
  Code: Integer;
begin
  SpecOf(_Version, Spec);
  for Code := Low(RuleIDs) to High(RuleIDs) do
    if not LandrixEInvoiceCheckRule(_Invoice, Spec, TLandrixEInvoiceString(RuleIDs[Code]), nil) then
    begin
      _ErrorCode := Code;
      Result := False;
      Exit;
    end;
  _ErrorCode := ccOK;
  Result := True;
end;

class procedure TXRechnungInvoiceAdapter.CorrectDueDateIfNotDefined(_Invoice: TLandrixInvoice);
var
  Days: Integer;
begin
  if _Invoice.InvoiceDueDate <> 0 then
    Exit;
  _Invoice.InvoiceDueDate := _Invoice.InvoiceIssueDate + 30;
  case _Invoice.PaymentTermsType of
    iptt_CashDiscount1: Days := _Invoice.PaymentTermCashDiscount1Days;
    iptt_CashDiscount2: Days := _Invoice.PaymentTermCashDiscount2Days;
    iptt_CashDiscount3: Days := _Invoice.PaymentTermCashDiscount3Days;
  else
    Days := -1;
  end;
  if (Days >= 0) and (_Invoice.InvoiceDueDate <= _Invoice.InvoiceIssueDate + Days) then
    _Invoice.InvoiceDueDate := _Invoice.InvoiceIssueDate + Days + 1;
end;

{ --- saving and loading ------------------------------------------------------- }

class procedure TXRechnungInvoiceAdapter.SaveToStream(_Invoice: TLandrixInvoice; _Version: TXRechnungVersion;
  _Stream: TStream; _Diagnostics: TLandrixEInvoiceDiagnostics);
var
  Bytes: TLandrixXmlUtf8;
begin
  if (_Invoice = nil) or (_Stream = nil) then
    Exit;
  Bytes := SaveToUtf8(_Invoice, _Version, _Diagnostics);
  if Bytes <> '' then
    _Stream.WriteBuffer(PAnsiChar(Bytes)^, Length(Bytes));
end;

class procedure TXRechnungInvoiceAdapter.SaveToFile(_Invoice: TLandrixInvoice; _Version: TXRechnungVersion;
  const _Filename: TXRechnungString; _Diagnostics: TLandrixEInvoiceDiagnostics);
var
  Bytes: TLandrixXmlUtf8;
  Stream: TStream;
begin
  if (_Invoice = nil) or (_Filename = '') then
    Exit;
  if (FolderOf(_Filename) = '') or not LandrixEInvoiceDirectoryExists(FolderOf(_Filename)) then
    Exit;
  Bytes := SaveToUtf8(_Invoice, _Version, _Diagnostics);
  Stream := LandrixEInvoiceOpenFile(_Filename, efm_Create);
  try
    if Bytes <> '' then
      Stream.WriteBuffer(PAnsiChar(Bytes)^, Length(Bytes));
  finally
    Stream.Free;
  end;
end;

class procedure TXRechnungInvoiceAdapter.SaveToXMLStr(_Invoice: TLandrixInvoice; _Version: TXRechnungVersion;
  out _XML: TXRechnungString; _Diagnostics: TLandrixEInvoiceDiagnostics);
begin
  _XML := '';
  if _Invoice = nil then
    Exit;
  _XML := XmlText(SaveToUtf8(_Invoice, _Version, _Diagnostics));
end;

class function TXRechnungInvoiceAdapter.LoadFromStream(_Invoice: TLandrixInvoice; _Stream: TStream;
  out _Error: TXRechnungString; _ProcessPdfFiles: Boolean; _Diagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  AttachmentName: TXRechnungString;
begin
  Result := False;
  _Error := '';
  if (_Invoice = nil) or (_Stream = nil) then
    Exit;
  if _ProcessPdfFiles and TLandrixEInvoicePdfExtractor.IsPdfStream(_Stream) then
  begin
    Result := LoadFromPdfStream(_Invoice, _Stream, _Error, AttachmentName, _Diagnostics);
    Exit;
  end;
  Result := ReadXmlStream(_Invoice, _Stream, _Error, _Diagnostics);
end;

class function TXRechnungInvoiceAdapter.LoadFromFile(_Invoice: TLandrixInvoice; const _Filename: TXRechnungString;
  out _Error: TXRechnungString; _ProcessPdfFiles: Boolean; _Diagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  AttachmentName: TXRechnungString;
  Stream: TStream;
begin
  Result := False;
  _Error := '';
  if (_Invoice = nil) or (_Filename = '') then
    Exit;
  if not LandrixEInvoiceFileExists(_Filename) then
  begin
    _Error := 'File not found: ' + _Filename;
    Exit;
  end;
  try
    Stream := LandrixEInvoiceOpenFile(_Filename, efm_Read);
  except
    on E: Exception do
    begin
      _Error := CompatText('File not readable: ' + E.Message);
      Exit;
    end;
  end;
  try
    if _ProcessPdfFiles and TLandrixEInvoicePdfExtractor.IsPdfStream(Stream) then
      Result := LoadFromPdfStream(_Invoice, Stream, _Error, AttachmentName, _Diagnostics)
    else
      Result := ReadXmlStream(_Invoice, Stream, _Error, _Diagnostics);
  finally
    Stream.Free;
  end;
end;

{ Unicode text is already decoded and read without the encoding
  declaration; an AnsiString holds bytes in the encoding of the declaration.
  DE: Unicode-Text ist schon dekodiert und wird ohne die Kodierungsangabe
  gelesen; ein AnsiString enthaelt Bytes in der Kodierung der Deklaration. }
class function TXRechnungInvoiceAdapter.LoadFromXMLStr(_Invoice: TLandrixInvoice; const _XML: TXRechnungString;
  out _Error: TXRechnungString; _Diagnostics: TLandrixEInvoiceDiagnostics): Boolean;
{$IF not (Defined(FPC) or Defined(LANDRIXEINVOICE_UNICODE))}
var
  M: TMemoryStream;
{$IFEND}
begin
  Result := False;
  _Error := '';
  if (_Invoice = nil) or (_XML = '') then
    Exit;
  {$IF Defined(FPC) or Defined(LANDRIXEINVOICE_UNICODE)}
  Result := ReadXml(_Invoice, nil, TLandrixEInvoiceString(_XML), _Error, _Diagnostics);
  {$ELSE}
  M := TMemoryStream.Create;
  try
    M.WriteBuffer(PAnsiChar(_XML)^, Length(_XML));
    M.Position := 0;
    Result := ReadXmlStream(_Invoice, M, _Error, _Diagnostics);
  finally
    M.Free;
  end;
  {$IFEND}
end;

class function TXRechnungInvoiceAdapter.LoadFromPdfStream(_Invoice: TLandrixInvoice; _Stream: TStream;
  out _Error: TXRechnungString; out _AttachmentName: TXRechnungString;
  _Diagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  Xml: TMemoryStream;
  Name: TLandrixEInvoiceString;
  Info: TLandrixEInvoicePdfExtractInfo;
begin
  Result := False;
  _Error := '';
  _AttachmentName := '';
  if (_Invoice = nil) or (_Stream = nil) then
    Exit;
  Xml := TMemoryStream.Create;
  try
    if not TLandrixEInvoicePdfExtractor.ExtractInvoiceFromStream(_Stream, Xml, Name, Info) then
    begin
      _Error := TXRechnungString(Info.Error);
      if _Error = '' then
        _Error := 'No embedded invoice found in the PDF';
      Exit;
    end;
    _AttachmentName := TXRechnungString(Name);
    if Xml.Size = 0 then
    begin
      _Error := 'The embedded invoice is empty';
      Exit;
    end;
    Xml.Position := 0;
    Result := LoadFromStream(_Invoice, Xml, _Error, False, _Diagnostics);
    if not Result then
      _Error := 'Embedded file ' + _AttachmentName + ': ' + _Error;
  finally
    Xml.Free;
  end;
end;

class function TXRechnungInvoiceAdapter.LoadFromPdfFile(_Invoice: TLandrixInvoice; const _Filename: TXRechnungString;
  out _Error: TXRechnungString; out _AttachmentName: TXRechnungString;
  _Diagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  Stream: TStream;
begin
  Result := False;
  _Error := '';
  _AttachmentName := '';
  if _Invoice = nil then
    Exit;
  if not LandrixEInvoiceFileExists(_Filename) then
  begin
    _Error := 'File not found: ' + _Filename;
    Exit;
  end;
  try
    Stream := LandrixEInvoiceOpenFile(_Filename, efm_Read);
  except
    on E: Exception do
    begin
      _Error := CompatText('File not readable: ' + E.Message);
      Exit;
    end;
  end;
  try
    Result := LoadFromPdfStream(_Invoice, Stream, _Error, _AttachmentName, _Diagnostics);
  finally
    Stream.Free;
  end;
end;

end.
