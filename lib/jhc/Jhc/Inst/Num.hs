{-# OPTIONS_JHC -fm4 -fno-prelude -fffi #-}
module Jhc.Inst.Num() where

m4_include(Jhc/Num.m4)

-- CI import Data.Word
-- CI import Data.Int
import Jhc.Num
import Jhc.Order
import Jhc.Float
import Jhc.Basics
-- CI import Jhc.Inst.Order
import Jhc.Inst.Enum
import Prelude.Text
import Jhc.Type.C

m4_define(SIGNED,{{
MkNumPrim($1,I)
MkRealPrim($1,I)
MkIntegralPrim($1)
}})

m4_define(UNSIGNED,{{
MkNumPrim($1,U)
MkRealPrim($1,U)
MkIntegralUPrim($1)
}})

UNSIGNED(Word)
UNSIGNED(Word8)
UNSIGNED(Word16)
UNSIGNED(Word32)
UNSIGNED(Word64)
UNSIGNED(WordPtr)
UNSIGNED(WordMax)

SIGNED(Int)
SIGNED(Int8)
SIGNED(Int16)
SIGNED(Int32)
SIGNED(Int64)
SIGNED(IntPtr)
SIGNED(IntMax)
SIGNED(Integer)

SIGNED(CChar)
SIGNED(CSChar)
UNSIGNED(CUChar)

SIGNED(CSize)
SIGNED(CInt)
UNSIGNED(CUInt)
UNSIGNED(CWchar)
