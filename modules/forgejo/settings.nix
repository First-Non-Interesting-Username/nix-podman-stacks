config: let
  cfg = config.nps.stacks.forgejo;
in {
  DEFAULT = {
    APP_NAME = "Forgejo";
    RUN_MODE = "prod";
    APP_SLOGAN = "Beyond coding. We Forge.";
    RUN_USER = "git";
    WORK_PATH = "/data/gitea";
  };

  repository = {
    ROOT = "/data/git/repositories";
  };

  "repository.local" = {
    LOCAL_COPY_PATH = "/data/gitea/tmp/local-repo";
  };

  "repository.upload" = {
    TEMP_PATH = "/data/gitea/uploads";
  };

  server = {
    APP_DATA_PATH = "/data/gitea";
    DOMAIN = cfg.containers.forgejo.traefik.serviceHost;
    SSH_DOMAIN = cfg.containers.forgejo.traefik.serviceHost;
    HTTP_PORT = 3000;
    ROOT_URL = cfg.containers.forgejo.traefik.serviceUrl;
    DISABLE_SSH = false;
    SSH_PORT = 2222;
    SSH_LISTEN_PORT = 22;
    LFS_START_SERVER = true;
    OFFLINE_MODE = true;
    LANDING_PAGE = "login";
  };

  indexer = {
    ISSUE_INDEXER_PATH = "/data/gitea/indexers/issues.bleve";
  };

  session = {
    PROVIDER = "file";
    PROVIDER_CONFIG = "/data/gitea/sessions";
  };

  picture = {
    AVATAR_UPLOAD_PATH = "/data/gitea/avatars";
    REPOSITORY_AVATAR_UPLOAD_PATH = "/data/gitea/repo-avatars";
  };

  attachment = {
    PATH = "/data/gitea/attachments";
  };

  log = {
    MODE = "console";
    LEVEL = "info";
    ROOT_PATH = "/data/gitea/log";
  };

  security = {
    INSTALL_LOCK = true;
    REVERSE_PROXY_LIMIT = 1;
    REVERSE_PROXY_TRUSTED_PROXIES = "*";
    PASSWORD_HASH_ALGO = "pbkdf2_hi";
  };

  service = {
    REQUIRE_SIGNIN_VIEW = false;
    REGISTER_EMAIL_CONFIRM = false;
    ENABLE_NOTIFY_MAIL = false;
    ENABLE_CAPTCHA = false;
    DEFAULT_KEEP_EMAIL_PRIVATE = false;
    DEFAULT_ALLOW_CREATE_ORGANIZATION = true;
    DEFAULT_ENABLE_TIMETRACKING = true;
    NO_REPLY_ADDRESS = "noreply.localhost";
  };

  lfs = {
    PATH = "/data/git/lfs";
  };

  mailer = {
    ENABLED = false;
  };

  "cron.update_checker" = {
    ENABLED = true;
  };

  "repository.pull-request" = {
    DEFAULT_MERGE_STYLE = "merge";
  };

  "repository.signing" = {
    DEFAULT_TRUST_MODEL = "committer";
  };
}
