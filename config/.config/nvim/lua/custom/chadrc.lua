---@type ChadrcConfig 
local M = {}
M.ui = {
    theme = 'radium',
    changed_themes = {
        radium = {
           base_16 = {
                base00 = "#171B20", -- updated
                base01 = "#21262e", -- updated
                base02 = "#242931", -- updated
                base03 = "#485263", -- updated
                base04 = "#485263",  -- updated
                base05 = "#bfc6d4",
                base06 = "#ccd3e1",
                base07 = "#D9E0EE",
                base08 = "#F38BA8",
                base09 = "#F8BD96",
                base0A = "#FAE3B0",
                base0B = "#ABE9B3",
                base0C = "#89DCEB",
                base0D = "#89B4FA",
                base0E = "#CBA6F7",
                base0F = "#F38BA8",
           },
           base_30 = {
                white = "#D9E0EE",
                darker_black = "#111519", -- updated
                black = "#171B20",  -- updated
                black2 = "#1e2227", -- updated
                one_bg = "#262a2f", -- updated
                one_bg2 = "#2f3338", -- updated
                one_bg3 = "#373b40", -- updated
                grey = "#474656",
                grey_fg = "#4e4d5d",
                grey_fg2 = "#555464",
                light_grey = "#605f6f",
                red = "#F38BA8",
                baby_pink = "#ffa5c3",
                pink = "#F5C2E7",
                line = "#383747",
                green = "#ABE9B3",
                vibrant_green = "#b6f4be",
                nord_blue = "#8bc2f0",
                blue = "#89B4FA",
                yellow = "#FAE3B0",
                sun = "#ffe9b6",
                purple = "#d0a9e5",
                dark_purple = "#c7a0dc",
                teal = "#B5E8E0",
                orange = "#F8BD96",
                cyan = "#89DCEB",
                statusline_bg = "#1c2026", -- updated
                lightbg = "#2b3038", -- updated
                pmenu_bg = "#ABE9B3",
                folder_bg = "#89B4FA",
                lavender = "#c7d1ff",
           }
        },
    },
}
M.plugins = "custom.plugins"
M.mappings = require "custom.mappings"
return M
