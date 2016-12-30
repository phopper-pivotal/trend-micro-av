# A bosh add-on for Trend Micro Deep Security Agent

Supports **only** Ubuntu 14.04 Trustg version of Trend Micro's Deep Security Agennt.

## Trend Micro's Deep Security bosh add-ons - runtime config
### clone this repository
### create the runtime config
```yaml
releases:
- {name: trend-micro, version: 9.6.2}

addons:
- name: trend-micro-anti-virus
  jobs:
  - name: trend-micro
    release: trend-micro
```
### update runtime config
### view runtime config changes
### bosh deploy runtime config
### troubleshoot deployment of addon
### notes
