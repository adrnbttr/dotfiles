-- Page d'accueil : « HELLO » à la place de « LAZYVIM », même police (ANSI Shadow) et mêmes « Zzz ».
-- Seul l'en-tête change : les raccourcis (keys) du dashboard LazyVim sont conservés.
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}
    opts.dashboard.preset.header = [[
          ██╗  ██╗███████╗██╗     ██╗      ██████╗           Z
          ██║  ██║██╔════╝██║     ██║     ██╔═══██╗      Z    
          ███████║█████╗  ██║     ██║     ██║   ██║   z       
          ██╔══██║██╔══╝  ██║     ██║     ██║   ██║ z         
          ██║  ██║███████╗███████╗███████╗╚██████╔╝           
          ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝ ╚═════╝            
   ]]
  end,
}
