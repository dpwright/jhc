--------------------------------------------------------------------------------
{-| Module      :  Seq
    Copyright   :  (c) Daan Leijen 2002
    License     :  BSD-style

    Maintainer  :  daan@cs.uu.nl
    Stability   :  provisional
    Portability :  portable

  An implementation of John Hughes's efficient catenable sequence type. A lazy sequence
  @Seq a@ can be concatenated in /O(1)/ time. After
  construction, the sequence in converted in /O(n)/ time into a list.

  Modified by John Meacham for use in jhc
-}
---------------------------------------------------------------------------------}
module Seq( -- * Type
            Seq
            -- * Operators
          , (<>)

            -- * Construction
          , empty
          , single
          , singleton
          , cons
          , append

            -- * Conversion
          , toList
          , fromList
          ) where

import Data.Monoid
import Monad
import Control.Monad.Writer as W

{--------------------------------------------------------------------
  Operators
--------------------------------------------------------------------}
infixr 5 <>

-- | /O(1)/. Append two sequences, see 'append'.
(<>) :: Seq a -> Seq a -> Seq a
s <> t
  = append s t

{--------------------------------------------------------------------
  Type
--------------------------------------------------------------------}
-- | Sequences of values @a@.
newtype Seq a = Seq ([a] -> [a])
    deriving(Monoid)

{--------------------------------------------------------------------
  Construction
--------------------------------------------------------------------}
-- | /O(1)/. Create an empty sequence.
empty :: Seq a
empty
  = Seq (\ts -> ts)

-- | /O(1)/. Create a sequence of one element.
single :: a -> Seq a
single x
  = Seq (\ts -> x:ts)

-- | /O(1)/. Create a sequence of one element.
singleton :: a -> Seq a
singleton x = single x  

-- | /O(1)/. Put a value in front of a sequence.
cons :: a -> Seq a -> Seq a
cons x (Seq f)
  = Seq (\ts -> x:f ts)

-- | /O(1)/. Append two sequences.
append :: Seq a -> Seq a -> Seq a
append (Seq f) (Seq g)
  = Seq (\ts -> f (g ts))


{--------------------------------------------------------------------
  Conversion
--------------------------------------------------------------------}
-- | /O(n)/. Convert a sequence to a list.
toList :: Seq a -> [a]
toList (Seq f)
  = f []

-- | /O(n)/. Create a sequence from a list.
fromList :: [a] -> Seq a
fromList xs
  = Seq (\ts -> xs++ts)


tell x = W.tell (Seq.singleton x)
tells xs = W.tell (Seq.fromList xs)

--instance Monoid (Seq.Seq a) where
--    mempty = Seq.empty
--    mappend = (Seq.<>)

concat :: Seq (Seq a) -> Seq a 
concat (Seq f) = (foldr Seq.append Seq.empty (f [])) 

instance Functor Seq.Seq where
    --fmap f xs = Seq.fromList (map f (Seq.toList xs))
    fmap f (Seq xs) = Seq (\ts -> map f (xs []) ++ ts )

instance Monad Seq.Seq where
    --a >>= b  = mconcat ( fmap b (Seq.toList a))
    a >>= b  = Seq.concat (fmap b a)
    return x = Seq.single x
    fail _ = Seq.empty

instance MonadPlus Seq.Seq where
    mplus = mappend
    mzero = Seq.empty




