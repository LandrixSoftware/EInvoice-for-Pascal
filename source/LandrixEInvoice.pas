{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The facade: read and write electronic invoices with one call.

  Writing resolves the target (an unknown target raises
  ELandrixEInvoiceTargetError before any file is opened), checks the
  business rules, maps the invoice to the syntax model and serialises it in
  memory. Only if no error remains is the result written; otherwise
  ELandrixEInvoiceWriteError carries the diagnostics and nothing is written.
  Options change this (TLandrixEInvoiceOption).

  Reading detects PDF by content, reads the syntax model, maps it to the
  invoice and returns a TLandrixEInvoiceDocument that owns both. It raises
  only when no document can be produced (ELandrixEInvoiceFormatError,
  ELandrixEInvoicePdfError); everything about the content is in the
  diagnostics of the document.

  DE: Die Fassade: elektronische Rechnungen mit einem Aufruf lesen und
  schreiben.

  Schreiben loest die Zielangabe auf (eine unbekannte Zielangabe loest
  ELandrixEInvoiceTargetError aus, bevor eine Datei geoeffnet wird), prueft
  die Geschaeftsregeln, bildet die Rechnung auf das Syntaxmodell ab und
  serialisiert es im Speicher. Nur wenn kein Fehler bleibt, wird das
  Ergebnis geschrieben; sonst traegt ELandrixEInvoiceWriteError die
  Meldungen und es wird nichts geschrieben. Optionen aendern das
  (TLandrixEInvoiceOption).

  Lesen erkennt PDF am Inhalt, liest das Syntaxmodell, bildet es auf die
  Rechnung ab und liefert ein TLandrixEInvoiceDocument, das beides besitzt.
  Es loest nur dann eine Ausnahme aus, wenn kein Dokument entstehen kann
  (ELandrixEInvoiceFormatError, ELandrixEInvoicePdfError); alles zum Inhalt
  steht in den Meldungen des Dokuments. }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixEInvoice;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII,
  LandrixEInvoiceUBL,
  LandrixEInvoicePdf;

type
  { Options of the facade; the default is the empty set.
    DE: Optionen der Fassade; Vorgabe ist die leere Menge. }
  TLandrixEInvoiceOption = (
    { Content the target does not allow or discourages (edk_NotAllowed) is an
      error, also where the mapping leaves it out.
      DE: Inhalt, den das Ziel nicht erlaubt oder von dem es abraet
      (edk_NotAllowed), ist ein Fehler, auch wo die Abbildung ihn weglaesst. }
    eio_Strict,
    { Writing and Check do not check the business rules (BR-..., BR-DE-...,
      Peppol rules) of the invoice model.
      DE: Schreiben und Check pruefen die Geschaeftsregeln (BR-...,
      BR-DE-..., Peppol-Regeln) des Rechnungsmodells nicht. }
    eio_NoRuleCheck,
    { Writing writes despite errors; ADiagnostics still receives them.
      DE: Schreiben schreibt trotz Fehlern; ADiagnostics erhaelt sie
      trotzdem. }
    eio_WriteDespiteErrors,
    { Reading checks the business rules of the detected specification;
      nothing is checked when BT-24 is unknown (Info.SpecFound False).
      DE: Lesen prueft die Geschaeftsregeln der erkannten Spezifikation; bei
      unbekannter BT-24 (Info.SpecFound False) wird nichts geprueft. }
    eio_CheckOnRead,
    { Reading frees the syntax model after the mapping (CII, UBLInvoice and
      UBLCreditNote of the document are nil).
      DE: Lesen gibt das Syntaxmodell nach der Abbildung frei (CII,
      UBLInvoice und UBLCreditNote des Dokuments sind nil). }
    eio_InvoiceOnly,
    { Reading treats the input as XML and does not look for a PDF.
      DE: Lesen behandelt die Eingabe als XML und sucht kein PDF. }
    eio_NoPdf
  );
  TLandrixEInvoiceOptions = set of TLandrixEInvoiceOption;

  { Where a read document came from. DE: Woher ein gelesenes Dokument kam. }
  TLandrixEInvoiceSource = (eso_Xml, eso_Pdf);

  { What reading found out about a document. The specification is decided
    by the identifier BT-24, never by the content.
    DE: Was das Lesen ueber ein Dokument herausgefunden hat. Die
    Spezifikation entscheidet die Kennung BT-24, nie der Inhalt. }
  TLandrixEInvoiceDocumentInfo = record
    Source: TLandrixEInvoiceSource;
    { Local name of the root element: Invoice, CreditNote or
      CrossIndustryInvoice. DE: Lokaler Name des Wurzelelements: Invoice,
      CreditNote oder CrossIndustryInvoice. }
    RootName: TLandrixEInvoiceString;
    Syntax: TLandrixEInvoiceSyntax;
    { BT-24 and BT-23 as read ('' if absent).
      DE: BT-24 und BT-23 wie gelesen ('' wenn nicht vorhanden). }
    CustomizationID: TLandrixEInvoiceString;
    ProfileID: TLandrixEInvoiceString;
    { True if the specification directory has an entry for RootName and
      CustomizationID; Spec is the empty entry otherwise. Spec.ExactVersion
      is the release the library is built for, not the release of the
      sender.
      DE: True, wenn das Spezifikationsverzeichnis einen Eintrag fuer
      RootName und CustomizationID hat; sonst ist Spec der leere Eintrag.
      Spec.ExactVersion ist der Stand, fuer den die Bibliothek gebaut ist,
      nicht der Stand des Absenders. }
    SpecFound: Boolean;
    Spec: TLandrixEInvoiceSpec;
    { BT-24 is the identifier of the XRechnung extension.
      DE: BT-24 ist die Kennung der XRechnung-Extension. }
    UsesExtension: Boolean;
    { PDF only: the name of the embedded invoice and the extraction facts;
      empty for XML.
      DE: Nur PDF: Name der eingebetteten Rechnung und die Angaben der
      Extraktion; leer bei XML. }
    PdfAttachmentName: TLandrixEInvoiceString;
    Pdf: TLandrixEInvoicePdfExtractInfo;
  end;

  { A read document: the invoice, the syntax model it was read from (one of
    CII, UBLInvoice, UBLCreditNote; nil with eio_InvoiceOnly), the
    diagnostics and the info. The document owns all of them. Invoice and
    syntax model are independent: changing one does not change the other.
    DE: Ein gelesenes Dokument: die Rechnung, das Syntaxmodell, aus dem sie
    gelesen wurde (eines von CII, UBLInvoice, UBLCreditNote; nil mit
    eio_InvoiceOnly), die Meldungen und die Info. Das Dokument besitzt
    alles. Rechnung und Syntaxmodell sind unabhaengig: eine Aenderung am
    einen aendert das andere nicht. }
  TLandrixEInvoiceDocument = class(TObject)
  private
    FInvoice: TLandrixInvoice;
    FCII: TLandrixCIIInvoice;
    FUBLInvoice: TLandrixUBLInvoice;
    FUBLCreditNote: TLandrixUBLCreditNote;
    FDiagnostics: TLandrixEInvoiceDiagnostics;
    FInfo: TLandrixEInvoiceDocumentInfo;
  public
    constructor Create;
    destructor Destroy; override;
    { Returns the invoice and gives up its ownership; Invoice is nil
      afterwards.
      DE: Liefert die Rechnung und gibt den Besitz ab; Invoice ist danach
      nil. }
    function DetachInvoice: TLandrixInvoice;
    { Frees the syntax model (CII, UBLInvoice, UBLCreditNote become nil).
      DE: Gibt das Syntaxmodell frei (CII, UBLInvoice, UBLCreditNote werden
      nil). }
    procedure FreeSyntaxModel;
    property Invoice: TLandrixInvoice read FInvoice;
    property CII: TLandrixCIIInvoice read FCII;
    property UBLInvoice: TLandrixUBLInvoice read FUBLInvoice;
    property UBLCreditNote: TLandrixUBLCreditNote read FUBLCreditNote;
    property Diagnostics: TLandrixEInvoiceDiagnostics read FDiagnostics;
    property Info: TLandrixEInvoiceDocumentInfo read FInfo;
  end;

  { The target has no entry in the specification directory, cannot be
    written or does not match the syntax model.
    DE: Die Zielangabe hat keinen Eintrag im Spezifikationsverzeichnis,
    kann nicht geschrieben werden oder passt nicht zum Syntaxmodell. }
  ELandrixEInvoiceTargetError = class(ELandrixEInvoiceError);

  { The input is no readable invoice: not well-formed XML (Line, Column and
    Offset tell where; 0, 0, -1 if unknown), an unknown root element, ZUGFeRD
    1.
    DE: Die Eingabe ist keine lesbare Rechnung: kein wohlgeformtes XML (Line,
    Column und Offset sagen wo; 0, 0, -1 wenn unbekannt), ein unbekanntes
    Wurzelelement, ZUGFeRD 1. }
  ELandrixEInvoiceFormatError = class(ELandrixEInvoiceError)
  private
    FLine: Integer;
    FColumn: Integer;
    FOffset: Int64;
  public
    constructor CreateAt(const AMessage: string; ALine, AColumn: Integer; AOffset: Int64);
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property Offset: Int64 read FOffset;
  end;

  { The PDF could not be read or contains no invoice.
    DE: Das PDF liess sich nicht lesen oder enthaelt keine Rechnung. }
  ELandrixEInvoicePdfError = class(ELandrixEInvoiceError);

  { Writing was refused because of errors; Diagnostics holds the
    diagnostics of the operation (owned by the exception).
    DE: Das Schreiben wurde wegen Fehlern verweigert; Diagnostics enthaelt
    die Meldungen des Vorgangs (gehoert der Ausnahme). }
  ELandrixEInvoiceWriteError = class(ELandrixEInvoiceError)
  private
    FDiagnostics: TLandrixEInvoiceDiagnostics;
  public
    { Takes ownership of ADiagnostics. DE: Uebernimmt ADiagnostics. }
    constructor CreateWithDiagnostics(const AMessage: string; ADiagnostics: TLandrixEInvoiceDiagnostics);
    destructor Destroy; override;
    property Diagnostics: TLandrixEInvoiceDiagnostics read FDiagnostics;
  end;

  { The facade. Every method is a class method. ADiagnostics (nil:
    discarded) receives the diagnostics of the operation; entries already
    in it stay.
    DE: Die Fassade. Alle Methoden sind Klassenmethoden. ADiagnostics (nil:
    verworfen) erhaelt die Meldungen des Vorgangs; vorhandene Eintraege
    bleiben. }
  TLandrixEInvoice = class(TObject)
  public
    { Writes AInvoice for ATarget (see the unit description).
      DE: Schreibt AInvoice fuer ATarget (siehe Unit-Beschreibung). }
    class procedure SaveToFile(AInvoice: TLandrixInvoice; const AFileName: TLandrixEInvoiceString;
      const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions = [];
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil); overload;
    class procedure SaveToStream(AInvoice: TLandrixInvoice; AStream: TStream;
      const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions = [];
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil); overload;
    class function SaveToUtf8(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixXmlUtf8;
      overload;
    { As SaveToUtf8, as text. The text keeps the declaration
      encoding="UTF-8": store it as UTF-8 (LandrixEInvoiceStringToUtf8, or
      SaveToFile/SaveToStream), never through a code page. On Delphi 6-2007
      the result is a WideString; assigning it to a string loses characters
      outside the system code page.
      DE: Wie SaveToUtf8, als Text. Der Text behaelt die Deklaration
      encoding="UTF-8": als UTF-8 speichern (LandrixEInvoiceStringToUtf8
      oder SaveToFile/SaveToStream), nie ueber eine Codepage. Unter Delphi
      6-2007 ist das Ergebnis ein WideString; die Zuweisung an einen string
      verliert Zeichen ausserhalb der System-Codepage. }
    class function SaveToText(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixEInvoiceString;
      overload;

    { Writes a syntax model for ATarget. Checked are the content the
      Factur-X profile does not contain, the content the schema and the
      profile require, and that BT-24 of the model belongs to ATarget; the
      business rules need the invoice model and are not checked here.
      DE: Schreibt ein Syntaxmodell fuer ATarget. Geprueft werden Inhalt,
      den das Factur-X-Profil nicht enthaelt, der Inhalt, den Schema und
      Profil verlangen, und dass BT-24 des Modells zu ATarget gehoert; die
      Geschaeftsregeln brauchen das Rechnungsmodell und werden hier nicht
      geprueft. }
    class procedure SaveToFile(ACII: TLandrixCIIInvoice; const AFileName: TLandrixEInvoiceString;
      const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions = [];
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil); overload;
    class procedure SaveToFile(AUBL: TLandrixUBLInvoice; const AFileName: TLandrixEInvoiceString;
      const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions = [];
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil); overload;
    class procedure SaveToFile(AUBL: TLandrixUBLCreditNote; const AFileName: TLandrixEInvoiceString;
      const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions = [];
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil); overload;
    class procedure SaveToStream(ACII: TLandrixCIIInvoice; AStream: TStream;
      const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions = [];
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil); overload;
    class procedure SaveToStream(AUBL: TLandrixUBLInvoice; AStream: TStream;
      const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions = [];
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil); overload;
    class procedure SaveToStream(AUBL: TLandrixUBLCreditNote; AStream: TStream;
      const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions = [];
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil); overload;
    class function SaveToUtf8(ACII: TLandrixCIIInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixXmlUtf8;
      overload;
    class function SaveToUtf8(AUBL: TLandrixUBLInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixXmlUtf8;
      overload;
    class function SaveToUtf8(AUBL: TLandrixUBLCreditNote; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixXmlUtf8;
      overload;
    class function SaveToText(ACII: TLandrixCIIInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixEInvoiceString;
      overload;
    class function SaveToText(AUBL: TLandrixUBLInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixEInvoiceString;
      overload;
    class function SaveToText(AUBL: TLandrixUBLCreditNote; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixEInvoiceString;
      overload;

    { Maps AInvoice to the syntax model of ATarget for changes before
      writing; nothing is refused here, SaveTo* checks. The caller frees the
      result. In UBL a credit note (BT-3 = 381) is written as CreditNote
      (ToUBLCreditNote), every other invoice as Invoice (ToUBLInvoice).
      DE: Bildet AInvoice auf das Syntaxmodell von ATarget ab, fuer
      Aenderungen vor dem Schreiben; hier wird nichts verweigert, SaveTo*
      prueft. Der Aufrufer gibt das Ergebnis frei. In UBL wird eine
      Gutschrift (BT-3 = 381) als CreditNote geschrieben (ToUBLCreditNote),
      jede andere Rechnung als Invoice (ToUBLInvoice). }
    class function ToCII(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixCIIInvoice;
    class function ToUBLInvoice(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixUBLInvoice;
    class function ToUBLCreditNote(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
      ADiagnostics: TLandrixEInvoiceDiagnostics = nil): TLandrixUBLCreditNote;

    { Runs the checks of SaveTo* without writing and returns the number of
      errors SaveTo* would refuse on.
      DE: Fuehrt die Pruefungen von SaveTo* aus, ohne zu schreiben, und
      liefert die Anzahl der Fehler, bei denen SaveTo* verweigern wuerde. }
    class function Check(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): Integer; overload;
    class function Check(ACII: TLandrixCIIInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): Integer; overload;
    class function Check(AUBL: TLandrixUBLInvoice; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): Integer; overload;
    class function Check(AUBL: TLandrixUBLCreditNote; const ATarget: TLandrixEInvoiceTarget;
      AOptions: TLandrixEInvoiceOptions = []; ADiagnostics: TLandrixEInvoiceDiagnostics = nil): Integer; overload;

    { Reads an invoice (XML, or a PDF with an embedded invoice) and returns
      the document; the caller frees it. A stream is read from its current
      position to the end.
      DE: Liest eine Rechnung (XML oder ein PDF mit eingebetteter Rechnung)
      und liefert das Dokument; der Aufrufer gibt es frei. Ein Stream wird
      ab seiner aktuellen Position bis zum Ende gelesen. }
    class function LoadFromFile(const AFileName: TLandrixEInvoiceString;
      AOptions: TLandrixEInvoiceOptions = []): TLandrixEInvoiceDocument;
    class function LoadFromStream(AStream: TStream;
      AOptions: TLandrixEInvoiceOptions = []): TLandrixEInvoiceDocument;
    { XML as UTF-8 bytes, never a PDF; the encoding declaration is not
      consulted (LoadFromStream follows it).
      DE: XML als UTF-8-Bytes, nie ein PDF; die Kodierungsangabe der
      Deklaration wird nicht beachtet (LoadFromStream folgt ihr). }
    class function LoadFromUtf8(const AXml: TLandrixXmlUtf8;
      AOptions: TLandrixEInvoiceOptions = []): TLandrixEInvoiceDocument;
    { XML as decoded text, never a PDF; the encoding declaration is not
      consulted (LoadFromStream follows it). An unpaired surrogate raises
      ELandrixEInvoiceFormatError. On Delphi 6-2007 an AnsiString holding
      UTF-8 bytes belongs in LoadFromUtf8: passed here, it is converted
      through the system code page and characters are garbled without a
      message.
      DE: XML als dekodierter Text, nie ein PDF; die Kodierungsangabe der
      Deklaration wird nicht beachtet (LoadFromStream folgt ihr). Ein ungepaartes
      Surrogat loest ELandrixEInvoiceFormatError aus. Unter Delphi 6-2007
      gehoert ein AnsiString mit UTF-8-Bytes in LoadFromUtf8: hier
      uebergeben, wird er ueber die System-Codepage umgewandelt, und
      Zeichen werden ohne Meldung verfaelscht. }
    class function LoadFromText(const AXml: TLandrixEInvoiceString;
      AOptions: TLandrixEInvoiceOptions = []): TLandrixEInvoiceDocument;
  end;

implementation

uses
  SysUtils,
  LandrixXmlReader,
  LandrixXmlWriter,
  LandrixEInvoiceLexical,
  LandrixEInvoiceFiles,
  LandrixEInvoiceCheck,
  LandrixEInvoiceCIIProfiles,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceUBLReader,
  LandrixEInvoiceUBLWriter,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceMapUBL;

type
  TModelKind = (mk_Invoice, mk_CII, mk_UBLInvoice, mk_UBLCreditNote);

{ --- exceptions ----------------------------------------------------------- }

constructor ELandrixEInvoiceFormatError.CreateAt(const AMessage: string; ALine, AColumn: Integer;
  AOffset: Int64);
begin
  inherited Create(AMessage);
  FLine := ALine;
  FColumn := AColumn;
  FOffset := AOffset;
end;

constructor ELandrixEInvoiceWriteError.CreateWithDiagnostics(const AMessage: string;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  inherited Create(AMessage);
  FDiagnostics := ADiagnostics;
end;

destructor ELandrixEInvoiceWriteError.Destroy;
begin
  FDiagnostics.Free;
  inherited;
end;

{ --- TLandrixEInvoiceDocument --------------------------------------------- }

constructor TLandrixEInvoiceDocument.Create;
begin
  inherited Create;
  FInvoice := TLandrixInvoice.Create;
  FDiagnostics := TLandrixEInvoiceDiagnostics.Create;
end;

destructor TLandrixEInvoiceDocument.Destroy;
begin
  FreeSyntaxModel;
  FInvoice.Free;
  FDiagnostics.Free;
  inherited;
end;

function TLandrixEInvoiceDocument.DetachInvoice: TLandrixInvoice;
begin
  Result := FInvoice;
  FInvoice := nil;
end;

procedure TLandrixEInvoiceDocument.FreeSyntaxModel;
begin
  FreeAndNil(FCII);
  FreeAndNil(FUBLInvoice);
  FreeAndNil(FUBLCreditNote);
end;

{ --- helpers -------------------------------------------------------------- }

{ The entry of ATarget; raises ELandrixEInvoiceTargetError if there is none,
  it cannot be written or its syntax does not fit AKind.
  DE: Der Eintrag zu ATarget; loest ELandrixEInvoiceTargetError aus, wenn es
  keinen gibt, er nicht geschrieben werden kann oder seine Syntax nicht zu
  AKind passt. }
function WritableSpec(const ATarget: TLandrixEInvoiceTarget; AKind: TModelKind): TLandrixEInvoiceSpec;
begin
  if not LandrixEInvoiceFindSpec(ATarget, Result) then
    raise ELandrixEInvoiceTargetError.Create('No specification for the target ' +
      string(LandrixEInvoiceTargetToStr(ATarget)));
  if not Result.CanWrite then
    raise ELandrixEInvoiceTargetError.Create('The target ' + string(LandrixEInvoiceTargetToStr(ATarget)) +
      ' cannot be written');
  if ((AKind = mk_CII) and (Result.Target.Syntax <> esy_CII)) or
     ((AKind in [mk_UBLInvoice, mk_UBLCreditNote]) and (Result.Target.Syntax <> esy_UBL)) then
    raise ELandrixEInvoiceTargetError.Create('The syntax model does not match the target ' +
      string(LandrixEInvoiceTargetToStr(ATarget)));
end;

{ Strict mode: left-out or discouraged content from AStart on becomes an
  error. Returns the number of errors from AStart on.
  DE: Strenger Modus: weggelassener oder abgeratener Inhalt ab AStart wird
  ein Fehler. Liefert die Anzahl der Fehler ab AStart. }
function Finish(ADiagnostics: TLandrixEInvoiceDiagnostics; AStart: TLandrixEInvoiceListIndex;
  AOptions: TLandrixEInvoiceOptions): Integer;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := AStart to ADiagnostics.Count - 1 do
  begin
    if (eio_Strict in AOptions) and (ADiagnostics[I].Kind = edk_NotAllowed) then
      ADiagnostics[I].Severity := eds_Error;
    if ADiagnostics[I].Severity = eds_Error then
      Inc(Result);
  end;
end;

{ A copy of the entries of ASource from AStart on.
  DE: Eine Kopie der Eintraege von ASource ab AStart. }
function CopyDiagnostics(ASource: TLandrixEInvoiceDiagnostics;
  AStart: TLandrixEInvoiceListIndex): TLandrixEInvoiceDiagnostics;
var
  I: TLandrixEInvoiceListIndex;
  Item: TLandrixEInvoiceDiagnostic;
begin
  Result := TLandrixEInvoiceDiagnostics.Create;
  for I := AStart to ASource.Count - 1 do
  begin
    Item := Result.AddDiagnostic(ASource[I].Kind, ASource[I].Path, ASource[I].Line, ASource[I].Column,
      ASource[I].Offset, ASource[I].Message);
    Item.Severity := ASource[I].Severity;
    Item.RuleID := ASource[I].RuleID;
  end;
end;

{ BT-24 of a syntax model must belong to the entry it is written for.
  DE: BT-24 eines Syntaxmodells muss zu dem Eintrag gehoeren, fuer den es
  geschrieben wird. }
procedure CheckCustomization(const ARootName, ACustomizationID, APath: TLandrixEInvoiceString;
  const ASpec: TLandrixEInvoiceSpec; ADiagnostics: TLandrixEInvoiceDiagnostics);
var
  Found: TLandrixEInvoiceSpec;
  Extension: Boolean;
begin
  { a blank BT-24 is reported by the writer as missing }
  if LandrixEInvoiceIsBlank(ACustomizationID) then
    Exit;
  if not LandrixEInvoiceDetectSpec(ARootName, ACustomizationID, Found, Extension) then
    ADiagnostics.AddDiagnostic(edk_InvalidValue, APath, 0, 0, 0, 'Unknown specification identifier (BT-24) ''' +
      ACustomizationID + ''' for ' + LandrixEInvoiceTargetToStr(ASpec.Target)).Severity := eds_Error
  else if not LandrixEInvoiceSameTarget(Found.Target, ASpec.Target) then
    ADiagnostics.AddDiagnostic(edk_InvalidValue, APath, 0, 0, 0, 'BT-24 ''' + ACustomizationID +
      ''' belongs to ' + LandrixEInvoiceTargetToStr(Found.Target) + ', not to ' +
      LandrixEInvoiceTargetToStr(ASpec.Target)).Severity := eds_Error;
end;

const
  CIIRoot = '/rsm:CrossIndustryInvoice';
  CIICustomizationPath = CIIRoot +
    '/rsm:ExchangedDocumentContext/ram:GuidelineSpecifiedDocumentContextParameter/ram:ID';

{ Runs the checks for ASpec and serialises the model into memory (Check
  discards the bytes). A syntax model keeps its content; reading BT-24 may
  create its empty context objects.
  DE: Fuehrt die Pruefungen fuer ASpec aus und serialisiert das Modell in den
  Speicher (Check verwirft die Bytes). Ein Syntaxmodell behaelt seinen
  Inhalt; das Lesen von BT-24 kann seine leeren Kontextobjekte anlegen. }
function Build(AKind: TModelKind; AModel: TObject; const ASpec: TLandrixEInvoiceSpec;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
  Invoice: TLandrixInvoice;
  CII: TLandrixCIIInvoice;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
  Owned: TObject;
begin
  Owned := nil;
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    case AKind of
      mk_Invoice:
        begin
          Invoice := TLandrixInvoice(AModel);
          if not (eio_NoRuleCheck in AOptions) then
            LandrixEInvoiceCheckInvoice(Invoice, ASpec, ADiagnostics);
          if ASpec.Target.Syntax = esy_CII then
          begin
            CII := LandrixEInvoiceInvoiceToCII(Invoice, ASpec, ADiagnostics);
            Owned := CII;
            LandrixEInvoiceWriteCII(CII, W, ADiagnostics, ASpec.Target.Profile);
          end
          else if LandrixEInvoiceUBLRootFor(Invoice, ASpec) = eur_CreditNote then
          begin
            UBLCreditNote := LandrixEInvoiceInvoiceToUBLCreditNote(Invoice, ASpec, ADiagnostics);
            Owned := UBLCreditNote;
            LandrixEInvoiceWriteUBLCreditNote(UBLCreditNote, W, ADiagnostics);
          end
          else
          begin
            UBLInvoice := LandrixEInvoiceInvoiceToUBLInvoice(Invoice, ASpec, ADiagnostics);
            Owned := UBLInvoice;
            LandrixEInvoiceWriteUBLInvoice(UBLInvoice, W, ADiagnostics);
          end;
        end;
      mk_CII:
        begin
          CII := TLandrixCIIInvoice(AModel);
          CheckCustomization('CrossIndustryInvoice',
            CII.ExchangedDocumentContext.GuidelineSpecifiedDocumentContextParameter.ID.Value,
            CIICustomizationPath, ASpec, ADiagnostics);
          LandrixEInvoiceCheckCIIProfile(CII, ASpec.Target.Profile, ADiagnostics);
          LandrixEInvoiceWriteCII(CII, W, ADiagnostics, ASpec.Target.Profile);
        end;
      mk_UBLInvoice:
        begin
          UBLInvoice := TLandrixUBLInvoice(AModel);
          CheckCustomization('Invoice', UBLInvoice.CustomizationID.Value, '/Invoice/cbc:CustomizationID', ASpec,
            ADiagnostics);
          LandrixEInvoiceWriteUBLInvoice(UBLInvoice, W, ADiagnostics);
        end;
      mk_UBLCreditNote:
        begin
          UBLCreditNote := TLandrixUBLCreditNote(AModel);
          CheckCustomization('CreditNote', UBLCreditNote.CustomizationID.Value, '/CreditNote/cbc:CustomizationID',
            ASpec, ADiagnostics);
          LandrixEInvoiceWriteUBLCreditNote(UBLCreditNote, W, ADiagnostics);
        end;
    end;
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
    Owned.Free;
  end;
end;

{ The whole write path up to the bytes: resolve, check, build, refuse.
  DE: Der ganze Schreibweg bis zu den Bytes: aufloesen, pruefen, bauen,
  verweigern. }
function Produce(AKind: TModelKind; AModel: TObject; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  Spec: TLandrixEInvoiceSpec;
  D, Own: TLandrixEInvoiceDiagnostics;
  Start: TLandrixEInvoiceListIndex;
  Errors: Integer;
begin
  if AModel = nil then
    raise ELandrixEInvoiceError.Create('TLandrixEInvoice: nothing to write (nil)');
  Spec := WritableSpec(ATarget, AKind);
  Own := nil;
  D := ADiagnostics;
  try
    if D = nil then
    begin
      Own := TLandrixEInvoiceDiagnostics.Create;
      D := Own;
    end;
    Start := D.Count;
    Result := Build(AKind, AModel, Spec, AOptions, D);
    Errors := Finish(D, Start, AOptions);
    if (Errors > 0) and not (eio_WriteDespiteErrors in AOptions) then
      raise ELandrixEInvoiceWriteError.CreateWithDiagnostics(IntToStr(Errors) + ' error(s), nothing written for ' +
        string(LandrixEInvoiceTargetToStr(ATarget)), CopyDiagnostics(D, Start));
  finally
    Own.Free;
  end;
end;

function RunCheck(AKind: TModelKind; AModel: TObject; const ATarget: TLandrixEInvoiceTarget;
  ADiagnostics: TLandrixEInvoiceDiagnostics; AOptions: TLandrixEInvoiceOptions): Integer;
var
  Spec: TLandrixEInvoiceSpec;
  D, Own: TLandrixEInvoiceDiagnostics;
  Start: TLandrixEInvoiceListIndex;
begin
  if AModel = nil then
    raise ELandrixEInvoiceError.Create('TLandrixEInvoice: nothing to check (nil)');
  Spec := WritableSpec(ATarget, AKind);
  Own := nil;
  D := ADiagnostics;
  try
    if D = nil then
    begin
      Own := TLandrixEInvoiceDiagnostics.Create;
      D := Own;
    end;
    Start := D.Count;
    Build(AKind, AModel, Spec, AOptions, D);
    Result := Finish(D, Start, AOptions);
  finally
    Own.Free;
  end;
end;

procedure WriteBytes(AStream: TStream; const ABytes: TLandrixXmlUtf8);
begin
  if ABytes <> '' then
    AStream.WriteBuffer(PAnsiChar(ABytes)^, Length(ABytes));
end;

procedure WriteFile(const AFileName: TLandrixEInvoiceString; const ABytes: TLandrixXmlUtf8);
var
  S: TStream;
begin
  S := LandrixEInvoiceOpenFile(AFileName, efm_Create);
  try
    WriteBytes(S, ABytes);
  finally
    S.Free;
  end;
end;

{ --- reading -------------------------------------------------------------- }

function FormatErrorOf(E: ELandrixXmlError): ELandrixEInvoiceFormatError;
begin
  Result := ELandrixEInvoiceFormatError.CreateAt('Not well-formed XML: ' + E.Message, E.Line, E.Column, E.Offset);
end;

{ Reads the XML in AReader into ADocument. Only reading is translated into
  ELandrixEInvoiceFormatError; the mapping raises unchanged.
  DE: Liest das XML in AReader in ADocument. Nur das Lesen wird in
  ELandrixEInvoiceFormatError uebersetzt; die Abbildung loest unveraendert
  aus. }
procedure ReadXml(AReader: TLandrixXmlReader; ADocument: TLandrixEInvoiceDocument;
  AOptions: TLandrixEInvoiceOptions);
var
  Root, Path: TLandrixEInvoiceString;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := ADocument.FDiagnostics;
  try
    while AReader.TokenType <> xttStartElement do
      if not AReader.Read then
        raise ELandrixEInvoiceFormatError.CreateAt('No root element', 0, 0, -1);
    Root := LandrixEInvoiceUtf8ToString(AReader.LocalNameUtf8);
    if Root = 'Invoice' then
      ADocument.FUBLInvoice := LandrixEInvoiceReadUBLInvoice(AReader, D)
    else if Root = 'CreditNote' then
      ADocument.FUBLCreditNote := LandrixEInvoiceReadUBLCreditNote(AReader, D)
    else if Root = 'CrossIndustryInvoice' then
      ADocument.FCII := LandrixEInvoiceReadCII(AReader, D)
    else if Root = 'CrossIndustryDocument' then
      raise ELandrixEInvoiceFormatError.CreateAt('ZUGFeRD 1 (CrossIndustryDocument) is not supported', 0, 0, -1)
    else
      raise ELandrixEInvoiceFormatError.CreateAt('Unsupported invoice format (root element ' + AReader.ElementPath +
        ')', 0, 0, -1);
  except
    on E: ELandrixXmlError do
      raise FormatErrorOf(E);
    on E: ELandrixEInvoiceFormatError do
      raise;
    { the readers raise ELandrixEInvoiceError for a root in another
      namespace }
    on E: ELandrixEInvoiceError do
      raise ELandrixEInvoiceFormatError.CreateAt(E.Message, 0, 0, -1);
  end;
  if ADocument.FUBLInvoice <> nil then
  begin
    ADocument.FInfo.Syntax := esy_UBL;
    ADocument.FInfo.CustomizationID := ADocument.FUBLInvoice.CustomizationID.Value;
    ADocument.FInfo.ProfileID := ADocument.FUBLInvoice.ProfileID.Value;
    Path := '/Invoice/cbc:CustomizationID';
    LandrixEInvoiceUBLInvoiceToInvoice(ADocument.FUBLInvoice, ADocument.FInvoice, D);
  end
  else if ADocument.FUBLCreditNote <> nil then
  begin
    ADocument.FInfo.Syntax := esy_UBL;
    ADocument.FInfo.CustomizationID := ADocument.FUBLCreditNote.CustomizationID.Value;
    ADocument.FInfo.ProfileID := ADocument.FUBLCreditNote.ProfileID.Value;
    Path := '/CreditNote/cbc:CustomizationID';
    LandrixEInvoiceUBLCreditNoteToInvoice(ADocument.FUBLCreditNote, ADocument.FInvoice, D);
  end
  else
  begin
    ADocument.FInfo.Syntax := esy_CII;
    ADocument.FInfo.CustomizationID :=
      ADocument.FCII.ExchangedDocumentContext.GuidelineSpecifiedDocumentContextParameter.ID.Value;
    ADocument.FInfo.ProfileID :=
      ADocument.FCII.ExchangedDocumentContext.BusinessProcessSpecifiedDocumentContextParameter.ID.Value;
    Path := CIICustomizationPath;
    LandrixEInvoiceCIIToInvoice(ADocument.FCII, ADocument.FInvoice, D);
  end;
  ADocument.FInfo.RootName := Root;
  ADocument.FInfo.SpecFound := LandrixEInvoiceDetectSpec(Root, ADocument.FInfo.CustomizationID,
    ADocument.FInfo.Spec, ADocument.FInfo.UsesExtension);
  if not ADocument.FInfo.SpecFound then
    D.AddDiagnostic(edk_UnknownCode, Path, 0, 0, 0, 'Unknown specification identifier (BT-24) ''' +
      ADocument.FInfo.CustomizationID + '''; read without a specification, no rule check').Severity := eds_Warning
  else if eio_CheckOnRead in AOptions then
    LandrixEInvoiceCheckInvoice(ADocument.FInvoice, ADocument.FInfo.Spec, D);
  if eio_InvoiceOnly in AOptions then
    ADocument.FreeSyntaxModel;
end;

procedure LoadXmlStream(AStream: TStream; ADocument: TLandrixEInvoiceDocument;
  AOptions: TLandrixEInvoiceOptions);
var
  R: TLandrixXmlReader;
begin
  R := TLandrixXmlReader.Create;
  try
    try
      R.LoadFromStream(AStream);
    except
      on E: ELandrixXmlError do
        raise FormatErrorOf(E);
    end;
    ReadXml(R, ADocument, AOptions);
  finally
    R.Free;
  end;
end;

{ --- TLandrixEInvoice ----------------------------------------------------- }

class procedure TLandrixEInvoice.SaveToFile(AInvoice: TLandrixInvoice; const AFileName: TLandrixEInvoiceString;
  const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  WriteFile(AFileName, Produce(mk_Invoice, AInvoice, ATarget, AOptions, ADiagnostics));
end;

class procedure TLandrixEInvoice.SaveToStream(AInvoice: TLandrixInvoice; AStream: TStream;
  const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  WriteBytes(AStream, Produce(mk_Invoice, AInvoice, ATarget, AOptions, ADiagnostics));
end;

class function TLandrixEInvoice.SaveToUtf8(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
begin
  Result := Produce(mk_Invoice, AInvoice, ATarget, AOptions, ADiagnostics);
end;

class function TLandrixEInvoice.SaveToText(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceUtf8ToString(Produce(mk_Invoice, AInvoice, ATarget, AOptions, ADiagnostics));
end;

class procedure TLandrixEInvoice.SaveToFile(ACII: TLandrixCIIInvoice; const AFileName: TLandrixEInvoiceString;
  const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  WriteFile(AFileName, Produce(mk_CII, ACII, ATarget, AOptions, ADiagnostics));
end;

class procedure TLandrixEInvoice.SaveToFile(AUBL: TLandrixUBLInvoice; const AFileName: TLandrixEInvoiceString;
  const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  WriteFile(AFileName, Produce(mk_UBLInvoice, AUBL, ATarget, AOptions, ADiagnostics));
end;

class procedure TLandrixEInvoice.SaveToFile(AUBL: TLandrixUBLCreditNote; const AFileName: TLandrixEInvoiceString;
  const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  WriteFile(AFileName, Produce(mk_UBLCreditNote, AUBL, ATarget, AOptions, ADiagnostics));
end;

class procedure TLandrixEInvoice.SaveToStream(ACII: TLandrixCIIInvoice; AStream: TStream;
  const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  WriteBytes(AStream, Produce(mk_CII, ACII, ATarget, AOptions, ADiagnostics));
end;

class procedure TLandrixEInvoice.SaveToStream(AUBL: TLandrixUBLInvoice; AStream: TStream;
  const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  WriteBytes(AStream, Produce(mk_UBLInvoice, AUBL, ATarget, AOptions, ADiagnostics));
end;

class procedure TLandrixEInvoice.SaveToStream(AUBL: TLandrixUBLCreditNote; AStream: TStream;
  const ATarget: TLandrixEInvoiceTarget; AOptions: TLandrixEInvoiceOptions;
  ADiagnostics: TLandrixEInvoiceDiagnostics);
begin
  WriteBytes(AStream, Produce(mk_UBLCreditNote, AUBL, ATarget, AOptions, ADiagnostics));
end;

class function TLandrixEInvoice.SaveToUtf8(ACII: TLandrixCIIInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
begin
  Result := Produce(mk_CII, ACII, ATarget, AOptions, ADiagnostics);
end;

class function TLandrixEInvoice.SaveToUtf8(AUBL: TLandrixUBLInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
begin
  Result := Produce(mk_UBLInvoice, AUBL, ATarget, AOptions, ADiagnostics);
end;

class function TLandrixEInvoice.SaveToUtf8(AUBL: TLandrixUBLCreditNote; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
begin
  Result := Produce(mk_UBLCreditNote, AUBL, ATarget, AOptions, ADiagnostics);
end;

class function TLandrixEInvoice.SaveToText(ACII: TLandrixCIIInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceUtf8ToString(Produce(mk_CII, ACII, ATarget, AOptions, ADiagnostics));
end;

class function TLandrixEInvoice.SaveToText(AUBL: TLandrixUBLInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceUtf8ToString(Produce(mk_UBLInvoice, AUBL, ATarget, AOptions, ADiagnostics));
end;

class function TLandrixEInvoice.SaveToText(AUBL: TLandrixUBLCreditNote; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixEInvoiceString;
begin
  Result := LandrixEInvoiceUtf8ToString(Produce(mk_UBLCreditNote, AUBL, ATarget, AOptions, ADiagnostics));
end;

class function TLandrixEInvoice.ToCII(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixCIIInvoice;
begin
  Result := LandrixEInvoiceInvoiceToCII(AInvoice, WritableSpec(ATarget, mk_CII), ADiagnostics);
end;

class function TLandrixEInvoice.ToUBLInvoice(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLInvoice;
begin
  Result := LandrixEInvoiceInvoiceToUBLInvoice(AInvoice, WritableSpec(ATarget, mk_UBLInvoice), ADiagnostics);
end;

class function TLandrixEInvoice.ToUBLCreditNote(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  ADiagnostics: TLandrixEInvoiceDiagnostics): TLandrixUBLCreditNote;
begin
  Result := LandrixEInvoiceInvoiceToUBLCreditNote(AInvoice, WritableSpec(ATarget, mk_UBLCreditNote), ADiagnostics);
end;

class function TLandrixEInvoice.Check(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := RunCheck(mk_Invoice, AInvoice, ATarget, ADiagnostics, AOptions);
end;

class function TLandrixEInvoice.Check(ACII: TLandrixCIIInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := RunCheck(mk_CII, ACII, ATarget, ADiagnostics, AOptions);
end;

class function TLandrixEInvoice.Check(AUBL: TLandrixUBLInvoice; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := RunCheck(mk_UBLInvoice, AUBL, ATarget, ADiagnostics, AOptions);
end;

class function TLandrixEInvoice.Check(AUBL: TLandrixUBLCreditNote; const ATarget: TLandrixEInvoiceTarget;
  AOptions: TLandrixEInvoiceOptions; ADiagnostics: TLandrixEInvoiceDiagnostics): Integer;
begin
  Result := RunCheck(mk_UBLCreditNote, AUBL, ATarget, ADiagnostics, AOptions);
end;

class function TLandrixEInvoice.LoadFromFile(const AFileName: TLandrixEInvoiceString;
  AOptions: TLandrixEInvoiceOptions): TLandrixEInvoiceDocument;
var
  S: TStream;
begin
  S := LandrixEInvoiceOpenFile(AFileName, efm_Read);
  try
    Result := LoadFromStream(S, AOptions);
  finally
    S.Free;
  end;
end;

class function TLandrixEInvoice.LoadFromStream(AStream: TStream;
  AOptions: TLandrixEInvoiceOptions): TLandrixEInvoiceDocument;
var
  Xml: TMemoryStream;
  Name: TLandrixEInvoiceString;
  Info: TLandrixEInvoicePdfExtractInfo;
begin
  Result := TLandrixEInvoiceDocument.Create;
  try
    if not (eio_NoPdf in AOptions) and TLandrixEInvoicePdfExtractor.IsPdfStream(AStream) then
    begin
      Xml := TMemoryStream.Create;
      try
        if not TLandrixEInvoicePdfExtractor.ExtractInvoiceFromStream(AStream, Xml, Name, Info) then
        begin
          if Info.Error = '' then
            raise ELandrixEInvoicePdfError.Create('The PDF contains no invoice');
          raise ELandrixEInvoicePdfError.Create('PDF: ' + string(Info.Error));
        end;
        Result.FInfo.Source := eso_Pdf;
        Result.FInfo.PdfAttachmentName := Name;
        Result.FInfo.Pdf := Info;
        Xml.Position := 0;
        LoadXmlStream(Xml, Result, AOptions);
      finally
        Xml.Free;
      end;
    end
    else
      LoadXmlStream(AStream, Result, AOptions);
  except
    Result.Free;
    raise;
  end;
end;

class function TLandrixEInvoice.LoadFromUtf8(const AXml: TLandrixXmlUtf8;
  AOptions: TLandrixEInvoiceOptions): TLandrixEInvoiceDocument;
var
  R: TLandrixXmlReader;
begin
  Result := TLandrixEInvoiceDocument.Create;
  try
    R := TLandrixXmlReader.Create;
    try
      try
        R.LoadFromUtf8(AXml);
      except
        on E: ELandrixXmlError do
          raise FormatErrorOf(E);
      end;
      ReadXml(R, Result, AOptions);
    finally
      R.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

class function TLandrixEInvoice.LoadFromText(const AXml: TLandrixEInvoiceString;
  AOptions: TLandrixEInvoiceOptions): TLandrixEInvoiceDocument;
var
  Bytes: TLandrixXmlUtf8;
begin
  try
    Bytes := LandrixEInvoiceStringToUtf8(AXml);
  except
    on E: ELandrixXmlError do
      raise FormatErrorOf(E);
  end;
  Result := LoadFromUtf8(Bytes, AOptions);
end;

end.
