# Contributing

Bee is an open-source project committed to bringing LLM agents to
people of all backgrounds. This page describes how you can join the Bee
community in this goal.

## Before you start

If you are new to Bee contributing, we recommend you do the following before diving into the code:

- Read [Code of Conduct](./CODE_OF_CONDUCT.md).

## Set up a development environment

To start contributing to this project, follow "Run examples" setup instructions in [README](README.md#run-examples-) and
install pre-commit. Make sure to execute all git commands within the project poetry environment.

1. **Setup environment:** Activate environment and pre-commit checks

```bash
poetry install # Install dependencies
poetry shell # activate virtual environment
pre-commit install

# Setup env variables
cp env.example .env
vim .env # Fill secrets for testing (Bee API key)
```

2. **Run linters and formatters:**

```shell
poe lint
poe format
```

3. **Run Tests:** Ensure your changes pass all tests. Run the following command:

```shell
poe test
```

By following these steps, you'll be all set to contribute to our project! If you encounter any issues during the setup
process, please feel free to open an issue.

## Style and lint

This project uses the following tools to meet code quality standards and ensure a unified code style across the
codebase.

- [ruff](https://docs.astral.sh/ruff/) - Linter and formatter
- [pre-commit](https://pre-commit.com/) - Various other formatting checks
- [commitizen](https://commitizen-tools.github.io/commitizen/) - Lint commit messages according to
  [Conventional Commits](https://www.conventionalcommits.org/).

## Issues and pull requests

We use GitHub pull requests to accept contributions.

While not required, opening a new issue about the bug you're fixing or the feature you're working on before you open a
pull request is important in starting a discussion with the community about your work. The issue gives us a place to
talk about the idea and how we can work together to implement it in the code. It also lets the community know what
you're working on, and if you need help, you can reference the issue when discussing it with other community and team
members.

If you've written some code but need help finishing it, want to get initial feedback on it before finishing it, or want
to share it and discuss it prior to completing the implementation, you can open a Draft pull request and prepend the
title with the [WIP] tag (for Work In Progress). This will indicate to reviewers that the code in the PR isn't in its
final state and will change. It also means we will only merge the commit once it is finished. You or a reviewer can
remove the [WIP] tag when the code is ready to be thoroughly reviewed for merging.

## Legal

The following sections detail important legal information that should be viewed prior to contribution.

### License and Copyright

Distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

SPDX-License-Identifier: [Apache-2.0](https://spdx.org/licenses/Apache-2.0)

If you would like to see the detailed LICENSE click [here](LICENSE).

### Developer Certificate of Origin (DCO)

We have tried to make it as easy as possible to make contributions. This applies to how we handle the legal aspects of
contribution. We use the same approach - the
[Developer's Certificate of Origin 1.1 (DCO)](https://developercertificate.org/) - that the Linux® Kernel
[community](https://docs.kernel.org/process/submitting-patches.html#sign-your-work-the-developer-s-certificate-of-origin)
uses to manage code contributions.

We ask that when submitting a patch for review, the developer must include a sign-off statement in the commit message.
If you set your `user.name` and `user.email` in your `git config` file, you can sign your commit automatically by using
the following command:

```shell
git commit -s
```

The following example includes a `Signed-off-by:` line, which indicates that the submitter has accepted the DCO:

```text
Signed-off-by: John Doe <john.doe@example.com>
```

We automatically verify that all commit messages contain a `Signed-off-by:` line with your email address.

#### Useful tools for doing DCO signoffs

There are a number of tools that make it easier for developers to manage DCO signoffs.

- DCO command line tool, which let's you do a single signoff for an entire repo ( <https://github.com/coderanger/dco> )
- GitHub UI integrations for adding the signoff automatically ( <https://github.com/scottrigby/dco-gh-ui> )
- Chrome - <https://chrome.google.com/webstore/detail/dco-github-ui/onhgmjhnaeipfgacbglaphlmllkpoijo>
- Firefox - <https://addons.mozilla.org/en-US/firefox/addon/scott-rigby/?src=search>
