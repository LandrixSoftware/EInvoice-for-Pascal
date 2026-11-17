{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Runs TLandrixEInvoicePdfChecker on every PDF of a folder (or the files
  given), reads the extracted invoice through the facade for the second
  pass (CheckInvoiceFacts) and prints, per file, a line
  "file<TAB>status<TAB>kind<TAB>name<TAB>profile<TAB>xmp status<TAB>
  fx:ConformanceLevel" (status: level 2, xmp status: level 3) and its
  findings indented below. With -facts=DIR it also prints, per file specification of the
  collector, a line "  spec<TAB>index<TAB>routes<TAB>key<TAB>spec object<TAB>
  /F<TAB>/UF<TAB>stream object<TAB>subtype<TAB>moddate<TAB>size" and writes
  the decoded data to DIR/<file>.<index>.bin (tools/pdfcheck/pdf-oracle.py).
  With -syntax it also prints the raw syntax facts of LandrixEInvoicePdfSyntax:
  "  syntax<TAB>complete|incomplete<TAB>objects in use<TAB>envelopes<TAB>
  streams<TAB>tokens<TAB>xref sections" and a line "  syntax-problem<TAB>text"
  per problem. With -pdfa it first prints "# pdfa-rule<TAB>number<TAB>full|partial|none"
  per rule of LandrixEInvoicePdfARules, then per file
  "  pdfa<TAB>complete|incomplete<TAB>failed rule numbers" (complete: the
  facts) and "  pdfa-fail<TAB>number<TAB>violations<TAB>first one" per
  failed rule (tools/pdfcheck/verapdf-oracle.py --native). }

program PdfCheckProbe;

{$I LandrixEInvoice.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoicePdfObjects,
  LandrixEInvoicePdfSyntax,
  LandrixEInvoicePdfARules,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoice,
  LandrixEInvoicePdfCheck;

const
  StatusNames: array[TLandrixEInvoicePdfLevelStatus] of string = ('not-run', 'passed', 'failed', 'incomplete');
  KindNames: array[TLandrixEInvoicePdfHybridKind] of string = ('none', 'factur-x', 'xrechnung', 'zugferd-2.0',
    'zugferd-1.0');
  SeverityNames: array[TLandrixEInvoiceDiagnosticSeverity] of string = ('info', 'warning', 'error');
  ProfileNames: array[TLandrixEInvoiceProfile] of string = ('none', 'minimum', 'basic-wl', 'basic', 'en16931',
    'extended', 'xrechnung');

{ The second pass with the facts of the extracted invoice; an invoice the
  facade cannot read gets no facts. }
procedure CheckFacts(AChecker: TLandrixEInvoicePdfChecker; AResult: TLandrixEInvoicePdfCheckResult);
var
  Doc: TLandrixEInvoiceDocument;
  Facts: TLandrixEInvoicePdfInvoiceFacts;
begin
  if AResult.Invoice.Size = 0 then
    Exit;
  AResult.Invoice.Position := 0;
  try
    Doc := TLandrixEInvoice.LoadFromStream(AResult.Invoice, [eio_NoPdf, eio_NoRuleCheck, eio_InvoiceOnly]);
  except
    Exit;
  end;
  try
    Facts.Target := Doc.Info.Spec.Target;
    if not Doc.Info.SpecFound then
      Facts.Target.Syntax := Doc.Info.Syntax;
    Facts.SellerCountryCode := Doc.Invoice.AccountingSupplierParty.Address.CountryCode;
    Facts.BuyerCountryCode := Doc.Invoice.AccountingCustomerParty.Address.CountryCode;
    AChecker.CheckInvoiceFacts(AResult, Facts);
  finally
    Doc.Free;
  end;
end;

var
  FactsDir: string;
  WithSyntax: Boolean;
  WithPdfA: Boolean;

{ PDF names are ASCII: one character per byte. }
function AnsiText(const S: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := Char(Ord(S[I]));
end;

function YesNo(B: Boolean): string;
begin
  if B then
    Result := '1'
  else
    Result := '0';
end;

procedure PrintFacts(const AFileName: string);
var
  Stream: TFileStream;
  Doc: TLandrixEInvoicePdfDocument;
  Specs: TLandrixEInvoicePdfCollector;
  F: TLandrixEInvoicePdfFileSpec;
  Data: TLandrixEInvoicePdfBytes;
  Dest: TFileStream;
  Err, Routes: string;
  I: Integer;
  Size: Int64;
begin
  Doc := TLandrixEInvoicePdfDocument.Create;
  try
    try
      Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
      try
        if not Doc.Load(Stream, Err) then
          Exit;
      finally
        Stream.Free;
      end;
    except
      Exit;
    end;
    Specs := TLandrixEInvoicePdfCollector.Create(Doc);
    try
      Specs.Collect;
      for I := 0 to Specs.Count - 1 do
      begin
        F := Specs[I];
        Routes := '';
        if efr_NameTree in F.Routes then
          Routes := 'tree';
        if efr_AF in F.Routes then
          Routes := Routes + '+af';
        Size := -1;
        if (F.Stream <> nil) and Doc.GetStreamData(F.Stream, Data) then
        begin
          Size := Length(Data);
          Dest := TFileStream.Create(FactsDir + ExtractFileName(AFileName) + '.' + IntToStr(I) + '.bin', fmCreate);
          try
            if Length(Data) > 0 then
              Dest.WriteBuffer(Data[0], Length(Data));
          finally
            Dest.Free;
          end;
        end;
        WriteLn('  spec', #9, I, #9, Routes, #9, UTF8Encode(F.NameTreeKey), #9, F.SpecNum, #9,
          UTF8Encode(F.FileNameF), #9, UTF8Encode(F.FileNameUF), #9, F.StreamNum, #9, AnsiText(F.Subtype), #9,
          YesNo(F.HasModDate), #9, Size);
      end;
    finally
      Specs.Free;
    end;
  finally
    Doc.Free;
  end;
end;

procedure PrintPdfA(ADoc: TLandrixEInvoicePdfDocument; AFacts: TLandrixEInvoicePdfSyntaxFacts);
const
  Done: array[Boolean] of string = ('incomplete', 'complete');
var
  Rules: TLandrixEInvoicePdfARuleCheck;
  R: TLandrixEInvoicePdfARule;
  Res: TLandrixEInvoicePdfARuleResult;
  Failed: string;
begin
  Rules := TLandrixEInvoicePdfARuleCheck.Create;
  try
    Rules.Check(ADoc, AFacts);
    Failed := '';
    for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
      if Rules.RuleResult(R).Outcome = pro_Failed then
      begin
        if Failed <> '' then
          Failed := Failed + ' ';
        Failed := Failed + LandrixEInvoicePdfARuleNumber(R);
      end;
    WriteLn('  pdfa', #9, Done[AFacts.Complete], #9, Failed);
    for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
    begin
      Res := Rules.RuleResult(R);
      if Res.Outcome = pro_Failed then
        WriteLn('  pdfa-fail', #9, LandrixEInvoicePdfARuleNumber(R), #9, Res.Failures, #9, Res.Detail);
    end;
  finally
    Rules.Free;
  end;
end;

procedure PrintSyntax(const AFileName: string);
const
  Done: array[Boolean] of string = ('incomplete', 'complete');
var
  Stream: TFileStream;
  Doc: TLandrixEInvoicePdfDocument;
  Facts: TLandrixEInvoicePdfSyntaxFacts;
  Err: string;
  I: Integer;
begin
  Facts := TLandrixEInvoicePdfSyntaxFacts.Create;
  try
    Doc := TLandrixEInvoicePdfDocument.Create;
    try
      Doc.Syntax := Facts;
      try
        Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
        try
          if not Doc.Load(Stream, Err) then
          begin
            if WithSyntax then
              WriteLn('  syntax', #9, 'unreadable', #9, Err);
            if WithPdfA then
              WriteLn('  pdfa', #9, 'unreadable', #9, Err);
            Exit;
          end;
        finally
          Stream.Free;
        end;
        Facts.Inspect(Doc);
      except
        on E: Exception do
        begin
          if WithSyntax then
            WriteLn('  syntax', #9, 'exception', #9, E.ClassName, ': ', E.Message);
          if WithPdfA then
            WriteLn('  pdfa', #9, 'exception', #9, E.ClassName, ': ', E.Message);
          Exit;
        end;
      end;
      if WithSyntax then
      begin
        WriteLn('  syntax', #9, Done[Facts.Complete], #9, Facts.InUseCount, #9, Facts.EnvelopeCount, #9,
          Facts.StreamCount, #9, Facts.TokenCount, #9, Facts.SectionCount);
        for I := 0 to Facts.Problems.Count - 1 do
          WriteLn('  syntax-problem', #9, Facts.Problems[I]);
      end;
      if WithPdfA then
        PrintPdfA(Doc, Facts);
    finally
      Doc.Free;
    end;
  finally
    Facts.Free;
  end;
end;

procedure CheckOne(AChecker: TLandrixEInvoicePdfChecker; AResult: TLandrixEInvoicePdfCheckResult;
  const AFileName: string);
var
  I: Integer;
  D: TLandrixEInvoiceDiagnostic;
begin
  AChecker.CheckFile(AFileName, AResult);
  CheckFacts(AChecker, AResult);
  WriteLn(ExtractFileName(AFileName), #9, StatusNames[AResult.Status[epl_Embedding]], #9,
    KindNames[AResult.HybridKind], #9, UTF8Encode(AResult.InvoiceFileName), #9, ProfileNames[AResult.Profile], #9,
    StatusNames[AResult.Status[epl_Metadata]], #9, UTF8Encode(AResult.XmpConformanceLevel));
  for I := 0 to Integer(AResult.Diagnostics.Count) - 1 do
  begin
    D := AResult.Diagnostics[I];
    WriteLn('  ', SeverityNames[D.Severity], #9, UTF8Encode(D.RuleID), #9, UTF8Encode(D.Path), #9,
      UTF8Encode(D.Message));
  end;
  if FactsDir <> '' then
    PrintFacts(AFileName);
  if WithSyntax or WithPdfA then
    PrintSyntax(AFileName);
end;

const
  CoverageNames: array[TLandrixEInvoicePdfARuleCoverage] of string = ('full', 'partial', 'none');
var
  Checker: TLandrixEInvoicePdfChecker;
  Result: TLandrixEInvoicePdfCheckResult;
  SR: TSearchRec;
  Dir: string;
  I: Integer;
  R: TLandrixEInvoicePdfARule;
begin
  if ParamCount = 0 then
  begin
    WriteLn('usage: PdfCheckProbe [-facts=DIR] [-syntax] [-pdfa] <folder or PDF files>');
    ExitCode := 2;
    Exit;
  end;
  FactsDir := '';
  WithSyntax := False;
  WithPdfA := False;
  for I := 1 to ParamCount do
    if ParamStr(I) = '-pdfa' then
      WithPdfA := True;
  if WithPdfA then
    for R := Low(TLandrixEInvoicePdfARule) to High(TLandrixEInvoicePdfARule) do
      WriteLn('# pdfa-rule', #9, LandrixEInvoicePdfARuleNumber(R), #9,
        CoverageNames[LandrixEInvoicePdfARuleCoverage(R)]);
  Checker := TLandrixEInvoicePdfChecker.Create;
  Result := TLandrixEInvoicePdfCheckResult.Create;
  try
    for I := 1 to ParamCount do
      if Copy(ParamStr(I), 1, 7) = '-facts=' then
        FactsDir := IncludeTrailingPathDelimiter(Copy(ParamStr(I), 8, MaxInt))
      else if ParamStr(I) = '-syntax' then
        WithSyntax := True
      else if ParamStr(I) = '-pdfa' then
        WithPdfA := True
      else if DirectoryExists(ParamStr(I)) then
      begin
        Dir := IncludeTrailingPathDelimiter(ParamStr(I));
        if FindFirst(Dir + '*.pdf', faAnyFile, SR) = 0 then
          try
            repeat
              CheckOne(Checker, Result, Dir + SR.Name);
            until FindNext(SR) <> 0;
          finally
            FindClose(SR);
          end;
      end
      else
        CheckOne(Checker, Result, ParamStr(I));
  finally
    Result.Free;
    Checker.Free;
  end;
end.
