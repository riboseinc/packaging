# Packaging for the Ribose yum repo

## Basic steps for building + uploading packages

1. Clone this repo

  `git clone https://github.com/riboseinc/packaging ~/src/packaging`

1. Set up environment variables

  ```sh
  cat << EOF > source_env.sh
  export PACKAGER_KEY_PATH=MY-PACKAGING-KEY-PATH
  export REPO_USERNAME=MY-GITHUB-USERNAME
  export REPO_PASSWORD=MY-GITHUB-PASSWORD
  EOF
  . source_env.sh
  ```

1. Run the docker container

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

1. Build, sign, upload packages within the container

  ``` sh
  # /usr/local/ribose-packaging/packages/${package-name}
  # e.g.
  /usr/local/ribose-packaging/packages/json-c12.sh
  ```

## Setting up the environment inside the container

You need to manually enter the CAPITALIZED arguments if not using the
default packaging scripts.

```
./set_yum_push_credentials.sh GITHUB_USERNAME GITHUB_PASSWORD
./import_packaging_key.sh RIBOSE-PACKAGER-SECRET-KEY-PATH
```

