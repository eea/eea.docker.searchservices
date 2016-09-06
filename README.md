# eea.docker.searchservices
ElasticSearch + Facetview complete Docker Stack Orchestration

**This repo is DEPRECATED**: We now deploy via [EEA Rancher catalog templates](https://github.com/eea/eea.rancher.catalog/tree/master/templates).

### 1. Components

__1.1 eeasearch__
[[repo]](https://github.com/eea/eea.docker.eeasearch), [[docker]](https://registry.hub.docker.com/u/eeacms/eeasearch/) -
Node.js frontend to an ElasticSearch cluster
* This container listens on port 3000 and provides a __readonly__ API endpoint to the elasticsearch cluster.
* The rendering is done by using jquery.facetview.js
* The base image has support for automatic sync jobs and for running index management commands
  
> More details on the [source repository](https://github.com/eea/eea.docker.eeasearch)

__1.2 pam__
[[repo]](https://github.com/eea/eea.docker.pam),  -
Node.js frontend to an ElasticSearch cluster
* This container listens on port 3010 and provides a __readonly__ API endpoint to the elasticsearch cluster.
* The rendering is done by using jquery.facetview.js
* The base image has support for running index management commands

> More details on the [source repository](https://github.com/eea/eea.docker.pam)

__1.3 aide__
[[repo]](https://github.com/eea/eea.docker.aide),  -
Node.js frontend to an ElasticSearch cluster
* This container listens on port 3020 and provides a __readonly__ API endpoint to the elasticsearch cluster.
* The rendering is done by using jquery.facetview.js
* The base image has support for running index management commands

> More details on the [source repository](https://github.com/eea/eea.docker.aide)

__1.4 esmaster__
[[repo]](https://github.com/eea/eea.docker.elastic), [[docker]](https://registry.hub.docker.com/u/eeacms/elastic/) -
Elastic master configurated node
* This node can't do anything besides cluster management. Thus, it has a low chance of getting shut down.

__1.5 esclient__
[[repo]](https://github.com/eea/eea.docker.elastic) [[docker]](https://registry.hub.docker.com/u/eeacms/elastic/) -
Elastic HTTP client configured node

* This node is the only one that can __accept__, __parse__, __scatter__ and __gather__ HTTP query requests.
* The actual work is being performed by the esworkers
  
__1.6 esworker__ 
[[repo]](https://github.com/eea/eea.docker.elastic), [[docker]](https://registry.hub.docker.com/u/eeacms/elastic/) -
Elastic Data storage nodes

* __Two__ configurated nodes for data replication.
* These nodes hold the data and execute the actual queries received from the esclient.
* In addition, these are the only nodes that can run the River process. Thus, if the river process
  brings down the node (e.g. consumes too much memory), the other node will be able to serve the
  data.
  
__1.7 dataw[1|2]__ - Data Volume Containers
* Lightweight containers holding the data stored in the workers.
* These containers make the data easy to backup and be restored independent of the esworker container's faith.

__1.8 datam__ - Data Container for Master node
* This container doesn't store any indexed data, but it stores information about the worker nodes, required by the master node
  
> * More information about elasticsearch node roles can be found [here](http://www.elastic.co/guide/en/elasticsearch/reference/1.5/modules-node.html)
> * More information about elasticsearch node discovery can be found [here](http://www.elastic.co/guide/en/elasticsearch/reference/1.5/modules-discovery.html)

### 2. Deployment tips
#### 2.1 Getting the latest release up and running for the first time

``` bash
git clone --recurse https://github.com/eea/eea.docker.searchservices
cd eea.docker.searchservices
docker-compose up -d
```

To see all commands an elastic app can do type ```docker-compose run --rm eeasearch help```.


__Troubleshooting:__
Data is not indexed?
Sometimes during the indexing and even after finishing it queries on the new index throws an error.
Restarting elasticsearch solves the problem:

```
# Restarting the elastic workers if the index is not built
docker-compose restart esworker1
docker-compose restart esworker2
```
Now go to the &lt;serverip&gt;:9200/_plugin/head/ to see if the index is being built.

Also you can try to increment the ES_HEAP_SIZE for the clients in the docker-compose.yml.

##### 2.1.1 Auto indexing

All elastic search apps run a create index at startup if they haven't indexes or not have data.

You can stop this feature adding ```AUTO_INDEXING=false``` into environment section of the docker-compose.yml

```
...
environment:
        - AUTO_INDEXING=false
...
```

After you can run the follow steps to index

```
# Wait a while for the elastic cluster to get initialized
# Start indexing data
docker-compose run --rm eeasearch create_index
# Check the logs
docker-compose logs
# If the river is not indexing just perform a couple of reindex commands
docker-compose run --rm eeasearch reindex
# Go to this host:3000 to see that data is being harvested
# And the same for PAM
# Start indexing data
docker-compose run --rm pam create_index
# And the same for AIDE
# Start indexing data
docker-compose run --rm aide create_index
# Check the logs
docker-compose logs
# If the river is not indexing just perform a couple of reindex commands
docker-compose run --rm pam reindex
# Go to this host:3010 to see that data is being harvested for pam
# Go to this host:3020 to see that data is being harvested for aide

```

#### 2.2 Persistent data

The data is kept persistent by using two explicit data containers.
The data is mounted in ```/usr/share/elasticsearch/data```
Follow te steps from the "Backup, restore, or migrate data volumes" section
in the [Docker documentation](https://docs.docker.com/userguide/dockervolumes/)

#### 2.3 Performing production updates

Change the tags in this repo to match the image version you want to
upgrade to. Then, push the changes on this repo.
On the host runnig this compose-file do:

``` bash
docker-compose stop    # stop the running containers
git pull origin master # and get the docker-compose-prod.yml containing the latests tags
# Before this step you should backup the data containers if the update procedure fails
docker-compose pull    # get the images and their tags
docker images | grep eeacms # inspect that the new images have been downloaded
docker-compose rm -vf eeasearch aide pam # remove the old containers befor start
docker-compose up -d --no-recreate # start the running containers
```
__Possible problems__

In some cases the containers cannot be stopped because for some reason they have no names. This happens mostly for the elastic containers. 
Running 
``` bash
docker ps -a
```
Displays the list of containers but some of them have no names. 
First these containers should be removed with
``` bash
docker rm --force <container_id>
```
Second the containers should be rebuilt with
``` bash
docker-compose up -d --no-recreate
```

#### 2.4 Running index management scripts from your office :)

Given a webapp and the fact that you can access __esclient__ from your office you can
reindex the data or force a sync using this command.

Assuming that __esclient:9200__ is available at `http://some-staging:80/elasticsearch/` and
you have permission to perform PUT POST and DELETE over that endpoint from your office, you can run
this oneliner to reindex the data from a given app.

```
docker run --rm -e elastic_host=some-staging -e elastic_path=/elasticsearch/ -e elastic_port=80 eeacms/eeasearch reindex
```

To see a list of all available commands run:
```
docker run --rm -e elastic_host=some-staging -e elastic_path=/elasticsearch/ -e elastic_port=80 eeacms/eeasearch help
```

> By default `elastic_path` is `/` and `elastic_port` is `9200`. So you can omit them if __esclient__ is accessible
> on port `9200` at path `/`.

#### 2.5 A note about scaling
TL;DR - it won't work with docker-compose scale because
the overhead is in worker nodes which need additional ops to be scaled.

By default, ElasticSearch breaks an index into 5 shards (holding different parts of the data). Each shard
will have one replica. If we have 4 workers with this setup, then shards could be distributed as such:
* Node1: Shard 0 Primary, Shard 1 Replia, Shard 3 Primary
* Node2: Shard 0 Replica, Shard 1 Primary, Shard 2 Primary
* Node3: Shard 4 Replica, Shard 3 Replica
* Node4: Shard 4 Primary, Shard 2 Replica

If Node3 and Node4 are scaled down, Shard 4 will get lost and it would be hard to recover.

* Scaling up will not automatically move shards to other nodes in order to better distribute the jobs.

* Scaling down will not move shards to remaining nodes to keep availability.

* Running on the same host would increase the number of parallel disk accesses which can trash the cache, resulting
in poor performance.

* Worker nodes perform most of the work. If something runs slow it's a high change that something is taking too long
on the workers, not the client or the master.

Maintaining a more complex ElasticSearch Cluster means distributing it over more hosts and performing
careful operations for scaling so data is not lost.
__Just don't do docker scale over elastic nodes.__

#### 2.7 Deployment with Rancher

The provided docker-compose-prod.yml in this repo is already configured to run within [Rancher PaaS](http://rancher.com/rancher/).

Make sure you have the appropriate labels on the docker hosts in your Rancher cluster. See docker-compose-prod.yml and look for labels __io.rancher.scheduler.affinity:host_label__.

Go to your Rancher Web interface and generate your API key (API & Keys for "..." Environment):

    $ export RANCHER_URL=<(Endpoint URL)>
    $ export RANCHER_ACCESS_KEY=<(ACCESS KEY)>
    $ export RANCHER_SECRET_KEY=<(SECRET KEY)>

    $ git clone https://github.com/eea/eea.docker.searchservices.git
    $ cd eea.docker.searchservices
    $ rancher-compose up

The above will automatically create a stack named eea-docker-searchservices and run it. Now look at the exposed rancher loadbalancer and configure your DNS/proxy to point to it.

## 3. Clean Development setup
Perform this steps to be able to easily make changes to any of the EEA maintained
parts of this stack.

#### 3.1 Prerequisites
* bash :)
* python (>= 2)
* git :)
* maven (for building the EEA RDF River plugin) ```sudo apt-get install maven``` and a Java environment
* npm (>= 2.8.4) for building and publishing the base node.js webapp module
 * Follow these steps to install the needed versions on a Debian based system [TODO]
* Docker (>=1.5) and docker-compose (>=1.3.0)
 * Follow these steps to install them [TODO]
 * To easily run the commands ad your user into the docker group and re-login for
   the changes to take effect.

#### 3.2 Clone all the components of the stack

This repository glues together all the components of the stack and also offers a template for a
development docker-compose file. Change directory to your home or working folder and clone the 
project using:

``` bash
user@host ~/ $ git clone --recursive git@github.com:eea/eea.docker.searchservices.git
```

#### 3.3 Run everything on your host
Building the elastic containers from sources is rarely used, and takes lot of time, so we have 2 options:

 - use the elastic images from dockerhub
 - build the images from sources

##### 3.3.1 With elastic images pulled from the hub

Run ```docker-compose -f docker-compose-dev.yml up``` to start all services.

Check http://localhost:9200 or http://localhost:9200/_plugin/head/ to see if elastic is up and running. When it's up, you can go to http://localhost:3000, http://localhost:3010 and http://localhost:3020 then make yourself a coffee, everything works now.

##### 3.3.2 With elastic images built from the source code using the rdf river plugin from sources

 Run ```docker-compose -f docker-compose-dev-elastic.yml up``` to start all services.

##### 3.3.3 Indexing
Run ```docker-compose -f docker-compose-dev.yml run --rm eeasearch create_index``` to create the index for EEASearch

Run ```docker-compose -f docker-compose-dev.yml run --rm pam create_index``` to create the index for PAM

Run ```docker-compose -f docker-compose-dev.yml run --rm aide create_index``` to create the index for AIDE

## 4. Publishing changes and updating Docker Registry images

Assuming you have tested locally and implemented the needed features, depending on the code
you changed, perform the following steps to make the changes available in Docker Registry.

> You can also use repo specific docker-compose.yml files if the changes affect only a part of the stack.

#### 4.1. eea.searchserver.js
__Note:__ make sure that all the applications using this package work with your new changes
before publishing anything.

First, you need to publish the new version of the package.
* Open package.json and increment the version
* Commit your changes
* Commit a new tag

This repository will not automatically build the eeacms/eeasearch (and other apps) Docker images.
* Go to https://registry.hub.docker.com/u/eeacms/eeasearch/ and trigger a build.
* Wait for the build to complete
* Perform [these](#23-performing-production-updates) steps to deploy

#### 4.2. eea.elasticsearch.river.rdf
__Note:__ make sure that all the applications using the river work with your new changes
before publishing anything.

First, you need to add a new release of the river.
* Open pom.xml and increment the version
* Run ```mvn clean install``` to make a new build
* Commit your changes
* Go to the [releases tab](https://github.com/eea/eea.elasticsearch.river.rdf/releases)
* Click on draft a new release
* Fill in the tag version and release name as the version you added in pom.xml
  __This is needed because the Dockerfile expects this naming scheme__
* Attach `eea.elasticsearch.river.rdf/target/releases/eea-rdf-river-plugin-version.zip` as a binary release
* Complete the release

This repository will not automatically build the eeacms/elastic Docker images.
* Go to https://registry.hub.docker.com/u/eeacms/elastic/ and trigger a build.
* Current naming scheme for the tags is $ES_VERSION-$RIVER_VERSION
* Wait for the build to complete
* Perform [these](#23-performing-production-updates) steps to deploy


#### 4.3. eea.docker.elastic and eea.docker.eeasearch

Pushing to master will automatically trigger a build with the :latest tag.
Make sure that you are building with the correct tags and wait for the builds
to complete bofore performing [these](#23-performing-production-updates) steps.


#### 4.4. Information about current container, git version and index

All elastic applications will display in the page footer information about the current index and container, like below:

```
Application data last refreshed 05 April 2016 12:52 PM. Version info eeacms/pam:v2.7.3 and git tag number v2.8 on 718b1e09d6a0.
```


* 05 April 2016 12:52 PM - the date when index was updated/rebuilt
* eeacms/pam:v2.7.3 - current image version used; this is an optional value that can be specified in the docker compose file like below:

```
environment:
	- VERSION_INFO=eeacms/pam:v2.7.3
```

* v2.8 - current git tag number (based on git describe --tags)
* 718b1e09d6a0 - container id (HOSTANME environment variable)
