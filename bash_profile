if [[ -f ~/.bashrc ]]; then
	. ~/.bashrc
fi

#docs.pkgx.sh/shellcode
if [[ -x "$(command -v pkgx)" ]]; then
  env () {
    unset -f env
    source <(pkgx --shellcode)
    env "$@"
  }
fi

function setup-python() {
  env +python@3.11
}

function setup-go() {
  env +go@1.20
}

function setup-node() {
  env +node@20
}

function setup-rust() {
  env +rust +rustup +cargo
}

function setup-ruby() {
  env +ruby
}

function setup-deno() {
  env +deno.land@1.37.1
}

function setup-devenv() {
  setup-go
  setup-node
  setup-deno
}
