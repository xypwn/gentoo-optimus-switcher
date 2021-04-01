#! /usr/bin/env sh

[ "$USER" = "root" ] && echo "Please DO NOT run this script as root" && exit 1

usage() {
    echo "Usage:"
    echo "  opti-sw.sh (i)ntel | (n)vidia"
}

checkinst() {
    which $1 >/dev/null 2>/dev/null && return 0 || return 1
}

rc_msg() {
    TERM_WIDTH=$(stty size | cut -d" " -f2)

    printf "%${TERM_WIDTH}s" | tr " " "_"
    printf "\n\n"
    echo "If you haven't done so already, please put the following line as the top of your display manager or XOrg init script (for example ~/.xinitrc for startx or /usr/share/sddm/scripts/Xsetup for SDDM):"
    echo "sh $HOME/.local/lib/nvidia-switch-rc.sh"
    printf "%${TERM_WIDTH}s" | tr " " "_"
}

su_run() {
    sh -c "$SU_PROG sh -c '$1'"
}

[ ! -e ~/.local/lib/nvidia-switch-rc.sh ] && mkdir -p ~/.local/lib/ && touch ~/.local/lib/nvidia-switch-rc.sh && chmod +x ~/.local/lib/nvidia-switch-rc.sh

if checkinst "sudo"; then
    SU_PROG="sudo"
elif checkinst "doas"; then
    SU_PROG="doas"
else
    SU_PROG="su -c"
fi

case $1 in
    i|intel)
	su_run "modprobe -r nvidia"
	[ -e /etc/X11/xorg.conf ] && 
	    su_run "mv -f /etc/X11/xorg.conf /etc/X11/xorg.conf.nvidia" &&
	    echo "Backed up existing XOrg config file /etc/X11/xorg.conf to /etc/X11/xorg.conf.nvidia"
	echo " " > ~/.local/lib/nvidia-switch-rc.sh

	echo "Switched to Intel GPU"
	;;
    n|nvidia)
	rc_msg
	# It will complain about the XOrg config file missing, so I am supressing all output, including errors
	su_run "nvidia-xconfig --prime" >/dev/null 2>/dev/null
	su_run "modprobe nvidia"
	echo -e "xrandr --setprovideroutputsource modesetting NVIDIA-0\nxrandr --auto" > ~/.local/lib/nvidia-switch-rc.sh

	su_run "mkdir -p /etc/modules-load.d"
	su_run "echo nvidia > /etc/modules-load.d/video.conf"

	echo "Switched to NVIDIA GPU. You will probably need to restart."
	;;
    *) usage; exit 1
	;;
esac
