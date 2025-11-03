<?php
if ( ! defined( 'ABSPATH' ) ) exit;

function nardeboun_upload_video_page() {
    if ( ! current_user_can('manage_options') ) {
        wp_die('شما اجازهٔ دسترسی به این بخش را ندارید.');
    }

    // پردازش فرم
    if ( isset($_POST['nardeboun_upload_submit']) && check_admin_referer('nardeboun_upload_video') ) {

        $branch         = sanitize_text_field($_POST['branch'] ?? '');
        $grade          = sanitize_text_field($_POST['grade'] ?? '');
        $track          = sanitize_text_field($_POST['track'] ?? '');
        $subject        = sanitize_text_field($_POST['subject'] ?? '');
        $subject_slug   = sanitize_text_field($_POST['subject_slug'] ?? '');
        $chapter_title  = sanitize_text_field($_POST['chapter_title'] ?? '');
        $chapter_order  = intval($_POST['chapter_order'] ?? 1);
        $style          = sanitize_text_field($_POST['style'] ?? 'جزوه');
        $lesson_title   = sanitize_text_field($_POST['lesson_title'] ?? '');
        $lesson_order   = intval($_POST['lesson_order'] ?? 1);
        $teacher_name   = sanitize_text_field($_POST['teacher_name'] ?? '');
        
        // تبدیل زمان به ثانیه
        $hours      = intval($_POST['duration_hours'] ?? 0);
        $minutes    = intval($_POST['duration_minutes'] ?? 0);
        $seconds    = intval($_POST['duration_seconds'] ?? 0);
        $duration_sec = ($hours * 3600) + ($minutes * 60) + $seconds;
        
        $tags_input     = sanitize_text_field($_POST['tags'] ?? '');
        $embed_html     = wp_kses_post($_POST['embed_html'] ?? '');
        $note_pdf_url   = esc_url_raw($_POST['note_pdf_url'] ?? '');
        $exercise_pdf_url = esc_url_raw($_POST['exercise_pdf_url'] ?? '');

        $tags = array_filter(array_map('trim', explode(',', $tags_input)));

        // مدیریت PDFها بر اساس سبک
        $final_note_pdf_url = null;
        $final_exercise_pdf_url = null;
        
        if ($style === 'جزوه') {
            $final_note_pdf_url = $note_pdf_url ?: null;
            $final_exercise_pdf_url = null;
        } elseif ($style === 'نمونه سوال') {
            $final_note_pdf_url = null;
            $final_exercise_pdf_url = $exercise_pdf_url ?: null;
        } else {
            // کتاب درسی
            $final_note_pdf_url = null;
            $final_exercise_pdf_url = null;
        }

        $payload = [
            "branch"           => $branch,
            "grade"            => $grade,
            "track"            => ($track === 'بدون رشته' || empty($track)) ? null : $track,
            "subject"          => $subject,
            "subject_slug"     => $subject_slug,
            "chapter_title"    => $chapter_title,
            "chapter_order"    => $chapter_order,
            "lesson_title"     => $lesson_title,
            "lesson_order"     => $lesson_order,
            "teacher_name"     => $teacher_name,
            "style"            => $style,
            "duration_sec"     => $duration_sec,
            "tags"             => $tags,
            "embed_html"       => $embed_html ?: null,
            "allow_landscape"  => true,
            "note_pdf_url"     => $final_note_pdf_url,
            "exercise_pdf_url" => $final_exercise_pdf_url,
            "aparat_url"       => "" // ارسال رشته خالی
        ];

        $endpoint = 'https://jarkzyebfgpxywlxizeo.functions.supabase.co/create-content';

        if ( ! defined('SUPABASE_SERVICE_ROLE_KEY') ) {
            echo '<div class="error"><p>کلید Service Role تعریف نشده است. لطفا در فایل wp-config.php تعریف کنید:</p><code>define(\'SUPABASE_SERVICE_ROLE_KEY\', \'your-key-here\');</code></div>';
        } else {
            // نمایش اطلاعات ارسالی برای دیباگ
            echo '<div class="notice notice-info"><h3>اطلاعات ارسالی:</h3><pre>' . esc_html(json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)) . '</pre></div>';
            
            $response = wp_remote_post($endpoint, [
                'headers' => [
                    'Authorization' => 'Bearer ' . SUPABASE_SERVICE_ROLE_KEY,
                    'Content-Type'  => 'application/json'
                ],
                'body' => wp_json_encode($payload, JSON_UNESCAPED_UNICODE),
                'timeout' => 30
            ]);

            if ( is_wp_error($response) ) {
                echo '<div class="error"><p>خطا در ارتباط: ' . esc_html($response->get_error_message()) . '</p></div>';
            } else {
                $code = wp_remote_retrieve_response_code($response);
                $body = json_decode(wp_remote_retrieve_body($response), true);

                echo '<div class="notice notice-info"><p>کد پاسخ: ' . $code . '</p></div>';
                
                if ($code >= 200 && $code < 300 && !empty($body['success'])) {
                    echo '<div class="updated"><p>✅ ویدیو با موفقیت ثبت شد.</p>';
                    if (isset($body['data'])) {
                        echo '<pre>' . esc_html(print_r($body['data'], true)) . '</pre>';
                    }
                    echo '</div>';
                } else {
                    $err = $body['error'] ?? ('خطای ناشناخته - کد: ' . $code);
                    echo '<div class="error"><p>❌ خطا در آپلود: ' . esc_html($err) . '</p></div>';
                    if (isset($body['details'])) {
                        echo '<div class="error"><pre>' . esc_html(print_r($body['details'], true)) . '</pre></div>';
                    }
                }
            }
        }
    }

    // لیست دروس فارسی و اسلاگ‌ها
    $subject_options = [
        'ریاضی' => 'riazi',
        'علوم' => 'olom',
        'فارسی' => 'farsi',
        'قرآن' => 'quran',
        'مطالعات اجتماعی' => 'motaleat',
        'هدیه های آسمانی' => 'hediye',
        'نگارش' => 'negaresh',
        'عربی' => 'arabi',
        'انگلیسی' => 'englisi',
        'دینی' => 'dini',
        'فیزیک' => 'fizik',
        'شیمی' => 'shimi',
        'هندسه' => 'hendese',
        'هنر' => 'honar',
        'جغرافیا' => 'joghrafia',
        'فناوری' => 'fanavari',
        'تفکر و سبک زندگی' => 'tafakor',
        'حسابان' => 'hesaban',
        'زمین شناسی' => 'zamin',
        'محیط زیست' => 'mohit',
        'تاریخ' => 'tarikh',
        'سلامت و بهداشت' => 'salamat',
        'هویت اجتماعی' => 'hoviat',
        'مدیریت خانواده' => 'modiriat',
        'ریاضیات گسسته' => 'gosaste',
        'آمادگی دفاعی' => 'amadegi',
        'اقتصاد' => 'eghtesad',
        'علوم و فنون ادبی' => 'fonon',
        'جامعه شناسی' => 'jameye',
        'کارگاه کارآفرینی' => 'kargah',
        'منطق' => 'mantegh',
        'فلسفه' => 'falsafe',
        'روانشناسی' => 'ravanshenasi',
        'زیست شناسی' => 'zist'
    ];

    // فرم
    ?>
    <div class="wrap">
        <h1>آپلود ویدیو - نردبون</h1>
        
        <div class="card">
            <h2>راهنما</h2>
            <p>• برای <strong>جزوه</strong>: فقط فیلد "لینک PDF جزوه" را پر کنید</p>
            <p>• برای <strong>نمونه سوال</strong>: فقط فیلد "لینک PDF نمونه سوال" را پر کنید</p>
            <p>• برای <strong>کتاب درسی</strong>: هیچ فیلد PDFیی پر نشود</p>
        </div>

        <form method="post" action="" id="nardeboun-upload-form">
            <?php wp_nonce_field('nardeboun_upload_video'); ?>
            <table class="form-table">
                <!-- 1. شاخه -->
                <tr>
                    <th scope="row"><label for="branch">شاخه</label></th>
                    <td>
                        <select name="branch" id="branch" required>
                            <option value="">-- انتخاب کنید --</option>
                            <option value="ابتدایی">ابتدایی</option>
                            <option value="متوسطه اول">متوسطه اول</option>
                            <option value="متوسطه دوم">متوسطه دوم</option>
                        </select>
                    </td>
                </tr>

                <!-- 2. پایه -->
                <tr>
                    <th scope="row"><label for="grade">پایه</label></th>
                    <td>
                        <select name="grade" id="grade" required>
                            <option value="">-- ابتدا شاخه را انتخاب کنید --</option>
                        </select>
                    </td>
                </tr>

                <!-- 3. رشته -->
                <tr>
                    <th scope="row"><label for="track">رشته</label></th>
                    <td>
                        <select name="track" id="track">
                            <option value="بدون رشته">بدون رشته</option>
                            <option value="ریاضی">ریاضی</option>
                            <option value="تجربی">تجربی</option>
                            <option value="انسانی">انسانی</option>
                        </select>
                    </td>
                </tr>

                <!-- 4. درس پایه -->
                <tr>
                    <th scope="row"><label for="subject">درس پایه</label></th>
                    <td>
                        <select name="subject" id="subject" required>
                            <option value="">-- انتخاب کنید --</option>
                            <?php foreach ($subject_options as $persian_name => $slug): ?>
                                <option value="<?php echo esc_attr($persian_name); ?>" data-slug="<?php echo esc_attr($slug); ?>">
                                    <?php echo esc_html($persian_name); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </td>
                </tr>

                <!-- 5. اسلاگ درس -->
                <tr>
                    <th scope="row"><label for="subject_slug">اسلاگ درس</label></th>
                    <td>
                        <select name="subject_slug" id="subject_slug" required>
                            <option value="">-- انتخاب کنید --</option>
                            <?php foreach ($subject_options as $persian_name => $slug): ?>
                                <option value="<?php echo esc_attr($slug); ?>">
                                    <?php echo esc_html($slug); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                        <p class="description">شناسه انگلیسی درس (به طور خودکار با انتخاب درس پر می‌شود)</p>
                    </td>
                </tr>

                <!-- 6. عنوان فصل -->
                <tr>
                    <th scope="row"><label for="chapter_title">عنوان فصل</label></th>
                    <td>
                        <input type="text" name="chapter_title" id="chapter_title" required style="width: 100%;" placeholder="مثال: فصل اول - اعداد صحیح">
                    </td>
                </tr>

                <!-- 7. شماره فصل -->
                <tr>
                    <th scope="row"><label for="chapter_order">شماره فصل</label></th>
                    <td>
                        <input type="number" name="chapter_order" id="chapter_order" min="1" value="1" required>
                    </td>
                </tr>

                <!-- 8. نوع محتوا -->
                <tr>
                    <th scope="row"><label for="style">نوع محتوا</label></th>
                    <td>
                        <select name="style" id="style" required>
                            <option value="جزوه">جزوه</option>
                            <option value="کتاب درسی">کتاب درسی</option>
                            <option value="نمونه سوال">نمونه سوال</option>
                        </select>
                    </td>
                </tr>

                <!-- 9. عنوان درس -->
                <tr>
                    <th scope="row"><label for="lesson_title">عنوان درس</label></th>
                    <td>
                        <input type="text" name="lesson_title" id="lesson_title" required style="width: 100%;" placeholder="مثال: درس اول - جمع اعداد">
                    </td>
                </tr>

                <!-- 10. شماره درس -->
                <tr>
                    <th scope="row"><label for="lesson_order">شماره درس</label></th>
                    <td>
                        <input type="number" name="lesson_order" id="lesson_order" min="1" value="1" required>
                    </td>
                </tr>

                <!-- 11. نام استاد -->
                <tr>
                    <th scope="row"><label for="teacher_name">نام استاد</label></th>
                    <td>
                        <input type="text" name="teacher_name" id="teacher_name" required style="width: 100%;" placeholder="مثال: استاد احمدی">
                    </td>
                </tr>

                <!-- 12. مدت زمان ویدیو -->
                <tr>
                    <th scope="row"><label for="duration_hours">مدت زمان ویدیو</label></th>
                    <td>
                        <div class="duration-inputs">
                            <input type="number" name="duration_hours" id="duration_hours" min="0" value="0" placeholder="ساعت" style="width: 80px;">
                            <span>:</span>
                            <input type="number" name="duration_minutes" id="duration_minutes" min="0" max="59" value="0" placeholder="دقیقه" style="width: 80px;">
                            <span>:</span>
                            <input type="number" name="duration_seconds" id="duration_seconds" min="0" max="59" value="0" placeholder="ثانیه" style="width: 80px;">
                            <small style="margin-right: 10px;">(مجموع: <span id="total-seconds">0</span> ثانیه)</small>
                        </div>
                    </td>
                </tr>

                <!-- 13. تگ‌ها -->
                <tr>
                    <th scope="row"><label for="tags">تگ‌ها</label></th>
                    <td>
                        <input type="text" name="tags" id="tags" placeholder="مثال: حد, پایه ۹, تابع" style="width: 100%;">
                        <p class="description">با کاما جدا کنید (حداکثر ۱۰ تگ)</p>
                    </td>
                </tr>

                <!-- 14. Embed HTML -->
                <tr>
                    <th scope="row"><label for="embed_html">Embed HTML</label></th>
                    <td>
                        <textarea name="embed_html" id="embed_html" rows="4" placeholder='&lt;script src="https://www.aparat.com/embed/..."&gt;&lt;/script&gt;' style="width: 100%;"></textarea>
                        <p class="description">کد embed آپارات یا پلیر دیگر</p>
                    </td>
                </tr>

                <!-- 15. لینک PDF جزوه -->
                <tr>
                    <th scope="row"><label for="note_pdf_url">لینک PDF جزوه</label></th>
                    <td>
                        <input type="url" name="note_pdf_url" id="note_pdf_url" placeholder="https://..." style="width: 100%;">
                        <p class="description">فقط برای نوع محتوای «جزوه»</p>
                    </td>
                </tr>

                <!-- 16. لینک PDF نمونه سوال -->
                <tr>
                    <th scope="row"><label for="exercise_pdf_url">لینک PDF نمونه سوال</label></th>
                    <td>
                        <input type="url" name="exercise_pdf_url" id="exercise_pdf_url" placeholder="https://..." style="width: 100%;">
                        <p class="description">فقط برای نوع محتوای «نمونه سوال»</p>
                    </td>
                </tr>
            </table>
            
            <p class="submit">
                <input type="submit" name="nardeboun_upload_submit" class="button button-primary" value="ارسال ویدیو">
                <span id="form-status" style="margin-right: 15px;"></span>
            </p>
        </form>
    </div>

    <script type="text/javascript">
    jQuery(document).ready(function($) {
        // داده‌های پایه‌ها
        const gradesData = {
            'ابتدایی': ['یکم', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم'],
            'متوسطه اول': ['هفتم', 'هشتم', 'نهم'],
            'متوسطه دوم': ['دهم', 'یازدهم', 'دوازدهم']
        };

        // تابع بروزرسانی لیست پایه‌ها
        function updateGrades() {
            const branch = $('#branch').val();
            const gradeSelect = $('#grade');
            
            gradeSelect.empty();
            
            if (branch && gradesData[branch]) {
                gradesData[branch].forEach(function(grade) {
                    gradeSelect.append($('<option>', {
                        value: grade,
                        text: 'پایه ' + grade
                    }));
                });
            } else {
                gradeSelect.append($('<option>', {
                    value: '',
                    text: '-- ابتدا شاخه را انتخاب کنید --'
                }));
            }
        }

        // مدیریت نمایش رشته
        function updateTrackVisibility() {
            const branch = $('#branch').val();
            if (branch === 'متوسطه دوم') {
                $('#track').closest('tr').show();
            } else {
                $('#track').closest('tr').hide();
                $('#track').val('بدون رشته');
            }
        }

        // هماهنگ کردن درس و اسلاگ
        function syncSubjectSlug() {
            const subject = $('#subject').val();
            const selectedOption = $('#subject option[value="' + subject + '"]');
            const slug = selectedOption.data('slug');
            
            if (slug) {
                $('#subject_slug').val(slug);
            }
        }

        // مدیریت فیلدهای PDF بر اساس نوع محتوا
        function updatePdfFields() {
            const style = $('#style').val();
            const noteRow = $('#note_pdf_url').closest('tr');
            const exerciseRow = $('#exercise_pdf_url').closest('tr');
            
            if (style === 'جزوه') {
                noteRow.show();
                exerciseRow.hide();
                $('#exercise_pdf_url').val('');
            } else if (style === 'نمونه سوال') {
                noteRow.hide();
                exerciseRow.show();
                $('#note_pdf_url').val('');
            } else {
                noteRow.hide();
                exerciseRow.hide();
                $('#note_pdf_url').val('');
                $('#exercise_pdf_url').val('');
            }
        }

        // محاسبه کل ثانیه‌ها
        function calculateTotalSeconds() {
            const hours = parseInt($('#duration_hours').val()) || 0;
            const minutes = parseInt($('#duration_minutes').val()) || 0;
            const seconds = parseInt($('#duration_seconds').val()) || 0;
            
            const total = (hours * 3600) + (minutes * 60) + seconds;
            $('#total-seconds').text(total);
        }

        // اعتبارسنجی فرم
        function validateForm() {
            let isValid = true;
            const status = $('#form-status');
            
            // بررسی فیلدهای الزامی
            $('input[required], select[required]').each(function() {
                if (!$(this).val().trim()) {
                    $(this).addClass('error-field');
                    isValid = false;
                } else {
                    $(this).removeClass('error-field');
                }
            });
            
            // بررسی مدت زمان
            const totalSeconds = parseInt($('#total-seconds').text());
            if (totalSeconds <= 0) {
                $('#duration_hours').addClass('error-field');
                isValid = false;
                status.text('❌ مدت زمان باید بیشتر از صفر باشد').css('color', 'red');
            } else {
                $('#duration_hours').removeClass('error-field');
                status.text('✅ فرم معتبر است').css('color', 'green');
            }
            
            return isValid;
        }

        // رویدادها
        $('#branch').on('change', function() {
            updateGrades();
            updateTrackVisibility();
        });
        
        $('#subject').on('change', syncSubjectSlug);
        $('#style').on('change', updatePdfFields);
        
        $('input[name="duration_hours"], input[name="duration_minutes"], input[name="duration_seconds"]')
            .on('input', calculateTotalSeconds);
            
        $('input, select').on('input change', validateForm);

        // مقداردهی اولیه
        updateGrades();
        updateTrackVisibility();
        updatePdfFields();
        calculateTotalSeconds();
    });
    </script>

    <style>
    .duration-inputs {
        display: flex;
        align-items: center;
        gap: 5px;
    }
    .duration-inputs span {
        font-weight: bold;
    }
    .form-table th {
        width: 200px;
    }
    .error-field {
        border-color: #dc3232 !important;
        box-shadow: 0 0 2px rgba(220, 50, 50, 0.8) !important;
    }
    .card {
        background: #fff;
        border: 1px solid #ccd0d4;
        border-radius: 4px;
        padding: 15px;
        margin-bottom: 20px;
    }
    .card h2 {
        margin-top: 0;
    }
    </style>
    <?php
}