# Set up extra repositories ##############################################
##########################################################################
include epel
yumrepo { 'localrepo':
    descr => 'Level3 Systems Exercise Local Repository',
    baseurl => 'http://test-mgmt.test',
    enabled => 1,
    gpgcheck => 1,
    gpgkey => 'http://goo.gl/kPy9NM',
}



# Ensure needed services are running and unnesecary ones arn't #########
########################################################################
# NOTE:  SSHD is already declared to be kept running in the ssh module.
include limitservices
service { 'monit':
    ensure => 'running',
    enable => true,
}



# Disable certain setuid/setgid binaries #################################
##########################################################################
include restrictsetuid


# Common Packages for all machines #######################################
##########################################################################
package { 'screen': ensure => 'installed'}
package { 'wget': ensure => 'installed'}
package { 'man': ensure => 'installed'}
package { 'tmux': ensure => 'installed'}
package { 'nc': ensure => 'installed' }
package { 'lynis': ensure => 'installed'}
package { 'monit': ensure => 'installed', require => Yumrepo['localrepo']}

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
	'ClientAliveCountMax' => '0',
        'StrictModes' => 'yes',
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
class { 'selinux': mode => 'enforcing' }

# Harden kernel settings #################################################
##########################################################################
sysctl { 'net.ipv4.conf.all.accept_redirects': value => 0 }
sysctl { 'net.ipv6.conf.default.accept_redirects': value => 0 }
sysctl { 'net.ipv4.conf.all.log_martians': value => 1 }
sysctl { 'net.ipv4.conf.all.rp_filter': value => 1 }
sysctl { 'net.ipv4.conf.all.send_redirects': value => 0 }
sysctl { 'net.ipv4.conf.default.accept_redirects': value => 0 }
sysctl { 'net.ipv4.conf.default.log_martians': value => 1 }
sysctl { 'net.ipv4.tcp_timestamps': value => 0 }
sysctl { 'net.ipv6.conf.all.accept_redirects': value => 0 }
sysctl { 'net.ipv4.tcp_synack_retries': value => 3 }
sysctl { 'net.ipv4.tcp_max_syn_backlog': value => 2048 }


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
resources { 'user': purge => true }
resources { 'firewall': purge => true }


# Server specific settings #############################################
########################################################################
node 'test-mgmt.test' {
    # Users #########################
    user { 'root':
        ensure => present,
        uid => 0,
        password => '$6$Sp4u29/n$7P6vFIdCucUBzJyfRVmerMQsma8woTba2YTb5FhSjDLC9RRUfPTjVB8rtsZrw07q5T43EEVC8BvuYb52KArAh0',
    }

    # Firewall Rules ###############
    firewall { '200 allow incoming puppet':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '8140',
        source => '10.25.62.0/24',
        action => 'accept',
    }

    firewall { '201 allow incoming http':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '80',
        source => '10.25.62.0/24',
        action => 'accept',
    }

    firewall { '202 allow incoming monit webgui from ext':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '8080',
        source => '10.0.2.0/24',
        action => 'accept',
    }

    firewall { '203 allow incoming monit webgui from int':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '8080',
        source => '10.25.62.0/24',
        action => 'accept',
    }

    firewall { '204 allow incoming syslog':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'udp',
        dport => '514',
        source => '10.25.62.0/24',
        action => 'accept',
    }

    # Software ##################
    package { 'pdsh': ensure => 'installed' }
    package { 'gcc': ensure => 'installed' }
    package { 'git': ensure => 'installed' }
    package { 'flex': ensure => 'installed' }
    package { 'bison': ensure => 'installed' }
    package { 'openssl-devel': ensure => 'installed' }
    package { 'pam-devel': ensure => 'installed' }
    package { 'rpm-build': ensure => 'installed' }
    package { 'createrepo': ensure => 'installed' }
    package { 'mmonit': ensure => 'installed', require => Yumrepo['localrepo'] }

    # Services ################
    service { 'puppetmaster':
        ensure => 'running',
        enable => true,
    }

    service { 'mmonit':
        ensure => 'running',
        enable => true,
    }

    class { 'apache':
        default_mods => false,
        default_confd_files => false,
        default_vhost => false,
    }

    apache::mod { 'dir': }

    apache::vhost { 'testmgmt':
        port => 80,
        docroot => '/var/www/repo',
        directoryindex => ['index.html index.htm'],
        options => ['None'],
    }   

}

# could be replaced with regex to apply to all web servers... might
# be a good idea to involve heira at that point.
#node /^test-web.*\.test$/ {
node 'test-web.test' {
    # Users #########################
    user { 'root':
        ensure => present,
        uid => 0,
        password => '$6$vmhbYyyN$kJNwlRvX9zb68QzoxSRmzXw1v00dbwwkQAJ95Up7RUeDM4a80W2LvegMRh.35MkaeOZ22VwuuIR2T4XuC2JbZ0',
    }

    # Software ######################
    yumrepo { 'elasticsearch':
        descr => 'Elasticsearch repository for 1.5.x packages',
        baseurl => 'http://packages.elasticsearch.org/elasticsearch/1.5/centos',
        enabled => 1,
        gpgcheck => 1,
        gpgkey => 'http://packages.elasticsearch.org/GPG-KEY-elasticsearch',
    }

    yumrepo { 'logstash':
        descr => 'logstash repository for 1.4.x packages',
        baseurl => 'http://packages.elasticsearch.org/logstash/1.4/centos',
        enabled => 1,
        gpgcheck => 1,
        gpgkey => 'http://packages.elasticsearch.org/GPG-KEY-elasticsearch',
    }
 
    package { 'elasticsearch':
        ensure => 'installed',
        require => Yumrepo['elasticsearch'],
    }

    package { 'logstash':
        ensure => 'installed',
        require => Yumrepo['logstash'],
    }

    package { 'daemonize':
        ensure => 'installed',
    }

    class { 'java':
        distribution => 'jre',
    }

    # Services ###################################
    service { 'elasticsearch':
        ensure => 'running',
        enable => true,
    }  

    service { 'kibana':
        ensure => 'running',
        enable => true,
    }  

    service { 'logstash':
        ensure => 'running',
        enable => true,
    }  

    # Firewall rules ##############################
    firewall { '200 allow incoming http':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '80',
        action => 'accept',
    }

    firewall { '201 allow incoming monit':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '2812',
        source => '10.25.62.0/24',
        action => 'accept',
    }

    firewall { '202 allow incoming kibana':
        chain => 'INPUT',
        state => ['NEW'],
        proto => 'tcp',
        dport => '8080',
        action => 'accept',
    }

    # Apache Configuration ######################
    selboolean { 'httpd_can_network_connect':
        name => 'httpd_can_network_connect',
        persistent => true,
        value => 'on',
    }

    class { 'apache':
        default_mods => false,
        default_confd_files => false,
        default_vhost => false,
    }

    apache::mod { 'dir': }

    apache::vhost { 'testweb':
        port => 80,
        docroot => '/var/www/html',
        directoryindex => ['index.html index.htm'],
        options => ['None'],
    }

    apache::vhost { 'kibana':
        port => 8080,
        docroot => '/var/www/kibana',
        proxy_dest => "http://localhost:5601",
    }
   
}
