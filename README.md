# HC3Emu

HC3Emu is a Lua-based emulator designed to simulate the behavior of Fibaro Home Center 3 QuickApp runtime. This emulator allows users to run and test QuickApps in a controlled environment.

## Features

- Support of most of the fibaro SDK.
  - fibaro.*, api.*, net.HTPClient, net.TCPClient, setTimeout, setInterval, ...
- Integrates/interacts with QAs running on the HC3
- Supports running UI front-end of QA on HC3 for UI testing (proxy)
- Works both in Zerobrane and VSCode, and most other environments supporting mobdebug

## Dependencies (installed by luarocks)

- Lua 5.3 or higher
- luasocket >= 2.0, <= 2.2
- copas >= 4.7.1-1 (+ timer and timerwheel)
- luamqtt >= 3.4.3-1
- lua-json >= 1.0.0-1  (will use rapidjson if installed)
- bit32 >= 5.3.5.1-1
- mobdebug >= 0.80-1

You also need to have openssl installed in the system for luasec to compile.

## Installation

1. Install with luarocks
    ```bash
    luarocks install hc3emu
    ```
    Update is just install again. To instal a specific version (ex. previous version if bugs are introduced...)
    ```bash
    luarocks install hc3emu <version>
    ```

## Usage

1. IDEs supported
  1. Zerobrane
  2. VSCode, tested with "Lua MobDebug adapter"

## Configuration

Configure the emulator by editing the `hc3emu_cfg.lua` file. You can set various options including credentials for accessing the HC3.
You can also have a ".hc3emu.lua" file in your home directory, e.g. ENV "HOME"

Include header in QA file and set --%% directives
```lua
if require and not QuickApp then require("hc3emu") end

--%%name=Test
--%%type=com.fibaro.multilevelSwitch
--%%proxy=MyProxy
--%%dark=true
--%%var=foo:config.secret
--%%debug=sdk:false,info:true
--%%debug=http:true

function QuickApp:onInit()
   self:debug(self.name,self.id)
end
```
The header is ignored when we move the code to the HC3 as the function 'require' don't exist in that environment.

## Directives
Comments in the main file starting with --%% are interpreted as configuration directives to the emulator.
- name=&lt;string>, The name of the QuickApp
- type=&lt;string>, the fibaro type
- proxy=&lt;string>, If defined is the name of the proxy on the HC3. If it doesn't exist it will be created. If the name is preceeded with a dash ,ex. "-MyProxy", a QA with that name will be deleted on the HC3 if it exists and the proxy directive is set to nil...
- dark=boolean, Sets dark mode. Affects what colors are used in the log console.
- var=name:value, defines a quickAppVariable for the QA with the name and the value. The value is an evaluated lua value. The lua table 'config' is the values read from the config files and can be used as values. In the example above, we set a quickVar 'foo' to the value in config.secret. This is a great way to initialize the QA with credentials without including them in plain sight in the code...
- debug=flag:"value", Sets various debug flags, affecting what is logged in the console.
- file=filepath:name, Loads the file as QA file with name 'name'. Will be included when saving QA to a .fqa.
- save="filename", When run it will package and save the QA as a .fqa file on disk. Ex. save="MyQA.fqa"
- state="filename", Will save the "internalStorage" keys in this file and read them back when running. Thus allowing retarts of the QA and preserve some state between runs. internalStorage is only saved in the emulator and not reflected to the HC3 proxy. quickVars are currently always set to the --%%var declaration when running.

## Supported APIs

- api.delete(...)
- api.get(...)
- api.post(...)
- api.put(...)
- fibaro.HC3EMU_VERSION
- fibaro.PASSWORD
- fibaro.URL
- fibaro.USER
- fibaro.__houseAlarm(...)
- fibaro.alarm(...)
- fibaro.alert(...)
- fibaro.call(...)
- fibaro.callGroupAction(...)
- fibaro.clearTimeout(...)
- fibaro.debug(...)
- fibaro.emitCustomEvent(...)
- fibaro.error(...)
- fibaro.get(...)
- fibaro.getDevicesID(...)
- fibaro.getGlobalVariable(...)
- fibaro.getHomeArmState(...)
- fibaro.getIds(...)
- fibaro.getName(...)
- fibaro.getPartition(...)
- fibaro.getPartitionArmState(...)
- fibaro.getPartitions(...)
- fibaro.getRoomID(...)
- fibaro.getRoomName(...)
- fibaro.getRoomNameByDeviceID(...)
- fibaro.getSectionID(...)
- fibaro.getType(...)
- fibaro.getValue(...)
- fibaro.hc3emu
- fibaro.isHomeBreached(...)
- fibaro.isPartitionBreached(...)
- fibaro.profile(...)
- fibaro.scene(...)
- fibaro.setGlobalVariable(...)
- fibaro.setTimeout(...)
- fibaro.sleep(...)
- fibaro.trace(...)
- fibaro.useAsyncHandler(...)
- fibaro.wakeUpDeadDevice(...)
- fibaro.warning(...)
- net.HTTPClient(...)
- net.TCPSocket(...)
- net.UDPSocket(...)
- plugin._dev
- plugin._quickApp
- plugin.createChildDevice(...)
- plugin.deleteDevice(...)
- plugin.getChildDevices(...)
- plugin.getDevice(...)
- plugin.getProperty(...)
- plugin.mainDeviceId
- plugin.restart(...)
- json.encode(expr)
- json.decode(str)
- setTimeout(fun,ms)
- clearTimeout(ref)
- setInterval(fun,ms)
- clearInterval(ref)
- class <name>(<parent>)
- property(...)
- class QuickAppBase()
- class QuickApp()
- class QuickAppChild
- hub = fibaro

## Contributing

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -m 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [List any acknowledgments or references]
