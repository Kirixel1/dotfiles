#!/usr/bin/env bash

# Neovim as Godot's external editor (after niscolas/nvim-godot), hardened.
#
# Two failure modes this fixes:
#  1. Godot's "External Editor" check was file existence, but a socket file
#     outlives a killed Neovim. We probe the server instead, so a stale socket
#     is cleaned up instead of swallowing the request.
#  2. The upstream launch is backgrounded inside this script's process group.
#     When Godot reaps the script the group can get SIGHUP and Neovim dies
#     seconds after opening. setsid + nohup detaches it.

term_exec="kitty"
nvim_exec="nvim"
server_path="$HOME/.cache/nvim/godot-server.pipe"
server_startup_delay=0.5

mkdir -p "$(dirname "$server_path")"

# $1 file, $2 "line,col" from Godot's {line},{col}
filename="$1"
position="${2:-1}"
line="${position%%,*}"
col="${position##*,}"
[ -n "$line" ] || line=1

log() { printf '%s godot-nvim: %s\n' "$(date '+%H:%M:%S')" "$*" >>"${GODOT_NVIM_LOG:-/tmp/godot-nvim.log}" 2>/dev/null; }

server_alive() {
	[ -S "$server_path" ] || return 1
	"$nvim_exec" --server "$server_path" --remote-expr '1' >/dev/null 2>&1
}

start_server() {
	rm -f "$server_path" # stale socket would block --listen
	# setsid: new session, so nothing Godot does to this process group reaches Neovim.
	setsid nohup "$term_exec" "$nvim_exec" --listen "$server_path" \
		>"/tmp/godot-nvim-nvim.log" 2>&1 < /dev/null &
	disown 2>/dev/null

	for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
		sleep 0.25
		server_alive && return 0
	done
	return 1
}

if server_alive; then
	log "reusing live server, opening $filename at $line:$col"
	# --remote-tab takes the path as a real argument, so spaces need no escaping.
	"$nvim_exec" --server "$server_path" --remote-tab "$filename"
	"$nvim_exec" --server "$server_path" \
		--remote-expr "execute(\"call cursor($line,$col)\")"
else
	log "no live server, launching new nvim for $filename at $line:$col"
	if ! start_server; then
		log "server did not come up; opening the file directly instead"
		setsid nohup "$term_exec" "$nvim_exec" "$filename" \
			>"/tmp/godot-nvim-nvim.log" 2>&1 < /dev/null &
		disown 2>/dev/null
		exit 0
	fi
	log "server up, handing the file over"
	"$nvim_exec" --server "$server_path" --remote-tab "$filename"
	"$nvim_exec" --server "$server_path" \
		--remote-expr "execute(\"call cursor($line,$col)\")"
fi
