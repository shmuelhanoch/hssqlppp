Copyright 2009 Jake Wheat

This file contains some generic utility stuff

> {-# OPTIONS_HADDOCK hide #-}

> module Database.HsSqlPpp.Utils where

> import Data.Maybe
> import Data.List
> import Data.Either
> import Control.Arrow
> import Control.Monad.Error

> errorWhen :: (Error a) =>
>            Bool -> a -> Either a ()
> errorWhen cond e = do
>     when (cond) $ Left e

> liftME :: a -> Maybe b -> Either a b
> liftME d m = case m of
>                Nothing -> Left d
>                Just b -> Right b

> both :: (a->b) -> (a,a) -> (b,b)
> both fn = (fn *** fn)

> eitherToMaybe :: Either a b -> Maybe b
> eitherToMaybe (Left _) = Nothing
> eitherToMaybe (Right b) = Just b

> fromRight :: b -> Either a b -> b
> fromRight b (Left _) = b
> fromRight _ (Right r) = r

> replace :: (Eq a) => [a] -> [a] -> [a] -> [a]
> replace _ _ [] = []
> replace old new xs@(y:ys) =
>   case stripPrefix old xs of
>     Nothing -> y : replace old new ys
>     Just ys' -> new ++ replace old new ys'


> split :: Char -> String -> [String]
> split _ ""                =  []
> split c s                 =  let (l, s') = break (== c) s
>                            in  l : case s' of
>                                            [] -> []
>                                            (_:s'') -> split c s''
