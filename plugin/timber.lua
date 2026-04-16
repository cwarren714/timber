if vim.g.loaded_timber == 1 then
    return
end

vim.g.loaded_timber = 1

local timber = require("timber")

vim.api.nvim_create_user_command("TimberInstall", function(opts)
    timber.install(opts.args)
end, {
    complete = function()
        return require("timber.registry").languages()
    end,
    nargs = 1,
})

vim.api.nvim_create_user_command("TimberInfo", function(opts)
    timber.info(opts.args ~= "" and opts.args or nil)
end, {
    complete = function()
        return require("timber.registry").languages()
    end,
    nargs = "?",
})

vim.api.nvim_create_user_command("TimberCheckUpdates", function()
    timber.check_updates()
end, {
    nargs = 0,
})

vim.api.nvim_create_user_command("TimberUpdate", function(opts)
    timber.update(opts.args ~= "" and opts.args or nil, { force = opts.bang })
end, {
    bang = true,
    complete = function()
        return require("timber.registry").languages()
    end,
    nargs = "?",
})

vim.api.nvim_create_user_command("TimberStart", function()
    timber.start()
end, {
    nargs = 0,
})

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("timber", { clear = true }),
    callback = function(ev)
        require("timber").ensure_for_buf(ev.buf)
    end,
})
