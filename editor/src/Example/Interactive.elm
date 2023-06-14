module Example.Interactive exposing (Runner, build)

{-|

    Given a Docs.Value, we want:


        1. Be able to generate JSON for storybook outside of this module.
        2. Be able to generate Elm input code
        3. Store necessary state in a model.
        4. View an executed version of the generated code.
        5. View a code example that uses the arguments provided.

We should be able to generate the json to drive storybook if we wanted from this module:

    export default {
        title: 'Button',
        parameters: {
            design: {
            url: "https://www.figma.com/file/zEgV052dUW7vWpwQ65oKd8/Blissfully-Design-System?node-id=22%3A135"
            }
        },
        argTypes: {
            label: { control: "text", defaultValue: "Button Text" },
            style: { control: "inline-radio", options: ["primary", "secondary", "link"], defaultValue: "primary"},
            size: { control: "inline-radio", options: ["default", "small"], defaultValue: "default" },
            withIcon: { control: "boolean", defaultValue: false },
            disabled: { control: "boolean", defaultValue: false },
            withMenu: { control: "boolean", defaultValue: false },
        },
    }

In order to do this, we can

-}

import Elm
import Elm.Annotation
import Elm.Docs
import Elm.Op
import Elm.Type
import Example.CallStack
import Example.Interactive.Build
import Example.Interactive.CodeSample
import Example.Type
import Gen.Element
import Gen.Element.Background
import Gen.Element.Border
import Gen.Element.Font
import Gen.Html.Attributes
import Gen.String
import Gen.Ui
import Gen.Ui.Input
import Interactive


type alias Runner =
    { canRun :
        Elm.Type.Type -> Bool
    , view :
        Interactive.ViewReferences
        -> Elm.Expression
        -> Elm.Expression
    , fields : List Interactive.Field
    }


{-| -}
build :
    Elm.Docs.Module
    ->
        { start : Elm.Docs.Value
        , runners :
            List Runner
        }
    -> Result String Interactive.Interactive
build modul targeting =
    case buildExampleCallStack modul targeting of
        Ok example ->
            case getRunner targeting.runners (Example.Type.getResultType example.return) of
                Nothing ->
                    Err "No Runner!  Huh, this shouldn't happen"

                Just runner ->
                    let
                        fields =
                            runner.fields ++ example.rendered.context.state
                    in
                    Ok
                        { name = targeting.start.name
                        , fields = fields
                        , view =
                            \opts ->
                                Gen.Element.column
                                    [ Gen.Element.width Gen.Element.fill
                                    , Gen.Element.height Gen.Element.fill
                                    ]
                                    [ --     Gen.Element.el
                                      --     [ Gen.Element.Font.size 24
                                      --     , Gen.Element.paddingXY 32 10
                                      --     , Gen.Element.Font.family
                                      --         [ Gen.Element.Font.typeface "Fira Code"
                                      --         , Gen.Element.Font.sansSerif
                                      --         ]
                                      --     ]
                                      --     (Gen.Element.text
                                      --         (modul.name ++ "." ++ targeting.start.name)
                                      --     )
                                      -- ,
                                      Elm.ifThen opts.codeOrOutput
                                        (example.rendered.drivenByModel
                                            |> runner.view opts
                                            |> Gen.Element.el
                                                [ Gen.Element.width Gen.Element.fill
                                                , Gen.Element.Font.color (Gen.Element.rgb 0 0 0)
                                                , Gen.Element.Background.color (Gen.Element.rgb 1 1 1)
                                                ]
                                        )
                                        (Gen.Ui.call_.code (Elm.string "")
                                            example.example.drivenByModel
                                            |> Gen.Element.el [ Gen.Element.centerY ]
                                            |> Gen.Element.el
                                                [ Gen.Element.padding 32
                                                , Gen.Element.height
                                                    (Gen.Element.shrink
                                                        |> Gen.Element.minimum 200
                                                    )
                                                ]
                                        )
                                    , Gen.Element.el
                                        [ Gen.Element.width Gen.Element.fill
                                        , Gen.Element.padding 32
                                        ]
                                        (viewInput opts fields)
                                    ]
                        }

        Err err ->
            Err err


viewInput :
    Interactive.ViewReferences
    -> List Interactive.Field
    -> Elm.Expression
viewInput viewOptions fields =
    Gen.Element.column
        [ Gen.Element.width Gen.Element.fill
        , Gen.Element.spacing 16
        ]
        (List.map (viewFieldInput viewOptions)
            (List.reverse fields)
        )


{-|

    - Label

-}
viewFieldInput :
    Interactive.ViewReferences
    -> Interactive.Field
    -> Elm.Expression
viewFieldInput opts field =
    let
        details =
            Interactive.details field

        updateValue =
            Elm.fn
                ( "new"
                , Nothing
                )
                (\new ->
                    Elm.apply
                        opts.onChange
                        [ opts.model
                            |> Elm.updateRecord
                                [ ( details.key, new )
                                ]
                        ]
                )
    in
    case details.input of
        Interactive.InputString ->
            Gen.Ui.Input.call_.string
                (Elm.string details.label)
                updateValue
                (Elm.get details.key opts.model)

        Interactive.InputBool ->
            Gen.Ui.Input.call_.bool
                (Elm.string details.label)
                updateValue
                (Elm.get details.key opts.model)

        Interactive.InputInt ->
            Gen.Ui.Input.call_.int
                (Elm.string details.label)
                updateValue
                (Elm.get details.key opts.model)

        Interactive.InputFloat ->
            Gen.Element.text "Float"

        Interactive.InputMaybe Interactive.InputString ->
            Elm.get details.key opts.model
                |> Gen.Ui.Input.call_.maybeString
                    (Elm.string details.label)
                    updateValue

        Interactive.InputMaybe Interactive.InputBool ->
            Elm.get details.key opts.model
                |> Gen.Ui.Input.call_.maybeBool
                    (Elm.string details.label)
                    updateValue

        Interactive.InputMaybe _ ->
            Gen.Element.text "Float"


runnerEnd : List Runner -> Elm.Type.Type -> Bool
runnerEnd runners target =
    case runners of
        [] ->
            False

        runner :: remain ->
            if runner.canRun target then
                True

            else
                runnerEnd remain target


buildExampleCallStack :
    Elm.Docs.Module
    ->
        { start : Elm.Docs.Value
        , runners :
            List Runner
        }
    ->
        Result
            String
            { rendered : Example.Interactive.CodeSample.Created
            , example : Example.Interactive.Build.Created
            , return : Elm.Type.Type
            }
buildExampleCallStack mod bounds =
    case Example.CallStack.find mod.values [] { start = bounds.start, end = runnerEnd bounds.runners } of
        Nothing ->
            Err "No way to build desired type"

        Just [] ->
            Err "No way to build desired type"

        Just (callStack :: calls) ->
            let
                exampleResult =
                    Example.Interactive.Build.build mod
                        callStack

                renderedResult =
                    Example.Interactive.CodeSample.build mod
                        callStack
            in
            case ( renderedResult, exampleResult ) of
                ( Ok rendered, Ok example ) ->
                    Ok
                        { rendered = example
                        , example = rendered
                        , return = Example.CallStack.getResultType callStack
                        }

                _ ->
                    Err "Something terribly terribly wrong happened"


getRunner :
    List { b | canRun : a -> Bool }
    -> a
    -> Maybe { b | canRun : a -> Bool }
getRunner runners tipe =
    List.foldl
        (\run maybe ->
            case maybe of
                Nothing ->
                    if run.canRun tipe then
                        Just run

                    else
                        Nothing

                Just _ ->
                    maybe
        )
        Nothing
        runners



--  { model : Elm.Expression
--     , onChange : Elm.Expression
--     }


viewWrapper result exp =
    -- case result of
    --     Elm.Type.Var string ->
    --         Gen.Element.text ""
    --     Elm.Type.Lambda one two ->
    --         Gen.Element.text ""
    --     Elm.Type.Tuple types ->
    --         case types of
    --             [] ->
    --                 Gen.Element.text "()"
    --             [ one, two ] ->
    --                 Gen.Element.text ""
    --             -- isViewable one && isViewable two
    --             [ one, two, three ] ->
    --                 Gen.Element.text ""
    --             -- isViewable one && isViewable two && isViewable three
    --             _ ->
    --                 Gen.Element.text ""
    --     Elm.Type.Type "List.List" [ inner ] ->
    --         Gen.Element.text ""
    --     Elm.Type.Type "Maybe.Maybe" [ inner ] ->
    --         Gen.Element.text ""
    --     Elm.Type.Type "Basics.Bool" [] ->
    --         Gen.Element.text ""
    --     Elm.Type.Type "Basics.Int" [] ->
    --         Gen.Element.call_.text (Gen.String.call_.fromInt exp)
    --     Elm.Type.Type "Basics.Float" [] ->
    --         Gen.Element.call_.text (Gen.String.call_.fromFloat exp)
    --     Elm.Type.Type "String.String" [] ->
    --         Gen.Element.call_.text exp
    --     Elm.Type.Type "Html.Html" [] ->
    --         Gen.Element.html exp
    --     Elm.Type.Type "Svg.Svg" [] ->
    --         Gen.Element.html exp
    --     Elm.Type.Type name types ->
    --         Gen.Element.text ""
    --     Elm.Type.Record fields maybeExtensible ->
    --         Gen.Element.text ""
    exp
