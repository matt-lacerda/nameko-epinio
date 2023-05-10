# Devops challenge

## STEPS I TOOK TO RUN NAMEKO LOCALLY

Note: All the modified code is committed to this repo

### 1 - Config the environment
	activate windows wsl and install ubuntu
	install all the necessary apps like docker, docker-compose, jq, conda, helm, kind...
	clone the nameko-devex repo

### 2 - Run necessary services 
	Start rabbitmq, postgres and redis
	Changed the image of the main Dockerfile. Debian 9 (python:3.7-slim-stretch) is no longer maintained, and its security packages have been archived. This prevented the build process from continuing due to an error while updating the packages. - [commit](https://github.com/matt-lacerda/nameko-epinio/commit/a0be95bb7da9cef5982fa07f05093168327afb78)
	Added importlib-metadata and sqlalchemy with the correct pinned versions inside setup.py for orders, products and gateway services. This was necessary to avoid crashing the build process for the docker images. - [commit](https://github.com/matt-lacerda/nameko-epinio/commit/6d70776e5e673991d88aa4c154da6aa63aa70c06)
  Start redis, postgres and rabbitmq using ./dev_run_backingsvcs.sh
	Start gateway.service orders.service products.service using ./dev_run.sh gateway.service orders.service products.service

### 3 - ./test/nex-smoketest.sh local 
	Succeeded

### 4 - ./test/nex-bzt.sh local
	Succeeded


## STEPS TO RUN NAMEKO WITH DOCKER (COMPOSE)

### 1 - Run the necessary services
	Fix the gateway service port in the docker-compose file to be 8000 instead of 8003. This is the port configured to run the curl smoke tests. [commit](https://github.com/matt-lacerda/nameko-epinio/commit/d777e1075e8f0b277e7cc6acd6640febf71d8176)
	The command make deploy-docker will run docker compoase, which in turn will start all needed services
	
### 2 - make smoke-test
	Succeeded

### 3 - make perf-test
	Succeeded


## STEPS TO RUN NAMEKO WITH K8S

### 1 - cd k8s; make deployK8
  Followed the steps on https://github.com/gitricko/nameko-devex/blob/master/k8s/README.md
	Increased the sleep time from 5s to 30s in the make file. That allowed enough time for the nginx ingress to fully start before the next steps - [commit](https://github.com/matt-lacerda/nameko-epinio/commit/e33e5f774c00179172583c021d1610b6c9acd0b9)
	Uncommented $(MAKE) init-helm in the make file. This added the stable repo for helm, which is necessary since it does not come with a default repository after fresh installation. - [commit](https://github.com/matt-lacerda/nameko-epinio/commit/e33e5f774c00179172583c021d1610b6c9acd0b9)

### 2 - make smoke-test
	Succeeded

### 3 - make perf-test
	Succeeded

## STEPS TO RUN NAMEKO WITH EPINIO

### 1 - Create necessary services and configurations

  Pin image inside kind-config.yaml to the epinio recommend version for the cluster server (image: kindest/node:v1.22.7) [commit](https://github.com/matt-lacerda/nameko-epinio/commit/98df469690320b8423c664ddaec7f2cc86687688)
  Create new make commands for deploying the app with epinio - [commit](https://github.com/matt-lacerda/nameko-epinio/commit/c77f9d3362c9708679bd1ff1395bb80fedafeecc)
  Added curl -k (--insecure) tag for the curl tests to avoid failing because of certificates - [commit](https://github.com/matt-lacerda/nameko-epinio/commit/99ea2bf693e77f281958f613755843dec9109043)

### 2 - make epinio-smoke-test
	Succeeded

### 3 - make epinio-perf-test
	Succeeded


# Nameko Examples
![Airship Ltd](airship.png)
## Airship Ltd
Buying and selling quality airships since 2012

[![CircleCI](https://circleci.com/gh/nameko/nameko-examples/tree/master.svg?style=svg)](https://circleci.com/gh/nameko/nameko-examples/tree/master)

## Prerequisites

* [Python 3](https://www.python.org/downloads/)
* [Docker](https://www.docker.com/)
* [Docker Compose](https://docs.docker.com/compose/)

## Overview

### Repository structure
When developing Nameko services you have the freedom to organize your repo structure any way you want.

For this example we placed 3 Nameko services: `Products`, `Orders` and `Gateway` in one repository.

While possible, this is not necessarily the best practice. Aim to apply Domain Driven Design concepts and try to place only services that belong to the same bounded context in one repository e.g., Product (main service responsible for serving products) and Product Indexer (a service responsible for listening for product change events and indexing product data within search database).

### Services

![Services](diagram.png)

#### Products Service

Responsible for storing and managing product information and exposing RPC Api that can be consumed by other services. This service is using Redis as it's data store. Example includes implementation of Nameko's [DependencyProvider](https://nameko.readthedocs.io/en/stable/key_concepts.html#dependency-injection) `Storage` which is used for talking to Redis.

#### Orders Service

Responsible for storing and managing orders information and exposing RPC Api that can be consumed by other services.

This service is using PostgreSQL database to persist order information.
- [nameko-sqlalchemy](https://pypi.python.org/pypi/nameko-sqlalchemy)  dependency is used to expose [SQLAlchemy](http://www.sqlalchemy.org/) session to the service class.
- [Alembic](https://pypi.python.org/pypi/alembic) is used for database migrations.

#### Gateway Service

Is a service exposing HTTP Api to be used by external clients e.g., Web and Mobile Apps. It coordinates all incoming requests and composes responses based on data from underlying domain services.

[Marshmallow](https://pypi.python.org/pypi/marshmallow) is used for validating, serializing and deserializing complex Python objects to JSON and vice versa in all services.

## Running examples

Quickest way to try out examples is to run them with Docker Compose

`$ docker-compose up`

Docker images for [RabbitMQ](https://hub.docker.com/_/rabbitmq/), [PostgreSQL](https://hub.docker.com/_/postgres/) and [Redis](https://hub.docker.com/_/redis/) will be automatically downloaded and their containers linked to example service containers.

When you see `Connected to amqp:...` it means services are up and running.

Gateway service with HTTP Api is listening on port 8003 and these endpoitns are available to play with:

#### Create Product

```sh
$ curl -XPOST -d '{"id": "the_odyssey", "title": "The Odyssey", "passenger_capacity": 101, "maximum_speed": 5, "in_stock": 10}' 'http://localhost:8003/products'
```

#### Get Product

```sh
$ curl 'http://localhost:8003/products/the_odyssey'

{
  "id": "the_odyssey",
  "title": "The Odyssey",
  "passenger_capacity": 101,
  "maximum_speed": 5,
  "in_stock": 10
}
```
#### Create Order

```sh
$ curl -XPOST -d '{"order_details": [{"product_id": "the_odyssey", "price": "100000.99", "quantity": 1}]}' 'http://localhost:8003/orders'

{"id": 1}
```

#### Get Order

```sh
$ curl 'http://localhost:8003/orders/1'

{
  "id": 1,
  "order_details": [
    {
      "id": 1,
      "quantity": 1,
      "product_id": "the_odyssey",
      "image": "http://www.example.com/airship/images/the_odyssey.jpg",
      "price": "100000.99",
      "product": {
        "maximum_speed": 5,
        "id": "the_odyssey",
        "title": "The Odyssey",
        "passenger_capacity": 101,
        "in_stock": 9
      }
    }
  ]
}
```

## Running tests

Ensure RabbitMQ, PostgreSQL and Redis are running and `config.yaml` files for each service are configured correctly.

`$ make coverage`

## Debug / Project setup for repo

Please refer to [README-DevEnv.md](README-DevEnv.md)
