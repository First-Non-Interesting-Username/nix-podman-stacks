## Example

```nix
{config, ...}: {
  nps.stacks.ephemera = {
    enable = true;
    downloadDirectory = "${config.nps.storageBaseDir}/booklore/bookdrop";
  };
}
```
