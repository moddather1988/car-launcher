#!/usr/bin/env bash
set -e

BASE="app/src/main/java/com/universal/carlauncher"

cat << 'EOF' > "$BASE/MainActivity.kt"
package com.universal.carlauncher
import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.*
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.*
import android.provider.ContactsContract
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import android.view.KeyEvent
import android.view.WindowManager
import androidx.activity.*
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.core.view.*
import com.universal.carlauncher.core.designsystem.CarLauncherTheme
import com.universal.carlauncher.core.diagnostics.InAppDiagnosticsLogger
import com.universal.carlauncher.core.diagnostics.PluginRegistry
import com.universal.carlauncher.core.dock.DockSerializer
import com.universal.carlauncher.core.hardware.VehicleHardwareService
import com.universal.carlauncher.core.media.CarMusicEngine
import com.universal.carlauncher.core.responsive.rememberResponsiveMetrics
import com.universal.carlauncher.core.storage.LauncherStorage
import com.universal.carlauncher.domain.automation.AutomationEngine
import com.universal.carlauncher.domain.islamic.OfflinePrayerEngine
import com.universal.carlauncher.domain.weather.MultiSourceWeatherProvider
import com.universal.carlauncher.ui.components.StateConditionSelectorBar
import com.universal.carlauncher.ui.components.UiStateCondition
import com.universal.carlauncher.ui.navigation.*
import com.universal.carlauncher.ui.screens.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.chrono.HijrahDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoField
import java.util.Locale
import kotlin.math.roundToInt

class MainActivity : ComponentActivity() {
    private val swcKeyEvents = mutableStateOf("في انتظار ضغطة زر من عجلة القيادة...")
    private val mediaKeyAction = mutableIntStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        InAppDiagnosticsLogger.installGlobalCrashShield()
        InAppDiagnosticsLogger.log("APP", "Car Launcher Universal v10.3 Real Music initialized")
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        enableImmersiveMode()
        setContent {
            CarLauncherRootApp(
                lastSwcKeyInfo = swcKeyEvents.value,
                mediaActionSignal = mediaKeyAction.intValue,
                onConsumeMediaSignal = { mediaKeyAction.intValue = 0 }
            )
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val keyName = KeyEvent.keyCodeToString(keyCode)
        swcKeyEvents.value = "$keyName (Code: $keyCode)"
        return when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_NEXT -> { mediaKeyAction.intValue = 1; true }
            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> { mediaKeyAction.intValue = 2; true }
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY, KeyEvent.KEYCODE_MEDIA_PAUSE -> { mediaKeyAction.intValue = 3; true }
            else -> super.onKeyDown(keyCode, event)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); if (hasFocus) enableImmersiveMode() }
    private fun enableImmersiveMode() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }
}

@SuppressLint("MissingPermission")
@Composable
fun CarLauncherRootApp(
    lastSwcKeyInfo: String,
    mediaActionSignal: Int,
    onConsumeMediaSignal: () -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val scope = rememberCoroutineScope()
    val storage = remember { LauncherStorage(context) }
    val hardwareService = remember { VehicleHardwareService(context) }
    val musicEngine = remember { CarMusicEngine(context) }
    val metrics = rememberResponsiveMetrics()

    var activeDockItems by remember { mutableStateOf(storage.dockItems) }
    var installedApps by remember { mutableStateOf(DockSerializer.queryInstalledLauncherApps(context)) }
    val installedAppsMap = remember(installedApps) { installedApps.associateBy { it.packageName } }

    var currentPreset by remember { mutableStateOf(storage.themePreset) }
    var currentWallpaper by remember { mutableStateOf(storage.wallpaperPreset) }
    var customWallpaperUri by remember { mutableStateOf(storage.customWallpaperUri) }
    var settingsTick by remember { mutableIntStateOf(0) }
    var lastVoiceCommandText by remember { mutableStateOf("لم يتم إصدار أمر صوتي بعد") }

    var ttsEngine by remember { mutableStateOf<TextToSpeech?>(null) }
    var islamicBootSpoken by remember { mutableStateOf(false) }

    fun speakArabic(text: String) {
        PluginRegistry.executeSandboxed("ai_copilot") {
            ttsEngine?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "car_ai_tts")
        }
    }

    DisposableEffect(Unit) {
        var instance: TextToSpeech? = null
        instance = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                instance?.language = Locale("ar")
                if (storage.islamicAudioAutoPlayOnBoot && !islamicBootSpoken) {
                    islamicBootSpoken = true
                    speakArabic("سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ")
                }
            }
        }
        ttsEngine = instance
        onDispose {
            runCatching { instance?.stop(); instance?.shutdown() }
            musicEngine.release()
        }
    }

    val initialRoute = remember {
        if (storage.restoreLastStateOnBoot) {
            runCatching { AppRoute.valueOf(storage.lastSavedRouteName) }.getOrDefault(AppRoute.DASHBOARD)
        } else AppRoute.DASHBOARD
    }
    val backStack = remember { mutableStateListOf(initialRoute) }
    val currentRoute = backStack.lastOrNull() ?: AppRoute.DASHBOARD
    var activeUiCondition by remember { mutableStateOf(UiStateCondition.NORMAL) }

    fun navigateTo(route: AppRoute) {
        activeUiCondition = UiStateCondition.NORMAL
        storage.lastSavedRouteName = route.name
        if (route == AppRoute.DASHBOARD) {
            backStack.clear()
            backStack.add(AppRoute.DASHBOARD)
        } else if (backStack.lastOrNull() != route) {
            backStack.add(route)
        }
    }

    fun popBack() {
        if (backStack.size > 1) {
            backStack.removeAt(backStack.lastIndex)
            storage.lastSavedRouteName = backStack.last().name
        }
    }

    val galleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            runCatching { context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            storage.customWallpaperUri = uri.toString()
            customWallpaperUri = uri.toString()
        }
    }

    val voiceLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { res ->
        if (res.resultCode == Activity.RESULT_OK) {
            val spoken = res.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() ?: ""
            if (spoken.isNotBlank()) {
                lastVoiceCommandText = spoken
                when {
                    spoken.contains("شريط") || spoken.contains("دوك") -> navigateTo(AppRoute.DOCK_CUSTOMIZATION)
                    spoken.contains("موسيق") || spoken.contains("أغان") -> navigateTo(AppRoute.MUSIC_PLAYER)
                    spoken.contains("راديو") -> navigateTo(AppRoute.RADIO)
                    spoken.contains("خرائط") -> navigateTo(AppRoute.NAVIGATION)
                    spoken.contains("صلا") -> navigateTo(AppRoute.PRAYER_TIMES)
                    spoken.contains("إعدادات") -> navigateTo(AppRoute.SETTINGS_MAIN)
                    spoken.contains("رئيسي") -> navigateTo(AppRoute.DASHBOARD)
                }
            }
        }
    }

    fun triggerVoiceAssistant() {
        runCatching {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ar-EG")
            }
            voiceLauncher.launch(intent)
        }
    }

    var timeFormatted by remember { mutableStateOf("07:52") }
    var amPmArabic by remember { mutableStateOf("ص") }
    var gregorianDate by remember { mutableStateOf("") }
    var hijriDate by remember { mutableStateOf("") }
    var tripStartRealtime by remember { mutableLongStateOf(SystemClock.elapsedRealtime()) }
    var durationMinutes by remember { mutableIntStateOf(0) }

    var liveSpeedKmh by remember { mutableStateOf<Int?>(null) }
    var accuracyMeters by remember { mutableStateOf<Int?>(null) }
    var distanceKm by remember { mutableFloatStateOf(storage.persistedDistanceKm) }
    var maxSpeedKmh by remember { mutableIntStateOf(0) }
    var bearingDeg by remember { mutableIntStateOf(136) }
    var magneticAzimuthDeg by remember { mutableIntStateOf(136) }
    var currentLat by remember { mutableStateOf<Double?>(null) }
    var currentLon by remember { mutableStateOf<Double?>(null) }
    var lastLoc by remember { mutableStateOf<Location?>(null) }
    var hardwareReport by remember { mutableStateOf(hardwareService.inspectHardware()) }
    var weatherSnapshot by remember { mutableStateOf(MultiSourceWeatherProvider.getOfflineSeasonalEstimate()) }
    var deviceContacts by remember { mutableStateOf<List<DeviceContactItem>>(emptyList()) }
    val toneGen = remember { runCatching { ToneGenerator(AudioManager.STREAM_NOTIFICATION, 75) }.getOrNull() }

    DisposableEffect(Unit) {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val accel = sm?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val mag = sm?.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        val gravity = FloatArray(3); val geomagnetic = FloatArray(3)
        var hasG = false; var hasM = false

        val l = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent?) {
                if (e == null) return
                if (e.sensor.type == Sensor.TYPE_ACCELEROMETER) { System.arraycopy(e.values, 0, gravity, 0, 3); hasG = true }
                else if (e.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) { System.arraycopy(e.values, 0, geomagnetic, 0, 3); hasM = true }
                if (hasG && hasM) {
                    val r = FloatArray(9); val i = FloatArray(9)
                    if (SensorManager.getRotationMatrix(r, i, gravity, geomagnetic)) {
                        val orientation = FloatArray(3)
                        SensorManager.getOrientation(r, orientation)
                        magneticAzimuthDeg = ((Math.toDegrees(orientation[0].toDouble()) + 360.0) % 360.0).roundToInt()
                    }
                }
            }
            override fun onAccuracyChanged(s: Sensor?, acc: Int) {}
        }
        if (accel != null && mag != null) { sm.registerListener(l, accel, SensorManager.SENSOR_DELAY_UI); sm.registerListener(l, mag, SensorManager.SENSOR_DELAY_UI) }
        onDispose { runCatching { sm?.unregisterListener(l) } }
    }

    fun loadDeviceContacts() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return
        val list = mutableListOf<DeviceContactItem>()
        runCatching {
            context.contentResolver.query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI, arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER), null, null, null)?.use { c ->
                val nC = c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val pC = c.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (c.moveToNext() && list.size < 100) { list.add(DeviceContactItem(c.getString(nC) ?: "", c.getString(pC) ?: "")) }
            }
        }
        deviceContacts = list.distinctBy { it.name + it.phone }
    }

    // الاستجابة لأزرار عجلة القيادة وسماعات الميديا الخارجية
    LaunchedEffect(mediaActionSignal) {
        if (mediaActionSignal != 0) {
            when (mediaActionSignal) {
                1 -> musicEngine.nextTrack()
                2 -> musicEngine.prevTrack()
                3 -> musicEngine.togglePlayPause()
            }
            onConsumeMediaSignal()
        }
    }

    fun refreshWeatherNow() {
        scope.launch {
            val live = MultiSourceWeatherProvider.fetchLiveOpenMeteo(currentLat ?: 30.0444, currentLon ?: 31.2357)
            weatherSnapshot = live ?: MultiSourceWeatherProvider.getOfflineSeasonalEstimate()
        }
    }

    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        hardwareReport = hardwareService.inspectHardware()
        musicEngine.checkPermissionAndScan()
        loadDeviceContacts()
        installedApps = DockSerializer.queryInstalledLauncherApps(context)
    }

    fun requestAudioPermissionNow() {
        permLauncher.launch(arrayOf(musicEngine.requiredAudioPermission()))
    }

    LaunchedEffect(Unit) {
        val perms = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.READ_CONTACTS,
            musicEngine.requiredAudioPermission()
        )
        if (Build.VERSION.SDK_INT >= 31) perms.add(Manifest.permission.BLUETOOTH_CONNECT)
        if (Build.VERSION.SDK_INT >= 33) perms.add(Manifest.permission.POST_NOTIFICATIONS)
        permLauncher.launch(perms.toTypedArray())
        musicEngine.checkPermissionAndScan()
        loadDeviceContacts()
        refreshWeatherNow()
    }

    DisposableEffect(hardwareReport.hasLocationPermission) {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val listener = LocationListener { loc ->
            val spd = if (loc.hasSpeed()) (loc.speed * 3.6f).toInt() else 0
            liveSpeedKmh = spd; accuracyMeters = loc.accuracy.toInt(); currentLat = loc.latitude; currentLon = loc.longitude
            if (spd > maxSpeedKmh) maxSpeedKmh = spd
            if (spd >= storage.speedAlertLimit && storage.audioSpeedAlertEnabled) runCatching { toneGen?.startTone(ToneGenerator.TONE_PROP_BEEP, 180) }
            AutomationEngine.executeRealTimeRules(spd, durationMinutes, musicEngine.isPlaying, { musicEngine.playTrackAt(musicEngine.currentTrackIndex) }, { storage.isDayMode = it }, { speakArabic(it) })
            lastLoc?.let { prev ->
                val d = prev.distanceTo(loc)
                if (d > 3f && loc.accuracy <= 35f) { val delta = d / 1000f; distanceKm += delta; storage.persistedDistanceKm = distanceKm; storage.totalOdometerKm += delta }
            }
            lastLoc = loc
        }
        if (hardwareReport.hasLocationPermission && lm != null) runCatching { lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 1f, listener) }
        onDispose { runCatching { lm?.removeUpdates(listener) }; runCatching { toneGen?.release() } }
    }

    LaunchedEffect(settingsTick) {
        val hijriMonths = arrayOf("محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة")
        var sec = 0
        while (true) {
            val now = LocalDateTime.now()
            timeFormatted = now.format(DateTimeFormatter.ofPattern(if (storage.use24HourFormat) "HH:mm" else "hh:mm", Locale.US))
            amPmArabic = if (now.hour < 12) "ص" else "م"
            gregorianDate = now.format(DateTimeFormatter.ofPattern("EEEE، d MMMM yyyy", Locale("ar", "EG")))
            val hijri = HijrahDate.now()
            hijriDate = "${hijri.get(ChronoField.DAY_OF_MONTH)} ${hijriMonths[(hijri.get(ChronoField.MONTH_OF_YEAR) - 1).coerceIn(0, 11)]} ${hijri.get(ChronoField.YEAR)} هـ"
            durationMinutes = ((SystemClock.elapsedRealtime() - tripStartRealtime) / 60000L).toInt()
            musicEngine.syncProgressEverySecond()
            if (sec % 6 == 0) hardwareReport = hardwareService.inspectHardware()
            sec++; delay(1000L)
        }
    }

    val prayers = remember(currentLat, currentLon, timeFormatted) { OfflinePrayerEngine.calculate(currentLat ?: 30.0444, currentLon ?: 31.2357) }
    val activeVehicle = storage.getActiveVehicle()
    val fuelUsed = (distanceKm / 100f) * activeVehicle.fuelLitersPer100Km
    val avgSpd = if (durationMinutes > 0) ((distanceKm / (durationMinutes / 60f)).toInt()).coerceIn(0, maxSpeedKmh.coerceAtLeast(1)) else 0
    val ecoScore = (100 - ((maxSpeedKmh - storage.speedAlertLimit).coerceAtLeast(0) / 2)).coerceIn(60, 100)
    val oilRem = (activeVehicle.oilIntervalKm - (storage.totalOdometerKm - storage.lastOilChangeKm).toInt()).coerceAtLeast(0)

    val telemetry = LiveDrivingTelemetry(liveSpeedKmh, accuracyMeters, distanceKm, maxSpeedKmh, avgSpd, durationMinutes, bearingDeg, magneticAzimuthDeg, fuelUsed, ecoScore, oilRem)

    CarLauncherTheme(preset = currentPreset, isDayMode = storage.isDayMode, fontScaleMultiplier = metrics.scaleFactor) {
        CockpitNavigationShell(
            currentRoute = currentRoute,
            dockItems = activeDockItems,
            installedAppsMap = installedAppsMap,
            dockIconScale = storage.dockIconScale,
            wallpaperPreset = currentWallpaper,
            customWallpaperUri = customWallpaperUri,
            useSideRail = storage.useSideNavigationRail,
            onNavigate = { navigateTo(it) },
            onLaunchVoice = { triggerVoiceAssistant() },
            onBack = { popBack() }
        ) {
            if (currentRoute == AppRoute.DASHBOARD) {
                DashboardScreen(
                    metrics = metrics,
                    timeFormatted = timeFormatted,
                    amPmArabic = amPmArabic,
                    gregorianDate = gregorianDate,
                    hijriDate = hijriDate,
                    telemetry = telemetry,
                    weather = weatherSnapshot,
                    hardware = hardwareReport,
                    prayers = prayers,
                    musicEngine = musicEngine,
                    storage = storage,
                    onCycleWallpaper = { currentWallpaper = storage.cycleWallpaper(); customWallpaperUri = null },
                    onLaunchVoiceCommand = { triggerVoiceAssistant() },
                    onResetTrip = { distanceKm = 0f; storage.persistedDistanceKm = 0f; maxSpeedKmh = 0; tripStartRealtime = SystemClock.elapsedRealtime() },
                    onNavigateTo = { navigateTo(it) },
                    onRequestGpsPermission = { permLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)) }
                )
            } else {
                Column(Modifier.fillMaxSize()) {
                    StateConditionSelectorBar(currentState = activeUiCondition, onSelectState = { activeUiCondition = it })
                    Box(Modifier.weight(1f).fillMaxWidth()) {
                        when (currentRoute) {
                            AppRoute.DOCK_CUSTOMIZATION -> DockCustomizationEditorScreen(
                                currentDockItems = activeDockItems,
                                installedApps = installedApps,
                                storage = storage,
                                onSaveDockItems = { updatedList ->
                                    storage.dockItems = updatedList
                                    activeDockItems = updatedList
                                },
                                onCancelAndBack = { popBack() }
                            )
                            AppRoute.MUSIC_PLAYER -> MusicPlayerFullScreen(
                                musicEngine = musicEngine,
                                storage = storage,
                                onRequestAudioPermission = { requestAudioPermissionNow() },
                                onOpenSongList = { navigateTo(AppRoute.SONG_LIST) },
                                stateCond = activeUiCondition
                            )
                            AppRoute.SONG_LIST -> SongListScreen(
                                musicEngine = musicEngine,
                                storage = storage,
                                onSelectTrack = { idx ->
                                    musicEngine.playTrackAt(idx)
                                    navigateTo(AppRoute.MUSIC_PLAYER)
                                },
                                onRequestAudioPermission = { requestAudioPermissionNow() },
                                stateCond = activeUiCondition
                            )
                            AppRoute.RADIO -> RadioFmScreen(
                                isStreamPlaying = musicEngine.isRadioStreamActive,
                                activeStreamTitle = if (musicEngine.isRadioStreamActive) musicEngine.activeRadioStreamTitle else "اختر محطة للبث المباشر",
                                onPlayStreamUrl = { url, name -> musicEngine.playRadioStream(url, name) },
                                onStopStream = { musicEngine.stopRadioStream() },
                                stateCond = activeUiCondition
                            )
                            AppRoute.AI_ASSISTANT -> SmartAiAssistantScreen(telemetry, hardwareReport, prayers, weatherSnapshot, { speakArabic(it) }, { triggerVoiceAssistant() }, { navigateTo(it) }, activeUiCondition)
                            AppRoute.MAINTENANCE_MANAGER -> MaintenanceManagerScreen(storage, { speakArabic(it) }, activeUiCondition)
                            AppRoute.SPEEDOMETER_FULL -> SpeedometerDedicatedScreen(telemetry, storage, { navigateTo(AppRoute.HUD_PROJECTOR) }, activeUiCondition)
                            AppRoute.HUD_PROJECTOR -> HudProjectorScreen(telemetry, storage)
                            AppRoute.NAVIGATION -> NavigationMapScreen(telemetry, currentLat, currentLon, storage, activeUiCondition)
                            AppRoute.WEATHER -> WeatherDetailScreen(weatherSnapshot, storage, { refreshWeatherNow() }, activeUiCondition)
                            AppRoute.PHONE_DIALPAD -> PhoneDialpadScreen(hardwareReport, { navigateTo(AppRoute.CONTACTS) }, activeUiCondition)
                            AppRoute.CONTACTS -> ContactsScreen(deviceContacts, { permLauncher.launch(arrayOf(Manifest.permission.READ_CONTACTS)); loadDeviceContacts() }, activeUiCondition)
                            AppRoute.APPS_INSTALLED -> AppsGridScreen(false, installedApps, storage, activeUiCondition)
                            AppRoute.APPS_FAVORITES -> AppsGridScreen(true, installedApps, storage, activeUiCondition)
                            AppRoute.VEHICLE_INFO -> VehicleInfoScreen(telemetry, hardwareReport, hardwareService, storage, { navigateTo(AppRoute.MAINTENANCE_MANAGER) }, activeUiCondition)
                            AppRoute.TRIP_DATA -> TripDataScreen(telemetry, storage, { distanceKm = 0f; storage.persistedDistanceKm = 0f; maxSpeedKmh = 0; tripStartRealtime = SystemClock.elapsedRealtime() }, activeUiCondition)
                            AppRoute.DRIVING_ANALYTICS -> DrivingAnalyticsScreen(telemetry, storage, activeUiCondition)
                            AppRoute.ISLAMIC_HUB, AppRoute.PRAYER_TIMES, AppRoute.ADHKAR, AppRoute.TASBEEH, AppRoute.QIBLA, AppRoute.HIJRI_CALENDAR ->
                                IslamicSectionScreens(currentRoute, prayers, hijriDate, magneticAzimuthDeg, storage, { navigateTo(it) }, activeUiCondition)
                            else -> SettingsAndSystemScreens(
                                currentRoute, storage, hardwareReport, currentPreset, currentWallpaper,
                                lastSwcKeyInfo, lastVoiceCommandText,
                                onPresetChange = { currentPreset = it },
                                onWallpaperChange = { currentWallpaper = it; customWallpaperUri = null },
                                onPickGalleryWallpaper = { galleryLauncher.launch("image/*") },
                                onLaunchVoice = { triggerVoiceAssistant() },
                                onSettingsUpdated = { settingsTick++ },
                                onNavigate = { navigateTo(it) },
                                stateCond = activeUiCondition
                            )
                        }
                    }
                }
            }
        }
    }
}
EOF
