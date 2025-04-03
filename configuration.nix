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
  users.users.pedrohlc = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+XO1v27sZQO2yV8q2AfYS/I/l9pHK33a4IjjrNDhV+YBlLbR2iB+L5iNu7x8tKDXYscynxJPHB3vWwerZXOh35SXdh5TE9Lez02Ck466fJnTjNxX63FvppXmMx8HaVYzymojDi+xTXMO4DxNFFrJTUIagWs8WNxEbYdGAaIKRQHB0ZWMSsyaY2XkR9RkV3I9QwKNrTnkC5h8bVn63LvTuORlTvY/Iu202M2toxOKWDQ5qdSrLfNaPl7kxWUVTCpyZ8Hza75sH3SB3/m8Queeq+E48nqjL7s9ZyO1TGf6ojaf2EGfx6H8jFwycXUD2QNLvsZcWmamyLPNbHY63jjOb"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDe+j0odZ7Mk0p8Q9lv0HWFt62ZW6uN4wi+pp7YD8BquU8cKYlh1yk5kQxzwhEpsrIgyiOYU5CxYWkdblh+h/oLBk7seCzYF+ZZnhR5AJdbUvz8FNPbDqd81tphjntRphNArYVgdpIz0pwvYz9yvDwNXaaPfJuLTIecmIM1PaVnQOTKR6zNhwWad9bXWr4NdS2LN5rl8Yg083BKu36kcdnj8bQi7viNhbpHrwYhDUiMuysUdAd/atNJGwyFehmRckhC/Jv65eJtwR/asXTsEB9KaRAqnuThAR9bGwlMdHP/zZOhB3Bb/M+HTafOlVvBv30iJXg426EUpoMg+X0C0ZOM+wddSDRTmf2z6m/tOxguG0DNwfug1lWjZUlLeevkauBywKo1TlqQEZ9BDFgI/J34YGELJV6hUYe+rQfzcTZwQ9nLx2bcZA877Sf7sAu4ajw+p2Vcz4gypwpdT6vNfDt15w9HKJM/PCAl9Y2OxXOqogrwL1zG9P7tX5adiXp3QW8="
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDyrnJw0jEN3OnAHPzMW1eUwNRk03Ba0bU1sLpRh51f+4M1LwLAraQtkg1bKe01cQGWWvNe1NUW0jGFywuvV2jwxcXb5bWSun9FpXfd0B9EMC/+uOCMBlEKflSkbzIGnLNbxWsVgAzzas+RbgyiFIlZ58qpUlhw2Iqp6eUGdH2ZtEm6WwU3PYB21UmEvthiDwfHImiWllpevfCmARMMndZy6/A6ygUrUQ4CBinya5K9SgxSDU20wo8ae4pQERtFIpYoW4HZ3iug/k+RW00Z9ofNN5YAFQYl+kS3jFQVH7Yz2PBbjbhF0qrKWwxg7pSn5gu+YRbZpZhZcqPzkuoZuTTq3/agNcH7nSOGtYFU9Mqx6BU/hRneUWUyLBO2qduHXBHATGvColuO9rMdu6EeVFpeSmVFXnTHkwisaBomQLwQn81aWKsWBPPJ9IbZur4t8SVBWxRunpz05cmgW9xCirzQbF68Uxw6qxG787CDF0aS8r0f/tj5o1Ef2DJhr4w+QV8="
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

  systemd.services.sync-archlinux-arm = {
    script = ''
      rsync -rlptH --safe-links --delete-delay --delay-updates rsync://de3.mirror.archlinuxarm.org/archlinux-arm /data/mirror/archlinux-arm
    '';
    path = [
      pkgs.rsync
    ];
    startAt = "minutely";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync-client.name;
      Group = config.users.users.rsync-client.group;
    };
  };

  systemd.services.sync-archriscv = {
    script = ''
      rsync -rlptH --safe-links --delete-delay --delay-updates rsync://archriscv.felixc.at/archriscv /data/mirror/archriscv
    '';
    path = [
      pkgs.rsync
    ];
    startAt = "minutely";
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
