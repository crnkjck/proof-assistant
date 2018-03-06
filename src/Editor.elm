module Editor exposing (Model, Msg(..), initialModel, render, subscriptions, update)

import Bootstrap.Button as Button
import Bootstrap.Dropdown as Dropdown
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.InputGroup as InputGroup
import ErrorHandler
import Html
import Html.Attributes
import Html.Events
import Zipper


-- Model


type alias Model =
    { proof : Zipper.Zipper }


initialModel : Model
initialModel =
    { proof =
        Zipper.create "(q -> p)"
            |> Zipper.add (Zipper.createElement "((q -> r) & (r-> q))")
            |> Zipper.downOrStop
            |> Zipper.toggleContradiction
            |> Zipper.enterContradictionOrStop
            |> Zipper.edit "(q -> r)"
            |> Zipper.add (Zipper.createElement "(r -> q)")
            |> Zipper.leaveContradictionOrStop
            |> Zipper.downOrStop
            |> Zipper.add (Zipper.createElement "(p -> r)")
            |> Zipper.downOrStop
            |> Zipper.downOrStop
            |> Zipper.add (Zipper.createElement "((a&b) | b)")
            |> Zipper.downOrStop
            |> Zipper.toggleCases
            |> Zipper.enterCase1OrStop
            |> Zipper.edit "(a & b)"
            |> Zipper.downOrStop
            |> Zipper.add (Zipper.createElement "b")
            |> Zipper.add (Zipper.createElement "a")
            |> Zipper.upOrStop
            |> Zipper.leaveContradictionOrStop
            |> Zipper.root
    }



-- Update


type Msg
    = ZipperAdd Zipper.Zipper
    | ZipperEdit Zipper.Zipper String
    | ShowButtons Zipper.Zipper Bool
    | DeleteProofStep Zipper.Zipper
    | ToggleContradiction Zipper.Zipper
    | ToggleCases Zipper.Zipper
    | DropdownMsg Zipper.Zipper Dropdown.State
    | UpdateDropdownState Zipper.Zipper Zipper.DropdownStates


update : Msg -> Model -> Model
update msg model =
    case msg of
        ZipperAdd zipper ->
            { model | proof = Zipper.add (Zipper.createElement "") zipper }

        ZipperEdit zipper value ->
            { model | proof = Zipper.edit value zipper }

        ShowButtons zipper state ->
            let
                oldGui =
                    Zipper.getGUI zipper

                newGui =
                    { oldGui | showButtons = state }
            in
            { model | proof = Zipper.setGUI newGui zipper }

        DeleteProofStep zipper ->
            { model | proof = Zipper.delete zipper }

        ToggleContradiction zipper ->
            { model | proof = Zipper.toggleContradiction zipper }

        ToggleCases zipper ->
            { model | proof = Zipper.toggleCases zipper }

        DropdownMsg zipper state ->
            let
                oldGui =
                    Zipper.getGUI zipper

                newGui =
                    { oldGui | dropdown = state }
            in
            { model | proof = Zipper.setGUI newGui zipper }

        UpdateDropdownState zipper state ->
            let
                oldElement =
                    Zipper.getElementFromSteps zipper.steps

                newElement =
                    { oldElement | dropdownType = state }

                newSteps =
                    Zipper.setElementInSteps newElement zipper.steps

                newProof =
                    { zipper | steps = newSteps }
            in
            { model | proof = newProof }



-- View


render : Model -> Html.Html Msg
render model =
    renderProof <| Zipper.root model.proof



-- Helpers


emptyNode : Html.Html Msg
emptyNode =
    Html.text ""


renderProof : Zipper.Zipper -> Html.Html Msg
renderProof zipper =
    Form.form [] [ Html.div [] (renderProofHelper zipper) ]


renderProofHelper : Zipper.Zipper -> List (Html.Html Msg)
renderProofHelper zipper =
    let
        base =
            renderLine zipper

        rest =
            case Zipper.down zipper of
                Nothing ->
                    []

                Just nextZipper ->
                    renderProofHelper nextZipper
    in
    base :: rest


renderButtons : Zipper.Zipper -> Maybe String -> Maybe String -> Html.Html Msg
renderButtons zipper contradictionText casesText =
    let
        contradictionButton =
            case contradictionText of
                Nothing ->
                    emptyNode

                Just text ->
                    Button.button
                        [ Button.onClick <| ToggleContradiction zipper
                        , Button.outlineInfo
                        , Button.attrs [ Html.Attributes.class "ml-1" ]
                        ]
                        [ Html.text text ]

        casesButton =
            case casesText of
                Nothing ->
                    emptyNode

                Just text ->
                    Button.button
                        [ Button.onClick <| ToggleCases zipper
                        , Button.outlineInfo
                        , Button.attrs [ Html.Attributes.class "ml-1" ]
                        ]
                        [ Html.text text ]
    in
    Html.div []
        [ Button.button
            [ Button.onClick <| ZipperAdd zipper
            , Button.outlineSuccess
            , Button.attrs [ Html.Attributes.class "ml-1" ]
            ]
            [ Html.text "+" ]
        , Button.button
            [ Button.onClick <| DeleteProofStep zipper
            , Button.outlineDanger
            , Button.attrs [ Html.Attributes.class "ml-1" ]
            ]
            [ Html.text "x" ]
        , contradictionButton
        , casesButton
        ]


innerStyle =
    Html.Attributes.style
        [ ( "border", "1px solid #cfcfcf" )
        , ( "padding", "20px 20px 20px 30px" )
        , ( "box-shadow", "0 0 5px #cfcfcf" )
        , ( "margin-bottom", "20px" )
        ]


renderContradiction : Zipper.Zipper -> Html.Html Msg
renderContradiction zipper =
    Html.div [ innerStyle ]
        (Html.h4
            []
            [ Html.text "By contradiction:" ]
            :: renderProofHelper (Zipper.enterContradictionOrStop zipper)
        )


renderCases : Zipper.Zipper -> Html.Html Msg
renderCases zipper =
    let
        renderCaseInput text =
            Html.div
                [ Html.Attributes.style [ ( "margin-bottom", "20px" ) ] ]
                [ InputGroup.config
                    (InputGroup.text
                        [ Input.value text
                        , Input.disabled True
                        , Input.success
                        ]
                    )
                    |> InputGroup.view
                ]
    in
    Html.div []
        [ Html.div [ innerStyle ]
            [ Html.h4 [] [ Html.text "Case 1" ]
            , renderCaseInput <| Zipper.getCase1Value zipper
            , Html.div [] (renderProofHelper <| Zipper.enterCase1OrStop zipper)
            ]
        , Html.div [ innerStyle ]
            [ Html.h4 [] [ Html.text "Case 2" ]
            , renderCaseInput <| Zipper.getCase2Value zipper
            , Html.div [] (renderProofHelper <| Zipper.enterCase2OrStop zipper)
            ]
        ]


renderLine : Zipper.Zipper -> Html.Html Msg
renderLine zipper =
    let
        ( contradictionText, casesText, disabled, subElements ) =
            case Zipper.getProofTypeFromSteps zipper.steps of
                Zipper.Normal _ ->
                    ( Just "Contradict", Just "Cases", False, emptyNode )

                Zipper.Contradiction _ _ ->
                    ( Just "Undo contradict", Nothing, True, renderContradiction zipper )

                Zipper.Cases _ _ _ ->
                    -- todo
                    ( Nothing, Just "Undo cases", True, renderCases zipper )

        ( errorNode, inputStatus ) =
            case ErrorHandler.handleErrors zipper of
                Ok _ ->
                    ( emptyNode, Input.success )

                Err error ->
                    ( Form.invalidFeedback [] [ Html.text <| "WTF?" ++ error ]
                    , Input.danger
                    )

        showButtons =
            (Zipper.getGUI zipper).showButtons

        buttons =
            if showButtons then
                renderButtons zipper contradictionText casesText
            else
                emptyNode
    in
    Html.div []
        [ Form.group []
            [ InputGroup.config
                (InputGroup.text
                    [ Input.placeholder "Formula"
                    , Input.value <| Zipper.getValue zipper
                    , Input.onInput <| ZipperEdit zipper
                    , Input.disabled disabled
                    , inputStatus
                    ]
                )
                |> InputGroup.predecessors
                    [ InputGroup.dropdown
                        (Zipper.getGUI zipper).dropdown
                        { options = []
                        , toggleMsg = DropdownMsg zipper
                        , toggleButton =
                            Dropdown.toggle
                                [ Button.outlineSecondary ]
                                [ Html.text <| toString <| (Zipper.getElement zipper).dropdownType ]
                        , items =
                            List.map
                                (\state ->
                                    Dropdown.buttonItem
                                        [ Html.Events.onClick <| UpdateDropdownState zipper state
                                        ]
                                        [ Html.text <| toString state ]
                                )
                                Zipper.dropdownStates
                        }
                    ]
                |> InputGroup.successors
                    [ InputGroup.button
                        [ Button.outlineInfo
                        , Button.onClick <| ShowButtons zipper (not showButtons)
                        ]
                        [ Html.text "?" ]
                    ]
                |> InputGroup.view
            , errorNode
            , Form.validFeedback [] [ Html.text "All good !" ]
            , Form.invalidFeedback [] [ Html.text "All good !" ]
            , buttons
            ]
        , subElements
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Dropdown.subscriptions (Zipper.getGUI model.proof).dropdown (DropdownMsg model.proof)
        ]



-- todo: nechapem preco to hove funguje, podla mna by nemalo.
--subscriptions : Model -> Sub Msg
--subscriptions model =
--    Sub.batch <|
--        List.map
--            (\zipper ->
--                Dropdown.subscriptions
--                    (Zipper.getGUI <| Zipper.root zipper).dropdown
--                    (DropdownMsg zipper)
--            )
--            (Debug.log "zippers:" (Zipper.getAllZipperStates model.proof))
