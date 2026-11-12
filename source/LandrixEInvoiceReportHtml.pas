{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ What the report writers share: the language of the labels, the
  sanitizing of text from outside (characters XML does not allow become
  U+FFFD) and a builder for HTML pages that are also well-formed XML
  (LandrixEInvoiceValidationReport, LandrixEInvoiceValidationHtml, later
  the rendering of the invoice).
  DE: Was die Bericht-Writer gemeinsam nutzen: die Sprache der
  Beschriftungen, die Bereinigung von Text von aussen (Zeichen, die XML
  nicht erlaubt, werden U+FFFD) und einen Baustein fuer HTML-Seiten, die
  zugleich wohlgeformtes XML sind (LandrixEInvoiceValidationReport,
  LandrixEInvoiceValidationHtml, spaeter die Darstellung der Rechnung). }

{ API: internal. May change in any release; use the facade LandrixEInvoice
  or the stable units instead.
  DE: API: intern. Kann sich in jeder Version aendern; stattdessen die
  Fassade LandrixEInvoice oder die stabilen Units verwenden. }

unit LandrixEInvoiceReportHtml;

{$I LandrixEInvoice.inc}

interface

uses
  Classes,
  LandrixEInvoiceTypes;

type
  { The language of the labels of a report.
    DE: Die Sprache der Beschriftungen eines Berichts. }
  TLandrixEInvoiceReportLanguage = (eln_English, eln_German);

  { Writes an HTML page as UTF-8 to a stream: trusted markup as it is, text
    from outside sanitized and escaped (& < > " and CR as references, so the
    page stays well-formed XML and keeps its CRs). Remembers whether
    anything was sanitized.
    DE: Schreibt eine HTML-Seite als UTF-8 in einen Stream: vertrauenswuerdiges
    Markup, wie es ist, Text von aussen bereinigt und maskiert (& < > " und CR
    als Referenzen, damit die Seite wohlgeformtes XML bleibt und ihre CRs
    behaelt). Merkt sich, ob etwas bereinigt wurde. }
  TLandrixEInvoiceHtmlBuilder = class(TObject)
  private
    FOut: TStream;
    FLanguage: TLandrixEInvoiceReportLanguage;
    FSanitized: Boolean;
  public
    { AOut is not owned.
      DE: AOut gehoert dem Aufrufer. }
    constructor Create(AOut: TStream; ALanguage: TLandrixEInvoiceReportLanguage);
    { Trusted markup (ASCII, labels with character references), written as
      it is.
      DE: Vertrauenswuerdiges Markup (ASCII, Beschriftungen mit
      Zeichenreferenzen), so geschrieben, wie es ist. }
    procedure Raw(const S: AnsiString);
    { Text from outside: sanitized (LandrixEInvoiceReportSanitize) and
      escaped; usable in content and in double-quoted attribute values (an
      apostrophe is not escaped).
      DE: Text von aussen: bereinigt (LandrixEInvoiceReportSanitize) und
      maskiert; fuer Inhalt und Attributwerte in doppelten Anfuehrungszeichen
      (ein Apostroph wird nicht maskiert). }
    procedure Text(const S: TLandrixEInvoiceString);
    { A number as text. DE: Eine Zahl als Text. }
    procedure Int(AValue: Integer);
    { The language of the page. DE: Die Sprache der Seite. }
    property Language: TLandrixEInvoiceReportLanguage read FLanguage;
    { True once Text replaced a character.
      DE: True, sobald Text ein Zeichen ersetzt hat. }
    property Sanitized: Boolean read FSanitized;
  end;

{ S with every character XML 1.0 does not allow (control characters other
  than TAB, LF, CR; U+FFFE, U+FFFF; a surrogate without its partner)
  replaced by U+FFFD; ASanitized becomes True if one was replaced.
  DE: S, in dem jedes Zeichen, das XML 1.0 nicht erlaubt
  (Steuerzeichen ausser TAB, LF, CR; U+FFFE, U+FFFF; ein Surrogat ohne
  Partner), durch U+FFFD ersetzt ist; ASanitized wird True, wenn eines
  ersetzt wurde. }
function LandrixEInvoiceReportSanitize(const S: TLandrixEInvoiceString; var ASanitized: Boolean): TLandrixEInvoiceString;

implementation

uses
  SysUtils,
  LandrixXmlBase;

function LandrixEInvoiceReportSanitize(const S: TLandrixEInvoiceString; var ASanitized: Boolean): TLandrixEInvoiceString;
var
  I, N: Integer;
  C: Cardinal;
begin
  Result := S;
  N := Length(S);
  I := 1;
  while I <= N do
  begin
    C := Ord(S[I]);
    if (C >= $D800) and (C <= $DBFF) and (I < N) and (Ord(S[I + 1]) >= $DC00) and (Ord(S[I + 1]) <= $DFFF) then
      Inc(I, 2)
    else
    begin
      if not ((C = 9) or (C = 10) or (C = 13) or ((C >= $20) and (C <= $D7FF)) or
              ((C >= $E000) and (C <= $FFFD))) then
      begin
        Result[I] := WideChar($FFFD);
        ASanitized := True;
      end;
      Inc(I);
    end;
  end;
end;

{ --- TLandrixEInvoiceHtmlBuilder ----------------------------------------- }

constructor TLandrixEInvoiceHtmlBuilder.Create(AOut: TStream; ALanguage: TLandrixEInvoiceReportLanguage);
begin
  inherited Create;
  FOut := AOut;
  FLanguage := ALanguage;
end;

procedure TLandrixEInvoiceHtmlBuilder.Raw(const S: AnsiString);
begin
  if S <> '' then
    FOut.WriteBuffer(PAnsiChar(S)^, Length(S));
end;

{ the replacement of C in text, '' if C stays; CR becomes a reference, or
  parsers and browsers would turn it into LF }
function EscapeOf(C: WideChar): AnsiString;
begin
  case C of
    '&':
      Result := '&amp;';
    '<':
      Result := '&lt;';
    '>':
      Result := '&gt;';
    '"':
      Result := '&quot;';
    #13:
      Result := '&#13;';
  else
    Result := '';
  end;
end;

procedure TLandrixEInvoiceHtmlBuilder.Text(const S: TLandrixEInvoiceString);
var
  Clean, Escaped: TLandrixEInvoiceString;
  Utf8: TLandrixXmlUtf8;
  Rep: AnsiString;
  I, J, K, N: Integer;
begin
  Clean := LandrixEInvoiceReportSanitize(S, FSanitized);
  { the length first, then one string: appending per character would copy
    the whole text each time (quadratic for long texts) }
  N := 0;
  for I := 1 to Length(Clean) do
  begin
    Rep := EscapeOf(Clean[I]);
    if Rep = '' then
      Inc(N)
    else
      Inc(N, Length(Rep));
  end;
  if N = Length(Clean) then
    Escaped := Clean
  else
  begin
    Escaped := '';
    SetLength(Escaped, N);
    J := 1;
    for I := 1 to Length(Clean) do
    begin
      Rep := EscapeOf(Clean[I]);
      if Rep = '' then
      begin
        Escaped[J] := Clean[I];
        Inc(J);
      end
      else
        for K := 1 to Length(Rep) do
        begin
          Escaped[J] := WideChar(Ord(Rep[K]));
          Inc(J);
        end;
    end;
  end;
  Utf8 := LandrixEInvoiceStringToUtf8(Escaped);
  if Utf8 <> '' then
    FOut.WriteBuffer(PAnsiChar(Utf8)^, Length(Utf8));
end;

procedure TLandrixEInvoiceHtmlBuilder.Int(AValue: Integer);
begin
  Text(TLandrixEInvoiceString(IntToStr(AValue)));
end;

end.
