{
  config,
  lib,
  ...
}: let
  name = "norish";
  dbName = "${name}-db";
  browserName = "${name}-browser";
  redisName = "${name}-redis";

  storage = "${config.nps.storageBaseDir}/${name}";
  cfg = config.nps.stacks.${name};

  category = "General";
  displayName = "Norish";
  description = "Recipe Management";
in {
  imports = import ../mkAliases.nix config lib name [name browserName];

  options.nps.stacks.${name} = {
    enable = lib.mkEnableOption name;
    masterKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the file containing the master encryption key. Can be generated with `openssl rand -base64 32`.
        See <https://github.com/norish-recipes/norish?tab=readme-ov-file#required-variables>
      '';
    };
    db = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "norish";
        description = "Database user name";
      };
      passwordFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to the file containing the database password";
      };
    };
    oidc = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable OIDC login with Authelia. This will register an OIDC client in Authelia
          and setup the necessary configuration.

          For details, see:

          - <https://www.authelia.com/integration/openid-connect/clients/karakeep/>
          - <https://docs.karakeep.app/configuration/#authentication--signup>
        '';
      };
      clientSecretFile = lib.mkOption {
        type = lib.types.str;
        description = ''
          The file containing the client secret for the OIDC client that will be registered in Authelia.
        '';
      };
      clientSecretHash = lib.mkOption {
        type = lib.types.str;
        description = ''
          The hashed client_secret. Will be set in the Authelia client config.
          For examples on how to generate a client secret, see

          <https://www.authelia.com/integration/openid-connect/frequently-asked-questions/#client-secret>
        '';
      };
      userGroup = lib.mkOption {
        type = lib.types.str;
        default = "${name}_user";
        description = "Users of this group will be able to log in";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nps.stacks.lldap.bootstrap.groups = lib.mkIf cfg.oidc.enable {
      ${cfg.oidc.userGroup} = {};
    };

    nps.stacks.authelia = lib.mkIf cfg.oidc.enable {
      oidc.clients.${name} = {
        client_name = displayName;
        client_secret = cfg.oidc.clientSecretHash;
        public = false;
        authorization_policy = name;
        #claims_policy = name;
        require_pkce = true;
        pkce_challenge_method = "S256";
        pre_configured_consent_duration = config.nps.stacks.authelia.oidc.defaultConsentDuration;
        redirect_uris = [
          "${cfg.containers.${name}.traefik.serviceUrl}/api/auth/oauth2/callback/oidc"
        ];
        token_endpoint_auth_method = "client_secret_post";
      };

      # See <https://www.authelia.com/integration/openid-connect/openid-connect-1.0-claims/#restore-functionality-prior-to-claims-parameter>
      settings.identity_providers.oidc.claims_policies.${name}.id_token = [
        "email"
        "email_verified"
        "alt_emails"
        "preferred_username"
        "name"
      ];

      # Norish doesn't have any Group/Claim based RBAC yet, so we have to do in on Authelia level
      # See <https://github.com/karakeep-app/karakeep/issues/1525>
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
        image = "docker.io/norishapp/norish:v0.14.1-beta";
        user = "${toString config.nps.defaultUid}:${toString config.nps.defaultGid}";
        volumes = [
          "${storage}/data:/app/uploads"
        ];

        extraEnv =
          {
            AUTH_URL = cfg.containers.${name}.traefik.serviceUrl;
            DATABASE_URL.fromTemplate = "postgres://${cfg.db.username}:{{ file.Read `${cfg.db.passwordFile}` }}@${dbName}/norish?sslmode=disable";
            MASTER_KEY.fromFile = cfg.masterKeyFile;
            REDIS_URL = "redis://${redisName}:6379";
            CHROME_WS_ENDPOINT = "ws://${browserName}:3000";
          }
          // lib.optionalAttrs cfg.oidc.enable {
            OIDC_NAME = "Authelia";
            OIDC_ISSUER = config.nps.containers.authelia.traefik.serviceUrl;
            OIDC_CLIENT_ID = name;
            OIDC_CLIENT_SECRET.fromFile = cfg.oidc.clientSecretFile;
          };

        dependsOnContainer = [dbName redisName];
        wantsContainer = [browserName];

        stack = name;
        port = 3000;
        traefik.name = name;
        homepage = {
          inherit category;
          name = displayName;
          settings = {
            inherit description;
            icon = "sh-norish";
          };
        };
        glance = {
          inherit category description;
          name = displayName;
          id = name;
          icon = "sh:norish";
        };
      };

      ${dbName} = {
        image = "docker.io/postgres:18";
        volumes = ["${storage}/postgres:/var/lib/postgresql"];

        extraEnv = {
          POSTGRES_DB = "norish";
          POSTGRES_USER = cfg.db.username;
          POSTGRES_PASSWORD.fromFile = cfg.db.passwordFile;
        };

        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "pg_isready -d norish -U ${cfg.db.username}";
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

      ${browserName} = {
        image = "docker.io/zenika/alpine-chrome:124";
        addCapabilities = ["SYS_ADMIN"];
        exec = lib.concatStringsSep " " [
          "--no-sandbox"
          "--disable-gpu"
          "--disable-dev-shm-usage"
          "--remote-debugging-address=0.0.0.0"
          "--remote-debugging-port=3000"
          "--headless"
        ];

        stack = name;
        glance = {
          inherit category;
          parent = name;
          name = "Chrome";
          icon = "di:chrome";
        };
      };

      ${redisName} = {
        image = "docker.io/redis:8";

        stack = name;
        extraConfig.Container = {
          Notify = "healthy";
          HealthCmd = "redis-cli ping";
          HealthInterval = "10s";
          HealthTimeout = "10s";
          HealthRetries = 5;
          HealthStartPeriod = "10s";
        };

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
