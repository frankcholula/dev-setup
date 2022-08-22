#!/usr/bin/env zsh

# Exit when a command fails.
set -euo pipefail

########################
# Metadata
########################
LAST_UPDATED="2022-08-21"
# VERSION is the current version of this script. 
# Please MAKE SURE that it's in the form VERSION="<major>.<minor>.<patch>"
VERSION="1.3.10"
VERSION_PATH="$HOME/.dev_setup_version"

BREW_PACKAGES=(pyenv poetry awscli kubernetes-cli kubie)

POSTGRESQL_VERSION=11

########################
# Utils
########################

# ANSI colors
BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
DEFAULT="\033[39m"
RESET="\033[0m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
REVERSED="\033[7m"

# Arguments: ($1: message, $2: color, $3: style)
pp() {
    local message="$1"
    local color="${2:-$DEFAULT}"
    local style="${3:-}"

    echo -e "${color}${style}$message${RESET}"
}

announce() {
    pp "\n========================================================================\n"
    pp "$1" $MAGENTA $BOLD
    pp "\n========================================================================\n"
}

header() {
    pp "\n------------------------------------\n"
    pp "$1" $CYAN $BOLD
    pp "\n------------------------------------\n"
}

step() {
    pp ""
    pp "👉 $1" $CYAN
    pp ""
}

success() {
    pp ""
    pp "✅ $1" $GREEN
}

prompt() {
    pp ""
    pp "$1" $YELLOW $BOLD
    read res
}

error() {
    pp ""
    pp "❌ $1" $RED
    exit 1
}

smart_brew() {
    if brew ls --versions "$1"; then
        brew upgrade "$1"
    else
        brew install "$1"
    fi
}

record_version() {
  echo $VERSION > $VERSION_PATH
}

# create_alias <alias> <command>
create_alias() {
    ALIAS_LINE="alias $1="'"'"$2"'"'
    if ! grep "$ALIAS_LINE" $USER_PROFILE_PATH 2>&1 >/dev/null; then
        echo $ALIAS_LINE >> $USER_PROFILE_PATH
    fi
}

init_bin_install_dir() {
    mkdir -p "$BIN_INSTALL_DIR"
    if ! grep "path+=($BIN_INSTALL_DIR)" ~/.zprofile 2>&1 >/dev/null; then
        if read -q "confirm? -> add $BIN_INSTALL_DIR to path in ~/.zprofile? [y/N] "; then
            echo
            echo "path+=($BIN_INSTALL_DIR)" >> ~/.zprofile
        else
            echo
            echo " -> manually add $BIN_INSTALL_DIR to your shell path to complete unison install"
        fi
    fi
}

# create_link <reference> <link>
create_link() {
    init_bin_install_dir
    pushd "$BIN_INSTALL_DIR" > /dev/null
    ln -sfn $1 $2
    popd > /dev/null
}

########################
# Initialization
########################

init() {
    # Overridable script parameters
    : ${USERNAME:=$(whoami)}
    : ${UNAME_MACHINE:=$(/usr/bin/uname -m)}
    : ${EMAIL_ADDRESS:="$USERNAME@flexport.com"}
    : ${USER_FULL_NAME:=$(finger $USERNAME | egrep -o 'Name: .+' | cut -d ':' -f 2 | xargs echo)}
    : ${FLEXPORT_LOCAL_SOURCE_PATH:=~/flexport}
    : ${BIN_INSTALL_DIR:=~/bin}

    # On ARM macOS, this script installs to /opt/homebrew only
    HB_PARENT_DIR="/opt/homebrew"
    if [[ "$UNAME_MACHINE" != "arm64" ]]; then
        # On Intel macOS, this script installs to /usr/local only
        HB_PARENT_DIR="/usr/local"
    fi
}

check_environment() {
    case $SHELL in
        *"bash") USER_PROFILE_PATH="$(echo ~/.bashrc)" ;;
        *"zsh") USER_PROFILE_PATH="$(echo ~/.zshrc)" ;;
        *) echo "Your shell ($SHELL) is not supported, you're on your own!" ;;
    esac
}

# this will end execution
load_shell() {
    case $SHELL in
        *"bash") bash ;;
        *"zsh") zsh ;;
        *) echo "Your shell ($SHELL) is not supported! Please reload manually." ;;
    esac
}

########################
# Environment Variables
########################

setup_git_config() {
    header "🐙  Setting up your git configs..."

    step "[1/3] Now checking your git config..."
    GIT_USER_NAME=$(git config --global user.name) || true
    echo "Your current git user.name:"
    echo ""
    echo "   $GIT_USER_NAME"

    if [[ "$GIT_USER_NAME" == "" ]]; then
        git config --global user.name "$USER_FULL_NAME"
        echo "git user.name updated to:"
        echo ""
        git config --global user.name
    fi

    GIT_USER_EMAIL=$(git config --global user.email) || true
    echo ""
    echo "Your current git user.email:"
    echo ""
    echo "   $GIT_USER_EMAIL"

    if [[ "$GIT_USER_EMAIL" == "" ]]; then
        git config --global user.email "$EMAIL_ADDRESS"
        echo "git user.email updated to:"
        echo ""
        git config --global user.email
    fi

    step "[2/3] Setting git to default to the current branch name when pushing..."
    git config --global push.default current

    step "[3/3] Checking GITHUB_USERNAME environment variable in $USER_PROFILE_PATH..."
    if grep -q "GITHUB_USERNAME" "$USER_PROFILE_PATH"; then
        echo "GITHUB_USERNAME exists."
    else
        echo "GITHUB_USERNAME is not set, setting to $USERNAME in your $USER_PROFILE_PATH..."
        GITHUB_USERNAME_EXPORT="export GITHUB_USERNAME=$USERNAME"
        echo -e "\n$GITHUB_USERNAME_EXPORT\n" >>$USER_PROFILE_PATH
    fi

    success "Finished setting up git configs!"
}

setup_ssh() {
    header "⚡️ Setting up ssh..."

    # Check if RSA key exists already or if needs to be created.
    RSA_ID_KEY_PATH="$(echo ~/.ssh/id_rsa)"
    RSA_ID_PUBLIC_KEY_PATH="$RSA_ID_KEY_PATH.pub"

    if [ -f $RSA_ID_KEY_PATH ]; then
        echo "Your RSA key already exists at $RSA_ID_KEY_PATH"
    else
        echo "Creating SSH key for $EMAIL_ADDRESS"
        ssh-keygen -t rsa -b 4096 -C "$EMAIL_ADDRESS" -f $RSA_ID_KEY_PATH
        echo "Done!"
        echo ""
    fi

    if  ssh-add -l | grep -q "$(ssh-keygen -lf $RSA_ID_KEY_PATH | awk '{print $2}')"; then
        echo "SSH key already exists in the local keystore.";
    else
        echo "Adding key to local keychain..."
        ssh-add "$RSA_ID_KEY_PATH"
        echo "Done!"
    fi

    echo ""
    echo "Here's your public key:"
    echo ""
    cat "$RSA_ID_PUBLIC_KEY_PATH"
    echo ""

    pbcopy < "$RSA_ID_PUBLIC_KEY_PATH"
    echo "Your public key has also been copied to the clipboard."
    echo ""
    prompt "If not done already, please paste your new public key to GitHub at https://github.flexport.io/settings/keys.\nPlease press ENTER to confirm that your key has been added to continue. "

    success "Finished setting up ssh!"
}

########################
# Common Infra Packages
########################

setup_homebrew() {
    header "🍺 Setting up Homebrew..."

    if command -v brew; then
        echo "Looks like you already have Homebrew installed"
        eval "$(brew shellenv)"
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      INSTALL_DIR="${HB_PARENT_DIR}/bin"
      if read -q "confirm? -> add $INSTALL_DIR to path in ~/.zprofile? [y/N] "; then
          echo 'eval "$('$INSTALL_DIR'/brew shellenv)"' >> ~/.zprofile
      fi
      echo # add trailing newline to read -q / confirm
      eval "$($INSTALL_DIR/brew shellenv)"

      if ! command -v brew >/dev/null; then
          echo "Brew installation failed!"
          exit 1;
      fi
    fi

    step "Running brew doctor..."

    # Temporarily allow exceptions
    set +e
    brew doctor
    set -e

    success "Finished setting up Homebrew!"
}

cleanup_homebrew() {
    header "Brew cleanup to uninstall old or unused packages..."

    # Temporarily allow exceptions
    set +e
    brew cleanup
    set -e
}

install_unison_2_51() {
    if command -v unison-2.51 >/dev/null; then
        echo "Unison-2.51 already installed."
    else
        UNISON_VERSION="unison-v2.51.4+ocaml-4.12.0+x86_64.macos-10.15"
        UNISON_DIR=~/opt/unison/$UNISON_VERSION
        mkdir -p "$UNISON_DIR"
        pushd "$UNISON_DIR" >/dev/null
        if [ ! -f "$UNISON_VERSION.installed.tar.gz" ]; then
            curl -L https://github.com/bcpierce00/unison/releases/download/v2.51.4/$UNISON_VERSION.tar.gz -o $UNISON_VERSION.tar.gz --progress-bar
            tar xzvf $UNISON_VERSION.tar.gz >/dev/null
            mv $UNISON_VERSION.tar.gz $UNISON_VERSION.installed.tar.gz
        fi
        popd > /dev/null

        create_link "$UNISON_DIR/bin/unison" unison-2.51
        create_link "$BIN_INSTALL_DIR/unison-2.51" unison
        echo " -> $($BIN_INSTALL_DIR/unison -version)"
    fi
}

setup_dev() {
    header "💻 Setting up dev tools..."

    step "[1/6] Installing yarn..."

    echo "Checking if yarn is installed already..."
    if command -v yarn >/dev/null; then
        echo "Yarn already installed, upgrading..."
        # Upgrade yarn if needed, otherwise brew doctor will fail.
        brew upgrade yarn
        echo "Yarn upgrade completed."
    else
        echo "Yarn not installed, no need to upgrade now as it will be installed later."
    fi

    step "[2/6] Installing other dependencies ($BREW_PACKAGES)..."

    if command -v kubectl >/dev/null; then
        echo "Kubectl already installed"
    fi
    for package in $BREW_PACKAGES; do
        echo "Installing or upgrading $package"
        smart_brew $package
        echo "Finished installing or upgrading $package"
        if [[ ${package} == *"@"* ]]
        then
            # version pinning requires a link in some cases
            brew link "${package}"
            # have this package first in PATH
            grep -q "${package}" "${USER_PROFILE_PATH}" || \
                echo 'PATH="${HB_PARENT_DIR}/opt/${package}/bin:$PATH"' >> "${USER_PROFILE_PATH}"
        fi
    done

    step "[3/6] Installing postgresql@$POSTGRESQL_VERSION"

    local postgresql_pkg="postgresql@$POSTGRESQL_VERSION"
    echo "Installing or upgrading $postgresql_pkg"
    smart_brew $postgresql_pkg
    if ! command -v postgres >/dev/null 2>&1; then
        brew link $postgresql_pkg
    fi
    echo "Finished installing or upgrading $postgresql_pkg"

    step "[4/6] Installing unison..."
    install_unison_2_51

    step "[5/6] Fixing /usr/local/share/zsh ownership"
    if [[ "$UNAME_MACHINE" == "arm64" ]]; then
        # Likely a Monterey OS+ issue
        echo " (skipping on M1/arm64 installs)"
    else
        # Stop compinit (see man zshcompsys for info) from complaining that the user owns this directory
        # sudo chown -R root:root /usr/local/share/zsh
        ZSH_SHARE_OWNERSHIP="$(ls -lad /usr/local/share/zsh | awk '{print $1}')"
        if [ "$ZSH_SHARE_OWNERSHIP" '==' 'drwxr-xr-x' ]; then
            echo "Ownership of /usr/local/share/zsh is already correct. Skipping"
        else
            sudo chmod -R g-w /usr/local/share/
        fi
    fi

    step "[6/6] Setting up additional 'Aliases'"
    echo "Setting up alias 'k' for 'kubectl'"
    create_alias k kubectl

    success "Finished setting up local dev tools!"
}

setup_aws() {
    header "☁️  Setting up aws cli..."

    if command -v aws >/dev/null 2>&1; then
        echo "AWS CLI already installed. skipping..."
    else
        curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg" --progress-bar
        sudo installer -pkg AWSCLIV2.pkg -target /

        rm "AWSCLIV2.pkg"
    fi

    success "Finished installing remote dev tools!"
}

########################
# Common Dev Packages
########################

rvm_install_fixup() {
      echo " -> Attempting to recover from error during rvm install..."
      pushd "$HOME/.rvm/src/ruby-$1" > /dev/null
      set -e
      make install
      echo " -> rvm install recovery complete!"
      popd > /dev/null
}

setup_rvm() {
    header "💎 Setting up rvm..."

    REQUIRED_RUBY_VERSION="2.7.3"
    RVM_INSTALL_DIR="$HOME/.rvm"
    if [ -d "$RVM_INSTALL_DIR" ]; then
        echo " -> rvm already installed. Skipping."
    else
        curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
        curl -sSL https://get.rvm.io | bash -s stable --auto-dotfiles
    fi

    # we'll need to access rvm functions that require sourcing
    # rvm script does not work w/ -u so temporarily disable
    set +u
    source "$RVM_INSTALL_DIR/scripts/rvm"
    path+=("$RVM_INSTALL_DIR/bin/")

    # Note that if the local .ruby-version points to a version that isn't installed
    # rvm list will actually print out that version to stdout as an error.
    # This can be confusing to our grep test below; adding a trailing \[ seems to
    # limit grep results to the actual installed versions. Brittle.
    if ! (rvm list | grep " ruby-$REQUIRED_RUBY_VERSION \[" > /dev/null); then
      echo " -> Ruby $REQUIRED_RUBY_VERSION not found; installing"
      rvm get master
      if [[ "$UNAME_MACHINE" == "arm64" ]]; then
          eval "$(brew info libffi | grep export)"
          RVM_INSTALL_ARGS="--with-out-ext=fiddle"
      fi
      set +e
      if ! rvm install $REQUIRED_RUBY_VERSION ${RVM_INSTALL_ARGS:-}; then
        # Currently, the rvm install will fail for some reason.
        # We need to go to the source directory, run make install manually
        rvm_install_fixup $REQUIRED_RUBY_VERSION
      fi
      set -e
    else
      echo " -> Ruby $REQUIRED_RUBY_VERSION already installed"
    fi
    if ! (rvm list | grep '* ruby-'$REQUIRED_RUBY_VERSION > /dev/null); then
      if read -q "confirm? -> configure ruby-$REQUIRED_RUBY_VERSION as default? [y/N] "; then
        echo
        rvm use $REQUIRED_RUBY_VERSION --default
      fi
      echo
    fi
    set -u
    success "Finished setting up rvm!"
}

########################
# Github
########################

setup_repo() {
    header "🥚 Setting up your github flexport repo..."

    if [ -d "$FLEXPORT_LOCAL_SOURCE_PATH" ]; then
        echo "Looks like the flexport repo is already cloned to $FLEXPORT_LOCAL_SOURCE_PATH"
    else
        echo "Great! Now cloning to $FLEXPORT_LOCAL_SOURCE_PATH"
        echo "Buckle up, this is going to take a while (30+ minutes)..."
        echo ""
        time git clone git@github.flexport.io:flexport/flexport.git "$FLEXPORT_LOCAL_SOURCE_PATH"
        echo ""
        echo "Clone completed!"
    fi

    success "Finished setting up your github flexport repo!"
}

########################
# Github Dependencies
########################

# Switching to the flexport repo directory should cause rvm to automatically switch ruby versions.
# rvm does not work under -u (it has undeclared variables) so we need to disable this temporarily.
go_to_flexport_repo() {
    set +u
    pushd "$FLEXPORT_LOCAL_SOURCE_PATH" > /dev/null
}

return_from_flexport_repo() {
    popd > /dev/null
    set -u
}

setup_repo_deps() {
    header "🐣 Setting up your repo dependencies..."
    go_to_flexport_repo

    echo ""
    echo "Setting up Bundler, and Yarn"

    # Super double check that rvm did actually switch versions correctly...
    monoRubyVersion=$(<.ruby-version)
    currentRubyVersion=$(ruby --version | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
    if [[ "${monoRubyVersion}" != "${currentRubyVersion}" ]]; then
        error "Ruby version mismatched. Found ${currentRubyVersion}; expected ${monoRubyVersion}. Please fix ruby version by 'rvm use ${monoRubyVersion} --default' and try again. You may have to reload your shell to use rvm."
    fi

    echo " -> installing bundler"
    gem install bundler -v '~>2.1.4' # Bundler

    echo " -> installing aws-sdk"
    gem install aws-sdk

    # this will fail when installing with the default system ruby
    echo " -> fixup build configs for ruby gems thin + puma"
    for gem in thin puma; do
        # https://github.com/puma/puma/issues/2304#issuecomment-664448309
        bundle config build.$gem --with-cflags="-Wno-error=implicit-function-declaration"
    done
    echo " -> fixup build config for ruby gem sassc"
    bundle config --local build.sassc --disable-march-tune-native

    echo " -> bundle install"
    bundle install -j4             # Gems
    echo " -> nvm install"
    nvm install                    # Node
    nvm use                        # Use the correct node version
    echo " -> yarn install"
    yarn install                   # Yarn

    return_from_flexport_repo
    success "Finished setting up your repo dependencies!"
}

setup_repo_aliases() {
    header "🐥 Setting up your repo aliases..."

    step "[1/2] Alias mpr, a cli that makes pull requests for your branch"
    create_alias mpr "${FLEXPORT_LOCAL_SOURCE_PATH}/mpr"

    step "[2/2] Install fx, a cli that hosts our custom toolings"
    go_to_flexport_repo
    ./fx/install
    return_from_flexport_repo
    create_alias dev "fx rdev"

    success "Finished setting up your repo aliases!"
}

setup_repo_hooks() {
    header "🐓 Setting up your repo hooks..."
    go_to_flexport_repo
    echo ""
    echo "Installing git hook handlers..."
    ./script/flexport/install_pre_commit_hook.sh
    ./script/flexport/install_auto_add_ticket_to_commit.sh
    ./engines/trucking/script/install_pre_commit_hook.sh
    return_from_flexport_repo

    success "Finished setting up your repo hooks!"
}

setup_repo_start() {
    if ! grep "cd $FLEXPORT_LOCAL_SOURCE_PATH" $USER_PROFILE_PATH 2>&1 >/dev/null; then
        if read -q "confirm? -> Would you like your shell to always start in the flexport repo? [y/N]"; then
            echo
            echo "cd $FLEXPORT_LOCAL_SOURCE_PATH" >> $USER_PROFILE_PATH
            success "You'll start in $FLEXPORT_LOCAL_SOURCE_PATH in new shells!"
        else
          echo
        fi
    fi
}

validate_localhost_entry() {
   if grep -q "127.0.0.1\s\+localhost" /etc/hosts; then
        success "Your /etc/hosts has the entry for '127.0.0.1 localhost'"
    else
        header "⛔️ Warning ⛔️"
        echo "Your /etc/hosts is missing the entry for '127.0.0.1 localhost'"
        echo "This is known to cause issues with development environments"
        echo "Please add the entry for '127.0.0.1 localhost' manually to /etc/hosts before proceeding"
    fi
}

########################
# Run
########################

# Parse args
while getopts ":vh" opt; do
    case $opt in
        v)
            echo "$VERSION"
            exit ;;
        h)
            echo "usage: setup.sh [-h | -v]
            Setup script will prepare/update your local machine with the latest dev tools!"
            exit ;;
    esac
done

# Run initial steps
init $0
check_environment

announce "🚀 Hi $USER_FULL_NAME, Welcome to the Tech Team setup script version $VERSION! (last updated $LAST_UPDATED)"

# Run machine installations
setup_homebrew # should also install git + xcode cli tools
setup_git_config
setup_ssh

# Install infra tools
setup_dev
setup_aws

# Install common tools
setup_repo
setup_repo_deps
setup_repo_aliases
setup_repo_hooks
setup_repo_start

# Cleanup
cleanup_homebrew

validate_localhost_entry

# Exit
announce "🚀 All Done! Happy Making!"
record_version

# Starting a new zsh instance so any exports
# and settings will be immediately usable for the console user.
if read -q "confirm? -> start new shell to update current settings? [y/N]"; then
  load_shell
else
  echo
  echo " -> some shell settings may need refreshing (path, rvm, nvm, brew, etc)"
  echo " -> run 'exec /bin/zsh -l' to reload your shell manually!"
fi