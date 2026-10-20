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
    declaration.
  - No IXMLDocument overloads, no Java validation. The PDF extraction is
    LandrixEInvoicePdf (old names: LandrixEInvoiceCompatXRechnungPdf).
  - Messages are English.
  - As before, SaveToFile writes nothing for a file name without folder.
    On FPC file names pass the RTL as AnsiString: characters outside the
    system code page are lost.

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
    Deklaration.
  - Keine IXMLDocument-Ueberladungen, keine Java-Validierung. Die
    PDF-Extraktion ist LandrixEInvoicePdf (alte Namen:
    LandrixEInvoiceCompatXRechnungPdf).
  - Meldungen sind englisch.
  - Wie bisher schreibt SaveToFile nichts fuer einen Dateinamen ohne
    Ordner. Unter FPC gehen Dateinamen als AnsiString an die RTL: Zeichen
    ausserhalb der System-Codepage gehen verloren. }

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
  LandrixXmlWriter,
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceLexical,
  LandrixEInvoiceRules,
  LandrixEInvoiceCalc,
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceUBL,
  LandrixEInvoiceUBLReader,
  LandrixEInvoiceUBLWriter,
  LandrixEInvoicePdf,
  LandrixEInvoiceMapUBL;

{ --- helpers ---------------------------------------------------------------- }

function CompatText(const S: string): TXRechnungString;
begin
  Result := TXRechnungString(S);
end;

function NativeFileName(const S: TXRechnungString): string;
begin
  Result := string(S);
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

{ Maps and writes _Invoice; the old SaveDocument raised for other versions.
  DE: Bildet ab und schreibt _Invoice; das alte SaveDocument loeste bei
  anderen Versionen eine Ausnahme aus. }
function SaveToUtf8(AInvoice: TLandrixInvoice; AVersion: TXRechnungVersion;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  Spec: TLandrixEInvoiceSpec;
  W: TLandrixXmlWriter;
  CII: TLandrixCIIInvoice;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
begin
  if not SpecOf(AVersion, Spec) then
    raise ELandrixEInvoiceError.Create('TXRechnungInvoiceAdapter: version ' + IntToStr(Ord(AVersion)) +
      ' cannot be written');
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    if Spec.Target.Syntax = esy_CII then
    begin
      CII := LandrixEInvoiceInvoiceToCII(AInvoice, Spec, ADiagnostics);
      try
        LandrixEInvoiceWriteCII(CII, W, ADiagnostics, Spec.Target.Profile);
      finally
        CII.Free;
      end;
    end
    else if LandrixEInvoiceUBLRootFor(AInvoice, Spec) = eur_CreditNote then
    begin
      UBLCreditNote := LandrixEInvoiceInvoiceToUBLCreditNote(AInvoice, Spec, ADiagnostics);
      try
        LandrixEInvoiceWriteUBLCreditNote(UBLCreditNote, W, ADiagnostics);
      finally
        UBLCreditNote.Free;
      end;
    end
    else
    begin
      UBLInvoice := LandrixEInvoiceInvoiceToUBLInvoice(AInvoice, Spec, ADiagnostics);
      try
        LandrixEInvoiceWriteUBLInvoice(UBLInvoice, W, ADiagnostics);
      finally
        UBLInvoice.Free;
      end;
    end;
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
  end;
end;

{ Reads the loaded document into AInvoice by its root element.
  DE: Liest das geladene Dokument nach seinem Wurzelelement in AInvoice. }
function LoadFromReader(AInvoice: TLandrixInvoice; AReader: TLandrixXmlReader; out AError: TXRechnungString;
  ADiagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  CII: TLandrixCIIInvoice;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
begin
  Result := False;
  AError := '';
  try
    if not MoveToRoot(AReader) then
    begin
      AError := 'No root element';
      Exit;
    end;
    if LandrixXmlSpanEquals(AReader.LocalNameSpan, 'Invoice') then
    begin
      UBLInvoice := LandrixEInvoiceReadUBLInvoice(AReader, ADiagnostics);
      try
        LandrixEInvoiceUBLInvoiceToInvoice(UBLInvoice, AInvoice, ADiagnostics);
      finally
        UBLInvoice.Free;
      end;
    end
    else if LandrixXmlSpanEquals(AReader.LocalNameSpan, 'CreditNote') then
    begin
      UBLCreditNote := LandrixEInvoiceReadUBLCreditNote(AReader, ADiagnostics);
      try
        LandrixEInvoiceUBLCreditNoteToInvoice(UBLCreditNote, AInvoice, ADiagnostics);
      finally
        UBLCreditNote.Free;
      end;
    end
    else if LandrixXmlSpanEquals(AReader.LocalNameSpan, 'CrossIndustryInvoice') then
    begin
      CII := LandrixEInvoiceReadCII(AReader, ADiagnostics);
      try
        LandrixEInvoiceCIIToInvoice(CII, AInvoice, ADiagnostics);
      finally
        CII.Free;
      end;
    end
    else if LandrixXmlSpanEquals(AReader.LocalNameSpan, 'CrossIndustryDocument') then
    begin
      AError := 'ZUGFeRD 1 (CrossIndustryDocument) is not supported';
      Exit;
    end
    else
    begin
      AError := 'Unsupported invoice format (root element ' + CompatText(AReader.ElementPath) + ')';
      Exit;
    end;
    Result := True;
  except
    on E: ELandrixXmlError do
      AError := CompatText('Not valid XML: ' + E.Message);
    on E: Exception do
      AError := CompatText(E.ClassName + ': ' + E.Message);
  end;
end;

{ --- TXRechnungValidationHelper --------------------------------------------- }

class function TXRechnungValidationHelper.GetXRechnungVersion(const _Filename: TXRechnungString;
  _ProcessPdfFiles: Boolean): TXRechnungVersion;
var
  R: TLandrixXmlReader;
  Stream: TFileStream;
begin
  Result := XRechnungVersion_Unknown;
  if not FileExists(NativeFileName(_Filename)) then
    Exit;
  if _ProcessPdfFiles and TLandrixEInvoicePdfExtractor.IsPdfFile(NativeFileName(_Filename)) then
  begin
    try
      Stream := TFileStream.Create(NativeFileName(_Filename), fmOpenRead or fmShareDenyWrite);
      try
        Result := GetXRechnungVersion(Stream, True);
      finally
        Stream.Free;
      end;
    except
      on Exception do
        Result := XRechnungVersion_Unknown;
    end;
    Exit;
  end;
  R := TLandrixXmlReader.Create;
  try
    try
      R.LoadFromFile(NativeFileName(_Filename));
      Result := VersionOf(R);
    except
      on Exception do
        Result := XRechnungVersion_Unknown;
    end;
  finally
    R.Free;
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
      R.LoadFromBuffer(PAnsiChar(Bytes)^, Length(Bytes));
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

function HasSubInvoiceLines(ALines: TLandrixInvoiceLines): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if ALines[I].SubInvoiceLines.Count > 0 then
      Exit;
  Result := False;
end;

{ Top level only: an INFORMATION line there would count outside EXTENDED.
  DE: Nur oberste Ebene: dort wuerde eine INFORMATION-Position ausserhalb
  von EXTENDED mitgezaehlt. }
function HasInformationLines(ALines: TLandrixInvoiceLines): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if ALines[I].LineStatusReasonCode = ilsrc_Information then
      Exit;
  Result := False;
end;

{ BR-FXEXT-08: a GROUP amount equals the sum of its DETAIL and GROUP sub
  lines, compared on the cent amounts that are written.
  DE: BR-FXEXT-08: Ein GROUP-Betrag ist die Summe seiner DETAIL- und
  GROUP-Unterpositionen, verglichen auf den Centbetraegen, die geschrieben
  werden. }
function CentAmount(AValue: Currency): Currency;
var
  Rounded: Boolean;
begin
  if not LandrixEInvoiceTryLexicalToCurrency(LandrixEInvoiceAmountToLexical(AValue), Result, Rounded) then
    Result := AValue;
end;

function HasGroupAmountMismatch(ALines: TLandrixInvoiceLines; AIsSubLine: Boolean): Boolean;
var
  I, K: TLandrixEInvoiceListIndex;
  Sum: Currency;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
  begin
    if LandrixEInvoiceLineStatusOf(ALines[I], AIsSubLine) = ilsrc_Group then
    begin
      Sum := 0;
      for K := 0 to ALines[I].SubInvoiceLines.Count - 1 do
        if LandrixEInvoiceLineStatusOf(ALines[I].SubInvoiceLines[K], True) in [ilsrc_Detail, ilsrc_Group] then
          Sum := Sum + CentAmount(ALines[I].SubInvoiceLines[K].LineAmount);
      if CentAmount(Sum) <> CentAmount(ALines[I].LineAmount) then
        Exit;
    end;
    if HasGroupAmountMismatch(ALines[I].SubInvoiceLines, True) then
      Exit;
  end;
  Result := False;
end;

{ An explicit DETAIL line with sub lines: EXTENDED counts both levels, UBL
  only the parent. DE: Eine ausdrueckliche DETAIL-Position mit
  Unterpositionen: EXTENDED zaehlt beide Ebenen, UBL nur die Oberposition. }
function HasDetailWithSubInvoiceLines(ALines: TLandrixInvoiceLines): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if ((ALines[I].LineStatusReasonCode = ilsrc_Detail) and (ALines[I].SubInvoiceLines.Count > 0)) or
       HasDetailWithSubInvoiceLines(ALines[I].SubInvoiceLines) then
      Exit;
  Result := False;
end;

function HasLineDeliveryData(ALines: TLandrixInvoiceLines): Boolean;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := True;
  for I := 0 to ALines.Count - 1 do
    if (ALines[I].DeliveryNoteNumber <> '') or (ALines[I].DeliveryNoteLineID <> '') or
       (ALines[I].DeliveryNoteDate > 0) or (ALines[I].ActualDeliveryDate > 0) or
       HasLineDeliveryData(ALines[I].SubInvoiceLines) then
      Exit;
  Result := False;
end;

function CountPayments(AInvoice: TLandrixInvoice; ACode: TLandrixInvoicePaymentMeansCode): Integer;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := 0 to AInvoice.PaymentTypes.Count - 1 do
    if AInvoice.PaymentTypes[I].PaymentMeansCode = ACode then
      Inc(Result);
end;

{ Peppol: a scheme from the EAS code list is mandatory, 'EM' is none, and
  the default 'EM' for an empty scheme is not applied (rule table).
  DE: Peppol: ein Schema aus der EAS-Codeliste ist Pflicht, 'EM' ist
  keines, und die Vorgabe 'EM' fuer ein leeres Schema gilt nicht
  (Regel-Tabelle). }
function BadElectronicAddress(AParty: TLandrixInvoiceAccountingParty; AVersion: TXRechnungVersion;
  ANoDefaultEM: Boolean): Boolean;
begin
  Result := (AParty.ElectronicAddressSellerBuyer <> '') and
    (((AVersion = PeppolBillingVersion_30) and (AParty.ElectronicAddressSellerBuyerSchemeID = 'EM')) or
     (ANoDefaultEM and (AParty.ElectronicAddressSellerBuyerSchemeID = '')));
end;

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

{ The checks of XRechnung-for-Delphi in their order. The five that have a
  row in the rule table ask it; for a version that cannot be written
  (Unknown, ZUGFeRD 1, XRechnung 2.x) third-party payments and line
  delivery data fail as before. The others are kept as they were until
  phase 2 moves them into the table.
  DE: Die Pruefungen von XRechnung-for-Delphi in ihrer Reihenfolge. Die
  fuenf mit einer Zeile in der Regel-Tabelle fragen sie; fuer eine nicht
  schreibbare Version (Unknown, ZUGFeRD 1, XRechnung 2.x) scheitern
  Zahlungen Dritter und Lieferdaten je Position wie bisher. Die uebrigen
  bleiben, wie sie waren, bis Phase 2 sie in die Tabelle uebernimmt. }
class function TXRechnungInvoiceAdapter.ConsistencyCheck(_Invoice: TLandrixInvoice;
  _Version: TXRechnungVersion; out _ErrorCode: Integer): Boolean;
var
  Spec: TLandrixEInvoiceSpec;
  NoDefaultEM, Writable: Boolean;
begin
  Writable := SpecOf(_Version, Spec);
  Result := False;
  if (_Invoice.PaymentTypes.Count = 0) and (_Version <> ZUGFeRDEN16931Version_250) then
    _ErrorCode := ccNoPaymentsCount
  else if (_Version in [XRechnungVersion_30x_UBL, XRechnungVersion_30x_UNCEFACT]) and
    (_Invoice.InvoiceTypeCode in [itc_DebitnoteRelatedToFinancialAdjustments, itc_SelfBilledCreditNote,
     itc_DebitNote, itc_PrepaymentInvoice, itc_Cancellation]) then
    _ErrorCode := ccInvoiceTypeNotSupported
  else if (_Invoice.PrecedingInvoiceReferences.Count > 1) and
    (LandrixEInvoiceRuleLevel(Spec, LandrixEInvoiceRuleMultiplePrecedingInvoices) = erl_Forbidden) then
    _ErrorCode := ccTooManyPrecedingInvoices
  else if CountPayments(_Invoice, ipmc_SEPADirectDebit) > 1 then
    _ErrorCode := ccTooManySEPADirectDebit
  else if CountPayments(_Invoice, ipmc_CreditCard) > 1 then
    _ErrorCode := ccTooManyCreditCard
  else if (_Invoice.AccountingSupplierParty.VATCompanyID = '') and (_Invoice.AccountingSupplierParty.CompanyID = '') then
    _ErrorCode := ccNoBT31BT30
  else if (_Invoice.AccountingSupplierParty.VATCompanyID = '') and
    (_Invoice.AccountingSupplierParty.VATCompanyNumber = '') then
    _ErrorCode := ccNoBT31BT32
  else if (_Invoice.PrepaidPayments.Count > 0) and (not Writable or
    (LandrixEInvoiceRuleLevel(Spec, LandrixEInvoiceRuleThirdPartyPayments) = erl_Forbidden)) then
    _ErrorCode := ccPrepaidPaymentNotSupported
  else
  begin
    NoDefaultEM := LandrixEInvoiceRuleLevel(Spec, LandrixEInvoiceRuleElectronicAddressDefaultEM) = erl_Forbidden;
    if BadElectronicAddress(_Invoice.AccountingSupplierParty, _Version, NoDefaultEM) or
       BadElectronicAddress(_Invoice.AccountingCustomerParty, _Version, NoDefaultEM) then
      _ErrorCode := ccNoEMUnderPeppol
    else if HasLineDeliveryData(_Invoice.InvoiceLines) and (not Writable or
      (LandrixEInvoiceRuleLevel(Spec, LandrixEInvoiceRuleLineDelivery) = erl_Forbidden)) then
      _ErrorCode := ccLineDeliveryOnlyExtended
    else if (HasSubInvoiceLines(_Invoice.InvoiceLines) and
       (LandrixEInvoiceRuleLevel(Spec, LandrixEInvoiceRuleLineSubLines) = erl_Forbidden)) or
      ((_Version <> ZUGFeRDExtendedVersion_250) and
       (HasInformationLines(_Invoice.InvoiceLines) or HasDetailWithSubInvoiceLines(_Invoice.InvoiceLines))) then
      _ErrorCode := ccSubInvoiceLinesNotSupported
    else if (_Version = ZUGFeRDExtendedVersion_250) and HasGroupAmountMismatch(_Invoice.InvoiceLines, False) then
      _ErrorCode := ccSubInvoiceLineAmountMismatch
    else
    begin
      _ErrorCode := ccOK;
      Result := True;
    end;
  end;
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
  Stream: TFileStream;
begin
  if (_Invoice = nil) or (_Filename = '') then
    Exit;
  if not DirectoryExists(ExtractFilePath(NativeFileName(_Filename))) then
    Exit;
  Bytes := SaveToUtf8(_Invoice, _Version, _Diagnostics);
  Stream := TFileStream.Create(NativeFileName(_Filename), fmCreate);
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
  R: TLandrixXmlReader;
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
  R := TLandrixXmlReader.Create;
  try
    try
      R.LoadFromStream(_Stream);
    except
      on E: Exception do
      begin
        _Error := CompatText('Stream is not valid XML: ' + E.Message);
        Exit;
      end;
    end;
    Result := LoadFromReader(_Invoice, R, _Error, _Diagnostics);
  finally
    R.Free;
  end;
end;

class function TXRechnungInvoiceAdapter.LoadFromFile(_Invoice: TLandrixInvoice; const _Filename: TXRechnungString;
  out _Error: TXRechnungString; _ProcessPdfFiles: Boolean; _Diagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  R: TLandrixXmlReader;
  AttachmentName: TXRechnungString;
begin
  Result := False;
  _Error := '';
  if (_Invoice = nil) or (_Filename = '') then
    Exit;
  if not FileExists(NativeFileName(_Filename)) then
  begin
    _Error := 'File not found: ' + _Filename;
    Exit;
  end;
  if _ProcessPdfFiles and TLandrixEInvoicePdfExtractor.IsPdfFile(NativeFileName(_Filename)) then
  begin
    Result := LoadFromPdfFile(_Invoice, _Filename, _Error, AttachmentName, _Diagnostics);
    Exit;
  end;
  R := TLandrixXmlReader.Create;
  try
    try
      R.LoadFromFile(NativeFileName(_Filename));
    except
      on E: Exception do
      begin
        _Error := CompatText('File is not valid XML: ' + E.Message);
        Exit;
      end;
    end;
    Result := LoadFromReader(_Invoice, R, _Error, _Diagnostics);
  finally
    R.Free;
  end;
end;

class function TXRechnungInvoiceAdapter.LoadFromXMLStr(_Invoice: TLandrixInvoice; const _XML: TXRechnungString;
  out _Error: TXRechnungString; _Diagnostics: TLandrixEInvoiceDiagnostics): Boolean;
var
  R: TLandrixXmlReader;
  Bytes: TLandrixXmlUtf8;
begin
  Result := False;
  _Error := '';
  if (_Invoice = nil) or (_XML = '') then
    Exit;
  R := TLandrixXmlReader.Create;
  try
    try
      Bytes := XmlBytes(_XML);
      R.LoadFromBuffer(PAnsiChar(Bytes)^, Length(Bytes));
    except
      on E: Exception do
      begin
        _Error := CompatText('Text is not valid XML: ' + E.Message);
        Exit;
      end;
    end;
    Result := LoadFromReader(_Invoice, R, _Error, _Diagnostics);
  finally
    R.Free;
  end;
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
  Stream: TFileStream;
begin
  Result := False;
  _Error := '';
  _AttachmentName := '';
  if _Invoice = nil then
    Exit;
  if not FileExists(NativeFileName(_Filename)) then
  begin
    _Error := 'File not found: ' + _Filename;
    Exit;
  end;
  try
    Stream := TFileStream.Create(NativeFileName(_Filename), fmOpenRead or fmShareDenyWrite);
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
