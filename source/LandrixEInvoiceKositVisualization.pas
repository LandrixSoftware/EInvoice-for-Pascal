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

procedure TLandrixEInvoiceKositVisualizer.Html(AXr: TObject; AOutput: TStream);
var
  Transformer: TLandrixXmlXsltTransformer;
begin
  Transformer := TLandrixXmlXsltTransformer.Create(TLandrixXmlXsltStylesheet(StylesheetOf('xrechnung-html.xsl')));
  try
    if FLanguage = eln_English then
      Transformer.SetParameter('lang', 'en')
    else
      Transformer.SetParameter('lang', 'de');
    try
      Transformer.Transform(TLandrixXmlXPathTree(AXr), AOutput);
    except
      on E: ELandrixXmlError do
        Fail(E.Message);
    end;
  finally
    Transformer.Free;
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
