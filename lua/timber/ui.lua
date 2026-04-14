local M = {}
local frames = { "|", "/", "-", "\\" }

local function has_ui()
    return #vim.api.nvim_list_uis() > 0
end

local function render(msg)
    if not has_ui() then
        return
    end
    vim.cmd.redraw()
    vim.cmd.echohl("ModeMsg")
    vim.cmd(("echon %s"):format(vim.fn.string(msg)))
    vim.cmd.echohl("None")
end

---show a timber notification
function M.notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "Timber" })
end

---ask to install a language
function M.confirm_install(lang, missing)
    local detail = table.concat(missing, ", ")
    local choice = vim.fn.confirm(
        ("Install Tree-sitter assets for %s? Missing: %s"):format(lang, detail),
        "&Yes\n&No",
        1
    )
    return choice == 1
end

---start a progress spinner
function M.start_spinner(msg)
    local spinner = {
        frame = 1,
        last_len = 0,
        msg = msg,
        timer = nil,
    }

    local initial = ("%s Timber %s"):format(frames[spinner.frame], spinner.msg)
    spinner.last_len = #initial
    render(initial)

    if not has_ui() then
        return spinner
    end

    spinner.timer = (vim.uv or vim.loop).new_timer()
    spinner.timer:start(0, 120, vim.schedule_wrap(function()
        spinner.frame = (spinner.frame % #frames) + 1
        local text = ("%s Timber %s"):format(frames[spinner.frame], spinner.msg)
        if #text < spinner.last_len then
            text = text .. string.rep(" ", spinner.last_len - #text)
        end
        spinner.last_len = #text
        render(text)
    end))

    return spinner
end

---update spinner text
function M.update_spinner(spinner, msg)
    if not spinner then
        return
    end
    spinner.msg = msg
end

---stop a progress spinner
function M.stop_spinner(spinner, msg)
    if not spinner or spinner.stopped then
        return
    end
    spinner.stopped = true
    if spinner.timer then
        spinner.timer:stop()
        spinner.timer:close()
        spinner.timer = nil
    end
    if msg and msg ~= "" then
        local text = ("✓ Timber %s"):format(msg)
        if #text < spinner.last_len then
            text = text .. string.rep(" ", spinner.last_len - #text)
        end
        render(text)
        return
    end
    render(string.rep(" ", spinner.last_len))
end

return M
