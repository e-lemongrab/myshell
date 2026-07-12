#!/bin/bash
# myshell - unified framework management (numbered text menu)

myshell() {
    local cmd="${1:-menu}"
    shift 2>/dev/null || true

    # Module state file path
    local _MF
    if [[ -n "${MY_SHELL_ENV_DIR:-}" && "$MY_SHELL_ENV_DIR" != "/" ]]; then
        _MF="$MY_SHELL_ENV_DIR/module_state/enabled.modules"
    else
        _MF="$project_path/.module_state/enabled.modules"
    fi
    mkdir -p "$(dirname "$_MF")" 2>/dev/null || true
    [ -f "$_MF" ] || touch "$_MF"

    # Color helpers
    c_green()    { printf '\033[0;32m%s\033[0m' "$1"; }
    c_red()      { printf '\033[0;31m%s\033[0m' "$1"; }
    c_yellow()   { printf '\033[0;33m%s\033[0m' "$1"; }
    c_blue()     { printf '\033[0;34m%s\033[0m' "$1"; }
    c_cyan()     { printf '\033[0;36m%s\033[0m' "$1"; }
    c_white()    { printf '\033[1;37m%s\033[0m' "$1"; }

    # ── status display (default, vertical) ──

    do_status() {
        local n=0

        echo ""
        c_green "========================================="
        echo ""
        c_white "  myshell Framework Status"
        echo ""
        c_green "========================================="
        echo ""

        # Core files
        c_blue "> CORE FILES"
        echo ""
        [ -f "$project_path/core/shells/bash/.bashrc" ] && { c_green "OK .bashrc"; echo ""; true; }
        [ -f "$project_path/core/shells/bash/.bash_profile" ] && { c_green "OK .bash_profile"; echo ""; true; }

        # Function files
        local func_files="checks colors crlf_to_lf shfmt yamlfmt hadolint myshell shellcheck"
        for f in $func_files; do
            if [ -f "$project_path/core/shells/bash/functions/${f}.bash" ]; then
                ((n++)) || true
                c_green "OK ${f}.bash"; echo ""
            else
                c_red "MISSING ${f}.bash"; echo ""
            fi
        done
        printf "  Total: %d/8 functions\n\n" "$n"

        # Modules
        c_blue "MODULES:"
        echo ""
        if [ -d "$project_path/modules" ]; then
            for ct in "$project_path/modules"/*/; do
                [ -d "$ct" ] || continue
                local cn=0 es=0
                for mp in "$ct"*/; do
                    [ -d "$mp" ] || continue
                    ((cn++)) || true
                    if grep -qxF "$(basename "$mp")" "$_MF" 2>/dev/null; then
                        c_green "  [+] $(basename "$ct")/$(basename "$mp")"; echo ""
                        ((es++)) || true
                    else
                        printf "  [ ] %s/%s\n" "$(basename "$ct")" "$(basename "$mp")"
                    fi
                done
                if [ "$cn" -gt 0 ]; then
                    printf "  Category: %s (%d, %d enabled)\n\n" "$(basename "$ct")" "$cn" "$es"
                else
                    # flat module (no subdirectories): tracked by its own name
                    if grep -qxF "$(basename "$ct")" "$_MF" 2>/dev/null; then
                        c_green "  [+] $(basename "$ct")"; echo ""
                    else
                        printf "  [ ] %s\n" "$(basename "$ct")"
                    fi
                fi
            done
        else
            c_yellow "  (none)"
            echo ""
        fi

        # Profiles
        c_blue "PROFILES:"
        echo ""
        if [ -d "$project_path/core/shells/bash/profiles" ]; then
            for pf in "$project_path/core/shells/bash/profiles"/.*; do
                [ -f "$pf" ] || continue
                local pn
                pn=$(basename "$pf")
                if grep -qxF "$pn" "$_MF" 2>/dev/null; then
                    c_green "  [+] $pn"; echo ""
                else
                    printf "  [ ] %s\n" "$pn"
                fi
            done
        else
            c_yellow "  (none)"
            echo ""
        fi

        # Aliases
        c_blue "> ALIASES"
        echo ""
        local ad="$project_path/core/shells/bash/aliases"
        if [ -d "$ad" ]; then
            local fa=0 ac=0 ec=0 sc2=0
            for af in "$ad"/.*.sh; do
                [ -f "$af" ] || continue
                ((fa++)) || true
                local a e s3
                a=$(grep -c "^alias " "$af" 2>/dev/null) || a=0
                e=$(grep -c "^export " "$af" 2>/dev/null) || e=0
                s3=$(grep -c "^source " "$af" 2>/dev/null) || s3=0
                ac=$((ac + a)) ec=$((ec + e)) sc2=$((sc2 + s3))
            done
            c_green "$fa file(s)"
            echo ""
            c_white "Total: $ac aliases | $ec exports | $sc2 sources"
            echo ""
        else
            c_red "Aliases dir missing"
            echo ""
        fi

        # Project
        c_blue "> PROJECT"
        echo ""
        if command -v git >/dev/null 2>&1 && [ -d "$project_path/.git" ]; then
            local br
            br=$(git branch --show-current 2>/dev/null) || br="?"
            local tg
            tg=$(git describe --tags --always 2>/dev/null) || tg=""
            if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
                c_white " $(basename "$project_path")@$br"
                c_green "(clean)"
                echo " ($tg)"
            else
                c_white " $(basename "$project_path")@$br"
                c_yellow "(dirty)"
                echo " ($tg)"
            fi
        elif [ -n "${project_path:-}" ]; then
            c_cyan "path: $project_path (no .git)"
            echo ""
        fi
        echo ""

        # Docker images
        if command -v docker >/dev/null 2>&1; then
            c_blue "> DOCKER IMAGES"
            echo ""
            local imgs
            imgs=$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | sort -u) || true
            if [ -n "$imgs" ]; then
                while IFS= read -r img; do printf "  %s\n" "$img"; done <<< "$imgs"
            else
                c_yellow "  (none)"
                echo ""
            fi
        fi

        c_green "========================================="
        echo ""
    }

    # ── list module commands (standalone command only) ──

    do_cmds_list() {
        # Commands are the aliases pointing into modules/ (what you actually type)
        local ad="$project_path/core/shells/bash/aliases"
        local found=0 seen=" " af line name rel
        echo ""
        c_blue "MODULE COMMANDS (alias -> module script):"
        echo ""
        for af in "$ad"/.aliases "$ad"/.*.sh; do
            [ -f "$af" ] || continue
            while IFS= read -r line; do
                case "$line" in
                    *"alias "*=*modules/*) ;;
                    *) continue ;;
                esac
                name="${line#*alias }"
                name="${name%%=*}"
                case "$seen" in *" $name "*) continue ;; esac
                seen="$seen$name "
                rel="${line#*modules/}"
                rel="${rel%%\"*}"
                rel="${rel%%\'*}"
                # skip legacy aliases whose module script no longer exists
                [ -f "$project_path/modules/$rel" ] || continue
                printf "  \033[0;32m%-28s\033[0m -> %s\n" "$name" "$rel"
                found=1
            done < "$af"
        done
        [ "$found" -eq 0 ] && { c_yellow "  (none)"; echo ""; }
        echo ""
    }

    # ── manage modules (arrow-key nav, Enter to toggle) ──

    do_manage_modules() {
        local -a names=() statuses=()
        if [ -d "$project_path/modules" ]; then
            for ct in "$project_path/modules"/*/; do
                [ -d "$ct" ] || continue
                local cat_name
                cat_name=$(basename "$ct")
                names+=("$cat_name")
                local total=0 en=0 mp
                for mp in "$ct"*/; do
                    [ -d "$mp" ] || continue; ((total++)) || true
                    grep -qxF "$(basename "$mp")" "$_MF" 2>/dev/null && { ((en++)) || true; }
                done
                if [ "$total" -eq 0 ]; then
                    # flat module (scripts directly inside): track by its own name
                    if grep -qxF "$cat_name" "$_MF" 2>/dev/null; then statuses+=("ON"); else statuses+=("OFF"); fi
                elif [ "$total" -eq "$en" ]; then statuses+=("ON"); else statuses+=("OFF"); fi
            done
        fi

        if [ "${#names[@]}" -eq 0 ]; then c_yellow "  (none)"; echo ""; return; fi

        local sel=0 ch="" ch2="" first=1
        local lines=$(( ${#names[@]} + 5 ))

        while true; do
            # Redraw in place (skip cursor-up on the first draw)
            if [ "$first" -eq 1 ]; then first=0; else printf '\033[%dA\033[J' "$lines"; fi
            echo ""
            c_blue "MODULES (arrows navigate, Enter/T toggle, E enable, D disable, Q back):"
            echo ""
            for ((i=0; i < ${#names[@]}; i++)); do
                if [ "$i" -eq "$sel" ]; then
                    printf '  \033[0;32m> [%-3s] %s\033[0m\n' "${statuses[$i]}" "${names[$i]}"
                else
                    printf "    [%-3s] %s\n" "${statuses[$i]}" "${names[$i]}"
                fi
            done
            echo ""
            printf "  q) Back to menu\n"

            # Get single keystroke (silent, unbuffered)
            IFS= read -rsn1 ch || { echo ""; return 0; }

            # Handle ESC sequences for arrow keys (bare ESC = back)
            if [[ "$ch" == $'\x1b' ]]; then
                ch2=""
                IFS= read -rsn2 -t 0.05 ch2 || true
                [ -z "$ch2" ] && { echo ""; return 0; }
                case "${ch2:1:1}" in
                    A|H) [ "$sel" -gt 0 ] && ((sel--)) || true ;;
                    B|F) [ "$sel" -lt $(( ${#names[@]} - 1 )) ] && ((sel++)) || true ;;
                esac
                continue
            fi

            case "$ch" in
                ""|t|T)  # Enter or T toggles the whole category
                    if [ "${statuses[$sel]}" = "ON" ]; then
                        _cat_disable "${names[$sel]}"; statuses[$sel]="OFF"
                    else
                        _cat_enable "${names[$sel]}"; statuses[$sel]="ON"
                    fi ;;
                e|E) _cat_enable  "${names[$sel]}"; statuses[$sel]="ON" ;;
                d|D) _cat_disable "${names[$sel]}"; statuses[$sel]="OFF" ;;
                q|Q|@) echo ""; return 0 ;;
            esac
        done
    }

    # ── category helpers: act on every module inside a category ──

    _cat_enable() {
        local mp found=0
        for mp in "$project_path/modules/$1"/*/; do
            [ -d "$mp" ] || continue
            found=1
            _mod_enable "$(basename "$mp")" >/dev/null
        done
        # flat module: no subdirectories, track by its own name
        [ "$found" -eq 0 ] && _mod_enable "$1" >/dev/null
    }

    _cat_disable() {
        local mp found=0
        for mp in "$project_path/modules/$1"/*/; do
            [ -d "$mp" ] || continue
            found=1
            _mod_disable "$(basename "$mp")" >/dev/null
        done
        [ "$found" -eq 0 ] && _mod_disable "$1" >/dev/null
    }

    # ── manage profiles (arrow-key nav, Enter to toggle) ──

    do_manage_profiles() {
        local -a names=() statuses=()

        if [ -d "$project_path/core/shells/bash/profiles" ]; then
            for pf in "$project_path/core/shells/bash/profiles"/.*; do
                [ -f "$pf" ] || continue
                local prof_name
                prof_name=$(basename "$pf")
                names+=("$prof_name")
                grep -qxF "$prof_name" "$_MF" 2>/dev/null && statuses+=("ON") || statuses+=("OFF")
            done
        fi

        if [ "${#names[@]}" -eq 0 ]; then c_yellow "  (none)"; echo ""; return; fi

        local sel=0 ch="" ch2="" first=1
        local lines=$(( ${#names[@]} + 5 ))

        while true; do
            if [ "$first" -eq 1 ]; then first=0; else printf '\033[%dA\033[J' "$lines"; fi
            echo ""
            c_blue "PROFILES (arrows navigate, Enter/T toggle, E enable, D disable, Q back):"
            echo ""
            for ((i=0; i < ${#names[@]}; i++)); do
                if [ "$i" -eq "$sel" ]; then
                    printf '  \033[0;32m> [%-3s] %s\033[0m\n' "${statuses[$i]}" "${names[$i]}"
                else
                    printf "    [%-3s] %s\n" "${statuses[$i]}" "${names[$i]}"
                fi
            done
            echo ""
            printf "  q) Back to menu\n"

            IFS= read -rsn1 ch || { echo ""; return 0; }

            # Handle ESC sequences for arrow keys (bare ESC = back)
            if [[ "$ch" == $'\x1b' ]]; then
                ch2=""
                IFS= read -rsn2 -t 0.05 ch2 || true
                [ -z "$ch2" ] && { echo ""; return 0; }
                case "${ch2:1:1}" in
                    A|H) [ "$sel" -gt 0 ] && ((sel--)) || true ;;
                    B|F) [ "$sel" -lt $(( ${#names[@]} - 1 )) ] && ((sel++)) || true ;;
                esac
                continue
            fi

            case "$ch" in
                ""|t|T)  # Enter or T toggles the profile
                    if [ "${statuses[$sel]}" = "ON" ]; then
                        _mod_disable "${names[$sel]}" >/dev/null; statuses[$sel]="OFF"
                    else
                        _mod_enable "${names[$sel]}" >/dev/null; statuses[$sel]="ON"
                    fi ;;
                e|E) _mod_enable  "${names[$sel]}" >/dev/null; statuses[$sel]="ON" ;;
                d|D) _mod_disable "${names[$sel]}" >/dev/null; statuses[$sel]="OFF" ;;
                q|Q|@) echo ""; return 0 ;;
            esac
        done
    }

    # ── enable helper ──

    _mod_enable() {
        local name="$1"
        [ -z "$name" ] && { c_red "Usage: myshell enable <name>"; echo ""; return 1; }
        grep -qxF "$name" "$_MF" 2>/dev/null && { c_yellow "'$name' already enabled"; echo ""; return 0; }
        printf '%s\n' "$name" >> "$_MF" || true
        c_green "Enabled: $name"
        echo ""
    }

    # ── disable helper ──

    _mod_disable() {
        local name="$1"
        [ -z "$name" ] && { c_red "Usage: myshell enable <name>"; echo ""; return 1; }
        grep -qxF "$name" "$_MF" 2>/dev/null || { c_yellow "'$name' not enabled"; echo ""; return 0; }
        local tmp="${_MF}.tmp_$$" rc=0
        grep -vxF "$name" "$_MF" > "$tmp" 2>/dev/null || rc=$?
        # grep exits 1 when no lines remain (removed the last entry) - still success
        if [ "$rc" -le 1 ] && mv "$tmp" "$_MF" 2>/dev/null; then
            c_red "Disabled: $name"
            echo ""
        else
            rm -f "$tmp" 2>/dev/null
            c_red "Failed to update $_MF"
            echo ""
            return 1
        fi
    }

    # ── interactive menu (numbers, vertical) ──

    do_menu() {
        local choice
        while true; do
            echo ""
            c_white "========================================="
            echo ""
            c_white "  myshell - Framework Manager"
            echo ""
            c_green "========================================="
            echo ""
            printf "  1) Show framework status\n"
            printf "  2) Manage modules\n"
            printf "  3) Manage profiles\n"
            printf "  4) List module commands\n"
            echo ""
            c_yellow "  q) Quit"
            echo ""
            printf "%s" "Choice: "
            read -r choice || { echo ""; return 0; }
            case "$choice" in
                1) do_status ;;
                2) do_manage_modules ;;
                3) do_manage_profiles ;;
                4) do_cmds_list ;;
                q|Q) echo ""; c_white "Bye."; return 0 ;;
                *) c_yellow "Unknown option." ; echo "" ;;
            esac
        done
    }

    # ── dispatch: bare "myshell" opens the menu, "myshell list" lists commands ──
    case "$cmd" in
        list)     do_cmds_list ;;
        menu|"")  do_menu ;;
        *) c_white "myshell - Framework Manager"
           echo ""
           printf "Usage: myshell [list]\n"
           ;;
    esac
}
