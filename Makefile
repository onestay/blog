-include Makefile_vars

.PHONY: build sync server

build:
	hugo --minify

sync: build
	rsync -avz --delete -e "ssh -i $(SSH_KEY)" ./public/ $(DEPLOY_HOST):$(DEPLOY_PATH)

dry-run: build
	rsync -avz --delete --dry-run -e "ssh -i $(SSH_KEY)" ./public/ $(DEPLOY_HOST):$(DEPLOY_PATH)

server:
	hugo server -D
