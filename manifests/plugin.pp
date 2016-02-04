#
# config_filename = undef
#   Name of the config file for this plugin.
#
# config_content = undef
#   Content of the config file for this plugin. It is up to the caller to
#   create this content from a template or any other mean.
#
# update_url = undef
#
# source = undef
#   Direct URL from which to download plugin without modification.  This is
#   particularly useful for development and testing of plugins which may not be
#   hosted in the typical Jenkins' plugin directory structure.  E.g.,
#
#   https://example.org/myplugin.hpi
#
define jenkins::plugin(
  $version         = 0,
  $manage_config   = false,
  $config_filename = undef,
  $config_content  = undef,
  $update_url      = undef,
  $enabled         = true,
  $source          = undef,
  $digest_string   = '',
  $digest_type     = 'sha1',
  $timeout         = 120,
  # deprecated
  $plugin_dir      = undef,
  $username        = undef,
  $group           = undef,
  $create_user     = undef,
) {
  include ::jenkins

  validate_bool($manage_config)
  validate_bool($enabled)
  # TODO: validate_str($update_url)
  validate_string($source)
  validate_string($digest_string)
  validate_string($digest_type)

  if $plugin_dir {
    warning('jenkins::plugin::plugin_dir is deprecated and has no effect -- see jenkins::localstatedir')
  }
  if $username {
    warning('jenkins::plugin::username is deprecated and has no effect -- see jenkins::user')
  }
  if $group {
    warning('jenkins::plugin::group is deprecated and has no effect -- see jenkins::group')
  }
  if $create_user {
    warning('jenkins::plugin::create_user is deprecated and has no effect')
  }

  if ($version != 0) {
    $plugins_host = $update_url ? {
      undef   => $::jenkins::default_plugins_host,
      default => $update_url,
    }
    $base_url = "${plugins_host}/download/plugins/${name}/${version}/"
    $search   = "${name} ${version}(,|$)"
  }
  else {
    $plugins_host = $update_url ? {
      undef   => $::jenkins::default_plugins_host,
      default => $update_url,
    }
    $base_url = "${plugins_host}/latest/"
    $search   = "${name} "
  }

  # if $source is specified, it overrides any other URL construction
  $download_url = $source ? {
    undef   => "${base_url}${name}.hpi",
    default => $source,
  }

  $plugin_ext = regsubst($download_url, '^.*\.(hpi|jpi)$', '\1')
  $plugin     = "${name}.${plugin_ext}"

  if (empty(grep([ $::jenkins_plugins ], $search))) {
    if ($jenkins::proxy_host) {
      $proxy_server = "${jenkins::proxy_host}:${jenkins::proxy_port}"
    } else {
      $proxy_server = undef
    }

    $enabled_ensure = $enabled ? {
      false   => present,
      default => absent,
    }

    # Allow plugins that are already installed to be enabled/disabled.
    file { "${::jenkins::plugin_dir}/${plugin}.disabled":
      ensure  => $enabled_ensure,
      owner   => $::jenkins::user,
      group   => $::jenkins::group,
      mode    => '0644',
      require => File["${::jenkins::plugin_dir}/${plugin}"],
      notify  => Service['jenkins'],
    }

    file { "${::jenkins::plugin_dir}/${plugin}.pinned":
      owner   => $::jenkins::user,
      group   => $::jenkins::group,
      require => Archive[$plugin],
    }

    if $digest_string == '' {
      $checksum = false
      $_digest_string = undef
      $_digest_type = undef
    } else {
      $checksum = true
      $_digest_string = $digest_string
      $_digest_type = $digest_type
    }


    archive { $plugin:
      ensure          => present,
      path            => "${::jenkins::plugin_dir}/${plugin}",
      source          => $download_url,
      checksum_verify => $checksum,
      checksum        => $_digest_string,
      checksum_type   => $_digest_type,
      cleanup         => false,
      creates         => "${::jenkins::plugin_dir}/${plugin}",
      user            => $::jenkins::user,
      notify          => Service['jenkins'],
      require         => File[$::jenkins::plugin_dir]
    }

    file { "${::jenkins::plugin_dir}/${plugin}" :
      require => Archive[$plugin],
      owner   => $::jenkins::user,
      group   => $::jenkins::group,
      mode    => '0644',
    }
  }

  if $manage_config {
    if $config_filename == undef or $config_content == undef {
      fail 'To deploy config file for plugin, you need to specify both $config_filename and $config_content'
    }

    file {"${::jenkins::localstatedir}/${config_filename}":
      ensure  => present,
      content => $config_content,
      owner   => $::jenkins::user,
      group   => $::jenkins::group,
      mode    => '0644',
      notify  => Service['jenkins']
    }
  }
}
