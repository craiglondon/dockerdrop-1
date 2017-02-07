init:
	if [ ! -f "data/database.sql" ]; then make download-seed-db; fi
	docker-compose up -d --build
	echo "Waiting for database to initialize"; sleep 15
	docker-compose ps
	docker-compose exec -T php composer update --working-dir=/var/www/html/www
	-make update-tests
	docker-compose exec -T php chmod a+w /var/www/html/www/sites/default
	docker-compose exec -T php cp config/settings/settings.php www/sites/default/settings.php
	docker-compose exec -T php cp config/settings/local.settings.php www/sites/default/local.settings.php
	if [ ! -d "www/sites/default/files" ]; then docker-compose exec -T php mkdir /var/www/html/www/sites/default/files; fi
	docker-compose exec -T php chmod a+w /var/www/html/www/sites/default/files
ifdef TRAVIS
	docker-compose exec php /bin/bash -c "chown -Rf 1000:1000 /var/www"
endif
	docker-compose exec -T php /bin/bash -c "ls -l /var/www/html/www"
	docker-compose exec -T php drush @default.dev status
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

phpcs:
	docker-compose exec -T php tests/bin/phpcs --config-set installed_paths tests/vendor/drupal/coder/coder_sniffer
	# Drupal 8
	docker-compose exec -T php tests/bin/phpcs --standard=Drupal www/modules/* www/themes/* --ignore=*.css --ignore=*.css,*.min.js,*features.*.inc,*.svg,*.jpg,*.png,*.json,*.woff*,*.ttf,*.md,*.sh --exclude=Drupal.InfoFiles.AutoAddedKeys

behat:
	docker-compose exec -T php tests/bin/behat -c tests/behat.yml --tags=~@failing --colors -f progress

update-tests:
	docker-compose exec -T php composer update --working-dir=/var/www/html/tests
	docker-compose exec -T php tests/bin/behat -c tests/behat.yml --init
