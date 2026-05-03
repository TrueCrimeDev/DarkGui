#Requires AutoHotkey v2.1-alpha.14
#SingleInstance Force
#include <DarkListView>

myGui := Gui(, "ListView")
myGui.AddListView("Count100 LV0x8000 R10 W400 cWhite Background0x202020", ["Select", "Number", "Description"]).SetDarkMode()
myGui.Show()