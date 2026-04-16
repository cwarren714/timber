local registry = require("timber.registry")
local runtime = require("timber.runtime")
local installer = require("timber.install")
local state = require("timber.state")
local ui = require("timber.ui")

local M = {}

local defaults = {
    auto_start = true,
    check_for_updates_on_start = false,
    lang_overrides = {},
    languages = {},
    prompt = true,
    remember_declines = "session",
    required_queries = { "highlights" },
}

local config = vim.deepcopy(defaults)
local session = {
    declined = {},
    failed = {},
    in_progress = {},
}

local function install_with_requires(lang, seen, progress)
    seen = seen or {}
    if seen[lang] then
        return
    end
    seen[lang] = true

    local entry = registry.get(lang)
    if not entry then
        error(("timber does not have a registry entry for %s"):format(lang))
    end

    for _, required in ipairs(entry.requires or {}) do
        install_with_requires(required, seen, progress)
    end

    if progress then
        progress(("installing %s"):format(lang))
    end
    installer.install(lang, { progress = progress })
end

local function language_for_buf(bufnr)
    local ft = vim.bo[bufnr].filetype
    return config.lang_overrides[ft] or registry.resolve(ft)
end

local function missing_assets(lang)
    local missing = {}
    if not runtime.has_parser(lang) then
        table.insert(missing, "parser")
    end
    for _, query_name in ipairs(runtime.missing_queries(lang, config.required_queries)) do
        table.insert(missing, ("query:%s"):format(query_name))
    end
    return missing
end

local function format_update(update)
    local bits = {}
    if update.parser_outdated then
        table.insert(bits, "parser")
    end
    if update.queries_outdated then
        table.insert(bits, "queries")
    end
    return ("%s (%s)"):format(update.lang, table.concat(bits, ", "))
end

---setup timber
function M.setup(opts)
    config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

    for lang, entry in pairs(config.languages) do
        registry.register(lang, entry)
    end

    if config.remember_declines ~= "session" then
        ui.notify(
            ("unknown remember_declines value %q (expected 'session')"):format(config.remember_declines),
            vim.log.levels.WARN
        )
    end

    for ft, lang in pairs(config.lang_overrides) do
        if not registry.get(lang) then
            ui.notify(
                ("lang_overrides[%q] = %q but %q is not in the registry"):format(ft, lang, lang),
                vim.log.levels.WARN
            )
        end
    end

    if config.check_for_updates_on_start then
        vim.schedule(M.check_updates)
    end
end

---ensure assets for a buffer
function M.ensure_for_buf(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if runtime.is_special_buffer(bufnr) then
        return
    end

    local lang = language_for_buf(bufnr)
    if not lang then
        return
    end

    local missing = missing_assets(lang)
    if #missing == 0 then
        if config.auto_start then
            local ok, err = runtime.start(bufnr, lang)
            if not ok then
                ui.notify(("failed to start treesitter for %s: %s"):format(lang, err), vim.log.levels.ERROR)
            end
        end
        return
    end

    if not config.prompt or session.declined[lang] or session.failed[lang] or session.in_progress[lang] then
        return
    end

    if not ui.confirm_install(lang, missing) then
        if config.remember_declines == "session" then
            session.declined[lang] = true
        end
        return
    end

    session.in_progress[lang] = true
    local ok, err = pcall(M.install, lang, { bufnr = bufnr, start = true })
    session.in_progress[lang] = nil
    if not ok then
        ui.notify(err, vim.log.levels.ERROR)
        session.failed[lang] = true
    end
end

---install a language
function M.install(lang, opts)
    opts = opts or {}
    local resolved = config.lang_overrides[lang] or registry.resolve(lang) or lang
    if not registry.get(resolved) then
        ui.notify(("timber does not have a registry entry for %s"):format(lang), vim.log.levels.WARN)
        return
    end

    local spinner = ui.start_spinner(("installing %s"):format(resolved))
    local function progress(msg)
        ui.update_spinner(spinner, msg)
    end

    local ok, err = pcall(function()
        install_with_requires(resolved, nil, progress)
    end)

    if not ok then
        ui.stop_spinner(spinner)
        error(err)
    end

    ui.stop_spinner(spinner, ("installed Tree-sitter assets for %s"):format(resolved))
    if opts.start and opts.bufnr and config.auto_start then
        local ok, err = runtime.start(opts.bufnr, resolved)
        if not ok then
            ui.notify(("failed to start treesitter for %s: %s"):format(resolved, err), vim.log.levels.ERROR)
        end
    end
end

---show install info
function M.info(lang)
    local resolved = lang and (config.lang_overrides[lang] or registry.resolve(lang) or lang) or nil
    if not resolved then
        ui.notify(("tracked languages: %s"):format(table.concat(registry.languages(), ", ")))
        return
    end

    local entry = registry.get(resolved)
    local installed = state.get(resolved)
    if not entry then
        ui.notify(("no registry entry for %s"):format(resolved), vim.log.levels.WARN)
        return
    end

    local lines = {
        ("language: %s"):format(resolved),
        ("parser revision: %s"):format(entry.parser.revision),
        ("queries revision: %s"):format(entry.queries.revision),
    }
    if installed then
        table.insert(lines, ("installed parser revision: %s"):format(installed.parser and installed.parser.revision or "unknown"))
        table.insert(lines, ("installed query revision: %s"):format(installed.queries and installed.queries.revision or "unknown"))
    else
        table.insert(lines, "installed: no")
    end
    ui.notify(table.concat(lines, "\n"))
end

---check for updates
function M.check_updates()
    local updates = {}
    for _, lang in ipairs(registry.languages()) do
        local update = installer.outdated(lang)
        if update then
            table.insert(updates, update)
        end
    end

    if #updates == 0 then
        ui.notify("all timber parser assets are up to date")
        return {}
    end

    local summary = {}
    for _, update in ipairs(updates) do
        table.insert(summary, format_update(update))
    end
    ui.notify("updates available:\n" .. table.concat(summary, "\n"))
    return updates
end

---update installed languages
function M.update(lang, opts)
    opts = opts or {}
    local targets = {}

    if lang then
        table.insert(targets, config.lang_overrides[lang] or registry.resolve(lang) or lang)
    else
        for _, update in ipairs(M.check_updates()) do
            table.insert(targets, update.lang)
        end
    end

    if #targets == 0 then
        return
    end

    if not opts.force then
        local choice = vim.fn.confirm(
            ("update Tree-sitter assets for: %s"):format(table.concat(targets, ", ")),
            "&Yes\n&No",
            1
        )
        if choice ~= 1 then
            return
        end
    end

    for _, target in ipairs(targets) do
        local spinner = ui.start_spinner(("updating %s"):format(target))
        local ok, err = pcall(installer.install, target, {
            progress = function(msg)
                ui.update_spinner(spinner, msg)
            end,
        })
        if ok then
            ui.stop_spinner(spinner, ("updated %s"):format(target))
        else
            ui.stop_spinner(spinner)
            ui.notify(err, vim.log.levels.ERROR)
        end
    end
end

---clear installed metadata for a language
function M.clear(lang)
    local resolved = config.lang_overrides[lang] or registry.resolve(lang) or lang
    installer.clear_state(resolved)
    ui.notify(("Cleared Timber state for %s"):format(resolved))
end

---manually start treesitter for the current buffer
function M.start(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if runtime.is_special_buffer(bufnr) then
        ui.notify("not a regular file buffer", vim.log.levels.WARN)
        return
    end

    local lang = language_for_buf(bufnr)
    if not lang then
        ui.notify("no treesitter language for this buffer", vim.log.levels.WARN)
        return
    end

    local ok, err = runtime.start(bufnr, lang)
    if ok then
        ui.notify(("started treesitter for %s"):format(lang))
    else
        ui.notify(("failed to start treesitter for %s: %s"):format(lang, err), vim.log.levels.ERROR)
    end
end

return M
