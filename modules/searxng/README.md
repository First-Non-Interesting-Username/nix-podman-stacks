## Example

```nix
{config, ...}: {
  nps.stacks.searxng = {
    enable = true;
    secretKeyFile = config.sops.secrets."searxng/secret_key".path;
  };
}
```
