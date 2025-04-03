{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-path/pci-0000:02:00.0-scsi-0:2:0:0";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "noatime" "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "noatime" ];
              };
            };
          };
        };
      };
      data = {
        device = "/dev/disk/by-path/pci-0000:02:00.0-scsi-0:2:1:0";
        type = "disk";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/data";
          mountOptions = [ "noatime" "barrier=0" "max_batch_time=10000000" "noauto_da_alloc" "nofail" "x-systemd.device-timeout=5" ];
        };
      };
    };
  };
}
