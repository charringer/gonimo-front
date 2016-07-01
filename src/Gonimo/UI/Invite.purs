module Gonimo.UI.Invite where



import Prelude
import Gonimo.UI.Html
import Gonimo.Client.Effects as Gonimo
import Gonimo.Client.LocalStorage as Key
import Gonimo.Client.Types as Client
import Pux.Html.Attributes as A
import Pux.Html.Events as E
import Browser.LocalStorage (STORAGE, localStorage)
import Control.Monad.Aff (Aff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Except.Trans (runExceptT)
import Control.Monad.Reader.Trans (runReaderT)
import Data.Either (Either(Right, Left))
import Data.Maybe (isJust, isNothing, Maybe(..))
import Data.Tuple (Tuple(Tuple))
import Gonimo.Client.Effects (handleError)
import Gonimo.Client.Types (Effects, Settings, runEffectsT)
import Gonimo.Pux (noEffects, justEffect, onlyEffects, EffModel(EffModel))
import Gonimo.Server.Types (AuthToken, AuthToken(GonimoSecret))
import Gonimo.Types (Key(Key), Family(Family), Secret(Secret))
import Gonimo.WebAPI (postInvitations, postFamilies, SPParams_(SPParams_), postAccounts)
import Gonimo.WebAPI.Types (AuthData(AuthData))
import Partial.Unsafe (unsafeCrashWith)
import Pux (renderToDOM, fromSimple, start)
import Pux.Html (button, input, p, h1, text, span, Html, img, div)
import Servant.PureScript.Affjax (AjaxError)
import Servant.PureScript.Settings (defaultSettings, SPSettings_(SPSettings_))
import Signal (constant, Signal)


type State =
  { familyName :: String
  , email      :: String
  , familyId   :: Maybe (Key Family)
  , invitationSent :: Boolean
  , errorOccurred :: Maybe Client.Error
  }

init :: State
init = { familyName : "Family"
       , email : ""
       , familyId : Nothing
       , invitationSent : false
       , errorOccurred : Nothing
       }


data Action = SetFamilyName String
            | SetEmail String
            | SendInvitation
            | InvitationSent
            | ReportError Client.Error
            | Nop


update :: forall eff. Settings -> Action -> State -> EffModel eff State Action
update settings action = case action of
  (SetFamilyName name ) -> \state -> noEffects state { familyName = name }
  (SetEmail email )     -> \state -> noEffects state { email = email }
  InvitationSent        -> \state -> noEffects state { invitationSent = true }
  SendInvitation        -> \state -> justEffect (runEffect settings (handleSendInvitation state)) state
  Nop                   -> noEffects
  ReportError err       -> \state -> justEffect (Gonimo.handleError Nop err) state { errorOccurred = Just err }


handleSendInvitation :: forall eff. State -> Effects eff Action
handleSendInvitation state = do
  fid <- case state.familyId of
    Nothing   -> postFamilies state.familyName
    Just fid' -> pure fid'
  (Tuple invId invitation) <- postInvitations fid
  pure InvitationSent

runEffect :: forall eff. Settings -> Effects eff Action
             -> Aff (Client.EffEffects eff) Action
runEffect settings m = do
    er <- runExceptT <<< flip runReaderT settings <<< runEffectsT $ m
    case er of
      Left err -> pure $ ReportError err
      Right v -> pure v

--------------------------------------------------------------------------------

view :: State -> Html Action
view state = if state.invitationSent
  then viewSent state
  else viewSend state

viewSend :: State -> Html Action
viewSend state =
  div []
      [ h1 [] [ text "Welcome To Gonimo!"]
      , p []  [ text $ "In order to get you started, invite a second device via email to your family " <> state.familyName <> ":"]
      , div []
            [ p []
                if isNothing state.familyId -- We can only set the family name here, if we are creating one!
                then
                  [ text "FamilyName: "
                  , input [ A.type_ "text"
                          , E.onInput $ \ev -> SetFamilyName ev.target.value
                          , A.value state.familyName
                          ] []
                  ]
                else
                  []
            , p []
                [ text "email Address: "
                , input [ A.type_ "text"
                        , E.onInput $ \ev -> SetEmail ev.target.value
                        , A.value state.email
                        ] []
                ]
            , button [ E.onClick $ const $ SendInvitation ]
                      [ text "Send Invitation!" ]
            , p []
                if isJust state.errorOccurred
                then [ text $ "Error occurred!"]
                else []
            ]
      ]

viewSent :: State -> Html Action
viewSent state = viewLogo $ text "Invitation sucessfully sent!"