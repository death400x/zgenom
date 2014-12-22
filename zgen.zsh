autoload -U compinit
compinit

local ZGEN_SOURCE=$(dirname $0)

if [[ -z "${ZGEN_DIR}" ]]; then
    ZGEN_DIR="${HOME}/.zgen"
fi

if [[ -z "${ZGEN_INIT}" ]]; then
    ZGEN_INIT="${ZGEN_DIR}/init.zsh"
fi

if [[ -z "${ZGEN_LOADED}" ]]; then
    ZGEN_LOADED=()
fi

if [[ -z "${ZGEN_COMPLETIONS}" ]]; then
    ZGEN_COMPLETIONS=()
fi

-zgen-get-clone-dir() {
    local repo=${1}
    local branch=${2:-master}

    if [ -d "${repo}/.git" ]; then
        echo "${ZGEN_DIR}/local/$(basename ${repo})-${branch}"
    else
        echo "${ZGEN_DIR}/${repo}-${branch}"
    fi
}

-zgen-get-clone-url() {
    local repo=${1}

    if [ -d "${repo}/.git" ]; then
        echo "${repo}"
    else
        echo "https://github.com/${repo}.git"
    fi
}

-zgen-clone() {
    local repo=${1}
    local dir=${2}
    local branch=${3:-master}
    local url=$(-zgen-get-clone-url "${repo}")

    mkdir -p "${dir}"
    git clone -b "${branch}" "${url}" "${dir}"
    echo
}

-zgen-source() {
    local file="${1}"

    source "${file}"

    # add to the array if not loaded already
    if [[ ! "${ZGEN_LOADED[@]}" =~ ${file} ]]; then
        ZGEN_LOADED+="${file}"
    fi

    completion_path=$(dirname ${file})
    # Add the directory to ZGEN_COMPLETIONS array if not there already
    if [[ ! "${ZGEN_COMPLETIONS[@]}" =~ ${completion_path} ]]; then
        ZGEN_COMPLETIONS+="${completion_path}"
    fi
}

zgen-update() {
    find "${ZGEN_DIR}" -maxdepth 2 -mindepth 2 -type d -exec \
        git --git-dir={}/.git --work-tree={} pull \;

    if [[ -f "${ZGEN_INIT}" ]]; then
        rm "${ZGEN_INIT}"
    fi
}

zgen-save() {
    if [[ -f "${ZGEN_INIT}" ]]; then
        rm "${ZGEN_INIT}"
    fi

    for file in "${ZGEN_LOADED[@]}"; do
        echo "-zgen-source \"$file\"" >> "${ZGEN_INIT}"
    done

    # Set up fpath
    echo "fpath=(\$fpath $ZGEN_COMPLETIONS )" >> "${ZGEN_INIT}"
}

zgen-completions() {
    local repo=${1}
    local branch=${3:-master}
    local dir=$(-zgen-get-clone-dir "${repo}" "${branch}")

    if [[ -z "${2}" ]]; then
        local completion_path="${dir}"
    else
        local completion_path="${dir}/${2}"
    fi

    # clone repo if not present
    if [[ ! -d "${dir}" ]]; then
        -zgen-clone "${repo}" "${dir}" "${branch}"
    fi

    if [[ -d "${completion_path}" ]]; then
        # Add the directory to ZGEN_COMPLETIONS array unless already present
        if [[ ! "${ZGEN_COMPLETIONS[@]}" =~ ${completion_path} ]]; then
            ZGEN_COMPLETIONS+="${completion_path}"
        fi
    else
        if [[ ! -z "${2}" ]]; then
            echo "Could not find ${2} in ${repo}"
        fi
    fi
}

zgen-load() {
    local repo=${1}
    local file=${2}
    local branch=${3:-master}
    local dir=$(-zgen-get-clone-dir "${repo}" "${branch}")
    local location=${dir}/${file}

    # clone repo if not present
    if [[ ! -d "${dir}" ]]; then
        -zgen-clone "${repo}" "${dir}" "${branch}"
    fi

    # source the file
    if [[ -f "${location}" ]]; then
        -zgen-source "${location}"

    # Prezto modules have init.zsh files
    elif [[ -f "${location}/init.zsh" ]]; then
        -zgen-source "${location}/init.zsh"

    elif [[ -f "${location}.zsh-theme" ]]; then
        -zgen-source "${location}.zsh-theme"

    elif [[ -f "${location}.zshplugin" ]]; then
        -zgen-source "${location}.zshplugin"

    elif [[ -f "${location}.zsh.plugin" ]]; then
        -zgen-source "${location}.zsh.plugin"

    # Classic oh-my-zsh plugins have foo.plugin.zsh
    elif ls "${location}" | grep -l "\.plugin\.zsh" &> /dev/null; then
        for script (${location}/*\.plugin\.zsh(N)) -zgen-source "${script}"

    elif ls "${location}" | grep -l "\.zsh" &> /dev/null; then
        for script (${location}/*\.zsh(N)) -zgen-source "${script}"

    elif ls "${location}" | grep -l "\.sh" &> /dev/null; then
        for script (${location}/*\.sh(N)) -zgen-source "${script}"

    else
        echo "zgen: failed to load ${dir}"
    fi
}

zgen-saved() {
    [[ -f "${ZGEN_INIT}" ]] && return 0 || return 1
}

zgen-selfupdate() {
    if [ -d ${ZGEN_SOURCE}/.git ]; then
        pushd ${ZGEN_SOURCE}
        git pull
        popd
    else
        echo "zgen is not running from a git repository, so it is not possible to selfupdate"
        return 1
    fi
}

zgen-oh-my-zsh() {
    local repo="robbyrussell/oh-my-zsh"
    local file="${1:-oh-my-zsh.sh}"

    zgen-load "${repo}" "${file}"
}

zgen() {
    local cmd="${1}"
    if [[ -z "${cmd}" ]]; then
        echo "usage: zgen [completions|load|oh-my-zsh|save|selfupdate|update]"
        return 1
    fi

    shift

    if functions "zgen-${cmd}" > /dev/null ; then
        "zgen-${cmd}" "${@}"
    else
        echo "zgen: command not found: ${cmd}"
    fi
}

_zgen() {
    compadd \
        completions \
        load \
        oh-my-zsh \
        save \
        selfupdate \
        update
}

ZSH=$(-zgen-get-clone-dir "robbyrussell/oh-my-zsh" "master")
if [[ -f "${ZGEN_INIT}" ]]; then
    source "${ZGEN_INIT}"
fi
compdef _zgen zgen
