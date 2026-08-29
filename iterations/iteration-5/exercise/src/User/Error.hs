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

-- | TODO: UserErrorを、対応するHTTPステータスコード・JSONボディを持つ
-- ServerErrorに変換し、throwErrorで投げること。
-- ヒント：
-- - Forbiddenはerr403、InvalidEmailはerr400に対応させる。
-- - `base { errBody = ..., errHeaders = ... }`のようにレコード更新
--   構文で、`Servant`が用意した既定の`ServerError`値（`err403`・
--   `err400`）のボディ・ヘッダだけを差し替える。
-- - `Data.Aeson`の`encode`と`object`・`.=`で、
--   `{"error":"forbidden"}`のようなJSON値をLazy ByteStringに
--   エンコードできる。`InvalidEmail`の場合は`email`キーに不正だった
--   値も含めるとよい。
-- - JSONを返すので、`errHeaders`に`("Content-Type", "application/json")`
--   を追加しておく（既定の`err403`・`err400`はJSON以外のContent-Type
--   を持つ）。
throwUserError :: UserError -> Handler a
throwUserError _ = error "TODO: Iteration 5で実装する"
