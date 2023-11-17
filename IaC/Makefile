
TERRA_CMD = terraform -chdir=/app/tf_infra
CREDENTIALS = credentials.tfvars
VARIABLES = terraform.tfvars
BUILD_DIR =
RUN_DIR =/app
TERRA_OPTIONS = -var-file=$(RUN_DIR)/$(CREDENTIALS)  -var-file=$(RUN_DIR)/$(VARIABLES)
.PHONY: setup init plan apply clean

setup: sts.json
	echo "Setting up"

init: .terraform
	$(TERRA_CMD) init

plan: $(CREDENTIALS) $(VARIABLES)
	$(TERRA_CMD) plan $(TERRA_OPTIONS)

apply: 
	$(TERRA_CMD) apply $(TERRA_OPTIONS)

clean:
	rm sts.json