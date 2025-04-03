# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./disko-config.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mirror"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
        };
        bondConfig = {
          Mode = "802.3ad";
          TransmitHashPolicy = "layer3+4";
          MIIMonitorSec="0.100s";
        };
      };
    };
    networks = {
      "30-enp68s0f0" = {
        matchConfig.Name = "enp68s0f0";
        networkConfig.Bond = "bond0";
      };
      
      "30-enp68s0f1" = {
        matchConfig.Name = "enp68s0f1";
        networkConfig.Bond = "bond0";
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        address = [
          "200.133.233.210/30"
          "2801:b0:9:37::210/64"
        ];
        routes = [
          { Gateway = "200.133.233.209"; }
          { Gateway = "2801:b0:9:37::209"; }
        ];
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };
  users.users.rsync-client = {
    isSystemUser = true;
    home = "/data/mirror";
    createHome = false;
    group = "rsync-client";
  };
  users.groups.rsync-client = {};

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.matias = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSMWXqe7XSDcfoeMBUfl4XkerMBw4ZUuLNbJsJfwfay"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git
    mosh
    tmux
    bmon
    iotop
    wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  systemd.services.sync-archlinux = {
    script = lib.readFile ./scripts/sync-archlinux.sh;
    path = [
      pkgs.diffutils
      pkgs.rsync
      pkgs.curl
    ];
    startAt = "*-*-* *:*:00,15,30,45";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync-client.name;
      Group = config.users.users.rsync-client.group;
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."mirror.ufscar.br" = {
      enableACME = true;
      forceSSL = false;
      addSSL = true;
      default = true;
      root = "/data/mirror";
      locations = {
        "/" = {
          extraConfig = ''
            autoindex on;
            autoindex_exact_size off;
          '';
        };
      };
    };
  };
  security.acme.defaults.email = "admin@ufscar.br";
  security.acme.acceptTerms = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?

}
