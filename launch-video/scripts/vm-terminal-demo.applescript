on run argv
    set demoCommand to item 1 of argv
    tell application "Terminal"
        activate
        set demoTab to do script demoCommand
        delay 0.5
        set current settings of demoTab to settings set "Pro"
        set font name of current settings of demoTab to "SF Mono"
        set font size of current settings of demoTab to 24
        set background color of current settings of demoTab to {0, 0, 0}
        set bounds of front window to {90, 90, 1830, 990}
    end tell
end run
