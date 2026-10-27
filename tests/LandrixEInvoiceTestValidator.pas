{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceValidator. Validator.Scenarios,
  Validator.Configuration and Validator.WithoutAcceptMatch use the small
  configurations in tests/data/validator/ (scenario choice, customLevel,
  fallback, the steps, the refused configurations and the verdict of a
  scenario without acceptMatch). Validator.KositSuite runs the KoSIT
  XRechnung test suite 2026-08-31 with the configuration of
  addons/java-tools and compares the result with tests/data/kosit-expected.txt,
  which tools/kosit/kosit-oracle.py --update writes after the KoSIT
  validator agreed; it is skipped without tests/data/local/kosit/ (see
  tools/testdata/sync-local.py) or without the configuration.
  Validator.Outputs, registered last (RegisterLast), checks every XRechnung
  file the run wrote (*-ubl-30x.xml and *-cii-30x.xml in cross/, cases/ and
  sweep/ next to the program) with that configuration: each must be
  accepted. Validator.PeppolOutputs, registered last too, does the same for
  the Peppol BIS files (*-peppol.xml) with the Peppol BIS configuration of
  addons/java-tools and the Peppol schematron of tests/data/local/kosit/peppol;
  the files of PeppolKnown must be rejected instead (each with its reason). }

unit LandrixEInvoiceTestValidator;

{$I LandrixEInvoice.inc}

interface

procedure Register;
{ Validator.Outputs; register it after the tests that write the outputs. }
procedure RegisterLast;

implementation

uses
  SysUtils,
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceValidator,
  LandrixEInvoiceTestFramework;

function DataDir: string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'validator' + PathDelim;
end;

function NewValidator: TLandrixEInvoiceValidator;
begin
  Result := TLandrixEInvoiceValidator.Create;
  try
    Result.LoadConfiguration(DataDir + 'scenarios.xml');
    Result.RuleFiles.Values['test.xsl'] := DataDir + 'test.sch';
  except
    Result.Free;
    raise;
  end;
end;

{ the codes with their effective level, e.g. 'T-02:warning' }
function Codes(R: TLandrixEInvoiceValidationResult): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to R.MessageCount - 1 do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + string(R[I].Code) + ':' + string(LandrixEInvoiceValidationLevelText(R[I].EffectiveLevel));
  end;
end;

procedure CheckDoc(V: TLandrixEInvoiceValidator; const AName, AScenario: string; AMatches: Integer;
  AAccepted: Boolean; const ACodes: string);
var
  R: TLandrixEInvoiceValidationResult;
begin
  R := TLandrixEInvoiceValidationResult.Create;
  try
    CheckEquals(Ord(AAccepted), Ord(V.Validate(DataDir + AName, R)), AName + ': verdict');
    CheckEquals(Ord(AAccepted), Ord(R.Accepted), AName + ': Accepted');
    CheckEqualsStr(AScenario, string(R.ScenarioName), AName + ': scenario');
    CheckEquals(AMatches, R.MatchCount, AName + ': matches');
    CheckEqualsStr(ACodes, Codes(R), AName + ': messages');
  finally
    R.Free;
  end;
end;

procedure TestScenarios;
var
  V: TLandrixEInvoiceValidator;
  R: TLandrixEInvoiceValidationResult;
begin
  V := NewValidator;
  try
    CheckEqualsStr('Test configuration', string(V.Name), 'configuration name');
    CheckEquals(2, V.ScenarioCount, 'scenarios');
    CheckEquals(1, V.Scenarios[0].SchematronCount, 'Schematron steps of Test A');
    CheckDoc(V, 'doc-a-5.xml', 'Test A', 1, True, '');
    CheckDoc(V, 'doc-a-7.xml', 'Test A', 1, True, 'T-03:information');
    CheckDoc(V, 'doc-a-150.xml', 'Test A', 1, True, 'T-02:warning');
    CheckDoc(V, 'doc-a-13.xml', 'Test A', 1, False, 'T-04:error');
    CheckDoc(V, 'doc-a-0.xml', 'Test A', 1, False, 'T-01:error');
    CheckDoc(V, 'doc-a-42.xml', 'Test A', 1, False, 'UNSPECIFIC:error');
    CheckDoc(V, 'doc-f-5.xml', 'Test fallback', 1, False, '');
    { both scenarios match: none is chosen, as KoSIT does }
    CheckDoc(V, 'doc-b-5.xml', '', 2, False, '');
    CheckDoc(V, 'doc-x-5.xml', '', 0, False, '');
    CheckDoc(V, 'doc-broken.xml', '', 0, False, 'generic-error:error');
    R := TLandrixEInvoiceValidationResult.Create;
    try
      V.Validate(DataDir + 'doc-a-150.xml', R);
      CheckEquals(1, R.MessageCount, 'one message');
      CheckEquals(Ord(evl_Error), Ord(R[0].Level), 'fatal is error');
      CheckEquals(Ord(evs_Schematron), Ord(R[0].Step), 'Schematron step');
      CheckEquals(1, R[0].StepIndex, 'first step');
      CheckEqualsStr('fatal', string(R[0].Flag), 'flag');
      CheckEqualsStr('/Q{urn:landrix:test:validator}doc[1]', string(R[0].Location), 'location');
      CheckEqualsStr('v is below 100', string(R[0].Text), 'text');
      { an XML schema error stops before the Schematron steps }
      V.Validate(DataDir + 'doc-a-abc.xml', R);
      Check(not R.Accepted, 'abc rejected');
      Check(not R.XmlSchemaValid, 'abc not schema-valid');
      Check(R.MessageCount > 0, 'abc schema messages');
      CheckEquals(Ord(evs_XmlSchema), Ord(R[0].Step), 'abc schema step');
      CheckEqualsStr('cvc-datatype-valid.1.2.1', string(R[0].Code), 'abc code');
      CheckEquals(2, R[0].Line, 'abc line');
    finally
      R.Free;
    end;
  finally
    V.Free;
  end;
end;

procedure TestWithoutAcceptMatch;
var
  V: TLandrixEInvoiceValidator;
begin
  V := TLandrixEInvoiceValidator.Create;
  try
    V.LoadConfiguration(DataDir + 'scenarios-no-accept.xml');
    V.RuleFiles.Values['test.xsl'] := DataDir + 'test.sch';
    CheckDoc(V, 'doc-a-5.xml', 'Test N', 1, True, '');
    { a successful report is no failed assert }
    CheckDoc(V, 'doc-a-7.xml', 'Test N', 1, True, 'T-03:information');
    { as KoSIT without acceptMatch: any failed assert rejects, whatever its
      level and customLevel }
    CheckDoc(V, 'doc-a-150.xml', 'Test N', 1, False, 'T-02:warning');
    CheckDoc(V, 'doc-a-13.xml', 'Test N', 1, False, 'T-04:warning');
    CheckDoc(V, 'doc-a-abc.xml', 'Test N', 1, False, 'cvc-datatype-valid.1.2.1:error cvc-type.3.1.3:error');
    CheckDoc(V, 'doc-x-5.xml', '', 0, False, '');
  finally
    V.Free;
  end;
end;

procedure TestConfiguration;
var
  V: TLandrixEInvoiceValidator;
  R: TLandrixEInvoiceValidationResult;
begin
  V := TLandrixEInvoiceValidator.Create;
  try
    try
      V.LoadConfiguration(DataDir + 'scenarios-other-accept.xml');
      FailNotRaised('ELandrixEInvoiceError');
    except
      on ELandrixEInvoiceError do ;
    end;
    CheckEquals(0, V.ScenarioCount, 'no scenario after a refused configuration');
    V.LoadConfiguration(DataDir + 'scenarios.xml');
    R := TLandrixEInvoiceValidationResult.Create;
    try
      try
        V.Validate(DataDir + 'doc-a-5.xml', R);
        FailNotRaised('ELandrixEInvoiceError');
      except
        on ELandrixEInvoiceError do ;
      end;
    finally
      R.Free;
    end;
  finally
    V.Free;
  end;
end;

{ --- KoSIT test suite ------------------------------------------------------ }

const
  KositRuleMap: array[0..3, 0..1] of string = (
    ('EN16931-UBL-validation.xsl', 'en16931-ubl.xml'),
    ('EN16931-CII-validation.xsl', 'en16931-cii.xml'),
    ('XRechnung-UBL-validation.xsl', 'xrechnung-ubl.xml'),
    ('XRechnung-CII-validation.xsl', 'xrechnung-cii.xml'));
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

{ the lines tools/kosit/ValidatorProbe.dpr prints for one file }
procedure AddResultLines(Lines: TStrings; const AName: string; R: TLandrixEInvoiceValidationResult);
var
  I: Integer;
  M: TLandrixEInvoiceValidationMessage;
  Step: string;
begin
  Lines.Add('## ' + AName);
  if R.ScenarioName = '' then
  begin
    Lines.Add('scenario none');
    Lines.Add('xsd skipped');
  end
  else
  begin
    Lines.Add('scenario ' + Ascii(R.ScenarioName) + ' (matches ' + IntToStr(R.MatchCount) + ')');
    if R.XmlSchemaValid then
      Lines.Add('xsd valid')
    else
      Lines.Add('xsd invalid');
  end;
  for I := 0 to R.MessageCount - 1 do
  begin
    M := R[I];
    Step := StepNames[M.Step];
    if M.Step = evs_Schematron then
      Step := Step + IntToStr(M.StepIndex);
    Lines.Add('msg ' + Step + ' ' + Ascii(M.Code) + ' ' + Ascii(LandrixEInvoiceValidationLevelText(M.Level)) + ' ' +
      Ascii(LandrixEInvoiceValidationLevelText(M.EffectiveLevel)) + ' ' + IntToStr(M.Line) + ':' +
      IntToStr(M.Column) + ' ' + Ascii(M.Location));
  end;
  if R.ProcessingError <> '' then
    Lines.Add('processing-error ' + Ascii(R.ProcessingError));
  if R.Accepted then
    Lines.Add('accepted')
  else
    Lines.Add('rejected');
end;

{ the file names of MANIFEST.txt ("sha256  name" per line), sorted }
function ManifestNames(const AFile: string): TStringList;
var
  Raw: TStringList;
  I, P: Integer;
begin
  Result := TStringList.Create;
  Raw := TStringList.Create;
  try
    Raw.LoadFromFile(AFile);
    for I := 0 to Raw.Count - 1 do
    begin
      P := Pos('  ', Raw[I]);
      if P > 0 then
        Result.Add(Copy(Raw[I], P + 2, MaxInt));
    end;
  finally
    Raw.Free;
  end;
  Result.Sort;
end;

function KositLocal: string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'kosit' + PathDelim;
end;

function KositConfig: string;
begin
  Result := RepositoryRoot + 'addons' + PathDelim + 'java-tools' + PathDelim + 'validator-configuration-xrechnung' +
    PathDelim + 'scenarios.xml';
end;

{ the XRechnung configuration with the rule files of tests/data/local/kosit;
  nil if either is missing }
function NewKositValidator: TLandrixEInvoiceValidator;
var
  I: Integer;
begin
  Result := nil;
  if not FileExists(KositConfig) or
     not FileExists(KositLocal + 'rules' + PathDelim + 'rules' + PathDelim + KositRuleMap[0, 1]) then
    Exit;
  Result := TLandrixEInvoiceValidator.Create;
  try
    Result.LoadConfiguration(KositConfig);
    for I := Low(KositRuleMap) to High(KositRuleMap) do
      Result.RuleFiles.Values[KositRuleMap[I, 0]] := KositLocal + 'rules' + PathDelim + 'rules' + PathDelim +
        KositRuleMap[I, 1];
  except
    Result.Free;
    raise;
  end;
end;

procedure TestKositSuite;
var
  Local, Expected: string;
  V: TLandrixEInvoiceValidator;
  R: TLandrixEInvoiceValidationResult;
  Names, Actual, Reference: TStringList;
  I, Accepted: Integer;
begin
  Local := KositLocal;
  Expected := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'kosit-expected.txt';
  V := nil;
  if FileExists(Local + 'instances' + PathDelim + 'MANIFEST.txt') then
    V := NewKositValidator;
  if V = nil then
  begin
    Skip('no KoSIT test suite or configuration (tools/testdata/sync-local.py, addons/java-tools)');
    Exit;
  end;
  R := TLandrixEInvoiceValidationResult.Create;
  Names := ManifestNames(Local + 'instances' + PathDelim + 'MANIFEST.txt');
  Actual := TStringList.Create;
  Reference := TStringList.Create;
  try
    Accepted := 0;
    for I := 0 to Names.Count - 1 do
    begin
      if V.Validate(Local + 'instances' + PathDelim + Names[I], R) then
        Inc(Accepted);
      AddResultLines(Actual, Names[I], R);
    end;
    CheckEquals(86, Names.Count, 'instances');
    CheckEquals(Names.Count, Accepted, 'every instance accepted');
    Reference.LoadFromFile(Expected);
    CheckEquals(Reference.Count, Actual.Count, 'lines of ' + Expected);
    for I := 0 to Reference.Count - 1 do
      if I < Actual.Count then
        CheckEqualsStr(Reference[I], Actual[I], 'line ' + IntToStr(I + 1));
  finally
    Reference.Free;
    Actual.Free;
    Names.Free;
    R.Free;
    V.Free;
  end;
end;

function PeppolConfig: string;
begin
  Result := RepositoryRoot + 'addons' + PathDelim + 'java-tools' + PathDelim + 'validator-configuration-bis' +
    PathDelim + 'scenarios.xml';
end;

{ the Peppol BIS configuration: its EN16931 rules are those of
  en16931-ubl.xml (the same source), the Peppol rules are compiled from the
  schematron; nil if a file is missing }
function NewPeppolValidator: TLandrixEInvoiceValidator;
var
  En16931, Peppol: string;
begin
  Result := nil;
  En16931 := KositLocal + 'rules' + PathDelim + 'rules' + PathDelim + 'en16931-ubl.xml';
  Peppol := KositLocal + 'peppol' + PathDelim + 'PEPPOL-EN16931-UBL.sch';
  if not FileExists(PeppolConfig) or not FileExists(En16931) or not FileExists(Peppol) then
    Exit;
  Result := TLandrixEInvoiceValidator.Create;
  try
    Result.LoadConfiguration(PeppolConfig);
    Result.RuleFiles.Values['CEN-EN16931-UBL.xslt'] := En16931;
    Result.RuleFiles.Values['PEPPOL-EN16931-UBL.xslt'] := Peppol;
  except
    Result.Free;
    raise;
  end;
end;

{ the codes of the messages with effective level error }
function ErrorCodes(R: TLandrixEInvoiceValidationResult): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to R.MessageCount - 1 do
    if R[I].EffectiveLevel = evl_Error then
      Result := Result + ' ' + Ascii(R[I].Code);
  if R.ScenarioName = '' then
    Result := Result + ' (no scenario)'
  else if not R.XmlSchemaValid then
    Result := Result + ' (XML schema)';
  if R.ProcessingError <> '' then
    Result := Result + ' ' + Ascii(R.ProcessingError);
end;

{ the outputs of this run matching APatterns in cross/, cases/ and sweep/
  next to the program must be accepted, those named in AKnown
  (folder/name) rejected; V is freed }
procedure CheckOutputs(V: TLandrixEInvoiceValidator; const APatterns, AKnown: array of string;
  const AWhat: string);
const
  Folders: array[0..2] of string = ('cross', 'cases', 'sweep');
var
  R: TLandrixEInvoiceValidationResult;
  SR: TSearchRec;
  Dir, Name: string;
  I, J, K, Files: Integer;
  Known: Boolean;
begin
  R := TLandrixEInvoiceValidationResult.Create;
  try
    Files := 0;
    for I := Low(Folders) to High(Folders) do
    begin
      Dir := ExtractFilePath(ParamStr(0)) + Folders[I] + PathDelim;
      for K := Low(APatterns) to High(APatterns) do
        if FindFirst(Dir + APatterns[K], faAnyFile, SR) = 0 then
          try
            repeat
              Inc(Files);
              Name := Folders[I] + '/' + SR.Name;
              Known := False;
              for J := Low(AKnown) to High(AKnown) do
                if AKnown[J] = Name then
                  Known := True;
              if Known then
                Check(not V.Validate(Dir + SR.Name, R), Name + ': known rejection, now accepted')
              else
                Check(V.Validate(Dir + SR.Name, R), Name + ':' + ErrorCodes(R));
            until FindNext(SR) <> 0;
          finally
            FindClose(SR);
          end;
    end;
    if Files = 0 then
      Skip('no ' + AWhat + ' output of this run');
  finally
    R.Free;
    V.Free;
  end;
end;

procedure TestOutputs;
var
  V: TLandrixEInvoiceValidator;
begin
  V := NewKositValidator;
  if V = nil then
    Skip('no KoSIT configuration or rule files (addons/java-tools, tools/testdata/sync-local.py)')
  else
    { no known rejection ('' names no file) }
    CheckOutputs(V, ['*-ubl-30x.xml', '*-cii-30x.xml'], [''], 'XRechnung');
end;

const
  { Peppol outputs the configuration rejects, each with its reason.
    TitelPositionsgruppen: the line groups are written as cac:SubInvoiceLine,
    which UBL-CR-646 (warning) flags; without acceptMatch any failed assert
    rejects. }
  PeppolKnown: array[0..0] of string = ('cross/TitelPositionsgruppen-ubl-peppol.xml');

procedure TestPeppolOutputs;
var
  V: TLandrixEInvoiceValidator;
begin
  V := NewPeppolValidator;
  if V = nil then
    Skip('no Peppol BIS configuration or rule files (addons/java-tools, tools/testdata/sync-local.py)')
  else
    CheckOutputs(V, ['*-peppol.xml'], PeppolKnown, 'Peppol BIS');
end;

procedure Register;
begin
  RegisterTest('Validator.Scenarios', TestScenarios);
  RegisterTest('Validator.Configuration', TestConfiguration);
  RegisterTest('Validator.WithoutAcceptMatch', TestWithoutAcceptMatch);
  RegisterTest('Validator.KositSuite', TestKositSuite);
end;

procedure RegisterLast;
begin
  RegisterTest('Validator.Outputs', TestOutputs);
  RegisterTest('Validator.PeppolOutputs', TestPeppolOutputs);
end;

end.
