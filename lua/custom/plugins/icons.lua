return {
  {
    'https://github.com/kyazdani42/nvim-web-devicons',
    lazy = true,
    priority = 1000,
    config = function()
      require('nvim-web-devicons').setup({
        override = {
          default_icon = {
            icon = "",
            color = "#6d8086",
            cterm_color = "66",
            name = "Default",
          },
          html = {
            icon = "",
            color = "#e34c26",
            cterm_color = "166",
            name = "HTML",
          },
          css = {
            icon = "",
            color = "#563d7c",
            cterm_color = "60",
            name = "CSS",
          },
          js = {
            icon = "",
            color = "#cbcb41",
            cterm_color = "185",
            name = "JavaScript",
          },
          ts = {
            icon = "ﯤ",
            color = "#519aba",
            cterm_color = "67",
            name = "TypeScript",
          },
          jsx = {
            icon = "",
            color = "#519aba",
            cterm_color = "67",
            name = "React",
          },
          vue = {
            icon = "﵂",
            color = "#8dc149",
            cterm_color = "107",
            name = "Vue",
          },
          json = {
            icon = "",
            color = "#cbcb41",
            cterm_color = "185",
            name = "JSON",
          },
          lua = {
            icon = "",
            color = "#51a0cf",
            cterm_color = "74",
            name = "Lua",
          },
          py = {
            icon = "",
            color = "#3572A5",
            cterm_color = "67",
            name = "Python",
          },
          md = {
            icon = "",
            color = "#519aba",
            cterm_color = "67",
            name = "Markdown",
          },
          zsh = {
            icon = "",
            color = "#89e051",
            cterm_color = "113",
            name = "Zsh",
          },
        },
        default = true,
      })
    end,
  }
}