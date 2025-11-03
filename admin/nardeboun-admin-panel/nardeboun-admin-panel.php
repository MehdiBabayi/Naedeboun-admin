<?php
/**
 * Plugin Name: Nardeboun Admin Panel
 * Description: پنل اپلیکیشن نردبون برای مدیریت و آپلود ویدیوها
 * Version: 1.0.1
 * Author: Omid
 */

if ( ! defined( 'ABSPATH' ) ) exit; // جلوگیری از دسترسی مستقیم

define('NARDEBOUN_PANEL_VERSION', '1.0.1');
define('NARDEBOUN_PANEL_SLUG', 'nardeboun-admin-panel');
define('NARDEBOUN_PANEL_PATH', plugin_dir_path(__FILE__));
define('NARDEBOUN_PANEL_URL', plugin_dir_url(__FILE__));

// بارگذاری استایل/اسکریپت فقط روی صفحات پنل
add_action('admin_enqueue_scripts', function($hook) {
    $is_panel = (isset($_GET['page']) && in_array($_GET['page'], ['nardeboun-admin-panel','nardeboun-upload-video'], true));
    if ($is_panel) {
        wp_enqueue_style('nardeboun-panel-style', NARDEBOUN_PANEL_URL . 'assets/style.css', array(), NARDEBOUN_PANEL_VERSION);
        wp_enqueue_script('nardeboun-panel-script', NARDEBOUN_PANEL_URL . 'assets/script.js', array('jquery'), NARDEBOUN_PANEL_VERSION, true);
    }
});

// ثبت منوها
function nardeboun_register_admin_menu() {
    add_menu_page(
        'پنل اپلیکیشن نردبون',
        'پنل اپلیکیشن نردبون',
        'manage_options',
        NARDEBOUN_PANEL_SLUG,
        'nardeboun_admin_dashboard',
        'dashicons-smartphone',
        3
    );

    add_submenu_page(
        NARDEBOUN_PANEL_SLUG,
        'آپلود ویدیو',
        'آپلود ویدیو',
        'manage_options',
        'nardeboun-upload-video',
        'nardeboun_upload_video_page'
    );
}
add_action('admin_menu', 'nardeboun_register_admin_menu');

// داشبورد اصلی
function nardeboun_admin_dashboard() {
    if ( ! current_user_can('manage_options') ) {
        wp_die('شما اجازهٔ دسترسی به این بخش را ندارید.');
    }

    echo '<div class="wrap">';
    echo '<h1>پنل اپلیکیشن نردبون</h1>';
    echo '<p>از منوی سمت چپ گزینه «آپلود ویدیو» را انتخاب کنید.</p>';
    echo '</div>';
}

// بارگذاری صفحه آپلود ویدیو
require_once NARDEBOUN_PANEL_PATH . 'includes/upload-video.php';
