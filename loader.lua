local EntityLib = {}
EntityLib.version = nil

function EntityLib.init()
    local path
    if EntityLib.version then
        path = "@" .. EntityLib.version .. "/main.lua"
    else
        path = "main/main.lua"
    end

    local url =
        "https://raw.githubusercontent.com/rconsoIe/EntityLib/refs/heads/main/" .. path

    local ok, impl = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)

    if not ok then
        error("EntityLib: failed to load implementation (" .. path .. ")")
    end

    return impl
end

return EntityLib
