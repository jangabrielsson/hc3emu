# HC3 QuickApp Emulator
<img src="doc/hc3emu.png" width="200" alt="HC3 Emulator"/>

## Overview

HC3Emu is a Lua-based emulator designed to simulate the Fibaro Home Center 3 QuickApp runtime environment. It allows developers to develop and test QuickApps offline before deploying them to a physical HC3 controller.

Forum thread discussing the emulator (and questions) [here](https://forum.fibaro.com/topic/78728-quickapp-emulator-hc3emu/)

## Key Features

- Simulates most of the Fibaro SDK APIs
- Integrates with real HC3 controllers for testing
- Supports UI testing through proxy deployment
- Works with major Lua IDEs (Zerobrane, VSCode)
- Provides comprehensive debugging capabilities
- Supports file operations and state persistence
- Limited support for testing Scenes...

## Installation

```bash
# Install via LuaRocks
luarocks install hc3emu

# Install specific version
luarocks install hc3emu <version>

# Update to latest version
luarocks install hc3emu
```

- For Windows installation see [here](https://forum.fibaro.com/topic/78728-quickapp-emulator-hc3emu/page/2/#findComment-290650)
- For Windows WSL installation see [here](https://forum.fibaro.com/topic/78728-quickapp-emulator-hc3emu/page/2/#findComment-290649)
- For MacOS, it's pretty straight forward to install Lua and Luarocks with brew.
- For Visual Studio Code setup see [here](https://forum.fibaro.com/topic/78728-quickapp-emulator-hc3emu/#findComment-290587)
- For ZeroBrane Studio setup see [here](https://forum.fibaro.com/topic/78728-quickapp-emulator-hc3emu/page/2/#findComment-290595)

## Dependencies

- Lua 5.3 or higher
- Required packages (installed automatically by LuaRocks):
  - luasocket >= 2.0
  - copas >= 4.7.1-1
  - luamqtt >= 3.4.3-1
  - lua-json >= 1.0.0-1
  - bit32 >= 5.3.5.1-1
  - lua-websockets-bit32 >= 2.0.1-7
  - argparse >= 0.7.1-1
  - mobdebug >= 0.80-1
- System requirement: openssl

## Configuration

### Global Configuration

The emulator can be configured through:
1. `hc3emu_cfg.lua` in the project directory
2. `.hc3emu.lua` in the user's home directory. Put credentials here so they don't polute project directory.

### QuickApp Configuration

QuickApps are configured using special directives in comments starting with `--%%`:

```lua
if require and not QuickApp then require("hc3emu") end

--%%name=MyQuickApp               # Name of the QuickApp
--%%type=com.fibaro.binarySwitch  # Device type
--%%proxy=MyProxy                 # HC3 proxy name
--%%dark=true                     # Enable dark mode for logs
--%%var=foo:config.secret         # Set QuickApp variable (from config file)
--%%debug=sdk:false,info:true     # Configure debug flags
--%%file=lib.lua:lib              # Include external file
--%%save=MyQA.fqa                 # Save as FQA file
```

## Command Line Tools

### vscode.lua Tool

Located in `/tools/vscode.lua`, this tool provides VSCode tasks integration with commands:

- `downloadQA(id, path)`: Download QuickApp from HC3
- `uploadQA(fname)`: Upload QuickApp to HC3
- `updateFile(fname)`: Update single file in QuickApp

See .vscode/tasks.json for usage

To use the updateFile command the workspace needs a `.project` file.
It's auto generated with the --%%project=<quickapp_id> directive that allows the command/task to push the file to the right QA on the HC3

```json
{
  "files": {
    "main": "main.lua",
    "lib": "lib.lua"
  },
  "id": "<quickapp_id>"
}
```

## API Support

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

### Core APIs
- `api.*` - HTTP API operations
- `fibaro.*` - Core Fibaro functions
- `net.*` - Network operations
- `plugin.*` - Plugin management
- `json.*` - JSON handling

### Common Operations
```lua
-- HTTP Operations
api.get("/devices")
api.post("/quickApp/", fqa)

-- Device Operations
fibaro.call(deviceId, "turnOn")
fibaro.getValue(deviceId, "value")

-- Timer Operations
setTimeout(callback, milliseconds)
setInterval(callback, milliseconds)

-- Storage Operations
self:setVariable("name", value)
self:getVariable("name")
```
etc etc.

## Debugging

The emulator provides various debug flags that can be enabled:

```lua
--%%debug=info:true       # Log general info
--%%debug=api:true        # Log api.* calls
--%%debug=timer:true      # Log start/stop of timers (setTimeout)
--%%debug=http:true       # Log HTTP requests
--%%debug=onAction:true   # Log Action callbacks
--%%debug=onUIEvent:true  # Log UI events
```

## Best Practices

1. Always include the emulator header:
```lua
if require and not QuickApp then require("hc3emu") end
```

2. Use state persistence for development:
```lua
--%%state=myqa.state
```
Running in offline mode this file will be used for storing device and resource states between runs.
For QAs that use the QA internalStorage api, it's recommended to turn this on.

3. Organize code in multiple files:
```lua
--%%file=utils.lua:utils
--%%file=api.lua:api
```
First is the path to the lua file, second is the name the file will have in the QA.

4. Test UI interactions using proxy mode:
```lua
--%%proxy=MyTestProxy
```

## Common Issues

1. **Missing Credentials**: Ensure URL, USER, and PASSWORD are configured when not in offline mode. If the emulator fails calling the HC3 (unathorized), it will block further requests. This to prevent that the HC3 blocks to emulator IP due to too many failed login requests... Fix credentials, and restart the emulator.
2. **File Permissions**: Check write permissions for state and save files
3. **Proxy Conflicts**: Use unique proxy names or remove existing proxies

## Contributing

See the [Contributing Guide](docs/CONTRIBUTING.md) for details on:
- Setting up development environment
- Coding standards
- Pull request process

## License

Released under MIT License. See [LICENSE](LICENSE) for details.
