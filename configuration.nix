# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./disko-config.nix
      inputs.sops-nix.nixosModules.sops
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mirror"; # Define your hostname.
  networking.domain = "ufscar.br";
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
  users.users.rsync = {
    isSystemUser = true;
    home = "/data/mirror";
    createHome = true;
    homeMode = "755";
    group = "rsync";
  };
  users.groups.rsync = {};

  users.users.rsyncro = {
    isSystemUser = true;
    home = "/data/mirror";
    createHome = false;
    group = "rsyncro";
  };
  users.groups.rsyncro = {};

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.matias = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSMWXqe7XSDcfoeMBUfl4XkerMBw4ZUuLNbJsJfwfay"
    ];
  };
  users.users.fabiors = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/URhEZ6RyyfEmrvg1D13Ri+K0CsmxEPvKMsSOO9pWPEFYrTERZz3mPEi21jI2onkz31/YyMCBRhUXJxc4bF/fJ8NbtEQcFYkFUr/DvZ3GhU4GTKAD9ihUASpFbEuQRvPfvmIm1XHY4sOhPejOS0UBiDvdnX6gCS7qPiaoRrt2ykpcLSpUwcgodqwj5dgehrx5Jwma41YAwNava7sjQQub6QofIXlsoPtuSZMbuncc2u1HEvEoSfCotDftZ4yQ6WL+HgvR4J4Jv6B9zBXJMEbeBEDhHxXOxiZMAURvGWiDmgF7YROos1dk/sEi2F08Zugr4uCPSUYZdASNR/y+yMPson00DtCfOQ1GPoc7f7+JvkuAGWQUBUrsr5fatJyxYtC9XnslEwssStbDMatU39DFl9mMQiyj2MwICdm+15HBRsBVDEomAhWx/Q5wWaEOytHCAjy4PfO7Xtdw402jX0YBFB8A0Dn0Lmbjv0/wDbCqegaU0rtIXdpiAl+/VAgiYUJO3ors0RdUbMyQYNgXLpzh0wpo9TDC8PfsNaJ5nxBNH7E6pQc7F87RYzDbpcIk9/JDdqWwH+6v+6EXrKao+nXg1oJMUhOpeIx0EVTMGtktwx80rL1llLvWAloOKqxvEGingc3wR/Oh5ozaL+q082K7t+UWzYuLuvddhmKKcyNJoQ=="
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
  users.users.gabriel = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDci4wJghnRRSqQuX1z2xeaUR+p/muKzac0jw0mgpXE2T/3iVlMJJ3UXJ+tIbySP6ezt0GVmzejNOvUarPAm0tOcW6W0Ejys2Tj+HBRU19rcnUtf4vsKk8r5PW5MnwS8DqZonP5eEbhW2OrX5ZsVyDT+Bqrf39p3kOyWYLXT2wA7y928g8FcXOZjwjTaWGWtA+BxAvbJgXhU9cl/y45kF69rfmc3uOQmeXpKNyOlTk6ipSrOfJkcHgNFFeLnxhJ7rYxpoXnxbObGhaNqn7gc5mt+ek+fwFzZ8j6QSKFsPr0NzwTFG80IbyiyrnC/MeRNh7SQFPAESIEP8LK3PoNx2l1M+MjCQXsb4oIG2oYYMRa2yx8qZ3npUOzMYOkJFY1uI/UEE/j/PlQSzMHfpmWus4o2sijfr8OmVPGeoU/UnVPyINqHhyAd1d3Iji3y3LMVemHtp5wVcuswABC7IRVVKZYrMCXMiycY5n00ch6XTaXBwCY00y8B3Mzkd7Ofq98YHc= hi@m7.rs"
    ];
  };
  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIOdYhRgFSM9pStYXvgMQuZXBSWTS8ud2l8pAokXsspH"
    ];
  };
  security.sudo.extraConfig = "%wheel ALL = (ALL) NOPASSWD: ALL";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git
    mosh
    tmux
    bmon
    htop
    wget
    inputs.archvsync.packages.${pkgs.system}.default
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
  services.wstunnel = {
    enable = true;
    servers = {
      ssh-tunnel = {
        enableHTTPS = false;
        listen = {
          host = "127.0.0.1";
          port = 8080;
        };
        restrictTo = [
          {
            host = "localhost";
            port = 22;
          }
        ];
      };
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  systemd.tmpfiles.rules = [
    # Syntax:
    # "d <path> <permissions> <user> <group> <age> <additional-flags>"
    "d /var/log/ftpsync 0755 rsync rsync - -"
    "d /data/mirror/chaotic-aur 0755 syncthing syncthing - -"
  ];

  services.syncthing = {
    enable = true;
    dataDir = "/home/syncthing";
    openDefaultPorts = false;
    cert = "${./certs/syncthing.pem}";
    key = config.sops.secrets."syncthing/key".path;
    overrideDevices = false;  # takes too long to activate if true
    settings = {
      folders = {
        "/data/mirror/chaotic-aur" = {
          id = "jhcrt-m2dra";
          devices = [ "garuda" ];
          type = "receiveonly";
          order = "oldestFirst";
          ignorePerms = true;
          rescanIntervalS = 604800;
        };
      };
      devices = {
        garuda = {
          id = "ZDHVMSP-EW4TMWX-DBH2W4P-HV5A6OY-BBEFABO-QTENANJ-RJ6GKNX-6KCG7QY";
          introducer = true;
        };
        this = {
          id = "43SSHD7-3LJDW5J-SLVW54I-IYWFWMF-ZIVLIEQ-4RXWCRI-MCN72R5-YJ2CJAH";
          name = "mirror.ufscar.br";
        };
      };
    };
  };

  systemd.services.sync-archlinux = {
    script = lib.readFile ./scripts/sync-archlinux.sh;
    path = [
      pkgs.diffutils
      pkgs.rsync
      pkgs.curl
    ];
    startAt = "*:*:0/15";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync.name;
      Group = config.users.users.rsync.group;
    };
  };

  systemd.services.sync-archlinux-arm = {
    script = ''
      target="/data/mirror/archlinux-arm"
      rsync_url="rsync://de3.mirror.archlinuxarm.org/archlinux-arm"
      upstream_url="https://de3.mirror.archlinuxarm.org"

      for dir in aarch64 armv7h os; do
        local_sync="$target/$dir/sync"
        remote_sync="$upstream_url/$dir/sync"
        if [[ ! -f "$local_sync" ]] || ! diff -b <(curl -Ls "$remote_sync") "$local_sync" >/dev/null; then
          rsync -rlptH --safe-links --delete-delay --delay-updates --timeout=600 --contimeout=60 --no-motd --quiet "$rsync_url/$dir/" "$target/$dir/"
        fi
      done
    '';
    path = [
      pkgs.diffutils
      pkgs.rsync
      pkgs.curl
    ];
    startAt = "minutely";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync.name;
      Group = config.users.users.rsync.group;
    };
  };

  systemd.services.sync-archriscv = {
    script = ''
      rsync -rlptH --safe-links --delete-delay --delay-updates --timeout=600 --contimeout=60 --no-motd --quiet rsync://archriscv.felixc.at/archriscv /data/mirror/archriscv
    '';
    path = [
      pkgs.rsync
    ];
    startAt = "minutely";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync.name;
      Group = config.users.users.rsync.group;
    };
  };

  environment.etc."ftpsync/ftpsync.conf".text = ''
    MIRRORNAME=mirror.ufscar.br

    TO=/data/mirror/debian/
    RSYNC_HOST=debian.c3sl.ufpr.br
    RSYNC_PATH="debian"

    INFO_MAINTAINER="CITI <citi@ufscar.br>"
    INFO_SPONSOR="Federal University of Sao Carlos <https://ufscar.br>"
    INFO_COUNTRY=BR
    INFO_LOCATION="Sao Carlos, Sao Paulo"
    INFO_THROUGHPUT=20Gb

    LOGDIR=/var/log/ftpsync
  '';

  systemd.services.sync-debian = {
    script = ''
      ftpsync-cron
    '';
    path = [
      inputs.archvsync.packages.${pkgs.system}.default
      pkgs.rsync
      pkgs.hostname
      pkgs.curl
      pkgs.gawk
    ];
    startAt = "*:0/5";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync.name;
      Group = config.users.users.rsync.group;
    };
  };

  systemd.services.sync-ubuntu = {
    script = ''
      target="/data/mirror/ubuntu"
      rsync_url="rsync://ubuntu.c3sl.ufpr.br/ubuntu"
      local_trace="$target/ubuntu/project/trace/mirror.ufscar.br"
      upstream_trace="$target/ubuntu/project/trace/br.archive.ubuntu.com"
      upstream_trace_url="https://ubuntu.c3sl.ufpr.br/ubuntu/project/trace/br.archive.ubuntu.com"

      if [[ ! -f "$local_trace" ]] || ! diff -b <(curl -Ls "$upstream_trace_url") "$local_trace" >/dev/null; then
        rsync -rlptH --safe-links --delete-delay --delay-updates --timeout=600 --contimeout=60 --no-motd --quiet "$rsync_url" "$target"
      fi
      cp "$upstream_trace" "$local_trace"
    '';
    path = [
      pkgs.diffutils
      pkgs.rsync
      pkgs.curl
    ];
    startAt = "*:0/5";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync.name;
      Group = config.users.users.rsync.group;
    };
  };

  systemd.services.sync-mint-packages = {
    script = ''
      rsync -rlptH --safe-links --delete-delay --delay-updates --timeout=600 --contimeout=60 --no-motd --quiet rsync-packages.linuxmint.com::packages /data/mirror/mint-archive
    '';
    path = [
      pkgs.rsync
    ];
    startAt = "hourly";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync.name;
      Group = config.users.users.rsync.group;
    };
  };

  systemd.services.sync-opensuse = {
    script = ''
      rsync -rlptH --safe-links --delete-after --delay-updates --delete-excluded --timeout=600 --contimeout=60 --no-motd --quiet \
        --exclude='debug/' \
        --exclude='history/' \
        --include='15.6/' \
        --exclude='15.*/' \
        --exclude='source/' \
        --exclude='src-*/' \
        --exclude='/update/**/src/' \
        --exclude='iso/' \
        --exclude='appliances/' \
        --exclude='images/' \
        --include='/ports/aarch64/' \
        --include='/ports/riscv/' \
        --exclude='/ports/*/' \
        rsync://rsync.opensuse.org/opensuse-full-really-everything/opensuse/ /data/mirror/opensuse
    '';
    path = [
      pkgs.rsync
    ];
    startAt = "*:0/15";
    serviceConfig = {
      Type = "oneshot";
      User = config.users.users.rsync.name;
      Group = config.users.users.rsync.group;
    };
  };

  systemd.extraConfig = "DefaultLimitNOFILE=8192";
  services.nginx =
    let
      defaultLocations = {
        "/" = {
          extraConfig = ''
            access_log /var/log/nginx/access.log custom;
            fancyindex on;
            fancyindex_exact_size off;
            fancyindex_footer ${./templates/footer.html} local;
          '';
        };
      };
    in
    {
      enable = true;
      additionalModules = [
        pkgs.nginxModules.fancyindex
      ];
      statusPage = true;
      appendConfig = ''
        worker_processes auto;
      '';
      virtualHosts."mirror.ufscar.br" = {
        enableACME = true;
        forceSSL = false;
        addSSL = true;
        default = true;
        root = "/data/mirror";
        locations = defaultLocations;
      };
      virtualHosts."br.mirror.archlinuxarm.org" = {
        enableACME = false;  # change later
        forceSSL = false;
        addSSL = false;  # change later
        root = "/data/mirror/archlinux-arm";
        locations = defaultLocations;
      };
      virtualHosts."mirror-admin.gelos.club" = {
        enableACME = true;
        forceSSL = false;
        addSSL = true;
        locations = {
          "/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:8080";
            extraConfig = ''
              access_log /dev/null;
            '';
          };
        };
      };
      commonHttpConfig = ''
        log_format custom '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" "$http_user_agent" $host';
      '';
    };
  security.acme.defaults.email = "citi@ufscar.br";
  security.acme.acceptTerms = true;

  services.rsyncd = {
    enable = true;
    settings = {
      sections = {
        opensuse = {
          "read only" = true;
          "hosts allow" = "195.135.220.0/22 2001:067c:2178::/48 ::1/128";
          path = "/data/mirror/opensuse";
        };
      };
      globalSection = {
        "max connections" = 4;
        "use chroot" = true;
        uid = config.users.users.rsyncro.name;
        gid = config.users.users.rsyncro.group;
      };
    };
  };

  services.datadog-agent = {
    enable = true;
    apiKeyFile = config.sops.secrets."datadog-agent/apiKey".path;
    site = "us5.datadoghq.com";
    extraConfig = {
      logs_enabled = true;
    };
    checks = {
      nginx = {
        init_config = { };
        instances = [
          {
            nginx_status_url = "http://localhost/nginx_status/";
            logs = [
              {
                type = "file";
                path = "/var/log/nginx/access.log";
                service = "nginx";
                source = "nginx";
              }
              {
                type = "file";
                path = "/var/log/nginx/error.log";
                service = "nginx";
                source = "nginx";
              }
            ];
          }
        ];
      };
    };
  };
  users.users.datadog.extraGroups = [ "nginx" ];  # read access to logs

  sops = {
    defaultSopsFile = ./secrets.yml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets."datadog-agent/apiKey" = {
      restartUnits = [ "datadog-agent.service" ];
      owner = config.users.users.datadog.name;
      group = config.users.users.datadog.group;
    };
    secrets."syncthing/key" = {
      restartUnits = [ "syncthing.service" ];
      owner = config.users.users.syncthing.name;
      group = config.users.users.syncthing.group;
    };
  };

  nix = {
    settings = {
      trusted-users = [ "root" "deploy" ];
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
    };
    gc = {
      automatic = true;
      dates = "hourly";
      options = "--delete-older-than 7d";
    };
  };

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
