# eea.docker.searchservices
ElasticSearch + Facetview complete Docker Stack Orchestration

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
  
> * More information about elasticsearch node roles can be found [here](http://www.elastic.co/guide/en/elasticsearch/reference/1.5/modules-node.html)
> * More information about elasticsearch node discovery can be found [here](http://www.elastic.co/guide/en/elasticsearch/reference/1.5/modules-discovery.html)

### 2. Deployment tips
#### 2.1 Getting the latest release up and running for the first time

``` bash
git clone https://github.com/eea/eea.docker.searchservices
cd eea.docker.searchservices
docker-compose up -d
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
git pull origin master # and get the docker-compose.yml containing the latests tags
# Before this step you should backup the data containers if the update procedure fails
docker-compose pull    # get the images and their tags
docker images | grep eeacms # inspect that the new images have been downloaded
docker-compose stop    # stop the running containers
docker-compose start -d # start the running containers
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

#### 2.6 Apache/nginx configuration
If the application is mapped under a path like: /data-and-maps/<node-app> it needs to be redirected to /data-and-maps/<node-app>/

 * Apache:
	```
	RewriteCond %{REQUEST_URI} data-and-maps/<node-app>$
	RewriteRule ^(.*[^/])$ $1/ [L,R=301]
	```

 * nginx:
	```
	location /data-and-maps/<node-app>/ {
		proxy_pass http://hostRunningNODEAPPContainer:3000/
	}
	```

## 3. Clean Development setup
Perform this steps to be able to easily make changes to any of the EEA maintained
parts of this stack.

#### 3.1 Prerequisites
* bash :)
* git :)
* maven (for building the EEA RDF River plugin) ```sudo apt-get install maven``` and a Java environment
* npm (>= 2.8.4) for building and publishing the base node.js webapp module
 * Follow these steps to install the needed versions on a Debian based system [TODO]
* Docker (>=1.5) and docker-compose (>=1.1.0)
 * Follow these steps to install them [TODO]
 * To easily run the commands ad your user into the docker group and re-login for
   the changes to take effect.

#### 3.2 Create a separate work directory in your home directory (or somewhere else)

``` bash
user@host ~ $ mkdir eea.es
user@host ~ $ cd eea.es
user@host ~/eea.es/ $ 
```

#### 3.3 Clone all the components of the stack
##### 3.3.1 This repository
This repository glues together all the components of the stack and also
offers a template for a development docker-compose file.

``` bash
user@host ~/eea.es/ $ git clone git@github.com:eea/eea.docker.searchservices.git
```

##### 3.3.2 EEAsearch web application
This repository contains a dockerized Node.js app that stands
as a frontend for the Elasticsearch cluster defined in eea.docker.searchservices

``` bash
user@host ~/eea.es/ $ git clone git@github.com:eea/eea.docker.eeasearch.git
```


##### 3.3.3 PAM web application
This repository contains a dockerized Node.js app that stands
as a frontend for the Elasticsearch cluster defined in eea.docker.searchservices

``` bash
user@host ~/eea.es/ $ git clone git@github.com:eea/eea.docker.pam.git
```


##### 3.3.4 AIDE web application
This repository contains a dockerized Node.js app that stands
as a frontend for the Elasticsearch cluster defined in eea.docker.searchservices

``` bash
user@host ~/eea.es/ $ git clone git@github.com:eea/eea.docker.aide.git
```


##### 3.3.5 Node.js eea.searchserver package
This repository contains a Node.js module that contains
all the shared logic needed by elasticsearch frontend webapps.

``` bash
user@host ~/eea.es/ $ git clone git@github.com:eea/eea.searchserver.js.git
```

##### 3.3.6 Elastic[Search] Dockerized repo
This repository builds a Docker image of Elastic (former ElasticSearch) containing
the RDF River Plugin and the Analysis ICU plugin

``` bash
user@host ~/eea.es/ $ git clone git@github.com:eea/eea.docker.elastic.git
```

##### 3.3.7 EEA RDF River Plugin
This repository builds the Java RDF River plugin needed by
elasticsearch in order to harvest data from SPARQL endpoints

``` bash
user@host ~/eea.es/ $ git clone git@github.com:eea/eea.elasticsearch.river.rdf.git
```

#### 3.4 Build the development images

Follow these steps to build local Docker images using the local repositories you just cloned.

##### 3.4.1 eeacms/eeasearch:dev

``` bash
cd ~/eea.es/eea.docker.eeasearch/
```

If you want to build the development image using the local `eea.searcherver.js` code, run:

``` bash
./build_dev.sh ../eea.searchserver.js # uses Dockerfile.dev and adds local code into the image
```

If you want to build a development image using the production setup and the public
`eea.searchserver.js` npm package available [here](https://www.npmjs.com/package/eea-searchserver), run:

``` bash
docker build -t eeacms/eeasearch:dev .
```

##### 3.4.2 eeacms/pam:dev

``` bash
cd ~/eea.es/eea.docker.pam/
```

If you want to build the development image using the local `eea.searcherver.js` code, run:

``` bash
./build_dev.sh ../eea.searchserver.js # uses Dockerfile.dev and adds local code into the image
```

If you want to build a development image using the production setup and the public
`eea.searchserver.js` npm package available [here](https://www.npmjs.com/package/eea-searchserver), run:

``` bash
docker build -t eeacms/pam:dev .
```

##### 3.4.3 eeacms/aide:dev

``` bash
cd ~/eea.es/eea.docker.aide/
```

If you want to build the development image using the local `eea.searcherver.js` code, run:

``` bash
./build_dev.sh ../eea.searchserver.js # uses Dockerfile.dev and adds local code into the image
```

If you want to build a development image using the production setup and the public
`eea.searchserver.js` npm package available [here](https://www.npmjs.com/package/eea-searchserver), run:

``` bash
docker build -t eeacms/aide:dev .
```

##### 3.4.4 eeacms/elastic:dev

``` bash
cd ~/eea.es/eea.docker.elastic/
```

If you want to build the development image using the local `eea.elasticsearch.river.rdf` code, run:
``` bash
./build_dev.sh ../eea.elasticsearch.river.rdf # uses Dockerfile.dev and adds local code into the image
```

> For this step you'll need maven

If you want to build a development image using the production setup and the public
`eea.elasticsearch.river.rdf` plugin available [here](https://github.com/eea/eea.elasticsearch.river.rdf/releases), run:

``` bash
docker build -t eeacms/elastic:dev .
```
---
> __Always__ use the :dev tag, as you need to delete the image in order to pull
> the official :latest image available on Docker Registry. Not using :dev tag
> increases the risk of running with some image on production and another locally.

#### 3.5 Run everything on your host

``` bash
cd ~/eea.es/eea.docker.searchservices/
cp docker-compose.dev.yml.example docker-compose.dev.yml
```

Edit docker-compose.dev.yml to fit your test case. 

Run ```docker-compose -f docker-compose.dev.yml up``` to start all services.

Run ```docker-compose -f docker-compose.dev.yml run eeasearch create_index``` to create the index for EEASearch

Run ```docker-compose -f docker-compose.dev.yml run pam create_index``` to create the index for PAM

Run ```docker-compose -f docker-compose.dev.yml run aide create_index``` to create the index for AIDE

Wait a bit and go to http://localhost:3000, http://localhost:3010 and http://localhost:3020 then make yourself a coffee, everything works now.

## 4. Publishing changes and updating Docker Registry images

Assuming you have tested locally and implemented the needed features, depending on the code
you changed, perform the following steps to make the changes available in Docker Registry.

> You can also use repo specific docker-compose.yml files if the changes affect only a part of the stack.

#### 4.1. eea.searchserver.js
__Note:__ make sure that all the applications using this package work with your new changes
before publishing anything.

First, you need to publish the new version of the package.
* Open package.json and increment the version
* Make sure you can publish to [the npm package](https://www.npmjs.com/package/eea-searchserver)
 * Contact @demarant or @mihaibivol to add you as a contributor it's the first time publishing
* Run `npm register` and register with your credentials
* Run `npm publish` and make sure that no error was encountered
* Commit your changes

> ```npm publish``` may fail if you are using an older version. Run ```npm install npm``` to upgrade.

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
