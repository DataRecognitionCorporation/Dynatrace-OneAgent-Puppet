# @summary
#   This class downloads the OneAgent installer binary
#
class dynatraceoneagent::download {

  if !defined('archive') {
    class { 'archive':
      seven_zip_provider => '',
    }
  }

  $created_dir              = $dynatraceoneagent::created_dir
  $download_dir             = $dynatraceoneagent::download_dir
  $filename                 = $dynatraceoneagent::filename
  $download_path            = $dynatraceoneagent::download_path
  $proxy_server             = $dynatraceoneagent::proxy_server
  $allow_insecure           = $dynatraceoneagent::allow_insecure
  $download_options         = $dynatraceoneagent::download_options
  $download_link            = $dynatraceoneagent::download_link
  $download_cert_link       = $dynatraceoneagent::download_cert_link
  $cert_file_name           = $dynatraceoneagent::cert_file_name
  $ca_cert_src_path         = $dynatraceoneagent::ca_cert_src_path
  $provider                 = $dynatraceoneagent::provider
  $oneagent_params_hash     = $dynatraceoneagent::oneagent_params_hash
  $reboot_system            = $dynatraceoneagent::reboot_system
  $service_name             = $dynatraceoneagent::service_name
  $package_state            = $dynatraceoneagent::package_state
  $global_owner             = $dynatraceoneagent::global_owner
  $global_group             = $dynatraceoneagent::global_group
  $global_mode              = $dynatraceoneagent::global_mode

  if $package_state != 'absent' {
    file{ $download_dir:
      ensure => directory
    }

    if ($::kernel == 'Linux' or $::osfamily  == 'AIX') {
      $etag_file = "${download_path}.etag"
      exec {"touch ${etag_file}":
        command => "touch ${etag_file}",
        path    => ['/usr/bin', '/bin'],
        unless  => "test -e ${etag_file}",
        creates => $etag_file,
      }

      # Fetch current ETag
      exec { 'get_current_etag':
        command => "curl -sI ${download_link} | grep -i etag | awk '{ print \$2; }' | tr -d '\r\"' > /tmp/current.etag",
        path    => ['/usr/bin', '/bin'],
      }

      # Download file if ETag changed
      exec { $filename:
        command     =>  "curl -s ${download_link} -o ${download_path}",
        path        => ['/usr/bin', '/bin'],
        unless      => "diff -q /tmp/current.etag ${etag_file}",
        require     => Exec['get_current_etag'],
        notify      => Exec['Create_etag_file'],
      }

      exec { 'Create_etag_file':
        command     => "cp /tmp/current.etag ${etag_file}",
        path        => ['/usr/bin', '/bin'],
        refreshonly => true,
      }
    } else {
      archive{ $filename:
        ensure           => present,
        extract          => false,
        source           => $download_link,
        path             => $download_path,
        allow_insecure   => $allow_insecure,
        require          => File[$download_dir],
        creates          => $created_dir,
        proxy_server     => $proxy_server,
        cleanup          => false,
        download_options => $download_options,
      }
    }
  }

  if ($::kernel == 'Linux' or $::osfamily  == 'AIX') and ($dynatraceoneagent::verify_signature) and ($package_state != 'absent'){

    file { $dynatraceoneagent::dt_root_cert:
      ensure  => present,
      mode    => $global_mode,
      source  => "puppet:///${ca_cert_src_path}",
      require => File[$download_dir]
    }

    $verify_signature_command = "( echo 'Content-Type: multipart/signed; protocol=\"application/x-pkcs7-signature\"; micalg=\"sha-256\";\
     boundary=\"--SIGNED-INSTALLER\"'; echo ; echo ; echo '----SIGNED-INSTALLER' ; \
     cat ${download_path} ) | openssl cms -verify -CAfile ${dynatraceoneagent::dt_root_cert} > /dev/null"

    exec { 'delete_oneagent_installer_script':
        command   => "rm ${$download_path} ${dynatraceoneagent::dt_root_cert}",
        cwd       => $download_dir,
        timeout   => 6000,
        provider  => $provider,
        logoutput => on_failure,
        unless    => $verify_signature_command,
        require   => [
            File[$dynatraceoneagent::dt_root_cert],
            Archive[$filename],
        ],
        creates   => $created_dir,
    }
  }
}
