{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

program XsltProbe;

{ Loads and runs XSLT stylesheets with the LandrixXML XSLT engine: the
  load test for the KoSIT report stylesheets and the XRechnung
  visualization on every toolchain.
  Usage:
    XsltProbe load <xsl>...
      compiles each stylesheet; prints "ok <file>" or "error <file>
      <class> <message>".
    XsltProbe chain <output> <xml> <xsl>...
      runs the stylesheets one after the other, each on the result of the
      one before, and writes the result of the last one to <output> as its
      xsl:output says; prints "ok <output>" or the error.
    XsltProbe visualize <xsl-folder> <output-folder> [-en] <xml>...
      runs the XRechnung visualization (LandrixEInvoiceKositVisualization,
      German unless -en) and writes <output-folder>/<name>.xr.xml and
      <name>.html; prints "ok <name>" or the error. Used by
      tools/kosit/viz-oracle.py.
  Exit code 0 when everything worked, 1 otherwise. }

{$I LandrixEInvoice.inc}
{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  SysUtils,
  Classes,
  LandrixXmlXPathTree,
  LandrixXmlXslt,
  LandrixEInvoiceReportHtml,
  LandrixEInvoiceKositVisualization;

var
  Failed: Boolean;

procedure Report(const AWhat: string; E: Exception);
begin
  WriteLn('error ', AWhat, ' ', E.ClassName, ' ', E.Message);
  Failed := True;
end;

procedure LoadAll;
var
  I: Integer;
  Sheet: TLandrixXmlXsltStylesheet;
begin
  for I := 2 to ParamCount do
  begin
    Sheet := TLandrixXmlXsltStylesheet.Create;
    try
      try
        Sheet.LoadFromFile(ParamStr(I));
        WriteLn('ok ', ParamStr(I));
      except
        on E: Exception do
          Report(ParamStr(I), E);
      end;
    finally
      Sheet.Free;
    end;
  end;
end;

procedure Chain;
var
  I: Integer;
  Sheet: TLandrixXmlXsltStylesheet;
  Transformer: TLandrixXmlXsltTransformer;
  Source, Target: TLandrixXmlXPathTree;
  Output: TFileStream;
begin
  Source := TLandrixXmlXPathTree.Create;
  try
    try
      Source.LoadFromFile(ParamStr(3));
      for I := 4 to ParamCount do
      begin
        Sheet := TLandrixXmlXsltStylesheet.Create;
        try
          Sheet.LoadFromFile(ParamStr(I));
          Transformer := TLandrixXmlXsltTransformer.Create(Sheet);
          try
            if I < ParamCount then
            begin
              Target := TLandrixXmlXPathTree.Create;
              try
                Transformer.TransformToTree(Source, Target);
              except
                Target.Free;
                raise;
              end;
              Source.Free;
              Source := Target;
            end
            else
            begin
              Output := TFileStream.Create(ParamStr(2), fmCreate);
              try
                Transformer.Transform(Source, Output);
              finally
                Output.Free;
              end;
            end;
          finally
            Transformer.Free;
          end;
        finally
          Sheet.Free;
        end;
      end;
      WriteLn('ok ', ParamStr(2));
    except
      on E: Exception do
        Report(ParamStr(2), E);
    end;
  finally
    Source.Free;
  end;
end;

procedure Visualize;
var
  I: Integer;
  V: TLandrixEInvoiceKositVisualizer;
  Dir, Base: string;
  Input, Output: TFileStream;
begin
  V := TLandrixEInvoiceKositVisualizer.Create;
  try
    V.Folder := ParamStr(2);
    Dir := IncludeTrailingPathDelimiter(ParamStr(3));
    for I := 4 to ParamCount do
      if ParamStr(I) = '-en' then
        V.Language := eln_English
      else
      begin
        Base := Dir + ChangeFileExt(ExtractFileName(ParamStr(I)), '');
        try
          Input := TFileStream.Create(ParamStr(I), fmOpenRead or fmShareDenyWrite);
          try
            Output := TFileStream.Create(Base + '.xr.xml', fmCreate);
            try
              V.WriteXr(Input, Output);
            finally
              Output.Free;
            end;
            Input.Position := 0;
            Output := TFileStream.Create(Base + '.html', fmCreate);
            try
              V.WriteHtml(Input, Output);
            finally
              Output.Free;
            end;
          finally
            Input.Free;
          end;
          WriteLn('ok ', ExtractFileName(ParamStr(I)));
        except
          on E: Exception do
            Report(ExtractFileName(ParamStr(I)), E);
        end;
      end;
  finally
    V.Free;
  end;
end;

begin
  Failed := False;
  if (ParamCount >= 2) and (ParamStr(1) = 'load') then
    LoadAll
  else if (ParamCount >= 4) and (ParamStr(1) = 'chain') then
    Chain
  else if (ParamCount >= 4) and (ParamStr(1) = 'visualize') then
    Visualize
  else
  begin
    WriteLn('usage: XsltProbe load <xsl>... | XsltProbe chain <output> <xml> <xsl>... | ' +
      'XsltProbe visualize <xsl-folder> <output-folder> [-en] <xml>...');
    Failed := True;
  end;
  if Failed then
    Halt(1);
end.
