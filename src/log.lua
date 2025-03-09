TQ = TQ
local fmt = string.format

local ANSICOLORMAP = {
  black="\027[30m",brown="\027[31m",green="\027[32m",orange="\027[33m",navy="\027[34m", -- Seems to work in both VSCode and Zerobrane console...
  purple="\027[35m",teal="\027[36m",grey="\027[37m", gray="\027[37m",red="\027[31;1m",
  tomato="\027[31;1m",neon="\027[32;1m",yellow="\027[33;1m",blue="\027[34;1m",magenta="\027[35;1m",
  cyan="\027[36;1m",white="\027[37;1m",darkgrey="\027[30;1m",
}

if TQ.isVscode then
  TQ.require("hc3emu.colors")(TQ) -- We can load extra colors working in vscode, don't work in zbs
end

TQ.SYSCOLORS = { debug='green', trace='blue', warning='orange', ['error']='red', text='black', sys='navy' }
if TQ.flags.dark then TQ.SYSCOLORS.text='gray' TQ.SYSCOLORS.trace='cyan' TQ.SYSCOLORS.sys='yellow'  end

TQ.COLORMAP = ANSICOLORMAP
local colorEnd = '\027[0m'

local function html2ansiColor(str, dfltColor) -- Allows for nested font tags and resets color to dfltColor
  local COLORMAP = TQ.COLORMAP
  local EXTRA = TQ.extraColors or {}
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
function TQ.debugOutput(tag, str, typ, time)
  time = time or os.time()
  for _,p in ipairs(TQ.logFilter or {}) do if str:find(p) then return end end
  str = str:gsub("<table (.-)>(.-)</table>",transformTable) -- Remove table tags
  str = str:gsub("(&nbsp;)", " ")  -- transform html space
  str = str:gsub("</br>", "\n")    -- transform break line
  str = str:gsub("<br>", "\n")     -- transform break line
  if TQ.flags.logColor==false then
    str = str:gsub("(</?font.->)", "") -- Remove color tags
    print(fmt("%s[%s][%s]: %s", os.date("[%d.%m.%Y][%H:%M:%S]",time), typ:upper(), tag, str))
  else
    local fstr = "<font color='%s'>%s[<font color='%s'>%-6s</font>][%-7s]: %s</font>"
    local txtColor = TQ.SYSCOLORS.text
    local typColor = TQ.SYSCOLORS[typ:lower()] or txtColor
    local outstr = fmt(fstr,txtColor,os.date("[%d.%m.%Y][%H:%M:%S]",time),typColor,typ:upper(),tag,str)
    print(html2ansiColor(outstr,TQ.SYSCOLORS.text))
  end
end

function TQ.colorStr(color,str) 
  if TQ.flags.logColor~=false then
    return fmt("%s%s%s",TQ.COLORMAP[color] or TQ.extraColors [color],str,colorEnd) 
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