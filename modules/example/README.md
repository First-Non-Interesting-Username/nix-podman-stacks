# Example Stack

This module serves as an exemplary stack, designed primarily as a structural blueprint for future contributions.

Please note that this blueprint is optimized for straightforward, standard services. Should your service require complex configurations, such as external YAML files, I recommend examining other existing modules or creating a custom solution.

## Service Implementation Checklist

- [ ] **Verify Existence**: Ensure the service has not already been implemented.
- [ ] **Documentation Review**: Thoroughly consult the service's docs, paying particular attention to:
  - [ ] User Accounts {32}
  - [ ] OIDC Integration (Availability and URI authentication endpoints) {117}
  - [ ] Default Configuration Paths {145}
  - [ ] Required Environment Variables {153, 160}
  - [ ] WebUI Port (if applicable) {170}
  - [ ] Database Compatibility (Supported types and specific requirements) {192}
- [ ] **Implementation**:
  - [ ] Duplicate the `modules/example` directory.
  - [ ] Apply the information gathered during the documentation review. Note: The bracketed numbers `{}` indicate the corresponding lines or blocks requiring modification in `default.nix`.
  - [ ] Edit the `default.nix` file, following the comments and instructions.
  - [ ] Add your module to `modules/module_list.nix` and `ci_config.nix`.
  - [ ] Update the "About" section below.

**Note:** Please delete the content above this line before submitting a PR.

{One sentence description of the service}

- [Github](Source code of the service)
- [Website](Website of the service)

## Example

```nix
{
  nps.stacks.example = {
    enable = true;
    oidc = {
      registerClient = true;
      clientSecretHash = "$pbkdf2-sha512$...";
    };
  };
}
```