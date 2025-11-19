# @summary
#   This class manages the installation of the OneAgent on the host
#
class dynatraceoneagent::install {

  $created_dir              = $dynatraceoneagent::created_dir
  $download_dir             = $dynatraceoneagent::download_dir
  $install_dir              = $dynatraceoneagent::install_dir
  $version_link             = $dynatraceoneagent::version_link
  $filename                 = $dynatraceoneagent::filename
  $download_path            = $dynatraceoneagent::download_path
  $provider                 = $dynatraceoneagent::provider
  $oneagent_params_hash     = $dynatraceoneagent::oneagent_params_hash
  $reboot_system            = $dynatraceoneagent::reboot_system
  $service_name             = $dynatraceoneagent::service_name
  $package_state            = $dynatraceoneagent::package_state
  $oneagent_puppet_conf_dir = $dynatraceoneagent::oneagent_puppet_conf_dir

  if ($::kernel == 'Linux' or $::osfamily  == 'AIX'){
    $current_version_file = '/tmp/current_version.txt'
    exec { 'get_latest_version':
      command => "curl -s ${version_link} | jq -r .latestAgentVersion > /tmp/latest_version.txt",
      path    => ['/usr/bin', '/bin'],
    }
    
    exec {"touch_current_version":
      command => "touch ${current_version_file}",
      path    => ['/usr/bin', '/bin'],
      unless  => "test -e ${install_dir}/agent/installer.version",
    }

    exec { 'get_current_version':
      command => "cp ${install_dir}/agent/installer.version ${current_version_file}",
      path    => ['/usr/bin', '/bin'],
      onlyif  => "test -e ${install_dir}/agent/installer.version",
    }

    exec { 'Copy_from_tmp_uninstall':
      command => "cp /tmp/uninstall.sh ${install_dir}/agent/",
      path    => ['/usr/bin', '/bin'],
      onlyif  => 'test -e /tmp/uninstall.sh',
      unless  => "test -e ${install_dir}/agent/uninstall.sh",
    }
    
    exec { 'install_oneagent':
      command   => $dynatraceoneagent::command,
      cwd       => $download_dir,
      timeout   => 6000,
      creates   => $created_dir,
      provider  => $provider,
      logoutput => on_failure,
      unless    => "diff -q ${current_version_file} /tmp/latest_version.txt",
      require   => Exec['Copy_from_tmp_uninstall'],
    }

    # Ensure uninstall script is copied if new install
    file { 'Copy_uninstall_tmp':
      path      => '/tmp/uninstall.sh',
      ensure    => file,
      source    => "${install_dir}/agent/uninstall.sh",
      mode      => '0750',
      owner     => 'root',
      group     => 'dtuser',
      replace   => true,
      subscribe => Exec['install_oneagent'],
    }
  }

  if ($::osfamily == 'Windows') {
    package { $service_name:
      ensure          => $package_state,
      provider        => $provider,
      source          => $download_path,
      install_options => [$oneagent_params_hash, '--quiet'],
    }
  }

  if ($reboot_system) and ($::osfamily == 'Windows') {
    reboot { 'after':
      subscribe => Package[$service_name],
    }
  } elsif ($::kernel == 'Linux' or $::osfamily  == 'AIX') and ($reboot_system) {
      reboot { 'after':
        subscribe => Exec['install_oneagent'],
      }
  }

}
