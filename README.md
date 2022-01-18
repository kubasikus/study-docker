# Containers
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

### Configuring podman registries
Update the /etc/containers/registries.conf file. Edit the registries entry in the [registries.search] section, adding an entry to the values list. 

Secure connections to a registry require a trusted certificate. To support insecure connections, add the registry name to the registries entry in [registries.insecure] section of /etc/containers/registries.conf file.

### registry interactions
registries can be searched using the `podman search` command. This command has has many options to further refine the search results.


It is also possible to use REST API of the image registries directly. For example, we can use `curl` along with `python json` module to get informations and format it:
```
curl -Ls \
> https://quay.io/v2/$NAMESPACE/$IMAGE_NAME/tags/list \
> | python -m json.tool
```


If authentication is required, we can use `podman login` command, or, if using the API directly, add the token into the request header, like this: `curl -H "Authorization: Bearer $TOKEN"`


### Container manipulation
#### Backing up
It is possible to save image as `.tar` file for backup or sharing via `podman save / load`. It is also possible to just upload the image into a registry using `podman push`

#### Saving modified Containers
If changes were made to a running container that we would like to keep, it is possible to see the changes made via `podman diff $CONTAINER_NAME` and then save the newly created layers via `podman commit $OLD_CONTAINER_NAME $NEW_CONTINER_NAME`. 


Note: changes made in mounted directories are not shown in `podman diff` output. 

#### Tagging
Tagging is a way to differentiate different version of images. `latest` is the default tag that is used when none is specified. 


The command `podman tag $OLD_CONTAINER:$OLD_TAG $NEW_CONTAINER:$NEW_TAG` may be used. To remove a tag, use `podman rmi $CONTAINER_ID:$TAG`

#### Pushing to registry
To push an image, it muse be present in local storage and be tagged. If the image name container FQDN of target repository, it is used to push there, like so: `podman push quay.io/$NAMESPACE/$CONTAINER:$TAG`.


## Container storage management
When container starts running, it gains a new layer, over the layers that are part of the base container image. That layer is container storage. This storage is ephemeral - it is not persistent, which means that this memory is lost between container runs. It is also unique for each running container, it is not shared. For applications that require data retention between runs, such as databases, we need persistent storage. 

### Configuring host directory
Since container runs as a process in the host operating system, with host assigned UID and GID, the directory we want to mount into the container must be configured with the appropriate ownership and permissions. When working with RHEL, appropriate SELinux context, `container_file_t` must be also set (podman uses this context to limit container access to host system directories).

One way to set this up:
1.  Create a directory via `mkdir ~/test_folder`
1.  The user running the container process must be able to access the folder. We can use the `unshare` command to execute commands in the same user namespace as the process running inside the container, like so: `podman unshare chown -R UID_NUM:UID_NUM ~/test_folder` 
1.  If on RHEL, we'll need to set the SELinux context to the directory recursively via `sudo semanage fcontext -a -t container_file_t '~/test_folder(/.*)?'`
1. Apply the SELinux container policy `sudo restorecon -Rv ~/test_folder`

Note: [here](https://www.redhat.com/sysadmin/user-namespaces-selinux-rootless-containers) is a blog post that uses the `:Z` option when mounting to automatically label the mounted folder with the SELinux policy. It also has more information about how this all works.`
### Mounting a Volume
Once the directory we wish to mount is properly configured, we can mount it to a specific location inside the container using the `podman run -v host/location:container/location` command option. If container/location already exists and has some content, that content is overlaid by the mounted folder and can be accessed again once the folder is unmounted.

## Network access to rootless container
Rootless container has no IP of it's own, so to access it, we can define port forwarding rules to allow remote access.

We can bind specific host port to specific container port using the `-p` option, like this: `podman run -p 8080:80`. That means that requests coming to port 8080 on the host are routed to port 80 in the container. The host port can be ommited and will be assigned randomly - use `podman ps` or `podman port $CONTAINER_ID` to find out which host port was assigned.

## Creating custom container images
It is possible to create a file, called Containerfile (used to be called Dockerfile), which take a base image and add a set of features on top of it. These features can be:
*  include new libraries
*  include SSL certificates
*  remove some redundant features or lock certain package to specific version

These `Containerfiles` are much more practical and maintainable than using the `podman commit` workflow. It is possible to get Red Hat Containerfiles via rhscl-dockerfiles package, and CentOS also has a [repository](https://github.com/sclorg?q=-container) to store these.

### S2I - Source to Image
Philosophy os S2I tool is to allow developers to use their usual tools, instead of having to learn Containerfile syntax. It uses a builder image, which has all the required runtime and development tools to build the project from VCS source. Once the project is built inside the container, a cleanup is done and new container is saved - with the built binaries and required runtimes. 


Note: This is often used in OpenShift due to security considerations.

### Containerfiles
Containerfile contains a set of commands that are executed from top to bottom. The first non-comment line must be `FROM` command, to specify which image to use as base. For a list of possible commands, see [here](https://www.mankier.com/5/Containerfile)


When possible, reduce the number of layers generated by putting multiple steps into single command where possible. This can be applied for `RUN yum $COMMAND1 && yum $COMMAND2 &&...`. `LABEL` and 'ENV' can be squished in similar way. For more information, see [Best Practices Doc](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)


Container can be built using `podman build -t $NAME:$TAG WORK_DIR`.


# Kubernetes - container orchestration tool
As previously stated, this tool simplifies management of containerized applications. Smalles manageable unit is a *pod*. Pod may contain one or more containers. It also has its' own IP address. Pods are also used to orchestrate containers running in them and limit their resources as a single unit.

Kubernetes build on top of features we know from _Podman_, adding features such as:
*  Service discovery and load balancing - each set of container has a single DNS entry, so even if the container location changes, service will be unaffected. This also permits load balancing of incoming requests.
*  Horizontal scaling - Automated scaling can be configured via CLI or web GUI.
*  Self-healing - user defined health checks monitor health of containers and can restart or reschedule them as needed.
*  Automated rollout - updates can be rolled out automatically, with automated return to the last functional state in case something goes wrong
*  Secrets and config management - these can be bound to containers and changed as needed without the need for container rebuilding.
*  Operators - An Operator extends Kubernetes to automate the management of the entire life cycle of a particular application. Operators serve as a packaging mechanism for distributing applications on Kubernetes, and they monitor, maintain, recover, and upgrade the software they deploy.

## Kubernetes terminology
Kubernetes uses several nodes (servers) to ensure resiliency and scalability of managed applications. So Kubernetes is in essence a cluster of servers that run containers. This cluster is managed by another set of servers, called control plane servers. Some terminology to understand (a whole glossary can be found [here](https://kubernetes.io/docs/reference/glossary/?fundamental=true)):
*  Node - A node is a worker machine in Kubernetes. It may be a VM or Physical machine, depending on the cluster. It has local daemons or services necessary to run Pods and is managed by the control plane.
*  Control Plane - The container orchestration layer that exposes the API and interfaces to define, deploy, and manage the lifecycle of containers.
*  Compute Node - This node executes workloads for the cluster. Application pods are scheduled onto compute nodes.
*  Resource - Resources are any kind of component definition managed by Kubernetes. Resources contain the configuration of the managed component (for example, the role assigned to a node), and the current state of the component (for example, if the node is available).
*  Controller - In Kubernetes, controllers are control loops that watch the state of your cluster, then make or request changes where needed. Each controller tries to move the current cluster state closer to the desired state. 
*  Label - Labels are key/value pairs that are attached to objects such as Pods. They are used to organize and to select subsets of objects.
*  Namespace - Namespaces are used to organize objects in a cluster and provide a way to divide cluster resources. Names of resources need to be unique within a namespace, but not across namespaces. Namespace-based scoping is applicable only for namespaced objects (e.g. Deployments, Services, etc) and not for cluster-wide objects (e.g. StorageClass, Nodes, PersistentVolumes, etc).

## Kubernetes Main Resource types
Kubernetes has six main resource types that can be configured via YAML or JSON file or the OCP management tools:
*  Pods (po) - Collection of containers that share resources. Basic work unit of K8s
*  Services (svc) - Defined single IP/port combination that provides access to a pool of pods (this allow containers in any pod on the same cluster to reliably connect to each other)
*  Replication controllers (rc) - Defines how pods are replicated (horizontal scaling) into different nodes
*  Persistent Volumes (pv) - Define storage used by K8 pods
*  Persistent Volume Claims (pvc) - request for storage by a pod. PCV links a PV to a pod, for use by it's containers
*  ConfigMaps (cm) and Secrets - used to store config values as key-value pairs. Secrets are always encoded (not encrypted!) and access to them is more restricted

# OpenShift overview
Red Hat OpenShift Container Platform (RHOCP) - is set of modular components and services built on top of Kubernetes infrastructure. It is a Platform as a Service (PaaS), open source development platform, which enables the developers to develop and deploy their applications on cloud infrastructure. It adds some new features to Kubernetes cluster:
*  Integrated developer workflow - RHOCP has integrated image registry, CI/CD pipelines and S2I (source to image - tool to build images from artifacts in source repositories)
*  Projects - Extension of Kubernetes namespaces. Allows definition of user access control (UAC) to resources
*  Routes - Easy to expose services to the outside world
*  Metrics and logging - built-in, self-analyzing metrics service with logging aggregation.
*  Unified UI - easy to manage different capabilities
*  Image registry

Here is a table visualization of OpenShift component stack:
| OCP stack | | |
| --- | --- | --- |
| DevOps Tools and UX (Web Console, CLI, REST API, SCM integration) |
| Containerized Services (Auth, Networking, Image registry) | Runtimes and xPaaS, base container images with Java, Ruby, Node.js, etc. |
| Kubernetes Container orchestration, manages clusters of hosts and application resources | Etcd Cluster state and configs, used by Kubernetes as config and state storage | CRDs Kubernetes Operators, Custom Resource Definitions stored in etcd, they are state and configurations of resources managed by OCP |
| CRI-O Container runtime, enables usage of OCI compatible runtimes like runc, libpod or rkt |
| Red Hat CoreOS, OS optimized for Containers |

## OCP Main Resource Types
OpenShift extends Kubernetes with some additional Resource Types:
*  Deployment and Deployment Config - Both are representation of set of containers included in a pod a their deployment strategies. It contains container configurations that are applied to all containers in each pod replica, such as base image, tags and storage definitions
    * Deployment is improved DeploymentConfig
        *  Automatic rollback is not supported
        *  Every change in pod template used by deployment objects triggers a new rollout
        *  Lifecycle hooks are no longer supported
        *  deployment process of deployment object can be paused without affecting deployer process
        *  deployment object can have as many active replica sets as the user wants, scaling down old replicas after a while (limit for DeploymentConfig was two replications sets)
*  Build config (bc) - Defines a process to be executed in the OpenShift project - used by S2I to build container images, then use Deployment for CI/CD workflows.
*  Routes - Creates a DNS host name recognized by OCP router as an ingress point (this allows access to pods from outside the cluster)

## Working with Resources
When working with OCP via CLI, the tool to use is called `oc`. It is required to login to the cluster we wish to interact with `oc login $CLUSTER_URL`


We can define various resources as `.yaml` or `.json` files. See example for a [Pod resource definition](https://kubernetes.io/docs/concepts/workloads/pods/#using-pods) or [Service resource definiton](https://kubernetes.io/docs/concepts/services-networking/service/#defining-a-service)

## Creating applications
The command `oc new-app` is extremely flexible and allows miryad of ways to create a new application from various sources. See the `help` section of that command for detailed examples.

## Managing storage
Storage has to created on a cluster level as a Persistent Volume (pv) resource and then claimed using a Persisten Volume Claim (pvc) resource. PVC's can subsequently be mounted into a container. See [docs](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/) for details.

## OCP Resouce management via CLI
*  Use `oc get all` or `oc get $RESOURCE_TYPE` to retrieve most important information about cluster resources.
*  Use `oc get $RESOURCE_TYPE $RESOURCE_NAME` to export a resource definition for backup or modification. Can be export as JSON/YAML
*  Use `oc describe $RESOURCE_TYPE $RESOURCE_NAME` for detailed information
*  Use `oc create` to create resource from definition, can be used with `oc get`
*  Use `oc edit` to modify resource definition in place using a text editor
*  Use `oc delete $RESOURCE_TYPE $RESOURCE_NAME` to delete a specific Resource.
*  Use `oc exec $CONTAINER_ID $OPTIONS` to execute commands inside a container

Refer to [developer cli commands](https://docs.openshift.com/container-platform/4.9/cli_reference/openshift_cli/developer-cli-commands.html) documentation for additional info

## Labelling 
It is a good practice to label resources to distinguish them inside a project. We can label them based on environment, application, template, or other. Labels are specified in the `metadata` section, or by using `oc label` command. 


Labels can be used to look up specific groups of resources and act on them - most `oc` commands allow `-l` option to specify which label to target (example: `oc get svc,deployments -l app=nexus`).


Tip: Labels specified on Template level are applied to all resources that are part of the Template. The convention is to use the `app` label to specify which application is using given resource, and `template` label to specify which Template generated given Resource.

## Routes
Routes are resources that expose services to the outside world by binding a FQDN and IP address to that of a selected Service resource. Each OCP instance has a cluster wide router service, which can be found `oc get pod --all-namespaces | grep router`. When constructing defailt FQDN for route, variables like ROUTER_CANONICAL_HOSTNAME defined in these router pods are used. 

Route is not created automatically via `oc new-app`. It can be create using `oc create` with a definition file. Another way is to use `oc expose $RESOURCE_TYPE $RESOURCE_NAME`


Note: Route links directly to the service resource name, not labels.


## Source to Image
S2I takes a build container and source code repository, builds a new image and pushes it to private openshift repository. The command `oc new-app` is very smart and can start an S2I build just from the local repository (if it also has a remote that is accessible to OCP instance), or automtically detect which builder image should be used based on the source code repository contents.
