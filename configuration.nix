# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./bash-config.nix
    ./neovim.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  networking.resolvconf.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NAME = "de_AT.UTF-8";
    LC_NUMERIC = "de_AT.UTF-8";
    LC_PAPER = "de_AT.UTF-8";
    LC_TELEPHONE = "de_AT.UTF-8";
    LC_TIME = "de_AT.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "at";
    variant = "nodeadkeys";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = false;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.linus = {
    isNormalUser = true;
    description = "Linus Hohlbrugger";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    packages = with pkgs; [
      kdePackages.kate
      #  thunderbird
    ];
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0416", ATTRS{idProduct}=="5020", MODE="0666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="0416", ATTRS{idProduct}=="5020", MODE="0666"
  '';

  nix.settings.extra-experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Install firefox.
  programs.firefox.enable = true;

  #nh
  programs.nh.enable = true;

  programs.starship.enable = true;

  # Install Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  programs.java = {
    enable = true;
    package = pkgs.openjdk21.override { enableJavaFX = true; };
  };

  # Install Mysql
  # Upgrade not automatic, first dump
  # then use mysql_upgrade
  # see nixos wiki https://wiki.nixos.org/wiki/Mysql
  # package mycli is also recommended, see in systemPackages
  # not used because not needed and conflict with mariadb docker
  # useless anyways considering that the use case i had for it is gone
  #services.mysql = {
  #  enable = true;
  #  package = pkgs.mysql84;
  #};

  # temporare remove to resolve update issues
  #virtualisation.docker = {
  #  enable = true;
  #};

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  # Install flatpak
  services.flatpak.enable = true;

  programs.git.enable = true;

  programs.dconf.enable = true;

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      # removed for safety when upgrading
      #"ciscoPacketTracer8-8.2.2"
      "pnpm-10.29.2"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    # replaced with neovim.nix
    #neovim
    kitty
    dmenu
    tree
    smartmontools
    docker-compose
       # For lazyvim (LSPs/formatters live in neovim.nix)
    fzf
    lazygit
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
    fira-code
    _3270font
    departure-mono
    gcc
    ruff
    sqlfluff
    statix
    #
    jq
    fq
    wget
    xh
    curlie
    tmux
    wireguard-tools
    yt-dlp
    ffmpeg-full
    imagemagick
    gifsicle
    ripgrep
    progress
    fd
    pay-respects
    helix
    gtop
    btop
    speedtest-cli
    cbonsai
    asciiquarium-transparent
    lolcat
    #asciiquarium
    xdotool
    tldr
    activate-linux
    mycli # Rich command-line interface for MySQL with auto-completion and syntax highlighting
    sqlcl
    dotnetCorePackages.sdk_10_0-bin
    plantuml
    graphviz
    gsettings-desktop-schemas
    gtk3

    # temporare disable for update
    #f3d
    pdal

    # school stuff

    # removed for safety when upgrading
    geogebra6
    # removed for safety when upgrading
    teams-for-linux

    fastfetch
    hyfetch
    # replaces by fastfetch
    #neofetch
    # Packet tracer previously not working now working
    # using nix-store and the official .deb from cisco
    # make sure to name the file just as the system excpects it, see https://nixos.wiki/wiki/Packettracer
    # removed for safety when upgrading
    cisco-packet-tracer_9
    # do not use to install steam, instead use programs.steam.enable = true;
    #steam
    prismlauncher
    sl
    vesktop
    # build issue
    stoat-desktop
    element-desktop
    signal-desktop
    easyeffects
    qpwgraph
    rnnoise
    pulseaudio
    # nheko has problems with old encrption libraries
    fluffychat
    fortune
    figlet
    cowsay
    pipes
    onlyoffice-desktopeditors
    tor-browser
    ani-cli
    # build problem, probable solution is to install pdal, problem for another time, useless game anyways
    #torcs
    endless-sky
    chromium
    chromium-bsu
    qbittorrent
    vopono
    spotify
    librespot
    ncspot
    spotify-qt
    # Alternative spotify GUIS but isnt actually spotify
    # so dont use if spotify is wanted
    spotube
    spotiflac
    psst
    chatterino7
    xournalpp
    obsidian
    rawtherapee
    rapidraw
    nomacs
    gimp-with-plugins

    # build problem, temporare disable
    bottles
    wineWow64Packages.stable
    distrobox

    # Coding and IDEs
    # rebuild failing and maybe not needed anymore; last tried at 19-30_09-14-2026
    #mysql-workbench
    dbeaver-bin
    jetbrains.rider
    # temporare remove because insecure
    #jetbrains.pycharm-oss
    sqlite
    vscodium
    nodejs
    unityhub

    # ai
    ollama

    # KDE
    kdePackages.discover # Optional: Install if you use Flatpak or fwupd firmware update sevice
    kdePackages.kcalc # Calculator
    kdePackages.kcharselect # Tool to select and copy special characters from all installed fonts
    kdePackages.kclock # Clock app
    kdePackages.kcolorchooser # A small utility to select a color
    kdePackages.kolourpaint # Easy-to-use paint program
    kdePackages.ksystemlog # KDE SystemLog Application
    kdePackages.sddm-kcm # Configuration module for SDDM
    kdiff3 # Compares and merges 2 or 3 files or directories
    kdePackages.isoimagewriter # Optional: Program to write hybrid ISO files onto USB disks
    kdePackages.partitionmanager # Optional: Manage the disk devices, partitions and file systems on your computer
    # Non-KDE graphical packages
    hardinfo2 # System information and benchmarks for Linux systems
    vlc # Cross-platform media player and streaming server
    mediainfo

    # these help VLC and Dolphin cover more codecs:
    libdvdcss
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly # includes patented codecs like x264, mp3
    gst_all_1.gst-libav # ffmpeg backend for GStreamer, covers a huge range
    kdePackages.ffmpegthumbs # Dolphin thumbnails
    wayland-utils # Wayland utilities
    wl-clipboard # Command-line copy/paste utilities for Wayland
    kdePackages.kpat # Kde pateince game
    kdePackages.kmines # Kde minesweeper
    kdePackages.kalzium # Kde Period table
    kdePackages.filelight # Kde file size viewer
    # for kde vault
    gocryptfs
    kdePackages.plasma-vault
    p7zip
  ];

  programs.ssh.startAgent = true;
  hardware.bluetooth.enable = true;
  services.geoclue2.enable = true;
  programs.kdeconnect.enable = true;
  #--extra-experimental-features nix-command

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
