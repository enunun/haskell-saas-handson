{-# LANGUAGE OverloadedStrings #-}

module User.Error
  ( UserError (..)
  , throwUserError
  , toServerError
  ) where

import Control.Monad.Except (throwError)
import Data.Aeson (ToJSON (..), encode, object, (.=))
import Data.Text (Text)
import Network.HTTP.Types.Header (Header, hContentType)
import Servant (Handler, ServerError (..), err400, err403)

-- | User機能のドメインエラー。「何が・なぜ失敗したか」をHTTPの都合
-- （ステータスコード）から切り離した型として表現する。ServantのHandler
-- は最終的にServerError（HTTPステータスコード・ボディを持つ）を要求する
-- ため、toServerErrorで変換する。
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

-- | TODO: UserErrorをHTTPレスポンス（ステータスコード・JSONボディ）に
-- 変換し、test/unit/User/UserSpec.hs・test/integration/User/UserSpec.hs
-- をGREENにすること。
-- ヒント：
-- - ForbiddenはServant.err403に、InvalidEmailはServant.err400に対応
--   させる。
-- - jsonErrorヘルパー（下）を使うと、「ServerErrorのerrBodyにUserErrorを
--   JSONエンコードして詰め、Content-Typeヘッダを追加する」という
--   共通処理を1回書くだけで済む。
toServerError :: UserError -> ServerError
toServerError _ = error "TODO: Iteration 5で実装する"

-- | ServerErrorのひな形（err400・err403等）にUserErrorをJSONエンコード
-- したボディとContent-Typeヘッダを追加する。
jsonError :: ServerError -> UserError -> ServerError
jsonError base e = base { errBody = encode e, errHeaders = jsonContentType : errHeaders base }

jsonContentType :: Header
jsonContentType = (hContentType, "application/json")

throwUserError :: UserError -> Handler a
throwUserError = throwError . toServerError
