# Security Policy

## Supported Versions

CardWise is an actively developed iOS app. Security fixes land on the latest
released version; please make sure you are running the newest build before
reporting an issue.

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security problems.

Instead, report privately via one of:

- GitHub's [private vulnerability reporting](https://github.com/tmj-studio/CardWise/security/advisories/new)
- Email: support@cardwiseapp.com

Include steps to reproduce, the affected version, and any relevant logs. We aim
to acknowledge reports within a few business days and will keep you updated as we
investigate and ship a fix.

## Scope notes

CardWise is fully on-device: it has no backend servers, requires no account, and
stores no credit card numbers, CVVs, or other sensitive financial data. User data
lives on-device and syncs only through the user's own private iCloud (CloudKit).
