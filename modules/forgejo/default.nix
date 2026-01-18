{
  config,
  lib,
  pkgs,
  ...
}: let
  name = "forgejo";
  dbName = "${name}-db";

  storage = "${config.nps.storageBaseDir}/${name}";
  cfg = config.nps.stacks.${name};

  ini = pkgs.formats.ini {};

  category = "General";
  displayName = "Forgejo";
  description = "Git Server";
in {
  imports = import ../mkAliases.nix config lib name [name];

  options.nps.stacks.${name} = {
    enable = lib.mkEnableOption name;
    lfsJwtSecretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the LFS JWT secret.
        Can be generated using `forgejo generate secret LFS_JWT_SECRET`.

        See <https://forgejo.org/docs/next/admin/config-cheat-sheet/#server-server>
      '';
    };
    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the global secret key.
        Can be generated using `forgejo generate secret SECRET_KEY`.

        See <https://forgejo.org/docs/latest/admin/config-cheat-sheet/#security-security>
      '';
    };
    internalTokenFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the internal token.
        Can be generated using `forgejo generate secret INTERNAL_TOKEN`.

        See <https://forgejo.org/docs/latest/admin/config-cheat-sheet/#security-security>
      '';
    };
    jwtSecretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the OAuth2 jwt secret. This is needed, even if OAuth2 is not used.
        See <https://codeberg.org/forgejo/forgejo/issues/4570> for more information.

        Can be generated using `forgejo generate secret JWT_SECRET`.

        See <https://forgejo.org/docs/latest/admin/config-cheat-sheet/#oauth2-oauth2>
      '';
    };
    adminProvisioning = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to automatically create an admin user on the first run.
          If set to false, an admin user can be manually created using the `forgejo` cli.

          See <https://forgejo.org/docs/next/admin/command-line/#admin-user-create>
        '';
      };
      username = lib.mkOption {
        type = lib.types.addCheck lib.types.str (s: s != "admin");
        default = "forgejo";
        description = "Username for the admin user. Cannot be `admin` as that name is reserved.";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Email address for the admin user ";
      };
      passwordFile = lib.mkOption {
        type = lib.types.path;
        default = null;
        description = "Path to a file containing the admin password";
      };
    };
    settings = lib.mkOption {
      type = lib.types.nullOr ini.type;
      default = null;
      apply = settings:
        if (settings != null)
        then ini.generate "app.ini" settings
        else null;
      description = ''
        Additional app settings for Forgejo.
        For a full list of options, refer to the [Forgejo documentation](https://forgejo.org/docs/latest/admin/config-cheat-sheet/).
      '';
    };
    db = {
      type = lib.mkOption {
        type = lib.types.enum [
          "sqlite"
          "postgres"
        ];
        default = "sqlite";
        description = ''
          Type of the database to use.
          Can be set to "sqlite" or "postgres".
          If set to "postgres", the `passwordFile` option must be set.
        '';
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "foregejo";
        description = ''
          The PostgreSQL user to use for the database.
          Only used if db.type is set to "postgres".
        '';
      };
      passwordFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          The file containing the PostgreSQL password for the database.
          Only used if db.type is set to "postgres".
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nps.stacks.${name}.settings = lib.mkMerge [
      (import ./settings.nix config)
      {
        server.FS_JWT_SECRET = "{{ file.Read `${cfg.lfsJwtSecretFile}` }}";
        security.SECRET_KEY = "{{ file.Read `${cfg.secretKeyFile}` }}";
        security.INTERNAL_TOKEN = "{{ file.Read `${cfg.internalTokenFile}` }}";
        oauth2.JWT_SECRET = "{{ file.Read `${cfg.jwtSecretFile}` }}";
      }
      (lib.mkIf (cfg.db.type == "sqlite") {
        database = {
          PATH = "/data/gitea/gitea.db";
          DB_TYPE = "sqlite3";
        };
      })
      (lib.mkIf (cfg.db.type == "postgres") {
        database = {
          DB_TYPE = "postgres";
          HOST = "${dbName}:5432";
          NAME = "forgejo";
          USER = cfg.db.username;
          PASSWD = "{{ file.Read `${cfg.db.passwordFile}` }}";
        };
      })
    ];

    services.podman.containers = {
      ${name} = {
        image = "codeberg.org/forgejo/forgejo:14";
        volumes = [
          "${storage}/data:/data"
        ];

        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "curl -s -f http://localhost:3000 || exit 1";
          HealthInterval = "10s";
          HealthTimeout = "10s";
          HealthRetries = 5;
          HealthStartPeriod = "5s";
        };
        extraConfig.Service.ExecStartPost =
          lib.mkIf (cfg.adminProvisioning.enable)
          [
            (
              lib.getExe (
                pkgs.writeShellScriptBin "forgejo-admin-user-create"
                (
                  lib.concatStringsSep
                  " "
                  [
                    "${lib.getExe config.nps.package} exec -u git"
                    "forgejo forgejo -c /data/gitea/conf/app.ini admin user create"
                    "--username ${cfg.adminProvisioning.username}"
                    "--email ${cfg.adminProvisioning.email}"
                    "--password $(cat ${cfg.adminProvisioning.passwordFile})"
                    "|| exit 0"
                  ]
                )
              )
            )
          ];

        # Use template mount instead of "_URI" settings, as app.ini has to be writable anyways
        templateMount = lib.optional (cfg.settings != null) {
          templatePath = cfg.settings;
          destPath = "/data/gitea/conf/app.ini";
          chown = {
            user = "1000";
            group = "1000";
          };
        };

        ports = ["222:22"];

        stack = name;
        port = 3000;
        traefik.name = name;
        homepage = {
          inherit category;
          name = displayName;
          settings = {
            inherit description;
            icon = "forgejo";
          };
        };
        glance = {
          inherit category description;
          name = displayName;
          id = name;
          icon = "di:forgejo";
        };
      };

      ${dbName} = lib.mkIf (cfg.db.type == "postgres") {
        image = "docker.io/postgres:18";
        volumes = ["${storage}/postgres:/var/lib/postgresql"];
        extraEnv = {
          POSTGRES_DB = "forgejo";
          POSTGRES_USER = cfg.db.username;
          POSTGRES_PASSWORD.fromFile = cfg.db.passwordFile;
        };

        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "pg_isready -d forgejo -U ${cfg.db.username}";
          HealthInterval = "10s";
          HealthTimeout = "10s";
          HealthRetries = 5;
          HealthStartPeriod = "10s";
        };

        stack = name;
        glance = {
          parent = name;
          name = "Postgres";
          icon = "di:postgres";
          inherit category;
        };
      };
    };
  };
}
