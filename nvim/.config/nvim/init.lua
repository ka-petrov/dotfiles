--
-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- For more options, you can see `:help option-list`
-- Make line numbers default
vim.o.number = true
-- relative line numbers
vim.o.relativenumber = true
-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'
-- Don't show the mode, since it's already in the status line
vim.o.showmode = false
-- Sync clipboard between OS and Neovim.
-- Schedule the setting after `UiEnter` because it can increase startup-time.
-- See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true
-- Save undo history
vim.o.undofile = true
-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true
-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'
-- Decrease update time
vim.o.updatetime = 250
-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300
-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'
-- Show which line your cursor is on
vim.o.cursorline = true
-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10
-- Global tab behavior
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.softtabstop = 4

-- Configure diagnostics display
-- vim.diagnostic.config {
--   severity_sort = true,
--   virtual_text = {
--     -- severity = { min = vim.diagnostic.severity.ERROR },
--     severity = { off = true },
--   },
--   signs = {
--     severity = { min = vim.diagnostic.severity.HINT },
--   },
--   underline = {
--     -- severity = { min = vim.diagnostic.severity.ERROR },
--     severity = { off = true },
--   },
-- }

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
-- Ctrl+A to select all text
vim.keymap.set('n', '<C-a>', function()
  vim.cmd 'normal! gg0VG'
end, { noremap = true, silent = true })
-- Ctrl+; / Ctrl+' to go to previous / next buffer
vim.keymap.set('n', '<C-;>', '<cmd>bprevious<CR>')
vim.keymap.set('n', "<C-'>", '<cmd>bnext<CR>')
-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
--  Use CTRL+<hjkl> to switch between windows
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`
--
-- Highlight when yanking (copying) text
--  See `:help vim.hl.on_yank()` (vim.highlight.on_yank())
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    -- vim.hl.on_yank()  -- probably changed in nvim 0.11
    vim.highlight.on_yank()
  end,
})

-- Testing some stuff
vim.api.nvim_create_user_command('VisiData', function()
  vim.cmd 'tabnew'
  -- vim.cmd 'botright new'
  -- vim.cmd 'resize 999'
  vim.cmd 'terminal vd'
  vim.cmd 'startinsert'
end, {})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

local function copy_repo_relative_path(state)
  local node = state.tree:get_node()
  local node_path = node.path or node:get_id()

  if not node_path or node_path == '' then
    vim.notify('No file path found under cursor', vim.log.levels.WARN)
    return
  end

  local target_dir = vim.fn.fnamemodify(node_path, ':p:h')
  local git_root = vim.fn.systemlist({ 'git', '-C', target_dir, 'rev-parse', '--show-toplevel' })[1]

  if vim.v.shell_error ~= 0 or not git_root or git_root == '' then
    vim.notify('Not inside a git repository', vim.log.levels.WARN)
    return
  end

  local relative_path = vim.fn.fnamemodify(node_path, ':p'):gsub('^' .. vim.pesc(git_root .. '/'), '')
  vim.fn.setreg('+', relative_path)
  vim.fn.setreg('"', relative_path)
  vim.notify('Copied repo-relative path: ' .. relative_path, vim.log.levels.INFO)
end

-- [[ Configure and install plugins ]]
--  To check the current status of your plugins, run `:Lazy`
--  You can press `?` in this menu for help. Use `:q` to close the window
--  To update plugins you can run `:Lazy update`
require('lazy').setup {
  --  NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).

  -- AI plugins --

  -- {
  --   'NickvanDyke/opencode.nvim',
  --   dependencies = {
  --     -- Recommended for `ask()` and `select()`.
  --     -- Required for `snacks` provider.
  --     ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
  --     { 'folke/snacks.nvim', opts = { input = {}, picker = {}, terminal = {} } },
  --   },
  --   config = function()
  --     ---@type opencode.Opts
  --     vim.g.opencode_opts = {
  --       -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
  --     }
  --
  --     -- Required for `opts.events.reload`.
  --     vim.o.autoread = true
  --
  --     -- Recommended/example keymaps.
  --     vim.keymap.set({ 'n', 'x' }, '<C-a>', function()
  --       require('opencode').ask('@this: ', { submit = true })
  --     end, { desc = 'Ask opencode' })
  --     vim.keymap.set({ 'n', 'x' }, '<C-x>', function()
  --       require('opencode').select()
  --     end, { desc = 'Execute opencode action…' })
  --     vim.keymap.set({ 'n', 't' }, '<C-.>', function()
  --       require('opencode').toggle()
  --     end, { desc = 'Toggle opencode' })
  --
  --     vim.keymap.set({ 'n', 'x' }, 'go', function()
  --       return require('opencode').operator '@this '
  --     end, { expr = true, desc = 'Add range to opencode' })
  --     vim.keymap.set('n', 'goo', function()
  --       return require('opencode').operator '@this ' .. '_'
  --     end, { expr = true, desc = 'Add line to opencode' })
  --
  --     vim.keymap.set('n', '<S-C-u>', function()
  --       require('opencode').command 'session.half.page.up'
  --     end, { desc = 'opencode half page up' })
  --     vim.keymap.set('n', '<S-C-d>', function()
  --       require('opencode').command 'session.half.page.down'
  --     end, { desc = 'opencode half page down' })
  --
  --     -- You may want these if you stick with the opinionated "<C-a>" and "<C-x>" above — otherwise consider "<leader>o".
  --     vim.keymap.set('n', '+', '<C-a>', { desc = 'Increment', noremap = true })
  --     vim.keymap.set('n', '-', '<C-x>', { desc = 'Decrement', noremap = true })
  --   end,
  -- },

  -- AI auto-complete
  -- {
  --   'Exafunction/windsurf.vim',
  --   event = 'BufEnter',
  --   config = function()
  --     -- Change '<C-g>' here to any keycode you like.
  --     vim.keymap.set('i', '<C-l>', function()
  --       return vim.fn['codeium#Accept']()
  --     end, { expr = true, silent = true })
  --     vim.keymap.set('i', '<c-;>', function()
  --       return vim.fn['codeium#CycleCompletions'](1)
  --     end, { expr = true, silent = true })
  --     vim.keymap.set('i', '<c-,>', function()
  --       return vim.fn['codeium#CycleCompletions'](-1)
  --     end, { expr = true, silent = true })
  --     vim.keymap.set('i', '<c-x>', function()
  --       return vim.fn['codeium#Clear']()
  --     end, { expr = true, silent = true })
  --   end,
  -- },

  --------

  {
    'kdheepak/lazygit.nvim',
    cmd = 'LazyGit',
    keys = {
      { '<leader>gg', '<cmd>LazyGit<cr>', desc = 'Open lazygit' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    config = function()
      -- Override the default float dimensions
      -- vim.g.lazygit_floating_window_winblend = 0
      vim.g.lazygit_floating_window_scaling_factor = 1.0 -- 1.0 = full screen
      -- vim.g.lazygit_floating_window_use_plenary = 0
    end,
  },

  {
    'mgierada/lazydocker.nvim',
    dependencies = { 'akinsho/toggleterm.nvim' },
    config = function()
      require('lazydocker').setup {
        border = 'curved', -- valid options are "single" | "double" | "shadow" | "curved"
      }
    end,
    event = 'BufRead',
    keys = {
      {
        '<leader>ld',
        function()
          require('lazydocker').open()
        end,
        desc = 'Open Lazydocker floating window',
      },
    },
  },

  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons', -- optional, but recommended
      'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
    keys = {
      { '<leader>e', '<cmd>Neotree toggle<cr>', desc = 'Explorer (Neo-tree) toggle' },
      -- { '<leader>o', '<cmd>Neotree focus<cr>', desc = 'Explorer (Neo-tree) focus' },
    },
    init = function()
      -- If you open nvim with a directory: `nvim .` -> open neo-tree automatically
      vim.api.nvim_create_autocmd('VimEnter', {
        callback = function(data)
          local directory = vim.fn.isdirectory(data.file) == 1
          if directory then
            vim.cmd.cd(data.file)
            vim.cmd 'Neotree show'
          end
        end,
      })
    end,
    opts = {
      close_if_last_window = true,
      popup_border_style = 'rounded',
      enable_git_status = true,
      enable_diagnostics = true,
      window = {
        position = 'left',
        width = 34,
        mappings = {
          -- ['<space>'] = 'toggle_node',
          ['l'] = 'open',
          ['h'] = 'close_node',
          ['Y'] = copy_repo_relative_path,
          ['a'] = { 'add', config = { show_path = 'relative' } },
          ['d'] = 'delete',
          ['r'] = 'rename',
          ['c'] = 'copy',
          ['m'] = 'move',
          ['q'] = 'close_window',
        },
      },
      filesystem = {
        follow_current_file = { enabled = true },
        hijack_netrw_behavior = 'open_default',
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          never_show = { '.DS_Store' },
        },
        use_libuv_file_watcher = true,
      },
      default_component_configs = {
        indent = { with_markers = true },
        icon = {
          folder_closed = '',
          folder_open = '',
          folder_empty = '',
        },
        git_status = {
          symbols = {
            added = '✚',
            modified = '',
            deleted = '✖',
            renamed = '󰁕',
            untracked = '',
            ignored = '',
            unstaged = '󰄱',
            staged = '',
            conflict = '',
          },
        },
      },
    },
  },

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'python',
        'javascript',
        'typescript',
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
        -- 'go',
        -- 'swift',
      },
      -- Autoinstall languages that are not installed
      auto_install = false,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
  },

  -- See `:help gitsigns` to understand what the configuration keys do
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      -- this setting is independent of vim.o.timeoutlen
      delay = 0,
      icons = {
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- Document existing key chains
      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      },
    },
  },

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      --  :Telescope help_tags
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- defaults = {
        --   mappings = {
        --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        --   },
        -- },
        pickers = {
          colorscheme = {
            enable_preview = true,
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- Find and Replace UI
  {
    'MagicDuck/grug-far.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('grug-far').setup {}
      vim.keymap.set('n', '<leader>sR', function()
        require('grug-far').open()
      end, { desc = '[S]earch [R]eplace (grug-far)' })
    end,
  },

  -- LSP plugins
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  {
    -- Main LSP Configuration
    -- TODO: `:help lsp-vs-treesitter`
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },
      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      --  This function gets run when an LSP attaches to a particular buffer.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('ga', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
          map('gi', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          -- Fuzzy find all the symbols in your current document.
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')
          -- Fuzzy find all the symbols in your current workspace.
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
          -- Jump to the type of the word under your cursor.
          map('gt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

          -- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = {
          -- severity = vim.diagnostic.severity.ERROR
          severity = { off = true },
        },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          severity = { off = true },
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Install and config LSP servers
      local servers = {
        -- clangd = {},
        gopls = {},
        pyright = {},
        rust_analyzer = {},
        -- TypeScript/JavaScript (typescript-language-server via Mason)
        ts_ls = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        lua_ls = {
          -- cmd = { ... },
          -- filetypes = { ... },
          -- capabilities = {},
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              -- diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
        automatic_installation = false,
        automatic_enable = true,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end, -- LspAttach autocmd function
  }, -- nvim-lspconfig

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
        opts = {},
      },
      'folke/lazydev.nvim',
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },
      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- By default, we use the Lua implementation instead, but you may enable
      -- the rust implementation via `'prefer_rust_with_warning'`
      --
      -- See :h blink-cmp-config-fuzzy for more information
      fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  -- Python Debugging (DAP) and Run Configurations
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'jay-babu/mason-nvim-dap.nvim', -- Bridges Mason with nvim-dap
    },
    config = function()
      local dap = require 'dap'

      -- Debugger keymaps
      vim.keymap.set('n', '<leader>ds', function()
        dap.continue()
      end, { desc = 'Debug: Start/Continue' })
      vim.keymap.set('n', '<leader>o', function()
        dap.step_over()
      end, { desc = 'Debug: Step Over' })
      vim.keymap.set('n', '<leader>i', function()
        dap.step_into()
      end, { desc = 'Debug: Step Into' })
      vim.keymap.set('n', '<leader>u', function()
        dap.step_out()
      end, { desc = 'Debug: Step Out' })
      vim.keymap.set('n', '<leader>b', function()
        dap.toggle_breakpoint()
      end, { desc = 'Debug: Toggle Breakpoint' })
      vim.keymap.set('n', '<leader>B', function()
        dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end, { desc = 'Debug: Set Conditional Breakpoint' })
      vim.keymap.set('n', '<leader>dr', function()
        dap.repl.open()
      end, { desc = 'Debug: Open REPL' })
      vim.keymap.set('n', '<leader>dl', function()
        dap.run_last()
      end, { desc = 'Debug: Run Last Config' })
    end,
  },

  {
    'mfussenegger/nvim-dap-python',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      local dap_python = require 'dap-python'
      -- Use Mason’s installed debugpy
      local mason_path = vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python'
      dap_python.setup(mason_path)
      -- Define one basic configuration
      require('dap').configurations.python = {
        {
          type = 'python',
          request = 'launch',
          name = 'Launch current file',
          cwd = vim.fn.getcwd(),
          program = '${file}', -- Run current file
          pythonPath = function()
            return vim.fn.exepath 'python3' or 'python'
          end,
        },
      }
    end,
  },

  {
    'jay-babu/mason-nvim-dap.nvim',
    dependencies = { 'williamboman/mason.nvim', 'mfussenegger/nvim-dap' },
    opts = {
      ensure_installed = { 'debugpy' },
      handlers = {},
    },
  },

  {
    'rcarriga/nvim-dap-ui',
    dependencies = {
      'mfussenegger/nvim-dap',
      'nvim-neotest/nvim-nio',
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'
      dapui.setup {
        layouts = {
          {
            elements = {
              { id = 'scopes', size = 0.35 },
              { id = 'breakpoints', size = 0.20 },
              { id = 'stacks', size = 0.20 },
              { id = 'watches', size = 0.25 },
            },
            size = 50, -- width of right sidebar
            position = 'right',
          },
          {
            elements = {
              'repl',
              'console',
            },
            size = 15, -- height of bottom pane
            position = 'bottom',
          },
        },
      }

      -- Auto open/close
      dap.listeners.after.event_initialized['dapui_config'] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated['dapui_config'] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited['dapui_config'] = function()
        dapui.close()
      end

      -- Optional keymaps
      vim.keymap.set('n', '<leader>du', dapui.toggle, { desc = 'Debug: Toggle UI' })
    end,
  },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },

  -- Install Colorscheme
  {
    'rebelot/kanagawa.nvim',
    priority = 1000,
    config = function()
      require('kanagawa').setup {}
      vim.cmd.colorscheme 'kanagawa-dragon'
    end,
  },

  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically
}
