# uni
The Universal Package Manager for GNU/Linux

## Overview
**uni** is a universal package manager designed for GNU/Linux systems. Created by **NEOAPPS**, it allows users to manage custom packages with features like installing, searching, updating, and removing packages, as well as managing repositories.

## Features
- Install and remove packages.
- Search for packages using keywords or tags.
- Add and update repositories.
- Upgrade installed packages to the latest version.
- List installed packages with details.
- Provides helper scripts for adding binaries to the PATH.

## Usage
Run `uni` with the following commands:

### General Commands
- `install` or `-i`: Install a package.
- `remove` or `-R`: Remove a package.
- `search` or `-s`: Search for packages by name or tags.
- `add-repo` or `-AR`: Add a package repository.
- `init-repo`: Initialize the default package repository.
- `update` or `-u`: Update all package repositories.
- `upgrade` or `-U`: Upgrade installed packages to the latest versions.
- `list` or `-l`: Display all installed packages.
- `-howtopath`: Display instructions to add installed binaries to your PATH.

### Help
Run `uni help` or `-h` to see the full list of commands and usage examples.

## Repository Format
Repositories are JSON files with metadata for packages, including:
- Repository URL
- Package name, version, maintainer
- Description, license, dependencies, and tags

## Dependencies
**uni** requires the following tools to function:
- `git`
- `curl`
- `jq`
- `tar`

Ensure these are installed before using **uni**.

## Examples
- Install a package:
  `uni install nano`
- Search for a text editor:
  `uni search text-editor`
- Add a new repository:
  `uni add-repo https://github.com/user/repository.git`
- Upgrade all packages:
  `uni upgrade`
- List installed packages:
  `uni list`

## Contributions
Contributions are welcome. Fork the project and create pull requests to suggest improvements or add new features.

## License
This project is licensed under the GNU GPL-v3 license.
