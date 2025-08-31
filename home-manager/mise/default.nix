{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  programs.mise = {
    package = pkgs.mise;
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    globalConfig = {
      tools = {
        python = "3.12";
      };
    };
    settings = {
      experimental = true;
      all_compile = false;
      node.compile = false;
      python.compile = false;
    };
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/share/mise/shims"
  ];

  # # For python building
  # home.packages = [
  #   pkgs.gcc
  #   pkgs.gnumake
  #   pkgs.zlib
  #   pkgs.libffi
  #   pkgs.readline
  #   pkgs.bzip2
  #   pkgs.openssl
  #   pkgs.ncurses
  # ];

  home.sessionVariables = {
    MISE_ALL_COMPILE = "false";
    MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS = "python";
    # # For python building
    #   CPPFLAGS="-I${pkgs.zlib.dev}/include -I${pkgs.libffi.dev}/include -I${pkgs.readline.dev}/include -I${pkgs.bzip2.dev}/include -I${pkgs.openssl.dev}/include";
    #   CXXFLAGS="-I${pkgs.zlib.dev}/include -I${pkgs.libffi.dev}/include -I${pkgs.readline.dev}/include -I${pkgs.bzip2.dev}/include -I${pkgs.openssl.dev}/include";
    #   CFLAGS="-I${pkgs.openssl.dev}/include";
    #   LDFLAGS="-L${pkgs.zlib.out}/lib -L${pkgs.libffi.out}/lib -L${pkgs.readline.out}/lib -L${pkgs.bzip2.out}/lib -L${pkgs.openssl.out}/lib";
    #   CONFIGURE_OPTS="-with-openssl=${pkgs.openssl.dev}";
  };
}
