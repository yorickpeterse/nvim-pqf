# Pretty Quickfix windows for NeoVim

nvim-pqf makes your quickfix and location list windows look nicer, thanks to a
combination of a custom `quickfixtextfunc` function and custom syntax rules for
quickfix/location list buffers.

Without nvim-pqf, your quickfix window looks like this:

![Without nvim-pqf](images/before.png)

With nvim-pqf, it looks like this (colours depend on your theme of course);

![With nvim-pqf](images/after.png)

## Requirements

NeoVim 0.5 or newer is required. Regular Vim isn't supported.

## Installation

First install this plugin using your plugin manager of choice. For example, when
using vim-plug use the following:

    Plug 'https://gitlab.com/yorickpeterse/nvim-pqf.git'

Once installed, add the following Lua snippet to your `init.lua`:

    require('pqf').setup()

And that's it!

## Tweaking the highlights

Depending on your theme, you may need to tweak the highlights used by nvim-pqf.
The following highlight groups are defined:

| Group        | Links to          | Use
|:-------------|:------------------|:-----------------------------------
| `qfPath`     | `Directory`       | The file path of a quickfix item
| `qfPosition` | `Number`          | Line and column numbers
| `qfError`    | `DiagnosticError` | The indicator of error items (lines starting with `E`)
| `qfWarning`  | `DiagnosticWarn`  | The indicator of warning items (lines starting with `W`)
| `qfInfo`     | `DiagnosticInfo`  | The indicator of info items (lines starting with `I`)
| `qfHint`     | `DiagnosticHint`  | The indicator of hint items (lines starting with `H`)

## License

All source code in this repository is licensed under the Mozilla Public License
version 2.0, unless stated otherwise. A copy of this license can be found in the
file "LICENSE".
