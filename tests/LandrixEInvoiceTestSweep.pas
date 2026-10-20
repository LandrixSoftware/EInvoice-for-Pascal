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
  LandrixEInvoiceCheck,
  LandrixEInvoiceCompatXRechnungAdapter,
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

{ XRechnung sources written in the other syntax, named '<source without
  .xml>-x<suffix of the other syntax>',
  for the XR comparison across syntaxes (tools/testdata/xr-compare.py). }
function CrossDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'sweep-cross' + PathDelim;
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
  Spec, Again, CrossSpec: TLandrixEInvoiceSpec;
  Other: TLandrixEInvoiceSyntax;
  K: TLandrixEInvoiceListIndex;
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
        { the official examples are valid: no rule may report an error }
        D.Clear;
        LandrixEInvoiceCheckInvoice(A, Spec, D);
        for K := 0 to D.Count - 1 do
          if D[K].Severity = eds_Error then
            Findings.Add('check ' + string(D[K].RuleID));
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
        if Spec.Target.Standard = est_XRechnung then
        begin
          if Spec.Target.Syntax = esy_UBL then
            Other := esy_CII
          else
            Other := esy_UBL;
          if LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.XRechnung('3.0', Other), CrossSpec) then
          begin
            D.Clear;
            SaveFile(CrossDir + ACorpus + '_' + ChangeFileExt(AName, '') + ChangeFileExt(Suffix(Spec), '') + '-x' +
              Suffix(CrossSpec), WriteModel(A, CrossSpec, D));
            { content the other syntax lacks is the XR comparison's business; errors
              (missing required content) are findings here }
            for K := 0 to D.Count - 1 do
              if D[K].Severity = eds_Error then
                Findings.Add('cross ' + string(LandrixEInvoiceDiagnosticKindToStr(D[K].Kind)) + ' ' +
                  string(D[K].Path));
          end;
        end;
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
  Check(ForceDirectories(OutDir) and ForceDirectories(SourceDir) and ForceDirectories(CrossDir),
    'sweep output folders');
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

{ --- namespace prefixes --------------------------------------------------- }

const
  XmlNamespace = 'http://www.w3.org/XML/1998/namespace';

type
  { Writes a document again with other prefixes: 'n0', 'n1' ... per
    namespace in the order of appearance, or (ADefault) the namespace of
    the root element as default namespace. Comments and processing
    instructions are left out. }
  TReprefixer = class(TObject)
  private
    FUris: array of TLandrixXmlUtf8;
    FRootUri: TLandrixXmlUtf8;
    FDefault: Boolean;
    function PrefixOf(const AUri: TLandrixXmlUtf8; AForAttribute: Boolean): TLandrixXmlUtf8;
  public
    function Run(const AXml: TLandrixXmlUtf8; ADefault: Boolean): TLandrixXmlUtf8;
  end;

function TReprefixer.PrefixOf(const AUri: TLandrixXmlUtf8; AForAttribute: Boolean): TLandrixXmlUtf8;
var
  I: Integer;
begin
  Result := '';
  if AUri = '' then
    Exit;
  if AUri = XmlNamespace then
  begin
    Result := 'xml';
    Exit;
  end;
  if FDefault and not AForAttribute and (AUri = FRootUri) then
    Exit;
  for I := 0 to Integer(Length(FUris)) - 1 do
    if FUris[I] = AUri then
    begin
      Result := LandrixEInvoiceStringToUtf8(TLandrixEInvoiceString('n' + IntToStr(I)));
      Exit;
    end;
  I := Integer(Length(FUris));
  SetLength(FUris, I + 1);
  FUris[I] := AUri;
  Result := LandrixEInvoiceStringToUtf8(TLandrixEInvoiceString('n' + IntToStr(I)));
end;

function TReprefixer.Run(const AXml: TLandrixXmlUtf8; ADefault: Boolean): TLandrixXmlUtf8;
var
  R: TLandrixXmlReader;
  W: TLandrixXmlWriter;
  I: Integer;
  Uri: TLandrixXmlUtf8;
begin
  SetLength(FUris, 0);
  FDefault := ADefault;
  FRootUri := '';
  R := TLandrixXmlReader.Create;
  W := TLandrixXmlWriter.Create;
  try
    R.LoadFromUtf8(AXml);
    while R.Read do
      case R.TokenType of
        xttStartElement:
          begin
            Uri := R.NamespaceUriUtf8;
            if R.Depth = 0 then
              FRootUri := Uri;
            W.StartElementNs(Uri, PrefixOf(Uri, False), R.LocalNameUtf8);
            for I := 0 to R.AttributeCount - 1 do
              if not R.IsNamespaceDeclaration(I) then
              begin
                Uri := R.AttributeNamespaceUriUtf8(I);
                if Uri = '' then
                  W.AttributeUtf8(R.AttributeLocalNameUtf8(I), R.AttributeValueUtf8(I))
                else
                  W.AttributeNsUtf8(Uri, PrefixOf(Uri, True), R.AttributeLocalNameUtf8(I), R.AttributeValueUtf8(I));
              end;
          end;
        xttEndElement:
          W.EndElement;
        xttText:
          W.TextUtf8(R.ValueUtf8);
        xttCData:
          W.CDataUtf8(R.ValueUtf8);
      else
        ;
      end;
    W.EndDocument;
    Result := W.AsUtf8;
  finally
    W.Free;
    R.Free;
  end;
end;

function VersionOfXml(const AXml: TLandrixXmlUtf8): TXRechnungVersion;
var
  S: TMemoryStream;
begin
  S := TMemoryStream.Create;
  try
    if AXml <> '' then
      S.WriteBuffer(PAnsiChar(AXml)^, Length(AXml));
    S.Position := 0;
    Result := TXRechnungValidationHelper.GetXRechnungVersion(S);
  finally
    S.Free;
  end;
end;

{ One file with other prefixes: the same specification and version are
  detected and the same invoice is read. }
procedure PrefixFile(const AKey: string; const AXml: TLandrixXmlUtf8; AFindings: TStrings);
var
  Rewriter: TReprefixer;
  Xml: TLandrixXmlUtf8;
  A, B: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec, Again: TLandrixEInvoiceSpec;
  Ext, Ext2: Boolean;
  Diffs: TStringList;
  Mode, I: Integer;
  ID, ID2: TLandrixEInvoiceString;
  Detected: Boolean;
  Kinds: array[TLandrixEInvoiceDiagnosticKind] of Integer;
  K: TLandrixEInvoiceDiagnosticKind;
begin
  Rewriter := TReprefixer.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  A := TLandrixInvoice.Create;
  B := TLandrixInvoice.Create;
  Diffs := TStringList.Create;
  try
    ID := ReadModel(AXml, RootLocalName(AXml), A, D);
    Detected := LandrixEInvoiceDetectSpec(TLandrixEInvoiceString(RootLocalName(AXml)), ID, Spec, Ext);
    for K := Low(TLandrixEInvoiceDiagnosticKind) to High(TLandrixEInvoiceDiagnosticKind) do
      Kinds[K] := D.CountOf(K);
    for Mode := 0 to 1 do
    begin
      Xml := Rewriter.Run(AXml, Mode = 1);
      if Pos('<n0:', LandrixXmlUtf8ToString(Xml)) + Pos(' xmlns=', LandrixXmlUtf8ToString(Xml)) = 0 then
        AFindings.Add(AKey + ' mode ' + IntToStr(Mode) + ': prefixes not changed');
      B.Clear;
      D.Clear;
      ID2 := ReadModel(Xml, RootLocalName(Xml), B, D);
      if ID2 <> ID then
        AFindings.Add(AKey + ' mode ' + IntToStr(Mode) + ': specification identifier ' + string(ID2));
      for K := Low(TLandrixEInvoiceDiagnosticKind) to High(TLandrixEInvoiceDiagnosticKind) do
        if D.CountOf(K) <> Kinds[K] then
          AFindings.Add(AKey + ' mode ' + IntToStr(Mode) + ': diagnostics ' +
            string(LandrixEInvoiceDiagnosticKindToStr(K)) + ' ' + IntToStr(D.CountOf(K)) + ' instead of ' +
            IntToStr(Kinds[K]));
      if Detected <> LandrixEInvoiceDetectSpec(TLandrixEInvoiceString(RootLocalName(Xml)), ID2, Again, Ext2) then
        AFindings.Add(AKey + ' mode ' + IntToStr(Mode) + ': detection differs')
      else if Detected and (not LandrixEInvoiceSameTarget(Again.Target, Spec.Target) or (Ext2 <> Ext)) then
        AFindings.Add(AKey + ' mode ' + IntToStr(Mode) + ': other target or extension');
      if VersionOfXml(Xml) <> VersionOfXml(AXml) then
        AFindings.Add(AKey + ' mode ' + IntToStr(Mode) + ': compatibility version differs');
      Diffs.Clear;
      CompareInvoices(A, B, Diffs);
      for I := 0 to Diffs.Count - 1 do
        AFindings.Add(AKey + ' mode ' + IntToStr(Mode) + ': compare ' + Diffs[I]);
    end;
  finally
    Diffs.Free;
    B.Free;
    A.Free;
    D.Free;
    Rewriter.Free;
  end;
end;

{ Namespace prefixes are free (XRechnung-for-Delphi #92): every official
  example and golden file is read again with prefixes n0, n1 ... and with
  the root namespace as default namespace. Other root elements of the UBL
  family are no invoice. }
procedure TestPrefixes;
var
  Dirs: array[0..3] of string;
  Findings: TStringList;
  SR: TSearchRec;
  K, Files: Integer;
  Spec: TLandrixEInvoiceSpec;
  Ext: Boolean;
begin
  Dirs[0] := LocalSweepDir + Corpora[0] + PathDelim;
  Dirs[1] := LocalSweepDir + Corpora[1] + PathDelim;
  Dirs[2] := LocalSweepDir + Corpora[2] + PathDelim;
  Dirs[3] := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'golden' + PathDelim;
  Findings := TStringList.Create;
  try
    Files := 0;
    for K := Low(Dirs) to High(Dirs) do
      if FindFirst(Dirs[K] + '*.xml', faAnyFile, SR) = 0 then
      begin
        repeat
          Inc(Files);
          try
            PrefixFile(ExtractFileName(ExcludeTrailingPathDelimiter(Dirs[K])) + '/' + SR.Name,
              LoadFile(Dirs[K] + SR.Name), Findings);
          except
            on E: Exception do
              Findings.Add(ExtractFileName(ExcludeTrailingPathDelimiter(Dirs[K])) + '/' + SR.Name + ': ' +
                E.ClassName + ': ' + E.Message);
          end;
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;
    for K := 0 to Findings.Count - 1 do
      WriteLn('  ', Findings[K]);
    if Files = 0 then
      Skip('no local sweep corpora or golden files')
    else
      CheckEquals(0, Findings.Count, IntToStr(Files) + ' files with other prefixes');
    Check(not LandrixEInvoiceDetectSpec('SelfBilledInvoice',
      'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0', Spec, Ext),
      'SelfBilledInvoice is no invoice');
    Check(VersionOfXml('<n0:SelfBilledInvoice xmlns:n0="urn:oasis:names:specification:ubl:schema:xsd:' +
      'SelfBilledInvoice-2"><n1:CustomizationID xmlns:n1="urn:oasis:names:specification:ubl:schema:xsd:' +
      'CommonBasicComponents-2">urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0' +
      '</n1:CustomizationID></n0:SelfBilledInvoice>') = XRechnungVersion_Unknown,
      'SelfBilledInvoice: no version');
    Check(VersionOfXml('<InvoiceResponse xmlns="urn:oasis:names:specification:ubl:schema:xsd:' +
      'ApplicationResponse-2"/>') = XRechnungVersion_Unknown, 'InvoiceResponse: no version');
  finally
    Findings.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Sweep.Official', TestSweep);
  RegisterTest('Sweep.Prefixes', TestPrefixes);
end;

end.
