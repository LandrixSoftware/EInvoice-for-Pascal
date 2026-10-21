{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of TLandrixEInvoice.CalculateLineAmounts and CalculateTotals:
  rounding, groups, the VAT breakdown, atomic failure, idempotence, and an
  oracle over the sweep corpora (tests/data/local/sweep): every invoice is
  recalculated and compared with the amounts it carries; deviations are
  listed with reasons in tests/data/calc-exceptions.txt. }

unit LandrixEInvoiceTestCalculate;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceCodes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoice,
  LandrixEInvoiceTestFramework,
  LandrixEInvoiceTestCheck;

function Cur(AScaled: Int64): Currency;
begin
  PInt64(@Result)^ := AScaled;
end;

function Cents(ACents: Int64): Currency;
begin
  Result := Cur(ACents * 100);
end;

function Quot(A, B: Integer): Double;
begin
  Result := A;
  Result := Result / B;
end;

procedure CheckAmount(AExpected, AActual: Currency; const AWhat: string);
begin
  Check(AExpected = AActual, AWhat + ': expected ' + CurrToStr(AExpected) + ', got ' + CurrToStr(AActual));
end;

function AddLine(Invoice: TLandrixInvoice; const AID: TLandrixEInvoiceString; AQuantity, APrice: Double;
  ACategory: TLandrixInvoiceDutyTaxFeeCategoryCode; ARate: Double): TLandrixInvoiceLine;
begin
  Result := Invoice.InvoiceLines.AddInvoiceLine;
  Result.ID := AID;
  Result.Name := 'Item';
  Result.Quantity := AQuantity;
  Result.UnitCode := iuc_piece;
  Result.NetPriceAmount := APrice;
  Result.TaxCategory := ACategory;
  Result.TaxPercent := ARate;
end;

{ Half away from zero, the base quantity, line allowances and charges. }
procedure TestLineAmounts;
var
  Invoice: TLandrixInvoice;
  Line: TLandrixInvoiceLine;
  Item: TLandrixInvoiceAllowanceCharge;
begin
  Invoice := TLandrixInvoice.Create;
  try
    AddLine(Invoice, '1', 3, Quot(285, 1000), idtfcc_S_StandardRate, 19);        { 0.855 -> 0.86 }
    AddLine(Invoice, '2', -3, Quot(285, 1000), idtfcc_S_StandardRate, 19);       { -0.855 -> -0.86 }
    Line := AddLine(Invoice, '3', 10, 5, idtfcc_S_StandardRate, 19);
    Line.BaseQuantity := 100;                                                    { 0.50 }
    Line := AddLine(Invoice, '4', 2, 50, idtfcc_S_StandardRate, 19);
    Item := Line.AllowanceCharges.AddAllowanceCharge;
    Item.ChargeIndicator := False;
    Item.Amount := 10;
    Item := Line.AllowanceCharges.AddAllowanceCharge;
    Item.ChargeIndicator := True;
    Item.Amount := Cents(250);                                                   { 100 - 10 + 2.50 }
    CheckEquals(0, TLandrixEInvoice.CalculateLineAmounts(Invoice), 'no errors');
    CheckAmount(Cents(86), Invoice.InvoiceLines[0].LineAmount, 'half away from zero');
    CheckAmount(Cents(-86), Invoice.InvoiceLines[1].LineAmount, 'negative half away from zero');
    CheckAmount(Cents(50), Invoice.InvoiceLines[2].LineAmount, 'base quantity');
    CheckAmount(Cents(9250), Invoice.InvoiceLines[3].LineAmount, 'allowance and charge');
    Invoice.InvoiceLines[2].BaseQuantity := -1;
    Invoice.InvoiceLines[0].LineAmount := 7;
    CheckEquals(1, TLandrixEInvoice.CalculateLineAmounts(Invoice), 'negative base quantity');
    CheckAmount(7, Invoice.InvoiceLines[0].LineAmount, 'unchanged on error');
  finally
    Invoice.Free;
  end;
end;

{ A group gets the sum of its DETAIL and GROUP sub lines; INFORMATION sub
  lines do not count. }
procedure TestGroups;
var
  Invoice: TLandrixInvoice;
  Group, Sub: TLandrixInvoiceLine;
begin
  Invoice := TLandrixInvoice.Create;
  try
    Group := AddLine(Invoice, '1', 1, 999, idtfcc_S_StandardRate, 19);
    Sub := Group.SubInvoiceLines.AddInvoiceLine;
    Sub.ID := '1.1';
    Sub.Quantity := 2;
    Sub.NetPriceAmount := 10;
    Sub.TaxCategory := idtfcc_S_StandardRate;
    Sub.TaxPercent := 19;
    Sub := Group.SubInvoiceLines.AddInvoiceLine;
    Sub.ID := '1.2';
    Sub.Quantity := 1;
    Sub.NetPriceAmount := 5;
    Sub.TaxCategory := idtfcc_S_StandardRate;
    Sub.TaxPercent := 19;
    Sub := Group.SubInvoiceLines.AddInvoiceLine;
    Sub.ID := '1.3';
    Sub.Quantity := 1;
    Sub.NetPriceAmount := 1000;
    Sub.LineStatusReasonCode := ilsrc_Information;
    Sub.TaxCategory := idtfcc_S_StandardRate;
    Sub.TaxPercent := 19;
    CheckEquals(0, TLandrixEInvoice.CalculateLineAmounts(Invoice), 'no errors');
    CheckAmount(25, Group.LineAmount, 'group = 20 + 5');
    CheckAmount(1000, Group.SubInvoiceLines[2].LineAmount, 'information line has its amount');
    CheckEquals(0, TLandrixEInvoice.CalculateTotals(Invoice), 'totals');
    CheckAmount(25, Invoice.LineAmount, 'BT-106 from the group');
    { a GROUP line without VAT data takes that of its sub lines }
    Group.TaxCategory := idtfcc_None;
    Group.TaxPercent := 0;
    CheckEquals(0, TLandrixEInvoice.CalculateTotals(Invoice), 'group without VAT category');
    Check(Invoice.TaxAmountSubtotals[0].TaxCategory = idtfcc_S_StandardRate, 'category of the sub lines');
    CheckAmount(Cents(475), Invoice.TaxAmountSubtotals[0].TaxAmount, '19 % of 25');
    Group.SubInvoiceLines[1].TaxCategory := idtfcc_Z_ZeroRatedGoods;
    Group.SubInvoiceLines[1].TaxPercent := 0;
    Invoice.LineAmount := 1;
    CheckEquals(1, TLandrixEInvoice.CalculateTotals(Invoice), 'mixed categories below a group');
    CheckAmount(1, Invoice.LineAmount, 'unchanged on error');
    Group.LineStatusReasonCode := ilsrc_Detail;
    CheckEquals(1, TLandrixEInvoice.CalculateLineAmounts(Invoice), 'DETAIL with sub lines');
  finally
    Invoice.Free;
  end;
end;

{ BG-23 by category and rate, tax per group, document allowances and
  charges, existing breakdowns, BG-22 with prepaid, rounding and third-party
  payments; a second call changes nothing. }
procedure TestTotals;
var
  Invoice: TLandrixInvoice;
  Item: TLandrixInvoiceAllowanceCharge;
  Tax: TLandrixInvoiceTaxAmount;
  D: TLandrixEInvoiceDiagnostics;
  Text: string;
begin
  Invoice := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    AddLine(Invoice, '1', 1, Quot(3333, 100), idtfcc_S_StandardRate, 19);
    AddLine(Invoice, '2', 1, Quot(3333, 100), idtfcc_S_StandardRate, 19);
    AddLine(Invoice, '3', 1, 10, idtfcc_S_StandardRate, 7);
    AddLine(Invoice, '4', 1, 20, idtfcc_E_ExemptFromTax, 0);
    Item := Invoice.AllowanceCharges.AddAllowanceCharge;
    Item.ChargeIndicator := False;
    Item.Amount := Cents(666);
    Item.TaxCategory := idtfcc_S_StandardRate;
    Item.TaxPercent := 19;
    Item.Reason := 'Discount';
    Item := Invoice.AllowanceCharges.AddAllowanceCharge;
    Item.ChargeIndicator := True;
    Item.Amount := 5;
    Item.TaxCategory := idtfcc_S_StandardRate;
    Item.TaxPercent := 7;
    Item.Reason := 'Freight';
    { an existing E breakdown with a reason and an unused one }
    Tax := Invoice.TaxAmountSubtotals.AddTaxAmount;
    Tax.TaxCategory := idtfcc_E_ExemptFromTax;
    Tax.TaxExemptionReason := 'Exempt';
    Tax := Invoice.TaxAmountSubtotals.AddTaxAmount;
    Tax.TaxCategory := idtfcc_Z_ZeroRatedGoods;
    Invoice.PrepaidAmount := 10;
    Invoice.PayableRoundingAmount := Cents(-1);
    CheckEquals(0, TLandrixEInvoice.CalculateLineAmounts(Invoice), 'lines');
    CheckEquals(0, TLandrixEInvoice.CalculateTotals(Invoice, D), 'totals: ' + string(D.ToText));
    CheckEquals(3, Integer(Invoice.TaxAmountSubtotals.Count), 'E kept, Z removed, S 19 and S 7 added');
    Text := string(D.ToText);
    Check(Pos('removed', Text) > 0, 'removal reported: ' + Text);
    Tax := Invoice.TaxAmountSubtotals[0];
    Check(Tax.TaxCategory = idtfcc_E_ExemptFromTax, 'E first (existing order)');
    CheckEqualsInvoiceStr('Exempt', Tax.TaxExemptionReason, 'reason kept');
    CheckAmount(20, Tax.TaxableAmount, 'E taxable');
    CheckAmount(0, Tax.TaxAmount, 'E tax');
    Tax := Invoice.TaxAmountSubtotals[1];
    CheckAmount(Cents(6000), Tax.TaxableAmount, 'S 19: 66.66 - 6.66');
    CheckAmount(Cents(1140), Tax.TaxAmount, 'S 19: tax on the group');
    Tax := Invoice.TaxAmountSubtotals[2];
    CheckAmount(15, Tax.TaxableAmount, 'S 7: 10 + 5');
    CheckAmount(Cents(105), Tax.TaxAmount, 'S 7: 1.05');
    CheckAmount(Cents(9666), Invoice.LineAmount, 'BT-106');
    CheckAmount(Cents(666), Invoice.AllowanceTotalAmount, 'BT-107');
    CheckAmount(5, Invoice.ChargeTotalAmount, 'BT-108');
    CheckAmount(95, Invoice.TaxExclusiveAmount, 'BT-109');
    CheckAmount(Cents(1245), Invoice.TaxAmountTotal, 'BT-110');
    CheckAmount(Cents(10745), Invoice.TaxInclusiveAmount, 'BT-112');
    CheckAmount(Cents(9744), Invoice.PayableAmount, 'BT-115 = 107.45 - 10 - 0.01');
    with Invoice.PrepaidPayments.AddPrepaidPayment do
      PaidAmount := Cur(55000);
    D.Clear;
    CheckEquals(0, TLandrixEInvoice.CalculateTotals(Invoice, D), 'again');
    CheckEquals(0, Integer(D.Count), 'nothing to report the second time: ' + string(D.ToText));
    CheckEquals(3, Integer(Invoice.TaxAmountSubtotals.Count), 'breakdowns stable');
    CheckAmount(Cents(10294), Invoice.PayableAmount, 'BT-115 with a third-party payment of 5.50');
    Invoice.InvoiceLines[3].TaxCategory := idtfcc_None;
    CheckEquals(1, TLandrixEInvoice.CalculateTotals(Invoice), 'line without category');
  finally
    D.Free;
    Invoice.Free;
  end;
end;

{ A complete invoice with zeroed amounts, recalculated, passes the check. }
procedure TestPassesCheck;
var
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  Invoice := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    FillComplete(Invoice);
    Invoice.InvoiceLines[0].Quantity := 3;
    Invoice.InvoiceLines[0].NetPriceAmount := Quot(1999, 100);
    Invoice.InvoiceLines[0].LineAmount := 0;
    Invoice.TaxAmountSubtotals.Clear;
    Invoice.LineAmount := 0;
    Invoice.PayableAmount := 0;
    CheckEquals(0, TLandrixEInvoice.CalculateLineAmounts(Invoice), 'lines');
    CheckEquals(0, TLandrixEInvoice.CalculateTotals(Invoice), 'totals');
    CheckEquals(0, TLandrixEInvoice.Check(Invoice, TLandrixEInvoiceTargets.XRechnung('3.0', esy_UBL), [], D),
      'XRechnung UBL: ' + string(D.ToText));
    CheckAmount(Cents(7136), Invoice.PayableAmount, 'BT-115 = 59.97 + 11.39');
  finally
    D.Free;
    Invoice.Free;
  end;
end;

{ --- oracle over the sweep corpora ------------------------------------------------ }

function CentsText(AValue: Currency): string;
begin
  Result := FormatFloat('0.00', AValue);
end;

procedure CompareAmount(const AWhat: string; AOriginal, ACalculated: Currency; AFindings: TStrings);
begin
  if CentsText(AOriginal) <> CentsText(ACalculated) then
    AFindings.Add(AWhat + ': ' + CentsText(AOriginal) + ' <> ' + CentsText(ACalculated));
end;

procedure CompareLines(AOriginal, ACalculated: TLandrixInvoiceLines; AFindings: TStrings);
var
  I: TLandrixEInvoiceListIndex;
begin
  for I := 0 to AOriginal.Count - 1 do
  begin
    CompareAmount('BT-131 line ' + string(AOriginal[I].ID), AOriginal[I].LineAmount, ACalculated[I].LineAmount,
      AFindings);
    CompareLines(AOriginal[I].SubInvoiceLines, ACalculated[I].SubInvoiceLines, AFindings);
  end;
end;

function FindTax(ATaxes: TLandrixInvoiceTaxAmounts; ATax: TLandrixInvoiceTaxAmount): TLandrixInvoiceTaxAmount;
var
  I: TLandrixEInvoiceListIndex;
begin
  for I := 0 to ATaxes.Count - 1 do
  begin
    Result := ATaxes[I];
    if (Result.TaxCategory = ATax.TaxCategory) and (Result.TaxCategoryOther = ATax.TaxCategoryOther) and
       (FormatFloat('0.####', Result.TaxPercent) = FormatFloat('0.####', ATax.TaxPercent)) then
      Exit;
  end;
  Result := nil;
end;

procedure CompareTotals(AOriginal, ACalculated: TLandrixInvoice; AFindings: TStrings);
var
  I: TLandrixEInvoiceListIndex;
  Tax, Other: TLandrixInvoiceTaxAmount;
  Name: string;
begin
  CompareAmount('BT-106', AOriginal.LineAmount, ACalculated.LineAmount, AFindings);
  CompareAmount('BT-107', AOriginal.AllowanceTotalAmount, ACalculated.AllowanceTotalAmount, AFindings);
  CompareAmount('BT-108', AOriginal.ChargeTotalAmount, ACalculated.ChargeTotalAmount, AFindings);
  CompareAmount('BT-109', AOriginal.TaxExclusiveAmount, ACalculated.TaxExclusiveAmount, AFindings);
  CompareAmount('BT-110', AOriginal.TaxAmountTotal, ACalculated.TaxAmountTotal, AFindings);
  CompareAmount('BT-112', AOriginal.TaxInclusiveAmount, ACalculated.TaxInclusiveAmount, AFindings);
  CompareAmount('BT-115', AOriginal.PayableAmount, ACalculated.PayableAmount, AFindings);
  if AOriginal.TaxAmountSubtotals.Count <> ACalculated.TaxAmountSubtotals.Count then
    AFindings.Add('BG-23 count: ' + IntToStr(Integer(AOriginal.TaxAmountSubtotals.Count)) + ' <> ' +
      IntToStr(Integer(ACalculated.TaxAmountSubtotals.Count)));
  for I := 0 to AOriginal.TaxAmountSubtotals.Count - 1 do
  begin
    Tax := AOriginal.TaxAmountSubtotals[I];
    Name := 'BG-23 ' + string(LandrixEInvoiceDutyTaxFeeCategoryCodeToStr(Tax.TaxCategory)) + ' ' +
      FormatFloat('0.##', Tax.TaxPercent);
    Other := FindTax(ACalculated.TaxAmountSubtotals, Tax);
    if Other = nil then
      AFindings.Add(Name + ': missing')
    else
    begin
      CompareAmount(Name + ' BT-116', Tax.TaxableAmount, Other.TaxableAmount, AFindings);
      CompareAmount(Name + ' BT-117', Tax.TaxAmount, Other.TaxAmount, AFindings);
    end;
  end;
end;

{ Recalculates one invoice: the line amounts from prices, and separately
  the totals from the line amounts as read. Invoices without lines
  (MINIMUM, BASIC WL) are skipped. }
procedure OracleFile(const AFileName: string; AFindings: TStrings; var AFiles: Integer);
var
  Doc: TLandrixEInvoiceDocument;
  Calculated: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
begin
  Doc := TLandrixEInvoice.LoadFromFile(TLandrixEInvoiceString(AFileName), [eio_InvoiceOnly, eio_NoPdf]);
  Calculated := TLandrixInvoice.Create;
  D := TLandrixEInvoiceDiagnostics.Create;
  try
    if Doc.Invoice.InvoiceLines.Count = 0 then
      Exit;
    Inc(AFiles);
    Calculated.Assign(Doc.Invoice);
    if TLandrixEInvoice.CalculateLineAmounts(Calculated, D) > 0 then
      AFindings.Add('lines refused: ' + string(D.ToText))
    else
      CompareLines(Doc.Invoice.InvoiceLines, Calculated.InvoiceLines, AFindings);
    Calculated.Assign(Doc.Invoice);
    D.Clear;
    if TLandrixEInvoice.CalculateTotals(Calculated, D) > 0 then
      AFindings.Add('totals refused: ' + string(D.ToText))
    else
      CompareTotals(Doc.Invoice, Calculated, AFindings);
  finally
    D.Free;
    Calculated.Free;
    Doc.Free;
  end;
end;

procedure LoadExceptions(AList: TStrings);
var
  FileName: string;
  Lines: TStringList;
  I: Integer;
begin
  FileName := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'calc-exceptions.txt';
  if not FileExists(FileName) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    for I := 0 to Lines.Count - 1 do
      if (Trim(Lines[I]) <> '') and (Copy(Lines[I], 1, 1) <> '#') then
        AList.Add(Lines[I]);
  finally
    Lines.Free;
  end;
end;

{ An exception line is "corpus/file<TAB>finding prefix". }
function Excepted(AExceptions: TStrings; var AUsed: array of Boolean; const AKey, AFinding: string): Boolean;
var
  I, P: Integer;
  Prefix: string;
begin
  Result := False;
  for I := 0 to AExceptions.Count - 1 do
  begin
    P := Pos(#9, AExceptions[I]);
    Prefix := Copy(AExceptions[I], P + 1, MaxInt);
    if (P > 0) and (Copy(AExceptions[I], 1, P - 1) = AKey) and (Copy(AFinding, 1, Length(Prefix)) = Prefix) then
    begin
      AUsed[I] := True;
      Result := True;
    end;
  end;
end;

procedure TestSweepOracle;
var
  Root, Key: string;
  Corpus, Item: TSearchRec;
  Findings, Exceptions: TStringList;
  Used: array of Boolean;
  Files, Failed, I: Integer;
begin
  Root := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim + 'sweep' + PathDelim;
  if not DirectoryExists(Root) then
  begin
    Skip('no local sweep corpora (tools/testdata/sync-local.py) in ' + Root);
    Exit;
  end;
  Findings := TStringList.Create;
  Exceptions := TStringList.Create;
  try
    LoadExceptions(Exceptions);
    Used := nil;
    SetLength(Used, Exceptions.Count);
    for I := 0 to Exceptions.Count - 1 do
      Used[I] := False;
    Files := 0;
    Failed := 0;
    if FindFirst(Root + '*', faDirectory, Corpus) = 0 then
    try
      repeat
        if (Corpus.Attr and faDirectory = 0) or (Corpus.Name = '.') or (Corpus.Name = '..') then
          Continue;
        if FindFirst(Root + Corpus.Name + PathDelim + '*.xml', faAnyFile, Item) = 0 then
        try
          repeat
            Key := Corpus.Name + '/' + Item.Name;
            Findings.Clear;
            try
              OracleFile(Root + Corpus.Name + PathDelim + Item.Name, Findings, Files);
            except
              on ELandrixEInvoiceError do
                Continue;
            end;
            for I := 0 to Findings.Count - 1 do
              if not Excepted(Exceptions, Used, Key, Findings[I]) then
              begin
                Inc(Failed);
                WriteLn('  ', Key, #9, Findings[I]);
              end;
          until FindNext(Item) <> 0;
        finally
          FindClose(Item);
        end;
      until FindNext(Corpus) <> 0;
    finally
      FindClose(Corpus);
    end;
    for I := 0 to Exceptions.Count - 1 do
      if not Used[I] then
      begin
        Inc(Failed);
        WriteLn('  unused exception: ', Exceptions[I]);
      end;
    WriteLn('  calculate oracle: ', Files, ' invoices with lines');
    Check(Files > 0, 'invoices recalculated');
    CheckEquals(0, Failed, 'deviations from the sweep invoices (tests/data/calc-exceptions.txt)');
  finally
    Exceptions.Free;
    Findings.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Calculate.LineAmounts', TestLineAmounts);
  RegisterTest('Calculate.Groups', TestGroups);
  RegisterTest('Calculate.Totals', TestTotals);
  RegisterTest('Calculate.PassesCheck', TestPassesCheck);
  RegisterTest('Calculate.SweepOracle', TestSweepOracle);
end;

end.
