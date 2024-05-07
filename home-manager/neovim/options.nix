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
      ambiwidth = "single";
      breakindent = true;
      emoji = true;
      fileformats = ["unix" "dos" "mac"];
      foldcolumn = "0";
      inccommand = "split";
      laststatus = 3;
      maxmempattern = 20000;
      number = true;
      relativenumber = true;
      showcmd = false;
      showmode = false;
      showtabline = 2;
      signcolumn = "yes";
      synmaxcol = 320;
      updatetime = 100;
      wildmode = "full";
    };
  };
}
