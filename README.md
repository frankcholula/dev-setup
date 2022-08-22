# dev-setup 💻
Setting up dev env for new 🍎 machines. Last updated: **Aug, 2022**.

Obviously, we start out with [`brew`](https://brew.sh/).
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
The rest of the installations are listed in the order of priorities
1. [Shell Setup](#Shell-Setup-)
2. [Python Distribution & Dependency Management](#Python-Distribution--Dependency-Management-)
3. [Infra Tools](#Infra-Tools-)
4. [Miscellaneous](#Miscellaneous-)
## Shell Setup 🐚

I use `zsh` as my default shell and 
* [`ohmyzsh`](https://github.com/ohmyzsh/ohmyzsh/) to manage my zsh configuration.
```bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```
* [`powerlevel10k`](https://github.com/romkatv/powerlevel10k) for my theme
```
brew install romkatv/powerlevel10k/powerlevel10k
echo "source $(brew --prefix)/opt/powerlevel10k/powerlevel10k.zsh-theme" >>~/.zshrc
```
Run `p10k configure` and follow the prompts to finish the setup.

## Python Distribution & Dependency Management 🐍
Use [`pyenv`](https://github.com/pyenv/pyenv) to manage python distibution. Use [`poetry`](https://github.com/python-poetry/poetry) for managing dependencies and projects.
```bash
brew install pyenv
brew install poetry
```
### Pyenv Setup
If the shell envrionment is not properly setup for Pyenv, run the following:
```bash
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
```
Installing a Python distribution and setting a default distribution
```bash
pyenv install 3.9.6
pyenv global 3.9.6
```
If you run into a warining on importing the `lzma` module, run `brew install xz` and reinstall your python distribution with `pyenv`. 

## Infra Tools 🏠

* [awscli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [terraform](https://www.terraform.io/)
* [docker](https://www.docker.com/)
* [kubernetes-cli](https://kubernetes.io/docs/tasks/tools/)
```bash
brew install awscli
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install kubernetes-cli
brew install --cask docker
```
 
### Quality of Life Optional Tools
* [kubie](https://github.com/sbstp/kubie)
* [lens](https://k8slens.dev/)
```bash
brew install kubie
brew install --cask lens
```


## Miscellaneous 🧰
* [homebrew-cask-drivers](https://github.com/Homebrew/homebrew-cask-drivers)
for installing drivers via homebrew
```bash
brew tap homebrew/cask-drivers
```
List of drivers I currently use:
* logitech-options
* displaylink
* obinskit
```bash
brew install logitech-options displaylink obinskit
```

Other cask applications
* Authy
* 1Password
* Spectacle
* Messenger
* Spotify
* Ledger-Live
* chrome-remote-desktop-host
* Grammarly
```bash
brew install --cask authy 1password spectacle messenger spotify ledger-live chrome-remote-desktop-host grammarly
```
## Windows
If you're using WSL, remember to install the extension `Remote - WSL` in order to use tools like `git` natively.