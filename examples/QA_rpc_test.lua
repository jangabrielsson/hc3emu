_DEVELOP =true
if require and not QuickApp then require("hc3emu") end

--%%name=RPC test
--%%file=examples/rpc_lib.lua:rpclib

local function startClient()
local client = [[
--%%name=RPC client
--%%file=examples/rpc_lib.lua:rpclib

function QuickApp:onInit()
  local Foo = fibaro.rpc(5001,"Foo")
  print("Sum 4+6",Foo(4,6))
end

]]
  fibaro.hc3emu.loadQAString(client)
end

function Foo(a,b) return a+b end

function QuickApp:onInit()
  self:debug("QuickApp Initialized", self.name, self.id)
  startClient()
end