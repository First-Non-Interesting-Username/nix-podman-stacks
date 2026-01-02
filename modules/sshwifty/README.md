## Example

```nix
{config, ...}: {
  nps.stacks.sshwifty = {
    enable = true;

    settings = {
      SharedKey = "{{ file.Read `${config.sops.secrets."sshwifty/web_password".path}`}}";
    };
  };
}
```
