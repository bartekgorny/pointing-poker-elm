module Example exposing (allsuites)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Session exposing (calcCount)

allsuites =
    describe "hahaha"
    [ test "two plus two" <|
         \_ ->
           (2+2)
           |> Expect.equal 4
       ,
      test "two plus three" <|
         \_ ->
           (3+2)
           |> Expect.equal 5
    ]
