# LLDB Neovim Frontend

This plugin provides LLDB debugger integration for Neovim, featuring:

* Breakpoints and program counter displayed as signs
* Buffers showing backtrace, breakpoints, threads, local variables, registers and disassembly
* Supports almost all LLDB commands from vim-command line (with tab-completion)
* Event-based UI updates
* Non-blocking UI
* Customizable Layout

**NOTE** : This is a fork of https://github.com/gilligan/vim-lldb/, which is a fork of
the plugin that is part of the llvm distribution. The original can be found at
http://llvm.org/svn/llvm-project/lldb/trunk/utils/vim-lldb/

## Prerequisites

* [Neovim](https://github.com/neovim/neovim) with [python support](https://github.com/neovim/python-client).
* [LLDB](http://lldb.llvm.org/)

## Installation

Installation is easiest using a plugin manager such as [vim-plug](https://github.com/junegunn/vim-plug):
```
    Plug "critiqjo/lldb.nvim"
```
Or you can manually copy the files to your `~/.nvimrc` folder if you prefer that for some reason.

Note: After installing (or updating) a plugin that uses Neovim's remote plugin API,
you may have to execute:
```
    :UpdateRemotePlugins
```
which will create a manifest file (`~/.nvim/.nvimrc-rplugin~`) containing some mappings;
then restart Neovim. This might already be taken care of by the plugin manager, but I'm not sure.

## Getting started

Watch a [demo video](https://youtu.be/aXSNhTH1Co4), or refer to the getting
started section in the vim-docs (`:h lldb-start`).

## General Discussion

[![Join the chat at https://gitter.im/critiqjo/lldb.nvim](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/critiqjo/lldb.nvim?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
