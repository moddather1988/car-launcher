#!/usr/bin/env bash
set -e

BASE="app/src/main/java/com/universal/carlauncher"

cat << 'EOF' > "$BASE/ui/components/StateViews.kt"
package com.universal.carlauncher.ui.components
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.universal.carlauncher.core.designsystem.DesignTokens
import com.universal.carlauncher.core.designsystem.LocalCockpitPreset

enum class UiStateCondition(val titleAr: String) {
    NORMAL("الحالة الطبيعية"), EMPTY_DATA("عدم وجود بيانات"), NO_INTERNET("عدم وجود إنترنت"),
    PERMISSION_DENIED("عدم منح الصلاحيات"), SENSOR_UNAVAILABLE("عدم توفر المستشعر"),
    LOADING("جاري التحميل"), ERROR("حدوث خطأ"), DEVICE_INCOMPATIBLE("عدم توافق الجهاز")
}

@Composable
fun StateConditionSelectorBar(currentState: UiStateCondition, onSelectState: (UiStateCondition) -> Unit) {
    val preset = LocalCockpitPreset.current
    LazyRow(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        items(UiStateCondition.entries) { cond ->
            val selected = cond == currentState
            Surface(
                color = if (selected) preset.primary.copy(alpha = 0.28f) else DesignTokens.GlassSurface,
                shape = RoundedCornerShape(50),
                border = BorderStroke(1.dp, if (selected) preset.primary else DesignTokens.GlassBorder),
                modifier = Modifier.clickable { onSelectState(cond) }
            ) {
                Text(cond.titleAr, fontSize = 10.sp, color = if (selected) preset.primary else DesignTokens.TextSecondary, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp))
            }
        }
    }
}

@Composable
fun UnifiedStateRenderer(
    condition: UiStateCondition,
    emptyMessage: String = "لا توجد بيانات متاحة للعرض حاليًا في هذا القسم.",
    sensorMessage: String = "المستشعر المطلوب لهذه الوظيفة غير متوفر في شاشة السيارة الحالية.",
    incompatibleMessage: String = "هذا الجهاز لا يدعم هذه الميزة عتاديًا.",
    onRetryOrRequestPermission: () -> Unit = {},
    normalContent: @Composable () -> Unit
) {
    val preset = LocalCockpitPreset.current
    if (condition == UiStateCondition.NORMAL) { normalContent(); return }
    Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.2.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(DesignTokens.RadiusL), modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            when (condition) {
                UiStateCondition.LOADING -> { CircularProgressIndicator(color = preset.primary); Spacer(Modifier.height(12.dp)); Text("جاري قراءة وتجهيز البيانات...", style = MaterialTheme.typography.titleLarge, color = DesignTokens.TextPrimary) }
                UiStateCondition.EMPTY_DATA -> { Icon(Icons.Outlined.Inbox, null, tint = DesignTokens.TextMuted, modifier = Modifier.size(48.dp)); Spacer(Modifier.height(10.dp)); Text("لا توجد بيانات", style = MaterialTheme.typography.titleLarge, color = DesignTokens.TextPrimary); Text(emptyMessage, color = DesignTokens.TextSecondary, textAlign = TextAlign.Center) }
                UiStateCondition.NO_INTERNET -> { Icon(Icons.Outlined.WifiOff, null, tint = DesignTokens.StatusWarning, modifier = Modifier.size(48.dp)); Spacer(Modifier.height(10.dp)); Text("لا يوجد اتصال بالإنترنت (وضع Offline)", style = MaterialTheme.typography.titleLarge, color = DesignTokens.StatusWarning); Text("التطبيق يعمل بنظام Offline-First؛ لن يتم عرض أي بيانات خارجية وهمية.", color = DesignTokens.TextSecondary, textAlign = TextAlign.Center) }
                UiStateCondition.PERMISSION_DENIED -> { Icon(Icons.Outlined.Security, null, tint = DesignTokens.AmberGold, modifier = Modifier.size(48.dp)); Spacer(Modifier.height(10.dp)); Text("الصلاحية مطلوبة لتشغيل هذه الوحدة", style = MaterialTheme.typography.titleLarge, color = DesignTokens.TextPrimary); Spacer(Modifier.height(12.dp)); Button(onClick = onRetryOrRequestPermission, colors = ButtonDefaults.buttonColors(containerColor = DesignTokens.AmberGold)) { Text("منح الصلاحية الآن", color = Color.Black, fontWeight = FontWeight.Bold) } }
                UiStateCondition.SENSOR_UNAVAILABLE -> { Icon(Icons.Outlined.SensorsOff, null, tint = DesignTokens.StatusWarning, modifier = Modifier.size(48.dp)); Spacer(Modifier.height(10.dp)); Text("المستشعر غير متوفر", style = MaterialTheme.typography.titleLarge, color = DesignTokens.StatusWarning); Text(sensorMessage, color = DesignTokens.TextSecondary, textAlign = TextAlign.Center) }
                UiStateCondition.ERROR -> { Icon(Icons.Outlined.ErrorOutline, null, tint = DesignTokens.StatusDanger, modifier = Modifier.size(48.dp)); Spacer(Modifier.height(10.dp)); Text("حدث خطأ أثناء معالجة الطلب", style = MaterialTheme.typography.titleLarge, color = DesignTokens.StatusDanger); Spacer(Modifier.height(10.dp)); Button(onClick = onRetryOrRequestPermission) { Text("إعادة المحاولة") } }
                UiStateCondition.DEVICE_INCOMPATIBLE -> { Icon(Icons.Outlined.Hardware, null, tint = DesignTokens.StatusDanger, modifier = Modifier.size(48.dp)); Spacer(Modifier.height(10.dp)); Text("الجهاز الحالي غير متوافق عتاديًا", style = MaterialTheme.typography.titleLarge, color = DesignTokens.StatusDanger); Text(incompatibleMessage, color = DesignTokens.TextSecondary, textAlign = TextAlign.Center) }
                else -> {}
            }
        }
    }
}
EOF

cat << 'EOF' > "$BASE/ui/screens/AllApplicationScreens.kt"
package com.universal.carlauncher.ui.screens
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.provider.ContactsContract
import android.provider.Settings
import android.widget.Toast
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.universal.carlauncher.core.designsystem.*
import com.universal.carlauncher.core.diagnostics.InAppDiagnosticsLogger
import com.universal.carlauncher.core.diagnostics.PluginRegistry
import com.universal.carlauncher.core.dock.DockActionType
import com.universal.carlauncher.core.dock.DockItemConfig
import com.universal.carlauncher.core.dock.DockSerializer
import com.universal.carlauncher.core.dock.InstalledAndroidApp
import com.universal.carlauncher.core.hardware.HardwareDiagnosticReport
import com.universal.carlauncher.core.hardware.ObdLiveScanResult
import com.universal.carlauncher.core.hardware.VehicleHardwareService
import com.universal.carlauncher.core.media.CarMusicEngine
import com.universal.carlauncher.core.storage.LauncherStorage
import com.universal.carlauncher.domain.assistant.AssistantChatMessage
import com.universal.carlauncher.domain.assistant.SmartCarAssistantEngine
import com.universal.carlauncher.domain.automation.AutomationEngine
import com.universal.carlauncher.domain.islamic.DailyPrayerSchedule
import com.universal.carlauncher.domain.weather.WeatherSnapshot
import com.universal.carlauncher.ui.components.*
import com.universal.carlauncher.ui.navigation.AppRoute
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin

data class DeviceContactItem(val name: String, val phone: String)

@Composable
fun DockCustomizationEditorScreen(
    currentDockItems: List<DockItemConfig>,
    installedApps: List<InstalledAndroidApp>,
    storage: LauncherStorage,
    onSaveDockItems: (List<DockItemConfig>) -> Unit,
    onCancelAndBack: () -> Unit
) {
    val preset = LocalCockpitPreset.current
    val context = LocalContext.current
    val workingList = remember(currentDockItems) { mutableStateListOf<DockItemConfig>().apply { addAll(currentDockItems) } }
    var replaceSlotIndex by remember { mutableStateOf<Int?>(null) }
    var catalogTab by remember { mutableIntStateOf(0) }
    var searchQuery by remember { mutableStateOf("") }
    var statusBanner by remember { mutableStateOf("اسحب أي عنصر أفقياً لتغيير ترتيبه، أو اضغط «استبدال ⇄» ثم اختر البديل.") }

    val internalCatalog = remember {
        listOf(
            DockItemConfig("int_home", DockActionType.INTERNAL_ROUTE, AppRoute.DASHBOARD.name, "الرئيسية"),
            DockItemConfig("int_nav", DockActionType.INTERNAL_ROUTE, AppRoute.NAVIGATION.name, "الخرائط"),
            DockItemConfig("int_phone", DockActionType.INTERNAL_ROUTE, AppRoute.PHONE_DIALPAD.name, "الهاتف"),
            DockItemConfig("int_apps", DockActionType.INTERNAL_ROUTE, AppRoute.APPS_INSTALLED.name, "التطبيقات"),
            DockItemConfig("int_music", DockActionType.INTERNAL_ROUTE, AppRoute.MUSIC_PLAYER.name, "الموسيقى"),
            DockItemConfig("int_songs", DockActionType.INTERNAL_ROUTE, AppRoute.SONG_LIST.name, "قوائم الأغاني"),
            DockItemConfig("int_radio", DockActionType.INTERNAL_ROUTE, AppRoute.RADIO.name, "الراديو"),
            DockItemConfig("int_speed", DockActionType.INTERNAL_ROUTE, AppRoute.SPEEDOMETER_FULL.name, "عداد السرعة"),
            DockItemConfig("int_hud", DockActionType.INTERNAL_ROUTE, AppRoute.HUD_PROJECTOR.name, "بروجكتور HUD"),
            DockItemConfig("int_weather", DockActionType.INTERNAL_ROUTE, AppRoute.WEATHER.name, "الطقس"),
            DockItemConfig("int_islamic", DockActionType.INTERNAL_ROUTE, AppRoute.ISLAMIC_HUB.name, "القسم الإسلامي"),
            DockItemConfig("int_vehicle", DockActionType.INTERNAL_ROUTE, AppRoute.VEHICLE_INFO.name, "معلومات السيارة"),
            DockItemConfig("int_settings", DockActionType.INTERNAL_ROUTE, AppRoute.SETTINGS_MAIN.name, "الإعدادات")
        )
    }

    val systemActionsCatalog = remember {
        listOf(
            DockItemConfig("sys_bt", DockActionType.SYSTEM_ACTION, "BLUETOOTH_SETTINGS", "بلوتوث النظام"),
            DockItemConfig("sys_wifi", DockActionType.SYSTEM_ACTION, "WIFI_SETTINGS", "واي فاي النظام"),
            DockItemConfig("sys_voice", DockActionType.SYSTEM_ACTION, "VOICE_COMMAND", "أمر صوتي")
        )
    }

    fun addOrReplaceWith(newItem: DockItemConfig) {
        val uniqueItem = newItem.copy(id = "dock_${System.currentTimeMillis()}_${newItem.target}")
        val targetSlot = replaceSlotIndex
        if (targetSlot != null && targetSlot in workingList.indices) {
            val oldLabel = workingList[targetSlot].labelAr
            workingList[targetSlot] = uniqueItem
            replaceSlotIndex = null
            onSaveDockItems(workingList.toList())
            statusBanner = "تم استبدال «$oldLabel» بـ «${uniqueItem.labelAr}» وحفظ التعديل!"
        } else if (workingList.size < 8) {
            workingList.add(uniqueItem)
            onSaveDockItems(workingList.toList())
            statusBanner = "تمت إضافة «${uniqueItem.labelAr}» إلى الشريط السفلي!"
        }
    }

    Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("محرر الشريط السفلي الحقيقي (Dock Customization Editor)", style = MaterialTheme.typography.titleLarge, color = preset.primary)
                    Text(statusBanner, fontSize = 11.sp, color = if (replaceSlotIndex != null) DesignTokens.AmberGold else DesignTokens.TextSecondary, maxLines = 1)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Button(onClick = { onSaveDockItems(workingList.toList()); Toast.makeText(context, "تم الحفظ!", Toast.LENGTH_SHORT).show() }, colors = ButtonDefaults.buttonColors(containerColor = DesignTokens.StatusSuccess)) {
                        Text("حفظ", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                    }
                    OutlinedButton(onClick = { val def = storage.resetDockToDefault(); workingList.clear(); workingList.addAll(def); replaceSlotIndex = null; onSaveDockItems(def) }) {
                        Text("الافتراضي", color = DesignTokens.AmberGold, fontSize = 11.sp)
                    }
                    OutlinedButton(onClick = onCancelAndBack) { Text("إغلاق", color = Color.White, fontSize = 11.sp) }
                }
            }

            Surface(color = Color(0xFF061621).copy(alpha = 0.80f), shape = RoundedCornerShape(16.dp), border = BorderStroke(1.dp, DesignTokens.GlassBorder), modifier = Modifier.fillMaxWidth().height(96.dp)) {
                LazyRow(modifier = Modifier.fillMaxSize().padding(horizontal = 10.dp, vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    itemsIndexed(workingList, key = { _, item -> item.id }) { idx, item ->
                        val isBeingReplaced = replaceSlotIndex == idx
                        var dragAccumulated by remember { mutableFloatStateOf(0f) }

                        Surface(
                            color = if (isBeingReplaced) DesignTokens.AmberGold.copy(alpha = 0.28f) else preset.cardElevated,
                            shape = RoundedCornerShape(14.dp),
                            border = BorderStroke(if (isBeingReplaced) 2.dp else 1.dp, if (isBeingReplaced) DesignTokens.AmberGold else preset.border),
                            modifier = Modifier.width(155.dp).fillMaxHeight().pointerInput(idx, workingList.size) {
                                detectHorizontalDragGestures(
                                    onDragStart = { dragAccumulated = 0f },
                                    onHorizontalDrag = { change, dragAmount ->
                                        change.consume()
                                        dragAccumulated += dragAmount
                                        if (dragAccumulated > 65f && idx > 0) {
                                            val tmp = workingList[idx - 1]; workingList[idx - 1] = workingList[idx]; workingList[idx] = tmp
                                            onSaveDockItems(workingList.toList()); dragAccumulated = 0f
                                        } else if (dragAccumulated < -65f && idx < workingList.lastIndex) {
                                            val tmp = workingList[idx + 1]; workingList[idx + 1] = workingList[idx]; workingList[idx] = tmp
                                            onSaveDockItems(workingList.toList()); dragAccumulated = 0f
                                        }
                                    }
                                )
                            }
                        ) {
                            Column(Modifier.fillMaxSize().padding(6.dp), verticalArrangement = Arrangement.SpaceBetween) {
                                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                    Text("#${idx + 1} ${item.labelAr}", fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1, modifier = Modifier.weight(1f))
                                    IconButton(onClick = { if (workingList.size > 1) { workingList.removeAt(idx); onSaveDockItems(workingList.toList()) } }, modifier = Modifier.size(22.dp)) {
                                        Icon(Icons.Default.Delete, null, tint = DesignTokens.StatusDanger, modifier = Modifier.size(16.dp))
                                    }
                                }
                                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                    Surface(color = DesignTokens.GlassSurface, shape = RoundedCornerShape(6.dp), modifier = Modifier.size(26.dp).clickable(enabled = idx > 0) { val tmp = workingList[idx - 1]; workingList[idx - 1] = workingList[idx]; workingList[idx] = tmp; onSaveDockItems(workingList.toList()) }) {
                                        Box(contentAlignment = Alignment.Center) { Text("▶", fontSize = 10.sp, color = Color.White) }
                                    }
                                    Surface(color = if (isBeingReplaced) DesignTokens.AmberGold else preset.primary.copy(alpha = 0.22f), shape = RoundedCornerShape(8.dp), modifier = Modifier.clickable { replaceSlotIndex = if (isBeingReplaced) null else idx }) {
                                        Text(if (isBeingReplaced) "اختر البديل..." else "استبدال ⇄", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = if (isBeingReplaced) Color.Black else preset.primary, modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp))
                                    }
                                    Surface(color = DesignTokens.GlassSurface, shape = RoundedCornerShape(6.dp), modifier = Modifier.size(26.dp).clickable(enabled = idx < workingList.lastIndex) { val tmp = workingList[idx + 1]; workingList[idx + 1] = workingList[idx]; workingList[idx] = tmp; onSaveDockItems(workingList.toList()) }) {
                                        Box(contentAlignment = Alignment.Center) { Text("◀", fontSize = 10.sp, color = Color.White) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                FilterChip(selected = catalogTab == 0, onClick = { catalogTab = 0 }, label = { Text("وظائف اللانشر (${internalCatalog.size})", fontSize = 11.sp) })
                FilterChip(selected = catalogTab == 1, onClick = { catalogTab = 1 }, label = { Text("تطبيقات الجهاز (${installedApps.size})", fontSize = 11.sp) })
                FilterChip(selected = catalogTab == 2, onClick = { catalogTab = 2 }, label = { Text("اختصارات النظام", fontSize = 11.sp) })
                OutlinedTextField(value = searchQuery, onValueChange = { searchQuery = it }, placeholder = { Text("ابحث...") }, modifier = Modifier.weight(1f).height(46.dp), singleLine = true)
            }

            LazyVerticalGrid(columns = GridCells.Adaptive(155.dp), verticalArrangement = Arrangement.spacedBy(6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.weight(1f).fillMaxWidth()) {
                when (catalogTab) {
                    0 -> items(internalCatalog.filter { it.labelAr.contains(searchQuery, true) }) { candidate ->
                        CatalogItemCard(candidate.labelAr, if (replaceSlotIndex != null) "استبدال هنا" else "إضافة للشريط", preset.primary) { addOrReplaceWith(candidate) }
                    }
                    1 -> items(installedApps.filter { it.label.contains(searchQuery, true) }) { app ->
                        CatalogItemCard(app.label, "تطبيق خارجي", DesignTokens.AmberGold) {
                            addOrReplaceWith(DockItemConfig("app_${app.packageName}", DockActionType.EXTERNAL_APP, app.packageName, app.label.take(10)))
                        }
                    }
                    else -> items(systemActionsCatalog) { sysItem ->
                        CatalogItemCard(sysItem.labelAr, "اختصار نظام", DesignTokens.StatusSuccess) { addOrReplaceWith(sysItem) }
                    }
                }
            }
        }
    }
}

@Composable
private fun CatalogItemCard(title: String, subtitle: String, accentColor: Color, onClick: () -> Unit) {
    Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(Modifier.padding(horizontal = 10.dp, vertical = 8.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp, maxLines = 1)
                Text(subtitle, color = accentColor, fontSize = 10.sp, maxLines = 1)
            }
            Icon(Icons.Default.AddCircleOutline, null, tint = accentColor, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun SmartAiAssistantScreen(
    telemetry: LiveDrivingTelemetry, hardware: HardwareDiagnosticReport, prayers: DailyPrayerSchedule, weather: WeatherSnapshot,
    onSpeakText: (String) -> Unit, onLaunchVoiceInput: () -> Unit, onNavigate: (AppRoute) -> Unit, stateCond: UiStateCondition
) {
    val preset = LocalCockpitPreset.current
    var inputQuery by remember { mutableStateOf("") }
    val chatHistory = remember { mutableStateListOf(AssistantChatMessage("المساعد الذكي", "أهلاً بك! اسألني عن الموسيقى، تخصيص الشريط السفلي، فولت البطارية، حالة الصيانة، أو الصلاة.", false)) }

    fun submitQuery(q: String) {
        if (q.isBlank()) return
        chatHistory.add(0, AssistantChatMessage("أنت", q, true))
        val (reply, action) = SmartCarAssistantEngine.processQuery(q, telemetry.speedKmh ?: 0, telemetry.distanceKm, telemetry.fuelUsedLiters, telemetry.oilRemainingKm, hardware, prayers, weather)
        chatHistory.add(0, AssistantChatMessage("المساعد الذكي", reply, false))
        onSpeakText(reply)
        when (action) {
            "OPEN_DOCK_EDITOR" -> onNavigate(AppRoute.DOCK_CUSTOMIZATION)
            "OPEN_MUSIC" -> onNavigate(AppRoute.MUSIC_PLAYER)
            "OPEN_VEHICLE" -> onNavigate(AppRoute.VEHICLE_INFO)
            "OPEN_MAINTENANCE" -> onNavigate(AppRoute.MAINTENANCE_MANAGER)
            "OPEN_TRIP" -> onNavigate(AppRoute.TRIP_DATA)
        }
    }

    UnifiedStateRenderer(condition = stateCond) {
        Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("المساعد الذكي للسيارة (Offline AI + TTS)", style = MaterialTheme.typography.titleLarge, color = preset.primary)
                    Button(onClick = onLaunchVoiceInput, colors = ButtonDefaults.buttonColors(containerColor = DesignTokens.AmberGold)) {
                        Text("أمر صوتي", color = Color.Black, fontWeight = FontWeight.Bold)
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(value = inputQuery, onValueChange = { inputQuery = it }, placeholder = { Text("اكتب سؤالك أو أمرك...") }, modifier = Modifier.weight(1f), singleLine = true)
                    Button(onClick = { submitQuery(inputQuery); inputQuery = "" }) { Text("إرسال") }
                }
                LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(chatHistory) { msg ->
                        Surface(color = if (msg.isUser) preset.primary.copy(alpha = 0.25f) else Color(0xFF0A2434).copy(alpha = 0.85f), shape = RoundedCornerShape(12.dp), border = BorderStroke(1.dp, DesignTokens.GlassBorder), modifier = Modifier.fillMaxWidth()) {
                            Column(Modifier.padding(10.dp)) {
                                Text(msg.senderAr, fontSize = 10.sp, color = DesignTokens.AmberGold, fontWeight = FontWeight.Bold)
                                Text(msg.textAr, fontSize = 13.sp, color = Color.White)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun MaintenanceManagerScreen(storage: LauncherStorage, onSpeakText: (String) -> Unit, stateCond: UiStateCondition) {
    val preset = LocalCockpitPreset.current
    val vProfile = storage.getActiveVehicle()
    var odo by remember { mutableFloatStateOf(storage.totalOdometerKm) }
    var lastOil by remember { mutableFloatStateOf(storage.lastOilChangeKm) }
    val oilRem = (vProfile.oilIntervalKm - (odo - lastOil).toInt()).coerceAtLeast(0)

    UnifiedStateRenderer(condition = stateCond) {
        Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column {
                        Text("إدارة الصيانة الدورية (${vProfile.brand})", style = MaterialTheme.typography.titleLarge, color = preset.primary)
                        Text("عداد المسافة الإجمالي (Odometer): ${odo.toInt()} كم", color = DesignTokens.AmberGold, fontWeight = FontWeight.Bold)
                    }
                    Button(onClick = { onSpeakText("المتبقي على تغيير الزيت القادم حوالي $oilRem كيلومتر.") }) { Text("قراءة صوتية") }
                }
                Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(12.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column { Text("تغيير زيت المحرك والفلتر (كل ${vProfile.oilIntervalKm} كم)", color = Color.White, fontWeight = FontWeight.Bold); Text("متبقي $oilRem كم", color = DesignTokens.StatusSuccess, fontWeight = FontWeight.Bold) }
                        OutlinedButton(onClick = { lastOil = odo; storage.lastOilChangeKm = odo }) { Text("تمت الصيانة اليوم", color = DesignTokens.AmberGold) }
                    }
                }
            }
        }
    }
}

@Composable
fun SpeedometerDedicatedScreen(telemetry: LiveDrivingTelemetry, storage: LauncherStorage, onOpenHud: () -> Unit, stateCond: UiStateCondition) {
    val preset = LocalCockpitPreset.current
    val rawSpeed = telemetry.speedKmh ?: 0
    val displaySpeed = if (storage.useMphUnit) (rawSpeed * 0.621371f).toInt() else rawSpeed
    val unitText = if (storage.useMphUnit) "MPH" else "كم/س"
    UnifiedStateRenderer(condition = stateCond) {
        Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxSize().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(0.58f).fillMaxHeight(), contentAlignment = Alignment.Center) {
                    PanoramicSpeedometerWithRealisticCar(displaySpeed, unitText, rawSpeed >= storage.speedAlertLimit, Modifier.fillMaxSize())
                }
                Column(Modifier.weight(0.42f).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("عداد السرعة الاحترافي", style = MaterialTheme.typography.headlineMedium, color = preset.primary)
                    Text("الأقصى: ${telemetry.maxSpeedKmh} كم/س • البوصلة: ${telemetry.magneticAzimuthDeg}°", color = DesignTokens.AmberGold, fontWeight = FontWeight.Bold)
                    Button(onClick = onOpenHud, colors = ButtonDefaults.buttonColors(containerColor = DesignTokens.AmberGold)) {
                        Text("تشغيل بروجكتور الزجاج الأمامي (HUD)", color = Color.Black, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

@Composable
fun HudProjectorScreen(telemetry: LiveDrivingTelemetry, storage: LauncherStorage) {
    var mirrorFlip by remember { mutableStateOf(true) }
    val rawSpeed = telemetry.speedKmh ?: 0
    Surface(color = Color.Black, shape = RoundedCornerShape(22.dp), border = BorderStroke(1.5.dp, Color(0xFF00F5D4)), modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.SpaceBetween) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("وضع بروجكتور الزجاج الأمامي الليلي (HUD)", color = Color(0xFF00F5D4), fontWeight = FontWeight.Bold)
                Button(onClick = { mirrorFlip = !mirrorFlip }, colors = ButtonDefaults.buttonColors(containerColor = DesignTokens.AmberGold)) {
                    Text(if (mirrorFlip) "إلغاء العكس المرآوي" else "تفعيل العكس للزجاج", color = Color.Black, fontWeight = FontWeight.Bold)
                }
            }
            Box(modifier = Modifier.weight(1f).fillMaxWidth().scale(scaleX = 1f, scaleY = if (mirrorFlip) -1f else 1f), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("$rawSpeed", fontSize = 92.sp, fontWeight = FontWeight.Black, color = Color(0xFF00F5D4))
                    Text("KM/H • بوصلة ${telemetry.magneticAzimuthDeg}°", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = DesignTokens.AmberGold)
                }
            }
            Text("ضع الشاشة أسفل الزجاج الأمامي ليلاً لانعكاس السرعة أمام عين السائق مباشرة.", fontSize = 11.sp, color = DesignTokens.TextSecondary)
        }
    }
}

@Composable
fun NavigationMapScreen(telemetry: LiveDrivingTelemetry, lat: Double?, lon: Double?, storage: LauncherStorage, stateCond: UiStateCondition) {
    val preset = LocalCockpitPreset.current; val context = LocalContext.current
    var destQuery by remember { mutableStateOf("") }
    fun launchMapsDestination(q: String) {
        val uri = Uri.parse("geo:0,0?q=${Uri.encode(q)}")
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }
    UnifiedStateRenderer(condition = stateCond) {
        Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column {
                        Text("الملاحة والوجهات الذكية المحفوظة", style = MaterialTheme.typography.titleLarge, color = preset.primary)
                        Text(if (lat != null && lon != null) "الإحداثيات: ${"%.5f".format(lat)} , ${"%.5f".format(lon)}" else "بانتظار إشارة GPS", color = DesignTokens.TextSecondary, fontSize = 12.sp)
                    }
                    Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(12.dp)) {
                        Text("السرعة: ${telemetry.speedKmh ?: 0} كم/س • البوصلة: ${telemetry.magneticAzimuthDeg}°", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.padding(10.dp), fontSize = 12.sp)
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { launchMapsDestination(storage.homeLocationQuery) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = preset.primary)) { Text("المنزل", color = Color.Black, fontWeight = FontWeight.Bold) }
                    Button(onClick = { launchMapsDestination(storage.workLocationQuery) }, modifier = Modifier.weight(1f), colors = ButtonDefaults.buttonColors(containerColor = DesignTokens.AmberGold)) { Text("العمل", color = Color.Black, fontWeight = FontWeight.Bold) }
                    OutlinedButton(onClick = { launchMapsDestination("محطة وقود") }, modifier = Modifier.weight(1f)) { Text("وقود", color = Color.White) }
                    OutlinedButton(onClick = { launchMapsDestination("مسجد") }, modifier = Modifier.weight(1f)) { Text("مسجد", color = Color.White) }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(value = destQuery, onValueChange = { destQuery = it }, placeholder = { Text("ابحث عن وجهة في الخرائط...") }, modifier = Modifier.weight(1f), singleLine = true)
                    Button(onClick = { if (destQuery.isNotBlank()) launchMapsDestination(destQuery) }) { Text("بدء الملاحة") }
                }
            }
        }
    }
}

@Composable
fun MusicPlayerFullScreen(
    musicEngine: CarMusicEngine,
    storage: LauncherStorage,
    onRequestAudioPermission: () -> Unit,
    onOpenSongList: () -> Unit,
    stateCond: UiStateCondition
) {
    val preset = LocalCockpitPreset.current
    val context = LocalContext.current
    val audioManager = remember { context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager }
    val maxVol = remember { audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15 }
    var curVol by remember { mutableIntStateOf(audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 10) }

    val currentTrack = musicEngine.currentTrack()
    var favIds by remember { mutableStateOf(storage.favoriteTrackIds) }
    var drivingIds by remember { mutableStateOf(storage.drivingPlaylistTrackIds) }
    val isFav = currentTrack != null && favIds.contains(currentTrack.id.toString())
    val isInDrivingList = currentTrack != null && drivingIds.contains(currentTrack.id.toString())

    val effectiveState = when {
        stateCond != UiStateCondition.NORMAL -> stateCond
        !musicEngine.hasAudioPermission -> UiStateCondition.PERMISSION_DENIED
        else -> UiStateCondition.NORMAL
    }

    UnifiedStateRenderer(condition = effectiveState, onRetryOrRequestPermission = onRequestAudioPermission) {
        Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxSize().padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.width(135.dp)) {
                    Surface(
                        color = Color(0xFF132232), shape = RoundedCornerShape(22.dp),
                        border = BorderStroke(2.dp, if (musicEngine.isPlaying) DesignTokens.AmberGold else preset.primary),
                        modifier = Modifier.size(120.dp)
                    ) {
                        if (musicEngine.currentAlbumArt != null) {
                            Image(bitmap = musicEngine.currentAlbumArt!!, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                        } else {
                            Box(contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Album, null, tint = preset.primary, modifier = Modifier.size(62.dp)) }
                        }
                    }
                    Text(if (musicEngine.isPlaying) "● يعمل الآن" else "متوقف", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = if (musicEngine.isPlaying) DesignTokens.StatusSuccess else DesignTokens.TextMuted)
                }

                Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.SpaceBetween) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(currentTrack?.title ?: "لا توجد أغنية محددة", style = MaterialTheme.typography.titleLarge, color = Color.White, maxLines = 1)
                            Text(currentTrack?.artist ?: "اختر من المكتبة", fontSize = 11.5.sp, color = preset.primary, maxLines = 1)
                        }
                        if (currentTrack != null) {
                            IconButton(onClick = { favIds = storage.toggleFavoriteTrack(currentTrack.id) }) {
                                Icon(if (isFav) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder, null, tint = if (isFav) DesignTokens.StatusDanger else Color.White)
                            }
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        Text(CarMusicEngine.formatTimeMs(musicEngine.currentPositionMs), fontSize = 11.5.sp, color = DesignTokens.AmberGold)
                        Slider(
                            value = musicEngine.currentPositionMs.toFloat().coerceIn(0f, musicEngine.currentDurationMs.coerceAtLeast(1).toFloat()),
                            onValueChange = { musicEngine.seekTo(it.toInt()) },
                            valueRange = 0f..musicEngine.currentDurationMs.coerceAtLeast(1).toFloat(),
                            modifier = Modifier.weight(1f).height(22.dp)
                        )
                        Text(CarMusicEngine.formatTimeMs(musicEngine.currentDurationMs), fontSize = 11.5.sp, color = DesignTokens.TextSecondary)
                    }

                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        Icon(Icons.Outlined.VolumeUp, null, tint = DesignTokens.AmberGold, modifier = Modifier.size(16.dp))
                        Slider(value = curVol.toFloat(), onValueChange = { curVol = it.toInt(); runCatching { audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, curVol, 0) } }, valueRange = 0f..maxVol.toFloat(), modifier = Modifier.weight(1f).height(20.dp))
                        Text("${(curVol * 100) / maxVol.coerceAtLeast(1)}%", fontSize = 10.sp, color = Color.White)
                    }

                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = { musicEngine.nextTrack() }) { Icon(Icons.Default.SkipNext, null, tint = Color.White, modifier = Modifier.size(28.dp)) }
                            Surface(shape = CircleShape, color = DesignTokens.AmberGold, modifier = Modifier.size(46.dp).clickable { musicEngine.togglePlayPause() }) {
                                Box(contentAlignment = Alignment.Center) { Icon(if (musicEngine.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow, null, tint = Color.Black, modifier = Modifier.size(28.dp)) }
                            }
                            IconButton(onClick = { musicEngine.prevTrack() }) { Icon(Icons.Default.SkipPrevious, null, tint = Color.White, modifier = Modifier.size(28.dp)) }
                        }
                        Button(onClick = onOpenSongList) { Text("المكتبة (${musicEngine.allTracks.size})", fontSize = 11.sp) }
                    }
                }
            }
        }
    }
}

@Composable
fun SongListScreen(musicEngine: CarMusicEngine, storage: LauncherStorage, onSelectTrack: (Int) -> Unit, onRefresh: () -> Unit, stateCond: UiStateCondition) {
    val preset = LocalCockpitPreset.current
    var query by remember { mutableStateOf("") }
    val filtered = musicEngine.allTracks.filter { it.title.contains(query, true) || it.artist.contains(query, true) }
    val effectiveCond = if (stateCond == UiStateCondition.NORMAL && filtered.isEmpty()) UiStateCondition.EMPTY_DATA else stateCond

    UnifiedStateRenderer(condition = effectiveCond, emptyMessage = "لا توجد ملفات صوتية.", onRetryOrRequestPermission = onRefresh) {
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            OutlinedTextField(value = query, onValueChange = { query = it }, placeholder = { Text("ابحث في المقاطع (${musicEngine.allTracks.size})...") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                items(filtered) { track ->
                    val idx = musicEngine.allTracks.indexOfFirst { it.id == track.id }
                    val isCurrent = idx == musicEngine.currentTrackIndex
                    Surface(color = if (isCurrent) preset.primary.copy(alpha = 0.28f) else DesignTokens.GlassSurface, shape = RoundedCornerShape(12.dp), border = BorderStroke(1.dp, if (isCurrent) preset.primary else DesignTokens.GlassBorder), modifier = Modifier.fillMaxWidth().clickable { if (idx >= 0) onSelectTrack(idx) }) {
                        Row(Modifier.padding(12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(track.title, color = DesignTokens.TextPrimary, fontWeight = FontWeight.Bold, maxLines = 1, modifier = Modifier.weight(1f))
                            Text(track.artist, color = DesignTokens.TextSecondary, fontSize = 12.sp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun RadioFmScreen(isStreamPlaying: Boolean, activeStreamTitle: String, onPlayUrl: (String, String) -> Unit, onStop: () -> Unit, stateCond: UiStateCondition) {
    val preset = LocalCockpitPreset.current
    UnifiedStateRenderer(condition = stateCond) {
        Surface(color = DesignTokens.GlassSurface, border = BorderStroke(1.dp, DesignTokens.GlassBorder), shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxSize()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
                Text("راديو الإنترنت والبث المباشر ($activeStreamTitle)", style = MaterialTheme.typography.titleLarge, color = preset.primary)
                Button(onClick = { onPlayUrl("https://stream.radiojar.com/8s5u5tpdtwzuv", "إذاعة القرآن الكريم") }) { Text("تشغيل إذاعة القرآن الكريم") }
                if (isStreamPlaying) OutlinedButton(onClick = onStop) { Text("إيقاف البث", color = DesignTokens.StatusDanger) }
            }
        }
    }
}

@Composable
fun PhoneDialpadScreen(hardware: HardwareDiagnosticReport, onOpenContacts: () -> Unit, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.Center) { Button(onClick = onOpenContacts) { Text("جهات الاتصال") } } }
}
@Composable
fun ContactsScreen(contacts: List<DeviceContactItem>, onRequestPerm: () -> Unit, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { LazyColumn(Modifier.padding(16.dp)) { items(contacts) { c -> Text("${c.name}: ${c.phone}", color = Color.White, modifier = Modifier.padding(6.dp)) } } }
}
@Composable
fun AppsGridScreen(favsOnly: Boolean, installedApps: List<InstalledAndroidApp>, storage: LauncherStorage, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { LazyVerticalGrid(columns = GridCells.Adaptive(140.dp), modifier = Modifier.padding(12.dp)) { items(installedApps) { app -> Text(app.label, color = Color.White, modifier = Modifier.padding(8.dp)) } } } }
}
@Composable
fun VehicleInfoScreen(telemetry: LiveDrivingTelemetry, hardware: HardwareDiagnosticReport, service: VehicleHardwareService, storage: LauncherStorage, onMaint: () -> Unit, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.Center) { Text("فولت البطارية: ${hardware.batteryVoltageVolts}V", color = Color.White) } }
}
@Composable
fun TripDataScreen(telemetry: LiveDrivingTelemetry, storage: LauncherStorage, onReset: () -> Unit, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { Box(contentAlignment = Alignment.Center) { Text("حاسوب الرحلة", color = Color.White) } }
}
@Composable
fun DrivingAnalyticsScreen(telemetry: LiveDrivingTelemetry, storage: LauncherStorage, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { Box(contentAlignment = Alignment.Center) { Text("إحصائيات القيادة", color = Color.White) } }
}
@Composable
fun IslamicSectionScreens(route: AppRoute, prayers: DailyPrayerSchedule, hijriDate: String, az: Int, storage: LauncherStorage, onNav: (AppRoute) -> Unit, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { Box(contentAlignment = Alignment.Center) { Text("القسم الإسلامي", color = Color.White) } }
}
@Composable
fun WeatherDetailScreen(weather: WeatherSnapshot, storage: LauncherStorage, onRefresh: () -> Unit, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { Box(contentAlignment = Alignment.Center) { Text("الطقس: ${weather.tempCelsius}°C", color = Color.White) } }
}
@Composable
fun SettingsAndSystemScreens(route: AppRoute, storage: LauncherStorage, hardware: HardwareDiagnosticReport, preset: CockpitThemePreset, wp: ScenicWallpaperPreset, swc: String, voice: String, onPreset: (CockpitThemePreset) -> Unit, onWp: (ScenicWallpaperPreset) -> Unit, onGallery: () -> Unit, onVoice: () -> Unit, onUpd: () -> Unit, onNav: (AppRoute) -> Unit, stateCond: UiStateCondition) {
    Surface(color = DesignTokens.GlassSurface, modifier = Modifier.fillMaxSize()) { Box(contentAlignment = Alignment.Center) { Text("الإعدادات", color = Color.White) } }
}
EOF
