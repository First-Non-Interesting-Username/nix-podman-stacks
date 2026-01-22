{
  config,
  lib,
  ...
}: let
  name = "adventurelog";
  webName = "${name}-web";
  backendName = "${name}-backend";
  dbName = "${name}-db";

  cfg = config.nps.stacks.${name};
  storage = "${config.nps.storageBaseDir}/${name}";

  category = "General";
  description = "Travel Companion";
  displayName = "AdventureLog";
in {
  imports = import ../mkAliases.nix config lib name [
    webName
    backendName
    dbName
  ];

  options.nps.stacks.${name} = {
    enable = lib.mkEnableOption name;
    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the file containing the Django secret key.
        Can be generated using `openssl rand -hex 32`

        See <https://adventurelog.app/docs/install/docker.html#%F0%9F%94%92-backend-server>
      '';
    };
    adminProvisioning = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Username for the admin user";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Email address for the admin user ";
      };
      passwordFile = lib.mkOption {
        type = lib.types.path;
        default = null;
        description = "Path to a file containing the admin user password";
      };
    };
    db = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "adventurelog";
        description = "Database user name";
      };
      passwordFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to the file containing the database password";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.podman.containers = {
      ${webName} = {
        image = "ghcr.io/seanmorley15/adventurelog-frontend:v0.11.0";

        environment = {
          PUBLIC_SERVER_URL = "http://${backendName}:8000";
          BODY_SIZE_LIMIT = "Infinity";
        };

        stack = name;
        port = 3000;
        traefik.name = name;
        homepage = {
          inherit category;
          name = displayName;
          settings = {
            inherit description;
            icon = "adventure-log";
          };
        };
        glance = {
          inherit category description;
          name = displayName;
          id = name;
          icon = "di:adventure-log";
        };
      };

      ${backendName} = {
        image = "ghcr.io/seanmorley15/adventurelog-backend:v0.11.0";
        volumes = [
          "${storage}/media:/code/media"
        ];

        extraEnv =
          rec {
            SECRET_KEY.fromFile = cfg.secretKeyFile;

            DJANGO_ADMIN_USERNAME = cfg.adminProvisioning.username;
            DJANGO_ADMIN_EMAIL = cfg.adminProvisioning.email;
            DJANGO_ADMIN_PASSWORD.fromFile = cfg.adminProvisioning.passwordFile;

            PUBLIC_URL = cfg.containers.${backendName}.traefik.serviceUrl;
            FRONTEND_URL = cfg.containers.${webName}.traefik.serviceUrl;
            CSRF_TRUSTED_ORIGINS = lib.concatStringsSep "," [PUBLIC_URL FRONTEND_URL];
          }
          // (let
            db = cfg.containers.${dbName};
          in {
            PGHOST = dbName;
            POSTGRES_DB = db.environment.POSTGRES_DB;
            POSTGRES_USER = db.environment.POSTGRES_USER;
            POSTGRES_PASSWORD.fromFile = cfg.db.passwordFile;
          });

        wantsContainer = [dbName];
        stack = name;
        port = 8000;
        traefik.name = backendName;
        glance = {
          inherit category;
          name = "Backend";
          parent = name;
          icon = "di:adventure-log";
        };
      };

      ${dbName} = {
        image = "docker.io/postgis/postgis:18-3.6-alpine";
        volumes = ["${storage}/postgres:/var/lib/postgresql"];

        extraEnv = {
          POSTGRES_DB = "adventurelog";
          POSTGRES_USER = cfg.db.username;
          POSTGRES_PASSWORD.fromFile = cfg.db.passwordFile;
        };

        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "pg_isready -d adventurelog -U ${cfg.db.username}";
          HealthInterval = "10s";
          HealthTimeout = "10s";
          HealthRetries = 5;
          HealthStartPeriod = "10s";
        };

        stack = name;
        glance = {
          inherit category;
          name = "Postgres";
          parent = name;
          icon = "di:postgres";
        };
      };
    };
  };
}
