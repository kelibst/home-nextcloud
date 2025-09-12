<?php
$CONFIG = array (
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => 
  array (
    0 => 
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => 
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => 
  array (
    'host' => 'redis',
    'password' => 'redispassword',
    'port' => 6379,
  ),
  'overwriteprotocol' => 'http',
  'trusted_proxies' => 
  array (
    0 => '172.0.0.0/8',
    1 => '192.168.0.0/16',
    2 => '10.0.0.0/8',
    3 => 'host.docker.internal',
    5 => '192.168.1.98',
  ),
  'upgrade.disable-web' => true,
  'passwordsalt' => 'pmuwUnj8Ur/7Xr5thhKDJFMkFmhWfW',
  'secret' => 'mL+OCx2Ce8WlRJFKG7yfcgCLrZ44kmRh5pK+XeBPdg2lcMGl',
  'trusted_domains' => 
  array (
    0 => 'localhost',
    1 => '172.26.58.22',
    2 => '192.168.1.98',
    3 => 'host.docker.internal',
  ),
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'pgsql',
  'version' => '31.0.8.1',
  'overwrite.cli.url' => 'http://localhost',
  'dbname' => 'nextcloud',
  'dbhost' => 'nextcloud-db',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'dbuser' => 'oc_admin',
  'dbpassword' => 'NqAGV09I1Uj76SAfWEOKleq2lp9gJP',
  'installed' => true,
  'instanceid' => 'ocn18a46ww76',
);
