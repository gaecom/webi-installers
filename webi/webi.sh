#!/bin/bash
set -e
set -u
#set -x

#shellcheck disable=SC2001,SC2155

function __webi_main() {

    export WEBI_TIMESTAMP=$(date +%F_%H-%M-%S)
    export _webi_tmp="${_webi_tmp:-"$(mktemp -d -t webi-"${WEBI_TIMESTAMP}".XXXXXXXX)"}"

    if [ -n "${_WEBI_PARENT:-}" ]; then
        export _WEBI_CHILD=true
    else
        export _WEBI_CHILD=
    fi
    export _WEBI_PARENT=true

    ##
    ## Detect acceptable package formats
    ##

    my_ext=""
    set +e
    # NOTE: the order here is least favorable to most favorable
    if [ -n "$(command -v pkgutil)" ]; then
        my_ext="pkg,$my_ext"
    fi
    # disable this check for the sake of building the macOS installer on Linux
    #if [ -n "$(command -v diskutil)" ]; then
    # note: could also detect via hdiutil
    my_ext="dmg,$my_ext"
    #fi
    if [ -n "$(command -v git)" ]; then
        my_ext="git,$my_ext"
    fi
    if [ -n "$(command -v unxz)" ]; then
        my_ext="xz,$my_ext"
    fi
    if [ -n "$(command -v unzip)" ]; then
        my_ext="zip,$my_ext"
    fi
    # for mac/linux 'exe' refers to the uncompressed binary without extension
    my_ext="exe,$my_ext"
    if [ -n "$(command -v tar)" ]; then
        my_ext="tar,$my_ext"
    fi
    my_ext="$(echo "$my_ext" | sed 's/,$//')" # nix trailing comma
    set -e

    ##
    ## Detect http client
    ##

    set +e
    export WEBI_CURL="$(command -v curl)"
    export WEBI_WGET="$(command -v wget)"
    set -e

    export WEBI_HOST="${WEBI_HOST:-https://webinstall.dev}"
    export WEBI_UA="$(uname -a)"

    function webinstall() {

        my_package="${1:-}"
        if [ -z "$my_package" ]; then
            echo >&2 "Usage: webi <package>@<version> ..."
            echo >&2 "Example: webi node@lts rg"
            exit 1
        fi

        export WEBI_BOOT="$(mktemp -d -t "$my_package-bootstrap.$WEBI_TIMESTAMP.XXXXXXXX")"

        my_installer_url="$WEBI_HOST/api/installers/$my_package.sh?formats=$my_ext"
        set +e
        if [ -n "$WEBI_CURL" ]; then
            curl -fsSL "$my_installer_url" -H "User-Agent: curl $WEBI_UA" \
                -o "$WEBI_BOOT/$my_package-bootstrap.sh"
        else
            wget -q "$my_installer_url" --user-agent="wget $WEBI_UA" \
                -O "$WEBI_BOOT/$my_package-bootstrap.sh"
        fi
        #shellcheck disable=SC2181
        if ! [[ $? -eq 0 ]]; then
            echo >&2 "error fetching '$my_installer_url'"
            exit 1
        fi
        set -e

        { pushd "${WEBI_BOOT}" > /dev/null; } 2>&1
        bash "${my_package}-bootstrap.sh"
        { popd > /dev/null; } 2>&1

        rm -rf "${WEBI_BOOT}"

    }

    show_path_updates() {

        if [[ -z ${_WEBI_CHILD} ]]; then
            if [ -f "$_webi_tmp/.PATH.env" ]; then
                my_paths=$(sort -u < "$_webi_tmp/.PATH.env")
                if [ -n "$my_paths" ]; then
                    echo "IMPORTANT: You must update you PATH to use the installed program(s)"
                    echo ""
                    echo "You can either"
                    echo "A) can CLOSE and REOPEN Terminal or"
                    echo "B) RUN these exports:"
                    echo ""
                    echo "$my_paths"
                    echo ""
                fi
                rm -f "$_webi_tmp/.PATH.env"
            fi
        fi

    }

    function version() {
        my_version=v1.1.15
        printf "\e[31mwebi\e[32m %s\e[0m Copyright 2020+ AJ ONeal\n" "${my_version}"
        printf "    \e[34mhttps://webinstall.dev/webi\e[0m\n"
    }

    # show help if no params given or help flags are used
    function usage() {
        echo ""
        version
        echo ""

        printf "\e[1mSUMMARY\e[0m\n"
        echo "    Webi is the best way to install the modern developer tools you love."
        echo "    It's fast, easy-to-remember, and conflict free."
        echo ""
        printf "\e[1mUSAGE\e[0m\n"
        echo "    webi <thing1>[@version] [thing2] ..."
        echo ""
        printf "\e[1mUNINSTALL\e[0m\n"
        echo "    Almost everything that is installed with webi is scoped to"
        echo "    ~/.local/opt/<thing1>, so you can remove it like so:"
        echo ""
        echo "    rm -rf ~/.local/opt/<thing1>"
        echo "    rm -f ~/.local/bin/<thing1>"
        echo ""
        echo "    Some packages have special uninstall instructions, check"
        echo "    https://webinstall.dev/<thing1> to be sure."
        echo ""
        printf "\e[1mFAQ\e[0m\n"
        printf "    See \e[34mhttps://webinstall.dev/faq\e[0m\n"
        echo ""
        printf "\e[1mALWAYS REMEMBER\e[0m\n"
        echo "    Friends don't let friends use brew for simple, modern tools that don't need it."
        echo "    (and certainly not apt either **shudder**)"
        echo ""
    }

    if [[ $# -eq 0 ]] || [[ $1 =~ ^(-V|--version|version)$ ]]; then
        version
        exit 0
    fi

    if [[ $1 =~ ^(-h|--help|help)$ ]]; then
        usage "$@"
        exit 0
    fi

    for pkgname in "$@"; do
        webinstall "$pkgname"
    done

    show_path_updates

}

__webi_main "$@"
