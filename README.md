# Packaging for the Ribose yum repo

This is a set of scripts used to build packages for the
[Ribose yum repo](https://github.com/riboseinc/yum). While these tools
are in public (the built packages are public), they are not meant for
external use.


## Basic steps for building + uploading packages

### Prerequisites

This repo only builds packages defined in
the [Ribose rpm-specs repo](https://github.com/riboseinc/rpm-specs), and
the packages built are pushed to the
[Ribose yum repo](https://github.com/riboseinc/yum).

Make sure you have provided your package information that repo under
`$pkgname/` in the following format:

* `$pkgname/prepare.sh` is used to install all build-time dependencies
  including all `BuildRequires` packages.
* `$pkgname/$pkgname.spec` is the RPM spec file. This is not necessary
  for a NodeJS/npm package because the spec will be generated dynamically
  based on its `package.json` file.

No changes are needed to this repo for adding, modifying or removing
packages.

### Clone this repo

```sh
git clone https://github.com/riboseinc/packaging ~/src/packaging
```

### Set up environment variables

```sh
cd ~/src/packaging
cat << EOF > source_env.sh
export PACKAGER_KEY_PATH=MY-PACKAGING-KEY-PATH
export REPO_USERNAME=MY-GITHUB-USERNAME
export REPO_PASSWORD=MY-GITHUB-PASSWORD
EOF
. source_env.sh
```

### Build, Sign, Upload Packages With One Command

``` sh
cd ~/src/packaging
./docker.sh $pkgname
```



## Advanced Steps For The Manual Person

### Manually Run The Docker Container

``` sh
cd ~/src/packaging
./docker.sh [options] $pkgname
```

(optional) The `./docker.sh` script takes the following arguments:

Options:
* `-d` for dry run, not pushing to yum repo.
* `-k` for the path to the packager key.
* `-u` for git repo's username (via https).
* `-p` for git repo's password / app-token.
* `-h` to show help

Arguments can also be set via environment variables:
- `REPO_USERNAME`
- `REPO_PASSWORD`
- `PACKAGER_KEY_PATH`

This script also automatically creates a docker volume called `ribose-yum`,
for the caching and management of the
[Ribose yum git repo](https://github.com/riboseinc/yum), in order to
prevent unnecessary re-pulls due to the size of it.


### Manually Build, Sign, Upload Packages Within The Container

In the container:
``` sh
. /usr/local/packaging/_common.sh
setup_env
the_works ${package_name}
```


### Manually Build A Package

```sh
. /usr/local/packaging/_common.sh
setup_env

# build the rpm
/usr/local/packaging/packages/${package_name}.sh

# sign packages at a destination
sign_packages /root/rpmbuild/RPMS
```


### To Edit The Yum Repo (sorry this has to be manual)

In the container:
``` sh
. /usr/local/packaging/_common.sh
setup_env

# pull in the latest yum repo into /usr/local/yum
pull_yum

cd /usr/local/yum

# ... do your thing in /usr/local/yum/SRPMS
update_yum_srpm

# ... do your thing in /usr/local/yum/RPMS
update_yum_rpm

# commit changes and push repo
commit_repo
```

### Setting up the container environment manually

You need to manually enter the CAPITALIZED arguments if not using the
default packaging scripts.

``` sh
./set_yum_push_credentials.sh GITHUB_USERNAME GITHUB_PASSWORD
./import_packaging_key.sh RIBOSE-PACKAGER-SECRET-KEY-PATH
```

