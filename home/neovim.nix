{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    initLua = builtins.readFile ../config/nvim/init.lua;
    plugins = with pkgs.vimPlugins; [
      diffview-nvim
      gitsigns-nvim
      neogit
      oil-nvim
      plenary-nvim
      rose-pine
      snacks-nvim
      which-key-nvim
    ];
  };
}
