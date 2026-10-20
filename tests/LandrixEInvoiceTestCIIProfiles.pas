{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for the Factur-X profiles of the CII paths (generated
  LandrixEInvoiceCIIProfiles): lookup, pruning, the profile-aware writer,
  the mapping to MINIMUM, BASIC WL and BASIC, and the local example files,
  each of which must keep everything when pruned to its own profile (skipped
  when tests/data/local/cii does not exist). CIIProfiles.WriteScenarios
  writes every EN16931 scenario also as MINIMUM, BASIC WL and BASIC to
  <program folder>/profiles/ for the KoSIT validation (tools/build.ps1
  -Validate). }

unit LandrixEInvoiceTestCIIProfiles;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
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
  LandrixEInvoiceCIIProfiles,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestScenarios,
  LandrixEInvoiceTestMapCII;

const
  Doc = '/rsm:CrossIndustryInvoice/rsm:ExchangedDocument';
  Transaction = '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction';
  LineItem = Transaction + '/ram:IncludedSupplyChainTradeLineItem';
  Summation = Transaction + '/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation';
  KnownInvalidMinimum = 'zfd-demodata_zugferd21_zugferd_2p1_MINIMUM_Rechnung-factur-x.xml';

function CountKind(D: TLandrixEInvoiceDiagnostics; AKind: TLandrixEInvoiceDiagnosticKind;
  const APath: string): Integer;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := 0 to D.Count - 1 do
    if (D[I].Kind = AKind) and (string(D[I].Path) = APath) then
      Inc(Result);
end;

function ProfileReports(D: TLandrixEInvoiceDiagnostics): Integer;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := 0;
  for I := 0 to D.Count - 1 do
    if Pos('not in Factur-X profile', string(D[I].Message)) > 0 then
      Inc(Result);
end;

function WriteCII(ACII: TLandrixCIIInvoice; D: TLandrixEInvoiceDiagnostics;
  AProfile: TLandrixEInvoiceProfile): string;
var
  W: TLandrixXmlWriter;
begin
  W := TLandrixXmlWriter.Create;
  try
    LandrixEInvoiceWriteCII(ACII, W, D, AProfile);
    W.EndDocument;
    Result := LandrixXmlUtf8ToString(W.AsUtf8);
  finally
    W.Free;
  end;
end;

procedure TestLookup;
begin
  Check(LandrixEInvoiceCIIMinProfile(Doc + '/ram:ID') = epr_Minimum, 'BT-1 in MINIMUM');
  Check(LandrixEInvoiceCIIMinProfile(Doc + '/ram:IncludedNote') = epr_BasicWL, 'BG-1 from BASIC WL');
  Check(LandrixEInvoiceCIIMinProfile(LineItem) = epr_Basic, 'BG-25 from BASIC');
  Check(LandrixEInvoiceCIIMinProfile(Doc + '/ram:Name') = epr_Extended, 'BT-X-2 in EXTENDED');
  Check(LandrixEInvoiceCIIMinProfile(Doc + '/ram:Unknown') = epr_None, 'unknown path');
  Check(LandrixEInvoiceCIIMinProfile(Doc + '/ram:ID/@schemeID') = epr_None, 'no scheme on BT-1');
  Check(LandrixEInvoiceCIIAllowed(LineItem, epr_Basic), 'lines in BASIC');
  Check(not LandrixEInvoiceCIIAllowed(LineItem, epr_BasicWL), 'no lines in BASIC WL');
  Check(not LandrixEInvoiceCIIAllowed(Doc + '/ram:Unknown', epr_EN16931), 'unknown path not in EN16931');
  Check(LandrixEInvoiceCIIAllowed(Doc + '/ram:Unknown', epr_Extended), 'EXTENDED: the schema decides');
  Check(LandrixEInvoiceCIIAllowed(Doc + '/ram:Name', epr_None), 'no profile: the schema decides');
  Check(LandrixEInvoiceCIIRequired(Doc + '/ram:ID', epr_Minimum), 'BT-1 required');
  Check(LandrixEInvoiceCIIRequired(Summation + '/ram:DuePayableAmount', epr_Minimum), 'BT-115 required');
  Check(not LandrixEInvoiceCIIRequired(Transaction +
    '/ram:ApplicableHeaderTradeAgreement/ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID', epr_Minimum),
    'BT-13 is 1..1 below an optional group, so not required');
  Check(not LandrixEInvoiceCIIRequired(LineItem, epr_Minimum), 'lines not required in MINIMUM');
  Check(LandrixEInvoiceCIIRequired(LineItem, epr_Basic), 'lines required in BASIC');
  Check(not LandrixEInvoiceCIIRequired(Doc + '/ram:ID', epr_XRechnung), 'no Factur-X profile');
end;

procedure FillModel(ACII: TLandrixCIIInvoice);
begin
  ACII.ExchangedDocument.ID.Value := 'R-1';
  ACII.ExchangedDocument.ID.SchemeID := 'X';
  ACII.ExchangedDocument.Name := 'RECHNUNG';
  ACII.ExchangedDocument.IncludedNote.Add.Content := 'a';
  ACII.ExchangedDocument.IncludedNote.Add.Content := 'b';
  ACII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem.Add.AssociatedDocumentLineDocument.LineID.Value := '1';
  ACII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem.Add.AssociatedDocumentLineDocument.LineID.Value := '2';
  ACII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.SellerTradeParty.Name := 'Seller';
end;

{ Pruning removes at the highest element that is not allowed, reports each
  path once with its count, and leaves allowed content alone. }
procedure TestPrune;
var
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  CII := TLandrixCIIInvoice.Create;
  try
    FillModel(CII);
    CheckEquals(6, LandrixEInvoicePruneCII(CII, epr_Minimum, D), 'removed: scheme, name, 2 notes, 2 lines');
    CheckEquals(4, Integer(D.Count), 'one report per path: ' + string(D.ToText));
    CheckEquals(1, CountKind(D, edk_NotAllowed, LineItem), 'lines reported once');
    Check(Pos('2 occurrence(s)', string(D[2].Message) + string(D[3].Message)) > 0, 'count in the message');
    Check(D[0].Severity = eds_Warning, 'warning');
    CheckEquals(0, Integer(CII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem.Count), 'lines removed');
    CheckEquals(0, Integer(CII.ExchangedDocument.IncludedNote.Count), 'notes removed');
    CheckEqualsInvoiceStr('', CII.ExchangedDocument.Name, 'name removed');
    CheckEqualsInvoiceStr('', CII.ExchangedDocument.ID.SchemeID, 'scheme removed');
    CheckEqualsInvoiceStr('R-1', CII.ExchangedDocument.ID.Value, 'BT-1 kept');
    CheckEqualsInvoiceStr('Seller', CII.SupplyChainTradeTransaction.ApplicableHeaderTradeAgreement.SellerTradeParty.Name,
      'BT-27 kept');
    CII.Clear;
    D.Clear;
    FillModel(CII);
    CheckEquals(2, LandrixEInvoicePruneCII(CII, epr_Basic, D), 'BASIC removes scheme and name');
    CheckEquals(2, Integer(CII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem.Count), 'lines kept in BASIC');
    CheckEqualsInvoiceStr('1', CII.SupplyChainTradeTransaction.IncludedSupplyChainTradeLineItem[0].
      AssociatedDocumentLineDocument.LineID.Value, 'BT-126 kept');
    CII.Clear;
    D.Clear;
    FillModel(CII);
    CheckEquals(0, LandrixEInvoicePruneCII(CII, epr_Extended, D), 'EXTENDED: nothing');
    CheckEquals(0, LandrixEInvoicePruneCII(CII, epr_None, D), 'no profile: nothing');
    CheckEquals(0, Integer(D.Count), 'no reports');
    LandrixEInvoicePruneCII(CII, epr_EN16931, nil);
    CheckEqualsInvoiceStr('', CII.ExchangedDocument.Name, 'pruned without diagnostics');
  finally
    CII.Free;
    D.Free;
  end;
end;

{ The writer reports missing required content only if the profile contains
  it: no lines and no line total in MINIMUM. }
procedure TestWriterMissing;
var
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  CII := TLandrixCIIInvoice.Create;
  try
    WriteCII(CII, D, epr_Extended);
    CheckEquals(1, CountKind(D, edk_MissingElement, LineItem), 'EXTENDED schema: lines required');
    CheckEquals(1, CountKind(D, edk_MissingElement, Summation + '/ram:LineTotalAmount'), 'EXTENDED: line total');
    CheckEquals(1, CountKind(D, edk_MissingElement, Summation + '/ram:DuePayableAmount'), 'EXTENDED: amount due');
    D.Clear;
    WriteCII(CII, D, epr_Minimum);
    CheckEquals(0, CountKind(D, edk_MissingElement, LineItem), 'MINIMUM: no lines');
    CheckEquals(0, CountKind(D, edk_MissingElement, Summation + '/ram:LineTotalAmount'), 'MINIMUM: no line total');
    CheckEquals(1, CountKind(D, edk_MissingElement, Summation + '/ram:DuePayableAmount'), 'MINIMUM: amount due');
    D.Clear;
    WriteCII(CII, D, epr_BasicWL);
    CheckEquals(0, CountKind(D, edk_MissingElement, LineItem), 'BASIC WL: no lines');
    CheckEquals(1, CountKind(D, edk_MissingElement, Summation + '/ram:LineTotalAmount'), 'BASIC WL: line total');
  finally
    CII.Free;
    D.Free;
  end;
end;

{ The mapping to a reduced profile leaves out what the profile lacks, once
  per path, and writes without errors that the profile does not know. }
procedure TestMapping;
var
  Invoice, Back: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Xml: string;
  P: TLandrixEInvoiceProfile;
  R: TLandrixXmlReader;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  Back := TLandrixInvoice.Create;
  try
    FillPhase2(Invoice);
    { the postal addresses every profile requires }
    Invoice.AccountingSupplierParty.Address.CountryCode := 'DE';
    Invoice.AccountingCustomerParty.Address.CountryCode := 'DE';
    Line := Invoice.InvoiceLines.AddInvoiceLine;
    Line.ID := '2';
    Line.Name := 'Item 2';
    Line.UnitCode := Invoice.InvoiceLines[0].UnitCode;
    Line.TaxCategory := Invoice.InvoiceLines[0].TaxCategory;
    Line.TaxPercent := Invoice.InvoiceLines[0].TaxPercent;
    for P := epr_Minimum to epr_EN16931 do
    begin
      D.Clear;
      Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', P), Spec), 'spec');
      CII := LandrixEInvoiceInvoiceToCII(Invoice, Spec, D);
      try
        Xml := WriteCII(CII, D, P);
      finally
        CII.Free;
      end;
      Check(Pos(string(Spec.CustomizationID), Xml) > 0, string(Spec.CustomizationID) + ' written');
      if P < epr_Basic then
      begin
        CheckEquals(1, CountKind(D, edk_NotAllowed, LineItem), 'lines left out once');
        Check(Pos('2 occurrence(s)', string(D.ToText)) > 0, 'with the count');
        Check(Pos('IncludedSupplyChainTradeLineItem', Xml) = 0, 'no lines written');
      end
      else
        Check(Pos('IncludedSupplyChainTradeLineItem', Xml) > 0, 'lines written');
      if P = epr_EN16931 then
        CheckEquals(0, ProfileReports(D), 'EN16931: the rule table already left out everything: ' +
          string(D.ToText))
      else
        Check(ProfileReports(D) > 0, 'reduced profile reports');
      CheckEquals(0, D.CountOf(edk_MissingElement), 'no missing element the profile knows: ' + string(D.ToText));
      R := TLandrixXmlReader.Create;
      try
        R.LoadFromUtf8(LandrixXmlStringToUtf8(Xml));
        CII := LandrixEInvoiceReadCII(R, D);
        try
          LandrixEInvoiceCIIToInvoice(CII, Back, D);
        finally
          CII.Free;
        end;
      finally
        R.Free;
      end;
      CheckEqualsInvoiceStr('R-2', Back.InvoiceNumber, 'BT-1 read back');
    end;
  finally
    Back.Free;
    Invoice.Free;
    D.Free;
  end;
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

{ Every local example of a profile below EXTENDED keeps everything when
  pruned to its own profile: the table and the pruner agree with the
  official examples. The one example that is invalid against its own
  profile schema (Factur-X 1.09.2 MINIMUM XSD, checked with lxml) must lose
  exactly that: PostcodeCode, LineOne and CityName of the seller and the
  buyer address (BG-8 starts in BASIC WL). }
procedure TestLocalFiles;
var
  Dir: string;
  SR: TSearchRec;
  R: TLandrixXmlReader;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Ext: Boolean;
  Files, Checked, Failed: Integer;
  Removed: Integer;
  Invalid: Boolean;
begin
  Dir := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'cii' + PathDelim;
  if not DirectoryExists(Dir) then
  begin
    Skip('no local CII files in ' + Dir);
    Exit;
  end;
  Files := 0;
  Checked := 0;
  Failed := 0;
  if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
  try
    repeat
      Inc(Files);
      D := TLandrixEInvoiceDiagnostics.Create;
      R := TLandrixXmlReader.Create;
      try
        R.LoadFromUtf8(LoadFile(Dir + SR.Name));
        CII := LandrixEInvoiceReadCII(R, nil);
        try
          if LandrixEInvoiceDetectSpec('CrossIndustryInvoice',
            CII.ExchangedDocumentContext.GuidelineSpecifiedDocumentContextParameter.ID.Value, Spec, Ext) and
            (Spec.Target.Standard = est_FacturX) and (Spec.Target.Profile in [epr_Minimum..epr_EN16931]) then
          begin
            Inc(Checked);
            Removed := LandrixEInvoicePruneCII(CII, Spec.Target.Profile, D);
            Invalid := SR.Name = KnownInvalidMinimum;
            if Invalid then
              CheckEquals(4, Removed, SR.Name + ' loses the address beyond the country')
            else if Removed > 0 then
            begin
              Inc(Failed);
              WriteLn('  ', SR.Name, ' (', string(LandrixEInvoiceTargetToStr(Spec.Target)), '): ', string(D.ToText));
            end;
          end;
        finally
          CII.Free;
        end;
      finally
        R.Free;
        D.Free;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  Check(Checked > 0, 'local files of a reduced profile found');
  CheckEquals(0, Failed, IntToStr(Checked) + ' of ' + IntToStr(Files) + ' files checked, files that lose content');
end;

function ProfilesOutDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'profiles' + PathDelim;
end;

type
  PProfileRun = ^TProfileRun;
  TProfileRun = record
    Files: Integer;
    Errors: string;
  end;

{ Writes an EN16931 scenario in the three reduced profiles; the file name
  part -ciiEN16931-25 becomes -ciiminimum-25, -ciibasicwl-25, -ciibasic-25. }
procedure ProfileSink(AInvoice: TLandrixInvoice; const ATarget: TLandrixEInvoiceTarget;
  const AFileName: string; AData: Pointer);
const
  Suffixes: array[epr_Minimum..epr_Basic] of string = ('-ciiminimum-25.xml', '-ciibasicwl-25.xml', '-ciibasic-25.xml');
  Marker = '-ciiEN16931-25.xml';
var
  Run: PProfileRun;
  P: TLandrixEInvoiceProfile;
  Spec: TLandrixEInvoiceSpec;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  W: TLandrixXmlWriter;
  S: TFileStream;
  Xml: TLandrixXmlUtf8;
  Base: string;
begin
  if (ATarget.Profile <> epr_EN16931) or (Pos(Marker, AFileName) = 0) then
    Exit;
  Run := PProfileRun(AData);
  Base := Copy(AFileName, 1, Pos(Marker, AFileName) - 1);
  for P := epr_Minimum to epr_Basic do
  begin
    Check(LandrixEInvoiceFindSpec(TLandrixEInvoiceTargets.FacturX('1.09', P), Spec), 'spec');
    D := TLandrixEInvoiceDiagnostics.Create;
    W := TLandrixXmlWriter.Create;
    try
      W.Indent := True;
      CII := LandrixEInvoiceInvoiceToCII(AInvoice, Spec, D);
      try
        LandrixEInvoiceWriteCII(CII, W, D, P);
      finally
        CII.Free;
      end;
      W.EndDocument;
      Xml := W.AsUtf8;
      S := TFileStream.Create(ProfilesOutDir + Base + Suffixes[P], fmCreate);
      try
        if Length(Xml) > 0 then
          S.WriteBuffer(PAnsiChar(Xml)^, Length(Xml));
      finally
        S.Free;
      end;
      if D.HasErrors then
        Run^.Errors := Run^.Errors + '  ' + Base + Suffixes[P] + ': ' + string(D.ToText) + #13#10;
      Inc(Run^.Files);
    finally
      W.Free;
      D.Free;
    end;
  end;
end;

{ Every EN16931 scenario written as MINIMUM, BASIC WL and BASIC without
  errors; tools/build.ps1 -Validate checks the files with the KoSIT
  validator. }
procedure TestWriteScenarios;
var
  Run: TProfileRun;
  Dir: string;
begin
  Dir := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'attachments' + PathDelim;
  if not DirectoryExists(Dir) then
  begin
    Skip('no local attachments');
    Exit;
  end;
  Check(ForceDirectories(ProfilesOutDir), 'profiles folder');
  Run.Files := 0;
  Run.Errors := '';
  RunAllScenarios(ProfileSink, @Run, Dir);
  CheckEquals(3 * 22, Run.Files, 'profile outputs');
  Check(Run.Errors = '', 'no errors:' + #13#10 + Run.Errors);
end;

procedure Register;
begin
  RegisterTest('CIIProfiles.Lookup', TestLookup);
  RegisterTest('CIIProfiles.Prune', TestPrune);
  RegisterTest('CIIProfiles.WriterMissing', TestWriterMissing);
  RegisterTest('CIIProfiles.Mapping', TestMapping);
  RegisterTest('CIIProfiles.LocalFiles', TestLocalFiles);
  RegisterTest('CIIProfiles.WriteScenarios', TestWriteScenarios);
end;

end.
