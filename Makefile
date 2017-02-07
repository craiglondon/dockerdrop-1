init:
	if [[ ! -f "data/database.sql" ]]; then make download-seed-db; fi
	docker-compose up -d --build
	docker-compose ps
	docker-compose exec php composer update --working-dir=/var/www/html/www
	-make update-tests
	echo "Waiting for database to initialize"; sleep 15
	@make provision

download-seed-db:
	curl -o data/database.sql https://s3.us-east-2.amazonaws.com/dockerdrop/database.sql

down:
	docker-compose down
	docker-compose ps

provision:
	@echo "Running database updates..."
	@docker-compose exec -T php drush @default.dev updb
	@echo "Running entity updates..."
	@docker-compose exec -T php drush @default.dev entup
	@echo "Importing configuration..."
	@docker-compose exec -T php drush @default.dev cim
	@echo "Running reverting features..."
	-docker-compose exec -T php drush @default.dev fra
	@echo "Resetting cache..."
	@docker-compose exec -T php drush @default.dev cr

lint:
	@echo "Running lint checker on php code..."
	@docker-compose exec -T web php -l www

phpcs:
	docker-compose exec -T php tests/bin/phpcs --config-set installed_paths tests/vendor/drupal/coder/coder_sniffer
	# Drupal 8
	docker-compose exec -T php tests/bin/phpcs --standard=Drupal www/modules/custom/*/* www/themes/custom/*/* --ignore=*.css --ignore=*.css,*.min.js,*features.*.inc,*.svg,*.jpg,*.png,*.json,*.woff*,*.ttf,*.md,*.sh --exclude=Drupal.InfoFiles.AutoAddedKeys

behat:
	docker-compose exec -T php tests/bin/behat -c tests/behat.yml --tags=~@failing --colors -f progress

update-tests:
	docker-compose exec -T php composer update --working-dir=/var/www/html/tests
	docker-compose exec -T php tests/bin/behat -c tests/behat.yml --init
