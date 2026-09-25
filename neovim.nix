{ pkgs, ... }:
let
  nvimTools = with pkgs; [
    tree-sitter gcc                   # treesitter parser builds

    lua-language-server               # core
    nil                               # lang.nix
    pyright ruff                      # lang.python
    vtsls                             # lang.typescript
    vscode-langservers-extracted      # jsonls, html, cssls
    roslyn-ls                  # lang.dotnet (-> roslyn-ls in the Unity step)
    jdt-language-server               # lang.java
    sqls                              # lsp.lua
    marksman                          # lang.markdown
    bash-language-server shellcheck   # util.dot
    yaml-language-server              # lang.yaml

    stylua shfmt nixfmt statix
    prettierd csharpier
    markdownlint-cli2 markdown-toc
    sqlfluff
  ];
in
{
  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "nvim";
      paths = [ pkgs.neovim ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/nvim --suffix PATH : ${pkgs.lib.makeBinPath nvimTools}
      '';
    })
  ];
}
