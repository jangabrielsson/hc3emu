package = "hc3emu"
version = "1.0.68-1" -- updated version to match the new version number
source = {
   url = "git://github.com/jangabrielsson/hc3emu",
   tag = "v1.0.68", -- updated tag to match version
}
description = {
   summary = "hc3emu is an emulator for developing Fibaro HC3 QuickApps offline.",
   detailed = [[
      hc3emu is an emulator for developing Fibaro HC3 QuickApps offline.
      It's based on copas for asynchronous network calls.
      It can automatically deploy a "QA proxy" on the HC3 funneling 
      onAction and uiEvents back to the QA running in the emulator, thus
      allowing the QA's UI to be tested.
   ]],
   homepage = "https://github.com/jangabrielsson/hc3emu",
   license = "MIT/X11" 
}
dependencies = {
   "lua >= 5.3, <= 5.4",
   "copas >= 4.7.1-1",
   --"luamqtt >= 3.4.3-1",
   "luamqttt >= 1.0.2-1",
   --"rapidjson >= 0.7.1-1", -- if already installed, will be used
   "lua-json >= 1.0.0-1",
   "bit32 >= 5.3.5.1-1",
   "lua-websockets-bit32 >= 2.0.1-7",
   --"luafilesystem >= 1.8.0-1", -- try to avoid this dependency...
   "argparse >= 0.7.1-1",
   "datafile >= 0.10-1",
   "mobdebug >= 0.80-1",
}
build = {
   type = "builtin",
   modules = {
      hc3emu = "src/hc3emu.lua", -- Proxy to load package or developer file
      ["hc3emu.emu"] = "src/hc3emu/emu.lua", -- The main emulator
      ["hc3emu.json"] = "src/hc3emu/json.lua",
      ["hc3emu.colors"] = "src/hc3emu/colors.lua",
      ["hc3emu.fibaro"] = "src/hc3emu/fibaro.lua",
      ["hc3emu.quickapp"] = "src/hc3emu/quickapp.lua",
      ["hc3emu.class"] = "src/hc3emu/class.lua",
      ["hc3emu.timers"] = "src/hc3emu/timers.lua",
      ["hc3emu.net"] = "src/hc3emu/net.lua",
      ["hc3emu.ui"] = "src/hc3emu/ui.lua",
      ["hc3emu.util"] = "src/hc3emu/util.lua",
      ["hc3emu.log"] = "src/hc3emu/log.lua",
      ["hc3emu.db"] = "src/hc3emu/db.lua",
      ["hc3emu.route"] = "src/hc3emu/route.lua",
      ["hc3emu.proxy"] = "src/hc3emu/proxy.lua",
      ["hc3emu.offline"] = "src/hc3emu/offline.lua",
      ["hc3emu.emuroute"] = "src/hc3emu/emuroute.lua",
      ["hc3emu.tools"] = "src/hc3emu/tools.lua",
      ["hc3emu.qa"] = "src/hc3emu/qa.lua",
      ["hc3emu.embedui"] = "src/hc3emu/embedui.lua",     
      ["hc3emu.scene"] = "src/hc3emu/scene.lua",
      ["hc3emu.sceneengine"] = "src/hc3emu/sceneengine.lua",
      ["hc3emu.refreshstate"] = "src/hc3emu/refreshstate.lua",
      ["hc3emu.refreshstateevents"] = "src/hc3emu/refreshstateevents.lua",
      ["hc3emu.webserver"] = "src/hc3emu/webserver.lua",
      ["hc3emu.simdevices"] = "src/hc3emu/simdevices.lua",
      ["hc3emu.event"] = "src/hc3emu/event.lua",
      ["hc3emu.lib"] = "src/hc3emu/lib.lua",
      ["hc3emu.sourcetrigger"] = "src/hc3emu/sourcetrigger.lua",
      ["hc3emu.qwikchild"] = "src/hc3emu/qwikchild.lua",
      ["hc3emu.eventlib"] = "src/hc3emu/eventlib.lua",
      ["hc3emu.sha2"] = "src/hc3emu/sha2.lua",
      ["hc3emu.stdStructs"] = "src/hc3emu/stdStructs.lua",
  },
  copy_directories = { "doc", "rsrcs" }
}
