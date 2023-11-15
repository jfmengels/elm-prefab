port module App.Effect exposing
    ( none, batch
    , pushUrl, replaceUrl
    , forward, back
    , preload, load, reload
    , Effect, toCmd, map
    )

{-|

@docs none, batch

@docs pushUrl, replaceUrl

@docs forward, back

@docs preload, load, reload


# Effects

@docs Effect, toCmd, map

-}

import App.Route
import Browser
import Browser.Dom
import Browser.Navigation
import Html
import Http
import Json.Encode
import Task


none : Effect msg
none =
    None


batch : List (Effect msg) -> Effect msg
batch =
    Batch


pushUrl : String -> Effect msg
pushUrl =
    PushUrl


replaceUrl : String -> Effect msg
replaceUrl =
    ReplaceUrl


load : String -> Effect msg
load =
    Load


preload : App.Route.Route -> Effect msg
preload =
    Preload


reload : Effect msg
reload =
    Reload


forward : Int -> Effect msg
forward =
    Forward


back : Int -> Effect msg
back =
    Back


type Effect msg
    = None
    | Batch (List (Effect msg))
      --
    | Callback msg
      -- Urls
    | PushUrl String
    | ReplaceUrl String
      -- Loading
    | Preload App.Route.Route
    | Load String
    | Reload
      -- History navigation
    | Forward Int
    | Back Int
      -- JS interop
    | SendToWorld
        { tag : String
        , details : Maybe Json.Encode.Value
        }


port outgoing : { tag : String, details : Maybe Json.Encode.Value } -> Cmd msg


toCmd : { options | navKey : Browser.Navigation.Key, preload : App.Route.Route -> msg } -> Effect msg -> Cmd msg
toCmd options effect =
    case effect of
        None ->
            Cmd.none

        Batch effects ->
            Cmd.batch (List.map (toCmd options) effects)

        PushUrl url ->
            Browser.Navigation.pushUrl options.navKey url

        ReplaceUrl url ->
            Browser.Navigation.replaceUrl options.navKey url

        Load url ->
            Browser.Navigation.load url

        Reload ->
            Browser.Navigation.reload

        Forward steps ->
            Browser.Navigation.forward options.navKey steps

        Back steps ->
            Browser.Navigation.back options.navKey steps

        SendToWorld outgoingMsg ->
            outgoing outgoingMsg

        Callback msg ->
            Task.succeed ()
                |> Task.perform (\_ -> msg)

        Preload route ->
            Task.succeed ()
                |> Task.perform (\_ -> options.preload route)


map : (a -> b) -> Effect a -> Effect b
map f effect =
    case effect of
        None ->
            None

        Batch effects ->
            Batch (List.map (map f) effects)

        PushUrl url ->
            PushUrl url

        ReplaceUrl url ->
            ReplaceUrl url

        Load url ->
            Load url

        Reload ->
            Reload

        Forward n ->
            Forward n

        Back n ->
            Back n

        SendToWorld { tag, details } ->
            SendToWorld { tag = tag, details = details }

        Callback msg ->
            Callback (f msg)

        Preload route ->
            Preload route
