init:
	if [ ! -f "data/database.sql" ]; then make download-seed-db; fi
	if [ ! -f "config/settings/settings.php" ] || [ ! -f "config/settings.settings.local.php" ]; then make download-drupal-settings; fi
	if [ ! -d "tests" ]; then make download-behat-tests; fi
	if [ ! -d "config/sync" ]; then make download-drupal-config; fi
	if [ ! -f "www/composer.json" ]; then make download-drupal-site; fi
	make up
	echo "Waiting for database to initialize"; sleep 15
	docker-compose exec -T php composer require drush/drush:8.* -n --working-dir=/var/www/html/www
	docker-compose exec -T php composer update --working-dir=/var/www/html/www
	-make update-tests
	docker-compose exec -T php chmod a+w /var/www/html/www/sites/default
	docker-compose exec -T php cp config/settings/settings.php www/sites/default/settings.php
	docker-compose exec -T php cp config/settings/settings.local.php www/sites/default/settings.local.php
	if [ ! -d "www/sites/default/files" ]; then docker-compose exec -T php mkdir /var/www/html/www/sites/default/files; fi
	docker-compose exec -T php chmod a+w /var/www/html/www/sites/default/files
ifdef TRAVIS
	docker-compose exec php /bin/bash -c "chown -Rf 1000:1000 /var/www"
endif
	docker-compose exec -T php /bin/bash -c "ls -l /var/www/html/www"
	docker-compose exec -T php www/vendor/bin/drush @default.dev status
	@make provision

download-seed-db:
	curl -o data/database.sql https://s3.us-east-2.amazonaws.com/dockerdrop/database.sql

up:
	docker-compose up -d --build
	docker-compose ps

down:
	docker-compose down
	docker-compose ps

clean-data:
	docker volume rm dockerdrop_db

provision:
	@echo "Running database updates..."
	@docker-compose exec -T php www/vendor/bin/drush @default.dev updb
	@echo "Running entity updates..."
	@docker-compose exec -T php www/vendor/bin/drush @default.dev entup
	@echo "Importing configuration..."
	@docker-compose exec -T php www/vendor/bin/drush @default.dev cim
	@echo "Running reverting features..."
	-docker-compose exec -T php www/vendor/bin/drush @default.dev fra -y
	@echo "Resetting cache..."
	@docker-compose exec -T php www/vendor/bin/drush @default.dev cr

phpcs:
	docker-compose exec -T php tests/bin/phpcs --config-set installed_paths tests/vendor/drupal/coder/coder_sniffer
	# Drupal 8
	docker-compose exec -T php tests/bin/phpcs --standard=Drupal www/modules/* www/themes/* --ignore=*.css --ignore=*.css,*.min.js,*features.*.inc,*.svg,*.jpg,*.png,*.json,*.woff*,*.ttf,*.md,*.sh --exclude=Drupal.InfoFiles.AutoAddedKeys

behat:
	docker-compose exec -T php tests/bin/behat -c tests/behat.yml --tags=~@failing --colors -f progress

update-tests:
	docker-compose exec -T php composer update --working-dir=/var/www/html/tests
	docker-compose exec -T php tests/bin/behat -c tests/behat.yml --init

download-drupal-settings:
	curl -o config/settings/settings.php https://s3.us-east-2.amazonaws.com/dockerdrop/settings.php
	curl -o config/settings/settings.local.php https://s3.us-east-2.amazonaws.com/dockerdrop/settings.local.php

download-drupal-site:
	rm -Rf www
	git clone --depth=1 https://github.com/codementality/drupal8-standard.git www
	rm -Rf www/.git

download-drupal-config:
	git clone --depth=1 https://github.com/codementality/dockerdrop-config.git config/sync
	rm -Rf config/sync/.git

download-behat-tests:
	git clone --depth=1 https://github.com/codementality/dockerdrop-tests.git tests
	rm -Rf tests/.git
	curl -o .travis.yml https://s3.us-east-2.amazonaws.com/dockerdrop/traviscfg.yml
