#!/bin/bash
set -e

tmux_send_key() {
    tmux send-keys -t qemu_session "$@"
}

tmux_send_key_until() {
    until tmux capture-pane -pJ -S-100 -t qemu_session | grep "$1" > /dev/null; do sleep 2; done
    tmux_send_key "${@:2}"
}

echo "Start ssh……"
service ssh start

echo "Configuring network……"
brctl addbr Virbr0
ifconfig Virbr0 192.168.10.1/24 up
tunctl -t tap0
ifconfig tap0 192.168.10.11/24 up
brctl addif Virbr0 tap0
echo "Network configuration down"

# Start simulating
tmux new-session -d -s qemu_session
tmux_send_key "qemu-system-mips -M malta -kernel vmlinux-2.6.32-5-4kc-malta -hda debian_squeeze_mips_standard.qcow2 -append "root=/dev/sda1" -netdev tap,id=tapnet,ifname=tap0,script=no -device rtl8139,netdev=tapnet -nographic" Enter

# Check http server state
echo "Waiting for qemu to boot..."
tmux_send_key_until "debian-mips login:" root Enter
echo "Send root"
sleep 2
tmux_send_key root Enter
echo "Server started! NetworkConnecting..."

sleep 2
tmux_send_key "ifconfig eth0 192.168.10.2/24 up" Enter

echo "Configuration done!"
sleep 2

echo "Copying file"
tmux new-session -d -s run_session

sleep 2
tmux send-keys -t run_session "scp -r squashfs-root/ root@192.168.10.2:~/" Enter

until tmux capture-pane -pJ -S-100 -t run_session | grep "continue connecting" > /dev/null; do sleep 2; done
echo "Entering yes"
tmux send-keys -t run_session "yes" Enter

until tmux capture-pane -pJ -S-100 -t run_session | grep "root@192.168.10.2's password:" > /dev/null; do sleep 2; done
tmux send-keys -t run_session "root" Enter
sleep 10
echo "File Copied"

tmux send-keys -t run_session "ssh root@192.168.10.2" Enter
sleep 5
tmux send-keys -t run_session root Enter
sleep 3
tmux send-keys -t run_session "mount -o bind /dev ./squashfs-root/dev" Enter
sleep 1
tmux send-keys -t run_session "mount -t proc /proc ./squashfs-root/proc" Enter
sleep 1
tmux send-keys -t run_session "chroot squashfs-root /bin/sh" Enter
sleep 1
tmux send-keys -t run_session "./bin/upnp" Enter
sleep 1
tmux send-keys -t run_session "./bin/mic" Enter
sleep 20
echo "Service Started"

tmux_send_key "ifconfig eth0 192.168.10.2/24 up" Enter
sleep 1
tmux_send_key "ifconfig br0 192.168.10.11/24 up" Enter
echo "Network reconfigured"

echo "Port mapping"
tmux new-session -d -s map_session
tmux send-keys -t map_session 'echo "127.0.0.1 6666 192.168.10.2 37215" > /etc/rinetd.conf' Enter
sleep 3
echo "Configuration changed"
tmux send-keys -t map_session 'pkill rinetd' Enter
echo "Rinetd killed"
sleep 3
tmux send-keys -t map_session 'rinetd -c /etc/rinetd.conf' Enter
echo "Rinetd restarted"
sleep 2
echo "Port mapped"

# Start attck
bash
