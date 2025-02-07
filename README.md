# HC3Emu

HC3Emu is a Lua-based emulator designed to simulate the behavior of Fibaro Home Center 3 QuickApp runtime. This emulator allows users to run and test QuickApps in a controlled environment.

## Features

- Support of most of the fibaro SDK.
  - fibaro.*, api.*, net.HTPClient, net.TCPClient, setTimeout, setInterval, ...
- Integrates/interacts with QAs running on the HC3
- Supports running UI front-end of QA on HC3 for UI testing (proxy)
- Works both in Zerobrane and VSCode, and most other environments supporting mobdebug

## Requirements

- Lua 5.3 or higher
- luasocket >= 2.0, <= 2.2
- copas >= 4.7.1-1 (+ timer and timerwheel)
- lua-cjson-219 >= 2.1.0.9-1
- mobdebug >= 0.80-1

## Installation

1. Install with luarocks
    ```bash
    luarocks install hc3emu
    ```

## Usage

1. IDEs supported
  1. Zerobrane
  2. VSCode

## Configuration

Configure the emulator by editing the `hc3emu_cfg.lua` file. You can set various options including credentials for accessing the HC3.

Include header in QA file and set --%% directives
```lua
if not QuickApp then require("hc3emu") end

--%%name="Test"
--%%type="com.fibaro.multilevelSwitch"
--%%proxy="MyProxy"
--%%dark=true
--%%var=foo:config.secret
--%%debug=sdk:false,info:true
--%%debug=http:true,color:true

function QuickApp:onInit()
   self:debug(self.name,self.id)
end
```

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
- fibaro.setTimeout(ms,fun)
- fibaro.sleep(ms)
- fibaro.trace(...)
- fibaro.useAsyncHandler(...)
- fibaro.wakeUpDeadDevice(...)
- fibaro.warning(...)
- net.HTTPClient(...)
- net.TCPSocket(...)
- net.TESTMQTT(...)
- net.UDPSocket(...)
- mqtt.Client.connect(uri, options)
- setTimeout(fun,ms)
- setTimeout(ref)
- setInterval(fun,ms)
- clearInterval(ref)

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
