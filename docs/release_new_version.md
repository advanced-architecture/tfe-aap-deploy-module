## Release a New Module Version

### Checkout the latest code

```shell
git clone git@github.com:hashicorp/terraform-aws-hc-cloudsec-[module-name].git
```
If you have already cloned the repository locally, ensure you are on the `main` branch with the most recent code pulled in from GitHub. 

```shell
git checkout main
```

```shell
git pull origin main
```

### Update Changelog
Create a branch from `main` in your local clone of the `terraform-aws-hc-cloudsec-[module-name]` repository.

Ensure the CHANGELOG is updated to reflect the new release and its list of changes/additions. 

Create a PR using your new branch with the changelog updates. Merge the approved PR into the `main` branch once it is approved.

### Tag the Release
The TFC Private Registry updates the remote version of the `hc-cloudsec-[module-name]` module based on the tags released from this repository. 

Release tags use semantic versioning, example: v1.2.0

In your local terminal, export the version of `terraform-aws-hc-cloudsec-[module-name]` you are releasing:

```shell
export MODULE_VERSION=v<VERSIONHERE>
```

To tag the latest commit on the `main` branch, run the following:

```shell
git tag -a ${MODULE_VERSION} <commit ID> -m "Release ${MODULE_VERSION}"
```

Push the tag to Github:

```shell
git push origin ${MODULE_VERSION}
```

Pushing the tag to Github will now make it available for use in a release. This will automatically trigger the `release` action which will create a new draft release. After the `release` action completes, review the draft and publish it as the latest version of the module.


