#!/bin/bash

# Uni - The Universal Package Manager for GNU/Linux
# Copyright (C) 2024-present NEOAPPS.
# Licensed under the GPLv3 License. See LICENSE file for details.
# Documentation: https://neoapps.gitbook.io/uni

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

initgit() {
git config --global core.pager ''
git config --global color.ui true
cat > ~/.git-clone-progress.sh << 'EOF'
#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

function progress_bar() {
    local width=50
    local percentage=$1
    local filled=$(printf "%.0f" $(echo "$percentage * $width / 100" | bc -l))
    local empty=$((width - filled))
    
    printf "${BOLD}["
    printf "%${filled}s" | tr ' ' '='
    printf ">"
    printf "%${empty}s" | tr ' ' ' '
    printf "] ${percentage}%%${NC}"
}

start_time=$(date +%s)
total_objects=0
received_objects=0
resolved_deltas=0
last_percentage=0

while IFS= read -r line; do
    printf "\r\033[K"
    
    if [[ $line =~ remote:\ Enumerating\ objects:\ ([0-9]+) ]]; then
        total_objects=${BASH_REMATCH[1]}
        printf "${CYAN}🔍 Discovering repository contents...${NC}\n"
    
    elif [[ $line =~ remote:\ Counting\ objects ]]; then
        printf "${MAGENTA}📊 Analyzing repository structure...${NC}\n"
    
    elif [[ $line =~ Receiving\ objects:\ +([0-9]+)% ]]; then
        percentage=${BASH_REMATCH[1]}
        received_objects=$((total_objects * percentage / 100))
        if [ "$percentage" != "$last_percentage" ]; then
            printf "\r${BLUE}📦 Downloading objects: "
            progress_bar $percentage
            printf " (${received_objects}/${total_objects})${NC}"
            last_percentage=$percentage
        fi
    
    elif [[ $line =~ Resolving\ deltas:\ +([0-9]+)% ]]; then
        percentage=${BASH_REMATCH[1]}
        printf "\r${YELLOW}⚡ Resolving deltas: "
        progress_bar $percentage
        printf "${NC}"
    
    elif [[ $line =~ ^Checking\ out\ files ]]; then
        printf "\n${GREEN}📂 Setting up working directory...${NC}\n"
    
    elif [[ $line =~ ^remote:\ Total\ ([0-9]+)\ \(delta\ ([0-9]+)\) ]]; then
        total_size=${BASH_REMATCH[1]}
        deltas=${BASH_REMATCH[2]}
        printf "${CYAN}📝 Repository size: ${total_size} objects (${deltas} deltas)${NC}\n"
    fi
done

end_time=$(date +%s)
duration=$((end_time - start_time))
printf "\n${BOLD}✨ Downloaded!${NC}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "${BOLD}📊 Statistics:${NC}\n"
printf "   ⏱️  Time taken: %02d:%02d\n" $((duration/60)) $((duration%60))
printf "   📦 Objects processed: %d\n" $total_objects
printf "   🚀 Average speed: %d objects/sec\n" $((total_objects / (duration + 1)))
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
EOF

chmod +x ~/.git-clone-progress.sh
git config --global alias.clone-fancy '!git clone "$1" --progress 2>&1 | ~/.git-clone-progress.sh #'

cat > ~/.git-pull-progress.sh << 'EOF'
#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

function progress_bar() {
    local width=50
    local percentage=$1
    local filled=$(printf "%.0f" $(echo "$percentage * $width / 100" | bc -l))
    local empty=$((width - filled))
    
    printf "${BOLD}["
    printf "%${filled}s" | tr ' ' '='
    printf ">"
    printf "%${empty}s" | tr ' ' ' '
    printf "] ${percentage}%%${NC}"
}

start_time=$(date +%s)
total_objects=0
received_objects=0
resolved_deltas=0
last_percentage=0
files_changed=0
insertions=0
deletions=0
branch_name=""
is_up_to_date=false
while IFS= read -r line; do
    printf "\r\033[K"
    
    if [[ $line =~ "Already up to date." ]]; then
        is_up_to_date=true
        printf "${GREEN}✨ Repository is already up to date!${NC}\n"
        
    elif [[ $line =~ "remote: Enumerating objects: "([0-9]+) ]]; then
        total_objects=${BASH_REMATCH[1]}
        printf "${CYAN}🔍 Checking remote changes...${NC}\n"
    
    elif [[ $line =~ "From " ]]; then
        printf "${MAGENTA}🌐 Connected to remote repository${NC}\n"
    
    elif [[ $line =~ "Updating "([a-f0-9]+)\.\.([a-f0-9]+) ]]; then
        printf "${YELLOW}📥 Pulling changes from ${BOLD}${branch_name}${NC}\n"
    
    elif [[ $line =~ "Receiving objects: "([0-9]+)"%" ]]; then
        percentage=${BASH_REMATCH[1]}
        received_objects=$((total_objects * percentage / 100))
        
        if [ "$percentage" != "$last_percentage" ]; then
            printf "\r${BLUE}📦 Downloading updates: "
            progress_bar $percentage
            printf " (${received_objects}/${total_objects})${NC}"
            last_percentage=$percentage
        fi
    
    elif [[ $line =~ "Resolving deltas: "([0-9]+)"%" ]]; then
        percentage=${BASH_REMATCH[1]}
        printf "\r${YELLOW}⚡ Resolving deltas: "
        progress_bar $percentage
        printf "${NC}"
    
    elif [[ $line =~ "Fast-forward" ]]; then
        printf "\n${GREEN}🚀 Fast-forwarding to latest changes...${NC}\n"
    
    elif [[ $line =~ "files? changed," ]]; then
        [[ $line =~ ([0-9]+)" file"? ]] && files_changed=${BASH_REMATCH[1]}
        [[ $line =~ ([0-9]+)" insertion"? ]] && insertions=${BASH_REMATCH[1]}
        [[ $line =~ ([0-9]+)" deletion"? ]] && deletions=${BASH_REMATCH[1]}
    
    elif [[ $line =~ "current branch "([^[:space:]]+) ]]; then
        branch_name=${BASH_REMATCH[1]}
    fi
done

end_time=$(date +%s)
duration=$((end_time - start_time))
if [ "$is_up_to_date" = false ]; then
    printf "\n${BOLD}✨ Updated!${NC}\n"
    printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BOLD}📊 Statistics:${NC}\n"
    printf "   ⏱️  Time taken: %02d:%02d\n" $((duration/60)) $((duration%60))
    printf "   📂 Files changed: %d\n" $files_changed
    printf "   ✍️  Changes: +%d -%d\n" $insertions $deletions
    if [ $total_objects -gt 0 ]; then
        printf "   📦 Objects processed: %d\n" $total_objects
        printf "   🚀 Average speed: %d objects/sec\n" $((total_objects / (duration + 1)))
    fi
    printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
fi
EOF

chmod +x ~/.git-pull-progress.sh
git config --global alias.pull-fancy '!git pull "$@" --progress 2>&1 | ~/.git-pull-progress.sh #'
}

check_dependencies() {
    local missing=()
    for cmd in git curl jq tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}✗ Missing required dependencies: ${missing[*]}${NC}"
        exit 1
    fi
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}" >&2; }
print_info() { echo -e "${BLUE}ℹ  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠  $1${NC}"; }

# not in use currently
show_spinner() {
    local pid=$1
    local message=$2
    local spin='-\|/'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${message} ${spin:$i:1}"
        sleep .1
    done
    printf "\r"
}

progress_git_clone() {
    initgit;
    local repo="$1"
    local branch="$2"
    local dir="$3"
    git clone --progress --branch "$branch" --single-branch "$repo" "$dir" 2>&1 | ~/.git-clone-progress.sh
    echo
}

extract_progress() {
    local archive="$1"
    local destination="$2"

    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local YELLOW='\033[0;33m'
    local CYAN='\033[0;36m'
    local BOLD='\033[1m'
    local NC='\033[0m'

    printf "${CYAN}📊 Analyzing archive...${NC}\n"
    
    local total_files=$(tar -tzf "$archive" | grep -v '/$' | wc -l)
    local total_size=$(stat -c %s "$archive")
    local total_size_mb=$(printf "%.2f" $(echo "scale=2; $total_size/1048576" | bc))

    printf "${YELLOW}📂 Total files: ${BOLD}${total_files}${NC}\n"
    printf "${YELLOW}💾 Size: ${BOLD}${total_size_mb}MB${NC}\n\n"

    local temp_dir=$(mktemp -d)
    local start_time=$(date +%s)
    (tar xzf "$archive" -C "$destination" --checkpoint=1 \
        --checkpoint-action=exec="echo \$TAR_CHECKPOINT > '${temp_dir}/progress'" 2>/dev/null) &
    local pid=$!
    
    while kill -0 $pid 2>/dev/null; do
        sleep 0.1
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    printf "\n${BOLD}✨ Extraction completed successfully!${NC}\n"
    rm -rf "$temp_dir"

    if (( duration > 0 )); then
        local files_per_sec=$(printf "%.1f" $(echo "scale=1; $total_files/$duration" | bc))
    else
        local files_per_sec=0
    fi
    
    printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BOLD}📊 Statistics:${NC}\n"
    printf "   ⏱️  Time taken: %02d:%02d\n" $((duration/60)) $((duration%60))
    printf "   📂 Files extracted: %d\n" $total_files
    printf "   💾 Total size: %.2fMB\n" $total_size_mb
    printf "   🚀 Average speed: %s files/sec\n" $files_per_sec
    printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

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

download_with_progress() {
    local url="$1"
    local output="$2"
    local temp_file=$(mktemp)
    local total_size=0
    local downloaded=0
    
    total_size=$(curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r')
    [ -z "$total_size" ] && total_size=0
    
    curl -L "$url" -o "$output" 2>"$temp_file" &
    local pid=$!
    
    while kill -0 $pid 2>/dev/null; do
        if [ -f "$output" ]; then
            downloaded=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
            if [ $total_size -gt 0 ]; then
                local percentage=$((downloaded * 100 / total_size))
                printf "\rDownloading: [%-50s] %d%%" "$(printf '#%.0s' $(seq 1 $((percentage / 2))))" "$percentage"
            else
                printf "\rDownloading: %d bytes" "$downloaded"
            fi
        fi
        sleep 0.1
    done
    wait $pid
    rm -f "$temp_file"
    echo
}

install_dependencies() {
    local pkg_metadata="$1"
    local dependencies=($(jq -r '.dependencies[]?' "$pkg_metadata"))
    
    if [ ${#dependencies[@]} -gt 0 ]; then
        print_info "Installing dependencies: ${dependencies[*]}"
        for dep in "${dependencies[@]}"; do
            if ! jq -e ".installed[\"$dep\"]" "${UNI_CONFIG}" >/dev/null; then
                install "$dep"
            fi
        done
    fi
}

install() {
    if [ -z "$1" ]; then
        print_error "Usage: uni install <package-name> [version]"
        exit 1
    fi
    
    local package_name="$1"
    local requested_version="$2"
    local found=false
    
    for repo in "${UNI_REPOS}"/*; do
        if [ -f "${repo}/${package_name}.json" ]; then
            found=true
            local metadata="${repo}/${package_name}.json"
            local package_repo=$(jq -r .repo "$metadata")
            local version=$(jq -r .version "$metadata")
            local maintainer=$(jq -r .maintainer "$metadata")
	    local installer=$(jq -r .installscripturl "$metadata")
            
            if [ ! -z "$requested_version" ]; then
                version="$requested_version"
            fi
            
            print_info "Installing ${BOLD}${package_name}${NC} version ${BOLD}${version}${NC} maintained by ${maintainer}"
            
            install_dependencies "$metadata"
            
            local temp_dir=$(mktemp -d)
            cd "$temp_dir"
            
            print_info "Downloading package..."
	   
            if [ "$installer" != "null" ]; then
		install_via_script $installer;
	    fi

            if ! progress_git_clone "$package_repo" "uni-v${version}" "." 2>/dev/null; then
                print_error "Version ${version} not found"
                rm -rf "$temp_dir"
                exit 1
            fi
            
            if [ ! -f "package.uni" ]; then
                print_error "package.uni not found in repository."
                rm -rf "$temp_dir"
                exit 1
            fi
            
            print_info "Installing..."
            sudo mkdir -p "${UNI_PACKAGES}/${package_name}"
            extract_progress "package.uni" "${UNI_PACKAGES}/${package_name}"
            chmod +x "${UNI_PACKAGES}/${package_name}/${package_name}"
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

install_via_script() {
print_info "This package has an installer script..."
print_info "Installing via the script..."
mkdir -p /uni/temp/
curl $1 -o /uni/temp/script.sh
chmod +x /uni/temp/script.sh
/uni/temp/script.sh
return $?
}

remove() {
    if [ -z "$1" ]; then
        print_error "Usage: uni remove <package-name>"
        exit 1
    fi
    
    local package_name="$1"
    
    if [ -d "${UNI_PACKAGES}/${package_name}" ]; then
        print_info "Removing package ${package_name}..."
        
        sudo rm -f "${UNI_PATH}/${package_name}"
        sudo rm -rf "${UNI_PACKAGES}/${package_name}"
        
        sudo jq "del(.installed[\"$package_name\"])" "${UNI_CONFIG}" > "${UNI_CONFIG}.tmp"
        sudo mv "${UNI_CONFIG}.tmp" "${UNI_CONFIG}"
        
        print_success "Package ${package_name} removed successfully"
    else
        print_error "Package ${package_name} is not installed"
        exit 1
    fi
}

search() {
    if [ -z "$1" ]; then
        print_error "Usage: uni search <package-name/tag>"
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
		    description="${description:0:30}"
                    [ ${#tags} -gt 20 ] && tags_display="${tags_display}..."
                    [ ${#description} -gt 30 ] && description="${description}..."

                    printf "%-20s %-10s %-20s %-30s %-20s\n" \
                        "$name" \
                        "$version" \
                        "$maintainer" \
                        "${description}" \
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
    initgit;
    if [ -z "$1" ]; then
        print_error "Usage: uni add-repo <repository-url>"
        exit 1
    fi
    
    repo_url="$1"
    repo_name=$(basename "$repo_url" .git)
    
    print_info "Adding repository: $repo_name"
    
    if [ -d "${UNI_REPOS}/${repo_name}" ]; then
        print_info "Repository exists, updating..."
        (cd "${UNI_REPOS}/${repo_name}" && git pull | ~/.git-pull-progress.sh)
    else
        print_info "Downloading repository..."
        temp_dir=$(mktemp -d)
        git clone --progress "$repo_url" "$temp_dir" | ~/.git-clone-progress.sh
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

initrepo() {
    print_info "Adding uni-packages to UNI_REPOS..."
    add_repo "https://github.com/neoapps-dev/uni-packages.git"
}

update() {
    initgit;
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
        cd "$repo"
	git pull | ~/.git-pull-progress.sh
    done
    echo
    print_success "All repositories updated successfully"
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

list() {
    echo -e "${BOLD}Installed Packages:${NC}\n"
    printf "${BOLD}%-20s %-10s %-20s %-30s${NC}\n" "NAME" "VERSION" "MAINTAINER" "INSTALLED AT"
    echo "--------------------------------------------------------------------------------"
    
    jq -r '.installed | to_entries | .[] | [.key, .value.version, .value.maintainer, .value.installed_at] | @tsv' "${UNI_CONFIG}" |
        while IFS=$'\t' read -r name version maintainer installed_at; do
            printf "%-20s %-10s %-20s %-30s\n" "$name" "$version" "$maintainer" "$(date -d "@${installed_at%.*}" "+%Y-%m-%d %H:%M:%S")"
        done
}

howtoaddtopath() {
    echo To add every installed uni Package to PATH,
    echo Use this command then restart your shell:
    echo 'echo export PATH=$PATH:/uni/bin/ > ~/.profile'
}

show_help() {
   echo -e "
${BOLD}uni${NC} - Universal Package Manager for GNU/Linux

${BOLD}USAGE:${NC}
    uni <command> [arguments]

${BOLD}COMMANDS:${NC}
    install, --install, -i, -S <package> [version]  Install a package
    remove,  --remove,  -R     <package>    Remove a package
    search,  --search,  -s     <term>       Search for packages
    add-repo,--add-repo,-AR,-a <url>       Add a package repository
    init-repo                              Initializes the uni-packages repo
    -howtopath                             Shows you how to add to PATH
    update,  --update,  -u                 Update all repositories
    upgrade, --upgrade, -U                 Upgrade installed packages
    list,    --list,    -l                 List installed packages
    help,    --help,    -h                 Show this help message

${BOLD}PACKAGE REPOSITORY FORMAT:${NC}
    {
        \"repo\": \"https://github.com/user/package.git\",
        \"name\": \"package-name\",
        \"version\": \"1.0.0\",
        \"maintainer\": \"Your name\",
        \"description\": \"Package description\",
        \"license\": \"MIT\",
        \"dependencies\": [],
        \"tags\": []
    }

${BOLD}EXAMPLES:${NC}
    uni -s dev                  Search for development tools
    uni -i hello-world          Install hello-world
    uni -i hello-world 2.0.1    Install specific version of hello-world
    uni -AR https://repo.git    Add a new package repository
    uni -U                      Check and upgrade packages
    uni -l                      List installed packages

For more information, visit: ${BLUE}https://neoapps.gitbook.io/uni${NC}
" | more
}

check_dependencies
case "$1" in
    "install"|"--install"|"-i"|"-S")
        install "$2" "$3"
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
        update | more
        ;;
    "upgrade"|"--upgrade"|"-U")
        upgrade | more
        ;;
    "list"|"--list"|"-l")
        list | more
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
