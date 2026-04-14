local query_repo = "https://github.com/nvim-treesitter/nvim-treesitter"
local query_rev = "42fc28ba918343ebfd5565147a42a26580579482"

local registry = {
    bash = {
        filetypes = { "bash", "sh", "zsh" },
        parser = {
            revision = "a06c2e4415e9bc0346c6b86d401879ffb44058f7",
            url = "https://github.com/tree-sitter/tree-sitter-bash",
        },
    },
    css = {
        parser = {
            revision = "dda5cfc5722c429eaba1c910ca32c2c0c5bb1a3f",
            url = "https://github.com/tree-sitter/tree-sitter-css",
        },
    },
    dockerfile = {
        filetypes = { "dockerfile" },
        parser = {
            revision = "971acdd908568b4531b0ba28a445bf0bb720aba5",
            url = "https://github.com/camdencheek/tree-sitter-dockerfile",
        },
    },
    go = {
        parser = {
            revision = "2346a3ab1bb3857b48b29d779a1ef9799a248cd7",
            url = "https://github.com/tree-sitter/tree-sitter-go",
        },
    },
    html = {
        parser = {
            revision = "73a3947324f6efddf9e17c0ea58d454843590cc0",
            url = "https://github.com/tree-sitter/tree-sitter-html",
        },
    },
    javascript = {
        parser = {
            revision = "58404d8cf191d69f2674a8fd507bd5776f46cb11",
            url = "https://github.com/tree-sitter/tree-sitter-javascript",
        },
    },
    json = {
        filetypes = { "json", "jsonc" },
        parser = {
            revision = "001c28d7a29832b06b0e831ec77845553c89b56d",
            url = "https://github.com/tree-sitter/tree-sitter-json",
        },
    },
    lua = {
        parser = {
            revision = "10fe0054734eec83049514ea2e718b2a56acd0c9",
            url = "https://github.com/tree-sitter-grammars/tree-sitter-lua",
        },
    },
    markdown = {
        requires = { "markdown_inline" },
        parser = {
            location = "tree-sitter-markdown",
            revision = "f969cd3ae3f9fbd4e43205431d0ae286014c05b5",
            url = "https://github.com/tree-sitter-grammars/tree-sitter-markdown",
        },
    },
    markdown_inline = {
        parser = {
            location = "tree-sitter-markdown-inline",
            revision = "f969cd3ae3f9fbd4e43205431d0ae286014c05b5",
            url = "https://github.com/tree-sitter-grammars/tree-sitter-markdown",
        },
    },
    php = {
        requires = { "php_only" },
        parser = {
            location = "php",
            revision = "3f2465c217d0a966d41e584b42d75522f2a3149e",
            url = "https://github.com/tree-sitter/tree-sitter-php",
        },
    },
    php_only = {
        parser = {
            location = "php_only",
            revision = "3f2465c217d0a966d41e584b42d75522f2a3149e",
            url = "https://github.com/tree-sitter/tree-sitter-php",
        },
    },
    rust = {
        parser = {
            revision = "77a3747266f4d621d0757825e6b11edcbf991ca5",
            url = "https://github.com/tree-sitter/tree-sitter-rust",
        },
    },
    toml = {
        parser = {
            revision = "64b56832c2cffe41758f28e05c756a3a98d16f41",
            url = "https://github.com/tree-sitter-grammars/tree-sitter-toml",
        },
    },
    tsx = {
        parser = {
            location = "tsx",
            revision = "75b3874edb2dc714fb1fd77a32013d0f8699989f",
            url = "https://github.com/tree-sitter/tree-sitter-typescript",
        },
    },
    typescript = {
        parser = {
            location = "typescript",
            revision = "75b3874edb2dc714fb1fd77a32013d0f8699989f",
            url = "https://github.com/tree-sitter/tree-sitter-typescript",
        },
    },
    vimdoc = {
        filetypes = { "help" },
        parser = {
            revision = "f061895a0eff1d5b90e4fb60d21d87be3267031a",
            url = "https://github.com/neovim/tree-sitter-vimdoc",
        },
    },
    yaml = {
        parser = {
            revision = "4463985dfccc640f3d6991e3396a2047610cf5f8",
            url = "https://github.com/tree-sitter-grammars/tree-sitter-yaml",
        },
    },
}

for lang, config in pairs(registry) do
    config.queries = {
        revision = query_rev,
        subdir = lang,
        url = query_repo,
    }
end

local M = {}

---get a registry entry
function M.get(lang)
    return registry[lang]
end

---list tracked languages
function M.languages()
    local langs = vim.tbl_keys(registry)
    table.sort(langs)
    return langs
end

---resolve filetype to language
function M.resolve(ft)
    local lang = vim.treesitter.language.get_lang(ft) or ft
    if registry[lang] then
        return lang
    end

    for name, config in pairs(registry) do
        if vim.tbl_contains(config.filetypes or {}, ft) then
            return name
        end
    end
end

function M.register(lang, entry)
    entry = vim.deepcopy(entry)
    if not entry.queries then
        entry.queries = {
            revision = query_rev,
            subdir = lang,
            url = query_repo,
        }
    end
    registry[lang] = entry
end

return M
