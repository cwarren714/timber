local M = {}

local function parser_pattern(lang)
    local sysname = (vim.uv or vim.loop).os_uname().sysname
    local ext = sysname == "Darwin" and "dylib" or sysname == "Windows_NT" and "dll" or "so"
    return ("parser/%s.%s"):format(lang, ext)
end

---check whether a buffer should be skipped
function M.is_special_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return true
    end

    if vim.bo[bufnr].buftype ~= "" then
        return true
    end

    if vim.bo[bufnr].filetype == "" then
        return true
    end

    return false
end

---check for an installed parser
function M.has_parser(lang)
    if #vim.api.nvim_get_runtime_file(parser_pattern(lang), true) > 0 then
        return true
    end

    local ok = pcall(vim.treesitter.language.add, lang)
    return ok
end

---check for an installed query
function M.has_query(lang, query_name)
    local ok, files = pcall(vim.treesitter.query.get_files, lang, query_name)
    return ok and type(files) == "table" and #files > 0
end

---list missing required queries
function M.missing_queries(lang, required_queries)
    local missing = {}
    for _, query_name in ipairs(required_queries) do
        if not M.has_query(lang, query_name) then
            table.insert(missing, query_name)
        end
    end
    return missing
end

---start treesitter for a buffer
function M.start(bufnr, lang)
    return pcall(vim.treesitter.start, bufnr, lang)
end

return M
