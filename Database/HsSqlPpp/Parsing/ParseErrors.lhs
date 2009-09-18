Copyright 2009 Jake Wheat

convert error messages to show source text fragment with little hat,
plus output error location in emacs friendly format.

> {-# OPTIONS_HADDOCK hide #-}

> module Database.HsSqlPpp.Parsing.ParseErrors (convertToExtendedError, ExtendedError(..)) where

> import Text.Parsec

> showEr :: ParseError -> String -> String -> String
> showEr er fn src =
>     let  pos  = errorPos er
>          lineNo = sourceLine pos
>          ls = lines src
>          line = safeGet ls(lineNo - 1)
>          prelines = map (safeGet ls) [(lineNo - 5) .. (lineNo - 2)]
>          postlines = map (safeGet ls) [lineNo .. (lineNo + 5)]
>          colNo = sourceColumn pos
>          highlightLine = replicate (colNo - 1) ' ' ++ "^"
>          errorHighlightText = prelines
>                               ++ [line, highlightLine, "ERROR HERE"]
>                               ++ postlines
>     in "\n---------------------\n" ++ show er
>        ++ "\nFILENAMESTUFF:\n" ++ fn ++ ":" ++ show lineNo ++ ":" ++ show colNo
>        ++ "\n------------\nCheck it out:\n"
>        ++ unlines (trimLines errorHighlightText)
>        ++ "\n-----------------\n"
>     where
>       safeGet a i = if i < 0 || i >= length a
>                       then ""
>                       else a !! i
>       trimLines = trimStartLines . reverse . trimStartLines . reverse
>       trimStartLines = dropWhile (=="")

give access to the nicer error text via Show

> data ExtendedError = ExtendedError ParseError String

> instance Show ExtendedError where
>    show (ExtendedError _ x) = x

> convertToExtendedError :: Either ParseError b
>                        -> String
>                        -> String
>                        -> Either ExtendedError b
> convertToExtendedError f fn src =
>      case f of
>             Left er -> Left $ ExtendedError er (showEr er fn src)
>             Right l -> Right l
