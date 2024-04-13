{
  programs.nixvim = {
    globals = {
      mapleader = " ";
      netrw_fastbrowse = 0;
      loaded_ruby_provider = 0;
      loaded_perl_provider = 0;
      loaded_python_provider = 0;
    };

    opts = {
      wildmode = "full";
      inccommand = "split";
      maxmempattern = 20000;
      updatetime = 100;
      number = true;
      relativenumber = true;
      showcmd = false;
      showmode = false;
      emoji = true;
      ambiwidth = "single";
      fileformats = ["unix" "dos" "mac"];
      foldcolumn = "0";
      signcolumn = "yes";
      laststatus = 3;
      showtabline = 2;
      breakindent = true;
    };
  };
}
