// Manual recent-feature translations that have not gone through the full
// visible-string generation pipeline yet.

String? recentFeatureTranslation(String text, String key) {
  return _localGameStringMaps[key]?[text] ??
      _recordImportFlowTranslation(text, key) ??
      _boardAnalyzerDepthTranslation(text, key) ??
      _gameRecordPgnStringMaps[key]?[text] ??
      _evo2SettingStringMaps[key]?[text] ??
      _iosGameHeaderStringMaps[key]?[text] ??
      _mistakeBookStringMaps[key]?[text] ??
      _puzzleIdStringMaps[key]?[text] ??
      _puzzleThemeStringMaps[key]?[text] ??
      _maia3ReviewHelpStringMaps[key]?[text] ??
      _moduleGuideStringMaps[key]?[text] ??
      _recentFeatureStringMaps[key]?[text];
}

String? _recordImportFlowTranslation(String text, String key) {
  final direct = _recordImportFlowStringMaps[key]?[text];
  if (direct != null) return direct;
  final previousLimitText = switch (text) {
    'Up to 500 games per import.' => 'Up to 50 games per import.',
    'You can import up to 500 games at a time.' =>
      'You can import up to 50 games at a time.',
    'Enter a number from 1 to 500.' => 'Enter a number from 1 to 50.',
    _ => null,
  };
  if (previousLimitText == null) return null;
  return _recordImportFlowStringMaps[key]?[previousLimitText]
      ?.replaceAll('50', '500');
}

const _recordImportFlowStringMaps = <String, Map<String, String>>{
  'zh-Hans': {
    'Import records': '导入记录',
    'Up to 50 games per import.': '每次最多导入 50 局。',
    'Selected {selected} of {total}': '已选择 {selected}/{total}',
    'You can import up to 50 games at a time.': '每次最多可导入 50 局。',
    'Clear all': '取消全选',
    'Select all': '全选',
    'Import selected games': '导入所选棋局',
    'Fetch games': '获取棋局',
    'Imported {count} games.': '已导入 {count} 局。',
    'Enter a number from 1 to 50.': '请输入 1 到 50 之间的数字。',
    'No finished games found.': '未找到已结束的棋局。',
    'Choose at least one game.': '请至少选择一局棋。',
    'Unable to import selected games.': '无法导入所选棋局。',
    'The start date must not be after the end date.': '开始日期不能晚于结束日期。',
    'Use YYYY-MM-DD for date filters.': '日期筛选请使用 YYYY-MM-DD 格式。',
  },
  'zh-Hant': {
    'Import records': '匯入記錄',
    'Up to 50 games per import.': '每次最多匯入 50 局。',
    'Selected {selected} of {total}': '已選擇 {selected}/{total}',
    'You can import up to 50 games at a time.': '每次最多可匯入 50 局。',
    'Clear all': '取消全選',
    'Select all': '全選',
    'Import selected games': '匯入所選棋局',
    'Fetch games': '取得棋局',
    'Imported {count} games.': '已匯入 {count} 局。',
    'Enter a number from 1 to 50.': '請輸入 1 到 50 之間的數字。',
    'No finished games found.': '找不到已結束的棋局。',
    'Choose at least one game.': '請至少選擇一局棋。',
    'Unable to import selected games.': '無法匯入所選棋局。',
    'The start date must not be after the end date.': '開始日期不能晚於結束日期。',
    'Use YYYY-MM-DD for date filters.': '日期篩選請使用 YYYY-MM-DD 格式。',
  },
  'ja': {
    'Import records': '棋譜をインポート',
    'Up to 50 games per import.': '1 回につき最大 50 局です。',
    'Selected {selected} of {total}': '{total} 局中 {selected} 局を選択',
    'You can import up to 50 games at a time.': '一度に最大 50 局までインポートできます。',
    'Clear all': 'すべて解除',
    'Select all': 'すべて選択',
    'Import selected games': '選択した対局をインポート',
    'Fetch games': '対局を取得',
    'Imported {count} games.': '{count} 局をインポートしました。',
    'Enter a number from 1 to 50.': '1 から 50 までの数値を入力してください。',
    'No finished games found.': '終了した対局が見つかりません。',
    'Choose at least one game.': '少なくとも 1 局選択してください。',
    'Unable to import selected games.': '選択した対局をインポートできません。',
    'The start date must not be after the end date.': '開始日は終了日より後にできません。',
    'Use YYYY-MM-DD for date filters.': '日付は YYYY-MM-DD 形式で入力してください。',
  },
  'ko': {
    'Import records': '기보 가져오기',
    'Up to 50 games per import.': '한 번에 최대 50국까지 가져올 수 있습니다.',
    'Selected {selected} of {total}': '{total}개 중 {selected}개 선택',
    'You can import up to 50 games at a time.': '한 번에 최대 50국까지 가져올 수 있습니다.',
    'Clear all': '모두 해제',
    'Select all': '모두 선택',
    'Import selected games': '선택한 대국 가져오기',
    'Fetch games': '대국 가져오기',
    'Imported {count} games.': '{count}국을 가져왔습니다.',
    'Enter a number from 1 to 50.': '1에서 50 사이의 숫자를 입력하세요.',
    'No finished games found.': '종료된 대국을 찾지 못했습니다.',
    'Choose at least one game.': '대국을 하나 이상 선택하세요.',
    'Unable to import selected games.': '선택한 대국을 가져올 수 없습니다.',
    'The start date must not be after the end date.':
        '시작 날짜는 종료 날짜보다 늦을 수 없습니다.',
    'Use YYYY-MM-DD for date filters.': '날짜 필터에는 YYYY-MM-DD 형식을 사용하세요.',
  },
  'de': {
    'Import records': 'Partien importieren',
    'Up to 50 games per import.': 'Bis zu 50 Partien pro Import.',
    'Selected {selected} of {total}': '{selected} von {total} ausgewählt',
    'You can import up to 50 games at a time.':
        'Sie können bis zu 50 Partien gleichzeitig importieren.',
    'Clear all': 'Auswahl aufheben',
    'Select all': 'Alle auswählen',
    'Import selected games': 'Ausgewählte Partien importieren',
    'Fetch games': 'Partien abrufen',
    'Imported {count} games.': '{count} Partien importiert.',
    'Enter a number from 1 to 50.': 'Geben Sie eine Zahl von 1 bis 50 ein.',
    'No finished games found.': 'Keine beendeten Partien gefunden.',
    'Choose at least one game.': 'Wählen Sie mindestens eine Partie aus.',
    'Unable to import selected games.':
        'Die ausgewählten Partien konnten nicht importiert werden.',
    'The start date must not be after the end date.':
        'Das Startdatum darf nicht nach dem Enddatum liegen.',
    'Use YYYY-MM-DD for date filters.':
        'Verwenden Sie für Datumsfilter YYYY-MM-DD.',
  },
  'fr': {
    'Import records': 'Importer des parties',
    'Up to 50 games per import.': 'Jusqu’à 50 parties par import.',
    'Selected {selected} of {total}': '{selected} sur {total} sélectionnées',
    'You can import up to 50 games at a time.':
        'Vous pouvez importer jusqu’à 50 parties à la fois.',
    'Clear all': 'Tout désélectionner',
    'Select all': 'Tout sélectionner',
    'Import selected games': 'Importer les parties sélectionnées',
    'Fetch games': 'Récupérer les parties',
    'Imported {count} games.': '{count} parties importées.',
    'Enter a number from 1 to 50.': 'Saisissez un nombre de 1 à 50.',
    'No finished games found.': 'Aucune partie terminée trouvée.',
    'Choose at least one game.': 'Sélectionnez au moins une partie.',
    'Unable to import selected games.':
        'Impossible d’importer les parties sélectionnées.',
    'The start date must not be after the end date.':
        'La date de début ne peut pas être postérieure à la date de fin.',
    'Use YYYY-MM-DD for date filters.':
        'Utilisez le format YYYY-MM-DD pour les dates.',
  },
  'es': {
    'Import records': 'Importar partidas',
    'Up to 50 games per import.': 'Hasta 50 partidas por importación.',
    'Selected {selected} of {total}': '{selected} de {total} seleccionadas',
    'You can import up to 50 games at a time.':
        'Puedes importar hasta 50 partidas a la vez.',
    'Clear all': 'Borrar selección',
    'Select all': 'Seleccionar todo',
    'Import selected games': 'Importar partidas seleccionadas',
    'Fetch games': 'Obtener partidas',
    'Imported {count} games.': 'Se importaron {count} partidas.',
    'Enter a number from 1 to 50.': 'Introduce un número del 1 al 50.',
    'No finished games found.': 'No se encontraron partidas terminadas.',
    'Choose at least one game.': 'Selecciona al menos una partida.',
    'Unable to import selected games.':
        'No se pudieron importar las partidas seleccionadas.',
    'The start date must not be after the end date.':
        'La fecha inicial no puede ser posterior a la final.',
    'Use YYYY-MM-DD for date filters.':
        'Usa YYYY-MM-DD para filtrar por fecha.',
  },
  'it': {
    'Import records': 'Importa partite',
    'Up to 50 games per import.': 'Fino a 50 partite per importazione.',
    'Selected {selected} of {total}': '{selected} di {total} selezionate',
    'You can import up to 50 games at a time.':
        'Puoi importare fino a 50 partite alla volta.',
    'Clear all': 'Deseleziona tutto',
    'Select all': 'Seleziona tutto',
    'Import selected games': 'Importa le partite selezionate',
    'Fetch games': 'Recupera partite',
    'Imported {count} games.': 'Importate {count} partite.',
    'Enter a number from 1 to 50.': 'Inserisci un numero da 1 a 50.',
    'No finished games found.': 'Nessuna partita conclusa trovata.',
    'Choose at least one game.': 'Seleziona almeno una partita.',
    'Unable to import selected games.':
        'Impossibile importare le partite selezionate.',
    'The start date must not be after the end date.':
        'La data iniziale non può essere successiva a quella finale.',
    'Use YYYY-MM-DD for date filters.': 'Usa YYYY-MM-DD per i filtri data.',
  },
  'nl': {
    'Import records': 'Partijen importeren',
    'Up to 50 games per import.': 'Maximaal 50 partijen per import.',
    'Selected {selected} of {total}': '{selected} van {total} geselecteerd',
    'You can import up to 50 games at a time.':
        'U kunt maximaal 50 partijen tegelijk importeren.',
    'Clear all': 'Alles deselecteren',
    'Select all': 'Alles selecteren',
    'Import selected games': 'Geselecteerde partijen importeren',
    'Fetch games': 'Partijen ophalen',
    'Imported {count} games.': '{count} partijen geïmporteerd.',
    'Enter a number from 1 to 50.': 'Voer een getal van 1 tot 50 in.',
    'No finished games found.': 'Geen voltooide partijen gevonden.',
    'Choose at least one game.': 'Selecteer ten minste één partij.',
    'Unable to import selected games.':
        'De geselecteerde partijen konden niet worden geïmporteerd.',
    'The start date must not be after the end date.':
        'De begindatum mag niet na de einddatum liggen.',
    'Use YYYY-MM-DD for date filters.': 'Gebruik YYYY-MM-DD voor datumfilters.',
  },
  'ru': {
    'Import records': 'Импорт партий',
    'Up to 50 games per import.': 'До 50 партий за один импорт.',
    'Selected {selected} of {total}': 'Выбрано {selected} из {total}',
    'You can import up to 50 games at a time.':
        'За один раз можно импортировать до 50 партий.',
    'Clear all': 'Снять выбор',
    'Select all': 'Выбрать все',
    'Import selected games': 'Импортировать выбранные партии',
    'Fetch games': 'Получить партии',
    'Imported {count} games.': 'Импортировано партий: {count}.',
    'Enter a number from 1 to 50.': 'Введите число от 1 до 50.',
    'No finished games found.': 'Завершённые партии не найдены.',
    'Choose at least one game.': 'Выберите хотя бы одну партию.',
    'Unable to import selected games.':
        'Не удалось импортировать выбранные партии.',
    'The start date must not be after the end date.':
        'Дата начала не должна быть позже даты окончания.',
    'Use YYYY-MM-DD for date filters.':
        'Используйте формат YYYY-MM-DD для дат.',
  },
  'pt': {
    'Import records': 'Importar partidas',
    'Up to 50 games per import.': 'Até 50 partidas por importação.',
    'Selected {selected} of {total}': '{selected} de {total} selecionadas',
    'You can import up to 50 games at a time.':
        'Você pode importar até 50 partidas por vez.',
    'Clear all': 'Limpar seleção',
    'Select all': 'Selecionar tudo',
    'Import selected games': 'Importar partidas selecionadas',
    'Fetch games': 'Buscar partidas',
    'Imported {count} games.': '{count} partidas importadas.',
    'Enter a number from 1 to 50.': 'Digite um número de 1 a 50.',
    'No finished games found.': 'Nenhuma partida concluída encontrada.',
    'Choose at least one game.': 'Selecione pelo menos uma partida.',
    'Unable to import selected games.':
        'Não foi possível importar as partidas selecionadas.',
    'The start date must not be after the end date.':
        'A data inicial não pode ser posterior à final.',
    'Use YYYY-MM-DD for date filters.': 'Use YYYY-MM-DD nos filtros de data.',
  },
  'pl': {
    'Import records': 'Importuj partie',
    'Up to 50 games per import.': 'Do 50 partii na import.',
    'Selected {selected} of {total}': 'Wybrano {selected} z {total}',
    'You can import up to 50 games at a time.':
        'Jednocześnie można zaimportować do 50 partii.',
    'Clear all': 'Wyczyść wybór',
    'Select all': 'Zaznacz wszystko',
    'Import selected games': 'Importuj wybrane partie',
    'Fetch games': 'Pobierz partie',
    'Imported {count} games.': 'Zaimportowano {count} partii.',
    'Enter a number from 1 to 50.': 'Wpisz liczbę od 1 do 50.',
    'No finished games found.': 'Nie znaleziono zakończonych partii.',
    'Choose at least one game.': 'Wybierz co najmniej jedną partię.',
    'Unable to import selected games.':
        'Nie udało się zaimportować wybranych partii.',
    'The start date must not be after the end date.':
        'Data początkowa nie może być późniejsza niż końcowa.',
    'Use YYYY-MM-DD for date filters.': 'Użyj formatu YYYY-MM-DD dla dat.',
  },
  'ro': {
    'Import records': 'Importă partide',
    'Up to 50 games per import.': 'Până la 50 de partide per import.',
    'Selected {selected} of {total}': '{selected} din {total} selectate',
    'You can import up to 50 games at a time.':
        'Poți importa până la 50 de partide odată.',
    'Clear all': 'Șterge selecția',
    'Select all': 'Selectează tot',
    'Import selected games': 'Importă partidele selectate',
    'Fetch games': 'Preia partidele',
    'Imported {count} games.': 'Au fost importate {count} partide.',
    'Enter a number from 1 to 50.': 'Introdu un număr de la 1 la 50.',
    'No finished games found.': 'Nu s-au găsit partide încheiate.',
    'Choose at least one game.': 'Selectează cel puțin o partidă.',
    'Unable to import selected games.':
        'Partidele selectate nu au putut fi importate.',
    'The start date must not be after the end date.':
        'Data de început nu poate fi după data de sfârșit.',
    'Use YYYY-MM-DD for date filters.':
        'Folosește YYYY-MM-DD pentru filtrele de dată.',
  },
  'cs': {
    'Import records': 'Importovat partie',
    'Up to 50 games per import.': 'Nejvýše 50 partií na jeden import.',
    'Selected {selected} of {total}': 'Vybráno {selected} z {total}',
    'You can import up to 50 games at a time.':
        'Najednou lze importovat až 50 partií.',
    'Clear all': 'Zrušit výběr',
    'Select all': 'Vybrat vše',
    'Import selected games': 'Importovat vybrané partie',
    'Fetch games': 'Načíst partie',
    'Imported {count} games.': 'Importováno {count} partií.',
    'Enter a number from 1 to 50.': 'Zadejte číslo od 1 do 50.',
    'No finished games found.': 'Nebyly nalezeny žádné dokončené partie.',
    'Choose at least one game.': 'Vyberte alespoň jednu partii.',
    'Unable to import selected games.':
        'Vybrané partie se nepodařilo importovat.',
    'The start date must not be after the end date.':
        'Počáteční datum nesmí být po koncovém datu.',
    'Use YYYY-MM-DD for date filters.': 'Pro datum použijte formát YYYY-MM-DD.',
  },
  'ar': {
    'Import records': 'استيراد المباريات',
    'Up to 50 games per import.': 'حتى 50 مباراة لكل عملية استيراد.',
    'Selected {selected} of {total}': 'تم تحديد {selected} من {total}',
    'You can import up to 50 games at a time.':
        'يمكنك استيراد ما يصل إلى 50 مباراة في المرة الواحدة.',
    'Clear all': 'إلغاء تحديد الكل',
    'Select all': 'تحديد الكل',
    'Import selected games': 'استيراد المباريات المحددة',
    'Fetch games': 'جلب المباريات',
    'Imported {count} games.': 'تم استيراد {count} مباراة.',
    'Enter a number from 1 to 50.': 'أدخل رقماً من 1 إلى 50.',
    'No finished games found.': 'لم يتم العثور على مباريات منتهية.',
    'Choose at least one game.': 'حدد مباراة واحدة على الأقل.',
    'Unable to import selected games.': 'تعذر استيراد المباريات المحددة.',
    'The start date must not be after the end date.':
        'يجب ألا يكون تاريخ البدء بعد تاريخ الانتهاء.',
    'Use YYYY-MM-DD for date filters.': 'استخدم YYYY-MM-DD لتصفية التاريخ.',
  },
  'he': {
    'Import records': 'ייבוא משחקים',
    'Up to 50 games per import.': 'עד 50 משחקים בכל ייבוא.',
    'Selected {selected} of {total}': 'נבחרו {selected} מתוך {total}',
    'You can import up to 50 games at a time.':
        'ניתן לייבא עד 50 משחקים בכל פעם.',
    'Clear all': 'נקה בחירה',
    'Select all': 'בחר הכול',
    'Import selected games': 'ייבא משחקים שנבחרו',
    'Fetch games': 'טען משחקים',
    'Imported {count} games.': 'יובאו {count} משחקים.',
    'Enter a number from 1 to 50.': 'יש להזין מספר בין 1 ל-50.',
    'No finished games found.': 'לא נמצאו משחקים שהסתיימו.',
    'Choose at least one game.': 'יש לבחור לפחות משחק אחד.',
    'Unable to import selected games.': 'לא ניתן לייבא את המשחקים שנבחרו.',
    'The start date must not be after the end date.':
        'תאריך ההתחלה לא יכול להיות אחרי תאריך הסיום.',
    'Use YYYY-MM-DD for date filters.':
        'יש להשתמש ב-YYYY-MM-DD לסינון תאריכים.',
  },
};

String? _boardAnalyzerDepthTranslation(String text, String key) {
  final direct = _boardAnalyzerDepthStringMaps[key]?[text];
  if (direct != null) return direct;

  final thinking = RegExp(
    r'^Stockfish is still thinking at depth (\d+)\.$',
  ).firstMatch(text);
  if (thinking != null) {
    final depth = thinking.group(1)!;
    return switch (key) {
      'zh-Hans' => 'Stockfish 仍在思考，当前深度为 $depth。',
      'zh-Hant' => 'Stockfish 仍在思考，目前深度為 $depth。',
      'de' => 'Stockfish rechnet auf Tiefe $depth weiter.',
      'es' => 'Stockfish sigue calculando en la profundidad $depth.',
      'fr' => 'Stockfish poursuit son calcul à la profondeur $depth.',
      'it' => 'Stockfish continua a calcolare alla profondità $depth.',
      'ja' => 'Stockfish は深さ $depth で思考を続けています。',
      'ko' => 'Stockfish가 깊이 $depth에서 계속 계산하고 있습니다.',
      'nl' => 'Stockfish rekent verder op diepte $depth.',
      'ru' => 'Stockfish продолжает расчёт на глубине $depth.',
      'pt' => 'O Stockfish continua calculando na profundidade $depth.',
      'pl' => 'Stockfish nadal liczy na głębokości $depth.',
      'ro' => 'Stockfish continuă calculul la adâncimea $depth.',
      'cs' => 'Stockfish pokračuje ve výpočtu v hloubce $depth.',
      'ar' => 'يواصل Stockfish الحساب عند العمق $depth.',
      'he' => 'Stockfish ממשיך לחשב בעומק $depth.',
      _ => null,
    };
  }

  final selected = RegExp(
    r'^Analysis depth (\d+) selected\.$',
  ).firstMatch(text);
  if (selected != null) {
    final depth = selected.group(1)!;
    return switch (key) {
      'zh-Hans' => '已选择分析深度 $depth。',
      'zh-Hant' => '已選擇分析深度 $depth。',
      'de' => 'Analysetiefe $depth ausgewählt.',
      'es' => 'Profundidad de análisis $depth seleccionada.',
      'fr' => 'Profondeur d’analyse $depth sélectionnée.',
      'it' => 'Profondità di analisi $depth selezionata.',
      'ja' => '解析の深さ $depth を選択しました。',
      'ko' => '분석 깊이 $depth을(를) 선택했습니다.',
      'nl' => 'Analysediepte $depth geselecteerd.',
      'ru' => 'Выбрана глубина анализа $depth.',
      'pt' => 'Profundidade de análise $depth selecionada.',
      'pl' => 'Wybrano głębokość analizy $depth.',
      'ro' => 'A fost selectată adâncimea de analiză $depth.',
      'cs' => 'Byla vybrána hloubka analýzy $depth.',
      'ar' => 'تم تحديد عمق التحليل $depth.',
      'he' => 'נבחר עומק ניתוח $depth.',
      _ => null,
    };
  }
  return null;
}

const _boardAnalyzerDepthStringMaps = <String, Map<String, String>>{
  'zh-Hans': <String, String>{
    'Stockfish is evaluating the current board.': 'Stockfish 正在评估当前棋盘。',
    'Stockfish is analyzing without a depth limit.': 'Stockfish 正在进行无限深度分析。',
    'Stockfish live analysis ready.': 'Stockfish 实时分析已就绪。',
    'Lightweight analysis ready.': '轻量分析已就绪。',
    'Stockfish is not available here. Check engine files or try another platform.':
        '此处无法使用 Stockfish。请检查引擎文件，或尝试其他平台。',
    'Unlimited analysis selected.': '已选择无限深度分析。',
  },
  'zh-Hant': <String, String>{
    'Stockfish is evaluating the current board.': 'Stockfish 正在評估目前棋盤。',
    'Stockfish is analyzing without a depth limit.': 'Stockfish 正在進行無限深度分析。',
    'Stockfish live analysis ready.': 'Stockfish 即時分析已就緒。',
    'Lightweight analysis ready.': '輕量分析已就緒。',
    'Stockfish is not available here. Check engine files or try another platform.':
        '此處無法使用 Stockfish。請檢查引擎檔案，或嘗試其他平台。',
    'Unlimited analysis selected.': '已選擇無限深度分析。',
  },
  'de': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish bewertet die aktuelle Stellung.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish analysiert ohne Tiefenbegrenzung.',
    'Stockfish live analysis ready.': 'Stockfish-Liveanalyse ist bereit.',
    'Lightweight analysis ready.': 'Leichtgewichtige Analyse ist bereit.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish ist hier nicht verfügbar. Prüfe die Engine-Dateien oder versuche eine andere Plattform.',
    'Unlimited analysis selected.': 'Unbegrenzte Analyse ausgewählt.',
  },
  'es': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish está evaluando el tablero actual.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish está analizando sin límite de profundidad.',
    'Stockfish live analysis ready.':
        'El análisis en vivo de Stockfish está listo.',
    'Lightweight analysis ready.': 'El análisis ligero está listo.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish no está disponible aquí. Comprueba los archivos del motor o prueba otra plataforma.',
    'Unlimited analysis selected.': 'Análisis sin límite seleccionado.',
  },
  'fr': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish évalue la position actuelle.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish analyse sans limite de profondeur.',
    'Stockfish live analysis ready.':
        'L’analyse en direct de Stockfish est prête.',
    'Lightweight analysis ready.': 'L’analyse légère est prête.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish n’est pas disponible ici. Vérifiez les fichiers du moteur ou essayez une autre plateforme.',
    'Unlimited analysis selected.': 'Analyse sans limite sélectionnée.',
  },
  'it': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish sta valutando la posizione attuale.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish sta analizzando senza limite di profondità.',
    'Stockfish live analysis ready.': 'L’analisi live di Stockfish è pronta.',
    'Lightweight analysis ready.': 'L’analisi leggera è pronta.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish non è disponibile qui. Controlla i file del motore o prova un’altra piattaforma.',
    'Unlimited analysis selected.': 'Analisi senza limiti selezionata.',
  },
  'ja': <String, String>{
    'Stockfish is evaluating the current board.': 'Stockfish が現在の局面を評価しています。',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish は深さの制限なしで解析しています。',
    'Stockfish live analysis ready.': 'Stockfish のライブ解析の準備ができました。',
    'Lightweight analysis ready.': '簡易解析の準備ができました。',
    'Stockfish is not available here. Check engine files or try another platform.':
        'ここでは Stockfish を利用できません。エンジンファイルを確認するか、別のプラットフォームをお試しください。',
    'Unlimited analysis selected.': '無制限解析を選択しました。',
  },
  'ko': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish가 현재 보드를 평가하고 있습니다.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish가 깊이 제한 없이 분석하고 있습니다.',
    'Stockfish live analysis ready.': 'Stockfish 실시간 분석이 준비되었습니다.',
    'Lightweight analysis ready.': '간단한 분석이 준비되었습니다.',
    'Stockfish is not available here. Check engine files or try another platform.':
        '이곳에서는 Stockfish를 사용할 수 없습니다. 엔진 파일을 확인하거나 다른 플랫폼을 사용해 보세요.',
    'Unlimited analysis selected.': '무제한 분석을 선택했습니다.',
  },
  'nl': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish beoordeelt het huidige bord.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish analyseert zonder dieptelimiet.',
    'Stockfish live analysis ready.': 'Stockfish-liveanalyse is klaar.',
    'Lightweight analysis ready.': 'Lichte analyse is klaar.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish is hier niet beschikbaar. Controleer de enginebestanden of probeer een ander platform.',
    'Unlimited analysis selected.': 'Onbegrensde analyse geselecteerd.',
  },
  'ru': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish оценивает текущую позицию.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish анализирует без ограничения глубины.',
    'Stockfish live analysis ready.': 'Живой анализ Stockfish готов.',
    'Lightweight analysis ready.': 'Упрощённый анализ готов.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish недоступен здесь. Проверьте файлы движка или попробуйте другую платформу.',
    'Unlimited analysis selected.': 'Выбран анализ без ограничения глубины.',
  },
  'pt': <String, String>{
    'Stockfish is evaluating the current board.':
        'O Stockfish está avaliando o tabuleiro atual.',
    'Stockfish is analyzing without a depth limit.':
        'O Stockfish está analisando sem limite de profundidade.',
    'Stockfish live analysis ready.':
        'A análise ao vivo do Stockfish está pronta.',
    'Lightweight analysis ready.': 'A análise leve está pronta.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'O Stockfish não está disponível aqui. Verifique os arquivos do motor ou tente outra plataforma.',
    'Unlimited analysis selected.': 'Análise sem limite selecionada.',
  },
  'pl': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish ocenia aktualną pozycję.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish analizuje bez limitu głębokości.',
    'Stockfish live analysis ready.': 'Analiza Stockfish na żywo jest gotowa.',
    'Lightweight analysis ready.': 'Lekka analiza jest gotowa.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish jest tutaj niedostępny. Sprawdź pliki silnika lub spróbuj innej platformy.',
    'Unlimited analysis selected.': 'Wybrano analizę bez limitu.',
  },
  'ro': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish evaluează poziția curentă.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish analizează fără limită de adâncime.',
    'Stockfish live analysis ready.': 'Analiza live Stockfish este pregătită.',
    'Lightweight analysis ready.': 'Analiza simplă este pregătită.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish nu este disponibil aici. Verifică fișierele motorului sau încearcă altă platformă.',
    'Unlimited analysis selected.': 'A fost selectată analiza fără limită.',
  },
  'cs': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish vyhodnocuje aktuální pozici.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish analyzuje bez omezení hloubky.',
    'Stockfish live analysis ready.': 'Živá analýza Stockfish je připravena.',
    'Lightweight analysis ready.': 'Lehká analýza je připravena.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish zde není dostupný. Zkontrolujte soubory enginu nebo zkuste jinou platformu.',
    'Unlimited analysis selected.': 'Byla vybrána analýza bez omezení.',
  },
  'ar': <String, String>{
    'Stockfish is evaluating the current board.':
        'يقيّم Stockfish الوضع الحالي.',
    'Stockfish is analyzing without a depth limit.':
        'يحلل Stockfish من دون حد للعمق.',
    'Stockfish live analysis ready.': 'تحليل Stockfish المباشر جاهز.',
    'Lightweight analysis ready.': 'التحليل الخفيف جاهز.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish غير متاح هنا. تحقق من ملفات المحرك أو جرّب منصة أخرى.',
    'Unlimited analysis selected.': 'تم تحديد التحليل بلا حد.',
  },
  'he': <String, String>{
    'Stockfish is evaluating the current board.':
        'Stockfish מנתח את העמדה הנוכחית.',
    'Stockfish is analyzing without a depth limit.':
        'Stockfish מנתח ללא הגבלת עומק.',
    'Stockfish live analysis ready.': 'הניתוח החי של Stockfish מוכן.',
    'Lightweight analysis ready.': 'הניתוח הקל מוכן.',
    'Stockfish is not available here. Check engine files or try another platform.':
        'Stockfish אינו זמין כאן. בדוק את קובצי המנוע או נסה פלטפורמה אחרת.',
    'Unlimited analysis selected.': 'נבחר ניתוח ללא הגבלה.',
  },
};

const _gameRecordPgnStringMaps = <String, Map<String, String>>{
  'zh-Hans': <String, String>{
    'Refresh PGN': '刷新 PGN',
    'PGN refreshed.': 'PGN 已刷新。',
    'Unable to refresh this PGN.': '无法刷新此 PGN。',
    'Unable to download this PGN.': '无法下载此 PGN。',
    'This record has no remote PGN.': '此记录没有远程 PGN。',
    'The PGN is still loading. Try again shortly.': 'PGN 仍在加载，请稍后重试。',
  },
  'zh-Hant': <String, String>{
    'Refresh PGN': '重新整理 PGN',
    'PGN refreshed.': 'PGN 已重新整理。',
    'Unable to refresh this PGN.': '無法重新整理此 PGN。',
    'Unable to download this PGN.': '無法下載此 PGN。',
    'This record has no remote PGN.': '此記錄沒有遠端 PGN。',
    'The PGN is still loading. Try again shortly.': 'PGN 仍在載入，請稍後再試。',
  },
  'de': <String, String>{
    'Refresh PGN': 'PGN aktualisieren',
    'PGN refreshed.': 'PGN wurde aktualisiert.',
    'Unable to refresh this PGN.':
        'Dieses PGN konnte nicht aktualisiert werden.',
    'Unable to download this PGN.':
        'Dieses PGN konnte nicht heruntergeladen werden.',
    'This record has no remote PGN.': 'Dieser Eintrag hat kein Remote-PGN.',
    'The PGN is still loading. Try again shortly.':
        'Das PGN wird noch geladen. Versuche es gleich noch einmal.',
  },
  'es': <String, String>{
    'Refresh PGN': 'Actualizar PGN',
    'PGN refreshed.': 'PGN actualizado.',
    'Unable to refresh this PGN.': 'No se pudo actualizar este PGN.',
    'Unable to download this PGN.': 'No se pudo descargar este PGN.',
    'This record has no remote PGN.': 'Este registro no tiene un PGN remoto.',
    'The PGN is still loading. Try again shortly.':
        'El PGN todavía se está cargando. Inténtalo de nuevo en breve.',
  },
  'fr': <String, String>{
    'Refresh PGN': 'Actualiser le PGN',
    'PGN refreshed.': 'PGN actualisé.',
    'Unable to refresh this PGN.': 'Impossible d’actualiser ce PGN.',
    'Unable to download this PGN.': 'Impossible de télécharger ce PGN.',
    'This record has no remote PGN.':
        'Cet enregistrement n’a pas de PGN distant.',
    'The PGN is still loading. Try again shortly.':
        'Le PGN est encore en cours de chargement. Réessayez dans un instant.',
  },
  'it': <String, String>{
    'Refresh PGN': 'Aggiorna PGN',
    'PGN refreshed.': 'PGN aggiornato.',
    'Unable to refresh this PGN.': 'Impossibile aggiornare questo PGN.',
    'Unable to download this PGN.': 'Impossibile scaricare questo PGN.',
    'This record has no remote PGN.': 'Questo record non ha un PGN remoto.',
    'The PGN is still loading. Try again shortly.':
        'Il PGN è ancora in caricamento. Riprova tra poco.',
  },
  'ja': <String, String>{
    'Refresh PGN': 'PGNを再取得',
    'PGN refreshed.': 'PGNを更新しました。',
    'Unable to refresh this PGN.': 'このPGNを更新できませんでした。',
    'Unable to download this PGN.': 'このPGNをダウンロードできませんでした。',
    'This record has no remote PGN.': 'この棋譜にはリモートPGNがありません。',
    'The PGN is still loading. Try again shortly.':
        'PGNを読み込み中です。しばらくしてからもう一度お試しください。',
  },
  'ko': <String, String>{
    'Refresh PGN': 'PGN 새로고침',
    'PGN refreshed.': 'PGN을 새로고침했습니다.',
    'Unable to refresh this PGN.': '이 PGN을 새로고침할 수 없습니다.',
    'Unable to download this PGN.': '이 PGN을 다운로드할 수 없습니다.',
    'This record has no remote PGN.': '이 기록에는 원격 PGN이 없습니다.',
    'The PGN is still loading. Try again shortly.':
        'PGN을 불러오는 중입니다. 잠시 후 다시 시도하세요.',
  },
  'nl': <String, String>{
    'Refresh PGN': 'PGN vernieuwen',
    'PGN refreshed.': 'PGN vernieuwd.',
    'Unable to refresh this PGN.': 'Dit PGN kon niet worden vernieuwd.',
    'Unable to download this PGN.': 'Dit PGN kon niet worden gedownload.',
    'This record has no remote PGN.': 'Dit record heeft geen externe PGN.',
    'The PGN is still loading. Try again shortly.':
        'De PGN wordt nog geladen. Probeer het zo opnieuw.',
  },
  'ru': <String, String>{
    'Refresh PGN': 'Обновить PGN',
    'PGN refreshed.': 'PGN обновлён.',
    'Unable to refresh this PGN.': 'Не удалось обновить этот PGN.',
    'Unable to download this PGN.': 'Не удалось скачать этот PGN.',
    'This record has no remote PGN.': 'Для этой записи нет удалённого PGN.',
    'The PGN is still loading. Try again shortly.':
        'PGN всё ещё загружается. Повторите попытку чуть позже.',
  },
};

const _evo2SettingStringMaps = <String, Map<String, String>>{
  'zh-Hans': <String, String>{
    'Keep playing while screen is off': '息屏时继续下棋',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        '开启后，对局可在息屏时继续；关闭后，息屏下棋停止，棋盘 LED 灯熄灭。',
  },
  'zh-Hant': <String, String>{
    'Keep playing while screen is off': '螢幕關閉時繼續下棋',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        '開啟後，對局可在螢幕關閉時繼續；關閉後，息屏下棋停止，棋盤 LED 燈熄滅。',
  },
  'de': <String, String>{
    'Keep playing while screen is off':
        'Bei ausgeschaltetem Bildschirm weiterspielen',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        'Wenn aktiviert, laufen aktive Partien bei ausgeschaltetem Bildschirm weiter. Wenn deaktiviert, wird das Spielen bei ausgeschaltetem Bildschirm beendet und die Brett-LEDs gehen aus.',
  },
  'es': <String, String>{
    'Keep playing while screen is off':
        'Seguir jugando con la pantalla apagada',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        'Al activarlo, las partidas activas continúan con la pantalla apagada. Al desactivarlo, el juego se detiene y los LED del tablero se apagan.',
  },
  'fr': <String, String>{
    'Keep playing while screen is off':
        'Continuer à jouer lorsque l’écran est éteint',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        'Lorsqu’elle est activée, la partie continue lorsque l’écran est éteint. Lorsqu’elle est désactivée, le jeu s’arrête et les LED de l’échiquier s’éteignent.',
  },
  'it': <String, String>{
    'Keep playing while screen is off': 'Continua a giocare a schermo spento',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        'Se attivato, le partite in corso continuano a schermo spento. Se disattivato, il gioco si interrompe e i LED della scacchiera si spengono.',
  },
  'ja': <String, String>{
    'Keep playing while screen is off': '画面オフ中も対局を続ける',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        'オンにすると、画面オフ中も進行中の対局を続けられます。オフにすると、画面オフ中の対局を停止し、ボードのLEDが消灯します。',
  },
  'ko': <String, String>{
    'Keep playing while screen is off': '화면이 꺼진 상태에서도 계속 플레이',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        '켜면 화면이 꺼진 상태에서도 진행 중인 게임을 계속할 수 있습니다. 끄면 화면 꺼짐 플레이가 중지되고 보드 LED가 꺼집니다.',
  },
  'nl': <String, String>{
    'Keep playing while screen is off':
        'Doorgaan met spelen als het scherm uit is',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        'Wanneer ingeschakeld, gaan actieve partijen door als het scherm uit is. Wanneer uitgeschakeld, stopt spelen met uitgeschakeld scherm en gaan de bord-LEDs uit.',
  },
  'ru': <String, String>{
    'Keep playing while screen is off':
        'Продолжать игру при выключенном экране',
    'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.':
        'Если включено, активная партия продолжается при выключенном экране. Если выключено, игра прекращается, а светодиоды доски гаснут.',
  },
};

const _puzzleIdStringMaps = <String, Map<String, String>>{
  'zh-Hans': <String, String>{
    'Puzzle number': '题目编号',
    'Puzzle ID': '题目 ID',
    'Enter a valid puzzle number.': '请输入有效的题目编号。',
    'Puzzle not found.': '未找到该题目。',
  },
  'zh-Hant': <String, String>{
    'Puzzle number': '題目編號',
    'Puzzle ID': '題目 ID',
    'Enter a valid puzzle number.': '請輸入有效的題目編號。',
    'Puzzle not found.': '找不到該題目。',
  },
  'de': <String, String>{
    'Puzzle number': 'Aufgabennummer',
    'Puzzle ID': 'Aufgaben-ID',
    'Enter a valid puzzle number.': 'Gib eine gültige Aufgabennummer ein.',
    'Puzzle not found.': 'Aufgabe nicht gefunden.',
  },
  'es': <String, String>{
    'Puzzle number': 'Número de puzzle',
    'Puzzle ID': 'ID del puzzle',
    'Enter a valid puzzle number.': 'Introduce un número de puzzle válido.',
    'Puzzle not found.': 'No se encontró el puzzle.',
  },
  'fr': <String, String>{
    'Puzzle number': 'Numéro du puzzle',
    'Puzzle ID': 'ID du puzzle',
    'Enter a valid puzzle number.': 'Saisissez un numéro de puzzle valide.',
    'Puzzle not found.': 'Puzzle introuvable.',
  },
  'it': <String, String>{
    'Puzzle number': 'Numero del puzzle',
    'Puzzle ID': 'ID del puzzle',
    'Enter a valid puzzle number.': 'Inserisci un numero di puzzle valido.',
    'Puzzle not found.': 'Puzzle non trovato.',
  },
  'ja': <String, String>{
    'Puzzle number': 'パズル番号',
    'Puzzle ID': 'パズル ID',
    'Enter a valid puzzle number.': '有効なパズル番号を入力してください。',
    'Puzzle not found.': 'パズルが見つかりません。',
  },
  'ko': <String, String>{
    'Puzzle number': '퍼즐 번호',
    'Puzzle ID': '퍼즐 ID',
    'Enter a valid puzzle number.': '올바른 퍼즐 번호를 입력하세요.',
    'Puzzle not found.': '퍼즐을 찾을 수 없습니다.',
  },
  'nl': <String, String>{
    'Puzzle number': 'Puzzelnummer',
    'Puzzle ID': 'Puzzel-ID',
    'Enter a valid puzzle number.': 'Voer een geldig puzzelnummer in.',
    'Puzzle not found.': 'Puzzel niet gevonden.',
  },
  'ru': <String, String>{
    'Puzzle number': 'Номер задачи',
    'Puzzle ID': 'ID задачи',
    'Enter a valid puzzle number.': 'Введите допустимый номер задачи.',
    'Puzzle not found.': 'Задача не найдена.',
  },
};

const _iosGameHeaderStringMaps = <String, Map<String, String>>{
  'zh-Hans': <String, String>{
    'Robot battle': '机器人对战',
    'Career challenge': '生涯挑战',
  },
  'zh-Hant': <String, String>{
    'Robot battle': '機器人對戰',
    'Career challenge': '生涯挑戰',
  },
  'de': <String, String>{
    'Robot battle': 'Roboterduell',
    'Career challenge': 'Karriere-Herausforderung',
  },
  'es': <String, String>{
    'Robot battle': 'Partida contra robot',
    'Career challenge': 'Desafío de carrera',
  },
  'fr': <String, String>{
    'Robot battle': 'Partie contre un robot',
    'Career challenge': 'Défi de carrière',
  },
  'it': <String, String>{
    'Robot battle': 'Partita contro un robot',
    'Career challenge': 'Sfida carriera',
  },
  'ja': <String, String>{
    'Robot battle': 'ロボット対戦',
    'Career challenge': 'キャリアチャレンジ',
  },
  'ko': <String, String>{
    'Robot battle': '로봇 대국',
    'Career challenge': '커리어 도전',
  },
  'nl': <String, String>{
    'Robot battle': 'Partij tegen robot',
    'Career challenge': 'Carrière-uitdaging',
  },
  'ru': <String, String>{
    'Robot battle': 'Игра с роботом',
    'Career challenge': 'Карьерное испытание',
  },
};

const _mistakeBookStringMaps = <String, Map<String, String>>{
  'zh-Hans': <String, String>{
    'All themes': '全部主题',
    'Not mastered': '未掌握',
  },
  'zh-Hant': <String, String>{
    'All themes': '全部主題',
    'Not mastered': '未掌握',
  },
  'de': <String, String>{
    'Not mastered': 'Nicht gemeistert',
  },
  'es': <String, String>{
    'Not mastered': 'No dominado',
  },
  'fr': <String, String>{
    'Not mastered': 'Non maîtrisé',
  },
  'it': <String, String>{
    'Not mastered': 'Non padroneggiato',
  },
  'ja': <String, String>{
    'Not mastered': '未習得',
  },
  'ko': <String, String>{
    'Not mastered': '미숙달',
  },
  'nl': <String, String>{
    'Not mastered': 'Niet beheerst',
  },
  'ru': <String, String>{
    'Not mastered': 'Не освоено',
  },
};

const _puzzleThemeStringMaps = <String, Map<String, String>>{
  'zh-Hans': <String, String>{
    'fork': '叉击',
    'pin': '牵制',
    'skewer': '串击',
    'discoveredAttack': '闪击',
    'backRankMate': '底线将杀',
    'mateIn1': '一步杀',
    'mateIn2': '两步杀',
    'mateIn3': '三步杀',
    'rookEndgame': '车残局',
    'pawnEndgame': '兵残局',
    'queenEndgame': '后残局',
    'bishopEndgame': '象残局',
    'opening': '开局',
    'middlegame': '中局',
    'endgame': '残局',
    'Fork': '叉击',
    'Pin': '牵制',
    'Skewer': '串击',
    'Discovered attack': '闪击',
    'Back rank mate': '底线将杀',
    'Mate in 1': '一步杀',
    'Mate in 2': '两步杀',
    'Mate in 3': '三步杀',
    'Rook endgame': '车残局',
    'Pawn endgame': '兵残局',
    'Queen endgame': '后残局',
    'Bishop endgame': '象残局',
    'Opening': '开局',
    'Middlegame': '中局',
    'Endgame': '残局',
    'Checkmates': '将杀',
    'Endgames': '残局',
    'Game phase': '对局阶段',
    'Mate patterns and forced mate lengths': '将杀模式与强制将杀步数',
    'Conversion, technique, and material-specific drills': '转化、技巧与特定子力训练',
    'Use opening and middlegame tags for targeted sessions': '使用开局和中局标签进行专项训练',
    'Attack two targets at once.': '同时攻击两个目标。',
    'Freeze a piece against a higher-value target.': '牵制棋子，使其无法保护身后更高价值目标。',
    'Drive the valuable piece away first.': '先攻击高价值棋子，迫使其让开。',
    'Move one piece to reveal another threat.': '移动一个棋子，露出另一条攻击线。',
    'Trap the king behind its own pawns.': '利用己方棋子困住国王完成底线将杀。',
    'One forcing move ends the game.': '一步强制走法直接结束对局。',
    'Calculate the opponent response.': '计算对手的应对。',
    'Longer forcing sequence practice.': '练习更长的强制将杀序列。',
    'Activity, checks, and passed pawns.': '子力活跃、将军和通路兵。',
    'Opposition, races, and promotion.': '对王、抢先和升变。',
    'Checks, shelters, and perpetual threats.': '将军、王的庇护和长将威胁。',
    'Color complexes and long diagonals.': '色格弱点和长斜线。',
    'Tactics from known opening structures.': '来自常见开局结构的战术。',
    'Plans, tactics, and king safety.': '计划、战术和王的安全。',
    'Clean conversion from smaller material.': '用较少子力完成清晰转化。',
    'Attack two targets': '同时攻击两个目标',
    'Trap the king behind pawns': '把国王困在兵后方',
    'Draw a piece onto a vulnerable square': '把棋子引到脆弱格',
    'A move where the moved piece attacks two opponent pieces at once':
        '移动后的棋子同时攻击对方两个棋子',
    'A tactic involving pins, where a piece is unable to move without exposing a more valuable piece to attack':
        '涉及牵制的战术：棋子一旦移动，就会暴露身后更有价值的棋子',
    'A motif involving a high value piece being attacked, moving out of the way, and allowing a lower value piece to be captured':
        '先攻击高价值棋子，迫使其让开，从而吃掉后方较低价值棋子的战术主题',
    'Moving a piece (such as a knight), that previously blocked an attack by a long range piece (such as a rook), out of the way of that piece':
        '移开原本挡住长距离棋子攻击线的棋子，例如移开马来打开车的攻击线',
    'Checkmate the king on the home rank, when it is trapped there by its own pieces':
        '当国王被己方棋子困在底线时完成将杀',
    'Deliver checkmate in one move.': '一步完成将杀。',
  },
  'zh-Hant': <String, String>{
    'fork': '叉擊',
    'pin': '牽制',
    'skewer': '串擊',
    'discoveredAttack': '閃擊',
    'backRankMate': '底線將殺',
    'mateIn1': '一步殺',
    'mateIn2': '兩步殺',
    'mateIn3': '三步殺',
    'rookEndgame': '車殘局',
    'pawnEndgame': '兵殘局',
    'queenEndgame': '后殘局',
    'bishopEndgame': '象殘局',
    'opening': '開局',
    'middlegame': '中局',
    'endgame': '殘局',
    'Fork': '叉擊',
    'Pin': '牽制',
    'Skewer': '串擊',
    'Discovered attack': '閃擊',
    'Back rank mate': '底線將殺',
    'Mate in 1': '一步殺',
    'Mate in 2': '兩步殺',
    'Mate in 3': '三步殺',
    'Rook endgame': '車殘局',
    'Pawn endgame': '兵殘局',
    'Queen endgame': '后殘局',
    'Bishop endgame': '象殘局',
    'Opening': '開局',
    'Middlegame': '中局',
    'Endgame': '殘局',
    'Checkmates': '將殺',
    'Endgames': '殘局',
    'Game phase': '對局階段',
    'Mate patterns and forced mate lengths': '將殺模式與強制將殺步數',
    'Conversion, technique, and material-specific drills': '轉化、技巧與特定子力訓練',
    'Use opening and middlegame tags for targeted sessions': '使用開局和中局標籤進行專項訓練',
    'Attack two targets at once.': '同時攻擊兩個目標。',
    'Freeze a piece against a higher-value target.': '牽制棋子，使其無法保護身後更高價值目標。',
    'Drive the valuable piece away first.': '先攻擊高價值棋子，迫使其讓開。',
    'Move one piece to reveal another threat.': '移動一個棋子，露出另一條攻擊線。',
    'Trap the king behind its own pawns.': '利用己方棋子困住國王完成底線將殺。',
    'One forcing move ends the game.': '一步強制走法直接結束對局。',
    'Calculate the opponent response.': '計算對手的應對。',
    'Longer forcing sequence practice.': '練習更長的強制將殺序列。',
    'Activity, checks, and passed pawns.': '子力活躍、將軍和通路兵。',
    'Opposition, races, and promotion.': '對王、搶先和升變。',
    'Checks, shelters, and perpetual threats.': '將軍、王的庇護和長將威脅。',
    'Color complexes and long diagonals.': '色格弱點和長斜線。',
    'Tactics from known opening structures.': '來自常見開局結構的戰術。',
    'Plans, tactics, and king safety.': '計畫、戰術和王的安全。',
    'Clean conversion from smaller material.': '用較少子力完成清晰轉化。',
    'Attack two targets': '同時攻擊兩個目標',
    'Trap the king behind pawns': '把國王困在兵後方',
    'Draw a piece onto a vulnerable square': '把棋子引到脆弱格',
    'A move where the moved piece attacks two opponent pieces at once':
        '移動後的棋子同時攻擊對方兩個棋子',
    'A tactic involving pins, where a piece is unable to move without exposing a more valuable piece to attack':
        '涉及牽制的戰術：棋子一旦移動，就會暴露身後更有價值的棋子',
    'A motif involving a high value piece being attacked, moving out of the way, and allowing a lower value piece to be captured':
        '先攻擊高價值棋子，迫使其讓開，從而吃掉後方較低價值棋子的戰術主題',
    'Moving a piece (such as a knight), that previously blocked an attack by a long range piece (such as a rook), out of the way of that piece':
        '移開原本擋住長距離棋子攻擊線的棋子，例如移開馬來打開車的攻擊線',
    'Checkmate the king on the home rank, when it is trapped there by its own pieces':
        '當國王被己方棋子困在底線時完成將殺',
    'Deliver checkmate in one move.': '一步完成將殺。',
  },
};

const _maia3ReviewHelpStringMaps = <String, Map<String, String>>{
  'zh-Hans': <String, String>{
    'How Maia3 works': 'Maia3 如何工作',
    'How Maia3 Review works': 'Maia3 复盘如何工作',
    'Mobile view': '移动端视图',
    'Moves by rating': '按棋力查看走法',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        '官方 Maia 可以比较不同棋力等级下的走法。移动端视图会保持所选模型紧凑显示。',
    'Rating trends will appear after Maia3 finishes this review.':
        'Maia3 完成本次复盘后，将显示棋力趋势。',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 会分析在所选棋力下，人类棋手更可能怎么走。',
    'Insight shows the current move and likely human alternatives.':
        '洞察会显示当前走法和人类可能选择的替代走法。',
    'Moves keeps the full game easy to scrub and reopen later.':
        '走法列表可让你轻松拖动查看整盘棋，并稍后重新打开。',
    'Summary condenses the whole game into human match and key moments.':
        '总结会把整盘棋浓缩为人类匹配度和关键时刻。',
  },
  'zh-Hant': <String, String>{
    'How Maia3 works': 'Maia3 如何運作',
    'How Maia3 Review works': 'Maia3 複盤如何運作',
    'Mobile view': '行動版檢視',
    'Moves by rating': '按棋力查看走法',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        '官方 Maia 可以比較不同棋力等級下的走法。行動版檢視會保持所選模型緊湊顯示。',
    'Rating trends will appear after Maia3 finishes this review.':
        'Maia3 完成本次複盤後，將顯示棋力趨勢。',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 會分析在所選棋力下，人類棋手更可能怎麼走。',
    'Insight shows the current move and likely human alternatives.':
        '洞察會顯示目前走法和人類可能選擇的替代走法。',
    'Moves keeps the full game easy to scrub and reopen later.':
        '走法列表可讓你輕鬆拖動查看整盤棋，並稍後重新開啟。',
    'Summary condenses the whole game into human match and key moments.':
        '總結會把整盤棋濃縮為人類匹配度和關鍵時刻。',
  },
  'de': <String, String>{
    'How Maia3 works': 'So funktioniert Maia3',
    'How Maia3 Review works': 'So funktioniert die Maia3-Analyse',
    'Mobile view': 'Mobile Ansicht',
    'Moves by rating': 'Züge nach Spielstärke',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Offizielles Maia kann Züge über verschiedene Spielstärken hinweg vergleichen. Diese mobile Ansicht hält das ausgewählte Modell kompakt.',
    'Rating trends will appear after Maia3 finishes this review.':
        'Spielstärketrends erscheinen, sobald Maia3 diese Analyse abgeschlossen hat.',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 zeigt, wie ein Mensch mit der gewählten Spielstärke wahrscheinlich ziehen würde.',
    'Insight shows the current move and likely human alternatives.':
        'Einblick zeigt den aktuellen Zug und wahrscheinliche menschliche Alternativen.',
    'Moves keeps the full game easy to scrub and reopen later.':
        'Züge macht es leicht, die ganze Partie zu durchsuchen und später erneut zu öffnen.',
    'Summary condenses the whole game into human match and key moments.':
        'Zusammenfassung verdichtet die Partie auf menschliche Übereinstimmung und Schlüsselmomente.',
  },
  'es': <String, String>{
    'How Maia3 works': 'Cómo funciona Maia3',
    'How Maia3 Review works': 'Cómo funciona la revisión Maia3',
    'Mobile view': 'Vista móvil',
    'Moves by rating': 'Jugadas por rating',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Maia oficial puede comparar jugadas entre niveles de rating. Esta vista móvil mantiene compacto el modelo seleccionado.',
    'Rating trends will appear after Maia3 finishes this review.':
        'Las tendencias de rating aparecerán cuando Maia3 termine esta revisión.',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 analiza cómo probablemente jugaría una persona con la fuerza seleccionada.',
    'Insight shows the current move and likely human alternatives.':
        'Perspectiva muestra la jugada actual y alternativas humanas probables.',
    'Moves keeps the full game easy to scrub and reopen later.':
        'Jugadas facilita recorrer toda la partida y volver a abrirla más tarde.',
    'Summary condenses the whole game into human match and key moments.':
        'Resumen condensa la partida en coincidencia humana y momentos clave.',
  },
  'fr': <String, String>{
    'How Maia3 works': 'Fonctionnement de Maia3',
    'How Maia3 Review works': 'Fonctionnement de la revue Maia3',
    'Mobile view': 'Vue mobile',
    'Moves by rating': 'Coups par classement',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Maia officiel peut comparer les coups entre plusieurs niveaux. Cette vue mobile garde le modèle sélectionné compact.',
    'Rating trends will appear after Maia3 finishes this review.':
        'Les tendances de niveau apparaîtront après la fin de cette revue Maia3.',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 analyse le coup qu’un joueur humain du niveau choisi jouerait probablement.',
    'Insight shows the current move and likely human alternatives.':
        'Aperçu affiche le coup actuel et les alternatives humaines probables.',
    'Moves keeps the full game easy to scrub and reopen later.':
        'Coups permet de parcourir facilement toute la partie et de la rouvrir plus tard.',
    'Summary condenses the whole game into human match and key moments.':
        'Résumé condense la partie en correspondance humaine et moments clés.',
  },
  'it': <String, String>{
    'How Maia3 works': 'Come funziona Maia3',
    'How Maia3 Review works': 'Come funziona la revisione Maia3',
    'Mobile view': 'Vista mobile',
    'Moves by rating': 'Mosse per rating',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Maia ufficiale può confrontare le mosse tra diversi livelli di rating. Questa vista mobile mantiene compatto il modello selezionato.',
    'Rating trends will appear after Maia3 finishes this review.':
        'Le tendenze del rating appariranno dopo che Maia3 avrà completato questa revisione.',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 analizza quale mossa giocherebbe probabilmente una persona alla forza selezionata.',
    'Insight shows the current move and likely human alternatives.':
        'Approfondimento mostra la mossa attuale e le probabili alternative umane.',
    'Moves keeps the full game easy to scrub and reopen later.':
        'Mosse permette di scorrere facilmente tutta la partita e riaprirla più tardi.',
    'Summary condenses the whole game into human match and key moments.':
        'Riepilogo condensa la partita in somiglianza umana e momenti chiave.',
  },
  'ja': <String, String>{
    'How Maia3 works': 'Maia3 の仕組み',
    'How Maia3 Review works': 'Maia3 復習の仕組み',
    'Mobile view': 'モバイル表示',
    'Moves by rating': 'レーティング別の手',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        '公式 Maia は、複数のレーティング帯で手を比較できます。このモバイル表示では、選択中のモデルをコンパクトに表示します。',
    'Rating trends will appear after Maia3 finishes this review.':
        'Maia3 の復習が完了すると、レーティング傾向が表示されます。',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 は、選択した強さの人間が指しそうな手を中心に分析します。',
    'Insight shows the current move and likely human alternatives.':
        '洞察では、現在の手と人間が選びそうな別候補を表示します。',
    'Moves keeps the full game easy to scrub and reopen later.':
        '手順では、対局全体を簡単にたどり、後で開き直せます。',
    'Summary condenses the whole game into human match and key moments.':
        '要約では、対局全体を人間らしさの一致度と重要場面にまとめます。',
  },
  'ko': <String, String>{
    'How Maia3 works': 'Maia3 작동 방식',
    'How Maia3 Review works': 'Maia3 복기 작동 방식',
    'Mobile view': '모바일 보기',
    'Moves by rating': '레이팅별 수',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        '공식 Maia는 여러 레이팅 수준의 수를 비교할 수 있습니다. 이 모바일 보기는 선택한 모델을 간결하게 표시합니다.',
    'Rating trends will appear after Maia3 finishes this review.':
        'Maia3가 이 복기를 완료하면 레이팅 추세가 표시됩니다.',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3는 선택한 기력의 사람이 둘 가능성이 높은 수를 중심으로 분석합니다.',
    'Insight shows the current move and likely human alternatives.':
        '인사이트는 현재 수와 사람이 둘 만한 대안을 보여 줍니다.',
    'Moves keeps the full game easy to scrub and reopen later.':
        '수 목록에서는 전체 대국을 쉽게 훑어보고 나중에 다시 열 수 있습니다.',
    'Summary condenses the whole game into human match and key moments.':
        '요약은 전체 대국을 인간 일치도와 핵심 장면으로 압축합니다.',
  },
  'nl': <String, String>{
    'How Maia3 works': 'Hoe Maia3 werkt',
    'How Maia3 Review works': 'Hoe Maia3-analyse werkt',
    'Mobile view': 'Mobiele weergave',
    'Moves by rating': 'Zetten per rating',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Officiële Maia kan zetten vergelijken tussen ratingniveaus. Deze mobiele weergave houdt het geselecteerde model compact.',
    'Rating trends will appear after Maia3 finishes this review.':
        'Ratingtrends verschijnen nadat Maia3 deze analyse heeft afgerond.',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 bekijkt welke zet een mens met de gekozen sterkte waarschijnlijk zou spelen.',
    'Insight shows the current move and likely human alternatives.':
        'Inzicht toont de huidige zet en waarschijnlijke menselijke alternatieven.',
    'Moves keeps the full game easy to scrub and reopen later.':
        'Zetten maakt de hele partij makkelijk door te lopen en later opnieuw te openen.',
    'Summary condenses the whole game into human match and key moments.':
        'Samenvatting vat de partij samen in menselijke overeenkomst en sleutelmomenten.',
  },
  'ru': <String, String>{
    'How Maia3 works': 'Как работает Maia3',
    'How Maia3 Review works': 'Как работает разбор Maia3',
    'Mobile view': 'Мобильный вид',
    'Moves by rating': 'Ходы по рейтингу',
    'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.':
        'Официальная Maia может сравнивать ходы на разных уровнях рейтинга. В мобильном виде выбранная модель остается компактной.',
    'Rating trends will appear after Maia3 finishes this review.':
        'Тенденции рейтинга появятся после завершения этого разбора Maia3.',
    'Maia3 focuses on how a human at the selected strength is likely to move.':
        'Maia3 анализирует, какой ход, скорее всего, выбрал бы человек выбранной силы.',
    'Insight shows the current move and likely human alternatives.':
        'Раздел анализа показывает текущий ход и вероятные человеческие альтернативы.',
    'Moves keeps the full game easy to scrub and reopen later.':
        'Список ходов помогает быстро просматривать всю партию и открывать её позже.',
    'Summary condenses the whole game into human match and key moments.':
        'Сводка сжимает партию до совпадения с человеческой игрой и ключевых моментов.',
  },
};

const _moduleGuideStringMaps = <String, Map<String, String>>{
  "zh-Hans": <String, String>{
    "Home": "主页",
    "Your daily launchpad for play, study, review, and devices.":
        "用于下棋、学习、复盘和设备管理的每日入口。",
    "Start playing": "开始下棋",
    "Use Play to choose bot, online, OTB, or clock modes.":
        "使用 Play 选择机器人、在线、OTB 或棋钟模式。",
    "Practice plan": "练习计划",
    "Practice brings puzzles, lessons, mistakes, and live analysis together.":
        "Practice 汇集谜题、课程、错题和实时分析。",
    "Review games": "复盘对局",
    "Game Review helps you analyze saved or imported games.":
        "Game Review 帮你分析已保存或导入的对局。",
    "Choose path": "选择模式",
    "Start the right kind of game from one focused place.": "在一个集中入口开始合适的对局模式。",
    "Play online": "在线对局",
    "Connect to online games when you want a real opponent.":
        "想和真人对手下棋时，从这里连接在线对局。",
    "Bot games": "机器人对局",
    "Choose Maia, Maia 3, Stockfish, or your enabled LC0 engines.":
        "选择 Maia、Maia 3、Stockfish 或已启用的 LC0 引擎。",
    "Board setup": "棋盘设置",
    "Use the editor when you want to start from a custom position.":
        "想从自定义局面开始时，使用编辑器。",
    "OTB and clock": "OTB 和棋钟",
    "Record a physical-board game or open the standalone chess clock.":
        "记录实体棋盘对局，或打开独立棋钟。",
    "Choose bot": "选择机器人",
    "Pick an engine, position, side, and time control.": "选择引擎、起始局面、执棋方和时间控制。",
    "Choose engine": "选择引擎",
    "Select Maia, Maia 3, Stockfish, or an enabled personal engine.":
        "选择 Maia、Maia 3、Stockfish 或已启用的个人引擎。",
    "Starting position": "起始局面",
    "Use Standard, 960, Opening, or Board Editor positions here.":
        "在这里选择标准、960、开局或 Board Editor 局面。",
    "Side and time": "执棋方和时间",
    "Choose your color and time control before starting the game.":
        "开始对局前选择颜色和时间控制。",
    "Online match": "在线对局",
    "Start Lichess or Chess.com games with board sync.":
        "通过棋盘同步开始 Lichess 或 Chess.com 对局。",
    "Choose platform": "选择平台",
    "Use Lichess native play or the Chess.com WebView flow.":
        "使用 Lichess 原生对局或 Chess.com WebView 流程。",
    "Authorize Lichess": "授权 Lichess",
    "Bind Lichess before seeking native online games.":
        "开始原生在线对局前，先绑定 Lichess。",
    "Match settings": "对局设置",
    "Set time control, rated mode, auto submit, and move LEDs.":
        "设置时间控制、积分模式、自动提交和走棋 LED。",
    "OTB game": "OTB 对局",
    "Record physical-board games or use the clock.": "记录实体棋盘对局，或使用棋钟。",
    "Record physical-board games.": "记录实体棋盘对局。",
    "Time control": "时间控制",
    "Choose a preset or custom time before starting.": "开始前选择预设或自定义时间。",
    "Record game": "记录对局",
    "Track legal moves, clocks, and PGN for later review.":
        "记录合法走法、棋钟和 PGN，方便之后复盘。",
    "Chess clock": "棋钟",
    "Open a standalone clock when you do not need PGN recording.":
        "不需要记录 PGN 时，打开独立棋钟。",
    "Chess Clock": "棋钟",
    "Use the app as a two-player clock.": "把 App 当作双人棋钟使用。",
    "White clock": "白方棋钟",
    "Tap the active clock after a move, or use the hardware switch.":
        "走棋后点击当前计时块，或使用硬件开关。",
    "Black clock": "黑方棋钟",
    "Only the active side can switch turns during the game.":
        "对局中只有当前走棋方可以切换回合。",
    "Clock controls": "棋钟控制",
    "Start, pause, reset, and exit the clock from this control area.":
        "在这个控制区开始、暂停、重置或退出棋钟。",
    "Bot game": "机器人对局",
    "Play against an engine with board sync and review tools.":
        "和引擎对弈，并使用棋盘同步和复盘工具。",
    "Game board": "对局棋盘",
    "Play your moves on the virtual board or a connected board.":
        "在虚拟棋盘或已连接棋盘上走棋。",
    "Board connection": "棋盘连接",
    "Check here whether your Chessnut board is connected and syncing.":
        "在这里检查 Chessnut 棋盘是否已连接并保持同步。",
    "Move list and actions": "走法列表和操作",
    "Review recent moves and open game options from the action bar.":
        "查看最近走法，并从操作栏打开对局选项。",
    "Play live online games while Chessnut keeps the board in sync.":
        "在线实时对局时，Chessnut 会保持棋盘同步。",
    "Connection status": "连接状态",
    "Check latency, voice moves, and physical-board connection here.":
        "在这里查看延迟、语音走棋和实体棋盘连接。",
    "The board mirrors the online game and accepts your legal moves.":
        "棋盘会同步在线对局，并接收你的合法走法。",
    "Game actions": "对局操作",
    "Use actions to flip, review moves, and open more online options.":
        "使用操作按钮翻转棋盘、查看走法，并打开更多在线选项。",
    "Play face to face while Chessnut records the PGN.":
        "面对面对弈时，由 Chessnut 记录 PGN。",
    "Game clocks": "对局棋钟",
    "Watch both players' time and whose turn is active.": "查看双方剩余时间和当前轮到谁走。",
    "Move list": "走法列表",
    "The PGN strip shows the latest recorded moves.": "PGN 条会显示最新记录的走法。",
    "Open game options such as draw, takeback, resign, or leave.":
        "打开和棋、悔棋、认输或暂离等对局选项。",
    "Game history": "对局历史",
    "Review, continue, import, and manage saved games.": "复盘、继续、导入和管理已保存对局。",
    "Sources": "来源",
    "Switch between Chessnut, Lichess, and Chess.com records.":
        "在 Chessnut、Lichess 和 Chess.com 记录之间切换。",
    "Filters": "筛选",
    "Filter and search when your game history grows.": "对局历史变多后，可用筛选和搜索快速定位。",
    "More actions": "更多操作",
    "Use the three-dot menu or long press for copy, delete, and continue.":
        "使用三点菜单或长按来复制、删除或继续对局。",
    "App settings": "App 设置",
    "Adjust app language, appearance, sounds, and guides.":
        "调整 App 语言、外观、声音和引导。",
    "Language": "语言",
    "Choose the app language used across the interface.": "选择整个界面使用的 App 语言。",
    "General preferences": "通用偏好",
    "Control coordinates, background board connection, and sounds.":
        "控制坐标、后台棋盘连接和声音。",
    "Replay guides": "再次观看引导",
    "Open this when you want to watch first-time guides again.":
        "想重新观看首次引导时，从这里打开。",
    "Board settings": "棋盘设置",
    "Tune board sync, LEDs, voice moves, firmware, and clock switch.":
        "调整棋盘同步、LED、语音走棋、固件和棋钟开关。",
    "Board status": "棋盘状态",
    "Check the connected board model and battery status here.":
        "在这里查看已连接棋盘型号和电量状态。",
    "Move logic": "走棋逻辑",
    "Adjust move delay, restore timing, and voice-move language.":
        "调整走棋延迟、恢复时机和语音走棋语言。",
    "Control the board LED hints used while setting up and playing.":
        "控制摆棋和下棋时使用的棋盘 LED 提示。",
    "Clock switch": "棋钟开关",
    "On Chessnut Clock, choose how hardware switch automation works.":
        "在 Chessnut Clock 上，设置硬件开关自动化的工作方式。",
    "Practice": "练习",
    "A training hub for puzzles, lessons, mistakes, and analysis.":
        "汇集谜题、课程、错题和分析的训练中心。",
    "Puzzle Themes": "谜题主题",
    "Choose one tactical motif and practice it directly.": "选择一个战术主题并直接练习。",
    "Mistake Book": "错题本",
    "Turn reviewed game mistakes into a personal training queue.":
        "把复盘中的失误变成个人训练队列。",
    "Board Analyzer": "棋盘分析器",
    "Explore any position with live engine feedback.": "用实时引擎反馈探索任意局面。",
    "Practice one motif at a time instead of random tactics.":
        "一次练一个主题，而不是随机战术。",
    "Choose a theme": "选择主题",
    "Open the theme picker when you want a different tactic type.":
        "想换战术类型时，打开主题选择器。",
    "Solve on the board": "在棋盘上解题",
    "Use the board area to play the answer, with physical board sync when connected.":
        "在棋盘区域走出答案，连接实体棋盘时会同步。",
    "Side to move": "轮到哪方",
    "Check whose turn it is before calculating the tactic.": "计算战术前，先确认轮到哪方走。",
    "Engine Lab": "引擎实验室",
    "Manage the engines that can appear in bot games.": "管理可出现在机器人对局中的引擎。",
    "Enabled engines": "已启用引擎",
    "Only enabled engines from this library appear in bot setup.":
        "只有此库中已启用的引擎会出现在机器人设置里。",
    "Personal engine": "个人引擎",
    "Build and manage engines trained from your own game sources.":
        "构建并管理由你的对局来源训练出的引擎。",
    "Engine market": "引擎市场",
    "Download Chessnut-provided popular LC0 engines here.":
        "在这里下载 Chessnut 提供的热门 LC0 引擎。",
    "Game Review": "对局复盘",
    "Review a full game through Stockfish, Maia, and Grandeur.":
        "通过 Stockfish、Maia 和 Grandeur 复盘完整对局。",
    "Import a game": "导入对局",
    "Import PGN when you want to review a game from outside Chessnut.":
        "想复盘 Chessnut 外的对局时，导入 PGN。",
    "Open saved games and generate reports from your records.":
        "打开已保存对局，并从记录生成报告。",
    "Live analysis": "实时分析",
    "Jump to Board Analyzer for real-time position exploration.":
        "跳转到 Board Analyzer，实时探索局面。",
    "A focused review queue built from your own weak moves.": "由你的弱手组成的专注复习队列。",
    "Filter mistakes": "筛选错题",
    "Use filters to focus on due, blunder, or mastered positions.":
        "使用筛选聚焦到期、漏着或已掌握局面。",
    "Search your book": "搜索错题本",
    "Search by game, motif, or move when the list grows long.":
        "列表变长后，可按对局、主题或走法搜索。",
    "Page through reviews": "翻页复习",
    "Use the pager to move through compact batches.": "使用翻页器查看紧凑分批内容。",
    "Career": "生涯",
    "Progress through chess challenges like a game campaign.": "像游戏闯关一样推进棋力挑战。",
    "Find opponent": "寻找对手",
    "Start the next Career challenge from here.": "从这里开始下一场 Career 挑战。",
    "Career journey": "生涯旅程",
    "Track your route, milestones, and current stage.": "查看你的路线、里程碑和当前阶段。",
    "Training focus": "训练重点",
    "Use recommended practice when you want to prepare for the next match.":
        "想准备下一场比赛时，使用推荐练习。",
    "Board Editor": "棋盘编辑器",
    "Set up a position from FEN or the physical board.": "从 FEN 或实体棋盘设置局面。",
    "Check whether the physical board is connected and syncing.":
        "检查实体棋盘是否已连接并同步。",
    "Edit controls": "编辑控制",
    "Use these controls to read from the board, send FEN, and adjust position settings.":
        "用这些控制项读取棋盘、发送 FEN，并调整局面设置。",
    "Start from here": "从这里开始",
    "Start a bot game from the edited position when it is ready.":
        "局面准备好后，从编辑后的局面开始机器人对局。",
    "Choose a module to view its first-time guide again.": "选择一个模块，重新查看首次引导。",
    "Show all guides next time": "下次显示所有引导",
    "Skip": "跳过",
    "Delete personal engine?": "删除个人引擎？",
    "This removes the training record from your Chessnut account. If this engine was downloaded for Bot game, it will also be removed from the local engine library. This action cannot be undone.":
        "这会从你的 Chessnut 账号中删除这条训练记录。如果该引擎已下载用于机器人对局，也会从本地引擎库中移除。此操作无法撤销。",
    "Personal engine deleted.": "个人引擎已删除。",
    "Unable to delete this personal engine. Try again later.":
        "无法删除这个个人引擎，请稍后重试。",
  },
  "zh-Hant": <String, String>{
    "Home": "首頁",
    "Your daily launchpad for play, study, review, and devices.":
        "用於下棋、學習、複盤和裝置管理的每日入口。",
    "Start playing": "開始下棋",
    "Use Play to choose bot, online, OTB, or clock modes.":
        "使用 Play 選擇機器人、線上、OTB 或棋鐘模式。",
    "Practice plan": "練習計畫",
    "Practice brings puzzles, lessons, mistakes, and live analysis together.":
        "Practice 匯集謎題、課程、錯題和即時分析。",
    "Review games": "複盤對局",
    "Game Review helps you analyze saved or imported games.":
        "Game Review 幫你分析已儲存或匯入的對局。",
    "Choose path": "選擇模式",
    "Start the right kind of game from one focused place.": "在一個集中入口開始合適的對局模式。",
    "Play online": "線上對局",
    "Connect to online games when you want a real opponent.":
        "想和真人對手下棋時，從這裡連接線上對局。",
    "Bot games": "機器人對局",
    "Choose Maia, Maia 3, Stockfish, or your enabled LC0 engines.":
        "選擇 Maia、Maia 3、Stockfish 或已啟用的 LC0 引擎。",
    "Board setup": "棋盤設定",
    "Use the editor when you want to start from a custom position.":
        "想從自訂局面開始時，使用編輯器。",
    "OTB and clock": "OTB 和棋鐘",
    "Record a physical-board game or open the standalone chess clock.":
        "記錄實體棋盤對局，或開啟獨立棋鐘。",
    "Choose bot": "選擇機器人",
    "Pick an engine, position, side, and time control.": "選擇引擎、起始局面、執棋方和時間控制。",
    "Choose engine": "選擇引擎",
    "Select Maia, Maia 3, Stockfish, or an enabled personal engine.":
        "選擇 Maia、Maia 3、Stockfish 或已啟用的個人引擎。",
    "Starting position": "起始局面",
    "Use Standard, 960, Opening, or Board Editor positions here.":
        "在這裡選擇標準、960、開局或 Board Editor 局面。",
    "Side and time": "執棋方和時間",
    "Choose your color and time control before starting the game.":
        "開始對局前選擇顏色和時間控制。",
    "Online match": "線上對局",
    "Start Lichess or Chess.com games with board sync.":
        "透過棋盤同步開始 Lichess 或 Chess.com 對局。",
    "Choose platform": "選擇平台",
    "Use Lichess native play or the Chess.com WebView flow.":
        "使用 Lichess 原生對局或 Chess.com WebView 流程。",
    "Authorize Lichess": "授權 Lichess",
    "Bind Lichess before seeking native online games.":
        "開始原生線上對局前，先綁定 Lichess。",
    "Match settings": "對局設定",
    "Set time control, rated mode, auto submit, and move LEDs.":
        "設定時間控制、積分模式、自動提交和走棋 LED。",
    "OTB game": "OTB 對局",
    "Record physical-board games or use the clock.": "記錄實體棋盤對局，或使用棋鐘。",
    "Record physical-board games.": "記錄實體棋盤對局。",
    "Time control": "時間控制",
    "Choose a preset or custom time before starting.": "開始前選擇預設或自訂時間。",
    "Record game": "記錄對局",
    "Track legal moves, clocks, and PGN for later review.":
        "記錄合法走法、棋鐘和 PGN，方便之後複盤。",
    "Chess clock": "棋鐘",
    "Open a standalone clock when you do not need PGN recording.":
        "不需要記錄 PGN 時，開啟獨立棋鐘。",
    "Chess Clock": "棋鐘",
    "Use the app as a two-player clock.": "把 App 當作雙人棋鐘使用。",
    "White clock": "白方棋鐘",
    "Tap the active clock after a move, or use the hardware switch.":
        "走棋後點擊目前計時區塊，或使用硬體開關。",
    "Black clock": "黑方棋鐘",
    "Only the active side can switch turns during the game.":
        "對局中只有目前走棋方可以切換回合。",
    "Clock controls": "棋鐘控制",
    "Start, pause, reset, and exit the clock from this control area.":
        "在這個控制區開始、暫停、重設或退出棋鐘。",
    "Bot game": "機器人對局",
    "Play against an engine with board sync and review tools.":
        "和引擎對弈，並使用棋盤同步和複盤工具。",
    "Game board": "對局棋盤",
    "Play your moves on the virtual board or a connected board.":
        "在虛擬棋盤或已連接棋盤上走棋。",
    "Board connection": "棋盤連接",
    "Check here whether your Chessnut board is connected and syncing.":
        "在這裡檢查 Chessnut 棋盤是否已連接並保持同步。",
    "Move list and actions": "走法列表和操作",
    "Review recent moves and open game options from the action bar.":
        "查看最近走法，並從操作列開啟對局選項。",
    "Play live online games while Chessnut keeps the board in sync.":
        "線上即時對局時，Chessnut 會保持棋盤同步。",
    "Connection status": "連線狀態",
    "Check latency, voice moves, and physical-board connection here.":
        "在這裡查看延遲、語音走棋和實體棋盤連線。",
    "The board mirrors the online game and accepts your legal moves.":
        "棋盤會同步線上對局，並接收你的合法走法。",
    "Game actions": "對局操作",
    "Use actions to flip, review moves, and open more online options.":
        "使用操作按鈕翻轉棋盤、查看走法，並開啟更多線上選項。",
    "Play face to face while Chessnut records the PGN.":
        "面對面對弈時，由 Chessnut 記錄 PGN。",
    "Game clocks": "對局棋鐘",
    "Watch both players' time and whose turn is active.": "查看雙方剩餘時間和目前輪到誰走。",
    "Move list": "走法列表",
    "The PGN strip shows the latest recorded moves.": "PGN 列會顯示最新記錄的走法。",
    "Open game options such as draw, takeback, resign, or leave.":
        "開啟和棋、悔棋、認輸或暫離等對局選項。",
    "Game history": "對局歷史",
    "Review, continue, import, and manage saved games.": "複盤、繼續、匯入和管理已儲存對局。",
    "Sources": "來源",
    "Switch between Chessnut, Lichess, and Chess.com records.":
        "在 Chessnut、Lichess 和 Chess.com 記錄之間切換。",
    "Filters": "篩選",
    "Filter and search when your game history grows.": "對局歷史變多後，可用篩選和搜尋快速定位。",
    "More actions": "更多操作",
    "Use the three-dot menu or long press for copy, delete, and continue.":
        "使用三點選單或長按來複製、刪除或繼續對局。",
    "App settings": "App 設定",
    "Adjust app language, appearance, sounds, and guides.":
        "調整 App 語言、外觀、聲音和引導。",
    "Language": "語言",
    "Choose the app language used across the interface.": "選擇整個介面使用的 App 語言。",
    "General preferences": "通用偏好",
    "Control coordinates, background board connection, and sounds.":
        "控制座標、背景棋盤連線和聲音。",
    "Replay guides": "再次觀看引導",
    "Open this when you want to watch first-time guides again.":
        "想重新觀看首次引導時，從這裡開啟。",
    "Board settings": "棋盤設定",
    "Tune board sync, LEDs, voice moves, firmware, and clock switch.":
        "調整棋盤同步、LED、語音走棋、韌體和棋鐘開關。",
    "Board status": "棋盤狀態",
    "Check the connected board model and battery status here.":
        "在這裡查看已連接棋盤型號和電量狀態。",
    "Move logic": "走棋邏輯",
    "Adjust move delay, restore timing, and voice-move language.":
        "調整走棋延遲、恢復時機和語音走棋語言。",
    "Control the board LED hints used while setting up and playing.":
        "控制擺棋和下棋時使用的棋盤 LED 提示。",
    "Clock switch": "棋鐘開關",
    "On Chessnut Clock, choose how hardware switch automation works.":
        "在 Chessnut Clock 上，設定硬體開關自動化的工作方式。",
    "Practice": "練習",
    "A training hub for puzzles, lessons, mistakes, and analysis.":
        "匯集謎題、課程、錯題和分析的訓練中心。",
    "Puzzle Themes": "謎題主題",
    "Choose one tactical motif and practice it directly.": "選擇一個戰術主題並直接練習。",
    "Mistake Book": "錯題本",
    "Turn reviewed game mistakes into a personal training queue.":
        "把複盤中的失誤變成個人訓練佇列。",
    "Board Analyzer": "棋盤分析器",
    "Explore any position with live engine feedback.": "用即時引擎回饋探索任意局面。",
    "Practice one motif at a time instead of random tactics.":
        "一次練一個主題，而不是隨機戰術。",
    "Choose a theme": "選擇主題",
    "Open the theme picker when you want a different tactic type.":
        "想換戰術類型時，開啟主題選擇器。",
    "Solve on the board": "在棋盤上解題",
    "Use the board area to play the answer, with physical board sync when connected.":
        "在棋盤區域走出答案，連接實體棋盤時會同步。",
    "Side to move": "輪到哪方",
    "Check whose turn it is before calculating the tactic.": "計算戰術前，先確認輪到哪方走。",
    "Engine Lab": "引擎實驗室",
    "Manage the engines that can appear in bot games.": "管理可出現在機器人對局中的引擎。",
    "Enabled engines": "已啟用引擎",
    "Only enabled engines from this library appear in bot setup.":
        "只有此庫中已啟用的引擎會出現在機器人設定裡。",
    "Personal engine": "個人引擎",
    "Build and manage engines trained from your own game sources.":
        "建立並管理由你的對局來源訓練出的引擎。",
    "Engine market": "引擎市場",
    "Download Chessnut-provided popular LC0 engines here.":
        "在這裡下載 Chessnut 提供的熱門 LC0 引擎。",
    "Game Review": "對局複盤",
    "Review a full game through Stockfish, Maia, and Grandeur.":
        "透過 Stockfish、Maia 和 Grandeur 複盤完整對局。",
    "Import a game": "匯入對局",
    "Import PGN when you want to review a game from outside Chessnut.":
        "想複盤 Chessnut 外的對局時，匯入 PGN。",
    "Open saved games and generate reports from your records.":
        "開啟已儲存對局，並從記錄生成報告。",
    "Live analysis": "即時分析",
    "Jump to Board Analyzer for real-time position exploration.":
        "跳轉到 Board Analyzer，即時探索局面。",
    "A focused review queue built from your own weak moves.": "由你的弱手組成的專注複習佇列。",
    "Filter mistakes": "篩選錯題",
    "Use filters to focus on due, blunder, or mastered positions.":
        "使用篩選聚焦到期、漏著或已掌握局面。",
    "Search your book": "搜尋錯題本",
    "Search by game, motif, or move when the list grows long.":
        "列表變長後，可按對局、主題或走法搜尋。",
    "Page through reviews": "翻頁複習",
    "Use the pager to move through compact batches.": "使用翻頁器查看緊湊分批內容。",
    "Career": "生涯",
    "Progress through chess challenges like a game campaign.": "像遊戲闖關一樣推進棋力挑戰。",
    "Find opponent": "尋找對手",
    "Start the next Career challenge from here.": "從這裡開始下一場 Career 挑戰。",
    "Career journey": "生涯旅程",
    "Track your route, milestones, and current stage.": "查看你的路線、里程碑和目前階段。",
    "Training focus": "訓練重點",
    "Use recommended practice when you want to prepare for the next match.":
        "想準備下一場比賽時，使用推薦練習。",
    "Board Editor": "棋盤編輯器",
    "Set up a position from FEN or the physical board.": "從 FEN 或實體棋盤設定局面。",
    "Check whether the physical board is connected and syncing.":
        "檢查實體棋盤是否已連接並同步。",
    "Edit controls": "編輯控制",
    "Use these controls to read from the board, send FEN, and adjust position settings.":
        "用這些控制項讀取棋盤、發送 FEN，並調整局面設定。",
    "Start from here": "從這裡開始",
    "Start a bot game from the edited position when it is ready.":
        "局面準備好後，從編輯後的局面開始機器人對局。",
    "Choose a module to view its first-time guide again.": "選擇一個模組，重新查看首次引導。",
    "Show all guides next time": "下次顯示所有引導",
    "Skip": "略過",
    "Delete personal engine?": "刪除個人引擎？",
    "This removes the training record from your Chessnut account. If this engine was downloaded for Bot game, it will also be removed from the local engine library. This action cannot be undone.":
        "這會從你的 Chessnut 帳號中刪除這筆訓練記錄。如果該引擎已下載用於機器人對局，也會從本機引擎庫中移除。此操作無法復原。",
    "Personal engine deleted.": "個人引擎已刪除。",
    "Unable to delete this personal engine. Try again later.":
        "無法刪除這個個人引擎，請稍後再試。",
  },
};

const _recentFeatureStringMaps = <String, Map<String, String>>{
  "zh-Hans": <String, String>{
    "Sound effects": "音效",
    "Moves, game starts, results, and key actions": "走棋、对局开始、结果和关键操作",
    "Refresh records": "刷新记录",
    "No cloud games found": "未找到云端对局",
    "Try fewer filters or import games from Lichess first.":
        "减少筛选条件，或先从 Lichess 导入对局。",
    "Back to local list": "返回本地列表",
    "Finish this game before generating an analysis report.": "完成这盘棋后才能生成分析报告。",
    "Game record deleted.": "对局记录已删除。",
    "Unable to delete this game record.": "无法删除这条对局记录。",
    "Unable to search your cloud archive. Check your connection and try again.":
        "无法搜索云端记录，请检查网络后重试。",
    "Delete record": "删除记录",
    "End game": "结束游戏",
    "End this game?": "结束这盘棋？",
    "Mark as finished": "标记为已结束",
    "Game marked as ended.": "对局已标记为结束。",
    "Unable to end this game record.": "无法结束这条对局记录。",
    "This will mark the saved PGN as a completed draw so it no longer appears as a game you can continue.":
        "这会把保存的 PGN 标记为已结束的和棋，它将不再显示为可继续的对局。",
    "Delete game record?": "删除这条对局记录？",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "这会从你的 Chessnut 账号中删除已保存的 PGN，且无法撤销。",
    "From PGN": "从 PGN 导入",
    "From Lichess player": "从 Lichess 棋手导入",
    "From Chess.com username": "从 Chess.com 用户名导入",
    "Local list": "本地列表",
    "Cloud search failed": "云端搜索失败",
    "Previous page": "上一页",
    "Next page": "下一页",
    "Import Chess.com games": "导入 Chess.com 对局",
    "Import Lichess games": "导入 Lichess 对局",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "将某个 Chess.com 用户名的公开完结对局导入 Game Record。Chess.com 归档最新对局可能需要一些时间。",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "将某个 Lichess 棋手的完结对局导入 Game Record，重复对局会自动跳过。",
    "Player ID": "棋手 ID",
    "Rated only": "仅积分对局",
    "Casual only": "仅休闲对局",
    "Rated and casual": "积分和休闲对局",
    "White games": "执白对局",
    "Black games": "执黑对局",
    "Start import": "开始导入",
    "Enter a Chess.com username.": "请输入 Chess.com 用户名。",
    "Enter a Lichess player ID.": "请输入 Lichess 棋手 ID。",
    "Use points or upgrade Premium": "使用积分或升级 Premium",
    "Standard plan": "标准方案",
    "Unable to preview Game Record.": "无法预览 Game Record。",
    "Unable to check build progress.": "无法检查构建进度。",
    "Unable to cancel Model Build.": "无法取消个人引擎训练。",
    "Model Build queued": "个人引擎训练已排队",
    "Model Build needs attention": "个人引擎训练需要处理",
    "Model Build failed": "个人引擎训练失败",
    "Model Build canceled": "个人引擎训练已取消",
    "Paste a PGN before starting review.": "开始复盘前请先粘贴 PGN。",
    "Unable to start Grandeur review.": "无法启动 Grandeur 复盘。",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur 已解锁，正在继续教练分析...",
    "Grandeur review is being prepared...": "Grandeur 复盘正在准备...",
    "Spend 100 points?": "消耗 100 积分？",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur 会使用钱包积分生成 LLM 教练复盘。",
    "Current balance": "当前余额",
    "Original cost": "原价消耗",
    "Member discount": "会员优惠",
    "Pay today": "今日支付",
    "Balance after review": "复盘后余额",
    "Start Grandeur review?": "开始 Grandeur 复盘？",
    "Start Grandeur review": "开始 Grandeur 复盘",
    "Not enough points": "积分不足",
    "Sign in required": "需要登录",
    "Grandeur review uses your wallet balance.": "Grandeur 复盘会使用你的钱包余额。",
    "Wallet unavailable": "钱包暂不可用",
    "Checking wallet": "正在检查钱包",
    "Grandeur report generating": "Grandeur 报告生成中",
    "Current move": "当前着法",
    "No Grandeur commentary is available for this move yet.":
        "这步棋暂时没有 Grandeur 评论。",
    "Stockfish analysis in progress": "Stockfish 分析进行中",
    "Preparing PGN positions for evaluation.": "正在准备 PGN 局面用于评估。",
    "Review settings": "复盘设置",
    "Maia3 official rating model": "Maia3 官方等级分模型",
    "Compare with Stockfish": "与 Stockfish 对比",
    "Show human likelihood next to the engine verdict.": "在引擎结论旁显示人类走法可能性。",
    "Start Maia3 Review": "开始 Maia3 复盘",
    "Choose the human rating to review against, then start Maia3.":
        "选择用于对照复盘的人类等级分，然后启动 Maia3。",
    "Engine comparison": "引擎对比",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 解释人类走法可能性，Stockfish 检查客观质量。",
    "Natural and strong": "自然且有力",
    "Common mistake": "常见失误",
    "Engine-like move": "类似引擎的走法",
    "Unusual mistake": "不寻常的失误",
    "Stockfish ready": "Stockfish 已就绪",
    "Stockfish pending": "Stockfish 等待中",
    "Auto-renewing plans get the best price": "自动续订方案价格最优惠",
    "Processing purchase": "正在处理购买",
    "Continue purchase": "继续购买",
    "Restore purchase": "恢复购买",
    "One-time access": "一次性使用",
    "Best price": "最优惠价格",
    "Sign in before upgrading membership.": "升级会员前请先登录。",
    "Sign in before restoring purchases.": "恢复购买前请先登录。",
    "In-app purchase is available on iOS and Android.":
        "应用内购买仅在 iOS 和 Android 可用。",
    "Restore purchase is available on iOS and Android.":
        "恢复购买仅在 iOS 和 Android 可用。",
    "Purchase canceled. Your membership was not changed.": "购买已取消，会员状态未改变。",
    "Purchase is still pending. Check your store account later.":
        "购买仍在处理中，请稍后检查商店账号。",
    "No active membership purchase was found for this store account.":
        "这个商店账号没有找到有效会员购买记录。",
    "Premium is active.": "Premium 已生效。",
    "VIP member": "会员",
    "Valid until": "有效期至",
    "Renew membership": "续费会员",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "购买验证失败，请检查网络并尝试恢复购买。",
    "This record cannot be deleted from the cloud.": "这条记录不能从云端删除。",
    "Lichess authorization expired. Re-authorize before continuing.":
        "Lichess 授权已过期，请重新授权后继续。",
    "Lichess authorized": "Lichess 已授权",
    "Connected as": "已连接为",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "你的 Chessnut 账号已连接到 Lichess。你可以保留此连接；如果想授权其他 Lichess 账号，也可以解除连接。",
    "Keep linked": "保持连接",
    "Unlink Lichess": "解除 Lichess 连接",
    "Lichess account unlinked.": "Lichess 账号已解除连接。",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "Lichess 授权尚未完成。请在 Lichess 页面完成后重试。",
    "I have authorized": "我已授权",
    "Open in browser": "在浏览器中打开",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "批准 Lichess 授权后返回 Chessnut。如果页面是在浏览器中打开的，请在页面显示授权成功后点击这里。",
    "Close authorization": "关闭授权",
    "Linked accounts": "已绑定账号",
    "Linked account updated.": "绑定账号已更新。",
    "Not linked": "未绑定",
    "Default 791556": "默认 791556",
    "Built-in": "内置",
    "Local file": "本地文件",
    "Playable engine library": "可玩的引擎库",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "还没有可玩的个人引擎。完成后的构建在可用于 Bot game 时会显示在这里。",
    "Manage in Engine Lab": "在引擎实验室中管理",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "训练、报告和可玩的个人引擎都在引擎实验室中。",
    "Unavailable": "不可用",
    "Check for updates": "检查更新",
    "Check whether a newer Chessnut version is available.":
        "检查是否有可用的新版 Chessnut。",
    "Update required": "需要更新",
    "Update available": "有可用更新",
    "Later": "稍后",
    "Open store": "打开商店",
    "Download update": "下载更新",
    "Update now": "立即更新",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "需要更新此版本才能确保 Chessnut 正常运行。请先更新再继续。",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "有新版可用。立即更新以获取最新修复和改进。",
    "This update will open the official app store or test track for your device.":
        "此更新会打开适用于你设备的官方应用商店或测试渠道。",
    "This update will open the official Chessnut download page.":
        "此更新会打开 Chessnut 官方下载页面。",
    "This update will open in your browser.": "此更新会在浏览器中打开。",
    "You are using the latest version.": "你正在使用最新版本。",
    "Could not check for updates. Please try again later.": "无法检查更新。请稍后重试。",
    "Update link is not available right now. Please try again later.":
        "更新链接暂时不可用。请稍后重试。",
    "Could not open the update link. Please try again later.":
        "无法打开更新链接。请稍后重试。",
    "Import from image": "从图片导入",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "启用 Chessnut Vision？",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision 使用图像识别从屏幕截图读取棋盘。功能运行期间，截图仅用于识别；Chessnut 不会在本设备本地保存截图，也不会在本设备保留你的个人数据。",
    "Not now": "暂不",
    "Enable Vision": "启用 Vision",
    "Chessnut Vision is on": "Chessnut Vision 已开启",
    "Chessnut Vision is off": "Chessnut Vision 已关闭",
    "Chessnut Vision is now active.": "Chessnut Vision 现已启用。",
    "Turn on Chessnut Vision in Accessibility": "在无障碍中打开 Chessnut Vision",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision 需要先开启 Android 无障碍权限，才能读取屏幕。请打开设置并启用 Chessnut Vision。",
    "Choose a clear board photo or take a new one.": "选择一张清晰的棋盘照片，或拍摄新照片。",
    "Choose a clear board image to recognize the position.":
        "选择一张清晰的棋盘图片来识别局面。",
    "Choose from gallery": "从相册选择",
    "Take a photo": "拍照",
    "Recognizing board image...": "正在识别棋盘图片...",
    "No image selected.": "未选择图片。",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision 无法识别此局面。",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision 无法读取这张图片。请尝试更清晰的照片。",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision 返回了棋盘无法读取的局面。",
    "Position imported from image.": "已从图片导入局面。",
    "Import a board position from a photo.": "从照片导入棋盘局面。",
    "Choose image": "选择图片",
    "Camera": "相机",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision 暂时不可用。请稍后重试。",
    "Choose a board image before using Chessnut Vision.":
        "使用 Chessnut Vision 前请先选择棋盘图片。",
    "This image is too large. Choose an image under 10 MB.":
        "这张图片太大。请选择小于 10 MB 的图片。",
    "This image could not be opened.": "无法打开这张图片。",
    "This image could not be read.": "无法读取这张图片。",
    "Use a JPG, PNG, or WebP board image.": "请使用 JPG、PNG 或 WebP 格式的棋盘图片。",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision 无法从这张图片识别有效局面。",
    "Keeps the board connected with a persistent notification, including while the screen is off. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "通过常驻通知保持棋盘连接，包括息屏时。如果 30 分钟内 FEN 没有变化，Chessnut 会自动断开棋盘以节省电量。",
    "Keeps listening for board events in the background when iOS allows. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "iOS 允许时会在后台继续监听棋盘事件。如果 30 分钟内 FEN 没有变化，Chessnut 会自动断开棋盘以节省电量。",
    "Keeps the board connected while Chessnut is running on Windows. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "在 Windows 上运行 Chessnut 时保持棋盘连接。如果 30 分钟内 FEN 没有变化，Chessnut 会自动断开棋盘以节省电量。",
    "Keeps the board connected while Chessnut is running on macOS. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "在 macOS 上运行 Chessnut 时保持棋盘连接。如果 30 分钟内 FEN 没有变化，Chessnut 会自动断开棋盘以节省电量。",
    "Keeps the board connected while Chessnut is running on Linux. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "在 Linux 上运行 Chessnut 时保持棋盘连接。如果 30 分钟内 FEN 没有变化，Chessnut 会自动断开棋盘以节省电量。",
    "Keeps the board connected while Chessnut is running. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "运行 Chessnut 时保持棋盘连接。如果 30 分钟内 FEN 没有变化，Chessnut 会自动断开棋盘以节省电量。",
    "Keeps the board connected while Chessnut is running in this browser tab. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "在当前浏览器标签页运行 Chessnut 时保持棋盘连接。如果 30 分钟内 FEN 没有变化，Chessnut 会自动断开棋盘以节省电量。",
    "Board position was unchanged for 30 minutes, so Chessnut disconnected the board to save battery.":
        "棋盘位置已 30 分钟没有变化，Chessnut 已自动断开棋盘以节省电量。",
  },
  "zh-Hant": <String, String>{
    "Sound effects": "音效",
    "Moves, game starts, results, and key actions": "走棋、對局開始、結果和關鍵操作",
    "Refresh records": "重新整理記錄",
    "No cloud games found": "找不到雲端對局",
    "Try fewer filters or import games from Lichess first.":
        "減少篩選條件，或先從 Lichess 匯入對局。",
    "Back to local list": "返回本機列表",
    "Finish this game before generating an analysis report.": "完成這盤棋後才能產生分析報告。",
    "Game record deleted.": "對局記錄已刪除。",
    "Unable to delete this game record.": "無法刪除這筆對局記錄。",
    "Unable to search your cloud archive. Check your connection and try again.":
        "無法搜尋雲端記錄，請檢查網路後再試。",
    "Delete record": "刪除記錄",
    "End game": "結束遊戲",
    "End this game?": "結束這盤棋？",
    "Mark as finished": "標記為已結束",
    "Game marked as ended.": "對局已標記為結束。",
    "Unable to end this game record.": "無法結束這筆對局記錄。",
    "This will mark the saved PGN as a completed draw so it no longer appears as a game you can continue.":
        "這會把儲存的 PGN 標記為已結束的和棋，它將不再顯示為可繼續的對局。",
    "Delete game record?": "刪除這筆對局記錄？",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "這會從你的 Chessnut 帳號中刪除已儲存的 PGN，且無法復原。",
    "From PGN": "從 PGN 匯入",
    "From Lichess player": "從 Lichess 棋手匯入",
    "From Chess.com username": "從 Chess.com 使用者名稱匯入",
    "Local list": "本機列表",
    "Cloud search failed": "雲端搜尋失敗",
    "Previous page": "上一頁",
    "Next page": "下一頁",
    "Import Chess.com games": "匯入 Chess.com 對局",
    "Import Lichess games": "匯入 Lichess 對局",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "將某個 Chess.com 使用者名稱的公開完結對局匯入 Game Record。Chess.com 封存最新對局可能需要一些時間。",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "將某個 Lichess 棋手的完結對局匯入 Game Record，重複對局會自動略過。",
    "Player ID": "棋手 ID",
    "Rated only": "僅積分對局",
    "Casual only": "僅休閒對局",
    "Rated and casual": "積分與休閒對局",
    "White games": "執白對局",
    "Black games": "執黑對局",
    "Start import": "開始匯入",
    "Enter a Chess.com username.": "請輸入 Chess.com 使用者名稱。",
    "Enter a Lichess player ID.": "請輸入 Lichess 棋手 ID。",
    "Use points or upgrade Premium": "使用積分或升級 Premium",
    "Standard plan": "標準方案",
    "Unable to preview Game Record.": "無法預覽 Game Record。",
    "Unable to check build progress.": "無法檢查建置進度。",
    "Unable to cancel Model Build.": "無法取消個人引擎訓練。",
    "Model Build queued": "個人引擎訓練已排入佇列",
    "Model Build needs attention": "個人引擎訓練需要處理",
    "Model Build failed": "個人引擎訓練失敗",
    "Model Build canceled": "個人引擎訓練已取消",
    "Paste a PGN before starting review.": "開始複盤前請先貼上 PGN。",
    "Unable to start Grandeur review.": "無法啟動 Grandeur 複盤。",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur 已解鎖，正在繼續教練分析...",
    "Grandeur review is being prepared...": "Grandeur 複盤正在準備...",
    "Spend 100 points?": "消耗 100 積分？",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur 會使用錢包積分產生 LLM 教練複盤。",
    "Current balance": "目前餘額",
    "Original cost": "原始費用",
    "Member discount": "會員優惠",
    "Pay today": "今天支付",
    "Balance after review": "複盤後餘額",
    "Start Grandeur review?": "開始 Grandeur 複盤？",
    "Start Grandeur review": "開始 Grandeur 複盤",
    "Not enough points": "積分不足",
    "Sign in required": "需要登入",
    "Grandeur review uses your wallet balance.": "Grandeur 複盤會使用你的錢包餘額。",
    "Wallet unavailable": "錢包暫不可用",
    "Checking wallet": "正在檢查錢包",
    "Grandeur report generating": "Grandeur 報告產生中",
    "Current move": "目前著法",
    "No Grandeur commentary is available for this move yet.":
        "這步棋暫時沒有 Grandeur 評論。",
    "Stockfish analysis in progress": "Stockfish 分析進行中",
    "Preparing PGN positions for evaluation.": "正在準備 PGN 局面用於評估。",
    "Review settings": "複盤設定",
    "Maia3 official rating model": "Maia3 官方等級分模型",
    "Compare with Stockfish": "與 Stockfish 比較",
    "Show human likelihood next to the engine verdict.": "在引擎結論旁顯示人類著法可能性。",
    "Start Maia3 Review": "開始 Maia3 複盤",
    "Choose the human rating to review against, then start Maia3.":
        "選擇用於對照複盤的人類等級分，然後啟動 Maia3。",
    "Engine comparison": "引擎比較",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 說明人類著法可能性，Stockfish 檢查客觀品質。",
    "Natural and strong": "自然且有力",
    "Common mistake": "常見失誤",
    "Engine-like move": "類似引擎的著法",
    "Unusual mistake": "不尋常的失誤",
    "Stockfish ready": "Stockfish 已就緒",
    "Stockfish pending": "Stockfish 等待中",
    "Auto-renewing plans get the best price": "自動續訂方案價格最優惠",
    "Processing purchase": "正在處理購買",
    "Continue purchase": "繼續購買",
    "Restore purchase": "恢復購買",
    "One-time access": "一次性使用",
    "Best price": "最優惠價格",
    "Sign in before upgrading membership.": "升級會員前請先登入。",
    "Sign in before restoring purchases.": "恢復購買前請先登入。",
    "In-app purchase is available on iOS and Android.":
        "App 內購買僅在 iOS 與 Android 可用。",
    "Restore purchase is available on iOS and Android.":
        "恢復購買僅在 iOS 與 Android 可用。",
    "Purchase canceled. Your membership was not changed.": "購買已取消，會員狀態未變更。",
    "Purchase is still pending. Check your store account later.":
        "購買仍在處理中，請稍後檢查商店帳號。",
    "No active membership purchase was found for this store account.":
        "這個商店帳號沒有找到有效會員購買記錄。",
    "Premium is active.": "Premium 已啟用。",
    "VIP member": "會員",
    "Valid until": "有效期至",
    "Renew membership": "續費會員",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "購買驗證失敗，請檢查網路並嘗試恢復購買。",
    "This record cannot be deleted from the cloud.": "這筆記錄不能從雲端刪除。",
    "Lichess authorization expired. Re-authorize before continuing.":
        "Lichess 授權已過期，請重新授權後繼續。",
    "Lichess authorized": "Lichess 已授權",
    "Connected as": "已連接為",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "你的 Chessnut 帳號已連接到 Lichess。你可以保留此連接；如果想授權其他 Lichess 帳號，也可以解除連接。",
    "Keep linked": "保持連接",
    "Unlink Lichess": "解除 Lichess 連接",
    "Lichess account unlinked.": "Lichess 帳號已解除連接。",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "Lichess 授權尚未完成。請在 Lichess 頁面完成後重試。",
    "I have authorized": "我已授權",
    "Open in browser": "在瀏覽器中開啟",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "批准 Lichess 授權後返回 Chessnut。如果頁面是在瀏覽器中開啟的，請在頁面顯示授權成功後點選這裡。",
    "Close authorization": "關閉授權",
    "Linked accounts": "已綁定帳號",
    "Linked account updated.": "綁定帳號已更新。",
    "Not linked": "未綁定",
    "Default 791556": "預設 791556",
    "Built-in": "內建",
    "Local file": "本機檔案",
    "Playable engine library": "可玩的引擎庫",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "還沒有可玩的個人引擎。完成後的建置在可用於 Bot game 時會顯示在這裡。",
    "Manage in Engine Lab": "在引擎實驗室中管理",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "訓練、報表和可玩的個人引擎都在引擎實驗室。",
    "Unavailable": "無法使用",
    "Check for updates": "檢查更新",
    "Check whether a newer Chessnut version is available.":
        "檢查是否有可用的新版 Chessnut。",
    "Update required": "需要更新",
    "Update available": "有可用更新",
    "Later": "稍後",
    "Open store": "開啟商店",
    "Download update": "下載更新",
    "Update now": "立即更新",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "需要更新此版本才能確保 Chessnut 正常運作。請先更新再繼續。",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "有新版可用。立即更新以取得最新修正與改進。",
    "This update will open the official app store or test track for your device.":
        "此更新會開啟適用於你裝置的官方 App 商店或測試通道。",
    "This update will open the official Chessnut download page.":
        "此更新會開啟 Chessnut 官方下載頁面。",
    "This update will open in your browser.": "此更新會在瀏覽器中開啟。",
    "You are using the latest version.": "你正在使用最新版本。",
    "Could not check for updates. Please try again later.": "無法檢查更新。請稍後再試。",
    "Update link is not available right now. Please try again later.":
        "更新連結目前不可用。請稍後再試。",
    "Could not open the update link. Please try again later.":
        "無法開啟更新連結。請稍後再試。",
    "Import from image": "從圖片匯入",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "啟用 Chessnut Vision？",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision 使用影像辨識從螢幕截圖讀取棋盤。功能執行期間，截圖僅用於辨識；Chessnut 不會在本裝置本機儲存截圖，也不會在本裝置保留你的個人資料。",
    "Not now": "暫不",
    "Enable Vision": "啟用 Vision",
    "Chessnut Vision is on": "Chessnut Vision 已開啟",
    "Chessnut Vision is off": "Chessnut Vision 已關閉",
    "Chessnut Vision is now active.": "Chessnut Vision 現已啟用。",
    "Turn on Chessnut Vision in Accessibility": "在輔助使用中開啟 Chessnut Vision",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision 需要先開啟 Android 輔助使用權限，才能讀取螢幕。請開啟設定並啟用 Chessnut Vision。",
    "Choose a clear board photo or take a new one.": "選擇一張清晰的棋盤照片，或拍攝新照片。",
    "Choose a clear board image to recognize the position.":
        "選擇一張清晰的棋盤圖片來辨識局面。",
    "Choose from gallery": "從相簿選擇",
    "Take a photo": "拍照",
    "Recognizing board image...": "正在辨識棋盤圖片...",
    "No image selected.": "未選擇圖片。",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision 無法辨識此局面。",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision 無法讀取這張圖片。請嘗試更清晰的照片。",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision 傳回了棋盤無法讀取的局面。",
    "Position imported from image.": "已從圖片匯入局面。",
    "Import a board position from a photo.": "從照片匯入棋盤局面。",
    "Choose image": "選擇圖片",
    "Camera": "相機",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision 目前不可用。請稍後再試。",
    "Choose a board image before using Chessnut Vision.":
        "使用 Chessnut Vision 前請先選擇棋盤圖片。",
    "This image is too large. Choose an image under 10 MB.":
        "這張圖片太大。請選擇小於 10 MB 的圖片。",
    "This image could not be opened.": "無法開啟這張圖片。",
    "This image could not be read.": "無法讀取這張圖片。",
    "Use a JPG, PNG, or WebP board image.": "請使用 JPG、PNG 或 WebP 格式的棋盤圖片。",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision 無法從這張圖片辨識有效局面。",
    "Keeps the board connected with a persistent notification, including while the screen is off. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "透過常駐通知保持棋盤連線，包括螢幕關閉時。如果 30 分鐘內 FEN 沒有變化，Chessnut 會自動斷開棋盤以節省電量。",
    "Keeps listening for board events in the background when iOS allows. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "iOS 允許時會在背景繼續監聽棋盤事件。如果 30 分鐘內 FEN 沒有變化，Chessnut 會自動斷開棋盤以節省電量。",
    "Keeps the board connected while Chessnut is running on Windows. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "在 Windows 上執行 Chessnut 時保持棋盤連線。如果 30 分鐘內 FEN 沒有變化，Chessnut 會自動斷開棋盤以節省電量。",
    "Keeps the board connected while Chessnut is running on macOS. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "在 macOS 上執行 Chessnut 時保持棋盤連線。如果 30 分鐘內 FEN 沒有變化，Chessnut 會自動斷開棋盤以節省電量。",
    "Keeps the board connected while Chessnut is running on Linux. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "在 Linux 上執行 Chessnut 時保持棋盤連線。如果 30 分鐘內 FEN 沒有變化，Chessnut 會自動斷開棋盤以節省電量。",
    "Keeps the board connected while Chessnut is running. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "執行 Chessnut 時保持棋盤連線。如果 30 分鐘內 FEN 沒有變化，Chessnut 會自動斷開棋盤以節省電量。",
    "Keeps the board connected while Chessnut is running in this browser tab. If the FEN does not change for 30 minutes, Chessnut disconnects it to save battery.":
        "在目前瀏覽器分頁執行 Chessnut 時保持棋盤連線。如果 30 分鐘內 FEN 沒有變化，Chessnut 會自動斷開棋盤以節省電量。",
    "Board position was unchanged for 30 minutes, so Chessnut disconnected the board to save battery.":
        "棋盤位置已 30 分鐘沒有變化，Chessnut 已自動斷開棋盤以節省電量。",
  },
  "de": <String, String>{
    "Sound effects": "Soundeffekte",
    "Moves, game starts, results, and key actions":
        "Zuege, Spielbeginn, Ergebnisse und wichtige Aktionen",
    "Refresh records": "Datensätze aktualisieren",
    "No cloud games found": "Keine Cloud-Partien gefunden",
    "Try fewer filters or import games from Lichess first.":
        "Nutze weniger Filter oder importiere zuerst Partien von Lichess.",
    "Back to local list": "Zur lokalen Liste",
    "Finish this game before generating an analysis report.":
        "Beende diese Partie, bevor du einen Analysebericht erstellst.",
    "Game record deleted.": "Partieeintrag gelöscht.",
    "Unable to delete this game record.":
        "Dieser Partieeintrag konnte nicht gelöscht werden.",
    "Unable to search your cloud archive. Check your connection and try again.":
        "Dein Cloud-Archiv konnte nicht durchsucht werden. Prüfe die Verbindung und versuche es erneut.",
    "Delete record": "Eintrag löschen",
    "Delete game record?": "Partieeintrag löschen?",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "Damit wird das gespeicherte PGN aus deinem Chessnut-Konto entfernt. Diese Aktion kann nicht rückgängig gemacht werden.",
    "From PGN": "Aus PGN",
    "From Lichess player": "Von Lichess-Spieler",
    "From Chess.com username": "Von Chess.com-Benutzername",
    "Local list": "Lokale Liste",
    "Cloud search failed": "Cloud-Suche fehlgeschlagen",
    "Previous page": "Vorherige Seite",
    "Next page": "Nächste Seite",
    "Import Chess.com games": "Chess.com-Partien importieren",
    "Import Lichess games": "Lichess-Partien importieren",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "Importiere öffentliche beendete Partien eines Chess.com-Benutzernamens in Game Record. Sehr neue Partien erscheinen im Chess.com-Archiv manchmal etwas später.",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "Importiere beendete Partien eines Lichess-Spielers in Game Record. Duplikate werden automatisch übersprungen.",
    "Player ID": "Spieler-ID",
    "Rated only": "Nur gewertet",
    "Casual only": "Nur ungezwungen",
    "Rated and casual": "Gewertet und ungezwungen",
    "White games": "Partien mit Weiß",
    "Black games": "Partien mit Schwarz",
    "Start import": "Import starten",
    "Enter a Chess.com username.": "Gib einen Chess.com-Benutzernamen ein.",
    "Enter a Lichess player ID.": "Gib eine Lichess-Spieler-ID ein.",
    "Use points or upgrade Premium": "Punkte nutzen oder Premium upgraden",
    "Standard plan": "Standardplan",
    "Unable to preview Game Record.":
        "Game Record konnte nicht in der Vorschau angezeigt werden.",
    "Unable to check build progress.":
        "Build-Fortschritt konnte nicht geprüft werden.",
    "Unable to cancel Model Build.":
        "Persönliches Engine-Training konnte nicht abgebrochen werden.",
    "Model Build queued": "Persönliches Engine-Training in Warteschlange",
    "Model Build needs attention":
        "Persönliches Engine-Training benötigt Aufmerksamkeit",
    "Model Build failed": "Persönliches Engine-Training fehlgeschlagen",
    "Model Build canceled": "Persönliches Engine-Training abgebrochen",
    "Paste a PGN before starting review.":
        "Füge ein PGN ein, bevor du die Analyse startest.",
    "Unable to start Grandeur review.":
        "Grandeur-Review konnte nicht gestartet werden.",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur ist freigeschaltet. Die Coach-Analyse wird fortgesetzt ...",
    "Grandeur review is being prepared...":
        "Grandeur-Review wird vorbereitet ...",
    "Spend 100 points?": "100 Punkte ausgeben?",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur nutzt Wallet-Punkte für die LLM-Coach-Review.",
    "Current balance": "Aktuelles Guthaben",
    "Original cost": "Ursprüngliche Kosten",
    "Member discount": "Mitgliederrabatt",
    "Pay today": "Heute zahlen",
    "Balance after review": "Guthaben nach Review",
    "Start Grandeur review?": "Grandeur-Review starten?",
    "Start Grandeur review": "Grandeur-Review starten",
    "Not enough points": "Nicht genug Punkte",
    "Sign in required": "Anmeldung erforderlich",
    "Grandeur review uses your wallet balance.":
        "Grandeur-Review nutzt dein Wallet-Guthaben.",
    "Wallet unavailable": "Wallet nicht verfügbar",
    "Checking wallet": "Wallet wird geprüft",
    "Grandeur report generating": "Grandeur-Bericht wird erstellt",
    "Current move": "Aktueller Zug",
    "No Grandeur commentary is available for this move yet.":
        "Für diesen Zug ist noch kein Grandeur-Kommentar verfügbar.",
    "Stockfish analysis in progress": "Stockfish-Analyse läuft",
    "Preparing PGN positions for evaluation.":
        "PGN-Stellungen werden für die Bewertung vorbereitet.",
    "Review settings": "Review-Einstellungen",
    "Maia3 official rating model": "Offizielles Maia3-Wertungsmodell",
    "Compare with Stockfish": "Mit Stockfish vergleichen",
    "Show human likelihood next to the engine verdict.":
        "Zeige die menschliche Wahrscheinlichkeit neben dem Engine-Urteil.",
    "Start Maia3 Review": "Maia3-Review starten",
    "Choose the human rating to review against, then start Maia3.":
        "Wähle die menschliche Wertung für den Vergleich und starte dann Maia3.",
    "Engine comparison": "Engine-Vergleich",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 erklärt die menschliche Wahrscheinlichkeit. Stockfish prüft die objektive Qualität.",
    "Natural and strong": "Natürlich und stark",
    "Common mistake": "Häufiger Fehler",
    "Engine-like move": "Engine-artiger Zug",
    "Unusual mistake": "Ungewöhnlicher Fehler",
    "Stockfish ready": "Stockfish bereit",
    "Stockfish pending": "Stockfish ausstehend",
    "Auto-renewing plans get the best price":
        "Automatisch verlängernde Pläne haben den besten Preis",
    "Processing purchase": "Kauf wird verarbeitet",
    "Continue purchase": "Kauf fortsetzen",
    "Restore purchase": "Kauf wiederherstellen",
    "One-time access": "Einmaliger Zugriff",
    "Best price": "Bester Preis",
    "Sign in before upgrading membership.":
        "Melde dich an, bevor du die Mitgliedschaft upgradest.",
    "Sign in before restoring purchases.":
        "Melde dich an, bevor du Käufe wiederherstellst.",
    "In-app purchase is available on iOS and Android.":
        "In-App-Käufe sind auf iOS und Android verfügbar.",
    "Restore purchase is available on iOS and Android.":
        "Käufe wiederherstellen ist auf iOS und Android verfügbar.",
    "Purchase canceled. Your membership was not changed.":
        "Kauf abgebrochen. Deine Mitgliedschaft wurde nicht geändert.",
    "Purchase is still pending. Check your store account later.":
        "Der Kauf ist noch ausstehend. Prüfe dein Store-Konto später.",
    "No active membership purchase was found for this store account.":
        "Für dieses Store-Konto wurde kein aktiver Mitgliedschaftskauf gefunden.",
    "Premium is active.": "Premium ist aktiv.",
    "VIP member": "VIP-Mitglied",
    "Valid until": "Gültig bis",
    "Renew membership": "Mitgliedschaft verlängern",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "Kaufprüfung fehlgeschlagen. Prüfe dein Netzwerk und versuche „Kauf wiederherstellen“.",
    "This record cannot be deleted from the cloud.":
        "Dieser Eintrag kann nicht aus der Cloud gelöscht werden.",
    "Lichess authorization expired. Re-authorize before continuing.":
        "Lichess-Autorisierung ist abgelaufen. Autorisiere erneut, bevor du fortfährst.",
    "Lichess authorized": "Lichess autorisiert",
    "Connected as": "Verbunden als",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "Dein Chessnut-Konto ist bereits mit Lichess verbunden. Du kannst diese Verknüpfung beibehalten oder sie trennen, wenn du ein anderes Lichess-Konto autorisieren möchtest.",
    "Keep linked": "Verknüpft lassen",
    "Unlink Lichess": "Lichess trennen",
    "Lichess account unlinked.": "Lichess-Konto getrennt.",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "Die Lichess-Autorisierung wurde nicht abgeschlossen. Versuche es erneut, wenn die Lichess-Seite fertig ist.",
    "I have authorized": "Ich habe autorisiert",
    "Open in browser": "Im Browser öffnen",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "Kehre zu Chessnut zurück, nachdem du die Lichess-Autorisierung genehmigt hast. Wenn die Seite in deinem Browser geöffnet wurde, tippe hier, nachdem dort steht, dass die Autorisierung erfolgreich war.",
    "Close authorization": "Autorisierung schließen",
    "Linked accounts": "Verknüpfte Konten",
    "Linked account updated.": "Verknüpftes Konto aktualisiert.",
    "Not linked": "Nicht verknüpft",
    "Default 791556": "Standard 791556",
    "Built-in": "Integriert",
    "Local file": "Lokale Datei",
    "Playable engine library": "Spielbare Engine-Bibliothek",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "Noch keine spielbaren persönlichen Engines. Fertige Builds erscheinen hier, sobald sie für Bot game bereit sind.",
    "Manage in Engine Lab": "Im Engine Lab verwalten",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "Training, Berichte und spielbare persönliche Engines befinden sich im Engine Lab.",
    "Unavailable": "Nicht verfügbar",
    "Check for updates": "Nach Updates suchen",
    "Check whether a newer Chessnut version is available.":
        "Prüfen, ob eine neuere Chessnut-Version verfügbar ist.",
    "Update required": "Update erforderlich",
    "Update available": "Update verfügbar",
    "Later": "Später",
    "Open store": "Store öffnen",
    "Download update": "Update herunterladen",
    "Update now": "Jetzt aktualisieren",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "Diese Version ist erforderlich, damit Chessnut korrekt funktioniert. Bitte aktualisiere, bevor du fortfährst.",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "Eine neuere Version ist verfügbar. Aktualisiere jetzt, um die neuesten Korrekturen und Verbesserungen zu erhalten.",
    "This update will open the official app store or test track for your device.":
        "Dieses Update öffnet den offiziellen App Store oder Test-Track für dein Gerät.",
    "This update will open the official Chessnut download page.":
        "Dieses Update öffnet die offizielle Chessnut-Downloadseite.",
    "This update will open in your browser.":
        "Dieses Update wird in deinem Browser geöffnet.",
    "You are using the latest version.": "Du verwendest die neueste Version.",
    "Could not check for updates. Please try again later.":
        "Updates konnten nicht geprüft werden. Bitte versuche es später erneut.",
    "Update link is not available right now. Please try again later.":
        "Der Update-Link ist derzeit nicht verfügbar. Bitte versuche es später erneut.",
    "Could not open the update link. Please try again later.":
        "Der Update-Link konnte nicht geöffnet werden. Bitte versuche es später erneut.",
    "Import from image": "Aus Bild importieren",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "Chessnut Vision aktivieren?",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision nutzt Bilderkennung, um das Brett aus Screenshots zu lesen. Screenshots werden nur zur Erkennung verwendet, während die Funktion aktiv ist; Chessnut speichert sie nicht lokal und behält deine persönlichen Daten nicht auf diesem Gerät.",
    "Not now": "Nicht jetzt",
    "Enable Vision": "Vision aktivieren",
    "Chessnut Vision is on": "Chessnut Vision ist eingeschaltet",
    "Chessnut Vision is off": "Chessnut Vision ist ausgeschaltet",
    "Chessnut Vision is now active.": "Chessnut Vision ist jetzt aktiv.",
    "Turn on Chessnut Vision in Accessibility":
        "Chessnut Vision in Bedienungshilfen einschalten",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision benötigt die Android-Bedienungshilfen-Berechtigung, bevor es den Bildschirm lesen kann. Öffne Einstellungen und schalte Chessnut Vision ein.",
    "Choose a clear board photo or take a new one.":
        "Wähle ein klares Brettfoto aus oder nimm ein neues auf.",
    "Choose a clear board image to recognize the position.":
        "Wähle ein klares Brettbild aus, um die Stellung zu erkennen.",
    "Choose from gallery": "Aus Galerie wählen",
    "Take a photo": "Foto aufnehmen",
    "Recognizing board image...": "Brettbild wird erkannt...",
    "No image selected.": "Kein Bild ausgewählt.",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision konnte diese Stellung nicht erkennen.",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision konnte dieses Bild nicht lesen. Versuche ein klareres Foto.",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision hat eine Stellung zurückgegeben, die das Brett nicht lesen konnte.",
    "Position imported from image.": "Stellung aus Bild importiert.",
    "Import a board position from a photo.":
        "Importiere eine Brettstellung aus einem Foto.",
    "Choose image": "Bild wählen",
    "Camera": "Kamera",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision ist derzeit nicht verfügbar. Bitte versuche es später erneut.",
    "Choose a board image before using Chessnut Vision.":
        "Wähle ein Brettbild aus, bevor du Chessnut Vision verwendest.",
    "This image is too large. Choose an image under 10 MB.":
        "Dieses Bild ist zu groß. Wähle ein Bild unter 10 MB.",
    "This image could not be opened.":
        "Dieses Bild konnte nicht geöffnet werden.",
    "This image could not be read.": "Dieses Bild konnte nicht gelesen werden.",
    "Use a JPG, PNG, or WebP board image.":
        "Verwende ein Brettbild im Format JPG, PNG oder WebP.",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision konnte aus diesem Bild keine gültige Stellung erkennen.",
  },
  "es": <String, String>{
    "Sound effects": "Efectos de sonido",
    "Moves, game starts, results, and key actions":
        "Jugadas, inicio de partida, resultados y acciones clave",
    "Refresh records": "Actualizar registros",
    "No cloud games found": "No se encontraron partidas en la nube",
    "Try fewer filters or import games from Lichess first.":
        "Usa menos filtros o importa partidas de Lichess primero.",
    "Back to local list": "Volver a la lista local",
    "Finish this game before generating an analysis report.":
        "Termina esta partida antes de generar un informe de análisis.",
    "Game record deleted.": "Registro de partida eliminado.",
    "Unable to delete this game record.":
        "No se pudo eliminar este registro de partida.",
    "Unable to search your cloud archive. Check your connection and try again.":
        "No se pudo buscar en tu archivo en la nube. Revisa la conexión e inténtalo de nuevo.",
    "Delete record": "Eliminar registro",
    "Delete game record?": "¿Eliminar el registro de partida?",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "Esto elimina el PGN guardado de tu cuenta Chessnut. Esta acción no se puede deshacer.",
    "From PGN": "Desde PGN",
    "From Lichess player": "Desde jugador de Lichess",
    "From Chess.com username": "Desde usuario de Chess.com",
    "Local list": "Lista local",
    "Cloud search failed": "Falló la búsqueda en la nube",
    "Previous page": "Página anterior",
    "Next page": "Página siguiente",
    "Import Chess.com games": "Importar partidas de Chess.com",
    "Import Lichess games": "Importar partidas de Lichess",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "Importa a Game Record las partidas públicas finalizadas de un usuario de Chess.com. Los archivos de Chess.com pueden tardar un poco en publicar partidas muy recientes.",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "Importa a Game Record las partidas finalizadas de un jugador de Lichess. Las duplicadas se omiten automáticamente.",
    "Player ID": "ID del jugador",
    "Rated only": "Solo puntuadas",
    "Casual only": "Solo amistosas",
    "Rated and casual": "Puntuadas y amistosas",
    "White games": "Partidas con blancas",
    "Black games": "Partidas con negras",
    "Start import": "Iniciar importación",
    "Enter a Chess.com username.": "Introduce un usuario de Chess.com.",
    "Enter a Lichess player ID.": "Introduce un ID de jugador de Lichess.",
    "Use points or upgrade Premium": "Usa puntos o mejora a Premium",
    "Standard plan": "Plan estándar",
    "Unable to preview Game Record.": "No se pudo previsualizar Game Record.",
    "Unable to check build progress.":
        "No se pudo comprobar el progreso de creación.",
    "Unable to cancel Model Build.":
        "No se pudo cancelar el entrenamiento del motor personal.",
    "Model Build queued": "Entrenamiento del motor personal en cola",
    "Model Build needs attention":
        "El entrenamiento del motor personal requiere atención",
    "Model Build failed": "El entrenamiento del motor personal falló",
    "Model Build canceled": "Entrenamiento del motor personal cancelado",
    "Paste a PGN before starting review.":
        "Pega un PGN antes de iniciar la revisión.",
    "Unable to start Grandeur review.":
        "No se pudo iniciar la revisión Grandeur.",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur está desbloqueado. Continuando el análisis del entrenador...",
    "Grandeur review is being prepared...":
        "Preparando la revisión Grandeur...",
    "Spend 100 points?": "¿Gastar 100 puntos?",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur usa puntos de cartera para la revisión del entrenador LLM.",
    "Current balance": "Saldo actual",
    "Original cost": "Coste original",
    "Member discount": "Descuento de miembro",
    "Pay today": "Pagar hoy",
    "Balance after review": "Saldo tras la revisión",
    "Start Grandeur review?": "¿Iniciar revisión Grandeur?",
    "Start Grandeur review": "Iniciar revisión Grandeur",
    "Not enough points": "No tienes puntos suficientes",
    "Sign in required": "Inicio de sesión requerido",
    "Grandeur review uses your wallet balance.":
        "La revisión Grandeur usa tu saldo de cartera.",
    "Wallet unavailable": "Cartera no disponible",
    "Checking wallet": "Comprobando cartera",
    "Grandeur report generating": "Generando informe Grandeur",
    "Current move": "Jugada actual",
    "No Grandeur commentary is available for this move yet.":
        "Aún no hay comentario de Grandeur para esta jugada.",
    "Stockfish analysis in progress": "Análisis de Stockfish en curso",
    "Preparing PGN positions for evaluation.":
        "Preparando posiciones PGN para evaluar.",
    "Review settings": "Ajustes de revisión",
    "Maia3 official rating model": "Modelo oficial de puntuación de Maia3",
    "Compare with Stockfish": "Comparar con Stockfish",
    "Show human likelihood next to the engine verdict.":
        "Muestra la probabilidad humana junto al veredicto del motor.",
    "Start Maia3 Review": "Iniciar revisión Maia3",
    "Choose the human rating to review against, then start Maia3.":
        "Elige la puntuación humana con la que revisar y luego inicia Maia3.",
    "Engine comparison": "Comparación de motores",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 explica la probabilidad humana. Stockfish comprueba la calidad objetiva.",
    "Natural and strong": "Natural y fuerte",
    "Common mistake": "Error común",
    "Engine-like move": "Jugada tipo motor",
    "Unusual mistake": "Error inusual",
    "Stockfish ready": "Stockfish listo",
    "Stockfish pending": "Stockfish pendiente",
    "Auto-renewing plans get the best price":
        "Los planes con renovación automática tienen el mejor precio",
    "Processing purchase": "Procesando compra",
    "Continue purchase": "Continuar compra",
    "Restore purchase": "Restaurar compra",
    "One-time access": "Acceso único",
    "Best price": "Mejor precio",
    "Sign in before upgrading membership.":
        "Inicia sesión antes de mejorar la membresía.",
    "Sign in before restoring purchases.":
        "Inicia sesión antes de restaurar compras.",
    "In-app purchase is available on iOS and Android.":
        "La compra dentro de la app está disponible en iOS y Android.",
    "Restore purchase is available on iOS and Android.":
        "Restaurar compra está disponible en iOS y Android.",
    "Purchase canceled. Your membership was not changed.":
        "Compra cancelada. Tu membresía no cambió.",
    "Purchase is still pending. Check your store account later.":
        "La compra sigue pendiente. Revisa tu cuenta de la tienda más tarde.",
    "No active membership purchase was found for this store account.":
        "No se encontró una compra de membresía activa para esta cuenta de la tienda.",
    "Premium is active.": "Premium está activo.",
    "VIP member": "Miembro VIP",
    "Valid until": "Válido hasta",
    "Renew membership": "Renovar membresía",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "Falló la verificación de compra. Revisa la red e intenta Restaurar compra.",
    "This record cannot be deleted from the cloud.":
        "Este registro no se puede eliminar de la nube.",
    "Lichess authorization expired. Re-authorize before continuing.":
        "La autorización de Lichess caducó. Autoriza de nuevo antes de continuar.",
    "Lichess authorized": "Lichess autorizado",
    "Connected as": "Conectado como",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "Tu cuenta de Chessnut ya está conectada a Lichess. Puedes mantener este vínculo o desvincularlo si quieres autorizar otra cuenta de Lichess.",
    "Keep linked": "Mantener vinculado",
    "Unlink Lichess": "Desvincular Lichess",
    "Lichess account unlinked.": "Cuenta de Lichess desvinculada.",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "La autorización de Lichess no se completó. Inténtalo de nuevo cuando la página de Lichess termine.",
    "I have authorized": "Ya autoricé",
    "Open in browser": "Abrir en el navegador",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "Vuelve a Chessnut después de aprobar la autorización de Lichess. Si la página se abrió en tu navegador, toca esto después de que indique que la autorización se realizó correctamente.",
    "Close authorization": "Cerrar autorización",
    "Linked accounts": "Cuentas vinculadas",
    "Linked account updated.": "Cuenta vinculada actualizada.",
    "Not linked": "No vinculado",
    "Default 791556": "Predeterminado 791556",
    "Built-in": "Integrado",
    "Local file": "Archivo local",
    "Playable engine library": "Biblioteca de motores jugables",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "Aún no hay motores personales jugables. Las compilaciones terminadas aparecerán aquí cuando estén listas para Bot game.",
    "Manage in Engine Lab": "Gestionar en Engine Lab",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "El entrenamiento, los informes y los motores personales jugables están en Engine Lab.",
    "Unavailable": "No disponible",
    "Check for updates": "Buscar actualizaciones",
    "Check whether a newer Chessnut version is available.":
        "Comprueba si hay una versión más reciente de Chessnut disponible.",
    "Update required": "Actualización obligatoria",
    "Update available": "Actualización disponible",
    "Later": "Más tarde",
    "Open store": "Abrir tienda",
    "Download update": "Descargar actualización",
    "Update now": "Actualizar ahora",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "Esta versión es necesaria para que Chessnut funcione correctamente. Actualiza antes de continuar.",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "Hay una versión más reciente disponible. Actualiza ahora para obtener las últimas correcciones y mejoras.",
    "This update will open the official app store or test track for your device.":
        "Esta actualización abrirá la tienda oficial de apps o el canal de pruebas de tu dispositivo.",
    "This update will open the official Chessnut download page.":
        "Esta actualización abrirá la página oficial de descargas de Chessnut.",
    "This update will open in your browser.":
        "Esta actualización se abrirá en tu navegador.",
    "You are using the latest version.":
        "Estás usando la versión más reciente.",
    "Could not check for updates. Please try again later.":
        "No se pudo buscar actualizaciones. Inténtalo de nuevo más tarde.",
    "Update link is not available right now. Please try again later.":
        "El enlace de actualización no está disponible ahora. Inténtalo de nuevo más tarde.",
    "Could not open the update link. Please try again later.":
        "No se pudo abrir el enlace de actualización. Inténtalo de nuevo más tarde.",
    "Import from image": "Importar desde imagen",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "¿Activar Chessnut Vision?",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision usa reconocimiento de imágenes para leer el tablero desde capturas de pantalla. Las capturas solo se usan para el reconocimiento mientras la función está activa; Chessnut no las guarda localmente ni conserva tus datos personales en este dispositivo.",
    "Not now": "Ahora no",
    "Enable Vision": "Activar Vision",
    "Chessnut Vision is on": "Chessnut Vision está activado",
    "Chessnut Vision is off": "Chessnut Vision está desactivado",
    "Chessnut Vision is now active.": "Chessnut Vision ya está activo.",
    "Turn on Chessnut Vision in Accessibility":
        "Activa Chessnut Vision en Accesibilidad",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision necesita el permiso de Accesibilidad de Android para leer la pantalla. Abre Ajustes y activa Chessnut Vision.",
    "Choose a clear board photo or take a new one.":
        "Elige una foto clara del tablero o toma una nueva.",
    "Choose a clear board image to recognize the position.":
        "Elige una imagen clara del tablero para reconocer la posición.",
    "Choose from gallery": "Elegir de la galería",
    "Take a photo": "Tomar una foto",
    "Recognizing board image...": "Reconociendo imagen del tablero...",
    "No image selected.": "No se seleccionó ninguna imagen.",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision no pudo reconocer esta posición.",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision no pudo leer esta imagen. Prueba con una foto más clara.",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision devolvió una posición que el tablero no pudo leer.",
    "Position imported from image.": "Posición importada desde la imagen.",
    "Import a board position from a photo.":
        "Importa una posición del tablero desde una foto.",
    "Choose image": "Elegir imagen",
    "Camera": "Cámara",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision no está disponible ahora. Inténtalo de nuevo más tarde.",
    "Choose a board image before using Chessnut Vision.":
        "Elige una imagen del tablero antes de usar Chessnut Vision.",
    "This image is too large. Choose an image under 10 MB.":
        "Esta imagen es demasiado grande. Elige una imagen de menos de 10 MB.",
    "This image could not be opened.": "No se pudo abrir esta imagen.",
    "This image could not be read.": "No se pudo leer esta imagen.",
    "Use a JPG, PNG, or WebP board image.":
        "Usa una imagen del tablero en formato JPG, PNG o WebP.",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision no pudo reconocer una posición válida en esta imagen.",
  },
  "fr": <String, String>{
    "Sound effects": "Effets sonores",
    "Moves, game starts, results, and key actions":
        "Coups, debuts de partie, resultats et actions cles",
    "Refresh records": "Actualiser les parties",
    "No cloud games found": "Aucune partie cloud trouvée",
    "Try fewer filters or import games from Lichess first.":
        "Réduisez les filtres ou importez d’abord des parties depuis Lichess.",
    "Back to local list": "Retour à la liste locale",
    "Finish this game before generating an analysis report.":
        "Terminez cette partie avant de générer un rapport d’analyse.",
    "Game record deleted.": "Partie supprimée.",
    "Unable to delete this game record.":
        "Impossible de supprimer cette partie.",
    "Unable to search your cloud archive. Check your connection and try again.":
        "Impossible de rechercher dans votre archive cloud. Vérifiez la connexion et réessayez.",
    "Delete record": "Supprimer la partie",
    "Delete game record?": "Supprimer cette partie ?",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "Cela supprime le PGN enregistré de votre compte Chessnut. Cette action est irréversible.",
    "From PGN": "Depuis PGN",
    "From Lichess player": "Depuis un joueur Lichess",
    "From Chess.com username": "Depuis un nom d’utilisateur Chess.com",
    "Local list": "Liste locale",
    "Cloud search failed": "Échec de la recherche cloud",
    "Previous page": "Page précédente",
    "Next page": "Page suivante",
    "Import Chess.com games": "Importer des parties Chess.com",
    "Import Lichess games": "Importer des parties Lichess",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "Importez dans Game Record les parties publiques terminées d’un nom d’utilisateur Chess.com. Les archives Chess.com peuvent mettre un peu de temps à publier les parties très récentes.",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "Importez dans Game Record les parties terminées d’un joueur Lichess. Les doublons sont ignorés automatiquement.",
    "Player ID": "ID du joueur",
    "Rated only": "Classées uniquement",
    "Casual only": "Amicales uniquement",
    "Rated and casual": "Classées et amicales",
    "White games": "Parties avec les blancs",
    "Black games": "Parties avec les noirs",
    "Start import": "Lancer l’import",
    "Enter a Chess.com username.": "Saisissez un nom d’utilisateur Chess.com.",
    "Enter a Lichess player ID.": "Saisissez un ID de joueur Lichess.",
    "Use points or upgrade Premium": "Utiliser des points ou passer à Premium",
    "Standard plan": "Formule standard",
    "Unable to preview Game Record.":
        "Impossible de prévisualiser Game Record.",
    "Unable to check build progress.":
        "Impossible de vérifier la progression de création.",
    "Unable to cancel Model Build.":
        "Impossible d’annuler l’entraînement du moteur personnel.",
    "Model Build queued": "Entraînement du moteur personnel en file d’attente",
    "Model Build needs attention":
        "L’entraînement du moteur personnel nécessite votre attention",
    "Model Build failed": "Échec de l’entraînement du moteur personnel",
    "Model Build canceled": "Entraînement du moteur personnel annulé",
    "Paste a PGN before starting review.":
        "Collez un PGN avant de démarrer la revue.",
    "Unable to start Grandeur review.":
        "Impossible de lancer la revue Grandeur.",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur est déverrouillé. L’analyse du coach continue...",
    "Grandeur review is being prepared...":
        "Préparation de la revue Grandeur...",
    "Spend 100 points?": "Dépenser 100 points ?",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur utilise les points du portefeuille pour la revue coach LLM.",
    "Current balance": "Solde actuel",
    "Original cost": "Coût initial",
    "Member discount": "Remise membre",
    "Pay today": "À payer aujourd’hui",
    "Balance after review": "Solde après la revue",
    "Start Grandeur review?": "Lancer la revue Grandeur ?",
    "Start Grandeur review": "Lancer la revue Grandeur",
    "Not enough points": "Points insuffisants",
    "Sign in required": "Connexion requise",
    "Grandeur review uses your wallet balance.":
        "La revue Grandeur utilise le solde de votre portefeuille.",
    "Wallet unavailable": "Portefeuille indisponible",
    "Checking wallet": "Vérification du portefeuille",
    "Grandeur report generating": "Génération du rapport Grandeur",
    "Current move": "Coup actuel",
    "No Grandeur commentary is available for this move yet.":
        "Aucun commentaire Grandeur n’est encore disponible pour ce coup.",
    "Stockfish analysis in progress": "Analyse Stockfish en cours",
    "Preparing PGN positions for evaluation.":
        "Préparation des positions PGN pour l’évaluation.",
    "Review settings": "Paramètres de révision",
    "Maia3 official rating model": "Modèle de classement officiel Maia3",
    "Compare with Stockfish": "Comparer avec Stockfish",
    "Show human likelihood next to the engine verdict.":
        "Affichez la probabilité humaine à côté du verdict du moteur.",
    "Start Maia3 Review": "Lancer la révision Maia3",
    "Choose the human rating to review against, then start Maia3.":
        "Choisissez le classement humain de référence, puis lancez Maia3.",
    "Engine comparison": "Comparaison des moteurs",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 explique la probabilité humaine. Stockfish vérifie la qualité objective.",
    "Natural and strong": "Naturel et fort",
    "Common mistake": "Erreur courante",
    "Engine-like move": "Coup de type moteur",
    "Unusual mistake": "Erreur inhabituelle",
    "Stockfish ready": "Stockfish prêt",
    "Stockfish pending": "Stockfish en attente",
    "Auto-renewing plans get the best price":
        "Les formules renouvelées automatiquement offrent le meilleur prix",
    "Processing purchase": "Traitement de l’achat",
    "Continue purchase": "Continuer l’achat",
    "Restore purchase": "Restaurer l’achat",
    "One-time access": "Accès unique",
    "Best price": "Meilleur prix",
    "Sign in before upgrading membership.":
        "Connectez-vous avant de passer à l’abonnement supérieur.",
    "Sign in before restoring purchases.":
        "Connectez-vous avant de restaurer les achats.",
    "In-app purchase is available on iOS and Android.":
        "L’achat intégré est disponible sur iOS et Android.",
    "Restore purchase is available on iOS and Android.":
        "La restauration des achats est disponible sur iOS et Android.",
    "Purchase canceled. Your membership was not changed.":
        "Achat annulé. Votre abonnement n’a pas été modifié.",
    "Purchase is still pending. Check your store account later.":
        "L’achat est toujours en attente. Vérifiez votre compte store plus tard.",
    "No active membership purchase was found for this store account.":
        "Aucun achat d’abonnement actif n’a été trouvé pour ce compte store.",
    "Premium is active.": "Premium est actif.",
    "VIP member": "Membre VIP",
    "Valid until": "Valable jusqu’au",
    "Renew membership": "Renouveler l’abonnement",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "Échec de la vérification d’achat. Vérifiez le réseau et essayez de restaurer l’achat.",
    "This record cannot be deleted from the cloud.":
        "Cette partie ne peut pas être supprimée du cloud.",
    "Lichess authorization expired. Re-authorize before continuing.":
        "L’autorisation Lichess a expiré. Réautorisez avant de continuer.",
    "Lichess authorized": "Lichess autorisé",
    "Connected as": "Connecté en tant que",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "Votre compte Chessnut est déjà connecté à Lichess. Vous pouvez conserver ce lien ou le dissocier si vous voulez autoriser un autre compte Lichess.",
    "Keep linked": "Conserver le lien",
    "Unlink Lichess": "Dissocier Lichess",
    "Lichess account unlinked.": "Compte Lichess dissocié.",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "L’autorisation Lichess n’a pas été terminée. Réessayez lorsque la page Lichess a terminé.",
    "I have authorized": "J’ai autorisé",
    "Open in browser": "Ouvrir dans le navigateur",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "Revenez à Chessnut après avoir approuvé l’autorisation Lichess. Si la page s’est ouverte dans votre navigateur, touchez ceci après qu’elle indique que l’autorisation a réussi.",
    "Close authorization": "Fermer l’autorisation",
    "Linked accounts": "Comptes liés",
    "Linked account updated.": "Compte lié mis à jour.",
    "Not linked": "Non lié",
    "Default 791556": "Par défaut 791556",
    "Built-in": "Intégré",
    "Local file": "Fichier local",
    "Playable engine library": "Bibliothèque de moteurs jouables",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "Aucun moteur personnel jouable pour le moment. Les builds terminés apparaîtront ici lorsqu’ils seront prêts pour Bot game.",
    "Manage in Engine Lab": "Gérer dans Engine Lab",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "L’entraînement, les rapports et les moteurs personnels jouables se trouvent dans Engine Lab.",
    "Unavailable": "Indisponible",
    "Check for updates": "Rechercher des mises à jour",
    "Check whether a newer Chessnut version is available.":
        "Vérifier si une version plus récente de Chessnut est disponible.",
    "Update required": "Mise à jour requise",
    "Update available": "Mise à jour disponible",
    "Later": "Plus tard",
    "Open store": "Ouvrir la boutique",
    "Download update": "Télécharger la mise à jour",
    "Update now": "Mettre à jour",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "Cette version est requise pour que Chessnut fonctionne correctement. Veuillez mettre à jour avant de continuer.",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "Une version plus récente est disponible. Mettez à jour maintenant pour obtenir les derniers correctifs et améliorations.",
    "This update will open the official app store or test track for your device.":
        "Cette mise à jour ouvrira la boutique officielle d'apps ou le canal de test de votre appareil.",
    "This update will open the official Chessnut download page.":
        "Cette mise à jour ouvrira la page officielle de téléchargement de Chessnut.",
    "This update will open in your browser.":
        "Cette mise à jour s'ouvrira dans votre navigateur.",
    "You are using the latest version.": "Vous utilisez la dernière version.",
    "Could not check for updates. Please try again later.":
        "Impossible de rechercher des mises à jour. Veuillez réessayer plus tard.",
    "Update link is not available right now. Please try again later.":
        "Le lien de mise à jour n'est pas disponible pour le moment. Veuillez réessayer plus tard.",
    "Could not open the update link. Please try again later.":
        "Impossible d'ouvrir le lien de mise à jour. Veuillez réessayer plus tard.",
    "Import from image": "Importer depuis une image",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "Activer Chessnut Vision ?",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision utilise la reconnaissance d’image pour lire l’échiquier à partir de captures d’écran. Les captures ne sont utilisées que pour la reconnaissance pendant que la fonctionnalité est active ; Chessnut ne les enregistre pas localement et ne conserve pas vos données personnelles sur cet appareil.",
    "Not now": "Pas maintenant",
    "Enable Vision": "Activer Vision",
    "Chessnut Vision is on": "Chessnut Vision est activé",
    "Chessnut Vision is off": "Chessnut Vision est désactivé",
    "Chessnut Vision is now active.": "Chessnut Vision est maintenant actif.",
    "Turn on Chessnut Vision in Accessibility":
        "Activez Chessnut Vision dans Accessibilité",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision a besoin de l’autorisation d’accessibilité Android avant de pouvoir lire l’écran. Ouvrez les réglages et activez Chessnut Vision.",
    "Choose a clear board photo or take a new one.":
        "Choisissez une photo claire de l’échiquier ou prenez-en une nouvelle.",
    "Choose a clear board image to recognize the position.":
        "Choisissez une image claire de l’échiquier pour reconnaître la position.",
    "Choose from gallery": "Choisir dans la galerie",
    "Take a photo": "Prendre une photo",
    "Recognizing board image...": "Reconnaissance de l’image de l’échiquier...",
    "No image selected.": "Aucune image sélectionnée.",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision n’a pas pu reconnaître cette position.",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision n’a pas pu lire cette image. Essayez une photo plus nette.",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision a renvoyé une position que l’échiquier n’a pas pu lire.",
    "Position imported from image.": "Position importée depuis l’image.",
    "Import a board position from a photo.":
        "Importez une position de l’échiquier depuis une photo.",
    "Choose image": "Choisir une image",
    "Camera": "Appareil photo",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision n’est pas disponible pour le moment. Veuillez réessayer plus tard.",
    "Choose a board image before using Chessnut Vision.":
        "Choisissez une image de l’échiquier avant d’utiliser Chessnut Vision.",
    "This image is too large. Choose an image under 10 MB.":
        "Cette image est trop volumineuse. Choisissez une image de moins de 10 Mo.",
    "This image could not be opened.": "Impossible d’ouvrir cette image.",
    "This image could not be read.": "Impossible de lire cette image.",
    "Use a JPG, PNG, or WebP board image.":
        "Utilisez une image d’échiquier au format JPG, PNG ou WebP.",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision n’a pas pu reconnaître de position valide dans cette image.",
  },
  "it": <String, String>{
    "Sound effects": "Effetti sonori",
    "Moves, game starts, results, and key actions":
        "Mosse, inizio partita, risultati e azioni chiave",
    "Refresh records": "Aggiorna registri",
    "No cloud games found": "Nessuna partita cloud trovata",
    "Try fewer filters or import games from Lichess first.":
        "Usa meno filtri o importa prima le partite da Lichess.",
    "Back to local list": "Torna all’elenco locale",
    "Finish this game before generating an analysis report.":
        "Completa questa partita prima di generare un report di analisi.",
    "Game record deleted.": "Registro partita eliminato.",
    "Unable to delete this game record.":
        "Impossibile eliminare questo registro partita.",
    "Unable to search your cloud archive. Check your connection and try again.":
        "Impossibile cercare nell’archivio cloud. Controlla la connessione e riprova.",
    "Delete record": "Elimina registro",
    "Delete game record?": "Eliminare il registro partita?",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "Rimuove il PGN salvato dal tuo account Chessnut. L’azione non può essere annullata.",
    "From PGN": "Da PGN",
    "From Lichess player": "Da giocatore Lichess",
    "From Chess.com username": "Da username Chess.com",
    "Local list": "Elenco locale",
    "Cloud search failed": "Ricerca cloud non riuscita",
    "Previous page": "Pagina precedente",
    "Next page": "Pagina successiva",
    "Import Chess.com games": "Importa partite Chess.com",
    "Import Lichess games": "Importa partite Lichess",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "Importa in Game Record le partite pubbliche concluse di uno username Chess.com. Gli archivi Chess.com possono impiegare un po’ a pubblicare le partite più recenti.",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "Importa in Game Record le partite concluse di un giocatore Lichess. I duplicati vengono saltati automaticamente.",
    "Player ID": "ID giocatore",
    "Rated only": "Solo classificate",
    "Casual only": "Solo amichevoli",
    "Rated and casual": "Classificate e amichevoli",
    "White games": "Partite con il Bianco",
    "Black games": "Partite con il Nero",
    "Start import": "Avvia importazione",
    "Enter a Chess.com username.": "Inserisci uno username Chess.com.",
    "Enter a Lichess player ID.": "Inserisci un ID giocatore Lichess.",
    "Use points or upgrade Premium": "Usa punti o passa a Premium",
    "Standard plan": "Piano standard",
    "Unable to preview Game Record.":
        "Impossibile visualizzare l’anteprima di Game Record.",
    "Unable to check build progress.":
        "Impossibile controllare l’avanzamento della build.",
    "Unable to cancel Model Build.":
        "Impossibile annullare l’allenamento del motore personale.",
    "Model Build queued": "Allenamento del motore personale in coda",
    "Model Build needs attention":
        "L’allenamento del motore personale richiede attenzione",
    "Model Build failed": "Allenamento del motore personale non riuscito",
    "Model Build canceled": "Allenamento del motore personale annullato",
    "Paste a PGN before starting review.":
        "Incolla un PGN prima di avviare la revisione.",
    "Unable to start Grandeur review.":
        "Impossibile avviare la revisione Grandeur.",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur è sbloccato. Continuo l’analisi coach...",
    "Grandeur review is being prepared...":
        "Preparazione della revisione Grandeur...",
    "Spend 100 points?": "Spendere 100 punti?",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur usa punti portafoglio per la revisione coach LLM.",
    "Current balance": "Saldo attuale",
    "Original cost": "Costo originale",
    "Member discount": "Sconto membro",
    "Pay today": "Paghi oggi",
    "Balance after review": "Saldo dopo la revisione",
    "Start Grandeur review?": "Avviare revisione Grandeur?",
    "Start Grandeur review": "Avvia revisione Grandeur",
    "Not enough points": "Punti insufficienti",
    "Sign in required": "Accesso richiesto",
    "Grandeur review uses your wallet balance.":
        "La revisione Grandeur usa il saldo del tuo portafoglio.",
    "Wallet unavailable": "Portafoglio non disponibile",
    "Checking wallet": "Controllo portafoglio",
    "Grandeur report generating": "Generazione report Grandeur",
    "Current move": "Mossa attuale",
    "No Grandeur commentary is available for this move yet.":
        "Nessun commento Grandeur disponibile per questa mossa.",
    "Stockfish analysis in progress": "Analisi Stockfish in corso",
    "Preparing PGN positions for evaluation.":
        "Preparazione delle posizioni PGN per la valutazione.",
    "Review settings": "Impostazioni revisione",
    "Maia3 official rating model": "Modello ufficiale di punteggio Maia3",
    "Compare with Stockfish": "Confronta con Stockfish",
    "Show human likelihood next to the engine verdict.":
        "Mostra la probabilità umana accanto al verdetto del motore.",
    "Start Maia3 Review": "Avvia revisione Maia3",
    "Choose the human rating to review against, then start Maia3.":
        "Scegli il punteggio umano con cui confrontare la revisione, poi avvia Maia3.",
    "Engine comparison": "Confronto motori",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 spiega la probabilità umana. Stockfish verifica la qualità oggettiva.",
    "Natural and strong": "Naturale e forte",
    "Common mistake": "Errore comune",
    "Engine-like move": "Mossa da motore",
    "Unusual mistake": "Errore insolito",
    "Stockfish ready": "Stockfish pronto",
    "Stockfish pending": "Stockfish in attesa",
    "Auto-renewing plans get the best price":
        "I piani con rinnovo automatico hanno il prezzo migliore",
    "Processing purchase": "Elaborazione acquisto",
    "Continue purchase": "Continua acquisto",
    "Restore purchase": "Ripristina acquisto",
    "One-time access": "Accesso una tantum",
    "Best price": "Prezzo migliore",
    "Sign in before upgrading membership.":
        "Accedi prima di aggiornare l’abbonamento.",
    "Sign in before restoring purchases.":
        "Accedi prima di ripristinare gli acquisti.",
    "In-app purchase is available on iOS and Android.":
        "Gli acquisti in-app sono disponibili su iOS e Android.",
    "Restore purchase is available on iOS and Android.":
        "Il ripristino acquisti è disponibile su iOS e Android.",
    "Purchase canceled. Your membership was not changed.":
        "Acquisto annullato. Il tuo abbonamento non è cambiato.",
    "Purchase is still pending. Check your store account later.":
        "L’acquisto è ancora in sospeso. Controlla più tardi l’account dello store.",
    "No active membership purchase was found for this store account.":
        "Nessun acquisto abbonamento attivo trovato per questo account store.",
    "Premium is active.": "Premium è attivo.",
    "VIP member": "Membro VIP",
    "Valid until": "Valido fino al",
    "Renew membership": "Rinnova abbonamento",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "Verifica acquisto non riuscita. Controlla la rete e prova Ripristina acquisto.",
    "This record cannot be deleted from the cloud.":
        "Questo registro non può essere eliminato dal cloud.",
    "Lichess authorization expired. Re-authorize before continuing.":
        "L’autorizzazione Lichess è scaduta. Autorizza di nuovo prima di continuare.",
    "Lichess authorized": "Lichess autorizzato",
    "Connected as": "Collegato come",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "Il tuo account Chessnut è già collegato a Lichess. Puoi mantenere questo collegamento o scollegarlo se vuoi autorizzare un altro account Lichess.",
    "Keep linked": "Mantieni collegato",
    "Unlink Lichess": "Scollega Lichess",
    "Lichess account unlinked.": "Account Lichess scollegato.",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "L’autorizzazione Lichess non è stata completata. Riprova quando la pagina Lichess ha finito.",
    "I have authorized": "Ho autorizzato",
    "Open in browser": "Apri nel browser",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "Torna a Chessnut dopo aver approvato l’autorizzazione Lichess. Se la pagina si è aperta nel browser, tocca questo dopo che indica che l’autorizzazione è riuscita.",
    "Close authorization": "Chiudi autorizzazione",
    "Linked accounts": "Account collegati",
    "Linked account updated.": "Account collegato aggiornato.",
    "Not linked": "Non collegato",
    "Default 791556": "Predefinito 791556",
    "Built-in": "Integrato",
    "Local file": "File locale",
    "Playable engine library": "Libreria di motori giocabili",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "Non ci sono ancora motori personali giocabili. Le build completate appariranno qui quando saranno pronte per Bot game.",
    "Manage in Engine Lab": "Gestisci in Engine Lab",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "Allenamento, report e motori personali giocabili si trovano in Engine Lab.",
    "Unavailable": "Non disponibile",
    "Check for updates": "Controlla aggiornamenti",
    "Check whether a newer Chessnut version is available.":
        "Controlla se è disponibile una versione più recente di Chessnut.",
    "Update required": "Aggiornamento richiesto",
    "Update available": "Aggiornamento disponibile",
    "Later": "Più tardi",
    "Open store": "Apri store",
    "Download update": "Scarica aggiornamento",
    "Update now": "Aggiorna ora",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "Questa versione è necessaria per mantenere Chessnut funzionante correttamente. Aggiorna prima di continuare.",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "È disponibile una versione più recente. Aggiorna ora per ottenere le ultime correzioni e miglioramenti.",
    "This update will open the official app store or test track for your device.":
        "Questo aggiornamento aprirà l'app store ufficiale o il canale di test per il tuo dispositivo.",
    "This update will open the official Chessnut download page.":
        "Questo aggiornamento aprirà la pagina ufficiale di download di Chessnut.",
    "This update will open in your browser.":
        "Questo aggiornamento si aprirà nel browser.",
    "You are using the latest version.": "Stai usando la versione più recente.",
    "Could not check for updates. Please try again later.":
        "Impossibile controllare gli aggiornamenti. Riprova più tardi.",
    "Update link is not available right now. Please try again later.":
        "Il link di aggiornamento non è disponibile al momento. Riprova più tardi.",
    "Could not open the update link. Please try again later.":
        "Impossibile aprire il link di aggiornamento. Riprova più tardi.",
    "Import from image": "Importa da immagine",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "Attivare Chessnut Vision?",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision usa il riconoscimento delle immagini per leggere la scacchiera dagli screenshot. Gli screenshot vengono usati solo per il riconoscimento mentre la funzione è attiva; Chessnut non li salva localmente né conserva i tuoi dati personali su questo dispositivo.",
    "Not now": "Non ora",
    "Enable Vision": "Attiva Vision",
    "Chessnut Vision is on": "Chessnut Vision è attivo",
    "Chessnut Vision is off": "Chessnut Vision è disattivato",
    "Chessnut Vision is now active.": "Chessnut Vision è ora attivo.",
    "Turn on Chessnut Vision in Accessibility":
        "Attiva Chessnut Vision in Accessibilità",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision richiede l’autorizzazione Accessibilità di Android prima di poter leggere lo schermo. Apri le impostazioni e attiva Chessnut Vision.",
    "Choose a clear board photo or take a new one.":
        "Scegli una foto chiara della scacchiera o scattane una nuova.",
    "Choose a clear board image to recognize the position.":
        "Scegli un’immagine chiara della scacchiera per riconoscere la posizione.",
    "Choose from gallery": "Scegli dalla galleria",
    "Take a photo": "Scatta una foto",
    "Recognizing board image...":
        "Riconoscimento dell’immagine della scacchiera...",
    "No image selected.": "Nessuna immagine selezionata.",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision non ha potuto riconoscere questa posizione.",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision non ha potuto leggere questa immagine. Prova con una foto più nitida.",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision ha restituito una posizione che la scacchiera non ha potuto leggere.",
    "Position imported from image.": "Posizione importata dall’immagine.",
    "Import a board position from a photo.":
        "Importa una posizione della scacchiera da una foto.",
    "Choose image": "Scegli immagine",
    "Camera": "Fotocamera",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision non è disponibile al momento. Riprova più tardi.",
    "Choose a board image before using Chessnut Vision.":
        "Scegli un’immagine della scacchiera prima di usare Chessnut Vision.",
    "This image is too large. Choose an image under 10 MB.":
        "Questa immagine è troppo grande. Scegli un’immagine sotto i 10 MB.",
    "This image could not be opened.": "Impossibile aprire questa immagine.",
    "This image could not be read.": "Impossibile leggere questa immagine.",
    "Use a JPG, PNG, or WebP board image.":
        "Usa un’immagine della scacchiera in formato JPG, PNG o WebP.",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision non ha potuto riconoscere una posizione valida da questa immagine.",
  },
  "ja": <String, String>{
    "Sound effects": "効果音",
    "Moves, game starts, results, and key actions": "手、対局開始、結果、主な操作",
    "Refresh records": "記録を更新",
    "No cloud games found": "クラウド対局が見つかりません",
    "Try fewer filters or import games from Lichess first.":
        "フィルターを減らすか、先に Lichess から対局をインポートしてください。",
    "Back to local list": "ローカル一覧に戻る",
    "Finish this game before generating an analysis report.":
        "分析レポートを作成する前に、この対局を終了してください。",
    "Game record deleted.": "対局記録を削除しました。",
    "Unable to delete this game record.": "この対局記録を削除できません。",
    "Unable to search your cloud archive. Check your connection and try again.":
        "クラウドアーカイブを検索できません。接続を確認してもう一度お試しください。",
    "Delete record": "記録を削除",
    "Delete game record?": "対局記録を削除しますか？",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "保存済みの PGN が Chessnut アカウントから削除されます。この操作は取り消せません。",
    "From PGN": "PGN から",
    "From Lichess player": "Lichess プレイヤーから",
    "From Chess.com username": "Chess.com ユーザー名から",
    "Local list": "ローカル一覧",
    "Cloud search failed": "クラウド検索に失敗しました",
    "Previous page": "前のページ",
    "Next page": "次のページ",
    "Import Chess.com games": "Chess.com の対局をインポート",
    "Import Lichess games": "Lichess の対局をインポート",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "Chess.com ユーザー名の公開済み終了対局を Game Record にインポートします。直近の対局は Chess.com アーカイブに反映されるまで少し時間がかかる場合があります。",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "Lichess プレイヤーの終了済み対局を Game Record にインポートします。重複した対局は自動的にスキップされます。",
    "Player ID": "プレイヤー ID",
    "Rated only": "レート戦のみ",
    "Casual only": "カジュアルのみ",
    "Rated and casual": "レート戦とカジュアル",
    "White games": "白番の対局",
    "Black games": "黒番の対局",
    "Start import": "インポート開始",
    "Enter a Chess.com username.": "Chess.com ユーザー名を入力してください。",
    "Enter a Lichess player ID.": "Lichess プレイヤー ID を入力してください。",
    "Use points or upgrade Premium": "ポイントを使うか Premium にアップグレード",
    "Standard plan": "標準プラン",
    "Unable to preview Game Record.": "Game Record をプレビューできません。",
    "Unable to check build progress.": "ビルド進行状況を確認できません。",
    "Unable to cancel Model Build.": "個人エンジンのトレーニングをキャンセルできません。",
    "Model Build queued": "個人エンジンのトレーニングはキューに入りました",
    "Model Build needs attention": "個人エンジンのトレーニングの確認が必要です",
    "Model Build failed": "個人エンジンのトレーニングに失敗しました",
    "Model Build canceled": "個人エンジンのトレーニングをキャンセルしました",
    "Paste a PGN before starting review.": "レビューを開始する前に PGN を貼り付けてください。",
    "Unable to start Grandeur review.": "Grandeur レビューを開始できません。",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur が解除されました。コーチ分析を続行しています...",
    "Grandeur review is being prepared...": "Grandeur レビューを準備しています...",
    "Spend 100 points?": "100 ポイントを使いますか？",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur は LLM コーチレビューにウォレットポイントを使用します。",
    "Current balance": "現在の残高",
    "Original cost": "元の費用",
    "Member discount": "メンバー割引",
    "Pay today": "本日支払い",
    "Balance after review": "レビュー後の残高",
    "Start Grandeur review?": "Grandeur レビューを開始しますか？",
    "Start Grandeur review": "Grandeur レビューを開始",
    "Not enough points": "ポイントが不足しています",
    "Sign in required": "サインインが必要です",
    "Grandeur review uses your wallet balance.": "Grandeur レビューはウォレット残高を使用します。",
    "Wallet unavailable": "ウォレットを利用できません",
    "Checking wallet": "ウォレットを確認中",
    "Grandeur report generating": "Grandeur レポートを生成中",
    "Current move": "現在の手",
    "No Grandeur commentary is available for this move yet.":
        "この手の Grandeur コメントはまだありません。",
    "Stockfish analysis in progress": "Stockfish 解析中",
    "Preparing PGN positions for evaluation.": "評価用の PGN 局面を準備しています。",
    "Review settings": "レビュー設定",
    "Maia3 official rating model": "Maia3 公式レーティングモデル",
    "Compare with Stockfish": "Stockfish と比較",
    "Show human likelihood next to the engine verdict.":
        "エンジン判定の横に人間らしさの確率を表示します。",
    "Start Maia3 Review": "Maia3 レビューを開始",
    "Choose the human rating to review against, then start Maia3.":
        "比較する人間のレーティングを選び、Maia3 を開始します。",
    "Engine comparison": "エンジン比較",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 は人間らしさの確率を説明し、Stockfish は客観的な質を確認します。",
    "Natural and strong": "自然で強い手",
    "Common mistake": "よくあるミス",
    "Engine-like move": "エンジン風の手",
    "Unusual mistake": "珍しいミス",
    "Stockfish ready": "Stockfish 準備完了",
    "Stockfish pending": "Stockfish 待機中",
    "Auto-renewing plans get the best price": "自動更新プランが最もお得です",
    "Processing purchase": "購入を処理中",
    "Continue purchase": "購入を続ける",
    "Restore purchase": "購入を復元",
    "One-time access": "1回限りのアクセス",
    "Best price": "ベスト価格",
    "Sign in before upgrading membership.": "メンバーシップをアップグレードする前にサインインしてください。",
    "Sign in before restoring purchases.": "購入を復元する前にサインインしてください。",
    "In-app purchase is available on iOS and Android.":
        "アプリ内購入は iOS と Android で利用できます。",
    "Restore purchase is available on iOS and Android.":
        "購入の復元は iOS と Android で利用できます。",
    "Purchase canceled. Your membership was not changed.":
        "購入はキャンセルされました。メンバーシップは変更されていません。",
    "Purchase is still pending. Check your store account later.":
        "購入はまだ保留中です。後でストアアカウントを確認してください。",
    "No active membership purchase was found for this store account.":
        "このストアアカウントに有効なメンバーシップ購入は見つかりませんでした。",
    "Premium is active.": "Premium が有効です。",
    "VIP member": "VIPメンバー",
    "Valid until": "有効期限",
    "Renew membership": "メンバーシップを更新",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "購入の確認に失敗しました。ネットワークを確認して「購入を復元」をお試しください。",
    "This record cannot be deleted from the cloud.": "この記録はクラウドから削除できません。",
    "Lichess authorization expired. Re-authorize before continuing.":
        "Lichess 認証の期限が切れました。続行する前に再認証してください。",
    "Lichess authorized": "Lichessの認証が完了しました",
    "Connected as": "接続中のアカウント",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "あなたの Chessnut アカウントはすでに Lichess に接続されています。この接続を維持するか、別の Lichess アカウントを認証したい場合は解除できます。",
    "Keep linked": "接続を維持",
    "Unlink Lichess": "Lichess 連携を解除",
    "Lichess account unlinked.": "Lichess アカウントの連携を解除しました。",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "Lichess の認証は完了していません。Lichess ページの処理が完了したらもう一度お試しください。",
    "I have authorized": "認証しました",
    "Open in browser": "ブラウザで開く",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "Lichess 認証を承認したら Chessnut に戻ってください。ページがブラウザで開いた場合は、認証成功と表示された後にこれをタップしてください。",
    "Close authorization": "認証を閉じる",
    "Linked accounts": "連携済みアカウント",
    "Linked account updated.": "連携アカウントを更新しました。",
    "Not linked": "未連携",
    "Default 791556": "デフォルト 791556",
    "Built-in": "内蔵",
    "Local file": "ローカルファイル",
    "Playable engine library": "対局できるエンジンライブラリ",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "プレイ可能な個人エンジンはまだありません。Bot game で使えるようになると、完了したビルドがここに表示されます。",
    "Manage in Engine Lab": "Engine Lab で管理",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "トレーニング、レポート、プレイ可能な個人エンジンは Engine Lab にあります。",
    "Unavailable": "利用不可",
    "Check for updates": "アップデートを確認",
    "Check whether a newer Chessnut version is available.":
        "新しい Chessnut バージョンが利用可能か確認します。",
    "Update required": "アップデートが必要です",
    "Update available": "アップデートがあります",
    "Later": "あとで",
    "Open store": "ストアを開く",
    "Download update": "アップデートをダウンロード",
    "Update now": "今すぐ更新",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "Chessnut を正常に動作させるには、このバージョンへの更新が必要です。続行する前にアップデートしてください。",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "新しいバージョンがあります。最新の修正と改善を入手するには、今すぐ更新してください。",
    "This update will open the official app store or test track for your device.":
        "このアップデートでは、お使いのデバイス向けの公式アプリストアまたはテストトラックを開きます。",
    "This update will open the official Chessnut download page.":
        "このアップデートでは、Chessnut の公式ダウンロードページを開きます。",
    "This update will open in your browser.": "このアップデートはブラウザーで開きます。",
    "You are using the latest version.": "最新バージョンを使用しています。",
    "Could not check for updates. Please try again later.":
        "アップデートを確認できませんでした。後でもう一度お試しください。",
    "Update link is not available right now. Please try again later.":
        "現在、アップデートリンクは利用できません。後でもう一度お試しください。",
    "Could not open the update link. Please try again later.":
        "アップデートリンクを開けませんでした。後でもう一度お試しください。",
    "Import from image": "画像からインポート",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "Chessnut Vision を有効にしますか？",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision は画像認識を使ってスクリーンショットからボードを読み取ります。スクリーンショットは機能の実行中、認識にのみ使用されます。Chessnut がこのデバイスにスクリーンショットをローカル保存したり、個人データを保持したりすることはありません。",
    "Not now": "今はしない",
    "Enable Vision": "Vision を有効化",
    "Chessnut Vision is on": "Chessnut Vision はオンです",
    "Chessnut Vision is off": "Chessnut Vision はオフです",
    "Chessnut Vision is now active.": "Chessnut Vision が有効になりました。",
    "Turn on Chessnut Vision in Accessibility":
        "アクセシビリティで Chessnut Vision をオンにする",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision が画面を読み取るには、先に Android のアクセシビリティ権限が必要です。設定を開き、Chessnut Vision をオンにしてください。",
    "Choose a clear board photo or take a new one.":
        "鮮明なボード写真を選ぶか、新しく撮影してください。",
    "Choose a clear board image to recognize the position.":
        "局面を認識するため、鮮明なボード画像を選んでください。",
    "Choose from gallery": "ギャラリーから選択",
    "Take a photo": "写真を撮影",
    "Recognizing board image...": "ボード画像を認識しています...",
    "No image selected.": "画像が選択されていません。",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision はこの局面を認識できませんでした。",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision はこの画像を読み取れませんでした。より鮮明な写真をお試しください。",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision が返した局面をボードが読み取れませんでした。",
    "Position imported from image.": "画像から局面をインポートしました。",
    "Import a board position from a photo.": "写真からボード局面をインポートします。",
    "Choose image": "画像を選択",
    "Camera": "カメラ",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision は現在利用できません。後でもう一度お試しください。",
    "Choose a board image before using Chessnut Vision.":
        "Chessnut Vision を使う前にボード画像を選んでください。",
    "This image is too large. Choose an image under 10 MB.":
        "この画像は大きすぎます。10 MB 未満の画像を選んでください。",
    "This image could not be opened.": "この画像を開けませんでした。",
    "This image could not be read.": "この画像を読み取れませんでした。",
    "Use a JPG, PNG, or WebP board image.": "JPG、PNG、または WebP のボード画像を使用してください。",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision はこの画像から有効な局面を認識できませんでした。",
  },
  "ko": <String, String>{
    "Sound effects": "효과음",
    "Moves, game starts, results, and key actions": "수, 대국 시작, 결과 및 주요 동작",
    "Refresh records": "기록 새로고침",
    "No cloud games found": "클라우드 대국을 찾을 수 없습니다",
    "Try fewer filters or import games from Lichess first.":
        "필터를 줄이거나 먼저 Lichess에서 대국을 가져오세요.",
    "Back to local list": "로컬 목록으로 돌아가기",
    "Finish this game before generating an analysis report.":
        "분석 리포트를 만들기 전에 이 대국을 끝내세요.",
    "Game record deleted.": "대국 기록이 삭제되었습니다.",
    "Unable to delete this game record.": "이 대국 기록을 삭제할 수 없습니다.",
    "Unable to search your cloud archive. Check your connection and try again.":
        "클라우드 보관함을 검색할 수 없습니다. 연결을 확인하고 다시 시도하세요.",
    "Delete record": "기록 삭제",
    "Delete game record?": "대국 기록을 삭제할까요?",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "저장된 PGN이 Chessnut 계정에서 삭제됩니다. 이 작업은 되돌릴 수 없습니다.",
    "From PGN": "PGN에서",
    "From Lichess player": "Lichess 플레이어에서",
    "From Chess.com username": "Chess.com 사용자 이름에서",
    "Local list": "로컬 목록",
    "Cloud search failed": "클라우드 검색 실패",
    "Previous page": "이전 페이지",
    "Next page": "다음 페이지",
    "Import Chess.com games": "Chess.com 대국 가져오기",
    "Import Lichess games": "Lichess 대국 가져오기",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "Chess.com 사용자 이름의 공개 완료 대국을 Game Record로 가져옵니다. 아주 최근 대국은 Chess.com 보관함에 게시되기까지 시간이 걸릴 수 있습니다.",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "Lichess 플레이어의 완료된 대국을 Game Record로 가져옵니다. 중복 대국은 자동으로 건너뜁니다.",
    "Player ID": "플레이어 ID",
    "Rated only": "레이팅 대국만",
    "Casual only": "캐주얼 대국만",
    "Rated and casual": "레이팅 및 캐주얼",
    "White games": "백 대국",
    "Black games": "흑 대국",
    "Start import": "가져오기 시작",
    "Enter a Chess.com username.": "Chess.com 사용자 이름을 입력하세요.",
    "Enter a Lichess player ID.": "Lichess 플레이어 ID를 입력하세요.",
    "Use points or upgrade Premium": "포인트를 사용하거나 Premium으로 업그레이드",
    "Standard plan": "표준 플랜",
    "Unable to preview Game Record.": "Game Record를 미리 볼 수 없습니다.",
    "Unable to check build progress.": "빌드 진행 상황을 확인할 수 없습니다.",
    "Unable to cancel Model Build.": "개인 엔진 훈련을 취소할 수 없습니다.",
    "Model Build queued": "개인 엔진 훈련 대기 중",
    "Model Build needs attention": "개인 엔진 훈련에 확인이 필요합니다",
    "Model Build failed": "개인 엔진 훈련 실패",
    "Model Build canceled": "개인 엔진 훈련 취소됨",
    "Paste a PGN before starting review.": "복기를 시작하기 전에 PGN을 붙여넣으세요.",
    "Unable to start Grandeur review.": "Grandeur 복기를 시작할 수 없습니다.",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur가 잠금 해제되었습니다. 코치 분석을 계속합니다...",
    "Grandeur review is being prepared...": "Grandeur 복기를 준비 중입니다...",
    "Spend 100 points?": "100포인트를 사용할까요?",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur는 LLM 코치 복기에 지갑 포인트를 사용합니다.",
    "Current balance": "현재 잔액",
    "Original cost": "원래 비용",
    "Member discount": "회원 할인",
    "Pay today": "오늘 결제",
    "Balance after review": "복기 후 잔액",
    "Start Grandeur review?": "Grandeur 복기를 시작할까요?",
    "Start Grandeur review": "Grandeur 복기 시작",
    "Not enough points": "포인트가 부족합니다",
    "Sign in required": "로그인이 필요합니다",
    "Grandeur review uses your wallet balance.": "Grandeur 복기는 지갑 잔액을 사용합니다.",
    "Wallet unavailable": "지갑을 사용할 수 없습니다",
    "Checking wallet": "지갑 확인 중",
    "Grandeur report generating": "Grandeur 리포트 생성 중",
    "Current move": "현재 수",
    "No Grandeur commentary is available for this move yet.":
        "이 수에 대한 Grandeur 코멘트가 아직 없습니다.",
    "Stockfish analysis in progress": "Stockfish 분석 진행 중",
    "Preparing PGN positions for evaluation.": "평가할 PGN 포지션을 준비 중입니다.",
    "Review settings": "리뷰 설정",
    "Maia3 official rating model": "Maia3 공식 레이팅 모델",
    "Compare with Stockfish": "Stockfish와 비교",
    "Show human likelihood next to the engine verdict.":
        "엔진 판정 옆에 사람다운 수의 가능성을 표시합니다.",
    "Start Maia3 Review": "Maia3 리뷰 시작",
    "Choose the human rating to review against, then start Maia3.":
        "비교할 사람 레이팅을 선택한 뒤 Maia3를 시작하세요.",
    "Engine comparison": "엔진 비교",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3는 사람다운 가능성을 설명하고, Stockfish는 객관적 품질을 확인합니다.",
    "Natural and strong": "자연스럽고 강한 수",
    "Common mistake": "흔한 실수",
    "Engine-like move": "엔진 같은 수",
    "Unusual mistake": "특이한 실수",
    "Stockfish ready": "Stockfish 준비됨",
    "Stockfish pending": "Stockfish 대기 중",
    "Auto-renewing plans get the best price": "자동 갱신 플랜이 가장 저렴합니다",
    "Processing purchase": "구매 처리 중",
    "Continue purchase": "구매 계속",
    "Restore purchase": "구매 복원",
    "One-time access": "일회성 이용",
    "Best price": "최저가",
    "Sign in before upgrading membership.": "멤버십을 업그레이드하기 전에 로그인하세요.",
    "Sign in before restoring purchases.": "구매를 복원하기 전에 로그인하세요.",
    "In-app purchase is available on iOS and Android.":
        "인앱 구매는 iOS와 Android에서 사용할 수 있습니다.",
    "Restore purchase is available on iOS and Android.":
        "구매 복원은 iOS와 Android에서 사용할 수 있습니다.",
    "Purchase canceled. Your membership was not changed.":
        "구매가 취소되었습니다. 멤버십은 변경되지 않았습니다.",
    "Purchase is still pending. Check your store account later.":
        "구매가 아직 보류 중입니다. 나중에 스토어 계정을 확인하세요.",
    "No active membership purchase was found for this store account.":
        "이 스토어 계정에서 활성 멤버십 구매를 찾을 수 없습니다.",
    "Premium is active.": "Premium이 활성화되었습니다.",
    "VIP member": "VIP 회원",
    "Valid until": "유효 기간",
    "Renew membership": "멤버십 갱신",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "구매 확인에 실패했습니다. 네트워크를 확인하고 구매 복원을 시도하세요.",
    "This record cannot be deleted from the cloud.": "이 기록은 클라우드에서 삭제할 수 없습니다.",
    "Lichess authorization expired. Re-authorize before continuing.":
        "Lichess 인증이 만료되었습니다. 계속하기 전에 다시 인증하세요.",
    "Lichess authorized": "Lichess 인증됨",
    "Connected as": "연결된 계정",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "Chessnut 계정이 이미 Lichess에 연결되어 있습니다. 이 연결을 유지하거나, 다른 Lichess 계정을 인증하려면 연결을 해제할 수 있습니다.",
    "Keep linked": "연결 유지",
    "Unlink Lichess": "Lichess 연결 해제",
    "Lichess account unlinked.": "Lichess 계정 연결이 해제되었습니다.",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "Lichess 인증이 완료되지 않았습니다. Lichess 페이지가 완료되면 다시 시도하세요.",
    "I have authorized": "인증했습니다",
    "Open in browser": "브라우저에서 열기",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "Lichess 인증을 승인한 뒤 Chessnut으로 돌아오세요. 페이지가 브라우저에서 열렸다면 인증 성공 메시지가 표시된 후 이것을 탭하세요.",
    "Close authorization": "인증 닫기",
    "Linked accounts": "연결된 계정",
    "Linked account updated.": "연결된 계정이 업데이트되었습니다.",
    "Not linked": "연결 안 됨",
    "Default 791556": "기본 791556",
    "Built-in": "내장",
    "Local file": "로컬 파일",
    "Playable engine library": "플레이 가능한 엔진 라이브러리",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "아직 플레이 가능한 개인 엔진이 없습니다. 완료된 빌드가 Bot game에서 준비되면 여기에 표시됩니다.",
    "Manage in Engine Lab": "Engine Lab에서 관리",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "훈련, 리포트, 플레이 가능한 개인 엔진은 Engine Lab에 있습니다.",
    "Unavailable": "사용할 수 없음",
    "Check for updates": "업데이트 확인",
    "Check whether a newer Chessnut version is available.":
        "새로운 Chessnut 버전이 있는지 확인합니다.",
    "Update required": "업데이트 필요",
    "Update available": "업데이트 가능",
    "Later": "나중에",
    "Open store": "스토어 열기",
    "Download update": "업데이트 다운로드",
    "Update now": "지금 업데이트",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "Chessnut이 올바르게 작동하려면 이 버전으로 업데이트해야 합니다. 계속하기 전에 업데이트하세요.",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "새 버전이 있습니다. 최신 수정 사항과 개선 사항을 받으려면 지금 업데이트하세요.",
    "This update will open the official app store or test track for your device.":
        "이 업데이트는 기기의 공식 앱 스토어 또는 테스트 트랙을 엽니다.",
    "This update will open the official Chessnut download page.":
        "이 업데이트는 Chessnut 공식 다운로드 페이지를 엽니다.",
    "This update will open in your browser.": "이 업데이트는 브라우저에서 열립니다.",
    "You are using the latest version.": "최신 버전을 사용 중입니다.",
    "Could not check for updates. Please try again later.":
        "업데이트를 확인할 수 없습니다. 나중에 다시 시도하세요.",
    "Update link is not available right now. Please try again later.":
        "현재 업데이트 링크를 사용할 수 없습니다. 나중에 다시 시도하세요.",
    "Could not open the update link. Please try again later.":
        "업데이트 링크를 열 수 없습니다. 나중에 다시 시도하세요.",
    "Import from image": "이미지에서 가져오기",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "Chessnut Vision을 켤까요?",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision은 이미지 인식을 사용해 스크린샷에서 보드를 읽습니다. 기능이 실행되는 동안 스크린샷은 인식에만 사용되며, Chessnut은 이를 기기에 로컬로 저장하거나 이 기기에 개인 데이터를 보관하지 않습니다.",
    "Not now": "나중에",
    "Enable Vision": "Vision 켜기",
    "Chessnut Vision is on": "Chessnut Vision 켜짐",
    "Chessnut Vision is off": "Chessnut Vision 꺼짐",
    "Chessnut Vision is now active.": "Chessnut Vision이 활성화되었습니다.",
    "Turn on Chessnut Vision in Accessibility": "접근성에서 Chessnut Vision 켜기",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision이 화면을 읽으려면 Android 접근성 권한이 필요합니다. 설정을 열고 Chessnut Vision을 켜세요.",
    "Choose a clear board photo or take a new one.":
        "선명한 보드 사진을 선택하거나 새로 촬영하세요.",
    "Choose a clear board image to recognize the position.":
        "포지션을 인식할 선명한 보드 이미지를 선택하세요.",
    "Choose from gallery": "갤러리에서 선택",
    "Take a photo": "사진 촬영",
    "Recognizing board image...": "보드 이미지를 인식하는 중...",
    "No image selected.": "선택한 이미지가 없습니다.",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision이 이 포지션을 인식할 수 없습니다.",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision이 이 이미지를 읽을 수 없습니다. 더 선명한 사진을 사용해 보세요.",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision이 보드에서 읽을 수 없는 포지션을 반환했습니다.",
    "Position imported from image.": "이미지에서 포지션을 가져왔습니다.",
    "Import a board position from a photo.": "사진에서 보드 포지션을 가져옵니다.",
    "Choose image": "이미지 선택",
    "Camera": "카메라",
    "Chessnut Vision is not available right now. Please try again later.":
        "현재 Chessnut Vision을 사용할 수 없습니다. 나중에 다시 시도하세요.",
    "Choose a board image before using Chessnut Vision.":
        "Chessnut Vision을 사용하기 전에 보드 이미지를 선택하세요.",
    "This image is too large. Choose an image under 10 MB.":
        "이 이미지는 너무 큽니다. 10 MB 미만의 이미지를 선택하세요.",
    "This image could not be opened.": "이 이미지를 열 수 없습니다.",
    "This image could not be read.": "이 이미지를 읽을 수 없습니다.",
    "Use a JPG, PNG, or WebP board image.":
        "JPG, PNG 또는 WebP 형식의 보드 이미지를 사용하세요.",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision이 이 이미지에서 유효한 포지션을 인식할 수 없습니다.",
  },
  "nl": <String, String>{
    "Sound effects": "Geluidseffecten",
    "Moves, game starts, results, and key actions":
        "Zetten, start van partijen, resultaten en belangrijke acties",
    "Refresh records": "Records vernieuwen",
    "No cloud games found": "Geen cloudpartijen gevonden",
    "Try fewer filters or import games from Lichess first.":
        "Gebruik minder filters of importeer eerst partijen van Lichess.",
    "Back to local list": "Terug naar lokale lijst",
    "Finish this game before generating an analysis report.":
        "Maak deze partij af voordat je een analyserapport maakt.",
    "Game record deleted.": "Partijrecord verwijderd.",
    "Unable to delete this game record.":
        "Kan dit partijrecord niet verwijderen.",
    "Unable to search your cloud archive. Check your connection and try again.":
        "Kan je cloudarchief niet doorzoeken. Controleer de verbinding en probeer opnieuw.",
    "Delete record": "Record verwijderen",
    "Delete game record?": "Partijrecord verwijderen?",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "Dit verwijdert de opgeslagen PGN uit je Chessnut-account. Dit kan niet ongedaan worden gemaakt.",
    "From PGN": "Van PGN",
    "From Lichess player": "Van Lichess-speler",
    "From Chess.com username": "Van Chess.com-gebruikersnaam",
    "Local list": "Lokale lijst",
    "Cloud search failed": "Cloudzoekactie mislukt",
    "Previous page": "Vorige pagina",
    "Next page": "Volgende pagina",
    "Import Chess.com games": "Chess.com-partijen importeren",
    "Import Lichess games": "Lichess-partijen importeren",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "Importeer openbare voltooide partijen van één Chess.com-gebruikersnaam naar Game Record. Chess.com-archieven hebben soms wat tijd nodig om heel recente partijen te publiceren.",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "Importeer voltooide partijen van één Lichess-speler naar Game Record. Dubbele partijen worden automatisch overgeslagen.",
    "Player ID": "Speler-ID",
    "Rated only": "Alleen rated",
    "Casual only": "Alleen casual",
    "Rated and casual": "Rated en casual",
    "White games": "Partijen met wit",
    "Black games": "Partijen met zwart",
    "Start import": "Import starten",
    "Enter a Chess.com username.": "Voer een Chess.com-gebruikersnaam in.",
    "Enter a Lichess player ID.": "Voer een Lichess-speler-ID in.",
    "Use points or upgrade Premium": "Gebruik punten of upgrade naar Premium",
    "Standard plan": "Standaardplan",
    "Unable to preview Game Record.": "Kan Game Record niet vooraf bekijken.",
    "Unable to check build progress.": "Kan buildvoortgang niet controleren.",
    "Unable to cancel Model Build.":
        "Kan training van persoonlijke engine niet annuleren.",
    "Model Build queued": "Training van persoonlijke engine in wachtrij",
    "Model Build needs attention":
        "Training van persoonlijke engine vereist aandacht",
    "Model Build failed": "Training van persoonlijke engine mislukt",
    "Model Build canceled": "Training van persoonlijke engine geannuleerd",
    "Paste a PGN before starting review.":
        "Plak een PGN voordat je de review start.",
    "Unable to start Grandeur review.": "Kan Grandeur-review niet starten.",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur is ontgrendeld. Coachanalyse gaat verder...",
    "Grandeur review is being prepared...":
        "Grandeur-review wordt voorbereid...",
    "Spend 100 points?": "100 punten besteden?",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur gebruikt walletpunten voor de LLM-coachreview.",
    "Current balance": "Huidig saldo",
    "Original cost": "Oorspronkelijke kosten",
    "Member discount": "Ledenkorting",
    "Pay today": "Vandaag betalen",
    "Balance after review": "Saldo na review",
    "Start Grandeur review?": "Grandeur-review starten?",
    "Start Grandeur review": "Grandeur-review starten",
    "Not enough points": "Niet genoeg punten",
    "Sign in required": "Aanmelden vereist",
    "Grandeur review uses your wallet balance.":
        "Grandeur-review gebruikt je walletsaldo.",
    "Wallet unavailable": "Wallet niet beschikbaar",
    "Checking wallet": "Wallet controleren",
    "Grandeur report generating": "Grandeur-rapport wordt gemaakt",
    "Current move": "Huidige zet",
    "No Grandeur commentary is available for this move yet.":
        "Nog geen Grandeur-commentaar voor deze zet.",
    "Stockfish analysis in progress": "Stockfish-analyse loopt",
    "Preparing PGN positions for evaluation.":
        "PGN-stellingen voorbereiden voor evaluatie.",
    "Review settings": "Review-instellingen",
    "Maia3 official rating model": "Officieel Maia3-ratingmodel",
    "Compare with Stockfish": "Vergelijken met Stockfish",
    "Show human likelihood next to the engine verdict.":
        "Toon de menselijke waarschijnlijkheid naast het engineoordeel.",
    "Start Maia3 Review": "Maia3-review starten",
    "Choose the human rating to review against, then start Maia3.":
        "Kies de menselijke rating waarmee je wilt vergelijken en start daarna Maia3.",
    "Engine comparison": "Enginevergelijking",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 verklaart de menselijke waarschijnlijkheid. Stockfish controleert de objectieve kwaliteit.",
    "Natural and strong": "Natuurlijk en sterk",
    "Common mistake": "Veelgemaakte fout",
    "Engine-like move": "Engine-achtige zet",
    "Unusual mistake": "Ongewone fout",
    "Stockfish ready": "Stockfish gereed",
    "Stockfish pending": "Stockfish in behandeling",
    "Auto-renewing plans get the best price":
        "Automatisch verlengende plannen hebben de beste prijs",
    "Processing purchase": "Aankoop verwerken",
    "Continue purchase": "Aankoop voortzetten",
    "Restore purchase": "Aankoop herstellen",
    "One-time access": "Eenmalige toegang",
    "Best price": "Beste prijs",
    "Sign in before upgrading membership.":
        "Meld je aan voordat je membership upgradet.",
    "Sign in before restoring purchases.":
        "Meld je aan voordat je aankopen herstelt.",
    "In-app purchase is available on iOS and Android.":
        "In-app-aankopen zijn beschikbaar op iOS en Android.",
    "Restore purchase is available on iOS and Android.":
        "Aankopen herstellen is beschikbaar op iOS en Android.",
    "Purchase canceled. Your membership was not changed.":
        "Aankoop geannuleerd. Je membership is niet gewijzigd.",
    "Purchase is still pending. Check your store account later.":
        "Aankoop is nog in behandeling. Controleer later je store-account.",
    "No active membership purchase was found for this store account.":
        "Geen actieve membershipaankoop gevonden voor dit store-account.",
    "Premium is active.": "Premium is actief.",
    "VIP member": "VIP-lid",
    "Valid until": "Geldig tot",
    "Renew membership": "Membership verlengen",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "Aankoopverificatie mislukt. Controleer je netwerk en probeer Aankoop herstellen.",
    "This record cannot be deleted from the cloud.":
        "Dit record kan niet uit de cloud worden verwijderd.",
    "Lichess authorization expired. Re-authorize before continuing.":
        "Lichess-autorisatie is verlopen. Autoriseer opnieuw voordat je doorgaat.",
    "Lichess authorized": "Lichess geautoriseerd",
    "Connected as": "Verbonden als",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "Je Chessnut-account is al verbonden met Lichess. Je kunt deze koppeling behouden of ontkoppelen als je een ander Lichess-account wilt autoriseren.",
    "Keep linked": "Gekoppeld houden",
    "Unlink Lichess": "Lichess ontkoppelen",
    "Lichess account unlinked.": "Lichess-account ontkoppeld.",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "Lichess-autorisatie is niet voltooid. Probeer het opnieuw wanneer de Lichess-pagina klaar is.",
    "I have authorized": "Ik heb geautoriseerd",
    "Open in browser": "Openen in browser",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "Ga terug naar Chessnut nadat je de Lichess-autorisatie hebt goedgekeurd. Als de pagina in je browser is geopend, tik hier nadat er staat dat de autorisatie is geslaagd.",
    "Close authorization": "Autorisatie sluiten",
    "Linked accounts": "Gekoppelde accounts",
    "Linked account updated.": "Gekoppeld account bijgewerkt.",
    "Not linked": "Niet gekoppeld",
    "Default 791556": "Standaard 791556",
    "Built-in": "Ingebouwd",
    "Local file": "Lokaal bestand",
    "Playable engine library": "Bibliotheek met speelbare engines",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "Er zijn nog geen speelbare persoonlijke engines. Voltooide builds verschijnen hier zodra ze klaar zijn voor Bot game.",
    "Manage in Engine Lab": "Beheren in Engine Lab",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "Training, rapporten en speelbare persoonlijke engines staan in Engine Lab.",
    "Unavailable": "Niet beschikbaar",
    "Check for updates": "Controleren op updates",
    "Check whether a newer Chessnut version is available.":
        "Controleer of er een nieuwere Chessnut-versie beschikbaar is.",
    "Update required": "Update vereist",
    "Update available": "Update beschikbaar",
    "Later": "Later",
    "Open store": "Store openen",
    "Download update": "Update downloaden",
    "Update now": "Nu updaten",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "Deze versie is vereist om Chessnut goed te laten werken. Update voordat je doorgaat.",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "Er is een nieuwere versie beschikbaar. Update nu voor de nieuwste fixes en verbeteringen.",
    "This update will open the official app store or test track for your device.":
        "Deze update opent de officiële appstore of testtrack voor je apparaat.",
    "This update will open the official Chessnut download page.":
        "Deze update opent de officiële Chessnut-downloadpagina.",
    "This update will open in your browser.":
        "Deze update wordt geopend in je browser.",
    "You are using the latest version.": "Je gebruikt de nieuwste versie.",
    "Could not check for updates. Please try again later.":
        "Kan niet controleren op updates. Probeer het later opnieuw.",
    "Update link is not available right now. Please try again later.":
        "De updatelink is momenteel niet beschikbaar. Probeer het later opnieuw.",
    "Could not open the update link. Please try again later.":
        "Kan de updatelink niet openen. Probeer het later opnieuw.",
    "Import from image": "Importeren uit afbeelding",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "Chessnut Vision inschakelen?",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision gebruikt beeldherkenning om het bord uit schermafbeeldingen te lezen. Schermafbeeldingen worden alleen gebruikt voor herkenning terwijl de functie actief is; Chessnut slaat ze niet lokaal op en bewaart je persoonlijke gegevens niet op dit apparaat.",
    "Not now": "Niet nu",
    "Enable Vision": "Vision inschakelen",
    "Chessnut Vision is on": "Chessnut Vision is ingeschakeld",
    "Chessnut Vision is off": "Chessnut Vision is uitgeschakeld",
    "Chessnut Vision is now active.": "Chessnut Vision is nu actief.",
    "Turn on Chessnut Vision in Accessibility":
        "Zet Chessnut Vision aan in Toegankelijkheid",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision heeft de Android-toegankelijkheidsmachtiging nodig voordat het het scherm kan lezen. Open Instellingen en zet Chessnut Vision aan.",
    "Choose a clear board photo or take a new one.":
        "Kies een duidelijke bordfoto of maak een nieuwe.",
    "Choose a clear board image to recognize the position.":
        "Kies een duidelijke bordafbeelding om de stelling te herkennen.",
    "Choose from gallery": "Kies uit galerij",
    "Take a photo": "Foto maken",
    "Recognizing board image...": "Bordafbeelding herkennen...",
    "No image selected.": "Geen afbeelding geselecteerd.",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision kon deze stelling niet herkennen.",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision kon deze afbeelding niet lezen. Probeer een duidelijkere foto.",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision gaf een stelling terug die het bord niet kon lezen.",
    "Position imported from image.": "Stelling geïmporteerd uit afbeelding.",
    "Import a board position from a photo.":
        "Importeer een bordstelling uit een foto.",
    "Choose image": "Afbeelding kiezen",
    "Camera": "Camera",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision is momenteel niet beschikbaar. Probeer het later opnieuw.",
    "Choose a board image before using Chessnut Vision.":
        "Kies een bordafbeelding voordat je Chessnut Vision gebruikt.",
    "This image is too large. Choose an image under 10 MB.":
        "Deze afbeelding is te groot. Kies een afbeelding kleiner dan 10 MB.",
    "This image could not be opened.":
        "Deze afbeelding kan niet worden geopend.",
    "This image could not be read.": "Deze afbeelding kan niet worden gelezen.",
    "Use a JPG, PNG, or WebP board image.":
        "Gebruik een bordafbeelding als JPG, PNG of WebP.",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision kon geen geldige stelling uit deze afbeelding herkennen.",
  },
  "ru": <String, String>{
    "Sound effects": "Звуковые эффекты",
    "Moves, game starts, results, and key actions":
        "Ходы, начало партий, результаты и ключевые действия",
    "Refresh records": "Обновить записи",
    "No cloud games found": "Облачные партии не найдены",
    "Try fewer filters or import games from Lichess first.":
        "Уменьшите число фильтров или сначала импортируйте партии из Lichess.",
    "Back to local list": "Вернуться к локальному списку",
    "Finish this game before generating an analysis report.":
        "Завершите эту партию перед созданием отчёта анализа.",
    "Game record deleted.": "Запись партии удалена.",
    "Unable to delete this game record.":
        "Не удалось удалить эту запись партии.",
    "Unable to search your cloud archive. Check your connection and try again.":
        "Не удалось выполнить поиск в облачном архиве. Проверьте подключение и повторите попытку.",
    "Delete record": "Удалить запись",
    "Delete game record?": "Удалить запись партии?",
    "This removes the saved PGN from your Chessnut account. This action cannot be undone.":
        "Сохранённый PGN будет удалён из вашей учётной записи Chessnut. Это действие нельзя отменить.",
    "From PGN": "Из PGN",
    "From Lichess player": "От игрока Lichess",
    "From Chess.com username": "По имени пользователя Chess.com",
    "Local list": "Локальный список",
    "Cloud search failed": "Поиск в облаке не удался",
    "Previous page": "Предыдущая страница",
    "Next page": "Следующая страница",
    "Import Chess.com games": "Импортировать партии Chess.com",
    "Import Lichess games": "Импортировать партии Lichess",
    "Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.":
        "Импортируйте открытые завершённые партии одного пользователя Chess.com в Game Record. Архивам Chess.com может потребоваться немного времени, чтобы опубликовать самые новые партии.",
    "Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.":
        "Импортируйте завершённые партии одного игрока Lichess в Game Record. Дубликаты пропускаются автоматически.",
    "Player ID": "ID игрока",
    "Rated only": "Только рейтинговые",
    "Casual only": "Только обычные",
    "Rated and casual": "Рейтинговые и обычные",
    "White games": "Партии белыми",
    "Black games": "Партии чёрными",
    "Start import": "Начать импорт",
    "Enter a Chess.com username.": "Введите имя пользователя Chess.com.",
    "Enter a Lichess player ID.": "Введите ID игрока Lichess.",
    "Use points or upgrade Premium":
        "Используйте очки или перейдите на Premium",
    "Standard plan": "Стандартный план",
    "Unable to preview Game Record.":
        "Не удалось предварительно просмотреть Game Record.",
    "Unable to check build progress.": "Не удалось проверить ход сборки.",
    "Unable to cancel Model Build.":
        "Не удалось отменить обучение личного движка.",
    "Model Build queued": "Обучение личного движка поставлено в очередь",
    "Model Build needs attention": "Обучение личного движка требует внимания",
    "Model Build failed": "Обучение личного движка не выполнено",
    "Model Build canceled": "Обучение личного движка отменено",
    "Paste a PGN before starting review.":
        "Вставьте PGN перед началом разбора.",
    "Unable to start Grandeur review.": "Не удалось начать разбор Grandeur.",
    "Grandeur is unlocked. Continuing the coach analysis...":
        "Grandeur разблокирован. Продолжается тренерский анализ...",
    "Grandeur review is being prepared...": "Разбор Grandeur готовится...",
    "Spend 100 points?": "Потратить 100 очков?",
    "Grandeur uses wallet points for the LLM coach review.":
        "Grandeur использует очки кошелька для тренерского разбора LLM.",
    "Current balance": "Текущий баланс",
    "Original cost": "Исходная стоимость",
    "Member discount": "Скидка участника",
    "Pay today": "Оплата сегодня",
    "Balance after review": "Баланс после разбора",
    "Start Grandeur review?": "Начать разбор Grandeur?",
    "Start Grandeur review": "Начать разбор Grandeur",
    "Not enough points": "Недостаточно очков",
    "Sign in required": "Требуется вход",
    "Grandeur review uses your wallet balance.":
        "Разбор Grandeur использует баланс кошелька.",
    "Wallet unavailable": "Кошелёк недоступен",
    "Checking wallet": "Проверка кошелька",
    "Grandeur report generating": "Отчёт Grandeur создаётся",
    "Current move": "Текущий ход",
    "No Grandeur commentary is available for this move yet.":
        "Для этого хода пока нет комментария Grandeur.",
    "Stockfish analysis in progress": "Анализ Stockfish выполняется",
    "Preparing PGN positions for evaluation.":
        "Подготовка позиций PGN для оценки.",
    "Review settings": "Настройки разбора",
    "Maia3 official rating model": "Официальная рейтинговая модель Maia3",
    "Compare with Stockfish": "Сравнить со Stockfish",
    "Show human likelihood next to the engine verdict.":
        "Показывать вероятность человеческого хода рядом с вердиктом движка.",
    "Start Maia3 Review": "Начать разбор Maia3",
    "Choose the human rating to review against, then start Maia3.":
        "Выберите человеческий рейтинг для сравнения, затем запустите Maia3.",
    "Engine comparison": "Сравнение движков",
    "Maia3 explains human likelihood. Stockfish checks objective quality.":
        "Maia3 объясняет вероятность человеческого хода. Stockfish проверяет объективное качество.",
    "Natural and strong": "Естественный и сильный ход",
    "Common mistake": "Типичная ошибка",
    "Engine-like move": "Ход в стиле движка",
    "Unusual mistake": "Необычная ошибка",
    "Stockfish ready": "Stockfish готов",
    "Stockfish pending": "Stockfish ожидает",
    "Auto-renewing plans get the best price":
        "Автопродляемые планы дают лучшую цену",
    "Processing purchase": "Обработка покупки",
    "Continue purchase": "Продолжить покупку",
    "Restore purchase": "Восстановить покупку",
    "One-time access": "Разовый доступ",
    "Best price": "Лучшая цена",
    "Sign in before upgrading membership.":
        "Войдите перед повышением уровня подписки.",
    "Sign in before restoring purchases.":
        "Войдите перед восстановлением покупок.",
    "In-app purchase is available on iOS and Android.":
        "Встроенные покупки доступны на iOS и Android.",
    "Restore purchase is available on iOS and Android.":
        "Восстановление покупок доступно на iOS и Android.",
    "Purchase canceled. Your membership was not changed.":
        "Покупка отменена. Подписка не изменилась.",
    "Purchase is still pending. Check your store account later.":
        "Покупка всё ещё ожидает обработки. Проверьте аккаунт магазина позже.",
    "No active membership purchase was found for this store account.":
        "Для этого аккаунта магазина не найдена активная покупка подписки.",
    "Premium is active.": "Premium активен.",
    "VIP member": "VIP-участник",
    "Valid until": "Действует до",
    "Renew membership": "Продлить подписку",
    "Purchase verification failed. Check your network and try Restore purchase.":
        "Проверка покупки не удалась. Проверьте сеть и попробуйте восстановить покупку.",
    "This record cannot be deleted from the cloud.":
        "Эту запись нельзя удалить из облака.",
    "Lichess authorization expired. Re-authorize before continuing.":
        "Авторизация Lichess истекла. Повторите авторизацию перед продолжением.",
    "Lichess authorized": "Авторизация в Lichess выполнена",
    "Connected as": "Подключено как",
    "Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.":
        "Ваша учётная запись Chessnut уже подключена к Lichess. Вы можете оставить эту связь или отключить её, если хотите авторизовать другую учётную запись Lichess.",
    "Keep linked": "Оставить связь",
    "Unlink Lichess": "Отключить Lichess",
    "Lichess account unlinked.": "Учётная запись Lichess отключена.",
    "Lichess authorization was not completed. Try again when the Lichess page finishes.":
        "Авторизация Lichess не была завершена. Повторите попытку после завершения на странице Lichess.",
    "I have authorized": "Авторизация выполнена",
    "Open in browser": "Открыть в браузере",
    "Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.":
        "Вернитесь в Chessnut после подтверждения авторизации Lichess. Если страница открылась в браузере, нажмите здесь после сообщения об успешной авторизации.",
    "Close authorization": "Закрыть авторизацию",
    "Linked accounts": "Связанные аккаунты",
    "Linked account updated.": "Связанная учётная запись обновлена.",
    "Not linked": "Не связано",
    "Default 791556": "По умолчанию 791556",
    "Built-in": "Встроено",
    "Local file": "Локальный файл",
    "Playable engine library": "Библиотека игровых движков",
    "No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.":
        "Пока нет игровых личных движков. Готовые сборки появятся здесь, когда будут готовы для Bot game.",
    "Manage in Engine Lab": "Управлять в Engine Lab",
    "Training, reports, and playable personal engines live in Engine Lab.":
        "Обучение, отчёты и игровые личные движки находятся в Engine Lab.",
    "Unavailable": "Недоступно",
    "Check for updates": "Проверить обновления",
    "Check whether a newer Chessnut version is available.":
        "Проверить, доступна ли более новая версия Chessnut.",
    "Update required": "Требуется обновление",
    "Update available": "Доступно обновление",
    "Later": "Позже",
    "Open store": "Открыть магазин",
    "Download update": "Скачать обновление",
    "Update now": "Обновить сейчас",
    "This version is required to keep Chessnut working correctly. Please update before continuing.":
        "Эта версия необходима для корректной работы Chessnut. Обновите приложение, прежде чем продолжить.",
    "A newer version is available. Update now to get the latest fixes and improvements.":
        "Доступна более новая версия. Обновите сейчас, чтобы получить последние исправления и улучшения.",
    "This update will open the official app store or test track for your device.":
        "Это обновление откроет официальный магазин приложений или тестовый канал для вашего устройства.",
    "This update will open the official Chessnut download page.":
        "Это обновление откроет официальную страницу загрузки Chessnut.",
    "This update will open in your browser.":
        "Это обновление откроется в браузере.",
    "You are using the latest version.": "Вы используете последнюю версию.",
    "Could not check for updates. Please try again later.":
        "Не удалось проверить обновления. Повторите попытку позже.",
    "Update link is not available right now. Please try again later.":
        "Ссылка на обновление сейчас недоступна. Повторите попытку позже.",
    "Could not open the update link. Please try again later.":
        "Не удалось открыть ссылку на обновление. Повторите попытку позже.",
    "Import from image": "Импорт из изображения",
    "Vision": "Vision",
    "Chessnut Vision": "Chessnut Vision",
    "Enable Chessnut Vision?": "Включить Chessnut Vision?",
    "Chessnut Vision uses image recognition to read the board from screenshots. Screenshots are used only for recognition while the feature is running; Chessnut does not save them locally or keep your personal data on this device.":
        "Chessnut Vision использует распознавание изображений, чтобы читать доску со снимков экрана. Снимки используются только для распознавания, пока функция включена; Chessnut не сохраняет их локально и не хранит ваши персональные данные на этом устройстве.",
    "Not now": "Не сейчас",
    "Enable Vision": "Включить Vision",
    "Chessnut Vision is on": "Chessnut Vision включён",
    "Chessnut Vision is off": "Chessnut Vision выключен",
    "Chessnut Vision is now active.": "Chessnut Vision теперь активен.",
    "Turn on Chessnut Vision in Accessibility":
        "Включите Chessnut Vision в специальных возможностях",
    "Chessnut Vision needs Android Accessibility permission before it can read the screen. Open Settings and turn on Chessnut Vision.":
        "Chessnut Vision требуется разрешение специальных возможностей Android, прежде чем читать экран. Откройте настройки и включите Chessnut Vision.",
    "Choose a clear board photo or take a new one.":
        "Выберите четкое фото доски или сделайте новое.",
    "Choose a clear board image to recognize the position.":
        "Выберите четкое изображение доски, чтобы распознать позицию.",
    "Choose from gallery": "Выбрать из галереи",
    "Take a photo": "Сделать фото",
    "Recognizing board image...": "Распознавание изображения доски...",
    "No image selected.": "Изображение не выбрано.",
    "Chessnut Vision could not recognize this position.":
        "Chessnut Vision не удалось распознать эту позицию.",
    "Chessnut Vision could not read this image. Try a clearer photo.":
        "Chessnut Vision не удалось прочитать это изображение. Попробуйте более четкое фото.",
    "Chessnut Vision returned a position the board could not read.":
        "Chessnut Vision вернул позицию, которую доска не смогла прочитать.",
    "Position imported from image.": "Позиция импортирована из изображения.",
    "Import a board position from a photo.":
        "Импортировать позицию на доске из фото.",
    "Choose image": "Выбрать изображение",
    "Camera": "Камера",
    "Chessnut Vision is not available right now. Please try again later.":
        "Chessnut Vision сейчас недоступен. Повторите попытку позже.",
    "Choose a board image before using Chessnut Vision.":
        "Выберите изображение доски перед использованием Chessnut Vision.",
    "This image is too large. Choose an image under 10 MB.":
        "Это изображение слишком большое. Выберите изображение меньше 10 МБ.",
    "This image could not be opened.": "Не удалось открыть это изображение.",
    "This image could not be read.": "Не удалось прочитать это изображение.",
    "Use a JPG, PNG, or WebP board image.":
        "Используйте изображение доски в формате JPG, PNG или WebP.",
    "Chessnut Vision could not recognize a valid position from this image.":
        "Chessnut Vision не удалось распознать допустимую позицию на этом изображении.",
  },
};

const _localGameStringMaps = <String, Map<String, String>>{
  'zh-Hans': {
    "Local games": "本地棋局",
    "Cloud games": "远程棋局",
    "Saved on this device. Upload only when you choose.": "棋局保存在本机，仅在你选择上传时同步。",
    "No local games. Games are saved here when you are signed out or a cloud save fails.":
        "暂无本地棋局。未登录或远程保存失败时，棋局会保存在这里。",
    "Select unsynced games": "选择未同步棋局",
    "Upload selected": "上传所选棋局",
    "Sync to cloud": "同步到远程",
    "Uploading": "同步中",
    "Synced": "已同步",
    "Not synced": "未同步",
    "Changed after upload": "上传后有修改",
    "In progress": "进行中",
    "Uploaded to account {account} on {date}": "已于 {date} 上传至账号 {account}",
    "Sign in to upload local games.": "请先登录，再上传本地棋局。",
    "Delete local game?": "删除本地棋局？",
    "Only the copy on this device will be deleted. Cloud records will not change.":
        "只删除本机副本，不会影响远程记录。",
    "Only the selected copies on this device will be deleted. Cloud records will not change.":
        "只删除本机中选中的副本，不会影响远程记录。",
    "Unable to read local games. Please try again.": "无法读取本地棋局，请重试。",
    "Unable to delete local game.": "无法删除本地棋局。",
    "Unable to delete selected local games.": "无法删除所选本地棋局。",
    "Unable to upload this game. The local copy has been kept.":
        "无法上传棋局，本地副本已保留。",
    "Selected games uploaded. Local copies have been kept.": "所选棋局已上传，本地副本已保留。",
    "Games uploaded, but cloud records could not be refreshed. Please try again.":
        "棋局已上传，但远程列表刷新失败，请重试。",
    "Saved on this device. Upload it later from Local games.":
        "已保存到本机，可稍后在本地棋局中手动上传。",
    "Game could not be saved locally. Check available storage and try again.":
        "本地保存失败，请检查存储空间后重试。",
    "Saved online, but the local upload status could not be saved.":
        "已保存到远程，但本地同步标记保存失败。",
    "Local game no longer exists.": "本地棋局已不存在。",
    "Sign in to the account that owns this game.": "请登录此棋局所属的账号。",
    "Game upload failed. Please try again.": "棋局上传失败，请重试。",
    "The server did not confirm the saved game.": "服务器未确认棋局保存成功。",
  },
};
