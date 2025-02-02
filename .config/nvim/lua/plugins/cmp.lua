package.path = package.path .. ';../?.lua'
local mason_servers = require('util').mason_lsp_servers

local truncate = function(text, max_width)
    if #text > max_width then
        return string.sub(text, 1, max_width) .. "…"
    else
        return text
    end
end

return {
    {
        'onsails/lspkind.nvim',
        config = function()
            require('lspkind').init()
        end
    },
    {
        'hrsh7th/nvim-cmp',
        event = 'BufReadPre',
        dependencies = {
            'hrsh7th/cmp-nvim-lua',
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            'hrsh7th/cmp-cmdline',
            'hrsh7th/cmp-calc',
            'hrsh7th/cmp-omni',
            'L3MON4D3/LuaSnip',
            'saadparwaiz1/cmp_luasnip',
            'neovim/nvim-lspconfig',
            'L3MON4D3/LuaSnip',
            'onsails/lspkind.nvim'
        },
        opts = function(_, opts)
            opts.sources = opts.sources or {}
            table.insert(opts.sources, {
                name = "lazydev",
                group_index = 0, -- set group index to 0 to skip loading LuaLS completions
            })
        end,
        config = function()
            local has_words_before = function()
                unpack = unpack or table.unpack
                local line, col = unpack(vim.api.nvim_win_get_cursor(0))
                return col ~= 0 and
                    vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
            end

            local luasnip = require("luasnip")
            local cmp = require("cmp")
            local lspkind = require('lspkind')

            require("luasnip.loaders.from_snipmate").lazy_load()

            cmp.setup({
                snippet = {
                    -- REQUIRED - you must specify a snippet engine
                    expand = function(args)
                        -- vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
                        require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
                        -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
                        -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
                    end,
                },
                window = {
                    -- completion = cmp.config.window.bordered(),
                    -- documentation = cmp.config.window.bordered(),
                },
                formatting = {
                    format = lspkind.cmp_format({
                        mode = 'symbol_text',
                        before = function(entry, vim_item)
                            -- detail information (optional)
                            local cmp_item = entry:get_completion_item() --- @type lsp.CompletionItem

                            if entry.source.name == 'nvim_lsp' then
                                -- Display which LSP servers this item came from.
                                local lspserver_name = nil
                                local success, _ = pcall(function()
                                    lspserver_name = entry.source.source.client.name
                                    vim_item.menu = lspserver_name
                                end)
                                if not success then
                                    vim_item.menu = "unknown LSP"
                                end
                            end

                            -- Some language servers provide details, e.g. type information.
                            -- The details info hide the name of lsp server, but mostly we'll have one LSP
                            -- per filetype, and we use special highlights so it's OK to hide it..
                            local detail_txt = (function()
                                if not cmp_item.detail then return nil end

                                if cmp_item.detail == "Auto-import" then
                                    local label = (cmp_item.labelDetails or {}).description
                                    if not label or label == "" then return nil end
                                    local logo = "󰋺"
                                    return logo .. " " .. truncate(label, 20)
                                else
                                    return truncate(cmp_item.detail, 50)
                                end
                            end)()

                            if detail_txt then
                              vim_item.menu = detail_txt
                              vim_item.menu_hl_group = 'CmpItemMenuDetail'
                            end

                            return vim_item
                        end
                    })
                }, -- formatting
                mapping = cmp.mapping.preset.insert({
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<S-Space>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping.abort(),
                    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                            -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
                            -- they way you will only jump inside the snippet region
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        elseif has_words_before() then
                            cmp.complete()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    {
                        name = 'omni'
                    },
                    {
                        name = 'nvim_lsp',
                        entry_filter = function(entry, ctx)
                            return require('cmp.types').lsp.CompletionItemKind[entry:get_kind()] ~= 'Text'
                        end
                    },
                    -- { name = 'vsnip' }, -- For vsnip users.
                    { name = 'luasnip' }, -- For luasnip users.
                    -- { name = 'ultisnips' }, -- For ultisnips users.
                    -- { name = 'snippy' }, -- For snippy users.
                }, {
                    { name = 'buffer' },
                })
            })

            -- Set configuration for specific filetype.
            cmp.setup.filetype('gitcommit', {
                sources = cmp.config.sources({
                    { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
                }, {
                    { name = 'buffer' },
                })
            })

            -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
            cmp.setup.cmdline({ '/', '?' }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = 'buffer' }
                }
            })

            -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
            cmp.setup.cmdline(':', {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({
                    { name = 'path' }
                }, {
                    { name = 'cmdline' }
                })
            })

            -- Set up lspconfig.
            local capabilities = require('cmp_nvim_lsp').default_capabilities()
            for _, server in pairs(mason_servers) do
                require('lspconfig')[server].setup {
                    capabilities = capabilities
                }
            end
        end
    },
}
