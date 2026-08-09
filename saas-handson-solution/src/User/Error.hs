{-# LANGUAGE OverloadedStrings #-}

module User.Error
  ( UserError (..)
  , throwUserError
  ) where

import Control.Monad.Except (throwError)
import Data.Aeson (ToJSON (..), encode, object, (.=))
import Data.Text (Text)
import Network.HTTP.Types.Header (Header, hContentType)
import Servant (Handler, ServerError (..), err400, err403)

-- | User機能のドメインエラー。「何が・なぜ失敗したか」をHTTPの都合
-- （ステータスコード）から切り離した型として表現する。ServantのHandler
-- は最終的にServerError（HTTPステータスコード・ボディを持つ）を要求する
-- ため、toServerError（このモジュール内）で変換する。
--
-- Iteration 5で追加した2種類のエラー：
--
-- * Forbidden：認証はできているが、その操作を行う権限（Role）がない
--   （403 Forbidden）。
-- * InvalidEmail：リクエストの内容自体が不正（400 Bad Request）。
data UserError
  = Forbidden
  | InvalidEmail Text
  deriving (Show, Eq)

instance ToJSON UserError where
  toJSON Forbidden =
    object
      [ "error" .= ("forbidden" :: Text)
      , "message" .= ("この操作を行う権限がありません" :: Text)
      ]
  toJSON (InvalidEmail email) =
    object
      [ "error" .= ("invalid_email" :: Text)
      , "message" .= ("メールアドレスの形式が不正です: " <> email)
      ]

-- | UserErrorをHTTPレスポンス（ステータスコード・JSONボディ）に変換する。
-- ドメインエラーの種類ごとにどのHTTPステータスへ落とすかをこの1箇所に
-- 集約することで、「403を返すべき場面で誤って400を返してしまう」
-- といった対応漏れを防ぐ。
toServerError :: UserError -> ServerError
toServerError e@Forbidden        = jsonError err403 e
toServerError e@(InvalidEmail _) = jsonError err400 e

jsonError :: ServerError -> UserError -> ServerError
jsonError base e = base { errBody = encode e, errHeaders = jsonContentType : errHeaders base }

jsonContentType :: Header
jsonContentType = (hContentType, "application/json")

throwUserError :: UserError -> Handler a
throwUserError = throwError . toServerError
