function use-session --description 'Choose the WM started at login: niri or labwc'
    set -l marker $HOME/.config/session-choice
    set -l valid niri labwc

    set -l current niri
    if test -f $marker
        set current (cat $marker)
    end

    # No arguments -> just report.
    if test (count $argv) -eq 0
        echo "Session started at login: $current"
        echo "Usage: use-session "(string join ' | ' $valid)
        return 0
    end

    if not contains -- $argv[1] $valid
        echo "Unknown session: $argv[1]" >&2
        echo "Valid options: "(string join ' | ' $valid) >&2
        return 1
    end

    printf '%s\n' $argv[1] >$marker

    if test "$argv[1]" != "$current"
        echo "Session changed: $current -> $argv[1]"
        echo "Log out and log back in for it to take effect."
    else
        echo "Session already set to: $argv[1]"
    end
end