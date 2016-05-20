{-# LANGUAGE OverloadedStrings #-}
module Lib
    ( serve
    , response
    , reqUri
    ) where

import Prelude hiding (length, intercalate, readFile)
import Data.ByteString.Char8
import Network hiding (accept)
import Network.Socket hiding (sClose, recv)
import Network.Socket.ByteString (sendAll, recv)
import Control.Concurrent
import Control.Exception
import Text.Regex.PCRE

serve :: PortNumber -> IO ()
serve port = withSocketsDo $ do
    sock <- listenOn $ PortNumber port
    loop sock

loop sock = do
    (conn, _) <- accept sock
    forkIO $ body conn
    loop sock
    where
        body conn = do
            req <- recv conn 4096

            -- Print incoming request information
            peer <- getPeerName conn
            Prelude.putStrLn $ show peer ++ ": " ++ show req
            Prelude.putStrLn $ "Requested URI: " ++ show (reqUri req)
            resp <- serveStatic req
            sendAll conn $ resp
            sClose conn

-- Serve static file
serveStatic :: ByteString -> IO ByteString
serveStatic request = case (reqUri request) of
    Nothing -> return $ response "400 NEED A DRINK" page400
    Just uri -> do
        result <- fileContents uri
        case result of
            Nothing -> return $ response "404 FECK OFF" page404
            Just garbage -> return $ response "200 ARSE" garbage

page404 :: ByteString
page404 = "<html><center><h1>404 Feck Off</h1><hr/>\
            \One last time. These packets are <em>small</em>, but the ones \
            \out there are <em>far away</em>.</html>"

page400 :: ByteString
page400 = "<html><center><h1>400 NEED A DRINK</h1><hr/>\
            \How did that <em>gobshite</em> get on the socket?!</html>"

reqUri :: ByteString -> Maybe ByteString
reqUri r = group1 $ ((r =~ pattern) :: [[ByteString]])
    where pattern = "GET /([^ ]+) HTTP/1\\.1" :: ByteString
          group1 :: [[ByteString]] -> Maybe ByteString
          group1 [[_, x]] = Just x
          group1 _ = Nothing

fileContents :: ByteString -> IO (Maybe ByteString)
fileContents path = do
    -- XXX: this annotation is annoying, please slay it
    -- XXX: also, whytf does ByteString.readFile take a [Char]???
    contents <- (try $ readFile $ unpack path) :: IO (Either IOException ByteString)
    case contents  of
        Left _ -> return Nothing
        Right text -> return $ Just text

response :: ByteString -> ByteString -> ByteString
response status body =
    intercalate "\r\n" [
          "HTTP/1.1 " `append` status
        , "Content-Length: " `append` (pack $ show $ length body)
        , ""
        , body]
