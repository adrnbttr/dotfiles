-- Dictee vocale : 1er appel = enregistre (parecord), 2e appel = arrete puis
-- transcrit en francais (voice-transcribe, whisper.cpp) et passe le texte a on_text.
-- Le texte est d'abord copie dans les registres + et " pour ne jamais etre perdu.

local M = {}

local MUTE_THRESHOLD = 0.01 -- amplitude max sox, meme seuil que script/doctor
local MIN_TIMEOUT_S = 180   -- timeout de transcription : max(180 s, 3 x duree audio)
local TIMEOUT_FACTOR = 3

local state = {
  job = nil,          -- job parecord en cours
  wav = nil,          -- fichier wav en cours
  stopping = false,   -- parecord arrete, on attend sa sortie
  transcribing = false,
  on_text = nil,
}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Dictee" })
end

local function transcribe(wav, size, on_text)
  state.transcribing = true
  notify("⏳ Transcription…")
  local out, err = {}, {}
  local timed_out = false
  local timer = vim.uv.new_timer()
  local ok, job = pcall(vim.fn.jobstart, { "voice-transcribe", wav }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data) out = data end,
    on_stderr = function(_, data) err = data end,
    on_exit = function(_, code)
      timer:stop()
      timer:close()
      vim.schedule(function()
        state.transcribing = false
        if timed_out then
          notify("Transcription trop longue, abandonnee. Audio conserve : " .. wav, vim.log.levels.ERROR)
          return
        end
        if code ~= 0 then
          local msg = vim.trim(table.concat(err, "\n"))
          notify("Echec de la transcription (code " .. code .. ")\n" .. msg .. "\nAudio conserve : " .. wav,
            vim.log.levels.ERROR)
          return
        end
        local text = vim.trim(table.concat(out, " "))
        if text == "" then
          os.remove(wav)
          notify("Aucune parole detectee")
          return
        end
        -- jamais perdre le texte : presse-papiers d'abord (pcall : pas de provider possible)
        pcall(vim.fn.setreg, "+", text)
        pcall(vim.fn.setreg, '"', text)
        -- le wav n'est supprime qu'une fois le texte affiche (on_text sans erreur)
        local shown, e = pcall(on_text, text)
        if shown then
          os.remove(wav)
        else
          notify("Affichage de la dictee impossible : " .. tostring(e) .. "\nTexte dans le presse-papiers. Audio conserve : " .. wav,
            vim.log.levels.ERROR)
        end
      end)
    end,
  })
  if not ok or job <= 0 then
    timer:close()
    state.transcribing = false
    notify("Impossible de lancer voice-transcribe : " .. tostring(ok and "code " .. job or job)
      .. "\nAudio conserve : " .. wav, vim.log.levels.ERROR)
    return
  end
  local seconds = math.max(MIN_TIMEOUT_S, TIMEOUT_FACTOR * math.max(0, size - 44) / 32000)
  timer:start(seconds * 1000, 0, vim.schedule_wrap(function()
    if state.transcribing then
      timed_out = true
      pcall(vim.fn.jobstop, job)
    end
  end))
end

local function start(on_text)
  local dir = (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/nvim-voice"
  vim.fn.mkdir(dir, "p")
  -- nom unique par enregistrement : plusieurs nvim, jamais d'ecrasement
  local wav = string.format("%s/record-%d-%s.wav", dir, vim.fn.getpid(), os.date("%Y%m%d-%H%M%S"))

  local rec_err
  local opts = {
    stderr_buffered = true,
    on_stderr = function(_, data) rec_err = data end,
    on_exit = function(_, code)
      vim.schedule(function()
        local was_stopping = state.stopping
        local cb, file = state.on_text, state.wav
        -- etat remis a zero dans tous les cas : un nouvel appui relance proprement
        state.job, state.stopping, state.wav, state.on_text = nil, false, nil, nil
        local st = vim.uv.fs_stat(file)
        -- un wav sans donnees ne fait que 44 octets d'en-tete
        local has_data = st and st.size > 44
        if not was_stopping then
          local msg = vim.trim(table.concat(rec_err or {}, "\n"))
          notify("parecord s'est arrete tout seul (code " .. code .. ")" .. (msg ~= "" and ("\n" .. msg) or "")
            .. (has_data and "\nTranscription de ce qui a ete capture…" or ""), vim.log.levels.ERROR)
          if not has_data then
            os.remove(file)
            return
          end
        elseif not has_data then
          os.remove(file)
          notify("Aucun audio capture", vim.log.levels.WARN)
          return
        end
        -- micro muet (panne WSLg audin) : meme seuil que script/doctor ; si sox echoue, on saute le controle
        local sok, stat = pcall(function() return vim.system({ "sox", file, "-n", "stat" }, { text = true }):wait() end)
        if sok and stat then
          local amp = tonumber(((stat.stderr or "") .. (stat.stdout or "")):match("Maximum amplitude:%s*([%d%.]+)"))
          if amp and amp < MUTE_THRESHOLD then
            os.remove(file)
            notify("Micro muet : lance `wsl --shutdown` depuis Windows", vim.log.levels.ERROR)
            return
          end
        end
        transcribe(file, st.size, cb)
      end)
    end,
  }
  -- Sous WSLg le micro passe par PulseServer ; absent de l'env si nvim n'a pas ete lance depuis zsh.
  -- env = {} est refuse par jobstart (E475) : ne le passer que s'il est non vide.
  if (vim.env.PULSE_SERVER or "") == "" and vim.uv.fs_stat("/mnt/wslg/PulseServer") then
    opts.env = { PULSE_SERVER = "unix:/mnt/wslg/PulseServer" }
  end

  local ok, job = pcall(vim.fn.jobstart, {
    "parecord", "--channels=1", "--rate=16000", "--format=s16le", "--file-format=wav", wav,
  }, opts)
  if not ok or job <= 0 then
    notify("Impossible de lancer parecord : " .. tostring(ok and "code " .. job or job), vim.log.levels.ERROR)
    return
  end
  state.job, state.wav, state.on_text = job, wav, on_text
  notify("🎤 Dictée… <leader>jv pour arrêter")
end

--- Demarre ou arrete la dictee ; on_text(text) est appele avec la transcription.
function M.toggle(on_text)
  if state.transcribing or state.stopping then
    notify("Transcription en cours, patiente…", vim.log.levels.WARN)
    return
  end
  if state.job then
    state.stopping = true
    vim.fn.jobstop(state.job) -- SIGTERM : parecord finalise l'en-tete du wav
    return
  end
  start(on_text)
end

return M
