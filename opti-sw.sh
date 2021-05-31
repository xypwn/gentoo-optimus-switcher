#!/usr/bin/env sh

[ "$USER" = "root" ] && echo "Please DO NOT run this script as root" && exit 1

checkinst() {
    which $1 >/dev/null 2>/dev/null && return 0 || return 1
}

usage() {
    echo "Usage:"
    echo "  opti-sw.sh (i)ntel | (n)vidia"
}

if ! checkinst "sudo"; then
	if checkinst "doas"; then
		alias sudo="doas"
	else
		alias sudo="su -c"
	fi
fi

case "$1" in
	i|intel) OPT=intel;;
	n|nvidia) OPT=nvidia;;
    *) usage; exit 1;;
esac

SUSPEND_SCRIPT=/lib64/elogind/system-sleep/opti-sw-nvidia.sh

rc_msg() {
    TERM_WIDTH=$(stty size | cut -d" " -f2)

    printf "%${TERM_WIDTH}s" | tr " " "_"
    printf "\n\n"
    echo "If you haven't done so already, please put the following line at the top of your display manager or XOrg init script (for example ~/.xinitrc for startx or /usr/share/sddm/scripts/Xsetup for SDDM):"
    echo "sh $HOME/.local/lib/nvidia-switch-rc.sh"
    printf "%${TERM_WIDTH}s\n" | tr " " "_"
}

# Make suspend work for NVIDIA
install_nvidia_suspend_script() {
	[ ! -d /lib64/elogind/system-sleep/ ] &&
		echo "Unable to install NVIDIA suspend script: /lib64/elogind/system-sleep/ not found. This might be because you aren't using elogind." &&
		return 1

	sudo sh -c "echo '#!/usr/bin/env sh
# Managed by opti-sw.sh
lsmod | cut -d\" \" -f1 | grep \"^nvidia\$\" > /dev/null || exit 0
WHEN=\"\$1\"
WHAT=\"\$2\"
if [ pre = \"\$WHEN\" ]; then
	if [ suspend = \"\$WHAT\" ]; then
		/usr/bin/nvidia-sleep.sh suspend
	else
		/usr/bin/nvidia-sleep.sh hibernate
	fi
elif [ post = \"\$WHEN\" ]; then
	sleep 1
	/usr/bin/nvidia-sleep.sh resume &
fi' > $SUSPEND_SCRIPT"

	sudo chmod +x $SUSPEND_SCRIPT
}

case $OPT in
	intel)
		sudo modprobe -r nvidia
		[ -e /etc/X11/xorg.conf ] && 
			sudo mv -f /etc/X11/xorg.conf /etc/X11/xorg.conf.nvidia &&
			echo "Backed up existing XOrg config file /etc/X11/xorg.conf to /etc/X11/xorg.conf.nvidia"
		echo " " > ~/.local/lib/nvidia-switch-rc.sh
		sudo sed -i '/^nvidia$/d' /etc/modules-load.d/video.conf
		echo "Switched to Intel GPU"
		;;
	nvidia)
		rc_msg
		sudo nvidia-xconfig --prime > /dev/null 2> /dev/null
		sudo modprobe nvidia
		echo -e "xrandr --setprovideroutputsource modesetting NVIDIA-0\nxrandr --auto" > ~/.local/lib/nvidia-switch-rc.sh
		sudo mkdir -p /etc/modules-load.d
		grep '^nvidia$' /etc/modules-load.d/video.conf > /dev/null || sudo su -c 'echo nvidia >> /etc/modules-load.d/video.conf'

		# Make suspend work
		[ ! -e "$SUSPEND_SCRIPT" ] && install_nvidia_suspend_script && echo "Installed $SUSPEND_SCRIPT to make suspend work on NVIDIA"

		echo "Switched to NVIDIA GPU. You will probably need to restart."
		;;
esac

[ ! -e ~/.local/lib/nvidia-switch-rc.sh ] && mkdir -p ~/.local/lib/ && touch ~/.local/lib/nvidia-switch-rc.sh && chmod +x ~/.local/lib/nvidia-switch-rc.sh

exit 0
