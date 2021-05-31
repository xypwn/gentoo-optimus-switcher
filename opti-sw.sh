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
    printf "%${TERM_WIDTH}s" | tr " " "_"
}

# Make suspend work for NVIDIA
install_nvidia_suspend_script() {
	[ ! -d /lib64/elogind/system-sleep/ ] &&
		echo "Unable to install NVIDIA suspend script: /lib64/elogind/system-sleep/ not found. This might be because you aren't using elogind."

	sudo sh -c "echo '#!/usr/bin/env sh'                         > $SUSPEND_SCRIPT"
	sudo sh -c "echo '# Managed by opti-sw.sh'                   >> $SUSPEND_SCRIPT"
	sudo sh -c "echo 'lsmod | grep \"^nvidia\" || exit 0'        >> $SUSPEND_SCRIPT"
	sudo sh -c "echo 'WHEN=\"\$1\"'                              >> $SUSPEND_SCRIPT"
	sudo sh -c "echo 'WHAT=\"\$2\"'                              >> $SUSPEND_SCRIPT"
	sudo sh -c "echo 'if [ pre = \"\$WHEN\" ]; then'             >> $SUSPEND_SCRIPT"
	sudo sh -c "echo '	if [ suspend = \"\$WHAT\" ]; then'       >> $SUSPEND_SCRIPT"
	sudo sh -c "echo '		/usr/bin/nvidia-sleep.sh suspend'    >> $SUSPEND_SCRIPT"
	sudo sh -c "echo '	else'                                    >> $SUSPEND_SCRIPT"
	sudo sh -c "echo '		/usr/bin/nvidia-sleep.sh hibernate'  >> $SUSPEND_SCRIPT"
	sudo sh -c "echo '	fi'                                      >> $SUSPEND_SCRIPT"
	sudo sh -c "echo 'elif [ post = \"\$WHEN\" ]; then'          >> $SUSPEND_SCRIPT"
	sudo sh -c "echo '	sleep 1'                                 >> $SUSPEND_SCRIPT"
	sudo sh -c "echo '	/usr/bin/nvidia-sleep.sh resume &'       >> $SUSPEND_SCRIPT"
	sudo sh -c "echo 'fi'                                        >> $SUSPEND_SCRIPT"

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