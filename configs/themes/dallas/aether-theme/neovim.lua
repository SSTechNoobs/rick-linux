return {
  {
    "omacom/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#000000",
        dark_bg    = "#000000",
        darker_bg  = "#000000",
        lighter_bg = "#1a1a1a",

        fg         = "#C8CED9",
        dark_fg    = "#969ba3",
        light_fg   = "#d0d5df",
        bright_fg  = "#d6dae3",
        muted      = "#686163",

        red        = "#978caf",
        yellow     = "#b9f9ff",
        orange     = "#a79dbb",
        green      = "#98c7e4",
        cyan       = "#aedcff",
        blue       = "#6e7ca1",
        purple     = "#a3a4d4",
        brown      = "#645e70",

        bright_red    = "#aea0cc",
        bright_yellow = "#aeffff",
        bright_green  = "#a1dfff",
        bright_cyan   = "#bbf4ff",
        bright_blue   = "#8091be",
        bright_purple = "#b7b8f6",

        accent               = "#6e7ca1",
        cursor               = "#C8CED9",
        foreground           = "#C8CED9",
        background           = "#000000",
        selection             = "#1a1a1a",
        selection_foreground = "#C8CED9",
        selection_background = "#1a1a1a",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
