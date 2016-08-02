{-# LANGUAGE OverloadedStrings #-}
import Test.Hspec
import Data.Maybe

import Server
import Ecumenical

main :: IO ()
main = hspec $ do
    describe "reqUri" $ do
        it "is Nothing for an invalid HTTP GET request" $ do
            reqUri "FOO" `shouldBe` Nothing
        it "is Nothing for an HTTP request that is not GET" $ do
            reqUri "POST / HTTP/1.1" `shouldBe` Nothing
        it "is Nothing for a non-1.1 HTTP request" $ do
            reqUri "GET /foo HTTP/1.0" `shouldBe` Nothing
        it "is Nothing for a GET request with extra spaces after the URI" $ do
            reqUri "GET /bar  HTTP/1.1" `shouldBe` Nothing
        it "is the request URI for a valid GET request" $ do
            reqUri "GET / HTTP/1.1" `shouldBe` Just "/"
        it "captures several path elements" $ do
            reqUri "GET /foo/bar/baz/ HTTP/1.1" `shouldBe` Just "/foo/bar/baz/"
        it "captures query parameters" $ do
            reqUri "GET /x?a=1&b=2 HTTP/1.1" `shouldBe` Just "/x?a=1&b=2"

    describe "HTTP response" $ do
        it "has correct zero content-length" $ do
            response "200 OK" "" `shouldBe`
                "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
        it "has correct non-zero content-length" $ do
            response "404 Not Found" "Eff off." `shouldBe`
                "HTTP/1.1 404 Not Found\r\nContent-Length: 8\r\n\r\nEff off."

    describe "Ecumenical DB" $ do
        -- There is no longer any need to run hlog from a directory ℵ₀ levels
        -- beneath root in your filesystem.
        it "does not traverse paths in keys" $ do
            result <- retrieve "../../../../../../../../../../../../etc/passwd"
            result `shouldBe` Nothing
        it "returns Nothing for a key that has not been added" $ do
            result <- retrieve "nothing"
            result `shouldBe` Nothing

    describe "Mockable DB" $ do
        it "actually works" $ do
            let env "arbitrary key" = Just "foof"
            result <- runMockFS
                (retrieve "arbitrary key") env
            result `shouldBe` Just "foof"
