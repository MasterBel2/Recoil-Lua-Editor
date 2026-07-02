# Lua File Editor
A file editing widget for Beyond All Reason.

## Install
Lua File Editor's project folder can be dropped directly inside your `LuaUI/Widgets` folder, e.g. such that `gui_lua_file_editor.lua` is present at `LuaUI/Widgets/Lua File Editor/gui_lua_file_editor.lua`, and similar for all other files.

Lua File Editor depends on [MasterBel2's GUI Framework](https://github.com/MasterBel2/Master-GUI-Framework). Mainline dev currently targets the GUI framework's mainline development branch: use `local requiredFrameworkVersion = "Dev"`. Individual releases are planned to be packaged with a specific release version of the framework, e.g. `local requiredFrameworkVersion = 42`.