{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Validates an e-invoice document as a whole: the KoSIT run of a
  configuration the caller chooses (well-formedness, XML schema,
  Schematron; LandrixEInvoiceValidator), reading through the facade and
  the library's own rule check. Only the KoSIT run decides the verdict;
  the own rule check predicts what KoSIT would report and never changes
  it (its findings are marked Predicted). Without a configuration there is
  no verdict (Incomplete); reading and the rule check still run. One flat
  list of findings, a status per part. So far XML only; PDF follows.

  DE: Prueft ein E-Rechnungs-Dokument als Ganzes: den KoSIT-Lauf einer
  Konfiguration, die der Aufrufer waehlt (Wohlgeformtheit, XML-Schema,
  Schematron; LandrixEInvoiceValidator), das Lesen ueber die Fassade und
  die eigene Regelpruefung der Bibliothek. Nur der KoSIT-Lauf entscheidet
  das Urteil; die eigene Regelpruefung sagt voraus, was KoSIT melden
  wuerde, und aendert es nie (ihre Befunde sind als Predicted markiert).
  Ohne Konfiguration gibt es kein Urteil (Incomplete); Lesen und
  Regelpruefung laufen trotzdem. Eine flache Befundliste, ein Status je
  Teil. Bisher nur XML; PDF folgt. }

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
  LandrixEInvoiceValidator;

type
  { The verdict on a document. Incomplete: no verdict could be reached
    because the part that decides it did not run (no KoSIT configuration).
    DE: Das Urteil ueber ein Dokument. Incomplete: es kam kein Urteil
    zustande, weil der Teil, der es entscheidet, nicht gelaufen ist (keine
    KoSIT-Konfiguration). }
  TLandrixEInvoiceVerdict = (ev_Accepted, ev_Rejected, ev_Incomplete);

  { The parts of a validation: reading through the facade, the KoSIT run,
    the own rule check (a prediction).
    DE: Die Teile einer Pruefung: Lesen ueber die Fassade, der KoSIT-Lauf,
    die eigene Regelpruefung (eine Vorhersage). }
  TLandrixEInvoiceValidationPart = (evp_Read, evp_KoSIT, evp_ModelCheck);

  { The status of a part. Failed: it found errors (reading: an error, or
    the document could not be read at all). Incomplete: it started but
    could not finish (a Schematron step that failed, a part that raised).
    DE: Der Status eines Teils. Failed: er hat Fehler gefunden (Lesen: ein
    Fehler, oder das Dokument liess sich gar nicht lesen). Incomplete: er
    hat begonnen, konnte aber nicht zu Ende laufen (ein Schematron-Schritt,
    der scheiterte, ein Teil, der eine Ausnahme ausloeste). }
  TLandrixEInvoicePartStatus = (evr_NotRun, evr_Passed, evr_Failed, evr_Incomplete);

  { One finding. RuleID: the KoSIT code (cvc-..., generic-error or the id
    of the assert or report), the rule identifier of the own rule check
    (e.g. BR-DE-15), for reading the kind of the diagnostic (e.g.
    UnknownElement); '' for a finding of the validation itself (no
    scenario, a processing error, a part that raised, a document that
    could not be read). Location: the XPath location (KoSIT) or the element
    path (reading, rule check); Line and Column 0 when unknown.
    DE: Ein Befund. RuleID: der KoSIT-Code (cvc-..., generic-error oder
    die id des asserts bzw. reports), die Regelkennung der eigenen
    Regelpruefung (z. B. BR-DE-15), beim Lesen die Art der Meldung (z. B.
    UnknownElement); '' fuer einen Befund der Pruefung selbst (kein
    Szenario, ein Verarbeitungsfehler, ein Teil mit Ausnahme, ein Dokument,
    das sich nicht lesen liess). Location: der XPath-Ort (KoSIT) oder der
    Elementpfad (Lesen, Regelpruefung); Line und Column 0, wenn
    unbekannt. }
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
  end;

  { The result of a validation.
    DE: Das Ergebnis einer Pruefung. }
  TLandrixEInvoiceDocumentValidation = class(TObject)
  private
    FVerdict: TLandrixEInvoiceVerdict;
    FStatus: array[TLandrixEInvoiceValidationPart] of TLandrixEInvoicePartStatus;
    FFindings: TObjectList;
    FScenarioName: TLandrixEInvoiceString;
    FInfo: TLandrixEInvoiceDocumentInfo;
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
    { Empties the result: ev_Incomplete, every part evr_NotRun, no findings.
      DE: Leert das Ergebnis: ev_Incomplete, jeder Teil evr_NotRun, keine
      Befunde. }
    procedure Clear;
    { The verdict: the assessment of the KoSIT run; ev_Incomplete without
      one.
      DE: Das Urteil: die Bewertung des KoSIT-Laufs; ev_Incomplete ohne
      ihn. }
    property Verdict: TLandrixEInvoiceVerdict read FVerdict;
    { The status of each part. DE: Der Status jedes Teils. }
    property Status[APart: TLandrixEInvoiceValidationPart]: TLandrixEInvoicePartStatus read GetStatus;
    { The findings in the order of the parts: KoSIT, reading, rule check.
      DE: Die Befunde in der Reihenfolge der Teile: KoSIT, Lesen,
      Regelpruefung. }
    property FindingCount: Integer read GetFindingCount;
    property Findings[AIndex: Integer]: TLandrixEInvoiceFinding read GetFinding; default;
    { The KoSIT scenario chosen, '' if none.
      DE: Das gewaehlte KoSIT-Szenario, '' wenn keines. }
    property ScenarioName: TLandrixEInvoiceString read FScenarioName;
    { What reading found out (syntax, BT-24, specification); empty when the
      document could not be read.
      DE: Was das Lesen herausgefunden hat (Syntax, BT-24, Spezifikation);
      leer, wenn das Dokument nicht gelesen werden konnte. }
    property Info: TLandrixEInvoiceDocumentInfo read FInfo;
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
      (the default): no KoSIT run, the verdict is ev_Incomplete.
      DE: Die KoSIT-Konfiguration, die laufen soll, vom Aufrufer geladen
      und besessen; nil (Vorgabe): kein KoSIT-Lauf, das Urteil ist
      ev_Incomplete. }
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
    procedure ReadAndCheck(AData: TMemoryStream; AResult: TLandrixEInvoiceDocumentValidation);
    procedure ValidateWithoutKosit(AStream: TStream; ACount: Int64; AResult: TLandrixEInvoiceDocumentValidation);
  public
    constructor Create;
    destructor Destroy; override;
    { Validates the XML document in AStream, read from its position to the
      end, fills AResult and returns AResult.Verdict. With
      Options.Configuration the verdict is the KoSIT assessment
      (ev_Accepted or ev_Rejected); without it KoSIT stays evr_NotRun and
      the verdict is ev_Incomplete. Reading and the own rule check run on
      the same bytes unless KoSIT finds the document not well-formed;
      without KoSIT, reading reports a document that is not well-formed. An
      exception of reading or of the rule check (other than EOutOfMemory)
      becomes a finding and leaves that part evr_Incomplete, or evr_Failed
      for a document the facade cannot read; the verdict stays. A problem
      of the setup (see TLandrixEInvoiceValidator.Validate) raises
      ELandrixEInvoiceError; an exception of AStream itself (e.g. EReadError)
      is passed on.
      DE: Prueft das XML-Dokument in AStream, gelesen ab seiner Position
      bis zum Ende, fuellt AResult und liefert AResult.Verdict. Mit
      Options.Configuration ist das Urteil die Bewertung von KoSIT
      (ev_Accepted oder ev_Rejected); ohne bleibt KoSIT evr_NotRun und das
      Urteil ist ev_Incomplete. Lesen und eigene Regelpruefung laufen auf
      denselben Bytes, ausser KoSIT findet das Dokument nicht wohlgeformt;
      ohne KoSIT meldet das Lesen ein nicht wohlgeformtes Dokument. Eine
      Ausnahme beim Lesen oder in der Regelpruefung (ausser EOutOfMemory)
      wird zum Befund und laesst den Teil evr_Incomplete, oder evr_Failed
      fuer ein Dokument, das die Fassade nicht lesen kann; das Urteil
      bleibt. Ein Problem der Einrichtung (siehe
      TLandrixEInvoiceValidator.Validate) loest ELandrixEInvoiceError aus;
      eine Ausnahme von AStream selbst (z. B. EReadError) wird
      weitergereicht. }
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
  LandrixEInvoiceCheck;

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

{ --- TLandrixEInvoiceDocumentValidation ---------------------------------- }

constructor TLandrixEInvoiceDocumentValidation.Create;
begin
  inherited Create;
  FFindings := TObjectList.Create(True);
  Clear;
end;

destructor TLandrixEInvoiceDocumentValidation.Destroy;
begin
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
  K: TLandrixEInvoiceValidationResult;
  M: TLandrixEInvoiceValidationMessage;
  Count: Int64;
  I: Integer;
  WellFormed: Boolean;
begin
  AResult.Clear;
  Count := 0;
  if AStream <> nil then
    Count := AStream.Size - AStream.Position;
  if FOptions.Configuration = nil then
  begin
    ValidateWithoutKosit(AStream, Count, AResult);
    Result := AResult.FVerdict;
    Exit;
  end;
  Data := TMemoryStream.Create;
  K := TLandrixEInvoiceValidationResult.Create;
  try
    { no stream or more than 2 GB: the engine reports it without reading }
    if (AStream = nil) or (Count > MaxInt) then
      FOptions.Configuration.ValidateStream(AStream, K)
    else
    begin
      { CopyFrom with 0 copies the whole stream: only when bytes are left }
      if Count > 0 then
        Data.CopyFrom(AStream, Count);
      Data.Position := 0;
      FOptions.Configuration.ValidateStream(Data, K);
    end;
    { the KoSIT run decides the verdict }
    AResult.FScenarioName := K.ScenarioName;
    WellFormed := True;
    for I := 0 to K.MessageCount - 1 do
    begin
      M := K[I];
      if M.Step = evs_Wellformedness then
        WellFormed := False;
      AResult.AddFinding(evp_KoSIT, M.Code, SeverityOf(M.EffectiveLevel), M.Location, M.Line, M.Column, M.Text);
    end;
    { KoSIT rejects without a message when no scenario is chosen (it
      chooses one when exactly one matches, whatever its name) }
    if WellFormed and (K.MatchCount <> 1) then
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
    { reading and the own rule check: findings only, never the verdict }
    if WellFormed then
      ReadAndCheck(Data, AResult);
  finally
    K.Free;
    Data.Free;
  end;
  Result := AResult.FVerdict;
end;

{ No KoSIT run: no verdict; reading and the rule check only. Reading
  reports a document that is not well-formed. }
procedure TLandrixEInvoiceDocumentValidator.ValidateWithoutKosit(AStream: TStream; ACount: Int64;
  AResult: TLandrixEInvoiceDocumentValidation);
var
  Data: TMemoryStream;
begin
  if AStream = nil then
    AResult.AddFinding(evp_Read, '', eds_Error, '', 0, 0, 'No document (no stream)')
  else if ACount > MaxInt then
    AResult.AddFinding(evp_Read, '', eds_Error, '', 0, 0, 'The document is larger than 2 GB')
  else
  begin
    Data := TMemoryStream.Create;
    try
      { CopyFrom with 0 copies the whole stream: only when bytes are left }
      if ACount > 0 then
        Data.CopyFrom(AStream, ACount);
      ReadAndCheck(Data, AResult);
    finally
      Data.Free;
    end;
    Exit;
  end;
  AResult.FStatus[evp_Read] := evr_Failed;
end;

procedure TLandrixEInvoiceDocumentValidator.ReadAndCheck(AData: TMemoryStream;
  AResult: TLandrixEInvoiceDocumentValidation);
var
  Doc: TLandrixEInvoiceDocument;
  D: TLandrixEInvoiceDiagnostics;
  I: TLandrixEInvoiceListIndex;
  Errors: Integer;
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
