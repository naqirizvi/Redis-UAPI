package Cpanel::API::SSO;

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

sub generate {
    my $success = 1;
    my $siteurl    = '';
    my ( $args, $result ) = @_;
    my ( $domain, $user ) = encode_entities($args->get( 'domain', 'user' ));

    my $username = $Cpanel::user;
    my $secret = `cat /proc/sys/kernel/random/uuid`;
    my $path="/home/$username/public_html";

    $domain     =~ tr/a-z_A-Z0-9\-\/\=\ \"\.,//cd;
    $secret=~ s/^\s+|\s+$//g;
    if (index($domain, 'staging') != -1) {
        $path="/home/$username/public_html/$domain";
    }

my $deli = <<'string_ending_delimiter';
<?php

@unlink(__FILE__);

if ($_GET['pass'] != 'SECRET'){
        die("Unauthorized Access");
}

define('WPMU_PLUGIN_DIR', '/home/x11kccb/public_html/n9ssxezpiewgnhkkbd3yyduz9uaechzr');
define('WP_PLUGIN_DIR', '/home/x11kccb/public_html/n9ssxezpiewgnhkkbd3yyduz9uaechzr');
define('WP_USE_THEMES', false);

$_SERVER['SCRIPT_NAME'] = '/wp-login.php';

require('wp-blog-header.php');
require('wp-includes/pluggable.php');

if (!is_user_logged_in()){

        $signon_user = '';

        if(!empty($signon_user) && !preg_match('/^\[\[(.*?)\]\]$/is', $signon_user)){
                $user = get_user_by('login', $signon_user);
        }else{
                $user_info = get_userdata(1);

                if(empty($user_info) || empty($user_info->user_login)){
                        $admin_id = get_users(array('role__in' => array('administrator'), 'number' => 1, 'fields' => array('ID')));
                        $user_info = get_userdata($admin_id[0]->ID);
                }

                $username = $user_info->user_login;
                $user = get_user_by('login', $username);
        }

        if(!is_wp_error($user)){
                wp_clear_auth_cookie();
                wp_set_current_user($user->ID);
                wp_set_auth_cookie($user->ID);

                if(file_exists(dirname(__FILE__).'/wp-content/plugins/wp-simple-firewall')){

                        try{

                                global $wpdb;

                                $wpsf_session_id = md5(uniqid('icwp-wpsf'));

                                $wpdb->insert($wpdb->prefix."icwp_wpsf_sessions", array(
                                   "session_id" => $wpsf_session_id,
                                   "wp_username" => $user->user_login,
                                   "ip" => $_SERVER['REMOTE_ADDR'],
                                   "browser" => md5($_SERVER['HTTP_USER_AGENT']),
                                   "last_activity_uri" => "/wp-login.php",
                                   "logged_in_at" => time(),
                                   "last_activity_at" => time(),
                                   "login_intent_expires_at" => 0,
                                   "secadmin_at" => 0,
                                   "created_at" => time(),
                                   "deleted_at" => 0,
                                ));

                                setcookie("wp-icwp-wpsf", $wpsf_session_id, time()+ DAY_IN_SECONDS * 30);

                        } catch(Exception $e){

                        }
                }
        }
}

$redirect_to = admin_url();
wp_safe_redirect( $redirect_to );

exit();
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
        $result->message("https://$domain/sapp-wp-signon.php?pass=$secret");
        return 1;
    }
    else {
        $result->error('Unable to generate SSO');
        return 0;
    }
}

1;