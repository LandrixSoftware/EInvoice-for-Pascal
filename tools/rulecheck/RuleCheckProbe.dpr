program RuleCheckProbe;

{ Reads invoice files (CII, UBL invoice or credit note), detects their
  specification, maps them to TLandrixInvoice and runs
  LandrixEInvoiceCheckInvoice. Prints one line per file:
  "file<TAB>status<TAB>rule rule ..." with the status ok, detect (no
  specification found) or exception, and the RuleID of every
  edk_RuleViolation. Arguments are files or folders (every *.xml in it).
  Used by tools/rulecheck/rule-oracle.py. }

{$I LandrixEInvoice.inc}
{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixEInvoiceTypes,
  LandrixEInvoiceDiagnostics,
  LandrixEInvoiceSpecs,
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceMapCII,
  LandrixEInvoiceUBL,
  LandrixEInvoiceUBLReader,
  LandrixEInvoiceMapUBL,
  LandrixEInvoiceCheck;

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

procedure Probe(const AFileName: string);
var
  Xml: TLandrixXmlUtf8;
  Root, Rules: string;
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Spec: TLandrixEInvoiceSpec;
  Ext: Boolean;
  CustomizationID: TLandrixEInvoiceString;
  I: TLandrixEInvoiceListIndex;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  try
    try
      Xml := LoadFile(AFileName);
      Root := RootLocalName(Xml);
      CustomizationID := ReadModel(Xml, Root, Invoice, D);
      if not LandrixEInvoiceDetectSpec(TLandrixEInvoiceString(Root), CustomizationID, Spec, Ext) then
      begin
        WriteLn(ExtractFileName(AFileName), #9'detect'#9);
        Exit;
      end;
      D.Clear;
      LandrixEInvoiceCheckInvoice(Invoice, Spec, D);
      Rules := '';
      for I := 0 to D.Count - 1 do
        if D[I].Kind = edk_RuleViolation then
          Rules := Rules + ' ' + string(D[I].RuleID);
      WriteLn(ExtractFileName(AFileName), #9'ok'#9, Trim(Rules));
    except
      on E: Exception do
        WriteLn(ExtractFileName(AFileName), #9'exception'#9, E.Message);
    end;
  finally
    Invoice.Free;
    D.Free;
  end;
end;

var
  I: Integer;
  SR: TSearchRec;
  Dir: string;
begin
  for I := 1 to ParamCount do
    if DirectoryExists(ParamStr(I)) then
    begin
      Dir := IncludeTrailingPathDelimiter(ParamStr(I));
      if FindFirst(Dir + '*.xml', faAnyFile, SR) = 0 then
      begin
        repeat
          Probe(Dir + SR.Name);
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;
    end
    else
      Probe(ParamStr(I));
end.
