import XMonad
import qualified XMonad.StackSet as W
import System.Environment (lookupEnv)

main :: IO ()
main = do
  protocol <- lookupEnv "FIREFOX_CONTROL_PROTOCOL"
  xmonad def
    { borderWidth        = 0
    , focusFollowsMouse  = True
    , layoutHook         = Full
    -- Background window creation must not replace the owner's focus.
    -- Transient extension/security dialogs keep normal manageHook behavior.
    , manageHook         = manageHook def <+> (if protocol == Just "firefox-windows-v3"
        then resource =? "Navigator" --> doF W.focusDown else mempty)
    , startupHook        = spawn "xsetroot -solid black"
    , terminal           = "false"
    }
