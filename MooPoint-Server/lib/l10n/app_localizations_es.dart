// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'MooPoint';

  @override
  String get dashboard => 'Panel';

  @override
  String get map => 'Mapa';

  @override
  String get mapView => 'Vista de Mapa';

  @override
  String get herd => 'Rebaño';

  @override
  String get events => 'Eventos';

  @override
  String get admin => 'Admin';

  @override
  String get settings => 'Ajustes';

  @override
  String get searchDevices => 'Buscar dispositivos...';

  @override
  String welcomeBack(String name) {
    return 'Bienvenido, $name. Esto es lo que ocurre en tu rancho.';
  }

  @override
  String get systemStatusStable => 'Estado del Sistema: Estable';

  @override
  String get totalAnimals => 'Total de Animales';

  @override
  String get onlineNow => 'En Línea';

  @override
  String get activeAlerts => 'Alertas Activas';

  @override
  String get batteryCritical => 'Batería Crítica';

  @override
  String get fenceAlerts => 'Alertas de Cerca';

  @override
  String get recentActivity => 'Actividad Reciente';

  @override
  String get viewAll => 'Ver todo';

  @override
  String get cattleEvent => 'Evento de Ganado';

  @override
  String get fenceEvent => 'Evento de Cerca';

  @override
  String get activeAlertsTitle => 'Alertas Activas';

  @override
  String get active => 'Activo';

  @override
  String get offline => 'Desconectado';

  @override
  String get lowBattery => 'Batería Baja';

  @override
  String get requiresAttention => 'Requiere atención';

  @override
  String get rechargeNeeded => 'Necesita recarga';

  @override
  String get breachDetected => 'Brecha detectada';

  @override
  String get acknowledge => 'Confirmar';

  @override
  String get viewMap => 'Ver Mapa';

  @override
  String get notifyTeam => 'Notificar Equipo';

  @override
  String get viewNodes => 'Ver Nodos';

  @override
  String get dismiss => 'Descartar';

  @override
  String connectivity(String percent) {
    return '$percent% conectividad';
  }

  @override
  String get livePosition => 'Posición en Vivo';

  @override
  String get positionHeatmap => 'Mapa de Calor';

  @override
  String get coverageView => 'Vista de Cobertura';

  @override
  String get positionHistory => 'Historial de Posición';

  @override
  String get liveView => 'Vista en Vivo';

  @override
  String get battery => 'Batería';

  @override
  String get signal => 'Señal';

  @override
  String get strong => 'Fuerte';

  @override
  String get good => 'Buena';

  @override
  String get weak => 'Débil';

  @override
  String lastSeen(String time) {
    return 'Última vez $time';
  }

  @override
  String get lastUpdate => 'Última Actualización';

  @override
  String get justNow => 'ahora mismo';

  @override
  String minutesAgo(int count) {
    return 'hace ${count}m';
  }

  @override
  String hoursAgo(int count) {
    return 'hace ${count}h';
  }

  @override
  String daysAgo(int count) {
    return 'hace ${count}d';
  }

  @override
  String get fenceNode => 'Nodo de Cerca';

  @override
  String get cattleNode => 'Nodo de Ganado';

  @override
  String get fenceStatus => 'Estado de Cerca';

  @override
  String get energized => 'Energizada';

  @override
  String get voltageFaultDetected => 'Fallo de Voltaje Detectado';

  @override
  String get systemNominal => 'Sistema nominal';

  @override
  String get pasturePulse => 'Pulso del Pasto';

  @override
  String get remoteConfig => 'Configuración Remota';

  @override
  String get remoteConfiguration => 'Configuración Remota';

  @override
  String get viewLogs => 'Ver Registros';

  @override
  String get editMapPlacement => 'Editar Ubicación en Mapa';

  @override
  String get voltageOverTime => 'Voltaje en el tiempo';

  @override
  String get latestEvents => 'Últimos Eventos';

  @override
  String get dailyBehavior => 'Comportamiento Diario';

  @override
  String get activity => 'Actividad';

  @override
  String get activityFeed => 'Flujo de Actividad';

  @override
  String get resting => 'Descansando';

  @override
  String get moving => 'Moviéndose';

  @override
  String get grazing => 'Pastando';

  @override
  String get ruminating => 'Rumiando';

  @override
  String get geofenceEvents => 'Eventos de Geocerca';

  @override
  String get entered => 'Entró';

  @override
  String get exited => 'Salió';

  @override
  String get power => 'Energía';

  @override
  String get gpsAccuracy => 'Precisión GPS';

  @override
  String get gps => 'GPS';

  @override
  String get voltageMonitoring => 'Monitoreo de Voltaje';

  @override
  String get fenceType => 'Tipo de Cerca';

  @override
  String get fenceVoltage => 'Voltaje de Cerca';

  @override
  String get firmware => 'Firmware';

  @override
  String get powerManagement => 'Gestión de Energía';

  @override
  String get batteryThreshold => 'Umbral de Batería';

  @override
  String get sleepTime => 'Tiempo de Reposo';

  @override
  String get gpsTimeout => 'Tiempo Límite GPS';

  @override
  String get reportInterval => 'Intervalo de Reporte';

  @override
  String get normal => 'Normal';

  @override
  String get powerSave => 'Ahorro de Energía';

  @override
  String get critical => 'Crítico';

  @override
  String get applyChanges => 'Aplicar Cambios';

  @override
  String get configApplyMessage =>
      'La nueva configuración se aplicará en el próximo ciclo de activación';

  @override
  String get batteryLevelCascade => 'Cascada de Nivel de Batería';

  @override
  String get profilesActivateNote =>
      'Los perfiles se activan en orden a medida que la batería se agota';

  @override
  String get maxHdopValue => 'Valor Máximo HDOP';

  @override
  String get hdopDescription =>
      'Valores más bajos requieren mayor precisión antes de aceptar una posición. Recomendado: 2.0 – 5.0';

  @override
  String get minSatellites => 'Satélites Mínimos Requeridos';

  @override
  String get satDescription =>
      'Valores más altos mejoran la precisión pero pueden aumentar el tiempo de fijación y el consumo de energía.';

  @override
  String get fasterFix => '← Más rápido';

  @override
  String get moreAccurate => 'Más preciso →';

  @override
  String get lowVoltageThreshold => 'Umbral de Alerta de Bajo Voltaje';

  @override
  String get lowVoltageDescription =>
      'Se envía alerta cuando el voltaje cae por debajo de este valor.';

  @override
  String get outageDetection => 'Detección de Corte';

  @override
  String get restorationConfirmation => 'Confirmación de Restauración';

  @override
  String get alerts => 'Alertas';

  @override
  String get fenceOutage => 'Corte de Cerca';

  @override
  String get lowVoltage => 'Bajo Voltaje';

  @override
  String get powerRestored => 'Energía Restaurada';

  @override
  String get nodeOffline => 'Nodo Desconectado';

  @override
  String get checkForUpdates => 'Buscar Actualizaciones';

  @override
  String get upToDate => 'Actualizado';

  @override
  String get placedOnMap => 'Ubicado en Mapa';

  @override
  String get editPlacement => 'Editar Ubicación';

  @override
  String get located => 'Ubicado';

  @override
  String get noGpsHardware => 'Sin Hardware GPS';

  @override
  String get noGpsDescription =>
      'Los ajustes de precisión GPS no están disponibles para nodos de cerca.';

  @override
  String get logout => 'Cerrar Sesión';

  @override
  String get login => 'Iniciar Sesión';

  @override
  String get username => 'Usuario';

  @override
  String get password => 'Contraseña';

  @override
  String get totalNodes => 'Total de Nodos';

  @override
  String get nodeId => 'ID de Nodo';

  @override
  String get locate => 'Localizar';

  @override
  String get overview => 'Resumen';

  @override
  String get behavior => 'Comportamiento';

  @override
  String get location => 'Ubicación';

  @override
  String get temperature => 'Temperatura';

  @override
  String get voltage => 'Voltaje';

  @override
  String get systemDetails => 'Detalles del Sistema';

  @override
  String get type => 'Tipo';

  @override
  String get breed => 'Raza';

  @override
  String get age => 'Edad';

  @override
  String get comments => 'Comentarios';

  @override
  String get noComments => 'Sin comentarios adicionales.';

  @override
  String get surroundings => 'Alrededores';

  @override
  String get batteryLevel => 'Nivel de Batería';

  @override
  String lastReported(String time) {
    return 'Último reporte $time';
  }

  @override
  String get locationActions => 'Acciones de Ubicación';

  @override
  String get positionHistoryBtn => 'Historial de Posición';

  @override
  String get heatmap => 'Mapa de Calor';

  @override
  String get language => 'Idioma';

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get theme => 'Tema';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get refreshData => 'Actualizar Datos';

  @override
  String lastSynced(String time) {
    return 'Última sincronización: $time';
  }

  @override
  String version(String version) {
    return 'MooPoint v$version';
  }

  @override
  String get allSystemsOperational => 'Todos los sistemas operativos';

  @override
  String get online => 'En Línea';

  @override
  String get inPasture => 'En Pastoreo';

  @override
  String get recentGeofenceEvents => 'Eventos Recientes de Geocerca';

  @override
  String get noRecentEvents => 'Sin eventos recientes';

  @override
  String get batteryDistribution => 'Distribución de Batería';

  @override
  String get backendUrl => 'URL del Servidor';

  @override
  String get refreshInterval => 'Intervalo de Actualización';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get geofenceExitAlerts => 'Alertas de Salida de Geocerca';

  @override
  String get lowBatteryAlerts => 'Alertas de Batería Baja';
}
