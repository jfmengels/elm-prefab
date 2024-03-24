module Options.Route exposing
    ( Page
    , ParsedPage
    , ParserError
    , QueryParams
    , UrlParsedPattern(..)
    , UrlPattern(..)
    , UrlPatternDetails
    , UrlPiece(..)
    , decode
    , decodePage
    , parseUrlPattern
    )

{-| -}

import Json.Decode
import Markdown.Parser
import Parser exposing ((|.), (|=))
import Set exposing (Set)


type alias ParsedPage =
    { id : String
    , url : UrlParsedPattern
    , redirectFrom : List UrlParsedPattern
    , assets : Maybe SourceDirectory
    }


type alias Page =
    { id : String
    , url : UrlPattern
    , redirectFrom : List UrlPattern
    , assets : Maybe SourceDirectory
    }


type alias SourceDirectory =
    { base : String
    , baseOnApp : String
    , baseOnServer : String
    , files : List Source
    }


type alias Source =
    { path : String
    , source : String
    }


type UrlPattern
    = UrlPattern UrlPatternDetails


type UrlParsedPattern
    = UrlParsedPattern UrlPatternDetails
    | UrlError ParserError


type alias ParserError =
    { name : String
    , isRedirect : Bool
    , pattern : String
    , deadEnds : List Parser.DeadEnd
    }


type alias UrlPatternDetails =
    { pattern : String
    , path : List UrlPiece
    , includePathTail : Bool
    , queryParams : QueryParams
    }


type alias QueryParams =
    { includeCatchAll : Bool
    , specificFields : Set String
    }


type UrlPiece
    = Token String
    | Variable String



{- Decoders -}


decode : Json.Decode.Decoder (List ParsedPage)
decode =
    Json.Decode.field "pages" (Json.Decode.list decodePage)


decodePage : Json.Decode.Decoder ParsedPage
decodePage =
    Json.Decode.field "id" Json.Decode.string
        |> Json.Decode.andThen
            (\id ->
                Json.Decode.map3 (ParsedPage id)
                    (Json.Decode.field "url" (decodeUrlPattern False id))
                    (Json.Decode.field "redirectFrom" (Json.Decode.list (decodeUrlPattern True id)))
                    (Json.Decode.field "assets" (Json.Decode.maybe decodeDirectory))
            )


decodeUrlPattern : Bool -> String -> Json.Decode.Decoder UrlParsedPattern
decodeUrlPattern isRedirect id =
    Json.Decode.string
        |> Json.Decode.andThen
            (\string ->
                case Parser.run (parseUrlPattern string) string of
                    Ok urlPattern ->
                        Json.Decode.succeed (UrlParsedPattern urlPattern)

                    Err err ->
                        Json.Decode.succeed
                            (UrlError
                                { name = id
                                , isRedirect = isRedirect
                                , pattern = string
                                , deadEnds = err
                                }
                            )
            )


{-| Parses a format like

    /users/:id/*?{search}

Which parses

  - id into a string
  - \* into a list of strings
  - and `search` into a list of strings from ?search

-}
parseUrlPattern : String -> Parser.Parser UrlPatternDetails
parseUrlPattern pattern =
    Parser.succeed
        (\path queryParams ->
            { pattern = pattern
            , path = path.path
            , includePathTail = path.includePathTail
            , queryParams = queryParams
            }
        )
        |= parsePath
        |= parseQueryParams


parsePath :
    Parser.Parser
        { includePathTail : Bool
        , path : List UrlPiece
        }
parsePath =
    Parser.loop []
        (\pieces ->
            Parser.oneOf
                [ Parser.succeed (\val -> val)
                    |. Parser.symbol "/"
                    |= Parser.oneOf
                        [ Parser.succeed
                            (Parser.Done
                                { includePathTail = True
                                , path = List.reverse pieces
                                }
                            )
                            |. Parser.symbol "*"
                        , Parser.succeed
                            (\isVariable label ->
                                if isBlank label then
                                    Parser.Loop pieces

                                else
                                    Parser.Loop <|
                                        if isVariable then
                                            Variable label :: pieces

                                        else
                                            Token label :: pieces
                            )
                            |= Parser.oneOf
                                [ Parser.succeed True
                                    |. Parser.chompIf (\c -> c == ':')
                                , Parser.succeed False
                                ]
                            |= Parser.getChompedString
                                (Parser.chompWhile
                                    (\c ->
                                        not (List.member c [ '/', ':', '?' ])
                                    )
                                )
                        ]
                , case pieces of
                    [] ->
                        Parser.problem "paths must start with /"

                    _ ->
                        Parser.succeed
                            (Parser.Done
                                { includePathTail = False
                                , path = List.reverse pieces
                                }
                            )
                ]
        )


parseQueryParams : Parser.Parser QueryParams
parseQueryParams =
    Parser.oneOf
        [ Parser.succeed
            { includeCatchAll = False
            , specificFields = Set.empty
            }
            |. Parser.end
        , Parser.succeed (\params -> params)
            |. Parser.symbol "?"
            |. Parser.symbol "{"
            |= Parser.oneOf
                [ Parser.succeed
                    { includeCatchAll = True
                    , specificFields = Set.empty
                    }
                    |. Parser.symbol "**"
                , Parser.loop
                    { includeCatchAll = False
                    , specificFields = Set.empty
                    }
                    (\params ->
                        Parser.oneOf
                            [ Parser.succeed
                                (\fieldName ->
                                    Parser.Loop { params | specificFields = Set.insert fieldName params.specificFields }
                                )
                                |= Parser.getChompedString
                                    (Parser.succeed ()
                                        |. Parser.chompIf Char.isAlpha
                                        |. Parser.chompWhile Char.isAlpha
                                    )
                                |. Parser.chompWhile (\c -> c == ',')
                            , Parser.succeed (Parser.Done params)
                            ]
                    )
                ]
            |. Parser.symbol "}"
        ]


isBlank : String -> Bool
isBlank str =
    String.isEmpty (String.trim str)


decodeDirectory : Json.Decode.Decoder SourceDirectory
decodeDirectory =
    Json.Decode.map4 SourceDirectory
        (Json.Decode.field "base" Json.Decode.string)
        (Json.Decode.field "baseOnApp" Json.Decode.string)
        (Json.Decode.field "baseOnServer" Json.Decode.string)
        (Json.Decode.field "files" (Json.Decode.list decodeSource))


decodeSource : Json.Decode.Decoder Source
decodeSource =
    Json.Decode.map2 Source
        (Json.Decode.field "path" Json.Decode.string)
        (Json.Decode.field "contents" Json.Decode.string)
