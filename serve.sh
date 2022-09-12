#!/bin/bash
set -ex

podman run --rm --name cert-nginx -d -p 8080:80 -v $(pwd)/static:/usr/share/nginx/html:Z nginx
