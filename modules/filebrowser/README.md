## Example

```nix
{config, ...}: {
  nps.stacks.filebrowser = {
    enable = true;
    mounts = {
      ${config.home.homeDirectory} = "/home";
      ${config.nps.externalStorageBaseDir} = "/hdd";
    };
  };
}
```
