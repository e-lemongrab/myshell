#!/bin/bash
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Set project directory
export project_path="$HOME/Documents/myshell"

# if running bash
if [ -n "$BASH_VERSION" ]; then
	# include .bashrc if it exists
	if [ -f "$project_path/core/shells/bash/.bashrc" ]; then
		. "$project_path/core/shells/bash/.bashrc"
	fi
fi
