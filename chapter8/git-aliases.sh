#!/bin/bash
# Git Aliases Setup - Chapter 8 Exercise
# Usage: bash git-aliases.sh
#
# Sets up useful git aliases for sysadmins.
# Run once to configure your ~/.gitconfig with handy shortcuts.

echo "Setting up git aliases..."

# Log visualization
git config --global alias.lg "log --oneline --graph --all --decorate"
git config --global alias.ll "log --pretty=format:'%C(yellow)%h%Creset %s %C(bold blue)<%an>%Creset %C(green)(%cr)%Creset' --abbrev-commit"
git config --global alias.last "log -1 HEAD --stat"

# Status shortcuts
git config --global alias.st "status -sb"
git config --global alias.df "diff"
git config --global alias.dfs "diff --staged"

# Branch shortcuts
git config --global alias.br "branch -av"
git config --global alias.co "switch"
git config --global alias.cb "switch -c"

# Undo shortcuts
git config --global alias.unstage "restore --staged"
git config --global alias.undo "reset --soft HEAD~1"

# Show what I did today
git config --global alias.today "log --since='midnight' --oneline --all --no-merges"

# List files in a commit
git config --global alias.files "diff-tree --no-commit-id --name-only -r"

echo ""
echo "Aliases configured. Try these:"
echo "  git lg     - visual log with graph"
echo "  git st     - short status"
echo "  git df     - diff unstaged changes"
echo "  git dfs    - diff staged changes"
echo "  git br     - all branches"
echo "  git cb name - create and switch to new branch"
echo "  git unstage file - unstage a file"
echo "  git undo   - undo last commit (keep changes)"
echo "  git today  - show today's commits"
echo "  git last   - show last commit details"
echo ""
echo "View all aliases: git config --get-regexp alias"
