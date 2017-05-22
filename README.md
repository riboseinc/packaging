# Packaging for the Ribose yum repo

## Basic steps for building + uploading packages

### Clone this repo

`git clone https://github.com/riboseinc/packaging ~/src/packaging`

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

### Run the docker container

``` sh
cd ~/src/packaging
./docker.sh
```

(optional) The `./docker.sh` script takes the following arguments:

``` sh
-k <packager-key-path>
-u <repo-username>
-p <repo-password>
```

### Build, sign, upload packages within the container

``` sh
# /usr/local/ribose-packaging/packages/${package-name}
# e.g.
/usr/local/ribose-packaging/packages/json-c12.sh
```


## Setting up the container environment manually (advanced)

You need to manually enter the CAPITALIZED arguments if not using the
default packaging scripts.

``` sh
./set_yum_push_credentials.sh GITHUB_USERNAME GITHUB_PASSWORD
./import_packaging_key.sh RIBOSE-PACKAGER-SECRET-KEY-PATH
```

