ROOT_DIR := $(shell git rev-parse --show-toplevel)
SHELL := /bin/bash

.PHONY: link neovim asdf bootstrap
link:
	touch ${HOME}/.gitconfig.local
	mkdir -p $(HOME)/.config
	ln -sfn $(ROOT_DIR)/zsh.d $(HOME)/.zsh.d
	ln -sfn $(ROOT_DIR)/zshrc $(HOME)/.zshrc
	ln -sfn $(ROOT_DIR)/zshenv $(HOME)/.zshenv
	ln -sfn $(ROOT_DIR)/tmux.conf $(HOME)/.tmux.conf
	ln -sfn $(ROOT_DIR)/bashrc $(HOME)/.bashrc
	ln -sfn $(ROOT_DIR)/bash_profile $(HOME)/.bash_profile
	ln -sfn $(ROOT_DIR)/dircolors $(HOME)/.dircolors
	ln -sfn $(ROOT_DIR)/nvim $(HOME)/.config/nvim
	ln -sfn $(ROOT_DIR)/ripgrep_ignore $(HOME)/.ripgrep_ignore
	ln -sfn $(ROOT_DIR)/gitconfig $(HOME)/.gitconfig
	ln -sfn $(ROOT_DIR)/gitconfig.d $(HOME)/.gitconfig.d
	ln -sfn $(ROOT_DIR)/bin $(HOME)/.bin

neovim: link
	@./installer/neovim
	nvim --headless -es -u nvim/init.vim -c "PlugInstall" -c "qa"

asdf: link
	@./installer/asdf
	@source $(HOME)/.asdf/asdf.sh && asdf plugin list all >/dev/null 2>&1
	@source $(HOME)/.asdf/asdf.sh && asdf plugin add golang || true
	@source $(HOME)/.asdf/asdf.sh && asdf plugin add kubectl || true
	@source $(HOME)/.asdf/asdf.sh && asdf plugin add kustomize || true
	@source $(HOME)/.asdf/asdf.sh && asdf plugin add helm || true
	@source $(HOME)/.asdf/asdf.sh && asdf plugin add nodejs || true
	@source $(HOME)/.asdf/asdf.sh && asdf plugin add vault || true
	@source $(HOME)/.asdf/asdf.sh && asdf plugin add terraform || true

bootstrap: link
ifeq ($(shell uname), Darwin)
	./bootstrap/darwin
	cat brewfile/darwin/Brewfile-base | brew bundle --file=- --no-lock
else ifndef DEVBOX
	./bootstrap/linux
	cat brewfile/linux/Brewfile-base | brew bundle --file=- --no-lock
endif
