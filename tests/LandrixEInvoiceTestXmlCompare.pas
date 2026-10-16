{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Compares two XML documents for the round-trip tests. Equivalent means:
  the same elements (namespace URI and local name) in the same order, the
  same attributes (any order) and the same text. Ignored: prefixes and
  namespace declarations, xsi attributes, comments, processing
  instructions, the document type, white-space-only text between elements,
  the XML declaration and the encoding. Elements without attributes, text
  and child elements (after this rule is applied to the children) count as
  absent, as in the syntax model, where empty text means "not present".
  Text is compared exactly. }

unit LandrixEInvoiceTestXmlCompare;

{$I LandrixEInvoice.inc}

interface

uses
  LandrixXmlBase;

{ True if both UTF-8 documents are equivalent; otherwise False and a
  description of the first difference in ADifference. }
function XmlEquivalent(const A, B: TLandrixXmlUtf8; out ADifference: string): Boolean;

implementation

uses
  SysUtils,
  LandrixXmlReader;

const
  XsiNamespace = 'http://www.w3.org/2001/XMLSchema-instance';

type
  TItemKind = (ikStart, ikEnd, ikText, ikEof);

  TItem = record
    Kind: TItemKind;
    Name: TLandrixXmlUtf8;   { namespace URI + ' ' + local name }
    Attrs: TLandrixXmlUtf8;  { sorted "uri local=value" lines }
    Text: TLandrixXmlUtf8;
    Path: string;
    Line: Integer;
  end;

  TItems = array of TItem;

  { Delivers the significant items of one document. }
  TCursor = class(TObject)
  private
    FReader: TLandrixXmlReader;
    FPending: Boolean;
    FPendingItem: TItem;
  public
    constructor Create(const S: TLandrixXmlUtf8);
    destructor Destroy; override;
    function Next: TItem;
  end;

constructor TCursor.Create(const S: TLandrixXmlUtf8);
begin
  inherited Create;
  FReader := TLandrixXmlReader.Create;
  FReader.LoadFromUtf8(S);
end;

destructor TCursor.Destroy;
begin
  FReader.Free;
  inherited;
end;

{ Attributes as sorted lines "uri local=value" (byte order), without
  namespace declarations and xsi attributes. }
function AttributeLines(R: TLandrixXmlReader): TLandrixXmlUtf8;
var
  Lines: array of TLandrixXmlUtf8;
  Count, I, J: Integer;
  Line: TLandrixXmlUtf8;
begin
  Count := 0;
  Lines := nil;
  SetLength(Lines, R.AttributeCount);
  for I := 0 to R.AttributeCount - 1 do
  begin
    if R.IsNamespaceDeclaration(I) then
      Continue;
    if R.AttributeNamespaceUriUtf8(I) = XsiNamespace then
      Continue;
    Line := R.AttributeNamespaceUriUtf8(I) + ' ' + R.AttributeLocalNameUtf8(I) +
      '=' + R.AttributeValueUtf8(I);
    J := Count;
    while (J > 0) and (Lines[J - 1] > Line) do
    begin
      Lines[J] := Lines[J - 1];
      Dec(J);
    end;
    Lines[J] := Line;
    Inc(Count);
  end;
  Result := '';
  for I := 0 to Count - 1 do
    Result := Result + Lines[I] + #10;
end;

function IsBlank(const S: TLandrixXmlUtf8): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if not (S[I] in [#9, #10, #13, ' ']) then
      Exit;
  Result := True;
end;

function TCursor.Next: TItem;
var
  Text: TLandrixXmlUtf8;
  HasText: Boolean;
begin
  if FPending then
  begin
    FPending := False;
    Result := FPendingItem;
    Exit;
  end;
  Text := '';
  HasText := False;
  while True do
  begin
    if not FReader.Read then
    begin
      Result.Kind := ikEof;
      Result.Name := '';
      Result.Attrs := '';
      Result.Text := '';
      Result.Path := '';
      Result.Line := 0;
      Exit;
    end;
    case FReader.TokenType of
      xttText, xttCData:
        begin
          Text := Text + FReader.ValueUtf8;
          HasText := True;
          Continue;
        end;
      xttStartElement, xttEndElement:
        begin
          FPendingItem.Path := FReader.ElementPath;
          FPendingItem.Line := FReader.Line;
          FPendingItem.Text := '';
          FPendingItem.Attrs := '';
          FPendingItem.Name := FReader.NamespaceUriUtf8 + ' ' + FReader.LocalNameUtf8;
          if FReader.TokenType = xttStartElement then
          begin
            FPendingItem.Kind := ikStart;
            FPendingItem.Attrs := AttributeLines(FReader);
          end
          else
            FPendingItem.Kind := ikEnd;
          { text before the element: significant unless white space only }
          if HasText and not IsBlank(Text) then
          begin
            FPending := True;
            Result.Kind := ikText;
            Result.Name := '';
            Result.Attrs := '';
            Result.Text := Text;
            Result.Path := FPendingItem.Path;
            Result.Line := FPendingItem.Line;
          end
          else
            Result := FPendingItem;
          Exit;
        end;
    else
      ; { comments, processing instructions, document type: skipped }
    end;
  end;
end;

function Describe(const I: TItem): string;
begin
  case I.Kind of
    ikStart: Result := 'start ' + LandrixXmlUtf8ToString(I.Name) + ' [' +
      LandrixXmlUtf8ToString(I.Attrs) + ']';
    ikEnd: Result := 'end ' + LandrixXmlUtf8ToString(I.Name);
    ikText: Result := 'text "' + LandrixXmlUtf8ToString(I.Text) + '"';
  else
    Result := 'end of document';
  end;
  Result := Result + ' at ' + I.Path + ' line ' + IntToStr(I.Line);
end;

{ All items of a document, ending with ikEof. An end directly after a start
  without attributes closes an empty element; both are dropped, which also
  drops parents that become empty. }
function CollectItems(const S: TLandrixXmlUtf8): TItems;
var
  C: TCursor;
  Item: TItem;
  Count: Integer;
begin
  Result := nil;
  Count := 0;
  C := TCursor.Create(S);
  try
    repeat
      Item := C.Next;
      if (Item.Kind = ikEnd) and (Count > 0) and (Result[Count - 1].Kind = ikStart) and
         (Result[Count - 1].Attrs = '') then
        Dec(Count)
      else
      begin
        if Count = Length(Result) then
          SetLength(Result, Count * 2 + 16);
        Result[Count] := Item;
        Inc(Count);
      end;
    until Item.Kind = ikEof;
  finally
    C.Free;
  end;
  SetLength(Result, Count);
end;

function XmlEquivalent(const A, B: TLandrixXmlUtf8; out ADifference: string): Boolean;
var
  LA, LB: TItems;
  I: Integer;
begin
  Result := False;
  ADifference := '';
  LA := CollectItems(A);
  LB := CollectItems(B);
  I := 0;
  repeat
    if (LA[I].Kind <> LB[I].Kind) or (LA[I].Name <> LB[I].Name) or
       (LA[I].Attrs <> LB[I].Attrs) or (LA[I].Text <> LB[I].Text) then
    begin
      ADifference := Describe(LA[I]) + ' <> ' + Describe(LB[I]);
      Exit;
    end;
    Inc(I);
  until LA[I - 1].Kind = ikEof;
  Result := True;
end;

end.
