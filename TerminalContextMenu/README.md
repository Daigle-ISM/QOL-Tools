# Terminal Context Menu
This is a registry change to adjust the behaviour of the "Open in Terminal" shortcut in the file explorer context menu.

The original behaviour creates a new Terminal window every time. If you're used to using tabbed browsing, this is usually undesirable.

The new behaviour creates a new tab in the existing Terminal window by adding `-w 0` to the command to start wt.exe. If multiple Terminal windows are open, the last one to have focus will get the new tab

![Demo Video](TermDemo.mkv)