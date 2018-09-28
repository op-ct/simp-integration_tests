[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-integration_tests.svg)](https://travis-ci.org/simp/pupmod-simp-integration_tests) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-6.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-6.*-orange.svg)

#### Table of Contents
<!-- vim-markdown-toc GFM -->

* [Description](#description)
  * [This is a SIMP project](#this-is-a-simp-project)
* [Setup](#setup)
  * [Setup Requirements](#setup-requirements)
    * [SIMP Vagrant boxes](#simp-vagrant-boxes)
* [Usage](#usage)
  * [Basic usage](#basic-usage)
    * [Preferred](#preferred)
    * [Alternative](#alternative)
    * [Optional settings](#optional-settings)
  * [Beaker Suites](#beaker-suites)
    * [`default`](#default)
    * [`upgrade`](#upgrade)
      * [Special Requirements](#special-requirements)
* [Troubleshooting](#troubleshooting)
  * [Inspecting troubled beaker VMs using  VRDE (RDP)](#inspecting-troubled-beaker-vms-using--vrde-rdp)
* [Development](#development)

<!-- vim-markdown-toc -->

## Description

Automated integration tests for SIMP.

Uses Beaker suites from [`simp-beaker-helpers`][simp-beaker-helpers] and
Vagrant boxes built by [`simp-packer`][simp-packer].

### This is a SIMP project

This module is a tests components of the [System Integrity Management
Platform][simp].

If you find any issues, submit them to our [bug tracker][simp-jira].

## Setup

### Setup Requirements

* [VirtualBox][virtualbox]
* [Vagrant][vagrant]
* [SIMP] Vagrant box files (`.box` and `.json`), built by
  [simp-packer][simp-packer] and its rake tasks

#### SIMP Vagrant boxes

It is **strongly** recommended to keep the SIMP Vagrant box files in
a `vagrant`-consumable directory tree. This will allow Vagrant and Beaker to
use detect and use the latest (or a specific) build of a particular SIMP
release.

There are rake tasks in [simp-packer][simp-packer] to create/populate this
directory tree:

* The [simp-packer][simp-packer] rake task `rake vagrant:publish:local` will
  create/populate a local directory tree from a `.box` and `.json` file.
* The [simp-packer][simp-packer] rake task `simp:packer:matrix` will also
  create and populate this directory tree as it builds various boxes.


## Usage

### Basic usage

#### Preferred

```sh
BEAKER_vagrant_box_tree=$PATH_TO_VAGRANT_BOXES_DIRTREE \
BEAKER_box__puppet="simpci/server-6.2.0-RC1.el7-CentOS-7.0.x86-64" \
  bundle exec rake beaker:suites
```

#### Alternative
An alternative method, if you only have a Vagrant `.box` + `.json` file but no
directory tree set up:

```sh
BEAKER_box__puppet="$direct_path_to/server-6.2.0-RC1.el7-CentOS-7.0.x86-64.json" \
  bundle exec rake beaker:suites
```

#### Optional settings

You can force an SUT's platform by setting `BEAKER_box_platform__<sut>`:

```sh
BEAKER_box_platform__puppet=el-7-x86_64
```

### Beaker Suites

#### `default`

The default test suite currently just contains a smoke test to ensure that
beaker can bring up a Vagrant box and run `puppet apply`

Usage:

```sh
BEAKER_vagrant_box_tree=$vagrant_boxes_dir \
BEAKER_box__puppet="simpci/server-6.2.0-RC1.el7-CentOS-6.9.x86-64" \
  bundle exec rake beaker:suites[default]
```

#### `upgrade`

The **`upgrade`** suite validates the SIMP user guide's [General Upgrade
Instructions for incremental upgrades][u0] by upgrading an older version of
SIMP.  It:

1. Uploads a newer SIMP version's `.iso` file from the host filesystem into the
   puppetserver SUT.
  - Uploads any `*.noarch.rpm` files from the local project's directory into
    the puppet server's yum repository before running `unpack_dvd`
2. Runs `unpack_dvd`
3. Runs `yum update -y`
4. Runs `puppet agent -t`

Usage:

```sh
BEAKER_vagrant_box_tree=$vagrant_boxes_dir \
BEAKER_box__puppet="simpci/SIMP-6.1.0-0-Powered-by-CentOS-7.0-x86_64" \
BEAKER_upgrade__new_simp_iso_path=$PWD\SIMP-6.2.0-RC1.el6-CentOS-7.0-x86_64.iso 
  bundle exec rake beaker:suites[upgrade]
```

[u0]: https://github.com/simp/simp-doc/blob/8277eab/docs/user_guide/Upgrade_SIMP/General_Upgrade_Instructions.rst#incremental-updates

##### Special Requirements

Because the `upgrade` suite starts from an older version of SIMP, its
requirements work a little differently from normal integration tests:

| Environment variable                | Description                                          |
| ----------------------------------- | ---------------------------------------------------- |
| `BEAKER_box__puppet`                | A Vagrant box tag from a _previous_ version of SIMP. |
| `BEAKER_upgrade__new_simp_iso_path` | Path to the current version of SIMP's `.iso` file(s) |




## Troubleshooting

### Inspecting troubled beaker VMs using  VRDE (RDP)

* VirtualBox must have the appropriate version of the [VirtualBox Extension Pack][vb-extpack]
* Turn on VRDE :
```sh
vboxmanage list runningvms
### => defaultyml_puppet_1536852168210_13152" {331df311-52c6-4471-b912-f730d8531e0c}

vboxmanage controlvm "defaultyml_puppet_1536852168210_13152" vrde on
vboxmanage controlvm "defaultyml_puppet_1536852168210_13152" vrdeport 5940
```
* Connect to VRDE using a Remote Desktop client


## Development

Please read our [Contribution Guide][simp-contrib].

[simp]:                     https://github.com/NationalSecurityAgency/SIMP
[simp-contrib]:             https://simp.readthedocs.io/en/master/contributors_guide/
[simp-jira]:                https://simp-project.atlassian.net
[simp-beaker-helpers]:      https://github.com/simp/rubygem-simp-beaker-helpers
[simp-beaker-helpers-docs]: https://github.com/simp/rubygem-simp-beaker-helpers/
[simp-packer]:              https://github.com/simp/simp-packer
[vagrant]:                  https://www.vagrantup.com
[virtualbox]:               https://www.virtualbox.org/wiki/Downloads
[vb-extpack]:               https://www.virtualbox.org/wiki/Downloads#VirtualBox5.2.18OracleVMVirtualBoxExtensionPack
