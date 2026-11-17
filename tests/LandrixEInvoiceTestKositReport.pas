{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for the KoSIT original outputs: Kosit.Result checks what
  LandrixEInvoiceValidator keeps for the report input (steps, resources,
  scenario, hash, SVRL with KeepSvrl, the report stylesheet with and
  without a scenario), Kosit.ReportInput the writer of
  LandrixEInvoiceKositReportInput, Kosit.Report and Kosit.ReportValidation
  LandrixEInvoiceKositReport with the small configuration in
  tests/data/validator/ and its own test stylesheet report.xsl (not KoSIT
  material). Kosit.Visualization runs LandrixEInvoiceKositVisualization on
  an instance of the KoSIT test suite; it is skipped without the
  visualization (addons/kosit/install-kosit.ps1 or
  addons/java-tools/install-tools.ps1) or without tests/data/local/kosit/.
  The comparison with the KoSIT validator and Saxon is the job of
  tools/kosit/kosit-oracle.py (--report-input, --report). }

unit LandrixEInvoiceTestKositReport;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceValidator,
  LandrixEInvoiceValidation,
  LandrixEInvoiceKositReportInput,
  LandrixEInvoiceKositReport,
  LandrixEInvoiceKositVisualization,
  LandrixEInvoiceTestFramework;

function DataDir: string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'validator' + PathDelim;
end;

function NewValidator(AKeepSvrl: Boolean): TLandrixEInvoiceValidator;
begin
  Result := TLandrixEInvoiceValidator.Create;
  try
    Result.LoadConfiguration(DataDir + 'scenarios.xml');
    Result.RuleFiles.Values['test.xsl'] := DataDir + 'test.sch';
    Result.KeepSvrl := AKeepSvrl;
  except
    Result.Free;
    raise;
  end;
end;

function Contains(const AText, APart: TLandrixXmlUtf8): Boolean;
begin
  Result := Pos(APart, AText) > 0;
end;

function StreamText(AStream: TMemoryStream): TLandrixXmlUtf8;
begin
  Result := '';
  SetLength(Result, Integer(AStream.Size));
  if AStream.Size > 0 then
    Move(AStream.Memory^, PAnsiChar(Result)^, Integer(AStream.Size));
end;

procedure TestResult;
var
  V: TLandrixEInvoiceValidator;
  R: TLandrixEInvoiceValidationResult;
begin
  V := NewValidator(False);
  R := TLandrixEInvoiceValidationResult.Create;
  try
    CheckEqualsStr(ExpandFileName(DataDir + 'report.xsl'), V.NoScenarioReportFile, 'noScenarioReport');
    CheckEqualsStr(ExpandFileName(DataDir + 'report.xsl'), V.Scenarios[0].ReportFile, 'createReport');
    Check(Contains(V.Scenarios[0].ScenarioXml, '<name>Test A</name>') or
      Contains(V.Scenarios[0].ScenarioXml, ':name>Test A</'), 'scenario XML');
    V.Validate(DataDir + 'doc-a-5.xml', R);
    CheckEquals(3, R.StepCount, 'steps');
    CheckEquals(Ord(evs_Wellformedness), Ord(R.Steps[0].Step), 'step 1');
    CheckEquals(Ord(evs_XmlSchema), Ord(R.Steps[1].Step), 'step 2');
    CheckEquals(Ord(evs_Schematron), Ord(R.Steps[2].Step), 'step 3');
    Check(Contains(R.Steps[1].ResourceXml, 'test.xsd'), 'schema resource');
    Check(Contains(R.Steps[2].ResourceXml, 'xsl/test.xsl'), 'Schematron resource');
    CheckEqualsUtf8('', R.Steps[2].Svrl, 'no SVRL without KeepSvrl');
    CheckEqualsStr('r2EoX9meaTbrD16F2MTgrIdxyeuXXQH54qLk6LMAfaI=', string(R.DocumentHash), 'hash');
    CheckEqualsStr(ExpandFileName(DataDir + 'doc-a-5.xml'), string(R.DocumentReference), 'reference');
    Check(Length(R.Timestamp) >= 19, 'timestamp');
    CheckEqualsUtf8(V.Scenarios[0].ScenarioXml, R.ScenarioXml, 'scenario of the result');
    CheckEqualsStr(V.Scenarios[0].ReportFile, R.ReportFile, 'report of the result');
    { no scenario: the report of noScenarioReport, one step }
    V.Validate(DataDir + 'doc-x-5.xml', R);
    CheckEquals(1, R.StepCount, 'steps without scenario');
    CheckEqualsUtf8('', R.ScenarioXml, 'no scenario');
    CheckEqualsStr(V.NoScenarioReportFile, R.ReportFile, 'noScenarioReport of the result');
    { KeepSvrl: the SVRL of the step, the message as written }
    V.KeepSvrl := True;
    V.Validate(DataDir + 'doc-a-150.xml', R);
    Check(Contains(R.Steps[2].Svrl, 'failed-assert'), 'SVRL failed-assert');
    Check(Contains(R.Steps[2].Svrl, 'v is below 100'), 'SVRL text');
    R.Clear;
    CheckEquals(0, R.StepCount, 'cleared');
  finally
    R.Free;
    V.Free;
  end;
end;

procedure TestReportInput;
var
  V: TLandrixEInvoiceValidator;
  R: TLandrixEInvoiceValidationResult;
  W: TLandrixEInvoiceKositReportInputWriter;
  S: TMemoryStream;
  Xml: TLandrixXmlUtf8;
begin
  V := NewValidator(True);
  R := TLandrixEInvoiceValidationResult.Create;
  W := TLandrixEInvoiceKositReportInputWriter.Create;
  S := TMemoryStream.Create;
  try
    V.Validate(DataDir + 'doc-a-150.xml', R);
    W.EngineName := 'Test engine';
    W.WriteToStream(R, S);
    Xml := StreamText(S);
    Check(Contains(Xml, 'createReportInput'), 'root');
    Check(Contains(Xml, 'frameworkVersion="1.0.2"'), 'framework version');
    Check(Contains(Xml, 'Test engine'), 'engine');
    Check(Contains(Xml, 'validationResultsWellformedness'), 'well-formedness');
    Check(Contains(Xml, 'validationResultsXmlSchema'), 'XML schema');
    Check(Contains(Xml, 'validationResultsSchematron'), 'Schematron');
    Check(Contains(Xml, 'svrl:failed-assert'), 'SVRL');
    Check(not Contains(Xml, 'processingError'), 'no processing error');
    { not well-formed: a fatal syntax error, also as processing error }
    S.Clear;
    V.Validate(DataDir + 'doc-broken.xml', R);
    W.WriteToStream(R, S);
    Xml := StreamText(S);
    Check(Contains(Xml, 'SEVERITY_FATAL_ERROR'), 'fatal error');
    Check(Contains(Xml, 'processingError'), 'processing error');
    Check(not Contains(Xml, 'validationResultsXmlSchema'), 'no schema step');
    CheckEqualsStr('EEH1SVsOkKZQiAjfUmYrYgpR4AoyhNRjv74BFCojpBg=', string(R.DocumentHash), 'hash of the broken file');
    { without KeepSvrl the Schematron step cannot be written }
    V.KeepSvrl := False;
    V.Validate(DataDir + 'doc-a-5.xml', R);
    try
      W.WriteToStream(R, S);
      FailNotRaised('ELandrixEInvoiceError');
    except
      on ELandrixEInvoiceError do ;
    end;
  finally
    S.Free;
    W.Free;
    R.Free;
    V.Free;
  end;
end;

{ The report of a file with the test stylesheet; AHtml: the page. }
function ReportOf(V: TLandrixEInvoiceValidator; Reporter: TLandrixEInvoiceKositReporter; const AName: string;
  out AHtml: TLandrixXmlUtf8): Boolean;
var
  R: TLandrixEInvoiceValidationResult;
  Doc: TFileStream;
  Report: TLandrixEInvoiceKositReport;
  S: TMemoryStream;
begin
  R := TLandrixEInvoiceValidationResult.Create;
  try
    V.Validate(DataDir + AName, R);
    Doc := TFileStream.Create(DataDir + AName, fmOpenRead or fmShareDenyWrite);
    try
      Report := Reporter.CreateReport(R, Doc);
    finally
      Doc.Free;
    end;
    S := TMemoryStream.Create;
    try
      Check(Report.HasHtml, AName + ': HTML');
      Report.SaveHtmlToStream(S);
      AHtml := StreamText(S);
      Result := Report.Accepted;
      S.Clear;
      Report.SaveXmlToStream(S);
      Check(Contains(StreamText(S), 'rep:report'), AName + ': report XML');
    finally
      S.Free;
      Report.Free;
    end;
  finally
    R.Free;
  end;
end;

procedure TestReport;
var
  V: TLandrixEInvoiceValidator;
  Reporter: TLandrixEInvoiceKositReporter;
  R: TLandrixEInvoiceValidationResult;
  Html: TLandrixXmlUtf8;
begin
  V := NewValidator(True);
  Reporter := TLandrixEInvoiceKositReporter.Create;
  try
    Check(ReportOf(V, Reporter, 'doc-a-5.xml', Html), 'doc-a-5 accepted');
    Check(Contains(Html, '>Test report</'), 'page title');
    Check(Contains(Html, 'class="root">doc</'), 'input-document passed');
    Check(Contains(Html, 'class="scenario">Test A</'), 'scenario on the page');
    Check(not ReportOf(V, Reporter, 'doc-a-150.xml', Html), 'doc-a-150 rejected (fatal)');
    Check(Contains(Html, 'class="assert">T-02</'), 'failed assert on the page');
    { no scenario: noScenarioReport }
    Check(not ReportOf(V, Reporter, 'doc-x-5.xml', Html), 'doc-x-5 rejected');
    Check(Contains(Html, 'class="scenario">none</'), 'no scenario on the page');
    { not well-formed: in:error-message as input-document }
    Check(not ReportOf(V, Reporter, 'doc-broken.xml', Html), 'broken rejected');
    Check(Contains(Html, 'class="root">error-message</'), 'error-message passed');
    { without KeepSvrl: refused }
    V.KeepSvrl := False;
    R := TLandrixEInvoiceValidationResult.Create;
    try
      V.Validate(DataDir + 'doc-a-5.xml', R);
      try
        Reporter.CreateReport(R, nil).Free;
        FailNotRaised('ELandrixEInvoiceError');
      except
        on ELandrixEInvoiceError do ;
      end;
    finally
      R.Free;
    end;
  finally
    Reporter.Free;
    V.Free;
  end;
end;

procedure TestReportValidation;
var
  V: TLandrixEInvoiceValidator;
  DV: TLandrixEInvoiceDocumentValidator;
  DocResult: TLandrixEInvoiceDocumentValidation;
  Reporter: TLandrixEInvoiceKositReporter;
  Report: TLandrixEInvoiceKositReport;
  F: TFileStream;
  S: TMemoryStream;
begin
  V := NewValidator(True);
  DV := TLandrixEInvoiceDocumentValidator.Create;
  DocResult := TLandrixEInvoiceDocumentValidation.Create;
  Reporter := TLandrixEInvoiceKositReporter.Create;
  S := TMemoryStream.Create;
  try
    DV.Options.Configuration := V;
    DV.Options.ModelCheck := False;
    F := TFileStream.Create(DataDir + 'doc-a-5.xml', fmOpenRead or fmShareDenyWrite);
    try
      DV.ValidateStream(F, DocResult);
      CheckEqualsInt64(F.Size, DocResult.InvoiceXml.Size, 'InvoiceXml');
    finally
      F.Free;
    end;
    Check(DocResult.Kosit <> nil, 'Kosit kept');
    CheckEqualsStr('Test A', string(DocResult.Kosit.ScenarioName), 'Kosit scenario');
    CheckEqualsStr('', string(DocResult.Kosit.DocumentReference), 'no reference for a stream');
    CheckEqualsStr('r2EoX9meaTbrD16F2MTgrIdxyeuXXQH54qLk6LMAfaI=', string(DocResult.Kosit.DocumentHash), 'hash');
    Report := Reporter.CreateReport(DocResult);
    try
      Check(Report.Accepted, 'accepted');
      Report.SaveHtmlToStream(S);
      Check(Contains(StreamText(S), 'class="root">doc</'), 'the invoice XML passed');
    finally
      Report.Free;
    end;
    DocResult.Clear;
    Check(DocResult.Kosit = nil, 'cleared Kosit');
    Check(DocResult.InvoiceXml = nil, 'cleared InvoiceXml');
    try
      Reporter.CreateReport(DocResult).Free;
      FailNotRaised('ELandrixEInvoiceError');
    except
      on ELandrixEInvoiceError do ;
    end;
  finally
    S.Free;
    Reporter.Free;
    DocResult.Free;
    DV.Free;
    V.Free;
  end;
end;

function VisualizationFolder: string;
begin
  Result := RepositoryRoot + 'addons' + PathDelim + 'kosit' + PathDelim + 'xrechnung-visualization' + PathDelim +
    'xsl';
  if not FileExists(Result + PathDelim + 'xrechnung-html.xsl') then
    Result := RepositoryRoot + 'addons' + PathDelim + 'java-tools' + PathDelim + 'xrechnung-visualization' +
      PathDelim + 'xsl';
  if not FileExists(Result + PathDelim + 'xrechnung-html.xsl') then
    Result := '';
end;

procedure TestVisualization;
var
  Viz: TLandrixEInvoiceKositVisualizer;
  Doc: TFileStream;
  S: TMemoryStream;
  Text: TLandrixXmlUtf8;
begin
  if VisualizationFolder = '' then
  begin
    Skip('no XRechnung visualization (addons/kosit/install-kosit.ps1)');
    Exit;
  end;
  if not FileExists(RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'kosit' +
    PathDelim + 'instances' + PathDelim + 'standard_01.01a-INVOICE_ubl.xml') then
  begin
    Skip('no tests/data/local/kosit (tools/testdata/sync-local.py)');
    Exit;
  end;
  Viz := TLandrixEInvoiceKositVisualizer.Create;
  S := TMemoryStream.Create;
  try
    Viz.Folder := VisualizationFolder;
    Doc := TFileStream.Create(RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim +
      'kosit' + PathDelim + 'instances' + PathDelim + 'standard_01.01a-INVOICE_ubl.xml', fmOpenRead or fmShareDenyWrite);
    try
      Viz.WriteXr(Doc, S);
      Text := StreamText(S);
      Check(Contains(Text, 'xr:invoice') or Contains(Text, ':Invoice'), 'XR');
      S.Clear;
      Doc.Position := 0;
      Viz.WriteHtml(Doc, S);
      Text := StreamText(S);
      Check(Contains(Text, '<html'), 'HTML');
      Check(Contains(Text, 'Rechnung'), 'German page');
      S.Clear;
      Doc.Position := 0;
      Viz.Language := eln_English;
      Viz.WriteHtml(Doc, S);
      Check(Contains(StreamText(S), 'Invoice'), 'English page');
    finally
      Doc.Free;
    end;
    { not an invoice }
    Doc := TFileStream.Create(DataDir + 'doc-a-5.xml', fmOpenRead or fmShareDenyWrite);
    try
      try
        Viz.WriteHtml(Doc, S);
        FailNotRaised('ELandrixEInvoiceError');
      except
        on ELandrixEInvoiceError do ;
      end;
    finally
      Doc.Free;
    end;
  finally
    S.Free;
    Viz.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Kosit.Result', TestResult);
  RegisterTest('Kosit.ReportInput', TestReportInput);
  RegisterTest('Kosit.Report', TestReport);
  RegisterTest('Kosit.ReportValidation', TestReportValidation);
  RegisterTest('Kosit.Visualization', TestVisualization);
end;

end.
