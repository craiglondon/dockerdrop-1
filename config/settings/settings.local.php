<?php
$databases['default']['default'] = array (
  'database' => 'drupal',
  'username' => 'drupal',
  'password' => 'drupal',
  'prefix' => '',
  'host' => 'db',
  'port' => '3306',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'driver' => 'mysql',
);
$settings['install_profile'] = 'standard';
$config_directories = array(
  CONFIG_SYNC_DIRECTORY => '../config/sync',
);
$settings['trusted_host_patterns'] = array(
  '^localhost$',
  '^web$'
);
$base_url = 'http://localhost:8000';
