Copyright 2009 Jake Wheat

Set of tests for the extensions

> {-# LANGUAGE RankNTypes,FlexibleContexts #-}

> module Database.HsSqlPpp.Tests.ExtensionTests (extensionTests) where

> import Test.HUnit
> import Test.Framework
> import Test.Framework.Providers.HUnit
> import Data.Char
> import Control.Monad.Error
> --import Debug.Trace

> import Database.HsSqlPpp.Parsing.Parser
> import Database.HsSqlPpp.Ast.Annotation
> import Database.HsSqlPpp.Extensions.ChaosExtensions
> import Database.HsSqlPpp.Ast.Ast
> import Database.HsSqlPpp.Ast.Annotation
> --import Database.HsSqlPpp.PrettyPrinter.PrettyPrinter

> extensionTests :: Test.Framework.Test
> extensionTests =
>   testGroup "extensionTests" (mapCheckExtension [
>     t rewriteCreateVars
>       "select create_var('varname','vartype');"
>       "create table varname_table (\n\
>       \  varname vartype);\n\
>       \create function get_varname() returns vartype as $a$\n\
>       \  select * from varname_table;\n\
>       \$a$ language sql stable;\n\
>       \create function check_con_varname_table_varname_key() returns boolean as $a$\n\
>       \begin\n\
>       \  return true;\n\
>       \end;\n\
>       \$a$ language plpgsql stable;\n\
>       \create function check_con_varname_table_01_tuple() returns boolean as $a$\n\
>       \begin\n\
>       \  return true;\n\
>       \end;\n\
>       \$a$ language plpgsql stable;"
>    ,t addReadonlyTriggers
>       "select set_relvar_type('stuff','readonly');"
>       "create function check_stuff_d_readonly() returns trigger as $a$\n\
>       \begin\n\
>       \  if (not (false)) then\n\
>       \    raise exception 'delete on base_relvar_metadata violates transition constraint base_relvar_metadata_d_readonly';\n\
>       \  end if;\n\
>       \return null;\n\
>       \end;\n\
>       \$a$ language plpgsql volatile;\n\
>       \create function check_stuff_i_readonly() returns trigger as $a$\n\
>       \begin\n\
>       \  if (not (false)) then\n\
>       \       raise exception 'delete on base_relvar_metadata violates transition constraint base_relvar_metadata_d_readonly';\n\
>       \  end if;\n\
>       \  return null;\n\
>       \end;\n\
>       \$a$ language plpgsql volatile;\n\
>       \create function check_stuff_u_readonly() returns trigger as $a$\n\
>       \begin\n\
>       \  if (not (false)) then\n\
>       \       raise exception 'delete on base_relvar_metadata violates transition constraint base_relvar_metadata_d_readonly';\n\
>       \  end if;\n\
>       \  return null;\n\
>       \end;\n\
>       \$a$ language plpgsql volatile;"

>    ,t createClientActionWrapper
>       "select create_client_action_wrapper('actname', $$actcall()$$);"
>       "create function action_actname() returns void as $a$\n\
>       \begin\n\
>       \  perform action_actcall();\n\
>       \end;\n\
>       \$a$ language plpgsql;"
>    ,t createClientActionWrapper
>       "select create_client_action_wrapper('actname', $$actcall('test')$$);"
>       "create function action_actname() returns void as $a$\n\
>       \begin\n\
>       \  perform action_actcall('test');\n\
>       \end;\n\
>       \$a$ language plpgsql;"
>    ,t addNotifyTriggers
>       "select set_relvar_type('stuff','data');"
>       "create function stuff_changed() returns trigger as $a$\n\
>       \begin\n\
>       \  notify stuff;\n\
>       \  return null;\n\
>       \end;\n\
>       \$a$ language plpgsql;"
>    ,t addConstraint
>       "select add_constraint('name', 'true', array['t1', 't2']);"
>       "create function check_con_name() returns boolean as $a$\n\
>       \begin\n\
>       \  return true;\n\
>       \end;\n\
>       \$a$ language plpgsql stable;"
>    ,t addKey
>       "select add_key('tbl', 'attr');"
>       "create function check_con_tbl_attr_key() returns boolean as $a$\n\
>       \begin\n\
>       \  return true;\n\
>       \end;\n\
>       \$a$ language plpgsql stable;"
>    ,t addKey
>       "select add_key('tbl', array['attr1','attr2']);"
>       "create function check_con_tbl_attr1_attr2_key() returns boolean as $a$\n\
>       \begin\n\
>       \  return true;\n\
>       \end;\n\
>       \$a$ language plpgsql stable;"
>    ,t zeroOneTuple
>       "select constrain_to_zero_or_one_tuple('tbl');"
>       "create function check_con_tbl_01_tuple() returns boolean as $a$\n\
>       \begin\n\
>       \  return true;\n\
>       \end;\n\
>       \$a$ language plpgsql stable;"


add_foreign_key
constrain zero one
add constraint

>    ])

>   where
>     t a b c = (a,b,c)
>     mapCheckExtension = map (\(a,b,c) ->  checkExtension a b c)
>     checkExtension :: (StatementList -> StatementList) -> String -> String -> Test.Framework.Test
>     checkExtension f stxt ttxt = testCase ("check " ++ stxt) $
>       case (do
>             sast <- parseSql stxt
>             let esast = f sast
>             --trace (printSql esast) $ return ()
>             tast <- parseSql ttxt
>             return (tast,esast)) of
>         Left e -> assertFailure $ show e
>         Right (ts,es) -> assertEqual "" (stripAnnotations ts) (stripAnnotations es)
