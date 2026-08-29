{-# LANGUAGE OverloadedStrings #-}

module User.Error
  ( UserError (..)
  , throwUserError
  ) where

import Control.Monad.Except (throwError)
import Data.Aeson (Value, encode, object, (.=))
import Data.Text (Text)
import Servant (Handler, ServerError (errBody, errHeaders), err400, err403)

-- | HTTPの都合（ステータスコード）から独立したドメインエラー型。
-- 「権限がない」（Forbidden）と「入力が不正」（InvalidEmail）は、
-- どちらもHTTPでは4xx系のエラーだが、ドメインとしては異なる種類の
-- 失敗である。`InvalidEmail`が不正だった値自体を持つのに対し、
-- `Forbidden`は追加の情報を持たない。この型自体はHTTPを一切知らない。
data UserError
  = Forbidden
  | InvalidEmail Text
  deriving (Show, Eq)

-- | UserErrorを、対応するHTTPステータスコード・JSONボディを持つ
-- ServerErrorに変換し、Handlerモナドの中で投げる。HTTPへの変換ロジックは
-- ここ1箇所にまとめる。
throwUserError :: UserError -> Handler a
throwUserError err = throwError (base { errBody = encode (errorBody err), errHeaders = jsonContentType : errHeaders base })
  where
    base = case err of
      Forbidden      -> err403
      InvalidEmail _ -> err400

    jsonContentType = ("Content-Type", "application/json")

    errorBody :: UserError -> Value
    errorBody Forbidden = object ["error" .= ("forbidden" :: String)]
    errorBody (InvalidEmail email) =
      object ["error" .= ("invalid_email" :: String), "email" .= email]
