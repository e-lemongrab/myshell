#!/bin/bash
# GitHub token manager for multiple repositories.
#
# Store: ~/.config/gh/repo_tokens  (JSON, chmod 600, never committed)
#   { "active": "<name>",
#     "tokens": [ { "name", "token", "scopes", "account", "created" }, ... ] }
#
# ~/.config/gh/hosts.yml (the only place gh reads) is never edited directly:
# switching goes through `gh auth switch` / `gh auth login --with-token`, and
# git picks it up via `gh auth setup-git` (credential helper reads hosts.yml).
# Everything here needs only gh, jq and curl -- no Python, no PyYAML.
#
# All interactive entry points are defined here and exposed as gh_* aliases
# from core/shells/bash/aliases/.aliases when utils/gh-tokens is enabled.

GH_TOKEN_STORE="${HOME}/.config/gh/repo_tokens"
GH_HOSTS="${HOME}/.config/gh/hosts.yml"
GH_HOST="github.com"

gh_store_ensure() {
	mkdir -p "$(dirname "$GH_TOKEN_STORE")" 2>/dev/null || return 1
	if [ ! -f "$GH_TOKEN_STORE" ]; then
		jq -n '{active:"",tokens:[]}' >"$GH_TOKEN_STORE" || return 1
	fi
	chmod 600 "$GH_TOKEN_STORE" 2>/dev/null
	# Bootstrap: register the token gh currently has active, if not stored.
	local current
	current=$(gh auth token --hostname "$GH_HOST" 2>/dev/null)
	if [ -n "$current" ] && ! jq -e --arg t "$current" '.tokens[] | select(.token==$t)' \
		"$GH_TOKEN_STORE" >/dev/null 2>&1; then
		local user scopes
		user=$(gh_hosts_active_account)
		scopes=$(gh_hosts_scopes_for "$user")
		jq --arg name "${user:-default}" --arg t "$current" \
			--arg s "${scopes:-}" --arg a "${user:-}" --arg d "$(date -Iseconds)" \
			'.tokens += [{name:$name, token:$t, scopes:$s, account:$a, created:$d}]
			 | if .active=="" then .active=$name else . end' \
			"$GH_TOKEN_STORE" >"$GH_TOKEN_STORE.tmp.$$" \
			&& mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
			&& chmod 600 "$GH_TOKEN_STORE"
		printf 'Registered current gh token as "%s" in the store.\n' "${user:-default}"
	fi
}

gh_store_list() {
	jq -r '"\(.active)" as $a | .tokens[]
		| "  \(if .name==$a then "*" else " " end) \(.name)\t\(.account // "?")\t\(.scopes // "")\t\(.created // "")"' \
		"$GH_TOKEN_STORE" 2>/dev/null
}

gh_store_active() {
	jq -r '.active' "$GH_TOKEN_STORE" 2>/dev/null
}

gh_store_find() {
	# $1 = name -> prints token value (empty if missing)
	jq -r --arg n "$1" '.tokens[] | select(.name==$n) | .token' "$GH_TOKEN_STORE" 2>/dev/null
}

gh_api_verify() {
	# $1 = token -> prints "ok <scopes>", returns non-zero on failure
	local token="$1" response
	response=$(curl -fsS --max-time 15 \
		-H "Authorization: Bearer ${token}" \
		https://api.github.com 2>/dev/null) || {
		printf 'API check failed (network or invalid token)\n' >&2
		return 1
	}
	local login scopes
	login=$(jq -r '.login // empty' <<<"$response")
	# scopes arrive in the response headers; refetch headers-only.
	local header_scopes
	header_scopes=$(curl -fsSI --max-time 15 \
		-H "Authorization: Bearer ${token}" https://api.github.com 2>/dev/null \
		| tr -d '\r' | awk 'tolower($1)=="x-oauth-scopes:"{print $2}')
	printf 'ok user=%s scopes=%s\n' "${login:-?}" "${header_scopes:-none}"
}

gh_api_account() {
	# $1 = token -> prints the login (account) for the token, empty on failure
	local token="$1"
	local response
	response=$(curl -fsS --max-time 15 \
		-H "Authorization: Bearer ${token}" \
		https://api.github.com/user 2>/dev/null) || return 0
	jq -r '.login // empty' <<<"$response" 2>/dev/null
}

gh_activate_token() {
	# $1 = token value, $2 = account (optional). Makes that token the active one.
	# hosts.yml is only ever written by gh itself, so its format stays valid.
	local token="$1" account="${2:-}"
	command -v gh >/dev/null 2>&1 || {
		printf 'gh is not installed.\n' >&2
		return 1
	}
	# gh already stores this exact token for that account: a plain switch is enough.
	if [ -n "$account" ] && [ "$(gh_hosts_token_for "$account")" = "$token" ]; then
		gh auth switch --hostname "$GH_HOST" --user "$account" >/dev/null || return 1
		return 0
	fi
	# New or rotated token: hand it to gh, which resolves the account and stores it.
	printf '%s\n' "$token" | gh auth login --hostname "$GH_HOST" --with-token || return 1
	if [ -n "$account" ]; then
		gh auth switch --hostname "$GH_HOST" --user "$account" >/dev/null 2>&1
	fi
	return 0
}

gh_rotate_flow() {
	local name new_token old_token acc
	name=$(gh_store_active)
	if [ -z "$name" ]; then
		name="default"
	fi
	acc=$(jq -r --arg n "$name" '.tokens[] | select(.name==$n) | .account // empty' "$GH_TOKEN_STORE" 2>/dev/null)
	printf 'Rotating token for "%s" (account: %s).\n' "$name" "${acc:-?}"
	printf 'Paste the new GitHub token (ghp_ / gho_ / github_pat_): '
	read -r new_token
	[ -n "$new_token" ] || { printf 'Cancelled.\n'; return 1; }
	printf 'Verifying new token against the GitHub API...\n'
	local new_acc
	new_acc=$(gh_api_account "$new_token")
	if [ -n "$new_acc" ] && [ "$new_acc" != "${acc:-}" ]; then
		printf 'NOTE: new token is for account "%s" (was "%s").\n' "$new_acc" "${acc:-?}"
		acc="$new_acc"
	fi
	if ! gh_api_verify "$new_token"; then
		printf 'New token failed verification, nothing was changed.\n'
		return 1
	fi
	old_token=$(gh_store_find "$name")
	printf 'Activating new token (writing hosts.yml)...\n'
	gh_activate_token "$new_token" "$acc" || { printf 'Activation failed.\n'; return 1; }
	jq --arg n "$name" --arg t "$new_token" --arg a "${acc:-}" --arg d "$(date -Iseconds)" \
		'(.tokens[] | select(.name==$n)) |= (.token=$t | .account=$a | .created=$d) | .active=$n' \
		"$GH_TOKEN_STORE" >"$GH_TOKEN_STORE.tmp.$$" \
		&& mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
		&& chmod 600 "$GH_TOKEN_STORE"
	printf 'Done. The OLD token for "%s" is still valid until you revoke it.\n' "$name"
	if [ -n "$old_token" ]; then
		printf 'Revoke it:  gh_revoke   (or https://github.com/settings/tokens)\n'
	fi
}

gh_create_flow() {
	command -v gh >/dev/null 2>&1 || {
		printf 'gh is not installed.\n' >&2
		return 1
	}
	local name
	printf 'Name for this token (repo or purpose, e.g. myshell / trading / ci): '
	read -r name
	[ -n "$name" ] || { printf 'Cancelled.\n'; return 1; }

	local all_scopes=(repo read:org gist workflow notifications project admin:repo_hook read:packages delete:packages)
	declare -A sel
	sel[repo]=1 sel[read:org]=1 sel[gist]=1   # minimum gh requires

	print_scope_menu() {
		printf 'Scopes (toggle by number, then press Enter when done):\n'
		local k=1
		for s in "${all_scopes[@]}"; do
			printf '  %s) %-18s %s\n' "$k" "$s" "${sel[$s]:+ [x]}"
			k=$((k + 1))
		done
	}
	print_scope_menu

	while :; do
		printf '\nToggle a scope (1-%d) or Enter to finish: ' "${#all_scopes[@]}"
		read -r pick
		[ -z "$pick" ] && break
		if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#all_scopes[@]}" ]; then
			local sc="${all_scopes[$((pick - 1))]}"
			if [ -n "${sel[$sc]:-}" ]; then unset "sel[$sc]"; else sel["$sc"]=1; fi
			printf '\n'
			print_scope_menu
		else
			break
		fi
	done

	local chosen
	chosen=()
	for s in "${all_scopes[@]}"; do [ -n "${sel[$s]:-}" ] && chosen+=("$s"); done
	if [ "${#chosen[@]}" -eq 0 ]; then
		printf 'At least one scope is required.\n'
		return 1
	fi

	printf '\nScopes: %s\n' "${chosen[*]}"
	printf 'This opens a browser to create the token and approve these scopes.\n'
	printf 'Continue? Type YES: '
	read -r confirmation
	[ "$confirmation" = "YES" ] || { printf 'Cancelled.\n'; return 1; }
	gh auth login --hostname "$GH_HOST" --scopes "${chosen[*]}" --web || return 1

	local newtok
	newtok=$(gh auth token --hostname "$GH_HOST" 2>/dev/null)
	[ -n "$newtok" ] || { printf 'Could not read the new token.\n'; return 1; }

	gh_store_ensure || return 1
	local scope_csv date_now account
	scope_csv=$(printf '%s, ' "${chosen[@]}"); scope_csv=${scope_csv%, }
	date_now=$(date -Iseconds)
	account=$(gh_api_account "$newtok")
	[ -n "$account" ] || account="$name"
	local exists
	if jq -e --arg n "$name" '.tokens[] | select(.name==$n)' "$GH_TOKEN_STORE" >/dev/null 2>&1; then
		exists=y
	fi
	if [ "${exists:-n}" = "y" ]; then
		jq --arg n "$name" --arg t "$newtok" --arg s "$scope_csv" --arg a "$account" --arg d "$date_now" \
			'(.tokens[] | select(.name==$n)) |= (.token=$t | .scopes=$s | .account=$a | .created=$d) | .active=$n' \
			"$GH_TOKEN_STORE" >"$GH_TOKEN_STORE.tmp.$$" \
			&& mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
			&& chmod 600 "$GH_TOKEN_STORE"
	else
		jq --arg n "$name" --arg t "$newtok" --arg s "$scope_csv" --arg a "$account" --arg d "$date_now" \
			'.tokens += [{name:$n, token:$t, scopes:$s, account:$a, created:$d}] | .active=$n' \
			"$GH_TOKEN_STORE" >"$GH_TOKEN_STORE.tmp.$$" \
			&& mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
			&& chmod 600 "$GH_TOKEN_STORE"
	fi
	gh_activate_token "$newtok" "$account" 2>/dev/null || true
	printf '\nToken "%s" (account: %s) created, activated and recorded. gh and git now use it.\n' "$name" "$account"
	printf 'Revoke any previous token at https://github.com/settings/tokens when ready.\n'
}

gh_revoke_flow() {
	gh_store_ensure || { printf 'Cannot initialise token store.\n' >&2; return 1; }
	local name
	printf 'Tokens:\n'
	gh_store_list
	printf 'Name to revoke: '
	read -r name
	if [ -z "$(gh_store_find "$name")" ]; then
		printf 'No token named "%s".\n' "$name"
		return 1
	fi
	if [ "$name" = "$(gh_store_active)" ]; then
		printf '\nWARNING: "%s" is the ACTIVE token. gh and git will lose GitHub\n' "$name"
		printf 'access until you activate another token.\n'
		printf 'Type REVOKE to continue: '
	else
		printf 'Type REVOKE to continue: '
	fi
	read -r confirmation
	[ "$confirmation" = "REVOKE" ] || { printf 'Cancelled.\n'; return 1; }

	# Capture the token value for a later liveness check, then remove it.
	local token_value
	token_value=$(gh_store_find "$name")
	jq --arg n "$name" \
		'.tokens -= [.tokens[] | select(.name==$n)]
		 | if .active==$n then .active="" else . end' \
		"$GH_TOKEN_STORE" >"$GH_TOKEN_STORE.tmp.$$" \
		&& mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
		&& chmod 600 "$GH_TOKEN_STORE" \
		&& printf 'Removed "%s" from the store.\n' "$name"

	printf '\nGitHub does not allow revoking classic PATs via API. Revoke it here:\n'
	printf '  https://github.com/settings/tokens\n'
	local opener=""
	command -v xdg-open >/dev/null 2>&1 && opener="xdg-open"
[ -n "$opener" ] && "$opener" "https://github.com/settings/tokens" >/dev/null 2>&1 &
	printf 'After revoking, confirm it is dead:\n'
	printf '  curl -fsS -H "Authorization: Bearer <old-token>" https://api.github.com\n'
	printf '  -> should now return 401\n'
}

gh_hosts_accounts() {
	# Print every account gh knows for the host, one per line
	gh auth status --json hosts 2>/dev/null \
		| jq -r --arg h "$GH_HOST" '.hosts[$h] // [] | .[].login' 2>/dev/null
}

gh_hosts_active_account() {
	# Print the account gh currently has active for the host
	gh auth status --json hosts 2>/dev/null \
		| jq -r --arg h "$GH_HOST" \
			'.hosts[$h] // [] | map(select(.active)) | .[0].login // empty' 2>/dev/null
}

gh_hosts_token_for() {
	# $1 = account -> prints the token gh holds for it (empty if unknown)
	local acct="$1"
	[ -n "$acct" ] || return 0
	gh auth token --hostname "$GH_HOST" --user "$acct" 2>/dev/null
}

gh_hosts_scopes_for() {
	# $1 = account -> prints scopes for that account via gh auth status (no token)
	local acct="$1"
	gh auth status --json hosts 2>/dev/null \
		| jq -r --arg h "$GH_HOST" --arg a "$acct" '
			.hosts[$h] as $arr
			| (if ($arr|type)=="array" then $arr else [$arr] end)
			| map(select(.login==$a))
			| .[0].scopes // empty' 2>/dev/null
}

gh_store_add_account() {
	# $1 = account gh already knows -> copy it into the myshell store (idempotent)
	local acct="$1" tok scopes
	if jq -e --arg n "$acct" '.tokens[] | select(.name==$n)' "$GH_TOKEN_STORE" >/dev/null 2>&1; then
		printf 'Account "%s" is already in the store — not duplicated.\n' "$acct"
		return 0
	fi
	tok=$(gh_hosts_token_for "$acct")
	[ -n "$tok" ] || {
		printf 'Could not read a token for "%s" from gh.\n' "$acct" >&2
		return 1
	}
	scopes=$(gh_hosts_scopes_for "$acct")
	jq --arg n "$acct" --arg t "$tok" --arg s "${scopes:-}" \
		--arg a "$acct" --arg d "$(date -Iseconds)" \
		'.tokens += [{name:$n, token:$t, scopes:$s, account:$a, created:$d}]
		 | if .active=="" then .active=$n else . end' \
		"$GH_TOKEN_STORE" >"$GH_TOKEN_STORE.tmp.$$" \
		&& mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
		&& chmod 600 "$GH_TOKEN_STORE" \
		&& printf 'Registered account "%s" (scopes: %s).\n' "$acct" "${scopes:-?}"
}

gh_register_existing() {
	# Register an account that gh already knows (hosts.yml) into the myshell store.
	gh_store_ensure || { printf 'Cannot initialise token store.\n' >&2; return 1; }
	local accounts
	accounts=$(gh_hosts_accounts)
	if [ -z "$accounts" ]; then
		printf 'No accounts known to gh (hosts file: %s).\n' "$GH_HOSTS"
		printf 'Authenticate one first:  gh auth login   (then retry gh_init)\n'
		return 1
	fi
	printf 'Accounts gh already knows (hosts.yml):\n'
	local n=1 a
	for a in $accounts; do
		local marker=""
		jq -e --arg n "$a" '.tokens[] | select(.name==$n)' "$GH_TOKEN_STORE" >/dev/null 2>&1 \
			&& marker="   (already in store)"
		printf '  %s) %s%s\n' "$n" "$a" "$marker"
		n=$((n + 1))
	done
	printf 'Account to register (1-%d, or "a" for all): ' "$((n - 1))"
	read -r pick
	if [ "$pick" = "a" ] || [ "$pick" = "A" ]; then
		for a in $accounts; do gh_store_add_account "$a"; done
		return 0
	fi
	[[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "$((n - 1))" ] || {
		printf 'Cancelled.\n'; return 0
	}
	# map pick -> account name
	local acct
	acct=$(for a in $accounts; do echo "$a"; done | sed -n "${pick}p")
	gh_store_add_account "$acct"
}

gh_init() {
	printf '=== myshell gh-tokens: init config ===\n'
	command -v gh >/dev/null 2>&1 || {
		printf 'gh CLI not found. Install it first (brew/apt or https://cli.github.com).\n'
		printf 'Then authenticate each account you want managed, and rerun:  gh_init\n'
		return 1
	}
	gh_store_ensure || { printf 'Cannot initialise token store.\n' >&2; return 1; }

	local choice
	while :; do
		printf '\n=== init config ===\n'
		printf ' 1) Register an account gh already knows (bootstrap, e.g. from another PC)\n'
		printf ' 2) Add a NEW account (browser flow, choose scopes)\n'
		printf ' 3) Configure git credential helper (gh auth setup-git)\n'
		printf ' 4) Show status (store + gh auth)\n'
		printf ' 0) Exit\n'
		printf 'Choice: '
		read -r choice
		case "$choice" in
		1) gh_register_existing ;;
		2) gh_create_flow ;;
		3) gh_git_setup ;;
		4)
			printf 'Store: %s\nActive: %s\n' "$GH_TOKEN_STORE" "$(gh_store_active)"
			printf '%s\n' "$(gh_store_list)"
			printf '\n'
			gh auth status
			;;
		0) return 0 ;;
		*) printf 'Invalid choice.\n' ;;
		esac
	done
}

gh_git_setup() {
	command -v gh >/dev/null 2>&1 || {
		printf 'gh is not installed.\n' >&2
		return 1
	}
	printf 'Running "gh auth setup-git" (creates the git credential helper)...\n'
	gh auth setup-git || return 1
	local helper
	helper=$(git config --global --get credential.https://github.com.helper 2>/dev/null)
	if [ -z "$helper" ]; then
		helper=$(git config --global --get credential.helper 2>/dev/null)
	fi
	# gh 2.x registers a "!" helper: !<path>/gh auth git-credential
	if [[ "$helper" == *"gh auth git-credential"* || "$helper" == *gh-credential-gh* ]]; then
		printf 'git credential helper for github.com: %s\n' "$helper"
	else
		printf 'WARN: git credential helper does not reference gh:\n'
		printf '  %s\n' "${helper:-<unset>}"
		printf 'Run manually:  gh auth setup-git\n'
	fi
}

gh_switch_flow() {
	gh_store_ensure || { printf 'Cannot initialise token store.\n' >&2; return 1; }
	printf 'Active: %s\n' "$(gh_store_active)"
	printf 'Tokens in the store:\n'
	gh_store_list
	printf 'Name to activate (blank = keep current): '
	read -r name
	[ -n "$name" ] || { printf 'No change.\n'; return 0; }
	local token_value acc
	token_value=$(gh_store_find "$name")
	acc=$(jq -r --arg n "$name" '.tokens[] | select(.name==$n) | .account // empty' "$GH_TOKEN_STORE" 2>/dev/null)
	[ -n "$acc" ] || acc="$name"
	if [ -z "$token_value" ]; then
		printf 'No token named "%s" in the store.\n' "$name"
		return 1
	fi
	gh_activate_token "$token_value" "$acc" &&
		jq --arg n "$name" '.active=$n' "$GH_TOKEN_STORE" \
			>"$GH_TOKEN_STORE.tmp.$$" && mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
		&& chmod 600 "$GH_TOKEN_STORE" \
		&& printf 'Activated "%s" (account: %s) in hosts.yml — gh and git now use it.\n' "$name" "${acc:-?}"
}

gh_tokens_menu() {
	gh_store_ensure || { printf 'Cannot initialise token store.\n' >&2; return 1; }
	local choice
	while :; do
		printf '\n=== GitHub tokens (store: %s) ===\n' "$GH_TOKEN_STORE"
		printf 'Active: %s\n' "$(gh_store_active)"
		printf '%s\n' "$(gh_store_list)"
		printf '\n 1) Create a new token (browser flow, choose scopes)\n'
		printf ' 2) Import an existing token (paste it)\n'
		printf ' 3) Switch active token\n'
		printf ' 4) Verify a token against the API\n'
		printf ' 5) Rotate active token (new -> verify -> activate -> revoke old)\n'
		printf ' 6) Configure git credential helper (gh auth setup-git)\n'
		printf ' 7) Revoke a token (remove from store + open revocation page)\n'
		printf ' 8) Delete a token entry (store-only, no revocation)\n'
		printf ' 9) Show current gh auth status\n'
		printf ' 10) Init config (new machine: register accounts + setup git)\n'
		printf ' 0) Exit\n'
		printf 'Choice: '
		read -r choice
		case "$choice" in
		1)
			gh_create_flow
			;;
		2)
			local name token scopes account
			printf 'Name for this token (account or purpose): '
			read -r name
			[ -n "$name" ] || continue
			printf 'Token (ghp_ / gho_ / github_pat_): '
			read -r token
			[ -n "$token" ] || continue
			printf 'Scopes (e.g. repo,workflow): '
			read -r scopes
			printf 'Detecting account via the GitHub API...\n'
			account=$(gh_api_account "$token")
			[ -n "$account" ] || account="unknown"
			jq --arg n "$name" --arg t "$token" --arg s "${scopes:-}" --arg a "$account" \
				--arg d "$(date -Iseconds)" \
				'.tokens += [{name:$n, token:$t, scopes:$s, account:$a, created:$d}]
				 | if .active=="" then .active=$n else . end' \
				"$GH_TOKEN_STORE" >"$GH_TOKEN_STORE.tmp.$$" \
				&& mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
				&& chmod 600 "$GH_TOKEN_STORE" \
				&& printf 'Added "%s" (account: %s).\n' "$name" "$account"
			;;
		3)
			local name
			printf 'Token name to activate: '
			read -r name
			local token_value acc
			token_value=$(gh_store_find "$name")
			acc=$(jq -r --arg n "$name" '.tokens[] | select(.name==$n) | .account // empty' "$GH_TOKEN_STORE" 2>/dev/null)
			[ -n "$acc" ] || acc="$name"
			if [ -z "$token_value" ]; then
				printf 'No token named "%s".\n' "$name"
			else
				gh_activate_token "$token_value" "$acc" &&
					jq --arg n "$name" '.active=$n' "$GH_TOKEN_STORE" \
						>"$GH_TOKEN_STORE.tmp.$$" && mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
						&& printf 'Activated "%s" (account: %s) in hosts.yml.\n' "$name" "${acc:-?}"
			fi
			;;
		4)
			local name
			printf 'Token name to verify (blank = active): '
			read -r name
			[ -n "$name" ] || name=$(gh_store_active)
			local tv
			tv=$(gh_store_find "$name")
			[ -n "$tv" ] && gh_api_verify "$tv" || printf 'Token "%s" not found.\n' "$name"
			;;
		5)
			gh_rotate_flow
			;;
		6)
			gh_git_setup
			;;
		7)
			gh_revoke_flow
			;;
		8)
			local name
			printf 'Token name to delete: '
			read -r name
			printf 'Delete "%s"? Type DELETE: ' "$name"
			read -r confirmation
			[ "$confirmation" = "DELETE" ] || { printf 'Cancelled.\n'; continue; }
			jq --arg n "$name" \
				'.tokens -= [.tokens[] | select(.name==$n)]
				 | if .active==$n then .active="" else . end' \
				"$GH_TOKEN_STORE" >"$GH_TOKEN_STORE.tmp.$$" \
				&& mv "$GH_TOKEN_STORE.tmp.$$" "$GH_TOKEN_STORE" \
				&& printf 'Deleted "%s".\n' "$name"
			;;
		9)
			gh auth status
			;;
		10)
			gh_init
			;;
		0)
			return 0
			;;
		*)
			printf 'Invalid choice.\n'
			;;
		esac
	done
}

gh_status_show() {
	printf '=== gh token status ===\n'
	gh_store_ensure || return 1
	printf 'Store:  %s\n' "$GH_TOKEN_STORE"
	printf 'Active: %s\n' "$(gh_store_active)"
	printf '%s\n' "$(gh_store_list)"
	printf '\n'
	gh auth status
}

gh_help_show() {
	printf 'GitHub token management (utils/gh-tokens)\n'
	printf '  gh_tokens   interactive menu: create / import / switch / verify / rotate / delete / git\n'
	printf '  gh_status   show store, active token, and gh auth status\n'
	printf '  gh_create   create a token via the gh browser flow, choosing scopes in a menu\n'
	printf '  gh_revoke   revoke a token: remove it from the store + open the revocation page\n'
	printf '  gh_rotate   guided rotation: paste new -> verify -> activate -> revoke old\n'
	printf '  gh_git      configure git credential helper via "gh auth setup-git"\n'
	printf '  gh_switch   switch the active account/token (which one gh and git use now)\n'
	printf '  gh_init     new-machine setup (menu): register an existing account, add a\n'
	printf '              new one (browser+scopes), setup git, or show status\n'
	printf '  gh_help     this text\n'
	printf '\nStore: %s (chmod 600, never committed)\n' "$GH_TOKEN_STORE"
	printf 'Active token is managed by gh in %s and used by gh and git.\n' "$GH_HOSTS"
}

# --- entry point (invoked via the gh_* aliases) ---
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	case "${1:-menu}" in
	menu) gh_tokens_menu ;;
	status) gh_status_show ;;
	create) gh_create_flow ;;
	switch) gh_switch_flow ;;
	init) gh_init ;;
	revoke) gh_revoke_flow ;;
	rotate) gh_rotate_flow ;;
	git) gh_git_setup ;;
	help) gh_help_show ;;
	*)
		printf 'Unknown command: %s (use menu|status|switch|rotate|git|init|help)\n' "$1" >&2
		exit 1
		;;
	esac
fi
