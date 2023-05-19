package Cpanel::API::Redis;

use strict;
use HTML::Entities;
use warnings;

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

my $redis_config=`curl -s https://raw.githubusercontent.com/naqirizvi/rocket/main/redis.conf`;
$redis_config =~ s/REDISDIR/$redis_root/g;
open (CONFIG, ">$redis_root/redis.conf") or $success = 0;
print CONFIG $redis_config;
close (CONFIG);

my $start_redis_bash=`curl -s https://raw.githubusercontent.com/naqirizvi/rocket/main/start_redis.sh`;
$start_redis_bash =~ s/REDISDIR/$redis_root/g;
open (BASH, ">$redis_root/start_redis.sh") or $success = 0;
print BASH $start_redis_bash;
close (BASH);

`chmod 755 $redis_root/start_redis.sh`;
`bash $redis_root/start_redis.sh`;

#`/usr/local/cpanel/share/WordPressManager/wp config delete WP_REDIS_CONFIG --path="$webroot 2>&1`;
#`/usr/local/cpanel/share/WordPressManager/wp config delete WP_REDIS_SCHEME --path="$webroot 2>&1`;
#`/usr/local/cpanel/share/WordPressManager/wp config delete WP_REDIS_PATH --path="$webroot 2>&1`;

$data = qx("/usr/local/cpanel/share/WordPressManager/wp" config set WP_REDIS_CONFIG "$value" --path=$webroot 2>&1 );
#my $data = qx("/usr/local/cpanel/share/WordPressManager/wp config delete WP_REDIS_CONFIG --path=$webroot");
my $error   = substr $data, 0, 6;
if($error eq 'Error:')
{
    $result->error( $data, $error );
    return 0;
}
else
{
    $result->data($data);
    return 1;
}

        $result->metadata('metadata_var', '1');
        use Encode qw(encode);
        $result->data( encode( 'utf-8',$Cpanel::user ) );
        $result->message("Redis Installed $path $secret");
        return 1;
}

1;