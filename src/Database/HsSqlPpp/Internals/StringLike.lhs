

> {-# LANGUAGE TypeSynonymInstances,FlexibleInstances #-}
> module Database.HsSqlPpp.Internals.StringLike where

> import qualified Data.Text as T
> import qualified Data.Text.Lazy as TL
> import Data.String

> class (IsString a, Eq a) => StringLike a where
>     pack :: String -> a

> instance StringLike String where
>     pack = id
> instance StringLike T.Text where
>     pack = T.pack
> instance StringLike TL.Text where
>     pack = TL.pack
