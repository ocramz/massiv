{-# LANGUAGE BangPatterns          #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE PatternSynonyms #-}
-- |
-- Module      : Data.Massiv.Array.Unsafe
-- Copyright   : (c) Alexey Kuleshevich 2018-2019
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Massiv.Array.Unsafe
  ( -- * Creation
  -- , unsafeGenerateArray
  -- , unsafeGenerateArrayP
  -- * Indexing
    Sz(SafeSz)
  , unsafeIndex
  , unsafeLinearIndex
  , unsafeLinearIndexM
  -- * Manipulations
  , unsafeBackpermute
  , unsafeResize
  , unsafeExtract
  , unsafeTransform
  , unsafeTransform2
  -- ** Deprecated
  , unsafeTraverse
  , unsafeTraverse2
  -- * Slicing
  , unsafeSlice
  , unsafeOuterSlice
  , unsafeInnerSlice
  -- * Mutable interface
  , unsafeThaw
  , unsafeFreeze
  , unsafeNew
  , unsafeRead
  , unsafeLinearRead
  , unsafeWrite
  , unsafeLinearWrite
  , unsafeLinearSet
  -- ** Atomic Operations
  , unsafeAtomicReadIntArray
  , unsafeAtomicWriteIntArray
  , unsafeAtomicModifyIntArray
  , unsafeAtomicAddIntArray
  , unsafeAtomicSubIntArray
  , unsafeAtomicAndIntArray
  , unsafeAtomicNandIntArray
  , unsafeAtomicOrIntArray
  , unsafeAtomicXorIntArray
  , unsafeCasIntArray
  ) where

import           Data.Massiv.Array.Delayed.Pull       (D)
import           Data.Massiv.Array.Manifest.Primitive
import           Data.Massiv.Core.Common
import           Data.Massiv.Core.Index.Internal      (Sz (SafeSz))


unsafeBackpermute :: (Source r' ix' e, Index ix) =>
                     Sz ix -> (ix -> ix') -> Array r' ix' e -> Array D ix e
unsafeBackpermute !sz ixF !arr =
  makeArray (getComp arr) sz $ \ !ix -> unsafeIndex arr (ixF ix)
{-# INLINE unsafeBackpermute #-}


unsafeTraverse
  :: (Source r ix' e', Index ix)
  => Sz ix
  -> ((ix' -> e') -> ix -> e)
  -> Array r ix' e'
  -> Array D ix e
unsafeTraverse sz f arr1 =
  makeArray (getComp arr1) sz (f (unsafeIndex arr1))
{-# INLINE unsafeTraverse #-}
{-# DEPRECATED unsafeTraverse "In favor of more general `unsafeTransform'`" #-}


unsafeTraverse2
  :: (Source r1 ix1 e1, Source r2 ix2 e2, Index ix)
  => Sz ix
  -> ((ix1 -> e1) -> (ix2 -> e2) -> ix -> e)
  -> Array r1 ix1 e1
  -> Array r2 ix2 e2
  -> Array D ix e
unsafeTraverse2 sz f arr1 arr2 =
  makeArray (getComp arr1 <> getComp arr2) sz (f (unsafeIndex arr1) (unsafeIndex arr2))
{-# INLINE unsafeTraverse2 #-}
{-# DEPRECATED unsafeTraverse2 "In favor of more general `unsafeTransform2'`" #-}

-- | Same `Data.Array.transform'`, except no bounds checking is performed, thus making it faster,
-- but unsafe.
--
-- @since 0.3.0
unsafeTransform ::
     (Source r' ix' e', Index ix)
  => (Sz ix' -> (Sz ix, a))
  -> (a -> (ix' -> e') -> ix -> e)
  -> Array r' ix' e'
  -> Array D ix e
unsafeTransform getSz get arr = makeArray (getComp arr) sz (get a (unsafeIndex arr))
  where
    (sz, a) = getSz (size arr)
{-# INLINE unsafeTransform #-}

-- | Same `Data.Array.transform2'`, except no bounds checking is performed, thus making it faster,
-- but unsafe.
--
-- @since 0.3.0
unsafeTransform2 ::
     (Source r1 ix1 e1, Source r2 ix2 e2, Index ix)
  => (Sz ix1 -> Sz ix2 -> (Sz ix, a))
  -> (a -> (ix1 -> e1) -> (ix2 -> e2) -> ix -> e)
  -> Array r1 ix1 e1
  -> Array r2 ix2 e2
  -> Array D ix e
unsafeTransform2 getSz get arr1 arr2 =
  makeArray (getComp arr1 <> getComp arr2) sz (get a (unsafeIndex arr1) (unsafeIndex arr2))
  where
    (sz, a) = getSz (size arr1) (size arr2)
{-# INLINE unsafeTransform2 #-}
