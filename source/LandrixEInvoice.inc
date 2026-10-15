{
  EInvoice-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and COMMERCIAL-LICENSE.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Central compiler switches. Included at the top of every unit, directly
  after the unit header.

  Defines set here:
    LANDRIXEINVOICE_UNICODE  Delphi 2009 or later: the native string is
                             UTF-16 (string = UnicodeString, Char = WideChar).
                             Not defined on Delphi 6-2007 and not on FPC. It
                             describes the native string, not whether invoice
                             text is Unicode-safe: TLandrixEInvoiceString is
                             lossless on every Delphi. }

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
  { Note 6058 "call to subroutine marked as inline is not inlined" is about
    RTL routines (Move, CompareMem) on some targets, not about our code. }
  {$WARN 6058 OFF}
{$ENDIF}

{$B-} { short-circuit boolean evaluation }
{$H+} { long strings }
{$J-} { typed constants are read-only }
{$T-} { untyped @ operator, as in default Delphi projects }
{$X+} { extended syntax }

{$IFNDEF FPC}
  {$IF CompilerVersion >= 20.0}
    { Delphi 2009+: string = UnicodeString, Char = WideChar }
    {$DEFINE LANDRIXEINVOICE_UNICODE}
  {$IFEND}
{$ENDIF}
