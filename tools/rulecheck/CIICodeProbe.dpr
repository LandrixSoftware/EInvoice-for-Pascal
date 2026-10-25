program CIICodeProbe;

{ Reads CII invoice files into the CII syntax model and runs
  LandrixEInvoiceCheckCIICodes for each Factur-X profile (MINIMUM to
  EXTENDED; the assert identifiers belong to one profile each). Prints one
  line per file: "file<TAB>status<TAB>rule rule ..." with the status ok or
  exception (also for another root element), and the RuleID of every
  violation. Arguments are files or folders (every *.xml in it). Used by
  tools/rulecheck/fx-code-oracle.py. }

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
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceCIICodeRules;

const
  Profiles: array[0..4] of TLandrixEInvoiceProfile = (epr_Minimum, epr_BasicWL, epr_Basic, epr_EN16931,
    epr_Extended);

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

procedure Probe(const AFileName: string);
var
  R: TLandrixXmlReader;
  CII: TLandrixCIIInvoice;
  D: TLandrixEInvoiceDiagnostics;
  Rules: string;
  I: Integer;
  J: TLandrixEInvoiceListIndex;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  R := TLandrixXmlReader.Create;
  try
    try
      R.LoadFromUtf8(LoadFile(AFileName));
      CII := LandrixEInvoiceReadCII(R, D);
      try
        D.Clear;
        for I := Low(Profiles) to High(Profiles) do
          LandrixEInvoiceCheckCIICodes(CII, Profiles[I], D);
        Rules := '';
        for J := 0 to D.Count - 1 do
          if D[J].Kind = edk_RuleViolation then
            Rules := Rules + ' ' + string(D[J].RuleID);
        WriteLn(ExtractFileName(AFileName), #9'ok'#9, Trim(Rules));
      finally
        CII.Free;
      end;
    except
      on E: Exception do
        WriteLn(ExtractFileName(AFileName), #9'exception'#9, E.Message);
    end;
  finally
    R.Free;
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
