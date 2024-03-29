
import * as path from "path";
import * as fs from "fs";
import * as Options from "../../options";

export const copyTo = (baseDir: string, overwrite: boolean, skip: boolean, summary: Options.Summary) => { 
  
  if (overwrite || (!fs.existsSync(path.join(baseDir, "/WebComponent/Portal.elm")) && !skip)) {
    const filepath = path.join(baseDir, "/WebComponent/Portal.elm");
    fs.mkdirSync(path.dirname(filepath), { recursive: true });
    fs.writeFileSync(filepath, "module WebComponent.Portal exposing\n    ( Model, closed\n    , view\n    , MenuPosition(..)\n    , isOpen\n    , Element, Window\n    )\n\n{-| This custom element is helping us with 2 things.\n\nFirst, we need to be able to render dropdown menus at the top of the DOM so they don't accidently get clipped when there are scrollbars.\n\nThe scrollbar clipping thing is a hard blocker from how CSS and stacking contexts work, so our solution is to render it in one place in\nthe DOM in Elm, but have some javascript that moves the element to a place at the top of the DOM behind the scenes.\n\nThis is called a \"portal\" in React land. So, we're just copying that here.\n\nSecond! We also want a drop down to be a drop _up_ if it is too low on the screen. We can do this calculation by capturing bounding boxes and doing some math with the window.\n\nThis element does not care about other styling or behavior though!\n\n@docs Model, closed\n@docs view\n\n@docs MenuPosition\n@docs isOpen\n@docs Element, Window\n\n-}\n\nimport Html exposing (Html)\nimport Html.Attributes as Attr\nimport Html.Events\nimport Json.Decode\n\n\ntype Model\n    = Open Viewport\n    | Closed\n\n\nclosed : Model\nclosed =\n    Closed\n\n\nisOpen : Model -> Bool\nisOpen model =\n    model /= Closed\n\n\ntype alias Viewport =\n    { parent : Element\n    , window : Window\n    }\n\n\ntype alias Element =\n    { x : Float\n    , y : Float\n    , width : Float\n    , height : Float\n    }\n\n\ntype alias Window =\n    { width : Float\n    , height : Float\n    }\n\n\nonToggle :\n    { options\n        | model : Model\n        , onMsg : Model -> msg\n    }\n    -> Html.Attribute msg\nonToggle { model, onMsg } =\n    Html.Events.on \"click\"\n        (Json.Decode.map2\n            (\\parent window ->\n                case model of\n                    Closed ->\n                        onMsg\n                            (Open\n                                { parent = parent\n                                , window = window\n                                }\n                            )\n\n                    Open _ ->\n                        onMsg Closed\n            )\n            (Json.Decode.at [ \"currentTarget\", \"__getParentClientRect\" ] elementDecoder)\n            (Json.Decode.at [ \"currentTarget\", \"__getWindowSize\" ] windowDecode)\n        )\n\n\nwindowDecode : Json.Decode.Decoder Window\nwindowDecode =\n    Json.Decode.map2 Window\n        (Json.Decode.field \"width\" Json.Decode.float)\n        (Json.Decode.field \"height\" Json.Decode.float)\n\n\nelementDecoder : Json.Decode.Decoder Element\nelementDecoder =\n    Json.Decode.map4 Element\n        (Json.Decode.field \"x\" Json.Decode.float)\n        (Json.Decode.field \"y\" Json.Decode.float)\n        (Json.Decode.field \"width\" Json.Decode.float)\n        (Json.Decode.field \"height\" Json.Decode.float)\n\n\nview :\n    { position : MenuPosition\n    , model : Model\n    , onMsg : Model -> msg\n    , button : Html msg\n    , menu : Html msg\n    }\n    -> Html msg\nview options =\n    let\n        dismissMenuOnEscapeEvent =\n            Html.Events.on \"keyup\"\n                (Json.Decode.field \"key\" Json.Decode.string\n                    |> Json.Decode.andThen\n                        (\\key ->\n                            if key == \"Escape\" then\n                                Json.Decode.succeed (options.onMsg Closed)\n\n                            else\n                                Json.Decode.fail key\n                        )\n                )\n\n        viewMenu : Viewport -> Html msg\n        viewMenu viewport =\n            Html.div\n                [ Attr.style \"position\" \"fixed\"\n                , Attr.style \"top\" (px viewport.parent.y)\n                , Attr.style \"left\" (px viewport.parent.x)\n                , Attr.style \"width\" (px viewport.parent.width)\n                , Attr.style \"height\" (px viewport.parent.height)\n                , dismissMenuOnEscapeEvent\n                ]\n                [ Html.div\n                    [ Html.Events.onClick (options.onMsg Closed)\n                    , Attr.style \"position\" \"absolute\"\n                    , Attr.style \"top\" \"0\"\n                    , Attr.style \"left\" \"0\"\n                    , Attr.style \"right\" \"0\"\n                    , Attr.style \"bottom\" \"0\"\n                    ]\n                    []\n                , Html.div\n                    (toPositionAttributes\n                        { position = options.position\n                        , viewport = viewport\n                        }\n                    )\n                    [ options.menu ]\n                ]\n\n        viewDismissOverlay : Html msg\n        viewDismissOverlay =\n            Html.div\n                [ Html.Events.onClick (options.onMsg Closed)\n                , Attr.style \"position\" \"fixed\"\n                , Attr.style \"top\" \"0\"\n                , Attr.style \"left\" \"0\"\n                , Attr.style \"width\" \"100%\"\n                , Attr.style \"height\" \"100%\"\n                ]\n                []\n    in\n    Html.div []\n        [ Html.div [ onToggle options ] [ options.button ]\n        , case options.model of\n            Open viewport ->\n                Html.node \"elm-portal\"\n                    []\n                    [ viewDismissOverlay\n                    , viewMenu viewport\n                    ]\n\n            Closed ->\n                Html.text \"\"\n        ]\n\n\ntype MenuPosition\n    = -- Render below toggle button\n      Below { isAlignedLeft : Bool }\n      -- Render to the right of the toggle button\n    | ToRightOf\n\n\ntoPositionAttributes :\n    { position : MenuPosition, viewport : Viewport }\n    -> List (Html.Attribute msg)\ntoPositionAttributes { position, viewport } =\n    let\n        menuBelowRightAligned =\n            [ Attr.style \"position\" \"absolute\"\n            , Attr.style \"top\" \"calc(100% + 4px)\"\n            , Attr.style \"right\" \"0\"\n            , Attr.style \"transform\" \"none\"\n            , Attr.style \"min-width\" \"max-content\"\n            ]\n\n        menuBelowLeftAligned =\n            [ Attr.style \"position\" \"absolute\"\n            , Attr.style \"top\" \"calc(100% + 4px)\"\n            , Attr.style \"left\" \"0\"\n            , Attr.style \"transform\" \"none\"\n            , Attr.style \"min-width\" \"max-content\"\n            ]\n\n        menuOnRightTopAligned =\n            [ Attr.style \"position\" \"absolute\"\n            , Attr.style \"left\" \"calc(100% + 5px)\"\n            , Attr.style \"top\" \"0px\"\n            , Attr.style \"transform\" \"none\"\n            , Attr.style \"min-width\" \"max-content\"\n            ]\n\n        menuOnRightBottomAligned =\n            [ Attr.style \"position\" \"absolute\"\n            , Attr.style \"left\" \"calc(100% + 5px)\"\n            , Attr.style \"bottom\" \"0px\"\n            , Attr.style \"transform\" \"none\"\n            , Attr.style \"min-width\" \"max-content\"\n            ]\n\n        attemptToAlignLeft =\n            if viewport.window.width - viewport.parent.x < 400 then\n                menuBelowRightAligned\n\n            else\n                menuBelowLeftAligned\n\n        attemptToAlignRight =\n            if viewport.parent.x < 400 then\n                menuBelowLeftAligned\n\n            else\n                menuBelowRightAligned\n    in\n    case position of\n        Below { isAlignedLeft } ->\n            if isAlignedLeft then\n                attemptToAlignLeft\n\n            else\n                attemptToAlignRight\n\n        ToRightOf ->\n            if viewport.window.height - viewport.parent.y < 400 then\n                menuOnRightBottomAligned\n\n            else\n                menuOnRightTopAligned\n\n\npx : Float -> String\npx float =\n    String.fromFloat float ++ \"px\"\n");
    const generated = { outputDir: baseDir, path: filepath}
    Options.addGenerated(summary, generated);
  }
}
