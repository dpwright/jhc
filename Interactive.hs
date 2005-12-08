module Interactive(Interactive.interact) where

import Data.Monoid
import IO(stdout)
import List(sort)
import Maybe
import Monad
import qualified Data.Map as Map
import Text.Regex
import Text.Regex.Posix(regcomp,regExtended)


import DataConstructors
import Doc.DocLike
import Doc.PPrint
import Doc.Pretty
import FrontEnd.HsParser(parseHsStmt)
import FrontEnd.KindInfer
import FrontEnd.ParseMonad
import FrontEnd.Rename
import GenUtil
import Ho
import HsPretty()
import HsSyn
import Warning
import Name.Name
import Options
import qualified Text.PrettyPrint.HughesPJ as PP
import Representation
import TypeSynonyms(showSynonym)
import Util.Interact

printDoc doc = do
    displayIO stdout (renderPretty 0.9 80 doc)
    putStrLn ""

grep_opts = [
 "f - match normal value",
 "C - match data constructor",
 "T - match type constructor",
 "L - match class"
 ]

nameTag :: NameType -> Char
nameTag TypeConstructor = 'T'
nameTag DataConstructor = 'C'
nameTag ClassName = 'L'
nameTag Val = 'f'
nameTag _ = '?'

data InteractiveState = IS {
    stateHo :: Ho,
    stateInteract :: Interact
    }

interact :: Ho -> IO ()
interact ho = mre where
    mre = case optStmts options of
        [] -> go
        xs -> runInteractions initialInteract (concatMap lines $ reverse xs) >> exitSuccess
    go = do
        putStrLn "--------------------------------------------------------------"
        putStrLn "Welcome to the jhc interactive experience. use :help for help."
        putStrLn versionString
        putStrLn "--------------------------------------------------------------"
        beginInteraction initialInteract
    initialInteract = emptyInteract { interactSettables = ["prog", "args"], interactVersion = versionString, interactCommands = commands, interactExpr = do_expr }
    dataTable = hoDataTable ho
    commands = [cmd_mods,cmd_grep]
    cmd_mods = InteractCommand { commandName = ":mods", commandHelp = "mods currently loaded modules", commandAction = do_mods }
    do_mods act _ _ = do
        printDoc $ fillSep (map tshow $ Map.keys $  hoExports ho)
        return act
    cmd_grep = InteractCommand { commandName = ":grep", commandHelp = "show names matching a regex", commandAction = do_grep }
    do_grep act _ "" = do
        putStrLn ":grep [options] <regex>"
        putStrLn "Valid options:"
        putStr $ unlines grep_opts
        return act
    do_grep act _ arg = do
        let (opt,reg) = case simpleUnquote arg of
                [x] -> ("TCLf",x)
                xs -> f "" xs where
            f opt [x] = (opt,x)
            f opt ~(x:xs) = f (x ++ opt) xs
            f _ _ = undefined
        rx <- catch ( Just `fmap` regcomp reg regExtended) (\_ -> return Nothing)
        case rx of
            Nothing -> putStrLn $ "Invalid regex: " ++ arg
            --Just rx -> mapM_ putStrLn $ sort [ nameTag (nameType v):' ':show v <+> "::" <+> ptype v  | v <- Map.keys (hoDefs ho), isJust (matchRegex rx (show v)), nameTag (nameType v) `elem` opt ]
            Just rx -> mapM_ putStrLn $ sort [ pshow opt v  | v <- Map.keys (hoDefs ho), isJust (matchRegex rx (show v)), nameTag (nameType v) `elem` opt ]
        return act
    ptype x | Just r <- pprintTypeOfCons dataTable x = r
    ptype k | Just r <- Map.lookup k (hoAssumps ho) = show (pprint r:: PP.Doc)
    ptype x | nameType x == ClassName = hsep (map kindShow $ kindOfClass x (hoKinds ho))
    ptype x = "UNKNOWN: " ++ show (nameType x,x)
    do_expr :: Interact -> String -> IO Interact
    do_expr act s = case parseStmt s of
        Left m -> putStrLn m >> return act
        Right e -> executeStatement IS { stateHo = ho, stateInteract = act } e >> return act
    pshow _opt v
        | Just d <- showSynonym (show . (pprint :: HsType -> PP.Doc) ) v (hoTypeSynonyms ho) = nameTag (nameType v):' ':d
        | otherwise = nameTag (nameType v):' ':show v <+> "::" <+> ptype v

kindShow Star = "*"
kindShow x = parens (pprint x)

parseStmt ::  Monad m => String -> m HsStmt
parseStmt s = case runParserWithMode ParseMode { parseFilename = "(jhci)" } parseHsStmt  s  of
                      ParseOk _ e -> return e
                      ParseFailed sl err -> fail $ show sl ++ ": " ++ err


executeStatement :: InteractiveState -> HsStmt -> IO ()
executeStatement IS { stateHo = ho } stmt = do
    defs <- calcImports ho False (Module "Prelude")
    stmt' <- renameStatement mempty defs (Module "Main") stmt
    b <- printIOErrors
    when (not b) $ putStrLn (show stmt')
executeStatement _ HsLetStmt {} = putStrLn "let statements not yet supported"
executeStatement _ HsGenerator {} = putStrLn "generators not yet supported"
executeStatement _ (HsQualifier e) = putStrLn (show e)


calcImports :: Monad m => Ho -> Bool -> Module -> m [(Name,[Name])]
calcImports ho qual mod = case Map.lookup mod (hoExports ho) of
    Nothing -> fail $ "calcImports: module not known " ++ show mod
    Just es -> do
        let ls = sortGroupUnderFG fst snd
                [ (n,if qual then [setModule mod n] else [setModule mod n,toUnqualified n]) | n <- es]
            ls' = concat [ zip (concat nns) (repeat [n]) | (n,nns) <- ls ]
        return $ Map.toList $ Map.map snub $ Map.fromListWith (++) ls'

