![A dark terminal split into four panes using the Darkstar palette: Helix editing a TypeScript file, Lazygit showing a diff, OpenCode's start screen and a zsh prompt with a coloured git log graph](https://henry.catalinismith.se/darkstar/readme/darkstar.webp)

# Darkstar

Deep space colour palette

## Install

### Chrome

Pending review.

### Firefox

Install from [Firefox Add-ons](https://addons.mozilla.org/addon/darkstar-theme/).

### Ghostty

```sh
mkdir -p ~/.config/ghostty/themes
curl -o ~/.config/ghostty/themes/darkstar https://raw.githubusercontent.com/henrycatalinismith/darkstar/main/ghostty/darkstar.toml
curl -o ~/.config/ghostty/themes/lightstar https://raw.githubusercontent.com/henrycatalinismith/darkstar/main/ghostty/lightstar.toml
```

Then in `~/.config/ghostty/config`:

```
theme = light:lightstar,dark:darkstar
```

### Helix

```sh
mkdir -p ~/.config/helix/themes
curl -o ~/.config/helix/themes/darkstar.toml https://raw.githubusercontent.com/henrycatalinismith/darkstar/main/helix/darkstar.toml
curl -o ~/.config/helix/themes/lightstar.toml https://raw.githubusercontent.com/henrycatalinismith/darkstar/main/helix/lightstar.toml
```

Then in `~/.config/helix/config.toml`:

```toml
[theme]
dark = "darkstar"
light = "lightstar"
```

### Lazygit

Copy the contents of
[`lazygit/darkstar.yml`](lazygit/darkstar.yml) into your `config.yml`.

### Neovim

```lua
vim.pack.add({ "https://github.com/henrycatalinismith/darkstar" }, {
  load = function(plugin)
    vim.opt.runtimepath:append(plugin.path .. "/nvim")
  end,
})
vim.cmd.colorscheme("darkstar")
```

### OpenCode

```sh
mkdir -p ~/.config/opencode/themes
curl -o ~/.config/opencode/themes/darkstar.json https://raw.githubusercontent.com/henrycatalinismith/darkstar/main/opencode/darkstar.json
```

Then in `~/.config/opencode/cli.json`:

```json
"theme": { "name": "darkstar", "mode": "system" }
```

### VS Code

Pending review.

### Zed

Pending review.

### Zellij

```sh
mkdir -p ~/.config/zellij/themes
curl -o ~/.config/zellij/themes/darkstar.kdl https://raw.githubusercontent.com/henrycatalinismith/darkstar/main/zellij/darkstar.kdl
curl -o ~/.config/zellij/themes/lightstar.kdl https://raw.githubusercontent.com/henrycatalinismith/darkstar/main/zellij/lightstar.kdl
```

Then in `~/.config/zellij/config.kdl`:

```kdl
theme_dark "darkstar"
theme_light "lightstar"
```

## License

[MIT](license)
