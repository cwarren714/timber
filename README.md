# Timber

Installer for treesitter parser and query, to be used with nvim

## Install

```lua
vim.pack.add({
    { src = "git@github.com:cwarren714/timber.git" },
})

require("timber").setup()
```

## Commands

- `:TimberInstall <lang>`
- `:TimberInfo [lang]`
- `:TimberCheckUpdates`
- `:TimberUpdate[!] [lang]`

