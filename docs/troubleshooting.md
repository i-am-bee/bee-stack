# Common issues

### ERROR: None of compose command versions meets the required version

If you get this error message, you have a compose provider installed, but it's not the correct version.

#### Symptoms A:

- `Found versions: ` in the error message start with `1.x.x`
- You see a warning `>>>> Executing external compose provider "/usr/bin/podman-compose"...`

Most probably, you have the [podman-compose](https://github.com/containers/podman-compose) package installed through
brew (using `brew install podman-compose`) or pip (`pip install podman-compose`).
This is an outdated version of compose which only supports a subset of features. Please uninstall it and follow
the podman instructions how to setup the [compose extension](https://podman-desktop.io/docs/compose/setting-up-compose).

> ⚠️`podman-compose` package is **not supported** by `bee-stack` and the script `./bee-stack.sh` will
> report an outdated compose version.

#### Symptomps B:

- `Found versions: ` in the error message start with `2.x.x`
- (optional) You see a warning `>>>> Executing external compose provider "/usr/bin/<external>"...` where `<external>` is
  something else than `podman-compose`

Podman prefers external providers for compose, for that reason, if you have any other container runtime
installed (such as Rancher or Docker desktop) it will be used instead of podman compose extension. We require
a compose version `>= 2.26`. Please update your other container runtime distribution (Docker Desktop, Rancher), etc.

### Part of the application is not working (UI, API, ...)

When `./bee-stack.sh setup` and `./bee-stack.sh start` works correctly,
but you can't use some part of the application.

#### Symptoms

- You open up the UI and it says: Unknown server error
- You go to http://localhost:3000, but the page is not loading

Most probably you don't have enough memory configured for your VM. Change the memory allocated in the GUI that came
with your distribution to at least 8GB. If you use podman, you can do this using CLI:

```shell
podman machine stop
podman machine set --memory 8192 --rootful 
podman machine start
```

### container `bee-code-interpreter-k3s` does not start

You may have a rootless podman machine configured. Please reconfigure it to rootful:

```shell
podman machine stop
podman machine set --rootful
podman machine start
```

## I'm lost

If you encounter any of the issue above, and you're not sure what to do, we recommend using rancher-desktop:
https://rancherdesktop.io/, it should work with bee-stack out of the box right after installation.

### Reinstalling or updating podman

If you have podman installed on your machine, unfortunately there is not a straight-forward process
to uninstall it, but at least make sure to stop and remove the virtual machine:

```shell
podman machine stop
podman machine rm
```

Then uninstall the podman CLI or GUI as well as `podman-compose` if installed.
Try these commands (on mac):

```shell
brew uninstall podman
brew uninstall podman-compose
brew uninstall podman-desktop
pip uninstall podman-compose
```

Advanced: on mac, you can cleanup the leftover files by running:

```
sudo /opt/podman/bin/podman-mac-helper uninstall
sudo rm -rf /opt/podman
sudo rm -rf /usr/local/podman
sudo rm -rfv /opt/podman
sudo rm /Library/LaunchDaemons/com.github.containers.podman.helper-dev.plist
sudo rm /etc/paths.d/podman-pkg
sudo rm /var/run/podman-helper-*.socket
```

You can refer to the following podman issues:

- https://github.com/containers/podman/issues/18034
- https://github.com/containers/podman/issues/11319

Or go to the official podman troubleshooting guide:
https://podman-desktop.io/docs/troubleshooting