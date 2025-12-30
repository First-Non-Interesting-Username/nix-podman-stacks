lib:
with lib;
with types; rec {
  fromFileOrTemplateSubmodule = (
    submodule (
      {config, ...}: {
        options = {
          fromFile = mkOption {
            type = nullOr path;
            default = null;
            description = "Path to file containing the variable value.";
            example = "/path/to/file.txt";
          };
          fromTemplate = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              Template string to be used with the file content.
              The template will be processed with `gomplate`, which allows you to access environment variables, read file contents and more.

              When used in the `extraEnv` option to set environment variables, make sure the templated value results in a single line.

              See

              - <https://docs.gomplate.ca/>
              - <https://github.com/hairyhenderson/gomplate>
            '';
            example = ''DB_URL={{ env.getEnv `DB_USERNAME` }}:{{ file.Read `/run/secrets/db_password` }}@localhost:5432/mydb'';
          };
          fromCommand = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              Command to be executed to obtain the variable value.

              When used in the `extraEnv` option to set environment variables, make sure the command outputs a single line.
            '';
            example = "cat /run/secrets/api_key";
          };
        };
      }
    )
  );

  primitiveOrSubmodule = (
    oneOf [
      bool
      int
      str
      path

      # Can't use oneOf [fromFileSubmodule fromTemplateSubmodule] unfortunately
      # See https://discourse.nixos.org/t/problems-with-types-oneof-and-submodules/15197
      fromFileOrTemplateSubmodule
    ]
  );

  # Allow null values, so env variables can be unset when overwritten
  extraEnv = attrsOf (nullOr primitiveOrSubmodule);
}
