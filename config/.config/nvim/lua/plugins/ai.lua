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
          reload = {
            enabled = true, -- recharge les buffers edites par OpenCode (checktime)
          },
        },
      }

      -- OpenCode v2 : le plugin ne pilote plus le TUI (commandes session.* supprimees),
      -- il dialogue avec le service en arriere-plan. Le terminal est gere par snacks.
      -- Modifiable avant la 1re creation du terminal (`nvim --agent opencode --last`) :
      -- snacks indexe le terminal par commande, la changer apres creerait un 2e terminal.
      local opencode_cmd = "opencode"
      local opencode_term_opts = {
        win = {
          position = "right",
          width = math.floor(vim.o.columns * 0.35),
        },
      }

      -- Onglet dedie (tabpage marquee vim.t.ai_tab == "opencode") : meme buffer terminal
      -- que le split, jamais affiches ensemble (le TUI se redimensionnerait a la plus petite).
      local function find_opencode_tab()
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
          local ok, v = pcall(vim.api.nvim_tabpage_get_var, tab, "ai_tab")
          if ok and v == "opencode" then
            return tab
          end
        end
      end

      -- Buffer terminal opencode courant (nil si aucun) pour le garde-fou TermClose. On garde
      -- le dernier connu : opencode_cmd peut etre reinitialise avant que TermClose ne passe.
      local last_term_buf
      require("config.ai_tab").register_term("opencode", function()
        local ok, t = pcall(function() return require("snacks.terminal").get(opencode_cmd, { create = false }) end)
        if ok and t and t:buf_valid() then
          last_term_buf = t.buf
        end
        if last_term_buf and vim.api.nvim_buf_is_valid(last_term_buf) then
          return last_term_buf
        end
      end)

      -- Remet le terminal dans l'onglet `tab` s'il n'y est plus affiche (marque perimee).
      local function ensure_opencode_term(tab)
        local term = require("snacks.terminal").get(opencode_cmd, { create = false })
        if term and term:buf_valid() then
          return require("config.ai_tab").ensure_terminal(tab, term.buf)
        end
      end

      -- Ferme l'onglet opencode s'il existe. Le buffer terminal survit (snacks ne le
      -- supprime pas : ce n'est pas sa fenetre).
      local function close_opencode_tab()
        local tab = find_opencode_tab()
        if not tab then
          return
        end
        if #vim.api.nvim_list_tabpages() > 1 then
          vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(tab))
          return
        end
        -- Dernier onglet : tabclose impossible, on remplace le terminal par un autre
        -- buffer sans le tuer.
        local term = require("snacks.terminal").get(opencode_cmd, { create = false })
        require("config.ai_tab").release_last_tab(tab, term and term.buf)
      end

      local function opencode_toggle()
        local term = require("snacks.terminal").get(opencode_cmd, { create = false })
        if not (term and term:valid()) then
          close_opencode_tab() -- le split va s'afficher : un seul affichage a la fois
        end
        require("snacks.terminal").toggle(opencode_cmd, opencode_term_opts)
      end

      -- Affiche le terminal opencode (cree si absent) sans jamais le masquer : meme
      -- commande et memes options que <leader>jt, mais get() au lieu de toggle().
      -- Si l'onglet opencode est ouvert, il affiche deja le terminal : rien a faire.
      local function opencode_show()
        local tab = find_opencode_tab()
        if tab then
          ensure_opencode_term(tab)
          return
        end
        local win, created = require("snacks.terminal").get(opencode_cmd, opencode_term_opts)
        if win and not created then
          win:show()
        end
      end

      -- Terminal opencode dont le buffer existe encore (snacks garde un objet perime apres
      -- la suppression du buffer : get() seul ne suffit pas).
      local function existing_term()
        local t = require("snacks.terminal").get(opencode_cmd, { create = false })
        return t and t:buf_valid() and t or nil
      end

      -- <leader>jT : bascule l'onglet opencode (focus dans le terminal).
      local function opencode_toggle_tab(opts)
        local launch_cmd -- commande de lancement posee par cet appel (voir plus bas)
        local tab = find_opencode_tab()
        -- onglet perime (plus de terminal vivant) + prompt a lancer : on le reutilise, sans
        -- le fermer ni le quitter (le texte ne doit pas se perdre)
        local reuse
        if tab and opts and opts.prompt and opts.prompt ~= "" then
          if not existing_term() then
            reuse = tab
          end
        end
        if tab and not reuse and tab == vim.api.nvim_get_current_tabpage() then
          close_opencode_tab()
          return
        end
        if tab and not reuse then
          vim.api.nvim_set_current_tabpage(tab)
          local win = ensure_opencode_term(tab)
          if win then
            vim.api.nvim_set_current_win(win)
            vim.cmd("startinsert")
          end
          return
        end

        -- get() peut ouvrir un split a la creation : on le masque (le buffer reste vivant,
        -- hide() = close({ buf = false })), idem si le split etait deja visible.
        if opts and (opts.last or (opts.prompt and opts.prompt ~= ""))
          and not existing_term() then
          -- liste d'arguments (pas de shell) ; toutes les fonctions relisent opencode_cmd
          local cmd = { "opencode" }
          local has_prompt = opts.prompt and opts.prompt ~= ""
          if has_prompt then
            table.insert(cmd, "--auto") -- prompt fourni : on execute, les permissions ne bloquent pas
          end
          if opts.last then
            table.insert(cmd, "--continue")
          end
          if has_prompt then
            -- une seule chaine argv : un texte commencant par "-" n'est pas lu comme une option
            table.insert(cmd, "--prompt=" .. opts.prompt)
          end
          if #cmd > 1 then
            opencode_cmd = cmd
            launch_cmd = cmd
          end
        end
        local term = require("snacks.terminal").get(opencode_cmd, opencode_term_opts)
        if launch_cmd then
          -- les arguments de lancement ne valent que pour ce terminal : quand il meurt,
          -- les relances (jt, server.start, dictee) repartent sur "opencode" simple
          local mine = launch_cmd
          if term and term:buf_valid() then
            vim.api.nvim_create_autocmd("TermClose", {
              buffer = term.buf,
              once = true,
              callback = function()
                if opencode_cmd == mine then
                  opencode_cmd = "opencode"
                end
              end,
            })
          else
            opencode_cmd = "opencode"
          end
        end
        if not term then
          return
        end
        if term:valid() then
          term:hide()
        end
        if not term:buf_valid() then
          return
        end

        local win
        if reuse then
          vim.api.nvim_set_current_tabpage(reuse)
          win = require("config.ai_tab").main_win(reuse)
          if not win then
            vim.notify("opencode : aucune fenêtre disponible. Texte : " .. opts.prompt, vim.log.levels.ERROR)
            return
          end
          vim.api.nvim_set_current_win(win)
        else
          vim.cmd("tabnew")
          win = vim.api.nvim_get_current_win()
          local empty = vim.api.nvim_get_current_buf()
          vim.bo[empty].bufhidden = "wipe" -- ne pas laisser le buffer [No Name]
        end
        vim.api.nvim_win_set_buf(win, term.buf)
        vim.t.ai_tab = "opencode"
        require("config.ai_tab").show_tree(win)
      end

      require("config.ai_tab").register("opencode", opencode_toggle_tab)

      -- Si le service est absent, le plugin lance `server.start` : terminal snacks, pas son vsplit term://
      require("opencode.config").opts.server.start = opencode_show

      -- Dictee : envoi brut a la session (POST /api/session/<id>/prompt) sans passer par
      -- prompt()/ask() : aucune substitution de contexte (@this, @buffer...), et max_time 30 s
      -- (2 s par defaut). La session est resolue AVANT l'envoi.
      local function opencode_send(text, cb)
        require("opencode.server.discovery")
          .get()
          :next(function(server)
            return server:resolve_session():next(function(session)
              return server:request("/api/session/" .. session.id .. "/prompt", "POST", { text = text }, { max_time = 30 })
            end)
          end)
          :next(function()
            cb(true)
          end)
          :catch(function(err)
            cb(false, err and tostring(err) or "")
          end)
      end

      -- <leader>jP : tache depuis un prompt. Sans terminal vivant : onglet agent avec ce prompt
      -- (--auto) ; sinon envoi a la session existante + affichage de l'onglet agent.
      local function opencode_task()
        vim.ui.input({ prompt = "Tâche opencode : " }, function(input)
          if not input or vim.trim(input) == "" then
            return
          end
          local term = require("snacks.terminal").get(opencode_cmd, { create = false })
          local alive = false
          if term and term:buf_valid() then
            local job = vim.b[term.buf].terminal_job_id
            alive = job ~= nil and vim.fn.jobwait({ job }, 0)[1] == -1
            if not alive then
              -- terminal mort resté ouvert (split) : on le supprime pour repartir d'une session neuve
              require("config.ai_tab").detach(term.buf) -- sans fermer l'onglet agent qui l'affiche
              pcall(vim.api.nvim_buf_delete, term.buf, { force = true })
            end
          end
          if not alive then
            opencode_toggle_tab({ prompt = input })
            return
          end
          local tab = find_opencode_tab()
          if tab then
            vim.api.nvim_set_current_tabpage(tab)
            local win = ensure_opencode_term(tab)
            if win then
              vim.api.nvim_set_current_win(win)
              vim.cmd("startinsert")
            end
          else
            opencode_toggle_tab() -- cree l'onglet avec le terminal existant
          end
          opencode_send(input, function(ok, err)
            if ok then
              vim.notify("Session existante : message envoyé, mode inchangé", vim.log.levels.INFO)
            else
              vim.notify(
                "opencode : envoi échoué (" .. tostring(err) .. ")\nTexte : " .. input,
                vim.log.levels.ERROR
              )
            end
          end)
        end)
      end

      local function opencode_on_fail(err)
        if err:find("exit code: 28", 1, true) then
          -- timeout curl : le service a peut-etre recu le prompt
          vim.notify("Envoi peut-être reçu par opencode, vérifie avant de renvoyer", vim.log.levels.WARN, { title = "Dictee" })
        elseif err == "" or err:find("No OpenCode", 1, true) or err:find("Failed to connect", 1, true)
          or err:find("exit code: 7", 1, true) then
          opencode_show()
          vim.notify("Lance/ouvre une session opencode puis <C-s>", vim.log.levels.WARN, { title = "Dictee" })
        else
          vim.notify("Envoi echoue : " .. err, vim.log.levels.ERROR, { title = "Dictee" })
        end
      end

      -- Dictee en direct : un seul raccourci. 1er appui = ecoute + panneau sous le terminal
      -- opencode (le focus reste ou il etait) ; 2e appui = fin, puis relecture dans le panneau.
      local dictation_finishing = false
      local function dictation_toggle()
        local voice = require("config.voice")
        local panel = require("config.voice_panel")
        local function dnotify(msg, level)
          vim.notify(msg, level or vim.log.levels.INFO, { title = "Dictee" })
        end

        if voice.is_active() then
          if dictation_finishing then
            dnotify("Transcription des derniers mots en cours…")
            return
          end
          dictation_finishing = true
          panel.status("finishing")
          voice.stop()
          return
        end
        if panel.is_open() then
          dnotify("Relecture en cours : Échap envoie, q annule")
          return
        end

        local origin_win = vim.api.nvim_get_current_win()
        local origin_mode = vim.api.nvim_get_mode().mode:sub(1, 1)
        opencode_show()
        local term = require("snacks.terminal").get(opencode_cmd, { create = false })
        local got_text, had_error, fatal = false, false, false
        dictation_finishing = false

        panel.open({
          anchor_win = term and term.win or nil,
          send = opencode_send,
          on_sent = opencode_show,
          on_fail = opencode_on_fail,
        })
        local ok, err = voice.start({
          -- un morceau en erreur arrive comme "[…]" (info.error) : visible a sa place, wav garde
          on_segment = function(text, _, info)
            if info and info.error then
              had_error = true
            elseif vim.trim(text or "") ~= "" then
              got_text = true
            end
            panel.append(text)
          end,
          on_status = function(st, info)
            if st == "error" and info and info.fatal then
              fatal = true
            end
            panel.status(st, info)
          end,
          on_done = function()
            dictation_finishing = false
            if got_text then
              panel.review()
            else
              panel.close()
              if fatal then
                -- l'erreur "Micro indisponible" a deja ete notifiee
              elseif had_error then
                dnotify("Transcription impossible : audio conservé, voir voice.log", vim.log.levels.ERROR)
              else
                dnotify("Aucune parole détectée")
              end
            end
          end,
        })
        if not ok then
          panel.close()
          dnotify("Dictée impossible : " .. tostring(err), vim.log.levels.ERROR)
        end

        -- Rendre le focus ET le mode d'origine. snacks fait un startinsert differe a la creation /
        -- l'affichage du terminal : on restaure tout de suite, puis apres lui (schedule, defer).
        local function restore_origin()
          if not vim.api.nvim_win_is_valid(origin_win) then
            return
          end
          if vim.api.nvim_get_current_win() ~= origin_win then
            vim.api.nvim_set_current_win(origin_win)
          end
          local m = vim.api.nvim_get_mode().mode:sub(1, 1)
          if origin_mode == "t" or origin_mode == "i" then
            if m ~= origin_mode then
              vim.cmd("startinsert")
            end
          elseif m == "i" or m == "t" then
            vim.cmd("stopinsert")
          end
        end
        restore_origin()
        vim.schedule(restore_origin)
        vim.defer_fn(restore_origin, 60)
        vim.defer_fn(restore_origin, 250)
      end

      -- Affiche le terminal quand OpenCode commence a executer une tache
      vim.api.nvim_create_autocmd("User", {
        pattern = { "OpencodeEvent:session.execution.started" },
        callback = function()
          local tab = find_opencode_tab()
          if tab then
            ensure_opencode_term(tab) -- l'onglet doit afficher le terminal
            return
          end
          local win = require("snacks.terminal").get(opencode_cmd, { create = false })
          if win then
            win:show()
          end
        end,
      })

      vim.keymap.set({ "n", "x" }, "<leader>ja", function() require("opencode").ask("@this: ") end, { desc = "Ask OpenCode (@this)" })
      vim.keymap.set({ "n", "t" }, "<leader>jt", opencode_toggle, { desc = "Toggle opencode" })
      vim.keymap.set({ "n", "t" }, "<leader>jT", function() opencode_toggle_tab() end, { desc = "Toggle opencode (onglet)" })
      vim.keymap.set("n", "<leader>jP", opencode_task, { desc = "opencode: tâche (prompt, auto)" })
      -- <leader>jv seulement en normal (en mode terminal il intercepterait "espace j v" tape dans le TUI) ;
      -- <M-v> sert en normal, terminal et insert (libre dans nvim et dans la config WezTerm).
      vim.keymap.set("n", "<leader>jv", dictation_toggle, { desc = "Dictee vers opencode" })
      vim.keymap.set({ "n", "t", "i" }, "<M-v>", dictation_toggle, { desc = "Dictee vers opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>jx", function() require("opencode").select() end, { desc = "OpenCode actions" })

      vim.keymap.set({ "n", "x" }, "<leader>jpe", function() require("opencode").prompt("Explain @this and its context") end, { desc = "Explain" })
      vim.keymap.set({ "n", "x" }, "<leader>jpf", function() require("opencode").prompt("Fix @diagnostics") end, { desc = "Fix diagnostics" })
      vim.keymap.set({ "n", "x" }, "<leader>jpr", function() require("opencode").prompt("Review @this for correctness and readability") end, { desc = "Review" })
      vim.keymap.set({ "n", "x" }, "<leader>jpd", function() require("opencode").prompt("Add comments documenting @this") end, { desc = "Document" })
      vim.keymap.set({ "n", "x" }, "<leader>jpo", function() require("opencode").prompt("Optimize @this for performance and readability") end, { desc = "Optimize" })
      vim.keymap.set({ "n", "x" }, "<leader>jpt", function() require("opencode").prompt("Add tests for @this") end, { desc = "Add tests" })

      vim.keymap.set("n", "<leader>jbb", function() require("opencode").prompt("@buffer: ") end, { desc = "Send current buffer" })
      vim.keymap.set("n", "<leader>jba", function() require("opencode").prompt("@buffers: ") end, { desc = "Send all buffers" })
      vim.keymap.set("n", "<leader>jbv", function() require("opencode").prompt("@visible: ") end, { desc = "Send visible text" })
      vim.keymap.set("n", "<leader>jbd", function() require("opencode").prompt("@diagnostics: ") end, { desc = "Send diagnostics" })

      vim.keymap.set({ "n", "x" }, "go", function() return require("opencode").operator("@this ") end, { expr = true, desc = "Add range to opencode" })
      vim.keymap.set("n", "goo", function() return require("opencode").operator("@this ") .. "_" end, { expr = true, desc = "Add line to opencode" })

      vim.keymap.set("n", "+", "<C-a>", { desc = "Increment", noremap = true })
      vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement", noremap = true })
    end,
  },
}
