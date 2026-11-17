program ValidatorProbe;

{ Validates XML files with LandrixEInvoiceValidator and a KoSIT validator
  configuration; used by tools/kosit/kosit-oracle.py, which compares the
  output with the reports of the KoSIT validator.
  Usage: ValidatorProbe <scenarios.xml> <rule-folder> [<xslt>=<rule file>]... [-matches] [-input:<folder>]
    [-report:<folder>] <file or folder>...
  The rule folder is tests/data/local/kosit as tools/testdata/sync-local.py
  fills it: the LandrixXML rule files in rules/rules (en16931-ubl.xml,
  en16931-cii.xml, xrechnung-ubl.xml, xrechnung-cii.xml) for the XRechnung
  configuration, and for Peppol BIS en16931-ubl.xml (the configuration's
  CEN-EN16931-UBL is the same source) and peppol/PEPPOL-EN16931-UBL.sch,
  compiled when loaded. An argument <xslt>=<rule file> maps an XSLT file
  name (replacing a built-in mapping; a .sch rule file is compiled); it
  applies to the files after it.
  Output per file (codes, levels and positions only, ASCII):
    ## <file name>
    scenario <name> | scenario none     (matches <n>)
    xsd valid | xsd invalid | xsd skipped
    msg <step> <code> <level> <effective level> <line>:<column> <location>
    processing-error <text>
    accepted | rejected
  With -matches (for the files after it) only the number of matching
  scenarios (TLandrixEInvoiceValidator.CountMatches, -1: not well-formed):
    ## <file name>
    matches <n>
  step is wf, xsd or sch<n>; a file that raises prints "exception <class>
  <message>". With -input:<folder> (for the files after it) the validator
  keeps the SVRL and every file's KoSIT report input is written to
  <folder>/<name>-reportInput.xml (LandrixEInvoiceKositReportInput), the
  name the KoSIT validator gives it with --serialize-report-input.
  With -report:<folder> the KoSIT report is made too
  (LandrixEInvoiceKositReport): <folder>/<name>-report.xml and, if it has
  one, the HTML page <folder>/<name>-report.html, the names the KoSIT
  validator gives them with --extract-html; the line "report accept" or
  "report reject" gives the report's assessment.
  Exit code 0 unless the configuration does not load. }

{$I LandrixEInvoice.inc}
{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceValidator,
  LandrixEInvoiceKositReportInput,
  LandrixEInvoiceKositReport;

const
  RuleMap: array[0..5, 0..1] of string = (
    ('EN16931-UBL-validation.xsl', 'rules/rules/en16931-ubl.xml'),
    ('EN16931-CII-validation.xsl', 'rules/rules/en16931-cii.xml'),
    ('XRechnung-UBL-validation.xsl', 'rules/rules/xrechnung-ubl.xml'),
    ('XRechnung-CII-validation.xsl', 'rules/rules/xrechnung-cii.xml'),
    ('CEN-EN16931-UBL.xslt', 'rules/rules/en16931-ubl.xml'),
    ('PEPPOL-EN16931-UBL.xslt', 'peppol/PEPPOL-EN16931-UBL.sch'));
  StepNames: array[TLandrixEInvoiceValidationStep] of string = ('wf', 'xsd', 'sch');

function Ascii(const S: TLandrixEInvoiceString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if (Ord(S[I]) >= 32) and (Ord(S[I]) < 127) then
      Result := Result + Char(Ord(S[I]))
    else
      Result := Result + '?';
end;

var
  MatchesOnly: Boolean = False;
  InputDir: string = '';
  ReportDir: string = '';
  Reporter: TLandrixEInvoiceKositReporter = nil;

procedure ProbeMatches(V: TLandrixEInvoiceValidator; const AFileName: string);
var
  F: TFileStream;
begin
  WriteLn('## ' + ExtractFileName(AFileName));
  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      WriteLn('matches ' + IntToStr(V.CountMatches(F)));
    finally
      F.Free;
    end;
  except
    on E: Exception do
      WriteLn('exception ' + E.ClassName + ' ' + StringReplace(E.Message, #10, ' ', [rfReplaceAll]));
  end;
end;

procedure Probe(V: TLandrixEInvoiceValidator; const AFileName: string);
var
  R: TLandrixEInvoiceValidationResult;
  M: TLandrixEInvoiceValidationMessage;
  I: Integer;
  Step: string;
  Input: TLandrixEInvoiceKositReportInputWriter;
  Doc: TFileStream;
  Report: TLandrixEInvoiceKositReport;
  Base: string;
begin
  if MatchesOnly then
  begin
    ProbeMatches(V, AFileName);
    Exit;
  end;
  WriteLn('## ' + ExtractFileName(AFileName));
  R := TLandrixEInvoiceValidationResult.Create;
  try
    try
      V.Validate(AFileName, R);
      if R.ScenarioName = '' then
        WriteLn('scenario none')
      else
        WriteLn('scenario ' + Ascii(R.ScenarioName) + ' (matches ' + IntToStr(R.MatchCount) + ')');
      if R.ScenarioName = '' then
        WriteLn('xsd skipped')
      else if R.XmlSchemaValid then
        WriteLn('xsd valid')
      else
        WriteLn('xsd invalid');
      for I := 0 to R.MessageCount - 1 do
      begin
        M := R[I];
        Step := StepNames[M.Step];
        if M.Step = evs_Schematron then
          Step := Step + IntToStr(M.StepIndex);
        WriteLn('msg ' + Step + ' ' + Ascii(M.Code) + ' ' + Ascii(LandrixEInvoiceValidationLevelText(M.Level)) + ' ' +
          Ascii(LandrixEInvoiceValidationLevelText(M.EffectiveLevel)) + ' ' + IntToStr(M.Line) + ':' +
          IntToStr(M.Column) + ' ' + Ascii(M.Location));
      end;
      if R.ProcessingError <> '' then
        WriteLn('processing-error ' + Ascii(R.ProcessingError));
      if R.Accepted then
        WriteLn('accepted')
      else
        WriteLn('rejected');
      if InputDir <> '' then
      begin
        Input := TLandrixEInvoiceKositReportInputWriter.Create;
        try
          Input.SaveToFile(R, InputDir + ChangeFileExt(ExtractFileName(AFileName), '') + '-reportInput.xml');
        finally
          Input.Free;
        end;
      end;
      if ReportDir <> '' then
      begin
        Doc := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
        try
          Report := Reporter.CreateReport(R, Doc);
          try
            Base := ReportDir + ChangeFileExt(ExtractFileName(AFileName), '') + '-report';
            Report.SaveXmlToFile(Base + '.xml');
            if Report.HasHtml then
              Report.SaveHtmlToFile(Base + '.html');
            if Report.Accepted then
              WriteLn('report accept')
            else
              WriteLn('report reject');
          finally
            Report.Free;
          end;
        finally
          Doc.Free;
        end;
      end;
    except
      on E: Exception do
        WriteLn('exception ' + E.ClassName + ' ' + StringReplace(E.Message, #10, ' ', [rfReplaceAll]));
    end;
  finally
    R.Free;
  end;
end;

procedure ProbeAll(V: TLandrixEInvoiceValidator; const APath: string);
var
  SR: TSearchRec;
  Names: TStringList;
  Dir: string;
  I: Integer;
begin
  if not DirectoryExists(APath) then
  begin
    Probe(V, APath);
    Exit;
  end;
  Dir := IncludeTrailingPathDelimiter(APath);
  Names := TStringList.Create;
  try
    if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Attr and faDirectory) = 0 then
          Names.Add(SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    Names.Sort;
    for I := 0 to Names.Count - 1 do
      Probe(V, Dir + Names[I]);
  finally
    Names.Free;
  end;
end;

var
  V: TLandrixEInvoiceValidator;
  RuleDir, Arg: string;
  I, Paths: Integer;
begin
  if ParamCount < 3 then
  begin
    WriteLn('Usage: ValidatorProbe <scenarios.xml> <rule-folder> [<xslt>=<rule file>]... [-matches] ' +
      '[-input:<folder>] <file or folder>...');
    ExitCode := 2;
    Exit;
  end;
  V := TLandrixEInvoiceValidator.Create;
  try
    try
      V.LoadConfiguration(ParamStr(1));
    except
      on E: Exception do
      begin
        WriteLn('configuration: ' + E.Message);
        ExitCode := 1;
        Exit;
      end;
    end;
    RuleDir := IncludeTrailingPathDelimiter(ParamStr(2));
    for I := Low(RuleMap) to High(RuleMap) do
      V.RuleFiles.Values[RuleMap[I, 0]] := RuleDir + StringReplace(RuleMap[I, 1], '/', PathDelim, [rfReplaceAll]);
    Paths := 0;
    for I := 3 to ParamCount do
    begin
      Arg := ParamStr(I);
      { a mapping replaces the built-in one of the same name }
      if Pos('=', Arg) > 0 then
        V.RuleFiles.Values[Copy(Arg, 1, Pos('=', Arg) - 1)] := Copy(Arg, Pos('=', Arg) + 1, MaxInt)
      else if Arg = '-matches' then
        MatchesOnly := True
      else if Copy(Arg, 1, 7) = '-input:' then
      begin
        InputDir := IncludeTrailingPathDelimiter(Copy(Arg, 8, MaxInt));
        V.KeepSvrl := True;
      end
      else if Copy(Arg, 1, 8) = '-report:' then
      begin
        ReportDir := IncludeTrailingPathDelimiter(Copy(Arg, 9, MaxInt));
        V.KeepSvrl := True;
        if Reporter = nil then
          Reporter := TLandrixEInvoiceKositReporter.Create;
      end
      else
      begin
        ProbeAll(V, Arg);
        Inc(Paths);
      end;
    end;
    if Paths = 0 then
    begin
      WriteLn('Usage: ValidatorProbe <scenarios.xml> <rule-folder> [<xslt>=<rule file>]... [-matches] ' +
      '[-input:<folder>] <file or folder>...');
      ExitCode := 2;
    end;
  finally
    Reporter.Free;
    V.Free;
  end;
end.
