Copyright 2010 Jake Wheat

Prepend view definitions for a simplified catalog.

> {-# LANGUAGE QuasiQuotes #-}
>
> module Database.HsSqlPpp.Examples.Extensions.SimplifiedCatalog
>     where
>
> --import Data.Generics
> --import Data.Generics.Uniplate.Data
>
> import Database.HsSqlPpp.Ast
> import Database.HsSqlPpp.Annotation
> --import Database.HsSqlPpp.Utils.Here
> --import Database.HsSqlPpp.Examples.Extensions.ExtensionsUtils
> import Database.HsSqlPpp.Examples.Extensions.SQLCode

> simplifiedCatalogSt :: [Statement]
> simplifiedCatalogSt =
>     [$sqlQuote|
\begin{code}

create view base_relvars as
  select relname as relvar_name from pg_class where relnamespace =
    (select oid from pg_namespace where nspname = 'public')
    and relkind = 'r';

create view base_relvar_attributes as
  select attname as attribute_name,
         typname as type_name,
         relname as relvar_name
    from pg_attribute inner join pg_class on (attrelid = pg_class.oid)
    inner join pg_type on (atttypid = pg_type.oid)
    inner join base_relvars on (relname = base_relvars.relvar_name)
    where attnum >= 1;

/*
scalars here since we are using the base relvar attributes table
to try to only show scalar types which are used and not the vast
array that pg comes with. This is a bit of a hack job, probably
a bit inaccurate
*/

create view scalars as
--   select typname as scalar_name from pg_type
--     where typtype in ('b', 'd')
--     and typnamespace =
--     (select oid from pg_namespace where nspname='public')
--   union
  select distinct type_name as scalar_name
    from base_relvar_attributes;

create view base_relvar_keys as
  select conname as constraint_name, relvar_name
    from pg_constraint
  natural inner join
    (select oid as conrelid, relname as relvar_name from pg_class) as b
  where contype in('p', 'u') and connamespace =
    (select oid from pg_namespace where nspname='public');

create view base_relvar_key_attributes as
  select constraint_name, attribute_name from
    (select conname as constraint_name, conrelid,
      conkey[generate_series] as attnum
      from pg_constraint
      cross join generate_series(1,
        (select max(array_upper(conkey, 1)) from pg_constraint))
      where contype in('p', 'u') and connamespace =
        (select oid from pg_namespace where nspname='public')
      and generate_series between
      array_lower(conkey, 1) and
      array_upper(conkey, 1)) as a
  natural inner join
    (select oid as conrelid, relname as relvar_name from pg_class) as b
  natural inner join
    (select attrelid as conrelid, attname as attribute_name,
    attnum from pg_attribute) as c
--  order by constraint_name
  ;

create view operators as
  select proname as operator_name from pg_proc
    where pronamespace = (select oid from pg_namespace
                           where nspname = 'public');

create view operator_source as
  select proname as operator_name, prosrc as source from pg_proc
    where pronamespace = (select oid from pg_namespace
                           where nspname = 'public');

create view triggers as
  select relname as relvar_name, tgname as trigger_name,
    proname as operator_name
    from pg_trigger
    inner join pg_class on (tgrelid = pg_class.oid)
    inner join pg_proc on (tgfoid = pg_proc.oid)
    inner join base_relvars on (relname = base_relvars.relvar_name)
    where not tgisconstraint; -- eliminate pg internal triggers

create view views as
  select viewname as view_name, definition
    from pg_views
    where schemaname = 'public';

create view view_attributes as
  select attname as attribute_name,
         typname as type_name,
         relname as relvar_name
    from pg_attribute inner join pg_class on (attrelid = pg_class.oid)
    inner join pg_type on (atttypid = pg_type.oid)
    inner join views on (relname = view_name)
    where attnum >= 1;

/*
== constraints
*/

/*create table database_constraints (
  constraint_name text,
  expression text
);*/

/*
== all database objects
*/

create view all_database_objects as
  select 'scalar' as object_type,
    scalar_name as object_name from scalars
  union select 'base_relvar' as object_type,
    relvar_name as object_name from base_relvars
  union select 'operator' as object_type,
    operator_name as object_name from operators
  union select 'view' as object_type,
    view_name as object_name from views
  union select 'trigger' as object_type,
    trigger_name as object_name from triggers
  /*union select 'database_constraint' as object_type,
    constraint_name as object_name from database_constraints*/;
insert into system_implementation_objects
  (object_name, object_type) values
  ('all_database_objects', 'view');
create view public_database_objects as
  select object_name,object_type from all_database_objects
  /*except
  select object_name,object_type from system_implementation_objects*/;

/*create view object_orders as
  select 'scalar'::text as object_type, 0 as object_order
  union select 'database_constraint', 1
  union select 'base_relvar', 2
  union select 'operator', 3
  union select 'view', 4
  union select 'trigger', 5
;*/

\end{code}
>     |]

> simplifiedCatalog :: [Statement] -> [Statement]
> simplifiedCatalog xs = simplifiedCatalogSt ++ xs