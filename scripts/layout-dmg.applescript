-- Lays out the mounted installer image: fixes the window size, applies the
-- background picture and puts the app and the Applications shortcut where the
-- background arrow points. Finder owns this state; there is no command-line way
-- to write it, so the layout is scripted here and run against the mounted
-- read-write image before it is compressed.
--
-- Everything is wrapped so a refused Finder automation permission leaves a
-- plain but working disk image rather than failing the build.
--
-- Usage: osascript scripts/layout-dmg.applescript <volume-name> <app-name>

on run argv
	set volName to item 1 of argv
	set appName to item 2 of argv
	set bgPath to "/Volumes/" & volName & "/.background/background.png"

	tell application "Finder"
		try
			tell disk volName
				open
				delay 1
				set current view of container window to icon view
				set toolbar visible of container window to false
				set statusbar visible of container window to false
				set the bounds of container window to {200, 140, 860, 560}
				set theViewOptions to the icon view options of container window
				set arrangement of theViewOptions to not arranged
				set icon size of theViewOptions to 112
				set shows icon preview of theViewOptions to true
				try
					set background picture of theViewOptions to (POSIX file bgPath)
				end try
				try
					set position of item (appName & ".app") of container window to {150, 200}
				end try
				try
					set position of item "Applications" of container window to {510, 200}
				end try
				update without registering applications
				delay 1
				close
			end tell
			return "layout applied"
		on error errMsg
			return "layout skipped: " & errMsg
		end try
	end tell
end run
