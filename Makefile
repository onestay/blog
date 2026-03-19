-include Makefile_vars

.PHONY: build sync server

build:
	hugo --minify

sync: build
	rsync -avz --delete ./public/ -e "ssh -i $(SSH_KEY)" $(DEPLOY_HOST):$(DEPLOY_PATH)

server:
	hugo server -D
