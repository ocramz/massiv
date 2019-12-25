{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
-- |
-- Module      : Data.Massiv.Array.IO.Base
-- Copyright   : (c) Alexey Kuleshevich 2018-2019
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Massiv.Array.IO.Base
  ( FileFormat(..)
  , Readable(..)
  , decode
  , Writable(..)
  , encode
  , ConvertError(..)
  , EncodeError(..)
  , DecodeError(..)
  , Sequence(..)
  , Auto(..)
  , Image
  , defaultReadOptions
  , defaultWriteOptions
  ---, encodeAuto
  , encodeError
  , convertImage
  , toProxy
  , fromMaybeEncode
  , fromEitherDecode
  , convertEither
  , MonadThrow(..)
  ) where

import Control.Exception (Exception, throw)
import Control.Monad.Catch (MonadThrow(..))
import qualified Data.ByteString as B (ByteString)
import qualified Data.ByteString.Lazy as BL (ByteString)
import Data.Default.Class (Default(..))
import Data.Massiv.Array as A
import Data.Typeable
import Graphics.Color.Pixel

type Image r cs e = Array r Ix2 (Pixel cs e)

-- | Conversion error, which is thrown when there is a mismatch between the
-- expected array type and the one supported by the file format. It is also
-- thrown upon a failure of automatic conversion between those types, in case
-- such conversion is utilized.
newtype ConvertError = ConvertError String deriving Show

instance Exception ConvertError

-- | This exception can be thrown while reading/decoding a file and indicates an
-- error in the file itself.
newtype DecodeError = DecodeError String deriving Show

instance Exception DecodeError

-- | This exception can be thrown while writing/encoding into a file and
-- indicates an error in an array that is being encoded.
newtype EncodeError = EncodeError String deriving Show

instance Exception EncodeError


-- | Generate default read options for a file format
defaultReadOptions :: FileFormat f => f -> ReadOptions f
defaultReadOptions _ = def


-- | Generate default write options for a file format
defaultWriteOptions :: FileFormat f => f -> WriteOptions f
defaultWriteOptions _ = def


-- | Special wrapper for formats that support encoding/decoding sequence of array.
newtype Sequence f = Sequence f deriving Show

newtype Auto f = Auto f deriving Show

-- | File format. Helps in guessing file format from a file extension,
-- as well as supplying format specific options during saving the file.
class (Default (ReadOptions f), Default (WriteOptions f), Show f) => FileFormat f where
  -- | Options that can be used during reading a file in this format.
  type ReadOptions f
  type ReadOptions f = ()

  -- | Options that can be used during writing a file in this format.
  type WriteOptions f
  type WriteOptions f = ()

  -- | Default file extension for this file format.
  ext :: f -> String

  -- | Other known file extensions for this file format, eg. ".jpeg", ".jpg".
  exts :: f -> [String]
  exts f = [ext f]

  -- | Checks if a file extension corresponds to the format, eg.
  -- @isFormat ".png" PNG == True@
  isFormat :: String -> f -> Bool
  isFormat e f = e `elem` exts f


instance FileFormat f => FileFormat (Auto f) where
  type ReadOptions (Auto f) = ReadOptions f
  type WriteOptions (Auto f) = WriteOptions f

  ext (Auto f) = ext f
  exts (Auto f) = exts f


-- | File formats that can be read into arrays.
class Readable f arr where

  -- | Decode a `B.ByteString` into an array. Can also return whatever left over data that
  -- was not consumed during decoding.
  --
  -- @since 0.2.0
  decodeM :: MonadThrow m => f -> ReadOptions f -> B.ByteString -> m (arr, Maybe B.ByteString)


-- | Encode an array into a `BL.ByteString`.
encode :: Writable f arr => f -> WriteOptions f -> arr -> BL.ByteString
encode f opts = either throw id . encodeM f opts
{-# DEPRECATED encode "In favor of a better `encodeM`" #-}

-- | Decode a `B.ByteString` into an Array.
decode :: Readable f arr => f -> ReadOptions f -> B.ByteString -> arr
decode f opts = either throw fst . decodeM f opts
{-# DEPRECATED decode "In favor of a better `decodeM`" #-}

-- | Arrays that can be written into a file.
class Writable f arr where

  -- | Encode an array into a `BL.ByteString`.
  --
  -- @since 0.2.0
  encodeM :: MonadThrow m => f -> WriteOptions f -> arr -> m BL.ByteString

-- | Helper function to create a `Proxy` from the value.
toProxy :: a -> Proxy a
toProxy _ = Proxy

showImageType ::
     forall r cs e. (Typeable r, ColorModel cs e)
  => Proxy (Image r cs e)
  -> String
showImageType _ =
  ("<Image " ++) .
  showsTypeRep (typeRep (Proxy :: Proxy r)) .
  (' ' :) . showsColorModelName (Proxy :: Proxy (Color cs e)) $
  ">"


-- | Encode an image using the supplied function or throw an error in case of failure.
fromMaybeEncode
  :: forall f r cs e b m. (ColorModel cs e, FileFormat f, Typeable r, MonadThrow m)
  => f -> Proxy (Image r cs e) -> Maybe b -> m b
fromMaybeEncode f imgProxy =
  \case
    Just b -> pure b
    Nothing ->
      throwM $
      ConvertError ("Format " ++ show f ++ " cannot be encoded as " ++ showImageType imgProxy)


-- | Decode an image using the supplied function or throw an error in case of failure.
fromEitherDecode ::
     forall r cs e a f m. (ColorModel cs e, FileFormat f, Typeable r, MonadThrow m)
  => f
  -> (a -> String)
  -> (a -> Maybe (Image r cs e))
  -> a
  -> m (Image r cs e)
fromEitherDecode f showCS conv eImg =
  case conv eImg of
    Nothing ->
      throwM $
      ConvertError $
      "Cannot decode " ++
      show f ++
      " image <" ++ showCS eImg ++ "> as " ++ showImageType (Proxy :: Proxy (Image r cs e))
    Just img -> pure img


-- | Convert an image using the supplied function and return ConvertError error in case of failure.
convertEither ::
     forall r cs i e a f m. (ColorSpace cs i e, FileFormat f, Typeable r, MonadThrow m)
  => f
  -> (a -> String)
  -> (a -> Maybe (Image r cs e))
  -> a
  -> m (Image r cs e)
convertEither f showCS conv eImg =
  maybe
    (throwM $
     ConvertError
       ("Cannot convert " ++
        show f ++
        " image <" ++ showCS eImg ++ "> as " ++ showImageType (Proxy :: Proxy (Image r cs e))))
    pure
    (conv eImg)


-- encodeAuto
--   :: forall f r cs e a csY eY csYA eYA csC eC csCA eCA m.
--      ( ColorSpace cs e
--      , ColorSpace csC eC
--      , ColorSpace csCA eCA
--      , ColorSpace csY eY
--      , ColorSpace csYA eYA
--      , Source r Ix2 (Pixel cs e)
--      , FileFormat f
--      , MonadThrow m
--      )
--   => f
--   -> (forall r' cs' e'. (Source r' Ix2 (Pixel cs' e'), ColorSpace cs' e') =>
--                           Image r' cs' e' -> Maybe a)
--   -> (Pixel cs e -> Pixel csY eY) -- ^ To preferred from Luma
--   -> (Pixel cs e -> Pixel csYA eYA) -- ^ To preferred from Luma with Alpha
--   -> (Pixel cs e -> Pixel csC eC) -- ^ To preferred from any color
--   -> (Pixel cs e -> Pixel csCA eCA) -- ^ To preferred from any color with Alpha
--   -> Image r cs e
--   -> m a
-- encodeAuto f enc toLuma toLumaA toColor toColorA img =
--   fromMaybeEncode f (toProxy img) $ msum
--     [ enc img
--     , do Refl <- eqT :: Maybe (cs :~: Y)
--          enc $ A.map toLuma img
--     , do Refl <- eqT :: Maybe (cs :~: YA)
--          enc $ A.map toLumaA img
--     , do Refl <- eqT :: Maybe (cs :~: RGB)
--          enc $ A.map toColor img
--     , do Refl <- eqT :: Maybe (cs :~: RGBA)
--          enc $ A.map toColorA img
--     , do Refl <- eqT :: Maybe (cs :~: HSI)
--          enc $ A.map toColor img
--     , do Refl <- eqT :: Maybe (cs :~: HSIA)
--          enc $ A.map toColorA img
--     , do Refl <- eqT :: Maybe (cs :~: YCbCr)
--          enc $ A.map toColor img
--     , do Refl <- eqT :: Maybe (cs :~: YCbCrA)
--          enc $ A.map toColorA img
--     , do Refl <- eqT :: Maybe (cs :~: CMYK)
--          enc $ A.map toColor img
--     , do Refl <- eqT :: Maybe (cs :~: CMYKA)
--          enc $ A.map toColorA img
--     , do Refl <- eqT :: Maybe (Pixel cs e :~: Pixel X Bit)
--          enc $ A.map fromPixelBinary img
--     ]

encodeError :: MonadThrow m => Either String a -> m a
encodeError = either (throwM . EncodeError) pure

convertImage ::
     ( Source r' Ix2 (Pixel cs' e')
     , Mutable r Ix2 (Pixel cs e)
     , ColorSpace cs' i' e'
     , ColorSpace cs i e
     )
  => Image r' cs' e'
  -> Image r cs e
convertImage = compute . A.map convertPixel
