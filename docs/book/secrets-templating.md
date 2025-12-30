# Secret Management

Many stacks need secret values such as JWT secrets, database passwords and other token to function correctly.
Secret values are typically expected as a path to a file that contains the secret. It is important that the file is located outside of the (world-readable) Nix store to prevent leaking your secrets.

To still keep the secrets as part of your (public) Git repository, projects like [sops-nix](https://github.com/Mic92/sops-nix) and [agenix](https://github.com/ryantm/agenix) can be used.

Since the decrypted secrets are not available during evaluation and build time, but just during runtime, you will have to work with just knowing the final path of the file.

While all stacks already take care of passing all mandatory secrets, you may want to provide additional secrets.
Depending on the context there are a few different way of achieving this. The following examples will use [sops-nix](https://github.com/Mic92/sops-nix) to reference the secrets file paths.

## Environment Variables

### Environment File

When passing secrets via environment variables, you can store the entire environment file in your sops managed `secrets.yaml`.
Example `secrets.yaml`:

```yaml
vaultwarden:
  env_file: |
    ADMIN_TOKEN=abc
```

The decrypted file can be passed during runtime using the [environmentFile](https://home-manager-options.extranix.com/?query=services.podman.containers+environmentFile) option:

```nix
{config, ...}: {
  nps.stacks.vaultwarden = {
      containers.vaultwarden.environmentFile = [ config.sops.secrets."vaultwarden/env_file".path ];
  };
}
```

### extraEnv

Instead of storing the entire environment file as a secret, nix-podman-stacks adds a custom `extraEnv` option to Home Managers existing `services.podman.containers` options. This extends the existing `environment` option and allows to also pass environment variables from file contents.

Using this, only the values of the secrets have to be stored in your encrypted secrets file.
This can allow for some more explicity because you can see which environment variables you pass into a service.

Modifying the previous `secrets.yaml`:

```yaml
vaultwarden:
  admin_token: abc
```

You can now pass the values of the environment variables using the `extraEnv` special value `fromFile`:

```nix
{config, ...}: {
  nps.stacks.vaultwarden = {
    containers.vaultwarden.extraEnv = {
      ADMIN_TOKEN = { fromFile = config.sops.secrets."vaultwarden/admin_token".path; };
    };
  };
}
```

Using this approach, before a container starts (during the systemd `ExecStartPre` hook), a new environment file will be automatically constructed by reading the contents of the specified secret files. The resulting environment file will then be passed to the container.

### Files

Many services not only support reading secrets from an environment variable, but also from a file.
Typically an environment variable with a `_FILE` suffix specifies the file that contains the value.

This can be achieved by combining the standard options `environment` & `volumes`:

```nix
{config, ...}: {
  nps.stacks.vaultwarden = {
    containers.vaultwarden = {
      volumes = [
        "${config.sops.secrets."vaultwarden/admin_token".path}:/run/secrets/admin_token"
      ];
      extraEnv = {
        ADMIN_TOKEN_FILE = "/run/secrets/admin_token";
      };
    };
  };
}
```

To simplify this, there is a wrapper option `fileEnvMount` available:

```nix
{config, ...}: {
  nps.stacks.vaultwarden = {
    containers.vaultwarden.fileEnvMount = {
      ADMIN_TOKEN_FILE = config.sops.secrets."vaultwarden/admin_token".path;
    };
  };
}
```

The file will be automatically added as a volume and the `ADMIN_TOKEN_FILE` environment variable will point to the path of the file within the container.

# Templating

nix-podman-stacks also has some extensions that allow templating of environment variables, as well as files that are mounted as volumes.
This can for example be useful when you don't want to store entire files/variables as a secret, but just parts of it.

## Environment Variables

To template environment variables, the `extraEnv` option of a container can be used again.

```nix

{config, ...}:
let
  cfg = config.nps.stacks.someStack;
in {
  nps.stacks.someStack = {
    containers.somedb.extraEnv = {
      DATABASE_URL = { fromTemplate = ''mysql://${cfg.db.username}:{{file.Read "${cfg.db.userPasswordFile}"}}@${dbName}/${cfg.db.databaseName}?charset=utf8mb4'' };
    };
  };
}
```

Setting the option `fromTemplate` will cause the string to be templated by [gomplate](https://github.com/hairyhenderson/gomplate).
Similar to the `fromFile` option, the `ExecStartPre` hook will be used to dynamically construct a new environment file with the templated values. Make sure that the output of the template is only a single line. Multi-line outputs might result in invalid environment files.

## Volumes

Files that are mounted as volumes can also be templated first before they are being mounted.
This can for example be used to hydrate a file with secrets before it's being mounted into the container.

For this purpose, nix-podman-stacks adds a `templateMount` container option, that wraps & enhances the existing `volumes` option:

```nix
{config, ...}:{
  nps.stacks.guacamole = {
    containers.guacamole.templateMount = [
      {
        templatePath = pkgs.writeText "user-mapping.xml" ''
          <user-mapping>
            <authorize username="someuser" password="{{ file.Read `${config.sops.secrets."guacamole/password".path}` }}">
                <connection name="Host SSH">
                    <protocol>ssh</protocol>
                    <param name="hostname">host.containers.internal</param>
                    <param name="port">22</param>
                    <param name="username">someuser</param>
                    <param name="private-key">{{ file.Read `${config.sops.secrets."guacamole/ssh_private_key".path}` }}</param>
                    <param name="command">bash</param>
                </connection>
            </authorize>
          </user-mapping>
          '';
        destPath = "/etc/guacamole/user-mapping.xml";
      }
    ];
  };
}
```

Similar to previous example, the template will be rendered by [gomplate](https://github.com/hairyhenderson/gomplate) before being mounted to the `destPath` inside the container.
