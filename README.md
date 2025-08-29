## Prerequisite

- `L3MON4D3/LuaSnip`
- `tree-sitter-csharp` parser installed

## Setup

To load dedicatedly for code-behind file in avalonia project, `L3MON4D3/LuaSnip` requires a specific filetype to distinguish from general `C#` file(following example uses `axaml-cs`).
And you should properly add detection pattern for it using `vim.filetype.add`.

```lua
require('luasnip').add_snippets('axaml-cs', require('avalonia-luasnip.snippets'))

vim.filetype.add {
  pattern = {
    ['.*axaml%.cs'] = 'axaml-cs',
  },
}
```

> [!NOTE]
> You can lazy-load this plugin using your package manager

## Supported Snippets

- `directProperty`
- `styledProperty`
- `attachedProperty`
- `routedEvent`
