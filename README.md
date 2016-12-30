# A bosh add-on for Trend Micro Deep Security Agent

Supports **only** Ubuntu 14.04 Trusty version of Trend Micro's Deep Security Agennt.

##  clone this repository
Let's clone this repository so that we can create bosh releases ourselves, and make changes as needed.
```
git clone https://github.com/phopper-pivotal/trend-micro-av.git
``` 
## create a bosh release
We will need to create a bosh release for this addon.
```
% cd trend-micro-av

% bosh create release
```
## Trend Micro's Deep Security bosh add-ons - runtime config
###
### create the runtime config
We will need to create the bosh addon runtime configuration.
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
