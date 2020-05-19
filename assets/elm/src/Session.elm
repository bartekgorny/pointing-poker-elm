port module Session exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Json.Encode as Encode
import Json.Decode as Decode
import Dict

main = Browser.element {init = init, view = view, update = update, subscriptions = subscriptions}

-- TYPES

type alias ReceivedVote = {nick : String, vote : Int}
type alias InternalVoteList = Dict.Dict String Int
type alias ReceivedState = {votes: InternalVoteList, showvotes: Bool, owner : String, description : String}
type alias Model = {session_id : String, nick : String, joined : Bool,
                    votes : InternalVoteList, showvotes : Bool, owner : String,
                    input_desc : String, description : String}
type alias Stats = {average : Float, count : Int}
type alias Results = {stats : Stats, aggr : Dict.Dict Int Int}

type Msg = SetNick String
           | SetDesc String
           | SendChangeNick
           | SendChangeDesc
           | SendVote Int
           | SendManage String
           | RecJoined Encode.Value
           | RecNewVote Encode.Value
           | RecFreshState Encode.Value
           | RecShowVotes Encode.Value

-- MODEL

init : String -> (Model, Cmd Msg)
init session_id =
    chooseInit "normal" session_id
--    chooseInit "test" session_id

chooseInit opt session_id =
    let i = {session_id = session_id,
             nick = "",
             joined = False,
             votes = Dict.empty,
             showvotes = False,
             owner = "",
             input_desc = "",
             description = ""} in
    case opt of
        "normal" ->
            (i, Cmd.none)
        _ ->
            ({i | nick = "abcdef",
                  showvotes = True
                  }, sendNickEvent "abcdef")

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SetNick n -> {model | nick = n}  |> newModel
        SetDesc n -> {model | input_desc = n}  |> newModel
        SendChangeNick -> (model, sendNickEvent model.nick)
        SendChangeDesc -> (model, sendDescEvent model.input_desc)
        SendVote i ->
            (addVoteToModel model {nick = model.nick, vote = i},
             sendVoteEvent i)
        SendManage action ->
            (model, sendManageEvent action)
        RecJoined _ -> {model | joined = True} |> newModel
        RecNewVote x ->
            x
            |> Decode.decodeValue decodeVote
            |> addVote model
            |> newModel
        RecFreshState x ->
            x
            |> Decode.decodeValue decodeFreshState
            |> setState model
            |> newModel
        RecShowVotes _ ->
            {model | showvotes = True} |> newModel

newModel model = (model, Cmd.none)

addVote : Model -> Result Decode.Error ReceivedVote -> Model
addVote model vote =
    case vote of
        Result.Ok v ->
            addVoteToModel model v
        e ->
            let z = Debug.log "error" e in
            model

addVoteToModel model v = {model | votes = Dict.insert v.nick v.vote model.votes}

setState model newstate =
    case newstate of
      Result.Ok ns ->
          {model | votes = ns.votes, showvotes = ns.showvotes, owner = ns.owner, description = ns.description}
      e ->
          let z = Debug.log "error" e in
          model

-- COMMUNICATION

port changeNickPort : Encode.Value -> Cmd msg
port votingActionPort : Encode.Value -> Cmd msg

port confirmJoinPort : (Encode.Value -> msg) -> Sub msg
port freshStatePort : (Encode.Value -> msg) -> Sub msg
port newVotePort : (Encode.Value -> msg) -> Sub msg
port showVotesPort : (Encode.Value -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch [
               confirmJoinPort RecJoined,
               newVotePort RecNewVote,
               freshStatePort RecFreshState,
               showVotesPort RecShowVotes
              ]

decodeVote : Decode.Decoder ReceivedVote
decodeVote = Decode.map2 ReceivedVote
                         (Decode.field "nick" Decode.string)
                         (Decode.field "vote" Decode.int)

decodeFreshState : Decode.Decoder ReceivedState
decodeFreshState = Decode.map4 ReceivedState
                               (Decode.field "votes" (Decode.dict Decode.int))
                               (Decode.field "showvotes" Decode.bool)
                               (Decode.field "owner" Decode.string)
                               (Decode.field "description" Decode.string)

sendNickEvent nick =
    changeNickPort (Encode.string nick)

sendVoteEvent i =
    votingActionPort (Encode.object [("action", Encode.string "vote"), ("value", Encode.int i)])

sendManageEvent action =
    votingActionPort (Encode.object [("action", Encode.string action)])

sendDescEvent newdesc =
    votingActionPort (Encode.object [("action", Encode.string "setdesc"), ("desc", Encode.string newdesc)])

-- VIEW

view : Model -> Html Msg
view model =
    case model.joined of
        False -> viewInitScreen model
        True ->
            if isOwner model && model.description == "" then
                viewDescScreen model
            else
                viewMainScreen model

viewMainScreen model =
    div [class "main"] [
            h1 [class "description"][text (if model.description == "" then "?" else model.description)],
            div [class "playing"] [text ("voting as \"" ++ model.nick ++ "\"")],
            div [class "playing"] [text ("session managed by \"" ++ model.owner ++ "\"")],
            div [class "manageButtons"] (manageButtons model),
            div [class "votingButtons"] votingButtons,
            div [class "votes"] (showVotes model.votes model.showvotes model.owner model.nick),
            div [class "results"] [(showResults model)]
           ]

showResults model =
    div [class "statsbox"][
    div [class "title"] [text "Results:"],
    case model.showvotes of
        True ->
            Dict.values model.votes
            |> calculateResults
            |> displayResults
        False ->
            text ""
    ]


displayResults res =
    div [] [
    div [class "stats"]
        [
        showStatRow "Number of votes" (String.fromInt res.stats.count),
        showStatRow "Average" (formatAvg res.stats.average)
        ],
    div [class " aggregates"]
        ((List.map (showOneAggr res.aggr) [1000, 0, 1, 2, 3, 5, 8, 13, 20])
        ++ maybeConsensus res.aggr)
    ]

maybeConsensus aggr =
    let x = Debug.log "aggr" aggr in
    case Dict.size aggr of
        1 -> [showConsensus]
        _ -> []

showConsensus = div [class "arow"][div [class "hooray"][text "Consensus!"]]

showStatRow label value =
    div [class "arow"][
        div [class "label"][text label],
        div [class "value"][text value]
    ]

showOneAggr aggr i =
    case getAggr i aggr of
        "" -> div [class "none"][]
        a ->
            div [class "arow"][
                div [class "label"][text (formatVote i)],
                div [class "value"][text a]
            ]

getAggr i aggr =
    case Dict.get i aggr of
        Nothing -> ""
        Just x -> String.fromInt x

formatAvg v =
    case isNaN v of
        True -> ""
        False ->
            String.fromFloat ((toFloat (round (v * 10))) / 10)

calculateResults : List Int -> Results
calculateResults votes =
    {stats = calculateStats votes,
     aggr = calculateAggr votes}

calculateStats : List Int -> Stats
calculateStats votes =
    {count = calcCount votes, average = calcAvg votes}

calcAvg votes =
    votes
    |> validOnly
    |> avg

calcCount votes =
    votes
    |> validOnly
    |> List.length

calculateAggr : List Int -> Dict.Dict Int Int
calculateAggr votes =
    List.foldl countAggr Dict.empty votes

countAggr vote aggr =
    case Dict.get vote aggr of
        Nothing -> Dict.insert vote 1 aggr
        Just x -> Dict.insert vote (x + 1) aggr


avg : List Int -> Float
avg lst = (toFloat (List.sum lst)) / (toFloat (List.length lst))

validOnly = List.filter (\x -> x > 0 && x < 1000)

votingButtons =
           [
            button [onClick (SendVote 1000)][text "?"],
            button [onClick (SendVote 1)][text "1"],
            button [onClick (SendVote 2)][text "2"],
            button [onClick (SendVote 3)][text "3"],
            button [onClick (SendVote 5)][text "5"],
            button [onClick (SendVote 8)][text "8"],
            button [onClick (SendVote 13)][text "13"],
            button [onClick (SendVote 20)][text "20"]
           ]

manageButtons model =
    case isOwner model of
        True ->
           [
            button [onClick (SendManage "showvotes")][text "Show votes"],
            button [onClick (SendManage "reset")][text "Reset session"]
           ]
        False -> []

showVotes : InternalVoteList -> Bool -> String -> String -> List (Html Msg)
showVotes votelist showvotes owner you =
   Dict.toList votelist
   |> List.sort
   |> List.map ( showOneVote showvotes owner you )

showOneVote : Bool -> String -> String -> (String, Int) -> Html Msg
showOneVote showvotes owner you (nick, vote) =
    div [class "vote"]
        [div [class "nick"][text (nick ++ maybeOwner nick owner ++ maybeYou nick you)],
         div [class ("number " ++ (voteClass vote showvotes))][text (formatVote vote)]
         ]

maybeOwner nick owner = if nick == owner then " (owner)" else ""
maybeYou nick you = if nick == you then " (You)" else ""

voteClass : Int -> Bool -> String
voteClass vote showvotes =
    case (vote, showvotes) of
        (0, _) -> "zero"
        (_, False) -> "hidden"
        _ -> "shown"

formatVote vote =
    case vote of
        1000 -> "?"
        0 -> "no vote"
        x -> String.fromInt x

viewInitScreen model =
    div [] [
            zmienNick model
           ]

zmienNick model =
    div [] [
            p [] [text "Choose your nickname for this session (at least 3 chars):"],
            input [placeholder "Your funny nickname", value model.nick, onInput SetNick] [],
            button [onClick SendChangeNick,
                    disabled (String.length model.nick < 3),
                    class "btn btn-default"]
                   [text "Join session"]
           ]


viewDescScreen : Model -> Html Msg
viewDescScreen model =
    div [class "enterDesc"][
        div [class "title"][text "Briefly describe what we are going to vote on"],
        textarea [placeholder "description", value model.input_desc, onInput SetDesc][],
        div [][
        button [onClick SendChangeDesc, class "btn btn-default"][text "Start voting"]
        ]
    ]

isOwner model = model.nick == model.owner
