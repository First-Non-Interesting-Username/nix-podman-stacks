## Example

```nix
{
  vaultwarden = {
    enable = true;
    oidc = {
      enable = true;
      clientSecretFile = config.sops.secrets."vaultwarden/authelia/client_secret".path;
      clientSecretHash = "$pbkdf2-sha512$...";
    };
  };
}
```
