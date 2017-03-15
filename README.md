# Packaging for the Ribose yum repo

## Run the docker container

```
./docker.sh
```


## Setting up the environment inside the container

You need to manually enter the CAPITALIZED arguments.
```
./set_yum_push_credentials.sh GITHUB_USERNAME GITHUB_PASSWORD
./import_packaging_key.sh RIBOSE-PACKAGER-SECRET-KEY-PATH
```


## Build and push packages to repo

```
./build_publish_netpgp.sh
```

