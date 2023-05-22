package Cpanel::API::Redis;

use strict;
use HTML::Entities;
use warnings;
use IPC::System::Simple qw(capture);

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

my $data = qx("/usr/local/cpanel/share/WordPressManager/wp" config delete WP_REDIS_CONFIG --path=$webroot 2>&1 );
my $data = qx("/usr/local/cpanel/share/WordPressManager/wp" config delete WP_REDIS_SCHEME --path=$webroot 2>&1 );
my $data = qx("/usr/local/cpanel/share/WordPressManager/wp" config delete WP_REDIS_PATH --path=$webroot 2>&1 );
my $data = qx("/usr/local/cpanel/share/WordPressManager/wp" plugin install https://rocketscripts.space/assets/object-cache-pro.zip --activate --path=$webroot 2>&1 );
my $data = qx("/usr/local/cpanel/share/WordPressManager/wp" plugin update object-cache-pro --path=$webroot 2>&1 );
my $error   = substr $data, 0, 6;
if($error eq 'Error:')
{
    #$result->error( $data, $error );
    #return 0;
}
else
{
    #$result->data($data);
    #return 1;
}

    my $redis_wp_config=`curl -s https://raw.githubusercontent.com/naqirizvi/rocket/main/WP_REDIS_CONFIG`;
    $redis_wp_config =~ s/USERNAME/$username/g;

    my $filename = "$webroot/wp-config.php";

    my $search_string = '<?php';
    my $replace_string = $redis_wp_config;

    open(my $file, '<', $filename) or die "Cannot open file '$filename': $!";
    my $file_content = do { local $/; <$file> };
    close($file);

    $file_content =~ s/\Q$search_string/$replace_string/;

    open($file, '>', $filename) or die "Cannot open file '$filename': $!";
    print $file $file_content;
    close($file);

my $cmd = qx("/usr/local/cpanel/share/WordPressManager/wp" redis enable --force --path=$webroot 2>&1 );
my $command = "bash /home/$username/redis/start_redis.sh >/dev/null 2>&1";

# Append the new cron job to the existing crontab
my $schedule = '*/5 * * * *';
my $crontab = `crontab -l`;
#$crontab .= "$schedule $command\n";

##
##my $cron_file = '/var/spool/cron/' . $username;
##my $cron_job = "*/5 * * * * bash /home/$username/redis/start_redis.sh >/dev/null 2>&1";
##
### Read the existing cron file
##open(my $fh, '<', $cron_file) or die "Failed to open $cron_file: $!";
##my @cron_lines = <$fh>;
##close($fh);
##
### Find and modify the cron job
 my $modified = 0;
foreach my $line ($crontab) {
    if ($line =~ /^"\*\/5 \* \* \* \* bash \/home\/$username\/redis\/start_redis.sh >\/dev\/null 2>&1"/) {
        $line = "$schedule $command\n";
        $modified = 1;
        last;
    }
}
##
### Append the modified cron job if it doesn't exist
if (!$modified) {
    push $crontab, "$schedule $command\n";
}


capture("echo \"$crontab\" | crontab -");

##
### Write the updated cron file
##open($fh, '>', $cron_file) or die "Failed to open $cron_file for writing: $!";
##print $fh @cron_lines;
##close($fh);
##
##
##my $cron_file = '/etc/crontab';
##my $cron_job = '/5 * * * * bash /home/$username/redis/start_redis.sh >/dev/null 2>&1';
###
###open(my $fh, '<', $cron_file) or die "Failed to open $cron_file: $!";
###my @cron_lines = <$fh>;
###close($fh);
##
##push @cron_lines, $cron_job . "\n";
##
##open($fh, '>', $cron_file) or die "Failed to open $cron_file for writing: $!";
##print $fh @cron_lines;
##close($fh);



    $result->metadata('metadata_var', '1');
    use Encode qw(encode);
    $result->data( encode( 'utf-8',$Cpanel::user ) );
    $result->message("Redis Installed $path First occurrence of $search_string has been replaced with $replace_string in $filename.\n");
    return 1;
}

1;