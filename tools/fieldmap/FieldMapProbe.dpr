program FieldMapProbe;

{ Reads CII files, maps them to TLandrixInvoice and prints every diagnostic
  as "file<TAB>kind<TAB>path<TAB>message". Arguments are files or folders
  (every *.xml in it). Used by tools/fieldmap/fieldmap.py. }

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
  LandrixEInvoiceInvoice,
  LandrixEInvoiceCII,
  LandrixEInvoiceCIIReader,
  LandrixEInvoiceMapCII;

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
  Invoice: TLandrixInvoice;
  D: TLandrixEInvoiceDiagnostics;
  I: TLandrixEInvoiceListIndex;
begin
  D := TLandrixEInvoiceDiagnostics.Create;
  Invoice := TLandrixInvoice.Create;
  R := TLandrixXmlReader.Create;
  try
    try
      R.LoadFromUtf8(LoadFile(AFileName));
      CII := LandrixEInvoiceReadCII(R, D);
      try
        LandrixEInvoiceCIIToInvoice(CII, Invoice, D);
      finally
        CII.Free;
      end;
    except
      on E: Exception do
        WriteLn(ExtractFileName(AFileName), #9'exception'#9#9, E.Message);
    end;
    for I := 0 to D.Count - 1 do
      WriteLn(ExtractFileName(AFileName), #9, string(LandrixEInvoiceDiagnosticKindToStr(D[I].Kind)), #9,
        string(D[I].Path), #9, string(D[I].Message));
  finally
    R.Free;
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
