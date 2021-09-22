# lukaszlach / satis-server

![Version](https://img.shields.io/badge/version-1.1-lightgrey.svg?style=flat)
[![Docker pulls](https://img.shields.io/docker/pulls/lukaszlach/satis-server.svg?label=docker+pulls)](https://hub.docker.com/r/lukaszlach/satis-server)
[![Docker stars](https://img.shields.io/docker/stars/lukaszlach/satis-server.svg?label=docker+stars)](https://hub.docker.com/r/lukaszlach/satis-server)

**Satis Server** provides ready to use solution for self-hosted repository of Composer packages, it is distributed as a lightweight [Docker image](https://hub.docker.com/r/lukaszlach/satis-server/) based on Alpine Linux. With the power of [Satis](https://github.com/composer/satis), [Composer](https://github.com/composer/composer) and [WebHook](https://github.com/adnanh/webhook) projects, it provides a set of powerful tools:

- **Private, self-hosted Composer repository** with unlimited private and open-source packages and support for Git, Mercurial, and Subversion.
- **[API](#satis-api)** - HTTP API with several endpoints allowing you to [add](#add) and [remove](#remove) packages, [build one](#build) single package or [whole repository](#build-all), [list](#list) packages with last build date information, [show](#show) package details, [dump](#dump) Satis configuration file. Access to the API can be [restricted](#restricting-access-to-api) to selected subnetwork mask.
- **[Webhook handler](#push)** - bind HTTP PUSH event in GitHub, GitLab or Beanstalk to automatically rebuild Satis index just after commit is made. This HTTP endpoint can be [secured with a pre-shared key](#securing).
- **[Scheduled builds](#scheduled-builds)** - periodically rebuild whole Satis repository, based on crontab expression.
- **[Command-line interface](#command-line-interface)** - manage Satis Server from command-line, all Satis API endpoints are available as shell commands.
- **[Build notifier](#build-notifier)** - send message to [Slack](#slack) or [HipChat](#hipchat) channel when repository or single package is rebuilt.
- **[HTTPs](#https)** support.

## Installing

![](https://img.shields.io/badge/docker-17.05+-lightgrey.svg?style=flat)
![](https://img.shields.io/badge/docker--compose-2.1+-lightgrey.svg?style=flat)

Use automated install script, that pulls Docker image, creates directory structure and configuration files and installs start/stop commands for you, by executing below command. If you prefer to do it manually - proceed with [usage instructions](#running), as Docker image will download automatically on first usage.

```bash
export SATIS_SERVER_VERSION=1.1
curl -L "https://raw.githubusercontent.com/lukaszlach/satis-server/$SATIS_SERVER_VERSION/install" | bash
```

You will see "satis-server installed and running" message after installation is done, `satis.json` file is created under `/etc/satis` (if did not exist before), this is also repository build directory where output JSON/ZIP files are stored. Configuration directory `/etc/satis-server` holds `satis-server.conf` that allows you to modify settings. 

Installation process also adds `satis-server-start` and `satis-server-stop` management commands and `satis-server-help` command.

You can use the same commands to upgrade Satis Server, all your configuration values, repository settings and packages will be preserved. Just change `SATIS_SERVER_VERSION` to desired version.

## Building manually

![](https://img.shields.io/badge/docker-17.05+-lightgrey.svg?style=flat)

You need to have [Docker](https://www.docker.com/get-docker) installed to run this project.

```bash
git clone https://github.com/lukaszlach/satis-server.git satis-server/
cd satis-server/
# build the "lukaszlach/satis-server:latest" image
make
```

## Running

> If you have installed Satis Server using automated install script there are `satis-server-start` and `satis-server-stop` commands already available on your server, below section covers manual installations.

In order to properly run Satis Server Docker container you need to pass at least one volume:

* *(required)* directory where `satis.json` configuration is kept and where built files will be stored, i.e. `/etc/satis`
* *(optional)* satis-server configuration directory, allows adding your own SSH key to use with private repositories and handle HTTPs, i.e. `/etc/satis-server`
* *(optional)* satis-server working directory where current status is kept, i.e. `/var/satis-server`

In case `/etc/satis/satis.json` does not exist in the container it will be created with empty repository settings. 

If you do not bind working directory volume, packages "last updated" information displayed by HTTP endpoints will be missing after Docker container is restarted. However, they can be always regenerated by rebuilding [the repository](#build-all) or [a single package](#build).

Container exposes Satis API on ports `80` and `443`, second one is reachable only with configured [HTTPs](#https). 

Below command runs Satis Server listening on port `8080`:

```bash
docker run -d \
    -p 8080:80 \
    -v /etc/satis:/etc/satis/ \
    -v /etc/satis-server/:/etc/satis-server/ \
    -v /var/satis-server/:/var/satis-server/ \
    --name satis_server \
    lukaszlach/satis-server:latest
```

You can also try an example `docker-compose.yml` file provided in this repository:

```bash
docker-compose -f docker-compose.yml.example up -d
```

Run `docker logs satis_server -f` to monitor logs or `docker stop satis_server` to stop the container.

> You can always view the documentation you are currently reading by calling `docker run --rm lukaszlach/satis-server:latest help`

## Configuration

### satis-server.conf

Automated installation creates configuration file under `/etc/satis-server/satis-server.conf` that is used by `docker-compose.yml` file from the same directory to start and stop the service, environment variables are passes automatically. This file has simple `FIELD=value` structure, currently below options are recognized:

- `PORT` - TCP port on which Satis API will listen on, default 8080
- `SSL_PORT` - default 443
- `REBUILD_AT` - see [Scheduled builds](#scheduled-builds)
- `PUSH_SECRET` - see [Securing with a pre-shared key](#securing)
- `API_ALLOW` - see [Restricting access to API](#restricting-access-to-api)
- `NOTIFY_DEBUG` - set to 1 to include extra information in notifications
- `NOTIFY_HIPCHAT` and `HIPCHAT_*` variables - see [Build notifier](#build-notifier) » [HipChat](#hipchat)
- `NOTIFY_SLACK` and `SLACK_*` variables - see [Build notifier](#build-notifier) » [Slack](#slack)

> `satis-server.conf.example` file with example configuration is available in root directory of this repository.

### SSH key for private repositories

In order to use private repositories (including GitHub) you have to provide SSH key that both Composer and Satis will use to fetch repository contents. 

SSH key should be available under `/etc/satis-server/ssh/id_rsa` file. If runnning manually you can do it with `-v /etc/satis-server:/etc/satis-server` to mount the whole config directory or `-v /path/to/id_rsa:/etc/satis-server/ssh/id_rsa` to mount this single file only.

### HTTPs

If you want to serve Satis API and webhook handler through HTTPs you need to place `cert.pem` and `key.pem` files inside `/etc/satis-server/https/` configuration directory. Existence of these files is detected automatically and after restart satis-server starts working over SSL.

### Scheduled builds

You can easily configure Satis Server to automatically rebuild the whole Satis repository once a day or every few hours/minutes. 

For automated installation you have to edit `REBUILD_AT` in `/etc/satis-server/satis-server.conf`, when running Docker image manually pass `SATIS_REBUILD_AT` environment variable i.e. `-e SATIS_REBUILD_AT="1 0 * * *"` to rebuild at one minute past midnight (00:01) every day. The value must be a valid [crontab](https://en.wikipedia.org/wiki/Cron) expression.

## Use your repository

Point Satis Server repository in your `composer.json` and require your packages by name, exactly as public packages.

```json
{
    "repositories": [
        {"type": "composer", "url": "https://your-server/"}
    ],
    "require": {
        "org/foo": "~1.0",
        "org/bar": "dev-master",
        "php-amqplib/php-amqplib": "v2.6.3"
    }
}
```

For more details read [Composer documentation](https://getcomposer.org/doc/articles/handling-private-packages-with-satis.md) on how to modify `composer.json` to work with your private repository.

> Such change in `composer.json` requires `composer update` command to be executed in order to update `composer.lock` file.

> If Satis Server does not work over HTTPs you need to set [secure-http](https://getcomposer.org/doc/06-config.md#secure-http) to `false`.

## Satis API

All HTTP endpoints are executing shell command underneath and return `200 OK` in case of success or `500 Internal Server Error` otherwise. Both `application/x-www-form-urlencoded` and `application/json` payloads are properly handled by all endpoints.

Raw command outputs are returned, sometimes including shell colors but this is useful when running on CI environments and sending HTTP requests from command-line.

Since Satis repository files can be found under `/` URL path, Satis API endpoints are available under `/api`.

### /push

PUSH events handler, returns immediately and does not wait for build to finish.

```
$ curl -sS -d'{"repository":{"url":"https://github.com/php-amqplib/php-amqplib"}}' -H'Content-Type: application/json' http://your-server:8080/api/push
```

Point `http://your-server:8080/api/push` as an URL to handle PUSH events on your repository.

#### Securing

As this endpoint is meant to be called by external services, you can protect it with a pre-shared key that will be required to call `/api/push` endpoint, it looks for `secret` query parameter so your final URL should look like this: `http://your-server:8080/api/push?secret=<PRE_SHARED_KEY>`.

To set the pre-shared key, either modify `PUSH_SECRET` variable in `/etc/satis-server/satis-server.conf` or pass it's value via environment variable: `-e PUSH_SECRET=d5a7c0d0c897665588cd0844744e3109`.

#### Integration

See below links for documentation how PUSH events work and how to configure them:
- GitHub - https://developer.github.com/v3/activity/events/types/#pushevent
- GitLab - https://docs.gitlab.com/ce/user/project/integrations/webhooks.html#push-events
- Beanstalk - http://support.beanstalkapp.com/article/931-classic-webhooks-integration

### /add

Add new package to Satis repository, send `POST` request and repository URL in `url` parameter.

```
$ curl -sS -d'url=https://github.com/php-amqplib/php-amqplib' http://your-server:8080/api/add
Your configuration file successfully updated! It's time to rebuild your repository  
```

### /remove

Remove package from Satis repository by URL, send `POST` request and point repository in `url` parameter.

```
$ curl -sS -d'url=https://github.com/php-amqplib/php-amqplib' http://your-server:8080/api/remove
Successfully removed https://github.com/php-amqplib/php-amqplib
```

### /build

Build a single package with matching repository URL, send `POST` request and point repository in `url` parameter.

```
$ curl -sS -d'url=https://github.com/php-amqplib/php-amqplib' http://your-server:8080/api/build
Scanning packages
Reading composer.json of php-amqplib/php-amqplib (v1.0)
Skipped tag v1.0, no composer file
Reading composer.json of php-amqplib/php-amqplib (v1.1)
Importing tag v1.1 (1.1.0.0)
Reading composer.json of php-amqplib/php-amqplib (v1.2.0)
Importing tag v1.2.0 (1.2.0.0)
...
```

### /build-all

Rebuild whole package repository, request is hold until process is done and it's output is returned.

```
$ curl -sS http://your-server:8080/api/build-all
Scanning packages
...
```

#### /show

Display details about selected package, send `POST` request and point repository in `url` parameter.

```
$ curl -sS -d'url=https://github.com/php-amqplib/php-amqplib' http://your-server:8080/api/show
Package: php-amqplib/php-amqplib
Description: Formerly videlalvaro/php-amqplib.  This library is a pure PHP implementation of the AMQP protocol. It's been tested against RabbitMQ.
Authors: Alvaro Videla, John Kelly, Raúl Araya
Releases: dev-channel_connection_closed, dev-master, dev-revert-460-HHVM-compat-bugfix, v1.1, v1.2.0, v1.2.1, v2.0.0, v2.0.1, v2.0.2, v2.1.0, v2.2.0, v2.2.1, v2.2.2, v2.2.3, v2.2.4, v2.2.5, v2.2.6, v2.3.0, v2.4.0, v2.4.1, v2.5.0, v2.5.1, v2.5.2, v2.6.0, v2.6.1, v2.6.2, v2.6.3, v2.7.0-rc1
Homepage: https://github.com/php-amqplib/php-amqplib/
Last built: Mon Jul 31 19:27:55 2017
```

### /list

List all packages in Satis repository.

```
$ curl -sS http://your-server:8080/api/list
PACKAGE NAME                    PACKAGE URL                                             LAST UPDATED
php-amqplib/php-amqplib         https://github.com/php-amqplib/php-amqplib              Mon Jul 31 19:27:55 2017
```

### /dump

Dump `satis.json` configuration file.

```
$ curl -sS http://your-server:8080/api/dump
{
    "name": "Your Repository",
    "homepage": "http://your-server",
    "repositories": [
        {
            "type": "vcs",
            "url": "https://github.com/php-amqplib/php-amqplib"
        }
    ]
}
```

### /version

Display versions of satis-server, Satis, Composer and PHP used inside the container.

```
$ curl -sS http://your-server:8080/api/version
satis-server 1.0 (build 20170731-24b177b)
Satis 1.0.0-dev
Composer version 1.4.2 2017-05-17 08:17:52
PHP 7.1.5 (cli) (built: May 13 2017 00:09:07) ( NTS )
webhook version 2.6.4
```

### /help

View HTML version of this documentation in web browser.

```
http://your-server:8080/help
```

## Restricting access to API

All Satis API endpoints can be restricted to specific subnetwork, except for `/api/push` which can be [secured using pre-shard key](#securing). 

By default API is opened for everyone, meaning `0.0.0.0/0`. To restrict access, set `API_ALLOW` to a valid subnetwork mask in [CIDR notation](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing#CIDR_blocks). If you are running Docker image manually, pass `API_ALLOW` environment variable: `-e API_ALLOW=192.168.1.0/24`.

## Command-line interface

All Satis API commands are available as shell commands inside the container. See available commands and example usages below.

### Enter satis-server and execute command

```
$ docker exec -it satis_server sh
/satis-server # satis-<TAB><TAB>
satis-add             satis-build-all       satis-list            satis-server
satis-build           satis-dump            satis-remove          satis-show
satis-server-version  satis-server-help


/satis-server # satis-show "https://github.com/php-amqplib/php-amqplib"
```

### Execute command directly on a running container

```
$ docker exec satis_server satis-show "https://github.com/php-amqplib/php-amqplib"
```

### Create command alias for portability

```
$ alias satis-server='docker exec satis_server'
$ satis-server satis-show "https://github.com/php-amqplib/php-amqplib"
```

## Build notifier

Notifications are sent before and after single package or the whole repository is built. To enable them you have to either edit `/etc/satis-server/satis-server.conf` file for automated installation or pass values as environment variables to Docker, i.e. `-e NOTIFY_HIPCHAT=1 -e ...`.

### HipChat

Set `NOTIFY_HIPCHAT=1` to enable HipChat notifications, you will also have to provide:

* `HIPCHAT_API` - base URL of your HipChat API, including trailing slash
* `HIPCHAT_ROOM` - room ID
* `HIPCHAT_TOKEN` - room notification token

### Slack

Set `NOTIFY_SLACK=1` to enable Slack notifications, you will also have to provide:

* `SLACK_URL` - "Incoming WebHook" URL
* `SLACK_ROOM` - room name

## Examples

### All possible parameters

So you can just remove what is not needed and replace rest with your values.

```bash
docker run -d \
    -p 8080:80 \
    -v /etc/satis:/etc/satis/ \
    -v /etc/satis-server/:/etc/satis-server/ \
    -v /var/satis-server/:/var/satis-server/ \
    -e PORT=8080 \
    -e SSL_PORT=443 \
    -e REBUILD_AT="1 0 * * *" \
    -e PUSH_SECRET=d5a7c0d0c897665588cd0844744e3109 \
    -e API_ALLOW="0.0.0.0/0" \
    -e NOTIFY_DEBUG=1 \
    -e NOTIFY_HIPCHAT=1 \
    -e HIPCHAT_API=https://hipchat.server.com/ \
    -e HIPCHAT_ROOM=123 \
    -e HIPCHAT_TOKEN=XTlyCeYH8rFhgjA4sJ8tu8UBnYhrmFOTPr5gM3J0 \
    -e NOTIFY_SLACK=1 \
    -e SLACK_ROOM=dev \
    -e SLACK_URL=https://hooks.slack.com/services/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 \
    --name satis_server \
    lukaszlach/satis-server:latest
```

## Licence

MIT License

Copyright (c) 2017 Łukasz Lach <llach@llach.pl>

Portions Copyright (c) 2015 Adnan Hajdarevic <adnanh@gmail.com>,
Portions Copyright (c) Composer,
Portions Copyright (c) 2012 Stephen Dolan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

[jq](https://github.com/stedolan/jq) :heart:
