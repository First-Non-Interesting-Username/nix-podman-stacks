## Example

```nix
{
  streaming = {
    enable = true;

    gluetun = {
      vpnProvider = "airvpn";
      wireguardPrivateKeyFile = config.sops.secrets."gluetun/wg_pk".path;
      wireguardPresharedKeyFile = config.sops.secrets."gluetun/wg_psk".path;
      wireguardAddressesFile = config.sops.secrets."gluetun/wg_address".path;

      extraEnv = {
        FIREWALL_VPN_INPUT_PORTS.fromFile = config.sops.secrets."qbittorrent/torrenting_port".path;
      };
    };

    qbittorrent.extraEnv = {
      TORRENTING_PORT.fromFile = config.sops.secrets."qbittorrent/torrenting_port".path;
    };
  };
}
```

## Notes

By default, Jellyfin writes to `/config/cache/transcodes` for transcoding. This can cause a high amount of write operations on the underlying disk.
To avoid this, you can optionally mount a tmpfs into the container:

```nix
{
  nps.stacks.streaming = {
    containers.jellyfin.extraPodmanArgs = [ "--tmpfs=/config/cache/transcodes:size=4G" ];
  };
}
```

Ram size to be determined on what you have available but 4G seems to be sufficient for most transcodes.
Thanks to [@Zer0PointModule](https://github.com/Zer0PointModule) for the hint.
