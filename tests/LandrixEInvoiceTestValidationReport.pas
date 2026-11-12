{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Checks for the validation report (LandrixEInvoiceValidationReport): every
  report is valid against schemas/landrix-einvoice-validation-report-1.xsd
  and, read back, shows the verdict, the statuses and the findings of the
  result. The tests themselves are in LandrixEInvoiceTestValidator, which
  calls CheckValidationReport after its validations. }

unit LandrixEInvoiceTestValidationReport;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceValidation;

{ The report of AResult with ADocumentName as UTF-8. }
function ReportUtf8(AResult: TLandrixEInvoiceDocumentValidation;
  const ADocumentName: TLandrixEInvoiceString): TLandrixXmlUtf8;
{ The schema errors of AXml, '' if it is valid. }
function ReportSchemaErrors(const AXml: TLandrixXmlUtf8): string;
{ Writes the report of AResult, checks it against the schema and reads it
  back: verdict, statuses, findings (part, rule, severity, step, predicted,
  line, location, text) and counts as in AResult. }
procedure CheckValidationReport(AResult: TLandrixEInvoiceDocumentValidation; const AName: string);
{ AXml equals the golden report AFile in tests/data/validation-report/ (with
  @VERSION@ for the library version); on a difference the report is written
  to reports/ next to the test program. }
procedure CheckGoldenReport(const AXml: TLandrixXmlUtf8; const AFile: string);

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlReader,
  LandrixXmlDom,
  LandrixXmlXsdSchema,
  LandrixXmlXsdSchemaLoader,
  LandrixXmlXsdValidator,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoice,
  LandrixEInvoiceValidationReport,
  LandrixEInvoiceTestFramework;

const
  ReportNs = 'urn:landrix:einvoice:validation-report:1';
  { the tokens of the format, written down independently of the writer }
  VerdictTokens: array[TLandrixEInvoiceVerdict] of string = ('accepted', 'rejected', 'incomplete');
  PartTokens: array[TLandrixEInvoiceValidationPart] of string = ('read', 'kosit', 'modelCheck', 'pdfEmbedding',
    'pdfMetadata', 'pdfA');
  StatusTokens: array[TLandrixEInvoicePartStatus] of string = ('notRun', 'passed', 'failed', 'incomplete');
  SeverityTokens: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('info', 'warning', 'error');
  StepTokens: array[TLandrixEInvoiceFindingStep] of string = ('', 'wellformedness', 'xmlSchema', 'schematron');
  SourceTokens: array[TLandrixEInvoiceSource] of string = ('xml', 'pdf');

var
  Schema: TLandrixXmlXsdSchemaSet = nil;

function ReportSchema: TLandrixXmlXsdSchemaSet;
begin
  if Schema = nil then
    Schema := LandrixXmlXsdLoadSchema(RepositoryRoot + 'schemas' + PathDelim +
      'landrix-einvoice-validation-report-1.xsd');
  Result := Schema;
end;

function ReportUtf8(AResult: TLandrixEInvoiceDocumentValidation;
  const ADocumentName: TLandrixEInvoiceString): TLandrixXmlUtf8;
var
  W: TLandrixEInvoiceValidationReportWriter;
  S: TMemoryStream;
begin
  W := TLandrixEInvoiceValidationReportWriter.Create;
  S := TMemoryStream.Create;
  try
    W.DocumentName := ADocumentName;
    W.WriteToStream(AResult, S);
    Result := '';
    SetLength(Result, Integer(S.Size));
    if S.Size > 0 then
      Move(S.Memory^, PAnsiChar(Result)^, Integer(S.Size));
  finally
    S.Free;
    W.Free;
  end;
end;

function ReportSchemaErrors(const AXml: TLandrixXmlUtf8): string;
var
  V: TLandrixXmlXsdValidator;
  Reader: TLandrixXmlReader;
  I: Integer;
begin
  Result := '';
  V := TLandrixXmlXsdValidator.Create(ReportSchema);
  Reader := TLandrixXmlReader.Create;
  try
    Reader.LoadFromBuffer(PAnsiChar(AXml)^, Length(AXml));
    V.ValidateReader(Reader);
    for I := 0 to V.ErrorCount - 1 do
      Result := Result + IntToStr(V.Errors[I].Line) + ':' + V.Errors[I].Code + ' ' + V.Errors[I].Message + '; ';
  finally
    Reader.Free;
    V.Free;
  end;
end;

{ the child element ALocal of AParent, nil if there is none }
function ChildElement(AParent: TLandrixXmlNode; const ALocal: string): TLandrixXmlNode;
begin
  Result := AParent.FirstChildElement;
  while (Result <> nil) and (Result.LocalName <> ALocal) do
    Result := Result.NextSiblingElement;
end;

function Attr(ANode: TLandrixXmlNode; const ALocal: TLandrixXmlUtf8): string;
begin
  if ANode.HasAttribute('', ALocal) then
    Result := ANode.AttributeValue('', ALocal)
  else
    Result := '';
end;

function AttrW(ANode: TLandrixXmlNode; const ALocal: TLandrixXmlUtf8): TLandrixEInvoiceString;
begin
  if ANode.HasAttribute('', ALocal) then
    Result := ANode.AttributeValueW('', ALocal)
  else
    Result := '';
end;

procedure CheckFindings(N: TLandrixXmlNode; AResult: TLandrixEInvoiceDocumentValidation; const AName: string);
var
  F: TLandrixXmlNode;
  I, Predicted: Integer;
  Counts: array[TLandrixEInvoiceDiagnosticSeverity] of Integer;
  S: TLandrixEInvoiceDiagnosticSeverity;
  Finding: TLandrixEInvoiceFinding;
  Sanitized: Boolean;
  What: string;
  Location: TLandrixXmlNode;
begin
  for S := Low(TLandrixEInvoiceDiagnosticSeverity) to High(TLandrixEInvoiceDiagnosticSeverity) do
    Counts[S] := 0;
  Predicted := 0;
  F := N.FirstChildElement;
  I := 0;
  while F <> nil do
  begin
    What := AName + ': finding ' + IntToStr(I);
    if I < AResult.FindingCount then
    begin
      Finding := AResult[I];
      if Finding.Predicted then
        Inc(Predicted)
      else
        Inc(Counts[Finding.Severity]);
      Sanitized := Attr(F, 'sanitized') = 'true';
      CheckEqualsStr(PartTokens[Finding.Part], Attr(F, 'part'), What + ' part');
      CheckEqualsStr(SeverityTokens[Finding.Severity], Attr(F, 'severity'), What + ' severity');
      CheckEqualsStr(StepTokens[Finding.Step], Attr(F, 'step'), What + ' step');
      Check(Finding.Predicted = (Attr(F, 'predicted') = 'true'), What + ' predicted');
      if Finding.Line > 0 then
        CheckEqualsStr(IntToStr(Finding.Line), Attr(F, 'line'), What + ' line')
      else
        CheckEqualsStr('', Attr(F, 'line'), What + ' no line');
      Location := ChildElement(F, 'location');
      if not Sanitized then
      begin
        Check(AttrW(F, 'rule') = Finding.RuleID, What + ' rule');
        Check(ChildElement(F, 'text').TextW = Finding.Text, What + ' text');
        if Finding.Location = '' then
          Check(Location = nil, What + ' no location')
        else
          Check((Location <> nil) and (Location.TextW = Finding.Location), What + ' location');
      end;
    end;
    Inc(I);
    F := F.NextSiblingElement;
  end;
  CheckEquals(AResult.FindingCount, I, AName + ': findings');
  CheckEqualsStr(IntToStr(Counts[eds_Error]), Attr(N, 'errors'), AName + ': errors');
  CheckEqualsStr(IntToStr(Counts[eds_Warning]), Attr(N, 'warnings'), AName + ': warnings');
  CheckEqualsStr(IntToStr(Counts[eds_Info]), Attr(N, 'infos'), AName + ': infos');
  CheckEqualsStr(IntToStr(Predicted), Attr(N, 'predicted'), AName + ': predicted');
end;

procedure CheckValidationReport(AResult: TLandrixEInvoiceDocumentValidation; const AName: string);
var
  Xml: TLandrixXmlUtf8;
  Errors: string;
  Doc: TLandrixXmlDocument;
  Root, N, Part: TLandrixXmlNode;
  P: TLandrixEInvoiceValidationPart;
begin
  Xml := ReportUtf8(AResult, '');
  Errors := ReportSchemaErrors(Xml);
  CheckEqualsStr('', Errors, AName + ': report valid against the schema');
  Doc := TLandrixXmlDocument.Create;
  try
    Doc.LoadFromUtf8(Xml);
    Root := Doc.Root;
    CheckEqualsStr(ReportNs, Root.NamespaceUri, AName + ': report namespace');
    CheckEqualsStr('1.0', Attr(Root, 'version'), AName + ': report version');
    N := ChildElement(Root, 'verdict');
    Check((N <> nil) and (N.Text = VerdictTokens[AResult.Verdict]), AName + ': report verdict');
    N := ChildElement(Root, 'document');
    Check((N <> nil) and (Attr(N, 'source') = SourceTokens[AResult.Info.Source]), AName + ': report source');
    N := ChildElement(Root, 'parts');
    if N <> nil then
    begin
      Part := N.FirstChildElement;
      for P := Low(TLandrixEInvoiceValidationPart) to High(TLandrixEInvoiceValidationPart) do
        if Part <> nil then
        begin
          CheckEqualsStr(PartTokens[P], Attr(Part, 'name'), AName + ': report part');
          CheckEqualsStr(StatusTokens[AResult.Status[P]], Attr(Part, 'status'), AName + ': status ' + PartTokens[P]);
          Part := Part.NextSiblingElement;
        end;
    end;
    Check((ChildElement(Root, 'pdf') <> nil) = (AResult.Pdf <> nil), AName + ': report pdf');
    N := ChildElement(Root, 'findings');
    Check(N <> nil, AName + ': report findings');
    if N <> nil then
      CheckFindings(N, AResult, AName);
  finally
    Doc.Free;
  end;
end;

function ReadFileBytes(const AFileName: string): AnsiString;
var
  F: TFileStream;
begin
  Result := '';
  F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Integer(F.Size));
    if F.Size > 0 then
      F.ReadBuffer(PAnsiChar(Result)^, Integer(F.Size));
  finally
    F.Free;
  end;
end;

procedure WriteFileBytes(const AFileName: string; const ABytes: AnsiString);
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFileName, fmCreate);
  try
    if ABytes <> '' then
      F.WriteBuffer(PAnsiChar(ABytes)^, Length(ABytes));
  finally
    F.Free;
  end;
end;

procedure CheckGoldenReport(const AXml: TLandrixXmlUtf8; const AFile: string);
var
  Golden, OutDir: string;
  Expected, Actual: AnsiString;
  P: Integer;
begin
  Golden := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'validation-report' + PathDelim + AFile;
  Actual := '';
  SetLength(Actual, Length(AXml));
  if AXml <> '' then
    Move(PAnsiChar(AXml)^, PAnsiChar(Actual)^, Length(AXml));
  Expected := '';
  if FileExists(Golden) then
    Expected := ReadFileBytes(Golden);
  P := Pos(AnsiString('@VERSION@'), Expected);
  if P > 0 then
    Expected := Copy(Expected, 1, P - 1) + AnsiString(LandrixEInvoiceVersion) + Copy(Expected, P + 9, MaxInt);
  if Expected <> Actual then
  begin
    OutDir := ExtractFilePath(ParamStr(0)) + 'reports' + PathDelim;
    ForceDirectories(OutDir);
    WriteFileBytes(OutDir + AFile, Actual);
    Fail('report differs from ' + Golden + ', written to ' + OutDir + AFile);
  end;
end;

initialization

finalization
  Schema.Free;

end.
