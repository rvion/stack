{-# LANGUAGE CPP               #-}
{-# LANGUAGE OverloadedStrings #-}

module Stack.Sig.Config where

{-|
Module      : Stack.Sig.Config
Description : Config File Functions
Copyright   : (c) FPComplete.com, 2015
License     : BSD3
Maintainer  : Tim Dysinger <tim@fpcomplete.com>
Stability   : experimental
Portability : POSIX
-}

import           Control.Applicative ((<$>))
import           Control.Exception (throwIO)
import           Control.Monad (when)
import qualified Data.ByteString as B
import           Data.Maybe (fromJust)
import           Data.Monoid ((<>))
import qualified Data.Set as Set
import           Data.Time ( formatTime, getCurrentTime )
import qualified Data.Yaml as Y
import           Stack.Sig.Defaults
import           Stack.Sig.Types (SigException(..), Config(..), Signer(..))
import           System.Directory (renameFile, getHomeDirectory, doesFileExist,
                                   createDirectoryIfMissing)
import           System.FilePath ( (</>) )
import           Text.Email.Validate ( emailAddress )

#if MIN_VERSION_time(1,5,0)
import           Data.Time (defaultTimeLocale)
#else
import           System.Locale (defaultTimeLocale)
#endif

defaultSigners :: [Signer]
defaultSigners = [ Signer
                   { signerFingerprint = "ADD9 EB09 887A BE32 3EF7  F701 2141 7080 9616 E227"
                   , signerEmail = fromJust (emailAddress "chrisdone@gmail.com")
                   }
                 , Signer
                   { signerFingerprint = "5E6C 66B2 78BD B10A A636  57FA A048 E8C0 57E8 6876"
                   , signerEmail = fromJust (emailAddress "michael@snoyman.com")
                   }
                 , Signer
                   { signerFingerprint = "8C69 4F5B 6941 3F16 736F  E055 A9E6 D147 44A5 2A60"
                   , signerEmail = fromJust (emailAddress "tim@dysinger.net")
                   }]

defaultConfig :: Config
defaultConfig = Config defaultSigners

readConfig :: IO Config
readConfig = do
    home <- getHomeDirectory
    let cfg = home </> configDir </> configFile
    result <- Y.decodeEither <$> B.readFile cfg
    case result of
        Left msg -> throwIO
                (ConfigParseException
                     (show msg))
        Right config -> return config

writeConfig :: Config -> IO ()
writeConfig cfg = do
    home <- getHomeDirectory
    let configPath = home </> configDir </> configFile
    oldExists <- doesFileExist configPath
    when
        oldExists
        (do time <- getCurrentTime
            renameFile
                configPath
                (formatTime
                     defaultTimeLocale
                     (configPath <> "-%s")
                     time))
    createDirectoryIfMissing
        True
        (home </> configDir)
    B.writeFile
        configPath
        (Y.encode
             cfg
             { configTrustedMappingSigners = ordNub
                   (defaultSigners ++ configTrustedMappingSigners cfg)
             })
    where ordNub l = go Set.empty l
          go _ [] = []
          go s (x:xs) = if x `Set.member` s
                  then go s xs
                  else x :
                       go (Set.insert x s) xs

writeConfigIfMissing :: Config -> IO ()
writeConfigIfMissing cfg = do
    home <- getHomeDirectory
    let configPath = home </> configDir </> configFile
    fileExists <- doesFileExist configPath
    when
        (not fileExists)
        (writeConfig cfg)

addSigner :: Config -> Signer -> IO ()
addSigner cfg signer = writeConfig
        (cfg
         { configTrustedMappingSigners = (signer :
                                          (configTrustedMappingSigners cfg))
         })