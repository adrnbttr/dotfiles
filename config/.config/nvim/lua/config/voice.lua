-- Dictee vocale CONTINUE : parecord ecrit en continu dans un fichier raw, un timer lit les
-- octets nouveaux, decoupe sur les pauses, et chaque morceau est transcrit (voice-transcribe,
-- une transcription a la fois, asynchrone) pendant qu'on parle.
--
-- API :
--   M.start(cb) -> true | false, msg
--     cb.on_segment(text, idx, info)  texte non vide, idx = 1, 2, 3... dans l'ordre strict.
--                               Un morceau en erreur est livre a sa place comme "[…]" avec
--                               info = { error = true, wav = chemin } (le wav est garde).
--     cb.on_status(state, info) "listening"{elapsed}  (seulement une fois le 1er octet recu)
--                               | "muted"{elapsed} | "reconnecting"{attempt}
--                               | "finishing"{pending} | "error"{msg[, fatal=true]}
--                               fatal : micro indisponible, l'ecoute s'arrete d'elle-meme puis on_done
--     cb.on_done()              apres stop() (ou arret fatal), quand tout est livre
--   M.stop()       arrete parecord, transcrit le dernier morceau, puis on_done
--   M.cancel()     arrete tout, plus aucun callback, fichiers nettoyes
--   M.is_active()  vrai entre start et on_done/cancel
--
-- Segmentation : le seuil de bruit ne sert QU'A choisir ou couper (pause de 700 ms apres 1,5 s de
-- parole, ou de 1,5 s apres 0,3 s de parole, ou coupure forcee a 25 s sur la fenetre la plus calme des 3 dernieres secondes). Les
-- morceaux couvrent tout le flux, contigus, sans trou ; seul le silence numerique (RMS max sous
-- 0.001) n'est pas envoye, la VAD de whisper gere le reste.
-- A chaque (re)lancement, parecord ecrit dans un NOUVEAU fichier raw ; le precedent est lu
-- jusqu'au bout (rien n'est perdu), le morceau en cours est coupe, puis le fichier est supprime.

local M = {}

local ffi = require("ffi")
local uv = vim.uv or vim.loop

local RATE = 16000
local BYTES_PER_MS = RATE * 2 / 1000        -- 32 octets/ms
local WIN_MS = 100
local WIN_BYTES = WIN_MS * BYTES_PER_MS     -- 3200
local TICK_MS = 200
local MUTE_THRESHOLD = 0.01                 -- amplitude max (0..1), meme seuil que script/doctor
local MUTE_S = 3
local SPEECH_FLOOR = 0.01                   -- plancher du seuil de coupure (RMS 0..1)
local NOISE_FACTOR = 2                      -- seuil = bruit de fond x facteur (choix des coupures seulement)
local NOISE_HIST = 100                      -- fenetres (10 s) pour estimer le bruit (centile 20)
local NOISE_MIN_WIN = 10
local ABS_SILENCE = 0.001                   -- RMS max sous lequel un morceau est du silence numerique
local MIN_SEG_BYTES = 3200                  -- pas de morceau sous 100 ms
local MIN_SPEECH_MS = 300                 -- parole minimale d'un morceau coupe sur une longue pause
local CUT_SILENCE_MS = 700                  -- pause qui coupe un morceau deja assez long...
local CUT_SPEECH_MS = 1500                  -- ... (au moins 1,5 s de parole : whisper rate les fragments)
local LONG_PAUSE_MS = 1500                  -- pause qui coupe meme un morceau court
local MAX_SEGMENT_WIN = 250                 -- coupure forcee a 25 s
local FORCED_LOOKBACK_WIN = 30              -- ... sur la fenetre la plus calme des 3 dernieres secondes
local MARGIN_WIN = 3                        -- silence garde apres la parole (300 ms)
local READ_MAX = 1024 * 1024
local BACKOFF = { 500, 1000, 2000 }         -- puis 2000 en boucle
local MAX_FAILS = 8                         -- relances sans audio tolerees...
local FAIL_WINDOW_S = 30                    -- ... sur cette fenetre
local MIN_AUDIO_BYTES = 16000               -- une run qui a produit ca a "du audio"
local COALESCE_BYTES = 25 * RATE * 2        -- fusion de morceaux en attente, jusqu'a 25 s
local PROMPT_CHARS = 200
local STALE_S = 24 * 3600
local MIN_TIMEOUT_S = 180
local TIMEOUT_FACTOR = 3
local LOG_MAX = 1024 * 1024
local FATAL_MSG = "Micro indisponible : wsl --shutdown (Windows)"

local sess = nil -- session courante

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Dictee" })
end

local function dir_path()
  return (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/nvim-voice"
end

local function now_s()
  return uv.hrtime() / 1e9
end

local function log(s, line)
  local f = io.open(s.dir .. "/voice.log", "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S "), line, "\n")
    f:close()
  end
end

local function emit(s, name, ...)
  if s.dead or s ~= sess then return end
  local fn = s.cb[name]
  if fn then
    local ok, err = pcall(fn, ...)
    if not ok then log(s, "callback " .. name .. " en erreur : " .. tostring(err)) end
  end
end

local function status(s, state, info)
  emit(s, "on_status", state, info or {})
end

local function le32(n)
  return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

local function wav_header(data_len)
  return "RIFF" .. le32(36 + data_len) .. "WAVEfmt " .. le32(16)
    .. "\1\0\1\0" .. le32(RATE) .. le32(RATE * 2) .. "\2\0\16\0"
    .. "data" .. le32(data_len)
end

-- Tue pid et tous ses descendants (voice-transcribe -> sous-shell -> whisper-cli). Asynchrone par
-- defaut ; sync = on attend (seulement a la fermeture de nvim, pour ne laisser aucun orphelin).
local KILL_TREE = 'kt() { for c in $(pgrep -P "$1" 2>/dev/null); do kt "$c"; done; kill -TERM "$1" 2>/dev/null; }; kt "$1"'

local function kill_tree(job, sync)
  local ok, pid = pcall(vim.fn.jobpid, job)
  if ok and pid and pid > 0 then
    pcall(function()
      local p = vim.system({ "sh", "-c", KILL_TREE, "sh", tostring(pid) }, {}, function() end)
      if sync then p:wait(2000) end
    end)
  end
  pcall(vim.fn.jobstop, job)
end

---------------------------------------------------------------- transcription

local check_done

local function pending_count(s)
  return #s.queue + (s.running and 1 or 0)
end

local function read_pcm(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*a")
  f:close()
  return d and d:sub(45) or nil
end

local function new_wav_path(s)
  s.seg_n = s.seg_n + 1
  return string.format("%s/seg-%d-%s-%03d.wav", s.dir, vim.fn.getpid(), s.stamp, s.seg_n)
end

-- Coalescence : si au moins 2 morceaux attendent, on fusionne les morceaux CONSECUTIFS
-- (jusqu'a 25 s) en un seul wav : moins d'appels a whisper, meilleure ponctuation.
local function take_batch(s)
  local first = table.remove(s.queue, 1)
  if #s.queue == 0 then return first end
  local batch, total = { first }, first.bytes
  while #s.queue > 0 and total + s.queue[1].bytes <= COALESCE_BYTES do
    local nxt = table.remove(s.queue, 1)
    batch[#batch + 1] = nxt
    total = total + nxt.bytes
  end
  if #batch == 1 then return first end
  local parts = {}
  for _, it in ipairs(batch) do
    local d = read_pcm(it.wav)
    if not d then
      -- lecture impossible : on ne fusionne pas, on remet tout dans l'ordre
      for i = #batch, 2, -1 do table.insert(s.queue, 1, batch[i]) end
      return first
    end
    parts[#parts + 1] = d
  end
  local data = table.concat(parts)
  local wav = new_wav_path(s)
  local f = io.open(wav, "wb")
  if not f then
    for i = #batch, 2, -1 do table.insert(s.queue, 1, batch[i]) end
    return first
  end
  f:write(wav_header(#data), data)
  f:close()
  for _, it in ipairs(batch) do os.remove(it.wav) end
  log(s, string.format("fusion de %d morceaux (%.1f s) -> %s", #batch, #data / (RATE * 2), wav))
  return { wav = wav, bytes = #data, t_end = batch[#batch].t_end }
end

-- ~200 derniers caracteres du texte deja transcrit, coupes sur un espace : contexte de whisper
local function prompt_tail(s)
  local h = s.history
  if h == "" then return "" end
  if #h > PROMPT_CHARS then
    h = h:sub(-PROMPT_CHARS)
    local sp = h:find(" ", 1, true)
    if sp then h = h:sub(sp + 1) end
  end
  return h
end

local function deliver(s, text, info)
  s.delivered = s.delivered + 1
  local ok, e = pcall(function()
    local fn = s.cb.on_segment
    if fn then fn(text, s.delivered, info) end
  end)
  return ok, e
end

local function run_next(s)
  if s.dead or s.running or #s.queue == 0 then return end
  local item = take_batch(s)
  s.running = item
  local out, err = {}, {}
  local timed_out = false
  local timer = uv.new_timer()
  local function finish(code)
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    vim.schedule(function()
      if s.dead then return end
      s.running = nil
      item.job = nil
      local failed
      if timed_out then
        failed = "Transcription trop longue, abandonnee. Audio conserve : " .. item.wav
        log(s, "segment " .. item.wav .. " : timeout")
      elseif code ~= 0 then
        local m = vim.trim(table.concat(err, "\n"))
        failed = "Echec de la transcription (code " .. tostring(code) .. ") " .. m .. " Audio conserve : " .. item.wav
        log(s, "segment " .. item.wav .. " : erreur code " .. tostring(code) .. " " .. m:gsub("\n", " | "))
      end
      if failed then
        status(s, "error", { msg = failed })
        -- le trou est visible dans le texte, a sa place ; le wav est garde
        deliver(s, "[…]", { error = true, wav = item.wav })
      else
        local text = vim.trim(table.concat(out, " "))
        if text == "" then
          os.remove(item.wav)
          log(s, "segment " .. item.wav .. " : pas de parole")
        else
          s.history = vim.trim(s.history .. " " .. text):sub(-2 * PROMPT_CHARS)
          local ok, e = deliver(s, text)
          if ok then
            os.remove(item.wav)
          else
            log(s, "on_segment en erreur : " .. tostring(e))
            status(s, "error", { msg = "Affichage impossible : " .. tostring(e) .. " Audio conserve : " .. item.wav })
          end
          log(s, string.format("segment %d livre : retard %.1f s, %d en attente", s.delivered,
            now_s() - (item.t_end or now_s()), #s.queue))
        end
      end
      if s.stopping then status(s, "finishing", { pending = pending_count(s) }) end
      run_next(s)
      check_done(s)
    end)
  end
  local jopts = {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data) out = data end,
    on_stderr = function(_, data) err = data end,
    on_exit = function(_, code) finish(code) end,
  }
  local prompt = prompt_tail(s)
  if prompt ~= "" then jopts.env = { WHISPER_PROMPT = prompt } end
  local ok, job = pcall(vim.fn.jobstart, { "voice-transcribe", item.wav }, jopts)
  if not ok or job <= 0 then
    err = { "impossible de lancer voice-transcribe : " .. tostring(ok and "code " .. job or job) }
    finish(1)
    return
  end
  item.job = job
  local seconds = math.max(MIN_TIMEOUT_S, TIMEOUT_FACTOR * item.bytes / (RATE * 2))
  timer:start(seconds * 1000, 0, vim.schedule_wrap(function()
    if s.running == item and not s.dead then
      timed_out = true
      kill_tree(job)
    end
  end))
end

local function enqueue(s, data, t_end, speech_ms)
  local wav = new_wav_path(s)
  local f = io.open(wav, "wb")
  if not f then
    status(s, "error", { msg = "Ecriture du segment impossible : " .. wav })
    return
  end
  f:write(wav_header(#data), data)
  f:close()
  log(s, string.format("coupure : segment %d, %.1f s (parole %.1f s) -> %s", s.seg_n, #data / (RATE * 2), speech_ms / 1000, wav))
  s.queue[#s.queue + 1] = { wav = wav, bytes = #data, t_end = t_end }
  run_next(s)
end

---------------------------------------------------------------- segmentation

local function reset_seg(s)
  s.chunks, s.rmss, s.flags, s.ends = {}, {}, {}, {}
  s.speech_ms, s.trail = 0, 0
end

local function recompute(s)
  local sp, trail = 0, 0
  for _, f in ipairs(s.flags) do
    if f then sp = sp + WIN_MS; trail = 0 else trail = trail + 1 end
  end
  s.speech_ms, s.trail = sp, trail
end

-- coupe les n premieres fenetres en un morceau ; le reste devient le debut du suivant (contigu)
local function cut_n(s, n)
  if n <= 0 then return end
  local data = table.concat(s.chunks, "", 1, n)
  local maxrms, last_speech = 0, n
  for i = 1, n do
    if s.rmss[i] > maxrms then maxrms = s.rmss[i] end
  end
  for i = n, 1, -1 do
    if s.flags[i] then last_speech = i; break end
  end
  local t_end = (s.run_t0 or now_s()) + (s.ends[last_speech] or 0) / 1000
  local speech_ms = 0
  for i = 1, n do
    if s.flags[i] then speech_ms = speech_ms + WIN_MS end
  end
  local c, r, f, e = {}, {}, {}, {}
  for i = n + 1, #s.chunks do
    c[#c + 1], r[#r + 1], f[#f + 1], e[#e + 1] = s.chunks[i], s.rmss[i], s.flags[i], s.ends[i]
  end
  s.chunks, s.rmss, s.flags, s.ends = c, r, f, e
  recompute(s)
  if maxrms < ABS_SILENCE then
    log(s, string.format("morceau de %.1f s non envoye : silence numerique", #data / (RATE * 2)))
  elseif #data < MIN_SEG_BYTES then
    log(s, "morceau de moins de 100 ms ignore")
  else
    enqueue(s, data, t_end, speech_ms)
  end
end

local function noise_level(s)
  local h = s.hist
  if #h < NOISE_MIN_WIN then return 0 end
  local tmp = {}
  for i = 1, #h do tmp[i] = h[i] end
  table.sort(tmp)
  return tmp[math.max(1, math.floor(#tmp * 0.2))]
end

local function on_window(s, str, rms, peak)
  local t = now_s()
  -- micro muet / retour du son
  if peak >= MUTE_THRESHOLD then
    s.sound_seen = true
    if s.muted then
      s.muted = false
      status(s, "listening", { elapsed = t - s.t0 })
    end
  end

  -- seuil adaptatif : sert uniquement a choisir ou couper
  local h = s.hist
  h[#h + 1] = rms
  if #h > NOISE_HIST then table.remove(h, 1) end
  local thr = math.max(SPEECH_FLOOR, NOISE_FACTOR * noise_level(s))
  local speech = rms > thr

  local n = #s.chunks + 1
  s.chunks[n], s.rmss[n], s.flags[n] = str, rms, speech
  s.run_ms = s.run_ms + WIN_MS
  s.ends[n] = s.run_ms
  if speech then
    s.speech_ms = s.speech_ms + WIN_MS
    s.trail = 0
  else
    s.trail = s.trail + 1
  end

  local pause_ms = s.trail * WIN_MS
  if (s.speech_ms >= CUT_SPEECH_MS and pause_ms >= CUT_SILENCE_MS)
    or (s.speech_ms >= MIN_SPEECH_MS and pause_ms >= LONG_PAUSE_MS) then
    -- pause : on garde MARGIN_WIN fenetres de silence, le reste ouvre le morceau suivant
    cut_n(s, n - s.trail + MARGIN_WIN)
  elseif n >= MAX_SEGMENT_WIN then
    -- coupure forcee : fenetre la plus calme des 3 dernieres secondes (la plus recente en cas d'egalite)
    local best, best_i = math.huge, n
    for i = n, math.max(1, n - FORCED_LOOKBACK_WIN + 1), -1 do
      if s.rmss[i] < best then best, best_i = s.rmss[i], i end
    end
    log(s, string.format("coupure forcee a 25 s sur la fenetre %d/%d (rms %.4f)", best_i, n, best))
    cut_n(s, best_i)
  end
end

local function process(s, bytes)
  local data = s.rem .. bytes
  local nwin = math.floor(#data / WIN_BYTES)
  for w = 0, nwin - 1 do
    local str = data:sub(w * WIN_BYTES + 1, (w + 1) * WIN_BYTES)
    local p = ffi.cast("const int16_t *", str)
    local sum, peak = 0, 0
    for i = 0, WIN_BYTES / 2 - 1 do
      local v = p[i]
      sum = sum + v * v
      if v < 0 then v = -v end
      if v > peak then peak = v end
    end
    on_window(s, str, math.sqrt(sum / (WIN_BYTES / 2)) / 32768, peak / 32768)
  end
  s.rem = data:sub(nwin * WIN_BYTES + 1)
end

-- ajoute le reste (< 100 ms) au morceau en cours puis coupe tout : rien n'est perdu
local function flush_all(s)
  if #s.rem >= 2 then
    local str = s.rem:sub(1, #s.rem - #s.rem % 2)
    local p = ffi.cast("const int16_t *", str)
    local n, sum = #str / 2, 0
    for i = 0, n - 1 do sum = sum + p[i] * p[i] end
    local k = #s.chunks + 1
    local rms = math.sqrt(sum / n) / 32768
    s.run_ms = s.run_ms + #str / BYTES_PER_MS
    s.chunks[k], s.rmss[k], s.flags[k], s.ends[k] = str, rms, false, s.run_ms
  end
  s.rem = ""
  cut_n(s, #s.chunks)
end

-- lit les octets nouveaux du fichier raw courant
local function drain(s)
  if not s.raw then return end
  if not s.fd then
    local fd = uv.fs_open(s.raw, "r", 438)
    if not fd then return end
    s.fd = fd
    s.offset = 0
  end
  while true do
    local data = uv.fs_read(s.fd, READ_MAX, s.offset)
    if not data or #data == 0 then break end
    local first = s.got_bytes == 0
    s.offset = s.offset + #data
    s.got_bytes = s.got_bytes + #data
    s.last_byte_t = now_s()
    if first then
      s.first_byte_t = s.last_byte_t
      log(s, "premier octet recu")
      if not s.muted then
        s.last_tick_s = s.last_byte_t - s.t0
        status(s, "listening", { elapsed = s.last_byte_t - s.t0 })
      end
    end
    process(s, data)
    if s.got_bytes >= MIN_AUDIO_BYTES then s.fails = {} end
    if #data < READ_MAX then break end
  end
end

local function close_raw(s)
  if s.fd then
    pcall(uv.fs_close, s.fd)
    s.fd = nil
  end
  if s.raw then
    os.remove(s.raw)
    s.raw = nil
  end
end

---------------------------------------------------------------- fin de session

local function cleanup(s)
  s.dead = true
  if s.tick then
    s.tick:stop()
    if not s.tick:is_closing() then s.tick:close() end
    s.tick = nil
  end
  if s.retry then
    s.retry:stop()
    if not s.retry:is_closing() then s.retry:close() end
    s.retry = nil
  end
  close_raw(s)
end

check_done = function(s)
  if s.dead or not s.stopping or not s.flushed then return end
  if pending_count(s) > 0 then return end
  local cb = s.cb.on_done
  log(s, "fin de dictee")
  cleanup(s)
  if sess == s then sess = nil end
  if cb then
    local ok, e = pcall(cb)
    if not ok then notify("on_done en erreur : " .. tostring(e), vim.log.levels.ERROR) end
  end
end

-- arret immediat : session morte (plus de relance, plus de callback), processus tues, fichiers nettoyes
local function abort(s, sync)
  if sess == s then sess = nil end
  s.dead = true
  local running = s.running
  local job = s.job
  s.job = nil
  if job then pcall(vim.fn.jobstop, job) end
  if running and running.job then kill_tree(running.job, sync) end
  if running then os.remove(running.wav) end
  for _, item in ipairs(s.queue) do os.remove(item.wav) end
  s.queue = {}
  cleanup(s)
end

---------------------------------------------------------------- parecord

local spawn

local function on_record_exit(s, job, code)
  vim.schedule(function()
    -- session morte (cancel, fermeture de nvim) : jamais de relance
    if s.dead or s.job ~= job then return end
    s.job = nil
    -- tout ce qui a ete ecrit avant la sortie est lu et coupe
    drain(s)
    flush_all(s)
    local had_audio = s.got_bytes >= MIN_AUDIO_BYTES
    close_raw(s)
    if s.stopping then
      s.flushed = true
      status(s, "finishing", { pending = pending_count(s) })
      check_done(s)
      return
    end
    s.attempt = had_audio and 1 or s.attempt + 1
    -- relances successives sans audio : micro indisponible
    local t = now_s()
    if not had_audio then
      s.fails[#s.fails + 1] = t
      while #s.fails > 0 and t - s.fails[1] > FAIL_WINDOW_S do table.remove(s.fails, 1) end
    end
    if #s.fails > MAX_FAILS then
      log(s, string.format("parecord arrete (code %s) : %d echecs sans audio en %d s, abandon", tostring(code), #s.fails, FAIL_WINDOW_S))
      status(s, "error", { msg = FATAL_MSG, fatal = true })
      s.stopping, s.flushed = true, true
      status(s, "finishing", { pending = pending_count(s) })
      check_done(s)
      return
    end
    local delay = BACKOFF[math.min(s.attempt, #BACKOFF)] or BACKOFF[#BACKOFF]
    log(s, string.format("parecord arrete (code %s), relance %d dans %d ms", tostring(code), s.attempt, delay))
    status(s, "reconnecting", { attempt = s.attempt })
    s.retry = uv.new_timer()
    s.retry:start(delay, 0, vim.schedule_wrap(function()
      if s.retry then
        s.retry:stop()
        if not s.retry:is_closing() then s.retry:close() end
        s.retry = nil
      end
      if s.dead or s.stopping then return end
      local ok = spawn(s)
      if not ok then
        -- lancement impossible : meme traitement qu'une sortie immediate
        s.job = -1
        on_record_exit(s, -1, "lancement")
      end
    end))
  end)
end

spawn = function(s)
  s.run_n = s.run_n + 1
  local raw = string.format("%s/%d-%s%s.raw", s.dir, vim.fn.getpid(), s.stamp, s.run_n > 1 and ("-r" .. s.run_n) or "")
  local opts = {
    on_stderr = function(_, data)
      for _, l in ipairs(data or {}) do
        if l ~= "" then
          local f = io.open(s.dir .. "/voice.log", "a")
          if f then
            f:write(os.date("%Y-%m-%d %H:%M:%S "), "parecord: ", l, "\n")
            f:close()
          end
        end
      end
    end,
  }
  -- Sous WSLg le micro passe par PulseServer ; absent de l'env si nvim n'a pas ete lance depuis zsh.
  -- env = {} est refuse par jobstart (E475) : ne le passer que s'il est non vide.
  if (vim.env.PULSE_SERVER or "") == "" and uv.fs_stat("/mnt/wslg/PulseServer") then
    opts.env = { PULSE_SERVER = "unix:/mnt/wslg/PulseServer" }
  end
  local job_ref
  opts.on_exit = function(_, code) on_record_exit(s, job_ref, code) end
  local ok, job = pcall(vim.fn.jobstart, {
    "parecord", "--raw", "--channels=1", "--rate=16000", "--format=s16le", raw,
  }, opts)
  if not ok or job <= 0 then
    return false, "Impossible de lancer parecord : " .. tostring(ok and "code " .. job or job)
  end
  job_ref = job
  s.job, s.raw, s.fd, s.offset, s.got_bytes = job, raw, nil, 0, 0
  s.run_t0, s.run_ms, s.first_byte_t, s.last_byte_t = now_s(), 0, nil, nil
  log(s, "parecord lance (essai " .. s.run_n .. ") -> " .. raw)
  return true
end

---------------------------------------------------------------- API

function M.is_active()
  return sess ~= nil and not sess.dead
end

-- supprime les restes de plus de 24 h (sessions mortes par crash)
local function purge_stale(dir)
  local limit = os.time() - STALE_S
  for name, ty in vim.fs.dir(dir) do
    if ty == "file" and (name:match("^seg%-.*%.wav$") or name:match("%.raw$")) then
      local st = uv.fs_stat(dir .. "/" .. name)
      if st and st.mtime.sec < limit then os.remove(dir .. "/" .. name) end
    end
  end
end

function M.start(cb)
  if M.is_active() then return false, "Dictee deja active" end
  if vim.fn.executable("parecord") ~= 1 then return false, "parecord introuvable" end
  local dir = dir_path()
  vim.fn.mkdir(dir, "p")
  pcall(purge_stale, dir)
  local s = {
    cb = cb or {}, dir = dir, stamp = os.date("%Y%m%d-%H%M%S"),
    queue = {}, running = nil, delivered = 0, seg_n = 0, run_n = 0, attempt = 0,
    rem = "", hist = {}, history = "", fails = {}, run_ms = 0, got_bytes = 0,
    muted = false, sound_seen = false, stopping = false, flushed = false, dead = false,
    t0 = now_s(), last_tick_s = 0,
  }
  reset_seg(s)
  local st = uv.fs_stat(dir .. "/voice.log")
  if st and st.size > LOG_MAX then os.remove(dir .. "/voice.log") end
  log(s, "debut de dictee")
  local ok, msg = spawn(s)
  if not ok then return false, msg end
  sess = s
  s.tick = uv.new_timer()
  s.tick:start(TICK_MS, TICK_MS, vim.schedule_wrap(function()
    if s.dead then return end
    local okp, e = pcall(drain, s)
    if not okp then log(s, "lecture en erreur : " .. tostring(e)) end
    if s.stopping or s.dead then return end
    local t = now_s()
    -- silence mesure en temps reel : aucun octet pendant 3 s (parecord vivant), ou zeros pendant 3 s
    if s.job and not s.muted then
      local since_bytes = t - (s.last_byte_t or s.run_t0)
      local zeros = s.first_byte_t and not s.sound_seen and t - s.first_byte_t >= MUTE_S
      if since_bytes >= MUTE_S or zeros then
        s.muted = true
        log(s, since_bytes >= MUTE_S and "micro muet (aucun octet pendant 3 s)" or "micro muet (zeros pendant 3 s)")
        s.last_tick_s = t - s.t0
        status(s, "muted", { elapsed = t - s.t0 })
        return
      end
    end
    local el = t - s.t0
    if el - s.last_tick_s >= 1 then
      if s.muted then
        s.last_tick_s = el
        status(s, "muted", { elapsed = el })
      elseif s.got_bytes > 0 then
        -- pas de "listening" tant qu'aucun octet n'est arrive depuis la (re)lance
        s.last_tick_s = el
        status(s, "listening", { elapsed = el })
      end
    end
  end))
  return true
end

function M.stop()
  local s = sess
  if not s or s.dead or s.stopping then return end
  s.stopping = true
  log(s, "stop demande")
  if s.retry then
    s.retry:stop()
    if not s.retry:is_closing() then s.retry:close() end
    s.retry = nil
  end
  if s.job then
    pcall(vim.fn.jobstop, s.job) -- SIGTERM ; la suite se passe dans on_record_exit
  else
    flush_all(s)
    s.flushed = true
    status(s, "finishing", { pending = pending_count(s) })
    check_done(s)
  end
end

function M.cancel()
  local s = sess
  if not s or s.dead then return end
  abort(s, false)
  log(s, "dictee annulee")
end

-- fermeture de nvim : session morte AVANT que les processus ne meurent (donc aucune relance),
-- tout est tue (parecord, voice-transcribe, whisper-cli) et les fichiers sont supprimes.
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("VoiceEngineLeave", { clear = true }),
  callback = function()
    local s = sess
    if s and not s.dead then
      abort(s, true)
      log(s, "nvim ferme : dictee arretee")
    end
  end,
})

return M
