{
  inputs,
  pkgs,
  ...
}: {
  programs.mise = {
    package = pkgs.unstable.mise;
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    globalConfig = {
      tools = {
        go = "1.23.7";
        python = "3.12";
      };
    };
    settings = {
      experimental = true;
    };
  };

  # For python building
  home.packages = [
    pkgs.gcc
    pkgs.gnumake
    pkgs.zlib
    pkgs.libffi
    pkgs.readline
    pkgs.bzip2
    pkgs.openssl
    pkgs.ncurses
  ];

  # For python building
  home.sessionVariables = {
    CPPFLAGS="-I${pkgs.zlib.dev}/include -I${pkgs.libffi.dev}/include -I${pkgs.readline.dev}/include -I${pkgs.bzip2.dev}/include -I${pkgs.openssl.dev}/include";
    CXXFLAGS="-I${pkgs.zlib.dev}/include -I${pkgs.libffi.dev}/include -I${pkgs.readline.dev}/include -I${pkgs.bzip2.dev}/include -I${pkgs.openssl.dev}/include";
    CFLAGS="-I${pkgs.openssl.dev}/include";
    LDFLAGS="-L${pkgs.zlib.out}/lib -L${pkgs.libffi.out}/lib -L${pkgs.readline.out}/lib -L${pkgs.bzip2.out}/lib -L${pkgs.openssl.out}/lib";
    CONFIGURE_OPTS="-with-openssl=${pkgs.openssl.dev}";
  };
}
