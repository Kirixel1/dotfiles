function labwc-session --description 'Start labwc, stopping niri first if it holds the DRM'
    # niri is started through the systemd user bus and takes the DRM master.
    # Only one compositor can hold it, so niri has to release it before labwc
    # can start. Without this, labwc dies with a "no DRM master" style error.
    if systemctl --user is-active --quiet niri.service
        echo "Stopping niri (releases the DRM master)..."
        systemctl --user stop niri.service
        sleep 1
    end

    set -gx XDG_CURRENT_DESKTOP labwc
    set -gx XDG_SESSION_TYPE wayland
    set -gx DESKTOP_SESSION labwc
    set -gx QT_QPA_PLATFORM wayland

    echo "Starting labwc..."
    exec labwc
end