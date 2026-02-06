{
  config,
  lib,
  ...
}: let
  # The name of your stack/service
  name = "example";
  cfg = config.nps.stacks.${name};

  # Databases, if you don't need them, delete or comment out these lines
  dbName = "${name}-db";
  redisName = "${name}-redis";

  # Comment out these lines if you wish
  storage = "${config.nps.storageBaseDir}/${name}";
  mediaStorage = "${config.nps.mediaStorageBaseDir}";

  # Metadata for Homepage and Glance
  category = "General";
  description = "Example Stack Description";
  displayName = "Example Stack";
in {
  imports = import ../mkAliases.nix config lib name [
    # Again, if you don't need databases, comment out dbName and redisName
    name
    dbName
    redisName
  ];

  options.nps.stacks.${name} = {
    enable = lib.mkEnableOption name;
    # Each service handles users differently, so you will need to determine the appropriate configuration.
    # In some (or most) cases you don't have to do anything
    # In cases where you need to declare a user, it will likely be set via environment variables.

    # If the service doesn't provide OIDC delete this block
    oidc = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable OIDC login with Authelia.
        '';
      };

      clientSecretFile = (import ../authelia/options.nix lib).clientSecretFile;
      clientSecretHash = (import ../authelia/options.nix lib).derivableClientSecretHash cfg.oidc.clientSecretFile;
       adminGroup = lib.mkOption {
        type = lib.types.str;
        default = "${name}_admin";
        description = "Users of this group will be assigned admin rights";
      };
      userGroup = lib.mkOption {
        type = lib.types.str;
        default = "${name}_user";
        description = "Users of this group will be able to log in";
      };
    };

    # Comment out or delete if not needed
    db = {
      type = lib.mkOption {
        type = lib.types.enum [
          "sqlite"
          "postgres"
        ];
        default = "sqlite";
        description = ''
          Type of the database to use. 
          If set to "postgres", the passwordFile option must be set.
          '';
      };

      passwordFile = lib.mkOption {
        type = lib.types.path;
        description = "The file containing the database password.";
      };
    };

    extraEnv = lib.mkOption {
      type = (import ../types.nix lib).extraEnv;
      default = {};
      description = ''
        Extra environment variables to set for the container.
        Variables can be either set directly or sourced from a file (e.g. for secrets).
      '';
    };

    # You can obviously add more options if you want/need
  };

  config = lib.mkIf cfg.enable {
    nps.stacks.lldap.bootstrap.groups = lib.mkIf cfg.oidc.enable {
      ${cfg.oidc.userGroup} = {};
      ${cfg.oidc.adminGroup} = {};
    };

    nps.stacks.authelia = lib.mkIf cfg.oidc.enable {
      oidc.clients.${name} = {
        client_name = displayName;
        client_secret = cfg.oidc.clientSecretHash;
        public = false;
        authorization_policy = name;
        require_pkce = true;
        pkce_challenge_method = "S256";
        redirect_uris = [
          # Make sure this is the correct URI for your service
          "${cfg.containers.${name}.traefik.serviceUrl}/oidc/callback"
        ];
      };

      settings.identity_providers.oidc.authorization_policies.${name} = {
        default_policy = "deny";
        rules = [
          {
            policy = config.nps.stacks.authelia.defaultAllowPolicy;
            subject = "group:${cfg.oidc.userGroup}";
          }
        ];
      };
    };

    services.podman.containers = {
      ${name} = {
        # Replace with the correct image
        image = "docker.io/example/image:latest";

        # At this point, you should know what to do if you don't need a database
        dependsOnContainer =
          lib.optional (cfg.db.type != "sqlite") dbName
          ++ [redisName];

        stack = name;

        volumeMap = {
          # Adjust if needed (needed)
          data = "${storage}/data:/app/data";
          config = "${storage}/config:/app/config";
          media = "${mediaStorage}:/media";
        };

        # Environment variables:
        # Readable in /nix/store
        environment = {
          APP_PORT = "8080";
          DB_TYPE = cfg.db.type;
          REDIS_HOST = redisName;
        };

        # Secrets
        extraEnv =
          {
            DB_HOST = lib.mkIf (cfg.db.type != "sqlite") dbName;
            DB_PASS.fromFile = lib.mkIf (cfg.db.type != "sqlite") cfg.db.passwordFile;

            OIDC_CLIENT_SECRET.fromFile = lib.mkIf cfg.oidc.enable cfg.oidc.clientSecretFile;
          }
          // cfg.extraEnv;

        # This is the internal (in container) port for this service
        port = 8080;
        traefik = {
          name = name;
        };
        homepage = {
          inherit category;
          name = displayName;
          settings = {
            inherit description;
            icon = "example-icon";
          };
        };

        glance = {
          inherit category description;
          name = displayName;
          id = name;
          icon = "di:react";
        };
      };

      # Delete or comment out if you don't need databases
      ${dbName} = lib.mkIf (cfg.db.type == "postgres") {
        image = "docker.io/postgres:16-alpine";
        stack = name;
        volumeMap = {
          data = "${storage}/db:/var/lib/postgresql/data";
        };
        extraEnv = {
          POSTGRES_DB = "example";
          POSTGRES_USER = "example";
          POSTGRES_PASSWORD.fromFile = cfg.db.passwordFile;
        };
        glance = {
          parent = name;
          name = "Postgres";
          icon = "di:postgres";
          inherit category;
        };
      };

      # Delete or comment out if you don't need redis
      ${redisName} = {
        image = "docker.io/redis:alpine";
        stack = name;
        glance = {
          parent = name;
          name = "Redis";
          icon = "di:redis";
          inherit category;
        };
      };
    };
  };
}
