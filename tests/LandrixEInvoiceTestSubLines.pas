{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of LandrixEInvoiceSubLines: which targets write sub lines nested,
  and the flat copy for the others (nested groups, INFORMATION lines,
  explicit GROUP and DETAIL lines, the credit note, the reports, the
  original left unchanged). }

unit LandrixEInvoiceTestSubLines;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceSubLines,
  LandrixEInvoiceTestFramework;

function SpecOf(const ATarget: TLandrixEInvoiceTarget): TLandrixEInvoiceSpec;
begin
  Check(LandrixEInvoiceFindSpec(ATarget, Result), 'spec ' + string(LandrixEInvoiceTargetToStr(ATarget)));
end;

function AddLine(ALines: TLandrixInvoiceLines; const AID: TLandrixEInvoiceString;
  AAmount: Currency): TLandrixInvoiceLine;
begin
  Result := ALines.AddInvoiceLine;
  Result.ID := AID;
  Result.LineAmount := AAmount;
end;

{ the IDs of the top-level lines, separated by blanks }
function LineIDs(AInvoice: TLandrixInvoice): string;
var
  I: TLandrixEInvoiceListIndex;
begin
  Result := '';
  for I := 0 to AInvoice.InvoiceLines.Count - 1 do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + string(AInvoice.InvoiceLines[I].ID);
  end;
end;

{ 1 (plain), 2 (group: 2.1, 2.2 group: 2.2.1, 2.2.2, 2.3 INFORMATION), 3 }
procedure FillGroups(AInvoice: TLandrixInvoice);
var
  Group, Inner: TLandrixInvoiceLine;
begin
  AddLine(AInvoice.InvoiceLines, '1', 10);
  Group := AddLine(AInvoice.InvoiceLines, '2', 60);
  AddLine(Group.SubInvoiceLines, '2.1', 20);
  Inner := AddLine(Group.SubInvoiceLines, '2.2', 40);
  AddLine(Inner.SubInvoiceLines, '2.2.1', 15);
  AddLine(Inner.SubInvoiceLines, '2.2.2', 25).LineStatusReasonCode := ilsrc_Detail;
  AddLine(Group.SubInvoiceLines, '2.3', 0).LineStatusReasonCode := ilsrc_Information;
  AddLine(AInvoice.InvoiceLines, '3', 5);
end;

procedure TestNested;
var
  Invoice: TLandrixInvoice;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Check(LandrixEInvoiceSubLinesNested(Invoice, SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL))),
      'XRechnung UBL');
    Check(LandrixEInvoiceSubLinesNested(Invoice, SpecOf(TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended))),
      'ZUGFeRD EXTENDED');
    Check(not LandrixEInvoiceSubLinesNested(Invoice, SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII))),
      'XRechnung CII');
    Check(not LandrixEInvoiceSubLinesNested(Invoice, SpecOf(TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_EN16931))),
      'ZUGFeRD EN16931');
    Check(not LandrixEInvoiceSubLinesNested(Invoice, SpecOf(TLandrixEInvoiceTargets.PeppolBIS('3.0'))),
      'Peppol (discouraged)');
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Check(not LandrixEInvoiceSubLinesNested(Invoice, SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL))),
      'XRechnung UBL credit note');
    Check(LandrixEInvoiceSubLinesNested(Invoice, SpecOf(TLandrixEInvoiceTargets.ZUGFeRD('2.5', epr_Extended))),
      'ZUGFeRD EXTENDED credit note');
  finally
    Invoice.Free;
  end;
end;

procedure TestFlatten;
var
  Invoice, Flat: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  I: TLandrixEInvoiceListIndex;
  Sum: Currency;
begin
  Invoice := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    FillGroups(Invoice);
    Check(LandrixEInvoiceFlattenSubLines(Invoice, SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)), D) = nil,
      'nested target: no copy');
    Flat := LandrixEInvoiceFlattenSubLines(Invoice, SpecOf(TLandrixEInvoiceTargets.PeppolBIS('3.0')), D);
    try
      Check(Flat <> nil, 'Peppol: a copy');
      CheckEqualsStr('1 2.1 2.2.1 2.2.2 3', LineIDs(Flat), 'lines, depth-first');
      Sum := 0;
      for I := 0 to Flat.InvoiceLines.Count - 1 do
      begin
        Check(Flat.InvoiceLines[I].SubInvoiceLines.Count = 0, 'no sub lines left');
        Check(Flat.InvoiceLines[I].LineStatusReasonCode = ilsrc_None, 'status cleared');
        Sum := Sum + Flat.InvoiceLines[I].LineAmount;
      end;
      Check(Sum = 75, 'BT-106 unchanged (10 + 60 + 5)');
      { one report for the group, one for the INFORMATION line }
      CheckEquals(2, D.CountOf(edk_NotAllowed), 'reports');
      Check(not D.HasErrors, 'warnings only');
      Check(Pos('2.1 2.2.1 2.2.2', string(D[D.Count - 1].Message)) > 0, 'group report names the lines');
      CheckEqualsStr('/Invoice/cac:InvoiceLine', string(D[0].Path), 'UBL path');
    finally
      Flat.Free;
    end;
    { the original is unchanged }
    CheckEqualsStr('1 2 3', LineIDs(Invoice), 'original lines');
    CheckEquals(3, Integer(Invoice.InvoiceLines[1].SubInvoiceLines.Count), 'original sub lines');
    Check(Invoice.InvoiceLines[1].SubInvoiceLines[1].SubInvoiceLines[1].LineStatusReasonCode = ilsrc_Detail,
      'original status');
    { a flat copy needs no second flattening }
    Flat := LandrixEInvoiceFlattenSubLines(Invoice, SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)), nil);
    try
      Check(LandrixEInvoiceFlattenSubLines(Flat, SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)), nil) = nil,
        'idempotent');
    finally
      Flat.Free;
    end;
  finally
    D.Free;
    Invoice.Free;
  end;
end;

{ explicit statuses: a GROUP without sub lines is an ordinary line, a
  DETAIL line keeps its place and loses its sub lines; the credit note in
  UBL is flat everywhere }
procedure TestStatuses;
var
  Invoice, Flat: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Line: TLandrixInvoiceLine;
begin
  Invoice := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    Line := AddLine(Invoice.InvoiceLines, '1', 10);
    Line.LineStatusReasonCode := ilsrc_Detail;
    AddLine(Line.SubInvoiceLines, '1.1', 10);
    Line := AddLine(Invoice.InvoiceLines, '2', 7);
    AddLine(Line.SubInvoiceLines, '2.1', 7).LineStatusReasonCode := ilsrc_Group;
    Flat := LandrixEInvoiceFlattenSubLines(Invoice, SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_CII)), D);
    try
      CheckEqualsStr('1 2.1', LineIDs(Flat), 'DETAIL kept, empty GROUP as a line');
      CheckEquals(0, Integer(Flat.InvoiceLines[0].SubInvoiceLines.Count), 'DETAIL without its sub lines');
      Check(Flat.InvoiceLines[0].LineStatusReasonCode = ilsrc_Detail, 'top-level status kept');
      Check(Flat.InvoiceLines[1].LineStatusReasonCode = ilsrc_None, 'group status cleared');
      CheckEquals(2, D.CountOf(edk_NotAllowed), 'reports');
      CheckEqualsStr('/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem',
        string(D[0].Path), 'CII path');
    finally
      Flat.Free;
    end;
    D.Clear;
    Invoice.InvoiceTypeCode := itc_CreditNote;
    Invoice.InvoiceLines[0].LineStatusReasonCode := ilsrc_None;
    Flat := LandrixEInvoiceFlattenSubLines(Invoice, SpecOf(TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL)), D);
    try
      CheckEqualsStr('1.1 2.1', LineIDs(Flat), 'credit note flat');
      CheckEqualsStr('/CreditNote/cac:CreditNoteLine', string(D[0].Path), 'credit note path');
    finally
      Flat.Free;
    end;
  finally
    D.Free;
    Invoice.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('SubLines.Nested', TestNested);
  RegisterTest('SubLines.Flatten', TestFlatten);
  RegisterTest('SubLines.Statuses', TestStatuses);
end;

end.
