# Environment setup
set fish_greeting
set -gx LC_ALL en_US.UTF-8
set -gx EDITOR /bin/nvim

# Aliasis
alias trans='trans -b :ru'
alias lp='lp -d "HP_LaserJet_1020"'
alias obs_bg='QT_QPA_PLATFORM=xcb obs &'
alias zapret='cd /home/kirill/opt/zapret-discord-youtube-linux/ && ./service.sh'
alias ira='stty -F /dev/ttyUSB0; /home/kirill/.arduino15/ira_program/arduino_listener'
alias raymer='/home/kirill/programming/probe/raymer/raymer'
alias olympus='/home/kirill/opt/olympus/linux.main/olympus &'
alias streamer_bot='cd /home/kirill/opt/streamer_bot/ && wine Streamer.bot.exe &'
alias start_steam='nohup Xephyr :1 -screen 1920x1080 -ac -noreset >/tmp/xephyr.log 2>&1 & sleep 3 & DISPLAY=:1 steam'
alias gdre='~/programming/probe/godot_tools/gdre/gdre_tools.x86_64'
alias godot_4_1_1='~/programming/probe/godot_tools/godot-4.1.1-steam/linux-411-editor.x86_64'
alias anki='~/opt/anki/anki'

# Paths
fish_add_path ~/.local/bin/.cargo/
fish_add_path ~/.local/bin/
fish_add_path ~/.nimble/bin/
fish_add_path /home/kirill/opt/telegram/

# Startup command for opening window manager automatically only once on login
if status is-login
    niri-session -l
end
