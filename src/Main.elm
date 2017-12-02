module Main exposing (..)

import Html exposing (..)
import Routing
import Page.NotFound.NotFound as NotFound
import Page.Blank.Blank as Blank
import Page.Errored.Errored as Errored
import Page.Home.LoadingHome as LoadingHome
import Page.Home.Home as Home
import Page.UserAgreement.UserAgreement as UserAgreement
import Data.TransitionStatus as TransitionStatus
import Navigation


type Page
    = BlankPage
    | NotFoundPage
    | ErroredPage Errored.Model
    | HomePage Home.Model
    | UserAgreementPage UserAgreement.Model


type Loading
    = LoadingHome LoadingHome.Model


type PageState
    = Loaded Page
    | Transitioning Page Loading


type alias Model =
    { pageState : PageState
    }


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    setRoute (Just Routing.UserAgreement) initModel


initModel : Model
initModel =
    { pageState = Loaded BlankPage }


main : Program Never Model Msg
main =
    Navigation.program ChangeLocation
        { view = view
        , init = init
        , update = update
        , subscriptions = always Sub.none
        }


type Msg
    = NoOp
    | ChangeLocation Navigation.Location
    | LoadingHomeMsg LoadingHome.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.pageState ) of
        ( ChangeLocation location, _ ) ->
            let
                newRoute =
                    Routing.fromLocation location

                _ =
                    Debug.log "new route" (toString newRoute)
            in
                setRoute newRoute model

        ( LoadingHomeMsg subMsg, Transitioning oldPage (LoadingHome subModel) ) ->
            let
                _ =
                    Debug.log "msg" (toString subMsg)

                transitionStatus =
                    LoadingHome.update subMsg subModel

                _ =
                    Debug.log "status" (toString transitionStatus)

                -- @todo fix offcourse
                ( newModel, newCmd ) =
                    case transitionStatus of
                        TransitionStatus.Pending ( resultModel, resultCmd ) progression ->
                            { model
                                | pageState =
                                    Transitioning
                                        oldPage
                                        (LoadingHome resultModel)
                            }
                                ! [ Cmd.map LoadingHomeMsg resultCmd ]

                        TransitionStatus.Success data ->
                            { model
                                | pageState = Loaded (HomePage data)
                            }
                                ! []

                        TransitionStatus.Failed error ->
                            { model
                                | pageState = Loaded (ErroredPage error)
                            }
                                ! []
            in
                ( newModel, newCmd )

        ( NoOp, _ ) ->
            ( model, Cmd.none )

        ( _, _ ) ->
            let
                _ =
                    Debug.log "wrong message for state" (toString ( msg, model.pageState ))
            in
                ( model, Cmd.none )


setRoute : Maybe Routing.Route -> Model -> ( Model, Cmd Msg )
setRoute maybeRoute model =
    case maybeRoute of
        Nothing ->
            { model | pageState = Loaded NotFoundPage } ! []

        Just Routing.Home ->
            let
                oldPage =
                    getVisualPage model.pageState

                ( newModel, newCmd ) =
                    LoadingHome.init
            in
                { model | pageState = Transitioning oldPage (LoadingHome newModel) }
                    ! [ Cmd.map LoadingHomeMsg newCmd ]

        Just Routing.AllItemCollections ->
            model ! []

        Just Routing.UserAgreement ->
            { model | pageState = Loaded (UserAgreementPage (UserAgreement.init)) } ! []


getVisualPage : PageState -> Page
getVisualPage pageState =
    case pageState of
        Loaded page ->
            page

        Transitioning page _ ->
            page


view : Model -> Html Msg
view model =
    case model.pageState of
        Loaded page ->
            viewPage page

        Transitioning oldPage transitionData ->
            viewPage oldPage
                |> viewLoading


viewPage : Page -> Html Msg
viewPage page =
    case page of
        BlankPage ->
            Blank.view

        NotFoundPage ->
            NotFound.view

        ErroredPage model ->
            Errored.view model

        HomePage model ->
            Home.view model

        UserAgreementPage model ->
            UserAgreement.view model


viewLoading : Html Msg -> Html Msg
viewLoading content =
    div
        []
        [ div [] [ h1 [] [ text "Loading..." ] ]
        , content
        ]
