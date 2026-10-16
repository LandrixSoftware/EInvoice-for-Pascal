{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests for the optional value types in LandrixEInvoiceTypes. }

unit LandrixEInvoiceTestNullable;

{$I LandrixEInvoice.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  LandrixEInvoiceTypes,
  LandrixEInvoiceTestFramework;

type
  { Fields of a class start zeroed, which must mean "not set". }
  THolder = class
  private
    FViaProperty: TLandrixEInvoiceAmount;
  public
    Amount: TLandrixEInvoiceAmount;
    Date: TLandrixEInvoiceDate;
    Quantity: TLandrixEInvoiceQuantity;
    Percent: TLandrixEInvoicePercent;
    Count: TLandrixEInvoiceInteger;
    Flag: TLandrixEInvoiceBoolean;
    { a property that reads the field directly: SetValue reaches the field }
    property ViaProperty: TLandrixEInvoiceAmount read FViaProperty write FViaProperty;
  end;

procedure TestFieldsStartUnset;
var
  H: THolder;
begin
  H := THolder.Create;
  try
    Check(not H.Amount.HasValue, 'Amount field starts unset');
    Check(not H.Date.HasValue, 'Date field starts unset');
    Check(not H.Quantity.HasValue, 'Quantity field starts unset');
    Check(not H.Percent.HasValue, 'Percent field starts unset');
    Check(not H.Count.HasValue, 'Integer field starts unset');
    Check(not H.Flag.HasValue, 'Boolean field starts unset');
  finally
    H.Free;
  end;
end;

procedure TestExplicitZero;
var
  H: THolder;
begin
  H := THolder.Create;
  try
    H.Amount.SetValue(0);
    H.Date.SetValue(0);
    H.Quantity.SetValue(0);
    H.Percent.SetValue(0);
    H.Count.SetValue(0);
    H.Flag.SetValue(False);
    Check(H.Amount.HasValue, 'explicit zero amount is set');
    Check(H.Date.HasValue, 'explicit zero date is set');
    Check(H.Quantity.HasValue, 'explicit zero quantity is set');
    Check(H.Percent.HasValue, 'explicit zero percent is set');
    Check(H.Count.HasValue, 'explicit zero integer is set');
    Check(H.Flag.HasValue, 'explicit False is set');
    Check(H.Amount.Value = 0, 'explicit zero amount value');
    Check(not H.Flag.Value, 'explicit False value');
  finally
    H.Free;
  end;
end;

procedure TestValueAndClear;
var
  A: TLandrixEInvoiceAmount;
  I: TLandrixEInvoiceInteger;
begin
  A.Clear;
  A.SetValue(12.34);
  Check(A.Value = 12.34, 'Amount.Value');
  A.Clear;
  Check(not A.HasValue, 'Amount after Clear');
  Check(A.ValueOr(-1) = -1, 'Amount.ValueOr default');
  I := LandrixEInvoiceInteger(7);
  CheckEquals(7, I.Value, 'Integer.Value');
  CheckEquals(7, I.ValueOr(-1), 'Integer.ValueOr with value');
end;

procedure TestValueRaisesWhenUnset;
var
  A: TLandrixEInvoiceAmount;
  Q: TLandrixEInvoiceQuantity;
  B: TLandrixEInvoiceBoolean;
begin
  A := LandrixEInvoiceNoAmount;
  try
    A.Value;
    FailNotRaised('ELandrixEInvoiceError for unset amount');
  except
    on E: ELandrixEInvoiceError do
      Check(Pos('TLandrixEInvoiceAmount', E.Message) > 0, 'type name in message');
  end;
  Q := LandrixEInvoiceNoQuantity;
  try
    Q.Value;
    FailNotRaised('ELandrixEInvoiceError for unset quantity');
  except
    on E: ELandrixEInvoiceError do ;
  end;
  B := LandrixEInvoiceNoBoolean;
  try
    B.Value;
    FailNotRaised('ELandrixEInvoiceError for unset boolean');
  except
    on E: ELandrixEInvoiceError do ;
  end;
end;

procedure TestFactories;
var
  D: TLandrixEInvoiceDate;
  P: TLandrixEInvoicePercent;
  F: TLandrixEInvoiceBoolean;
begin
  D := LandrixEInvoiceDate(EncodeDate(2026, 10, 16));
  Check(D.HasValue and (D.Value = EncodeDate(2026, 10, 16)), 'LandrixEInvoiceDate');
  D := LandrixEInvoiceNoDate;
  Check(not D.HasValue, 'LandrixEInvoiceNoDate');
  P := LandrixEInvoicePercent(19);
  Check(P.HasValue and (P.Value = 19), 'LandrixEInvoicePercent');
  F := LandrixEInvoiceBoolean(True);
  Check(F.HasValue and F.Value, 'LandrixEInvoiceBoolean');
  Check(not LandrixEInvoiceNoPercent.HasValue, 'LandrixEInvoiceNoPercent');
  Check(not LandrixEInvoiceNoInteger.HasValue, 'LandrixEInvoiceNoInteger');
end;

procedure TestCopyIsValue;
var
  A, B: TLandrixEInvoiceAmount;
begin
  A := LandrixEInvoiceAmount(5);
  B := A;
  B.Clear;
  Check(A.HasValue, 'original keeps its value after the copy is cleared');
  Check(A.Value = 5, 'original value unchanged');
end;

procedure TestEquals;
var
  A, B: TLandrixEInvoiceAmount;
  Q1, Q2: TLandrixEInvoiceQuantity;
  X: Double;
  I: Integer;
begin
  A := LandrixEInvoiceNoAmount;
  B := LandrixEInvoiceNoAmount;
  Check(A.Equals(B), 'unset equals unset');
  B.SetValue(0);
  Check(not A.Equals(B), 'unset differs from explicit zero');
  Check(not B.Equals(A), 'explicit zero differs from unset');
  A.SetValue(0);
  Check(A.Equals(B), 'zero equals zero');
  A.SetValue(0.01);
  Check(not A.Equals(B), 'different amounts');

  Q1 := LandrixEInvoiceQuantity(0.1 + 0.2);
  Q2 := LandrixEInvoiceQuantity(0.3);
  Check(Q1.Equals(Q2), 'quantity within tolerance');
  { values built at run time: Win64 truncates Extended constants (W1066) }
  X := 3000001;
  X := X / 10000000;
  Q2.SetValue(X);
  Check(not Q1.Equals(Q2), 'quantity outside tolerance');
  Q1 := LandrixEInvoiceQuantity(1e9);
  X := 1;
  X := X / 10000;
  Q2 := LandrixEInvoiceQuantity(1e9 + X);
  Check(Q1.Equals(Q2), 'large quantity: relative tolerance');
  X := 1;
  X := X / 100;
  Q2 := LandrixEInvoiceQuantity(1e9 + X);
  Check(not Q1.Equals(Q2), 'large quantity: outside relative tolerance');
  { 1e308 - (-1e308) would overflow: must give False, not an exception }
  X := 1;
  for I := 1 to 51 do
    X := X * 1000000;
  X := X * 100;
  Q1 := LandrixEInvoiceQuantity(X);
  Q2 := LandrixEInvoiceQuantity(-X);
  Check(not Q1.Equals(Q2), 'huge values of opposite sign: no overflow');
  Q2 := LandrixEInvoiceQuantity(X);
  Check(Q1.Equals(Q2), 'huge equal values');
end;

procedure TestEqualsOtherTypes;
var
  D1, D2: TLandrixEInvoiceDate;
  P1, P2: TLandrixEInvoicePercent;
  I1, I2: TLandrixEInvoiceInteger;
  B1, B2: TLandrixEInvoiceBoolean;
  X: Double;
begin
  D1 := LandrixEInvoiceNoDate;
  D2 := LandrixEInvoiceNoDate;
  Check(D1.Equals(D2), 'Date: unset equals unset');
  D2.SetValue(EncodeDate(2026, 10, 16));
  Check(not D1.Equals(D2), 'Date: unset differs from set');
  D1.SetValue(EncodeDate(2026, 10, 16));
  Check(D1.Equals(D2), 'Date: equal');
  D1.SetValue(EncodeDate(2026, 10, 17));
  Check(not D1.Equals(D2), 'Date: different');

  P1 := LandrixEInvoiceNoPercent;
  P2 := LandrixEInvoiceNoPercent;
  Check(P1.Equals(P2), 'Percent: unset equals unset');
  P2.SetValue(19);
  Check(not P1.Equals(P2), 'Percent: unset differs from set');
  X := 19;
  X := X + X / 100000000000000; { 19 + 1.9e-13: distinct, but within the tolerance }
  P1.SetValue(X);
  Check(P1.Value <> 19, 'Percent: test value differs from 19');
  Check(P1.Equals(P2), 'Percent: equal within tolerance');
  P1.SetValue(7);
  Check(not P1.Equals(P2), 'Percent: different');

  I1 := LandrixEInvoiceNoInteger;
  I2 := LandrixEInvoiceNoInteger;
  Check(I1.Equals(I2), 'Integer: unset equals unset');
  I2.SetValue(0);
  Check(not I1.Equals(I2), 'Integer: unset differs from zero');
  I1.SetValue(0);
  Check(I1.Equals(I2), 'Integer: equal');
  I1.SetValue(1);
  Check(not I1.Equals(I2), 'Integer: different');

  B1 := LandrixEInvoiceNoBoolean;
  B2 := LandrixEInvoiceNoBoolean;
  Check(B1.Equals(B2), 'Boolean: unset equals unset');
  B2.SetValue(False);
  Check(not B1.Equals(B2), 'Boolean: unset differs from False');
  B1.SetValue(False);
  Check(B1.Equals(B2), 'Boolean: equal');
  B1.SetValue(True);
  Check(not B1.Equals(B2), 'Boolean: different');
end;

procedure TestFieldBackedProperty;
var
  H: THolder;
begin
  H := THolder.Create;
  try
    Check(not H.ViaProperty.HasValue, 'property starts unset');
    H.ViaProperty.SetValue(5);
    Check(H.ViaProperty.HasValue, 'SetValue through a field-backed property reaches the field');
    Check(H.ViaProperty.Value = 5, 'value through a field-backed property');
    H.ViaProperty.Clear;
    Check(not H.ViaProperty.HasValue, 'Clear through a field-backed property');
  finally
    H.Free;
  end;
end;

{ Delphi 13 Win64 passes objects of exactly 8 bytes wrongly as value or
  const parameters; none of the optional value types may have that size. }
procedure TestNoEightByteObjects;
begin
  Check(SizeOf(TLandrixEInvoiceAmount) <> 8, 'SizeOf(TLandrixEInvoiceAmount) <> 8');
  Check(SizeOf(TLandrixEInvoiceDate) <> 8, 'SizeOf(TLandrixEInvoiceDate) <> 8');
  Check(SizeOf(TLandrixEInvoiceQuantity) <> 8, 'SizeOf(TLandrixEInvoiceQuantity) <> 8');
  Check(SizeOf(TLandrixEInvoicePercent) <> 8, 'SizeOf(TLandrixEInvoicePercent) <> 8');
  Check(SizeOf(TLandrixEInvoiceInteger) <> 8, 'SizeOf(TLandrixEInvoiceInteger) <> 8');
  Check(SizeOf(TLandrixEInvoiceBoolean) <> 8, 'SizeOf(TLandrixEInvoiceBoolean) <> 8');
end;

{ The Win64 defect showed up as a wrong const parameter: pass every type
  through a const parameter and read it back. }
function IntegerOf(const X: TLandrixEInvoiceInteger): Integer;
begin
  Result := X.ValueOr(-1);
end;

function BooleanOf(const X: TLandrixEInvoiceBoolean): Boolean;
begin
  Result := X.HasValue and X.Value;
end;

procedure TestConstParameters;
begin
  CheckEquals(42, IntegerOf(LandrixEInvoiceInteger(42)), 'Integer through a const parameter');
  CheckEquals(-1, IntegerOf(LandrixEInvoiceNoInteger), 'unset Integer through a const parameter');
  Check(BooleanOf(LandrixEInvoiceBoolean(True)), 'Boolean through a const parameter');
  Check(not BooleanOf(LandrixEInvoiceBoolean(False)), 'False through a const parameter');
end;

procedure Register;
begin
  RegisterTest('Nullable.FieldsStartUnset', TestFieldsStartUnset);
  RegisterTest('Nullable.ExplicitZero', TestExplicitZero);
  RegisterTest('Nullable.ValueAndClear', TestValueAndClear);
  RegisterTest('Nullable.ValueRaisesWhenUnset', TestValueRaisesWhenUnset);
  RegisterTest('Nullable.Factories', TestFactories);
  RegisterTest('Nullable.CopyIsValue', TestCopyIsValue);
  RegisterTest('Nullable.Equals', TestEquals);
  RegisterTest('Nullable.EqualsOtherTypes', TestEqualsOtherTypes);
  RegisterTest('Nullable.FieldBackedProperty', TestFieldBackedProperty);
  RegisterTest('Nullable.NoEightByteObjects', TestNoEightByteObjects);
  RegisterTest('Nullable.ConstParameters', TestConstParameters);
end;

end.
