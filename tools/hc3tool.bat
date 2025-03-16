SET mypath=%~dp0
echo %mypath:~0,-1%
lua %~dp0hc3tool %*
