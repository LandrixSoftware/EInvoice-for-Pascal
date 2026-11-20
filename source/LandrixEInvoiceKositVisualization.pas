{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The XRechnung visualization of KoSIT (itplr-kosit/xrechnung-visualization)
  run with the XSLT engine of LandrixXML: a UBL invoice, UBL credit note or
  CII invoice is turned into the syntax-neutral XR form (ubl-invoice-xr.xsl,
  ubl-creditnote-xr.xsl, cii-xr.xsl, chosen by the namespace and name of the
  root element) and that into an HTML page (xrechnung-html.xsl), as Saxon
  does it. The stylesheets come from the xsl folder of the visualization
  (addons/kosit/install-kosit.ps1, module visualization); they are compiled
  once and kept. The PDF of the visualization (Apache FOP) is not made.
  This library's own rendering is LandrixEInvoiceRenderHtml.
  DE: Die XRechnung-Visualisierung von KoSIT
  (itplr-kosit/xrechnung-visualization), ausgefuehrt mit der XSLT-Maschine
  von LandrixXML: eine UBL-Rechnung, UBL-Gutschrift oder CII-Rechnung wird in
  die syntaxneutrale XR-Form gebracht (ubl-invoice-xr.xsl,
  ubl-creditnote-xr.xsl, cii-xr.xsl, gewaehlt nach Namensraum und Name des
  Wurzelelements) und diese in eine HTML-Seite (xrechnung-html.xsl), wie
  Saxon es tut. Die Stylesheets kommen aus dem xsl-Ordner der
  Visualisierung (addons/kosit/install-kosit.ps1, Modul visualization); sie
  werden einmal uebersetzt und behalten. Das PDF der Visualisierung (Apache
  FOP) entsteht nicht. Die eigene Darstellung dieser Bibliothek ist
  LandrixEInvoiceRenderHtml. }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceKositVisualization;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes,
  LandrixEInvoiceReportHtml;

type
  { Runs the XRechnung visualization. One object per thread.
    DE: Fuehrt die XRechnung-Visualisierung aus. Ein Objekt je Thread. }
  TLandrixEInvoiceKositVisualizer = class(TObject)
  private
    FFolder: string;
    FLanguage: TLandrixEInvoiceReportLanguage;
    FStylesheets: TStringList;
    procedure SetFolder(const AValue: string);
    function StylesheetOf(const AName: string): TObject;
    function XrTree(ADocument: TStream): TObject;
    procedure Html(AXr: TObject; AOutput: TStream);
  public
    constructor Create;
    destructor Destroy; override;
    { Writes the XR form of the invoice in ADocument (read from its
      position to the end) to AOutput as UTF-8 XML. Raises
      ELandrixEInvoiceError when the document is not well-formed or is no
      UBL invoice, UBL credit note or CII invoice, or a stylesheet does not
      load or fails.
      DE: Schreibt die XR-Form der Rechnung in ADocument (gelesen ab seiner
      Position bis zum Ende) als UTF-8-XML nach AOutput. Loest
      ELandrixEInvoiceError aus, wenn das Dokument nicht wohlgeformt oder
      keine UBL-Rechnung, UBL-Gutschrift oder CII-Rechnung ist, oder ein
      Stylesheet nicht laedt oder scheitert. }
    procedure WriteXr(ADocument, AOutput: TStream);
    { The HTML page of the invoice in ADocument; errors as WriteXr.
      DE: Die HTML-Seite der Rechnung in ADocument; Fehler wie WriteXr. }
    procedure WriteHtml(ADocument, AOutput: TStream);
    { The HTML page of an XR document (as WriteXr writes it).
      DE: Die HTML-Seite eines XR-Dokuments (wie WriteXr es schreibt). }
    procedure WriteHtmlFromXr(AXr, AOutput: TStream);
    { The xsl folder of the visualization (with xrechnung-html.xsl);
      changing it drops the compiled stylesheets.
      DE: Der xsl-Ordner der Visualisierung (mit xrechnung-html.xsl); eine
      Aenderung verwirft die uebersetzten Stylesheets. }
    property Folder: string read FFolder write SetFolder;
    { The language of the page (parameter lang); default German, as the
      visualization.
      DE: Die Sprache der Seite (Parameter lang); Vorgabe Deutsch, wie die
      Visualisierung. }
    property Language: TLandrixEInvoiceReportLanguage read FLanguage write FLanguage;
  end;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixXmlXPathTree,
  LandrixXmlXslt;

const
  UblInvoiceNs = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2';
  UblCreditNoteNs = 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2';
  CiiNs = 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100';

procedure Fail(const AMsg: string);
begin
  raise ELandrixEInvoiceError.Create('KoSIT visualization: ' + AMsg);
end;

constructor TLandrixEInvoiceKositVisualizer.Create;
begin
  inherited Create;
  FStylesheets := TStringList.Create;
  FLanguage := eln_German;
end;

destructor TLandrixEInvoiceKositVisualizer.Destroy;
begin
  SetFolder('');
  FStylesheets.Free;
  inherited Destroy;
end;

procedure TLandrixEInvoiceKositVisualizer.SetFolder(const AValue: string);
var
  I: Integer;
begin
  for I := 0 to FStylesheets.Count - 1 do
    FStylesheets.Objects[I].Free;
  FStylesheets.Clear;
  FFolder := AValue;
end;

function TLandrixEInvoiceKositVisualizer.StylesheetOf(const AName: string): TObject;
var
  I: Integer;
  Sheet: TLandrixXmlXsltStylesheet;
  FileName: string;
begin
  I := FStylesheets.IndexOf(AName);
  if I < 0 then
  begin
    if FFolder = '' then
      Fail('no folder');
    FileName := IncludeTrailingPathDelimiter(FFolder) + AName;
    if not FileExists(FileName) then
      Fail('missing ' + FileName);
    Sheet := TLandrixXmlXsltStylesheet.Create;
    try
      Sheet.LoadFromFile(FileName);
    except
      on E: Exception do
      begin
        Sheet.Free;
        Fail('stylesheet ' + FileName + ': ' + E.Message);
      end;
    end;
    I := FStylesheets.AddObject(AName, Sheet);
  end;
  Result := FStylesheets.Objects[I];
end;

{ The tree of the bytes from the stream's position to the end. }
function LoadTree(AStream: TStream): TLandrixXmlXPathTree;
var
  Data: TMemoryStream;
  Count: Int64;
  Reader: TLandrixXmlReader;
begin
  if AStream = nil then
    Fail('no document');
  Count := AStream.Size - AStream.Position;
  if Count > MaxInt then
    Fail('the document is larger than 2 GB');
  Result := TLandrixXmlXPathTree.Create;
  Data := TMemoryStream.Create;
  try
    try
      if Count > 0 then
        Data.CopyFrom(AStream, Count);
      Reader := TLandrixXmlReader.Create;
      try
        Reader.LoadFromBuffer(Data.Memory^, Integer(Data.Size));
        Result.LoadFromReader(Reader);
      finally
        Reader.Free;
      end;
    except
      on E: ELandrixXmlError do
      begin
        Result.Free;
        Fail('the document is not well-formed: ' + E.Message);
      end;
      else
      begin
        Result.Free;
        raise;
      end;
    end;
  finally
    Data.Free;
  end;
end;

{ The stylesheet that turns the document into XR, by its root element. }
function XrStylesheetName(ATree: TLandrixXmlXPathTree): string;
var
  Root: Integer;
  Ns, Name: TLandrixXmlUtf8;
begin
  Root := ATree.DocumentElement;
  Ns := '';
  Name := '';
  if Root >= 0 then
  begin
    Ns := ATree.NamespaceUriUtf8(Root);
    Name := ATree.LocalNameUtf8(Root);
  end;
  if (Ns = UblInvoiceNs) and (Name = 'Invoice') then
    Result := 'ubl-invoice-xr.xsl'
  else if (Ns = UblCreditNoteNs) and (Name = 'CreditNote') then
    Result := 'ubl-creditnote-xr.xsl'
  else if (Ns = CiiNs) and (Name = 'CrossIndustryInvoice') then
    Result := 'cii-xr.xsl'
  else
  begin
    Result := '';
    Fail('the document is no UBL invoice, UBL credit note or CII invoice');
  end;
end;

function TLandrixEInvoiceKositVisualizer.XrTree(ADocument: TStream): TObject;
var
  Source, Target: TLandrixXmlXPathTree;
  Transformer: TLandrixXmlXsltTransformer;
begin
  Source := LoadTree(ADocument);
  try
    Target := TLandrixXmlXPathTree.Create;
    try
      Transformer := TLandrixXmlXsltTransformer.Create(
        TLandrixXmlXsltStylesheet(StylesheetOf(XrStylesheetName(Source))));
      try
        try
          Transformer.TransformToTree(Source, Target);
        except
          on E: ELandrixXmlError do
            Fail(E.Message);
        end;
      finally
        Transformer.Free;
      end;
    except
      Target.Free;
      raise;
    end;
  finally
    Source.Free;
  end;
  Result := Target;
end;

{ --- active content of the visualization ------------------------------------ }

{ The KoSIT stylesheet copies invoice values into active content: BT-124
  (external document location) into an href, and the attachment's
  reference, MIME code and file name into the arguments of an onClick
  JavaScript call, where an apostrophe ends the string literal. The values
  come from the sender of the invoice, so the page would run their script.
  The output is filtered: an href with a scheme other than http, https,
  mailto or ftp becomes '#', a downloadData onClick that is not exactly
  downloadData('...', '...', '...') with plain arguments becomes
  'return false'. A well-formed invoice keeps the page unchanged. }

function DecodeAttr(const AValue: AnsiString): AnsiString;
var
  I, J, N, Code: Integer;
  Ent: AnsiString;
begin
  { never longer than the input }
  Result := '';
  SetLength(Result, Length(AValue));
  N := 0;
  I := 1;
  while I <= Length(AValue) do
  begin
    if AValue[I] = '&' then
    begin
      J := I + 1;
      while (J <= Length(AValue)) and (AValue[J] <> ';') and (J - I < 12) do
        Inc(J);
      if (J <= Length(AValue)) and (AValue[J] = ';') then
      begin
        Ent := Copy(AValue, I + 1, J - I - 1);
        Code := -1;
        if Ent = 'amp' then
          Code := Ord('&')
        else if Ent = 'quot' then
          Code := Ord('"')
        else if Ent = 'apos' then
          Code := Ord('''')
        else if Ent = 'lt' then
          Code := Ord('<')
        else if Ent = 'gt' then
          Code := Ord('>')
        else if (Length(Ent) > 2) and (Ent[1] = '#') and ((Ent[2] = 'x') or (Ent[2] = 'X')) then
          Code := StrToIntDef('$' + string(Copy(Ent, 3, MaxInt)), -1)
        else if (Length(Ent) > 1) and (Ent[1] = '#') then
          Code := StrToIntDef(string(Copy(Ent, 2, MaxInt)), -1);
        if Code >= 0 then
        begin
          Inc(N);
          { only the ASCII range matters for the checks }
          if Code < 128 then
            Result[N] := AnsiChar(Code)
          else
            Result[N] := '?';
          I := J + 1;
          Continue;
        end;
      end;
    end;
    Inc(N);
    Result[N] := AValue[I];
    Inc(I);
  end;
  SetLength(Result, N);
end;

{ A relative reference or one with a harmless scheme. Browsers ignore
  control characters and spaces in the scheme, so they are dropped first. }
function IsSafeHref(const AValue: AnsiString): Boolean;
var
  V, Scheme: AnsiString;
  I, N: Integer;
begin
  V := '';
  SetLength(V, Length(AValue));
  N := 0;
  for I := 1 to Length(AValue) do
    if Ord(AValue[I]) > 32 then
    begin
      Inc(N);
      V[N] := AValue[I];
    end;
  SetLength(V, N);
  V := AnsiString(LowerCase(string(V)));
  Result := True;
  for I := 1 to Length(V) do
    if (V[I] = '/') or (V[I] = '?') or (V[I] = '#') then
      Exit
    else if V[I] = ':' then
    begin
      Scheme := Copy(V, 1, I - 1);
      Result := (Scheme = 'http') or (Scheme = 'https') or (Scheme = 'mailto') or (Scheme = 'ftp');
      Exit;
    end;
end;

{ Exactly downloadData('a', 'b', 'c') with arguments free of quotes,
  backslashes and control characters. }
function IsSafeOnClick(const AValue: AnsiString): Boolean;
const
  Head = 'downloadData(';
var
  P, K: Integer;
begin
  Result := False;
  if Copy(AValue, 1, Length(Head)) <> Head then
    Exit;
  P := Length(Head) + 1;
  for K := 1 to 3 do
  begin
    if K > 1 then
    begin
      if Copy(AValue, P, 2) <> ', ' then
        Exit;
      Inc(P, 2);
    end;
    if (P > Length(AValue)) or (AValue[P] <> '''') then
      Exit;
    Inc(P);
    while (P <= Length(AValue)) and (AValue[P] <> '''') do
    begin
      if (AValue[P] = '\') or (AValue[P] = '"') or (Ord(AValue[P]) < 32) then
        Exit;
      Inc(P);
    end;
    if P > Length(AValue) then
      Exit;
    Inc(P);
  end;
  Result := (P = Length(AValue)) and (AValue[P] = ')');
end;

function LowerAt(const ABuf: AnsiString; APos: Integer; const AText: AnsiString): Boolean;
var
  I: Integer;
  C: AnsiChar;
begin
  Result := False;
  if APos + Length(AText) - 1 > Length(ABuf) then
    Exit;
  for I := 1 to Length(AText) do
  begin
    C := ABuf[APos + I - 1];
    if (C >= 'A') and (C <= 'Z') then
      C := AnsiChar(Ord(C) + 32);
    if C <> AText[I] then
      Exit;
  end;
  Result := True;
end;

procedure WriteSegment(AOutput: TStream; const ABuf: AnsiString; AFrom, ATo: Integer);
begin
  { bytes AFrom..ATo - 1 }
  if ATo > AFrom then
    AOutput.WriteBuffer(ABuf[AFrom], ATo - AFrom);
end;

function IsHtmlWhite(C: AnsiChar): Boolean;
begin
  Result := (C = ' ') or (C = #9) or (C = #10) or (C = #12) or (C = #13);
end;

{ The page is read as HTML: attributes count only inside a start tag, so
  text of the invoice (where an apostrophe is not escaped) cannot hide one;
  comments and the contents of script and style are skipped. Everything
  else is copied unchanged. }
procedure NeutralizeActiveContent(ASource: TMemoryStream; AOutput: TStream);
var
  Buf, Tag, Name, Repl: AnsiString;
  Len, I, P, Start, NameStart, ValStart, ValStop: Integer;
  Quote: AnsiChar;
  Quoted, Safe: Boolean;
begin
  Buf := '';
  Len := Integer(ASource.Size);
  if Len = 0 then
    Exit;
  SetLength(Buf, Len);
  Move(ASource.Memory^, Buf[1], Len);
  Start := 1;
  I := 1;
  while I <= Len do
  begin
    if Buf[I] <> '<' then
    begin
      Inc(I);
      Continue;
    end;
    if LowerAt(Buf, I, '<!--') then
    begin
      P := I + 4;
      while (P <= Len) and not LowerAt(Buf, P, '-->') do
        Inc(P);
      I := P + 3;
      Continue;
    end;
    if (I < Len) and ((Buf[I + 1] = '!') or (Buf[I + 1] = '?') or (Buf[I + 1] = '/')) then
    begin
      while (I <= Len) and (Buf[I] <> '>') do
        Inc(I);
      Inc(I);
      Continue;
    end;
    { start tag: name, then the attributes up to '>' }
    P := I + 1;
    NameStart := P;
    while (P <= Len) and not IsHtmlWhite(Buf[P]) and (Buf[P] <> '>') and (Buf[P] <> '/') do
      Inc(P);
    Tag := AnsiString(LowerCase(string(Copy(Buf, NameStart, P - NameStart))));
    while P <= Len do
    begin
      while (P <= Len) and (IsHtmlWhite(Buf[P]) or (Buf[P] = '/')) do
        Inc(P);
      if (P > Len) or (Buf[P] = '>') then
        Break;
      NameStart := P;
      while (P <= Len) and not IsHtmlWhite(Buf[P]) and (Buf[P] <> '=') and (Buf[P] <> '>') do
        Inc(P);
      Name := AnsiString(LowerCase(string(Copy(Buf, NameStart, P - NameStart))));
      while (P <= Len) and IsHtmlWhite(Buf[P]) do
        Inc(P);
      if (P > Len) or (Buf[P] <> '=') then
        Continue;
      Inc(P);
      while (P <= Len) and IsHtmlWhite(Buf[P]) do
        Inc(P);
      Quoted := (P <= Len) and ((Buf[P] = '"') or (Buf[P] = ''''));
      if Quoted then
      begin
        Quote := Buf[P];
        ValStart := P + 1;
        ValStop := ValStart;
        while (ValStop <= Len) and (Buf[ValStop] <> Quote) do
          Inc(ValStop);
        P := ValStop + 1;
      end
      else
      begin
        ValStart := P;
        while (P <= Len) and not IsHtmlWhite(Buf[P]) and (Buf[P] <> '>') do
          Inc(P);
        ValStop := P;
      end;
      if (Name <> 'href') and (Name <> 'onclick') then
        Continue;
      { an attribute this long carries no reference the page needs }
      if ValStop - ValStart > 65536 then
        Safe := False
      else if Name = 'href' then
        Safe := IsSafeHref(DecodeAttr(Copy(Buf, ValStart, ValStop - ValStart)))
      else
      begin
        Repl := DecodeAttr(Copy(Buf, ValStart, ValStop - ValStart));
        { the other handlers of the page (show(this)) carry no invoice
          data; an injected value cannot change the start }
        Safe := (Copy(Repl, 1, 13) <> 'downloadData(') or IsSafeOnClick(Repl);
      end;
      if not Safe then
      begin
        if Name = 'href' then
          Repl := '#'
        else
          Repl := 'return false';
        if not Quoted then
          Repl := '"' + Repl + '"';
        WriteSegment(AOutput, Buf, Start, ValStart);
        AOutput.WriteBuffer(Repl[1], Length(Repl));
        Start := ValStop;
      end;
    end;
    I := P + 1;
    { raw text: up to the end tag }
    if (Tag = 'script') or (Tag = 'style') then
      while (I <= Len) and not LowerAt(Buf, I, '</' + Tag) do
        Inc(I);
  end;
  WriteSegment(AOutput, Buf, Start, Len + 1);
end;

procedure TLandrixEInvoiceKositVisualizer.Html(AXr: TObject; AOutput: TStream);
var
  Transformer: TLandrixXmlXsltTransformer;
  Page: TMemoryStream;
begin
  Page := TMemoryStream.Create;
  try
    Transformer := TLandrixXmlXsltTransformer.Create(TLandrixXmlXsltStylesheet(StylesheetOf('xrechnung-html.xsl')));
    try
      if FLanguage = eln_English then
        Transformer.SetParameter('lang', 'en')
      else
        Transformer.SetParameter('lang', 'de');
      try
        Transformer.Transform(TLandrixXmlXPathTree(AXr), Page);
      except
        on E: ELandrixXmlError do
          Fail(E.Message);
      end;
    finally
      Transformer.Free;
    end;
    NeutralizeActiveContent(Page, AOutput);
  finally
    Page.Free;
  end;
end;

procedure TLandrixEInvoiceKositVisualizer.WriteXr(ADocument, AOutput: TStream);
var
  Sheet: TLandrixXmlXsltStylesheet;
  Source: TLandrixXmlXPathTree;
  Transformer: TLandrixXmlXsltTransformer;
begin
  { serialized as the XR stylesheet's xsl:output says }
  Source := LoadTree(ADocument);
  try
    Sheet := TLandrixXmlXsltStylesheet(StylesheetOf(XrStylesheetName(Source)));
    Transformer := TLandrixXmlXsltTransformer.Create(Sheet);
    try
      try
        Transformer.Transform(Source, AOutput);
      except
        on E: ELandrixXmlError do
          Fail(E.Message);
      end;
    finally
      Transformer.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TLandrixEInvoiceKositVisualizer.WriteHtml(ADocument, AOutput: TStream);
var
  Xr: TObject;
begin
  Xr := XrTree(ADocument);
  try
    Html(Xr, AOutput);
  finally
    Xr.Free;
  end;
end;

procedure TLandrixEInvoiceKositVisualizer.WriteHtmlFromXr(AXr, AOutput: TStream);
var
  Xr: TLandrixXmlXPathTree;
begin
  Xr := LoadTree(AXr);
  try
    Html(Xr, AOutput);
  finally
    Xr.Free;
  end;
end;

end.
