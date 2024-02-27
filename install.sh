# Update pacman database
sudo pacman --noconfirm -Sy
sudo pacman -S --noconfirm --needed base-devel git rust

read -p "Do you want to add the work source to .zshrc? (y/N): " zsh_work

if [ ! $(git config user.email)  ]; then
    read -p "Type your git email:  " git_email
    git config --global user.email "$git_email"
    
fi
if [ ! $(git config user.name)  ]; then
    read -p "Type your git Full name:  " git_name
    git config --global user.name "$git_name"
fi


sudo gpasswd -a $USER uucp

# Install Paru helper
if ! command -v paru --help &> /dev/null; then
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd ..
    sudorm -r paru-bin
fi

sudo sed -i 's/#BottomUp/BottomUp/g' /etc/paru.conf
sudo sed -i 's/#SudoLoop/SudoLoop/g' /etc/paru.conf
sudo sed -i 's/#Color/Color/g' /etc/pacman.conf

# Install Packages
paru -S --noconfirm --needed

# Install Packages from file
install_packages() {
    local filename=$1
    while IFS= read -r package; do
        echo "--------------------------------Installing $package"
        start_time=$(date +%s)
        paru -S --noconfirm --needed "$package" || echo "ERROR: $package" >> paru.log
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "INFO: Installation of $package took $duration sec" >> paru.log
    done < "$filename"
}

install_packages "packages"

install_code_packages() {
    local filename=$1
    while IFS= read -r package; do
        code --install-extension  "$package" || echo " failed to install $package" >> error.log
    done < "$filename"
}

install_code_packages "code_packages"



# Generate ssh key
if [[ ! -f $HOME/.ssh/id_rsa ]]
then
    ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
fi

sudo timedatectl set-timezone Europe/Oslo

# Set theme
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
# Set Backlight permissions and monotor rules
echo 'SUBSYSTEM=="backlight",RUN+="/bin/chmod 666 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"' | sudo tee /etc/udev/rules.d/backlight-permissions.rules
sudo sh -c 'echo SUBSYSTEM=="drm", ACTION=="change", RUN+="/usr/bin/autorandr" > /etc/udev/rules.d/70-monitor.rules'

# Enable services
if ! systemctl is-active --quiet teamviewerd  ; then
    sudo systemctl enable teamviewerd.service --now
fi

# Setup syslog-ng
sudo systemctl enable syslog-ng@default.service --now

# Setup Network manager
sudo systemctl disable systemd-networkd.service
sudo systemctl disable iwd.service
sudo systemctl enable NetworkManager.service --now

sudo sh -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo sh -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"

if [[ ! -f $HOME/.zshrc ]]
then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' ~/.zshrc

#Docker
sudo systemctl enable docker.service acpid.service --now
sudo usermod -aG docker $USER

# Virt Manager
sudo usermod -G libvirt -a $USER
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service
## This command does not work, and we do not know the reason or a workaround yet...
#sudo virsh net-autostart default

# user defaults
if [ $USER = fw ]; then
    git_url="https://github.com/frodus/dotfiles.git"

# Add Teamviewer config to make it start
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
    echo -e '[Service] \nEnvironment=XDG_SESSION_TYPE=x11' | sudo tee /etc/systemd/system/getty@tty1.service.d/getty@tty1.service-drop-in.conf

    paru -S --noconfirm --needed dwm st xorg-xinit xorg-server qemu-full qelectrotech neovim microsoft-edge-stable-bin libva-intel-driver dmenu prusa-slicer xidlehook

elif [ $USER = user ] || [ $USER = ingar ]; then
    git_url="https://github.com/ingar195/.dotfiles.git"
    
    # Power Save
    sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=suspend/g' /etc/systemd/logind.conf
    sudo sed -i 's/#IdleAction=ignore/IdleAction=suspend/g' /etc/systemd/logind.conf
    sudo sed -i 's/#IdleActionSec=30min/IdleActionSec=30min/g' /etc/systemd/logind.conf
    sudo sed -i 's/#HoldoffTimeoutSec=30s/HoldoffTimeoutSec=5s/g' /etc/systemd/logind.conf
    install_packages "user_packages"

    # greeter
    sudo sed -i 's/#theme-name=/theme-name=Numix/g' /etc/lightdm/lightdm-gtk-greeter.conf
    sudo sed -i 's/#icon-theme-name=/icon-theme-name=Papirus-Dark/g' /etc/lightdm/lightdm-gtk-greeter.conf
    sudo sed -i 's/#background=/background=#2f343f/g' /etc/lightdm/lightdm-gtk-greeter.conf
    sudo sed -i 's/#xft-dpi=/xft-dpi=261/g' /etc/lightdm/lightdm-gtk-greeter.conf

    
    sudo systemctl enable lightdm
    # Dunst settings 
    sudo sed -i 's/offset = 10x50/offset = 40x70/g' /etc/dunst/dunstrc
    sudo sed -i 's/notification_limit = 0/notification_limit = 5/g' /etc/dunst/dunstrc

    # Directory
    mkdir -p $HOME/workspace &> /dev/null
    


elif [ $USER = screen ]; then
    # Autostart script for web kiosk
    echo Screen 
else
    read -p "enter the https URL for you git bare repo : " git_url
fi

if [[ ! -f .dotfiles/config ]]
then
    rm .config/i3/config
    mkdir .config/polybar
fi

# Tmp alias for installation only 
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=/home/$USER'

# Create gitingore
if [[ ! -f $HOME/.gitignore ]]
then
    echo ".dotfiles" > $HOME/.gitignore
fi
if [[ ! -d $HOME/.dotfiles/ ]]
then
    echo "Did not find .dotfiles, so will check them out again"
    git clone --bare $git_url $HOME/.dotfiles
    dotfiles checkout -f
else
    dotfiles pull
fi

# Create folders for filemanager
mkdir -p $HOME/Downloads &> /dev/null
mkdir -p $HOME/Desktop &> /dev/null
mkdir -P $HOME/Pictures &> /dev/null
mkdir -P $HOME/.config/wireguard &> /dev/null

# not working
if [ "$(echo $SHELL )" != "/bin/zsh" ]; then
    sudo chsh -s /bin/zsh $USER
fi

# Aliases and functions
# Copy .aliases and .functions files to .config
zsh_config_path=$HOME/.config/zsh
mkdir -p $zsh_config_path

cp .aliases $zsh_config_path/
cp .functions $zsh_config_path/


# Function to add source to .zshrc if not already there
add_source_to_zshrc() {
    if [[ -f $HOME/.zshrc ]]; then
        echo "Adding 'source $1 to .zshrc'"
        if ! grep -Fxq "source $1" $HOME/.zshrc; then
            echo "source $1" >> $HOME/.zshrc
        fi
    fi
}

# Add sources to .zshrc if not already there
add_source_to_zshrc "$zsh_config_path/.aliases"
add_source_to_zshrc "$zsh_config_path/.functions"


if [[ $zsh_work == "y" ]]; then
    add_source_to_zshrc "$zsh_config_path/.work"
fi

# Power settings
sudo powertop --auto-tune

# Install updates and cleanup unused 
paru -Qdtq | paru --noconfirm  -Rs - &> /dev/null

sed -i 's/https:\/\/github.com\//git@github.com:/g' /home/$USER/.dotfiles/config

echo ----------------------
echo "Please reboot your PC"
echo ----------------------
