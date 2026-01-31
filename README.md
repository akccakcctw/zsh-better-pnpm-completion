# zsh-better-pnpm-completion

> Better completion for `pnpm`

This plugin is a fork of [zsh-better-npm-completion](https://github.com/lukechilds/zsh-better-npm-completion). It works the same way, as you can see with `npm` demo:

<img src="demo.gif" width="690">

* Makes `pnpm install` recommendations from pnpm cache
* Makes `pnpm uninstall` recommendations from `dependencies`/`devDependencies`
* Adds workspace package name completion for `--filter`/`-F`
* Shows detailed information on script contents for `pnpm run`
* Falls back to default pnpm completions if we don't have anything better

## Installation

### Using [Antigen](https://github.com/zsh-users/antigen)

Bundle `zsh-better-pnpm-completion` in your `.zshrc`

```shell
antigen bundle akccakcctw/zsh-better-pnpm-completion
```

### Using [zplug](https://github.com/b4b4r07/zplug)
Load `zsh-better-pnpm-completion` as a plugin in your `.zshrc`

```shell
zplug "akccakcctw/zsh-better-pnpm-completion", defer:2

```
### Using [zgen](https://github.com/tarjoilija/zgen)

Include the load command in your `.zshrc`

```shell
zgen load akccakcctw/zsh-better-pnpm-completion
```

### As an [Oh My ZSH!](https://github.com/robbyrussell/oh-my-zsh) custom plugin

Clone `zsh-better-pnpm-completion` into your custom plugins repo

```shell
git clone https://github.com/akccakcctw/zsh-better-pnpm-completion ~/.oh-my-zsh/custom/plugins/zsh-better-pnpm-completion
```
Then load as a plugin in your `.zshrc`

```shell
plugins+=(zsh-better-pnpm-completion)
```

### Manually
Clone this repository somewhere (`~/.zsh-better-pnpm-completion` for example)

```shell
git clone https://github.com/akccakcctw/zsh-better-pnpm-completion.git ~/.zsh-better-pnpm-completion
```
Then source it in your `.zshrc`

```shell
source ~/.zsh-better-pnpm-completion/zsh-better-pnpm-completion.plugin.zsh
```

## Troubleshooting

If pnpm's own completion behaves strangely, ensure you removed older `__tabtab`-based setup from your shell config. pnpm's docs note the v9+ completion isn't compatible with older `__tabtab` initialization.

## License

MIT © RexTsou
