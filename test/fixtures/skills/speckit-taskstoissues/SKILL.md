---
description: Convert tasks into GitHub issues.
---

# Spec Kit: Tasks to Issues (stock-shaped fixture)

## Outline

1. From the executed script, extract the path to **tasks**.
1. Get the Git remote by running `git config --get remote.origin.url`.

1. For each task in the list, use the GitHub MCP server to create a new issue in the repository that is representative of the Git remote.

> [!CAUTION]
> UNDER NO CIRCUMSTANCES EVER CREATE ISSUES IN REPOSITORIES THAT DO NOT MATCH THE REMOTE URL
