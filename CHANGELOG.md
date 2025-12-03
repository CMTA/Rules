# CHANGELOG

Please follow [https://changelog.md/](https://changelog.md/) conventions.

## Checklist

> Before a new release, perform the following tasks

- Code: Update the version name, variable VERSION
- Run linter

> npm run-script lint:all:prettier

- Documentation
  - Perform a code coverage and update the files in the corresponding directory [./doc/coverage](./doc/coverage)
  - Perform an audit with several audit tools (Mythril and Slither), update the report in the corresponding directory [./doc/security/audits/tools](./doc/security/audits/tools)
  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script)
  - Update changelog

## v0.1.0

First release !
