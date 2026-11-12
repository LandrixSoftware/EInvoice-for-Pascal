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
  scenario without acceptMatch); Validator.Stream checks that ValidateStream
  gives what Validate gives on the file. Validator.KositSuite runs the KoSIT
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
  addons/java-tools and the Peppol schematron of tests/data/local/kosit/peppol.
  Validator.ZugferdOutputs, registered last as well, checks the ZUGFeRD
  files (*-cii*-25.xml) with the ZUGFeRD 2.5.2 configuration of
  addons/java-tools, whose Schematron sources are compiled (ZugferdRuleMap,
  paths below its Schema/factur-x-1.09.2 folder); skipped without that configuration.
  Validation.Xml checks LandrixEInvoiceValidation with the small configuration
  (verdict from KoSIT, reading, the predicted findings of the own rule check
  on a generated XRechnung; without a configuration no verdict);
  Validation.KositSuite runs it over the KoSIT test
  suite (same verdict and KoSIT findings as the engine, every instance read
  and checked), skipped like Validator.KositSuite. }

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
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoice,
  LandrixEInvoiceValidator,
  LandrixEInvoiceValidation,
  LandrixEInvoicePdfCheck,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestCheck,
  LandrixEInvoiceTestPdf;

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

{ S without loss: characters outside printable ASCII as #hex }
function Lossless(const S: TLandrixEInvoiceString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if (Ord(S[I]) >= 32) and (Ord(S[I]) < 127) and (S[I] <> '#') then
      Result := Result + Char(Ord(S[I]))
    else
      Result := Result + '#' + IntToHex(Ord(S[I]), 4);
end;

{ the message texts, one line each, for comparisons beyond AddResultLines }
procedure AddTexts(Lines: TStrings; R: TLandrixEInvoiceValidationResult);
var
  I: Integer;
begin
  for I := 0 to R.MessageCount - 1 do
    Lines.Add('text ' + Lossless(R[I].Text));
end;

{ ValidateStream on the file AFileName behind the bytes 'junk', read from the
  position after them }
function ValidateFromStream(V: TLandrixEInvoiceValidator; const AFileName: string;
  R: TLandrixEInvoiceValidationResult): Boolean;
var
  S: TMemoryStream;
  F: TFileStream;
begin
  S := TMemoryStream.Create;
  try
    S.WriteBuffer(PAnsiChar(AnsiString('junk'))^, 4);
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      S.CopyFrom(F, 0);
    finally
      F.Free;
    end;
    S.Position := 4;
    Result := V.ValidateStream(S, R);
  finally
    S.Free;
  end;
end;

{ ValidateStream gives exactly what Validate gives: scenario, schema result,
  every message with its position, verdict. }
procedure TestStream;
const
  Docs: array[0..10] of string = ('doc-a-0.xml', 'doc-a-13.xml', 'doc-a-150.xml', 'doc-a-42.xml', 'doc-a-5.xml',
    'doc-a-7.xml', 'doc-a-abc.xml', 'doc-b-5.xml', 'doc-broken.xml', 'doc-f-5.xml', 'doc-x-5.xml');
var
  V: TLandrixEInvoiceValidator;
  R: TLandrixEInvoiceValidationResult;
  FromFile, FromStream: TStringList;
  S: TMemoryStream;
  I: Integer;
begin
  V := NewValidator;
  R := TLandrixEInvoiceValidationResult.Create;
  FromFile := TStringList.Create;
  FromStream := TStringList.Create;
  try
    for I := Low(Docs) to High(Docs) do
    begin
      FromFile.Clear;
      FromStream.Clear;
      V.Validate(DataDir + Docs[I], R);
      AddResultLines(FromFile, Docs[I], R);
      AddTexts(FromFile, R);
      ValidateFromStream(V, DataDir + Docs[I], R);
      AddResultLines(FromStream, Docs[I], R);
      AddTexts(FromStream, R);
      CheckEqualsStr(FromFile.Text, FromStream.Text, Docs[I] + ': stream as file');
    end;
    { an empty stream and no stream: not well-formed, no exception }
    S := TMemoryStream.Create;
    try
      Check(not V.ValidateStream(S, R), 'empty stream rejected');
      CheckEquals(1, R.MessageCount, 'empty stream: one message');
      Check((R.MessageCount = 1) and (R[0].Step = evs_Wellformedness), 'empty stream: well-formedness');
    finally
      S.Free;
    end;
    { a stream at its end holds nothing more, however much is before }
    S := TMemoryStream.Create;
    try
      S.LoadFromFile(DataDir + 'doc-a-5.xml');
      S.Position := S.Size;
      Check(not V.ValidateStream(S, R), 'stream at its end rejected');
      Check((R.MessageCount = 1) and (R[0].Step = evs_Wellformedness), 'stream at its end: well-formedness');
    finally
      S.Free;
    end;
    Check(not V.ValidateStream(nil, R), 'no stream rejected');
    Check((R.MessageCount = 1) and (R[0].Step = evs_Wellformedness), 'no stream: well-formedness');
  finally
    FromStream.Free;
    FromFile.Free;
    R.Free;
    V.Free;
  end;
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
  Names, Actual, Reference, FromStream, FileFull: TStringList;
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
  FromStream := TStringList.Create;
  FileFull := TStringList.Create;
  try
    Accepted := 0;
    for I := 0 to Names.Count - 1 do
    begin
      if V.Validate(Local + 'instances' + PathDelim + Names[I], R) then
        Inc(Accepted);
      AddResultLines(Actual, Names[I], R);
      AddResultLines(FileFull, Names[I], R);
      AddTexts(FileFull, R);
      ValidateFromStream(V, Local + 'instances' + PathDelim + Names[I], R);
      AddResultLines(FromStream, Names[I], R);
      AddTexts(FromStream, R);
    end;
    CheckEqualsStr(FileFull.Text, FromStream.Text, 'ValidateStream gives the same results');
    CheckEquals(86, Names.Count, 'instances');
    CheckEquals(Names.Count, Accepted, 'every instance accepted');
    Reference.LoadFromFile(Expected);
    CheckEquals(Reference.Count, Actual.Count, 'lines of ' + Expected);
    for I := 0 to Reference.Count - 1 do
      if I < Actual.Count then
        CheckEqualsStr(Reference[I], Actual[I], 'line ' + IntToStr(I + 1));
  finally
    FileFull.Free;
    FromStream.Free;
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
      for K := 0 to Integer(High(APatterns)) do
        if FindFirst(Dir + APatterns[K], faAnyFile, SR) = 0 then
          try
            repeat
              Inc(Files);
              Name := Folders[I] + '/' + SR.Name;
              Known := False;
              for J := 0 to Integer(High(AKnown)) do
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
  { the Schematron step of each profile (a wrapper XSLT of the configuration
    importing the profile's XSLT) and the source of that XSLT }
  ZugferdRuleMap: array[0..4, 0..1] of string = (
    ('Factur-X-1.09.2_MINIMUM.xslt', '0_Factur-X_1.09.2_MINIMUM/FACTUR-X_MINIMUM.sch'),
    ('Factur-X-1.09.2_BASICWL.xslt', '1_Factur-X_1.09.2_BASICWL/FACTUR-X_BASIC-WL.sch'),
    ('Factur-X-1.09.2_BASIC.xslt', '2_Factur-X_1.09.2_BASIC/FACTUR-X_BASIC.sch'),
    ('Factur-X-1.09.2_EN16931.xslt', '3_Factur-X_1.09.2_EN16931/FACTUR-X_EN16931.sch'),
    ('Factur-X-1.09.2_EXTENDED.xslt', '4_Factur-X_1.09.2_EXTENDED/FACTUR-X_EXTENDED.sch'));

{ the ZUGFeRD configuration with its own Schematron sources; nil if the
  configuration or a source is missing (e.g. another version installed) }
function NewZugferdValidator: TLandrixEInvoiceValidator;
var
  Dir, Schema: string;
  I: Integer;
begin
  Result := nil;
  Dir := RepositoryRoot + 'addons' + PathDelim + 'java-tools' + PathDelim + 'validator-configuration-zugferd' +
    PathDelim;
  Schema := Dir + 'Schema' + PathDelim + 'factur-x-1.09.2' + PathDelim;
  if not FileExists(Dir + 'scenarios.xml') then
    Exit;
  for I := Low(ZugferdRuleMap) to High(ZugferdRuleMap) do
    if not FileExists(Schema + StringReplace(ZugferdRuleMap[I, 1], '/', PathDelim, [rfReplaceAll])) then
      Exit;
  Result := TLandrixEInvoiceValidator.Create;
  try
    Result.LoadConfiguration(Dir + 'scenarios.xml');
    for I := Low(ZugferdRuleMap) to High(ZugferdRuleMap) do
      Result.RuleFiles.Values[ZugferdRuleMap[I, 0]] := Schema +
        StringReplace(ZugferdRuleMap[I, 1], '/', PathDelim, [rfReplaceAll]);
  except
    Result.Free;
    raise;
  end;
end;

procedure TestZugferdOutputs;
var
  V: TLandrixEInvoiceValidator;
begin
  V := NewZugferdValidator;
  if V = nil then
    Skip('no ZUGFeRD 2.5.2 configuration (addons/java-tools)')
  else
    { no known rejection ('' names no file) }
    CheckOutputs(V, ['*-cii*-25.xml'], [''], 'ZUGFeRD');
end;

procedure TestPeppolOutputs;
var
  V: TLandrixEInvoiceValidator;
begin
  V := NewPeppolValidator;
  if V = nil then
    Skip('no Peppol BIS configuration or rule files (addons/java-tools, tools/testdata/sync-local.py)')
  else
    { no known rejection ('' names no file) }
    CheckOutputs(V, ['*-peppol.xml'], [''], 'Peppol BIS');
end;

{ --- LandrixEInvoiceValidation ------------------------------------------- }

function NewDocumentValidator(V: TLandrixEInvoiceValidator): TLandrixEInvoiceDocumentValidator;
begin
  Result := TLandrixEInvoiceDocumentValidator.Create;
  Result.Options.Configuration := V;
end;

{ the findings as "part:rule:severity[:predicted]", separated by spaces }
function Findings(R: TLandrixEInvoiceDocumentValidation): string;
const
  PartText: array[TLandrixEInvoiceValidationPart] of string = ('read', 'kosit', 'model', 'pdf', 'xmp', 'pdfa');
  SeverityText: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('info', 'warning', 'error');
var
  I: Integer;
begin
  Result := '';
  for I := 0 to R.FindingCount - 1 do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + PartText[R[I].Part] + ':' + string(R[I].RuleID) + ':' + SeverityText[R[I].Severity];
    if R[I].Predicted then
      Result := Result + ':predicted';
  end;
end;

procedure CheckStatus(R: TLandrixEInvoiceDocumentValidation; ARead, AKosit, AModel: TLandrixEInvoicePartStatus;
  const AName: string);
begin
  CheckEquals(Ord(ARead), Ord(R.Status[evp_Read]), AName + ': read status');
  CheckEquals(Ord(AKosit), Ord(R.Status[evp_KoSIT]), AName + ': KoSIT status');
  CheckEquals(Ord(AModel), Ord(R.Status[evp_ModelCheck]), AName + ': model check status');
end;

{ a complete invoice for ATarget as bytes; without a buyer reference an
  XRechnung breaks BR-DE-15 (written despite the error) }
function InvoiceBytes(const ATarget: TLandrixEInvoiceTarget; AWithBuyerReference: Boolean): AnsiString;
var
  Invoice: TLandrixInvoice;
  Xml: TLandrixXmlUtf8;
begin
  Invoice := TLandrixInvoice.Create;
  try
    FillComplete(Invoice);
    if not AWithBuyerReference then
      Invoice.BuyerReference := '';
    Xml := TLandrixEInvoice.SaveToUtf8(Invoice, ATarget, [eio_WriteDespiteErrors]);
  finally
    Invoice.Free;
  end;
  Result := '';
  SetLength(Result, Length(Xml));
  if Length(Xml) > 0 then
    Move(PAnsiChar(Xml)^, PAnsiChar(Result)^, Length(Xml));
end;

function BytesStream(const ABytes: AnsiString): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  if ABytes <> '' then
    Result.WriteBuffer(PAnsiChar(ABytes)^, Length(ABytes));
  Result.Position := 0;
end;

{ an XRechnung UBL invoice as a stream }
function InvoiceStream(AWithBuyerReference: Boolean): TMemoryStream;
begin
  Result := BytesStream(InvoiceBytes(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), AWithBuyerReference));
end;

{ an XRechnung CII invoice in a hybrid PDF as xrechnung.xml }
function XRechnungPdf(AWithBuyerReference, AWithXmp: Boolean): AnsiString;
begin
  Result := BuildHybridPdf('xrechnung.xml', InvoiceBytes(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII),
    AWithBuyerReference), TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), AWithXmp);
end;

procedure CheckPdfStatus(R: TLandrixEInvoiceDocumentValidation; AEmbedding, AMetadata: TLandrixEInvoicePartStatus;
  const AName: string);
begin
  CheckEquals(Ord(AEmbedding), Ord(R.Status[evp_PdfEmbedding]), AName + ': embedding status');
  CheckEquals(Ord(AMetadata), Ord(R.Status[evp_PdfMetadata]), AName + ': metadata status');
  CheckEquals(Ord(evr_NotRun), Ord(R.Status[evp_PdfA]), AName + ': PDF/A not run');
end;

{ validates the bytes APdf }
function ValidateBytes(DV: TLandrixEInvoiceDocumentValidator; const APdf: AnsiString;
  R: TLandrixEInvoiceDocumentValidation): TLandrixEInvoiceVerdict;
var
  S: TMemoryStream;
begin
  S := BytesStream(APdf);
  try
    Result := DV.ValidateStream(S, R);
  finally
    S.Free;
  end;
end;

{ AStream's bytes with every AOld replaced by ANew }
procedure ReplaceBytes(AStream: TMemoryStream; const AOld, ANew: AnsiString);
var
  S, Rest: AnsiString;
  P, N: Integer;
begin
  N := Integer(AStream.Size);
  Rest := '';
  SetLength(Rest, N);
  if N > 0 then
    Move(AStream.Memory^, PAnsiChar(Rest)^, N);
  S := '';
  P := Pos(AOld, Rest);
  while P > 0 do
  begin
    S := S + Copy(Rest, 1, P - 1) + ANew;
    Delete(Rest, 1, P - 1 + Length(AOld));
    P := Pos(AOld, Rest);
  end;
  S := S + Rest;
  AStream.Clear;
  AStream.WriteBuffer(PAnsiChar(S)^, Length(S));
  AStream.Position := 0;
end;

{ The verdict is KoSIT's; reading and the own rule check add findings. }
procedure TestDocumentXml;
var
  V: TLandrixEInvoiceValidator;
  DV: TLandrixEInvoiceDocumentValidator;
  R: TLandrixEInvoiceDocumentValidation;
  S, F: TMemoryStream;
  FromFile: string;
begin
  V := NewValidator;
  DV := NewDocumentValidator(V);
  R := TLandrixEInvoiceDocumentValidation.Create;
  try
    CheckEquals(Ord(ev_Incomplete), Ord(R.Verdict), 'a new result is incomplete');
    { accepted by the test configuration, but no invoice: reading fails,
      no rule check, the verdict stays }
    CheckEquals(Ord(ev_Accepted), Ord(DV.ValidateFile(DataDir + 'doc-a-5.xml', R)), 'doc-a-5 verdict');
    CheckEqualsStr('Test A', string(R.ScenarioName), 'doc-a-5 scenario');
    CheckStatus(R, evr_Failed, evr_Passed, evr_NotRun, 'doc-a-5');
    CheckEqualsStr('read::error', Findings(R), 'doc-a-5 findings');
    CheckEqualsStr('', string(R.Info.RootName), 'doc-a-5 no info');
    CheckEquals(Ord(ev_Accepted), Ord(DV.ValidateFile(DataDir + 'doc-a-7.xml', R)), 'doc-a-7 verdict');
    CheckEqualsStr('kosit:T-03:info read::error', Findings(R), 'doc-a-7 findings');
    CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateFile(DataDir + 'doc-a-13.xml', R)), 'doc-a-13 verdict');
    CheckStatus(R, evr_Failed, evr_Failed, evr_NotRun, 'doc-a-13');
    CheckEqualsStr('kosit:T-04:error read::error', Findings(R), 'doc-a-13 findings');
    CheckEqualsStr('v is not 13', string(R[0].Text), 'doc-a-13 text');
    Check(not R[0].Predicted, 'a KoSIT finding is no prediction');
    { file and stream give the same }
    FromFile := Findings(R);
    S := TMemoryStream.Create;
    try
      S.LoadFromFile(DataDir + 'doc-a-13.xml');
      CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateStream(S, R)), 'doc-a-13 stream verdict');
      CheckEqualsStr(FromFile, Findings(R), 'doc-a-13 stream findings');
    finally
      S.Free;
    end;
    { not well-formed: KoSIT says so, reading does not run }
    CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateFile(DataDir + 'doc-broken.xml', R)), 'broken verdict');
    CheckStatus(R, evr_NotRun, evr_Failed, evr_NotRun, 'broken');
    CheckEqualsStr('kosit:generic-error:error', Findings(R), 'broken findings');
    Check(R[0].Line > 0, 'broken line');
    CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateStream(nil, R)), 'no stream verdict');
    CheckStatus(R, evr_NotRun, evr_Failed, evr_NotRun, 'no stream');
    S := TMemoryStream.Create;
    try
      CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateStream(S, R)), 'empty stream verdict');
      CheckStatus(R, evr_NotRun, evr_Failed, evr_NotRun, 'empty stream');
      CheckEqualsStr('kosit:generic-error:error', Findings(R), 'empty stream findings');
      { read from the position on: what is before does not count }
      S.WriteBuffer(PAnsiChar(AnsiString('junk'))^, 4);
      S.Position := S.Size;
      CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateStream(S, R)), 'stream at its end verdict');
      CheckStatus(R, evr_NotRun, evr_Failed, evr_NotRun, 'stream at its end');
      F := TMemoryStream.Create;
      try
        F.LoadFromFile(DataDir + 'doc-a-13.xml');
        S.CopyFrom(F, 0);
      finally
        F.Free;
      end;
      S.Position := 4;
      DV.ValidateStream(S, R);
      CheckEqualsStr(FromFile, Findings(R), 'stream from its position');
      Check(S.Position = S.Size, 'stream read to its end');
    finally
      S.Free;
    end;

    { a valid XRechnung no scenario of the test configuration matches:
      rejected, read, the rule check finds nothing }
    S := InvoiceStream(True);
    try
      CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateStream(S, R)), 'invoice verdict');
      CheckEqualsStr('', string(R.ScenarioName), 'invoice scenario');
      CheckStatus(R, evr_Passed, evr_Failed, evr_Passed, 'invoice');
      { KoSIT has no message for it; the validation adds one }
      CheckEqualsStr('kosit::error', Findings(R), 'invoice findings');
      CheckEqualsStr('No scenario of the configuration matches the document', string(R[0].Text),
        'invoice no scenario');
      Check(R.Info.SpecFound, 'invoice specification found');
      CheckEquals(Ord(esy_UBL), Ord(R.Info.Syntax), 'invoice syntax');
      { without the rule check }
      DV.Options.ModelCheck := False;
      S.Position := 0;
      DV.ValidateStream(S, R);
      CheckStatus(R, evr_Passed, evr_Failed, evr_NotRun, 'invoice without rule check');
      DV.Options.ModelCheck := True;
    finally
      S.Free;
    end;
    { BR-DE-15 broken: a predicted finding, the verdict is still KoSIT's }
    S := InvoiceStream(False);
    try
      CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateStream(S, R)), 'BR-DE-15 verdict');
      CheckStatus(R, evr_Passed, evr_Failed, evr_Failed, 'BR-DE-15');
      CheckEqualsStr('kosit::error model:BR-DE-15:error:predicted', Findings(R), 'BR-DE-15 findings');
    finally
      S.Free;
    end;
    { a VAT rate of 1e24 is read, but the rule check cannot format it: the
      rule check is incomplete, the verdict stays }
    S := InvoiceStream(True);
    try
      ReplaceBytes(S, 'Percent>19', 'Percent>1000000000000000000000000');
      CheckEquals(Ord(ev_Rejected), Ord(DV.ValidateStream(S, R)), 'huge rate verdict');
      CheckEquals(Ord(evr_Incomplete), Ord(R.Status[evp_ModelCheck]), 'huge rate: rule check incomplete');
      CheckEqualsStr('model::error', Copy(Findings(R), Length(Findings(R)) - 11, MaxInt), 'huge rate: last finding');
      Check(not R[R.FindingCount - 1].Predicted, 'huge rate: no prediction');
    finally
      S.Free;
    end;
  finally
    R.Free;
    DV.Free;
    V.Free;
  end;
  { a scenario without a name is chosen like any other: no finding for it }
  V := TLandrixEInvoiceValidator.Create;
  DV := NewDocumentValidator(V);
  R := TLandrixEInvoiceDocumentValidation.Create;
  try
    V.LoadConfiguration(DataDir + 'scenarios-unnamed.xml');
    V.RuleFiles.Values['test.xsl'] := DataDir + 'test.sch';
    CheckEquals(Ord(ev_Accepted), Ord(DV.ValidateFile(DataDir + 'doc-a-5.xml', R)), 'unnamed verdict');
    CheckEqualsStr('', string(R.ScenarioName), 'unnamed scenario');
    CheckEqualsStr('read::error', Findings(R), 'unnamed findings');
  finally
    R.Free;
    DV.Free;
    V.Free;
  end;
  { no configuration: no verdict; reading and the rule check run }
  DV := TLandrixEInvoiceDocumentValidator.Create;
  R := TLandrixEInvoiceDocumentValidation.Create;
  try
    S := InvoiceStream(True);
    try
      CheckEquals(Ord(ev_Incomplete), Ord(DV.ValidateStream(S, R)), 'no KoSIT: invoice verdict');
      CheckStatus(R, evr_Passed, evr_NotRun, evr_Passed, 'no KoSIT: invoice');
      CheckEqualsStr('', Findings(R), 'no KoSIT: invoice findings');
      CheckEqualsStr('', string(R.ScenarioName), 'no KoSIT: no scenario');
      Check(R.Info.SpecFound, 'no KoSIT: specification found');
      Check(S.Position = S.Size, 'no KoSIT: stream read to its end');
      DV.Options.ModelCheck := False;
      S.Position := 0;
      DV.ValidateStream(S, R);
      CheckStatus(R, evr_Passed, evr_NotRun, evr_NotRun, 'no KoSIT: invoice without rule check');
      DV.Options.ModelCheck := True;
    finally
      S.Free;
    end;
    S := InvoiceStream(False);
    try
      CheckEquals(Ord(ev_Incomplete), Ord(DV.ValidateStream(S, R)), 'no KoSIT: BR-DE-15 verdict');
      CheckStatus(R, evr_Passed, evr_NotRun, evr_Failed, 'no KoSIT: BR-DE-15');
      CheckEqualsStr('model:BR-DE-15:error:predicted', Findings(R), 'no KoSIT: BR-DE-15 findings');
    finally
      S.Free;
    end;
    { an invoice that is not well-formed: reading says where, no rule check }
    S := InvoiceStream(True);
    try
      ReplaceBytes(S, '</Invoice>', '</Invoce>');
      CheckEquals(Ord(ev_Incomplete), Ord(DV.ValidateStream(S, R)), 'no KoSIT: broken invoice verdict');
      CheckStatus(R, evr_Failed, evr_NotRun, evr_NotRun, 'no KoSIT: broken invoice');
      CheckEqualsStr('read::error', Findings(R), 'no KoSIT: broken invoice findings');
      Check(R[0].Line > 0, 'no KoSIT: broken invoice line');
    finally
      S.Free;
    end;
    { not well-formed with an unknown root: the root is reported first }
    CheckEquals(Ord(ev_Incomplete), Ord(DV.ValidateFile(DataDir + 'doc-broken.xml', R)), 'no KoSIT: broken verdict');
    CheckStatus(R, evr_Failed, evr_NotRun, evr_NotRun, 'no KoSIT: broken');
    CheckEqualsStr('read::error', Findings(R), 'no KoSIT: broken findings');
    { well-formed, but no invoice }
    CheckEquals(Ord(ev_Incomplete), Ord(DV.ValidateFile(DataDir + 'doc-a-5.xml', R)), 'no KoSIT: doc-a-5 verdict');
    CheckStatus(R, evr_Failed, evr_NotRun, evr_NotRun, 'no KoSIT: doc-a-5');
    CheckEqualsStr('read::error', Findings(R), 'no KoSIT: doc-a-5 findings');
    CheckEquals(Ord(ev_Incomplete), Ord(DV.ValidateStream(nil, R)), 'no KoSIT: no stream verdict');
    CheckStatus(R, evr_Failed, evr_NotRun, evr_NotRun, 'no KoSIT: no stream');
    CheckEqualsStr('read::error', Findings(R), 'no KoSIT: no stream findings');
    S := TMemoryStream.Create;
    try
      CheckEquals(Ord(ev_Incomplete), Ord(DV.ValidateStream(S, R)), 'no KoSIT: empty stream verdict');
      CheckStatus(R, evr_Failed, evr_NotRun, evr_NotRun, 'no KoSIT: empty stream');
      CheckEqualsStr('read::error', Findings(R), 'no KoSIT: empty stream findings');
    finally
      S.Free;
    end;
  finally
    R.Free;
    DV.Free;
  end;
end;

{ A hybrid PDF: levels 2 and 3 decide with KoSIT; their findings come first. }
procedure TestDocumentPdf;
var
  V: TLandrixEInvoiceValidator;
  DV: TLandrixEInvoiceDocumentValidator;
  R: TLandrixEInvoiceDocumentValidation;
  Doc: AnsiString;
  S: TMemoryStream;
begin
  DV := TLandrixEInvoiceDocumentValidator.Create;
  R := TLandrixEInvoiceDocumentValidation.Create;
  V := nil;
  try
    { without KoSIT: levels 2 and 3 pass, so no verdict }
    CheckEquals(Ord(ev_Incomplete), Ord(ValidateBytes(DV, XRechnungPdf(True, True), R)), 'good PDF verdict');
    CheckPdfStatus(R, evr_Passed, evr_Passed, 'good PDF');
    CheckStatus(R, evr_Passed, evr_NotRun, evr_Passed, 'good PDF');
    CheckEqualsStr('', Findings(R), 'good PDF findings');
    Check(R.Pdf <> nil, 'good PDF: PDF result');
    if R.Pdf <> nil then
    begin
      CheckEquals(Ord(ehk_XRechnung), Ord(R.Pdf.HybridKind), 'good PDF: hybrid kind');
      Check(R.Pdf.FactsChecked, 'good PDF: facts checked');
    end;
    CheckEquals(Ord(eso_Pdf), Ord(R.Info.Source), 'good PDF: source');
    CheckEqualsStr('xrechnung.xml', string(R.Info.PdfAttachmentName), 'good PDF: attachment name');
    Check(R.Info.SpecFound, 'good PDF: specification found');
    { the rule check of the embedded invoice predicts, never decides }
    CheckEquals(Ord(ev_Incomplete), Ord(ValidateBytes(DV, XRechnungPdf(False, True), R)), 'BR-DE-15 PDF verdict');
    CheckEqualsStr('model:BR-DE-15:error:predicted', Findings(R), 'BR-DE-15 PDF findings');
    { no XMP: level 3 fails, rejected without KoSIT }
    CheckEquals(Ord(ev_Rejected), Ord(ValidateBytes(DV, XRechnungPdf(True, False), R)), 'no XMP verdict');
    CheckPdfStatus(R, evr_Passed, evr_Failed, 'no XMP');
    CheckEqualsStr('xmp:LX-PDF-11:error', Findings(R), 'no XMP findings');
    { an XRechnung named factur-x.xml: the second pass fails level 2 }
    Doc := BuildHybridPdf('factur-x.xml', InvoiceBytes(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), True),
      TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII), True);
    CheckEquals(Ord(ev_Rejected), Ord(ValidateBytes(DV, Doc, R)), 'wrong name verdict');
    CheckEquals(Ord(evr_Failed), Ord(R.Status[evp_PdfEmbedding]), 'wrong name: embedding failed');
    Check(Pos('pdf:BR-HYBRID-13:error', Findings(R)) = 1, 'wrong name findings: ' + Findings(R));
    { well-formed, but no invoice: no facts, so level 2 is incomplete }
    S := TMemoryStream.Create;
    try
      S.LoadFromFile(DataDir + 'doc-a-5.xml');
      SetLength(Doc, Integer(S.Size));
      Move(S.Memory^, PAnsiChar(Doc)^, Integer(S.Size));
    finally
      S.Free;
    end;
    CheckEquals(Ord(ev_Incomplete), Ord(ValidateBytes(DV, BuildHybridPdf('factur-x.xml', Doc,
      TLandrixEInvoiceTargets.FacturX('1.09', epr_EN16931), True), R)), 'no invoice verdict');
    CheckPdfStatus(R, evr_Incomplete, evr_Passed, 'no invoice');
    CheckStatus(R, evr_Failed, evr_NotRun, evr_NotRun, 'no invoice');
    CheckEqualsStr('read::error', Findings(R), 'no invoice findings');
    { a PDF that cannot be read: rejected, nothing else runs }
    CheckEquals(Ord(ev_Rejected), Ord(ValidateBytes(DV, '%PDF-1.7'#10'junk', R)), 'broken PDF verdict');
    CheckPdfStatus(R, evr_Failed, evr_NotRun, 'broken PDF');
    CheckStatus(R, evr_NotRun, evr_NotRun, evr_NotRun, 'broken PDF');
    CheckEqualsStr('pdf:LX-PDF-01:error', Findings(R), 'broken PDF findings');
    { XML again: no PDF result }
    ValidateBytes(DV, InvoiceBytes(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), True), R);
    Check(R.Pdf = nil, 'XML: no PDF result');
    CheckEquals(Ord(evr_NotRun), Ord(R.Status[evp_PdfEmbedding]), 'XML: no embedding');

    { with the test configuration: KoSIT finds no scenario, the PDF findings
      come first }
    V := NewValidator;
    DV.Options.Configuration := V;
    CheckEquals(Ord(ev_Rejected), Ord(ValidateBytes(DV, XRechnungPdf(True, True), R)), 'KoSIT PDF verdict');
    CheckPdfStatus(R, evr_Passed, evr_Passed, 'KoSIT PDF');
    CheckStatus(R, evr_Passed, evr_Failed, evr_Passed, 'KoSIT PDF');
    CheckEqualsStr('kosit::error', Findings(R), 'KoSIT PDF findings');
    CheckEquals(Ord(ev_Rejected), Ord(ValidateBytes(DV, XRechnungPdf(False, False), R)), 'KoSIT no XMP verdict');
    CheckEqualsStr('xmp:LX-PDF-11:error kosit::error model:BR-DE-15:error:predicted', Findings(R),
      'KoSIT no XMP findings');
  finally
    R.Free;
    DV.Free;
    V.Free;
  end;
end;

{ A hybrid PDF with the KoSIT XRechnung configuration: accepted. }
procedure TestDocumentPdfKosit;
var
  V: TLandrixEInvoiceValidator;
  DV: TLandrixEInvoiceDocumentValidator;
  R: TLandrixEInvoiceDocumentValidation;
begin
  V := NewKositValidator;
  if V = nil then
  begin
    Skip('no KoSIT configuration (addons/java-tools)');
    Exit;
  end;
  DV := NewDocumentValidator(V);
  R := TLandrixEInvoiceDocumentValidation.Create;
  try
    CheckEquals(Ord(ev_Accepted), Ord(ValidateBytes(DV, XRechnungPdf(True, True), R)), 'verdict: ' + Findings(R));
    CheckPdfStatus(R, evr_Passed, evr_Passed, 'accepted PDF');
    CheckStatus(R, evr_Passed, evr_Passed, evr_Passed, 'accepted PDF');
    Check(R.ScenarioName <> '', 'accepted PDF: scenario');
    { BR-DE-15: KoSIT rejects, the rule check predicted it }
    CheckEquals(Ord(ev_Rejected), Ord(ValidateBytes(DV, XRechnungPdf(False, True), R)), 'BR-DE-15 verdict');
    Check(Pos('kosit:BR-DE-15:error', Findings(R)) = 1, 'BR-DE-15 findings: ' + Findings(R));
  finally
    R.Free;
    DV.Free;
    V.Free;
  end;
end;

{ Over the local PDF corpus without KoSIT: the PDF findings are those of
  the PDF checker, each in a part that ran; rejected exactly when level 2
  or 3 failed, never accepted. }
procedure TestDocumentPdfCorpus;
var
  Dir: string;
  SR: TSearchRec;
  DV: TLandrixEInvoiceDocumentValidator;
  R: TLandrixEInvoiceDocumentValidation;
  I, PdfFindings, Files, Rejected, Incomplete: Integer;
  Failed: Boolean;
begin
  Dir := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'pdf' + PathDelim;
  if not FileExists(Dir + 'index.txt') then
  begin
    Skip('no local PDF corpus in ' + Dir);
    Exit;
  end;
  DV := TLandrixEInvoiceDocumentValidator.Create;
  R := TLandrixEInvoiceDocumentValidation.Create;
  Files := 0;
  Rejected := 0;
  Incomplete := 0;
  try
    if FindFirst(Dir + '*.pdf', faAnyFile, SR) = 0 then
      try
        repeat
          Inc(Files);
          DV.ValidateFile(Dir + SR.Name, R);
          Check(R.Pdf <> nil, SR.Name + ': PDF result');
          if R.Pdf = nil then
            Continue;
          PdfFindings := 0;
          for I := 0 to R.FindingCount - 1 do
          begin
            Check(R.Status[R[I].Part] <> evr_NotRun, SR.Name + ': finding ' + string(R[I].RuleID) + ' in a part that ran');
            if R[I].Part in [evp_PdfEmbedding, evp_PdfMetadata] then
              Inc(PdfFindings);
          end;
          CheckEquals(Integer(R.Pdf.Diagnostics.Count), PdfFindings, SR.Name + ': PDF findings');
          Failed := (R.Status[evp_PdfEmbedding] = evr_Failed) or (R.Status[evp_PdfMetadata] = evr_Failed);
          Check(R.Verdict <> ev_Accepted, SR.Name + ': not accepted without KoSIT');
          CheckEquals(Ord(Failed), Ord(R.Verdict = ev_Rejected), SR.Name + ': rejected exactly on a failed level');
          if R.Verdict = ev_Rejected then
            Inc(Rejected)
          else
            Inc(Incomplete);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
  finally
    R.Free;
    DV.Free;
  end;
  WriteLn('  PDF corpus: ', Files, ' files, ', Rejected, ' rejected, ', Incomplete, ' incomplete');
end;

{ Over the KoSIT test suite: the verdict and the KoSIT findings are those of
  the engine; every instance is read and checked. }
procedure TestDocumentKositSuite;
var
  Local: string;
  V: TLandrixEInvoiceValidator;
  DV: TLandrixEInvoiceDocumentValidator;
  K: TLandrixEInvoiceValidationResult;
  R: TLandrixEInvoiceDocumentValidation;
  Msg: TLandrixEInvoiceValidationMessage;
  Names: TStringList;
  I, J, KositFindings, Checked: Integer;
begin
  Local := KositLocal;
  V := nil;
  if FileExists(Local + 'instances' + PathDelim + 'MANIFEST.txt') then
    V := NewKositValidator;
  if V = nil then
  begin
    Skip('no KoSIT test suite or configuration (tools/testdata/sync-local.py, addons/java-tools)');
    Exit;
  end;
  DV := NewDocumentValidator(V);
  K := TLandrixEInvoiceValidationResult.Create;
  R := TLandrixEInvoiceDocumentValidation.Create;
  Names := ManifestNames(Local + 'instances' + PathDelim + 'MANIFEST.txt');
  try
    Checked := 0;
    for I := 0 to Names.Count - 1 do
    begin
      V.Validate(Local + 'instances' + PathDelim + Names[I], K);
      DV.ValidateFile(Local + 'instances' + PathDelim + Names[I], R);
      CheckEquals(Ord(K.Accepted), Ord(R.Verdict = ev_Accepted), Names[I] + ': verdict');
      CheckEquals(Ord(ev_Accepted), Ord(R.Verdict), Names[I] + ': accepted');
      CheckEqualsStr(string(K.ScenarioName), string(R.ScenarioName), Names[I] + ': scenario');
      { the KoSIT findings are the engine's messages, in order, in full }
      KositFindings := 0;
      for J := 0 to R.FindingCount - 1 do
        if R[J].Part = evp_KoSIT then
        begin
          if KositFindings < K.MessageCount then
          begin
            Msg := K[KositFindings];
            CheckEqualsStr(string(Msg.Code), string(R[J].RuleID), Names[I] + ': KoSIT code');
            CheckEquals(Ord(Msg.EffectiveLevel), Ord(R[J].Severity), Names[I] + ': KoSIT level');
            CheckEqualsStr(Lossless(Msg.Location), Lossless(R[J].Location), Names[I] + ': KoSIT location');
            CheckEquals(Msg.Line, R[J].Line, Names[I] + ': KoSIT line');
            CheckEquals(Msg.Column, R[J].Column, Names[I] + ': KoSIT column');
            CheckEqualsStr(Lossless(Msg.Text), Lossless(R[J].Text), Names[I] + ': KoSIT text');
            Check(not R[J].Predicted, Names[I] + ': KoSIT no prediction');
          end;
          Inc(KositFindings);
        end;
      CheckEquals(K.MessageCount, KositFindings, Names[I] + ': KoSIT findings');
      CheckEquals(Ord(evr_Passed), Ord(R.Status[evp_Read]), Names[I] + ': read');
      { the rule check runs when reading knows the specification (BT-24)
        and not otherwise }
      if R.Info.SpecFound then
      begin
        Inc(Checked);
        Check(R.Status[evp_ModelCheck] in [evr_Passed, evr_Failed], Names[I] + ': rule check ran');
      end
      else
        CheckEquals(Ord(evr_NotRun), Ord(R.Status[evp_ModelCheck]), Names[I] + ': no rule check');
    end;
    CheckEquals(86, Names.Count, 'instances');
    Check(Checked > 80, 'most instances checked');
  finally
    Names.Free;
    R.Free;
    K.Free;
    DV.Free;
    V.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Validator.Scenarios', TestScenarios);
  RegisterTest('Validator.Configuration', TestConfiguration);
  RegisterTest('Validator.Stream', TestStream);
  RegisterTest('Validator.WithoutAcceptMatch', TestWithoutAcceptMatch);
  RegisterTest('Validator.KositSuite', TestKositSuite);
  RegisterTest('Validation.Xml', TestDocumentXml);
  RegisterTest('Validation.Pdf', TestDocumentPdf);
  RegisterTest('Validation.PdfCorpus', TestDocumentPdfCorpus);
  RegisterTest('Validation.KositSuite', TestDocumentKositSuite);
  RegisterTest('Validation.PdfKosit', TestDocumentPdfKosit);
end;

procedure RegisterLast;
begin
  RegisterTest('Validator.Outputs', TestOutputs);
  RegisterTest('Validator.PeppolOutputs', TestPeppolOutputs);
  RegisterTest('Validator.ZugferdOutputs', TestZugferdOutputs);
end;

end.
