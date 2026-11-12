{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Validates an e-invoice document as a whole, XML or a hybrid PDF
  (ZUGFeRD, Factur-X; told by the content): the KoSIT run of a
  configuration the caller chooses (well-formedness, XML schema,
  Schematron; LandrixEInvoiceValidator), reading through the facade and
  the library's own rule check; for a PDF first the embedding of the XML
  and the XMP metadata (levels 2 and 3, LandrixEInvoicePdfCheck), then the
  same for the embedded invoice. For XML only the KoSIT run decides the
  verdict; for a PDF levels 2 and 3 decide with it. The own rule check
  predicts what KoSIT would report and never changes it (its findings are
  marked Predicted). Without a configuration an XML document gets no
  verdict (Incomplete), a PDF only a rejection by levels 2 and 3; reading
  and the rule check still run. PDF/A (level 1) is not checked. One flat
  list of findings, a status per part.

  DE: Prueft ein E-Rechnungs-Dokument als Ganzes, XML oder ein hybrides
  PDF (ZUGFeRD, Factur-X; am Inhalt erkannt): den KoSIT-Lauf einer
  Konfiguration, die der Aufrufer waehlt (Wohlgeformtheit, XML-Schema,
  Schematron; LandrixEInvoiceValidator), das Lesen ueber die Fassade und
  die eigene Regelpruefung der Bibliothek; bei einem PDF zuerst die
  Einbettung der XML und die XMP-Metadaten (Ebenen 2 und 3,
  LandrixEInvoicePdfCheck), dann dasselbe fuer die eingebettete Rechnung.
  Bei XML entscheidet nur der KoSIT-Lauf das Urteil, bei einem PDF
  entscheiden die Ebenen 2 und 3 mit. Die eigene Regelpruefung sagt
  voraus, was KoSIT melden wuerde, und aendert es nie (ihre Befunde sind
  als Predicted markiert). Ohne Konfiguration bekommt ein XML-Dokument
  kein Urteil (Incomplete), ein PDF nur eine Ablehnung durch die Ebenen 2
  und 3; Lesen und Regelpruefung laufen trotzdem. PDF/A (Ebene 1) wird
  nicht geprueft. Eine flache Befundliste, ein Status je Teil. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceValidation;

{$I LandrixEInvoice.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoice,
  LandrixEInvoicePdfCheck,
  LandrixEInvoiceValidator;

type
  { The verdict on a document. Incomplete: no verdict could be reached
    because a part that decides it did not run or is incomplete (no KoSIT
    configuration; for a PDF also level 2 or 3).
    DE: Das Urteil ueber ein Dokument. Incomplete: es kam kein Urteil
    zustande, weil ein Teil, der es entscheidet, nicht gelaufen oder
    unvollstaendig ist (keine KoSIT-Konfiguration; bei einem PDF auch
    Ebene 2 oder 3). }
  TLandrixEInvoiceVerdict = (ev_Accepted, ev_Rejected, ev_Incomplete);

  { The parts of a validation: reading through the facade, the KoSIT run,
    the own rule check (a prediction); for a PDF the embedding of the XML
    (level 2), the XMP metadata (level 3) and PDF/A (level 1, not
    implemented: always evr_NotRun).
    DE: Die Teile einer Pruefung: Lesen ueber die Fassade, der KoSIT-Lauf,
    die eigene Regelpruefung (eine Vorhersage); bei einem PDF die
    Einbettung der XML (Ebene 2), die XMP-Metadaten (Ebene 3) und PDF/A
    (Ebene 1, nicht umgesetzt: immer evr_NotRun). }
  TLandrixEInvoiceValidationPart = (evp_Read, evp_KoSIT, evp_ModelCheck, evp_PdfEmbedding, evp_PdfMetadata,
    evp_PdfA);

  { The status of a part. Failed: it found errors (reading: an error, or
    the document could not be read at all). Incomplete: it started but
    could not finish (a Schematron step that failed, a part that raised).
    DE: Der Status eines Teils. Failed: er hat Fehler gefunden (Lesen: ein
    Fehler, oder das Dokument liess sich gar nicht lesen). Incomplete: er
    hat begonnen, konnte aber nicht zu Ende laufen (ein Schematron-Schritt,
    der scheiterte, ein Teil, der eine Ausnahme ausloeste). }
  TLandrixEInvoicePartStatus = (evr_NotRun, evr_Passed, evr_Failed, evr_Incomplete);

  { The KoSIT step that reported a finding (well-formedness, XML schema,
    Schematron); efs_None for every other finding, also for the KoSIT
    findings of the validation itself (no scenario, a processing error).
    DE: Der KoSIT-Schritt, der einen Befund gemeldet hat (Wohlgeformtheit,
    XML-Schema, Schematron); efs_None fuer jeden anderen Befund, auch fuer
    die KoSIT-Befunde der Pruefung selbst (kein Szenario, ein
    Verarbeitungsfehler). }
  TLandrixEInvoiceFindingStep = (efs_None, efs_Wellformedness, efs_XmlSchema, efs_Schematron);

  { One finding. RuleID: the KoSIT code (cvc-..., generic-error or the id
    of the assert or report), the rule identifier of the own rule check
    (e.g. BR-DE-15), for reading the kind of the diagnostic (e.g.
    UnknownElement); '' for a finding of the validation itself (no
    scenario, a processing error, a part that raised, a document that
    could not be read), the rule of the PDF checker (BR-HYBRID-..,
    LX-PDF-..). Location: the XPath location (KoSIT), the element path
    (reading, rule check) or the place in the PDF as the PDF checker writes
    it (e.g. /Root/Names/EmbeddedFiles/Names[1]/UF, XMP fx:Version); Line
    and Column 0 when unknown (KoSIT, reading, the rule check and
    BR-HYBRID-12: in the invoice XML; LX-PDF-11: in the XMP packet).
    DE: Ein Befund. RuleID: der KoSIT-Code (cvc-..., generic-error oder
    die id des asserts bzw. reports), die Regelkennung der eigenen
    Regelpruefung (z. B. BR-DE-15), beim Lesen die Art der Meldung (z. B.
    UnknownElement); '' fuer einen Befund der Pruefung selbst (kein
    Szenario, ein Verarbeitungsfehler, ein Teil mit Ausnahme, ein Dokument,
    das sich nicht lesen liess), die Regel des PDF-Pruefers (BR-HYBRID-..,
    LX-PDF-..). Location: der XPath-Ort (KoSIT), der Elementpfad (Lesen,
    Regelpruefung) oder der Ort im PDF, wie der PDF-Pruefer ihn schreibt
    (z. B. /Root/Names/EmbeddedFiles/Names[1]/UF, XMP fx:Version); Line
    und Column 0, wenn unbekannt (KoSIT, Lesen, Regelpruefung und
    BR-HYBRID-12: in der Rechnungs-XML; LX-PDF-11: im XMP-Paket). }
  TLandrixEInvoiceFinding = class(TObject)
  private
    FPart: TLandrixEInvoiceValidationPart;
    FRuleID: TLandrixEInvoiceString;
    FSeverity: TLandrixEInvoiceDiagnosticSeverity;
    FLocation: TLandrixEInvoiceString;
    FLine: Integer;
    FColumn: Integer;
    FText: TLandrixEInvoiceString;
    FPredicted: Boolean;
    FStep: TLandrixEInvoiceFindingStep;
  public
    { The part that reported it. DE: Der Teil, der ihn gemeldet hat. }
    property Part: TLandrixEInvoiceValidationPart read FPart;
    property RuleID: TLandrixEInvoiceString read FRuleID;
    { KoSIT: the effective level (after customLevel).
      DE: KoSIT: die wirksame Stufe (nach customLevel). }
    property Severity: TLandrixEInvoiceDiagnosticSeverity read FSeverity;
    property Location: TLandrixEInvoiceString read FLocation;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    { The message (English, or as the rule set writes it).
      DE: Der Meldungstext (englisch, oder wie das Regelwerk ihn schreibt). }
    property Text: TLandrixEInvoiceString read FText;
    { True for the rule findings of the own rule check: they predict what KoSIT
      would report, they do not replace it.
      DE: True fuer die Befunde der eigenen Regelpruefung: sie sagen
      voraus, was KoSIT melden wuerde, sie ersetzen es nicht. }
    property Predicted: Boolean read FPredicted;
    { KoSIT: the step that reported it; efs_None otherwise.
      DE: KoSIT: der Schritt, der ihn gemeldet hat; sonst efs_None. }
    property Step: TLandrixEInvoiceFindingStep read FStep;
  end;

  { The result of a validation.
    DE: Das Ergebnis einer Pruefung. }
  TLandrixEInvoiceDocumentValidation = class(TObject)
  private
    FVerdict: TLandrixEInvoiceVerdict;
    FStatus: array[TLandrixEInvoiceValidationPart] of TLandrixEInvoicePartStatus;
    FFindings: TObjectList;
    FScenarioName: TLandrixEInvoiceString;
    FConfigurationName: TLandrixEInvoiceString;
    FInfo: TLandrixEInvoiceDocumentInfo;
    FPdf: TLandrixEInvoicePdfCheckResult;
    function GetStatus(APart: TLandrixEInvoiceValidationPart): TLandrixEInvoicePartStatus;
    function GetFindingCount: Integer;
    function GetFinding(AIndex: Integer): TLandrixEInvoiceFinding;
    procedure AddFailure(APart: TLandrixEInvoiceValidationPart; E: Exception);
    function AddFinding(APart: TLandrixEInvoiceValidationPart; const ARuleID: TLandrixEInvoiceString;
      ASeverity: TLandrixEInvoiceDiagnosticSeverity; const ALocation: TLandrixEInvoiceString;
      ALine, AColumn: Integer; const AText: TLandrixEInvoiceString): TLandrixEInvoiceFinding;
  public
    constructor Create;
    destructor Destroy; override;
    { Empties the result: ev_Incomplete, every part evr_NotRun, no findings,
      Pdf nil.
      DE: Leert das Ergebnis: ev_Incomplete, jeder Teil evr_NotRun, keine
      Befunde, Pdf nil. }
    procedure Clear;
    { The verdict: for XML the assessment of the KoSIT run (ev_Incomplete
      without one); for a PDF ev_Rejected if KoSIT rejects or level 2 or 3
      failed, ev_Incomplete if one of them did not run or is incomplete,
      ev_Accepted otherwise (PDF/A does not count). KoSIT rejects also when
      it could not finish (a processing error, KoSIT evr_Incomplete).
      DE: Das Urteil: bei XML die Bewertung des KoSIT-Laufs (ev_Incomplete
      ohne ihn); bei einem PDF ev_Rejected, wenn KoSIT ablehnt oder Ebene 2
      oder 3 fehlschlug, ev_Incomplete, wenn eine davon nicht lief oder
      unvollstaendig ist, sonst ev_Accepted (PDF/A zaehlt nicht mit). KoSIT
      lehnt auch ab, wenn es nicht zu Ende kam (ein Verarbeitungsfehler,
      KoSIT evr_Incomplete). }
    property Verdict: TLandrixEInvoiceVerdict read FVerdict;
    { The status of each part. DE: Der Status jedes Teils. }
    property Status[APart: TLandrixEInvoiceValidationPart]: TLandrixEInvoicePartStatus read GetStatus;
    { The findings in the order: PDF embedding, PDF metadata, KoSIT,
      reading, rule check.
      DE: Die Befunde in der Reihenfolge: PDF-Einbettung, PDF-Metadaten,
      KoSIT, Lesen, Regelpruefung. }
    property FindingCount: Integer read GetFindingCount;
    property Findings[AIndex: Integer]: TLandrixEInvoiceFinding read GetFinding; default;
    { The KoSIT scenario chosen, '' if none.
      DE: Das gewaehlte KoSIT-Szenario, '' wenn keines. }
    property ScenarioName: TLandrixEInvoiceString read FScenarioName;
    { The name of the KoSIT configuration that ran (its scenarios/name, as
      it was at the time of the run), '' without a KoSIT run.
      DE: Der Name der KoSIT-Konfiguration, die lief (ihr scenarios/name,
      wie er zur Zeit des Laufs war), '' ohne KoSIT-Lauf. }
    property ConfigurationName: TLandrixEInvoiceString read FConfigurationName;
    { What reading found out (syntax, BT-24, specification); empty when the
      document could not be read, except for a PDF: Source eso_Pdf and
      PdfAttachmentName are always set (Pdf has the details).
      DE: Was das Lesen herausgefunden hat (Syntax, BT-24, Spezifikation);
      leer, wenn das Dokument nicht gelesen werden konnte, ausser bei einem
      PDF: Source eso_Pdf und PdfAttachmentName sind immer gesetzt (Pdf hat
      die Einzelheiten). }
    property Info: TLandrixEInvoiceDocumentInfo read FInfo;
    { For a PDF the result of the PDF checker (hybrid kind, file names, XMP
      values, versions, the embedded invoice bytes); nil for XML. Owned by
      the result; read only. Status and Findings of the validation are
      authoritative, Pdf.Diagnostics is their raw source.
      DE: Bei einem PDF das Ergebnis des PDF-Pruefers (hybride Art,
      Dateinamen, XMP-Werte, Versionen, die eingebetteten Rechnungsbytes);
      nil bei XML. Gehoert dem Ergebnis; nur lesen. Status und Findings der
      Pruefung sind massgeblich, Pdf.Diagnostics ist ihre Rohquelle. }
    property Pdf: TLandrixEInvoicePdfCheckResult read FPdf;
  end;

  { The options of a validation.
    DE: Die Optionen einer Pruefung. }
  TLandrixEInvoiceValidationOptions = class(TObject)
  private
    FConfiguration: TLandrixEInvoiceValidator;
    FModelCheck: Boolean;
  public
    constructor Create;
    { The KoSIT configuration to run, loaded and owned by the caller; nil
      (the default): no KoSIT run, the verdict is ev_Incomplete (for a PDF
      ev_Rejected if level 2 or 3 failed).
      DE: Die KoSIT-Konfiguration, die laufen soll, vom Aufrufer geladen
      und besessen; nil (Vorgabe): kein KoSIT-Lauf, das Urteil ist
      ev_Incomplete (bei einem PDF ev_Rejected, wenn Ebene 2 oder 3
      fehlschlug). }
    property Configuration: TLandrixEInvoiceValidator read FConfiguration write FConfiguration;
    { Run the own rule check (default True).
      DE: Die eigene Regelpruefung ausfuehren (Vorgabe True). }
    property ModelCheck: Boolean read FModelCheck write FModelCheck;
  end;

  { Validates documents with its Options.
    DE: Prueft Dokumente mit seinen Options. }
  TLandrixEInvoiceDocumentValidator = class(TObject)
  private
    FOptions: TLandrixEInvoiceValidationOptions;
    procedure RunKosit(AData: TStream; AResult: TLandrixEInvoiceDocumentValidation; out AWellFormed: Boolean);
    procedure ValidatePdf(AData: TMemoryStream; AResult: TLandrixEInvoiceDocumentValidation);
    procedure ReadAndCheck(AData: TMemoryStream; AResult: TLandrixEInvoiceDocumentValidation;
      APdfChecker: TLandrixEInvoicePdfChecker);
  public
    constructor Create;
    destructor Destroy; override;
    { Validates the document in AStream, read from its position to the end
      (a hybrid PDF if it starts with %PDF-, XML otherwise), fills AResult
      and returns AResult.Verdict (see Verdict). For XML: with
      Options.Configuration the verdict is the KoSIT assessment; without it
      KoSIT stays evr_NotRun and the verdict is ev_Incomplete. Reading and
      the own rule check run on the same bytes unless KoSIT finds the
      document not well-formed; without KoSIT, reading reports a document
      that is not well-formed. For a PDF: levels 2 and 3 first, then the
      same for the embedded invoice, if level 2 found one; reading also
      runs the second pass of the PDF checker (profile and country rules),
      without it level 2 is at most evr_Incomplete. An exception of reading
      or of the rule check (other than EOutOfMemory) becomes a finding and
      leaves that part evr_Incomplete, or evr_Failed for a document the
      facade cannot read; the verdict stays. A problem of the setup (see
      TLandrixEInvoiceValidator.Validate) raises ELandrixEInvoiceError; an
      exception of AStream itself (e.g. EReadError) is passed on.
      DE: Prueft das Dokument in AStream, gelesen ab seiner Position bis
      zum Ende (ein hybrides PDF, wenn es mit %PDF- beginnt, sonst XML),
      fuellt AResult und liefert AResult.Verdict (siehe Verdict). Bei XML:
      mit Options.Configuration ist das Urteil die Bewertung von KoSIT;
      ohne bleibt KoSIT evr_NotRun und das Urteil ist ev_Incomplete. Lesen
      und eigene Regelpruefung laufen auf denselben Bytes, ausser KoSIT
      findet das Dokument nicht wohlgeformt; ohne KoSIT meldet das Lesen
      ein nicht wohlgeformtes Dokument. Bei einem PDF: zuerst die Ebenen 2
      und 3, dann dasselbe fuer die eingebettete Rechnung, wenn Ebene 2
      eine gefunden hat; das Lesen fuehrt auch den zweiten Durchgang des
      PDF-Pruefers aus (Profil- und Laenderregeln), ohne ihn ist Ebene 2
      hoechstens evr_Incomplete. Eine Ausnahme beim Lesen oder in der
      Regelpruefung (ausser EOutOfMemory) wird zum Befund und laesst den
      Teil evr_Incomplete, oder evr_Failed fuer ein Dokument, das die
      Fassade nicht lesen kann; das Urteil bleibt. Ein Problem der
      Einrichtung (siehe TLandrixEInvoiceValidator.Validate) loest
      ELandrixEInvoiceError aus; eine Ausnahme von AStream selbst (z. B.
      EReadError) wird weitergereicht. }
    function ValidateStream(AStream: TStream; AResult: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
    { The same for a file; a file that cannot be opened raises the
      exception of TFileStream (EFOpenError).
      DE: Dasselbe fuer eine Datei; eine Datei, die sich nicht oeffnen
      laesst, loest die Ausnahme von TFileStream aus (EFOpenError). }
    function ValidateFile(const AFileName: string; AResult: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
    { The options, owned by the validator.
      DE: Die Optionen, im Besitz des Pruefers. }
    property Options: TLandrixEInvoiceValidationOptions read FOptions;
  end;

implementation

uses
  LandrixEInvoiceCheck,
  LandrixEInvoicePdf;

function SeverityOf(ALevel: TLandrixEInvoiceValidationLevel): TLandrixEInvoiceDiagnosticSeverity;
begin
  case ALevel of
    evl_Information:
      Result := eds_Info;
    evl_Warning:
      Result := eds_Warning;
  else
    Result := eds_Error;
  end;
end;

function StepOf(AStep: TLandrixEInvoiceValidationStep): TLandrixEInvoiceFindingStep;
begin
  case AStep of
    evs_Wellformedness:
      Result := efs_Wellformedness;
    evs_XmlSchema:
      Result := efs_XmlSchema;
  else
    Result := efs_Schematron;
  end;
end;

{ --- TLandrixEInvoiceDocumentValidation ---------------------------------- }

constructor TLandrixEInvoiceDocumentValidation.Create;
begin
  inherited Create;
  FFindings := TObjectList.Create(True);
  Clear;
end;

destructor TLandrixEInvoiceDocumentValidation.Destroy;
begin
  FPdf.Free;
  FFindings.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoiceDocumentValidation.Clear;
var
  P: TLandrixEInvoiceValidationPart;
begin
  FVerdict := ev_Incomplete;
  for P := Low(TLandrixEInvoiceValidationPart) to High(TLandrixEInvoiceValidationPart) do
    FStatus[P] := evr_NotRun;
  FFindings.Clear;
  FScenarioName := '';
  FConfigurationName := '';
  FPdf.Free;
  FPdf := nil;
  Finalize(FInfo);
  FillChar(FInfo, SizeOf(FInfo), 0);
end;

function TLandrixEInvoiceDocumentValidation.GetStatus(APart: TLandrixEInvoiceValidationPart): TLandrixEInvoicePartStatus;
begin
  Result := FStatus[APart];
end;

function TLandrixEInvoiceDocumentValidation.GetFindingCount: Integer;
begin
  Result := Integer(FFindings.Count);
end;

function TLandrixEInvoiceDocumentValidation.GetFinding(AIndex: Integer): TLandrixEInvoiceFinding;
begin
  Result := TLandrixEInvoiceFinding(FFindings[AIndex]);
end;

function TLandrixEInvoiceDocumentValidation.AddFinding(APart: TLandrixEInvoiceValidationPart;
  const ARuleID: TLandrixEInvoiceString; ASeverity: TLandrixEInvoiceDiagnosticSeverity;
  const ALocation: TLandrixEInvoiceString; ALine, AColumn: Integer;
  const AText: TLandrixEInvoiceString): TLandrixEInvoiceFinding;
begin
  Result := TLandrixEInvoiceFinding.Create;
  FFindings.Add(Result);
  Result.FPart := APart;
  Result.FRuleID := ARuleID;
  Result.FSeverity := ASeverity;
  Result.FLocation := ALocation;
  Result.FLine := ALine;
  Result.FColumn := AColumn;
  Result.FText := AText;
  Result.FPredicted := (APart = evp_ModelCheck) and (ARuleID <> '');
  Result.FStep := efs_None;
end;

{ A part that raised: a document the facade cannot read fails reading;
  anything else leaves the part incomplete. }
procedure TLandrixEInvoiceDocumentValidation.AddFailure(APart: TLandrixEInvoiceValidationPart; E: Exception);
var
  Line, Column: Integer;
begin
  if (APart = evp_Read) and (E is ELandrixEInvoiceError) then
  begin
    Line := 0;
    Column := 0;
    if E is ELandrixEInvoiceFormatError then
    begin
      Line := ELandrixEInvoiceFormatError(E).Line;
      Column := ELandrixEInvoiceFormatError(E).Column;
    end;
    AddFinding(APart, '', eds_Error, '', Line, Column, TLandrixEInvoiceString(E.Message));
    FStatus[APart] := evr_Failed;
  end
  else
  begin
    AddFinding(APart, '', eds_Error, '', 0, 0, TLandrixEInvoiceString(E.ClassName + ': ' + E.Message));
    FStatus[APart] := evr_Incomplete;
  end;
end;

{ --- TLandrixEInvoiceValidationOptions ----------------------------------- }

constructor TLandrixEInvoiceValidationOptions.Create;
begin
  inherited Create;
  FModelCheck := True;
end;

{ --- TLandrixEInvoiceDocumentValidator ----------------------------------- }

constructor TLandrixEInvoiceDocumentValidator.Create;
begin
  inherited Create;
  FOptions := TLandrixEInvoiceValidationOptions.Create;
end;

destructor TLandrixEInvoiceDocumentValidator.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

function TLandrixEInvoiceDocumentValidator.ValidateFile(const AFileName: string;
  AResult: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := ValidateStream(F, AResult);
  finally
    F.Free;
  end;
end;

function TLandrixEInvoiceDocumentValidator.ValidateStream(AStream: TStream;
  AResult: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
var
  Data: TMemoryStream;
  Count: Int64;
  WellFormed: Boolean;
begin
  AResult.Clear;
  Count := 0;
  if AStream <> nil then
    Count := AStream.Size - AStream.Position;
  if (AStream = nil) or (Count > MaxInt) then
  begin
    { no stream or more than 2 GB: the engine reports it without reading }
    if FOptions.Configuration <> nil then
      RunKosit(AStream, AResult, WellFormed)
    else
    begin
      if AStream = nil then
        AResult.AddFinding(evp_Read, '', eds_Error, '', 0, 0, 'No document (no stream)')
      else
        AResult.AddFinding(evp_Read, '', eds_Error, '', 0, 0, 'The document is larger than 2 GB');
      AResult.FStatus[evp_Read] := evr_Failed;
    end;
    Result := AResult.FVerdict;
    Exit;
  end;
  Data := TMemoryStream.Create;
  try
    { CopyFrom with 0 copies the whole stream: only when bytes are left }
    if Count > 0 then
      Data.CopyFrom(AStream, Count);
    Data.Position := 0;
    if TLandrixEInvoicePdfExtractor.IsPdfStream(Data) then
      ValidatePdf(Data, AResult)
    else
    begin
      { XML: the KoSIT run decides; without it there is no verdict }
      WellFormed := True;
      if FOptions.Configuration <> nil then
        RunKosit(Data, AResult, WellFormed);
      if WellFormed then
        ReadAndCheck(Data, AResult, nil);
    end;
  finally
    Data.Free;
  end;
  Result := AResult.FVerdict;
end;

{ Runs the configuration on AData (nil or more than 2 GB: the engine
  reports it), adds its findings, sets the KoSIT status and the verdict to
  its assessment. AWellFormed: False if KoSIT found the document not
  well-formed. }
procedure TLandrixEInvoiceDocumentValidator.RunKosit(AData: TStream; AResult: TLandrixEInvoiceDocumentValidation;
  out AWellFormed: Boolean);
var
  K: TLandrixEInvoiceValidationResult;
  M: TLandrixEInvoiceValidationMessage;
  I: Integer;
begin
  K := TLandrixEInvoiceValidationResult.Create;
  try
    FOptions.Configuration.ValidateStream(AData, K);
    AResult.FScenarioName := K.ScenarioName;
    AResult.FConfigurationName := FOptions.Configuration.Name;
    AWellFormed := True;
    for I := 0 to K.MessageCount - 1 do
    begin
      M := K[I];
      if M.Step = evs_Wellformedness then
        AWellFormed := False;
      AResult.AddFinding(evp_KoSIT, M.Code, SeverityOf(M.EffectiveLevel), M.Location, M.Line, M.Column,
        M.Text).FStep := StepOf(M.Step);
    end;
    { KoSIT rejects without a message when no scenario is chosen (it
      chooses one when exactly one matches, whatever its name) }
    if AWellFormed and (K.MatchCount <> 1) then
      if K.MatchCount = 0 then
        AResult.AddFinding(evp_KoSIT, '', eds_Error, '', 0, 0, 'No scenario of the configuration matches the document')
      else
        AResult.AddFinding(evp_KoSIT, '', eds_Error, '', 0, 0,
          TLandrixEInvoiceString(IntToStr(K.MatchCount) + ' scenarios match the document; none is chosen'));
    if K.ProcessingError <> '' then
    begin
      AResult.AddFinding(evp_KoSIT, '', eds_Error, '', 0, 0, K.ProcessingError);
      AResult.FStatus[evp_KoSIT] := evr_Incomplete;
    end
    else if K.Accepted then
      AResult.FStatus[evp_KoSIT] := evr_Passed
    else
      AResult.FStatus[evp_KoSIT] := evr_Failed;
    if K.Accepted then
      AResult.FVerdict := ev_Accepted
    else
      AResult.FVerdict := ev_Rejected;
  finally
    K.Free;
  end;
end;

function PartStatusOf(AStatus: TLandrixEInvoicePdfLevelStatus): TLandrixEInvoicePartStatus;
begin
  case AStatus of
    eps_Passed:
      Result := evr_Passed;
    eps_Failed:
      Result := evr_Failed;
    eps_Incomplete:
      Result := evr_Incomplete;
  else
    Result := evr_NotRun;
  end;
end;

{ The level of a finding of the PDF checker: level 3 paths start with
  "XMP " or are /Root/Metadata (LandrixEInvoicePdfCheck), everything else is
  level 2. }
function IsMetadataFinding(const APath: TLandrixEInvoiceString): Boolean;
begin
  Result := (Copy(APath, 1, 4) = 'XMP ') or (APath = '/Root/Metadata');
end;

{ A hybrid PDF: levels 2 and 3, then the embedded invoice through KoSIT,
  reading (with the second pass of the PDF checker) and the rule check.
  The verdict: rejected if KoSIT rejects or level 2 or 3 failed;
  incomplete if one of them did not run or is incomplete; accepted
  otherwise. PDF/A (level 1) is not checked and does not count.
  DE: Ein hybrides PDF: Ebenen 2 und 3, dann die eingebettete Rechnung
  durch KoSIT, Lesen (mit dem zweiten Durchgang des PDF-Pruefers) und
  Regelpruefung. Das Urteil: abgelehnt, wenn KoSIT ablehnt oder Ebene 2
  oder 3 fehlschlug; unvollstaendig, wenn eine davon nicht lief oder
  unvollstaendig ist; sonst angenommen. PDF/A (Ebene 1) wird nicht
  geprueft und zaehlt nicht mit. }
procedure TLandrixEInvoiceDocumentValidator.ValidatePdf(AData: TMemoryStream;
  AResult: TLandrixEInvoiceDocumentValidation);
var
  Checker: TLandrixEInvoicePdfChecker;
  Pdf: TLandrixEInvoicePdfCheckResult;
  D: TLandrixEInvoiceDiagnostics;
  First, J: Integer;
  I: TLandrixEInvoiceListIndex;
  WellFormed, Metadata: Boolean;
  Embedding, Meta, Kosit: TLandrixEInvoicePartStatus;
begin
  Pdf := TLandrixEInvoicePdfCheckResult.Create;
  AResult.FPdf := Pdf;
  Checker := TLandrixEInvoicePdfChecker.Create;
  try
    Checker.CheckStream(AData, Pdf);
    { the embedded invoice, if level 2 found one with bytes }
    if (Pdf.HybridKind <> ehk_None) and (Pdf.Invoice.Size > 0) then
    begin
      WellFormed := True;
      if FOptions.Configuration <> nil then
        RunKosit(Pdf.Invoice, AResult, WellFormed);
      if WellFormed then
        ReadAndCheck(Pdf.Invoice, AResult, Checker);
    end;
  finally
    Checker.Free;
  end;
  AResult.FInfo.Source := eso_Pdf;
  AResult.FInfo.PdfAttachmentName := Pdf.InvoiceFileName;
  { the findings of levels 2 and 3 go first, in this order }
  First := AResult.FindingCount;
  D := Pdf.Diagnostics;
  for Metadata := False to True do
    for I := 0 to D.Count - 1 do
      if IsMetadataFinding(D[I].Path) = Metadata then
        if Metadata then
          AResult.AddFinding(evp_PdfMetadata, D[I].RuleID, D[I].Severity, D[I].Path, D[I].Line, D[I].Column,
            D[I].Message)
        else
          AResult.AddFinding(evp_PdfEmbedding, D[I].RuleID, D[I].Severity, D[I].Path, D[I].Line, D[I].Column,
            D[I].Message);
  for J := 0 to AResult.FindingCount - First - 1 do
    AResult.FFindings.Move(First + J, J);
  Embedding := PartStatusOf(Pdf.Status[epl_Embedding]);
  { the profile and country rules need the facts of the invoice: without
    them level 2 is not complete }
  if (Embedding = evr_Passed) and (Pdf.HybridKind in [ehk_FacturX, ehk_XRechnung]) and not Pdf.FactsChecked then
    Embedding := evr_Incomplete;
  Meta := PartStatusOf(Pdf.Status[epl_Metadata]);
  AResult.FStatus[evp_PdfEmbedding] := Embedding;
  AResult.FStatus[evp_PdfMetadata] := Meta;
  Kosit := AResult.FStatus[evp_KoSIT];
  if (Embedding = evr_Failed) or (Meta = evr_Failed) or
     ((FOptions.Configuration <> nil) and (AResult.FVerdict = ev_Rejected)) then
    AResult.FVerdict := ev_Rejected
  else if (Embedding <> evr_Passed) or (Meta <> evr_Passed) or (Kosit <> evr_Passed) then
    AResult.FVerdict := ev_Incomplete
  else
    AResult.FVerdict := ev_Accepted;
end;

procedure TLandrixEInvoiceDocumentValidator.ReadAndCheck(AData: TMemoryStream;
  AResult: TLandrixEInvoiceDocumentValidation; APdfChecker: TLandrixEInvoicePdfChecker);
var
  Doc: TLandrixEInvoiceDocument;
  D: TLandrixEInvoiceDiagnostics;
  I: TLandrixEInvoiceListIndex;
  Errors: Integer;
  Facts: TLandrixEInvoicePdfInvoiceFacts;
begin
  Doc := nil;
  try
    AData.Position := 0;
    try
      Doc := TLandrixEInvoice.LoadFromStream(AData, [eio_NoPdf, eio_InvoiceOnly]);
    except
      on E: Exception do
      begin
        if E is EOutOfMemory then
          raise;
        AResult.AddFailure(evp_Read, E);
        Exit;
      end;
    end;
    AResult.FInfo := Doc.Info;
    for I := 0 to Doc.Diagnostics.Count - 1 do
      AResult.AddFinding(evp_Read, LandrixEInvoiceDiagnosticKindToStr(Doc.Diagnostics[I].Kind),
        Doc.Diagnostics[I].Severity, Doc.Diagnostics[I].Path, Doc.Diagnostics[I].Line,
        Doc.Diagnostics[I].Column, Doc.Diagnostics[I].Message);
    if Doc.Diagnostics.HasErrors then
      AResult.FStatus[evp_Read] := evr_Failed
    else
      AResult.FStatus[evp_Read] := evr_Passed;
    { second pass of the PDF checker with what reading found; without a
      known specification Target.Syntax still tells UBL (LX-PDF-10) }
    if APdfChecker <> nil then
    begin
      Facts.Target := Doc.Info.Spec.Target;
      if not Doc.Info.SpecFound then
        Facts.Target.Syntax := Doc.Info.Syntax;
      Facts.SellerCountryCode := Doc.Invoice.AccountingSupplierParty.Address.CountryCode;
      Facts.BuyerCountryCode := Doc.Invoice.AccountingCustomerParty.Address.CountryCode;
      APdfChecker.CheckInvoiceFacts(AResult.FPdf, Facts);
    end;
    { without a known specification (BT-24) there are no rules to check;
      reading reported it }
    if not FOptions.ModelCheck or not Doc.Info.SpecFound then
      Exit;
    D := TLandrixEInvoiceDiagnostics.Create;
    try
      try
        Errors := LandrixEInvoiceCheckInvoice(Doc.Invoice, Doc.Info.Spec, D);
      except
        on E: Exception do
        begin
          if E is EOutOfMemory then
            raise;
          AResult.AddFailure(evp_ModelCheck, E);
          Exit;
        end;
      end;
      for I := 0 to D.Count - 1 do
        AResult.AddFinding(evp_ModelCheck, D[I].RuleID, D[I].Severity, D[I].Path, D[I].Line, D[I].Column,
          D[I].Message);
      if Errors > 0 then
        AResult.FStatus[evp_ModelCheck] := evr_Failed
      else
        AResult.FStatus[evp_ModelCheck] := evr_Passed;
    finally
      D.Free;
    end;
  finally
    Doc.Free;
  end;
end;

end.
