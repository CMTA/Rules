# Contributing Guidelines

There are many ways to contribute to Rules Contracts.

## Development branch

If you want to propose some improvement to the codebase, use the current development branch `dev` to perform the modification.

## Opening an issue

You can [open an issue] to suggest a feature, a difficulty you have or report a minor bug. For serious bugs in an audited version please do not open an issue, instead refer to our [security policy] for appropriate steps. See [SECURITY.md](https://github.com/CMTA/CMTAT/blob/master/SECURITY.md) in CMTAT project.

Before opening an issue, be sure to search through the existing open and closed issues, and consider posting a comment in one of those instead.

When requesting a new feature, include as many details as you can, especially around the use cases that motivate it.

## Submitting a pull request

If you would like to contribute code or documentation you may do so by forking the repository and submitting a pull request.

Run linter and tests to make sure your pull request is good before submitting it.

## Code conventions (rules)

- Each rule has an `InvariantStorage` abstract contract holding its constants, custom errors, and events.
- Access control is implemented via an abstract `_authorize*()` method overridden by concrete subclasses (template method pattern).
- AccessControl variants must use `onlyRole(ROLE)` in `_authorize*()` methods (avoid direct `_checkRole`).
- All `internal` functions should be marked `virtual`.
- Use `require(condition, CustomError(...))` for custom errors; avoid direct `revert CustomError(...)`.
- Keep `AGENTS.md` and `CLAUDE.md` in sync when updating guidance.



## Reference

Based on the version made by [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/CONTRIBUTING.md)
