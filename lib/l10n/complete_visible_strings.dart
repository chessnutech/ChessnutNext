// Handwritten translations for visible UI copy found by the localization audit.

String? completeVisibleTranslation(String text, String key) {
  return _completeVisibleStringMaps[key]?[text];
}

Set<String> get completeVisibleSourceStrings => {
      for (final translations in _completeVisibleStringMaps.values)
        ...translations.keys,
    };

const _completeVisibleStringMaps = <String, Map<String, String>>{
  'zh-Hans': {
    '6-digit code': '6 位验证码',
    'Analysis marker LED patterns': '分析标记 LED 模式',
    'Auto-detect set': '自动检测棋子套装',
    'Back to channels': '返回通道列表',
    'Board connection failed.': '棋盘连接失败。',
    'Board disconnected. Reconnect failed; the game will stay open.':
        '棋盘已断开且重连失败；对局会保持打开。',
    'Check placement, battery, and nearby interference, then try again.':
        '请检查棋子摆放、电量和附近干扰，然后重试。',
    'Checkpoints': '检查点',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': '云端 Maia 3',
    'Confirm': '确认',
    'Confirm draw': '确认和棋',
    'Confirm takeback': '确认悔棋',
    'Date': '日期',
    'Delete': '删除',
    'Fill': '填充',
    'G': '局',
    'Go to login': '前往登录',
    'Google Play update is not available right now. Opening the store page instead.':
        'Google Play 应用内更新暂不可用，正在改为打开商店页面。',
    'Grandeur HTML report downloaded.': 'Grandeur HTML 报告已下载。',
    'Help': '帮助',
    'Interactive': '互动',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        '配对时请移开附近的其他 Move 棋子套装。此过程通常需要 3–5 分钟。',
    'Key moments': '关键时刻',
    'Latest version': '最新版本',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.': 'Lichess 未及时响应，请重试。',
    'Location': '地点',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 正在估算每一步人类最可能选择的走法。',
    'More filters': '更多筛选',
    'Move board did not accept the command.': 'Move 棋盘未接受该指令。',
    'Move board did not accept the reset command.': 'Move 棋盘未接受重置指令。',
    'Move board reset to the standard starting position.': 'Move 棋盘已重置为标准初始局面。',
    'Network issue': '网络异常',
    'No PGN available for this record.': '此记录没有可用的 PGN。',
    'No finished game with playable moves is available yet.':
        '暂时没有包含可播放走法的已结束对局。',
    'No moves yet': '暂无走法',
    'No usable PGN games matched this Lichess player and filters.':
        '没有与该 Lichess 棋手及筛选条件匹配的可用 PGN 对局。',
    'Open Google Play': '打开 Google Play',
    'Password cannot be empty.': '密码不能为空。',
    'Password reset successfully.': '密码重置成功。',
    'Pieces are ready': '棋子已就绪',
    'Place all 34 pieces exactly as shown before pairing.':
        '配对前请严格按图示摆好全部 34 枚棋子。',
    'Preparing insight': '正在准备洞察',
    'Preview Lichess games before starting training.': '开始训练前请先预览 Lichess 对局。',
    'Refresh': '刷新',
    'Remove': '移除',
    'Remove piece set?': '移除棋子套装？',
    'Removed pieces need to be paired again before they can be used.':
        '被移除的棋子需重新配对后才能使用。',
    'Replay': '重放',
    'Report': '报告',
    'Reset both clocks and start over.': '重置双方棋钟并重新开始。',
    'Reset clock?': '重置棋钟？',
    'Retry': '重试',
    'Select': '选择',
    'Shutdown mode': '关机模式',
    'Shutdown mode sent.': '关机模式指令已发送。',
    'Start pairing': '开始配对',
    'Switch account': '切换账号',
    'Tap a move to jump back to the board.': '点击走法即可跳转回对应棋盘局面。',
    'The new set has been paired and saved to this channel.':
        '新棋子套装已配对并保存到此通道。',
    'The selected PGN file is empty.': '所选 PGN 文件为空。',
    'This PGN could not be read. Check the PGN file and try again.':
        '无法读取此 PGN，请检查 PGN 文件后重试。',
    'This PGN could not be read. Check the move list and try again.':
        '无法读取此 PGN，请检查走法列表后重试。',
    'This update will be handled by Google Play on this device.':
        '此设备上的更新将由 Google Play 处理。',
    'This update will open the Chessnut page on Google Play.':
        '此次更新将打开 Google Play 上的 Chessnut 页面。',
    'Time': '时间',
    'Turn on': '开启',
    'Turn on shutdown mode?': '开启关机模式？',
    'Unable to check Lichess authorization. Please try again.':
        '无法检查 Lichess 授权状态，请重试。',
    'Unable to download Grandeur report.': '无法下载 Grandeur 报告。',
    'Unable to open this PGN file. Choose another file and try again.':
        '无法打开此 PGN 文件，请选择其他文件后重试。',
    'Unable to pair pieces': '无法配对棋子',
    'Unable to send command.': '无法发送指令。',
    'Unable to switch to this account.': '无法切换到此账号。',
    'Update with Google Play': '通过 Google Play 更新',
    'Use another saved Chessnut ID': '使用其他已保存的 Chessnut ID',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        '用于长期存放。再次使用前，必须先将棋子放到充电板上。',
    'Use this position': '使用此局面',
    'Verification code cannot be empty.': '验证码不能为空。',
    'Verification code required': '需要验证码',
    'View first-time tips again': '再次查看首次使用提示',
    'no legal mainline moves': '主线中没有合法走法',
    'sec': '秒',
  },
  'zh-Hant': {
    '6-digit code': '6 位驗證碼',
    'Analysis marker LED patterns': '分析標記 LED 模式',
    'Auto-detect set': '自動偵測棋子套裝',
    'Back to channels': '返回頻道列表',
    'Board connection failed.': '棋盤連線失敗。',
    'Board disconnected. Reconnect failed; the game will stay open.':
        '棋盤已中斷連線且重新連線失敗；對局會保持開啟。',
    'Check placement, battery, and nearby interference, then try again.':
        '請檢查棋子擺放、電量和附近干擾，然後再試。',
    'Checkpoints': '檢查點',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': '雲端 Maia 3',
    'Confirm': '確認',
    'Confirm draw': '確認和棋',
    'Confirm takeback': '確認悔棋',
    'Date': '日期',
    'Delete': '刪除',
    'Fill': '填滿',
    'G': '局',
    'Go to login': '前往登入',
    'Google Play update is not available right now. Opening the store page instead.':
        'Google Play 應用程式內更新目前無法使用，將改為開啟商店頁面。',
    'Grandeur HTML report downloaded.': 'Grandeur HTML 報告已下載。',
    'Help': '說明',
    'Interactive': '互動',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        '配對時請移開附近其他 Move 棋子套裝。此程序通常需要 3–5 分鐘。',
    'Key moments': '關鍵時刻',
    'Latest version': '最新版本',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.': 'Lichess 未及時回應，請再試一次。',
    'Location': '地點',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 正在估算每一步人類最可能選擇的走法。',
    'More filters': '更多篩選',
    'Move board did not accept the command.': 'Move 棋盤未接受該指令。',
    'Move board did not accept the reset command.': 'Move 棋盤未接受重設指令。',
    'Move board reset to the standard starting position.': 'Move 棋盤已重設為標準初始局面。',
    'Network issue': '網路異常',
    'No PGN available for this record.': '此記錄沒有可用的 PGN。',
    'No finished game with playable moves is available yet.':
        '目前沒有包含可播放走法的已結束對局。',
    'No moves yet': '尚無走法',
    'No usable PGN games matched this Lichess player and filters.':
        '沒有符合此 Lichess 棋手及篩選條件的可用 PGN 對局。',
    'Open Google Play': '開啟 Google Play',
    'Password cannot be empty.': '密碼不能為空。',
    'Password reset successfully.': '密碼重設成功。',
    'Pieces are ready': '棋子已就緒',
    'Place all 34 pieces exactly as shown before pairing.':
        '配對前請完全依照圖示擺好全部 34 枚棋子。',
    'Preparing insight': '正在準備洞察',
    'Preview Lichess games before starting training.': '開始訓練前請先預覽 Lichess 對局。',
    'Refresh': '重新整理',
    'Remove': '移除',
    'Remove piece set?': '移除棋子套裝？',
    'Removed pieces need to be paired again before they can be used.':
        '已移除的棋子必須重新配對後才能使用。',
    'Replay': '重播',
    'Report': '報告',
    'Reset both clocks and start over.': '重設雙方棋鐘並重新開始。',
    'Reset clock?': '重設棋鐘？',
    'Retry': '重試',
    'Select': '選擇',
    'Shutdown mode': '關機模式',
    'Shutdown mode sent.': '關機模式指令已傳送。',
    'Start pairing': '開始配對',
    'Switch account': '切換帳號',
    'Tap a move to jump back to the board.': '點選走法即可跳回對應棋盤局面。',
    'The new set has been paired and saved to this channel.':
        '新棋子套裝已配對並儲存到此頻道。',
    'The selected PGN file is empty.': '所選 PGN 檔案是空的。',
    'This PGN could not be read. Check the PGN file and try again.':
        '無法讀取此 PGN，請檢查 PGN 檔案後再試。',
    'This PGN could not be read. Check the move list and try again.':
        '無法讀取此 PGN，請檢查走法列表後再試。',
    'This update will be handled by Google Play on this device.':
        '此裝置上的更新將由 Google Play 處理。',
    'This update will open the Chessnut page on Google Play.':
        '此次更新將開啟 Google Play 上的 Chessnut 頁面。',
    'Time': '時間',
    'Turn on': '開啟',
    'Turn on shutdown mode?': '開啟關機模式？',
    'Unable to check Lichess authorization. Please try again.':
        '無法檢查 Lichess 授權狀態，請再試一次。',
    'Unable to download Grandeur report.': '無法下載 Grandeur 報告。',
    'Unable to open this PGN file. Choose another file and try again.':
        '無法開啟此 PGN 檔案，請選擇其他檔案後再試。',
    'Unable to pair pieces': '無法配對棋子',
    'Unable to send command.': '無法傳送指令。',
    'Unable to switch to this account.': '無法切換到此帳號。',
    'Update with Google Play': '透過 Google Play 更新',
    'Use another saved Chessnut ID': '使用其他已儲存的 Chessnut ID',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        '用於長期存放。再次使用前，必須先將棋子放到充電板上。',
    'Use this position': '使用此局面',
    'Verification code cannot be empty.': '驗證碼不能為空。',
    'Verification code required': '需要驗證碼',
    'View first-time tips again': '再次查看首次使用提示',
    'no legal mainline moves': '主線中沒有合法走法',
    'sec': '秒',
  },
  'de': {
    '6-digit code': '6-stelliger Code',
    'Analysis marker LED patterns': 'LED-Muster für Analysemarkierungen',
    'Auto-detect set': 'Figurensatz automatisch erkennen',
    'Back to channels': 'Zurück zu den Kanälen',
    'Board connection failed.': 'Brettverbindung fehlgeschlagen.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'Das Brett wurde getrennt und konnte nicht erneut verbunden werden; die Partie bleibt geöffnet.',
    'Check placement, battery, and nearby interference, then try again.':
        'Prüfe Aufstellung, Akkustand und Störquellen in der Nähe und versuche es erneut.',
    'Checkpoints': 'Kontrollpunkte',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': 'Maia 3 in der Cloud',
    'Confirm': 'Bestätigen',
    'Confirm draw': 'Remis bestätigen',
    'Confirm takeback': 'Rücknahme bestätigen',
    'Date': 'Datum',
    'Delete': 'Löschen',
    'Fill': 'Füllen',
    'G': 'P',
    'Go to login': 'Zur Anmeldung',
    'Google Play update is not available right now. Opening the store page instead.':
        'Das Google-Play-Update ist derzeit nicht verfügbar. Stattdessen wird die Store-Seite geöffnet.',
    'Grandeur HTML report downloaded.':
        'Der Grandeur-HTML-Bericht wurde heruntergeladen.',
    'Help': 'Hilfe',
    'Interactive': 'Interaktiv',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Halte andere Move-Sätze während der Kopplung fern. Der Vorgang dauert normalerweise 3–5 Minuten.',
    'Key moments': 'Schlüsselmomente',
    'Latest version': 'Neueste Version',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.':
        'Lichess hat nicht rechtzeitig geantwortet. Versuche es erneut.',
    'Location': 'Ort',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 schätzt für jeden Zug die wahrscheinlichen menschlichen Entscheidungen.',
    'More filters': 'Weitere Filter',
    'Move board did not accept the command.':
        'Das Move-Brett hat den Befehl nicht angenommen.',
    'Move board did not accept the reset command.':
        'Das Move-Brett hat den Rücksetzbefehl nicht angenommen.',
    'Move board reset to the standard starting position.':
        'Das Move-Brett wurde auf die Standardanfangsstellung zurückgesetzt.',
    'Network issue': 'Netzwerkproblem',
    'No PGN available for this record.':
        'Für diesen Eintrag ist keine PGN verfügbar.',
    'No finished game with playable moves is available yet.':
        'Es ist noch keine beendete Partie mit abspielbaren Zügen verfügbar.',
    'No moves yet': 'Noch keine Züge',
    'No usable PGN games matched this Lichess player and filters.':
        'Für diesen Lichess-Spieler und die Filter wurden keine nutzbaren PGN-Partien gefunden.',
    'Open Google Play': 'Google Play öffnen',
    'Password cannot be empty.': 'Das Passwort darf nicht leer sein.',
    'Password reset successfully.': 'Passwort erfolgreich zurückgesetzt.',
    'Pieces are ready': 'Figuren sind bereit',
    'Place all 34 pieces exactly as shown before pairing.':
        'Stelle vor der Kopplung alle 34 Figuren genau wie gezeigt auf.',
    'Preparing insight': 'Auswertung wird vorbereitet',
    'Preview Lichess games before starting training.':
        'Sieh dir die Lichess-Partien vor dem Trainingsstart an.',
    'Refresh': 'Aktualisieren',
    'Remove': 'Entfernen',
    'Remove piece set?': 'Figurensatz entfernen?',
    'Removed pieces need to be paired again before they can be used.':
        'Entfernte Figuren müssen vor der erneuten Verwendung neu gekoppelt werden.',
    'Replay': 'Wiedergeben',
    'Report': 'Bericht',
    'Reset both clocks and start over.':
        'Beide Uhren zurücksetzen und neu beginnen.',
    'Reset clock?': 'Uhr zurücksetzen?',
    'Retry': 'Erneut versuchen',
    'Select': 'Auswählen',
    'Shutdown mode': 'Abschaltmodus',
    'Shutdown mode sent.': 'Abschaltmodus wurde gesendet.',
    'Start pairing': 'Kopplung starten',
    'Switch account': 'Konto wechseln',
    'Tap a move to jump back to the board.':
        'Tippe auf einen Zug, um zur entsprechenden Brettstellung zu springen.',
    'The new set has been paired and saved to this channel.':
        'Der neue Satz wurde gekoppelt und in diesem Kanal gespeichert.',
    'The selected PGN file is empty.': 'Die ausgewählte PGN-Datei ist leer.',
    'This PGN could not be read. Check the PGN file and try again.':
        'Diese PGN konnte nicht gelesen werden. Prüfe die PGN-Datei und versuche es erneut.',
    'This PGN could not be read. Check the move list and try again.':
        'Diese PGN konnte nicht gelesen werden. Prüfe die Zugliste und versuche es erneut.',
    'This update will be handled by Google Play on this device.':
        'Dieses Update wird auf diesem Gerät von Google Play ausgeführt.',
    'This update will open the Chessnut page on Google Play.':
        'Dieses Update öffnet die Chessnut-Seite bei Google Play.',
    'Time': 'Zeit',
    'Turn on': 'Einschalten',
    'Turn on shutdown mode?': 'Abschaltmodus einschalten?',
    'Unable to check Lichess authorization. Please try again.':
        'Die Lichess-Autorisierung konnte nicht geprüft werden. Versuche es erneut.',
    'Unable to download Grandeur report.':
        'Der Grandeur-Bericht konnte nicht heruntergeladen werden.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Diese PGN-Datei konnte nicht geöffnet werden. Wähle eine andere Datei und versuche es erneut.',
    'Unable to pair pieces': 'Figuren konnten nicht gekoppelt werden',
    'Unable to send command.': 'Befehl konnte nicht gesendet werden.',
    'Unable to switch to this account.':
        'Zu diesem Konto konnte nicht gewechselt werden.',
    'Update with Google Play': 'Mit Google Play aktualisieren',
    'Use another saved Chessnut ID':
        'Andere gespeicherte Chessnut ID verwenden',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Für die Langzeitaufbewahrung verwenden. Vor der erneuten Nutzung müssen die Figuren auf das Ladebrett gestellt werden.',
    'Use this position': 'Diese Stellung verwenden',
    'Verification code cannot be empty.':
        'Der Bestätigungscode darf nicht leer sein.',
    'Verification code required': 'Bestätigungscode erforderlich',
    'View first-time tips again': 'Erste-Hilfe-Tipps erneut anzeigen',
    'no legal mainline moves': 'keine legalen Züge in der Hauptvariante',
    'sec': 'Sek.',
    'Auto': 'Automatisch',
    'Bluetooth': 'Bluetooth',
    'Cantonese': 'Kantonesisch',
    'Control the board LED hints used while setting up and playing.':
        'Steuere die LED-Hinweise des Bretts beim Aufbau und Spielen.',
    'Copy URL': 'URL kopieren',
    'End game': 'Partie beenden',
    'Engine': 'Schachengine',
    'Game marked as ended.': 'Partie als beendet markiert.',
    'Level': 'Stufe',
    'Live': 'Live-Modus',
    'Mandarin': 'Hochchinesisch',
    'Open': 'Öffnen',
    'Replay guides': 'Anleitungen erneut anzeigen',
    'Show all guides next time': 'Nächstes Mal alle Anleitungen anzeigen',
    'Sign in before starting Career Mode.':
        'Melde dich an, bevor du den Karrieremodus startest.',
    'Skip': 'Überspringen',
    'Start': 'Starten',
    'Stockfish live': 'Stockfish-Liveanalyse',
    'Tap to view details': 'Antippen, um Details anzuzeigen',
    'This game ended before any playable moves, so there is no position to analyze.':
        'Diese Partie endete vor einem abspielbaren Zug, daher gibt es keine Stellung zu analysieren.',
    'Unable to end this game record.':
        'Dieser Partieeintrag konnte nicht beendet werden.',
    'Version': 'Versionsnummer',
    'Voice moves': 'Sprachzüge',
  },
  'es': {
    '6-digit code': 'Código de 6 dígitos',
    'Analysis marker LED patterns': 'Patrones LED de marcadores de análisis',
    'Auto-detect set': 'Detectar juego automáticamente',
    'Back to channels': 'Volver a los canales',
    'Board connection failed.': 'Falló la conexión con el tablero.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'El tablero se desconectó y no se pudo reconectar; la partida seguirá abierta.',
    'Check placement, battery, and nearby interference, then try again.':
        'Comprueba la colocación, la batería y las interferencias cercanas, y vuelve a intentarlo.',
    'Checkpoints': 'Puntos de control',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': 'Maia 3 en la nube',
    'Confirm': 'Confirmar',
    'Confirm draw': 'Confirmar tablas',
    'Confirm takeback': 'Confirmar deshacer jugada',
    'Date': 'Fecha',
    'Delete': 'Eliminar',
    'Fill': 'Rellenar',
    'G': 'P',
    'Go to login': 'Ir al inicio de sesión',
    'Google Play update is not available right now. Opening the store page instead.':
        'La actualización de Google Play no está disponible ahora. Se abrirá la página de la tienda.',
    'Grandeur HTML report downloaded.':
        'Se descargó el informe HTML de Grandeur.',
    'Help': 'Ayuda',
    'Interactive': 'Interactivo',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Aleja otros juegos Move durante el emparejamiento. El proceso suele tardar de 3 a 5 minutos.',
    'Key moments': 'Momentos clave',
    'Latest version': 'Última versión',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.':
        'Lichess no respondió a tiempo. Inténtalo de nuevo.',
    'Location': 'Lugar',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 está estimando las elecciones humanas más probables en cada jugada.',
    'More filters': 'Más filtros',
    'Move board did not accept the command.':
        'El tablero Move no aceptó el comando.',
    'Move board did not accept the reset command.':
        'El tablero Move no aceptó el comando de reinicio.',
    'Move board reset to the standard starting position.':
        'El tablero Move se restableció a la posición inicial estándar.',
    'Network issue': 'Problema de red',
    'No PGN available for this record.':
        'No hay un PGN disponible para este registro.',
    'No finished game with playable moves is available yet.':
        'Aún no hay ninguna partida terminada con jugadas reproducibles.',
    'No moves yet': 'Aún no hay jugadas',
    'No usable PGN games matched this Lichess player and filters.':
        'No se encontraron partidas PGN utilizables para este jugador de Lichess y estos filtros.',
    'Open Google Play': 'Abrir Google Play',
    'Password cannot be empty.': 'La contraseña no puede estar vacía.',
    'Password reset successfully.':
        'La contraseña se restableció correctamente.',
    'Pieces are ready': 'Las piezas están listas',
    'Place all 34 pieces exactly as shown before pairing.':
        'Coloca las 34 piezas exactamente como se muestra antes de emparejarlas.',
    'Preparing insight': 'Preparando información',
    'Preview Lichess games before starting training.':
        'Previsualiza las partidas de Lichess antes de iniciar el entrenamiento.',
    'Refresh': 'Actualizar',
    'Remove': 'Quitar',
    'Remove piece set?': '¿Quitar el juego de piezas?',
    'Removed pieces need to be paired again before they can be used.':
        'Las piezas retiradas deben volver a emparejarse antes de usarlas.',
    'Replay': 'Reproducir',
    'Report': 'Informe',
    'Reset both clocks and start over.':
        'Restablecer ambos relojes y empezar de nuevo.',
    'Reset clock?': '¿Restablecer el reloj?',
    'Retry': 'Reintentar',
    'Select': 'Seleccionar',
    'Shutdown mode': 'Modo de apagado',
    'Shutdown mode sent.': 'Se envió el modo de apagado.',
    'Start pairing': 'Iniciar emparejamiento',
    'Switch account': 'Cambiar de cuenta',
    'Tap a move to jump back to the board.':
        'Toca una jugada para volver a esa posición del tablero.',
    'The new set has been paired and saved to this channel.':
        'El nuevo juego se emparejó y guardó en este canal.',
    'The selected PGN file is empty.':
        'El archivo PGN seleccionado está vacío.',
    'This PGN could not be read. Check the PGN file and try again.':
        'No se pudo leer este PGN. Comprueba el archivo y vuelve a intentarlo.',
    'This PGN could not be read. Check the move list and try again.':
        'No se pudo leer este PGN. Comprueba la lista de jugadas y vuelve a intentarlo.',
    'This update will be handled by Google Play on this device.':
        'Google Play gestionará esta actualización en este dispositivo.',
    'This update will open the Chessnut page on Google Play.':
        'Esta actualización abrirá la página de Chessnut en Google Play.',
    'Time': 'Tiempo',
    'Turn on': 'Activar',
    'Turn on shutdown mode?': '¿Activar el modo de apagado?',
    'Unable to check Lichess authorization. Please try again.':
        'No se pudo comprobar la autorización de Lichess. Inténtalo de nuevo.',
    'Unable to download Grandeur report.':
        'No se pudo descargar el informe de Grandeur.',
    'Unable to open this PGN file. Choose another file and try again.':
        'No se pudo abrir este archivo PGN. Elige otro y vuelve a intentarlo.',
    'Unable to pair pieces': 'No se pudieron emparejar las piezas',
    'Unable to send command.': 'No se pudo enviar el comando.',
    'Unable to switch to this account.': 'No se pudo cambiar a esta cuenta.',
    'Update with Google Play': 'Actualizar con Google Play',
    'Use another saved Chessnut ID': 'Usar otro Chessnut ID guardado',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Úsalo para almacenamiento prolongado. Las piezas deben colocarse en el tablero de carga antes de volver a usarlas.',
    'Use this position': 'Usar esta posición',
    'Verification code cannot be empty.':
        'El código de verificación no puede estar vacío.',
    'Verification code required': 'Se requiere código de verificación',
    'View first-time tips again': 'Volver a ver los consejos iniciales',
    'no legal mainline moves': 'no hay jugadas legales en la línea principal',
    'sec': 's',
    'Bluetooth': 'Bluetooth',
    'Cantonese': 'Cantonés',
    'Color': 'Color de juego',
    'Control the board LED hints used while setting up and playing.':
        'Controla las indicaciones LED del tablero durante la preparación y la partida.',
    'Copy URL': 'Copiar URL',
    'End game': 'Terminar partida',
    'Game marked as ended.': 'La partida se marcó como terminada.',
    'Mandarin': 'Mandarín',
    'Open': 'Abrir',
    'Replay guides': 'Volver a mostrar las guías',
    'Show all guides next time': 'Mostrar todas las guías la próxima vez',
    'Sign in before starting Career Mode.':
        'Inicia sesión antes de comenzar el modo Carrera.',
    'Skip': 'Omitir',
    'Start': 'Iniciar',
    'Tap to view details': 'Toca para ver los detalles',
    'This game ended before any playable moves, so there is no position to analyze.':
        'Esta partida terminó antes de que hubiera jugadas reproducibles, así que no hay una posición que analizar.',
    'Unable to end this game record.':
        'No se pudo finalizar este registro de partida.',
    'Voice moves': 'Jugadas por voz',
  },
  'fr': {
    '6-digit code': 'Code à 6 chiffres',
    'Analysis marker LED patterns': 'Motifs LED des marqueurs d’analyse',
    'Auto-detect set': 'Détecter le jeu automatiquement',
    'Back to channels': 'Retour aux canaux',
    'Board connection failed.': 'Échec de la connexion à l’échiquier.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'L’échiquier est déconnecté et la reconnexion a échoué ; la partie restera ouverte.',
    'Check placement, battery, and nearby interference, then try again.':
        'Vérifiez le placement, la batterie et les interférences à proximité, puis réessayez.',
    'Checkpoints': 'Points de contrôle',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': 'Maia 3 dans le cloud',
    'Confirm': 'Confirmer',
    'Confirm draw': 'Confirmer la nulle',
    'Confirm takeback': 'Confirmer la reprise',
    'Date': 'Date de la partie',
    'Delete': 'Supprimer',
    'Fill': 'Remplir',
    'G': 'P',
    'Go to login': 'Aller à la connexion',
    'Google Play update is not available right now. Opening the store page instead.':
        'La mise à jour Google Play n’est pas disponible pour le moment. Ouverture de la page de la boutique.',
    'Grandeur HTML report downloaded.':
        'Le rapport HTML Grandeur a été téléchargé.',
    'Help': 'Aide',
    'Interactive': 'Interactif',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Éloignez les autres jeux Move pendant l’appairage. L’opération prend généralement 3 à 5 minutes.',
    'Key moments': 'Moments clés',
    'Latest version': 'Dernière version',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.':
        'Lichess n’a pas répondu à temps. Réessayez.',
    'Location': 'Lieu',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 estime les choix humains probables pour chaque coup.',
    'More filters': 'Plus de filtres',
    'Move board did not accept the command.':
        'L’échiquier Move n’a pas accepté la commande.',
    'Move board did not accept the reset command.':
        'L’échiquier Move n’a pas accepté la commande de réinitialisation.',
    'Move board reset to the standard starting position.':
        'L’échiquier Move a été réinitialisé à la position de départ standard.',
    'Network issue': 'Problème de réseau',
    'No PGN available for this record.':
        'Aucun PGN n’est disponible pour cet enregistrement.',
    'No finished game with playable moves is available yet.':
        'Aucune partie terminée avec des coups lisibles n’est encore disponible.',
    'No moves yet': 'Aucun coup pour le moment',
    'No usable PGN games matched this Lichess player and filters.':
        'Aucune partie PGN exploitable ne correspond à ce joueur Lichess et à ces filtres.',
    'Open Google Play': 'Ouvrir Google Play',
    'Password cannot be empty.': 'Le mot de passe ne peut pas être vide.',
    'Password reset successfully.': 'Mot de passe réinitialisé.',
    'Pieces are ready': 'Les pièces sont prêtes',
    'Place all 34 pieces exactly as shown before pairing.':
        'Placez les 34 pièces exactement comme indiqué avant l’appairage.',
    'Preparing insight': 'Préparation de l’analyse',
    'Preview Lichess games before starting training.':
        'Prévisualisez les parties Lichess avant de commencer l’entraînement.',
    'Refresh': 'Actualiser',
    'Remove': 'Retirer',
    'Remove piece set?': 'Retirer le jeu de pièces ?',
    'Removed pieces need to be paired again before they can be used.':
        'Les pièces retirées doivent être appairées à nouveau avant utilisation.',
    'Replay': 'Rejouer',
    'Report': 'Rapport',
    'Reset both clocks and start over.':
        'Réinitialiser les deux pendules et recommencer.',
    'Reset clock?': 'Réinitialiser la pendule ?',
    'Retry': 'Réessayer',
    'Select': 'Sélectionner',
    'Shutdown mode': 'Mode arrêt',
    'Shutdown mode sent.': 'La commande du mode arrêt a été envoyée.',
    'Start pairing': 'Démarrer l’appairage',
    'Switch account': 'Changer de compte',
    'Tap a move to jump back to the board.':
        'Touchez un coup pour revenir à cette position.',
    'The new set has been paired and saved to this channel.':
        'Le nouveau jeu a été appairé et enregistré sur ce canal.',
    'The selected PGN file is empty.': 'Le fichier PGN sélectionné est vide.',
    'This PGN could not be read. Check the PGN file and try again.':
        'Ce PGN n’a pas pu être lu. Vérifiez le fichier PGN et réessayez.',
    'This PGN could not be read. Check the move list and try again.':
        'Ce PGN n’a pas pu être lu. Vérifiez la liste des coups et réessayez.',
    'This update will be handled by Google Play on this device.':
        'Cette mise à jour sera gérée par Google Play sur cet appareil.',
    'This update will open the Chessnut page on Google Play.':
        'Cette mise à jour ouvrira la page Chessnut sur Google Play.',
    'Time': 'Temps',
    'Turn on': 'Activer',
    'Turn on shutdown mode?': 'Activer le mode arrêt ?',
    'Unable to check Lichess authorization. Please try again.':
        'Impossible de vérifier l’autorisation Lichess. Réessayez.',
    'Unable to download Grandeur report.':
        'Impossible de télécharger le rapport Grandeur.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Impossible d’ouvrir ce fichier PGN. Choisissez-en un autre et réessayez.',
    'Unable to pair pieces': 'Impossible d’appairer les pièces',
    'Unable to send command.': 'Impossible d’envoyer la commande.',
    'Unable to switch to this account.': 'Impossible de passer à ce compte.',
    'Update with Google Play': 'Mettre à jour avec Google Play',
    'Use another saved Chessnut ID': 'Utiliser un autre Chessnut ID enregistré',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Utilisez ce mode pour un stockage prolongé. Les pièces doivent être placées sur l’échiquier de charge avant leur prochaine utilisation.',
    'Use this position': 'Utiliser cette position',
    'Verification code cannot be empty.':
        'Le code de vérification ne peut pas être vide.',
    'Verification code required': 'Code de vérification requis',
    'View first-time tips again': 'Revoir les conseils de démarrage',
    'no legal mainline moves': 'aucun coup légal dans la variante principale',
    'sec': 's',
    'Auto': 'Automatique',
    'Bluetooth': 'Bluetooth',
    'Cantonese': 'Cantonais',
    'Control the board LED hints used while setting up and playing.':
        'Contrôlez les indications LED de l’échiquier pendant la mise en place et la partie.',
    'Copy URL': 'Copier l’URL',
    'End game': 'Terminer la partie',
    'Game marked as ended.': 'La partie a été marquée comme terminée.',
    'Mandarin': 'Chinois mandarin',
    'Mode': 'Mode de jeu',
    'Open': 'Ouvrir',
    'Replay guides': 'Revoir les guides',
    'Show all guides next time': 'Afficher tous les guides la prochaine fois',
    'Sign in before starting Career Mode.':
        'Connectez-vous avant de démarrer le mode Carrière.',
    'Skip': 'Passer',
    'Start': 'Démarrer',
    'Tap to view details': 'Touchez pour voir les détails',
    'This game ended before any playable moves, so there is no position to analyze.':
        'Cette partie s’est terminée avant tout coup lisible ; aucune position ne peut être analysée.',
    'Unable to end this game record.':
        'Impossible de terminer cet enregistrement de partie.',
    'Version': 'Numéro de version',
    'Voice moves': 'Coups vocaux',
    'points': 'points fidélité',
  },
  'it': {
    '6-digit code': 'Codice a 6 cifre',
    'Analysis marker LED patterns': 'Schemi LED dei marcatori di analisi',
    'Auto-detect set': 'Rileva automaticamente il set',
    'Back to channels': 'Torna ai canali',
    'Board connection failed.': 'Connessione alla scacchiera non riuscita.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'La scacchiera si è disconnessa e la riconnessione non è riuscita; la partita resterà aperta.',
    'Check placement, battery, and nearby interference, then try again.':
        'Controlla disposizione, batteria e interferenze vicine, quindi riprova.',
    'Checkpoints': 'Punti di controllo',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': 'Maia 3 cloud',
    'Confirm': 'Conferma',
    'Confirm draw': 'Conferma patta',
    'Confirm takeback': 'Conferma annullamento',
    'Date': 'Data',
    'Delete': 'Elimina',
    'Fill': 'Riempi',
    'G': 'P',
    'Go to login': 'Vai all’accesso',
    'Google Play update is not available right now. Opening the store page instead.':
        'L’aggiornamento Google Play non è disponibile. Verrà aperta la pagina dello store.',
    'Grandeur HTML report downloaded.': 'Report HTML Grandeur scaricato.',
    'Help': 'Aiuto',
    'Interactive': 'Interattivo',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Allontana gli altri set Move durante l’abbinamento. Il processo richiede in genere 3–5 minuti.',
    'Key moments': 'Momenti chiave',
    'Latest version': 'Ultima versione',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.':
        'Lichess non ha risposto in tempo. Riprova.',
    'Location': 'Luogo',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 sta stimando le scelte umane più probabili per ogni mossa.',
    'More filters': 'Altri filtri',
    'Move board did not accept the command.':
        'La scacchiera Move non ha accettato il comando.',
    'Move board did not accept the reset command.':
        'La scacchiera Move non ha accettato il comando di ripristino.',
    'Move board reset to the standard starting position.':
        'La scacchiera Move è stata ripristinata alla posizione iniziale standard.',
    'Network issue': 'Problema di rete',
    'No PGN available for this record.':
        'Nessun PGN disponibile per questa registrazione.',
    'No finished game with playable moves is available yet.':
        'Non è ancora disponibile una partita terminata con mosse riproducibili.',
    'No moves yet': 'Ancora nessuna mossa',
    'No usable PGN games matched this Lichess player and filters.':
        'Nessuna partita PGN utilizzabile corrisponde a questo giocatore Lichess e ai filtri.',
    'Open Google Play': 'Apri Google Play',
    'Password cannot be empty.': 'La password non può essere vuota.',
    'Password reset successfully.': 'Password reimpostata correttamente.',
    'Pieces are ready': 'I pezzi sono pronti',
    'Place all 34 pieces exactly as shown before pairing.':
        'Posiziona tutti i 34 pezzi esattamente come mostrato prima dell’abbinamento.',
    'Preparing insight': 'Preparazione dell’analisi',
    'Preview Lichess games before starting training.':
        'Visualizza l’anteprima delle partite Lichess prima di iniziare l’allenamento.',
    'Refresh': 'Aggiorna',
    'Remove': 'Rimuovi',
    'Remove piece set?': 'Rimuovere il set di pezzi?',
    'Removed pieces need to be paired again before they can be used.':
        'I pezzi rimossi devono essere abbinati di nuovo prima dell’uso.',
    'Replay': 'Rivedi',
    'Report': 'Rapporto',
    'Reset both clocks and start over.':
        'Reimposta entrambi gli orologi e ricomincia.',
    'Reset clock?': 'Reimpostare l’orologio?',
    'Retry': 'Riprova',
    'Select': 'Seleziona',
    'Shutdown mode': 'Modalità spegnimento',
    'Shutdown mode sent.': 'Comando di spegnimento inviato.',
    'Start pairing': 'Avvia abbinamento',
    'Switch account': 'Cambia account',
    'Tap a move to jump back to the board.':
        'Tocca una mossa per tornare a quella posizione.',
    'The new set has been paired and saved to this channel.':
        'Il nuovo set è stato abbinato e salvato su questo canale.',
    'The selected PGN file is empty.': 'Il file PGN selezionato è vuoto.',
    'This PGN could not be read. Check the PGN file and try again.':
        'Impossibile leggere questo PGN. Controlla il file e riprova.',
    'This PGN could not be read. Check the move list and try again.':
        'Impossibile leggere questo PGN. Controlla l’elenco delle mosse e riprova.',
    'This update will be handled by Google Play on this device.':
        'Questo aggiornamento sarà gestito da Google Play sul dispositivo.',
    'This update will open the Chessnut page on Google Play.':
        'Questo aggiornamento aprirà la pagina Chessnut su Google Play.',
    'Time': 'Tempo',
    'Turn on': 'Attiva',
    'Turn on shutdown mode?': 'Attivare la modalità spegnimento?',
    'Unable to check Lichess authorization. Please try again.':
        'Impossibile verificare l’autorizzazione Lichess. Riprova.',
    'Unable to download Grandeur report.':
        'Impossibile scaricare il report Grandeur.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Impossibile aprire questo file PGN. Scegline un altro e riprova.',
    'Unable to pair pieces': 'Impossibile abbinare i pezzi',
    'Unable to send command.': 'Impossibile inviare il comando.',
    'Unable to switch to this account.':
        'Impossibile passare a questo account.',
    'Update with Google Play': 'Aggiorna con Google Play',
    'Use another saved Chessnut ID': 'Usa un altro Chessnut ID salvato',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Usa questa modalità per la conservazione a lungo termine. Prima di riutilizzarli, i pezzi devono essere posti sulla scacchiera di ricarica.',
    'Use this position': 'Usa questa posizione',
    'Verification code cannot be empty.':
        'Il codice di verifica non può essere vuoto.',
    'Verification code required': 'Codice di verifica richiesto',
    'View first-time tips again': 'Rivedi i suggerimenti iniziali',
    'no legal mainline moves': 'nessuna mossa legale nella variante principale',
    'sec': 's',
    'Account': 'Profilo',
    'Auto': 'Automatico',
    'Bluetooth': 'Bluetooth',
    'Cantonese': 'Lingua cantonese',
    'Control the board LED hints used while setting up and playing.':
        'Controlla le indicazioni LED della scacchiera durante la preparazione e il gioco.',
    'Copy URL': 'Copia URL',
    'End game': 'Termina partita',
    'Game marked as ended.': 'Partita contrassegnata come terminata.',
    'Live': 'In diretta',
    'Mandarin': 'Mandarino',
    'Open': 'Apri',
    'Replay guides': 'Rivedi le guide',
    'Show all guides next time': 'Mostra tutte le guide la prossima volta',
    'Sign in before starting Career Mode.':
        'Accedi prima di avviare la modalità Carriera.',
    'Skip': 'Salta',
    'Start': 'Avvia',
    'Stockfish live': 'Stockfish in diretta',
    'Tap to view details': 'Tocca per vedere i dettagli',
    'This game ended before any playable moves, so there is no position to analyze.':
        'La partita è terminata prima di mosse riproducibili, quindi non c’è una posizione da analizzare.',
    'Unable to end this game record.':
        'Impossibile terminare questa registrazione.',
    'Voice moves': 'Mosse vocali',
  },
  'ja': {
    '6-digit code': '6桁のコード',
    'Analysis marker LED patterns': '解析マーカーの LED パターン',
    'Auto-detect set': '駒セットを自動検出',
    'Back to channels': 'チャンネル一覧に戻る',
    'Board connection failed.': 'ボードへの接続に失敗しました。',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'ボードが切断され、再接続にも失敗しました。対局画面は開いたままになります。',
    'Check placement, battery, and nearby interference, then try again.':
        '駒の配置、バッテリー、周囲の干渉を確認して、もう一度お試しください。',
    'Checkpoints': 'チェックポイント',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': 'クラウド Maia 3',
    'Confirm': '確認',
    'Confirm draw': '引き分けを確認',
    'Confirm takeback': '待ったを確認',
    'Date': '日付',
    'Delete': '削除',
    'Fill': '塗りつぶす',
    'G': '局',
    'Go to login': 'ログインへ',
    'Google Play update is not available right now. Opening the store page instead.':
        'Google Play のアプリ内更新は現在利用できません。ストアページを開きます。',
    'Grandeur HTML report downloaded.': 'Grandeur の HTML レポートをダウンロードしました。',
    'Help': 'ヘルプ',
    'Interactive': 'インタラクティブ',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'ペアリング中は近くのほかの Move セットを離してください。通常 3～5 分かかります。',
    'Key moments': '重要局面',
    'Latest version': '最新バージョン',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.':
        'Lichess から時間内に応答がありませんでした。もう一度お試しください。',
    'Location': '場所',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 が各手で人間が選びそうな候補を推定しています。',
    'More filters': 'その他のフィルター',
    'Move board did not accept the command.': 'Move ボードがコマンドを受け付けませんでした。',
    'Move board did not accept the reset command.':
        'Move ボードがリセットコマンドを受け付けませんでした。',
    'Move board reset to the standard starting position.':
        'Move ボードを標準の初期配置に戻しました。',
    'Network issue': 'ネットワークの問題',
    'No PGN available for this record.': 'この記録には利用できる PGN がありません。',
    'No finished game with playable moves is available yet.':
        '再生できる手を含む終了済み対局はまだありません。',
    'No moves yet': 'まだ手がありません',
    'No usable PGN games matched this Lichess player and filters.':
        'この Lichess プレイヤーとフィルターに一致する利用可能な PGN 対局はありません。',
    'Open Google Play': 'Google Play を開く',
    'Password cannot be empty.': 'パスワードを入力してください。',
    'Password reset successfully.': 'パスワードをリセットしました。',
    'Pieces are ready': '駒の準備ができました',
    'Place all 34 pieces exactly as shown before pairing.':
        'ペアリング前に 34 個すべての駒を図のとおり正確に置いてください。',
    'Preparing insight': '解析結果を準備中',
    'Preview Lichess games before starting training.':
        'トレーニング開始前に Lichess 対局を確認してください。',
    'Refresh': '更新',
    'Remove': '削除',
    'Remove piece set?': '駒セットを削除しますか？',
    'Removed pieces need to be paired again before they can be used.':
        '削除した駒は、再利用する前にもう一度ペアリングする必要があります。',
    'Replay': '再生',
    'Report': 'レポート',
    'Reset both clocks and start over.': '両方の時計をリセットして最初から始めます。',
    'Reset clock?': '時計をリセットしますか？',
    'Retry': '再試行',
    'Select': '選択',
    'Shutdown mode': 'シャットダウンモード',
    'Shutdown mode sent.': 'シャットダウンモードを送信しました。',
    'Start pairing': 'ペアリング開始',
    'Switch account': 'アカウントを切り替える',
    'Tap a move to jump back to the board.': '手をタップすると、その盤面に戻ります。',
    'The new set has been paired and saved to this channel.':
        '新しいセットをペアリングし、このチャンネルに保存しました。',
    'The selected PGN file is empty.': '選択した PGN ファイルは空です。',
    'This PGN could not be read. Check the PGN file and try again.':
        'この PGN を読み込めませんでした。PGN ファイルを確認して、もう一度お試しください。',
    'This PGN could not be read. Check the move list and try again.':
        'この PGN を読み込めませんでした。手順を確認して、もう一度お試しください。',
    'This update will be handled by Google Play on this device.':
        'この端末では Google Play が更新を処理します。',
    'This update will open the Chessnut page on Google Play.':
        'Google Play の Chessnut ページを開きます。',
    'Time': '時間',
    'Turn on': 'オンにする',
    'Turn on shutdown mode?': 'シャットダウンモードをオンにしますか？',
    'Unable to check Lichess authorization. Please try again.':
        'Lichess の認証状態を確認できませんでした。もう一度お試しください。',
    'Unable to download Grandeur report.': 'Grandeur レポートをダウンロードできませんでした。',
    'Unable to open this PGN file. Choose another file and try again.':
        'この PGN ファイルを開けませんでした。別のファイルを選んで、もう一度お試しください。',
    'Unable to pair pieces': '駒をペアリングできません',
    'Unable to send command.': 'コマンドを送信できませんでした。',
    'Unable to switch to this account.': 'このアカウントに切り替えられませんでした。',
    'Update with Google Play': 'Google Play で更新',
    'Use another saved Chessnut ID': '保存済みの別の Chessnut ID を使用',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        '長期保管に使用します。再び使う前に、駒を充電ボードに置く必要があります。',
    'Use this position': 'この局面を使用',
    'Verification code cannot be empty.': '確認コードを入力してください。',
    'Verification code required': '確認コードが必要です',
    'View first-time tips again': '初回ガイドをもう一度見る',
    'no legal mainline moves': 'メインラインに合法手がありません',
    'sec': '秒',
    'Bluetooth': 'Bluetooth',
    'Cantonese': '広東語',
    'Control the board LED hints used while setting up and playing.':
        '配置中や対局中に使うボードの LED ガイドを設定します。',
    'Copy URL': 'URL をコピー',
    'End game': '対局を終了',
    'Game marked as ended.': '対局を終了済みにしました。',
    'Mandarin': '標準中国語',
    'Open': '開く',
    'Replay guides': 'ガイドをもう一度見る',
    'Show all guides next time': '次回すべてのガイドを表示',
    'Sign in before starting Career Mode.': 'キャリアモードを始める前にログインしてください。',
    'Skip': 'スキップ',
    'Start': '開始',
    'Tap to view details': 'タップして詳細を表示',
    'This game ended before any playable moves, so there is no position to analyze.':
        'この対局は再生可能な手がないまま終了したため、解析できる局面がありません。',
    'Unable to end this game record.': 'この対局記録を終了できませんでした。',
    'Voice moves': '音声入力による着手',
  },
  'ko': {
    '6-digit code': '6자리 코드',
    'Analysis marker LED patterns': '분석 표시 LED 패턴',
    'Auto-detect set': '기물 세트 자동 감지',
    'Back to channels': '채널로 돌아가기',
    'Board connection failed.': '보드 연결에 실패했습니다.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        '보드 연결이 끊어졌고 재연결에도 실패했습니다. 대국 화면은 열린 상태로 유지됩니다.',
    'Check placement, battery, and nearby interference, then try again.':
        '기물 배치, 배터리, 주변 간섭을 확인한 후 다시 시도하세요.',
    'Checkpoints': '확인 지점',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': '클라우드 Maia 3',
    'Confirm': '확인',
    'Confirm draw': '무승부 확인',
    'Confirm takeback': '무르기 확인',
    'Date': '날짜',
    'Delete': '삭제',
    'Fill': '채우기',
    'G': '국',
    'Go to login': '로그인으로 이동',
    'Google Play update is not available right now. Opening the store page instead.':
        '현재 Google Play 앱 내 업데이트를 사용할 수 없어 스토어 페이지를 엽니다.',
    'Grandeur HTML report downloaded.': 'Grandeur HTML 보고서를 다운로드했습니다.',
    'Help': '도움말',
    'Interactive': '대화형',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        '페어링 중에는 주변의 다른 Move 세트를 멀리 두세요. 보통 3~5분이 걸립니다.',
    'Key moments': '핵심 순간',
    'Latest version': '최신 버전',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.':
        'Lichess가 시간 내에 응답하지 않았습니다. 다시 시도하세요.',
    'Location': '장소',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3가 각 수에서 사람이 선택할 가능성이 높은 후보를 추정하고 있습니다.',
    'More filters': '필터 더 보기',
    'Move board did not accept the command.': 'Move 보드가 명령을 받지 않았습니다.',
    'Move board did not accept the reset command.':
        'Move 보드가 초기화 명령을 받지 않았습니다.',
    'Move board reset to the standard starting position.':
        'Move 보드를 표준 시작 위치로 초기화했습니다.',
    'Network issue': '네트워크 문제',
    'No PGN available for this record.': '이 기록에 사용할 수 있는 PGN이 없습니다.',
    'No finished game with playable moves is available yet.':
        '재생 가능한 수가 있는 종료 대국이 아직 없습니다.',
    'No moves yet': '아직 수가 없습니다',
    'No usable PGN games matched this Lichess player and filters.':
        '이 Lichess 선수와 필터에 맞는 사용 가능한 PGN 대국이 없습니다.',
    'Open Google Play': 'Google Play 열기',
    'Password cannot be empty.': '비밀번호를 입력하세요.',
    'Password reset successfully.': '비밀번호를 재설정했습니다.',
    'Pieces are ready': '기물이 준비되었습니다',
    'Place all 34 pieces exactly as shown before pairing.':
        '페어링 전에 34개 기물을 그림과 똑같이 배치하세요.',
    'Preparing insight': '분석 정보 준비 중',
    'Preview Lichess games before starting training.':
        '훈련을 시작하기 전에 Lichess 대국을 미리 확인하세요.',
    'Refresh': '새로고침',
    'Remove': '제거',
    'Remove piece set?': '기물 세트를 제거할까요?',
    'Removed pieces need to be paired again before they can be used.':
        '제거한 기물은 다시 사용하기 전에 페어링해야 합니다.',
    'Replay': '다시 보기',
    'Report': '보고서',
    'Reset both clocks and start over.': '양쪽 시계를 초기화하고 다시 시작합니다.',
    'Reset clock?': '시계를 초기화할까요?',
    'Retry': '다시 시도',
    'Select': '선택',
    'Shutdown mode': '종료 모드',
    'Shutdown mode sent.': '종료 모드 명령을 보냈습니다.',
    'Start pairing': '페어링 시작',
    'Switch account': '계정 전환',
    'Tap a move to jump back to the board.': '수를 탭하면 해당 보드 위치로 이동합니다.',
    'The new set has been paired and saved to this channel.':
        '새 세트를 페어링하여 이 채널에 저장했습니다.',
    'The selected PGN file is empty.': '선택한 PGN 파일이 비어 있습니다.',
    'This PGN could not be read. Check the PGN file and try again.':
        '이 PGN을 읽을 수 없습니다. PGN 파일을 확인한 후 다시 시도하세요.',
    'This PGN could not be read. Check the move list and try again.':
        '이 PGN을 읽을 수 없습니다. 수 목록을 확인한 후 다시 시도하세요.',
    'This update will be handled by Google Play on this device.':
        '이 기기에서는 Google Play가 업데이트를 처리합니다.',
    'This update will open the Chessnut page on Google Play.':
        'Google Play의 Chessnut 페이지를 엽니다.',
    'Time': '시간',
    'Turn on': '켜기',
    'Turn on shutdown mode?': '종료 모드를 켤까요?',
    'Unable to check Lichess authorization. Please try again.':
        'Lichess 인증 상태를 확인할 수 없습니다. 다시 시도하세요.',
    'Unable to download Grandeur report.': 'Grandeur 보고서를 다운로드할 수 없습니다.',
    'Unable to open this PGN file. Choose another file and try again.':
        '이 PGN 파일을 열 수 없습니다. 다른 파일을 선택한 후 다시 시도하세요.',
    'Unable to pair pieces': '기물을 페어링할 수 없습니다',
    'Unable to send command.': '명령을 보낼 수 없습니다.',
    'Unable to switch to this account.': '이 계정으로 전환할 수 없습니다.',
    'Update with Google Play': 'Google Play로 업데이트',
    'Use another saved Chessnut ID': '저장된 다른 Chessnut ID 사용',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        '장기 보관에 사용합니다. 다시 사용하기 전에 기물을 충전 보드에 놓아야 합니다.',
    'Use this position': '이 포지션 사용',
    'Verification code cannot be empty.': '인증 코드를 입력하세요.',
    'Verification code required': '인증 코드 필요',
    'View first-time tips again': '첫 사용 안내 다시 보기',
    'no legal mainline moves': '메인 라인에 합법적인 수가 없습니다',
    'sec': '초',
    'Cantonese': '광둥어',
    'Control the board LED hints used while setting up and playing.':
        '배치와 대국 중에 사용하는 보드 LED 안내를 설정합니다.',
    'Copy URL': 'URL 복사',
    'End game': '대국 종료',
    'Game marked as ended.': '대국을 종료 상태로 표시했습니다.',
    'Mandarin': '표준 중국어',
    'Open': '열기',
    'Replay guides': '안내 다시 보기',
    'Show all guides next time': '다음에 모든 안내 표시',
    'Sign in before starting Career Mode.': '커리어 모드를 시작하기 전에 로그인하세요.',
    'Skip': '건너뛰기',
    'Start': '시작',
    'Tap to view details': '탭하여 세부 정보 보기',
    'This game ended before any playable moves, so there is no position to analyze.':
        '이 대국은 재생 가능한 수 없이 종료되어 분석할 포지션이 없습니다.',
    'Unable to end this game record.': '이 대국 기록을 종료할 수 없습니다.',
    'Voice moves': '음성 수 입력',
  },
  'nl': {
    '6-digit code': '6-cijferige code',
    'Analysis marker LED patterns': 'LED-patronen voor analysemarkeringen',
    'Auto-detect set': 'Set automatisch detecteren',
    'Back to channels': 'Terug naar kanalen',
    'Board connection failed.': 'Verbinding met het bord mislukt.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'Het bord is losgekoppeld en opnieuw verbinden is mislukt; de partij blijft open.',
    'Check placement, battery, and nearby interference, then try again.':
        'Controleer de opstelling, batterij en storingsbronnen in de buurt en probeer het opnieuw.',
    'Checkpoints': 'Controlepunten',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': 'Maia 3 in de cloud',
    'Confirm': 'Bevestigen',
    'Confirm draw': 'Remise bevestigen',
    'Confirm takeback': 'Terugname bevestigen',
    'Date': 'Datum',
    'Delete': 'Verwijderen',
    'Fill': 'Vullen',
    'G': 'P',
    'Go to login': 'Naar aanmelden',
    'Google Play update is not available right now. Opening the store page instead.':
        'De Google Play-update is nu niet beschikbaar. De winkelpagina wordt geopend.',
    'Grandeur HTML report downloaded.':
        'Het Grandeur-HTML-rapport is gedownload.',
    'Help': 'Hulp',
    'Interactive': 'Interactief',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Houd andere Move-sets uit de buurt tijdens het koppelen. Dit duurt meestal 3–5 minuten.',
    'Key moments': 'Belangrijke momenten',
    'Latest version': 'Nieuwste versie',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.':
        'Lichess reageerde niet op tijd. Probeer het opnieuw.',
    'Location': 'Locatie',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 schat voor elke zet de waarschijnlijke menselijke keuzes.',
    'More filters': 'Meer filters',
    'Move board did not accept the command.':
        'Het Move-bord heeft de opdracht niet geaccepteerd.',
    'Move board did not accept the reset command.':
        'Het Move-bord heeft de resetopdracht niet geaccepteerd.',
    'Move board reset to the standard starting position.':
        'Het Move-bord is teruggezet naar de standaardbeginstelling.',
    'Network issue': 'Netwerkprobleem',
    'No PGN available for this record.':
        'Voor dit record is geen PGN beschikbaar.',
    'No finished game with playable moves is available yet.':
        'Er is nog geen voltooide partij met afspeelbare zetten beschikbaar.',
    'No moves yet': 'Nog geen zetten',
    'No usable PGN games matched this Lichess player and filters.':
        'Geen bruikbare PGN-partijen gevonden voor deze Lichess-speler en filters.',
    'Open Google Play': 'Google Play openen',
    'Password cannot be empty.': 'Het wachtwoord mag niet leeg zijn.',
    'Password reset successfully.': 'Wachtwoord opnieuw ingesteld.',
    'Pieces are ready': 'Stukken zijn gereed',
    'Place all 34 pieces exactly as shown before pairing.':
        'Plaats alle 34 stukken precies zoals afgebeeld voordat je koppelt.',
    'Preparing insight': 'Inzicht voorbereiden',
    'Preview Lichess games before starting training.':
        'Bekijk de Lichess-partijen voordat je de training start.',
    'Refresh': 'Vernieuwen',
    'Remove': 'Verwijderen',
    'Remove piece set?': 'Stukkenset verwijderen?',
    'Removed pieces need to be paired again before they can be used.':
        'Verwijderde stukken moeten opnieuw worden gekoppeld voordat je ze kunt gebruiken.',
    'Replay': 'Opnieuw afspelen',
    'Report': 'Rapport',
    'Reset both clocks and start over.':
        'Beide klokken resetten en opnieuw beginnen.',
    'Reset clock?': 'Klok resetten?',
    'Retry': 'Opnieuw proberen',
    'Select': 'Selecteren',
    'Shutdown mode': 'Uitschakelmodus',
    'Shutdown mode sent.': 'Uitschakelmodus verzonden.',
    'Start pairing': 'Koppelen starten',
    'Switch account': 'Account wisselen',
    'Tap a move to jump back to the board.':
        'Tik op een zet om naar die bordstelling te gaan.',
    'The new set has been paired and saved to this channel.':
        'De nieuwe set is gekoppeld en in dit kanaal opgeslagen.',
    'The selected PGN file is empty.': 'Het geselecteerde PGN-bestand is leeg.',
    'This PGN could not be read. Check the PGN file and try again.':
        'Deze PGN kon niet worden gelezen. Controleer het bestand en probeer het opnieuw.',
    'This PGN could not be read. Check the move list and try again.':
        'Deze PGN kon niet worden gelezen. Controleer de zettenlijst en probeer het opnieuw.',
    'This update will be handled by Google Play on this device.':
        'Deze update wordt op dit apparaat door Google Play uitgevoerd.',
    'This update will open the Chessnut page on Google Play.':
        'Deze update opent de Chessnut-pagina op Google Play.',
    'Time': 'Tijd',
    'Turn on': 'Inschakelen',
    'Turn on shutdown mode?': 'Uitschakelmodus inschakelen?',
    'Unable to check Lichess authorization. Please try again.':
        'De Lichess-autorisatie kon niet worden gecontroleerd. Probeer het opnieuw.',
    'Unable to download Grandeur report.':
        'Het Grandeur-rapport kon niet worden gedownload.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Dit PGN-bestand kon niet worden geopend. Kies een ander bestand en probeer het opnieuw.',
    'Unable to pair pieces': 'Stukken konden niet worden gekoppeld',
    'Unable to send command.': 'Opdracht kon niet worden verzonden.',
    'Unable to switch to this account.': 'Kan niet naar dit account wisselen.',
    'Update with Google Play': 'Bijwerken met Google Play',
    'Use another saved Chessnut ID':
        'Een andere opgeslagen Chessnut ID gebruiken',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Gebruik dit voor langdurige opslag. De stukken moeten op het laadbord worden geplaatst voordat je ze weer kunt gebruiken.',
    'Use this position': 'Deze stelling gebruiken',
    'Verification code cannot be empty.':
        'De verificatiecode mag niet leeg zijn.',
    'Verification code required': 'Verificatiecode vereist',
    'View first-time tips again': 'Introductietips opnieuw bekijken',
    'no legal mainline moves': 'geen legale zetten in de hoofdvariant',
    'sec': 'sec.',
    'Account': 'Gebruikersaccount',
    'Auto': 'Automatisch',
    'Bluetooth': 'Bluetooth',
    'Blunder': 'Grove fout',
    'Camera': 'Fotocamera',
    'Cantonese': 'Kantonees',
    'Control the board LED hints used while setting up and playing.':
        'Beheer de LED-aanwijzingen van het bord tijdens opstelling en spel.',
    'Copy URL': 'URL kopiëren',
    'End game': 'Partij beëindigen',
    'Engine': 'Schaakengine',
    'Game marked as ended.': 'Partij gemarkeerd als beëindigd.',
    'Later': 'Op een later moment',
    'Live': 'Liveweergave',
    'Mandarin': 'Mandarijn',
    'Open': 'Openen',
    'Replay guides': 'Handleidingen opnieuw bekijken',
    'Reset': 'Resetten',
    'Show all guides next time': 'Volgende keer alle handleidingen tonen',
    'Sign in before starting Career Mode.':
        'Meld je aan voordat je de carrièremodus start.',
    'Skip': 'Overslaan',
    'Start': 'Starten',
    'Stockfish live': 'Stockfish-liveanalyse',
    'Tap to view details': 'Tik om details te bekijken',
    'This game ended before any playable moves, so there is no position to analyze.':
        'Deze partij eindigde vóór een afspeelbare zet, dus er is geen stelling om te analyseren.',
    'Unable to end this game record.':
        'Dit partijrecord kon niet worden beëindigd.',
    'Voice moves': 'Stemzetten',
  },
  'ru': {
    '6-digit code': '6-значный код',
    'Analysis marker LED patterns': 'LED-схемы меток анализа',
    'Auto-detect set': 'Автоопределение комплекта',
    'Back to channels': 'Назад к каналам',
    'Board connection failed.': 'Не удалось подключить доску.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'Доска отключилась, повторное подключение не удалось; партия останется открытой.',
    'Check placement, battery, and nearby interference, then try again.':
        'Проверьте расстановку, заряд и помехи поблизости, затем повторите попытку.',
    'Checkpoints': 'Контрольные точки',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Cloud Maia 3': 'Облачная Maia 3',
    'Confirm': 'Подтвердить',
    'Confirm draw': 'Подтвердить ничью',
    'Confirm takeback': 'Подтвердить возврат хода',
    'Date': 'Дата',
    'Delete': 'Удалить',
    'Fill': 'Заполнить',
    'G': 'П',
    'Go to login': 'Перейти ко входу',
    'Google Play update is not available right now. Opening the store page instead.':
        'Обновление через Google Play сейчас недоступно. Открываем страницу магазина.',
    'Grandeur HTML report downloaded.': 'HTML-отчёт Grandeur загружен.',
    'Help': 'Помощь',
    'Interactive': 'Интерактивный',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Уберите другие комплекты Move подальше на время сопряжения. Обычно это занимает 3–5 минут.',
    'Key moments': 'Ключевые моменты',
    'Latest version': 'Последняя версия',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess did not respond in time. Try again.':
        'Lichess не ответил вовремя. Повторите попытку.',
    'Location': 'Место',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 оценивает вероятный выбор человека для каждого хода.',
    'More filters': 'Другие фильтры',
    'Move board did not accept the command.': 'Доска Move не приняла команду.',
    'Move board did not accept the reset command.':
        'Доска Move не приняла команду сброса.',
    'Move board reset to the standard starting position.':
        'Доска Move возвращена в стандартную начальную позицию.',
    'Network issue': 'Проблема сети',
    'No PGN available for this record.': 'Для этой записи нет доступного PGN.',
    'No finished game with playable moves is available yet.':
        'Пока нет завершённой партии с доступными для воспроизведения ходами.',
    'No moves yet': 'Ходов пока нет',
    'No usable PGN games matched this Lichess player and filters.':
        'Для этого игрока Lichess и выбранных фильтров нет подходящих PGN-партий.',
    'Open Google Play': 'Открыть Google Play',
    'Password cannot be empty.': 'Пароль не может быть пустым.',
    'Password reset successfully.': 'Пароль успешно сброшен.',
    'Pieces are ready': 'Фигуры готовы',
    'Place all 34 pieces exactly as shown before pairing.':
        'Перед сопряжением расставьте все 34 фигуры точно по схеме.',
    'Preparing insight': 'Подготовка анализа',
    'Preview Lichess games before starting training.':
        'Просмотрите партии Lichess перед началом обучения.',
    'Refresh': 'Обновить',
    'Remove': 'Удалить',
    'Remove piece set?': 'Удалить комплект фигур?',
    'Removed pieces need to be paired again before they can be used.':
        'Удалённые фигуры нужно снова сопрячь перед использованием.',
    'Replay': 'Повтор',
    'Report': 'Отчёт',
    'Reset both clocks and start over.':
        'Сбросить оба таймера и начать заново.',
    'Reset clock?': 'Сбросить часы?',
    'Retry': 'Повторить',
    'Select': 'Выбрать',
    'Shutdown mode': 'Режим выключения',
    'Shutdown mode sent.': 'Команда режима выключения отправлена.',
    'Start pairing': 'Начать сопряжение',
    'Switch account': 'Сменить аккаунт',
    'Tap a move to jump back to the board.':
        'Нажмите ход, чтобы перейти к этой позиции на доске.',
    'The new set has been paired and saved to this channel.':
        'Новый комплект сопряжён и сохранён в этом канале.',
    'The selected PGN file is empty.': 'Выбранный файл PGN пуст.',
    'This PGN could not be read. Check the PGN file and try again.':
        'Не удалось прочитать PGN. Проверьте файл и повторите попытку.',
    'This PGN could not be read. Check the move list and try again.':
        'Не удалось прочитать PGN. Проверьте список ходов и повторите попытку.',
    'This update will be handled by Google Play on this device.':
        'На этом устройстве обновление будет выполнено через Google Play.',
    'This update will open the Chessnut page on Google Play.':
        'Будет открыта страница Chessnut в Google Play.',
    'Time': 'Время',
    'Turn on': 'Включить',
    'Turn on shutdown mode?': 'Включить режим выключения?',
    'Unable to check Lichess authorization. Please try again.':
        'Не удалось проверить авторизацию Lichess. Повторите попытку.',
    'Unable to download Grandeur report.': 'Не удалось скачать отчёт Grandeur.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Не удалось открыть этот файл PGN. Выберите другой файл и повторите попытку.',
    'Unable to pair pieces': 'Не удалось сопрячь фигуры',
    'Unable to send command.': 'Не удалось отправить команду.',
    'Unable to switch to this account.':
        'Не удалось переключиться на этот аккаунт.',
    'Update with Google Play': 'Обновить через Google Play',
    'Use another saved Chessnut ID':
        'Использовать другой сохранённый Chessnut ID',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Используйте для длительного хранения. Перед следующим использованием фигуры нужно поставить на зарядную доску.',
    'Use this position': 'Использовать эту позицию',
    'Verification code cannot be empty.':
        'Код подтверждения не может быть пустым.',
    'Verification code required': 'Требуется код подтверждения',
    'View first-time tips again': 'Снова показать начальные подсказки',
    'no legal mainline moves': 'нет допустимых ходов в основной линии',
    'sec': 'с',
    'Bluetooth': 'Bluetooth',
    'Cantonese': 'Кантонский',
    'Control the board LED hints used while setting up and playing.':
        'Настройте LED-подсказки доски при расстановке и игре.',
    'Copy URL': 'Копировать URL',
    'End game': 'Завершить партию',
    'Game marked as ended.': 'Партия отмечена как завершённая.',
    'Mandarin': 'Мандаринский китайский',
    'Open': 'Открыть',
    'Replay guides': 'Снова показать инструкции',
    'Show all guides next time': 'В следующий раз показать все инструкции',
    'Sign in before starting Career Mode.':
        'Войдите перед запуском режима карьеры.',
    'Skip': 'Пропустить',
    'Start': 'Начать',
    'Tap to view details': 'Нажмите, чтобы посмотреть подробности',
    'This game ended before any playable moves, so there is no position to analyze.':
        'Партия завершилась до появления воспроизводимых ходов, поэтому позиции для анализа нет.',
    'Unable to end this game record.':
        'Не удалось завершить эту запись партии.',
    'Voice moves': 'Голосовые ходы',
  },
  'pt': {
    '6-digit code': 'Código de 6 dígitos',
    'A newer version is available. Update now to get the latest fixes and improvements.':
        'Uma versão mais recente está disponível. Atualize agora para obter as últimas correções e melhorias.',
    'Add an engine name before starting training.':
        'Adicione um nome ao motor antes de iniciar o treino.',
    'All daily tasks completed.': 'Todas as tarefas diárias foram concluídas.',
    'Analysis marker LED patterns': 'Padrões LED dos marcadores de análise',
    'Auto-detect set': 'Detectar conjunto automaticamente',
    'Automatic switch press': 'Pressão automática do botão',
    'Back to channels': 'Voltar aos canais',
    'Black games': 'Partidas de pretas',
    'Bluetooth': 'Bluetooth',
    'Board Settings lets you choose Direct control or Web control for physical board moves.':
        'As Definições do tabuleiro permitem escolher Controlo direto ou Controlo web para os lances no tabuleiro físico.',
    'Board connection failed.': 'Falha ao ligar ao tabuleiro.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'O tabuleiro desligou-se e não foi possível voltar a ligar; a partida continuará aberta.',
    'Bot game engine library':
        'Biblioteca de motores para jogar contra o computador',
    'Camera': 'Câmara',
    'Candidate moves are human probabilities, not best-move scores.':
        'Os lances candidatos representam probabilidades humanas, não avaliações do melhor lance.',
    'Cantonese': 'Cantonês',
    'Casual only': 'Apenas casuais',
    'Check for updates': 'Procurar atualizações',
    'Check placement, battery, and nearby interference, then try again.':
        'Verifique a colocação, a bateria e as interferências próximas e tente novamente.',
    'Check whether a newer Chessnut version is available.':
        'Verifique se existe uma versão mais recente do Chessnut.',
    'Checked in today / Grandeur 100 / personal engine training 500':
        'Check-in feito hoje / Grandeur 100 / treino de motor pessoal 500',
    'Checking': 'A verificar',
    'Checkpoints': 'Pontos de controlo',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Chessnut Vision is now active.': 'O Chessnut Vision está agora ativo.',
    'Choose a target': 'Escolha um objetivo',
    'Choose image': 'Escolher imagem',
    'Claimed': 'Resgatado',
    'Clear page': 'Limpar página',
    'Close authorization': 'Fechar autorização',
    'Cloud Maia 3': 'Maia 3 na nuvem',
    'Compare with Stockfish': 'Comparar com Stockfish',
    'Confirm': 'Confirmar',
    'Confirm draw': 'Confirmar empate',
    'Confirm resign': 'Confirmar desistência',
    'Confirm takeback': 'Confirmar anulação',
    'Connected as': 'Ligado como',
    'Connection Status': 'Estado da ligação',
    'Continue learning': 'Continuar a aprender',
    'Control the board LED hints used while setting up and playing.':
        'Controle as indicações LED do tabuleiro durante a configuração e a partida.',
    'Copy failed. Please try again.': 'Falha ao copiar. Tente novamente.',
    'Could not check for updates. Please try again later.':
        'Não foi possível procurar atualizações. Tente novamente mais tarde.',
    'Could not open the source link. Please try again later.':
        'Não foi possível abrir a ligação do código-fonte. Tente novamente mais tarde.',
    'Could not open the update link. Please try again later.':
        'Não foi possível abrir a ligação de atualização. Tente novamente mais tarde.',
    'Curated LC0 engines': 'Motores LC0 selecionados',
    'Daily check-in available / Grandeur 100 / personal engine training 500':
        'Check-in diário disponível / Grandeur 100 / treino de motor pessoal 500',
    'Date': 'Data',
    'Delete record': 'Eliminar registo',
    "Don't remind me again for this update":
        'Não voltar a lembrar-me desta atualização',
    'Download update': 'Transferir atualização',
    'Enable Vision': 'Ativar Vision',
    'End game': 'Terminar partida',
    'Engine comparison': 'Comparação de motores',
    'Engine disabled.': 'Motor desativado.',
    'Engine enabled for Bot game.':
        'Motor ativado para jogar contra o computador.',
    'Engine name updated.': 'Nome do motor atualizado.',
    'Enter an engine name before saving.':
        'Introduza um nome para o motor antes de guardar.',
    'Event Log': 'Registo de eventos',
    'FEN position': 'Posição FEN',
    'Fetching the latest Chessnut lesson library.':
        'A obter a biblioteca de lições mais recente do Chessnut.',
    'Fill': 'Preencher',
    'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.':
        'Filtre aqui as partidas guardadas, pré-visualize os PGN utilizáveis e inicie o treino sem sair do Engine Lab.',
    'Finish this game before generating an analysis report.':
        'Termine esta partida antes de gerar um relatório de análise.',
    'From Chess.com username': 'Do nome de utilizador Chess.com',
    'From Lichess player': 'Do jogador Lichess',
    'From PGN': 'De PGN',
    'G': 'P',
    'Game marked as ended.': 'Partida marcada como terminada.',
    'Game record deleted.': 'Registo da partida eliminado.',
    'Go': 'Ir',
    'Go to login': 'Ir para o início de sessão',
    'Google Play update is not available right now. Opening the store page instead.':
        'A atualização do Google Play não está disponível. A abrir a página da loja.',
    'Grandeur HTML report downloaded.':
        'Relatório HTML do Grandeur transferido.',
    'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.':
        'O Grandeur custa normalmente 100 pontos da carteira. Os membros pagam automaticamente 0 pontos. Se não tiver pontos suficientes, pode ganhar mais nas Tarefas diárias.',
    'Help': 'Ajuda',
    'Import Chess.com games': 'Importar partidas do Chess.com',
    'Import Lichess games': 'Importar partidas do Lichess',
    'Import PGN files before starting training.':
        'Importe ficheiros PGN antes de iniciar o treino.',
    'Import at least 1 game.': 'Importe pelo menos 1 partida.',
    'Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.':
        'Importe para os Registos de partidas as partidas concluídas de um jogador Lichess. As partidas duplicadas são ignoradas automaticamente.',
    'Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.':
        'Importe para os Registos de partidas as partidas públicas concluídas de um utilizador Chess.com. Os arquivos do Chess.com podem demorar a publicar partidas muito recentes.',
    'Include app logs and device details':
        'Incluir registos da aplicação e detalhes do dispositivo',
    'Includes app version, device type, current screen, board status, and recent logs.':
        'Inclui a versão da aplicação, tipo de dispositivo, ecrã atual, estado do tabuleiro e registos recentes.',
    'Interactive': 'Interativo',
    'Keep first 200': 'Manter os primeiros 200',
    'Keep linked': 'Manter ligado',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Mantenha outros conjuntos Move afastados durante o emparelhamento. O processo demora normalmente 3–5 minutos.',
    'Key moments': 'Momentos-chave',
    'Last Button Pressed': 'Último botão premido',
    'Later': 'Mais tarde',
    'Latest version': 'Versão mais recente',
    'Learn with your board': 'Aprenda com o seu tabuleiro',
    'Leave for now': 'Sair por agora',
    'Licenses and Maia 3 source code': 'Licenças e código-fonte do Maia 3',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess account unlinked.': 'Conta Lichess desligada.',
    'Lichess authorization complete.': 'Autorização do Lichess concluída.',
    'Lichess authorization could not open.':
        'Não foi possível abrir a autorização do Lichess.',
    'Lichess authorization could not open. Try again later.':
        'Não foi possível abrir a autorização do Lichess. Tente novamente mais tarde.',
    'Lichess authorization expired. Re-authorize before continuing.':
        'A autorização do Lichess expirou. Autorize novamente antes de continuar.',
    'Lichess authorization is not available right now. Please try again later.':
        'A autorização do Lichess não está disponível neste momento. Tente novamente mais tarde.',
    'Lichess authorization was not completed. Try again when the Lichess page finishes.':
        'A autorização do Lichess não foi concluída. Tente novamente quando a página do Lichess terminar.',
    'Lichess authorized.': 'Lichess autorizado.',
    'Lichess did not respond in time. Try again.':
        'O Lichess não respondeu a tempo. Tente novamente.',
    'Lichess sign-in status could not be checked. Please try again later.':
        'Não foi possível verificar o estado de início de sessão no Lichess. Tente novamente mais tarde.',
    'Linked account update failed. Please try again.':
        'Falha ao atualizar a conta ligada. Tente novamente.',
    'Linked accounts': 'Contas ligadas',
    'Loading courses': 'A carregar cursos',
    'Loading subtitles and board checkpoints.':
        'A carregar legendas e pontos de controlo do tabuleiro.',
    'Local QA wallet tools': 'Ferramentas locais de QA da carteira',
    'Local list': 'Lista local',
    'Location': 'Local',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia 3 predicts likely human moves from 600 to 2600 Elo. Sign in and stay online to use it.':
        'O Maia 3 prevê lances humanos prováveis entre 600 e 2600 Elo. Inicie sessão e mantenha-se online para o utilizar.',
    'Maia3 explains human likelihood. Stockfish checks objective quality.':
        'O Maia3 explica a probabilidade humana. O Stockfish verifica a qualidade objetiva.',
    'Maia3 is estimating likely human choices for each move.':
        'O Maia3 está a estimar as escolhas humanas prováveis em cada lance.',
    'Mandarin': 'Mandarim',
    'Max games': 'Máximo de partidas',
    'Member discount': 'Desconto de membro',
    'Message status could not be updated. Please try again.':
        'Não foi possível atualizar o estado da mensagem. Tente novamente.',
    'More filters': 'Mais filtros',
    'Move board did not accept the command.':
        'O tabuleiro Move não aceitou o comando.',
    'Move board did not accept the reset command.':
        'O tabuleiro Move não aceitou o comando de reposição.',
    'Move board reset to the standard starting position.':
        'O tabuleiro Move foi reposto na posição inicial padrão.',
    'Move control can be changed': 'O controlo de movimentos pode ser alterado',
    'Move likelihood': 'Probabilidade do lance',
    'Moves by rating': 'Lances por nível',
    'My personal engine': 'O meu motor pessoal',
    'Network issue': 'Problema de rede',
    'New personal engine': 'Novo motor pessoal',
    'No PGN available for this record.':
        'Não existe PGN disponível para este registo.',
    'No active themes': 'Sem temas ativos',
    'No finished game with playable moves is available yet.':
        'Ainda não existe uma partida terminada com lances reproduzíveis.',
    'No games loaded for this page.': 'Nenhuma partida carregada nesta página.',
    'No moves yet': 'Ainda não há lances',
    'No personal engines yet': 'Ainda não há motores pessoais',
    'No review mistakes yet': 'Ainda não há erros de revisão',
    'No usable PGN games matched this Lichess player and filters.':
        'Nenhuma partida PGN utilizável corresponde a este jogador Lichess e aos filtros.',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'O Maia oficial pode comparar lances entre níveis de rating. Esta vista móvel mantém compacto o modelo selecionado.',
    'Open': 'Abrir',
    'Open Google Play': 'Abrir Google Play',
    'Open source code': 'Abrir código-fonte',
    'Open store': 'Abrir loja',
    'Open-source notices': 'Avisos de código aberto',
    'Opponent move mode': 'Modo de lance do adversário',
    'Optional date or text': 'Data ou texto opcional',
    'Original cost': 'Custo original',
    'PGN refreshed.': 'PGN atualizado.',
    'Password cannot be empty.': 'A palavra-passe não pode estar vazia.',
    'Password reset successfully.': 'Palavra-passe redefinida com sucesso.',
    'Pay today': 'Pagar hoje',
    'Personal engine deleted.': 'Motor pessoal eliminado.',
    'Pieces are ready': 'As peças estão prontas',
    'Place all 34 pieces exactly as shown before pairing.':
        'Coloque as 34 peças exatamente como indicado antes de emparelhar.',
    'Play style': 'Estilo de jogo',
    'Playable engine library': 'Biblioteca de motores jogáveis',
    'Player ID': 'ID do jogador',
    'Please agree to the Terms of Use and Privacy Policy.':
        'Aceite os Termos de Utilização e a Política de Privacidade.',
    'Premium active / Grandeur and personal engine training unlimited':
        'Premium ativo / Grandeur e treino de motor pessoal ilimitados',
    'Premium is active.': 'O Premium está ativo.',
    'Preparing insight': 'A preparar análise',
    'Preparing lesson': 'A preparar lição',
    'Press clock switch': 'Premir o botão do relógio',
    'Preview Lichess games before starting training.':
        'Pré-visualize as partidas do Lichess antes de iniciar o treino.',
    'Profile update failed. Check your connection and try again.':
        'Falha ao atualizar o perfil. Verifique a ligação e tente novamente.',
    'Progress synced. Keep the streak moving.':
        'Progresso sincronizado. Continue a sequência.',
    'Purchase was not completed. You can try again when ready.':
        'A compra não foi concluída. Pode tentar novamente quando quiser.',
    'Rated and casual': 'Com rating e casuais',
    'Rated only': 'Apenas com rating',
    'Remind me in 1 day': 'Lembrar-me dentro de 1 dia',
    'Remove': 'Remover',
    'Remove piece set?': 'Remover o conjunto de peças?',
    'Removed pieces need to be paired again before they can be used.':
        'As peças removidas têm de ser emparelhadas novamente antes de serem usadas.',
    'Replay': 'Reproduzir',
    'Replay guides': 'Ver guias novamente',
    'Report': 'Relatório',
    'Report image ready to share.':
        'Imagem do relatório pronta para partilhar.',
    'Reset both clocks and start over.':
        'Repor ambos os relógios e começar de novo.',
    'Reset clock?': 'Repor o relógio?',
    'Resign and exit': 'Desistir e sair',
    'Restore purchase': 'Restaurar compra',
    'Resume': 'Continuar',
    'Retry': 'Tentar novamente',
    'Review settings': 'Definições de revisão',
    'Select': 'Selecionar',
    'Select page': 'Selecionar página',
    'Set LEFT': 'Definir ESQUERDA',
    'Set RIGHT': 'Definir DIREITA',
    'Show all guides next time': 'Mostrar todos os guias da próxima vez',
    'Show human likelihood next to the engine verdict.':
        'Mostrar a probabilidade humana junto ao veredito do motor.',
    'Shutdown mode': 'Modo de desligamento',
    'Shutdown mode sent.': 'Modo de desligamento enviado.',
    'Sign in before starting Career Mode.':
        'Inicie sessão antes de iniciar o Modo Carreira.',
    'Sign in did not finish. Please try again.':
        'O início de sessão não foi concluído. Tente novamente.',
    'Sign in to sync points and profile.':
        'Inicie sessão para sincronizar pontos e perfil.',
    'Since': 'Desde',
    'Skip': 'Ignorar',
    'Start': 'Iniciar',
    'Start import': 'Iniciar importação',
    'Start pairing': 'Iniciar emparelhamento',
    'Submitting selected games for personal engine training...':
        'A enviar as partidas selecionadas para treino do motor pessoal...',
    'Switch account': 'Mudar de conta',
    'Tactical depth': 'Profundidade tática',
    'Tap a move to jump back to the board.':
        'Toque num lance para voltar a essa posição do tabuleiro.',
    'Tap to view details': 'Toque para ver detalhes',
    'Target Elo': 'Elo alvo',
    'The PGN is still loading. Try again shortly.':
        'O PGN ainda está a carregar. Tente novamente dentro de instantes.',
    'The new set has been paired and saved to this channel.':
        'O novo conjunto foi emparelhado e guardado neste canal.',
    'The selected PGN file is empty.': 'O ficheiro PGN selecionado está vazio.',
    'Theme not available yet': 'Tema ainda indisponível',
    'This LC0 engine is not ready to download yet.':
        'Este motor LC0 ainda não está pronto para transferência.',
    'This PGN could not be read. Check the PGN file and try again.':
        'Não foi possível ler este PGN. Verifique o ficheiro e tente novamente.',
    'This PGN could not be read. Check the move list and try again.':
        'Não foi possível ler este PGN. Verifique a lista de lances e tente novamente.',
    'This PGN includes a move Chessnut cannot read. Check the move list and try again.':
        'Este PGN inclui um lance que o Chessnut não consegue ler. Verifique a lista de lances e tente novamente.',
    'This engine cannot be liked yet.':
        'Ainda não é possível marcar este motor como favorito.',
    'This game ended before any playable moves, so there is no position to analyze.':
        'A partida terminou antes de haver lances reproduzíveis, por isso não existe posição para analisar.',
    'This personal engine cannot be renamed yet.':
        'Ainda não é possível mudar o nome deste motor pessoal.',
    'This personal engine does not have a weight file yet.':
        'Este motor pessoal ainda não tem um ficheiro de pesos.',
    'This personal engine is still training.':
        'Este motor pessoal ainda está em treino.',
    'This update will be handled by Google Play on this device.':
        'Esta atualização será tratada pelo Google Play neste dispositivo.',
    'This update will open in your browser.':
        'Esta atualização será aberta no navegador.',
    'This update will open the Chessnut page on Google Play.':
        'Esta atualização abrirá a página do Chessnut no Google Play.',
    'This update will open the official Chessnut download page.':
        'Esta atualização abrirá a página oficial de transferências do Chessnut.',
    'This update will open the official app store or test track for your device.':
        'Esta atualização abrirá a loja oficial ou a faixa de testes do dispositivo.',
    'This version is required to keep Chessnut working correctly. Please update before continuing.':
        'Esta versão é necessária para manter o Chessnut a funcionar corretamente. Atualize antes de continuar.',
    'Time': 'Tempo',
    'Training modes': 'Modos de treino',
    'Turn on': 'Ativar',
    'Turn on shutdown mode?': 'Ativar o modo de desligamento?',
    'USB Clock Test': 'Teste do relógio USB',
    'Unable to check Lichess authorization. Please try again.':
        'Não foi possível verificar a autorização do Lichess. Tente novamente.',
    'Unable to delete this personal engine. Try again later.':
        'Não foi possível eliminar este motor pessoal. Tente novamente mais tarde.',
    'Unable to download Grandeur report.':
        'Não foi possível transferir o relatório Grandeur.',
    'Unable to download this LC0 engine. Check your connection and try again.':
        'Não foi possível transferir este motor LC0. Verifique a ligação e tente novamente.',
    'Unable to download this personal engine. Check your connection and try again.':
        'Não foi possível transferir este motor pessoal. Verifique a ligação e tente novamente.',
    'Unable to end this game record.':
        'Não foi possível terminar este registo de partida.',
    'Unable to load the matched Game Record preview.':
        'Não foi possível carregar a pré-visualização dos Registos de partidas encontrados.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Não foi possível abrir este ficheiro PGN. Escolha outro e tente novamente.',
    'Unable to pair pieces': 'Não foi possível emparelhar as peças',
    'Unable to refresh this PGN.': 'Não foi possível atualizar este PGN.',
    'Unable to send command.': 'Não foi possível enviar o comando.',
    'Unable to share report image.':
        'Não foi possível partilhar a imagem do relatório.',
    'Unable to start personal engine training.':
        'Não foi possível iniciar o treino do motor pessoal.',
    'Unable to switch to this account.':
        'Não foi possível mudar para esta conta.',
    'Unable to update like. Try again later.':
        'Não foi possível atualizar o favorito. Tente novamente mais tarde.',
    'Unable to update this engine name. Try again later.':
        'Não foi possível atualizar o nome deste motor. Tente novamente mais tarde.',
    'Unable to update this engine. Try again later.':
        'Não foi possível atualizar este motor. Tente novamente mais tarde.',
    'Unable to update this personal engine. Check your connection and try again.':
        'Não foi possível atualizar este motor pessoal. Verifique a ligação e tente novamente.',
    'Unlink Lichess': 'Desligar Lichess',
    'Until': 'Até',
    'Update available': 'Atualização disponível',
    'Update link is not available right now. Please try again later.':
        'A ligação de atualização não está disponível neste momento. Tente novamente mais tarde.',
    'Update now': 'Atualizar agora',
    'Update required': 'Atualização necessária',
    'Update with Google Play': 'Atualizar com Google Play',
    'Use another saved Chessnut ID': 'Usar outro Chessnut ID guardado',
    'Use selected': 'Usar selecionados',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Use este modo para armazenamento prolongado. As peças devem ser colocadas no tabuleiro de carregamento antes de voltarem a ser usadas.',
    'Use this model': 'Usar este modelo',
    'Use this position': 'Usar esta posição',
    'VIP member': 'Membro VIP',
    'Valid until': 'Válido até',
    'Verification code cannot be empty.':
        'O código de verificação não pode estar vazio.',
    'Verification code required': 'Código de verificação obrigatório',
    'Verification could not open in the app':
        'Não foi possível abrir a verificação na aplicação',
    'View first-time tips again': 'Ver novamente as dicas iniciais',
    'Voice moves': 'Lances por voz',
    'Waiting for piece status': 'A aguardar o estado das peças',
    'Wallet test tools are unavailable.':
        'As ferramentas de teste da carteira não estão disponíveis.',
    'White games': 'Partidas de brancas',
    'You are using the latest version.':
        'Está a utilizar a versão mais recente.',
    'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.':
        'A sua conta Chessnut já está ligada ao Lichess. Pode manter esta ligação ou desligá-la para autorizar outra conta Lichess.',
    'no legal mainline moves': 'sem lances legais na variante principal',
    'points': 'pontos',
    'pts': 'pnt.',
    'sec': 's',
  },
  'pl': {
    '6-digit code': '6-cyfrowy kod',
    'A newer version is available. Update now to get the latest fixes and improvements.':
        'Dostępna jest nowsza wersja. Zaktualizuj teraz, aby uzyskać najnowsze poprawki i ulepszenia.',
    'Add an engine name before starting training.':
        'Dodaj nazwę silnika przed rozpoczęciem treningu.',
    'All daily tasks completed.': 'Wszystkie zadania dzienne ukończone.',
    'Analysis marker LED patterns': 'Wzory LED znaczników analizy',
    'Auto-detect set': 'Automatycznie wykryj zestaw',
    'Automatic switch press': 'Automatyczne naciśnięcie przełącznika',
    'Back to channels': 'Wróć do kanałów',
    'Black games': 'Partie czarnymi',
    'Bluetooth': 'Bluetooth',
    'Board Settings lets you choose Direct control or Web control for physical board moves.':
        'Ustawienia szachownicy pozwalają wybrać sterowanie bezpośrednie lub internetowe dla ruchów na fizycznej szachownicy.',
    'Board connection failed.': 'Nie udało się połączyć z szachownicą.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'Szachownica została rozłączona i nie udało się połączyć ponownie; partia pozostanie otwarta.',
    'Bot game engine library': 'Biblioteka silników do gry z komputerem',
    'Camera': 'Aparat',
    'Candidate moves are human probabilities, not best-move scores.':
        'Ruchy kandydujące pokazują prawdopodobieństwo wyboru przez człowieka, a nie ocenę najlepszego ruchu.',
    'Cantonese': 'Kantoński',
    'Casual only': 'Tylko nierankingowe',
    'Check for updates': 'Sprawdź aktualizacje',
    'Check placement, battery, and nearby interference, then try again.':
        'Sprawdź ustawienie, baterię i pobliskie zakłócenia, a następnie spróbuj ponownie.',
    'Check whether a newer Chessnut version is available.':
        'Sprawdź, czy jest dostępna nowsza wersja Chessnut.',
    'Checked in today / Grandeur 100 / personal engine training 500':
        'Dzisiejsza nagroda odebrana / Grandeur 100 / trening osobistego silnika 500',
    'Checking': 'Sprawdzanie',
    'Checkpoints': 'Punkty kontrolne',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Chessnut Vision is now active.': 'Chessnut Vision jest teraz aktywny.',
    'Choose a target': 'Wybierz cel',
    'Choose image': 'Wybierz obraz',
    'Claimed': 'Odebrano',
    'Clear page': 'Wyczyść stronę',
    'Close authorization': 'Zamknij autoryzację',
    'Cloud Maia 3': 'Maia 3 w chmurze',
    'Compare with Stockfish': 'Porównaj ze Stockfish',
    'Confirm': 'Potwierdź',
    'Confirm draw': 'Potwierdź remis',
    'Confirm resign': 'Potwierdź poddanie',
    'Confirm takeback': 'Potwierdź cofnięcie',
    'Connected as': 'Połączono jako',
    'Connection Status': 'Stan połączenia',
    'Continue learning': 'Kontynuuj naukę',
    'Control the board LED hints used while setting up and playing.':
        'Steruj wskazówkami LED szachownicy używanymi podczas ustawiania i gry.',
    'Copy failed. Please try again.':
        'Nie udało się skopiować. Spróbuj ponownie.',
    'Could not check for updates. Please try again later.':
        'Nie udało się sprawdzić aktualizacji. Spróbuj ponownie później.',
    'Could not open the source link. Please try again later.':
        'Nie udało się otworzyć łącza do kodu źródłowego. Spróbuj ponownie później.',
    'Could not open the update link. Please try again later.':
        'Nie udało się otworzyć łącza aktualizacji. Spróbuj ponownie później.',
    'Curated LC0 engines': 'Wybrane silniki LC0',
    'Daily check-in available / Grandeur 100 / personal engine training 500':
        'Nagroda dzienna dostępna / Grandeur 100 / trening osobistego silnika 500',
    'Date': 'Data',
    'Delete record': 'Usuń zapis',
    "Don't remind me again for this update":
        'Nie przypominaj ponownie o tej aktualizacji',
    'Download update': 'Pobierz aktualizację',
    'Enable Vision': 'Włącz Vision',
    'End game': 'Zakończ partię',
    'Engine comparison': 'Porównanie silników',
    'Engine disabled.': 'Silnik wyłączony.',
    'Engine enabled for Bot game.': 'Silnik włączony do gry z komputerem.',
    'Engine name updated.': 'Nazwa silnika zaktualizowana.',
    'Enter an engine name before saving.':
        'Wprowadź nazwę silnika przed zapisaniem.',
    'Event Log': 'Dziennik zdarzeń',
    'FEN position': 'Pozycja FEN',
    'Fetching the latest Chessnut lesson library.':
        'Pobieranie najnowszej biblioteki lekcji Chessnut.',
    'Fill': 'Wypełnij',
    'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.':
        'Filtruj tutaj zapisane partie, przejrzyj użyteczne PGN-y i rozpocznij trening bez opuszczania Engine Lab.',
    'Finish this game before generating an analysis report.':
        'Zakończ tę partię przed wygenerowaniem raportu analizy.',
    'From Chess.com username': 'Z konta Chess.com',
    'From Lichess player': 'Od gracza Lichess',
    'From PGN': 'Z PGN',
    'G': 'P',
    'Game marked as ended.': 'Partia oznaczona jako zakończona.',
    'Game record deleted.': 'Zapis partii usunięty.',
    'Go': 'Przejdź',
    'Go to login': 'Przejdź do logowania',
    'Google Play update is not available right now. Opening the store page instead.':
        'Aktualizacja Google Play jest teraz niedostępna. Zostanie otwarta strona sklepu.',
    'Grandeur HTML report downloaded.': 'Pobrano raport HTML Grandeur.',
    'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.':
        'Grandeur zwykle kosztuje 100 punktów portfela. Członkowie automatycznie płacą 0 punktów. Jeśli masz za mało punktów, zdobądź więcej w Zadaniach dziennych.',
    'Help': 'Pomoc',
    'Import Chess.com games': 'Importuj partie z Chess.com',
    'Import Lichess games': 'Importuj partie z Lichess',
    'Import PGN files before starting training.':
        'Zaimportuj pliki PGN przed rozpoczęciem treningu.',
    'Import at least 1 game.': 'Zaimportuj co najmniej 1 partię.',
    'Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.':
        'Importuj zakończone partie gracza Lichess do zapisów partii. Duplikaty będą automatycznie pomijane.',
    'Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.':
        'Importuj publiczne zakończone partie użytkownika Chess.com do zapisów partii. Najnowsze partie mogą pojawić się w archiwum Chess.com z opóźnieniem.',
    'Include app logs and device details':
        'Dołącz dzienniki aplikacji i dane urządzenia',
    'Includes app version, device type, current screen, board status, and recent logs.':
        'Obejmuje wersję aplikacji, typ urządzenia, bieżący ekran, stan szachownicy i ostatnie dzienniki.',
    'Interactive': 'Interaktywny',
    'Keep first 200': 'Zachowaj pierwsze 200',
    'Keep linked': 'Pozostaw połączone',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Podczas parowania odsuń inne zestawy Move. Proces zwykle trwa 3–5 minut.',
    'Key moments': 'Kluczowe momenty',
    'Last Button Pressed': 'Ostatnio naciśnięty przycisk',
    'Later': 'Później',
    'Latest version': 'Najnowsza wersja',
    'Learn with your board': 'Ucz się z szachownicą',
    'Leave for now': 'Wyjdź na razie',
    'Licenses and Maia 3 source code': 'Licencje i kod źródłowy Maia 3',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess account unlinked.': 'Konto Lichess odłączone.',
    'Lichess authorization complete.': 'Autoryzacja Lichess zakończona.',
    'Lichess authorization could not open.':
        'Nie udało się otworzyć autoryzacji Lichess.',
    'Lichess authorization could not open. Try again later.':
        'Nie udało się otworzyć autoryzacji Lichess. Spróbuj ponownie później.',
    'Lichess authorization expired. Re-authorize before continuing.':
        'Autoryzacja Lichess wygasła. Autoryzuj ponownie przed kontynuowaniem.',
    'Lichess authorization is not available right now. Please try again later.':
        'Autoryzacja Lichess jest teraz niedostępna. Spróbuj ponownie później.',
    'Lichess authorization was not completed. Try again when the Lichess page finishes.':
        'Autoryzacja Lichess nie została ukończona. Spróbuj ponownie po zakończeniu działania strony Lichess.',
    'Lichess authorized.': 'Lichess autoryzowany.',
    'Lichess did not respond in time. Try again.':
        'Lichess nie odpowiedział na czas. Spróbuj ponownie.',
    'Lichess sign-in status could not be checked. Please try again later.':
        'Nie udało się sprawdzić stanu logowania Lichess. Spróbuj ponownie później.',
    'Linked account update failed. Please try again.':
        'Nie udało się zaktualizować połączonego konta. Spróbuj ponownie.',
    'Linked accounts': 'Połączone konta',
    'Loading courses': 'Ładowanie kursów',
    'Loading subtitles and board checkpoints.':
        'Ładowanie napisów i punktów kontrolnych szachownicy.',
    'Local QA wallet tools': 'Lokalne narzędzia testowe portfela',
    'Local list': 'Lista lokalna',
    'Location': 'Miejsce',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia 3 predicts likely human moves from 600 to 2600 Elo. Sign in and stay online to use it.':
        'Maia 3 przewiduje prawdopodobne ruchy ludzi od 600 do 2600 Elo. Zaloguj się i pozostań online, aby jej używać.',
    'Maia3 explains human likelihood. Stockfish checks objective quality.':
        'Maia3 wyjaśnia prawdopodobieństwo ludzkiego wyboru. Stockfish sprawdza obiektywną jakość.',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 szacuje prawdopodobne wybory człowieka dla każdego ruchu.',
    'Mandarin': 'Mandaryński',
    'Max games': 'Maksymalna liczba partii',
    'Member discount': 'Zniżka członkowska',
    'Message status could not be updated. Please try again.':
        'Nie udało się zaktualizować stanu wiadomości. Spróbuj ponownie.',
    'More filters': 'Więcej filtrów',
    'Move board did not accept the command.':
        'Szachownica Move nie przyjęła polecenia.',
    'Move board did not accept the reset command.':
        'Szachownica Move nie przyjęła polecenia resetowania.',
    'Move board reset to the standard starting position.':
        'Szachownica Move została ustawiona w standardowej pozycji początkowej.',
    'Move control can be changed': 'Sterowanie ruchami można zmienić',
    'Move likelihood': 'Prawdopodobieństwo ruchu',
    'Moves by rating': 'Ruchy według rankingu',
    'My personal engine': 'Mój osobisty silnik',
    'Network issue': 'Problem z siecią',
    'New personal engine': 'Nowy osobisty silnik',
    'No PGN available for this record.': 'Brak PGN dla tego zapisu.',
    'No active themes': 'Brak aktywnych motywów',
    'No finished game with playable moves is available yet.':
        'Nie ma jeszcze zakończonej partii z odtwarzalnymi ruchami.',
    'No games loaded for this page.':
        'Na tej stronie nie wczytano żadnych partii.',
    'No moves yet': 'Brak ruchów',
    'No personal engines yet': 'Brak osobistych silników',
    'No review mistakes yet': 'Brak błędów do omówienia',
    'No usable PGN games matched this Lichess player and filters.':
        'Brak użytecznych partii PGN pasujących do tego gracza Lichess i filtrów.',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Oficjalna Maia porównuje ruchy na różnych poziomach rankingu. Ten widok mobilny prezentuje wybrany model w zwartej formie.',
    'Open': 'Otwórz',
    'Open Google Play': 'Otwórz Google Play',
    'Open source code': 'Otwórz kod źródłowy',
    'Open store': 'Otwórz sklep',
    'Open-source notices': 'Informacje o otwartym oprogramowaniu',
    'Opponent move mode': 'Tryb ruchu przeciwnika',
    'Optional date or text': 'Opcjonalna data lub tekst',
    'Original cost': 'Cena pierwotna',
    'PGN refreshed.': 'PGN odświeżony.',
    'Password cannot be empty.': 'Hasło nie może być puste.',
    'Password reset successfully.': 'Hasło zostało zresetowane.',
    'Pay today': 'Zapłać dziś',
    'Personal engine deleted.': 'Osobisty silnik usunięty.',
    'Pieces are ready': 'Figury są gotowe',
    'Place all 34 pieces exactly as shown before pairing.':
        'Przed parowaniem ustaw wszystkie 34 figury dokładnie jak na ilustracji.',
    'Play style': 'Styl gry',
    'Playable engine library': 'Biblioteka silników do gry',
    'Player ID': 'ID gracza',
    'Please agree to the Terms of Use and Privacy Policy.':
        'Zaakceptuj Warunki użytkowania i Politykę prywatności.',
    'Premium active / Grandeur and personal engine training unlimited':
        'Premium aktywne / Grandeur i trening osobistego silnika bez limitu',
    'Premium is active.': 'Premium jest aktywne.',
    'Preparing insight': 'Przygotowywanie analizy',
    'Preparing lesson': 'Przygotowywanie lekcji',
    'Press clock switch': 'Naciśnij przełącznik zegara',
    'Preview Lichess games before starting training.':
        'Przejrzyj partie Lichess przed rozpoczęciem treningu.',
    'Profile update failed. Check your connection and try again.':
        'Nie udało się zaktualizować profilu. Sprawdź połączenie i spróbuj ponownie.',
    'Progress synced. Keep the streak moving.':
        'Postęp zsynchronizowany. Kontynuuj serię.',
    'Purchase was not completed. You can try again when ready.':
        'Zakup nie został ukończony. Możesz spróbować ponownie później.',
    'Rated and casual': 'Rankingowe i nierankingowe',
    'Rated only': 'Tylko rankingowe',
    'Remind me in 1 day': 'Przypomnij za 1 dzień',
    'Remove': 'Usuń',
    'Remove piece set?': 'Usunąć zestaw figur?',
    'Removed pieces need to be paired again before they can be used.':
        'Usunięte figury trzeba ponownie sparować przed użyciem.',
    'Replay': 'Odtwórz',
    'Replay guides': 'Wyświetl ponownie przewodniki',
    'Report': 'Raport',
    'Report image ready to share.':
        'Obraz raportu jest gotowy do udostępnienia.',
    'Reset both clocks and start over.':
        'Zresetuj oba zegary i zacznij od nowa.',
    'Reset clock?': 'Zresetować zegar?',
    'Resign and exit': 'Poddaj się i wyjdź',
    'Restore purchase': 'Przywróć zakup',
    'Resume': 'Wznów',
    'Retry': 'Spróbuj ponownie',
    'Review settings': 'Ustawienia przeglądu',
    'Select': 'Wybierz',
    'Select page': 'Wybierz stronę',
    'Set LEFT': 'Ustaw LEWY',
    'Set RIGHT': 'Ustaw PRAWY',
    'Show all guides next time': 'Następnym razem pokaż wszystkie przewodniki',
    'Show human likelihood next to the engine verdict.':
        'Pokaż prawdopodobieństwo ludzkiego wyboru obok oceny silnika.',
    'Shutdown mode': 'Tryb wyłączenia',
    'Shutdown mode sent.': 'Wysłano tryb wyłączenia.',
    'Sign in before starting Career Mode.':
        'Zaloguj się przed rozpoczęciem trybu kariery.',
    'Sign in did not finish. Please try again.':
        'Logowanie nie zostało ukończone. Spróbuj ponownie.',
    'Sign in to sync points and profile.':
        'Zaloguj się, aby synchronizować punkty i profil.',
    'Since': 'Od',
    'Skip': 'Pomiń',
    'Start': 'Rozpocznij',
    'Start import': 'Rozpocznij import',
    'Start pairing': 'Rozpocznij parowanie',
    'Submitting selected games for personal engine training...':
        'Wysyłanie wybranych partii do treningu osobistego silnika...',
    'Switch account': 'Zmień konto',
    'Tactical depth': 'Głębokość taktyczna',
    'Tap a move to jump back to the board.':
        'Dotknij ruchu, aby przejść do tej pozycji na szachownicy.',
    'Tap to view details': 'Dotknij, aby zobaczyć szczegóły',
    'Target Elo': 'Docelowe Elo',
    'The PGN is still loading. Try again shortly.':
        'PGN nadal się wczytuje. Spróbuj ponownie za chwilę.',
    'The new set has been paired and saved to this channel.':
        'Nowy zestaw sparowano i zapisano w tym kanale.',
    'The selected PGN file is empty.': 'Wybrany plik PGN jest pusty.',
    'Theme not available yet': 'Motyw jeszcze niedostępny',
    'This LC0 engine is not ready to download yet.':
        'Ten silnik LC0 nie jest jeszcze gotowy do pobrania.',
    'This PGN could not be read. Check the PGN file and try again.':
        'Nie udało się odczytać PGN. Sprawdź plik i spróbuj ponownie.',
    'This PGN could not be read. Check the move list and try again.':
        'Nie udało się odczytać PGN. Sprawdź listę ruchów i spróbuj ponownie.',
    'This PGN includes a move Chessnut cannot read. Check the move list and try again.':
        'Ten PGN zawiera ruch, którego Chessnut nie potrafi odczytać. Sprawdź listę ruchów i spróbuj ponownie.',
    'This engine cannot be liked yet.':
        'Tego silnika nie można jeszcze polubić.',
    'This game ended before any playable moves, so there is no position to analyze.':
        'Partia zakończyła się przed wykonaniem odtwarzalnych ruchów, więc nie ma pozycji do analizy.',
    'This personal engine cannot be renamed yet.':
        'Nie można jeszcze zmienić nazwy tego osobistego silnika.',
    'This personal engine does not have a weight file yet.':
        'Ten osobisty silnik nie ma jeszcze pliku wag.',
    'This personal engine is still training.':
        'Ten osobisty silnik nadal się trenuje.',
    'This update will be handled by Google Play on this device.':
        'Na tym urządzeniu aktualizację przeprowadzi Google Play.',
    'This update will open in your browser.':
        'Aktualizacja zostanie otwarta w przeglądarce.',
    'This update will open the Chessnut page on Google Play.':
        'Zostanie otwarta strona Chessnut w Google Play.',
    'This update will open the official Chessnut download page.':
        'Zostanie otwarta oficjalna strona pobierania Chessnut.',
    'This update will open the official app store or test track for your device.':
        'Zostanie otwarty oficjalny sklep lub kanał testowy dla urządzenia.',
    'This version is required to keep Chessnut working correctly. Please update before continuing.':
        'Ta wersja jest wymagana do prawidłowego działania Chessnut. Zaktualizuj przed kontynuowaniem.',
    'Time': 'Czas',
    'Training modes': 'Tryby treningowe',
    'Turn on': 'Włącz',
    'Turn on shutdown mode?': 'Włączyć tryb wyłączenia?',
    'USB Clock Test': 'Test zegara USB',
    'Unable to check Lichess authorization. Please try again.':
        'Nie udało się sprawdzić autoryzacji Lichess. Spróbuj ponownie.',
    'Unable to delete this personal engine. Try again later.':
        'Nie udało się usunąć osobistego silnika. Spróbuj ponownie później.',
    'Unable to download Grandeur report.':
        'Nie udało się pobrać raportu Grandeur.',
    'Unable to download this LC0 engine. Check your connection and try again.':
        'Nie udało się pobrać silnika LC0. Sprawdź połączenie i spróbuj ponownie.',
    'Unable to download this personal engine. Check your connection and try again.':
        'Nie udało się pobrać osobistego silnika. Sprawdź połączenie i spróbuj ponownie.',
    'Unable to end this game record.':
        'Nie udało się zakończyć tego zapisu partii.',
    'Unable to load the matched Game Record preview.':
        'Nie udało się wczytać podglądu pasujących zapisów partii.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Nie udało się otworzyć pliku PGN. Wybierz inny i spróbuj ponownie.',
    'Unable to pair pieces': 'Nie udało się sparować figur',
    'Unable to refresh this PGN.': 'Nie udało się odświeżyć PGN.',
    'Unable to send command.': 'Nie udało się wysłać polecenia.',
    'Unable to share report image.': 'Nie udało się udostępnić obrazu raportu.',
    'Unable to start personal engine training.':
        'Nie udało się rozpocząć treningu osobistego silnika.',
    'Unable to switch to this account.':
        'Nie udało się przełączyć na to konto.',
    'Unable to update like. Try again later.':
        'Nie udało się zaktualizować polubienia. Spróbuj ponownie później.',
    'Unable to update this engine name. Try again later.':
        'Nie udało się zaktualizować nazwy silnika. Spróbuj ponownie później.',
    'Unable to update this engine. Try again later.':
        'Nie udało się zaktualizować silnika. Spróbuj ponownie później.',
    'Unable to update this personal engine. Check your connection and try again.':
        'Nie udało się zaktualizować osobistego silnika. Sprawdź połączenie i spróbuj ponownie.',
    'Unlink Lichess': 'Odłącz Lichess',
    'Until': 'Do',
    'Update available': 'Dostępna aktualizacja',
    'Update link is not available right now. Please try again later.':
        'Łącze aktualizacji jest teraz niedostępne. Spróbuj ponownie później.',
    'Update now': 'Aktualizuj teraz',
    'Update required': 'Wymagana aktualizacja',
    'Update with Google Play': 'Aktualizuj przez Google Play',
    'Use another saved Chessnut ID': 'Użyj innego zapisanego Chessnut ID',
    'Use selected': 'Użyj wybranych',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Użyj do długotrwałego przechowywania. Przed ponownym użyciem figury trzeba położyć na szachownicy ładującej.',
    'Use this model': 'Użyj tego modelu',
    'Use this position': 'Użyj tej pozycji',
    'VIP member': 'Członek VIP',
    'Valid until': 'Ważne do',
    'Verification code cannot be empty.':
        'Kod weryfikacyjny nie może być pusty.',
    'Verification code required': 'Wymagany kod weryfikacyjny',
    'Verification could not open in the app':
        'Nie udało się otworzyć weryfikacji w aplikacji',
    'View first-time tips again': 'Ponownie pokaż wskazówki początkowe',
    'Voice moves': 'Ruchy głosowe',
    'Waiting for piece status': 'Oczekiwanie na stan figur',
    'Wallet test tools are unavailable.':
        'Narzędzia testowe portfela są niedostępne.',
    'White games': 'Partie białymi',
    'You are using the latest version.': 'Używasz najnowszej wersji.',
    'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.':
        'Twoje konto Chessnut jest już połączone z Lichess. Możesz zachować połączenie lub je odłączyć, aby autoryzować inne konto Lichess.',
    'no legal mainline moves': 'brak legalnych ruchów w głównej linii',
    'points': 'punkty',
    'pts': 'pkt',
    'sec': 's',
  },
  'ro': {
    '6-digit code': 'Cod din 6 cifre',
    'A newer version is available. Update now to get the latest fixes and improvements.':
        'Este disponibilă o versiune mai nouă. Actualizați acum pentru cele mai recente remedieri și îmbunătățiri.',
    'Add an engine name before starting training.':
        'Adăugați un nume motorului înainte de a începe antrenamentul.',
    'All daily tasks completed.': 'Toate sarcinile zilnice sunt finalizate.',
    'Analysis marker LED patterns': 'Modele LED pentru marcajele de analiză',
    'Auto-detect set': 'Detectare automată a setului',
    'Automatic switch press': 'Apăsare automată a comutatorului',
    'Back to channels': 'Înapoi la canale',
    'Black games': 'Partide cu negrele',
    'Bluetooth': 'Bluetooth',
    'Board Settings lets you choose Direct control or Web control for physical board moves.':
        'Setările tablei vă permit să alegeți controlul direct sau controlul web pentru mutările pe tabla fizică.',
    'Board connection failed.': 'Conectarea tablei a eșuat.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'Tabla s-a deconectat și reconectarea a eșuat; partida va rămâne deschisă.',
    'Bot game engine library':
        'Bibliotecă de motoare pentru jocul cu computerul',
    'Camera': 'Cameră',
    'Candidate moves are human probabilities, not best-move scores.':
        'Mutările candidate indică probabilități umane, nu evaluări ale celei mai bune mutări.',
    'Cantonese': 'Cantoneză',
    'Casual only': 'Doar amicale',
    'Check for updates': 'Caută actualizări',
    'Check placement, battery, and nearby interference, then try again.':
        'Verificați așezarea, bateria și interferențele din apropiere, apoi încercați din nou.',
    'Check whether a newer Chessnut version is available.':
        'Verificați dacă este disponibilă o versiune Chessnut mai nouă.',
    'Checked in today / Grandeur 100 / personal engine training 500':
        'Recompensă zilnică revendicată / Grandeur 100 / antrenare motor personal 500',
    'Checking': 'Se verifică',
    'Checkpoints': 'Puncte de verificare',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Chessnut Vision is now active.': 'Chessnut Vision este acum activ.',
    'Choose a target': 'Alegeți o țintă',
    'Choose image': 'Alegeți imaginea',
    'Claimed': 'Revendicat',
    'Clear page': 'Golește pagina',
    'Close authorization': 'Închide autorizarea',
    'Cloud Maia 3': 'Maia 3 în cloud',
    'Compare with Stockfish': 'Compară cu Stockfish',
    'Confirm': 'Confirmă',
    'Confirm draw': 'Confirmă remiza',
    'Confirm resign': 'Confirmă abandonul',
    'Confirm takeback': 'Confirmă retragerea mutării',
    'Connected as': 'Conectat ca',
    'Connection Status': 'Starea conexiunii',
    'Continue learning': 'Continuă învățarea',
    'Control the board LED hints used while setting up and playing.':
        'Controlați indicațiile LED ale tablei folosite la așezare și în timpul jocului.',
    'Copy failed. Please try again.': 'Copierea a eșuat. Încercați din nou.',
    'Could not check for updates. Please try again later.':
        'Actualizările nu au putut fi verificate. Încercați din nou mai târziu.',
    'Could not open the source link. Please try again later.':
        'Linkul către codul sursă nu a putut fi deschis. Încercați mai târziu.',
    'Could not open the update link. Please try again later.':
        'Linkul de actualizare nu a putut fi deschis. Încercați mai târziu.',
    'Curated LC0 engines': 'Motoare LC0 selectate',
    'Daily check-in available / Grandeur 100 / personal engine training 500':
        'Recompensă zilnică disponibilă / Grandeur 100 / antrenare motor personal 500',
    'Date': 'Data',
    'Delete record': 'Șterge înregistrarea',
    "Don't remind me again for this update":
        'Nu-mi mai aminti despre această actualizare',
    'Download update': 'Descarcă actualizarea',
    'Enable Vision': 'Activează Vision',
    'End game': 'Încheie partida',
    'Engine comparison': 'Compararea motoarelor',
    'Engine disabled.': 'Motor dezactivat.',
    'Engine enabled for Bot game.': 'Motor activat pentru jocul cu computerul.',
    'Engine name updated.': 'Numele motorului a fost actualizat.',
    'Enter an engine name before saving.':
        'Introduceți un nume pentru motor înainte de salvare.',
    'Event Log': 'Jurnal de evenimente',
    'FEN position': 'Poziție FEN',
    'Fetching the latest Chessnut lesson library.':
        'Se descarcă cea mai recentă bibliotecă de lecții Chessnut.',
    'Fill': 'Umple',
    'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.':
        'Filtrați aici partidele salvate, previzualizați PGN-urile utilizabile și începeți antrenamentul fără a părăsi Engine Lab.',
    'Finish this game before generating an analysis report.':
        'Încheiați partida înainte de a genera raportul de analiză.',
    'From Chess.com username': 'De la utilizatorul Chess.com',
    'From Lichess player': 'De la jucătorul Lichess',
    'From PGN': 'Din PGN',
    'G': 'P',
    'Game marked as ended.': 'Partida a fost marcată ca încheiată.',
    'Game record deleted.': 'Înregistrarea partidei a fost ștearsă.',
    'Go': 'Continuă',
    'Go to login': 'Mergi la autentificare',
    'Google Play update is not available right now. Opening the store page instead.':
        'Actualizarea prin Google Play nu este disponibilă acum. Se deschide pagina magazinului.',
    'Grandeur HTML report downloaded.':
        'Raportul HTML Grandeur a fost descărcat.',
    'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.':
        'Grandeur costă în mod normal 100 de puncte. Membrii plătesc automat 0 puncte. Dacă nu aveți suficiente puncte, puteți câștiga din Sarcinile zilnice.',
    'Help': 'Ajutor',
    'Import Chess.com games': 'Importă partide Chess.com',
    'Import Lichess games': 'Importă partide Lichess',
    'Import PGN files before starting training.':
        'Importați fișiere PGN înainte de a începe antrenamentul.',
    'Import at least 1 game.': 'Importați cel puțin o partidă.',
    'Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.':
        'Importați partidele încheiate ale unui jucător Lichess în Înregistrări. Dublurile sunt omise automat.',
    'Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.':
        'Importați partidele publice încheiate ale unui utilizator Chess.com în Înregistrări. Partidele foarte recente pot apărea cu întârziere în arhive.',
    'Include app logs and device details':
        'Include jurnalele aplicației și detaliile dispozitivului',
    'Includes app version, device type, current screen, board status, and recent logs.':
        'Include versiunea aplicației, tipul dispozitivului, ecranul curent, starea tablei și jurnalele recente.',
    'Interactive': 'Interactiv',
    'Keep first 200': 'Păstrează primele 200',
    'Keep linked': 'Păstrează legătura',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Țineți celelalte seturi Move la distanță în timpul asocierii. Procesul durează de obicei 3–5 minute.',
    'Key moments': 'Momente-cheie',
    'Last Button Pressed': 'Ultimul buton apăsat',
    'Later': 'Mai târziu',
    'Latest version': 'Cea mai recentă versiune',
    'Learn with your board': 'Învață cu tabla ta',
    'Leave for now': 'Ieși pentru moment',
    'Licenses and Maia 3 source code': 'Licențe și codul sursă Maia 3',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess account unlinked.': 'Contul Lichess a fost deconectat.',
    'Lichess authorization complete.': 'Autorizarea Lichess este finalizată.',
    'Lichess authorization could not open.':
        'Autorizarea Lichess nu a putut fi deschisă.',
    'Lichess authorization could not open. Try again later.':
        'Autorizarea Lichess nu a putut fi deschisă. Încercați mai târziu.',
    'Lichess authorization expired. Re-authorize before continuing.':
        'Autorizarea Lichess a expirat. Autorizați din nou înainte de a continua.',
    'Lichess authorization is not available right now. Please try again later.':
        'Autorizarea Lichess nu este disponibilă acum. Încercați mai târziu.',
    'Lichess authorization was not completed. Try again when the Lichess page finishes.':
        'Autorizarea Lichess nu a fost finalizată. Încercați din nou după finalizarea paginii Lichess.',
    'Lichess authorized.': 'Lichess autorizat.',
    'Lichess did not respond in time. Try again.':
        'Lichess nu a răspuns la timp. Încercați din nou.',
    'Lichess sign-in status could not be checked. Please try again later.':
        'Starea autentificării Lichess nu a putut fi verificată. Încercați mai târziu.',
    'Linked account update failed. Please try again.':
        'Actualizarea contului asociat a eșuat. Încercați din nou.',
    'Linked accounts': 'Conturi asociate',
    'Loading courses': 'Se încarcă cursurile',
    'Loading subtitles and board checkpoints.':
        'Se încarcă subtitrările și punctele de verificare ale tablei.',
    'Local QA wallet tools': 'Instrumente locale de testare a portofelului',
    'Local list': 'Listă locală',
    'Location': 'Locație',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia 3 predicts likely human moves from 600 to 2600 Elo. Sign in and stay online to use it.':
        'Maia 3 prezice mutările umane probabile între 600 și 2600 Elo. Autentificați-vă și rămâneți online pentru a o folosi.',
    'Maia3 explains human likelihood. Stockfish checks objective quality.':
        'Maia3 explică probabilitatea alegerii umane. Stockfish verifică valoarea obiectivă.',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 estimează alegerile umane probabile pentru fiecare mutare.',
    'Mandarin': 'Mandarină',
    'Max games': 'Număr maxim de partide',
    'Member discount': 'Reducere pentru membri',
    'Message status could not be updated. Please try again.':
        'Starea mesajului nu a putut fi actualizată. Încercați din nou.',
    'More filters': 'Mai multe filtre',
    'Move board did not accept the command.':
        'Tabla Move nu a acceptat comanda.',
    'Move board did not accept the reset command.':
        'Tabla Move nu a acceptat comanda de resetare.',
    'Move board reset to the standard starting position.':
        'Tabla Move a fost resetată la poziția inițială standard.',
    'Move control can be changed': 'Controlul mutărilor poate fi schimbat',
    'Move likelihood': 'Probabilitatea mutării',
    'Moves by rating': 'Mutări după rating',
    'My personal engine': 'Motorul meu personal',
    'Network issue': 'Problemă de rețea',
    'New personal engine': 'Motor personal nou',
    'No PGN available for this record.':
        'Nu există PGN pentru această înregistrare.',
    'No active themes': 'Nicio temă activă',
    'No finished game with playable moves is available yet.':
        'Nu există încă o partidă încheiată cu mutări redate.',
    'No games loaded for this page.':
        'Nu s-au încărcat partide pentru această pagină.',
    'No moves yet': 'Nicio mutare încă',
    'No personal engines yet': 'Niciun motor personal încă',
    'No review mistakes yet': 'Nicio greșeală de revizuit încă',
    'No usable PGN games matched this Lichess player and filters.':
        'Nicio partidă PGN utilizabilă nu corespunde acestui jucător Lichess și filtrelor.',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Maia oficială poate compara mutări între niveluri de rating. Această vizualizare mobilă păstrează compact modelul selectat.',
    'Open': 'Deschide',
    'Open Google Play': 'Deschide Google Play',
    'Open source code': 'Deschide codul sursă',
    'Open store': 'Deschide magazinul',
    'Open-source notices': 'Notificări open-source',
    'Opponent move mode': 'Modul mutării adversarului',
    'Optional date or text': 'Dată sau text opțional',
    'Original cost': 'Cost inițial',
    'PGN refreshed.': 'PGN actualizat.',
    'Password cannot be empty.': 'Parola nu poate fi goală.',
    'Password reset successfully.': 'Parola a fost resetată.',
    'Pay today': 'Plătește astăzi',
    'Personal engine deleted.': 'Motorul personal a fost șters.',
    'Pieces are ready': 'Piesele sunt pregătite',
    'Place all 34 pieces exactly as shown before pairing.':
        'Așezați toate cele 34 de piese exact ca în imagine înainte de asociere.',
    'Play style': 'Stil de joc',
    'Playable engine library': 'Bibliotecă de motoare jucabile',
    'Player ID': 'ID jucător',
    'Please agree to the Terms of Use and Privacy Policy.':
        'Acceptați Termenii de utilizare și Politica de confidențialitate.',
    'Premium active / Grandeur and personal engine training unlimited':
        'Premium activ / Grandeur și antrenare nelimitată a motorului personal',
    'Premium is active.': 'Premium este activ.',
    'Preparing insight': 'Se pregătește analiza',
    'Preparing lesson': 'Se pregătește lecția',
    'Press clock switch': 'Apasă comutatorul ceasului',
    'Preview Lichess games before starting training.':
        'Previzualizați partidele Lichess înainte de a începe antrenamentul.',
    'Profile update failed. Check your connection and try again.':
        'Actualizarea profilului a eșuat. Verificați conexiunea și încercați din nou.',
    'Progress synced. Keep the streak moving.':
        'Progres sincronizat. Continuați seria.',
    'Purchase was not completed. You can try again when ready.':
        'Achiziția nu a fost finalizată. Puteți încerca din nou când doriți.',
    'Rated and casual': 'Cu rating și amicale',
    'Rated only': 'Doar cu rating',
    'Remind me in 1 day': 'Amintește-mi peste o zi',
    'Remove': 'Elimină',
    'Remove piece set?': 'Eliminați setul de piese?',
    'Removed pieces need to be paired again before they can be used.':
        'Piesele eliminate trebuie asociate din nou înainte de utilizare.',
    'Replay': 'Redă',
    'Replay guides': 'Afișează din nou ghidurile',
    'Report': 'Raport',
    'Report image ready to share.':
        'Imaginea raportului este gata de distribuit.',
    'Reset both clocks and start over.':
        'Resetați ambele ceasuri și începeți din nou.',
    'Reset clock?': 'Resetați ceasul?',
    'Resign and exit': 'Abandonează și ieși',
    'Restore purchase': 'Restaurează achiziția',
    'Resume': 'Continuă',
    'Retry': 'Încearcă din nou',
    'Review settings': 'Setări de revizuire',
    'Select': 'Selectează',
    'Select page': 'Selectează pagina',
    'Set LEFT': 'Setează STÂNGA',
    'Set RIGHT': 'Setează DREAPTA',
    'Show all guides next time': 'Arată toate ghidurile data viitoare',
    'Show human likelihood next to the engine verdict.':
        'Afișează probabilitatea umană lângă verdictul motorului.',
    'Shutdown mode': 'Mod de oprire',
    'Shutdown mode sent.': 'Comanda modului de oprire a fost trimisă.',
    'Sign in before starting Career Mode.':
        'Autentificați-vă înainte de a începe Modul carieră.',
    'Sign in did not finish. Please try again.':
        'Autentificarea nu s-a finalizat. Încercați din nou.',
    'Sign in to sync points and profile.':
        'Autentificați-vă pentru a sincroniza punctele și profilul.',
    'Since': 'Din',
    'Skip': 'Omite',
    'Start': 'Începe',
    'Start import': 'Începe importul',
    'Start pairing': 'Începe asocierea',
    'Submitting selected games for personal engine training...':
        'Se trimit partidele selectate pentru antrenarea motorului personal...',
    'Switch account': 'Schimbă contul',
    'Tactical depth': 'Profunzime tactică',
    'Tap a move to jump back to the board.':
        'Atingeți o mutare pentru a reveni la poziția respectivă.',
    'Tap to view details': 'Atingeți pentru detalii',
    'Target Elo': 'Elo țintă',
    'The PGN is still loading. Try again shortly.':
        'PGN-ul încă se încarcă. Încercați din nou în curând.',
    'The new set has been paired and saved to this channel.':
        'Noul set a fost asociat și salvat pe acest canal.',
    'The selected PGN file is empty.': 'Fișierul PGN selectat este gol.',
    'Theme not available yet': 'Tema nu este disponibilă încă',
    'This LC0 engine is not ready to download yet.':
        'Acest motor LC0 nu este încă gata pentru descărcare.',
    'This PGN could not be read. Check the PGN file and try again.':
        'Acest PGN nu a putut fi citit. Verificați fișierul și încercați din nou.',
    'This PGN could not be read. Check the move list and try again.':
        'Acest PGN nu a putut fi citit. Verificați lista mutărilor și încercați din nou.',
    'This PGN includes a move Chessnut cannot read. Check the move list and try again.':
        'Acest PGN conține o mutare pe care Chessnut nu o poate citi. Verificați lista și încercați din nou.',
    'This engine cannot be liked yet.':
        'Acest motor nu poate fi apreciat încă.',
    'This game ended before any playable moves, so there is no position to analyze.':
        'Partida s-a încheiat înainte de mutări redate, deci nu există o poziție de analizat.',
    'This personal engine cannot be renamed yet.':
        'Acest motor personal nu poate fi redenumit încă.',
    'This personal engine does not have a weight file yet.':
        'Acest motor personal nu are încă un fișier de ponderi.',
    'This personal engine is still training.':
        'Acest motor personal este încă în curs de antrenare.',
    'This update will be handled by Google Play on this device.':
        'Actualizarea va fi gestionată de Google Play pe acest dispozitiv.',
    'This update will open in your browser.':
        'Actualizarea se va deschide în browser.',
    'This update will open the Chessnut page on Google Play.':
        'Se va deschide pagina Chessnut din Google Play.',
    'This update will open the official Chessnut download page.':
        'Se va deschide pagina oficială de descărcare Chessnut.',
    'This update will open the official app store or test track for your device.':
        'Se va deschide magazinul oficial sau canalul de testare al dispozitivului.',
    'This version is required to keep Chessnut working correctly. Please update before continuing.':
        'Această versiune este necesară pentru funcționarea corectă a Chessnut. Actualizați înainte de a continua.',
    'Time': 'Timp',
    'Training modes': 'Moduri de antrenament',
    'Turn on': 'Pornește',
    'Turn on shutdown mode?': 'Porniți modul de oprire?',
    'USB Clock Test': 'Test ceas USB',
    'Unable to check Lichess authorization. Please try again.':
        'Autorizarea Lichess nu a putut fi verificată. Încercați din nou.',
    'Unable to delete this personal engine. Try again later.':
        'Motorul personal nu a putut fi șters. Încercați mai târziu.',
    'Unable to download Grandeur report.':
        'Raportul Grandeur nu a putut fi descărcat.',
    'Unable to download this LC0 engine. Check your connection and try again.':
        'Motorul LC0 nu a putut fi descărcat. Verificați conexiunea și încercați din nou.',
    'Unable to download this personal engine. Check your connection and try again.':
        'Motorul personal nu a putut fi descărcat. Verificați conexiunea și încercați din nou.',
    'Unable to end this game record.':
        'Înregistrarea partidei nu a putut fi încheiată.',
    'Unable to load the matched Game Record preview.':
        'Previzualizarea înregistrărilor potrivite nu a putut fi încărcată.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Fișierul PGN nu a putut fi deschis. Alegeți altul și încercați din nou.',
    'Unable to pair pieces': 'Piesele nu au putut fi asociate',
    'Unable to refresh this PGN.': 'PGN-ul nu a putut fi actualizat.',
    'Unable to send command.': 'Comanda nu a putut fi trimisă.',
    'Unable to share report image.':
        'Imaginea raportului nu a putut fi distribuită.',
    'Unable to start personal engine training.':
        'Antrenarea motorului personal nu a putut fi pornită.',
    'Unable to switch to this account.': 'Nu s-a putut trece la acest cont.',
    'Unable to update like. Try again later.':
        'Aprecierea nu a putut fi actualizată. Încercați mai târziu.',
    'Unable to update this engine name. Try again later.':
        'Numele motorului nu a putut fi actualizat. Încercați mai târziu.',
    'Unable to update this engine. Try again later.':
        'Motorul nu a putut fi actualizat. Încercați mai târziu.',
    'Unable to update this personal engine. Check your connection and try again.':
        'Motorul personal nu a putut fi actualizat. Verificați conexiunea și încercați din nou.',
    'Unlink Lichess': 'Deconectează Lichess',
    'Until': 'Până la',
    'Update available': 'Actualizare disponibilă',
    'Update link is not available right now. Please try again later.':
        'Linkul de actualizare nu este disponibil acum. Încercați mai târziu.',
    'Update now': 'Actualizează acum',
    'Update required': 'Actualizare necesară',
    'Update with Google Play': 'Actualizează prin Google Play',
    'Use another saved Chessnut ID': 'Folosește alt Chessnut ID salvat',
    'Use selected': 'Folosește selecția',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Folosiți acest mod pentru depozitare îndelungată. Piesele trebuie puse pe tabla de încărcare înainte de reutilizare.',
    'Use this model': 'Folosește acest model',
    'Use this position': 'Folosește această poziție',
    'VIP member': 'Membru VIP',
    'Valid until': 'Valabil până la',
    'Verification code cannot be empty.':
        'Codul de verificare nu poate fi gol.',
    'Verification code required': 'Cod de verificare necesar',
    'Verification could not open in the app':
        'Verificarea nu a putut fi deschisă în aplicație',
    'View first-time tips again': 'Afișează din nou sfaturile inițiale',
    'Voice moves': 'Mutări vocale',
    'Waiting for piece status': 'Se așteaptă starea pieselor',
    'Wallet test tools are unavailable.':
        'Instrumentele de testare a portofelului nu sunt disponibile.',
    'White games': 'Partide cu albele',
    'You are using the latest version.': 'Folosiți cea mai recentă versiune.',
    'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.':
        'Contul Chessnut este deja conectat la Lichess. Puteți păstra legătura sau o puteți elimina pentru a autoriza alt cont Lichess.',
    'no legal mainline moves': 'nicio mutare legală în varianta principală',
    'points': 'puncte',
    'pts': 'pct.',
    'sec': 's',
  },
  'cs': {
    '6-digit code': 'Šestimístný kód',
    'A newer version is available. Update now to get the latest fixes and improvements.':
        'Je dostupná novější verze. Aktualizujte nyní a získejte nejnovější opravy a vylepšení.',
    'Add an engine name before starting training.':
        'Před zahájením tréninku zadejte název enginu.',
    'All daily tasks completed.': 'Všechny denní úkoly jsou splněny.',
    'Analysis marker LED patterns': 'Vzory LED značek analýzy',
    'Auto-detect set': 'Automaticky rozpoznat sadu',
    'Automatic switch press': 'Automatické stisknutí přepínače',
    'Back to channels': 'Zpět ke kanálům',
    'Black games': 'Partie černými',
    'Bluetooth': 'Bluetooth',
    'Board Settings lets you choose Direct control or Web control for physical board moves.':
        'Nastavení šachovnice umožňuje pro tahy na fyzické šachovnici zvolit přímé nebo webové ovládání.',
    'Board connection failed.': 'Připojení šachovnice se nezdařilo.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'Šachovnice se odpojila a opětovné připojení se nezdařilo; partie zůstane otevřená.',
    'Bot game engine library': 'Knihovna enginů pro hru s počítačem',
    'Camera': 'Fotoaparát',
    'Candidate moves are human probabilities, not best-move scores.':
        'Kandidátní tahy ukazují pravděpodobnost lidské volby, nikoli hodnocení nejlepšího tahu.',
    'Cantonese': 'Kantonština',
    'Casual only': 'Pouze nehodnocené',
    'Check for updates': 'Vyhledat aktualizace',
    'Check placement, battery, and nearby interference, then try again.':
        'Zkontrolujte rozmístění, baterii a okolní rušení a zkuste to znovu.',
    'Check whether a newer Chessnut version is available.':
        'Zkontrolujte, zda je dostupná novější verze Chessnut.',
    'Checked in today / Grandeur 100 / personal engine training 500':
        'Dnešní odměna vyzvednuta / Grandeur 100 / trénink osobního enginu 500',
    'Checking': 'Kontrola',
    'Checkpoints': 'Kontrolní body',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Chessnut Vision is now active.': 'Chessnut Vision je nyní aktivní.',
    'Choose a target': 'Vyberte cíl',
    'Choose image': 'Vybrat obrázek',
    'Claimed': 'Vyzvednuto',
    'Clear page': 'Vymazat stránku',
    'Close authorization': 'Zavřít autorizaci',
    'Cloud Maia 3': 'Cloudová Maia 3',
    'Engine': 'Šachový engine',
    'Compare with Stockfish': 'Porovnat se Stockfish',
    'Confirm': 'Potvrdit',
    'Confirm draw': 'Potvrdit remízu',
    'Confirm resign': 'Potvrdit vzdání',
    'Confirm takeback': 'Potvrdit vrácení tahu',
    'Connected as': 'Připojeno jako',
    'Connection Status': 'Stav připojení',
    'Continue learning': 'Pokračovat v učení',
    'Control the board LED hints used while setting up and playing.':
        'Nastavte LED nápovědu šachovnice používanou při rozestavení a hře.',
    'Copy failed. Please try again.':
        'Kopírování se nezdařilo. Zkuste to znovu.',
    'Could not check for updates. Please try again later.':
        'Aktualizace se nepodařilo ověřit. Zkuste to později.',
    'Could not open the source link. Please try again later.':
        'Odkaz na zdrojový kód se nepodařilo otevřít. Zkuste to později.',
    'Could not open the update link. Please try again later.':
        'Odkaz na aktualizaci se nepodařilo otevřít. Zkuste to později.',
    'Curated LC0 engines': 'Vybrané enginy LC0',
    'Daily check-in available / Grandeur 100 / personal engine training 500':
        'Denní odměna dostupná / Grandeur 100 / trénink osobního enginu 500',
    'Date': 'Datum',
    'Delete record': 'Smazat záznam',
    "Don't remind me again for this update":
        'Tuto aktualizaci již nepřipomínat',
    'Download update': 'Stáhnout aktualizaci',
    'Enable Vision': 'Zapnout Vision',
    'End game': 'Ukončit partii',
    'Engine comparison': 'Porovnání enginů',
    'Engine disabled.': 'Engine vypnut.',
    'Engine enabled for Bot game.': 'Engine zapnut pro hru s počítačem.',
    'Engine name updated.': 'Název enginu byl aktualizován.',
    'Enter an engine name before saving.':
        'Před uložením zadejte název enginu.',
    'Event Log': 'Protokol událostí',
    'FEN position': 'Pozice FEN',
    'Fetching the latest Chessnut lesson library.':
        'Načítá se nejnovější knihovna lekcí Chessnut.',
    'Fill': 'Vyplnit',
    'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.':
        'Zde filtrujte uložené partie, prohlédněte použitelné PGN a spusťte trénink bez opuštění Engine Lab.',
    'Finish this game before generating an analysis report.':
        'Před vytvořením analytické zprávy tuto partii dokončete.',
    'From Chess.com username': 'Z účtu Chess.com',
    'From Lichess player': 'Od hráče Lichess',
    'From PGN': 'Z PGN',
    'G': 'P',
    'Game marked as ended.': 'Partie byla označena jako ukončená.',
    'Game record deleted.': 'Záznam partie byl smazán.',
    'Go': 'Přejít',
    'Go to login': 'Přejít k přihlášení',
    'Google Play update is not available right now. Opening the store page instead.':
        'Aktualizace přes Google Play nyní není dostupná. Otevírá se stránka obchodu.',
    'Grandeur HTML report downloaded.': 'HTML zpráva Grandeur byla stažena.',
    'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.':
        'Grandeur běžně stojí 100 bodů. Členové automaticky platí 0 bodů. Další body lze získat v denních úkolech.',
    'Help': 'Nápověda',
    'Import Chess.com games': 'Importovat partie Chess.com',
    'Import Lichess games': 'Importovat partie Lichess',
    'Import PGN files before starting training.':
        'Před zahájením tréninku importujte soubory PGN.',
    'Import at least 1 game.': 'Importujte alespoň jednu partii.',
    'Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.':
        'Importujte dokončené partie hráče Lichess do záznamů. Duplicitní partie budou automaticky přeskočeny.',
    'Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.':
        'Importujte veřejné dokončené partie uživatele Chess.com do záznamů. Velmi nové partie se mohou v archivu objevit se zpožděním.',
    'Include app logs and device details':
        'Zahrnout protokoly aplikace a údaje zařízení',
    'Includes app version, device type, current screen, board status, and recent logs.':
        'Obsahuje verzi aplikace, typ zařízení, aktuální obrazovku, stav šachovnice a poslední protokoly.',
    'Interactive': 'Interaktivní',
    'Keep first 200': 'Ponechat prvních 200',
    'Keep linked': 'Ponechat propojení',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'Během párování odsuňte ostatní sady Move. Proces obvykle trvá 3–5 minut.',
    'Key moments': 'Klíčové okamžiky',
    'Last Button Pressed': 'Naposledy stisknuté tlačítko',
    'Later': 'Později',
    'Latest version': 'Nejnovější verze',
    'Learn with your board': 'Učte se se svou šachovnicí',
    'Leave for now': 'Prozatím odejít',
    'Licenses and Maia 3 source code': 'Licence a zdrojový kód Maia 3',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess account unlinked.': 'Účet Lichess byl odpojen.',
    'Lichess authorization complete.': 'Autorizace Lichess je dokončena.',
    'Lichess authorization could not open.':
        'Autorizaci Lichess se nepodařilo otevřít.',
    'Lichess authorization could not open. Try again later.':
        'Autorizaci Lichess se nepodařilo otevřít. Zkuste to později.',
    'Lichess authorization expired. Re-authorize before continuing.':
        'Autorizace Lichess vypršela. Před pokračováním ji obnovte.',
    'Lichess authorization is not available right now. Please try again later.':
        'Autorizace Lichess nyní není dostupná. Zkuste to později.',
    'Lichess authorization was not completed. Try again when the Lichess page finishes.':
        'Autorizace Lichess nebyla dokončena. Zkuste to znovu po dokončení stránky Lichess.',
    'Lichess authorized.': 'Lichess autorizován.',
    'Lichess did not respond in time. Try again.':
        'Lichess neodpověděl včas. Zkuste to znovu.',
    'Lichess sign-in status could not be checked. Please try again later.':
        'Stav přihlášení k Lichess se nepodařilo ověřit. Zkuste to později.',
    'Linked account update failed. Please try again.':
        'Aktualizace propojeného účtu se nezdařila. Zkuste to znovu.',
    'Linked accounts': 'Propojené účty',
    'Loading courses': 'Načítání kurzů',
    'Loading subtitles and board checkpoints.':
        'Načítání titulků a kontrolních bodů šachovnice.',
    'Local QA wallet tools': 'Místní testovací nástroje peněženky',
    'Local list': 'Místní seznam',
    'Location': 'Místo',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia 3 predicts likely human moves from 600 to 2600 Elo. Sign in and stay online to use it.':
        'Maia 3 předpovídá pravděpodobné lidské tahy od 600 do 2600 Elo. Pro použití se přihlaste a zůstaňte online.',
    'Maia3 explains human likelihood. Stockfish checks objective quality.':
        'Maia3 vysvětluje pravděpodobnost lidské volby. Stockfish ověřuje objektivní kvalitu.',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 odhaduje pravděpodobné lidské volby pro každý tah.',
    'Mandarin': 'Mandarínština',
    'Max games': 'Maximum partií',
    'Member discount': 'Členská sleva',
    'Message status could not be updated. Please try again.':
        'Stav zprávy se nepodařilo aktualizovat. Zkuste to znovu.',
    'More filters': 'Další filtry',
    'Move board did not accept the command.':
        'Šachovnice Move příkaz nepřijala.',
    'Move board did not accept the reset command.':
        'Šachovnice Move nepřijala příkaz k resetování.',
    'Move board reset to the standard starting position.':
        'Šachovnice Move byla vrácena do standardní počáteční pozice.',
    'Move control can be changed': 'Ovládání tahů lze změnit',
    'Move likelihood': 'Pravděpodobnost tahu',
    'Moves by rating': 'Tahy podle ratingu',
    'My personal engine': 'Můj osobní engine',
    'Network issue': 'Problém se sítí',
    'New personal engine': 'Nový osobní engine',
    'No PGN available for this record.': 'Pro tento záznam není dostupné PGN.',
    'No active themes': 'Žádná aktivní témata',
    'No finished game with playable moves is available yet.':
        'Zatím není dostupná dokončená partie s přehratelnými tahy.',
    'No games loaded for this page.':
        'Na této stránce nejsou načteny žádné partie.',
    'No moves yet': 'Zatím žádné tahy',
    'No personal engines yet': 'Zatím žádné osobní enginy',
    'No review mistakes yet': 'Zatím žádné chyby k rozboru',
    'No usable PGN games matched this Lichess player and filters.':
        'Tomuto hráči Lichess a filtrům neodpovídají žádné použitelné PGN partie.',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Oficiální Maia porovnává tahy napříč ratingy. Mobilní zobrazení udržuje vybraný model přehledný.',
    'Open': 'Otevřít',
    'Open Google Play': 'Otevřít Google Play',
    'Open source code': 'Otevřít zdrojový kód',
    'Open store': 'Otevřít obchod',
    'Open-source notices': 'Informace o open-source',
    'Opponent move mode': 'Režim tahu soupeře',
    'Optional date or text': 'Volitelné datum nebo text',
    'Original cost': 'Původní cena',
    'PGN refreshed.': 'PGN aktualizováno.',
    'Password cannot be empty.': 'Heslo nesmí být prázdné.',
    'Password reset successfully.': 'Heslo bylo úspěšně obnoveno.',
    'Pay today': 'Zaplatit dnes',
    'Personal engine deleted.': 'Osobní engine byl smazán.',
    'Pieces are ready': 'Figury jsou připraveny',
    'Place all 34 pieces exactly as shown before pairing.':
        'Před párováním umístěte všech 34 figur přesně podle obrázku.',
    'Play style': 'Styl hry',
    'Playable engine library': 'Knihovna hratelných enginů',
    'Player ID': 'ID hráče',
    'Please agree to the Terms of Use and Privacy Policy.':
        'Odsouhlaste Podmínky použití a Zásady ochrany soukromí.',
    'Premium active / Grandeur and personal engine training unlimited':
        'Premium aktivní / Grandeur a trénink osobního enginu bez omezení',
    'Premium is active.': 'Premium je aktivní.',
    'Preparing insight': 'Příprava rozboru',
    'Preparing lesson': 'Příprava lekce',
    'Press clock switch': 'Stisknout přepínač hodin',
    'Preview Lichess games before starting training.':
        'Před zahájením tréninku si prohlédněte partie Lichess.',
    'Profile update failed. Check your connection and try again.':
        'Aktualizace profilu se nezdařila. Zkontrolujte připojení a zkuste to znovu.',
    'Progress synced. Keep the streak moving.':
        'Postup synchronizován. Pokračujte v sérii.',
    'Purchase was not completed. You can try again when ready.':
        'Nákup nebyl dokončen. Můžete to zkusit znovu později.',
    'Rated and casual': 'Hodnocené i nehodnocené',
    'Rated only': 'Pouze hodnocené',
    'Remind me in 1 day': 'Připomenout za 1 den',
    'Remove': 'Odebrat',
    'Remove piece set?': 'Odebrat sadu figur?',
    'Removed pieces need to be paired again before they can be used.':
        'Odebrané figury je před použitím nutné znovu spárovat.',
    'Replay': 'Přehrát',
    'Replay guides': 'Znovu zobrazit průvodce',
    'Report': 'Zpráva',
    'Report image ready to share.': 'Obrázek zprávy je připraven ke sdílení.',
    'Reset both clocks and start over.':
        'Resetovat oboje hodiny a začít znovu.',
    'Reset clock?': 'Resetovat hodiny?',
    'Resign and exit': 'Vzdát a odejít',
    'Restore purchase': 'Obnovit nákup',
    'Resume': 'Pokračovat',
    'Retry': 'Zkusit znovu',
    'Review settings': 'Nastavení rozboru',
    'Select': 'Vybrat',
    'Select page': 'Vybrat stránku',
    'Set LEFT': 'Nastavit LEVÉ',
    'Set RIGHT': 'Nastavit PRAVÉ',
    'Show all guides next time': 'Příště zobrazit všechny průvodce',
    'Show human likelihood next to the engine verdict.':
        'Zobrazit pravděpodobnost lidské volby vedle verdiktu enginu.',
    'Shutdown mode': 'Režim vypnutí',
    'Shutdown mode sent.': 'Příkaz režimu vypnutí byl odeslán.',
    'Sign in before starting Career Mode.':
        'Před spuštěním režimu kariéry se přihlaste.',
    'Sign in did not finish. Please try again.':
        'Přihlášení nebylo dokončeno. Zkuste to znovu.',
    'Sign in to sync points and profile.':
        'Přihlaste se pro synchronizaci bodů a profilu.',
    'Since': 'Od',
    'Skip': 'Přeskočit',
    'Start': 'Spustit',
    'Start import': 'Spustit import',
    'Start pairing': 'Spustit párování',
    'Submitting selected games for personal engine training...':
        'Odesílání vybraných partií k tréninku osobního enginu...',
    'Switch account': 'Přepnout účet',
    'Tactical depth': 'Taktická hloubka',
    'Tap a move to jump back to the board.':
        'Klepnutím na tah přejdete k dané pozici.',
    'Tap to view details': 'Klepnutím zobrazíte podrobnosti',
    'Target Elo': 'Cílové Elo',
    'The PGN is still loading. Try again shortly.':
        'PGN se stále načítá. Zkuste to za chvíli.',
    'The new set has been paired and saved to this channel.':
        'Nová sada byla spárována a uložena do tohoto kanálu.',
    'The selected PGN file is empty.': 'Vybraný soubor PGN je prázdný.',
    'Theme not available yet': 'Téma zatím není dostupné',
    'This LC0 engine is not ready to download yet.':
        'Tento engine LC0 zatím není připraven ke stažení.',
    'This PGN could not be read. Check the PGN file and try again.':
        'PGN se nepodařilo přečíst. Zkontrolujte soubor a zkuste to znovu.',
    'This PGN could not be read. Check the move list and try again.':
        'PGN se nepodařilo přečíst. Zkontrolujte seznam tahů a zkuste to znovu.',
    'This PGN includes a move Chessnut cannot read. Check the move list and try again.':
        'PGN obsahuje tah, který Chessnut neumí přečíst. Zkontrolujte seznam tahů.',
    'This engine cannot be liked yet.':
        'Tento engine zatím nelze označit jako oblíbený.',
    'This game ended before any playable moves, so there is no position to analyze.':
        'Partie skončila před přehratelným tahem, takže není co analyzovat.',
    'This personal engine cannot be renamed yet.':
        'Tento osobní engine zatím nelze přejmenovat.',
    'This personal engine does not have a weight file yet.':
        'Tento osobní engine zatím nemá soubor vah.',
    'This personal engine is still training.':
        'Tento osobní engine se stále trénuje.',
    'This update will be handled by Google Play on this device.':
        'Aktualizaci na tomto zařízení provede Google Play.',
    'This update will open in your browser.':
        'Aktualizace se otevře v prohlížeči.',
    'This update will open the Chessnut page on Google Play.':
        'Otevře se stránka Chessnut na Google Play.',
    'This update will open the official Chessnut download page.':
        'Otevře se oficiální stránka pro stažení Chessnut.',
    'This update will open the official app store or test track for your device.':
        'Otevře se oficiální obchod nebo testovací kanál zařízení.',
    'This version is required to keep Chessnut working correctly. Please update before continuing.':
        'Tato verze je nutná pro správnou funkci Chessnut. Před pokračováním aktualizujte.',
    'Time': 'Čas',
    'Training modes': 'Tréninkové režimy',
    'Turn on': 'Zapnout',
    'Turn on shutdown mode?': 'Zapnout režim vypnutí?',
    'USB Clock Test': 'Test hodin USB',
    'Unable to check Lichess authorization. Please try again.':
        'Autorizaci Lichess se nepodařilo ověřit. Zkuste to znovu.',
    'Unable to delete this personal engine. Try again later.':
        'Osobní engine se nepodařilo smazat. Zkuste to později.',
    'Unable to download Grandeur report.':
        'Zprávu Grandeur se nepodařilo stáhnout.',
    'Unable to download this LC0 engine. Check your connection and try again.':
        'Engine LC0 se nepodařilo stáhnout. Zkontrolujte připojení.',
    'Unable to download this personal engine. Check your connection and try again.':
        'Osobní engine se nepodařilo stáhnout. Zkontrolujte připojení.',
    'Unable to end this game record.': 'Záznam partie se nepodařilo ukončit.',
    'Unable to load the matched Game Record preview.':
        'Náhled odpovídajících záznamů se nepodařilo načíst.',
    'Unable to open this PGN file. Choose another file and try again.':
        'Soubor PGN se nepodařilo otevřít. Vyberte jiný a zkuste to znovu.',
    'Unable to pair pieces': 'Figury se nepodařilo spárovat',
    'Unable to refresh this PGN.': 'PGN se nepodařilo aktualizovat.',
    'Unable to send command.': 'Příkaz se nepodařilo odeslat.',
    'Unable to share report image.': 'Obrázek zprávy se nepodařilo sdílet.',
    'Unable to start personal engine training.':
        'Trénink osobního enginu se nepodařilo spustit.',
    'Unable to switch to this account.':
        'Na tento účet se nepodařilo přepnout.',
    'Unable to update like. Try again later.':
        'Oblíbení se nepodařilo aktualizovat. Zkuste to později.',
    'Unable to update this engine name. Try again later.':
        'Název enginu se nepodařilo aktualizovat. Zkuste to později.',
    'Unable to update this engine. Try again later.':
        'Engine se nepodařilo aktualizovat. Zkuste to později.',
    'Unable to update this personal engine. Check your connection and try again.':
        'Osobní engine se nepodařilo aktualizovat. Zkontrolujte připojení.',
    'Unlink Lichess': 'Odpojit Lichess',
    'Until': 'Do',
    'Update available': 'Je dostupná aktualizace',
    'Update link is not available right now. Please try again later.':
        'Odkaz na aktualizaci nyní není dostupný. Zkuste to později.',
    'Update now': 'Aktualizovat nyní',
    'Update required': 'Je vyžadována aktualizace',
    'Update with Google Play': 'Aktualizovat přes Google Play',
    'Use another saved Chessnut ID': 'Použít jiné uložené Chessnut ID',
    'Use selected': 'Použít vybrané',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'Použijte pro dlouhodobé uložení. Před dalším použitím je nutné figury položit na nabíjecí šachovnici.',
    'Use this model': 'Použít tento model',
    'Use this position': 'Použít tuto pozici',
    'VIP member': 'Člen VIP',
    'Valid until': 'Platné do',
    'Verification code cannot be empty.': 'Ověřovací kód nesmí být prázdný.',
    'Verification code required': 'Je vyžadován ověřovací kód',
    'Verification could not open in the app':
        'Ověření se nepodařilo otevřít v aplikaci',
    'View first-time tips again': 'Znovu zobrazit úvodní tipy',
    'Voice moves': 'Hlasové tahy',
    'Waiting for piece status': 'Čekání na stav figur',
    'Wallet test tools are unavailable.':
        'Testovací nástroje peněženky nejsou dostupné.',
    'White games': 'Partie bílými',
    'You are using the latest version.': 'Používáte nejnovější verzi.',
    'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.':
        'Účet Chessnut je již propojen s Lichess. Propojení můžete ponechat nebo zrušit a autorizovat jiný účet.',
    'no legal mainline moves': 'žádné legální tahy v hlavní variantě',
    'points': 'body',
    'pts': 'b.',
    'sec': 's',
  },
  'ar': {
    '6-digit code': 'رمز من 6 أرقام',
    'A newer version is available. Update now to get the latest fixes and improvements.':
        'يتوفر إصدار أحدث. حدّث الآن للحصول على أحدث الإصلاحات والتحسينات.',
    'Add an engine name before starting training.':
        'أضف اسمًا للمحرك قبل بدء التدريب.',
    'All daily tasks completed.': 'اكتملت جميع المهام اليومية.',
    'Analysis marker LED patterns': 'أنماط LED لعلامات التحليل',
    'Auto-detect set': 'اكتشاف مجموعة القطع تلقائيًا',
    'Automatic switch press': 'ضغط مفتاح الساعة تلقائيًا',
    'Back to channels': 'العودة إلى القنوات',
    'Black games': 'مباريات بالأسود',
    'Bluetooth': 'بلوتوث',
    'Board Settings lets you choose Direct control or Web control for physical board moves.':
        'تتيح لك إعدادات الرقعة اختيار التحكم المباشر أو التحكم عبر الويب لنقلات الرقعة الفعلية.',
    'Board connection failed.': 'فشل الاتصال بالرقعة.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'انقطع اتصال الرقعة وفشلت إعادة الاتصال؛ ستظل المباراة مفتوحة.',
    'Bot game engine library': 'مكتبة محركات اللعب ضد الحاسوب',
    'Camera': 'الكاميرا',
    'Candidate moves are human probabilities, not best-move scores.':
        'النقلات المرشحة هي احتمالات اختيار بشري وليست تقييمات لأفضل نقلة.',
    'Cantonese': 'الكانتونية',
    'Casual only': 'غير مصنفة فقط',
    'Check for updates': 'التحقق من التحديثات',
    'Check placement, battery, and nearby interference, then try again.':
        'تحقق من مواضع القطع والبطارية والتشويش القريب، ثم حاول مجددًا.',
    'Check whether a newer Chessnut version is available.':
        'تحقق من توفر إصدار أحدث من Chessnut.',
    'Checked in today / Grandeur 100 / personal engine training 500':
        'تم تسجيل الحضور اليوم / Grandeur‏ 100 / تدريب المحرك الشخصي 500',
    'Checking': 'جارٍ التحقق',
    'Checkpoints': 'نقاط التحقق',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Chessnut Vision is now active.': 'أصبح Chessnut Vision نشطًا الآن.',
    'Choose a target': 'اختر هدفًا',
    'Choose image': 'اختيار صورة',
    'Claimed': 'تم الاستلام',
    'Clear page': 'مسح الصفحة',
    'Close authorization': 'إغلاق التفويض',
    'Cloud Maia 3': 'Maia 3 السحابي',
    'Compare with Stockfish': 'المقارنة مع Stockfish',
    'Confirm': 'تأكيد',
    'Confirm draw': 'تأكيد التعادل',
    'Confirm resign': 'تأكيد الاستسلام',
    'Confirm takeback': 'تأكيد التراجع',
    'Connected as': 'متصل باسم',
    'Connection Status': 'حالة الاتصال',
    'Continue learning': 'متابعة التعلم',
    'Control the board LED hints used while setting up and playing.':
        'تحكم في إرشادات LED على الرقعة أثناء الإعداد واللعب.',
    'Copy failed. Please try again.': 'فشل النسخ. حاول مرة أخرى.',
    'Could not check for updates. Please try again later.':
        'تعذر التحقق من التحديثات. حاول لاحقًا.',
    'Could not open the source link. Please try again later.':
        'تعذر فتح رابط المصدر. حاول لاحقًا.',
    'Could not open the update link. Please try again later.':
        'تعذر فتح رابط التحديث. حاول لاحقًا.',
    'Curated LC0 engines': 'محركات LC0 مختارة',
    'Daily check-in available / Grandeur 100 / personal engine training 500':
        'تسجيل الحضور اليومي متاح / Grandeur‏ 100 / تدريب المحرك الشخصي 500',
    'Date': 'التاريخ',
    'Delete record': 'حذف السجل',
    "Don't remind me again for this update":
        'عدم التذكير بهذا التحديث مرة أخرى',
    'Download update': 'تنزيل التحديث',
    'Enable Vision': 'تفعيل Vision',
    'End game': 'إنهاء المباراة',
    'Engine comparison': 'مقارنة المحركات',
    'Engine disabled.': 'تم تعطيل المحرك.',
    'Engine enabled for Bot game.': 'تم تفعيل المحرك للعب ضد الحاسوب.',
    'Engine name updated.': 'تم تحديث اسم المحرك.',
    'Enter an engine name before saving.': 'أدخل اسمًا للمحرك قبل الحفظ.',
    'Event Log': 'سجل الأحداث',
    'FEN position': 'وضعية FEN',
    'Fetching the latest Chessnut lesson library.':
        'جارٍ جلب أحدث مكتبة دروس Chessnut.',
    'Fill': 'ملء',
    'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.':
        'صفِّ مبارياتك المحفوظة هنا، وعاين ملفات PGN الصالحة، ثم ابدأ التدريب دون مغادرة Engine Lab.',
    'Finish this game before generating an analysis report.':
        'أنه هذه المباراة قبل إنشاء تقرير التحليل.',
    'From Chess.com username': 'من اسم مستخدم Chess.com',
    'From Lichess player': 'من لاعب Lichess',
    'From PGN': 'من PGN',
    'G': 'م',
    'Game marked as ended.': 'تم تحديد المباراة كمنتهية.',
    'Game record deleted.': 'تم حذف سجل المباراة.',
    'Go': 'متابعة',
    'Go to login': 'الانتقال إلى تسجيل الدخول',
    'Google Play update is not available right now. Opening the store page instead.':
        'تحديث Google Play غير متاح الآن. سيتم فتح صفحة المتجر بدلًا منه.',
    'Grandeur HTML report downloaded.': 'تم تنزيل تقرير Grandeur بصيغة HTML.',
    'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.':
        'تبلغ تكلفة Grandeur عادةً 100 نقطة من المحفظة. يدفع الأعضاء 0 نقطة تلقائيًا. يمكنك كسب المزيد من المهام اليومية إذا لم تكفِ نقاطك.',
    'Help': 'مساعدة',
    'Import Chess.com games': 'استيراد مباريات Chess.com',
    'Import Lichess games': 'استيراد مباريات Lichess',
    'Import PGN files before starting training.':
        'استورد ملفات PGN قبل بدء التدريب.',
    'Import at least 1 game.': 'استورد مباراة واحدة على الأقل.',
    'Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.':
        'استورد المباريات المنتهية للاعب Lichess إلى سجلات المباريات. يتم تخطي المباريات المكررة تلقائيًا.',
    'Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.':
        'استورد المباريات العامة المنتهية لمستخدم Chess.com إلى سجلات المباريات. قد يتأخر ظهور المباريات الحديثة جدًا في أرشيف Chess.com.',
    'Include app logs and device details': 'تضمين سجلات التطبيق وتفاصيل الجهاز',
    'Includes app version, device type, current screen, board status, and recent logs.':
        'يتضمن إصدار التطبيق ونوع الجهاز والشاشة الحالية وحالة الرقعة والسجلات الحديثة.',
    'Interactive': 'تفاعلي',
    'Keep first 200': 'الاحتفاظ بأول 200',
    'Keep linked': 'إبقاء الربط',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'أبعد مجموعات Move الأخرى أثناء الاقتران. تستغرق العملية عادةً من 3 إلى 5 دقائق.',
    'Key moments': 'اللحظات المهمة',
    'Last Button Pressed': 'آخر زر تم ضغطه',
    'Later': 'لاحقًا',
    'Latest version': 'أحدث إصدار',
    'Learn with your board': 'تعلّم باستخدام رقعتك',
    'Leave for now': 'المغادرة الآن',
    'Licenses and Maia 3 source code': 'التراخيص والكود المصدري لـ Maia 3',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess account unlinked.': 'تم إلغاء ربط حساب Lichess.',
    'Lichess authorization complete.': 'اكتمل تفويض Lichess.',
    'Lichess authorization could not open.': 'تعذر فتح تفويض Lichess.',
    'Lichess authorization could not open. Try again later.':
        'تعذر فتح تفويض Lichess. حاول لاحقًا.',
    'Lichess authorization expired. Re-authorize before continuing.':
        'انتهت صلاحية تفويض Lichess. أعد التفويض قبل المتابعة.',
    'Lichess authorization is not available right now. Please try again later.':
        'تفويض Lichess غير متاح الآن. حاول لاحقًا.',
    'Lichess authorization was not completed. Try again when the Lichess page finishes.':
        'لم يكتمل تفويض Lichess. حاول مجددًا بعد انتهاء صفحة Lichess.',
    'Lichess authorized.': 'تم تفويض Lichess.',
    'Lichess did not respond in time. Try again.':
        'لم يستجب Lichess في الوقت المحدد. حاول مجددًا.',
    'Lichess sign-in status could not be checked. Please try again later.':
        'تعذر التحقق من حالة تسجيل الدخول إلى Lichess. حاول لاحقًا.',
    'Linked account update failed. Please try again.':
        'فشل تحديث الحساب المرتبط. حاول مجددًا.',
    'Linked accounts': 'الحسابات المرتبطة',
    'Loading courses': 'جارٍ تحميل الدورات',
    'Loading subtitles and board checkpoints.':
        'جارٍ تحميل الترجمات ونقاط التحقق على الرقعة.',
    'Local QA wallet tools': 'أدوات اختبار المحفظة المحلية',
    'Local list': 'القائمة المحلية',
    'Location': 'المكان',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia 3 predicts likely human moves from 600 to 2600 Elo. Sign in and stay online to use it.':
        'يتوقع Maia 3 النقلات البشرية المحتملة من 600 إلى 2600 Elo. سجّل الدخول وابقَ متصلًا لاستخدامه.',
    'Maia3 explains human likelihood. Stockfish checks objective quality.':
        'يوضح Maia3 احتمال اختيار البشر، بينما يفحص Stockfish الجودة الموضوعية.',
    'Maia3 is estimating likely human choices for each move.':
        'يقدّر Maia3 الاختيارات البشرية المحتملة لكل نقلة.',
    'Mandarin': 'الماندرين',
    'Max games': 'الحد الأقصى للمباريات',
    'Member discount': 'خصم العضوية',
    'Message status could not be updated. Please try again.':
        'تعذر تحديث حالة الرسالة. حاول مجددًا.',
    'More filters': 'المزيد من عوامل التصفية',
    'Move board did not accept the command.': 'لم تقبل رقعة Move الأمر.',
    'Move board did not accept the reset command.':
        'لم تقبل رقعة Move أمر إعادة الضبط.',
    'Move board reset to the standard starting position.':
        'أُعيدت رقعة Move إلى وضع البداية القياسي.',
    'Move control can be changed': 'يمكن تغيير التحكم في النقلات',
    'Move likelihood': 'احتمال النقلة',
    'Moves by rating': 'النقلات حسب التصنيف',
    'My personal engine': 'محركي الشخصي',
    'Network issue': 'مشكلة في الشبكة',
    'New personal engine': 'محرك شخصي جديد',
    'No PGN available for this record.': 'لا يتوفر PGN لهذا السجل.',
    'No active themes': 'لا توجد سمات نشطة',
    'No finished game with playable moves is available yet.':
        'لا توجد بعد مباراة منتهية بنقلات قابلة للتشغيل.',
    'No games loaded for this page.': 'لم يتم تحميل مباريات لهذه الصفحة.',
    'No moves yet': 'لا توجد نقلات بعد',
    'No personal engines yet': 'لا توجد محركات شخصية بعد',
    'No review mistakes yet': 'لا توجد أخطاء للمراجعة بعد',
    'No usable PGN games matched this Lichess player and filters.':
        'لا توجد مباريات PGN صالحة تطابق لاعب Lichess وعوامل التصفية هذه.',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'يمكن لـ Maia الرسمي مقارنة النقلات عبر مستويات التصنيف. يحافظ عرض الهاتف على اختصار النموذج المحدد.',
    'Open': 'فتح',
    'Open Google Play': 'فتح Google Play',
    'Open source code': 'فتح الكود المصدري',
    'Open store': 'فتح المتجر',
    'Open-source notices': 'إشعارات المصادر المفتوحة',
    'Opponent move mode': 'وضع نقلة الخصم',
    'Optional date or text': 'تاريخ أو نص اختياري',
    'Original cost': 'التكلفة الأصلية',
    'PGN refreshed.': 'تم تحديث PGN.',
    'Password cannot be empty.': 'لا يمكن ترك كلمة المرور فارغة.',
    'Password reset successfully.': 'تمت إعادة تعيين كلمة المرور بنجاح.',
    'Pay today': 'الدفع اليوم',
    'Personal engine deleted.': 'تم حذف المحرك الشخصي.',
    'Pieces are ready': 'القطع جاهزة',
    'Place all 34 pieces exactly as shown before pairing.':
        'ضع القطع الـ34 تمامًا كما هو موضح قبل الاقتران.',
    'Play style': 'أسلوب اللعب',
    'Playable engine library': 'مكتبة المحركات القابلة للعب',
    'Player ID': 'معرّف اللاعب',
    'Please agree to the Terms of Use and Privacy Policy.':
        'يرجى الموافقة على شروط الاستخدام وسياسة الخصوصية.',
    'Premium active / Grandeur and personal engine training unlimited':
        'Premium نشط / Grandeur وتدريب المحرك الشخصي بلا حدود',
    'Premium is active.': 'Premium نشط.',
    'Preparing insight': 'جارٍ إعداد التحليل',
    'Preparing lesson': 'جارٍ إعداد الدرس',
    'Press clock switch': 'ضغط مفتاح الساعة',
    'Preview Lichess games before starting training.':
        'عاين مباريات Lichess قبل بدء التدريب.',
    'Profile update failed. Check your connection and try again.':
        'فشل تحديث الملف الشخصي. تحقق من اتصالك وحاول مجددًا.',
    'Progress synced. Keep the streak moving.':
        'تمت مزامنة التقدم. واصل السلسلة.',
    'Purchase was not completed. You can try again when ready.':
        'لم تكتمل عملية الشراء. يمكنك المحاولة مجددًا عندما تكون مستعدًا.',
    'Rated and casual': 'مصنفة وغير مصنفة',
    'Rated only': 'مصنفة فقط',
    'Remind me in 1 day': 'ذكّرني بعد يوم واحد',
    'Remove': 'إزالة',
    'Remove piece set?': 'إزالة مجموعة القطع؟',
    'Removed pieces need to be paired again before they can be used.':
        'يجب إقران القطع التي تمت إزالتها مجددًا قبل استخدامها.',
    'Replay': 'إعادة التشغيل',
    'Replay guides': 'عرض الإرشادات مجددًا',
    'Report': 'تقرير',
    'Report image ready to share.': 'صورة التقرير جاهزة للمشاركة.',
    'Reset both clocks and start over.': 'أعد ضبط الساعتين وابدأ من جديد.',
    'Reset clock?': 'إعادة ضبط الساعة؟',
    'Resign and exit': 'الاستسلام والخروج',
    'Restore purchase': 'استعادة الشراء',
    'Resume': 'متابعة',
    'Retry': 'إعادة المحاولة',
    'Review settings': 'إعدادات المراجعة',
    'Select': 'اختيار',
    'Select page': 'اختيار الصفحة',
    'Set LEFT': 'ضبط اليسار',
    'Set RIGHT': 'ضبط اليمين',
    'Show all guides next time': 'عرض جميع الإرشادات في المرة القادمة',
    'Show human likelihood next to the engine verdict.':
        'إظهار احتمال الاختيار البشري بجانب حكم المحرك.',
    'Shutdown mode': 'وضع إيقاف التشغيل',
    'Shutdown mode sent.': 'تم إرسال أمر وضع إيقاف التشغيل.',
    'Sign in before starting Career Mode.': 'سجّل الدخول قبل بدء وضع المسيرة.',
    'Sign in did not finish. Please try again.':
        'لم يكتمل تسجيل الدخول. حاول مجددًا.',
    'Sign in to sync points and profile.':
        'سجّل الدخول لمزامنة النقاط والملف الشخصي.',
    'Since': 'منذ',
    'Skip': 'تخطي',
    'Start': 'بدء',
    'Start import': 'بدء الاستيراد',
    'Start pairing': 'بدء الاقتران',
    'Submitting selected games for personal engine training...':
        'جارٍ إرسال المباريات المحددة لتدريب المحرك الشخصي...',
    'Switch account': 'تبديل الحساب',
    'Tactical depth': 'العمق التكتيكي',
    'Tap a move to jump back to the board.':
        'اضغط على نقلة للعودة إلى وضعيتها على الرقعة.',
    'Tap to view details': 'اضغط لعرض التفاصيل',
    'Target Elo': 'Elo المستهدف',
    'The PGN is still loading. Try again shortly.':
        'ما زال PGN قيد التحميل. حاول بعد قليل.',
    'The new set has been paired and saved to this channel.':
        'تم إقران المجموعة الجديدة وحفظها في هذه القناة.',
    'The selected PGN file is empty.': 'ملف PGN المحدد فارغ.',
    'Theme not available yet': 'السمة غير متاحة بعد',
    'This LC0 engine is not ready to download yet.':
        'محرك LC0 هذا غير جاهز للتنزيل بعد.',
    'This PGN could not be read. Check the PGN file and try again.':
        'تعذرت قراءة PGN. تحقق من الملف وحاول مجددًا.',
    'This PGN could not be read. Check the move list and try again.':
        'تعذرت قراءة PGN. تحقق من قائمة النقلات وحاول مجددًا.',
    'This PGN includes a move Chessnut cannot read. Check the move list and try again.':
        'يتضمن PGN نقلة لا يستطيع Chessnut قراءتها. تحقق من قائمة النقلات.',
    'This engine cannot be liked yet.':
        'لا يمكن إضافة هذا المحرك إلى المفضلة بعد.',
    'This game ended before any playable moves, so there is no position to analyze.':
        'انتهت المباراة قبل وجود نقلات قابلة للتشغيل، لذلك لا توجد وضعية للتحليل.',
    'This personal engine cannot be renamed yet.':
        'لا يمكن إعادة تسمية هذا المحرك الشخصي بعد.',
    'This personal engine does not have a weight file yet.':
        'لا يملك هذا المحرك الشخصي ملف أوزان بعد.',
    'This personal engine is still training.':
        'ما زال هذا المحرك الشخصي قيد التدريب.',
    'This update will be handled by Google Play on this device.':
        'سيتولى Google Play التحديث على هذا الجهاز.',
    'This update will open in your browser.': 'سيُفتح هذا التحديث في المتصفح.',
    'This update will open the Chessnut page on Google Play.':
        'سيفتح هذا التحديث صفحة Chessnut على Google Play.',
    'This update will open the official Chessnut download page.':
        'سيفتح هذا التحديث صفحة تنزيل Chessnut الرسمية.',
    'This update will open the official app store or test track for your device.':
        'سيفتح هذا التحديث المتجر الرسمي أو مسار الاختبار لجهازك.',
    'This version is required to keep Chessnut working correctly. Please update before continuing.':
        'هذا الإصدار مطلوب لاستمرار عمل Chessnut بشكل صحيح. حدّث قبل المتابعة.',
    'Time': 'الوقت',
    'Training modes': 'أوضاع التدريب',
    'Turn on': 'تشغيل',
    'Turn on shutdown mode?': 'تشغيل وضع إيقاف التشغيل؟',
    'USB Clock Test': 'اختبار ساعة USB',
    'Unable to check Lichess authorization. Please try again.':
        'تعذر التحقق من تفويض Lichess. حاول مجددًا.',
    'Unable to delete this personal engine. Try again later.':
        'تعذر حذف هذا المحرك الشخصي. حاول لاحقًا.',
    'Unable to download Grandeur report.': 'تعذر تنزيل تقرير Grandeur.',
    'Unable to download this LC0 engine. Check your connection and try again.':
        'تعذر تنزيل محرك LC0. تحقق من اتصالك وحاول مجددًا.',
    'Unable to download this personal engine. Check your connection and try again.':
        'تعذر تنزيل المحرك الشخصي. تحقق من اتصالك وحاول مجددًا.',
    'Unable to end this game record.': 'تعذر إنهاء سجل المباراة.',
    'Unable to load the matched Game Record preview.':
        'تعذر تحميل معاينة سجلات المباريات المطابقة.',
    'Unable to open this PGN file. Choose another file and try again.':
        'تعذر فتح ملف PGN. اختر ملفًا آخر وحاول مجددًا.',
    'Unable to pair pieces': 'تعذر إقران القطع',
    'Unable to refresh this PGN.': 'تعذر تحديث PGN.',
    'Unable to send command.': 'تعذر إرسال الأمر.',
    'Unable to share report image.': 'تعذرت مشاركة صورة التقرير.',
    'Unable to start personal engine training.':
        'تعذر بدء تدريب المحرك الشخصي.',
    'Unable to switch to this account.': 'تعذر التبديل إلى هذا الحساب.',
    'Unable to update like. Try again later.':
        'تعذر تحديث المفضلة. حاول لاحقًا.',
    'Unable to update this engine name. Try again later.':
        'تعذر تحديث اسم المحرك. حاول لاحقًا.',
    'Unable to update this engine. Try again later.':
        'تعذر تحديث المحرك. حاول لاحقًا.',
    'Unable to update this personal engine. Check your connection and try again.':
        'تعذر تحديث المحرك الشخصي. تحقق من اتصالك وحاول مجددًا.',
    'Unlink Lichess': 'إلغاء ربط Lichess',
    'Until': 'حتى',
    'Update available': 'يتوفر تحديث',
    'Update link is not available right now. Please try again later.':
        'رابط التحديث غير متاح الآن. حاول لاحقًا.',
    'Update now': 'التحديث الآن',
    'Update required': 'التحديث مطلوب',
    'Update with Google Play': 'التحديث عبر Google Play',
    'Use another saved Chessnut ID': 'استخدام Chessnut ID محفوظ آخر',
    'Use selected': 'استخدام المحدد',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'استخدمه للتخزين طويل الأمد. يجب وضع القطع على رقعة الشحن قبل استخدامها مجددًا.',
    'Use this model': 'استخدام هذا النموذج',
    'Use this position': 'استخدام هذه الوضعية',
    'VIP member': 'عضو VIP',
    'Valid until': 'صالح حتى',
    'Verification code cannot be empty.': 'لا يمكن ترك رمز التحقق فارغًا.',
    'Verification code required': 'رمز التحقق مطلوب',
    'Verification could not open in the app': 'تعذر فتح التحقق داخل التطبيق',
    'View first-time tips again': 'عرض إرشادات الاستخدام الأول مجددًا',
    'Voice moves': 'النقلات الصوتية',
    'Waiting for piece status': 'بانتظار حالة القطع',
    'Wallet test tools are unavailable.': 'أدوات اختبار المحفظة غير متاحة.',
    'White games': 'مباريات بالأبيض',
    'You are using the latest version.': 'أنت تستخدم أحدث إصدار.',
    'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.':
        'حساب Chessnut مرتبط بالفعل بـ Lichess. يمكنك إبقاء الربط أو إلغاؤه لتفويض حساب Lichess آخر.',
    'no legal mainline moves': 'لا توجد نقلات قانونية في الخط الرئيسي',
    'points': 'نقاط',
    'pts': 'نقطة',
    'sec': 'ث',
  },
  'he': {
    '6-digit code': 'קוד בן 6 ספרות',
    'A newer version is available. Update now to get the latest fixes and improvements.':
        'גרסה חדשה יותר זמינה. ניתן לעדכן עכשיו לקבלת התיקונים והשיפורים האחרונים.',
    'Add an engine name before starting training.':
        'יש להוסיף שם למנוע לפני תחילת האימון.',
    'All daily tasks completed.': 'כל המשימות היומיות הושלמו.',
    'Analysis marker LED patterns': 'תבניות LED לסימוני ניתוח',
    'Auto-detect set': 'זיהוי אוטומטי של ערכת הכלים',
    'Automatic switch press': 'לחיצה אוטומטית על מתג השעון',
    'Back to channels': 'חזרה לערוצים',
    'Black games': 'משחקים בשחור',
    'Bluetooth': 'Bluetooth',
    'Board Settings lets you choose Direct control or Web control for physical board moves.':
        'בהגדרות הלוח ניתן לבחור שליטה ישירה או שליטה דרך האינטרנט למהלכים בלוח הפיזי.',
    'Board connection failed.': 'החיבור ללוח נכשל.',
    'Board disconnected. Reconnect failed; the game will stay open.':
        'הלוח נותק והחיבור מחדש נכשל; המשחק יישאר פתוח.',
    'Bot game engine library': 'ספריית מנועים למשחק מול המחשב',
    'Camera': 'מצלמה',
    'Candidate moves are human probabilities, not best-move scores.':
        'המהלכים המועמדים מציגים הסתברות לבחירה אנושית, ולא ציונים של המהלך הטוב ביותר.',
    'Cantonese': 'קנטונזית',
    'Casual only': 'לא מדורגים בלבד',
    'Check for updates': 'בדיקת עדכונים',
    'Check placement, battery, and nearby interference, then try again.':
        'יש לבדוק את מיקום הכלים, הסוללה והפרעות בסביבה, ולנסות שוב.',
    'Check whether a newer Chessnut version is available.':
        'בדיקה אם זמינה גרסה חדשה יותר של Chessnut.',
    'Checked in today / Grandeur 100 / personal engine training 500':
        'התגמול היומי נאסף / Grandeur‏ 100 / אימון מנוע אישי 500',
    'Checking': 'מתבצעת בדיקה',
    'Checkpoints': 'נקודות בדיקה',
    'Chess.com 10+5': 'Chess.com 10+5',
    'Chessnut Vision is now active.': 'Chessnut Vision פעיל כעת.',
    'Choose a target': 'בחירת יעד',
    'Choose image': 'בחירת תמונה',
    'Claimed': 'נאסף',
    'Clear page': 'ניקוי הדף',
    'Close authorization': 'סגירת ההרשאה',
    'Cloud Maia 3': 'Maia 3 בענן',
    'Compare with Stockfish': 'השוואה ל-Stockfish',
    'Confirm': 'אישור',
    'Confirm draw': 'אישור תיקו',
    'Confirm resign': 'אישור כניעה',
    'Confirm takeback': 'אישור החזרת מהלך',
    'Connected as': 'מחובר בתור',
    'Connection Status': 'מצב החיבור',
    'Continue learning': 'המשך למידה',
    'Control the board LED hints used while setting up and playing.':
        'שליטה ברמזי ה-LED בלוח בזמן סידור הכלים והמשחק.',
    'Copy failed. Please try again.': 'ההעתקה נכשלה. יש לנסות שוב.',
    'Could not check for updates. Please try again later.':
        'לא ניתן לבדוק עדכונים. יש לנסות שוב מאוחר יותר.',
    'Could not open the source link. Please try again later.':
        'לא ניתן לפתוח את הקישור לקוד המקור. יש לנסות מאוחר יותר.',
    'Could not open the update link. Please try again later.':
        'לא ניתן לפתוח את קישור העדכון. יש לנסות מאוחר יותר.',
    'Curated LC0 engines': 'מנועי LC0 נבחרים',
    'Daily check-in available / Grandeur 100 / personal engine training 500':
        'התגמול היומי זמין / Grandeur‏ 100 / אימון מנוע אישי 500',
    'Date': 'תאריך',
    'Delete record': 'מחיקת רשומה',
    "Don't remind me again for this update": 'אין להזכיר שוב את העדכון הזה',
    'Download update': 'הורדת העדכון',
    'Enable Vision': 'הפעלת Vision',
    'End game': 'סיום המשחק',
    'Engine comparison': 'השוואת מנועים',
    'Engine disabled.': 'המנוע הושבת.',
    'Engine enabled for Bot game.': 'המנוע הופעל למשחק מול המחשב.',
    'Engine name updated.': 'שם המנוע עודכן.',
    'Enter an engine name before saving.': 'יש להזין שם למנוע לפני השמירה.',
    'Event Log': 'יומן אירועים',
    'FEN position': 'עמדת FEN',
    'Fetching the latest Chessnut lesson library.':
        'מתבצעת הורדה של ספריית השיעורים העדכנית של Chessnut.',
    'Fill': 'מילוי',
    'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.':
        'כאן ניתן לסנן משחקים שמורים, לצפות בקובצי PGN תקינים ולהתחיל אימון בלי לצאת מ-Engine Lab.',
    'Finish this game before generating an analysis report.':
        'יש לסיים את המשחק לפני יצירת דוח ניתוח.',
    'From Chess.com username': 'משם משתמש ב-Chess.com',
    'From Lichess player': 'משחקן Lichess',
    'From PGN': 'מ-PGN',
    'G': 'מ',
    'Game marked as ended.': 'המשחק סומן כהסתיים.',
    'Game record deleted.': 'רשומת המשחק נמחקה.',
    'Go': 'המשך',
    'Go to login': 'מעבר להתחברות',
    'Google Play update is not available right now. Opening the store page instead.':
        'עדכון דרך Google Play אינו זמין כרגע. דף החנות ייפתח במקום זאת.',
    'Grandeur HTML report downloaded.': 'דוח ה-HTML של Grandeur הורד.',
    'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.':
        'Grandeur עולה בדרך כלל 100 נקודות מהארנק. חברים משלמים אוטומטית 0 נקודות. אם אין מספיק נקודות, ניתן לצבור עוד במשימות היומיות.',
    'Help': 'עזרה',
    'Import Chess.com games': 'ייבוא משחקים מ-Chess.com',
    'Import Lichess games': 'ייבוא משחקים מ-Lichess',
    'Import PGN files before starting training.':
        'יש לייבא קובצי PGN לפני תחילת האימון.',
    'Import at least 1 game.': 'יש לייבא לפחות משחק אחד.',
    'Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.':
        'ייבוא משחקים שהסתיימו של שחקן Lichess לרשומות המשחקים. משחקים כפולים ידולגו אוטומטית.',
    'Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.':
        'ייבוא משחקים ציבוריים שהסתיימו של משתמש Chess.com לרשומות המשחקים. ייתכן עיכוב בפרסום משחקים חדשים מאוד בארכיון Chess.com.',
    'Include app logs and device details': 'צירוף יומני האפליקציה ופרטי המכשיר',
    'Includes app version, device type, current screen, board status, and recent logs.':
        'כולל את גרסת האפליקציה, סוג המכשיר, המסך הנוכחי, מצב הלוח ויומנים אחרונים.',
    'Interactive': 'אינטראקטיבי',
    'Keep first 200': 'שמירת 200 הראשונים',
    'Keep linked': 'השארת החיבור',
    'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.':
        'בזמן הצימוד יש להרחיק ערכות Move אחרות. התהליך נמשך בדרך כלל 3–5 דקות.',
    'Key moments': 'רגעי מפתח',
    'Last Button Pressed': 'הכפתור האחרון שנלחץ',
    'Later': 'מאוחר יותר',
    'Latest version': 'הגרסה העדכנית',
    'Learn with your board': 'למידה עם הלוח',
    'Leave for now': 'יציאה לעת עתה',
    'Licenses and Maia 3 source code': 'רישיונות וקוד המקור של Maia 3',
    'Lichess 10+5': 'Lichess 10+5',
    'Lichess account unlinked.': 'חשבון Lichess נותק.',
    'Lichess authorization complete.': 'ההרשאה ל-Lichess הושלמה.',
    'Lichess authorization could not open.':
        'לא ניתן לפתוח את ההרשאה ל-Lichess.',
    'Lichess authorization could not open. Try again later.':
        'לא ניתן לפתוח את ההרשאה ל-Lichess. יש לנסות מאוחר יותר.',
    'Lichess authorization expired. Re-authorize before continuing.':
        'תוקף ההרשאה ל-Lichess פג. יש לאשר מחדש לפני ההמשך.',
    'Lichess authorization is not available right now. Please try again later.':
        'ההרשאה ל-Lichess אינה זמינה כרגע. יש לנסות מאוחר יותר.',
    'Lichess authorization was not completed. Try again when the Lichess page finishes.':
        'ההרשאה ל-Lichess לא הושלמה. יש לנסות שוב לאחר סיום דף Lichess.',
    'Lichess authorized.': 'Lichess אושר.',
    'Lichess did not respond in time. Try again.':
        'Lichess לא הגיב בזמן. יש לנסות שוב.',
    'Lichess sign-in status could not be checked. Please try again later.':
        'לא ניתן לבדוק את מצב ההתחברות ל-Lichess. יש לנסות מאוחר יותר.',
    'Linked account update failed. Please try again.':
        'עדכון החשבון המקושר נכשל. יש לנסות שוב.',
    'Linked accounts': 'חשבונות מקושרים',
    'Loading courses': 'הקורסים נטענים',
    'Loading subtitles and board checkpoints.':
        'כתוביות ונקודות בדיקה בלוח נטענות.',
    'Local QA wallet tools': 'כלי בדיקה מקומיים לארנק',
    'Local list': 'רשימה מקומית',
    'Location': 'מיקום',
    'Maia 1500 / 10+5': 'Maia 1500 / 10+5',
    'Maia 3 predicts likely human moves from 600 to 2600 Elo. Sign in and stay online to use it.':
        'Maia 3 חוזה מהלכים אנושיים סבירים בין 600 ל-2600 Elo. יש להתחבר ולהישאר מקוון כדי להשתמש בו.',
    'Maia3 explains human likelihood. Stockfish checks objective quality.':
        'Maia3 מסביר את ההסתברות לבחירה אנושית. Stockfish בודק את האיכות האובייקטיבית.',
    'Maia3 is estimating likely human choices for each move.':
        'Maia3 מעריך אילו מהלכים אנשים צפויים לבחור בכל מצב.',
    'Mandarin': 'מנדרינית',
    'Max games': 'מספר משחקים מרבי',
    'Member discount': 'הנחת חבר',
    'Message status could not be updated. Please try again.':
        'לא ניתן לעדכן את מצב ההודעה. יש לנסות שוב.',
    'More filters': 'מסננים נוספים',
    'Move board did not accept the command.': 'לוח Move לא קיבל את הפקודה.',
    'Move board did not accept the reset command.':
        'לוח Move לא קיבל את פקודת האיפוס.',
    'Move board reset to the standard starting position.':
        'לוח Move אופס לעמדת הפתיחה הרגילה.',
    'Move control can be changed': 'ניתן לשנות את בקרת המהלכים',
    'Move likelihood': 'הסתברות המהלך',
    'Moves by rating': 'מהלכים לפי דירוג',
    'My personal engine': 'המנוע האישי שלי',
    'Network issue': 'בעיית רשת',
    'New personal engine': 'מנוע אישי חדש',
    'No PGN available for this record.': 'אין PGN זמין לרשומה זו.',
    'No active themes': 'אין ערכות נושא פעילות',
    'No finished game with playable moves is available yet.':
        'עדיין אין משחק שהסתיים עם מהלכים שניתנים להפעלה.',
    'No games loaded for this page.': 'לא נטענו משחקים בדף זה.',
    'No moves yet': 'עדיין אין מהלכים',
    'No personal engines yet': 'עדיין אין מנועים אישיים',
    'No review mistakes yet': 'עדיין אין טעויות לסקירה',
    'No usable PGN games matched this Lichess player and filters.':
        'לא נמצאו משחקי PGN תקינים התואמים לשחקן Lichess ולמסננים.',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Maia הרשמי יכול להשוות מהלכים בין רמות דירוג. תצוגת הנייד מציגה את המודל הנבחר בצורה קומפקטית.',
    'Open': 'פתיחה',
    'Open Google Play': 'פתיחת Google Play',
    'Open source code': 'פתיחת קוד המקור',
    'Open store': 'פתיחת החנות',
    'Open-source notices': 'מידע על קוד פתוח',
    'Opponent move mode': 'מצב מהלך היריב',
    'Optional date or text': 'תאריך או טקסט לבחירה',
    'Original cost': 'עלות מקורית',
    'PGN refreshed.': 'ה-PGN עודכן.',
    'Password cannot be empty.': 'הסיסמה אינה יכולה להיות ריקה.',
    'Password reset successfully.': 'הסיסמה אופסה בהצלחה.',
    'Pay today': 'תשלום היום',
    'Personal engine deleted.': 'המנוע האישי נמחק.',
    'Pieces are ready': 'הכלים מוכנים',
    'Place all 34 pieces exactly as shown before pairing.':
        'לפני הצימוד יש להציב את כל 34 הכלים בדיוק כפי שמוצג.',
    'Play style': 'סגנון משחק',
    'Playable engine library': 'ספריית מנועים למשחק',
    'Player ID': 'מזהה שחקן',
    'Please agree to the Terms of Use and Privacy Policy.':
        'יש לאשר את תנאי השימוש ואת מדיניות הפרטיות.',
    'Premium active / Grandeur and personal engine training unlimited':
        'Premium פעיל / Grandeur ואימון מנוע אישי ללא הגבלה',
    'Premium is active.': 'Premium פעיל.',
    'Preparing insight': 'הניתוח בהכנה',
    'Preparing lesson': 'השיעור בהכנה',
    'Press clock switch': 'לחיצה על מתג השעון',
    'Preview Lichess games before starting training.':
        'יש לצפות במשחקי Lichess לפני תחילת האימון.',
    'Profile update failed. Check your connection and try again.':
        'עדכון הפרופיל נכשל. יש לבדוק את החיבור ולנסות שוב.',
    'Progress synced. Keep the streak moving.':
        'ההתקדמות סונכרנה. כדאי להמשיך את הרצף.',
    'Purchase was not completed. You can try again when ready.':
        'הרכישה לא הושלמה. ניתן לנסות שוב כשנוח.',
    'Rated and casual': 'מדורגים ולא מדורגים',
    'Rated only': 'מדורגים בלבד',
    'Remind me in 1 day': 'תזכורת בעוד יום',
    'Remove': 'הסרה',
    'Remove piece set?': 'להסיר את ערכת הכלים?',
    'Removed pieces need to be paired again before they can be used.':
        'יש לצמד מחדש כלים שהוסרו לפני השימוש בהם.',
    'Replay': 'הפעלה חוזרת',
    'Replay guides': 'הצגת המדריכים שוב',
    'Report': 'דוח',
    'Report image ready to share.': 'תמונת הדוח מוכנה לשיתוף.',
    'Reset both clocks and start over.': 'איפוס שני השעונים והתחלה מחדש.',
    'Reset clock?': 'לאפס את השעון?',
    'Resign and exit': 'כניעה ויציאה',
    'Restore purchase': 'שחזור רכישה',
    'Resume': 'המשך',
    'Retry': 'ניסיון חוזר',
    'Review settings': 'הגדרות סקירה',
    'Select': 'בחירה',
    'Select page': 'בחירת הדף',
    'Set LEFT': 'הגדרת שמאל',
    'Set RIGHT': 'הגדרת ימין',
    'Show all guides next time': 'הצגת כל המדריכים בפעם הבאה',
    'Show human likelihood next to the engine verdict.':
        'הצגת ההסתברות לבחירה אנושית לצד הערכת המנוע.',
    'Shutdown mode': 'מצב כיבוי',
    'Shutdown mode sent.': 'פקודת מצב הכיבוי נשלחה.',
    'Sign in before starting Career Mode.': 'יש להתחבר לפני התחלת מצב הקריירה.',
    'Sign in did not finish. Please try again.':
        'ההתחברות לא הושלמה. יש לנסות שוב.',
    'Sign in to sync points and profile.':
        'יש להתחבר כדי לסנכרן נקודות ופרופיל.',
    'Since': 'מאז',
    'Skip': 'דילוג',
    'Start': 'התחלה',
    'Start import': 'התחלת ייבוא',
    'Start pairing': 'התחלת צימוד',
    'Submitting selected games for personal engine training...':
        'המשחקים שנבחרו נשלחים לאימון המנוע האישי...',
    'Switch account': 'החלפת חשבון',
    'Tactical depth': 'עומק טקטי',
    'Tap a move to jump back to the board.':
        'יש להקיש על מהלך כדי לחזור לעמדה המתאימה בלוח.',
    'Tap to view details': 'הקשה להצגת פרטים',
    'Target Elo': 'Elo יעד',
    'The PGN is still loading. Try again shortly.':
        'ה-PGN עדיין נטען. יש לנסות שוב בעוד רגע.',
    'The new set has been paired and saved to this channel.':
        'הערכה החדשה צומדה ונשמרה בערוץ זה.',
    'The selected PGN file is empty.': 'קובץ ה-PGN שנבחר ריק.',
    'Theme not available yet': 'ערכת הנושא עדיין אינה זמינה',
    'This LC0 engine is not ready to download yet.':
        'מנוע LC0 זה עדיין אינו מוכן להורדה.',
    'This PGN could not be read. Check the PGN file and try again.':
        'לא ניתן לקרוא את ה-PGN. יש לבדוק את הקובץ ולנסות שוב.',
    'This PGN could not be read. Check the move list and try again.':
        'לא ניתן לקרוא את ה-PGN. יש לבדוק את רשימת המהלכים ולנסות שוב.',
    'This PGN includes a move Chessnut cannot read. Check the move list and try again.':
        'ה-PGN כולל מהלך ש-Chessnut אינו יכול לקרוא. יש לבדוק את רשימת המהלכים.',
    'This engine cannot be liked yet.': 'עדיין לא ניתן לסמן מנוע זה כמועדף.',
    'This game ended before any playable moves, so there is no position to analyze.':
        'המשחק הסתיים לפני מהלך שניתן להפעלה, ולכן אין עמדה לניתוח.',
    'This personal engine cannot be renamed yet.':
        'עדיין לא ניתן לשנות את שם המנוע האישי.',
    'This personal engine does not have a weight file yet.':
        'למנוע האישי עדיין אין קובץ משקלים.',
    'This personal engine is still training.': 'המנוע האישי עדיין באימון.',
    'This update will be handled by Google Play on this device.':
        'Google Play יטפל בעדכון במכשיר זה.',
    'This update will open in your browser.': 'העדכון ייפתח בדפדפן.',
    'This update will open the Chessnut page on Google Play.':
        'דף Chessnut ב-Google Play ייפתח.',
    'This update will open the official Chessnut download page.':
        'דף ההורדה הרשמי של Chessnut ייפתח.',
    'This update will open the official app store or test track for your device.':
        'החנות הרשמית או מסלול הבדיקה של המכשיר ייפתחו.',
    'This version is required to keep Chessnut working correctly. Please update before continuing.':
        'גרסה זו נדרשת לפעולה תקינה של Chessnut. יש לעדכן לפני ההמשך.',
    'Time': 'זמן',
    'Training modes': 'מצבי אימון',
    'Turn on': 'הפעלה',
    'Turn on shutdown mode?': 'להפעיל מצב כיבוי?',
    'USB Clock Test': 'בדיקת שעון USB',
    'Unable to check Lichess authorization. Please try again.':
        'לא ניתן לבדוק את הרשאת Lichess. יש לנסות שוב.',
    'Unable to delete this personal engine. Try again later.':
        'לא ניתן למחוק את המנוע האישי. יש לנסות מאוחר יותר.',
    'Unable to download Grandeur report.': 'לא ניתן להוריד את דוח Grandeur.',
    'Unable to download this LC0 engine. Check your connection and try again.':
        'לא ניתן להוריד את מנוע LC0. יש לבדוק את החיבור ולנסות שוב.',
    'Unable to download this personal engine. Check your connection and try again.':
        'לא ניתן להוריד את המנוע האישי. יש לבדוק את החיבור ולנסות שוב.',
    'Unable to end this game record.': 'לא ניתן לסיים את רשומת המשחק.',
    'Unable to load the matched Game Record preview.':
        'לא ניתן לטעון את תצוגת הרשומות המתאימות.',
    'Unable to open this PGN file. Choose another file and try again.':
        'לא ניתן לפתוח את קובץ ה-PGN. יש לבחור קובץ אחר ולנסות שוב.',
    'Unable to pair pieces': 'לא ניתן לצמד את הכלים',
    'Unable to refresh this PGN.': 'לא ניתן לרענן את ה-PGN.',
    'Unable to send command.': 'לא ניתן לשלוח את הפקודה.',
    'Unable to share report image.': 'לא ניתן לשתף את תמונת הדוח.',
    'Unable to start personal engine training.':
        'לא ניתן להתחיל את אימון המנוע האישי.',
    'Unable to switch to this account.': 'לא ניתן לעבור לחשבון זה.',
    'Unable to update like. Try again later.':
        'לא ניתן לעדכן את המועדף. יש לנסות מאוחר יותר.',
    'Unable to update this engine name. Try again later.':
        'לא ניתן לעדכן את שם המנוע. יש לנסות מאוחר יותר.',
    'Unable to update this engine. Try again later.':
        'לא ניתן לעדכן את המנוע. יש לנסות מאוחר יותר.',
    'Unable to update this personal engine. Check your connection and try again.':
        'לא ניתן לעדכן את המנוע האישי. יש לבדוק את החיבור ולנסות שוב.',
    'Unlink Lichess': 'ניתוק Lichess',
    'Until': 'עד',
    'Update available': 'עדכון זמין',
    'Update link is not available right now. Please try again later.':
        'קישור העדכון אינו זמין כרגע. יש לנסות מאוחר יותר.',
    'Update now': 'עדכון עכשיו',
    'Update required': 'נדרש עדכון',
    'Update with Google Play': 'עדכון דרך Google Play',
    'Use another saved Chessnut ID': 'שימוש ב-Chessnut ID שמור אחר',
    'Use selected': 'שימוש בפריטים שנבחרו',
    'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.':
        'מיועד לאחסון ממושך. יש להניח את הכלים על לוח הטעינה לפני שימוש חוזר.',
    'Use this model': 'שימוש במודל זה',
    'Use this position': 'שימוש בעמדה זו',
    'VIP member': 'חבר VIP',
    'Valid until': 'בתוקף עד',
    'Verification code cannot be empty.': 'קוד האימות אינו יכול להיות ריק.',
    'Verification code required': 'נדרש קוד אימות',
    'Verification could not open in the app':
        'לא ניתן לפתוח את האימות באפליקציה',
    'View first-time tips again': 'הצגת טיפים ראשוניים שוב',
    'Voice moves': 'מהלכים קוליים',
    'Waiting for piece status': 'בהמתנה למצב הכלים',
    'Wallet test tools are unavailable.': 'כלי בדיקת הארנק אינם זמינים.',
    'White games': 'משחקים בלבן',
    'You are using the latest version.': 'נעשה שימוש בגרסה העדכנית ביותר.',
    'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.':
        'חשבון Chessnut כבר מחובר ל-Lichess. ניתן להשאיר את החיבור או לנתק אותו כדי לאשר חשבון Lichess אחר.',
    'no legal mainline moves': 'אין מהלכים חוקיים בקו הראשי',
    'points': 'נקודות',
    'pts': 'נק׳',
    'sec': 'שנ׳',
  },
};
