# Set up extra repositories ##############################################
##########################################################################
include epel

# Ensure needed services are running and unnesecary ones arn't #########
########################################################################
# NOTE:  SSHD is already declared to be kept running in the ssh module.
include limitservices

# Disable certain setuid/setgid binaries #################################
##########################################################################
include restrictsetuid


# Common Packages for all machines #######################################
##########################################################################
package { 'screen':
    ensure => 'installed',
}

package { 'wget':
    ensure => 'installed',
}

package { 'man':
    ensure => 'installed',
}

package { 'tmux':
    ensure => 'installed',
}

# Control sshd settings and secure its config ############################
##########################################################################
class { 'ssh::server':
    storeconfigs_enabled => false,
    options => {
        'X11Forwarding' => 'no',
        'PasswordAuthentication' => 'no',
        'PermitRootLogin' => 'no',
        'AllowTCPForwarding' => 'no',
	'Protocol' => '2',
	'AllowGroups' => 'wheel',
	'LoginGraceTime' => '30',
	'ClientAliveInterval' => '600',
	'ClientAliveCountMax' => 0,
    }
}

# Ensure hosts file contains all hosts in our network ####################
##########################################################################
host { 'puppet.test':
    ip => '10.25.62.1',
    host_aliases => ['puppet']
}

host { 'test-mgmt.test':
    ip => '10.25.62.1',
    host_aliases => ['test-mgmt']
}

host { 'test-web.test':
    ip => '10.25.62.2',
    host_aliases => ['test-web']
}

# Manage SELinux and ensure it is set to enforcing #######################
##########################################################################
class { 'selinux':
    mode => 'enforcing'
}

# Enable NTP #############################################################
##########################################################################
class { '::ntp':
  servers => [ '0.pool.ntp.org', '1.pool.ntp.org', 
		'2.pool.ntp.org', '3.pool.ntp.org' ],
}

# Load Common Firewall Rules from modules/default_fw_rules ###############
##########################################################################
Firewall {
    before => Class['default_fw_rules::post'],
    require => Class['default_fw_rules::pre']
}
class { ['default_fw_rules::pre', 'default_fw_rules::post']:}

# Set mounts and appropriate options #####################################
##########################################################################
    

# Define administrative users, keys, and sudo access #####################
##########################################################################
user { 'dehus':
    ensure => present,
    uid => 500,
    comment => 'Mark Dehus',
    groups => ['wheel'],
    password => '$6$HvSd.TvF$YQTyac48IicTejZcTAFJteORt6IaKfS/yEbnX3bITr1FoD1nKyNBaNxaxQErcAV5wyvCA3EUt/lpIUYG0KQLZ0',
}

group { 'dehus':
    ensure => present,
    gid => 500,
}

file { '/home/dehus':
    ensure => 'directory',
    owner => 'dehus',
    group => 'dehus',
    mode => '0750',
    require => [ User[dehus], Group[dehus]],
}

file {'/home/dehus/.ssh':
    ensure => 'directory',
    owner => 'dehus',
    group => 'dehus',
    mode => '0700',
    require => File['/home/dehus'],
}

ssh_authorized_key { 'dehus@storm':
    user => 'dehus',
    type => 'ssh-rsa',
    key => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQDN0GfZpsGqlXfza++LMUnGWwuoNdp32KbFwItDJvwSWLQh0WqidoZwjCPnJjKsf5znqeyir5WShcgGbAdyffp8Q57k7fk1efNtKQ0QwPEkzUEi6qnMSht0NH8l+QoCbTUEna8ZVfD2n1/q0fIiBXqq2gGf4ChZxlDDfVeiP6fBFbdPAE76jEzMpwiMhAflIutRG5TVRuHqfia627L8niJvKGb2wJFrfz3yPKK6+0+X5ntG6nfpYngyoo0ZNsQoCRva2U72YfK5S17AJHgmZOqrqQDd7vej7cBzHby88zbTbm1WooYrDUQDEtaWejzp6eAhr/M/sqyvRgPj9Os6VUG7',
    require => File['/home/dehus/.ssh'],
}

class { 'sudo' : }
sudo::conf { 'wheel':
    ensure => present,
    content => '%wheel ALL=ALL',
}

# Ensure non-puppet data is purged #####################################
########################################################################
resources { 'user':
    purge => true
}

resources { 'firewall':
    purge => true
}


# Server specific settings #############################################
########################################################################
node 'test-mgmt.test' {
    firewall { '200 allow incoming puppet':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '8140',
        action => 'accept',
    }

    package { 'rpm-build':
        ensure => 'installed',
    }

    package { 'createrepo':
        ensure => 'installed',
    }

    service { 'puppetmaster':
        ensure => 'running',
        enable => true,
    }
}

# could be replaced with regex to apply to all web servers... might
# be a good idea to involve heira at that point.
#node /^test-web.*\.test$/ {
node 'test-web.test' {
    user { 'root':
        ensure => present,
        uid => 0,
        password => '$6$vmhbYyyN$kJNwlRvX9zb68QzoxSRmzXw1v00dbwwkQAJ95Up7RUeDM4a80W2LvegMRh.35MkaeOZ22VwuuIR2T4XuC2JbZ0',
    }

    yumrepo { 'elasticsearch':
        descr => 'Elasticsearch repository for 1.5.x packages',
        baseurl => 'http://packages.elasticsearch.org/elasticsearch/1.5/centos',
        enabled => 1,
        gpgcheck => 1,
        gpgkey => 'http://packages.elasticsearch.org/GPG-KEY-elasticsearch',
    }
 
    package { 'elasticsearch':
        ensure => 'installed',
        require => Yumrepo['elasticsearch'],
    }

    package { 'daemonize':
        ensure => 'installed',
    }

    class { 'java':
        distribution => 'jre',
    }

    service { 'elasticsearch':
        ensure => 'running',
        enable => true,
    }  

    firewall { '200 allow incoming http':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '80',
        action => 'accept',
    }

    class { 'apache':
        default_mods => false,
        default_confd_files => false,
        default_vhost => false,
    }

    apache::mod { 'dir': }

    apache::vhost {'testweb':
        port => 80,
        docroot => '/var/www/html',
        directoryindex => ['index.html index.htm'],
        options => ['None'],
    }
   
}
