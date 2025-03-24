local exports = {}
local E = setmetatable({},{ 
  __index=function(t,k) return exports.emulator[k] end,
  __newindex=function(t,k,v) exports.emulator[k] = v end
})
local fmt = string.format

local ANSICOLORMAP = {
  black="\027[30m",brown="\027[31m",green="\027[32m",orange="\027[33m",navy="\027[34m", -- Seems to work in both VSCode and Zerobrane console...
  purple="\027[35m",teal="\027[36m",grey="\027[37m", gray="\027[37m",red="\027[31;1m",
  tomato="\027[31;1m",neon="\027[32;1m",yellow="\027[33;1m",blue="\027[34;1m",magenta="\027[35;1m",
  cyan="\027[36;1m",white="\027[37;1m",darkgrey="\027[30;1m",
}

local SYSCOLORS = { debug='green', trace='blue', warning='orange', ['error']='red', text='black', sys='navy' }

local extraColors = {}

local function init()
  if E.isVscode then
    extraColors = require("hc3emu.colors") -- We can load extra colors working in vscode, don't work in zbs
  end
  if E.DBG.dark then SYSCOLORS.text='gray' SYSCOLORS.trace='cyan' SYSCOLORS.sys='yellow'  end
end

local COLORMAP = ANSICOLORMAP
local colorEnd = '\027[0m'

local function html2ansiColor(str, dfltColor) -- Allows for nested font tags and resets color to dfltColor
  local EXTRA = extraColors or {}
  dfltColor = COLORMAP[dfltColor] or EXTRA[dfltColor]
  local st, p = { dfltColor }, 1
  return dfltColor..str:gsub("(</?font.->)", function(s)
    if s == "</font>" then
      p = p - 1; return st[p]
    else
      local color = s:match("color=\"?([#%w]+)\"?") or s:match("color='([#%w]+)'")
      if color then color = color:lower() end
      color = COLORMAP[color] or EXTRA[color] or dfltColor
      p = p + 1; st[p] = color
      return color
    end
  end)..colorEnd
end

local transformTable
local function debugOutput(tag, str, typ, time)
  time = time or os.time()
  for _,p in ipairs(E.logFilter or {}) do if str:find(p) then return end end
  str = str:gsub("<table (.-)>(.-)</table>",transformTable) -- Remove table tags
  str = str:gsub("(&nbsp;)", " ")  -- transform html space
  str = str:gsub("</br>", "\n")    -- transform break line
  str = str:gsub("<br>", "\n")     -- transform break line
  if E.DBG.logColor==false then
    str = str:gsub("(</?font.->)", "") -- Remove color tags
    print(fmt("%s[%s][%s]: %s", os.date("[%d.%m.%Y][%H:%M:%S]",time), typ:upper(), tag:upper(), str))
  else
    local fstr = "<font color='%s'>%s[<font color='%s'>%-6s</font>][%-7s]: %s</font>"
    local txtColor = SYSCOLORS.text
    local typColor = SYSCOLORS[typ:lower()] or txtColor
    local outstr = fmt(fstr,txtColor,os.date("[%d.%m.%Y][%H:%M:%S]",time),typColor,typ:upper(),tag:upper(),str)
    print(html2ansiColor(outstr,SYSCOLORS.text))
  end
end

local function colorStr(color,str) 
  if E.DBG.logColor~=false then
    return fmt("%s%s%s",COLORMAP[color] or extraColors [color],str,colorEnd) 
  else return str end
end

function transformTable(pref,str)
  local buff = {}
  local function out(b,str) table.insert(b,str) end
  str:gsub("<tr.->(.-)</tr>",function(row)
    local rowbuff = {}
    row:gsub("<td.->(.-)</td>",function(cell) 
      out(rowbuff,cell)
    end)
    out(buff,table.concat(rowbuff,"  "))
  end)
  return table.concat(buff,"\n")
end

exports.colors = { ANSICOLORMAP = ANSICOLORMAP, SYSCOLORS = SYSCOLORS, extraColors = extraColors }
exports.debugOutput = debugOutput
exports.colorStr = colorStr
exports.html2ansiColor = html2ansiColor
exports.init = init

return exports
