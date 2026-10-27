program ValidatorProbe;

{ Validates XML files with LandrixEInvoiceValidator and a KoSIT validator
  configuration; used by tools/kosit/kosit-oracle.py, which compares the
  output with the reports of the KoSIT validator.
  Usage: ValidatorProbe <scenarios.xml> <rule-folder> [<xslt>=<rule file>]... <file or folder>...
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
  step is wf, xsd or sch<n>; a file that raises prints "exception <class>
  <message>". Exit code 0 unless the configuration does not load. }

{$I LandrixEInvoice.inc}
{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceValidator;

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

procedure Probe(V: TLandrixEInvoiceValidator; const AFileName: string);
var
  R: TLandrixEInvoiceValidationResult;
  M: TLandrixEInvoiceValidationMessage;
  I: Integer;
  Step: string;
begin
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
    WriteLn('Usage: ValidatorProbe <scenarios.xml> <rule-folder> [<xslt>=<rule file>]... <file or folder>...');
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
      else
      begin
        ProbeAll(V, Arg);
        Inc(Paths);
      end;
    end;
    if Paths = 0 then
    begin
      WriteLn('Usage: ValidatorProbe <scenarios.xml> <rule-folder> [<xslt>=<rule file>]... <file or folder>...');
      ExitCode := 2;
    end;
  finally
    V.Free;
  end;
end.
