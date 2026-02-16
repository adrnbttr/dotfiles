return {
  -- Disable blink.cmp and its Copilot integration.
  -- This removes the custom completion engine provided by LazyVim's blink setup.
  -- LSP and other features continue to work; Codeium still provides ghost text.
  {
    "saghen/blink.cmp",
    enabled = false,
  },
  {
    "saghen/blink-cmp-copilot",
    enabled = false,
  },
}
