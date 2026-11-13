program MarkdownProbe;

{ Writes the Markdown of invoices and the values the walk passes for them,
  for tools/render/md-oracle.py: per case NNNN.md and NNNN.tsv (one line
  "kind<TAB>depth<TAB>section<TAB>label<TAB>value" per line the walk calls
  for, see TEvent; \\ \t \n \r escaped), and
  index.txt ("NNNN<TAB>case"). Cases: the filled invoice with one and two
  items per list, the golden invoices and the hostile invoice of the tests
  and every readable local corpus file (golden, cii, ubl, sweep), each in
  English and in German with business terms.
  Usage: MarkdownProbe <repository root> <output folder> }

{$I LandrixEInvoice.inc}
{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceInvoice,
  LandrixEInvoice,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceRenderMarkdown,
  LandrixEInvoiceTestInvoiceCompare,
  LandrixEInvoiceTestRender,
  LandrixEInvoiceTestRenderMarkdown;

var
  OutDir: string;
  Index: TStringList;
  CaseNo: Integer;

procedure WriteUtf8(const AFileName: string; const S: TLandrixXmlUtf8);
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFileName, fmCreate);
  try
    if S <> '' then
      F.WriteBuffer(PAnsiChar(S)^, Length(S));
  finally
    F.Free;
  end;
end;

function Field(const S: TLandrixEInvoiceString): TLandrixEInvoiceString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '\': Result := Result + '\\';
      #9: Result := Result + '\t';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
    else
      Result := Result + S[I];
    end;
end;

procedure WriteCase(const AName: string; AInvoice: TLandrixInvoice; ADocument: TLandrixEInvoiceDocument;
  ALanguage: TLandrixEInvoiceReportLanguage; AShowTerms: Boolean; const ADocumentName: TLandrixEInvoiceString);
var
  W: TLandrixEInvoiceRenderMarkdownWriter;
  Events: TEventList;
  Tsv: TLandrixEInvoiceString;
  Base: string;
  I: Integer;
begin
  Inc(CaseNo);
  Base := Format('%.5d', [CaseNo]);
  W := TLandrixEInvoiceRenderMarkdownWriter.Create;
  Events := TEventList.Create;
  try
    W.Language := ALanguage;
    W.ShowBusinessTerms := AShowTerms;
    W.DocumentName := ADocumentName;
    if ADocument <> nil then
      WriteUtf8(OutDir + Base + '.md', LandrixEInvoiceStringToUtf8(W.WriteToString(ADocument)))
    else
      WriteUtf8(OutDir + Base + '.md', LandrixEInvoiceStringToUtf8(W.WriteToString(AInvoice)));
    RecordEvents(AInvoice, ADocument, ALanguage, AShowTerms, Events, ADocumentName);
    Tsv := '';
    for I := 0 to Events.Count - 1 do
      Tsv := Tsv + TLandrixEInvoiceString(Events.Items[I].Kind) + #9 +
        TLandrixEInvoiceString(IntToStr(Events.Items[I].Depth)) + #9 + Field(Events.Items[I].Section) + #9 + Field(Events.Items[I].Lbl) + #9 +
        Field(Events.Items[I].Value) + #10;
    WriteUtf8(OutDir + Base + '.tsv', LandrixEInvoiceStringToUtf8(Tsv));
  finally
    Events.Free;
    W.Free;
  end;
  if ALanguage = eln_German then
    Index.Add(Base + #9 + AName + ' de')
  else
    Index.Add(Base + #9 + AName + ' en');
end;

procedure WriteBoth(const AName: string; AInvoice: TLandrixInvoice; ADocument: TLandrixEInvoiceDocument;
  const ADocumentName: TLandrixEInvoiceString = '');
begin
  WriteCase(AName, AInvoice, ADocument, eln_English, False, ADocumentName);
  WriteCase(AName, AInvoice, ADocument, eln_German, True, ADocumentName);
end;

procedure Folder(const ADir, ARel: string);
var
  SR: TSearchRec;
  List: TStringList;
  D: TLandrixEInvoiceDocument;
  I: Integer;
begin
  List := TStringList.Create;
  try
    if FindFirst(ADir + '*', faAnyFile, SR) = 0 then
      try
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') then
            List.Add(SR.Name);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    List.Sort;
    for I := 0 to List.Count - 1 do
      if DirectoryExists(ADir + List[I]) then
        Folder(ADir + List[I] + PathDelim, ARel + List[I] + '/')
      else if LowerCase(ExtractFileExt(List[I])) = '.xml' then
      begin
        try
          D := TLandrixEInvoice.LoadFromFile(TLandrixEInvoiceString(ADir + List[I]));
        except
          D := nil;
        end;
        if D <> nil then
          try
            WriteBoth(ARel + List[I], D.Invoice, D);
          finally
            D.Free;
          end;
      end;
  finally
    List.Free;
  end;
end;

const
  Folders: array[0..3] of string = ('golden', 'cii', 'ubl', 'sweep');
var
  Root, Local: string;
  Inv: TLandrixInvoice;
  I: Integer;
begin
  if ParamCount < 2 then
  begin
    WriteLn('Usage: MarkdownProbe <repository root> <output folder>');
    Halt(2);
  end;
  Root := IncludeTrailingPathDelimiter(ParamStr(1));
  OutDir := IncludeTrailingPathDelimiter(ParamStr(2));
  ForceDirectories(OutDir);
  Index := TStringList.Create;
  try
    for I := 1 to 2 do
    begin
      Inv := TLandrixInvoice.Create;
      try
        FillInvoiceAll(Inv, I);
        WriteBoth('fill' + IntToStr(I), Inv, nil);
      finally
        Inv.Free;
      end;
    end;
    Inv := TLandrixInvoice.Create;
    try
      BuildFullInvoice(Inv);
      WriteBoth('full', Inv, nil);
    finally
      Inv.Free;
    end;
    Inv := TLandrixInvoice.Create;
    try
      BuildCreditNote(Inv);
      WriteBoth('credit', Inv, nil);
    finally
      Inv.Free;
    end;
    Inv := TLandrixInvoice.Create;
    try
      BuildHostileInvoice(Inv);
      WriteBoth('hostile', Inv, nil, HostileDocumentName);
    finally
      Inv.Free;
    end;
    Local := Root + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
    for I := Low(Folders) to High(Folders) do
      if DirectoryExists(Local + Folders[I]) then
        Folder(Local + Folders[I] + PathDelim, Folders[I] + '/');
    Index.SaveToFile(OutDir + 'index.txt');
    WriteLn(CaseNo, ' cases');
  finally
    Index.Free;
  end;
end.
