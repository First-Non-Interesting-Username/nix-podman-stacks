lib:
with lib;
with types; rec {
  nullableClientSecretType = nullOr clientSecretType;

  clientSecretType = either str (submodule {
    options = {
      fromFile = lib.mkOption {
        type = nullOr path;
        default = null;
        description = "Path to file containing the client secret hash.";
      };
      toHash = lib.mkOption {
        type = nullOr path;
        default = null;
        description = "Path to file containing the client secret. The file content will be hashed automatically before being passed to Authelia.";
      };
    };
  });

  clientSecretFile = mkOption {
    type = str;
    example = lib.literalExpression ''config.sops.secrets."immich/authelia/client_secret".path"'';
    description = ''
      The file containing the client secret for the OIDC client that will be registered in Authelia.

      For examples on how to generate a client secret, see

      <https://www.authelia.com/integration/openid-connect/frequently-asked-questions/#client-secret>
    '';
  };

  clientSecretHash = mkOption {
    type = clientSecretType;
    example = ''$pbkdf2-sha512$310000$vV9QrLSHV.vUrX2EpUC/ig$spbmTFMnl0vWFlILOTDsGPv.kFpFnX7OxFcZBSPqp9k0RilwGtEWbgJcta8AfFgEuT7sJmEi2WBQ9t0WSEZSiA'';
    description = ''
      The client secret hash.
      For examples on how to generate a client secret, see

      <https://www.authelia.com/integration/openid-connect/frequently-asked-questions/#client-secret>

      The value can be passed in multiple ways:

      1. As a literal string, e.g. `$pbkdf2-sha512$...`
      2. As an absolute path to a file containing the hash, e.g. `{ fromFile = "/run/secrets/client_secret_hash" };`
      3. As an absolute oath to a file containing the client_secret, in which case the hash will be automatically computed: `{ toHash = "/run/secrets/client_secret" };`
    '';
  };

  derivableClientSecretHash = clientSecretFile:
    mkOption {
      type = nullableClientSecretType;
      default = null;
      example = ''$pbkdf2-sha512$310000$vV9QrLSHV.vUrX2EpUC/ig$spbmTFMnl0vWFlILOTDsGPv.kFpFnX7OxFcZBSPqp9k0RilwGtEWbgJcta8AfFgEuT7sJmEi2WBQ9t0WSEZSiA'';
      description = ''
        The client secret hash.
        For examples on how to generate a client secret, see
        <https://www.authelia.com/integration/openid-connect/frequently-asked-questions/#client-secret>

        The value can be passed in multiple ways:

        1. As a literal string, e.g. `$pbkdf2-sha512$...`
        2. As an absolute path to a file containing the hash, e.g. `{ fromFile = "/run/secrets/client_secret_hash" };`
        3. As an absolute path to a file containing the client_secret, in which case the hash will be automatically computed: `{ toHash = "/run/secrets/client_secret" };`
        4. As `null`

        If left unset (`null`), the client secret will be read from the file specified in the `clientSecretFile` option and hashed automatically before being passed to the Authelia container.
      '';
      apply = v:
        if v == null
        then {
          toHash = clientSecretFile;
        }
        else v;
    };
}
