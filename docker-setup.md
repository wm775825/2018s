# Docker setup

This guide demonstrates how to install/setup Docker environment and use
Docker image to run the assignment code. You can view this as kind of virtual
machine image with required softwares installed. OCaml and Lua are included in [the
image](https://hub.docker.com/r/dimo414/cs242).

## Install Docker

Please refer to [About Docker CE, docker docs](https://docs.docker.com/install/) for how to install Docker.
In fact, for this experiment you only need to type "docker" in shell and then install by tips. It may be
```shell
sudo apt install docker.io
```

Cheat sheet:

```shell
## List Docker CLI commands
docker
docker container --help

## Display Docker version and info
docker --version
docker version
docker info

## Execute Docker image
docker run hello-world

## List Docker images
docker image ls

## List Docker containers (running, all, all in quiet mode)
docker container ls
docker container ls --all
docker container ls -aq
```

## Pull Docker Image from DockerHub

The Docker image is at [dimo414/cs242](https://hub.docker.com/r/dimo414/cs242).

To download the image,

``` shell
docker pull dimo414/cs242
```

It may be **SO SLOW** to pull this image that you can use `docker save` and `docker load` to copy from your classmates who make it luckily. [This page](https://stackoverflow.com/questions/23935141/how-to-copy-docker-images-from-one-host-to-another-without-using-a-repository) may help.

## Usage

To run the image.

``` shell
$ docker run -it --tty dimo414/cs242

root@84dff11c2296:/dimo414# ls
solution.byte
root@84dff11c2296:/dimo414# ocaml
        OCaml version 4.02.3
> exit(0);;
root@84dff11c2296:/dimo414# 
```

* `--interactive/-it` says you want an interactive session.
* `--tty` allocates a pseudo-tty.
* you can also use `-v` option to map your assign directory in your host machine to the docker iamge. Or you can use `docker cp <src-path> <dst-path>` to copy files between the host and the image . Google for details if you need. 

This commands create a **container** from the `dimo414/cs242` image.
You can run `lua` or `ocaml` here. Note the hash value `84dff11c2296`. This is
you container's name.

You make some change, and exit the container.

If you want to start the  **container** again.
Running  `docker run -it --tty dimo414/cs242`  won't help since it will create a brand **new**
container from the image. You will see a clean home directory, all the previous
changes gone.

To resume your previous work.

``` shell
docker start 84dff11c2296
docker attach 84dff11c2296
```

## Learn Docker

* [Play with Docker Classroom](https://training.play-with-docker.com/) gives you
  an interactive environment for learning docker. **Recommended**.
* Official documentation: [Get Started with Docker, docker docs](https://docs.docker.com/get-started/)
  for Docker's basic usages.

## PS

I'm not familiar with docker. If there are some mistake, issues and pull requests are welcomed.
(created by Xing Guo and updated by wm775825)