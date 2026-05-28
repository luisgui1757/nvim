return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante", "codecompanion" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      file_types = { "markdown" },
      completions = { lsp = { enabled = true } },

      heading = {
        sign = false,
        width = "block",
        min_width = 40,
        border = false,
        icons = { "󰉫 ", "󰉬 ", "󰉭 ", "󰉮 ", "󰉯 ", "󰉰 " },
        backgrounds = {
          "RenderMarkdownH1Bg",
          "RenderMarkdownH2Bg",
          "RenderMarkdownH3Bg",
          "RenderMarkdownH4Bg",
          "RenderMarkdownH5Bg",
          "RenderMarkdownH6Bg",
        },
        foregrounds = {
          "RenderMarkdownH1",
          "RenderMarkdownH2",
          "RenderMarkdownH3",
          "RenderMarkdownH4",
          "RenderMarkdownH5",
          "RenderMarkdownH6",
        },
      },

      code = {
        sign = false,
        width = "block",
        min_width = 60,
        border = "thin",
        language_pad = 2,
        highlight = "RenderMarkdownCode",
        highlight_inline = "RenderMarkdownCodeInline",
      },

      -- Task lists: this is the bit the user asked about.
      checkbox = {
        enabled = true,
        right_pad = 1,
        unchecked = { icon = "󰄱 ", highlight = "RenderMarkdownUnchecked" },
        checked = { icon = "󰱒 ", highlight = "RenderMarkdownChecked", scope_highlight = "@markup.strikethrough" },
        custom = {
          todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo" },
          important = { raw = "[!]", rendered = "󰀦 ", highlight = "RenderMarkdownError" },
          question = { raw = "[?]", rendered = "󰘥 ", highlight = "RenderMarkdownHint" },
          cancelled = { raw = "[/]", rendered = "󰜺 ", highlight = "@markup.strikethrough" },
        },
      },

      bullet = {
        icons = { "●", "○", "◆", "◇" },
        right_pad = 1,
      },

      quote = { repeat_linebreak = true },

      -- Obsidian-style callouts (> [!NOTE], > [!WARNING], etc.) — these
      -- come built-in; we just confirm the common ones are enabled.
      callout = {
        note = { raw = "[!NOTE]", rendered = "󰋽 Note", highlight = "RenderMarkdownInfo" },
        tip = { raw = "[!TIP]", rendered = "󰌶 Tip", highlight = "RenderMarkdownSuccess" },
        important = { raw = "[!IMPORTANT]", rendered = "󰅾 Important", highlight = "RenderMarkdownHint" },
        warning = { raw = "[!WARNING]", rendered = "󰀪 Warning", highlight = "RenderMarkdownWarn" },
        caution = { raw = "[!CAUTION]", rendered = "󰳦 Caution", highlight = "RenderMarkdownError" },
        abstract = { raw = "[!ABSTRACT]", rendered = "󰨸 Abstract", highlight = "RenderMarkdownInfo" },
        todo = { raw = "[!TODO]", rendered = "󰗡 Todo", highlight = "RenderMarkdownInfo" },
        question = { raw = "[!QUESTION]", rendered = "󰘥 Question", highlight = "RenderMarkdownWarn" },
        quote = { raw = "[!QUOTE]", rendered = "󱆨 Quote", highlight = "RenderMarkdownQuote" },
      },

      -- Links: render wikilinks (Obsidian syntax) as a small icon.
      link = {
        enabled = true,
        image = "󰥶 ",
        email = "󰀓 ",
        hyperlink = "󰌹 ",
        wiki = { icon = "󱗖 ", highlight = "RenderMarkdownWikiLink" },
      },

      pipe_table = {
        preset = "round",
        style = "full",
      },

      -- Rose Pine palette overrides for the heading/code surfaces.
      -- The plugin's defaults look fine on most colorschemes; these
      -- pin our rose-pine variants so headings have consistent depth.
      win_options = {
        conceallevel = { default = vim.o.conceallevel, rendered = 2 },
        concealcursor = { default = vim.o.concealcursor, rendered = "" },
      },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)

      -- Rose Pine heading backgrounds, deepest at H1, fading out.
      -- iris=#c4a7e7, foam=#9ccfd8, rose=#ebbcba, gold=#f6c177,
      -- pine=#31748f, love=#eb6f92
      local hi = function(name, opts2)
        vim.api.nvim_set_hl(0, name, opts2)
      end
      hi("RenderMarkdownH1", { fg = "#c4a7e7", bold = true })
      hi("RenderMarkdownH2", { fg = "#9ccfd8", bold = true })
      hi("RenderMarkdownH3", { fg = "#ebbcba", bold = true })
      hi("RenderMarkdownH4", { fg = "#f6c177", bold = true })
      hi("RenderMarkdownH5", { fg = "#31748f", bold = true })
      hi("RenderMarkdownH6", { fg = "#eb6f92", bold = true })
      hi("RenderMarkdownH1Bg", { bg = "#2a1f3d" })
      hi("RenderMarkdownH2Bg", { bg = "#1f2e36" })
      hi("RenderMarkdownH3Bg", { bg = "#33252a" })
      hi("RenderMarkdownH4Bg", { bg = "#332a1f" })
      hi("RenderMarkdownH5Bg", { bg = "#1f262a" })
      hi("RenderMarkdownH6Bg", { bg = "#33222a" })
      hi("RenderMarkdownCode", { bg = "#1f1d2e" })
      hi("RenderMarkdownCodeInline", { bg = "#26233a", fg = "#ebbcba" })
      hi("RenderMarkdownChecked", { fg = "#9ccfd8" })
      hi("RenderMarkdownUnchecked", { fg = "#6e6a86" })
      hi("RenderMarkdownTodo", { fg = "#f6c177" })
      hi("RenderMarkdownInfo", { fg = "#9ccfd8" })
      hi("RenderMarkdownSuccess", { fg = "#31748f" })
      hi("RenderMarkdownHint", { fg = "#c4a7e7" })
      hi("RenderMarkdownWarn", { fg = "#f6c177" })
      hi("RenderMarkdownError", { fg = "#eb6f92" })
      hi("RenderMarkdownQuote", { fg = "#ebbcba", italic = true })
      hi("RenderMarkdownWikiLink", { fg = "#c4a7e7", underline = true })
    end,
    keys = {
      { "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown rendering", ft = "markdown" },
    },
  },
}
