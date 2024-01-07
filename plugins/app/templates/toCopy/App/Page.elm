module App.Page exposing
    ( Page, page, authenticated
    , withKey, withPageCacheLimit
    , Init, init, initWith, notFound, loadFrom, error
    )

{-|

@docs Page, page, authenticated

@docs withKey, withPageCacheLimit

@docs Init, init, initWith, notFound, loadFrom, error

-}

import App.Effect
import App.Engine.Page
import App.Page.Error
import App.Shared
import App.Sub
import App.View
import App.View.Id


type alias Page params msg model =
    App.Engine.Page.Page App.Shared.Shared params msg model


{-| -}
page :
    { init : params -> App.Shared.Shared -> Maybe model -> Init msg model
    , update : App.Shared.Shared -> msg -> model -> ( model, App.Effect.Effect msg )
    , subscriptions : App.Shared.Shared -> model -> App.Sub.Sub msg
    , view : App.View.Id.Id -> App.Shared.Shared -> model -> App.View.View msg
    }
    -> Page params msg model
page =
    App.Engine.Page.page


{-| -}
withKey : (params -> String) -> Page params msg model -> Page params msg model
withKey =
    App.Engine.Page.withKey


{-| This is the maximum number of page instances that will be cached, above what is already visible.

This defaults to 1.

-}
withPageCacheLimit : Int -> Page params msg model -> Page params msg model
withPageCacheLimit =
    App.Engine.Page.withPageCacheLimit


{-| -}
authenticated :
    { init : params -> App.Shared.Shared -> Maybe model -> Init msg model
    , update : App.Shared.Shared -> msg -> model -> ( model, App.Effect.Effect msg )
    , subscriptions : App.Shared.Shared -> model -> App.Sub.Sub msg
    , view : App.View.Id.Id -> App.Shared.Shared -> model -> App.View.View msg
    }
    -> Page params msg model
authenticated options =
    App.Engine.Page.page options
        |> App.Engine.Page.withGuard
            (\shared ->
                case shared.authenticated of
                    App.Shared.Authenticated ->
                        Ok shared

                    App.Shared.Unauthenticated ->
                        Err App.Page.Error.Unauthenticated
            )


type alias Init msg model =
    App.Engine.Page.Init msg model


{-| -}
init : model -> Init msg model
init =
    App.Engine.Page.init


{-| -}
initWith : model -> App.Effect.Effect msg -> Init msg model
initWith =
    App.Engine.Page.initWith


{-| -}
notFound : Init msg model
notFound =
    App.Engine.Page.notFound


{-| -}
loadFrom : App.Effect.Effect (Init msg model) -> Init msg model
loadFrom =
    App.Engine.Page.loadFrom


{-| -}
error : App.Page.Error.Error -> Init msg model
error =
    App.Engine.Page.error
