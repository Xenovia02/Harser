module Main where

import qualified Data.Map as M
import System.IO
import System.Exit

import Harser.Char
import Harser.Combinators
import Harser.Parser
import Harser.Utilities


type Map = M.Map String Double

type Parser' a = Parser String Map a


data Expr
    = Var String
    | Num Double
    | Add Expr Expr
    | Mul Expr Expr


expr :: Parser' (Map, Expr)
expr = do
    ex <- oper <?> letExpr
    st <- getState
    return (st, ex)


num :: Parser' Expr
num = Num <$> (fractional <?> (fromInteger <$> integral))


iden :: Parser' String
iden = (:) <$> letter <*> zeroOrMore alnum


var :: Parser' Expr
var = Var <$> iden


term :: Parser' Expr
term = var <?> num <?> parens (letExpr <?> oper)


assign :: Parser' ()
assign = do
    c <- iden
    _ <- wrap skipws (char '=')
    n <- num
    fmapState (M.insert c (eval M.empty n))


letExpr :: Parser' Expr
letExpr = do
    _ <- lexeme $ string "let"
    _ <- splits (wrap skipws (char ';')) assign
    _ <- spaces
    _ <- string "in"
    skipws *> oper


oper :: Parser' Expr
oper = add <?> mul


add :: Parser' Expr
add = do
    le <- term
    _ <- wrap skipws (char '+')
    ri <- oper <?> term
    return $ Add le ri


mul :: Parser' Expr
mul = do
    le <- term
    _ <- wrap skipws (char '*')
    ri <- oper <?> term
    return $ Mul le ri


eval :: Map -> Expr -> Double
eval m e = case e of
    (Var c)     -> case M.lookup c m of
        (Nothing) -> error "unknown variable"
        (Just n)  -> n
    (Num n)     -> n
    (Add le ri) -> (eval m le) + (eval m ri)
    (Mul le ri) -> (eval m le) * (eval m ri)


inlnPrompt :: String -> IO String
inlnPrompt p = do
    _ <- putStr p
    _ <- hFlush stdout
    getLine


-- TODO: associativity is not correct
main :: IO ()
main = hSetEcho stdin False >> (loop M.empty)


loop :: Map -> IO ()
loop mp = inlnPrompt "~>>" >>= (\inp -> case inp of
    "exit"  -> exitSuccess
    "clear" -> loop M.empty
    _       -> case parse expr inp mp of
        (Failure e)      -> (putStrLn $ "!>> " ++ e) >> loop mp
        (Success (m, e)) -> do
            case e of
                (Var c) -> case M.lookup c m of
                    (Nothing) -> putStrLn "!>> unknown variable"
                    (Just n)  -> putStrLn $ "=>> " ++ show n
                _       -> putStrLn $ "=>> " ++ show (eval m e)
            loop m)
