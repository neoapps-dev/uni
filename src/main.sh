#!/bin/bash

# uni - The Universal Package Manager for GNU/Linux
# Created by NEOAPPS
# License: GNU GPL-v3

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

UNI_ROOT="/uni"
UNI_PACKAGES="${UNI_ROOT}/packages/"
UNI_REPOS="${UNI_ROOT}/repos"
UNI_PATH="${UNI_ROOT}/bin"
UNI_CONFIG="${UNI_ROOT}/config.json"

for dir in "${UNI_PACKAGES}" "${UNI_REPOS}" "${UNI_PATH}"; do
    [ ! -d "$dir" ] && sudo mkdir -p "$dir"
done

[ ! -f "${UNI_CONFIG}" ] && echo '{"repos":[],"installed":{}}' | sudo tee "${UNI_CONFIG}" > /dev/null

check_dependencies() {
    local missing=()
    for cmd in git curl jq tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing[*]}${NC}"
        exit 1
    fi
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}" >&2; }
print_info() { echo -e "${BLUE}ℹ  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠  $1${NC}"; }

show_progress() {
    local current=$1
    local total=$2

    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r$3: ["
    printf "%${filled}s" '' | tr ' ' '='
    printf "%${empty}s" '' | tr ' ' ' '
    printf "] %3d%%" $percentage
}

howtoaddtopath() {
    echo To add every installed uni Package to PATH,
    echo Use this command then restart your shell:
    echo 'echo export PATH=$PATH:/uni/bin/ > ~/.profile'
}

download_with_progress() {
    local url="$1"
    local output="$2"
    curl --progress-bar -L "$url" -o "$output" 2>&1 | stdbuf -o0 tr '\r' '\n' | \
    while IFS= read -r line; do
        if [[ $line =~ [0-9]+\.[0-9]% ]]; then
            percent=${line%\%*}
            show_progress ${percent%.*} 100 "Progress"
        fi
    done
    echo
}

update() {
    print_info "Updating package repositories..."
    local count=0
    local total=$(jq -r '.repos | length' "${UNI_CONFIG}")
    
    if [ $total -eq 0 ]; then
        print_warning "No repositories configured. Add one with 'uni add-repo <url>'"
        return
    fi
    
    for repo in "${UNI_REPOS}"/*; do
            repo_name=$(basename "$repo")
            ((count += 1))
            print_info "[$count/$total] Updating $repo_name"
            cd "$repo" && git pull --quiet
            show_progress $count $total $repo_name
    done
    echo
    print_success "All repositories updated successfully"
}

initrepo() {
    print_info "Adding uni-packages to UNI_REPOS..."
    add_repo "https://github.com/neoapps-dev/uni-packages.git"
}

upgrade() {
    print_info "Checking for package updates..."
    local updates_available=false
    local update_list=()
    
    while IFS= read -r pkg_name; do
        local current_version=$(jq -r ".installed[\"$pkg_name\"].version" "${UNI_CONFIG}")
        for repo in "${UNI_REPOS}"/*; do
            if [ -f "${repo}/${pkg_name}.json" ]; then
                local available_version=$(jq -r .version "${repo}/${pkg_name}.json")
                if [ "$current_version" != "$available_version" ]; then
                    updates_available=true
                    update_list+=("$pkg_name:$current_version:$available_version")
                fi
                break
            fi
        done
    done < <(jq -r '.installed | keys[]' "${UNI_CONFIG}")
    
    if [ "$updates_available" = false ]; then
        print_success "All packages are up to date"
        return
    fi
    
    echo -e "\n${BOLD}Available Updates:${NC}"
    printf "${BOLD}%-20s %-15s %-15s${NC}\n" "PACKAGE" "CURRENT" "AVAILABLE"
    echo "------------------------------------------------"
    for update in "${update_list[@]}"; do
        IFS=':' read -r name current available <<< "$update"
        printf "%-20s %-15s %-15s\n" "$name" "$current" "$available"
    done
    
    echo
    read -p "Do you want to upgrade these packages? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for update in "${update_list[@]}"; do
            IFS=':' read -r name _ _ <<< "$update"
            install "$name"
        done
        print_success "All packages upgraded successfully"
    fi
}

search() {
    if [ -z "$1" ]; then
        print_error "Usage: uni search|--search|-s <package-name/tag>"
        exit 1
    fi
    
    search_term="$1"
    found=false
    
    echo -e "${BOLD}Searching for packages matching '$search_term'...${NC}\n"
    printf "${BOLD}%-20s %-10s %-20s %-30s %-20s${NC}\n" "NAME" "VERSION" "MAINTAINER" "DESCRIPTION" "TAGS"
    echo "------------------------------------------------------------------------------------------------"
    
    for repo in "${UNI_REPOS}"/*; do
        for pkg in "$repo"/*.json; do
            if [ -f "$pkg" ]; then
                name=$(basename "$pkg" .json)
                tags=$(jq -r '.tags | join(", ") // ""' "$pkg")
                
                if [[ "$name" =~ .*"$search_term".* ]] || \
                   [[ "$tags" =~ .*"$search_term".* ]]; then
                    found=true
                    version=$(jq -r '.version // "unknown"' "$pkg")
                    maintainer=$(jq -r '.maintainer // "unknown"' "$pkg")
                    description=$(jq -r '.description // "No description"' "$pkg")
                    tags_display="${tags:0:20}"
                    [ ${#tags} -gt 20 ] && tags_display="${tags_display}..."
                    
                    printf "%-20s %-10s %-20s %-30s %-20s\n" \
                        "$name" \
                        "$version" \
                        "$maintainer" \
                        "${description:0:30}" \
                        "$tags_display"
                fi
            fi
        done
    done
    
    if [ "$found" = false ]; then
        print_warning "No packages found matching '$search_term'"
        print_info "Try searching by package name or tags (e.g., 'editor', 'development', 'cli')"
    fi
}

add_repo() {
    if [ -z "$1" ]; then
        print_error "Usage: uni add-repo|--add-repo|-AR|-a <repository-url>"
        exit 1
    fi
    
    repo_url="$1"
    repo_name=$(basename "$repo_url" .git)
    
    print_info "Adding repository: $repo_name"
    
    if [ -d "${UNI_REPOS}/${repo_name}" ]; then
        print_info "Repository exists, updating..."
        (cd "${UNI_REPOS}/${repo_name}" && git pull --quiet)
    else
        print_info "Downloading repository..."
        temp_dir=$(mktemp -d)
        git clone --quiet "$repo_url" "$temp_dir"
        sudo mv "$temp_dir" "${UNI_REPOS}/${repo_name}"
    fi
    
    if ! jq -e ".repos | contains([\"$repo_url\"])" "${UNI_CONFIG}" > /dev/null; then
        sudo jq --arg repo "$repo_url" '.repos += [$repo]' "${UNI_CONFIG}" > "${UNI_CONFIG}.tmp"
        sudo mv "${UNI_CONFIG}.tmp" "${UNI_CONFIG}"
        print_success "Repository added successfully"
    else
        print_info "Repository already exists"
    fi
}

install() {
    if [ -z "$1" ]; then
        print_error "Usage: uni install|--install|-i|-S <package-name>"
        exit 1
    fi
    
    package_name="$1"
    found=false
    
    for repo in "${UNI_REPOS}"/*; do
        if [ -f "${repo}/${package_name}.json" ]; then
            found=true
            metadata="${repo}/${package_name}.json"
            package_repo=$(jq -r .repo "$metadata")
            version=$(jq -r .version "$metadata")
            maintainer=$(jq -r .maintainer "$metadata")
            
            print_info "Installing ${BOLD}${package_name}${NC} version ${BOLD}${version}${NC} by ${maintainer}"
            
            temp_dir=$(mktemp -d)
            cd "$temp_dir"
            
            print_info "Downloading package..."
            git clone --branch uni-v$version --single-branch --quiet "$package_repo" .
            
            if [ ! -f "package.uni" ]; then
                print_error "package.uni not found in repository"
                rm -rf "$temp_dir"
                exit 1
            fi
            
            print_info "Installing..."
            sudo mkdir -p "${UNI_PACKAGES}/${package_name}"
            sudo tar xzf package.uni -C "${UNI_PACKAGES}/${package_name}" 2>/dev/null
            sudo ln -sf "${UNI_PACKAGES}/${package_name}/${package_name}" "${UNI_PATH}/"
            
            sudo jq --arg name "$package_name" \
                --arg repo "$package_repo" \
                --arg version "$version" \
                --arg maintainer "$maintainer" \
                '.installed[$name] = {
                    "repo": $repo,
                    "version": $version,
                    "maintainer": $maintainer,
                    "installed_at": now
                }' "${UNI_CONFIG}" > "${UNI_CONFIG}.tmp"
            sudo mv "${UNI_CONFIG}.tmp" "${UNI_CONFIG}"
            
            rm -rf "$temp_dir"
            print_success "Package ${package_name} installed successfully"
            break
        fi
    done
    
    if [ "$found" = false ]; then
        print_error "Package ${package_name} not found in any repository"
        exit 1
    fi
}

remove() {
    if [ -z "$1" ]; then
        print_error "Usage: uni remove|--remove|-R <package-name>"
        exit 1
    fi
    
    package_name="$1"
    
    if [ -d "${UNI_PACKAGES}/${package_name}" ]; then
        print_info "Removing package ${package_name}..."
        
        sudo rm -f "${UNI_PATH}"/*
        sudo rm -rf "${UNI_PACKAGES}/${package_name}"
        
        sudo jq "del(.installed[\"$package_name\"])" "${UNI_CONFIG}" > "${UNI_CONFIG}.tmp"
        sudo mv "${UNI_CONFIG}.tmp" "${UNI_CONFIG}"
        
        print_success "Package ${package_name} removed successfully"
    else
        print_error "Package ${package_name} is not installed"
        exit 1
    fi
}

list() {
    echo -e "${BOLD}Installed Packages:${NC}\n"
    printf "${BOLD}%-20s %-10s %-20s %-30s${NC}\n" "NAME" "VERSION" "MAINTAINER" "INSTALLED AT"
    echo "--------------------------------------------------------------------------------"
    
    jq -r '.installed | to_entries | .[] | [.key, .value.version, .value.maintainer, .value.installed_at] | @tsv' "${UNI_CONFIG}" |
        while IFS=$'\t' read -r name version maintainer installed_at; do
            printf "%-20s %-10s %-20s %-30s\n" "$name" "$version" "$maintainer" "$(date -d "@${installed_at%.*}" "+%Y-%m-%d %H:%M:%S")"
        done
}

show_help() {
   echo -e "
${BOLD}uni${NC} - Universal Package Manager for GNU/Linux

${BOLD}USAGE:${NC}
    uni <command> [arguments]

${BOLD}COMMANDS:${NC}
    install, --install, -i, -S <package>    Install a package
    remove,  --remove,  -R     <package>    Remove a package
    search,  --search,  -s     <term>       Search for packages
    add-repo,--add-repo,-AR,-a <url>        Add a package repository
    init-repo                               Initializes the uni-packages repo.
    -howtopath                              Shows you how to add to PATH
    update,  --update,  -u                  Update all repositories
    upgrade, --upgrade, -U                  Upgrade installed packages
    list,    --list,    -l                  List installed packages
    help,    --help,    -h                  Show this help message

${BOLD}PACKAGE REPOSITORY FORMAT:${NC}
    {
        \"repo\": \"https://github.com/user/package.git\",
        \"name\": \"package-name\",
        \"version\": \"1.0.0\",
        \"maintainer\": \"That person\",
        \"description\": \"Package description\",
        \"license\": \"MIT\",
        \"dependencies\": [],
        \"tags\": []
    }

${BOLD}EXAMPLES:${NC}
    uni -s text-editor          Search for text editors
    uni -i nano                 Install nano
    uni -AR https://repo.git    Add a new package repository
    uni -U                      Check and upgrade packages
    uni -l                      List installed packages

For more information, visit: ${BLUE}https://github.com/neoapps-dev/uni${NC}
" | more
}

check_dependencies
case "$1" in
    "install"|"--install"|"-i"|"-S")
        install "$2"
        ;;
    "remove"|"--remove"|"-R")
        remove "$2"
        ;;
    "search"|"--search"|"-s")
        search "$2"
        ;;
    "add-repo"|"--add-repo"|"-AR"|"-a")
        add_repo "$2"
        ;;
    "init-repo"|"-IR")
        initrepo
        ;;
    "-howtopath")
        howtoaddtopath
        ;;
    "update"|"--update"|"-u")
        update
        ;;
    "upgrade"|"--upgrade"|"-U")
        upgrade
        ;;
    "list"|"--list"|"-l")
        list
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        print_info "Run 'uni --help' for usage information"
        exit 1
        ;;
esac
