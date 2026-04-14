local M = {}

local cache = nil

local function state_dir()
    return vim.fs.joinpath(vim.fn.stdpath("data"), "timber")
end

local function state_path()
    return vim.fs.joinpath(state_dir(), "installed.json")
end

local function ensure_dir()
    vim.fn.mkdir(state_dir(), "p")
end

---load installed state
function M.load()
    if cache then
        return cache
    end

    local path = state_path()
    if vim.fn.filereadable(path) == 0 then
        cache = { installed = {} }
        return cache
    end

    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if not ok or type(decoded) ~= "table" then
        cache = { installed = {} }
        return cache
    end

    decoded.installed = decoded.installed or {}
    cache = decoded
    return cache
end

---get installed state
function M.get(lang)
    return M.load().installed[lang]
end

---save installed state
function M.save(data)
    cache = data
    ensure_dir()
    vim.fn.writefile(vim.split(vim.json.encode(data), "\n"), state_path())
end

---set installed state
function M.set(lang, value)
    local data = M.load()
    data.installed[lang] = value
    M.save(data)
end

return M
