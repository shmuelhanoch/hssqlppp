

This module represents part of the bound names environment used in the
type checker. It doesn't cover the stuff that is contained in the
catalog (so it is slightly misnamed), but focuses only on identifiers
introduced by things like tablerefs, sub selects, plpgsql parameters
and variables, etc.

> {-# LANGUAGE DeriveDataTypeable #-}
> module Database.HsSqlPpp.Internals.TypeChecking.Environment
>     (-- * abstract environment value
>      Environment
>      -- * environment create and update functions
>     ,emptyEnvironment
>     ,isEmptyEnv
>     ,envCreateTrefEnvironment
>     ,createJoinTrefEnvironment
>      -- * environment query functions
>     ,envLookupIdentifier
>     ,envExpandStar
>     ) where

> import Data.Data
> import Data.Char
> import Data.Maybe
> import Control.Monad

> import Database.HsSqlPpp.Internals.TypesInternal
> import Database.HsSqlPpp.Internals.TypeChecking.TypeConversion
> import Database.HsSqlPpp.Internals.Catalog.CatalogInternal

---------------------------------

> -- | Represent an environment using an abstracted version of the syntax
> -- which produced the environment. This structure has all the catalog
> -- queries resolved. No attempt is made to combine environment parts from
> -- different sources, they are just stacked together, the logic for
> -- working with combined environments is in the query functions below
> data Environment =
>                  -- | represents an empty environment, makes e.g. joining
>                  -- the environments for a list of trefs in a select list
>                  -- more straightforward
>                    EmptyEnvironment
>                  -- | represents the bindings introduced by a tableref:
>                  -- the name, the public fields, the private fields
>                  | SimpleTref String [(String,Type)] [(String,Type)]
>                  | JoinTref [(String,Type)] -- join ids
>                             Environment Environment
>                    deriving (Data,Typeable,Show,Eq)



---------------------------------------------------

Create/ update functions, these are shortcuts to create environment variables,
the main purpose is to encapsulate looking up information in the
catalog and combining environment values with updates

> emptyEnvironment :: Environment
> emptyEnvironment = EmptyEnvironment

> isEmptyEnv :: Environment -> Bool
> isEmptyEnv EmptyEnvironment = True
> isEmptyEnv _ = False

> envCreateTrefEnvironment :: Catalog -> [NameComponent] -> Either [TypeError] Environment
> envCreateTrefEnvironment cat tbnm = do
>   (nm,pub,prv) <- catLookupTableAndAttrs cat tbnm
>   return $ SimpleTref nm pub prv

> -- | create an environment as two envs joined together
> createJoinTrefEnvironment :: Catalog
>                           -> Environment
>                           -> Environment
>                           -> Maybe [NameComponent] -- | join ids: empty if cross join
>                                                    -- nothing for natural join
>                           -> Either [TypeError] Environment
> createJoinTrefEnvironment cat tref0 tref1 jsc = do
>   -- todo: handle natural join case
>   let jids = maybe (error "natural join ids") (map (nnm . (:[]))) jsc
>   jts <- forM jids $ \i -> do
>            t0 <- envLookupIdentifier [QNmc i] tref0
>            t1 <- envLookupIdentifier [QNmc i] tref1
>            fmap (i,) $ resolveResultSetType cat [t0,t1]
>   -- todo: check type compatibility
>   return $ JoinTref jts tref0 tref1



-------------------------------------------------------


The main hard work is done in the query functions: so the idea is that
the update functions create environment values which contain the
context free contributions of each part of the ast to the current
environment, and these query functions do all the work of resolving
implicit correlation names, ambigous identifiers, etc.

> nnm :: [NameComponent] -> String
> nnm [] = error "Env: empty name component"
> nnm ns = case last ns of
>            Nmc n -> map toLower n
>            QNmc n -> n

-----------------------------------------------------

> envLookupIdentifier :: [NameComponent] -> Environment -> Either [TypeError] Type
> envLookupIdentifier nmc EmptyEnvironment = Left [UnrecognisedIdentifier $ nnm nmc]

> envLookupIdentifier nmc (SimpleTref _nm pub _prv) =
>   let n = nnm nmc
>   in case lookup n pub of
>        Just t -> return t
>        Nothing -> Left [UnrecognisedIdentifier n]


> envLookupIdentifier nmc (JoinTref jids env0 env1) =
>   let n = nnm nmc
>   in case (lookup n jids
>           ,envLookupIdentifier nmc env0
>           ,envLookupIdentifier nmc env1) of
>        -- not sure this is right, errors are ignored, hope
>        -- this doesn't hide something
>        (Just t, _, _) -> Right t
>        (_,Left _, Left _) -> Left [UnrecognisedIdentifier n]
>        (_,Right t, Left _) -> Right t
>        (_,Left _, Right t) -> Right t
>        (_,Right _, Right _) -> Left [AmbiguousIdentifier n]

-------------------------------------------------------

> envExpandStar :: Maybe NameComponent -> Environment -> Either [TypeError] [(String,Type)]
> envExpandStar nmc  EmptyEnvironment = Left [BadStarExpand]

> envExpandStar nmc (SimpleTref nm pub prv)
>   | case nmc of
>              Nothing -> True
>              Just x -> nnm [x] == nm = Right pub
>   | otherwise = case nmc of
>                    Nothing -> Left [BadStarExpand]
>                    Just n -> Left [UnrecognisedCorrelationName $ nnm [n]]

> envExpandStar nmc (JoinTref jts env0 env1) = do
>   -- have to get the columns in the right order:
>   -- join columns first (have to get the types of these also - should
>   -- probably do that > -- in createjointrefenv since that is where the
>   -- type compatibility is checked
>   -- then the env0 columns without any join cols
>   -- then the env1 columns without any join cols
>   t0 <- noJs env0
>   t1 <- noJs env1
>   return $ jts ++ t0 ++ t1
>   where
>     noJs e = do
>              se <- envExpandStar nmc e
>              return $ filter ((`notElem` (map fst jts)) . fst) se

