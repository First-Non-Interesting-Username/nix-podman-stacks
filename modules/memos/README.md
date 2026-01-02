## Example

```nix
{
  nps.stacks.memos = {
    enable = true;

    oidc = {
      registerClient = true;
      clientSecretHash = "$pbkdf2-sha512$...";
    };
  };
}
```
