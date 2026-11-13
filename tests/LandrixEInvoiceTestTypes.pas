{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for LandrixEInvoiceTypes: string and character type, UTF-8
  conversion. Expected values are built from code units or bytes, never from
  non-ASCII literals. }

unit LandrixEInvoiceTestTypes;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixXmlBase,
  LandrixEInvoiceTypes,
  LandrixEInvoiceTestFramework;

{ "Lodz" with Polish letters: U+0141 U+00F3 U+0064 U+017A }
function LodzUtf8: TLandrixXmlUtf8;
begin
  Result := Utf8Bytes([$C5, $81, $C3, $B3, $64, $C5, $BA]);
end;

procedure TestVersion;
begin
  CheckEqualsStr('0.9.0-beta.1', LandrixEInvoiceVersion, 'LandrixEInvoiceVersion');
end;

procedure TestCharSize;
var
  S: TLandrixEInvoiceString;
  C: TLandrixEInvoiceChar;
begin
  CheckEquals(2, SizeOf(TLandrixEInvoiceChar), 'UTF-16 code unit');
  S := 'xA';
  C := S[2];
  CheckEquals(Ord('A'), Ord(C), 'indexing yields TLandrixEInvoiceChar');
end;

procedure TestAsciiRoundTrip;
var
  S: TLandrixEInvoiceString;
begin
  S := LandrixEInvoiceUtf8ToString(Utf8Bytes([$52, $45, $2D, $31]));
  CheckEqualsInvoiceStr('RE-1', S, 'ASCII from UTF-8');
  CheckEqualsUtf8(Utf8Bytes([$52, $45, $2D, $31]), LandrixEInvoiceStringToUtf8(S),
    'ASCII to UTF-8');
end;

procedure TestEmpty;
begin
  CheckEquals(0, Length(LandrixEInvoiceUtf8ToString(Utf8Bytes([]))), 'empty from UTF-8');
  CheckEquals(0, Length(LandrixEInvoiceStringToUtf8('')), 'empty to UTF-8');
end;

procedure TestPolishRoundTrip;
var
  S: TLandrixEInvoiceString;
begin
  { lossless on every compiler, whatever the system code page }
  S := LandrixEInvoiceUtf8ToString(LodzUtf8);
  CheckEqualsInvoiceStr(Wide([$0141, $00F3, $0064, $017A]), S, 'UTF-16 code units');
  CheckEqualsUtf8(LodzUtf8, LandrixEInvoiceStringToUtf8(S), 'lossless round trip');
end;

procedure TestSupplementaryRoundTrip;
var
  U: TLandrixXmlUtf8;
  S: TLandrixEInvoiceString;
begin
  { U+1F600, four bytes in UTF-8, a surrogate pair in UTF-16 }
  U := Utf8Bytes([$F0, $9F, $98, $80]);
  S := LandrixEInvoiceUtf8ToString(U);
  CheckEqualsInvoiceStr(Wide([$D83D, $DE00]), S, 'surrogate pair');
  CheckEqualsUtf8(U, LandrixEInvoiceStringToUtf8(S), 'round trip');
end;

procedure TestInvalidUtf8;
begin
  try
    LandrixEInvoiceUtf8ToString(Utf8Bytes([$41, $FF]));
    FailNotRaised('ELandrixXmlError for malformed UTF-8');
  except
    on E: ELandrixXmlError do
      Check(E.Code = xecInvalidUnicode, 'malformed UTF-8: xecInvalidUnicode');
  end;
end;

procedure TestLoneSurrogate;
begin
  try
    LandrixEInvoiceStringToUtf8(Wide([$41, $D800]));
    FailNotRaised('ELandrixXmlError for lone surrogate');
  except
    on E: ELandrixXmlError do
      Check(E.Code = xecInvalidUnicode, 'lone surrogate: xecInvalidUnicode');
  end;
end;

procedure TestStringList;
var
  L: TLandrixEInvoiceStringList;
  I: Integer;
begin
  L := TLandrixEInvoiceStringList.Create;
  try
    CheckEquals(0, Integer(L.Count), 'empty');
    for I := 1 to 10 do
      L.Add(Wide([Word($41 + I), $0142]));
    CheckEquals(10, Integer(L.Count), 'ten items');
    Check(L[0] = Wide([$42, $0142]), 'first item, non-Latin-1 kept');
    L[1] := 'x';
    Check(L[1] = 'x', 'set item');
    L.Delete(0);
    CheckEquals(9, Integer(L.Count), 'after delete');
    Check(L[0] = 'x', 'items moved up');
    try
      L.Delete(9);
      FailNotRaised('ELandrixEInvoiceError for index 9 of 9');
    except
      on ELandrixEInvoiceError do ;
    end;
    L.Clear;
    CheckEquals(0, Integer(L.Count), 'after Clear');
  finally
    L.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Types.Version', TestVersion);
  RegisterTest('Types.CharSize', TestCharSize);
  RegisterTest('Types.AsciiRoundTrip', TestAsciiRoundTrip);
  RegisterTest('Types.Empty', TestEmpty);
  RegisterTest('Types.PolishRoundTrip', TestPolishRoundTrip);
  RegisterTest('Types.SupplementaryRoundTrip', TestSupplementaryRoundTrip);
  RegisterTest('Types.InvalidUtf8', TestInvalidUtf8);
  RegisterTest('Types.LoneSurrogate', TestLoneSurrogate);
  RegisterTest('Types.StringList', TestStringList);
end;

end.
