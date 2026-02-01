## Example

```nix
{config, ...}: {
  nps.stacks.wallos = {
    enable = true;
    oidc = {
      registerClient = true;
      clientSecretHash = "$pbkdf2-sha512$...";
    };
  };
}
```
