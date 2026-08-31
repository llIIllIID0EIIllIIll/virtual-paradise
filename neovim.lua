-- ==============================================================================
--  Virtual☆Paradise — Neovim Cyberpunk Neon Theme
-- ==============================================================================

return {
	{
		"bjarneo/aether.nvim",
		branch = "v2",
		name = "aether",
		priority = 1000,
		opts = {
			transparent = false,
			colors = {
				-- Background colors
				bg = "#07080d",
				bg_dark = "#07080d",
				bg_highlight = "#0e141d",

				-- Foreground colors
				fg = "#eafbfa",
				fg_dark = "#b8d5d4",
				comment = "#7091a4",

				-- Accent colors
				red = "#ff0055",
				orange = "#ffe066",
				yellow = "#ffe066",
				green = "#00ff88",
				cyan = "#00f5d4",
				blue = "#39c5bb",
				purple = "#ffb7d5",
				magenta = "#ff79a8",
			},
			on_highlights = function(hl, c)
				hl["@constant.builtin"] = { fg = c.orange }
				hl["@keyword.function"] = { fg = c.magenta, bold = true }
				hl["@module"] = { fg = c.purple }
				hl["@property"] = { fg = c.fg_dark }
				hl["@type.builtin"] = { fg = c.cyan }
				hl["@variable.member"] = { fg = c.fg_dark }

				-- Window separators
				hl.WinSeparator = { fg = c.comment }
				hl.VertSplit = { fg = c.comment }
				hl.NeoTreeWinSeparator = { fg = c.comment }
				hl.NeoTreeVertSplit = { fg = c.comment }
				hl.NvimTreeVertSplit = { fg = c.comment }

				hl["@lsp.type.class"] = { fg = c.yellow }
				hl["@lsp.type.interface"] = { fg = c.yellow }
				hl["@lsp.type.namespace"] = { fg = c.purple }
				hl["@lsp.type.parameter"] = { fg = c.cyan, italic = true }
				hl["@lsp.type.property"] = { fg = c.fg_dark }
				hl["@lsp.type.struct"] = { fg = c.yellow }
				hl["@lsp.type.type"] = { fg = c.yellow }
				hl["@lsp.type.typeParameter"] = { fg = c.blue }
			end,
		},
		config = function(_, opts)
			require("aether").setup(opts)
			vim.cmd.colorscheme("aether")

			-- Enable hot reload
			require("aether.hotreload").setup()
		end,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "aether",
		},
	},
}