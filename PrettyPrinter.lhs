Copyright 2009 Jake Wheat

The pretty printer which prints parse tree nodes from Grammar.lhs
It uses the hughes pj pretty printer

> module PrettyPrinter (
>                       --convert a sql parse tree to text
>                       printSql
>                       --convert a single expression parse node to text
>                      ,printExpression
>                      )
>     where

> import Text.PrettyPrint
> import Data.List (stripPrefix)
> import Data.Maybe
> import Tree

================================================================================

Public functions

> printSql :: [Statement] -> String
> printSql ast = render $ vcat (map convStatement ast) <> text "\n"

> printExpression :: Expression -> String
> printExpression = render . convExp


================================================================================

Conversion routines - convert Sql asts into Docs
= Statements

> convStatement :: Statement -> Doc

== selects

> convStatement s@(Select _ _ _ _ _) =
>   convSelectFragment True s <> statementEnd
> convStatement s@(CombineSelect _ _ _) =
>   convSelectFragment True s <> statementEnd

> convStatement (Values expss) = convValues expss <> statementEnd

== dml

> convStatement (Insert tb atts idata rt) =
>   text "insert into" <+> text tb
>   <+> maybeConv (\x -> parens (hcatCsvMap text x)) atts
>   $+$ convSelectFragment True idata
>   $+$ convReturning rt
>   <> statementEnd

> convStatement (Update tb scs wh rt) = text "update" <+> text tb <+> text "set"
>                                    <+> hcatCsvMap convSetClause scs
>                                    <+> convWhere wh
>                                    $+$ convReturning rt
>                                    <> statementEnd

> convStatement (Delete tbl wh rt) = text "delete from" <+> text tbl
>                                 <+> convWhere wh
>                                 $+$ convReturning rt
>                                 <> statementEnd

== ddl

> convStatement (CreateTable t atts cons) =
>     text "create table"
>     <+> text t <+> lparen

>     $+$ nest 2 (vcat (csv (map convAttDef atts ++ map convCon cons)))
>     $+$ rparen <> statementEnd

> convStatement (CreateFunction lang name args retType qt body vol) =
>     text "create function" <+> text name
>     <+> parens (hcatCsvMap convParamDef args)
>     <+> text "returns" <+> convExp retType <+> text "as" <+> text qt
>     $+$ convFnBody body
>     $+$ text qt <+> text "language"
>     <+> text (case lang of
>                         Sql -> "sql"
>                         Plpgsql -> "plpgsql")
>     <+> text (case vol of
>                        Volatile -> "volatile"
>                        Stable -> "stable"
>                        Immutable -> "immutable")
>     <> statementEnd
> convStatement (DropFunction name types) =
>   text "drop function" <+> text name
>   <> parens (hcatCsvMap text types) <> statementEnd

> convStatement (CreateView name sel) =
>     text "create view" <+> text name <+> text "as"
>     $+$ nest 2 (convSelectFragment True sel) <> statementEnd

> convStatement (CreateDomain name tp ex) =
>     text "create domain" <+> text name <+> text "as"
>     <+> text tp <+> checkExp ex <> statementEnd

> convStatement (CreateType name atts) =
>     text "create type" <+> text name <+> text "as" <+> lparen
>     $+$ nest 2 (vcat (csv
>           (map (\(TypeAttDef n t) -> text n <+> text t)  atts)))
>     $+$ rparen <> statementEnd

== plpgsql

> convStatement NullStatement = text "null" <> statementEnd

> convStatement (Assignment name val) =
>     text name <+> text ":=" <+> convExp val <> statementEnd

> convStatement (Return ex) =
>     text "return" <+> maybeConv convExp ex <> statementEnd

> convStatement (ReturnNext ex) =
>     text "return" <+> text "next" <+> convExp ex <> statementEnd


> convStatement (Raise rt st exps) =
>     text "raise"
>     <+> case rt of
>                 RNotice -> text "notice"
>                 RException -> text "exception"
>                 RError -> text "error"
>     <+> quotes (text st)
>     <> (if not (null exps)
>          then
>            comma
>            <+> csvExp exps
>          else empty)
>     <> statementEnd

> convStatement (ForSelectStatement i sel stmts) =
>     text "for" <+> text i <+> text "in"
>     <+> convSelectFragment True sel <+> text "loop"
>     $+$ convNestedStatements stmts
>     $+$ text "end loop" <> statementEnd

> convStatement (ForIntegerStatement var st en stmts) =
>     text "for" <+> text var <+> text "in"
>     <+> convExp st <+> text ".." <+> convExp en <+> text "loop"
>     $+$ convNestedStatements stmts
>     $+$ text "end loop" <> statementEnd

> convStatement (WhileStatement ex stmts) =
>     text "while" <+> convExp ex <+> text "loop"
>     $+$ convNestedStatements stmts
>     $+$ text "end loop" <> statementEnd

> convStatement (Perform f@(FunCall _ _)) =
>     text "perform" <+> convExp f <> statementEnd
> convStatement (Perform x) =
>    error $ "convStatement not supported for " ++ show x

> convStatement (Copy x) =
>     text "copy" <+> text x

> convStatement (If conds els) =
>    text "if" <+> (convCond $ head conds)
>    $+$ vcat (map (\c -> text "elseif" <+> convCond c) $ tail conds)
>    $+$ maybeConv (\e -> text "else" $+$ convNestedStatements e) els
>    $+$ text "end if" <> statementEnd
>     where
>       convCond (ex, sts) = convExp ex <+> text "then"
>                            $+$ convNestedStatements sts
> convStatement (Execute s) = text "execute" <+> convExp s <> statementEnd

> statementEnd :: Doc
> statementEnd = semi <> newline

================================================================================

= Statement components

== selects

> convSelectFragment :: Bool -> Statement -> Doc
> convSelectFragment writeSelect (Select l tb wh ord lim) =
>   text (if writeSelect then "select" else "") <+> convSelList l
>   $+$ nest 2 (
>     maybeConv convFrom tb
>     $+$ convWhere wh)
>   <+> maybeConv (\exps -> text "order by" <+> (hcatCsvMap convExp exps)) ord
>   <+> maybeConv (\lm -> text "limit" <+> convExp lm) lim
> convSelectFragment writeSelect (CombineSelect tp s1 s2) =
>   convSelectFragment writeSelect s1
>   $+$ (case tp of
>          Except -> text "except"
>          Union -> text "union"
>          Intersect -> text "intersect")
>   $+$ convSelectFragment True s2
> convSelectFragment _ (Values expss) = convValues expss

> convSelectFragment _ a = error $ "no convSelectFragment for " ++ show a

> convFrom :: From -> Doc
> convFrom (From tr) = text "from" <+> convTref tr

> convTref :: TableRef -> Doc
> convTref (Tref f) = text f
> convTref (TrefAlias f a) = text f <+> text a
> convTref (JoinedTref t1 nat jt t2 ex) =
>     convTref t1
>     $+$ case nat of
>           True -> text "natural"
>           False -> empty
>     <+> text (case jt of
>                       Inner -> "inner"
>                       Cross -> "cross"
>                       LeftOuter -> "left outer"
>                       RightOuter -> "right outer"
>                       FullOuter -> "full outer")
>     <+> text "join"
>     <+> convTref t2
>     <+> maybeConv (\e -> nest 2 (convJoinExpression e)) ex
> convTref (SubTref sub alias) =
>     parens (convSelectFragment True sub)
>     <+> text "as" <+> text alias
> convTref (TrefFun f@(FunCall _ _)) = convExp f
> convTref (TrefFun x) =
>     error $ "node not supported in function tref: " ++ show x
> convTref (TrefFunAlias f@(FunCall _ _) a) =
>     convExp f <+> text "as" <+> text a
> convTref (TrefFunAlias x _) =
>     error $ "node not supported in function tref: " ++ show x

> convJoinExpression :: JoinExpression -> Doc
> convJoinExpression (JoinOn e) = text "on" <+> convExp e
> convJoinExpression (JoinUsing ids) =
>   text "using" <+> parens (hcatCsvMap text ids)

> convWhere :: Maybe Where -> Doc
> convWhere (Just (Where ex)) = text "where" <+> convExp ex
> convWhere Nothing = empty

> convSelList :: SelectList -> Doc
> convSelList (SelectList ex into) =
>   hcatCsvMap convSelItem ex
>   <+> maybeConv (\i -> text "into" <+> hcatCsvMap text i) into

> convSelItem :: SelectItem -> Doc
> convSelItem (SelectItem ex nm) = (convExp ex) <+> text "as" <+> text nm
> convSelItem (SelExp e) = convExp e

> convValues :: [[Expression]] -> Doc
> convValues expss = text "values"
>                    $$ nest 2 (vcat (csv $ map
>                                     (\es -> parens (csvExp es)) expss))


== ddl

> convReturning :: Maybe SelectList -> Doc
> convReturning l = case l of
>                 Nothing -> empty
>                 Just ls -> nest 2 (text "returning" <+> convSelList ls)

> convSetClause :: SetClause -> Doc
> convSetClause (SetClause att ex) = text att <+> text "=" <+> convExp ex

> convAttDef :: AttributeDef -> Doc
> convAttDef (AttributeDef n t def cons) =
>   text n <+> text t
>   <+> maybeConv (\e -> text "default" <+> convExp e) def
>   <+> hsep (map (\e -> (case e of
>                           NullConstraint -> text "null"
>                           NotNullConstraint -> text "not null"
>                           InlineCheckConstraint ew ->
>                               text "check" <+> parens (convExp ew)
>                           InlineUniqueConstraint -> text "unique"
>                   )) cons)

> checkExp :: Maybe Expression -> Doc
> checkExp c = maybeConv (\e -> text "check" <+> convExp e) c

> convCon :: Constraint -> Doc
> convCon (UniqueConstraint c) = text "unique" <+> parens (hcatCsvMap text c)

 >                 | PrimaryKeyConstraint [String]
 >                 | CheckConstraint (Maybe String) Expression
 >                 | ReferenceConstraint [String] [String]

== plpgsql

> convFnBody :: FnBody -> Doc
> convFnBody (SqlFnBody sts) = convNestedStatements sts
> convFnBody (PlpgsqlFnBody decls sts) =
>     (if not (null decls)
>           then
>             text "declare"
>             $+$ nest 2 (vcat $ map convVarDef decls)
>           else empty)
>     $+$ text "begin"
>     $+$ convNestedStatements sts
>     $+$ text "end;"

> convParamDef :: ParamDef -> Doc
> convParamDef (ParamDef n t) = text n <+> text t
> convParamDef  (ParamDefTp t) = text t

> convVarDef :: VarDef -> Doc
> convVarDef (VarDef n t v) =
>   text n <+> text t <+>  maybeConv (\x -> text ":=" <+> convExp x) v <> semi

> convNestedStatements :: [Statement] -> Doc
> convNestedStatements s = nest 2 (vcat $ map convStatement s)

= Expressions

> convExp :: Expression -> Doc
> convExp (Identifier i) = text i
> convExp (IntegerL n) = integer n
> convExp (StringL s) = quotes $ text $ replace "'" "''" s
> convExp (StringLD t s) = tag <> text s <> tag
>     where tag = text "$" <> text t <> text "$"

> convExp (FunCall i as) = text i <> parens (csvExp as)

> convExp (BinOpCall op a b) =
>   parens (convExp a <+> text (binOpToSymbol op) <+> convExp b)

> convExp (UnOpCall op a) =
>     case op of
>           Not -> parens (text (unOpToSymbol op) <+> convExp a)
>           SetOf -> text (unOpToSymbol op) <+> convExp a
>           IsNull -> parens (convExp a <+> text (unOpToSymbol op))
>           IsNotNull -> parens (convExp a <+> text (unOpToSymbol op))


> convExp (BooleanL b) = bool b
> convExp (InPredicate att t lst) =
>   convExp att <+> (if not t then text "not" else empty) <+> text "in"
>   <+> parens (case lst of
>                        InList expr -> csvExp expr
>                        InSelect sel -> convSelectFragment True sel)
> convExp (ScalarSubQuery s) = parens (convSelectFragment True s)
> convExp NullL = text "null"
> convExp (ArrayL es) = text "array" <> brackets (csvExp es)
> convExp (WindowFn fn partition order) =
>   convExp fn <+> text "over"
>   <+> (if (isJust partition) || (isJust order)
>        then
>           parens (maybeConv (\x -> text "partition by"
>                                    <+> csvExp x) partition
>                   <+> maybeConv (\x -> text "order by"
>                                        <+> csvExp x) order)
>        else empty)
> convExp (Case whens els) = text "case"
>                            $+$ nest 2 (vcat (map convWhen whens)
>                              $+$ case els of
>                                    Nothing -> empty
>                                    Just (Else e) -> text "else" <+> convExp e)
>                            $+$ text "end"
> convExp (PositionalArg a) = text "$" <> int a
> convExp (Exists s) = text "exists" <+> parens (convSelectFragment True s)
> convExp (Row r) = text "row" <> parens (hcatCsvMap convExp r)

> convWhen :: When -> Doc
> convWhen (When ex1 ex2) =
>   text "when" <+> convExp ex1 <+> text "then" <+> convExp ex2


= Utils

convert a list of expressions to horizontal csv

> csvExp :: [Expression] -> Doc
> csvExp = hcatCsvMap convExp

run conversion function if Just, return empty if nothing

> maybeConv :: (t -> Doc) -> Maybe t -> Doc
> maybeConv f c =
>     case c of
>       Nothing -> empty
>       Just a -> f a

> csv :: [Doc] -> [Doc]
> csv = punctuate comma

> hcatCsv :: [Doc] -> Doc
> hcatCsv = hcat . csv

map the converter ex over a list
then hcatcsv the results

> hcatCsvMap :: (a -> Doc) -> [a] -> Doc
> hcatCsvMap ex = hcatCsv . map ex

> bool :: Bool -> Doc
> bool b = if b then text "true" else text "false"

> newline :: Doc
> newline = text "\n"

> replace :: (Eq a) => [a] -> [a] -> [a] -> [a]
> replace _ _ [] = []
> replace old new xs@(y:ys) =
>   case stripPrefix old xs of
>     Nothing -> y : replace old new ys
>     Just ys' -> new ++ replace old new ys'
