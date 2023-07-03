module Press.Generate.Route exposing (generate)

import Elm
import Elm.Annotation as Type
import Elm.Case
import Elm.Let
import Elm.Op
import Gen.App.Markdown
import Gen.App.State
import Gen.AppUrl
import Gen.Browser
import Gen.Browser.Navigation
import Gen.Dict
import Gen.Html
import Gen.Http
import Gen.Json.Encode
import Gen.List
import Gen.Markdown.Parser
import Gen.Markdown.Renderer
import Gen.Platform.Cmd
import Gen.Platform.Sub
import Gen.String
import Gen.Tuple
import Gen.Url
import Gen.Url.Parser
import Gen.Url.Parser.Query
import Json.Decode
import Markdown.Block as Block
import Markdown.Parser
import Parser exposing ((|.), (|=))
import Path
import Press.Generate.Engine
import Press.Model exposing (..)
import Set exposing (Set)


generate : List Press.Model.Page -> Elm.File
generate routes =
    Elm.fileWith [ "Route" ]
        { docs =
            \groups ->
                groups
                    |> List.sortBy
                        (\doc ->
                            case doc.group of
                                Nothing ->
                                    0

                                Just "Route" ->
                                    1

                                Just "Params" ->
                                    2

                                Just "Encodings" ->
                                    3

                                _ ->
                                    4
                        )
                    |> List.map Elm.docs
        , aliases = []
        }
        (List.concat
            [ [ Elm.customType "Route"
                    (List.map
                        (\route ->
                            Elm.variantWith
                                route.id
                                [ paramType route
                                ]
                        )
                        routes
                    )
                    |> Elm.exposeWith
                        { exposeConstructor = True
                        , group = Just "Route"
                        }
              ]
            , List.map
                (\route ->
                    Elm.alias (route.id ++ "_Params")
                        (paramType route)
                        |> Elm.exposeWith
                            { exposeConstructor = False
                            , group = Just "Params"
                            }
                )
                routes
            , urlEncoder routes
            , urlParser routes
            , urlToId routes
            ]
        )


hasNoParams : QueryParams -> Bool
hasNoParams params =
    Set.isEmpty params.specificFields
        && not params.includeCatchAll


paramType : Page -> Type.Annotation
paramType route =
    let
        (UrlPattern { queryParams, includePathTail, path }) =
            route.url
    in
    if hasNoParams queryParams && not includePathTail then
        Type.record []

    else
        let
            addCatchall fields =
                if queryParams.includeCatchAll then
                    ( "params", Type.dict Type.string Type.string )
                        :: fields

                else
                    fields

            addFullTail fields =
                if includePathTail then
                    ( "path", Type.list Type.string ) :: fields

                else
                    fields
        in
        Type.record
            (List.concat
                [ List.filterMap
                    (\piece ->
                        case piece of
                            Token _ ->
                                Nothing

                            Variable name ->
                                Just ( name, Type.string )
                    )
                    path
                    |> addFullTail
                , queryParams.specificFields
                    |> Set.toList
                    |> List.map
                        (\field ->
                            ( field, Type.maybe Type.string )
                        )
                    |> addCatchall
                ]
            )



-- pathToUrlPieces : String -> String -> Maybe ( String, List UrlPiece )
-- pathToUrlPieces base filepath =
--     let
--         ( relativePath, ext ) =
--             Path.relative base filepath
--                 |> Path.extension
--     in
--     if ext == "md" || ext == "markdown" then
--         let
--             tokens =
--                 relativePath
--                     |> String.split "/"
--                     |> List.map camelToKebab
--                     |> List.filter (not << String.isEmpty)
--                     |> List.map Token
--             name =
--                 relativePath
--                     |> String.split "/"
--                     |> List.map toElmTypeName
--                     |> List.filter (not << String.isEmpty)
--                     |> String.join ""
--         in
--         Just ( name, tokens )
--     else
--         Nothing


urlToId : List Page -> List Elm.Declaration
urlToId routes =
    [ Elm.declaration "toId"
        (Elm.fn ( "route", Just (Type.named [] "Route") )
            (\route ->
                Elm.Case.custom route
                    (Type.named [] "Route")
                    (routes
                        |> List.map
                            (\individualRoute ->
                                Elm.Case.branch1 individualRoute.id
                                    ( "params", paramType individualRoute )
                                    (\_ ->
                                        Elm.string individualRoute.id
                                    )
                            )
                    )
            )
            |> Elm.withType
                (Type.function [ Type.named [] "Route" ] Type.string)
        )
        |> Elm.exposeWith
            { exposeConstructor = True
            , group = Just "Encodings"
            }
    ]


urlEncoder : List Page -> List Elm.Declaration
urlEncoder routes =
    [ Elm.declaration "toUrl"
        (Elm.fn ( "route", Just (Type.named [] "Route") )
            (\route ->
                Elm.Case.custom route
                    (Type.named [] "Route")
                    (routes
                        |> List.map
                            (\individualRoute ->
                                Elm.Case.branch1 individualRoute.id
                                    ( "params", paramType individualRoute )
                                    (\params ->
                                        let
                                            (UrlPattern { path, includePathTail, queryParams }) =
                                                individualRoute.url
                                        in
                                        renderPath path includePathTail queryParams params
                                    )
                            )
                    )
            )
            |> Elm.withType
                (Type.function [ Type.named [] "Route" ] Type.string)
        )
        |> Elm.exposeWith
            { exposeConstructor = True
            , group = Just "Encodings"
            }
    ]


renderPath : List UrlPiece -> Bool -> QueryParams -> Elm.Expression -> Elm.Expression
renderPath path includePathTail queryParams paramValues =
    let
        base =
            path
                |> List.map
                    (\piece ->
                        case piece of
                            Token token ->
                                Elm.string token

                            Variable var ->
                                Elm.get var paramValues
                    )
                |> Elm.list

        fullPath =
            if includePathTail then
                Elm.Op.append base
                    (Elm.get "path" paramValues)

            else
                base

        allParams =
            if hasNoParams queryParams then
                Gen.Dict.empty

            else if queryParams.includeCatchAll then
                Elm.get "params" paramValues

            else
                Set.foldl
                    (\field dict ->
                        dict
                            |> Elm.Op.pipe
                                (Elm.apply
                                    Gen.Dict.values_.insert
                                    [ Elm.string field
                                    , Elm.get field paramValues
                                    ]
                                )
                    )
                    Gen.Dict.empty
                    queryParams.specificFields
    in
    Gen.AppUrl.toString
        (Elm.record
            [ ( "path", fullPath )
            , ( "queryParameters", allParams )
            , ( "fragment", Elm.nothing )
            ]
        )


surround first last middle =
    first ++ middle ++ last


wrapRecord fields =
    case fields of
        [] ->
            "{}"

        _ ->
            surround "\n                { "
                "\n                }"
                (fields
                    |> String.join "\n                , "
                )


wrapOpenList remaining fields =
    case fields of
        [] ->
            "[]"

        _ ->
            String.join " :: " fields
                ++ " :: "
                ++ remaining


wrapList fields =
    case fields of
        [] ->
            "[]"

        _ ->
            surround "[ "
                " ]"
                (fields
                    |> String.join ", "
                )


sameRoute : List Page -> Elm.Declaration
sameRoute routes =
    Elm.declaration "sameRoute"
        (Elm.fn2
            ( "one", Just (Type.named [] "Route") )
            ( "two", Just (Type.named [] "Route") )
            (\one two ->
                Elm.Case.custom one
                    (Type.named [] "Route")
                    (routes
                        |> List.map
                            (\route ->
                                Elm.Case.branch1 route.id
                                    ( "params", Type.var "params" )
                                    (\_ ->
                                        Elm.Case.custom two
                                            (Type.named [] "Route")
                                            [ Elm.Case.branch1 route.id
                                                ( "params2", Type.var "params2" )
                                                (\_ ->
                                                    Elm.bool True
                                                )
                                            , Elm.Case.otherwise
                                                (\_ ->
                                                    Elm.bool False
                                                )
                                            ]
                                    )
                            )
                    )
            )
        )
        |> Elm.exposeWith
            { exposeConstructor = False
            , group = Just "Route"
            }


parseAppUrl : List Page -> Elm.Declaration
parseAppUrl routes =
    let
        paths =
            routes
                |> List.reverse
                |> List.concatMap
                    (\route ->
                        case route.url of
                            UrlPattern { path, includePathTail, queryParams } ->
                                let
                                    branch =
                                        if includePathTail then
                                            path
                                                |> List.map
                                                    (\piece ->
                                                        case piece of
                                                            Token token ->
                                                                surround "\"" "\"" token

                                                            Variable var ->
                                                                var
                                                    )
                                                |> wrapOpenList "andPathTail"

                                        else
                                            path
                                                |> List.map
                                                    (\piece ->
                                                        case piece of
                                                            Token token ->
                                                                surround "\"" "\"" token

                                                            Variable var ->
                                                                var
                                                    )
                                                |> wrapList

                                    fieldsFromPath =
                                        path
                                            |> List.filterMap
                                                (\piece ->
                                                    case piece of
                                                        Token token ->
                                                            Nothing

                                                        Variable var ->
                                                            Just (var ++ " = " ++ var)
                                                )
                                            |> (\innerFields ->
                                                    if includePathTail then
                                                        "path = andPathTail" :: innerFields

                                                    else
                                                        innerFields
                                               )

                                    queryParamFields =
                                        if queryParams.includeCatchAll then
                                            [ "params = appUrl.queryParameters" ]

                                        else
                                            case Set.toList queryParams.specificFields of
                                                [] ->
                                                    []

                                                specificFields ->
                                                    List.map
                                                        (\field ->
                                                            field ++ " = getSingle " ++ field ++ " appUrl.queryParameters"
                                                        )
                                                        specificFields

                                    constructedRoute =
                                        route.id
                                            ++ " "
                                            ++ (fieldsFromPath
                                                    ++ queryParamFields
                                                    |> wrapRecord
                                               )
                                in
                                [ "        " ++ branch ++ " ->\n            Just <| " ++ constructedRoute
                                ]
                    )
                |> String.join "\n\n"
    in
    Elm.unsafe
        ("""

parseAppUrl : AppUrl.AppUrl -> Maybe Route
parseAppUrl appUrl = 
    case appUrl.path of
${paths}

        _ -> 
            Nothing
"""
            |> String.replace "${paths}" paths
        )


urlParser : List Page -> List Elm.Declaration
urlParser routes =
    [ Elm.declaration "parse"
        (Elm.fn ( "url", Just Gen.Url.annotation_.url )
            (\url ->
                let
                    appUrl =
                        Gen.AppUrl.fromUrl url
                in
                Elm.apply (Elm.val "parseAppUrl") [ appUrl ]
            )
            |> Elm.withType
                (Type.function [ Gen.Url.annotation_.url ] (Type.maybe (Type.named [] "Route")))
        )
        |> Elm.exposeWith
            { exposeConstructor = True
            , group = Just "Encodings"
            }
    , sameRoute routes
    , parseAppUrl routes
    , Elm.unsafe """
getSingle : String -> AppUrl.QueryParameters -> Maybe String
getSingle field appUrlParams =
    case Dict.get field appUrlParams of
        Nothing ->
            Nothing

        Just [] ->
            Nothing

        Just (single :: _) ->
            Just single


getList : String -> AppUrl.QueryParameters -> List String
getList field appUrlParams =
    Dict.get field appUrlParams
        |> Maybe.withDefault []

"""
    ]
