## Example

```nix
{config, ...}: {
  searxng = {
    enable = true;
    secretKeyFile = config.sops.secrets."searxng/secret_key".path;
  };
}
```
