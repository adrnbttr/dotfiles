return {
  {
    "Exafunction/codeium.nvim",
    cmd = "Codeium",
    event = "InsertEnter",
    build = ":Codeium Auth",
    opts = {
      enable_cmp_source = false,
      virtual_text = {
        enabled = true,
        key_bindings = {
          accept = false,
          next = "<M-Right>",
          prev = "<M-Left>",
          clear = "<M-Down>",
        },
      },
    },
  },
  {
    "Exafunction/codeium.nvim",
    opts = function()
      local lv = rawget(_G, "LazyVim")
      local function codeium_accept()
        local ok, vt = pcall(require, "codeium.virtual_text")
        if ok and vt.get_current_completion_item() then
          if lv and lv.create_undo then
            lv.create_undo()
          end
          vim.api.nvim_input(vt.accept())
          return true
        end
      end

      if lv and lv.cmp and lv.cmp.actions then
        lv.cmp.actions.ai_accept = codeium_accept
      end

      vim.keymap.set("i", "<C-l>", function()
        codeium_accept()
      end, { desc = "Accept AI suggestion" })
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    enabled = false,
  },
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
      ---@module 'snacks'
      { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
      vim.o.autoread = true

      ---@type opencode.Opts
      vim.g.opencode_opts = {
        events = {
          reload = function()
            vim.schedule(function()
              vim.cmd("checktime")
            end)
          end,
        },
      }

      vim.keymap.set({ "n", "x" }, "<leader>ja", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask (@this)" })
      vim.keymap.set({ "n" }, "<leader>jn", function() require("opencode").command("session.new") end, { desc = "New session" })
      vim.keymap.set({ "n" }, "<leader>ju", function() require("opencode").command("session.undo") end, { desc = "Undo last action" })
      vim.keymap.set({ "n" }, "<leader>jr", function() require("opencode").command("session.redo") end, { desc = "Redo" })
      vim.keymap.set({ "n" }, "<leader>jc", function() require("opencode").command("session.compact") end, { desc = "Compact session" })
      vim.keymap.set({ "n" }, "<leader>js", function() require("opencode").command("session.select") end, { desc = "Select session" })
      vim.keymap.set({ "n" }, "<leader>jS", function() require("opencode").command("session.share") end, { desc = "Share session" })
      vim.keymap.set({ "n", "t" }, "<leader>jt", function() require("opencode").toggle() end, { desc = "Toggle opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>jx", function() require("opencode").select() end, { desc = "Execute action" })

      vim.keymap.set({ "n", "x" }, "<leader>jpe", function() require("opencode").prompt("Explain @this and its context") end, { desc = "Explain" })
      vim.keymap.set({ "n", "x" }, "<leader>jpf", function() require("opencode").prompt("Fix @diagnostics") end, { desc = "Fix diagnostics" })
      vim.keymap.set({ "n", "x" }, "<leader>jpr", function() require("opencode").prompt("Review @this for correctness and readability") end, { desc = "Review" })
      vim.keymap.set({ "n", "x" }, "<leader>jpd", function() require("opencode").prompt("Add comments documenting @this") end, { desc = "Document" })
      vim.keymap.set({ "n", "x" }, "<leader>jpo", function() require("opencode").prompt("Optimize @this for performance and readability") end, { desc = "Optimize" })
      vim.keymap.set({ "n", "x" }, "<leader>jpt", function() require("opencode").prompt("Add tests for @this") end, { desc = "Add tests" })

      vim.keymap.set({ "n" }, "<leader>jbb", function() require("opencode").ask("@buffer: ", { submit = true }) end, { desc = "Send current buffer" })
      vim.keymap.set({ "n" }, "<leader>jba", function() require("opencode").ask("@buffers: ", { submit = true }) end, { desc = "Send all buffers" })
      vim.keymap.set({ "n" }, "<leader>jbv", function() require("opencode").ask("@visible: ", { submit = true }) end, { desc = "Send visible text" })
      vim.keymap.set({ "n" }, "<leader>jbd", function() require("opencode").ask("@diagnostics: ", { submit = true }) end, { desc = "Send diagnostics" })

      vim.keymap.set("n", "<S-C-u>", function() require("opencode").command("session.half.page.up") end, { desc = "opencode half page up" })
      vim.keymap.set("n", "<S-C-d>", function() require("opencode").command("session.half.page.down") end, { desc = "opencode half page down" })

      vim.keymap.set({ "n", "x" }, "go", function() return require("opencode").operator("@this ") end, { expr = true, desc = "Add range to opencode" })
      vim.keymap.set("n", "goo", function() return require("opencode").operator("@this ") .. "_" end, { expr = true, desc = "Add line to opencode" })

      vim.keymap.set("n", "+", "<C-a>", { desc = "Increment", noremap = true })
      vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement", noremap = true })
    end,
  },
}
