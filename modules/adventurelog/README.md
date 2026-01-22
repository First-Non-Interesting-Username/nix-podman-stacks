## Example

```nix
{config, ...}: {
  adventurelog = {
    enable = true;
    secretKeyFile = config.sops.secrets."adventurelog/secret_key".path;
    db.passwordFile = config.sops.secrets."adventurelog/db_password".path;
    adminProvisioning = {
      username = "admin";
      email = "admin@example.com";
      passwordFile = config.sops.secrets."adventurelog/admin_password".path;
    };
  };
}
```
