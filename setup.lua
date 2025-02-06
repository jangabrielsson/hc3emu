local home = "/Users/jangabrielsson/.luarocks"
package.path = 
home.."/share/lua/5.4/?.lua;"..
home.."/share/lua/5.4/?/init.lua;"..
package.path
package.cpath = package.cpath..";"..home.."/lib/lua/5.4/?.so"