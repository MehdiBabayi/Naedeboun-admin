import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/mini_request/content_counts_model.dart';
import '../../models/mini_request/mini_request_state.dart';
import '../../models/content/step_by_step_pdf.dart';
import '../../models/content/provincial_sample_pdf.dart';
import '../../models/content/banner.dart';
import '../../models/content/subject.dart';
import '../../models/content/chapter.dart';
import '../../models/content/lesson.dart';
import '../../models/content/lesson_video.dart';
// import '../../models/content/book_cover.dart';
import '../content/book_cover_service.dart';
import '../content/content_service.dart';
import '../auth/auth_service.dart';
import '../image_cache/smart_image_cache_service.dart';
import 'mini_request_logger.dart';
import '../../utils/logger.dart';

/// سرویس Mini-Request برای به‌روزرسانی خودکار محتوا
class MiniRequestService {
  static final MiniRequestService _instance = MiniRequestService._internal();
  static MiniRequestService get instance => _instance;
  MiniRequestService._internal();

  Timer? _timer;
  bool _isInitialized = false;
  Completer<void>? _checkCompleter; // برای جلوگیری از race condition
  final _supabase = Supabase.instance.client;
  final _logger = MiniRequestLogger.instance;
  late final AuthService _authService;
  final _contentService = ContentService(Supabase.instance.client);

  // Stream برای Progress و State
  final _progressController = StreamController<double>.broadcast();
  final _stateController = StreamController<MiniRequestState>.broadcast();

  // 🔔 Stream برای بنرهای جدید (برای Smart Image Cache)
  final _newBannersController = StreamController<List<AppBanner>>.broadcast();

  Stream<double> get downloadProgress => _progressController.stream;
  Stream<MiniRequestState> get state => _stateController.stream;
  Stream<List<AppBanner>> get onNewBanners => _newBannersController.stream;

  MiniRequestState _currentState = MiniRequestState.idle;

  /// مقداردهی اولیه سرویس
  Future<void> init() async {
    if (_isInitialized) return;

    _logger.log('Initializing Mini-Request Service...', LogLevel.info);

    // Initialize AuthService
    _authService = AuthService(supaBase: _supabase);

    // ✅ همیشه فعال است. همیشه در لانچ اجرا کن:
    _logger.log('Mini-Request ALWAYS enabled, config bypassed', LogLevel.info);
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      _logger.log('Running on launch... (force)', LogLevel.info);
      await checkForUpdates(force: true);
    } else {
      _logger.log(
        'Skipping launch check - user not logged in',
        LogLevel.warning,
      );
    }

    // شروع Timer
    _startTimer();

    _isInitialized = true;
    _logger.log(
      'Mini-Request Service initialized successfully',
      LogLevel.success,
    );
  }

  /// شروع Timer برای چک کردن دوره‌ای
  void _startTimer() {
    const intervalHours = 2; // هر دو ساعت یکبار
    _logger.log(
      'Starting timer with interval: ${intervalHours}h',
      LogLevel.info,
    );

    _timer = Timer.periodic(
      Duration(hours: intervalHours),
      (_) => checkForUpdates(),
    );
  }

  /// 🚀 **اجرای دستی Mini-Request برای Prefetch کردن محتوا**
  /// این متد برای فراخوانی دستی بعد از لاگین یا تغییر پایه استفاده می‌شود.
  Future<void> runManually({int? gradeId, int? trackId}) async {
    Logger.info('🚀 [MINI-REQUEST] MANUALLY RUNNING MINI-REQUEST');
    Logger.info('🔍 [MINI-REQUEST] Grade: $gradeId, Track: $trackId');

    // با force=true فراخوانی کن تا گارد زمانی نادیده گرفته شود.
    await checkForUpdates(gradeId: gradeId, trackId: trackId, force: true);

    Logger.info('✅ [MINI-REQUEST] MANUAL RUN COMPLETED');
  }

  /// متوقف کردن Timer
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _logger.log('Timer stopped', LogLevel.info);
  }

  /// بررسی برای محتوای جدید (با محافظت از race condition)
  /// [force] - اگر true باشد، گارد زمانی نادیده گرفته می‌شود (برای تغییر پایه)
  Future<void> checkForUpdates({
    int? gradeId,
    int? trackId,
    bool force = false,
  }) async {
    Logger.debug('🔍 [MINI-REQUEST] checkForUpdates called with force=$force, gradeId=$gradeId, trackId=$trackId');

    // اگر در حال چک کردن است، منتظر بمان
    if (_checkCompleter != null && !_checkCompleter!.isCompleted) {
      Logger.info('⏳ [MINI-REQUEST] Already checking updates, waiting...');
      await _checkCompleter!.future;
      return;
    }

    _checkCompleter = Completer<void>();

    try {
      _currentState = MiniRequestState.checking;
      _stateController.add(_currentState);
      Logger.info('🚀 [MINI-REQUEST] Starting check for updates...');

      // دریافت grade و track از AuthService
      int? grade = gradeId;
      int? track = trackId;

      // اگر grade داده نشده، از AuthService بگیر
      if (grade == null) {
        final profile = _authService.currentProfile;
        if (profile != null) {
          grade = profile.grade;
          // track از field_of_study نمی‌تونیم بگیریم، فعلاً null
          track = null;
          _logger.log(
            'Got grade from AuthService profile',
            LogLevel.info,
            data: {'grade': grade, 'track': track},
          );
        }
      }

      // اگر هنوز grade نداریم، خطا بده
      if (grade == null) {
        _logger.log('No grade found, cannot proceed', LogLevel.error);
        throw Exception('User grade not found. Please complete registration.');
      }

      // 🛡️ گارد زمانی: اگر force نباشد و هنوز در بازه زمانی هستیم، چک نکن
      if (!force) {
        final intervalHours = 2; // هر دو ساعت یکبار
        final boxName = _getBoxName(grade, track);
        final box = await Hive.openBox(boxName);
        final lastCheckStr = box.get('last_check') as String?;

        if (lastCheckStr != null) {
          final lastCheck = DateTime.tryParse(lastCheckStr);
          if (lastCheck != null) {
            final elapsed = DateTime.now().difference(lastCheck);
            if (elapsed < Duration(hours: intervalHours)) {
              _logger.log(
                'Skip check: inside interval window',
                LogLevel.info,
                data: {
                  'elapsed_min': elapsed.inMinutes,
                  'interval_h': intervalHours,
                  'force': force,
                },
              );
              _currentState = MiniRequestState.completed;
              _stateController.add(_currentState);
              return; // هیچ چکی انجام نشود
            }
          }
        }
      }

      _logger.log(
        'Checking content for grade',
        LogLevel.info,
        data: {'grade': grade, 'track': track},
      );

      // دریافت counts از backend با fallback
      ContentCounts? newCounts;
      try {
        newCounts = await _getContentCountsFromBackend(grade, track);
      } catch (e) {
        _logger.log(
          'Counts backend failed, proceeding with direct caching',
          LogLevel.warning,
        );
      }

      // دریافت counts ذخیره شده
      final storedCounts = await _getStoredCounts(grade, track);

      _logger.log(
        'Count comparison',
        LogLevel.info,
        data: {
          'new': newCounts.toString(),
          'stored': storedCounts?.toString() ?? 'null',
        },
      );

      // مقایسه
      if (newCounts == null ||
          storedCounts == null ||
          newCounts.hasChanges(storedCounts)) {
        _logger.log('New content detected! Downloading...', LogLevel.success);

        _currentState = MiniRequestState.downloading;
        _stateController.add(_currentState);

        // Load book covers
        await _loadBookCovers(grade);

        // Load subjects metadata (از RPC)
        await _loadSubjectsMetadata(grade, track);

        // Load chapters metadata (برای تمام subjects)
        await _loadChaptersMetadata(grade, track);

        // Load lessons metadata (برای تمام chapters)
        await _loadLessonsMetadata(grade, track);

        // Load videos metadata (برای تمام lessons)
        await _loadVideosMetadata(grade, track);

        // Load and cache PDFs metadata directly (no RPC)
        await _loadStepByStepPdfsMetadata(grade, track);
        await _loadProvincialPdfsMetadata(grade, track);
        await _loadTeachersMetadata(grade, track);
        await _loadBannersMetadata(grade, track);

        // Store last_counts
        if (newCounts != null) {
          await _saveLastCountsOnly(grade, track, newCounts);
        }

        _currentState = MiniRequestState.completed;
        _stateController.add(_currentState);
        _logger.log('Content update completed', LogLevel.success);
      } else {
        _logger.log('No new content found', LogLevel.info);

        // 🚀 حتی اگر محتوای جدیدی نباشد، book covers را چک کن
        _logger.log('Checking book covers anyway...', LogLevel.info);
        await _loadBookCovers(grade);

        // Load subjects metadata (از RPC)
        await _loadSubjectsMetadata(grade, track);

        // Load chapters metadata (برای تمام subjects)
        await _loadChaptersMetadata(grade, track);

        // Load lessons metadata (برای تمام chapters)
        await _loadLessonsMetadata(grade, track);

        // Load videos metadata (برای تمام lessons)
        await _loadVideosMetadata(grade, track);

        // Ensure PDFs metadata are cached for fast access
        await _loadStepByStepPdfsMetadata(grade, track);
        await _loadProvincialPdfsMetadata(grade, track);
        await _loadTeachersMetadata(grade, track);
        await _loadBannersMetadata(grade, track);

        _currentState = MiniRequestState.completed;
        _stateController.add(_currentState);
      }

      // ذخیره timestamp آخرین چک
      await _saveLastCheckTimestamp(grade, track);
    } catch (e) {
      _logger.log('Error during check: $e', LogLevel.error);
      _currentState = MiniRequestState.error;
      _stateController.add(_currentState);
      _checkCompleter?.completeError(e);
      rethrow;
    } finally {
      if (_checkCompleter != null && !_checkCompleter!.isCompleted) {
        _checkCompleter!.complete();
      }

      // برگشت به حالت idle بعد از 2 ثانیه
      Future.delayed(const Duration(seconds: 2), () {
        _currentState = MiniRequestState.idle;
        _stateController.add(_currentState);
      });
    }
  }

  /// دریافت counts از backend
  Future<ContentCounts> _getContentCountsFromBackend(
    int grade,
    int? track,
  ) async {
    try {
      _logger.log('Calling backend function...', LogLevel.info);

      final response = await _supabase.functions.invoke(
        'mini_request_check_updates',
        body: {'grade': grade, 'track': track},
      );

      if (response.status != 200) {
        throw Exception('Backend returned status ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      final counts = data['counts'] as Map<String, dynamic>;

      _logger.log('Backend counts received', LogLevel.success);
      return ContentCounts.fromJson(counts);
    } catch (e) {
      _logger.log('Error getting counts from backend: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Load book covers for a specific grade
  Future<void> _loadBookCovers(int grade) async {
    try {
      Logger.info('📚 [MINI-REQUEST] ===== LOADING BOOK COVERS FOR GRADE: $grade =====');
      final covers = await BookCoverService.instance.getBookCoversForGrade(
        grade,
      );
      Logger.info('✅ [MINI-REQUEST] Loaded ${covers.length} book covers');

      // 🚀 Emit event for Smart Image Cache to prefetch
      if (covers.isNotEmpty) {
        // _newBookCoversController.add(covers);
      }

      // 🚀 Prefetch book cover images to warm cache
      if (covers.isNotEmpty) {
        Logger.info('🖼️ [MINI-REQUEST] Prefetching book cover images...');

        // دانلود همزمان همه عکس‌ها
        final downloadFutures = <Future>[];

        for (final cover in covers) {
          if (cover.subjectPath.isNotEmpty) {
            // Trigger background download
            final downloadFuture = SmartImageCacheService.instance
                .getBookCoverFromUrl(cover.subjectPath);
            downloadFutures.add(downloadFuture);
            Logger.debug('⬇️ [MINI-REQUEST] Queued download: ${cover.subjectName}');
          }
        }

        // منتظر بمان تا همه دانلودها شروع شوند
        await Future.wait(downloadFutures);
        Logger.info('✅ [MINI-REQUEST] All book cover downloads initiated');

        // Debug: Check cache status after a longer delay (commented out - cachedCount was unused)
        // Future.delayed(const Duration(seconds: 5), () async {
        //   int cachedCount = 0;
        //   for (final cover in covers) {
        //     if (cover.subjectPath.isNotEmpty) {
        //       final key = 'book_covers/url_${cover.subjectPath.hashCode}';
        //       final box = await Hive.openBox('image_cache');
        //       if (box.containsKey(key)) {
        //         cachedCount++;
        //       }
        //     }
        //   }
        //   // print(
        //   //   '🔍 [MINI-REQUEST] Cache status: $cachedCount/${covers.length} images cached',
        //   // );
        // });
      } else {
        Logger.info('⚠️ [MINI-REQUEST] No book covers found for grade: $grade');
      }
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error loading book covers: $e');
    }
  }

  Future<ContentCounts?> _getStoredCounts(int grade, int? track) async {
    try {
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      final countsJson = box.get('last_counts');

      if (countsJson == null) return null;

      return ContentCounts.fromJson(jsonDecode(countsJson));
    } catch (e) {
      _logger.log('Error getting stored counts: $e', LogLevel.warning);
      return null;
    }
  }

  // متد legacy حذف شد: دریافت تجمیعی محتوا از RPC get_all_content_for_grade

  /// فقط ذخیره کردن last_counts در Hive (وقتی فقط متادیتا را به‌روزرسانی می‌کنیم)
  Future<void> _saveLastCountsOnly(
    int grade,
    int? track,
    ContentCounts counts,
  ) async {
    try {
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      await box.put('last_counts', jsonEncode(counts.toJson()));
      await box.put('last_updated', DateTime.now().toIso8601String());
      _logger.log('Counts stored in Hive', LogLevel.success);
    } catch (e) {
      _logger.log('Error storing counts in Hive: $e', LogLevel.error);
    }
  }

  /// دریافت و کش کردن متادیتای PDF های گام به گام (بدون دانلود فایل)
  Future<void> _loadStepByStepPdfsMetadata(int grade, int? track) async {
    try {
      Logger.info('📄 [MINI-REQUEST] Loading StepByStep PDFs metadata: grade=$grade track=$track');

      // Query Supabase
      final response =
          await _supabase
                  .from('step_by_step_pdfs')
                  .select('*')
                  .eq('grade_id', grade)
                  .eq('active', true)
                  .filter('track_id', track == null ? 'is' : 'eq', track)
                  .order('updated_at', ascending: false)
              as List<dynamic>;

      final list = response
          .map((j) => StepByStepPdf.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      // Save in Hive box for this grade/track
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      await box.put(
        'step_by_step_pdfs',
        jsonEncode(list.map((p) => p.toJson()).toList()),
      );

      Logger.info('✅ [MINI-REQUEST] StepByStep PDFs cached: ${list.length} items');
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error loading StepByStep PDFs metadata: $e');
    }
  }

  /// دریافت و کش کردن متادیتای PDF های نمونه سوال استانی (بدون دانلود فایل)
  Future<void> _loadProvincialPdfsMetadata(int grade, int? track) async {
    try {
      Logger.info('📄 [MINI-REQUEST] Loading Provincial PDFs metadata: grade=$grade track=$track');

      // Query Supabase
      final response =
          await _supabase
                  .from('provincial_sample_pdfs')
                  .select('*')
                  .eq('grade_id', grade)
                  .eq('active', true)
                  .filter('track_id', track == null ? 'is' : 'eq', track)
                  .order('updated_at', ascending: false)
              as List<dynamic>;

      final list = response
          .map(
            (j) => ProvincialSamplePdf.fromJson(Map<String, dynamic>.from(j)),
          )
          .toList();

      // Save in Hive box for this grade/track
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      await box.put(
        'provincial_sample_pdfs',
        jsonEncode(list.map((p) => p.toJson()).toList()),
      );

      Logger.info('✅ [MINI-REQUEST] Provincial PDFs cached: ${list.length} items');
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error loading Provincial PDFs metadata: $e');
    }
  }

  /// دریافت و کش کردن نام اساتید (id -> name) برای نمایش سریع و آفلاین
  Future<void> _loadTeachersMetadata(int grade, int? track) async {
    try {
      Logger.info('👩‍🏫 [MINI-REQUEST] Loading teachers metadata (id→name)');

      // ساده: همه اساتید فعال را بگیر (کوچک و کم‌تغییر)
      final response =
          await _supabase
                  .from('teachers')
                  .select('id,name,active')
                  .eq('active', true)
              as List<dynamic>;

      final Map<String, String> idToName = {
        for (final t in response)
          (t['id'] as int).toString(): (t['name'] as String),
      };

      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      await box.put('teachers', jsonEncode(idToName));

      Logger.info('✅ [MINI-REQUEST] Teachers cached: ${idToName.length} items');
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error loading teachers metadata: $e');
    }
  }

  /// دریافت و کش کردن بنرها (metadata) برای نمایش سریع
  Future<void> _loadBannersMetadata(int grade, int? track) async {
    try {
      Logger.info('🎨 [MINI-REQUEST] Loading banners metadata: grade=$grade track=$track');

      var query = _supabase
          .from('banners')
          .select('*')
          .eq('grade_id', grade)
          .eq('active', true);

      // فیلتر بر اساس track (مانند منطق BannerService)
      if (track != null) {
        query = query.or('track_id.is.null,track_id.eq.$track');
      } else {
        query = query.isFilter('track_id', null);
      }

      final response =
          await query.order('display_order', ascending: true) as List<dynamic>;

      Logger.debug('📊 [MINI-REQUEST] Banners response: ${response.length} items');

      final list = response
          .map((j) => AppBanner.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      // ذخیره در Hive
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      await box.put(
        'banners',
        jsonEncode(list.map((b) => b.toJson()).toList()),
      );

      Logger.info('✅ [MINI-REQUEST] Banners cached: ${list.length} items');
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error caching banners: $e');
    }
  }

  /// دریافت و کش کردن subjects (metadata) از RPC
  Future<void> _loadSubjectsMetadata(int grade, int? track) async {
    try {
      Logger.info('📚 [MINI-REQUEST] Loading subjects metadata: grade=$grade track=$track');

      // استفاده از RPC function (همانند ContentService)
      final data =
          await _supabase.rpc(
                'get_active_subjects_for_user',
                params: {'p_grade_id': grade, 'p_track_id': track},
              )
              as List<dynamic>;

      if (data.isEmpty) {
        Logger.info('⚠️ [MINI-REQUEST] No subjects found for grade $grade');
        // حتی اگر subjects خالی باشند، یک لیست خالی ذخیره کن
        final boxName = _getBoxName(grade, track);
        final box = await Hive.openBox(boxName);
        await box.put('subjects', jsonEncode([]));
        return;
      }

      final subjects = data
          .map((j) => Subject.fromRpc(j as Map<String, dynamic>))
          .toList();

      // Save in Hive box for this grade/track
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      await box.put(
        'subjects',
        jsonEncode(subjects.map((s) => s.toJson()).toList()),
      );

      Logger.info('✅ [MINI-REQUEST] Subjects cached: ${subjects.length} items');
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error loading subjects metadata: $e');
    }
  }

  /// دریافت و کش کردن chapters (metadata) برای تمام subjects
  Future<void> _loadChaptersMetadata(int grade, int? track) async {
    try {
      Logger.info('📖 [MINI-REQUEST] Loading chapters metadata: grade=$grade track=$track');

      // ابتدا subjects را از Hive بخوان (که تازه ذخیره شدند)
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      final subjectsJson = box.get('subjects');

      if (subjectsJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No subjects found, cannot load chapters');
        return;
      }

      final List<dynamic> subjectsData = jsonDecode(subjectsJson);
      if (subjectsData.isEmpty) {
        Logger.info('⚠️ [MINI-REQUEST] Subjects list is empty, skipping chapters');
        return;
      }

      // دریافت subjectOfferId ها از subjects
      final subjects = subjectsData
          .map((j) => Subject.fromJson(j as Map<String, dynamic>))
          .toList();

      // برای هر subject، subjectOfferId را پیدا کن
      final Map<String, List<dynamic>> chaptersBySubjectOffer = {};

      for (final subject in subjects) {
        try {
          // پیدا کردن subjectOfferId برای این subject
          final subjectOfferId = await _contentService.getSubjectOfferId(
            subjectId: subject.id,
            gradeId: grade,
            trackId: track,
          );

          if (subjectOfferId == null) {
            Logger.info(
              '⚠️ [MINI-REQUEST] Subject ${subject.name} (id: ${subject.id}) has no subjectOfferId, skipping',
            );
            continue;
          }

          // Query chapters برای این subjectOfferId
          final chaptersData =
              await _supabase
                      .from('chapters')
                      .select()
                      .eq('subject_offer_id', subjectOfferId)
                      .eq('active', true)
                      .order('chapter_order', ascending: true)
                  as List<dynamic>;

          final chapters = chaptersData
              .map((j) => Chapter.fromJson(j as Map<String, dynamic>))
              .toList();

          chaptersBySubjectOffer[subjectOfferId.toString()] = chapters
              .map((c) => c.toJson())
              .toList();
        } catch (e) {
          Logger.error(
            '❌ [MINI-REQUEST] Error loading chapters for subject ${subject.name} (id: ${subject.id})',
            e,
          );
        }
      }

      // ذخیره chapters در Hive به صورت Map: {subjectOfferId: [chapters]}
      await box.put('chapters', jsonEncode(chaptersBySubjectOffer));

      // final totalChapters = chaptersBySubjectOffer.values.fold(
      //   0,
      //   (sum, list) => sum + list.length,
      // );
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error loading chapters metadata', e);
    }
  }

  /// دریافت و کش کردن lessons (metadata) برای تمام chapters
  Future<void> _loadLessonsMetadata(int grade, int? track) async {
    try {
      Logger.info(
        '📝 [MINI-REQUEST] Loading lessons metadata: grade=$grade track=$track',
      );

      // ابتدا chapters را از Hive بخوان
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      final chaptersJson = box.get('chapters');

      if (chaptersJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No chapters found, cannot load lessons');
        return;
      }

      final Map<String, dynamic> allChapters = jsonDecode(chaptersJson);
      if (allChapters.isEmpty) {
        Logger.info('⚠️ [MINI-REQUEST] Chapters map is empty, skipping lessons');
        return;
      }

      // برای هر chapter، lessons را دانلود کن
      final Map<String, List<dynamic>> lessonsByChapter = {};

      // تمام chapters را از همه subjectOfferId ها جمع کن
      final List<Chapter> allChaptersList = [];
      for (final chaptersList in allChapters.values) {
        if (chaptersList is List) {
          for (final chapterData in chaptersList) {
            if (chapterData is Map<String, dynamic>) {
              allChaptersList.add(Chapter.fromJson(chapterData));
            }
          }
        }
      }

      Logger.debug(
        '📝 [MINI-REQUEST] Found ${allChaptersList.length} chapters to load lessons for',
      );

      for (final chapter in allChaptersList) {
        try {
          // Query lessons برای این chapter
          final lessonsData =
              await _supabase
                      .from('lessons')
                      .select()
                      .eq('chapter_id', chapter.id)
                      .eq('active', true)
                      .order('lesson_order', ascending: true)
                  as List<dynamic>;

          final lessons = lessonsData
              .map((j) => Lesson.fromJson(j as Map<String, dynamic>))
              .toList();

          lessonsByChapter[chapter.id.toString()] = lessons
              .map((l) => l.toJson())
              .toList();
        } catch (e) {
          Logger.error(
            '❌ [MINI-REQUEST] Error loading lessons for chapter ${chapter.id}',
            e,
          );
        }
      }

      // ذخیره lessons در Hive به صورت Map: {chapterId: [lessons]}
      await box.put('lessons', jsonEncode(lessonsByChapter));

      // final totalLessons = lessonsByChapter.values.fold(
      //   0,
      //   (sum, list) => sum + list.length,
      // );
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error loading lessons metadata', e);
    }
  }

  /// دریافت و کش کردن videos (metadata) برای تمام lessons
  Future<void> _loadVideosMetadata(int grade, int? track) async {
    try {
      Logger.info(
        '🎥 [MINI-REQUEST] Loading videos metadata: grade=$grade track=$track',
      );

      // ابتدا lessons را از Hive بخوان
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      final lessonsJson = box.get('lessons');

      if (lessonsJson == null) {
        Logger.info('⚠️ [MINI-REQUEST] No lessons found, cannot load videos');
        return;
      }

      final Map<String, dynamic> allLessons = jsonDecode(lessonsJson);
      if (allLessons.isEmpty) {
        Logger.info('⚠️ [MINI-REQUEST] Lessons map is empty, skipping videos');
        return;
      }

      // برای هر lesson، videos را دانلود کن
      final Map<String, List<dynamic>> videosByLesson = {};

      // تمام lessons را از همه chapters جمع کن
      final List<Lesson> allLessonsList = [];
      for (final lessonsList in allLessons.values) {
        if (lessonsList is List) {
          for (final lessonData in lessonsList) {
            if (lessonData is Map<String, dynamic>) {
              allLessonsList.add(Lesson.fromJson(lessonData));
            }
          }
        }
      }

      Logger.debug(
        '🎥 [MINI-REQUEST] Found ${allLessonsList.length} lessons to load videos for',
      );

      for (final lesson in allLessonsList) {
        try {
          // Query videos برای این lesson
          final videosData =
              await _supabase
                      .from('lesson_videos')
                      .select()
                      .eq('lesson_id', lesson.id)
                      .eq('active', true)
                      .order('style', ascending: true)
                  as List<dynamic>;

          final videos = videosData
              .map((j) => LessonVideo.fromJson(j as Map<String, dynamic>))
              .toList();

          videosByLesson[lesson.id.toString()] = videos
              .map((v) => v.toJson())
              .toList();
        } catch (e) {
          Logger.error(
            '❌ [MINI-REQUEST] Error loading videos for lesson ${lesson.id}',
            e,
          );
        }
      }

      // ذخیره videos در Hive به صورت Map: {lessonId: [videos]}
      await box.put('videos', jsonEncode(videosByLesson));

      // final totalVideos = videosByLesson.values.fold(
      //   0,
      //   (sum, list) => sum + list.length,
      // );
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error loading videos metadata', e);
    }
  }

  /// ذخیره timestamp آخرین چک
  Future<void> _saveLastCheckTimestamp(int grade, int? track) async {
    try {
      final boxName = _getBoxName(grade, track);
      final box = await Hive.openBox(boxName);
      await box.put('last_check', DateTime.now().toIso8601String());
    } catch (e) {
      _logger.log('Error saving timestamp: $e', LogLevel.warning);
    }
  }

  /// دریافت نام Box برای grade مشخص
  String _getBoxName(int grade, int? track) {
    return 'grade_${grade}_${track ?? "null"}_content';
  }

  /// رفرش دستی (برای دکمه dev)
  Future<void> manualRefresh({int? gradeId, int? trackId}) async {
    _logger.log('Manual refresh triggered', LogLevel.info);
    await checkForUpdates(gradeId: gradeId, trackId: trackId, force: true);
  }

  /// دریافت وضعیت فعلی
  MiniRequestState get currentState => _currentState;

  /// پاک کردن منابع
  void dispose() {
    stopTimer();
    _progressController.close();
    _stateController.close();
    _newBannersController.close(); // 🔔 Close banner stream
    _isInitialized = false;
    _logger.log('Service disposed', LogLevel.info);
  }

  /// 🚀 Prefetch book covers برای grade مشخص (منتظر می‌ماند تا دانلود کامل شود)
  Future<void> prefetchBookCoversForGrade(int gradeId) async {
    try {
      Logger.info(
        '🚀 [MINI-REQUEST] ===== PREFETCHING BOOK COVERS FOR GRADE: $gradeId =====',
      );

      // دریافت book covers
      final covers = await BookCoverService.instance.getBookCoversForGrade(
        gradeId,
      );

      if (covers.isEmpty) {
        Logger.info('⚠️ [MINI-REQUEST] No book covers found for grade: $gradeId');
        return;
      }

      Logger.info('📚 [MINI-REQUEST] Found ${covers.length} book covers to prefetch');

      // دانلود همزمان همه عکس‌ها و منتظر ماندن تا کامل شوند
      final downloadFutures = <Future<Uint8List?>>[];

      for (final cover in covers) {
        if (cover.subjectPath.isNotEmpty) {
          // استفاده از prefetchBookCoverFromUrl که منتظر می‌ماند
          final downloadFuture = SmartImageCacheService.instance
              .prefetchBookCoverFromUrl(cover.subjectPath);
          downloadFutures.add(downloadFuture);
          Logger.debug('⬇️ [MINI-REQUEST] Prefetching: ${cover.subjectName}');
        }
      }

      // منتظر بمان تا همه دانلودها کامل شوند (نه فقط شروع شوند)
      await Future.wait(downloadFutures);
      // final results = await Future.wait(downloadFutures);
      // final successCount = results.where((r) => r != null).length;
      Logger.info('🚀 [MINI-REQUEST] ===== PREFETCH COMPLETE =====');
    } catch (e) {
      Logger.error('❌ [MINI-REQUEST] Error prefetching book covers', e);
    }
  }
}
