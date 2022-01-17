# Containers & Kubernetes
## What is a container?
It's a set of processes isolated from the host system. They provide security, storage and network isolation. They also isolate libraries and runtime resources (e.g. CPU or storage). 

## Benefits of using containers over traditional deployments
*  Low HW footprint - Containers use OS internal features like namespaces or cgroups, thus avoiding requirement for special isolation managing services required in VMs
*  Environment isolation - libraries are part of our container. Updates of the underlying OS or other containers have no effect on our container.
*  Quick deployment - Containers do not need to install a whole new OS, like VMs or physical hosts. Restarting is quick.
*  Multi-Environment deployment - everything required by the container is packaged inside, so host stup differences do not matter
*  Reusability - same container may be used by different parties and deployed as needed with the same results. 

Larger monolithic applications should be split into multiple smaller, easier to manage services, when possible. These services can then possibly be deployed on single host instead of one service per host.

Note: some applications may not be suited for containerization, such as low-level HW accessing (memory, filesystem, devices) applications. This is due to some design limitations of containers.

## Container architecture
The goal of containers is to enable processes to run isolated while still being able to access system resources. The idea of isolated process became formalized around these Linux kernel features:
1. Namespaces - isolation of system resources. Only processes that are part of a namespace can see those resources (e.g network interfaces, PID list)
1. Control Groups (cgroups) - used to group processes and their children and impose a limit on resources they can consume.
1. seccomp - limits process access to system calls via a security profile, whitelisting system calls, parameters and file descriptors they are allowed to use.
1. SELinux - Security Enhanced Linux is mandatory access control system for processes. Processes are protected from each other and host is protected from them. 

Containers are based on images. Images are file-system bundles with all dependencies required to execute our process, like config files, packages or kernel modules.
Container images are immutable files - can be used by multiple containers at the same time. They can also be put into version control - usually into an image repository. These repositories can also provide image metadata, authorization, tagging and image version control.

## Managing containers
The most popular tools for managing interactions between containers, images and image repositories are _docker_ and _podman_. These allow us to build images, put/get them via registries or execute them.

Podman is open source tool. Its' image format is specified by Open Container Initiative. It's able to store images locally, has CLI which is very similar to that of docker, and is compatible with Kubernetes. Kubernetes is another open source tool which can be used to manage larger amounts of containers.

Once containerized services start appearing in production environment, the amount of work required to keep all the containers up and running would grow exponentially. So to address issues such as
*  Easy communication between services
*  Overall resource limit for applications regardless of number of running containers
*  Demand driven scaling of running containers
*  Reaction to service deterioration
*  Gradual and controlled roll-out of new releases to sets of users
There exists an orchestration tool called Kubernetes.

## Root vs Rootless containers
It is possible to launch containers without root privileges, which was originally impossible in docker. It is possible in podman by default. There are some advantages, like code running as root in rootless container, attackers cannot gain root access to the host via compromised container engine, or allow isolation inside nested containers. 

There are also disadvantages to running rootless, such as inability to bind ports <1024,or  volume mounting. Complete list may be found [here](https://github.com/containers/podman/blob/master/rootless.md)

## Using Podman
Some examples of podman commands:
```
# Basic pull from specified registry
podman pull registry.redhat.io/rhel8/mysql-80:1 --> image registry is FQDN, image has NAME:TAG formatting

# Execution of a named container (--name) in background (-d / --detached) with defined ENV variables (-e)
podman run --name mysql-basic \
> -e MYSQL_USER=user1 -e MYSQL_PASSWORD=mypa55 \
> -e MYSQL_DATABASE=items -e MYSQL_ROOT_PASSWORD=r00tpa55 \
> -d registry.redhat.io/rhel8/mysql-80:1
```
Podman has a set of subcommands for management of containers, such as:
*  push/pull - downloads or uploads image to/from registry
*  rmi - removes image from local storage
*  run - create and start container from image
*  create - creates a container from image, but it's stopped
*  start/stop - sends SIGTERM to running processes and terminates the container or restarts a terminated container
*  pause/unpause - sends SIGSTOP to pause running processes, which can then be restarted via unpause
*  rm - deleted a stopped container, if used with -f, will also delete a running container
*  commit - create a new image based on selected running container

There are also some subcommands for gaining various information:
*  search - searches remote repository for images
*  images - searches locally saved images
*  inspect - shows low level information about image or running container
*  top - similar to `top` command, lists running processes in the container
*  stats - displays live stream information about resource usage of a container
*  ps - prints out information about running and paused containers. With -a modifier, also shows stopped containers.
*  logs - view logs of running/stopped containers

## Container storage management
When container starts running, it gains a new layer, over the layers that are part of the base container image. That layer is container storage. This storage is ephemeral - it is not persistent, which means that this memory is lost between container runs. It is also unique for each running container, it is not shared. For applications that require data retention between runs, such as databases, we need persistent storage. 

### Configuring host directory
Since container runs as a process in the host operating system, with host assigned UID and GID, the directory we want to mount into the container must be configured with the appropriate ownership and permissions. When working with RHEL, appropriate SELinux context, `container_file_t` must be also set (podman uses this context to limit container access to host system directories).

One way to set this up:
1.  Create a directory via `mkdir ~/test_folder`
1.  The user running the container process must be able to access the folder. We can use the `unshare` command to execute commands in the same user namespace as the process running inside the container, like so: `podman unshare chown -R UID_NUM:UID_NUM ~/test_folder` 
1.  If on RHEL, we'll need to set the SELinux context to the directory recursively via `sudo semanage fcontext -a -t container_file_t '~/test_folder(/.*)?'`
1. Apply the SELinux container policy `sudo restorecon -Rv ~/test_folder`

### Mounting a Volume
Once the directory we wish to mount is properly configured, we can mount it to a specific location inside the container using the `podman run -v host/location:container/location` command option. If container/location already exists and has some content, that content is overlaid by the mounted folder and can be accessed again once the folder is unmounted.

## Kubernetes - container orchestration tool
As previously stated, this tool simplifies management of containerized applications. Smalles manageable unit is a *pod*. Pod may contain one or more containers. It also has its' own IP address. Pods are also used to orchestrate containers running in them and limit their resources as a single unit.

Kubernetes build on top of features we know from _Podman_, adding features such as:
*  Service discovery and load balancing - each set of container has a single DNS entry, so even if the container location changes, service will be unaffected. This also permits load balancing of incoming requests.
*  Horizontal scaling - Automated scaling can be configured via CLI or web GUI.
*  Self-healing - user defined health checks monitor health of containers and can restart or reschedule them as needed.
*  Automated rollout - updates can be rolled out automatically, with automated return to the last functional state in case something goes wrong
*  Secrets and config management - these can be bound to containers and changed as needed without the need for container rebuilding.
*  Operators - An Operator extends Kubernetes to automate the management of the entire life cycle of a particular application. Operators serve as a packaging mechanism for distributing applications on Kubernetes, and they monitor, maintain, recover, and upgrade the software they deploy.

## OpenShift overview
Red Hat OpenShift Container Platform (RHOCP) - is set of modular components and services built on top of Kubernetes infrastructure. It is a Platform as a Service (PaaS), open source development platform, which enables the developers to develop and deploy their applications on cloud infrastructure. It adds some new features to Kubernetes cluster:
*  Integrated developer workflow - RHOCP has integrated image registry, CI/CD pipelines and S2I (source to image - tool to build images from artifacts in source repositories)
*  Routes - Easy to expose services to the outside world
*  Metrics and logging - built-in, self-analyzing metrics service with logging aggregation.
*  Unified UI - easy mo manage different capabilities


