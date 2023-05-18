package Cpanel::API::Redis;

use strict;
use HTML::Entities;

our $VERSION = '1.0';

undef $ENV{'HTTP_HOST'};
undef $ENV{'SERVER_SOFTWARE'};

use Cpanel                   ();
use Cpanel::API              ();
use Cpanel::Locale           ();
use Cpanel::Logger           ();

my $logger;
my $locale;
our $success = 1;
our $siteurl    = '';
our $username = $Cpanel::user;
my $secret = `cat /proc/sys/kernel/random/uuid`;
our $path="/home/$username/public_html";
our $webroot="/home/$username/public_html";
our $redis_root="/home/$username/redis";

sub install_redis {
our ( $args, $result ) = @_;
my ( $domain, $user ) = encode_entities($args->get( 'domain', 'user' ));
    $domain     =~ tr/a-z_A-Z0-9\-\/\=\ \"\.,//cd;
    $secret=~ s/^\s+|\s+$//g;
    if (index($domain, 'staging') != -1) {
        $path="/home/$username/public_html/$domain";
    }

my $deli = <<'string_ending_delimiter';
string_ending_delimiter

    $deli =~ s/SECRET/$secret/g;

    open (SSO, ">$path/sapp-wp-signon.php") or
         $success = 0;
    print SSO $deli;
    close (SSO);

    if ($success) {
        $result->metadata('metadata_var', '1');
        use Encode qw(encode);
        $result->data( encode( 'utf-8',$Cpanel::user ) );
        $result->message("Redis Installed $secret");
        return 1;
    }
    else {
        $result->error('Unable to Install Redis');
        return 0;
    }
}

sub install_ocp {
my ( $args, $result ) = @_;
mkdir($redis_root) unless(-d $redis_root);

my $cmd = `curl -s https://raw.githubusercontent.com/naqirizvi/rocket/main/redis.conf -o $redis_root/redis.conf`;
my $cmd = `curl -s https://raw.githubusercontent.com/naqirizvi/rocket/main/start_redis.sh -o $redis_root/start_redis.sh`;
#my $cmd = `sed -i "s@REDISDIR@$redis_root@g" $redis_root/* 2>/dev/null`
my $cmd = `chmod 755 $redis_root/start_redis.sh`
my $cmd = `bash $redis_root/start_redis.sh`

        $result->metadata('metadata_var', '1');
        use Encode qw(encode);
        $result->data( encode( 'utf-8',$Cpanel::user ) );
        $result->message("Redis Installed $path $secret");
        return 1;
}

1;