## Example

```nix
{config, ...}: {
  nps.stacks.shelfmark = {
    enable = true;
    downloadDirectory = "${config.nps.storageBaseDir}/booklore/bookdrop";
  };
}
```
