local registry = require("timber.registry")
local state = require("timber.state")

local M = {}

local function run(cmd, cwd)
    local done = false
    local result
    vim.system(cmd, { cwd = cwd, text = true }, function(obj)
        result = obj
        done = true
    end)
    vim.wait(300000, function()
        return done
    end, 100)
    if result.code ~= 0 then
        error(result.stderr ~= "" and result.stderr or table.concat(cmd, " "))
    end
    return result
end

local function tmpdir(lang)
    local base = vim.fs.joinpath(vim.fn.stdpath("cache"), "timber", lang .. "-" .. tostring(vim.loop.hrtime()))
    vim.fn.mkdir(base, "p")
    return base
end

local function parser_ext()
    local sysname = (vim.uv or vim.loop).os_uname().sysname
    if sysname == "Darwin" then
        return "dylib"
    end
    if sysname == "Windows_NT" then
        return "dll"
    end
    return "so"
end

local function parser_output(lang)
    local dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser")
    vim.fn.mkdir(dir, "p")
    return vim.fs.joinpath(dir, ("%s.%s"):format(lang, parser_ext()))
end

local function queries_output(lang)
    local dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "queries", lang)
    vim.fn.mkdir(dir, "p")
    return dir
end

local function clone_repo(url, rev, dest, progress)
    if progress then
        progress(("cloning %s"):format(url))
    end
    run({ "git", "clone", "--filter=blob:none", url, dest })
    if progress then
        progress(("checking out %s"):format(rev:sub(1, 12)))
    end
    run({ "git", "checkout", rev }, dest)
end

local function repo_root(checkout_dir, location)
    if not location or location == "" then
        return checkout_dir
    end
    return vim.fs.joinpath(checkout_dir, location)
end

local function object_name(path)
    local name = vim.fs.basename(path):gsub("%.[^.]+$", ".o")
    return name
end

local function compile_parser(lang, config, progress)
    local work = tmpdir(lang)
    local ok, result = pcall(function()
        local repo_dir = vim.fs.joinpath(work, "parser-repo")
        clone_repo(config.url, config.revision, repo_dir, progress)

        local root = repo_root(repo_dir, config.location)
        local src_dir = vim.fs.joinpath(root, "src")
        local objects = {}
        local sources = { vim.fs.joinpath(src_dir, "parser.c") }
        local has_cpp = false
        local scanner_c = vim.fs.joinpath(src_dir, "scanner.c")
        local scanner_cc = vim.fs.joinpath(src_dir, "scanner.cc")
        if vim.fn.filereadable(scanner_c) == 1 then
            table.insert(sources, scanner_c)
        end
        if vim.fn.filereadable(scanner_cc) == 1 then
            table.insert(sources, scanner_cc)
            has_cpp = true
        end

        for _, source in ipairs(sources) do
            if vim.fn.filereadable(source) == 0 then
                error(("missing parser source: %s"):format(source))
            end
            local compiler = source:sub(-3) == ".cc" and (vim.env.CXX or "c++") or (vim.env.CC or "cc")
            local obj = vim.fs.joinpath(work, object_name(source))
            if progress then
                progress(("compiling %s"):format(vim.fs.basename(source)))
            end
            run({ compiler, "-O2", "-fPIC", "-I", src_dir, "-c", source, "-o", obj })
            table.insert(objects, obj)
        end

        local output = parser_output(lang)
        local linker = has_cpp and (vim.env.CXX or "c++") or (vim.env.CC or "cc")
        local link_cmd = { linker, "-shared", "-o", output }
        vim.list_extend(link_cmd, objects)
        if progress then
            progress(("linking %s"):format(vim.fs.basename(output)))
        end
        run(link_cmd)
        return output
    end)
    vim.fn.delete(work, "rf")
    if not ok then error(result) end
    return result
end

local function copy_file(src, dst)
    local lines = vim.fn.readfile(src, "b")
    vim.fn.writefile(lines, dst, "b")
end

local function install_queries(lang, config, progress)
    local work = tmpdir(lang .. "-queries")
    local ok, result = pcall(function()
        local repo_dir = vim.fs.joinpath(work, "queries-repo")
        clone_repo(config.url, config.revision, repo_dir, progress)

        local candidates = {
            vim.fs.joinpath(repo_dir, "queries", config.subdir),
            vim.fs.joinpath(repo_dir, "runtime", "queries", config.subdir),
        }

        local query_dir
        for _, candidate in ipairs(candidates) do
            if vim.fn.isdirectory(candidate) == 1 then
                query_dir = candidate
                break
            end
        end

        if not query_dir then
            error(("missing query directory for %s"):format(lang))
        end

        local output = queries_output(lang)
        local files = vim.fn.glob(vim.fs.joinpath(query_dir, "*.scm"), false, true)
        for _, file in ipairs(files) do
            if progress then
                progress(("installing query %s"):format(vim.fs.basename(file)))
            end
            copy_file(file, vim.fs.joinpath(output, vim.fs.basename(file)))
        end
        return output
    end)
    vim.fn.delete(work, "rf")
    if not ok then error(result) end
    return result
end

---install parser and queries
function M.install(lang, opts)
    opts = opts or {}
    local entry = registry.get(lang)
    if not entry then
        error(("unsupported language: %s"):format(lang))
    end

    compile_parser(lang, entry.parser, opts.progress)
    install_queries(lang, entry.queries, opts.progress)

    state.set(lang, {
        installed_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        parser = {
            revision = entry.parser.revision,
            url = entry.parser.url,
        },
        queries = {
            revision = entry.queries.revision,
            url = entry.queries.url,
        },
    })
    if opts.progress then
        opts.progress(("installed %s assets"):format(lang))
    end
end

---check registry updates
function M.outdated(lang)
    local installed = state.get(lang)
    local entry = registry.get(lang)
    if not installed or not entry then
        return nil
    end

    local parser_outdated = installed.parser == nil or installed.parser.revision ~= entry.parser.revision
    local queries_outdated = installed.queries == nil or installed.queries.revision ~= entry.queries.revision
    if not parser_outdated and not queries_outdated then
        return nil
    end

    return {
        lang = lang,
        parser_outdated = parser_outdated,
        queries_outdated = queries_outdated,
        installed = installed,
        latest = entry,
    }
end

function M.clear_state(lang)
    local data = state.load()
    data.installed[lang] = nil
    state.save(data)
end

return M
