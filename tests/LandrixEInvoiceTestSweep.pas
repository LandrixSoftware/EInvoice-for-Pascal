{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Semantic sweep over the official test material (plan, Phase 2 step 3):
  tests/data/local/sweep/<corpus>/ as copied by tools/testdata/sync-local.py
  (skipped when the folder does not exist; a file listed in a corpus
  MANIFEST.txt but missing fails).

  Per file: read and map (model A), detect the specification from the root
  and BT-24, write in that specification to <program folder>/sweep/ (file
  names follow the patterns of tools/validate.ps1; the source goes under
  the same name to <program folder>/sweep-source/, so that both are
  validated alike), read the output and map
  it again (model B), compare every field of A and B. Every finding is one
  line 'stage text'; findings of a complete specification (everything up to
  EN 16931, XRechnung without extension, Peppol) fail unless
  tests/data/sweep-exceptions.txt lists them, and an exception that matches
  nothing fails too. For EXTENDED and the XRechnung extension, content the
  model does not hold is counted, not failed. }

unit LandrixEInvoiceTestSweep;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixXmlWriter,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceCIIWriter,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceUBL,
  LandrixEInvoiceUBLReader,
  LandrixEInvoiceUBLWriter,
  LandrixEInvoiceMapUBL,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestInvoiceCompare;

const
  Corpora: array[0..2] of string = ('kosit-xr302', 'zugferd252', 'peppol');

type
  TSweepException = class(TObject)
  public
    FileName: string;
    Prefix: string;
    Used: Boolean;
  end;

function LocalSweepDir: string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'sweep' + PathDelim;
end;

function OutDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'sweep' + PathDelim;
end;

{ The source files under the name of their detected specification, so that
  tools/validate.ps1 checks them like the outputs. }
function SourceDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'sweep-source' + PathDelim;
end;

function LoadFile(const AFileName: string): TLandrixXmlUtf8;
var
  S: TFileStream;
begin
  Result := '';
  S := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Integer(S.Size));
    if S.Size > 0 then
      S.ReadBuffer(PAnsiChar(Result)^, Integer(S.Size));
  finally
    S.Free;
  end;
end;

procedure SaveFile(const AFileName: string; const AData: TLandrixXmlUtf8);
var
  S: TFileStream;
begin
  S := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(AData) > 0 then
      S.WriteBuffer(PAnsiChar(AData)^, Length(AData));
  finally
    S.Free;
  end;
end;

{ Lines 'name<TAB>prefix'; '#' starts a comment. }
procedure LoadExceptions(AList: TObjectList);
var
  Lines: TStringList;
  I, P: Integer;
  Line: string;
  E: TSweepException;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'sweep-exceptions.txt');
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if (Trim(Line) = '') or (Copy(Trim(Line), 1, 1) = '#') then
        Continue;
      P := Pos(#9, Line);
      if P = 0 then
        raise Exception.Create('sweep-exceptions.txt line ' + IntToStr(I + 1) + ': no tab');
      if Trim(Copy(Line, P + 1, MaxInt)) = '' then
        raise Exception.Create('sweep-exceptions.txt line ' + IntToStr(I + 1) + ': empty finding prefix');
      E := TSweepException.Create;
      E.FileName := Copy(Line, 1, P - 1);
      E.Prefix := Copy(Line, P + 1, MaxInt);
      AList.Add(E);
    end;
  finally
    Lines.Free;
  end;
end;

function RootLocalName(const AXml: TLandrixXmlUtf8): string;
var
  R: TLandrixXmlReader;
begin
  Result := '';
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    while R.Read do
      if R.TokenType = xttStartElement then
      begin
        Result := R.LocalName;
        Exit;
      end;
  finally
    R.Free;
  end;
end;

{ Reads AXml (root ARoot) into AInvoice; returns BT-24. }
function ReadModel(const AXml: TLandrixXmlUtf8; const ARoot: string; AInvoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics): TLandrixEInvoiceString;
var
  R: TLandrixXmlReader;
  CII: TLandrixCIIInvoice;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
begin
  R := TLandrixXmlReader.Create;
  try
    R.LoadFromUtf8(AXml);
    if ARoot = 'CrossIndustryInvoice' then
    begin
      CII := LandrixEInvoiceReadCII(R, D);
      try
        LandrixEInvoiceCIIToInvoice(CII, AInvoice, D);
        Result := CII.ExchangedDocumentContext.GuidelineSpecifiedDocumentContextParameter.ID.Value;
      finally
        CII.Free;
      end;
    end
    else if ARoot = 'CreditNote' then
    begin
      UBLCreditNote := LandrixEInvoiceReadUBLCreditNote(R, D);
      try
        LandrixEInvoiceUBLCreditNoteToInvoice(UBLCreditNote, AInvoice, D);
        Result := UBLCreditNote.CustomizationID.Value;
      finally
        UBLCreditNote.Free;
      end;
    end
    else
    begin
      UBLInvoice := LandrixEInvoiceReadUBLInvoice(R, D);
      try
        LandrixEInvoiceUBLInvoiceToInvoice(UBLInvoice, AInvoice, D);
        Result := UBLInvoice.CustomizationID.Value;
      finally
        UBLInvoice.Free;
      end;
    end;
  finally
    R.Free;
  end;
end;

function WriteModel(AInvoice: TLandrixInvoice; const ASpec: TLandrixEInvoiceSpec;
  D: TLandrixEInvoiceDiagnostics): TLandrixXmlUtf8;
var
  W: TLandrixXmlWriter;
  CII: TLandrixCIIInvoice;
  UBLInvoice: TLandrixUBLInvoice;
  UBLCreditNote: TLandrixUBLCreditNote;
begin
  W := TLandrixXmlWriter.Create;
  try
    W.Indent := True;
    if ASpec.Target.Syntax = esy_CII then
    begin
      CII := LandrixEInvoiceInvoiceToCII(AInvoice, ASpec, D);
      try
        LandrixEInvoiceWriteCII(CII, W, D, ASpec.Target.Profile);
      finally
        CII.Free;
      end;
    end
    else if LandrixEInvoiceUBLRootFor(AInvoice, ASpec) = eur_CreditNote then
    begin
      UBLCreditNote := LandrixEInvoiceInvoiceToUBLCreditNote(AInvoice, ASpec, D);
      try
        LandrixEInvoiceWriteUBLCreditNote(UBLCreditNote, W, D);
      finally
        UBLCreditNote.Free;
      end;
    end
    else
    begin
      UBLInvoice := LandrixEInvoiceInvoiceToUBLInvoice(AInvoice, ASpec, D);
      try
        LandrixEInvoiceWriteUBLInvoice(UBLInvoice, W, D);
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

{ File name suffix that tools/validate.ps1 maps to the configuration. }
function Suffix(const ASpec: TLandrixEInvoiceSpec): string;
begin
  case ASpec.Target.Standard of
    est_XRechnung:
      if ASpec.Target.Syntax = esy_UBL then
        Result := '-ubl-30x.xml'
      else
        Result := '-cii-30x.xml';
    est_PeppolBIS:
      Result := '-ubl-peppol.xml';
  else
    case ASpec.Target.Profile of
      epr_Minimum: Result := '-ciiminimum-25.xml';
      epr_BasicWL: Result := '-ciibasicwl-25.xml';
      epr_Basic: Result := '-ciibasic-25.xml';
      epr_EN16931: Result := '-ciiEN16931-25.xml';
    else
      Result := '-ciiextended-25.xml';
    end;
  end;
end;

{ Diagnostics that mean lost or broken content. }
procedure AddFindings(D: TLandrixEInvoiceDiagnostics; const AStage: string; AFindings: TStrings;
  AOnlyBroken: Boolean);
var
  I: TLandrixEInvoiceListIndex;
  K: TLandrixEInvoiceDiagnosticKind;
begin
  for I := 0 to D.Count - 1 do
  begin
    K := D[I].Kind;
    if (D[I].Severity = eds_Error) or (K in [edk_UnknownElement, edk_DuplicateElement, edk_ConversionFailed]) or
       (not AOnlyBroken and (K in [edk_NotMapped, edk_NotAllowed])) then
      AFindings.Add(AStage + ' ' + string(LandrixEInvoiceDiagnosticKindToStr(K)) + ' ' + string(D[I].Path));
  end;
end;

{ Removes the findings of AFileName that an exception covers. }
procedure ApplyExceptions(const AFileName: string; AFindings: TStrings; AExceptions: TObjectList);
var
  I, J: Integer;
  E: TSweepException;
begin
  for I := AFindings.Count - 1 downto 0 do
    for J := 0 to Integer(AExceptions.Count) - 1 do
    begin
      E := TSweepException(AExceptions[J]);
      if (E.FileName = AFileName) and (Copy(AFindings[I], 1, Length(E.Prefix)) = E.Prefix) then
      begin
        E.Used := True;
        AFindings.Delete(I);
        Break;
      end;
    end;
end;

procedure SweepFile(const ACorpus, AName: string; AExceptions: TObjectList; var AFiles, AFailed, ALost: Integer);
var
  Xml, Written: TLandrixXmlUtf8;
  Root, Key: string;
  A, B: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Findings, Diffs: TStringList;
  Spec, Again: TLandrixEInvoiceSpec;
  Ext, Complete: Boolean;
  CustomizationID: TLandrixEInvoiceString;
  I: Integer;
begin
  Inc(AFiles);
  Key := ACorpus + '/' + AName;
  Findings := TStringList.Create;
  Diffs := TStringList.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  A := TLandrixInvoice.Create;
  B := TLandrixInvoice.Create;
  try
    try
      Xml := LoadFile(LocalSweepDir + ACorpus + PathDelim + AName);
      Root := RootLocalName(Xml);
      CustomizationID := ReadModel(Xml, Root, A, D);
      if not LandrixEInvoiceDetectSpec(TLandrixEInvoiceString(Root), CustomizationID, Spec, Ext) then
        Findings.Add('detect ' + string(CustomizationID))
      else
      begin
        SaveFile(SourceDir + ACorpus + '_' + ChangeFileExt(AName, '') + Suffix(Spec), Xml);
        Complete := not Ext and not ((Spec.Target.Standard = est_FacturX) and (Spec.Target.Profile = epr_Extended));
        AddFindings(D, 'read', Findings, not Complete);
        if not Complete then
          Inc(ALost, D.CountOf(edk_NotMapped));
        D.Clear;
        Written := WriteModel(A, Spec, D);
        AddFindings(D, 'write', Findings, False);
        SaveFile(OutDir + ACorpus + '_' + ChangeFileExt(AName, '') + Suffix(Spec), Written);
        D.Clear;
        CustomizationID := ReadModel(Written, RootLocalName(Written), B, D);
        AddFindings(D, 'reread', Findings, False);
        if not LandrixEInvoiceDetectSpec(TLandrixEInvoiceString(RootLocalName(Written)), CustomizationID, Again, Ext) or
           not LandrixEInvoiceSameTarget(Again.Target, Spec.Target) then
          Findings.Add('redetect ' + string(CustomizationID));
        CompareInvoices(A, B, Diffs);
        for I := 0 to Diffs.Count - 1 do
          Findings.Add('compare ' + Diffs[I]);
      end;
    except
      on E: Exception do
        Findings.Add('exception ' + E.ClassName + ': ' + E.Message);
    end;
    ApplyExceptions(Key, Findings, AExceptions);
    if Findings.Count > 0 then
    begin
      Inc(AFailed);
      WriteLn('  ', Key);
      for I := 0 to Findings.Count - 1 do
        WriteLn('    ', Findings[I]);
    end;
  finally
    B.Free;
    A.Free;
    D.Free;
    Diffs.Free;
    Findings.Free;
  end;
end;

procedure TestSweep;
var
  Exceptions: TObjectList;
  Manifest: TStringList;
  C, I, Files, Failed, Lost, Missing: Integer;
  Name: string;
begin
  if not DirectoryExists(LocalSweepDir) then
  begin
    Skip('no local sweep corpora (tools/testdata/sync-local.py) in ' + LocalSweepDir);
    Exit;
  end;
  Check(ForceDirectories(OutDir) and ForceDirectories(SourceDir), 'sweep output folders');
  Exceptions := TObjectList.Create;
  Manifest := TStringList.Create;
  try
    LoadExceptions(Exceptions);
    Files := 0;
    Failed := 0;
    Lost := 0;
    Missing := 0;
    for C := Low(Corpora) to High(Corpora) do
    begin
      Manifest.LoadFromFile(LocalSweepDir + Corpora[C] + PathDelim + 'MANIFEST.txt');
      for I := 0 to Manifest.Count - 1 do
      begin
        Name := Copy(Manifest[I], 67, MaxInt);
        if not FileExists(LocalSweepDir + Corpora[C] + PathDelim + Name) then
        begin
          Inc(Missing);
          WriteLn('  missing: ', Corpora[C], '/', Name);
          Continue;
        end;
        SweepFile(Corpora[C], Name, Exceptions, Files, Failed, Lost);
      end;
    end;
    for I := 0 to Integer(Exceptions.Count) - 1 do
      if not TSweepException(Exceptions[I]).Used then
      begin
        Inc(Failed);
        WriteLn('  unused exception: ', TSweepException(Exceptions[I]).FileName, ' ',
          TSweepException(Exceptions[I]).Prefix);
      end;
    WriteLn('  sweep: ', Files, ' files, ', Lost, ' paths of EXTENDED or extension content not held by the model');
    CheckEquals(0, Missing, 'files of the manifests missing');
    Check(Files > 0, 'sweep files');
    CheckEquals(0, Failed, IntToStr(Files) + ' files, with findings');
  finally
    Exceptions.Free;
    Manifest.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Sweep.Official', TestSweep);
end;

end.
