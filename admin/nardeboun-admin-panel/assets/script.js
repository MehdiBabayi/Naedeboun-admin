jQuery(document).ready(function($) {
    // مدیریت نمایش/پنهان کردن رشته بر اساس شاخه
    function manageTrackVisibility() {
        const branch = $('select[name="branch"]').val();
        const trackRow = $('select[name="track"]').closest('tr');
        
        if (branch === 'متوسطه دوم') {
            trackRow.show();
        } else {
            trackRow.hide();
            $('select[name="track"]').val('بدون رشته');
        }
    }
    
    // اعتبارسنجی فرم
    $('#nardeboun-upload-form').on('submit', function(e) {
        let hasError = false;
        
        // بررسی مدت زمان
        const totalSeconds = $('#total-seconds').text();
        if (parseInt(totalSeconds) <= 0) {
            alert('لطفاً مدت زمان معتبری وارد کنید');
            hasError = true;
        }
        
        // بررسی فیلدهای الزامی
        $('input[required], select[required]').each(function() {
            if (!$(this).val().trim()) {
                alert('لطفاً همه فیلدهای الزامی را پر کنید');
                hasError = true;
                return false;
            }
        });
        
        if (hasError) {
            e.preventDefault();
        }
    });
    
    // رویداد تغییر شاخه
    $('select[name="branch"]').on('change', manageTrackVisibility);
    
    // اجرای اولیه
    manageTrackVisibility();
});