{-# LANGUAGE OverloadedStrings #-}

module User.UserSpec (spec) where

import Auth.Types (AuthenticatedUser (..), Role (..), TenantId (..))
import Logging (LogEntry (..), LogLevel (Warn))
import Logging.Capturing (newCapturingLogger)
import Servant ((:<|>) (..), err404)
import Servant.Server (runHandler)
import Test.Hspec
import User.Server (isValidEmail, server)
import User.Repository.InMemory (newInMemoryUserRepository)
import User.Types (CreateUserRequest (..), User (..))

acmeAdmin :: AuthenticatedUser
acmeAdmin = AuthenticatedUser "alice" (TenantId "acme") Admin

acmeMember :: AuthenticatedUser
acmeMember = AuthenticatedUser "carol" (TenantId "acme") Member

globexAdmin :: AuthenticatedUser
globexAdmin = AuthenticatedUser "bob" (TenantId "globex") Admin

spec :: Spec
spec = do
  describe "User（単体）" $ do
    it "adminがPOST /usersでユーザーを作成すると、id=1から採番される" $ do
      repo <- newInMemoryUserRepository
      (logger, _getLogs) <- newCapturingLogger
      let createUserHandler :<|> _ :<|> _ = server logger repo
      result <- runHandler (createUserHandler acmeAdmin (CreateUserRequest "Alice" "alice@example.com"))
      result `shouldBe` Right (User 1 "Alice" "alice@example.com")

    it "同一テナント内で2人目に作成したユーザーはid=2になる" $ do
      repo <- newInMemoryUserRepository
      (logger, _getLogs) <- newCapturingLogger
      let createUserHandler :<|> _ :<|> _ = server logger repo
      _ <- runHandler (createUserHandler acmeAdmin (CreateUserRequest "Alice" "alice@example.com"))
      result <- runHandler (createUserHandler acmeAdmin (CreateUserRequest "Carol" "carol@example.com"))
      result `shouldBe` Right (User 2 "Carol" "carol@example.com")

    it "異なるテナントの1人目のユーザーもid=1になる（採番系列がテナントごとに独立）" $ do
      repo <- newInMemoryUserRepository
      (logger, _getLogs) <- newCapturingLogger
      let createUserHandlerAcme :<|> _ :<|> _ = server logger repo
      _ <- runHandler (createUserHandlerAcme acmeAdmin (CreateUserRequest "Alice" "alice@example.com"))
      result <- runHandler (createUserHandlerAcme globexAdmin (CreateUserRequest "Bob" "bob@example.com"))
      result `shouldBe` Right (User 1 "Bob" "bob@example.com")

    it "memberがPOST /usersを呼ぶと403相当（Forbidden）になり、警告ログが記録される" $ do
      repo <- newInMemoryUserRepository
      (logger, getLogs) <- newCapturingLogger
      let createUserHandler :<|> _ :<|> _ = server logger repo
      result <- runHandler (createUserHandler acmeMember (CreateUserRequest "Alice" "alice@example.com"))
      case result of
        Left _  -> pure ()
        Right _ -> expectationFailure "memberによる作成は拒否されるべき"
      logs <- getLogs
      map logEntryMessage logs `shouldBe` ["user_creation_forbidden"]
      map logEntryLevel logs `shouldBe` [Warn]

    it "不正な形式のメールアドレスは拒否される（InvalidEmail）" $ do
      repo <- newInMemoryUserRepository
      (logger, _getLogs) <- newCapturingLogger
      let createUserHandler :<|> _ :<|> _ = server logger repo
      result <- runHandler (createUserHandler acmeAdmin (CreateUserRequest "Alice" "not-an-email"))
      case result of
        Left _  -> pure ()
        Right _ -> expectationFailure "不正なメールアドレスは拒否されるべき"

    it "GET /usersは自テナントのユーザーだけを返す" $ do
      repo <- newInMemoryUserRepository
      (logger, _getLogs) <- newCapturingLogger
      let createUserHandler :<|> listUsersHandler :<|> _ = server logger repo
      _ <- runHandler (createUserHandler acmeAdmin (CreateUserRequest "Alice" "alice@example.com"))
      _ <- runHandler (createUserHandler globexAdmin (CreateUserRequest "Bob" "bob@example.com"))
      result <- runHandler (listUsersHandler acmeAdmin)
      result `shouldBe` Right [User 1 "Alice" "alice@example.com"]

    it "GET /users/{id}は自テナントの該当するidのユーザーを返す" $ do
      repo <- newInMemoryUserRepository
      (logger, _getLogs) <- newCapturingLogger
      let createUserHandler :<|> _ :<|> getUserHandler = server logger repo
      _ <- runHandler (createUserHandler acmeAdmin (CreateUserRequest "Alice" "alice@example.com"))
      result <- runHandler (getUserHandler acmeAdmin 1)
      result `shouldBe` Right (User 1 "Alice" "alice@example.com")

    it "GET /users/{id}は存在しないidに対して404を返す" $ do
      repo <- newInMemoryUserRepository
      (logger, _getLogs) <- newCapturingLogger
      let _ :<|> _ :<|> getUserHandler = server logger repo
      result <- runHandler (getUserHandler acmeAdmin 999)
      result `shouldBe` Left err404

    it "GET /users/{id}は他テナントが作成したidに対しても404を返す（テナント分離）" $ do
      repo <- newInMemoryUserRepository
      (logger, _getLogs) <- newCapturingLogger
      let createUserHandler :<|> _ :<|> getUserHandler = server logger repo
      _ <- runHandler (createUserHandler acmeAdmin (CreateUserRequest "Alice" "alice@example.com"))
      result <- runHandler (getUserHandler globexAdmin 1)
      result `shouldBe` Left err404

  describe "isValidEmail" $ do
    it "local@domainの形式ならTrue" $
      isValidEmail "alice@example.com" `shouldBe` True

    it "@がなければFalse" $
      isValidEmail "alice" `shouldBe` False

    it "@の前後どちらかが空ならFalse" $ do
      isValidEmail "@example.com" `shouldBe` False
      isValidEmail "alice@" `shouldBe` False
