# DockerDrop, a training site for Docker for Development with Drupal

## Lesson 2:  Pin your image selection to a particular version
 
### 1: Open `docker-compose.yml` in your editor / IDE

Open the `docker-compose.yml` file and take a look at the following line:

~~~
    image: nginx:latest
~~~

This line designates the image to be used in this build.  The format of this line is `<container>:<version>`.  For Docker containers, the "latest" version is usually the "bleeding edge" image, and is subject to change.

### 2:  Edit the line from Step 1 to pin it to version 1.10.2

Edit the line from Step 1 to read as follows:

~~~
    image: nginx:1.10.2
~~~

This "pins" your stack build to use this specific version of the official NginX container.  The available versions can be seen on Docker Hub, at `https://hub.docker.com/r/library/nginx/tags/`.

### 3:  Save the changes and build your stack

Save the revised `docker-compose.yml` file, and issue the following command:

`docker-compose up -d`

You should have seen output similar to the following:

~~~
Creating network "dockerdrop_default" with the default driver
Pulling web (nginx:1.10.2)...
1.10.2: Pulling from library/nginx
386a066cd84a: Already exists
21413bff969a: Pull complete
eee080e089c4: Pull complete
Digest: sha256:eb7e3bbd8e3040efa71d9c2cacfa12a8e39c6b2ccd15eac12bdc49e0b66cee63
Status: Downloaded newer image for nginx:1.10.2
Creating dockerdrop_web_1
~~~

Notice the 4th line of the output above:

~~~
386a066cd84a: Already exists
~~~

When Docker downloads an image, that image is comprised of several "layers", that comprise different components that make up a particular image.  Each "layer" is stored on Docker Hub with a hash.  Whenever possible Docker will "reuse" layers across multiple containers.  In our case, both the "latest" vesion and version "1.10.2" start with the official "debian/jessie" Docker image, so naturally there will be some commonality between the two.  Since we had started with the "latest" image in our build, Docker had already downloaded the layers for the `nginx:latest` image and cached them locally.  There is one layer that is common between `nginx:latest` and `nginx:1.10.2`, which Docker identified via its hash, so Docker doesn't download that layer again; it simply downloads the ones where there are differences.

### 4:  Delete the `nginx:latest` image from your cache

This is an optional step, but helps keep your local Docker cache from becoming cluttered with unused images.  Issue the following command:

~~~
docker images
~~~

You should see something similar to the following:

~~~
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
nginx               1.10.2              5acd1b9bc321        2 weeks ago         180.7 MB
nginx               latest              05a60462f8ba        2 weeks ago         181.5 MB
~~~

The IMAGE ID is the hash assigned to each image stored in your local cache.  To delete the `nginx:latest` image, issue the following command, replacing the hash for `nginx:latest` with the one shown on your local machine:
 
~~~
docker rmi 05a60462f8ba <== replace hash
~~~

Now when you issue the command `docker images` you should only see the `nginx:1.10.2` image.


<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />The instructional materials, which includes any materials in this repository included in markdown (.md) and/or text (.txt) files, are licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.
