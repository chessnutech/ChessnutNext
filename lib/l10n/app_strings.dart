import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated_app_strings.dart';
import 'manual_language_strings.dart';
import 'recent_feature_strings.dart';
import 'complete_visible_strings.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  static AppStrings? maybeOf(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings);
  }

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppStringsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  String get localeKey {
    if (locale.languageCode == 'zh') {
      final country = locale.countryCode?.toUpperCase();
      return locale.scriptCode == 'Hant' ||
              country == 'TW' ||
              country == 'HK' ||
              country == 'MO'
          ? 'zh-Hant'
          : 'zh-Hans';
    }
    return locale.languageCode;
  }

  String t(String text) {
    if (text.isEmpty || localeKey == 'en') return text;
    final completeVisible = completeVisibleTranslation(text, localeKey);
    if (completeVisible != null) return completeVisible;
    final manualLanguage = manualLanguageStringMaps[localeKey]?[text];
    if (manualLanguage != null) return manualLanguage;
    final authRecovery = _authRecoveryTranslations(text, localeKey);
    if (authRecovery != null) return authRecovery;
    final standardAnalysis =
        _standardAnalysisControlTranslations(text, localeKey);
    if (standardAnalysis != null) return standardAnalysis;
    final commentaryVoice = _commentaryVoiceTranslations(text, localeKey);
    if (commentaryVoice != null) return commentaryVoice;
    final visionSetting = _visionSettingTranslations(text, localeKey);
    if (visionSetting != null) return visionSetting;
    final lichessFriend = _lichessFriendTranslations(text, localeKey);
    if (lichessFriend != null) return lichessFriend;
    final freshVisible = _freshVisibleTranslations(text, localeKey);
    if (freshVisible != null) return freshVisible;
    final lichessDraw = _lichessDrawTranslations(text, localeKey);
    if (lichessDraw != null) return lichessDraw;
    final critical = _criticalVisibleTranslations(text, localeKey);
    if (critical != null) return critical;
    final engineLab = _engineLabTranslations(text, localeKey);
    if (engineLab != null) return engineLab;
    final careerMode = _careerModeTranslations(text, localeKey);
    if (careerMode != null) return careerMode;
    final override = _manualOverrideTranslations(text, localeKey);
    if (override != null) return override;
    final recent = recentFeatureTranslation(text, localeKey);
    if (recent != null) return recent;
    final termsPrivacy = _termsPrivacyTranslations(text, localeKey);
    if (termsPrivacy != null) return termsPrivacy;
    final releaseCleanup = _releaseCleanupTranslations(text, localeKey);
    if (releaseCleanup != null) return releaseCleanup;
    final boardStorageImport = _boardStorageImportTranslations(text, localeKey);
    if (boardStorageImport != null) return boardStorageImport;
    final translated = generatedAppLocalizedMap(localeKey)[text];
    if (translated != null) return translated;
    return _translatePatterns(text, localeKey) ?? text;
  }

  String systemLanguageLabel() => t('Follow system');
}

String? _lichessFriendTranslations(String text, String key) {
  return _lichessPlayerStringMaps[key]?[text] ??
      _lichessFriendStringMaps[key]?[text] ??
      _lichessFriendFailureStringMaps[key]?[text];
}

const _lichessPlayerStringMaps = <String, Map<String, String>>{
  'zh-Hans': {
    'Challenge a Lichess player': '挑战 Lichess 玩家',
    'Lichess username': 'Lichess 用户名',
    'Enter any Lichess username or select a followed user.':
        '输入任意 Lichess 用户名，或选择一个关注用户。',
    'Challenge player': '挑战玩家',
    'Waiting for the player to accept the challenge...': '正在等待对方接受挑战……',
    'The player declined the challenge.': '对方拒绝了挑战。',
  },
  'zh-Hant': {
    'Challenge a Lichess player': '挑戰 Lichess 玩家',
    'Lichess username': 'Lichess 使用者名稱',
    'Enter any Lichess username or select a followed user.':
        '輸入任意 Lichess 使用者名稱，或選擇一個關注使用者。',
    'Challenge player': '挑戰玩家',
    'Waiting for the player to accept the challenge...': '正在等待對方接受挑戰……',
    'The player declined the challenge.': '對方拒絕了挑戰。',
  },
  'de': {
    'Challenge a Lichess player': 'Einen Lichess-Spieler herausfordern',
    'Lichess username': 'Lichess-Benutzername',
    'Enter any Lichess username or select a followed user.':
        'Gib einen Lichess-Benutzernamen ein oder wähle einen abonnierten Nutzer aus.',
    'Challenge player': 'Spieler herausfordern',
    'Waiting for the player to accept the challenge...':
        'Warten darauf, dass der Spieler die Herausforderung annimmt …',
    'The player declined the challenge.':
        'Der Spieler hat die Herausforderung abgelehnt.',
  },
  'es': {
    'Challenge a Lichess player': 'Desafiar a un jugador de Lichess',
    'Lichess username': 'Nombre de usuario de Lichess',
    'Enter any Lichess username or select a followed user.':
        'Introduce un nombre de usuario de Lichess o selecciona un usuario seguido.',
    'Challenge player': 'Desafiar al jugador',
    'Waiting for the player to accept the challenge...':
        'Esperando a que el jugador acepte el desafío…',
    'The player declined the challenge.': 'El jugador rechazó el desafío.',
  },
  'fr': {
    'Challenge a Lichess player': 'Défier un joueur Lichess',
    'Lichess username': 'Nom d’utilisateur Lichess',
    'Enter any Lichess username or select a followed user.':
        'Saisissez un nom d’utilisateur Lichess ou sélectionnez un utilisateur suivi.',
    'Challenge player': 'Défier le joueur',
    'Waiting for the player to accept the challenge...':
        'En attente de l’acceptation du défi par le joueur…',
    'The player declined the challenge.': 'Le joueur a refusé le défi.',
  },
  'it': {
    'Challenge a Lichess player': 'Sfida un giocatore Lichess',
    'Lichess username': 'Nome utente Lichess',
    'Enter any Lichess username or select a followed user.':
        'Inserisci un nome utente Lichess o seleziona un utente seguito.',
    'Challenge player': 'Sfida il giocatore',
    'Waiting for the player to accept the challenge...':
        'In attesa che il giocatore accetti la sfida…',
    'The player declined the challenge.': 'Il giocatore ha rifiutato la sfida.',
  },
  'ja': {
    'Challenge a Lichess player': 'Lichess プレイヤーに挑戦',
    'Lichess username': 'Lichess ユーザー名',
    'Enter any Lichess username or select a followed user.':
        'Lichess ユーザー名を入力するか、フォロー中のユーザーを選択してください。',
    'Challenge player': 'プレイヤーに挑戦',
    'Waiting for the player to accept the challenge...':
        'プレイヤーが対局申請を承認するのを待っています…',
    'The player declined the challenge.': 'プレイヤーが対局申請を拒否しました。',
  },
  'ko': {
    'Challenge a Lichess player': 'Lichess 플레이어에게 도전',
    'Lichess username': 'Lichess 사용자 이름',
    'Enter any Lichess username or select a followed user.':
        'Lichess 사용자 이름을 입력하거나 팔로우한 사용자를 선택하세요.',
    'Challenge player': '플레이어에게 도전',
    'Waiting for the player to accept the challenge...':
        '플레이어가 대국 신청을 수락하기를 기다리는 중…',
    'The player declined the challenge.': '플레이어가 대국 신청을 거절했습니다.',
  },
  'nl': {
    'Challenge a Lichess player': 'Een Lichess-speler uitdagen',
    'Lichess username': 'Lichess-gebruikersnaam',
    'Enter any Lichess username or select a followed user.':
        'Voer een Lichess-gebruikersnaam in of selecteer een gevolgde gebruiker.',
    'Challenge player': 'Speler uitdagen',
    'Waiting for the player to accept the challenge...':
        'Wachten tot de speler de uitdaging accepteert…',
    'The player declined the challenge.':
        'De speler heeft de uitdaging geweigerd.',
  },
  'ru': {
    'Challenge a Lichess player': 'Бросить вызов игроку Lichess',
    'Lichess username': 'Имя пользователя Lichess',
    'Enter any Lichess username or select a followed user.':
        'Введите имя пользователя Lichess или выберите отслеживаемого пользователя.',
    'Challenge player': 'Бросить вызов игроку',
    'Waiting for the player to accept the challenge...':
        'Ожидание принятия вызова игроком…',
    'The player declined the challenge.': 'Игрок отклонил вызов.',
  },
  'pt': {
    'Challenge a Lichess player': 'Desafiar um jogador do Lichess',
    'Lichess username': 'Nome de utilizador do Lichess',
    'Enter any Lichess username or select a followed user.':
        'Introduza um nome de utilizador do Lichess ou selecione um utilizador seguido.',
    'Challenge player': 'Desafiar jogador',
    'Waiting for the player to accept the challenge...':
        'A aguardar que o jogador aceite o desafio…',
    'The player declined the challenge.': 'O jogador recusou o desafio.',
  },
  'pl': {
    'Challenge a Lichess player': 'Wyzwij gracza Lichess',
    'Lichess username': 'Nazwa użytkownika Lichess',
    'Enter any Lichess username or select a followed user.':
        'Wpisz nazwę użytkownika Lichess lub wybierz obserwowanego użytkownika.',
    'Challenge player': 'Wyzwij gracza',
    'Waiting for the player to accept the challenge...':
        'Oczekiwanie, aż gracz przyjmie wyzwanie…',
    'The player declined the challenge.': 'Gracz odrzucił wyzwanie.',
  },
  'ro': {
    'Challenge a Lichess player': 'Provoacă un jucător Lichess',
    'Lichess username': 'Nume de utilizator Lichess',
    'Enter any Lichess username or select a followed user.':
        'Introdu un nume de utilizator Lichess sau selectează un utilizator urmărit.',
    'Challenge player': 'Provoacă jucătorul',
    'Waiting for the player to accept the challenge...':
        'Se așteaptă ca jucătorul să accepte provocarea…',
    'The player declined the challenge.': 'Jucătorul a refuzat provocarea.',
  },
  'cs': {
    'Challenge a Lichess player': 'Vyzvat hráče Lichess',
    'Lichess username': 'Uživatelské jméno Lichess',
    'Enter any Lichess username or select a followed user.':
        'Zadejte uživatelské jméno Lichess nebo vyberte sledovaného uživatele.',
    'Challenge player': 'Vyzvat hráče',
    'Waiting for the player to accept the challenge...':
        'Čeká se, až hráč výzvu přijme…',
    'The player declined the challenge.': 'Hráč výzvu odmítl.',
  },
  'ar': {
    'Challenge a Lichess player': 'تحدي لاعب على Lichess',
    'Lichess username': 'اسم مستخدم Lichess',
    'Enter any Lichess username or select a followed user.':
        'أدخل اسم مستخدم Lichess أو اختر مستخدمًا تتابعه.',
    'Challenge player': 'تحدي اللاعب',
    'Waiting for the player to accept the challenge...':
        'في انتظار قبول اللاعب للتحدي…',
    'The player declined the challenge.': 'رفض اللاعب التحدي.',
  },
  'he': {
    'Challenge a Lichess player': 'אתגר שחקן Lichess',
    'Lichess username': 'שם משתמש ב-Lichess',
    'Enter any Lichess username or select a followed user.':
        'הזינו שם משתמש ב-Lichess או בחרו משתמש שאתם עוקבים אחריו.',
    'Challenge player': 'אתגר שחקן',
    'Waiting for the player to accept the challenge...':
        'ממתין שהשחקן יקבל את האתגר…',
    'The player declined the challenge.': 'השחקן דחה את האתגר.',
  },
};

const _lichessFriendFailureStringMaps = <String, Map<String, String>>{
  'de': {
    'Lichess could not create this challenge.':
        'Lichess konnte diese Herausforderung nicht erstellen.',
    'Lichess could not cancel the challenge.':
        'Lichess konnte die Herausforderung nicht abbrechen.',
    'Lichess could not accept the challenge.':
        'Lichess konnte die Herausforderung nicht annehmen.',
    'Lichess could not decline the challenge.':
        'Lichess konnte die Herausforderung nicht ablehnen.',
  },
  'es': {
    'Lichess could not create this challenge.':
        'Lichess no pudo crear este desafío.',
    'Lichess could not cancel the challenge.':
        'Lichess no pudo cancelar el desafío.',
    'Lichess could not accept the challenge.':
        'Lichess no pudo aceptar el desafío.',
    'Lichess could not decline the challenge.':
        'Lichess no pudo rechazar el desafío.',
  },
  'fr': {
    'Lichess could not create this challenge.':
        'Lichess n’a pas pu créer ce défi.',
    'Lichess could not cancel the challenge.':
        'Lichess n’a pas pu annuler ce défi.',
    'Lichess could not accept the challenge.':
        'Lichess n’a pas pu accepter ce défi.',
    'Lichess could not decline the challenge.':
        'Lichess n’a pas pu refuser ce défi.',
  },
  'it': {
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'L’autorizzazione Lichess non è stata completata. Quella esistente rimane invariata.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'La nuova autorizzazione Lichess non è ancora pronta. Riprova.',
    'Lichess could not create this challenge.':
        'Lichess non ha potuto creare questa sfida.',
    'Lichess could not cancel the challenge.':
        'Lichess non ha potuto annullare la sfida.',
    'Lichess could not accept the challenge.':
        'Lichess non ha potuto accettare la sfida.',
    'Lichess could not decline the challenge.':
        'Lichess non ha potuto rifiutare la sfida.',
  },
  'ja': {
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'Lichess の認証は完了しませんでした。現在の認証は変更されていません。',
    'The new Lichess authorization is not ready yet. Please try again.':
        '新しい Lichess 認証はまだ準備できていません。再試行してください。',
    'Lichess could not create this challenge.': 'Lichess で対局申請を作成できませんでした。',
    'Lichess could not cancel the challenge.': 'Lichess で対局申請をキャンセルできませんでした。',
    'Lichess could not accept the challenge.': 'Lichess で対局申請を承認できませんでした。',
    'Lichess could not decline the challenge.': 'Lichess で対局申請を拒否できませんでした。',
  },
  'ko': {
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'Lichess 인증이 완료되지 않았습니다. 기존 인증은 변경되지 않았습니다.',
    'The new Lichess authorization is not ready yet. Please try again.':
        '새 Lichess 인증이 아직 준비되지 않았습니다. 다시 시도하세요.',
    'Lichess could not create this challenge.': 'Lichess에서 대국 신청을 만들 수 없습니다.',
    'Lichess could not cancel the challenge.': 'Lichess에서 대국 신청을 취소할 수 없습니다.',
    'Lichess could not accept the challenge.': 'Lichess에서 대국 신청을 수락할 수 없습니다.',
    'Lichess could not decline the challenge.': 'Lichess에서 대국 신청을 거절할 수 없습니다.',
  },
  'nl': {
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'De Lichess-autorisatie is niet voltooid. De bestaande autorisatie blijft ongewijzigd.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'De nieuwe Lichess-autorisatie is nog niet gereed. Probeer opnieuw.',
    'Lichess could not create this challenge.':
        'Lichess kon deze uitdaging niet maken.',
    'Lichess could not cancel the challenge.':
        'Lichess kon de uitdaging niet annuleren.',
    'Lichess could not accept the challenge.':
        'Lichess kon de uitdaging niet accepteren.',
    'Lichess could not decline the challenge.':
        'Lichess kon de uitdaging niet weigeren.',
  },
  'ru': {
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'Авторизация Lichess не завершена. Текущая авторизация не изменена.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'Новая авторизация Lichess ещё не готова. Повторите попытку.',
    'Lichess could not create this challenge.':
        'Lichess не удалось создать этот вызов.',
    'Lichess could not cancel the challenge.':
        'Lichess не удалось отменить вызов.',
    'Lichess could not accept the challenge.':
        'Lichess не удалось принять вызов.',
    'Lichess could not decline the challenge.':
        'Lichess не удалось отклонить вызов.',
  },
  'pt': {
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'A autorização do Lichess não foi concluída. A autorização atual não foi alterada.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'A nova autorização do Lichess ainda não está pronta. Tente novamente.',
    'Lichess could not create this challenge.':
        'O Lichess não conseguiu criar este desafio.',
    'Lichess could not cancel the challenge.':
        'O Lichess não conseguiu cancelar o desafio.',
    'Lichess could not accept the challenge.':
        'O Lichess não conseguiu aceitar o desafio.',
    'Lichess could not decline the challenge.':
        'O Lichess não conseguiu recusar o desafio.',
  },
  'pl': {
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'Autoryzacja Lichess nie została ukończona. Dotychczasowa autoryzacja pozostaje bez zmian.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'Nowa autoryzacja Lichess nie jest jeszcze gotowa. Spróbuj ponownie.',
    'Lichess could not create this challenge.':
        'Lichess nie mógł utworzyć tego wyzwania.',
    'Lichess could not cancel the challenge.':
        'Lichess nie mógł anulować wyzwania.',
    'Lichess could not accept the challenge.':
        'Lichess nie mógł przyjąć wyzwania.',
    'Lichess could not decline the challenge.':
        'Lichess nie mógł odrzucić wyzwania.',
  },
  'ro': {
    'Lichess could not create this challenge.':
        'Lichess nu a putut crea această provocare.',
    'Lichess could not cancel the challenge.':
        'Lichess nu a putut anula provocarea.',
    'Lichess could not accept the challenge.':
        'Lichess nu a putut accepta provocarea.',
    'Lichess could not decline the challenge.':
        'Lichess nu a putut refuza provocarea.',
  },
  'cs': {
    'Lichess could not create this challenge.':
        'Lichess nemohl vytvořit tuto výzvu.',
    'Lichess could not cancel the challenge.': 'Lichess nemohl výzvu zrušit.',
    'Lichess could not accept the challenge.': 'Lichess nemohl výzvu přijmout.',
    'Lichess could not decline the challenge.':
        'Lichess nemohl výzvu odmítnout.',
  },
  'ar': {
    'Lichess could not create this challenge.':
        'تعذر على Lichess إنشاء هذا التحدي.',
    'Lichess could not cancel the challenge.': 'تعذر على Lichess إلغاء التحدي.',
    'Lichess could not accept the challenge.': 'تعذر على Lichess قبول التحدي.',
    'Lichess could not decline the challenge.': 'تعذر على Lichess رفض التحدي.',
  },
  'he': {
    'Lichess could not create this challenge.':
        'Lichess לא הצליח ליצור את האתגר.',
    'Lichess could not cancel the challenge.':
        'Lichess לא הצליח לבטל את האתגר.',
    'Lichess could not accept the challenge.':
        'Lichess לא הצליח לאשר את האתגר.',
    'Lichess could not decline the challenge.':
        'Lichess לא הצליח לדחות את האתגר.',
  },
};

const _lichessFriendStringMaps = <String, Map<String, String>>{
  'zh-Hans': {
    'Random match': '随机匹配',
    'Friend match': '好友对战',
    'Play with a Lichess friend': '与 Lichess 好友对战',
    'Refresh friends': '刷新好友',
    'Checking whether this authorization can access your followed users...':
        '正在检查当前授权能否访问关注用户……',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        '当前 Lichess 授权不包含好友列表权限。请重新授权以和关注用户对战。',
    'Incoming challenges': '收到的挑战',
    'Search followed users': '搜索关注用户',
    'You are not following any Lichess users yet.': '你还没有关注任何 Lichess 用户。',
    'No followed users match this search.': '没有符合搜索条件的关注用户。',
    'Your color': '你的执棋颜色',
    'Cancel challenge': '取消挑战',
    'Checking friend access...': '正在检查好友权限……',
    'Challenge selected friend': '挑战所选好友',
    'Retry friend access': '重新检查好友权限',
    'Friend access could not be checked. Check the network and try again.':
        '无法检查好友权限，请检查网络后重试。',
    'Sending Lichess challenge...': '正在发送 Lichess 挑战……',
    'Waiting for your friend to accept the challenge...': '正在等待好友接受挑战……',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        '未完成 Lichess 授权，现有授权保持不变。',
    'The new Lichess authorization is not ready yet. Please try again.':
        '新的 Lichess 授权尚未就绪，请重试。',
    'Challenge accepted.': '挑战已接受。',
    'Your friend declined the challenge.': '好友拒绝了挑战。',
    'Challenge canceled.': '挑战已取消。',
    'The challenge expired.': '挑战已过期。',
    'This challenge is not compatible with Board API play.':
        '该挑战不支持通过 Board API 对弈。',
    'Challenge declined.': '已拒绝挑战。',
    'Accept challenge': '接受挑战',
    'Decline challenge': '拒绝挑战',
    'Lichess could not create this challenge.': 'Lichess 无法创建该挑战。',
    'Lichess could not cancel the challenge.': 'Lichess 无法取消该挑战。',
    'Lichess could not accept the challenge.': 'Lichess 无法接受该挑战。',
    'Lichess could not decline the challenge.': 'Lichess 无法拒绝该挑战。',
    'Casual': '非评级',
  },
  'zh-Hant': {
    'Random match': '隨機配對',
    'Friend match': '好友對戰',
    'Play with a Lichess friend': '與 Lichess 好友對戰',
    'Refresh friends': '重新整理好友',
    'Checking whether this authorization can access your followed users...':
        '正在檢查目前授權能否存取關注使用者……',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        '目前 Lichess 授權不包含好友清單權限。請重新授權以和關注使用者對戰。',
    'Incoming challenges': '收到的挑戰',
    'Search followed users': '搜尋關注使用者',
    'You are not following any Lichess users yet.': '你尚未關注任何 Lichess 使用者。',
    'No followed users match this search.': '沒有符合搜尋條件的關注使用者。',
    'Your color': '你的執棋顏色',
    'Cancel challenge': '取消挑戰',
    'Checking friend access...': '正在檢查好友權限……',
    'Challenge selected friend': '挑戰所選好友',
    'Retry friend access': '重新檢查好友權限',
    'Friend access could not be checked. Check the network and try again.':
        '無法檢查好友權限，請檢查網路後重試。',
    'Sending Lichess challenge...': '正在傳送 Lichess 挑戰……',
    'Waiting for your friend to accept the challenge...': '正在等待好友接受挑戰……',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        '未完成 Lichess 授權，現有授權維持不變。',
    'The new Lichess authorization is not ready yet. Please try again.':
        '新的 Lichess 授權尚未就緒，請重試。',
    'Challenge accepted.': '挑戰已接受。',
    'Your friend declined the challenge.': '好友拒絕了挑戰。',
    'Challenge canceled.': '挑戰已取消。',
    'The challenge expired.': '挑戰已過期。',
    'This challenge is not compatible with Board API play.':
        '此挑戰不支援透過 Board API 對弈。',
    'Challenge declined.': '已拒絕挑戰。',
    'Accept challenge': '接受挑戰',
    'Decline challenge': '拒絕挑戰',
    'Lichess could not create this challenge.': 'Lichess 無法建立此挑戰。',
    'Lichess could not cancel the challenge.': 'Lichess 無法取消此挑戰。',
    'Lichess could not accept the challenge.': 'Lichess 無法接受此挑戰。',
    'Lichess could not decline the challenge.': 'Lichess 無法拒絕此挑戰。',
    'Casual': '非評級',
  },
  'de': {
    'Random match': 'Zufällige Partie',
    'Friend match': 'Partie mit Freund',
    'Play with a Lichess friend': 'Mit einem Lichess-Freund spielen',
    'Refresh friends': 'Freunde aktualisieren',
    'Checking whether this authorization can access your followed users...':
        'Es wird geprüft, ob diese Autorisierung auf deine abonnierten Nutzer zugreifen kann …',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Diese Lichess-Autorisierung enthält keinen Zugriff auf die Freundesliste. Autorisiere Lichess erneut.',
    'Incoming challenges': 'Eingehende Herausforderungen',
    'Search followed users': 'Abonnierte Nutzer suchen',
    'You are not following any Lichess users yet.':
        'Du folgst noch keinen Lichess-Nutzern.',
    'No followed users match this search.':
        'Keine passenden abonnierten Nutzer gefunden.',
    'Your color': 'Deine Farbe',
    'Cancel challenge': 'Herausforderung abbrechen',
    'Checking friend access...': 'Freundeszugriff wird geprüft …',
    'Challenge selected friend': 'Ausgewählten Freund herausfordern',
    'Retry friend access': 'Freundeszugriff erneut prüfen',
    'Friend access could not be checked. Check the network and try again.':
        'Der Freundeszugriff konnte nicht geprüft werden. Prüfe das Netzwerk und versuche es erneut.',
    'Sending Lichess challenge...': 'Lichess-Herausforderung wird gesendet …',
    'Waiting for your friend to accept the challenge...':
        'Warten auf die Annahme durch deinen Freund …',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'Die Lichess-Autorisierung wurde nicht abgeschlossen. Die bestehende Autorisierung bleibt unverändert.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'Die neue Lichess-Autorisierung ist noch nicht bereit. Bitte erneut versuchen.',
    'Challenge accepted.': 'Herausforderung angenommen.',
    'Your friend declined the challenge.':
        'Dein Freund hat die Herausforderung abgelehnt.',
    'Challenge canceled.': 'Herausforderung abgebrochen.',
    'The challenge expired.': 'Die Herausforderung ist abgelaufen.',
    'This challenge is not compatible with Board API play.':
        'Diese Herausforderung ist nicht mit der Board API kompatibel.',
    'Challenge declined.': 'Herausforderung abgelehnt.',
    'Accept challenge': 'Herausforderung annehmen',
    'Decline challenge': 'Herausforderung ablehnen',
    'Casual': 'Ungewertet',
  },
  'es': {
    'Random match': 'Partida aleatoria',
    'Friend match': 'Partida con amigo',
    'Play with a Lichess friend': 'Jugar con un amigo de Lichess',
    'Refresh friends': 'Actualizar amigos',
    'Checking whether this authorization can access your followed users...':
        'Comprobando si esta autorización permite acceder a los usuarios que sigues…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Esta autorización de Lichess no incluye acceso a la lista de amigos. Vuelve a autorizar Lichess.',
    'Incoming challenges': 'Desafíos recibidos',
    'Search followed users': 'Buscar usuarios seguidos',
    'You are not following any Lichess users yet.':
        'Todavía no sigues a ningún usuario de Lichess.',
    'No followed users match this search.':
        'Ningún usuario seguido coincide con la búsqueda.',
    'Your color': 'Tu color',
    'Cancel challenge': 'Cancelar desafío',
    'Checking friend access...': 'Comprobando acceso a amigos…',
    'Challenge selected friend': 'Desafiar al amigo seleccionado',
    'Retry friend access': 'Reintentar acceso a amigos',
    'Friend access could not be checked. Check the network and try again.':
        'No se pudo comprobar el acceso a amigos. Revisa la red e inténtalo de nuevo.',
    'Sending Lichess challenge...': 'Enviando desafío de Lichess…',
    'Waiting for your friend to accept the challenge...':
        'Esperando a que tu amigo acepte el desafío…',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'No se completó la autorización de Lichess. La autorización actual no ha cambiado.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'La nueva autorización de Lichess aún no está lista. Inténtalo de nuevo.',
    'Challenge accepted.': 'Desafío aceptado.',
    'Your friend declined the challenge.': 'Tu amigo rechazó el desafío.',
    'Challenge canceled.': 'Desafío cancelado.',
    'The challenge expired.': 'El desafío ha caducado.',
    'This challenge is not compatible with Board API play.':
        'Este desafío no es compatible con Board API.',
    'Challenge declined.': 'Desafío rechazado.',
    'Accept challenge': 'Aceptar desafío',
    'Decline challenge': 'Rechazar desafío',
    'Casual': 'No puntuado',
  },
  'fr': {
    'Random match': 'Partie aléatoire',
    'Friend match': 'Partie avec un ami',
    'Play with a Lichess friend': 'Jouer avec un ami Lichess',
    'Refresh friends': 'Actualiser les amis',
    'Checking whether this authorization can access your followed users...':
        'Vérification de l’accès de cette autorisation aux utilisateurs suivis…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Cette autorisation Lichess ne permet pas d’accéder à la liste d’amis. Autorisez de nouveau Lichess.',
    'Incoming challenges': 'Défis reçus',
    'Search followed users': 'Rechercher parmi les utilisateurs suivis',
    'You are not following any Lichess users yet.':
        'Vous ne suivez encore aucun utilisateur Lichess.',
    'No followed users match this search.':
        'Aucun utilisateur suivi ne correspond à la recherche.',
    'Your color': 'Votre couleur',
    'Cancel challenge': 'Annuler le défi',
    'Checking friend access...': 'Vérification de l’accès aux amis…',
    'Challenge selected friend': 'Défier l’ami sélectionné',
    'Retry friend access': 'Revérifier l’accès aux amis',
    'Friend access could not be checked. Check the network and try again.':
        'Impossible de vérifier l’accès aux amis. Vérifiez le réseau et réessayez.',
    'Sending Lichess challenge...': 'Envoi du défi Lichess…',
    'Waiting for your friend to accept the challenge...':
        'En attente de l’acceptation de votre ami…',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'L’autorisation Lichess n’a pas été terminée. L’autorisation actuelle est inchangée.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'La nouvelle autorisation Lichess n’est pas encore prête. Réessayez.',
    'Challenge accepted.': 'Défi accepté.',
    'Your friend declined the challenge.': 'Votre ami a refusé le défi.',
    'Challenge canceled.': 'Défi annulé.',
    'The challenge expired.': 'Le défi a expiré.',
    'This challenge is not compatible with Board API play.':
        'Ce défi n’est pas compatible avec la Board API.',
    'Challenge declined.': 'Défi refusé.',
    'Accept challenge': 'Accepter le défi',
    'Decline challenge': 'Refuser le défi',
    'Casual': 'Non classée',
  },
  'it': {
    'Random match': 'Partita casuale',
    'Friend match': 'Partita con un amico',
    'Play with a Lichess friend': 'Gioca con un amico di Lichess',
    'Refresh friends': 'Aggiorna amici',
    'Checking whether this authorization can access your followed users...':
        'Verifica dell’accesso agli utenti seguiti…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Questa autorizzazione Lichess non include l’accesso agli amici. Autorizza nuovamente Lichess.',
    'Incoming challenges': 'Sfide in arrivo',
    'Search followed users': 'Cerca utenti seguiti',
    'You are not following any Lichess users yet.':
        'Non segui ancora alcun utente Lichess.',
    'No followed users match this search.':
        'Nessun utente seguito corrisponde alla ricerca.',
    'Your color': 'Il tuo colore',
    'Cancel challenge': 'Annulla sfida',
    'Checking friend access...': 'Verifica accesso agli amici…',
    'Challenge selected friend': 'Sfida l’amico selezionato',
    'Retry friend access': 'Riprova accesso agli amici',
    'Friend access could not be checked. Check the network and try again.':
        'Impossibile verificare l’accesso agli amici. Controlla la rete e riprova.',
    'Sending Lichess challenge...': 'Invio della sfida Lichess…',
    'Waiting for your friend to accept the challenge...':
        'In attesa che il tuo amico accetti la sfida…',
    'Challenge accepted.': 'Sfida accettata.',
    'Your friend declined the challenge.':
        'Il tuo amico ha rifiutato la sfida.',
    'Challenge canceled.': 'Sfida annullata.',
    'The challenge expired.': 'La sfida è scaduta.',
    'This challenge is not compatible with Board API play.':
        'Questa sfida non è compatibile con la Board API.',
    'Challenge declined.': 'Sfida rifiutata.',
    'Accept challenge': 'Accetta sfida',
    'Decline challenge': 'Rifiuta sfida',
    'Casual': 'Non classificata',
  },
  'ja': {
    'Random match': 'ランダム対局',
    'Friend match': 'フレンド対局',
    'Play with a Lichess friend': 'Lichess のフレンドと対局',
    'Refresh friends': 'フレンドを更新',
    'Checking whether this authorization can access your followed users...':
        'この認証でフォロー中のユーザーにアクセスできるか確認しています…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'この Lichess 認証にはフレンド一覧の権限がありません。再認証してください。',
    'Incoming challenges': '届いた対局申請',
    'Search followed users': 'フォロー中のユーザーを検索',
    'You are not following any Lichess users yet.': 'フォロー中の Lichess ユーザーはいません。',
    'No followed users match this search.': '検索に一致するユーザーはいません。',
    'Your color': '自分の色',
    'Cancel challenge': '対局申請をキャンセル',
    'Checking friend access...': 'フレンド権限を確認中…',
    'Challenge selected friend': '選択したフレンドに申請',
    'Retry friend access': 'フレンド権限を再確認',
    'Friend access could not be checked. Check the network and try again.':
        'フレンド権限を確認できません。ネットワークを確認して再試行してください。',
    'Sending Lichess challenge...': 'Lichess の対局申請を送信中…',
    'Waiting for your friend to accept the challenge...': 'フレンドの承認を待っています…',
    'Challenge accepted.': '対局申請が承認されました。',
    'Your friend declined the challenge.': 'フレンドが対局申請を拒否しました。',
    'Challenge canceled.': '対局申請をキャンセルしました。',
    'The challenge expired.': '対局申請の期限が切れました。',
    'This challenge is not compatible with Board API play.':
        'この対局申請は Board API に対応していません。',
    'Challenge declined.': '対局申請を拒否しました。',
    'Accept challenge': '対局申請を承認',
    'Decline challenge': '対局申請を拒否',
    'Casual': '非レート',
  },
  'ko': {
    'Random match': '무작위 대국',
    'Friend match': '친구 대국',
    'Play with a Lichess friend': 'Lichess 친구와 대국',
    'Refresh friends': '친구 새로고침',
    'Checking whether this authorization can access your followed users...':
        '이 인증으로 팔로우한 사용자에 접근할 수 있는지 확인 중…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        '현재 Lichess 인증에는 친구 목록 권한이 없습니다. Lichess를 다시 인증하세요.',
    'Incoming challenges': '받은 대국 신청',
    'Search followed users': '팔로우한 사용자 검색',
    'You are not following any Lichess users yet.':
        '아직 팔로우한 Lichess 사용자가 없습니다.',
    'No followed users match this search.': '검색과 일치하는 사용자가 없습니다.',
    'Your color': '내 색상',
    'Cancel challenge': '대국 신청 취소',
    'Checking friend access...': '친구 권한 확인 중…',
    'Challenge selected friend': '선택한 친구에게 신청',
    'Retry friend access': '친구 권한 다시 확인',
    'Friend access could not be checked. Check the network and try again.':
        '친구 권한을 확인할 수 없습니다. 네트워크를 확인하고 다시 시도하세요.',
    'Sending Lichess challenge...': 'Lichess 대국 신청 전송 중…',
    'Waiting for your friend to accept the challenge...': '친구의 수락을 기다리는 중…',
    'Challenge accepted.': '대국 신청이 수락되었습니다.',
    'Your friend declined the challenge.': '친구가 대국 신청을 거절했습니다.',
    'Challenge canceled.': '대국 신청이 취소되었습니다.',
    'The challenge expired.': '대국 신청이 만료되었습니다.',
    'This challenge is not compatible with Board API play.':
        '이 대국 신청은 Board API와 호환되지 않습니다.',
    'Challenge declined.': '대국 신청을 거절했습니다.',
    'Accept challenge': '대국 신청 수락',
    'Decline challenge': '대국 신청 거절',
    'Casual': '비레이팅',
  },
  'nl': {
    'Random match': 'Willekeurige partij',
    'Friend match': 'Partij met vriend',
    'Play with a Lichess friend': 'Met een Lichess-vriend spelen',
    'Refresh friends': 'Vrienden vernieuwen',
    'Checking whether this authorization can access your followed users...':
        'Controleren of deze autorisatie toegang heeft tot gevolgde gebruikers…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Deze Lichess-autorisatie bevat geen toegang tot de vriendenlijst. Autoriseer Lichess opnieuw.',
    'Incoming challenges': 'Ontvangen uitdagingen',
    'Search followed users': 'Gevolgde gebruikers zoeken',
    'You are not following any Lichess users yet.':
        'Je volgt nog geen Lichess-gebruikers.',
    'No followed users match this search.':
        'Geen gevolgde gebruikers gevonden.',
    'Your color': 'Jouw kleur',
    'Cancel challenge': 'Uitdaging annuleren',
    'Checking friend access...': 'Vriendentoegang controleren…',
    'Challenge selected friend': 'Geselecteerde vriend uitdagen',
    'Retry friend access': 'Vriendentoegang opnieuw proberen',
    'Friend access could not be checked. Check the network and try again.':
        'Vriendentoegang kon niet worden gecontroleerd. Controleer het netwerk en probeer opnieuw.',
    'Sending Lichess challenge...': 'Lichess-uitdaging verzenden…',
    'Waiting for your friend to accept the challenge...':
        'Wachten tot je vriend de uitdaging accepteert…',
    'Challenge accepted.': 'Uitdaging geaccepteerd.',
    'Your friend declined the challenge.':
        'Je vriend heeft de uitdaging geweigerd.',
    'Challenge canceled.': 'Uitdaging geannuleerd.',
    'The challenge expired.': 'De uitdaging is verlopen.',
    'This challenge is not compatible with Board API play.':
        'Deze uitdaging is niet compatibel met de Board API.',
    'Challenge declined.': 'Uitdaging geweigerd.',
    'Accept challenge': 'Uitdaging accepteren',
    'Decline challenge': 'Uitdaging weigeren',
    'Casual': 'Ongewaardeerd',
  },
  'ru': {
    'Random match': 'Случайная игра',
    'Friend match': 'Игра с другом',
    'Play with a Lichess friend': 'Играть с другом из Lichess',
    'Refresh friends': 'Обновить друзей',
    'Checking whether this authorization can access your followed users...':
        'Проверка доступа авторизации к отслеживаемым пользователям…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'В этой авторизации Lichess нет доступа к списку друзей. Авторизуйте Lichess повторно.',
    'Incoming challenges': 'Входящие вызовы',
    'Search followed users': 'Поиск отслеживаемых пользователей',
    'You are not following any Lichess users yet.':
        'Вы пока не отслеживаете пользователей Lichess.',
    'No followed users match this search.':
        'Подходящие пользователи не найдены.',
    'Your color': 'Ваш цвет',
    'Cancel challenge': 'Отменить вызов',
    'Checking friend access...': 'Проверка доступа к друзьям…',
    'Challenge selected friend': 'Вызвать выбранного друга',
    'Retry friend access': 'Повторить проверку доступа',
    'Friend access could not be checked. Check the network and try again.':
        'Не удалось проверить доступ к друзьям. Проверьте сеть и повторите попытку.',
    'Sending Lichess challenge...': 'Отправка вызова Lichess…',
    'Waiting for your friend to accept the challenge...':
        'Ожидание принятия вызова другом…',
    'Challenge accepted.': 'Вызов принят.',
    'Your friend declined the challenge.': 'Друг отклонил вызов.',
    'Challenge canceled.': 'Вызов отменён.',
    'The challenge expired.': 'Срок вызова истёк.',
    'This challenge is not compatible with Board API play.':
        'Этот вызов несовместим с Board API.',
    'Challenge declined.': 'Вызов отклонён.',
    'Accept challenge': 'Принять вызов',
    'Decline challenge': 'Отклонить вызов',
    'Casual': 'Без рейтинга',
  },
  'pt': {
    'Random match': 'Partida aleatória',
    'Friend match': 'Partida com amigo',
    'Play with a Lichess friend': 'Jogar com um amigo do Lichess',
    'Refresh friends': 'Atualizar amigos',
    'Checking whether this authorization can access your followed users...':
        'A verificar o acesso aos utilizadores seguidos…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Esta autorização do Lichess não inclui acesso à lista de amigos. Autorize novamente o Lichess.',
    'Incoming challenges': 'Desafios recebidos',
    'Search followed users': 'Pesquisar utilizadores seguidos',
    'You are not following any Lichess users yet.':
        'Ainda não segue nenhum utilizador do Lichess.',
    'No followed users match this search.':
        'Nenhum utilizador seguido corresponde à pesquisa.',
    'Your color': 'A sua cor',
    'Cancel challenge': 'Cancelar desafio',
    'Checking friend access...': 'A verificar acesso aos amigos…',
    'Challenge selected friend': 'Desafiar amigo selecionado',
    'Retry friend access': 'Repetir acesso aos amigos',
    'Friend access could not be checked. Check the network and try again.':
        'Não foi possível verificar o acesso aos amigos. Verifique a rede e tente novamente.',
    'Sending Lichess challenge...': 'A enviar desafio do Lichess…',
    'Waiting for your friend to accept the challenge...':
        'A aguardar que o amigo aceite o desafio…',
    'Challenge accepted.': 'Desafio aceite.',
    'Your friend declined the challenge.': 'O seu amigo recusou o desafio.',
    'Challenge canceled.': 'Desafio cancelado.',
    'The challenge expired.': 'O desafio expirou.',
    'This challenge is not compatible with Board API play.':
        'Este desafio não é compatível com a Board API.',
    'Challenge declined.': 'Desafio recusado.',
    'Accept challenge': 'Aceitar desafio',
    'Decline challenge': 'Recusar desafio',
    'Casual': 'Sem classificação',
  },
  'pl': {
    'Random match': 'Losowa partia',
    'Friend match': 'Partia ze znajomym',
    'Play with a Lichess friend': 'Zagraj ze znajomym z Lichess',
    'Refresh friends': 'Odśwież znajomych',
    'Checking whether this authorization can access your followed users...':
        'Sprawdzanie dostępu do obserwowanych użytkowników…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Ta autoryzacja Lichess nie obejmuje listy znajomych. Autoryzuj Lichess ponownie.',
    'Incoming challenges': 'Otrzymane wyzwania',
    'Search followed users': 'Szukaj obserwowanych użytkowników',
    'You are not following any Lichess users yet.':
        'Nie obserwujesz jeszcze żadnych użytkowników Lichess.',
    'No followed users match this search.':
        'Brak pasujących obserwowanych użytkowników.',
    'Your color': 'Twój kolor',
    'Cancel challenge': 'Anuluj wyzwanie',
    'Checking friend access...': 'Sprawdzanie dostępu do znajomych…',
    'Challenge selected friend': 'Rzuć wyzwanie wybranemu znajomemu',
    'Retry friend access': 'Ponów sprawdzanie dostępu',
    'Friend access could not be checked. Check the network and try again.':
        'Nie udało się sprawdzić dostępu do znajomych. Sprawdź sieć i spróbuj ponownie.',
    'Sending Lichess challenge...': 'Wysyłanie wyzwania Lichess…',
    'Waiting for your friend to accept the challenge...':
        'Oczekiwanie na przyjęcie wyzwania…',
    'Challenge accepted.': 'Wyzwanie przyjęte.',
    'Your friend declined the challenge.': 'Znajomy odrzucił wyzwanie.',
    'Challenge canceled.': 'Wyzwanie anulowane.',
    'The challenge expired.': 'Wyzwanie wygasło.',
    'This challenge is not compatible with Board API play.':
        'To wyzwanie nie jest zgodne z Board API.',
    'Challenge declined.': 'Wyzwanie odrzucone.',
    'Accept challenge': 'Przyjmij wyzwanie',
    'Decline challenge': 'Odrzuć wyzwanie',
    'Casual': 'Nierankingowa',
  },
  'ro': {
    'Random match': 'Partidă aleatorie',
    'Friend match': 'Partidă cu un prieten',
    'Play with a Lichess friend': 'Joacă cu un prieten Lichess',
    'Refresh friends': 'Reîmprospătează prietenii',
    'Checking whether this authorization can access your followed users...':
        'Se verifică dacă această autorizare poate accesa utilizatorii urmăriți…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Această autorizare Lichess nu include accesul la lista de prieteni. Autorizează din nou Lichess.',
    'Incoming challenges': 'Provocări primite',
    'Search followed users': 'Caută utilizatori urmăriți',
    'You are not following any Lichess users yet.':
        'Nu urmărești încă utilizatori Lichess.',
    'No followed users match this search.':
        'Niciun utilizator urmărit nu corespunde căutării.',
    'Your color': 'Culoarea ta',
    'Cancel challenge': 'Anulează provocarea',
    'Checking friend access...': 'Se verifică accesul la prieteni…',
    'Challenge selected friend': 'Provoacă prietenul selectat',
    'Retry friend access': 'Reîncearcă accesul la prieteni',
    'Friend access could not be checked. Check the network and try again.':
        'Accesul la prieteni nu a putut fi verificat. Verifică rețeaua și încearcă din nou.',
    'Sending Lichess challenge...': 'Se trimite provocarea Lichess…',
    'Waiting for your friend to accept the challenge...':
        'Se așteaptă acceptarea provocării…',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'Autorizarea Lichess nu a fost finalizată. Autorizarea existentă rămâne neschimbată.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'Noua autorizare Lichess nu este încă pregătită. Încearcă din nou.',
    'Challenge accepted.': 'Provocare acceptată.',
    'Your friend declined the challenge.': 'Prietenul a refuzat provocarea.',
    'Challenge canceled.': 'Provocare anulată.',
    'The challenge expired.': 'Provocarea a expirat.',
    'This challenge is not compatible with Board API play.':
        'Această provocare nu este compatibilă cu Board API.',
    'Challenge declined.': 'Provocare refuzată.',
    'Accept challenge': 'Acceptă provocarea',
    'Decline challenge': 'Refuză provocarea',
    'Casual': 'Neclasată',
  },
  'cs': {
    'Random match': 'Náhodná partie',
    'Friend match': 'Partie s přítelem',
    'Play with a Lichess friend': 'Hrát s přítelem z Lichess',
    'Refresh friends': 'Obnovit přátele',
    'Checking whether this authorization can access your followed users...':
        'Kontrola, zda toto oprávnění umožňuje přístup ke sledovaným uživatelům…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'Toto oprávnění Lichess nezahrnuje přístup k přátelům. Autorizujte Lichess znovu.',
    'Incoming challenges': 'Příchozí výzvy',
    'Search followed users': 'Hledat sledované uživatele',
    'You are not following any Lichess users yet.':
        'Zatím nesledujete žádné uživatele Lichess.',
    'No followed users match this search.':
        'Žádný sledovaný uživatel neodpovídá hledání.',
    'Your color': 'Vaše barva',
    'Cancel challenge': 'Zrušit výzvu',
    'Checking friend access...': 'Kontrola přístupu k přátelům…',
    'Challenge selected friend': 'Vyzvat vybraného přítele',
    'Retry friend access': 'Znovu ověřit přístup',
    'Friend access could not be checked. Check the network and try again.':
        'Přístup k přátelům se nepodařilo ověřit. Zkontrolujte síť a opakujte akci.',
    'Sending Lichess challenge...': 'Odesílání výzvy Lichess…',
    'Waiting for your friend to accept the challenge...':
        'Čekání na přijetí výzvy…',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'Autorizace Lichess nebyla dokončena. Stávající autorizace zůstala beze změny.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'Nová autorizace Lichess ještě není připravena. Zkuste to znovu.',
    'Challenge accepted.': 'Výzva přijata.',
    'Your friend declined the challenge.': 'Přítel výzvu odmítl.',
    'Challenge canceled.': 'Výzva zrušena.',
    'The challenge expired.': 'Platnost výzvy vypršela.',
    'This challenge is not compatible with Board API play.':
        'Tato výzva není kompatibilní s Board API.',
    'Challenge declined.': 'Výzva odmítnuta.',
    'Accept challenge': 'Přijmout výzvu',
    'Decline challenge': 'Odmítnout výzvu',
    'Casual': 'Nehodnocená',
  },
  'ar': {
    'Random match': 'مباراة عشوائية',
    'Friend match': 'مباراة مع صديق',
    'Play with a Lichess friend': 'العب مع صديق على Lichess',
    'Refresh friends': 'تحديث الأصدقاء',
    'Checking whether this authorization can access your followed users...':
        'جارٍ التحقق من قدرة هذا التفويض على الوصول إلى المستخدمين المتابَعين…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'لا يتضمن تفويض Lichess هذا صلاحية قائمة الأصدقاء. أعد تفويض Lichess.',
    'Incoming challenges': 'التحديات الواردة',
    'Search followed users': 'البحث في المستخدمين المتابَعين',
    'You are not following any Lichess users yet.':
        'أنت لا تتابع أي مستخدم على Lichess بعد.',
    'No followed users match this search.':
        'لا يوجد مستخدم متابَع يطابق البحث.',
    'Your color': 'لونك',
    'Cancel challenge': 'إلغاء التحدي',
    'Checking friend access...': 'جارٍ التحقق من صلاحية الأصدقاء…',
    'Challenge selected friend': 'تحدي الصديق المحدد',
    'Retry friend access': 'إعادة التحقق من صلاحية الأصدقاء',
    'Friend access could not be checked. Check the network and try again.':
        'تعذر التحقق من صلاحية الأصدقاء. تحقق من الشبكة وحاول مجددًا.',
    'Sending Lichess challenge...': 'جارٍ إرسال تحدي Lichess…',
    'Waiting for your friend to accept the challenge...':
        'في انتظار قبول صديقك للتحدي…',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'لم يكتمل تفويض Lichess. بقي التفويض الحالي دون تغيير.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'تفويض Lichess الجديد غير جاهز بعد. حاول مجددًا.',
    'Challenge accepted.': 'تم قبول التحدي.',
    'Your friend declined the challenge.': 'رفض صديقك التحدي.',
    'Challenge canceled.': 'تم إلغاء التحدي.',
    'The challenge expired.': 'انتهت صلاحية التحدي.',
    'This challenge is not compatible with Board API play.':
        'هذا التحدي غير متوافق مع Board API.',
    'Challenge declined.': 'تم رفض التحدي.',
    'Accept challenge': 'قبول التحدي',
    'Decline challenge': 'رفض التحدي',
    'Casual': 'غير مصنفة',
  },
  'he': {
    'Random match': 'משחק אקראי',
    'Friend match': 'משחק עם חבר',
    'Play with a Lichess friend': 'משחק עם חבר מ־Lichess',
    'Refresh friends': 'רענון חברים',
    'Checking whether this authorization can access your followed users...':
        'בודק אם ההרשאה יכולה לגשת למשתמשים שבמעקב…',
    'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.':
        'הרשאת Lichess זו אינה כוללת גישה לרשימת החברים. יש לאשר מחדש את Lichess.',
    'Incoming challenges': 'אתגרים נכנסים',
    'Search followed users': 'חיפוש משתמשים במעקב',
    'You are not following any Lichess users yet.':
        'עדיין אינך עוקב אחרי משתמשי Lichess.',
    'No followed users match this search.': 'לא נמצאו משתמשים מתאימים במעקב.',
    'Your color': 'הצבע שלך',
    'Cancel challenge': 'ביטול האתגר',
    'Checking friend access...': 'בודק גישה לחברים…',
    'Challenge selected friend': 'שליחת אתגר לחבר שנבחר',
    'Retry friend access': 'בדיקה חוזרת של הגישה',
    'Friend access could not be checked. Check the network and try again.':
        'לא ניתן לבדוק את הגישה לחברים. בדקו את הרשת ונסו שוב.',
    'Sending Lichess challenge...': 'שולח אתגר Lichess…',
    'Waiting for your friend to accept the challenge...':
        'ממתין שהחבר יאשר את האתגר…',
    'Lichess authorization was not completed. Your existing authorization is unchanged.':
        'הרשאת Lichess לא הושלמה. ההרשאה הקיימת לא השתנתה.',
    'The new Lichess authorization is not ready yet. Please try again.':
        'הרשאת Lichess החדשה עדיין אינה מוכנה. נסו שוב.',
    'Challenge accepted.': 'האתגר אושר.',
    'Your friend declined the challenge.': 'החבר דחה את האתגר.',
    'Challenge canceled.': 'האתגר בוטל.',
    'The challenge expired.': 'תוקף האתגר פג.',
    'This challenge is not compatible with Board API play.':
        'אתגר זה אינו תואם למשחק דרך Board API.',
    'Challenge declined.': 'האתגר נדחה.',
    'Accept challenge': 'אישור האתגר',
    'Decline challenge': 'דחיית האתגר',
    'Casual': 'ללא דירוג',
  },
};

String? _commentaryVoiceTranslations(String text, String key) {
  const translations = <String, Map<String, String>>{
    'Commentary voice': {
      'zh-Hans': '解说声音',
      'zh-Hant': '解說聲音',
      'de': 'Kommentarstimme',
      'es': 'Voz de comentarios',
      'fr': 'Voix du commentaire',
      'it': 'Voce del commento',
      'ja': '解説音声',
      'ko': '해설 음성',
      'nl': 'Commentaarstem',
      'ru': 'Голос комментария',
      'pt': 'Voz dos comentários',
      'pl': 'Głos komentarza',
      'ro': 'Vocea comentariului',
      'cs': 'Hlas komentáře',
      'ar': 'صوت التعليق',
      'he': 'קול הפרשנות',
    },
    'Female voice': {
      'zh-Hans': '女声',
      'zh-Hant': '女聲',
      'de': 'Weibliche Stimme',
      'es': 'Voz femenina',
      'fr': 'Voix féminine',
      'it': 'Voce femminile',
      'ja': '女性の声',
      'ko': '여성 음성',
      'nl': 'Vrouwenstem',
      'ru': 'Женский голос',
      'pt': 'Voz feminina',
      'pl': 'Głos żeński',
      'ro': 'Voce feminină',
      'cs': 'Ženský hlas',
      'ar': 'صوت نسائي',
      'he': 'קול נשי',
    },
    'Male voice': {
      'zh-Hans': '男声',
      'zh-Hant': '男聲',
      'de': 'Männliche Stimme',
      'es': 'Voz masculina',
      'fr': 'Voix masculine',
      'it': 'Voce maschile',
      'ja': '男性の声',
      'ko': '남성 음성',
      'nl': 'Mannenstem',
      'ru': 'Мужской голос',
      'pt': 'Voz masculina',
      'pl': 'Głos męski',
      'ro': 'Voce masculină',
      'cs': 'Mužský hlas',
      'ar': 'صوت رجالي',
      'he': 'קול גברי',
    },
  };
  return translations[text]?[key];
}

String? _visionSettingTranslations(String text, String key) {
  const translations = <String, Map<String, String>>{
    'Vision recognition only': {
      'zh-Hans': 'Vision 仅识别',
      'zh-Hant': 'Vision 僅識別',
      'de': 'Nur Vision-Erkennung',
      'es': 'Solo reconocimiento Vision',
      'fr': 'Reconnaissance Vision uniquement',
      'it': 'Solo riconoscimento Vision',
      'ja': 'Vision 認識のみ',
      'ko': 'Vision 인식만 사용',
      'nl': 'Alleen Vision-herkenning',
      'ru': 'Только распознавание Vision',
      'pt': 'Apenas reconhecimento Vision',
      'pl': 'Tylko rozpoznawanie Vision',
      'ro': 'Doar recunoaștere Vision',
      'cs': 'Pouze rozpoznávání Vision',
      'ar': 'التعرّف عبر Vision فقط',
      'he': 'זיהוי Vision בלבד',
    },
    'Recognize and guide the physical board without simulating taps on the screen':
        {
      'zh-Hans': '识别并引导物理棋盘，但不模拟点击屏幕',
      'zh-Hant': '識別並引導實體棋盤，但不模擬點按螢幕',
      'de':
          'Das physische Brett erkennen und führen, ohne Bildschirmtipps zu simulieren',
      'es':
          'Reconoce y guía el tablero físico sin simular toques en la pantalla',
      'fr':
          'Reconnaître et guider l’échiquier physique sans simuler d’appuis à l’écran',
      'it':
          'Riconosce e guida la scacchiera fisica senza simulare tocchi sullo schermo',
      'ja': '画面のタップをシミュレートせずに物理ボードを認識して案内します',
      'ko': '화면 탭을 시뮬레이션하지 않고 실제 보드를 인식하고 안내합니다',
      'nl':
          'Het fysieke bord herkennen en begeleiden zonder schermtikken te simuleren',
      'ru':
          'Распознавать и направлять физическую доску без имитации нажатий на экран',
      'pt':
          'Reconhecer e orientar o tabuleiro físico sem simular toques no ecrã',
      'pl':
          'Rozpoznawaj i prowadź fizyczną szachownicę bez symulowania dotknięć ekranu',
      'ro':
          'Recunoaște și ghidează tabla fizică fără a simula atingeri pe ecran',
      'cs':
          'Rozpoznávat a vést fyzickou šachovnici bez simulace klepnutí na obrazovku',
      'ar':
          'التعرّف على الرقعة الفعلية وإرشادها من دون محاكاة النقر على الشاشة',
      'he': 'זיהוי והנחיה של הלוח הפיזי ללא הדמיית הקשות על המסך',
    },
  };
  return translations[text]?[key];
}

String? _standardAnalysisControlTranslations(String text, String key) {
  const translations = <String, Map<String, String>>{
    'Analysis depth': {
      'zh-Hans': '分析深度',
      'zh-Hant': '分析深度',
      'de': 'Analysetiefe',
      'es': 'Profundidad de análisis',
      'fr': 'Profondeur d’analyse',
      'it': 'Profondità di analisi',
      'ja': '解析深度',
      'ko': '분석 깊이',
      'nl': 'Analysediepte',
      'ru': 'Глубина анализа',
      'pt': 'Profundidade da análise',
      'pl': 'Głębokość analizy',
      'ro': 'Adâncimea analizei',
      'cs': 'Hloubka analýzy',
      'ar': 'عمق التحليل',
      'he': 'עומק הניתוח',
    },
    'Regenerate report': {
      'zh-Hans': '重新生成报告',
      'zh-Hant': '重新產生報告',
      'de': 'Bericht neu erstellen',
      'es': 'Volver a generar el informe',
      'fr': 'Régénérer le rapport',
      'it': 'Rigenera rapporto',
      'ja': 'レポートを再生成',
      'ko': '보고서 다시 생성',
      'nl': 'Rapport opnieuw genereren',
      'ru': 'Повторно создать отчёт',
      'pt': 'Gerar relatório novamente',
      'pl': 'Wygeneruj raport ponownie',
      'ro': 'Regenerează raportul',
      'cs': 'Znovu vygenerovat zprávu',
      'ar': 'إعادة إنشاء التقرير',
      'he': 'יצירת הדוח מחדש',
    },
  };
  return translations[text]?[key];
}

String? _authRecoveryTranslations(String text, String key) {
  const translations = <String, Map<String, String>>{
    'Login refreshed. Please try again.': {
      'zh-Hans': '登录状态已刷新，请稍后重试。',
      'zh-Hant': '登入狀態已重新整理，請稍後再試。',
      'de': 'Die Anmeldung wurde erneuert. Bitte versuchen Sie es erneut.',
      'es': 'Se ha renovado la sesión. Inténtalo de nuevo.',
      'fr': 'La connexion a été actualisée. Veuillez réessayer.',
      'it': 'L’accesso è stato aggiornato. Riprova.',
      'ja': 'ログイン状態を更新しました。もう一度お試しください。',
      'ko': '로그인 상태가 갱신되었습니다. 다시 시도해 주세요.',
      'nl': 'De aanmelding is vernieuwd. Probeer het opnieuw.',
      'ru': 'Сеанс входа обновлён. Повторите попытку.',
      'pt': 'A sessão foi renovada. Tente novamente.',
      'pl': 'Sesja logowania została odświeżona. Spróbuj ponownie.',
      'ro': 'Sesiunea de conectare a fost reînnoită. Încercați din nou.',
      'cs': 'Přihlášení bylo obnoveno. Zkuste to znovu.',
      'ar': 'تم تحديث تسجيل الدخول. يُرجى المحاولة مرة أخرى.',
      'he': 'מצב ההתחברות רוענן. נא לנסות שוב.',
    },
    'Your login has expired. Please sign in again.': {
      'zh-Hans': '登录状态已失效，请重新登录。',
      'zh-Hant': '登入狀態已失效，請重新登入。',
      'de': 'Ihre Anmeldung ist abgelaufen. Bitte melden Sie sich erneut an.',
      'es': 'Tu sesión ha caducado. Vuelve a iniciar sesión.',
      'fr': 'Votre connexion a expiré. Veuillez vous reconnecter.',
      'it': 'La sessione è scaduta. Accedi di nuovo.',
      'ja': 'ログインの有効期限が切れました。もう一度ログインしてください。',
      'ko': '로그인이 만료되었습니다. 다시 로그인해 주세요.',
      'nl': 'Uw aanmelding is verlopen. Meld u opnieuw aan.',
      'ru': 'Срок действия входа истёк. Войдите снова.',
      'pt': 'A sessão expirou. Inicie sessão novamente.',
      'pl': 'Sesja logowania wygasła. Zaloguj się ponownie.',
      'ro': 'Sesiunea de conectare a expirat. Conectați-vă din nou.',
      'cs': 'Platnost přihlášení vypršela. Přihlaste se znovu.',
      'ar': 'انتهت صلاحية تسجيل الدخول. يُرجى تسجيل الدخول مرة أخرى.',
      'he': 'תוקף ההתחברות פג. נא להתחבר מחדש.',
    },
  };
  return translations[text]?[key];
}

String? _lichessDrawTranslations(String text, String key) {
  const translations = <String, Map<String, String>>{
    'Draw offer': {
      'zh-Hans': '和棋提议',
      'zh-Hant': '和棋提議',
      'de': 'Remisangebot',
      'es': 'Oferta de tablas',
      'fr': 'Proposition de nulle',
      'it': 'Offerta di patta',
      'ja': '引き分けの提案',
      'ko': '무승부 제안',
      'nl': 'Remiseaanbod',
      'ru': 'Предложение ничьей',
      'pt': 'Proposta de empate',
      'pl': 'Oferta remisu',
      'ro': 'Ofertă de remiză',
      'cs': 'Nabídka remízy',
      'ar': 'عرض التعادل',
      'he': 'הצעת תיקו',
    },
    'White offers a draw.': {
      'zh-Hans': '白方提出和棋。',
      'zh-Hant': '白方提出和棋。',
      'de': 'Weiß bietet ein Remis an.',
      'es': 'Las blancas ofrecen tablas.',
      'fr': 'Les blancs proposent la nulle.',
      'it': 'Il Bianco offre patta.',
      'ja': '白が引き分けを提案しました。',
      'ko': '백이 무승부를 제안했습니다.',
      'nl': 'Wit biedt remise aan.',
      'ru': 'Белые предлагают ничью.',
      'pt': 'As brancas propõem empate.',
      'pl': 'Białe proponują remis.',
      'ro': 'Albul oferă remiză.',
      'cs': 'Bílý nabízí remízu.',
      'ar': 'الأبيض يعرض التعادل.',
      'he': 'הלבן מציע תיקו.',
    },
    'Black offers a draw.': {
      'zh-Hans': '黑方提出和棋。',
      'zh-Hant': '黑方提出和棋。',
      'de': 'Schwarz bietet ein Remis an.',
      'es': 'Las negras ofrecen tablas.',
      'fr': 'Les noirs proposent la nulle.',
      'it': 'Il Nero offre patta.',
      'ja': '黒が引き分けを提案しました。',
      'ko': '흑이 무승부를 제안했습니다.',
      'nl': 'Zwart biedt remise aan.',
      'ru': 'Чёрные предлагают ничью.',
      'pt': 'As pretas propõem empate.',
      'pl': 'Czarne proponują remis.',
      'ro': 'Negrul oferă remiză.',
      'cs': 'Černý nabízí remízu.',
      'ar': 'الأسود يعرض التعادل.',
      'he': 'השחור מציע תיקו.',
    },
    'Accept': {
      'zh-Hans': '接受',
      'zh-Hant': '接受',
      'de': 'Annehmen',
      'es': 'Aceptar',
      'fr': 'Accepter',
      'it': 'Accetta',
      'ja': '承諾',
      'ko': '수락',
      'nl': 'Accepteren',
      'ru': 'Принять',
      'pt': 'Aceitar',
      'pl': 'Akceptuj',
      'ro': 'Acceptă',
      'cs': 'Přijmout',
      'ar': 'قبول',
      'he': 'קבל',
    },
    'Decline': {
      'zh-Hans': '拒绝',
      'zh-Hant': '拒絕',
      'de': 'Ablehnen',
      'es': 'Rechazar',
      'fr': 'Refuser',
      'it': 'Rifiuta',
      'ja': '拒否',
      'ko': '거절',
      'nl': 'Weigeren',
      'ru': 'Отклонить',
      'pt': 'Recusar',
      'pl': 'Odrzuć',
      'ro': 'Refuză',
      'cs': 'Odmítnout',
      'ar': 'رفض',
      'he': 'דחה',
    },
    'Draw accepted': {
      'zh-Hans': '已接受和棋',
      'zh-Hant': '已接受和棋',
      'de': 'Remis angenommen',
      'es': 'Tablas aceptadas',
      'fr': 'Nulle acceptée',
      'it': 'Patta accettata',
      'ja': '引き分けを受け入れました',
      'ko': '무승부를 수락했습니다',
      'nl': 'Remise geaccepteerd',
      'ru': 'Ничья принята',
      'pt': 'Empate aceito',
      'pl': 'Remis zaakceptowany',
      'ro': 'Remiză acceptată',
      'cs': 'Remíza přijata',
      'ar': 'تم قبول التعادل',
      'he': 'התיקו התקבל',
    },
    'Draw declined': {
      'zh-Hans': '已拒绝和棋',
      'zh-Hant': '已拒絕和棋',
      'de': 'Remis abgelehnt',
      'es': 'Tablas rechazadas',
      'fr': 'Nulle refusée',
      'it': 'Patta rifiutata',
      'ja': '引き分けを拒否しました',
      'ko': '무승부를 거절했습니다',
      'nl': 'Remise geweigerd',
      'ru': 'Ничья отклонена',
      'pt': 'Empate recusado',
      'pl': 'Remis odrzucony',
      'ro': 'Remiză refuzată',
      'cs': 'Remíza odmítnuta',
      'ar': 'تم رفض التعادل',
      'he': 'התיקו נדחה',
    },
    'Accept draw failed': {
      'zh-Hans': '接受和棋失败',
      'zh-Hant': '接受和棋失敗',
      'de': 'Annahme des Remis fehlgeschlagen',
      'es': 'No se pudieron aceptar las tablas',
      'fr': 'Échec de l’acceptation de la nulle',
      'it': 'Impossibile accettare la patta',
      'ja': '引き分けの受け入れに失敗しました',
      'ko': '무승부 수락 실패',
      'nl': 'Remise accepteren mislukt',
      'ru': 'Не удалось принять ничью',
      'pt': 'Falha ao aceitar o empate',
      'pl': 'Nie udało się zaakceptować remisu',
      'ro': 'Acceptarea remizei a eșuat',
      'cs': 'Přijetí remízy se nezdařilo',
      'ar': 'فشل قبول التعادل',
      'he': 'קבלת התיקו נכשלה',
    },
    'Decline draw failed': {
      'zh-Hans': '拒绝和棋失败',
      'zh-Hant': '拒絕和棋失敗',
      'de': 'Ablehnung des Remis fehlgeschlagen',
      'es': 'No se pudieron rechazar las tablas',
      'fr': 'Échec du refus de la nulle',
      'it': 'Impossibile rifiutare la patta',
      'ja': '引き分けの拒否に失敗しました',
      'ko': '무승부 거절 실패',
      'nl': 'Remise weigeren mislukt',
      'ru': 'Не удалось отклонить ничью',
      'pt': 'Falha ao recusar o empate',
      'pl': 'Nie udało się odrzucić remisu',
      'ro': 'Refuzul remizei a eșuat',
      'cs': 'Odmítnutí remízy se nezdařilo',
      'ar': 'فشل رفض التعادل',
      'he': 'דחיית התיקו נכשלה',
    },
  };
  return translations[text]?[key];
}

const _engineLabStaticTranslations = <String, Map<String, String>>{
  'Engine market': {
    'zh-Hans': '引擎市场',
    'zh-Hant': '引擎市場',
    'de': 'Engine-Markt',
    'es': 'Mercado de motores',
    'fr': 'Marché des moteurs',
    'it': 'Mercato motori',
    'ja': 'エンジンマーケット',
    'ko': '엔진 마켓',
    'nl': 'Engine-markt',
    'ru': 'Магазин движков',
  },
  'Manage custom LC0 models trained from your own games.': {
    'zh-Hans': '管理用你自己的对局训练出的自定义 LC0 模型。',
    'zh-Hant': '管理用你自己的對局訓練出的自訂 LC0 模型。',
    'de':
        'Verwalte eigene LC0-Modelle, die aus deinen Partien trainiert wurden.',
    'es': 'Gestiona modelos LC0 personalizados entrenados con tus partidas.',
    'fr': 'Gérez les modèles LC0 personnalisés entraînés avec vos parties.',
    'it': 'Gestisci modelli LC0 personalizzati allenati dalle tue partite.',
    'ja': '自分の対局でトレーニングしたカスタム LC0 モデルを管理します。',
    'ko': '내 대국으로 훈련한 맞춤 LC0 모델을 관리합니다.',
    'nl':
        'Beheer aangepaste LC0-modellen die met je eigen partijen zijn getraind.',
    'ru': 'Управляйте своими моделями LC0, обученными на ваших партиях.',
  },
  'Download Chessnut-provided LC0 engines.': {
    'zh-Hans': '下载 Chessnut 提供的 LC0 引擎。',
    'zh-Hant': '下載 Chessnut 提供的 LC0 引擎。',
    'de': 'Lade von Chessnut bereitgestellte LC0-Engines herunter.',
    'es': 'Descarga motores LC0 proporcionados por Chessnut.',
    'fr': 'Téléchargez les moteurs LC0 fournis par Chessnut.',
    'it': 'Scarica motori LC0 forniti da Chessnut.',
    'ja': 'Chessnut が提供する LC0 エンジンをダウンロードします。',
    'ko': 'Chessnut이 제공하는 LC0 엔진을 다운로드합니다.',
    'nl': 'Download LC0-engines die door Chessnut worden geleverd.',
    'ru': 'Загружайте движки LC0, предоставленные Chessnut.',
  },
  'Build your own LC0 engines and enable completed models.': {
    'zh-Hans': '构建你自己的 LC0 引擎，并启用已完成的模型。',
    'zh-Hant': '建置你自己的 LC0 引擎，並啟用已完成的模型。',
    'de': 'Erstelle eigene LC0-Engines und aktiviere fertige Modelle.',
    'es': 'Crea tus propios motores LC0 y activa los modelos terminados.',
    'fr': 'Créez vos moteurs LC0 et activez les modèles terminés.',
    'it': 'Crea i tuoi motori LC0 e abilita i modelli completati.',
    'ja': '自分の LC0 エンジンを作成し、完了したモデルを有効化します。',
    'ko': '나만의 LC0 엔진을 만들고 완료된 모델을 활성화합니다.',
    'nl': 'Bouw je eigen LC0-engines en schakel voltooide modellen in.',
    'ru': 'Создавайте свои движки LC0 и включайте готовые модели.',
  },
  'Download Chessnut-provided LC0 engines for Bot game.': {
    'zh-Hans': '下载 Chessnut 提供的 LC0 引擎用于 Bot game。',
    'zh-Hant': '下載 Chessnut 提供的 LC0 引擎用於 Bot game。',
    'de': 'Lade Chessnut-LC0-Engines für Bot game herunter.',
    'es': 'Descarga motores LC0 de Chessnut para Bot game.',
    'fr': 'Téléchargez les moteurs LC0 Chessnut pour Bot game.',
    'it': 'Scarica motori LC0 Chessnut per Bot game.',
    'ja': 'Bot game 用に Chessnut 提供の LC0 エンジンをダウンロードします。',
    'ko': 'Bot game에서 사용할 Chessnut 제공 LC0 엔진을 다운로드합니다.',
    'nl': 'Download Chessnut-LC0-engines voor Bot game.',
    'ru': 'Скачивайте движки LC0 от Chessnut для Bot game.',
  },
  'Bot game engine library': {
    'zh-Hans': 'Bot game 引擎库',
    'zh-Hant': 'Bot game 引擎庫',
    'de': 'Bot game-Engine-Bibliothek',
    'es': 'Biblioteca de motores de Bot game',
    'fr': 'Bibliothèque de moteurs Bot game',
    'it': 'Libreria motori Bot game',
    'ja': 'Bot game エンジンライブラリ',
    'ko': 'Bot game 엔진 라이브러리',
    'nl': 'Bot game-enginebibliotheek',
    'ru': 'Библиотека движков Bot game',
  },
  'Enabled personal and market engines appear in Bot game LC0 choices.': {
    'zh-Hans': '已启用的个人和市场引擎会出现在 Bot game 的 LC0 选项中。',
    'zh-Hant': '已啟用的個人和市場引擎會出現在 Bot game 的 LC0 選項中。',
    'de':
        'Aktivierte persönliche und Markt-Engines erscheinen in den LC0-Auswahlen von Bot game.',
    'es':
        'Los motores personales y del mercado activados aparecen en las opciones LC0 de Bot game.',
    'fr':
        'Les moteurs personnels et du marché activés apparaissent dans les choix LC0 de Bot game.',
    'it':
        'I motori personali e di mercato abilitati appaiono tra le scelte LC0 di Bot game.',
    'ja': '有効化した個人エンジンとマーケットエンジンは Bot game の LC0 選択肢に表示されます。',
    'ko': '활성화된 개인 및 마켓 엔진은 Bot game LC0 선택지에 표시됩니다.',
    'nl':
        'Ingeschakelde persoonlijke en markt-engines verschijnen in de LC0-keuzes van Bot game.',
    'ru':
        'Включённые личные и рыночные движки появятся в вариантах LC0 для Bot game.',
  },
  'Search enabled engines': {
    'zh-Hans': '搜索已启用引擎',
    'zh-Hant': '搜尋已啟用引擎',
    'de': 'Aktivierte Engines suchen',
    'es': 'Buscar motores activados',
    'fr': 'Rechercher des moteurs activés',
    'it': 'Cerca motori abilitati',
    'ja': '有効なエンジンを検索',
    'ko': '활성화된 엔진 검색',
    'nl': 'Ingeschakelde engines zoeken',
    'ru': 'Поиск включённых движков',
  },
  'Built-in': {
    'zh-Hans': '内置',
    'zh-Hant': '內建',
    'de': 'Integriert',
    'es': 'Integrado',
    'fr': 'Intégré',
    'it': 'Integrato',
    'ja': '内蔵',
    'ko': '내장',
    'nl': 'Ingebouwd',
    'ru': 'Встроено',
  },
  'No enabled engines match these filters. Enable personal builds or downloaded market engines to use them in Bot game.':
      {
    'zh-Hans': '没有已启用引擎匹配这些筛选。启用个人构建或已下载的市场引擎后即可在 Bot game 中使用。',
    'zh-Hant': '沒有已啟用引擎符合這些篩選。啟用個人建置或已下載的市場引擎後即可在 Bot game 中使用。',
    'de':
        'Keine aktivierten Engines passen zu diesen Filtern. Aktiviere persönliche Builds oder heruntergeladene Markt-Engines für Bot game.',
    'es':
        'Ningún motor activado coincide con estos filtros. Activa builds personales o motores del mercado descargados para usarlos en Bot game.',
    'fr':
        'Aucun moteur activé ne correspond à ces filtres. Activez des builds personnels ou des moteurs du marché téléchargés pour Bot game.',
    'it':
        'Nessun motore abilitato corrisponde a questi filtri. Abilita build personali o motori di mercato scaricati per Bot game.',
    'ja':
        'これらのフィルターに一致する有効なエンジンはありません。個人ビルドまたはダウンロード済みマーケットエンジンを有効化すると Bot game で使えます。',
    'ko':
        '이 필터와 일치하는 활성화된 엔진이 없습니다. 개인 빌드나 다운로드한 마켓 엔진을 활성화하면 Bot game에서 사용할 수 있습니다.',
    'nl':
        'Geen ingeschakelde engines passen bij deze filters. Schakel persoonlijke builds of gedownloade markt-engines in voor Bot game.',
    'ru':
        'Нет включённых движков по этим фильтрам. Включите личные сборки или загруженные движки рынка для Bot game.',
  },
  'Curated LC0 engines': {
    'zh-Hans': '精选 LC0 引擎',
    'zh-Hant': '精選 LC0 引擎',
    'de': 'Kuratierte LC0-Engines',
    'es': 'Motores LC0 seleccionados',
    'fr': 'Moteurs LC0 sélectionnés',
    'it': 'Motori LC0 selezionati',
    'ja': '厳選 LC0 エンジン',
    'ko': '선별된 LC0 엔진',
    'nl': 'Geselecteerde LC0-engines',
    'ru': 'Подборка движков LC0',
  },
  'Popular LC0 community weights selected and provided by Chessnut. Download and enable the engines you want in Bot game.':
      {
    'zh-Hans': 'Chessnut 精选并提供热门 LC0 社区权重。下载并启用你想在 Bot game 中使用的引擎。',
    'zh-Hant': 'Chessnut 精選並提供熱門 LC0 社群權重。下載並啟用你想在 Bot game 中使用的引擎。',
    'de':
        'Beliebte LC0-Community-Gewichte, ausgewählt und bereitgestellt von Chessnut. Lade die gewünschten Engines herunter und aktiviere sie für Bot game.',
    'es':
        'Pesos LC0 populares de la comunidad, seleccionados y proporcionados por Chessnut. Descarga y activa los motores que quieras en Bot game.',
    'fr':
        'Poids LC0 populaires de la communauté, sélectionnés et fournis par Chessnut. Téléchargez et activez les moteurs voulus dans Bot game.',
    'it':
        'Pesi LC0 popolari della community, selezionati e forniti da Chessnut. Scarica e abilita i motori che vuoi in Bot game.',
    'ja':
        'Chessnut が選んで提供する人気の LC0 コミュニティ重みです。Bot game で使いたいエンジンをダウンロードして有効化します。',
    'ko':
        'Chessnut이 선별해 제공하는 인기 LC0 커뮤니티 가중치입니다. Bot game에서 사용할 엔진을 다운로드하고 활성화하세요.',
    'nl':
        'Populaire LC0-communitygewichten, geselecteerd en geleverd door Chessnut. Download en schakel de engines in die je in Bot game wilt gebruiken.',
    'ru':
        'Популярные веса LC0 сообщества, отобранные и предоставленные Chessnut. Скачайте и включите нужные движки для Bot game.',
  },
  'Provided by Chessnut': {
    'zh-Hans': 'Chessnut 提供',
    'zh-Hant': 'Chessnut 提供',
    'de': 'Von Chessnut bereitgestellt',
    'es': 'Proporcionado por Chessnut',
    'fr': 'Fourni par Chessnut',
    'it': 'Fornito da Chessnut',
    'ja': 'Chessnut 提供',
    'ko': 'Chessnut 제공',
    'nl': 'Geleverd door Chessnut',
    'ru': 'Предоставлено Chessnut',
  },
  'Search engines': {
    'zh-Hans': '搜索引擎',
    'zh-Hant': '搜尋引擎',
    'de': 'Engines suchen',
    'es': 'Buscar motores',
    'fr': 'Rechercher des moteurs',
    'it': 'Cerca motori',
    'ja': 'エンジンを検索',
    'ko': '엔진 검색',
    'nl': 'Engines zoeken',
    'ru': 'Поиск движков',
  },
  'No curated LC0 engines are available right now. Pull to refresh later.': {
    'zh-Hans': '当前没有可用的精选 LC0 引擎。稍后下拉刷新。',
    'zh-Hant': '目前沒有可用的精選 LC0 引擎。稍後下拉重新整理。',
    'de':
        'Derzeit sind keine kuratierten LC0-Engines verfügbar. Ziehe später zum Aktualisieren.',
    'es':
        'No hay motores LC0 seleccionados disponibles ahora. Desliza para actualizar más tarde.',
    'fr':
        'Aucun moteur LC0 sélectionné n’est disponible pour le moment. Tirez pour actualiser plus tard.',
    'it':
        'Nessun motore LC0 selezionato disponibile ora. Trascina per aggiornare più tardi.',
    'ja': '現在利用できる厳選 LC0 エンジンはありません。後で引っ張って更新してください。',
    'ko': '현재 사용할 수 있는 선별 LC0 엔진이 없습니다. 나중에 당겨서 새로고침하세요.',
    'nl':
        'Er zijn nu geen geselecteerde LC0-engines beschikbaar. Trek later omlaag om te vernieuwen.',
    'ru':
        'Сейчас нет доступных отобранных движков LC0. Потяните для обновления позже.',
  },
  'Unlike this engine': {
    'zh-Hans': '取消点赞这个引擎',
    'zh-Hant': '取消按讚這個引擎',
    'de': 'Like für diese Engine entfernen',
    'es': 'Quitar me gusta a este motor',
    'fr': 'Retirer le j’aime de ce moteur',
    'it': 'Rimuovi Mi piace da questo motore',
    'ja': 'このエンジンのいいねを解除',
    'ko': '이 엔진 좋아요 취소',
    'nl': 'Like voor deze engine verwijderen',
    'ru': 'Убрать лайк с движка',
  },
  'Like this engine': {
    'zh-Hans': '点赞这个引擎',
    'zh-Hant': '按讚這個引擎',
    'de': 'Diese Engine liken',
    'es': 'Dar me gusta a este motor',
    'fr': 'Aimer ce moteur',
    'it': 'Metti Mi piace a questo motore',
    'ja': 'このエンジンにいいね',
    'ko': '이 엔진 좋아요',
    'nl': 'Deze engine liken',
    'ru': 'Поставить лайк движку',
  },
  'Community LC0': {
    'zh-Hans': '社区 LC0',
    'zh-Hant': '社群 LC0',
    'de': 'Community-LC0',
    'es': 'LC0 comunitario',
    'fr': 'LC0 communautaire',
    'it': 'LC0 community',
    'ja': 'コミュニティ LC0',
    'ko': '커뮤니티 LC0',
    'nl': 'Community-LC0',
    'ru': 'LC0 сообщества',
  },
  'LC0 weight ready': {
    'zh-Hans': 'LC0 权重已就绪',
    'zh-Hant': 'LC0 權重已就緒',
    'de': 'LC0-Gewicht bereit',
    'es': 'Peso LC0 listo',
    'fr': 'Poids LC0 prêt',
    'it': 'Peso LC0 pronto',
    'ja': 'LC0 重み準備完了',
    'ko': 'LC0 가중치 준비됨',
    'nl': 'LC0-gewicht gereed',
    'ru': 'Вес LC0 готов',
  },
  'Ready in Bot game': {
    'zh-Hans': '可在 Bot game 中使用',
    'zh-Hant': '可在 Bot game 中使用',
    'de': 'Bereit in Bot game',
    'es': 'Listo en Bot game',
    'fr': 'Prêt dans Bot game',
    'it': 'Pronto in Bot game',
    'ja': 'Bot game で利用可能',
    'ko': 'Bot game에서 준비됨',
    'nl': 'Gereed in Bot game',
    'ru': 'Готово в Bot game',
  },
  'Download to use': {
    'zh-Hans': '下载后使用',
    'zh-Hant': '下載後使用',
    'de': 'Zum Nutzen herunterladen',
    'es': 'Descargar para usar',
    'fr': 'Télécharger pour utiliser',
    'it': 'Scarica per usare',
    'ja': 'ダウンロードして使用',
    'ko': '다운로드 후 사용',
    'nl': 'Downloaden om te gebruiken',
    'ru': 'Скачать для использования',
  },
  'Search personal engines': {
    'zh-Hans': '搜索个人引擎',
    'zh-Hant': '搜尋個人引擎',
    'de': 'Persönliche Engines suchen',
    'es': 'Buscar motores personales',
    'fr': 'Rechercher des moteurs personnels',
    'it': 'Cerca motori personali',
    'ja': '個人エンジンを検索',
    'ko': '개인 엔진 검색',
    'nl': 'Persoonlijke engines zoeken',
    'ru': 'Поиск личных движков',
  },
  'Training games ready': {
    'zh-Hans': '训练对局已就绪',
    'zh-Hant': '訓練對局已就緒',
    'de': 'Trainingspartien bereit',
    'es': 'Partidas de entrenamiento listas',
    'fr': 'Parties d’entraînement prêtes',
    'it': 'Partite di allenamento pronte',
    'ja': 'トレーニング対局準備完了',
    'ko': '훈련 대국 준비됨',
    'nl': 'Trainingspartijen gereed',
    'ru': 'Учебные партии готовы',
  },
  'Training games': {
    'zh-Hans': '训练对局',
    'zh-Hant': '訓練對局',
    'de': 'Trainingspartien',
    'es': 'Partidas de entrenamiento',
    'fr': 'Parties d’entraînement',
    'it': 'Partite di allenamento',
    'ja': 'トレーニング対局',
    'ko': '훈련 대국',
    'nl': 'Trainingspartijen',
    'ru': 'Учебные партии',
  },
  'Enabled for Bot game': {
    'zh-Hans': '已启用于 Bot game',
    'zh-Hant': '已啟用於 Bot game',
    'de': 'Für Bot game aktiviert',
    'es': 'Activado para Bot game',
    'fr': 'Activé pour Bot game',
    'it': 'Abilitato per Bot game',
    'ja': 'Bot game で有効',
    'ko': 'Bot game에 활성화됨',
    'nl': 'Ingeschakeld voor Bot game',
    'ru': 'Включено для Bot game',
  },
  'Engine Report': {
    'zh-Hans': '引擎报告',
    'zh-Hant': '引擎報告',
    'de': 'Engine-Bericht',
    'es': 'Informe del motor',
    'fr': 'Rapport du moteur',
    'it': 'Report motore',
    'ja': 'エンジンレポート',
    'ko': '엔진 리포트',
    'nl': 'Enginerapport',
    'ru': 'Отчёт движка',
  },
  'Use this model': {
    'zh-Hans': '使用这个模型',
    'zh-Hant': '使用這個模型',
    'de': 'Dieses Modell nutzen',
    'es': 'Usar este modelo',
    'fr': 'Utiliser ce modèle',
    'it': 'Usa questo modello',
    'ja': 'このモデルを使用',
    'ko': '이 모델 사용',
    'nl': 'Dit model gebruiken',
    'ru': 'Использовать эту модель',
  },
  'Details': {
    'zh-Hans': '详情',
    'zh-Hant': '詳情',
    'de': 'Details',
    'es': 'Detalles',
    'fr': 'Détails',
    'it': 'Dettagli',
    'ja': '詳細',
    'ko': '세부정보',
    'nl': 'Details',
    'ru': 'Подробнее',
  },
  'Engine Details': {
    'zh-Hans': '引擎详情',
    'zh-Hant': '引擎詳情',
    'de': 'Engine-Details',
    'es': 'Detalles del motor',
    'fr': 'Détails du moteur',
    'it': 'Dettagli motore',
    'ja': 'エンジン詳細',
    'ko': '엔진 세부정보',
    'nl': 'Enginegegevens',
    'ru': 'Сведения о движке',
  },
  'Save name': {
    'zh-Hans': '保存名称',
    'zh-Hant': '儲存名稱',
    'de': 'Namen speichern',
    'es': 'Guardar nombre',
    'fr': 'Enregistrer le nom',
    'it': 'Salva nome',
    'ja': '名前を保存',
    'ko': '이름 저장',
    'nl': 'Naam opslaan',
    'ru': 'Сохранить имя',
  },
  'Selected games': {
    'zh-Hans': '已选对局',
    'zh-Hant': '已選對局',
    'de': 'Ausgewählte Partien',
    'es': 'Partidas seleccionadas',
    'fr': 'Parties sélectionnées',
    'it': 'Partite selezionate',
    'ja': '選択した対局',
    'ko': '선택한 대국',
    'nl': 'Geselecteerde partijen',
    'ru': 'Выбранные партии',
  },
  'Choose one PGN source. Minimum 20 games, 50+ recommended.': {
    'zh-Hans': '选择一个 PGN 来源。最少 20 盘，建议 50 盘以上。',
    'zh-Hant': '選擇一個 PGN 來源。最少 20 盤，建議 50 盤以上。',
    'de': 'Wähle eine PGN-Quelle. Mindestens 20 Partien, 50+ empfohlen.',
    'es': 'Elige una fuente PGN. Mínimo 20 partidas, se recomiendan 50 o más.',
    'fr': 'Choisissez une source PGN. Minimum 20 parties, 50+ recommandé.',
    'it': 'Scegli una fonte PGN. Minimo 20 partite, consigliate 50+.',
    'ja': 'PGN ソースを1つ選択します。最少20局、50局以上推奨です。',
    'ko': 'PGN 소스 하나를 선택하세요. 최소 20개, 50개 이상 권장.',
    'nl': 'Kies één PGN-bron. Minimaal 20 partijen, 50+ aanbevolen.',
    'ru': 'Выберите один источник PGN. Минимум 20 партий, рекомендуется 50+.',
  },
  'Premium training is unlimited': {
    'zh-Hans': 'Premium 训练不限量',
    'zh-Hant': 'Premium 訓練不限量',
    'de': 'Premium-Training ist unbegrenzt',
    'es': 'El entrenamiento Premium es ilimitado',
    'fr': 'L’entraînement Premium est illimité',
    'it': 'L’allenamento Premium è illimitato',
    'ja': 'Premium トレーニングは無制限です',
    'ko': 'Premium 훈련은 무제한입니다',
    'nl': 'Premium-training is onbeperkt',
    'ru': 'Обучение Premium без ограничений',
  },
  'Use one clean source and keep games from the same player or style for better results.':
      {
    'zh-Hans': '使用一个干净来源，并尽量选择同一棋手或同一风格的对局，效果会更好。',
    'zh-Hant': '使用一個乾淨來源，並盡量選擇同一棋手或同一風格的對局，效果會更好。',
    'de':
        'Nutze eine saubere Quelle und Partien desselben Spielers oder Stils für bessere Ergebnisse.',
    'es':
        'Usa una fuente limpia y partidas del mismo jugador o estilo para mejores resultados.',
    'fr':
        'Utilisez une source propre et des parties du même joueur ou style pour de meilleurs résultats.',
    'it':
        'Usa una fonte pulita e partite dello stesso giocatore o stile per risultati migliori.',
    'ja': 'より良い結果のため、クリーンなソースを1つ使い、同じプレイヤーまたはスタイルの対局を選んでください。',
    'ko': '더 좋은 결과를 위해 깔끔한 소스 하나와 같은 플레이어 또는 스타일의 대국을 사용하세요.',
    'nl':
        'Gebruik één schone bron en partijen van dezelfde speler of stijl voor betere resultaten.',
    'ru':
        'Используйте один чистый источник и партии одного игрока или стиля для лучших результатов.',
  },
  'Notes': {
    'zh-Hans': '备注',
    'zh-Hant': '備註',
    'de': 'Notizen',
    'es': 'Notas',
    'fr': 'Notes',
    'it': 'Note',
    'ja': 'メモ',
    'ko': '메모',
    'nl': 'Notities',
    'ru': 'Заметки',
  },
  'Lichess Player': {
    'zh-Hans': 'Lichess 棋手',
    'zh-Hant': 'Lichess 棋手',
    'de': 'Lichess-Spieler',
    'es': 'Jugador de Lichess',
    'fr': 'Joueur Lichess',
    'it': 'Giocatore Lichess',
    'ja': 'Lichess プレイヤー',
    'ko': 'Lichess 플레이어',
    'nl': 'Lichess-speler',
    'ru': 'Игрок Lichess',
  },
  'Checking games': {
    'zh-Hans': '正在检查棋局',
    'zh-Hant': '正在檢查棋局',
    'de': 'Partien werden geprüft',
    'es': 'Comprobando partidas',
    'fr': 'Vérification des parties',
    'it': 'Controllo partite',
    'ja': '対局を確認中',
    'ko': '대국 확인 중',
    'nl': 'Partijen controleren',
    'ru': 'Проверка партий',
  },
  'Too many games selected': {
    'zh-Hans': '选择的对局太多',
    'zh-Hant': '選擇的對局太多',
    'de': 'Zu viele Partien ausgewählt',
    'es': 'Demasiadas partidas seleccionadas',
    'fr': 'Trop de parties sélectionnées',
    'it': 'Troppe partite selezionate',
    'ja': '選択した対局が多すぎます',
    'ko': '선택한 대국이 너무 많습니다',
    'nl': 'Te veel partijen geselecteerd',
    'ru': 'Выбрано слишком много партий',
  },
  'Select more games': {
    'zh-Hans': '选择更多对局',
    'zh-Hant': '選擇更多對局',
    'de': 'Mehr Partien auswählen',
    'es': 'Selecciona más partidas',
    'fr': 'Sélectionnez plus de parties',
    'it': 'Seleziona più partite',
    'ja': 'さらに対局を選択',
    'ko': '더 많은 대국 선택',
    'nl': 'Meer partijen selecteren',
    'ru': 'Выберите больше партий',
  },
  'Use selected': {
    'zh-Hans': '使用已选',
    'zh-Hant': '使用已選',
    'de': 'Auswahl verwenden',
    'es': 'Usar selección',
    'fr': 'Utiliser la sélection',
    'it': 'Usa selezionate',
    'ja': '選択を使用',
    'ko': '선택 항목 사용',
    'nl': 'Selectie gebruiken',
    'ru': 'Использовать выбранное',
  },
  'Preview found games': {
    'zh-Hans': '预览找到的棋局',
    'zh-Hant': '預覽找到的棋局',
    'de': 'Gefundene Partien ansehen',
    'es': 'Previsualizar partidas encontradas',
    'fr': 'Prévisualiser les parties trouvées',
    'it': 'Anteprima partite trovate',
    'ja': '見つかった対局をプレビュー',
    'ko': '찾은 대국 미리보기',
    'nl': 'Gevonden partijen bekijken',
    'ru': 'Предпросмотр найденных партий',
  },
  'No games loaded for this page.': {
    'zh-Hans': '此页没有加载到棋局。',
    'zh-Hant': '此頁沒有載入到棋局。',
    'de': 'Für diese Seite wurden keine Partien geladen.',
    'es': 'No se cargaron partidas para esta página.',
    'fr': 'Aucune partie chargée pour cette page.',
    'it': 'Nessuna partita caricata per questa pagina.',
    'ja': 'このページの対局は読み込まれていません。',
    'ko': '이 페이지에 불러온 대국이 없습니다.',
    'nl': 'Geen partijen geladen voor deze pagina.',
    'ru': 'Для этой страницы партии не загружены.',
  },
  'Select page': {
    'zh-Hans': '选择本页',
    'zh-Hant': '選擇本頁',
    'de': 'Seite auswählen',
    'es': 'Seleccionar página',
    'fr': 'Sélectionner la page',
    'it': 'Seleziona pagina',
    'ja': 'このページを選択',
    'ko': '페이지 선택',
    'nl': 'Pagina selecteren',
    'ru': 'Выбрать страницу',
  },
  'Clear page': {
    'zh-Hans': '清除本页',
    'zh-Hant': '清除本頁',
    'de': 'Seite leeren',
    'es': 'Limpiar página',
    'fr': 'Effacer la page',
    'it': 'Deseleziona pagina',
    'ja': 'このページを解除',
    'ko': '페이지 선택 해제',
    'nl': 'Pagina wissen',
    'ru': 'Очистить страницу',
  },
  'Keep first 200': {
    'zh-Hans': '保留前 200 盘',
    'zh-Hant': '保留前 200 盤',
    'de': 'Erste 200 behalten',
    'es': 'Conservar primeras 200',
    'fr': 'Garder les 200 premières',
    'it': 'Tieni le prime 200',
    'ja': '先頭200局を保持',
    'ko': '처음 200개 유지',
    'nl': 'Eerste 200 behouden',
    'ru': 'Оставить первые 200',
  },
  'Import by Lichess player id': {
    'zh-Hans': '按 Lichess 棋手 ID 导入',
    'zh-Hant': '按 Lichess 棋手 ID 匯入',
    'de': 'Nach Lichess-Spieler-ID importieren',
    'es': 'Importar por ID de jugador Lichess',
    'fr': 'Importer par ID joueur Lichess',
    'it': 'Importa per ID giocatore Lichess',
    'ja': 'Lichess プレイヤー ID でインポート',
    'ko': 'Lichess 플레이어 ID로 가져오기',
    'nl': 'Importeren op Lichess-speler-ID',
    'ru': 'Импорт по ID игрока Lichess',
  },
  'Lichess player id': {
    'zh-Hans': 'Lichess 棋手 ID',
    'zh-Hant': 'Lichess 棋手 ID',
    'de': 'Lichess-Spieler-ID',
    'es': 'ID de jugador Lichess',
    'fr': 'ID joueur Lichess',
    'it': 'ID giocatore Lichess',
    'ja': 'Lichess プレイヤー ID',
    'ko': 'Lichess 플레이어 ID',
    'nl': 'Lichess-speler-ID',
    'ru': 'ID игрока Lichess',
  },
  'Any speed': {
    'zh-Hans': '任意速度',
    'zh-Hant': '任意速度',
    'de': 'Beliebige Geschwindigkeit',
    'es': 'Cualquier ritmo',
    'fr': 'Toute cadence',
    'it': 'Qualsiasi cadenza',
    'ja': '任意の速度',
    'ko': '모든 속도',
    'nl': 'Elke snelheid',
    'ru': 'Любой темп',
  },
  'Optional date or text': {
    'zh-Hans': '可选日期或文本',
    'zh-Hant': '可選日期或文字',
    'de': 'Optionales Datum oder Text',
    'es': 'Fecha o texto opcional',
    'fr': 'Date ou texte facultatif',
    'it': 'Data o testo opzionale',
    'ja': '任意の日付またはテキスト',
    'ko': '선택 날짜 또는 텍스트',
    'nl': 'Optionele datum of tekst',
    'ru': 'Необязательная дата или текст',
  },
  'Preview games': {
    'zh-Hans': '预览棋局',
    'zh-Hant': '預覽棋局',
    'de': 'Partien ansehen',
    'es': 'Previsualizar partidas',
    'fr': 'Prévisualiser les parties',
    'it': 'Anteprima partite',
    'ja': '対局をプレビュー',
    'ko': '대국 미리보기',
    'nl': 'Partijen bekijken',
    'ru': 'Предпросмотр партий',
  },
  'Desktop can select one multi-game PGN or multiple single-game PGNs. The app merges them before upload.':
      {
    'zh-Hans': '桌面端可以选择一个多局 PGN，或多个单局 PGN。App 会在上传前合并它们。',
    'zh-Hant': '桌面端可以選擇一個多局 PGN，或多個單局 PGN。App 會在上傳前合併它們。',
    'de':
        'Auf dem Desktop kannst du eine PGN mit mehreren Partien oder mehrere Einzel-PGNs wählen. Die App fügt sie vor dem Upload zusammen.',
    'es':
        'En escritorio puedes seleccionar un PGN con varias partidas o varios PGN de una partida. La app los fusiona antes de subirlos.',
    'fr':
        'Sur ordinateur, vous pouvez choisir un PGN multi-parties ou plusieurs PGN d’une seule partie. L’app les fusionne avant l’envoi.',
    'it':
        'Su desktop puoi selezionare un PGN multi-partita o più PGN singoli. L’app li unisce prima del caricamento.',
    'ja': 'デスクトップでは複数対局入り PGN 1つ、または単一対局 PGN 複数を選べます。アップロード前にアプリが結合します。',
    'ko':
        '데스크톱에서는 여러 대국 PGN 하나 또는 단일 대국 PGN 여러 개를 선택할 수 있습니다. 앱이 업로드 전에 병합합니다.',
    'nl':
        'Op desktop kun je één PGN met meerdere partijen of meerdere losse PGN’s kiezen. De app voegt ze samen vóór upload.',
    'ru':
        'На desktop можно выбрать один PGN с несколькими партиями или несколько PGN по одной партии. Приложение объединит их перед загрузкой.',
  },
  'Reading files': {
    'zh-Hans': '正在读取文件',
    'zh-Hant': '正在讀取檔案',
    'de': 'Dateien werden gelesen',
    'es': 'Leyendo archivos',
    'fr': 'Lecture des fichiers',
    'it': 'Lettura file',
    'ja': 'ファイルを読み込み中',
    'ko': '파일 읽는 중',
    'nl': 'Bestanden lezen',
    'ru': 'Чтение файлов',
  },
  'Selected PGN files': {
    'zh-Hans': '已选择 PGN 文件',
    'zh-Hant': '已選擇 PGN 檔案',
    'de': 'Ausgewählte PGN-Dateien',
    'es': 'Archivos PGN seleccionados',
    'fr': 'Fichiers PGN sélectionnés',
    'it': 'File PGN selezionati',
    'ja': '選択した PGN ファイル',
    'ko': '선택한 PGN 파일',
    'nl': 'Geselecteerde PGN-bestanden',
    'ru': 'Выбранные PGN-файлы',
  },
  'Games were found, but no sample PGN preview was returned.': {
    'zh-Hans': '已找到棋局，但没有返回示例 PGN 预览。',
    'zh-Hant': '已找到棋局，但沒有回傳範例 PGN 預覽。',
    'de':
        'Partien wurden gefunden, aber keine Beispiel-PGN-Vorschau zurückgegeben.',
    'es':
        'Se encontraron partidas, pero no se devolvió una vista previa PGN de muestra.',
    'fr':
        'Des parties ont été trouvées, mais aucun aperçu PGN d’exemple n’a été renvoyé.',
    'it':
        'Sono state trovate partite, ma non è stata restituita alcuna anteprima PGN.',
    'ja': '対局は見つかりましたが、サンプル PGN プレビューは返されませんでした。',
    'ko': '대국을 찾았지만 샘플 PGN 미리보기가 반환되지 않았습니다.',
    'nl':
        'Er zijn partijen gevonden, maar er is geen PGN-voorbeeld teruggekomen.',
    'ru': 'Партии найдены, но пример предпросмотра PGN не получен.',
  },
  'PGN file import is available on desktop.': {
    'zh-Hans': 'PGN 文件导入仅在桌面端可用。',
    'zh-Hant': 'PGN 檔案匯入僅在桌面端可用。',
    'de': 'PGN-Dateiimport ist auf dem Desktop verfügbar.',
    'es': 'La importación de archivos PGN está disponible en escritorio.',
    'fr': 'L’import de fichiers PGN est disponible sur ordinateur.',
    'it': 'L’importazione di file PGN è disponibile su desktop.',
    'ja': 'PGN ファイルのインポートはデスクトップで利用できます。',
    'ko': 'PGN 파일 가져오기는 데스크톱에서 사용할 수 있습니다.',
    'nl': 'PGN-bestanden importeren is beschikbaar op desktop.',
    'ru': 'Импорт файлов PGN доступен на desktop.',
  },
  'Import PGN files before starting training.': {
    'zh-Hans': '开始训练前请先导入 PGN 文件。',
    'zh-Hant': '開始訓練前請先匯入 PGN 檔案。',
    'de': 'Importiere PGN-Dateien, bevor du das Training startest.',
    'es': 'Importa archivos PGN antes de iniciar el entrenamiento.',
    'fr': 'Importez des fichiers PGN avant de lancer l’entraînement.',
    'it': 'Importa file PGN prima di avviare l’allenamento.',
    'ja': 'トレーニング開始前に PGN ファイルをインポートしてください。',
    'ko': '훈련을 시작하기 전에 PGN 파일을 가져오세요.',
    'nl': 'Importeer PGN-bestanden voordat je de training start.',
    'ru': 'Импортируйте PGN-файлы перед началом обучения.',
  },
  'Game Record search is unavailable.': {
    'zh-Hans': 'Game Record 搜索不可用。',
    'zh-Hant': 'Game Record 搜尋不可用。',
    'de': 'Game Record-Suche ist nicht verfügbar.',
    'es': 'La búsqueda de Game Record no está disponible.',
    'fr': 'La recherche Game Record est indisponible.',
    'it': 'La ricerca Game Record non è disponibile.',
    'ja': 'Game Record 検索を利用できません。',
    'ko': 'Game Record 검색을 사용할 수 없습니다.',
    'nl': 'Game Record-zoekfunctie is niet beschikbaar.',
    'ru': 'Поиск Game Record недоступен.',
  },
  'Selected games do not include usable PGN text.': {
    'zh-Hans': '所选棋局不包含可用的 PGN 文本。',
    'zh-Hant': '所選棋局不包含可用的 PGN 文字。',
    'de': 'Die ausgewählten Partien enthalten keinen nutzbaren PGN-Text.',
    'es': 'Las partidas seleccionadas no incluyen texto PGN utilizable.',
    'fr':
        'Les parties sélectionnées ne contiennent pas de texte PGN exploitable.',
    'it': 'Le partite selezionate non includono testo PGN utilizzabile.',
    'ja': '選択した対局には使用可能な PGN テキストが含まれていません。',
    'ko': '선택한 대국에 사용 가능한 PGN 텍스트가 없습니다.',
    'nl': 'De geselecteerde partijen bevatten geen bruikbare PGN-tekst.',
    'ru': 'Выбранные партии не содержат пригодный текст PGN.',
  },
  'Unable to load selected Game Record PGNs.': {
    'zh-Hans': '无法加载所选 Game Record 的 PGN。',
    'zh-Hant': '無法載入所選 Game Record 的 PGN。',
    'de': 'Ausgewählte Game Record-PGNs konnten nicht geladen werden.',
    'es': 'No se pudieron cargar los PGN de Game Record seleccionados.',
    'fr': 'Impossible de charger les PGN Game Record sélectionnés.',
    'it': 'Impossibile caricare i PGN Game Record selezionati.',
    'ja': '選択した Game Record PGN を読み込めません。',
    'ko': '선택한 Game Record PGN을 불러올 수 없습니다.',
    'nl': 'Kan geselecteerde Game Record-PGN’s niet laden.',
    'ru': 'Не удалось загрузить выбранные PGN из Game Record.',
  },
  'Unable to load games for this page.': {
    'zh-Hans': '无法加载此页棋局。',
    'zh-Hant': '無法載入此頁棋局。',
    'de': 'Partien für diese Seite konnten nicht geladen werden.',
    'es': 'No se pudieron cargar las partidas de esta página.',
    'fr': 'Impossible de charger les parties de cette page.',
    'it': 'Impossibile caricare le partite di questa pagina.',
    'ja': 'このページの対局を読み込めません。',
    'ko': '이 페이지의 대국을 불러올 수 없습니다.',
    'nl': 'Kan partijen voor deze pagina niet laden.',
    'ru': 'Не удалось загрузить партии этой страницы.',
  },
  'My personal engine': {
    'zh-Hans': '我的个人引擎',
    'zh-Hant': '我的個人引擎',
    'de': 'Meine persönliche Engine',
    'es': 'Mi motor personal',
    'fr': 'Mon moteur personnel',
    'it': 'Il mio motore personale',
    'ja': '自分の個人エンジン',
    'ko': '내 개인 엔진',
    'nl': 'Mijn persoonlijke engine',
    'ru': 'Мой личный движок',
  },
  'This engine cannot be liked yet.': {
    'zh-Hans': '这个引擎暂时不能点赞。',
    'zh-Hant': '這個引擎暫時不能按讚。',
    'de': 'Diese Engine kann noch nicht geliked werden.',
    'es': 'Todavía no se puede dar me gusta a este motor.',
    'fr': 'Ce moteur ne peut pas encore être aimé.',
    'it': 'Non puoi ancora mettere Mi piace a questo motore.',
    'ja': 'このエンジンにはまだいいねできません。',
    'ko': '아직 이 엔진에 좋아요를 누를 수 없습니다.',
    'nl': 'Deze engine kan nog niet worden geliket.',
    'ru': 'Этот движок пока нельзя лайкнуть.',
  },
  'Unable to update like. Try again later.': {
    'zh-Hans': '无法更新点赞，请稍后重试。',
    'zh-Hant': '無法更新按讚，請稍後再試。',
    'de': 'Like konnte nicht aktualisiert werden. Versuche es später erneut.',
    'es': 'No se pudo actualizar el me gusta. Inténtalo más tarde.',
    'fr': 'Impossible de mettre à jour le j’aime. Réessayez plus tard.',
    'it': 'Impossibile aggiornare il Mi piace. Riprova più tardi.',
    'ja': 'いいねを更新できません。後でもう一度お試しください。',
    'ko': '좋아요를 업데이트할 수 없습니다. 나중에 다시 시도하세요.',
    'nl': 'Kan de like niet bijwerken. Probeer het later opnieuw.',
    'ru': 'Не удалось обновить лайк. Повторите попытку позже.',
  },
  'Engine enabled for Bot game.': {
    'zh-Hans': '引擎已启用于 Bot game。',
    'zh-Hant': '引擎已啟用於 Bot game。',
    'de': 'Engine für Bot game aktiviert.',
    'es': 'Motor activado para Bot game.',
    'fr': 'Moteur activé pour Bot game.',
    'it': 'Motore abilitato per Bot game.',
    'ja': 'エンジンを Bot game で有効にしました。',
    'ko': '엔진이 Bot game에 활성화되었습니다.',
    'nl': 'Engine ingeschakeld voor Bot game.',
    'ru': 'Движок включён для Bot game.',
  },
  'Engine disabled.': {
    'zh-Hans': '引擎已停用。',
    'zh-Hant': '引擎已停用。',
    'de': 'Engine deaktiviert.',
    'es': 'Motor desactivado.',
    'fr': 'Moteur désactivé.',
    'it': 'Motore disabilitato.',
    'ja': 'エンジンを無効にしました。',
    'ko': '엔진이 비활성화되었습니다.',
    'nl': 'Engine uitgeschakeld.',
    'ru': 'Движок отключён.',
  },
  'Unable to update this engine. Try again later.': {
    'zh-Hans': '无法更新这个引擎，请稍后重试。',
    'zh-Hant': '無法更新這個引擎，請稍後再試。',
    'de':
        'Diese Engine konnte nicht aktualisiert werden. Versuche es später erneut.',
    'es': 'No se pudo actualizar este motor. Inténtalo más tarde.',
    'fr': 'Impossible de mettre à jour ce moteur. Réessayez plus tard.',
    'it': 'Impossibile aggiornare questo motore. Riprova più tardi.',
    'ja': 'このエンジンを更新できません。後でもう一度お試しください。',
    'ko': '이 엔진을 업데이트할 수 없습니다. 나중에 다시 시도하세요.',
    'nl': 'Kan deze engine niet bijwerken. Probeer het later opnieuw.',
    'ru': 'Не удалось обновить этот движок. Повторите попытку позже.',
  },
  'This LC0 engine is not ready to download yet.': {
    'zh-Hans': '这个 LC0 引擎暂时还不能下载。',
    'zh-Hant': '這個 LC0 引擎暫時還不能下載。',
    'de': 'Diese LC0-Engine ist noch nicht zum Download bereit.',
    'es': 'Este motor LC0 aún no está listo para descargar.',
    'fr': 'Ce moteur LC0 n’est pas encore prêt à être téléchargé.',
    'it': 'Questo motore LC0 non è ancora pronto per il download.',
    'ja': 'この LC0 エンジンはまだダウンロードできません。',
    'ko': '이 LC0 엔진은 아직 다운로드할 준비가 되지 않았습니다.',
    'nl': 'Deze LC0-engine is nog niet klaar om te downloaden.',
    'ru': 'Этот движок LC0 ещё не готов к загрузке.',
  },
  'Unable to download this LC0 engine. Check your connection and try again.': {
    'zh-Hans': '无法下载这个 LC0 引擎。请检查网络后重试。',
    'zh-Hant': '無法下載這個 LC0 引擎。請檢查網路後再試。',
    'de':
        'Diese LC0-Engine konnte nicht heruntergeladen werden. Prüfe deine Verbindung und versuche es erneut.',
    'es':
        'No se pudo descargar este motor LC0. Revisa tu conexión e inténtalo de nuevo.',
    'fr':
        'Impossible de télécharger ce moteur LC0. Vérifiez votre connexion puis réessayez.',
    'it':
        'Impossibile scaricare questo motore LC0. Controlla la connessione e riprova.',
    'ja': 'この LC0 エンジンをダウンロードできません。接続を確認してもう一度お試しください。',
    'ko': '이 LC0 엔진을 다운로드할 수 없습니다. 연결을 확인하고 다시 시도하세요.',
    'nl':
        'Kan deze LC0-engine niet downloaden. Controleer je verbinding en probeer opnieuw.',
    'ru':
        'Не удалось скачать этот движок LC0. Проверьте соединение и повторите попытку.',
  },
  'This personal engine is still training.': {
    'zh-Hans': '这个个人引擎仍在训练中。',
    'zh-Hant': '這個個人引擎仍在訓練中。',
    'de': 'Diese persönliche Engine wird noch trainiert.',
    'es': 'Este motor personal aún se está entrenando.',
    'fr': 'Ce moteur personnel est encore en entraînement.',
    'it': 'Questo motore personale è ancora in allenamento.',
    'ja': 'この個人エンジンはまだトレーニング中です。',
    'ko': '이 개인 엔진은 아직 훈련 중입니다.',
    'nl': 'Deze persoonlijke engine wordt nog getraind.',
    'ru': 'Этот личный движок ещё обучается.',
  },
  'This personal engine does not have a weight file yet.': {
    'zh-Hans': '这个个人引擎还没有权重文件。',
    'zh-Hant': '這個個人引擎還沒有權重檔。',
    'de': 'Diese persönliche Engine hat noch keine Gewichtdatei.',
    'es': 'Este motor personal aún no tiene archivo de pesos.',
    'fr': 'Ce moteur personnel n’a pas encore de fichier de poids.',
    'it': 'Questo motore personale non ha ancora un file pesi.',
    'ja': 'この個人エンジンにはまだ重みファイルがありません。',
    'ko': '이 개인 엔진에는 아직 가중치 파일이 없습니다.',
    'nl': 'Deze persoonlijke engine heeft nog geen gewichtbestand.',
    'ru': 'У этого личного движка ещё нет файла весов.',
  },
  'Unable to download this personal engine. Check your connection and try again.':
      {
    'zh-Hans': '无法下载这个个人引擎。请检查网络后重试。',
    'zh-Hant': '無法下載這個個人引擎。請檢查網路後再試。',
    'de':
        'Diese persönliche Engine konnte nicht heruntergeladen werden. Prüfe deine Verbindung und versuche es erneut.',
    'es':
        'No se pudo descargar este motor personal. Revisa tu conexión e inténtalo de nuevo.',
    'fr':
        'Impossible de télécharger ce moteur personnel. Vérifiez votre connexion puis réessayez.',
    'it':
        'Impossibile scaricare questo motore personale. Controlla la connessione e riprova.',
    'ja': 'この個人エンジンをダウンロードできません。接続を確認してもう一度お試しください。',
    'ko': '이 개인 엔진을 다운로드할 수 없습니다. 연결을 확인하고 다시 시도하세요.',
    'nl':
        'Kan deze persoonlijke engine niet downloaden. Controleer je verbinding en probeer opnieuw.',
    'ru':
        'Не удалось скачать этот личный движок. Проверьте соединение и повторите попытку.',
  },
  'Unable to update this personal engine. Check your connection and try again.':
      {
    'zh-Hans': '无法更新这个个人引擎。请检查网络后重试。',
    'zh-Hant': '無法更新這個個人引擎。請檢查網路後再試。',
    'de':
        'Diese persönliche Engine konnte nicht aktualisiert werden. Prüfe deine Verbindung und versuche es erneut.',
    'es':
        'No se pudo actualizar este motor personal. Revisa tu conexión e inténtalo de nuevo.',
    'fr':
        'Impossible de mettre à jour ce moteur personnel. Vérifiez votre connexion puis réessayez.',
    'it':
        'Impossibile aggiornare questo motore personale. Controlla la connessione e riprova.',
    'ja': 'この個人エンジンを更新できません。接続を確認してもう一度お試しください。',
    'ko': '이 개인 엔진을 업데이트할 수 없습니다. 연결을 확인하고 다시 시도하세요.',
    'nl':
        'Kan deze persoonlijke engine niet bijwerken. Controleer je verbinding en probeer opnieuw.',
    'ru':
        'Не удалось обновить этот личный движок. Проверьте соединение и повторите попытку.',
  },
  'Personal engine deleted.': {
    'zh-Hans': '个人引擎已删除。',
    'zh-Hant': '個人引擎已刪除。',
    'de': 'Persönliche Engine gelöscht.',
    'es': 'Motor personal eliminado.',
    'fr': 'Moteur personnel supprimé.',
    'it': 'Motore personale eliminato.',
    'ja': '個人エンジンを削除しました。',
    'ko': '개인 엔진이 삭제되었습니다.',
    'nl': 'Persoonlijke engine verwijderd.',
    'ru': 'Личный движок удалён.',
  },
  'Unable to delete this personal engine. Try again later.': {
    'zh-Hans': '无法删除这个个人引擎，请稍后重试。',
    'zh-Hant': '無法刪除這個個人引擎，請稍後再試。',
    'de':
        'Diese persönliche Engine konnte nicht gelöscht werden. Versuche es später erneut.',
    'es': 'No se pudo eliminar este motor personal. Inténtalo más tarde.',
    'fr': 'Impossible de supprimer ce moteur personnel. Réessayez plus tard.',
    'it': 'Impossibile eliminare questo motore personale. Riprova più tardi.',
    'ja': 'この個人エンジンを削除できません。後でもう一度お試しください。',
    'ko': '이 개인 엔진을 삭제할 수 없습니다. 나중에 다시 시도하세요.',
    'nl':
        'Kan deze persoonlijke engine niet verwijderen. Probeer het later opnieuw.',
    'ru': 'Не удалось удалить этот личный движок. Повторите попытку позже.',
  },
  'Enter an engine name before saving.': {
    'zh-Hans': '保存前请输入引擎名称。',
    'zh-Hant': '儲存前請輸入引擎名稱。',
    'de': 'Gib vor dem Speichern einen Engine-Namen ein.',
    'es': 'Introduce un nombre de motor antes de guardar.',
    'fr': 'Saisissez un nom de moteur avant d’enregistrer.',
    'it': 'Inserisci un nome motore prima di salvare.',
    'ja': '保存する前にエンジン名を入力してください。',
    'ko': '저장하기 전에 엔진 이름을 입력하세요.',
    'nl': 'Voer een enginenaam in voordat je opslaat.',
    'ru': 'Введите название движка перед сохранением.',
  },
  'This personal engine cannot be renamed yet.': {
    'zh-Hans': '这个个人引擎暂时不能重命名。',
    'zh-Hant': '這個個人引擎暫時不能重新命名。',
    'de': 'Diese persönliche Engine kann noch nicht umbenannt werden.',
    'es': 'Este motor personal aún no se puede renombrar.',
    'fr': 'Ce moteur personnel ne peut pas encore être renommé.',
    'it': 'Questo motore personale non può ancora essere rinominato.',
    'ja': 'この個人エンジンはまだ名前を変更できません。',
    'ko': '이 개인 엔진은 아직 이름을 바꿀 수 없습니다.',
    'nl': 'Deze persoonlijke engine kan nog niet worden hernoemd.',
    'ru': 'Этот личный движок пока нельзя переименовать.',
  },
  'Engine name updated.': {
    'zh-Hans': '引擎名称已更新。',
    'zh-Hant': '引擎名稱已更新。',
    'de': 'Engine-Name aktualisiert.',
    'es': 'Nombre del motor actualizado.',
    'fr': 'Nom du moteur mis à jour.',
    'it': 'Nome motore aggiornato.',
    'ja': 'エンジン名を更新しました。',
    'ko': '엔진 이름이 업데이트되었습니다.',
    'nl': 'Enginenaam bijgewerkt.',
    'ru': 'Название движка обновлено.',
  },
  'Unable to update this engine name. Try again later.': {
    'zh-Hans': '无法更新这个引擎名称，请稍后重试。',
    'zh-Hant': '無法更新這個引擎名稱，請稍後再試。',
    'de':
        'Dieser Engine-Name konnte nicht aktualisiert werden. Versuche es später erneut.',
    'es': 'No se pudo actualizar este nombre de motor. Inténtalo más tarde.',
    'fr': 'Impossible de mettre à jour ce nom de moteur. Réessayez plus tard.',
    'it': 'Impossibile aggiornare questo nome motore. Riprova più tardi.',
    'ja': 'このエンジン名を更新できません。後でもう一度お試しください。',
    'ko': '이 엔진 이름을 업데이트할 수 없습니다. 나중에 다시 시도하세요.',
    'nl': 'Kan deze enginenaam niet bijwerken. Probeer het later opnieuw.',
    'ru': 'Не удалось обновить название движка. Повторите попытку позже.',
  },
  'Add an engine name before starting training.': {
    'zh-Hans': '开始训练前请先填写引擎名称。',
    'zh-Hant': '開始訓練前請先填寫引擎名稱。',
    'de': 'Gib vor dem Trainingsstart einen Engine-Namen ein.',
    'es': 'Añade un nombre de motor antes de iniciar el entrenamiento.',
    'fr': 'Ajoutez un nom de moteur avant de lancer l’entraînement.',
    'it': 'Aggiungi un nome motore prima di avviare l’allenamento.',
    'ja': 'トレーニング開始前にエンジン名を入力してください。',
    'ko': '훈련을 시작하기 전에 엔진 이름을 추가하세요.',
    'nl': 'Voeg een enginenaam toe voordat je de training start.',
    'ru': 'Перед запуском обучения добавьте название движка.',
  },
  'No usable PGN games matched these filters.': {
    'zh-Hans': '没有可用的 PGN 对局匹配这些筛选。',
    'zh-Hant': '沒有可用的 PGN 對局符合這些篩選。',
    'de': 'Keine nutzbaren PGN-Partien passen zu diesen Filtern.',
    'es': 'Ninguna partida PGN utilizable coincide con estos filtros.',
    'fr': 'Aucune partie PGN exploitable ne correspond à ces filtres.',
    'it': 'Nessuna partita PGN utilizzabile corrisponde a questi filtri.',
    'ja': 'これらのフィルターに一致する使用可能な PGN 対局はありません。',
    'ko': '이 필터와 일치하는 사용 가능한 PGN 대국이 없습니다.',
    'nl': 'Geen bruikbare PGN-partijen passen bij deze filters.',
    'ru': 'Нет пригодных PGN-партий по этим фильтрам.',
  },
  'Unable to load the matched Game Record preview.': {
    'zh-Hans': '无法加载匹配的 Game Record 预览。',
    'zh-Hant': '無法載入符合的 Game Record 預覽。',
    'de':
        'Die Vorschau der passenden Game Record-Partien konnte nicht geladen werden.',
    'es': 'No se pudo cargar la vista previa de Game Record coincidente.',
    'fr': 'Impossible de charger l’aperçu Game Record correspondant.',
    'it': 'Impossibile caricare l’anteprima Game Record corrispondente.',
    'ja': '一致した Game Record プレビューを読み込めません。',
    'ko': '일치하는 Game Record 미리보기를 불러올 수 없습니다.',
    'nl': 'Kan de gevonden Game Record-preview niet laden.',
    'ru': 'Не удалось загрузить превью подходящих записей Game Record.',
  },
  'Submitting selected games for personal engine training...': {
    'zh-Hans': '正在提交已选对局用于个人引擎训练...',
    'zh-Hant': '正在提交已選對局用於個人引擎訓練...',
    'de':
        'Ausgewählte Partien werden für das Training der persönlichen Engine gesendet...',
    'es': 'Enviando partidas seleccionadas para entrenar el motor personal...',
    'fr':
        'Envoi des parties sélectionnées pour l’entraînement du moteur personnel...',
    'it':
        'Invio delle partite selezionate per l’allenamento del motore personale...',
    'ja': '選択した対局を個人エンジンのトレーニングに送信中...',
    'ko': '선택한 대국을 개인 엔진 훈련용으로 제출하는 중...',
    'nl':
        'Geselecteerde partijen indienen voor training van de persoonlijke engine...',
    'ru': 'Отправка выбранных партий для обучения личного движка...',
  },
  'Import or preview games before starting training.': {
    'zh-Hans': '开始训练前请先导入或预览棋局。',
    'zh-Hant': '開始訓練前請先匯入或預覽棋局。',
    'de': 'Importiere oder prüfe Partien, bevor du das Training startest.',
    'es': 'Importa o previsualiza partidas antes de iniciar el entrenamiento.',
    'fr':
        'Importez ou prévisualisez des parties avant de lancer l’entraînement.',
    'it': 'Importa o visualizza le partite prima di avviare l’allenamento.',
    'ja': 'トレーニング開始前に対局をインポートまたはプレビューしてください。',
    'ko': '훈련을 시작하기 전에 대국을 가져오거나 미리 보세요.',
    'nl': 'Importeer of bekijk partijen voordat je de training start.',
    'ru': 'Перед обучением импортируйте или просмотрите партии.',
  },
  'Downloaded personal engine': {
    'zh-Hans': '已下载的个人引擎',
    'zh-Hant': '已下載的個人引擎',
    'de': 'Heruntergeladene persönliche Engine',
    'es': 'Motor personal descargado',
    'fr': 'Moteur personnel téléchargé',
    'it': 'Motore personale scaricato',
    'ja': 'ダウンロード済み個人エンジン',
    'ko': '다운로드한 개인 엔진',
    'nl': 'Gedownloade persoonlijke engine',
    'ru': 'Загруженный личный движок',
  },
  'This personal engine is downloaded locally and ready for Bot game.': {
    'zh-Hans': '这个个人引擎已下载到本地，可用于 Bot game。',
    'zh-Hant': '這個個人引擎已下載到本機，可用於 Bot game。',
    'de':
        'Diese persönliche Engine ist lokal heruntergeladen und bereit für Bot game.',
    'es':
        'Este motor personal está descargado localmente y listo para Bot game.',
    'fr':
        'Ce moteur personnel est téléchargé localement et prêt pour Bot game.',
    'it':
        'Questo motore personale è scaricato in locale e pronto per Bot game.',
    'ja': 'この個人エンジンはローカルにダウンロード済みで、Bot game で使えます。',
    'ko': '이 개인 엔진은 로컬에 다운로드되어 Bot game에서 사용할 수 있습니다.',
    'nl':
        'Deze persoonlijke engine is lokaal gedownload en klaar voor Bot game.',
    'ru': 'Этот личный движок загружен локально и готов для Bot game.',
  },
  'Local engine library': {
    'zh-Hans': '本地引擎库',
    'zh-Hant': '本機引擎庫',
    'de': 'Lokale Engine-Bibliothek',
    'es': 'Biblioteca local de motores',
    'fr': 'Bibliothèque locale de moteurs',
    'it': 'Libreria motori locale',
    'ja': 'ローカルエンジンライブラリ',
    'ko': '로컬 엔진 라이브러리',
    'nl': 'Lokale enginebibliotheek',
    'ru': 'Локальная библиотека движков',
  },
  'Local download': {
    'zh-Hans': '本地下载',
    'zh-Hant': '本機下載',
    'de': 'Lokaler Download',
    'es': 'Descarga local',
    'fr': 'Téléchargement local',
    'it': 'Download locale',
    'ja': 'ローカルダウンロード',
    'ko': '로컬 다운로드',
    'nl': 'Lokale download',
    'ru': 'Локальная загрузка',
  },
  'Imported training games': {
    'zh-Hans': '已导入的训练对局',
    'zh-Hant': '已匯入的訓練對局',
    'de': 'Importierte Trainingspartien',
    'es': 'Partidas de entrenamiento importadas',
    'fr': 'Parties d’entraînement importées',
    'it': 'Partite di allenamento importate',
    'ja': 'インポートしたトレーニング対局',
    'ko': '가져온 훈련 대국',
    'nl': 'Geïmporteerde trainingspartijen',
    'ru': 'Импортированные учебные партии',
  },
  'Lichess games': {
    'zh-Hans': 'Lichess 对局',
    'zh-Hant': 'Lichess 對局',
    'de': 'Lichess-Partien',
    'es': 'Partidas de Lichess',
    'fr': 'Parties Lichess',
    'it': 'Partite Lichess',
    'ja': 'Lichess 対局',
    'ko': 'Lichess 대국',
    'nl': 'Lichess-partijen',
    'ru': 'Партии Lichess',
  },
  'Chessnut game records': {
    'zh-Hans': 'Chessnut 对局记录',
    'zh-Hant': 'Chessnut 對局記錄',
    'de': 'Chessnut-Partieaufzeichnungen',
    'es': 'Registros de partidas Chessnut',
    'fr': 'Archives de parties Chessnut',
    'it': 'Registri partite Chessnut',
    'ja': 'Chessnut 対局記録',
    'ko': 'Chessnut 대국 기록',
    'nl': 'Chessnut-partijrecords',
    'ru': 'Записи партий Chessnut',
  },
  'Imported PGN batch': {
    'zh-Hans': '已导入的 PGN 批次',
    'zh-Hant': '已匯入的 PGN 批次',
    'de': 'Importierter PGN-Batch',
    'es': 'Lote PGN importado',
    'fr': 'Lot PGN importé',
    'it': 'Batch PGN importato',
    'ja': 'インポートした PGN バッチ',
    'ko': '가져온 PGN 배치',
    'nl': 'Geïmporteerde PGN-batch',
    'ru': 'Импортированный пакет PGN',
  },
  'Chessnut training games': {
    'zh-Hans': 'Chessnut 训练对局',
    'zh-Hant': 'Chessnut 訓練對局',
    'de': 'Chessnut-Trainingspartien',
    'es': 'Partidas de entrenamiento Chessnut',
    'fr': 'Parties d’entraînement Chessnut',
    'it': 'Partite di allenamento Chessnut',
    'ja': 'Chessnut トレーニング対局',
    'ko': 'Chessnut 훈련 대국',
    'nl': 'Chessnut-trainingspartijen',
    'ru': 'Учебные партии Chessnut',
  },
  'Ready for Bot game': {
    'zh-Hans': '已可用于 Bot game',
    'zh-Hant': '已可用於 Bot game',
    'de': 'Bereit für Bot game',
    'es': 'Listo para Bot game',
    'fr': 'Prêt pour Bot game',
    'it': 'Pronto per Bot game',
    'ja': 'Bot game で使用可能',
    'ko': 'Bot game에서 사용 가능',
    'nl': 'Klaar voor Bot game',
    'ru': 'Готов для Bot game',
  },
  'Training in cloud': {
    'zh-Hans': '云端训练中',
    'zh-Hant': '雲端訓練中',
    'de': 'Training in der Cloud',
    'es': 'Entrenando en la nube',
    'fr': 'Entraînement dans le cloud',
    'it': 'Allenamento nel cloud',
    'ja': 'クラウドでトレーニング中',
    'ko': '클라우드에서 훈련 중',
    'nl': 'Training in de cloud',
    'ru': 'Обучение в облаке',
  },
  'Waiting for training': {
    'zh-Hans': '等待训练',
    'zh-Hant': '等待訓練',
    'de': 'Wartet auf Training',
    'es': 'Esperando entrenamiento',
    'fr': 'En attente d’entraînement',
    'it': 'In attesa di allenamento',
    'ja': 'トレーニング待ち',
    'ko': '훈련 대기 중',
    'nl': 'Wacht op training',
    'ru': 'Ожидает обучения',
  },
  'Personal style': {
    'zh-Hans': '个人风格',
    'zh-Hant': '個人風格',
    'de': 'Persönlicher Stil',
    'es': 'Estilo personal',
    'fr': 'Style personnel',
    'it': 'Stile personale',
    'ja': '個人スタイル',
    'ko': '개인 스타일',
    'nl': 'Persoonlijke stijl',
    'ru': 'Личный стиль',
  },
  'Popular LC0 community weight selected and packaged by Chessnut for Bot game play.':
      {
    'zh-Hans': 'Chessnut 为 Bot game 精选并打包的热门 LC0 社区权重。',
    'zh-Hant': 'Chessnut 為 Bot game 精選並打包的熱門 LC0 社群權重。',
    'de':
        'Beliebtes LC0-Community-Gewicht, von Chessnut für Bot game ausgewählt und gepackt.',
    'es':
        'Peso LC0 popular de la comunidad, seleccionado y empaquetado por Chessnut para Bot game.',
    'fr':
        'Poids LC0 communautaire populaire, sélectionné et empaqueté par Chessnut pour Bot game.',
    'it':
        'Peso LC0 community popolare, selezionato e pacchettizzato da Chessnut per Bot game.',
    'ja': 'Bot game 用に Chessnut が選んでパッケージした人気の LC0 コミュニティ重みです。',
    'ko': 'Chessnut이 Bot game용으로 선별하고 패키징한 인기 LC0 커뮤니티 가중치입니다.',
    'nl':
        'Populair LC0-communitygewicht, door Chessnut geselecteerd en verpakt voor Bot game.',
    'ru':
        'Популярный вес LC0 сообщества, отобранный и упакованный Chessnut для Bot game.',
  },
};

String? _engineLabTranslations(String text, String key) {
  final direct = _engineLabStaticTranslations[text]?[key];
  if (direct != null) return direct;
  return _engineLabPatternTranslation(text, key);
}

String? _engineLabPatternTranslation(String text, String key) {
  String local(String source) {
    return _engineLabStaticTranslations[source]?[key] ??
        _translatePatterns(source, key) ??
        _manualDirectTranslations(source, key) ??
        generatedAppLocalizedMap(key)[source] ??
        source;
  }

  final pointsPerTraining =
      RegExp(r'^(\d+) points per training$').firstMatch(text);
  if (pointsPerTraining != null) {
    final points = pointsPerTraining.group(1)!;
    return switch (key) {
      'zh-Hans' => '每次训练 $points 积分',
      'zh-Hant' => '每次訓練 $points 點',
      'de' => '$points Punkte pro Training',
      'es' => '$points puntos por entrenamiento',
      'fr' => '$points points par entraînement',
      'it' => '$points punti per allenamento',
      'ja' => 'トレーニング1回 $points ポイント',
      'ko' => '훈련 1회당 $points포인트',
      'nl' => '$points punten per training',
      'ru' => '$points очков за обучение',
      _ => null,
    };
  }

  final premiumUntil =
      RegExp(r'^Premium active until (.+)\.$').firstMatch(text);
  if (premiumUntil != null) {
    final until = premiumUntil.group(1)!;
    return switch (key) {
      'zh-Hans' => 'Premium 有效期至 $until。',
      'zh-Hant' => 'Premium 有效期至 $until。',
      'de' => 'Premium aktiv bis $until.',
      'es' => 'Premium activo hasta $until.',
      'fr' => 'Premium actif jusqu’au $until.',
      'it' => 'Premium attivo fino al $until.',
      'ja' => 'Premium は $until まで有効です。',
      'ko' => 'Premium은 $until까지 활성화됩니다.',
      'nl' => 'Premium actief tot $until.',
      'ru' => 'Premium активен до $until.',
      _ => null,
    };
  }

  final personalEngineTitle =
      RegExp(r'^Personal engine (\d+)$').firstMatch(text);
  if (personalEngineTitle != null) {
    final id = personalEngineTitle.group(1)!;
    return switch (key) {
      'zh-Hans' => '个人引擎 $id',
      'zh-Hant' => '個人引擎 $id',
      'de' => 'Persönliche Engine $id',
      'es' => 'Motor personal $id',
      'fr' => 'Moteur personnel $id',
      'it' => 'Motore personale $id',
      'ja' => '個人エンジン $id',
      'ko' => '개인 엔진 $id',
      'nl' => 'Persoonlijke engine $id',
      'ru' => 'Личный движок $id',
      _ => null,
    };
  }

  final lc0WeightTitle = RegExp(r'^LC0 weight (\d+)$').firstMatch(text);
  if (lc0WeightTitle != null) {
    final id = lc0WeightTitle.group(1)!;
    return switch (key) {
      'zh-Hans' => 'LC0 权重 $id',
      'zh-Hant' => 'LC0 權重 $id',
      'de' => 'LC0-Gewicht $id',
      'es' => 'Peso LC0 $id',
      'fr' => 'Poids LC0 $id',
      'it' => 'Peso LC0 $id',
      'ja' => 'LC0 重み $id',
      'ko' => 'LC0 가중치 $id',
      'nl' => 'LC0-gewicht $id',
      'ru' => 'Вес LC0 $id',
      _ => null,
    };
  }

  final playerGames = RegExp(r"^(.+)'s games$").firstMatch(text);
  if (playerGames != null) {
    final player = playerGames.group(1)!;
    return switch (key) {
      'zh-Hans' => '$player 的对局',
      'zh-Hant' => '$player 的對局',
      'de' => 'Partien von $player',
      'es' => 'Partidas de $player',
      'fr' => 'Parties de $player',
      'it' => 'Partite di $player',
      'ja' => '$player の対局',
      'ko' => '$player의 대국',
      'nl' => 'Partijen van $player',
      'ru' => 'Партии $player',
      _ => null,
    };
  }

  final titleReady = RegExp(r'^(.+) is ready for Bot game\.$').firstMatch(text);
  if (titleReady != null) {
    final title = titleReady.group(1)!;
    return switch (key) {
      'zh-Hans' => '$title 已可用于 Bot game。',
      'zh-Hant' => '$title 已可用於 Bot game。',
      'de' => '$title ist bereit für Bot game.',
      'es' => '$title está listo para Bot game.',
      'fr' => '$title est prêt pour Bot game.',
      'it' => '$title è pronto per Bot game.',
      'ja' => '$title は Bot game で使用できます。',
      'ko' => '$title을 Bot game에서 사용할 수 있습니다.',
      'nl' => '$title is klaar voor Bot game.',
      'ru' => '$title готов для Bot game.',
      _ => null,
    };
  }

  final titleEnabled =
      RegExp(r'^(.+) is enabled for Bot game\.$').firstMatch(text);
  if (titleEnabled != null) {
    final title = titleEnabled.group(1)!;
    return switch (key) {
      'zh-Hans' => '$title 已启用于 Bot game。',
      'zh-Hant' => '$title 已啟用於 Bot game。',
      'de' => '$title ist für Bot game aktiviert.',
      'es' => '$title está activado para Bot game.',
      'fr' => '$title est activé pour Bot game.',
      'it' => '$title è abilitato per Bot game.',
      'ja' => '$title は Bot game で有効です。',
      'ko' => '$title이 Bot game에 활성화되었습니다.',
      'nl' => '$title is ingeschakeld voor Bot game.',
      'ru' => '$title включён для Bot game.',
      _ => null,
    };
  }

  final titleDisabled = RegExp(r'^(.+) is disabled\.$').firstMatch(text);
  if (titleDisabled != null) {
    final title = titleDisabled.group(1)!;
    return switch (key) {
      'zh-Hans' => '$title 已停用。',
      'zh-Hant' => '$title 已停用。',
      'de' => '$title ist deaktiviert.',
      'es' => '$title está desactivado.',
      'fr' => '$title est désactivé.',
      'it' => '$title è disabilitato.',
      'ja' => '$title は無効です。',
      'ko' => '$title이 비활성화되었습니다.',
      'nl' => '$title is uitgeschakeld.',
      'ru' => '$title отключён.',
      _ => null,
    };
  }

  final enabledCount = RegExp(r'^(\d+) enabled$').firstMatch(text);
  if (enabledCount != null) {
    final count = enabledCount.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 个已启用',
      'zh-Hant' => '$count 個已啟用',
      'de' => '$count aktiviert',
      'es' => '$count activados',
      'fr' => '$count activés',
      'it' => '$count abilitati',
      'ja' => '$count 件有効',
      'ko' => '$count개 활성화됨',
      'nl' => '$count ingeschakeld',
      'ru' => 'Включено: $count',
      _ => null,
    };
  }

  final enginesCount = RegExp(r'^(\d+) engines$').firstMatch(text);
  if (enginesCount != null) {
    final count = enginesCount.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 个引擎',
      'zh-Hant' => '$count 個引擎',
      'de' => '$count Engines',
      'es' => '$count motores',
      'fr' => '$count moteurs',
      'it' => '$count motori',
      'ja' => '$count 件のエンジン',
      'ko' => '엔진 $count개',
      'nl' => '$count schaakengines',
      'ru' => 'Движков: $count',
      _ => null,
    };
  }

  final pageSlash = RegExp(r'^Page (\d+) / (\d+)$').firstMatch(text);
  if (pageSlash != null) {
    final page = pageSlash.group(1)!;
    final total = pageSlash.group(2)!;
    return switch (key) {
      'zh-Hans' => '第 $page / $total 页',
      'zh-Hant' => '第 $page / $total 頁',
      'de' => 'Seite $page / $total',
      'es' => 'Página $page / $total',
      'fr' => 'Page $page sur $total',
      'it' => 'Pagina $page / $total',
      'ja' => '$total ページ中 $page ページ',
      'ko' => '$total페이지 중 $page페이지',
      'nl' => 'Pagina $page / $total',
      'ru' => 'Страница $page / $total',
      _ => null,
    };
  }

  final gamesSource = RegExp(r'^(\d+) games / (.+)$').firstMatch(text);
  if (gamesSource != null) {
    final count = gamesSource.group(1)!;
    final source = gamesSource.group(2)!;
    return switch (key) {
      'zh-Hans' => '$count 盘对局 / $source',
      'zh-Hant' => '$count 盤對局 / $source',
      'de' => '$count Partien / $source',
      'es' => '$count partidas / $source',
      'fr' => '$count parties / $source',
      'it' => '$count partite / $source',
      'ja' => '$count 局 / $source',
      'ko' => '$count 대국 / $source',
      'nl' => '$count partijen / $source',
      'ru' => '$count партий / $source',
      _ => null,
    };
  }

  final selectionSummary = RegExp(
    r'^(\d+) matched(?: / (\d+) total)? / (\d+) selected\. Select (\d+)-(\d+) games for training\.$',
  ).firstMatch(text);
  if (selectionSummary != null) {
    final matched = selectionSummary.group(1)!;
    final total = selectionSummary.group(2);
    final selected = selectionSummary.group(3)!;
    final min = selectionSummary.group(4)!;
    final max = selectionSummary.group(5)!;
    final totalPart = total == null
        ? ''
        : switch (key) {
            'zh-Hans' => ' / 共 $total',
            'zh-Hant' => ' / 共 $total',
            'de' => ' / $total gesamt',
            'es' => ' / $total en total',
            'fr' => ' / $total au total',
            'it' => ' / $total totali',
            'ja' => ' / 合計 $total',
            'ko' => ' / 총 $total',
            'nl' => ' / $total totaal',
            'ru' => ' / всего $total',
            _ => ' / $total total',
          };
    return switch (key) {
      'zh-Hans' => '$matched 盘匹配$totalPart / 已选 $selected。请选择 $min-$max 盘用于训练。',
      'zh-Hant' => '$matched 盤符合$totalPart / 已選 $selected。請選擇 $min-$max 盤用於訓練。',
      'de' =>
        '$matched passend$totalPart / $selected ausgewählt. Wähle $min-$max Partien fürs Training.',
      'es' =>
        '$matched coincidentes$totalPart / $selected seleccionadas. Elige $min-$max partidas para entrenar.',
      'fr' =>
        '$matched correspondantes$totalPart / $selected sélectionnées. Choisissez $min-$max parties pour l’entraînement.',
      'it' =>
        '$matched corrispondenti$totalPart / $selected selezionate. Scegli $min-$max partite per l’allenamento.',
      'ja' =>
        '$matched 件一致$totalPart / $selected 件選択中。トレーニング用に $min-$max 局選択してください。',
      'ko' =>
        '$matched개 일치$totalPart / $selected개 선택됨. 훈련에 $min-$max개 대국을 선택하세요.',
      'nl' =>
        '$matched gevonden$totalPart / $selected geselecteerd. Kies $min-$max partijen voor training.',
      'ru' =>
        '$matched совпадений$totalPart / выбрано $selected. Выберите $min-$max партий для обучения.',
      _ => null,
    };
  }

  final matchedPage =
      RegExp(r'^(\d+) matched / page (\d+) of (\d+)$').firstMatch(text);
  if (matchedPage != null) {
    final matched = matchedPage.group(1)!;
    final page = matchedPage.group(2)!;
    final total = matchedPage.group(3)!;
    return switch (key) {
      'zh-Hans' => '$matched 盘匹配 / 第 $page 页，共 $total 页',
      'zh-Hant' => '$matched 盤符合 / 第 $page 頁，共 $total 頁',
      'de' => '$matched passend / Seite $page von $total',
      'es' => '$matched coincidentes / página $page de $total',
      'fr' => '$matched correspondantes / page $page sur $total',
      'it' => '$matched corrispondenti / pagina $page di $total',
      'ja' => '$matched 件一致 / $total ページ中 $page ページ',
      'ko' => '$matched개 일치 / $total페이지 중 $page페이지',
      'nl' => '$matched gevonden / pagina $page van $total',
      'ru' => '$matched совпадений / страница $page из $total',
      _ => null,
    };
  }

  final onThisPage = RegExp(r'^(.+) / (\d+) on this page$').firstMatch(text);
  if (onThisPage != null) {
    final title = local(onThisPage.group(1)!);
    final count = onThisPage.group(2)!;
    return switch (key) {
      'zh-Hans' => '$title / 本页 $count 个',
      'zh-Hant' => '$title / 本頁 $count 個',
      'de' => '$title / $count auf dieser Seite',
      'es' => '$title / $count en esta página',
      'fr' => '$title / $count sur cette page',
      'it' => '$title / $count in questa pagina',
      'ja' => '$title / このページで $count 件',
      'ko' => '$title / 이 페이지 $count개',
      'nl' => '$title / $count op deze pagina',
      'ru' => '$title / на странице: $count',
      _ => null,
    };
  }

  final gamesReady = RegExp(r'^(\d+) games ready$').firstMatch(text);
  if (gamesReady != null) {
    final count = gamesReady.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 盘对局已就绪',
      'zh-Hant' => '$count 盤對局已就緒',
      'de' => '$count Partien bereit',
      'es' => '$count partidas listas',
      'fr' => '$count parties prêtes',
      'it' => '$count partite pronte',
      'ja' => '$count 局準備完了',
      'ko' => '$count개 대국 준비됨',
      'nl' => '$count partijen gereed',
      'ru' => '$count партий готовы',
      _ => null,
    };
  }

  final gamesRecommended =
      RegExp(r'^(\d+) games ready / (\d+)\+ recommended$').firstMatch(text);
  if (gamesRecommended != null) {
    final count = gamesRecommended.group(1)!;
    final recommended = gamesRecommended.group(2)!;
    return switch (key) {
      'zh-Hans' => '$count 盘对局已就绪 / 建议 $recommended 盘以上',
      'zh-Hant' => '$count 盤對局已就緒 / 建議 $recommended 盤以上',
      'de' => '$count Partien bereit / $recommended+ empfohlen',
      'es' => '$count partidas listas / se recomiendan $recommended+',
      'fr' => '$count parties prêtes / $recommended+ recommandé',
      'it' => '$count partite pronte / consigliate $recommended+',
      'ja' => '$count 局準備完了 / $recommended 局以上推奨',
      'ko' => '$count개 대국 준비됨 / $recommended개 이상 권장',
      'nl' => '$count partijen gereed / $recommended+ aanbevolen',
      'ru' => '$count партий готовы / рекомендуется $recommended+',
      _ => null,
    };
  }

  final gamesLimit =
      RegExp(r'^(\d+) games / (maximum|minimum) (\d+)$').firstMatch(text);
  if (gamesLimit != null) {
    final count = gamesLimit.group(1)!;
    final type = gamesLimit.group(2)!;
    final limit = gamesLimit.group(3)!;
    final isMax = type == 'maximum';
    return switch (key) {
      'zh-Hans' => '$count 盘对局 / ${isMax ? '最多' : '最少'} $limit',
      'zh-Hant' => '$count 盤對局 / ${isMax ? '最多' : '最少'} $limit',
      'de' => '$count Partien / ${isMax ? 'maximal' : 'mindestens'} $limit',
      'es' => '$count partidas / ${isMax ? 'máximo' : 'mínimo'} $limit',
      'fr' => '$count parties / ${isMax ? 'maximum' : 'minimum'} $limit',
      'it' => '$count partite / ${isMax ? 'massimo' : 'minimo'} $limit',
      'ja' => '$count 局 / ${isMax ? '最大' : '最小'} $limit',
      'ko' => '$count개 대국 / ${isMax ? '최대' : '최소'} $limit',
      'nl' => '$count partijen / ${isMax ? 'maximum' : 'minimum'} $limit',
      'ru' => '$count партий / ${isMax ? 'максимум' : 'минимум'} $limit',
      _ => null,
    };
  }

  final sampleNotice = RegExp(
    r'^Showing (\d+) sample games from (\d+) matched games\.$',
  ).firstMatch(text);
  if (sampleNotice != null) {
    final sample = sampleNotice.group(1)!;
    final total = sampleNotice.group(2)!;
    return switch (key) {
      'zh-Hans' => '正在显示 $total 盘匹配对局中的 $sample 盘示例。',
      'zh-Hant' => '正在顯示 $total 盤符合對局中的 $sample 盤範例。',
      'de' =>
        '$sample Beispielpartien von $total passenden Partien werden angezeigt.',
      'es' => 'Mostrando $sample partidas de muestra de $total coincidentes.',
      'fr' =>
        'Affichage de $sample parties d’exemple sur $total correspondantes.',
      'it' => 'Mostro $sample partite di esempio da $total corrispondenti.',
      'ja' => '$total 件の一致対局から $sample 件のサンプルを表示しています。',
      'ko' => '$total개 일치 대국 중 $sample개 샘플을 표시합니다.',
      'nl' => '$sample voorbeeldpartijen uit $total gevonden partijen.',
      'ru' => 'Показано примеров: $sample из $total подходящих партий.',
      _ => null,
    };
  }

  final pgnFiles = RegExp(r'^(\d+) PGN files?$').firstMatch(text);
  if (pgnFiles != null) {
    final count = pgnFiles.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 个 PGN 文件',
      'zh-Hant' => '$count 個 PGN 檔案',
      'de' => '$count PGN-Dateien',
      'es' => '$count archivos PGN',
      'fr' => '$count fichiers PGN',
      'it' => '$count file PGN',
      'ja' => '$count 個の PGN ファイル',
      'ko' => 'PGN 파일 $count개',
      'nl' => '$count PGN-bestanden',
      'ru' => 'PGN-файлов: $count',
      _ => null,
    };
  }

  final preparing = RegExp(
    r'^Preparing (\d+) selected Game Record PGNs for training\.\.\.$',
  ).firstMatch(text);
  if (preparing != null) {
    final count = preparing.group(1)!;
    return switch (key) {
      'zh-Hans' => '正在准备 $count 盘已选 Game Record PGN 用于训练...',
      'zh-Hant' => '正在準備 $count 盤已選 Game Record PGN 用於訓練...',
      'de' =>
        '$count ausgewählte Game Record-PGNs werden fürs Training vorbereitet...',
      'es' =>
        'Preparando $count PGN de Game Record seleccionados para entrenar...',
      'fr' =>
        'Préparation de $count PGN Game Record sélectionnés pour l’entraînement...',
      'it' =>
        'Preparazione di $count PGN Game Record selezionati per l’allenamento...',
      'ja' => '選択した Game Record PGN $count 件をトレーニング用に準備中...',
      'ko' => '선택한 Game Record PGN $count개를 훈련용으로 준비 중...',
      'nl' =>
        '$count geselecteerde Game Record-PGN’s voorbereiden voor training...',
      'ru' => 'Подготовка выбранных PGN Game Record для обучения: $count...',
      _ => null,
    };
  }

  final selectAtMost =
      RegExp(r'^Select at most (\d+) games before starting training\.$')
          .firstMatch(text);
  if (selectAtMost != null) {
    final max = selectAtMost.group(1)!;
    return switch (key) {
      'zh-Hans' => '开始训练前最多选择 $max 盘对局。',
      'zh-Hant' => '開始訓練前最多選擇 $max 盤對局。',
      'de' => 'Wähle höchstens $max Partien, bevor du das Training startest.',
      'es' => 'Selecciona como máximo $max partidas antes de entrenar.',
      'fr' =>
        'Sélectionnez au maximum $max parties avant de lancer l’entraînement.',
      'it' =>
        'Seleziona al massimo $max partite prima di avviare l’allenamento.',
      'ja' => 'トレーニング開始前に最大 $max 局まで選択してください。',
      'ko' => '훈련을 시작하기 전에 최대 $max개 대국을 선택하세요.',
      'nl' => 'Selecteer maximaal $max partijen voordat je de training start.',
      'ru' => 'Перед обучением выберите не больше $max партий.',
      _ => null,
    };
  }

  final selectAtLeast =
      RegExp(r'^Select at least (\d+) games before starting training\.$')
          .firstMatch(text);
  if (selectAtLeast != null) {
    final min = selectAtLeast.group(1)!;
    return switch (key) {
      'zh-Hans' => '开始训练前至少选择 $min 盘对局。',
      'zh-Hant' => '開始訓練前至少選擇 $min 盤對局。',
      'de' => 'Wähle mindestens $min Partien, bevor du das Training startest.',
      'es' => 'Selecciona al menos $min partidas antes de entrenar.',
      'fr' =>
        'Sélectionnez au moins $min parties avant de lancer l’entraînement.',
      'it' => 'Seleziona almeno $min partite prima di avviare l’allenamento.',
      'ja' => 'トレーニング開始前に少なくとも $min 局選択してください。',
      'ko' => '훈련을 시작하기 전에 최소 $min개 대국을 선택하세요.',
      'nl' => 'Selecteer minstens $min partijen voordat je de training start.',
      'ru' => 'Перед обучением выберите минимум $min партий.',
      _ => null,
    };
  }

  final onlyUsable = RegExp(
    r'^Only (\d+) usable games were selected\. At least (\d+) games are required before starting training\.$',
  ).firstMatch(text);
  if (onlyUsable != null) {
    final count = onlyUsable.group(1)!;
    final min = onlyUsable.group(2)!;
    return switch (key) {
      'zh-Hans' => '只选择了 $count 盘可用对局。开始训练前至少需要 $min 盘。',
      'zh-Hant' => '只選擇了 $count 盤可用對局。開始訓練前至少需要 $min 盤。',
      'de' =>
        'Nur $count nutzbare Partien ausgewählt. Vor dem Training sind mindestens $min Partien erforderlich.',
      'es' =>
        'Solo se seleccionaron $count partidas utilizables. Se requieren al menos $min para entrenar.',
      'fr' =>
        'Seulement $count parties utilisables sélectionnées. Il en faut au moins $min avant l’entraînement.',
      'it' =>
        'Sono state selezionate solo $count partite utilizzabili. Ne servono almeno $min prima dell’allenamento.',
      'ja' => '使用可能な対局は $count 局だけ選択されています。トレーニング開始には少なくとも $min 局必要です。',
      'ko' => '사용 가능한 대국이 $count개만 선택되었습니다. 훈련 전에 최소 $min개가 필요합니다.',
      'nl' =>
        'Slechts $count bruikbare partijen geselecteerd. Voor training zijn minstens $min partijen nodig.',
      'ru' =>
        'Выбрано пригодных партий: $count. Для обучения нужно минимум $min.',
      _ => null,
    };
  }

  final whiteBlack = RegExp(r'^White: (.+) / Black: (.+)$').firstMatch(text);
  if (whiteBlack != null) {
    final white = whiteBlack.group(1)!;
    final black = whiteBlack.group(2)!;
    return switch (key) {
      'zh-Hans' => '白方：$white / 黑方：$black',
      'zh-Hant' => '白方：$white / 黑方：$black',
      'de' => 'Weiß: $white / Schwarz: $black',
      'es' => 'Blancas: $white / Negras: $black',
      'fr' => 'Blancs : $white / Noirs : $black',
      'it' => 'Bianco: $white / Nero: $black',
      'ja' => '白：$white / 黒：$black',
      'ko' => '백: $white / 흑: $black',
      'nl' => 'Wit: $white / Zwart: $black',
      'ru' => 'Белые: $white / Чёрные: $black',
      _ => null,
    };
  }

  final modeTime = RegExp(r'^(.+) / Time: (.+)$').firstMatch(text);
  if (modeTime != null) {
    final mode = local(modeTime.group(1)!);
    final time = modeTime.group(2)!;
    return switch (key) {
      'zh-Hans' => '$mode / 时间：$time',
      'zh-Hant' => '$mode / 時間：$time',
      'de' => '$mode / Zeit: $time',
      'es' => '$mode / Tiempo: $time',
      'fr' => '$mode / Temps : $time',
      'it' => '$mode / Tempo: $time',
      'ja' => '$mode / 時間：$time',
      'ko' => '$mode / 시간: $time',
      'nl' => '$mode / Tijd: $time',
      'ru' => '$mode / Время: $time',
      _ => null,
    };
  }

  final date = RegExp(r'^Date: (.+)$').firstMatch(text);
  if (date != null) {
    final value = date.group(1)!;
    return switch (key) {
      'zh-Hans' => '日期：$value',
      'zh-Hant' => '日期：$value',
      'de' => 'Datum: $value',
      'es' => 'Fecha: $value',
      'fr' => 'Date : $value',
      'it' => 'Data: $value',
      'ja' => '日付：$value',
      'ko' => '날짜: $value',
      'nl' => 'Datum: $value',
      'ru' => 'Дата: $value',
      _ => null,
    };
  }

  final location = RegExp(r'^Location: (.+)$').firstMatch(text);
  if (location != null) {
    final value = location.group(1)!;
    return switch (key) {
      'zh-Hans' => '地点：$value',
      'zh-Hant' => '地點：$value',
      'de' => 'Ort: $value',
      'es' => 'Ubicación: $value',
      'fr' => 'Lieu : $value',
      'it' => 'Luogo: $value',
      'ja' => '場所：$value',
      'ko' => '장소: $value',
      'nl' => 'Locatie: $value',
      'ru' => 'Место: $value',
      _ => null,
    };
  }

  final trainedFrom = RegExp(
    r'^Trained from (\d+) games / Source: (.+) / (.+)\.$',
  ).firstMatch(text);
  if (trainedFrom != null) {
    final count = trainedFrom.group(1)!;
    final source = local(trainedFrom.group(2)!);
    final status = local(trainedFrom.group(3)!);
    return switch (key) {
      'zh-Hans' => '基于 $count 盘对局训练 / 来源：$source / $status。',
      'zh-Hant' => '基於 $count 盤對局訓練 / 來源：$source / $status。',
      'de' => 'Aus $count Partien trainiert / Quelle: $source / $status.',
      'es' => 'Entrenado con $count partidas / Fuente: $source / $status.',
      'fr' => 'Entraîné avec $count parties / Source : $source / $status.',
      'it' => 'Allenato da $count partite / Fonte: $source / $status.',
      'ja' => '$count 局からトレーニング / ソース：$source / $status。',
      'ko' => '$count개 대국으로 훈련 / 소스: $source / $status.',
      'nl' => 'Getraind met $count partijen / Bron: $source / $status.',
      'ru' => 'Обучено на $count партиях / Источник: $source / $status.',
      _ => null,
    };
  }

  final trainedSelected =
      RegExp(r'^Trained from selected games / Source: (.+) / (.+)\.$')
          .firstMatch(text);
  if (trainedSelected != null) {
    final source = local(trainedSelected.group(1)!);
    final status = local(trainedSelected.group(2)!);
    return switch (key) {
      'zh-Hans' => '基于已选对局训练 / 来源：$source / $status。',
      'zh-Hant' => '基於已選對局訓練 / 來源：$source / $status。',
      'de' => 'Aus ausgewählten Partien trainiert / Quelle: $source / $status.',
      'es' =>
        'Entrenado con partidas seleccionadas / Fuente: $source / $status.',
      'fr' =>
        'Entraîné avec les parties sélectionnées / Source : $source / $status.',
      'it' => 'Allenato dalle partite selezionate / Fonte: $source / $status.',
      'ja' => '選択した対局からトレーニング / ソース：$source / $status。',
      'ko' => '선택한 대국으로 훈련 / 소스: $source / $status.',
      'nl' => 'Getraind met geselecteerde partijen / Bron: $source / $status.',
      'ru' => 'Обучено на выбранных партиях / Источник: $source / $status.',
      _ => null,
    };
  }

  final trainedCount = RegExp(r'^Trained from (\d+) games$').firstMatch(text);
  if (trainedCount != null) {
    final count = trainedCount.group(1)!;
    return switch (key) {
      'zh-Hans' => '基于 $count 盘对局训练',
      'zh-Hant' => '基於 $count 盤對局訓練',
      'de' => 'Aus $count Partien trainiert',
      'es' => 'Entrenado con $count partidas',
      'fr' => 'Entraîné avec $count parties',
      'it' => 'Allenato da $count partite',
      'ja' => '$count 局からトレーニング',
      'ko' => '$count개 대국으로 훈련',
      'nl' => 'Getraind met $count partijen',
      'ru' => 'Обучено на $count партиях',
      _ => null,
    };
  }

  final modelAccuracy = RegExp(r'^Model accuracy (.+)$').firstMatch(text);
  if (modelAccuracy != null) {
    final value = modelAccuracy.group(1)!;
    return switch (key) {
      'zh-Hans' => '模型准确率 $value',
      'zh-Hant' => '模型準確率 $value',
      'de' => 'Modellgenauigkeit $value',
      'es' => 'Precisión del modelo $value',
      'fr' => 'Précision du modèle $value',
      'it' => 'Accuratezza modello $value',
      'ja' => 'モデル精度 $value',
      'ko' => '모델 정확도 $value',
      'nl' => 'Modelnauwkeurigheid $value',
      'ru' => 'Точность модели $value',
      _ => null,
    };
  }

  final target = RegExp(r'^Target (.+)$').firstMatch(text);
  if (target != null) {
    final value = target.group(1)!;
    return switch (key) {
      'zh-Hans' => '目标 $value',
      'zh-Hant' => '目標 $value',
      'de' => 'Ziel $value',
      'es' => 'Objetivo $value',
      'fr' => 'Objectif $value',
      'it' => 'Obiettivo $value',
      'ja' => '目標 $value',
      'ko' => '목표 $value',
      'nl' => 'Doel $value',
      'ru' => 'Цель $value',
      _ => null,
    };
  }

  final curatedRemark =
      RegExp(r'^(.+) Provided by Chessnut for Bot game use\.$')
          .firstMatch(text);
  if (curatedRemark != null) {
    final remark = curatedRemark.group(1)!;
    return switch (key) {
      'zh-Hans' => '$remark Chessnut 提供，可用于 Bot game。',
      'zh-Hant' => '$remark Chessnut 提供，可用於 Bot game。',
      'de' => '$remark Von Chessnut für Bot game bereitgestellt.',
      'es' => '$remark Proporcionado por Chessnut para Bot game.',
      'fr' => '$remark Fourni par Chessnut pour Bot game.',
      'it' => '$remark Fornito da Chessnut per Bot game.',
      'ja' => '$remark Chessnut が Bot game 用に提供しています。',
      'ko' => '$remark Chessnut이 Bot game용으로 제공합니다.',
      'nl' => '$remark Geleverd door Chessnut voor Bot game.',
      'ru' => '$remark Предоставлено Chessnut для Bot game.',
      _ => null,
    };
  }

  return null;
}

String? _careerModeTranslations(String text, String key) {
  final careerGate = RegExp(r'^Gate (\d+)$').firstMatch(text);
  if (careerGate != null) {
    final gate = careerGate.group(1)!;
    return switch (key) {
      'zh-Hans' => '第 $gate 关',
      'zh-Hant' => '第 $gate 關',
      _ => null,
    };
  }

  final careerStage = RegExp(r'^Stage (\d+)$').firstMatch(text);
  if (careerStage != null) {
    final stage = careerStage.group(1)!;
    return switch (key) {
      'zh-Hans' => '第 $stage 阶段',
      'zh-Hant' => '第 $stage 階段',
      _ => null,
    };
  }

  final careerLevel =
      RegExp(r'^(Rookie|Bronze|Silver|Gold|Platinum|Master) ([IV]+)$')
          .firstMatch(text);
  if (careerLevel != null) {
    final level = careerLevel.group(1)!;
    final tier = careerLevel.group(2)!;
    final translatedLevel = switch (level) {
      'Rookie' => key == 'zh-Hant' ? '新手' : '新手',
      'Bronze' => key == 'zh-Hant' ? '青銅' : '青铜',
      'Silver' => key == 'zh-Hant' ? '白銀' : '白银',
      'Gold' => key == 'zh-Hant' ? '黃金' : '黄金',
      'Platinum' => key == 'zh-Hant' ? '白金' : '铂金',
      'Master' => key == 'zh-Hant' ? '大師' : '大师',
      _ => null,
    };
    if (translatedLevel != null && (key == 'zh-Hans' || key == 'zh-Hant')) {
      return '$translatedLevel $tier';
    }
  }

  const journeyTranslations = <String, Map<String, String>>{
    'Career Journey': {
      'zh-Hans': '生涯之旅',
      'zh-Hant': '生涯之旅',
    },
    'Passed gate': {
      'zh-Hans': '已通过关卡',
      'zh-Hant': '已通過關卡',
    },
    'Current gate': {
      'zh-Hans': '当前关卡',
      'zh-Hant': '目前關卡',
    },
    'Training recommendations': {
      'zh-Hans': '训练建议',
      'zh-Hant': '訓練建議',
    },
    'If stuck': {
      'zh-Hans': '如果卡住了',
      'zh-Hant': '如果卡住了',
    },
    'Puzzle Practice': {
      'zh-Hans': '战术题练习',
      'zh-Hant': '戰術題練習',
    },
    'Review Last Loss': {
      'zh-Hans': '复盘上一场失利',
      'zh-Hant': '複盤上一場失利',
    },
    'Maia3 Review': {
      'zh-Hans': 'Maia3 复盘',
      'zh-Hant': 'Maia3 複盤',
    },
    'Train tactics linked to recent mistakes': {
      'zh-Hans': '练习与你近期失误相关的战术',
      'zh-Hant': '練習與你近期失誤相關的戰術',
    },
    'Review the game that blocked this node': {
      'zh-Hans': '复盘让你卡在这里的对局',
      'zh-Hant': '複盤讓你卡在這裡的對局',
    },
    'Compare choices with players near this rating': {
      'zh-Hans': '对比相近等级棋手的选择',
      'zh-Hant': '對比相近等級棋手的選擇',
    },
    'If this gate keeps blocking you, train one weakness and come back for the challenge.':
        {
      'zh-Hans': '如果一直卡在这一关，先针对一个弱点训练，再回来挑战。',
      'zh-Hant': '如果一直卡在這一關，先針對一個弱點訓練，再回來挑戰。',
    },
    'If this stage keeps blocking you, train one weakness and come back for the challenge.':
        {
      'zh-Hans': '如果一直卡在这一阶段，先针对一个弱点训练，再回来挑战。',
      'zh-Hant': '如果一直卡在這一階段，先針對一個弱點訓練，再回來挑戰。',
    },
  };
  final journeyTranslation = journeyTranslations[text]?[key];
  if (journeyTranslation != null) return journeyTranslation;

  final careerElo = RegExp(r'^Career ELO (\d+)$').firstMatch(text);
  if (careerElo != null) {
    final elo = careerElo.group(1)!;
    return switch (key) {
      'zh-Hans' => '生涯 ELO $elo',
      'zh-Hant' => '生涯 ELO $elo',
      _ => null,
    };
  }

  final nextGoal = RegExp(r'^Next goal (\d+)$').firstMatch(text);
  if (nextGoal != null) {
    final elo = nextGoal.group(1)!;
    return switch (key) {
      'zh-Hans' => '下一目标 $elo',
      'zh-Hant' => '下一目標 $elo',
      _ => null,
    };
  }

  final ratingDelta = RegExp(r'^([+−-]?\d+|±0) ELO$').firstMatch(text);
  if (ratingDelta != null) {
    final delta = ratingDelta.group(1)!;
    return switch (key) {
      'zh-Hans' => '$delta ELO',
      'zh-Hant' => '$delta ELO',
      _ => null,
    };
  }

  final opponentReady = RegExp(
    r'^(.+) is ready for a career challenge\.$',
  ).firstMatch(text);
  if (opponentReady != null) {
    final name = opponentReady.group(1)!;
    return switch (key) {
      'zh-Hans' => '$name 已准备好进行生涯挑战。',
      'zh-Hant' => '$name 已準備好進行生涯挑戰。',
      _ => null,
    };
  }

  final findingPlayer = RegExp(
    r'^Finding a virtual player near ELO (\d+)\.$',
  ).firstMatch(text);
  if (findingPlayer != null) {
    final elo = findingPlayer.group(1)!;
    return switch (key) {
      'zh-Hans' => '正在寻找 ELO 接近 $elo 的虚拟棋手。',
      'zh-Hant' => '正在尋找 ELO 接近 $elo 的虛擬棋手。',
      _ => null,
    };
  }

  final careerChallengeWithOpening =
      RegExp(r'^Career challenge / (.+)$').firstMatch(text);
  if (careerChallengeWithOpening != null) {
    final opening = careerChallengeWithOpening.group(1)!;
    return switch (key) {
      'zh-Hans' => '生涯挑战 / $opening',
      'zh-Hant' => '生涯挑戰 / $opening',
      _ => null,
    };
  }

  final eloToUnlockBoss =
      RegExp(r'^(\d+) ELO to unlock the boss challenge\.$').firstMatch(text);
  if (eloToUnlockBoss != null) {
    final elo = eloToUnlockBoss.group(1)!;
    return switch (key) {
      'zh-Hans' => '还需 $elo ELO 解锁关底挑战。',
      'zh-Hant' => '還需 $elo ELO 解鎖關底挑戰。',
      _ => null,
    };
  }

  final stageComplete = RegExp(
    r'^Stage (\d+) complete\. Challenge the boss to enter the next stage\.$',
  ).firstMatch(text);
  if (stageComplete != null) {
    final stage = stageComplete.group(1)!;
    return switch (key) {
      'zh-Hans' => '第 $stage 阶段已完成。挑战关底对手即可进入下一阶段。',
      'zh-Hant' => '第 $stage 階段已完成。挑戰關底對手即可進入下一階段。',
      _ => null,
    };
  }

  final gainMoreElo = RegExp(
    r'^Gain (\d+) more ELO through battles and training to unlock the boss\.$',
  ).firstMatch(text);
  if (gainMoreElo != null) {
    final elo = gainMoreElo.group(1)!;
    return switch (key) {
      'zh-Hans' => '通过对局和训练再获得 $elo ELO，即可解锁关底对手。',
      'zh-Hant' => '透過對局和訓練再獲得 $elo ELO，即可解鎖關底對手。',
      _ => null,
    };
  }

  final winCareerGames = RegExp(
    r'^Win career games for \+(\d+) ELO\. Use training below if this stage gets stuck\.$',
  ).firstMatch(text);
  if (winCareerGames != null) {
    final elo = winCareerGames.group(1)!;
    return switch (key) {
      'zh-Hans' => '赢下生涯对局可获得 +$elo ELO。卡住时可使用下方训练。',
      'zh-Hant' => '贏下生涯對局可獲得 +$elo ELO。卡住時可使用下方訓練。',
      _ => null,
    };
  }

  const translations = <String, Map<String, String>>{
    'Career': {
      'zh-Hans': '生涯',
      'zh-Hant': '生涯',
    },
    'Career Mode': {
      'zh-Hans': '生涯模式',
      'zh-Hant': '生涯模式',
    },
    'ELO journey': {
      'zh-Hans': 'ELO 成长之路',
      'zh-Hant': 'ELO 成長之路',
    },
    'Sign in to sync your career progress.': {
      'zh-Hans': '登录以同步你的生涯进度。',
      'zh-Hant': '登入以同步你的生涯進度。',
    },
    'Career progress is not available right now.': {
      'zh-Hans': '生涯进度暂时不可用。',
      'zh-Hant': '生涯進度暫時不可用。',
    },
    'Sign in before starting Career Mode.': {
      'zh-Hans': '开始生涯模式前请先登录。',
      'zh-Hant': '開始生涯模式前請先登入。',
    },
    'Loading rating': {
      'zh-Hans': '正在加载等级分',
      'zh-Hant': '正在載入等級分',
    },
    'Loading career rating': {
      'zh-Hans': '正在加载生涯等级分',
      'zh-Hant': '正在載入生涯等級分',
    },
    'Loading': {
      'zh-Hans': '加载中',
      'zh-Hant': '載入中',
    },
    'Find career opponent': {
      'zh-Hans': '寻找生涯对手',
      'zh-Hant': '尋找生涯對手',
    },
    'Sign in / register': {
      'zh-Hans': '登录 / 注册',
      'zh-Hant': '登入 / 註冊',
    },
    'Career challenge': {
      'zh-Hans': '生涯挑战',
      'zh-Hant': '生涯挑戰',
    },
    'Beat a matched virtual opponent': {
      'zh-Hans': '击败匹配到的虚拟对手',
      'zh-Hant': '擊敗配對到的虛擬對手',
    },
    'Tactical practice': {
      'zh-Hans': '战术训练',
      'zh-Hant': '戰術訓練',
    },
    'Solve puzzles related to your level': {
      'zh-Hans': '解答与你水平相关的谜题',
      'zh-Hant': '解答與你水平相關的謎題',
    },
    'Review one game': {
      'zh-Hans': '复盘一局',
      'zh-Hant': '覆盤一局',
    },
    'Analyze a finished game after play': {
      'zh-Hans': '对弈结束后分析一局棋',
      'zh-Hant': '對弈結束後分析一局棋',
    },
    'Rank up match': {
      'zh-Hans': '晋级赛',
      'zh-Hant': '晉級賽',
    },
    'Unlocks when you reach the next ELO gate': {
      'zh-Hans': '达到下一个 ELO 门槛后解锁',
      'zh-Hant': '達到下一個 ELO 門檻後解鎖',
    },
    'Boss': {
      'zh-Hans': '关底',
      'zh-Hant': '關底',
    },
    'Career path': {
      'zh-Hans': '生涯路径',
      'zh-Hant': '生涯路徑',
    },
    'Possible opponent': {
      'zh-Hans': '可能的对手',
      'zh-Hant': '可能的對手',
    },
    'Build your career': {
      'zh-Hans': '打造你的生涯',
      'zh-Hant': '打造你的生涯',
    },
    'Puzzles': {
      'zh-Hans': '谜题',
      'zh-Hant': '謎題',
    },
    'Lessons': {
      'zh-Hans': '课程',
      'zh-Hant': '課程',
    },
    'Analysis': {
      'zh-Hans': '分析',
      'zh-Hant': '分析',
    },
    'Records': {
      'zh-Hans': '记录',
      'zh-Hant': '紀錄',
    },
    'Pattern work': {
      'zh-Hans': '棋形训练',
      'zh-Hant': '棋形訓練',
    },
    'Board course': {
      'zh-Hans': '棋盘课程',
      'zh-Hant': '棋盤課程',
    },
    'Review games': {
      'zh-Hans': '复盘对局',
      'zh-Hant': '覆盤對局',
    },
    'Career games': {
      'zh-Hans': '生涯对局',
      'zh-Hant': '生涯對局',
    },
    'Boss threshold': {
      'zh-Hans': '关底门槛',
      'zh-Hant': '關底門檻',
    },
    'Ready to challenge the boss and enter the next stage.': {
      'zh-Hans': '已可挑战关底对手并进入下一阶段。',
      'zh-Hant': '已可挑戰關底對手並進入下一階段。',
    },
    'Boss challenge unlocked': {
      'zh-Hans': '关底挑战已解锁',
      'zh-Hant': '關底挑戰已解鎖',
    },
    'Win the boss match to enter the next stage.': {
      'zh-Hans': '赢下关底对局即可进入下一阶段。',
      'zh-Hant': '贏下關底對局即可進入下一階段。',
    },
    'Now': {
      'zh-Hans': '当前',
      'zh-Hant': '目前',
    },
    'Boss ready': {
      'zh-Hans': '关底就绪',
      'zh-Hant': '關底就緒',
    },
    'Upcoming Opponent': {
      'zh-Hans': '即将挑战的对手',
      'zh-Hant': '即將挑戰的對手',
      'de': 'Bevorstehender Gegner',
      'es': 'Proximo rival',
      'fr': 'Prochain adversaire',
      'it': 'Prossimo avversario',
      'ja': '次の対戦相手',
      'ko': '다음 상대',
      'nl': 'Volgende tegenstander',
      'ru': 'Следующий соперник',
    },
    'Boss is unlocked. Start a career match to challenge the next stage.': {
      'zh-Hans': '关底对手已解锁。开始生涯对局即可挑战下一阶段。',
      'zh-Hant': '關底對手已解鎖。開始生涯對局即可挑戰下一階段。',
    },
    'Opponent found': {
      'zh-Hans': '已找到对手',
      'zh-Hant': '已找到對手',
    },
    'Matching opponent': {
      'zh-Hans': '正在匹配对手',
      'zh-Hant': '正在配對對手',
    },
    'Cancel': {
      'zh-Hans': '取消',
      'zh-Hant': '取消',
    },
    'Start': {
      'zh-Hans': '开始',
      'zh-Hant': '開始',
    },
  };

  return translations[text]?[key];
}

String? _visibleSweepTranslations(String text, String key) {
  const translations = <String, Map<String, String>>{
    'Lichess authorized.': {
      'zh-Hans': 'Lichess 已授权。',
      'zh-Hant': 'Lichess 已授權。',
      'de': 'Lichess autorisiert.',
      'es': 'Lichess autorizado.',
      'fr': 'Lichess autorisé.',
      'it': 'Lichess autorizzato.',
      'ja': 'Lichess の認証が完了しました。',
      'ko': 'Lichess 인증이 완료되었습니다.',
      'nl': 'Lichess gemachtigd.',
      'ru': 'Lichess авторизован.',
    },
    'Lichess authorized': {
      'zh-Hans': 'Lichess 已授权',
      'zh-Hant': 'Lichess 已授權',
      'de': 'Lichess autorisiert',
      'es': 'Lichess autorizado',
      'fr': 'Lichess autorisé',
      'it': 'Lichess autorizzato',
      'ja': 'Lichess 認証済み',
      'ko': 'Lichess 인증됨',
      'nl': 'Lichess gemachtigd',
      'ru': 'Lichess авторизован',
    },
    'Spend 0 points': {
      'zh-Hans': '消耗 0 积分',
      'zh-Hant': '消耗 0 積分',
      'de': '0 Punkte ausgeben',
      'es': 'Gastar 0 puntos',
      'fr': 'Dépenser 0 point',
      'it': 'Usa 0 punti',
      'ja': '0 ポイントを使う',
      'ko': '0 포인트 사용',
      'nl': '0 punten besteden',
      'ru': 'Списать 0 баллов',
    },
    'Spend 100 points': {
      'zh-Hans': '消耗 100 积分',
      'zh-Hant': '消耗 100 積分',
      'de': '100 Punkte ausgeben',
      'es': 'Gastar 100 puntos',
      'fr': 'Dépenser 100 points',
      'it': 'Usa 100 punti',
      'ja': '100 ポイントを使う',
      'ko': '100 포인트 사용',
      'nl': '100 punten besteden',
      'ru': 'Списать 100 баллов',
    },
    'Verifying': {
      'zh-Hans': '正在验证',
      'zh-Hant': '正在驗證',
      'de': 'Prüfung läuft',
      'es': 'Verificando',
      'fr': 'Vérification',
      'it': 'Verifica',
      'ja': '確認中',
      'ko': '확인 중',
      'nl': 'Verifiëren',
      'ru': 'Проверка',
    },
    'Live evaluation': {
      'zh-Hans': '实时评分',
      'zh-Hant': '即時評分',
      'de': 'Live-Bewertung',
      'es': 'Evaluación en vivo',
      'fr': 'Évaluation en direct',
      'it': 'Valutazione live',
      'ja': 'ライブ評価',
      'ko': '실시간 평가',
      'nl': 'Live-evaluatie',
      'ru': 'Живая оценка',
    },
    'Firmware update': {
      'zh-Hans': '固件更新',
      'zh-Hant': '韌體更新',
      'de': 'Firmware-Update',
      'es': 'Actualización de firmware',
      'fr': 'Mise à jour du firmware',
      'it': 'Aggiornamento firmware',
      'ja': 'ファームウェア更新',
      'ko': '펌웨어 업데이트',
      'nl': 'Firmware-update',
      'ru': 'Обновление прошивки',
    },
    'Board link ready': {
      'zh-Hans': '棋盘连接就绪',
      'zh-Hant': '棋盤連線就緒',
      'de': 'Brettverbindung bereit',
      'es': 'Tablero conectado',
      'fr': 'Échiquier prêt',
      'it': 'Scacchiera pronta',
      'ja': 'ボード接続準備完了',
      'ko': '보드 연결 준비됨',
      'nl': 'Bordverbinding klaar',
      'ru': 'Доска подключена',
    },
    'Waiting for piece status': {
      'zh-Hans': '正在等待棋子状态',
      'zh-Hant': '正在等待棋子狀態',
      'de': 'Warte auf Figurenstatus',
      'es': 'Esperando estado de piezas',
      'fr': 'En attente des pièces',
      'it': 'Attesa stato pezzi',
      'ja': '駒の状態を待機中',
      'ko': '기물 상태 대기 중',
      'nl': 'Wachten op stukstatus',
      'ru': 'Ожидание состояния фигур',
    },
    'Keep Chessnut Move connected. Piece positions and batteries will appear when the board reports them.':
        {
      'zh-Hans': '请保持 Chessnut Move 连接。棋盘上报后会显示棋子位置和电量。',
      'zh-Hant': '請保持 Chessnut Move 連線。棋盤回報後會顯示棋子位置和電量。',
      'de':
          'Lass Chessnut Move verbunden. Figurenpositionen und Batterien erscheinen, sobald das Brett sie meldet.',
      'es':
          'Mantén Chessnut Move conectado. Las posiciones y baterías aparecerán cuando el tablero las envíe.',
      'fr':
          'Gardez Chessnut Move connecté. Les positions et batteries apparaîtront quand l’échiquier les transmettra.',
      'it':
          'Mantieni Chessnut Move connesso. Posizioni e batterie appariranno quando la scacchiera le invia.',
      'ja': 'Chessnut Move を接続したままにしてください。ボードから報告されると駒の位置と電池が表示されます。',
      'ko': 'Chessnut Move 연결을 유지하세요. 보드가 보고하면 기물 위치와 배터리가 표시됩니다.',
      'nl':
          'Houd Chessnut Move verbonden. Stukposities en batterijen verschijnen zodra het bord ze meldt.',
      'ru':
          'Оставьте Chessnut Move подключенным. Позиции фигур и заряд появятся после ответа доски.',
    },
    'Continue learning': {
      'zh-Hans': '继续学习',
      'zh-Hant': '繼續學習',
      'de': 'Weiterlernen',
      'es': 'Continuar lección',
      'fr': 'Continuer',
      'it': 'Continua',
      'ja': '学習を続ける',
      'ko': '계속 학습',
      'nl': 'Verder leren',
      'ru': 'Продолжить обучение',
    },
    'Learn with your board': {
      'zh-Hans': '用棋盘学习',
      'zh-Hant': '用棋盤學習',
      'de': 'Mit dem Brett lernen',
      'es': 'Aprende con tu tablero',
      'fr': 'Apprendre avec l’échiquier',
      'it': 'Impara con la scacchiera',
      'ja': 'ボードで学ぶ',
      'ko': '보드로 배우기',
      'nl': 'Leren met je bord',
      'ru': 'Учиться с доской',
    },
    'Videos pause for hands-on checkpoints.': {
      'zh-Hans': '视频会在实操检查点暂停。',
      'zh-Hant': '影片會在實作檢查點暫停。',
      'de': 'Videos pausieren für praktische Checkpoints.',
      'es': 'Los videos se pausan en puntos prácticos.',
      'fr': 'Les vidéos s’arrêtent aux étapes pratiques.',
      'it': 'I video si fermano ai passaggi pratici.',
      'ja': '動画は実践チェックポイントで一時停止します。',
      'ko': '영상은 실습 체크포인트에서 일시정지됩니다.',
      'nl': 'Video’s pauzeren bij oefenstappen.',
      'ru': 'Видео останавливается на практических шагах.',
    },
    'Checkpoints can resume automatically when the position matches.': {
      'zh-Hans': '局面匹配后，检查点可自动继续。',
      'zh-Hant': '局面符合後，檢查點可自動繼續。',
      'de': 'Checkpoints können bei passender Stellung automatisch fortsetzen.',
      'es': 'Los puntos continúan cuando la posición coincide.',
      'fr': 'Les étapes reprennent quand la position correspond.',
      'it': 'I checkpoint riprendono quando la posizione coincide.',
      'ja': '局面が一致するとチェックポイントは自動で再開できます。',
      'ko': '포지션이 맞으면 체크포인트가 자동으로 이어집니다.',
      'nl': 'Checkpoints gaan door wanneer de stelling klopt.',
      'ru': 'Контрольные шаги продолжаются, когда позиция совпадает.',
    },
    'Interactive lesson': {
      'zh-Hans': '互动课程',
      'zh-Hant': '互動課程',
      'de': 'Interaktive Lektion',
      'es': 'Lección interactiva',
      'fr': 'Leçon interactive',
      'it': 'Lezione interattiva',
      'ja': 'インタラクティブレッスン',
      'ko': '인터랙티브 레슨',
      'nl': 'Interactieve les',
      'ru': 'Интерактивный урок',
    },
    'Lesson board': {
      'zh-Hans': '课程棋盘',
      'zh-Hant': '課程棋盤',
      'de': 'Lektionsbrett',
      'es': 'Tablero de lección',
      'fr': 'Échiquier de leçon',
      'it': 'Scacchiera lezione',
      'ja': 'レッスンボード',
      'ko': '레슨 보드',
      'nl': 'Lesbord',
      'ru': 'Доска урока',
    },
    'Watch the video. The board will pause when a move is needed.': {
      'zh-Hans': '观看视频。需要走棋时，棋盘会暂停。',
      'zh-Hant': '觀看影片。需要走棋時，棋盤會暫停。',
      'de': 'Sieh das Video. Das Brett pausiert, wenn ein Zug nötig ist.',
      'es': 'Mira el video. El tablero pausa cuando hace falta mover.',
      'fr': 'Regardez la vidéo. L’échiquier pause quand un coup est requis.',
      'it': 'Guarda il video. La scacchiera pausa quando serve una mossa.',
      'ja': '動画を見てください。手が必要になるとボードが一時停止します。',
      'ko': '영상을 보세요. 수가 필요하면 보드가 일시정지됩니다.',
      'nl': 'Bekijk de video. Het bord pauzeert wanneer een zet nodig is.',
      'ru': 'Смотрите видео. Доска остановится, когда нужен ход.',
    },
    'Canceling': {
      'zh-Hans': '正在取消',
      'zh-Hant': '正在取消',
      'de': 'Abbrechen...',
      'es': 'Cancelando',
      'fr': 'Annulation',
      'it': 'Annullamento',
      'ja': 'キャンセル中',
      'ko': '취소 중',
      'nl': 'Annuleren',
      'ru': 'Отмена',
    },
    'Deleting': {
      'zh-Hans': '正在删除',
      'zh-Hant': '正在刪除',
      'de': 'Löschen...',
      'es': 'Eliminando',
      'fr': 'Suppression',
      'it': 'Eliminazione',
      'ja': '削除中',
      'ko': '삭제 중',
      'nl': 'Verwijderen',
      'ru': 'Удаление',
    },
    'Low battery': {
      'zh-Hans': '电量低',
      'zh-Hant': '電量低',
      'de': 'Niedriger Akku',
      'es': 'Batería baja',
      'fr': 'Batterie faible',
      'it': 'Batteria scarica',
      'ja': '電池残量低下',
      'ko': '배터리 부족',
      'nl': 'Lage batterij',
      'ru': 'Низкий заряд',
    },
    'What went wrong?': {
      'zh-Hans': '遇到了什么问题？',
      'zh-Hant': '遇到了什麼問題？',
      'de': 'Was ist passiert?',
      'es': '¿Qué salió mal?',
      'fr': 'Que s’est-il passé ?',
      'it': 'Cosa non ha funzionato?',
      'ja': '何が起きましたか？',
      'ko': '무슨 문제가 있었나요?',
      'nl': 'Wat ging er mis?',
      'ru': 'Что пошло не так?',
    },
    'Add screenshot or video': {
      'zh-Hans': '添加截图或视频',
      'zh-Hant': '新增截圖或影片',
      'de': 'Screenshot oder Video hinzufügen',
      'es': 'Añadir captura o video',
      'fr': 'Ajouter capture ou vidéo',
      'it': 'Aggiungi screenshot o video',
      'ja': 'スクリーンショットまたは動画を追加',
      'ko': '스크린샷 또는 영상 추가',
      'nl': 'Screenshot of video toevoegen',
      'ru': 'Добавить снимок или видео',
    },
    'Minutes': {
      'zh-Hans': '分钟',
      'zh-Hant': '分鐘',
      'de': 'Minuten',
      'es': 'Minutos',
      'fr': 'Durée en minutes',
      'it': 'Minuti',
      'ja': '分',
      'ko': '분',
      'nl': 'Minuten',
      'ru': 'Минуты',
    },
    'Play style': {
      'zh-Hans': '下棋风格',
      'zh-Hant': '下棋風格',
      'de': 'Spielstil',
      'es': 'Estilo de juego',
      'fr': 'Style de jeu',
      'it': 'Stile di gioco',
      'ja': 'プレイスタイル',
      'ko': '플레이 스타일',
      'nl': 'Speelstijl',
      'ru': 'Стиль игры',
    },
    'Official no-search Maia. More human-distribution faithful, but may allow obvious mistakes.':
        {
      'zh-Hans': '官方无搜索 Maia。更贴近人类走法分布，但可能会出现明显失误。',
      'zh-Hant': '官方無搜尋 Maia。更貼近人類走法分布，但可能會出現明顯失誤。',
      'de':
          'Offizielles Maia ohne Suche. Näher an menschlichen Zügen, kann aber klare Fehler zulassen.',
      'es':
          'Maia oficial sin búsqueda. Más fiel al juego humano, pero puede permitir errores obvios.',
      'fr':
          'Maia officiel sans recherche. Plus humain, mais peut laisser des erreurs évidentes.',
      'it':
          'Maia ufficiale senza ricerca. Più fedele al gioco umano, ma può fare errori evidenti.',
      'ja': '公式の探索なし Maia。人間らしい分布に近い一方で、明らかなミスを許すことがあります。',
      'ko': '공식 무탐색 Maia입니다. 사람의 수 분포에 가깝지만 명백한 실수가 나올 수 있습니다.',
      'nl':
          'Officiële Maia zonder zoekdiepte. Menselijker, maar duidelijke fouten kunnen voorkomen.',
      'ru':
          'Официальная Maia без поиска. Ближе к человеческим ходам, но возможны очевидные ошибки.',
    },
    'More stable Maia play with a small search to reduce obvious blunders.': {
      'zh-Hans': '加入少量搜索，让 Maia 更稳定，减少明显昏招。',
      'zh-Hant': '加入少量搜尋，讓 Maia 更穩定，減少明顯昏招。',
      'de': 'Stabileres Maia-Spiel mit kleiner Suche gegen klare Patzer.',
      'es':
          'Maia más estable con una búsqueda breve para reducir errores obvios.',
      'fr':
          'Maia plus stable avec une courte recherche contre les grosses erreurs.',
      'it':
          'Maia più stabile con una piccola ricerca per ridurre errori evidenti.',
      'ja': '小さな探索で Maia を安定させ、明らかな悪手を減らします。',
      'ko': '작은 탐색으로 Maia를 더 안정화해 명백한 실수를 줄입니다.',
      'nl': 'Stabielere Maia met kleine zoekslag tegen duidelijke blunders.',
      'ru': 'Более стабильная Maia с малым поиском против грубых ошибок.',
    },
    'Tactical depth': {
      'zh-Hans': '战术深度',
      'zh-Hant': '戰術深度',
      'de': 'Taktische Tiefe',
      'es': 'Profundidad táctica',
      'fr': 'Profondeur tactique',
      'it': 'Profondità tattica',
      'ja': '戦術深度',
      'ko': '전술 깊이',
      'nl': 'Tactische diepte',
      'ru': 'Тактическая глубина',
    },
    'Higher depth feels stronger, but less like raw Maia Elo.': {
      'zh-Hans': '深度越高越强，但会更不像原始 Maia Elo。',
      'zh-Hant': '深度越高越強，但會更不像原始 Maia Elo。',
      'de': 'Höhere Tiefe wirkt stärker, aber weniger wie rohes Maia Elo.',
      'es': 'Más profundidad se siente más fuerte, pero menos Maia Elo puro.',
      'fr': 'Plus de profondeur paraît plus fort, mais moins Maia Elo pur.',
      'it': 'Più profondità sembra più forte, ma meno Maia Elo puro.',
      'ja': '深度を上げると強くなりますが、素の Maia Elo らしさは薄れます。',
      'ko': '깊이가 높을수록 강하지만 순수 Maia Elo 느낌은 줄어듭니다.',
      'nl': 'Meer diepte voelt sterker, maar minder als rauwe Maia Elo.',
      'ru': 'Большая глубина сильнее, но меньше похожа на чистый Maia Elo.',
    },
    'Sign in and choose games on Chess.com.': {
      'zh-Hans': '登录 Chess.com 后选择对局。',
      'zh-Hant': '登入 Chess.com 後選擇對局。',
      'de': 'Melde dich an und wähle Partien auf Chess.com.',
      'es': 'Inicia sesión y elige partidas en Chess.com.',
      'fr': 'Connectez-vous et choisissez des parties sur Chess.com.',
      'it': 'Accedi e scegli partite su Chess.com.',
      'ja': 'Chess.com にログインして対局を選びます。',
      'ko': 'Chess.com에 로그인하고 게임을 선택하세요.',
      'nl': 'Meld je aan en kies partijen op Chess.com.',
      'ru': 'Войдите и выберите партии на Chess.com.',
    },
    'Move control can be changed': {
      'zh-Hans': '可切换走棋控制方式',
      'zh-Hant': '可切換走棋控制方式',
      'de': 'Zugsteuerung änderbar',
      'es': 'Puedes cambiar el control',
      'fr': 'Contrôle des coups modifiable',
      'it': 'Controllo mosse modificabile',
      'ja': '手の制御方式を変更できます',
      'ko': '수 제어 방식을 바꿀 수 있습니다',
      'nl': 'Zetbesturing kan worden gewijzigd',
      'ru': 'Управление ходами можно менять',
    },
    'Place the pieces on your physical board to match the lesson position.': {
      'zh-Hans': '请在实体棋盘上摆出课程局面。',
      'zh-Hant': '請在實體棋盤上擺出課程局面。',
      'de': 'Stelle die Figuren auf deinem Brett wie in der Lektion auf.',
      'es': 'Coloca las piezas en tu tablero según la posición de la lección.',
      'fr': 'Placez les pièces sur votre échiquier selon la leçon.',
      'it': 'Metti i pezzi sulla scacchiera come nella lezione.',
      'ja': '実物のボードにレッスンの局面を並べてください。',
      'ko': '실제 보드에 레슨 포지션과 맞게 기물을 놓으세요.',
      'nl': 'Zet de stukken op je fysieke bord zoals in de les.',
      'ru': 'Расставьте фигуры на доске как в уроке.',
    },
    'USB Clock Test': {
      'zh-Hans': 'USB 棋钟测试',
      'zh-Hant': 'USB 棋鐘測試',
      'de': 'USB-Uhrtest',
      'es': 'Prueba de reloj USB',
      'fr': 'Test pendule USB',
      'it': 'Test orologio USB',
      'ja': 'USB チェスクロックテスト',
      'ko': 'USB 체스시계 테스트',
      'nl': 'USB-kloktest',
      'ru': 'Тест USB-часов',
    },
    'Connection Status': {
      'zh-Hans': '连接状态',
      'zh-Hant': '連線狀態',
      'de': 'Verbindungsstatus',
      'es': 'Estado de conexión',
      'fr': 'État de connexion',
      'it': 'Stato connessione',
      'ja': '接続状態',
      'ko': '연결 상태',
      'nl': 'Verbindingsstatus',
      'ru': 'Состояние подключения',
    },
    'Last Button Pressed': {
      'zh-Hans': '上次按下的按键',
      'zh-Hant': '上次按下的按鍵',
      'de': 'Letzte Taste',
      'es': 'Último botón',
      'fr': 'Dernier bouton',
      'it': 'Ultimo pulsante',
      'ja': '最後に押したボタン',
      'ko': '마지막으로 누른 버튼',
      'nl': 'Laatste knop',
      'ru': 'Последняя кнопка',
    },
    'Set LEFT': {
      'zh-Hans': '设为左侧',
      'zh-Hant': '設為左側',
      'de': 'Links setzen',
      'es': 'Poner izquierda',
      'fr': 'Définir gauche',
      'it': 'Imposta sinistra',
      'ja': '左に設定',
      'ko': '왼쪽 설정',
      'nl': 'Links instellen',
      'ru': 'Выбрать левую',
    },
    'Set RIGHT': {
      'zh-Hans': '设为右侧',
      'zh-Hant': '設為右側',
      'de': 'Rechts setzen',
      'es': 'Poner derecha',
      'fr': 'Définir droite',
      'it': 'Imposta destra',
      'ja': '右に設定',
      'ko': '오른쪽 설정',
      'nl': 'Rechts instellen',
      'ru': 'Выбрать правую',
    },
    'Event Log': {
      'zh-Hans': '事件日志',
      'zh-Hant': '事件記錄',
      'de': 'Ereignislog',
      'es': 'Registro de eventos',
      'fr': 'Journal des événements',
      'it': 'Registro eventi',
      'ja': 'イベントログ',
      'ko': '이벤트 로그',
      'nl': 'Gebeurtenislog',
      'ru': 'Журнал событий',
    },
    'No events yet': {
      'zh-Hans': '暂无事件',
      'zh-Hant': '暫無事件',
      'de': 'Noch keine Ereignisse',
      'es': 'Sin eventos todavía',
      'fr': 'Aucun événement',
      'it': 'Nessun evento',
      'ja': 'まだイベントはありません',
      'ko': '아직 이벤트 없음',
      'nl': 'Nog geen gebeurtenissen',
      'ru': 'Событий пока нет',
    },
    'Return after approving Lichess.': {
      'zh-Hans': '授权完成后返回。',
      'zh-Hant': '授權完成後返回。',
      'de': 'Nach der Lichess-Freigabe zurückkehren.',
      'es': 'Vuelve tras aprobar Lichess.',
      'fr': 'Revenez après l’autorisation Lichess.',
      'it': 'Torna dopo l’autorizzazione Lichess.',
      'ja': 'Lichess の承認後に戻ってください。',
      'ko': 'Lichess 승인 후 돌아오세요.',
      'nl': 'Keer terug na Lichess-goedkeuring.',
      'ru': 'Вернитесь после подтверждения Lichess.',
    },
    'Complete authorization on this page.': {
      'zh-Hans': '在此页面完成授权。',
      'zh-Hant': '在此頁面完成授權。',
      'de': 'Autorisierung auf dieser Seite abschliessen.',
      'es': 'Completa la autorizacion en esta pagina.',
      'fr': 'Terminez l’autorisation sur cette page.',
      'it': 'Completa l’autorizzazione in questa pagina.',
      'ja': 'このページで認証を完了してください。',
      'ko': '이 페이지에서 인증을 완료하세요.',
      'nl': 'Voltooi de autorisatie op deze pagina.',
      'ru': 'Завершите авторизацию на этой странице.',
    },
    'Chessnut will return automatically after Lichess shows the authorization callback.':
        {
      'zh-Hans': 'Lichess 显示授权回调后，Chessnut 会自动返回。',
      'zh-Hant': 'Lichess 顯示授權回調後，Chessnut 會自動返回。',
      'de':
          'Chessnut kehrt automatisch zurueck, nachdem Lichess den Autorisierungs-Rueckruf zeigt.',
      'es':
          'Chessnut volvera automaticamente cuando Lichess muestre la devolucion de autorizacion.',
      'fr':
          'Chessnut revient automatiquement apres l’affichage du rappel d’autorisation Lichess.',
      'it':
          'Chessnut torna automaticamente dopo il callback di autorizzazione di Lichess.',
      'ja': 'Lichess の認証コールバックが表示されると、Chessnut は自動的に戻ります。',
      'ko': 'Lichess 인증 콜백이 표시되면 Chessnut이 자동으로 돌아옵니다.',
      'nl':
          'Chessnut keert automatisch terug nadat Lichess de autorisatiecallback toont.',
      'ru':
          'Chessnut автоматически вернется после callback авторизации Lichess.',
    },
    'Report ready': {
      'zh-Hans': '报告已完成',
      'zh-Hant': '報告已完成',
      'de': 'Bericht bereit',
      'es': 'Informe listo',
      'fr': 'Rapport prêt',
      'it': 'Report pronto',
      'ja': 'レポート準備完了',
      'ko': '보고서 준비됨',
      'nl': 'Rapport klaar',
      'ru': 'Отчёт готов',
    },
    'Pre-analyzing report': {
      'zh-Hans': '正在预分析报告',
      'zh-Hant': '正在預分析報告',
      'de': 'Bericht wird voranalysiert',
      'es': 'Preanalizando informe',
      'fr': 'Pré-analyse du rapport',
      'it': 'Pre-analisi report',
      'ja': 'レポートを事前解析中',
      'ko': '보고서 사전 분석 중',
      'nl': 'Rapport vooraf analyseren',
      'ru': 'Предварительный анализ',
    },
    'Local estimate': {
      'zh-Hans': '本地估算',
      'zh-Hant': '本機估算',
      'de': 'Lokale Schätzung',
      'es': 'Estimación local',
      'fr': 'Estimation locale',
      'it': 'Stima locale',
      'ja': 'ローカル推定',
      'ko': '로컬 추정',
      'nl': 'Lokale schatting',
      'ru': 'Локальная оценка',
    },
    'Local analysis status': {
      'zh-Hans': '本地分析状态',
      'zh-Hant': '本機分析狀態',
      'de': 'Lokaler Analysestatus',
      'es': 'Estado de análisis local',
      'fr': 'État de l’analyse locale',
      'it': 'Stato analisi locale',
      'ja': 'ローカル解析状態',
      'ko': '로컬 분석 상태',
      'nl': 'Lokale analysestatus',
      'ru': 'Статус локального анализа',
    },
    'Stockfish analysis in progress': {
      'zh-Hans': 'Stockfish 正在分析',
      'zh-Hant': 'Stockfish 正在分析',
      'de': 'Stockfish-Analyse läuft',
      'es': 'Stockfish está analizando',
      'fr': 'Analyse Stockfish en cours',
      'it': 'Analisi Stockfish in corso',
      'ja': 'Stockfish 解析中',
      'ko': 'Stockfish 분석 중',
      'nl': 'Stockfish-analyse loopt',
      'ru': 'Stockfish анализирует',
    },
    'Preparing PGN positions for evaluation.': {
      'zh-Hans': '正在准备要评估的 PGN 局面。',
      'zh-Hant': '正在準備要評估的 PGN 局面。',
      'de': 'PGN-Stellungen werden vorbereitet.',
      'es': 'Preparando posiciones PGN.',
      'fr': 'Préparation des positions PGN.',
      'it': 'Preparazione posizioni PGN.',
      'ja': '評価用の PGN 局面を準備中です。',
      'ko': '평가할 PGN 포지션 준비 중입니다.',
      'nl': 'PGN-stellingen voorbereiden.',
      'ru': 'Подготовка позиций PGN.',
    },
    'Solved puzzles add points after sync': {
      'zh-Hans': '解题同步后会增加积分',
      'zh-Hant': '解題同步後會增加積分',
      'de': 'Geloeste Aufgaben geben nach Sync Punkte',
      'es': 'Los puzzles resueltos suman puntos tras sincronizar',
      'fr': 'Les puzzles resolus ajoutent des points apres synchro',
      'it': 'I puzzle risolti aggiungono punti dopo la sincronizzazione',
      'ja': '解いたパズルは同期後にポイントが加算されます',
      'ko': '푼 퍼즐은 동기화 후 포인트가 추가됩니다',
      'nl': 'Opgeloste puzzels geven punten na synchronisatie',
      'ru': 'Решенные задачи дают баллы после синхронизации',
    },
    'Loading puzzle database...': {
      'zh-Hans': '正在加载题库...',
      'zh-Hant': '正在載入題庫...',
      'de': 'Aufgabendatenbank wird geladen...',
      'es': 'Cargando base de puzzles...',
      'fr': 'Chargement de la base de puzzles...',
      'it': 'Caricamento database puzzle...',
      'ja': 'パズルデータベースを読み込み中...',
      'ko': '퍼즐 데이터베이스 로드 중...',
      'nl': 'Puzzeldatabase laden...',
      'ru': 'Загрузка базы задач...',
    },
    'One theme': {
      'zh-Hans': '一个主题',
      'zh-Hant': '一個主題',
      'de': 'Ein Thema',
      'es': 'Un tema',
      'fr': 'Un theme',
      'it': 'Un tema',
      'ja': '1つのテーマ',
      'ko': '테마 1개',
      'nl': 'Een thema',
      'ru': 'Одна тема',
    },
    'This FEN is not legal.': {
      'zh-Hans': '这个 FEN 不合法。',
      'zh-Hant': '這個 FEN 不合法。',
      'de': 'Dieses FEN ist ungültig.',
      'es': 'Este FEN no es legal.',
      'fr': 'Ce FEN n’est pas valide.',
      'it': 'Questo FEN non è valido.',
      'ja': 'この FEN は有効ではありません。',
      'ko': '이 FEN은 유효하지 않습니다.',
      'nl': 'Deze FEN is ongeldig.',
      'ru': 'Этот FEN недопустим.',
    },
    'Paste a valid board FEN before sending.': {
      'zh-Hans': '发送前请粘贴有效的棋盘 FEN。',
      'zh-Hant': '送出前請貼上有效的棋盤 FEN。',
      'de': 'Füge vor dem Senden eine gültige Brett-FEN ein.',
      'es': 'Pega un FEN válido antes de enviar.',
      'fr': 'Collez un FEN valide avant l’envoi.',
      'it': 'Incolla un FEN valido prima di inviare.',
      'ja': '送信前に有効なボード FEN を貼り付けてください。',
      'ko': '보내기 전에 유효한 보드 FEN을 붙여넣으세요.',
      'nl': 'Plak een geldige bord-FEN voordat je verzendt.',
      'ru': 'Вставьте допустимый FEN доски перед отправкой.',
    },
    'Board not connected': {
      'zh-Hans': '棋盘未连接',
      'zh-Hant': '棋盤未連線',
      'de': 'Brett nicht verbunden',
      'es': 'Tablero no conectado',
      'fr': 'Échiquier non connecté',
      'it': 'Scacchiera non connessa',
      'ja': 'ボード未接続',
      'ko': '보드가 연결되지 않음',
      'nl': 'Bord niet verbonden',
      'ru': 'Доска не подключена',
    },
    'Connect a physical board before sending FEN.': {
      'zh-Hans': '发送 FEN 前请先连接实体棋盘。',
      'zh-Hant': '送出 FEN 前請先連接實體棋盤。',
      'de': 'Verbinde ein physisches Brett, bevor du FEN sendest.',
      'es': 'Conecta un tablero físico antes de enviar FEN.',
      'fr': 'Connectez un échiquier physique avant d’envoyer le FEN.',
      'it': 'Connetti una scacchiera fisica prima di inviare il FEN.',
      'ja': 'FEN を送信する前に物理ボードを接続してください。',
      'ko': 'FEN을 보내기 전에 실제 보드를 연결하세요.',
      'nl': 'Verbind een fysiek bord voordat je FEN verzendt.',
      'ru': 'Подключите физическую доску перед отправкой FEN.',
    },
    'FEN send failed': {
      'zh-Hans': 'FEN 发送失败',
      'zh-Hant': 'FEN 傳送失敗',
      'de': 'FEN konnte nicht gesendet werden',
      'es': 'No se pudo enviar el FEN',
      'fr': 'Échec de l’envoi du FEN',
      'it': 'Invio FEN non riuscito',
      'ja': 'FEN の送信に失敗しました',
      'ko': 'FEN 전송 실패',
      'nl': 'FEN verzenden mislukt',
      'ru': 'Не удалось отправить FEN',
    },
    'The app preview updated and the physical board now guides the setup.': {
      'zh-Hans': 'App 预览已更新，实体棋盘会引导摆子。',
      'zh-Hant': 'App 預覽已更新，實體棋盤會引導擺子。',
      'de':
          'Die App-Vorschau wurde aktualisiert; das Brett führt nun den Aufbau.',
      'es':
          'La vista previa se actualizó y el tablero físico guía la posición.',
      'fr':
          'L’aperçu est à jour et l’échiquier physique guide la mise en place.',
      'it':
          'L’anteprima è aggiornata e la scacchiera fisica guida la posizione.',
      'ja': 'アプリのプレビューが更新され、物理ボードが配置を案内します。',
      'ko': '앱 미리보기가 업데이트되었고 실제 보드가 배치를 안내합니다.',
      'nl':
          'De app-preview is bijgewerkt en het fysieke bord begeleidt de opstelling.',
      'ru': 'Предпросмотр обновлён, физическая доска подскажет расстановку.',
    },
    'The physical board did not accept the FEN command.': {
      'zh-Hans': '实体棋盘未接受 FEN 指令。',
      'zh-Hant': '實體棋盤未接受 FEN 指令。',
      'de': 'Das physische Brett hat den FEN-Befehl nicht angenommen.',
      'es': 'El tablero físico no aceptó el comando FEN.',
      'fr': 'L’échiquier physique n’a pas accepté la commande FEN.',
      'it': 'La scacchiera fisica non ha accettato il comando FEN.',
      'ja': '物理ボードが FEN コマンドを受け付けませんでした。',
      'ko': '실제 보드가 FEN 명령을 받지 않았습니다.',
      'nl': 'Het fysieke bord accepteerde de FEN-opdracht niet.',
      'ru': 'Физическая доска не приняла команду FEN.',
    },
    'Move delay': {
      'zh-Hans': '走子延迟',
      'zh-Hant': '走子延遲',
      'de': 'Zugverzögerung',
      'es': 'Retraso de jugada',
      'fr': 'Délai des coups',
      'it': 'Ritardo mossa',
      'ja': '手の遅延',
      'ko': '수 지연',
      'nl': 'Zetvertraging',
      'ru': 'Задержка хода',
    },
    'Automatic switch press': {
      'zh-Hans': '自动按下 switch',
      'zh-Hant': '自動按下 switch',
      'de': 'Automatischer Switch-Druck',
      'es': 'Pulsación automática del switch',
      'fr': 'Appui automatique du switch',
      'it': 'Pressione automatica dello switch',
      'ja': 'switch の自動押下',
      'ko': 'switch 자동 누름',
      'nl': 'Automatisch switch indrukken',
      'ru': 'Автонажатие switch',
    },
    'Choose when the clock hardware switch is pressed for you.': {
      'zh-Hans': '选择什么时候由系统自动按下棋钟硬件 switch。',
      'zh-Hant': '選擇什麼時候由系統自動按下棋鐘硬體 switch。',
      'de':
          'Wähle, wann der Hardware-Switch der Uhr automatisch gedrückt wird.',
      'es': 'Elige cuándo se pulsa automáticamente el switch del reloj.',
      'fr': 'Choisissez quand le switch matériel de la pendule est pressé.',
      'it': 'Scegli quando premere automaticamente lo switch dell’orologio.',
      'ja': '時計のハードウェア switch をいつ自動で押すか選びます。',
      'ko': '시계 하드웨어 switch를 언제 자동으로 누를지 선택하세요.',
      'nl':
          'Kies wanneer de hardware-switch van de klok automatisch wordt ingedrukt.',
      'ru': 'Выберите, когда аппаратный switch часов нажимается автоматически.',
    },
    'Confirm moves with switch': {
      'zh-Hans': '用 switch 确认走子',
      'zh-Hant': '用 switch 確認走子',
      'de': 'Züge mit switch bestätigen',
      'es': 'Confirmar jugadas con switch',
      'fr': 'Confirmer les coups avec switch',
      'it': 'Conferma mosse con switch',
      'ja': 'switch で手を確定',
      'ko': 'switch로 수 확인',
      'nl': 'Zetten bevestigen met switch',
      'ru': 'Подтверждать ходы через switch',
    },
    'Hold board moves until the clock switch is pressed.': {
      'zh-Hans': '棋盘走子会暂存，直到按下棋钟 switch 后再提交。',
      'zh-Hant': '棋盤走子會暫存，直到按下棋鐘 switch 後再提交。',
      'de': 'Brettzüge warten, bis der Uhr-Switch gedrückt wird.',
      'es': 'Las jugadas del tablero esperan hasta pulsar el switch del reloj.',
      'fr':
          'Les coups du plateau attendent l’appui sur le switch de la pendule.',
      'it': 'Le mosse attendono finché non premi lo switch dell’orologio.',
      'ja': 'ボード上の手は時計の switch が押されるまで保留されます。',
      'ko': '보드 수는 시계 switch를 누를 때까지 보류됩니다.',
      'nl': 'Bordzetten wachten tot de klok-switch wordt ingedrukt.',
      'ru': 'Ходы с доски ждут нажатия switch часов.',
    },
    'No firmware update is available from the connected board service right now.':
        {
      'zh-Hans': '当前连接的棋盘服务没有可用固件更新。',
      'zh-Hant': '目前連線的棋盤服務沒有可用韌體更新。',
      'de': 'Der verbundene Brettdienst hat derzeit kein Firmware-Update.',
      'es':
          'El servicio del tablero conectado no tiene actualización disponible.',
      'fr': 'Aucune mise à jour du firmware n’est disponible pour l’instant.',
      'it': 'Nessun aggiornamento firmware disponibile al momento.',
      'ja': '接続中のボードサービスには現在利用可能な更新がありません。',
      'ko': '현재 연결된 보드 서비스에 사용 가능한 펌웨어 업데이트가 없습니다.',
      'nl':
          'Er is nu geen firmware-update beschikbaar voor het verbonden bord.',
      'ru': 'Для подключённой доски сейчас нет обновления прошивки.',
    },
    'Connect a board to change live hardware settings.': {
      'zh-Hans': '连接棋盘后即可修改实时硬件设置。',
      'zh-Hant': '連接棋盤後即可修改即時硬體設定。',
      'de': 'Verbinde ein Brett, um Live-Hardwareeinstellungen zu ändern.',
      'es': 'Conecta un tablero para cambiar ajustes de hardware en vivo.',
      'fr': 'Connectez un échiquier pour modifier les réglages matériels.',
      'it': 'Connetti una scacchiera per modificare le impostazioni hardware.',
      'ja': 'ライブのハードウェア設定を変更するにはボードを接続してください。',
      'ko': '실시간 하드웨어 설정을 바꾸려면 보드를 연결하세요.',
      'nl': 'Verbind een bord om live hardware-instellingen te wijzigen.',
      'ru': 'Подключите доску, чтобы менять аппаратные настройки.',
    },
    'No piece status yet': {
      'zh-Hans': '暂无棋子状态',
      'zh-Hant': '暫無棋子狀態',
      'de': 'Noch kein Figurenstatus',
      'es': 'Aún sin estado de piezas',
      'fr': 'Aucun état de pièce',
      'it': 'Nessuno stato pezzi',
      'ja': 'まだ駒の状態はありません',
      'ko': '아직 기물 상태가 없습니다',
      'nl': 'Nog geen stukstatus',
      'ru': 'Статуса фигур пока нет',
    },
    'Refresh courses': {
      'zh-Hans': '刷新课程',
      'zh-Hant': '重新整理課程',
      'de': 'Kurse aktualisieren',
      'es': 'Actualizar cursos',
      'fr': 'Actualiser les cours',
      'it': 'Aggiorna corsi',
      'ja': 'コースを更新',
      'ko': '코스 새로고침',
      'nl': 'Cursussen vernieuwen',
      'ru': 'Обновить курсы',
    },
    'Loading courses': {
      'zh-Hans': '正在加载课程',
      'zh-Hant': '正在載入課程',
      'de': 'Kurse werden geladen',
      'es': 'Cargando cursos',
      'fr': 'Chargement des cours',
      'it': 'Caricamento corsi',
      'ja': 'コースを読み込み中',
      'ko': '코스 로딩 중',
      'nl': 'Cursussen laden',
      'ru': 'Загрузка курсов',
    },
    'No courses found': {
      'zh-Hans': '未找到课程',
      'zh-Hant': '找不到課程',
      'de': 'Keine Kurse gefunden',
      'es': 'No se encontraron cursos',
      'fr': 'Aucun cours trouvé',
      'it': 'Nessun corso trovato',
      'ja': 'コースが見つかりません',
      'ko': '코스를 찾을 수 없습니다',
      'nl': 'Geen cursussen gevonden',
      'ru': 'Курсы не найдены',
    },
    'Preparing lesson': {
      'zh-Hans': '正在准备课程',
      'zh-Hant': '正在準備課程',
      'de': 'Lektion wird vorbereitet',
      'es': 'Preparando lección',
      'fr': 'Préparation de la leçon',
      'it': 'Preparazione lezione',
      'ja': 'レッスンを準備中',
      'ko': '레슨 준비 중',
      'nl': 'Les voorbereiden',
      'ru': 'Подготовка урока',
    },
    'Send report': {
      'zh-Hans': '发送报告',
      'zh-Hant': '傳送報告',
      'de': 'Bericht senden',
      'es': 'Enviar informe',
      'fr': 'Envoyer le rapport',
      'it': 'Invia report',
      'ja': 'レポートを送信',
      'ko': '보고서 보내기',
      'nl': 'Rapport verzenden',
      'ru': 'Отправить отчёт',
    },
    'Sending': {
      'zh-Hans': '正在发送',
      'zh-Hant': '正在傳送',
      'de': 'Senden...',
      'es': 'Enviando',
      'fr': 'Envoi',
      'it': 'Invio',
      'ja': '送信中',
      'ko': '보내는 중',
      'nl': 'Verzenden',
      'ru': 'Отправка',
    },
    'Local Maia weights, 1100-1900 strength': {
      'zh-Hans': '本地 Maia 权重，强度 1100-1900',
      'zh-Hant': '本地 Maia 權重，強度 1100-1900',
      'de': 'Lokale Maia-Gewichte, Stärke 1100-1900',
      'es': 'Pesos Maia locales, fuerza 1100-1900',
      'fr': 'Poids Maia locaux, force 1100-1900',
      'it': 'Pesi Maia locali, forza 1100-1900',
      'ja': 'ローカル Maia 重み、強さ 1100-1900',
      'ko': '로컬 Maia 가중치, 강도 1100-1900',
      'nl': 'Lokale Maia-gewichten, sterkte 1100-1900',
      'ru': 'Локальные веса Maia, сила 1100-1900',
    },
    'Maia 3 strength': {
      'zh-Hans': 'Maia 3 强度',
      'zh-Hant': 'Maia 3 強度',
      'de': 'Maia-3-Stärke',
      'es': 'Fuerza Maia 3',
      'fr': 'Force Maia 3',
      'it': 'Forza Maia 3',
      'ja': 'Maia 3 の強さ',
      'ko': 'Maia 3 강도',
      'nl': 'Maia 3-sterkte',
      'ru': 'Сила Maia 3',
    },
    'Linked accounts': {
      'zh-Hans': '已绑定账号',
      'zh-Hant': '已綁定帳號',
      'de': 'Verknüpfte Konten',
      'es': 'Cuentas vinculadas',
      'fr': 'Comptes liés',
      'it': 'Account collegati',
      'ja': '連携済みアカウント',
      'ko': '연결된 계정',
      'nl': 'Gekoppelde accounts',
      'ru': 'Связанные аккаунты',
    },
    'Linked account updated.': {
      'zh-Hans': '账号绑定已更新。',
      'zh-Hant': '帳號綁定已更新。',
      'de': 'Verknüpftes Konto aktualisiert.',
      'es': 'Cuenta vinculada actualizada.',
      'fr': 'Compte lié mis à jour.',
      'it': 'Account collegato aggiornato.',
      'ja': '連携アカウントを更新しました。',
      'ko': '연결된 계정이 업데이트되었습니다.',
      'nl': 'Gekoppeld account bijgewerkt.',
      'ru': 'Связанный аккаунт обновлён.',
    },
    'Keep linked': {
      'zh-Hans': '保持绑定',
      'zh-Hant': '保持綁定',
      'de': 'Verknüpfung behalten',
      'es': 'Mantener vinculado',
      'fr': 'Garder le lien',
      'it': 'Mantieni collegato',
      'ja': '連携を維持',
      'ko': '연결 유지',
      'nl': 'Gekoppeld houden',
      'ru': 'Оставить связь',
    },
    'Unlink Lichess': {
      'zh-Hans': '解绑 Lichess',
      'zh-Hant': '解除 Lichess 綁定',
      'de': 'Lichess trennen',
      'es': 'Desvincular Lichess',
      'fr': 'Dissocier Lichess',
      'it': 'Scollega Lichess',
      'ja': 'Lichess 連携を解除',
      'ko': 'Lichess 연결 해제',
      'nl': 'Lichess ontkoppelen',
      'ru': 'Отвязать Lichess',
    },
    'Connected as': {
      'zh-Hans': '当前绑定',
      'zh-Hant': '目前綁定',
      'de': 'Verbunden als',
      'es': 'Conectado como',
      'fr': 'Connecté en tant que',
      'it': 'Connesso come',
      'ja': '接続中',
      'ko': '연결된 계정',
      'nl': 'Verbonden als',
      'ru': 'Подключено как',
    },
    'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.':
        {
      'zh-Hans': '你的 Chessnut 账号已绑定 Lichess。你可以保持绑定，或先解绑后授权另一个 Lichess 账号。',
      'zh-Hant': '你的 Chessnut 帳號已綁定 Lichess。你可以保持綁定，或先解除後授權另一個 Lichess 帳號。',
      'de':
          'Dein Chessnut-Konto ist bereits mit Lichess verbunden. Du kannst die Verbindung behalten oder trennen, um ein anderes Lichess-Konto zu autorisieren.',
      'es':
          'Tu cuenta de Chessnut ya está conectada a Lichess. Puedes mantener el vínculo o desvincularla para autorizar otra cuenta de Lichess.',
      'fr':
          'Votre compte Chessnut est déjà connecté à Lichess. Vous pouvez garder ce lien ou le dissocier pour autoriser un autre compte Lichess.',
      'it':
          'Il tuo account Chessnut è già collegato a Lichess. Puoi mantenere il collegamento o scollegarlo per autorizzare un altro account Lichess.',
      'ja':
          'Chessnut アカウントはすでに Lichess と連携しています。このまま維持するか、別の Lichess アカウントを認証するために解除できます。',
      'ko':
          'Chessnut 계정은 이미 Lichess와 연결되어 있습니다. 연결을 유지하거나 다른 Lichess 계정을 인증하려면 연결을 해제하세요.',
      'nl':
          'Je Chessnut-account is al verbonden met Lichess. Je kunt de koppeling behouden of ontkoppelen om een ander Lichess-account te autoriseren.',
      'ru':
          'Ваш аккаунт Chessnut уже связан с Lichess. Можно оставить связь или отвязать её, чтобы авторизовать другой аккаунт Lichess.',
    },
    'Models': {
      'zh-Hans': '模型',
      'zh-Hant': '模型',
      'de': 'Modelle',
      'es': 'Modelos',
      'fr': 'Modèles',
      'it': 'Modelli',
      'ja': 'モデル',
      'ko': '모델',
      'nl': 'Modellen',
      'ru': 'Модели',
    },
    'Spend 100 points?': {
      'zh-Hans': '消耗 100 积分？',
      'zh-Hant': '消耗 100 積分？',
      'de': '100 Punkte ausgeben?',
      'es': '¿Gastar 100 puntos?',
      'fr': 'Dépenser 100 points ?',
      'it': 'Usare 100 punti?',
      'ja': '100 ポイントを使いますか？',
      'ko': '100 포인트를 사용할까요?',
      'nl': '100 punten besteden?',
      'ru': 'Списать 100 баллов?',
    },
    'Grandeur uses wallet points for the LLM coach review.': {
      'zh-Hans': 'Grandeur 会使用钱包积分生成 AI 教练复盘。',
      'zh-Hant': 'Grandeur 會使用錢包積分生成 AI 教練復盤。',
      'de': 'Grandeur nutzt Wallet-Punkte für die KI-Coach-Analyse.',
      'es': 'Grandeur usa puntos del wallet para la revisión del coach IA.',
      'fr': 'Grandeur utilise les points du wallet pour la revue du coach IA.',
      'it': 'Grandeur usa i punti wallet per la revisione coach IA.',
      'ja': 'Grandeur は AI コーチレビューにウォレットポイントを使います。',
      'ko': 'Grandeur는 AI 코치 리뷰에 지갑 포인트를 사용합니다.',
      'nl': 'Grandeur gebruikt walletpunten voor de AI-coachreview.',
      'ru': 'Grandeur использует баллы кошелька для AI-разбора.',
    },
    'Current balance': {
      'zh-Hans': '当前余额',
      'zh-Hant': '目前餘額',
      'de': 'Aktueller Stand',
      'es': 'Saldo actual',
      'fr': 'Solde actuel',
      'it': 'Saldo attuale',
      'ja': '現在の残高',
      'ko': '현재 잔액',
      'nl': 'Huidig saldo',
      'ru': 'Текущий баланс',
    },
    'Original cost': {
      'zh-Hans': '原价',
      'zh-Hant': '原價',
      'de': 'Normalpreis',
      'es': 'Coste original',
      'fr': 'Coût initial',
      'it': 'Costo originale',
      'ja': '通常価格',
      'ko': '기본 비용',
      'nl': 'Oorspronkelijke kosten',
      'ru': 'Обычная стоимость',
    },
    'Member discount': {
      'zh-Hans': '会员优惠',
      'zh-Hant': '會員優惠',
      'de': 'Mitgliedsrabatt',
      'es': 'Descuento de miembro',
      'fr': 'Remise membre',
      'it': 'Sconto membro',
      'ja': '会員割引',
      'ko': '회원 할인',
      'nl': 'Ledenkorting',
      'ru': 'Скидка участника',
    },
    'Pay today': {
      'zh-Hans': '今日支付',
      'zh-Hant': '今日支付',
      'de': 'Heute zahlen',
      'es': 'Pagar hoy',
      'fr': 'À payer aujourd’hui',
      'it': 'Paghi oggi',
      'ja': '今回の支払い',
      'ko': '오늘 결제',
      'nl': 'Vandaag betalen',
      'ru': 'К оплате сегодня',
    },
    'Balance after review': {
      'zh-Hans': '复盘后余额',
      'zh-Hant': '復盤後餘額',
      'de': 'Stand nach Review',
      'es': 'Saldo tras la revisión',
      'fr': 'Solde après revue',
      'it': 'Saldo dopo la review',
      'ja': 'レビュー後の残高',
      'ko': '리뷰 후 잔액',
      'nl': 'Saldo na review',
      'ru': 'Баланс после разбора',
    },
    'Start Grandeur review?': {
      'zh-Hans': '开始 Grandeur 复盘？',
      'zh-Hant': '開始 Grandeur 復盤？',
      'de': 'Grandeur-Review starten?',
      'es': '¿Iniciar revisión Grandeur?',
      'fr': 'Lancer la revue Grandeur ?',
      'it': 'Avviare la review Grandeur?',
      'ja': 'Grandeur レビューを開始しますか？',
      'ko': 'Grandeur 리뷰를 시작할까요?',
      'nl': 'Grandeur-review starten?',
      'ru': 'Начать разбор Grandeur?',
    },
    'Start Grandeur review': {
      'zh-Hans': '开始 Grandeur 复盘',
      'zh-Hant': '開始 Grandeur 復盤',
      'de': 'Grandeur-Review starten',
      'es': 'Iniciar revisión Grandeur',
      'fr': 'Lancer la revue Grandeur',
      'it': 'Avvia review Grandeur',
      'ja': 'Grandeur レビューを開始',
      'ko': 'Grandeur 리뷰 시작',
      'nl': 'Grandeur-review starten',
      'ru': 'Начать разбор Grandeur',
    },
    'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.':
        {
      'zh-Hans':
          'Grandeur 通常消耗 100 钱包积分。会员会自动优惠为 0 分；积分不足时可先去 Daily Tasks 获取更多积分。',
      'zh-Hant':
          'Grandeur 通常消耗 100 錢包積分。會員會自動優惠為 0 分；積分不足時可先去 Daily Tasks 獲取更多積分。',
      'de':
          'Grandeur kostet normalerweise 100 Wallet-Punkte. Mitglieder zahlen automatisch 0 Punkte. Fehlen Punkte, kannst du sie über Daily Tasks verdienen.',
      'es':
          'Grandeur cuesta normalmente 100 puntos del wallet. Los miembros pagan 0 puntos automáticamente. Si faltan puntos, puedes ganarlos en Daily Tasks.',
      'fr':
          'Grandeur coûte normalement 100 points wallet. Les membres paient automatiquement 0 point. Si vous manquez de points, gagnez-en dans Daily Tasks.',
      'it':
          'Grandeur costa normalmente 100 punti wallet. I membri pagano automaticamente 0 punti. Se non bastano, puoi guadagnarli in Daily Tasks.',
      'ja':
          'Grandeur は通常 100 ウォレットポイントを消費します。会員は自動的に 0 ポイントになります。不足時は Daily Tasks で獲得できます。',
      'ko':
          'Grandeur는 보통 지갑 포인트 100점을 사용합니다. 회원은 자동으로 0점이 적용됩니다. 포인트가 부족하면 Daily Tasks에서 더 얻을 수 있습니다.',
      'nl':
          'Grandeur kost normaal 100 walletpunten. Leden betalen automatisch 0 punten. Bij tekort kun je meer verdienen via Daily Tasks.',
      'ru':
          'Grandeur обычно стоит 100 баллов кошелька. Участники автоматически платят 0. Если баллов мало, заработайте их в Daily Tasks.',
    },
    'Not enough points': {
      'zh-Hans': '积分不足',
      'zh-Hant': '積分不足',
      'de': 'Nicht genug Punkte',
      'es': 'Puntos insuficientes',
      'fr': 'Points insuffisants',
      'it': 'Punti insufficienti',
      'ja': 'ポイントが足りません',
      'ko': '포인트 부족',
      'nl': 'Niet genoeg punten',
      'ru': 'Недостаточно баллов',
    },
    'Go to Daily Tasks': {
      'zh-Hans': '前往 Daily Tasks',
      'zh-Hant': '前往 Daily Tasks',
      'de': 'Zu Daily Tasks',
      'es': 'Ir a Daily Tasks',
      'fr': 'Aller à Daily Tasks',
      'it': 'Vai a Daily Tasks',
      'ja': 'Daily Tasks へ',
      'ko': 'Daily Tasks로 이동',
      'nl': 'Naar Daily Tasks',
      'ru': 'Перейти к Daily Tasks',
    },
    'Wallet unavailable': {
      'zh-Hans': '钱包暂不可用',
      'zh-Hant': '錢包暫不可用',
      'de': 'Wallet nicht verfügbar',
      'es': 'Wallet no disponible',
      'fr': 'Wallet indisponible',
      'it': 'Wallet non disponibile',
      'ja': 'ウォレットを利用できません',
      'ko': '지갑을 사용할 수 없음',
      'nl': 'Wallet niet beschikbaar',
      'ru': 'Кошелёк недоступен',
    },
    'Grandeur report generating': {
      'zh-Hans': 'Grandeur 报告生成中',
      'zh-Hant': 'Grandeur 報告生成中',
      'de': 'Grandeur-Report wird erstellt',
      'es': 'Generando informe Grandeur',
      'fr': 'Rapport Grandeur en cours',
      'it': 'Report Grandeur in creazione',
      'ja': 'Grandeur レポート生成中',
      'ko': 'Grandeur 보고서 생성 중',
      'nl': 'Grandeur-rapport wordt gemaakt',
      'ru': 'Отчёт Grandeur создаётся',
    },
    'You can leave this page. Chessnut will keep working and save the report when it is ready.':
        {
      'zh-Hans': '你可以离开此页面。Chessnut 会继续处理，并在报告完成后保存。',
      'zh-Hant': '你可以離開此頁面。Chessnut 會繼續處理，並在報告完成後保存。',
      'de':
          'Du kannst diese Seite verlassen. Chessnut arbeitet weiter und speichert den Report, sobald er fertig ist.',
      'es':
          'Puedes salir de esta página. Chessnut seguirá trabajando y guardará el informe cuando esté listo.',
      'fr':
          'Vous pouvez quitter cette page. Chessnut continue le traitement et enregistrera le rapport une fois prêt.',
      'it':
          'Puoi lasciare questa pagina. Chessnut continuerà a lavorare e salverà il report quando sarà pronto.',
      'ja': 'このページを離れても構いません。Chessnut は処理を続け、完了後にレポートを保存します。',
      'ko': '이 페이지를 떠나도 됩니다. Chessnut이 계속 처리하고 보고서가 준비되면 저장합니다.',
      'nl':
          'Je kunt deze pagina verlaten. Chessnut werkt door en bewaart het rapport zodra het klaar is.',
      'ru':
          'Можно покинуть страницу. Chessnut продолжит работу и сохранит отчёт, когда он будет готов.',
    },
    'From PGN': {
      'zh-Hans': '从 PGN 导入',
      'zh-Hant': '從 PGN 匯入',
      'de': 'Aus PGN',
      'es': 'Desde PGN',
      'fr': 'Depuis un PGN',
      'it': 'Da PGN',
      'ja': 'PGN から',
      'ko': 'PGN에서',
      'nl': 'Uit PGN',
      'ru': 'Из PGN',
    },
    'From Lichess player': {
      'zh-Hans': '从 Lichess 棋手导入',
      'zh-Hant': '從 Lichess 棋手匯入',
      'de': 'Von Lichess-Spieler',
      'es': 'Desde jugador de Lichess',
      'fr': 'Depuis un joueur Lichess',
      'it': 'Da giocatore Lichess',
      'ja': 'Lichess プレイヤーから',
      'ko': 'Lichess 선수에서',
      'nl': 'Van Lichess-speler',
      'ru': 'От игрока Lichess',
    },
    'From Chess.com username': {
      'zh-Hans': '从 Chess.com 用户名导入',
      'zh-Hant': '從 Chess.com 使用者名稱匯入',
      'de': 'Von Chess.com-Nutzername',
      'es': 'Desde usuario de Chess.com',
      'fr': 'Depuis un utilisateur Chess.com',
      'it': 'Da nome utente Chess.com',
      'ja': 'Chess.com ユーザー名から',
      'ko': 'Chess.com 사용자 이름에서',
      'nl': 'Van Chess.com-gebruikersnaam',
      'ru': 'По имени Chess.com',
    },
    'Local list': {
      'zh-Hans': '本地列表',
      'zh-Hant': '本地列表',
      'de': 'Lokale Liste',
      'es': 'Lista local',
      'fr': 'Liste locale',
      'it': 'Elenco locale',
      'ja': 'ローカル一覧',
      'ko': '로컬 목록',
      'nl': 'Lokale lijst',
      'ru': 'Локальный список',
    },
    'Cloud search failed': {
      'zh-Hans': '云端搜索失败',
      'zh-Hant': '雲端搜尋失敗',
      'de': 'Cloud-Suche fehlgeschlagen',
      'es': 'Falló la búsqueda en la nube',
      'fr': 'Recherche cloud échouée',
      'it': 'Ricerca cloud non riuscita',
      'ja': 'クラウド検索に失敗しました',
      'ko': '클라우드 검색 실패',
      'nl': 'Cloudzoekopdracht mislukt',
      'ru': 'Поиск в облаке не удался',
    },
    'Previous page': {
      'zh-Hans': '上一页',
      'zh-Hant': '上一頁',
      'de': 'Vorige Seite',
      'es': 'Página anterior',
      'fr': 'Page précédente',
      'it': 'Pagina precedente',
      'ja': '前のページ',
      'ko': '이전 페이지',
      'nl': 'Vorige pagina',
      'ru': 'Предыдущая страница',
    },
    'Next page': {
      'zh-Hans': '下一页',
      'zh-Hant': '下一頁',
      'de': 'Nächste Seite',
      'es': 'Página siguiente',
      'fr': 'Page suivante',
      'it': 'Pagina successiva',
      'ja': '次のページ',
      'ko': '다음 페이지',
      'nl': 'Volgende pagina',
      'ru': 'Следующая страница',
    },
    'Start import': {
      'zh-Hans': '开始导入',
      'zh-Hant': '開始匯入',
      'de': 'Import starten',
      'es': 'Iniciar importación',
      'fr': 'Lancer l’import',
      'it': 'Avvia importazione',
      'ja': 'インポート開始',
      'ko': '가져오기 시작',
      'nl': 'Import starten',
      'ru': 'Начать импорт',
    },
    'Delete record': {
      'zh-Hans': '删除记录',
      'zh-Hant': '刪除記錄',
      'de': 'Eintrag löschen',
      'es': 'Eliminar registro',
      'fr': 'Supprimer la partie',
      'it': 'Elimina record',
      'ja': '記録を削除',
      'ko': '기록 삭제',
      'nl': 'Record verwijderen',
      'ru': 'Удалить запись',
    },
    'Delete game record?': {
      'zh-Hans': '删除这条对局记录？',
      'zh-Hant': '刪除這筆對局記錄？',
      'de': 'Partieeintrag löschen?',
      'es': '¿Eliminar registro de partida?',
      'fr': 'Supprimer cette partie ?',
      'it': 'Eliminare il record partita?',
      'ja': '対局記録を削除しますか？',
      'ko': '게임 기록을 삭제할까요?',
      'nl': 'Partijrecord verwijderen?',
      'ru': 'Удалить запись партии?',
    },
    'This removes the saved PGN from your Chessnut account. This action cannot be undone.':
        {
      'zh-Hans': '这会从你的 Chessnut 账号中删除已保存的 PGN，且无法撤销。',
      'zh-Hant': '這會從你的 Chessnut 帳號中刪除已儲存的 PGN，且無法復原。',
      'de':
          'Damit wird die gespeicherte PGN aus deinem Chessnut-Konto entfernt. Diese Aktion kann nicht rückgängig gemacht werden.',
      'es':
          'Esto elimina el PGN guardado de tu cuenta Chessnut. Esta acción no se puede deshacer.',
      'fr':
          'Cela supprime le PGN enregistré de votre compte Chessnut. Cette action est irréversible.',
      'it':
          'Rimuove il PGN salvato dal tuo account Chessnut. L’azione non può essere annullata.',
      'ja': '保存済み PGN が Chessnut アカウントから削除されます。この操作は元に戻せません。',
      'ko': '저장된 PGN이 Chessnut 계정에서 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
      'nl':
          'Hiermee verwijder je de opgeslagen PGN uit je Chessnut-account. Dit kan niet ongedaan worden gemaakt.',
      'ru':
          'Сохранённый PGN будет удалён из аккаунта Chessnut. Это действие нельзя отменить.',
    },
    'Video lessons that pause for your Chessnut board': {
      'zh-Hans': '会为你的 Chessnut 棋盘暂停的视频课程',
      'zh-Hant': '會為你的 Chessnut 棋盤暫停的影片課程',
      'de': 'Videolektionen mit Pausen für dein Chessnut-Brett',
      'es': 'Lecciones en video que pausan para tu tablero Chessnut',
      'fr': 'Leçons vidéo avec pauses pour votre échiquier Chessnut',
      'it': 'Lezioni video che si fermano per la tua scacchiera Chessnut',
      'ja': 'Chessnut ボード操作に合わせて一時停止する動画レッスン',
      'ko': 'Chessnut 보드에 맞춰 멈추는 영상 레슨',
      'nl': 'Videolessen die pauzeren voor je Chessnut-bord',
      'ru': 'Видео уроки с паузами для доски Chessnut',
    },
    'Fetching the latest Chessnut lesson library.': {
      'zh-Hans': '正在获取最新 Chessnut 课程库。',
      'zh-Hant': '正在取得最新 Chessnut 課程庫。',
      'de': 'Die aktuelle Chessnut-Lektionsbibliothek wird geladen.',
      'es': 'Obteniendo la biblioteca de lecciones Chessnut más reciente.',
      'fr': 'Chargement de la dernière bibliothèque de leçons Chessnut.',
      'it': 'Caricamento della libreria lezioni Chessnut più recente.',
      'ja': '最新の Chessnut レッスンライブラリを取得中です。',
      'ko': '최신 Chessnut 레슨 라이브러리를 가져오는 중입니다.',
      'nl': 'De nieuwste Chessnut-lesbibliotheek wordt opgehaald.',
      'ru': 'Загружается последняя библиотека уроков Chessnut.',
    },
    'The course catalog is empty right now.': {
      'zh-Hans': '当前课程目录为空。',
      'zh-Hant': '目前課程目錄為空。',
      'de': 'Der Kurskatalog ist derzeit leer.',
      'es': 'El catálogo de cursos está vacío ahora.',
      'fr': 'Le catalogue de cours est vide pour le moment.',
      'it': 'Il catalogo dei corsi è vuoto al momento.',
      'ja': '現在、コースカタログは空です。',
      'ko': '현재 코스 카탈로그가 비어 있습니다.',
      'nl': 'De cursuscatalogus is nu leeg.',
      'ru': 'Каталог курсов сейчас пуст.',
    },
    'Board checks': {
      'zh-Hans': '棋盘检查',
      'zh-Hant': '棋盤檢查',
      'de': 'Brettchecks',
      'es': 'Comprobaciones del tablero',
      'fr': 'Contrôles échiquier',
      'it': 'Controlli scacchiera',
      'ja': 'ボード確認',
      'ko': '보드 확인',
      'nl': 'Bordchecks',
      'ru': 'Проверки доски',
    },
    'Physical board': {
      'zh-Hans': '实体棋盘',
      'zh-Hant': '實體棋盤',
      'de': 'Physisches Brett',
      'es': 'Tablero físico',
      'fr': 'Échiquier physique',
      'it': 'Scacchiera fisica',
      'ja': '物理ボード',
      'ko': '실제 보드',
      'nl': 'Fysiek bord',
      'ru': 'Физическая доска',
    },
    'Train your chess style': {
      'zh-Hans': '训练你的棋风',
      'zh-Hant': '訓練你的棋風',
      'de': 'Trainiere deinen Schachstil',
      'es': 'Entrena tu estilo de ajedrez',
      'fr': 'Entraînez votre style d’échecs',
      'it': 'Allena il tuo stile di scacchi',
      'ja': '自分の棋風をトレーニング',
      'ko': '나만의 체스 스타일 훈련',
      'nl': 'Train je schaakstijl',
      'ru': 'Тренируйте свой шахматный стиль',
    },
    'Train engines from your own games': {
      'zh-Hans': '用你自己的对局训练引擎',
      'zh-Hant': '用你自己的對局訓練引擎',
      'de': 'Trainiere Engines mit deinen eigenen Partien',
      'es': 'Entrena motores con tus propias partidas',
      'fr': 'Entraînez des moteurs avec vos propres parties',
      'it': 'Allena motori dalle tue partite',
      'ja': '自分の対局からエンジンをトレーニング',
      'ko': '내 대국으로 엔진 훈련',
      'nl': 'Train engines met je eigen partijen',
      'ru': 'Обучайте движки на своих партиях',
    },
    'Personal engine training flow': {
      'zh-Hans': '个人引擎训练流程',
      'zh-Hant': '個人引擎訓練流程',
      'de': 'Trainingsablauf für persönliche Engines',
      'es': 'Flujo de entrenamiento de motores personales',
      'fr': 'Parcours d’entraînement de moteur personnel',
      'it': 'Flusso di allenamento del motore personale',
      'ja': '個人エンジンのトレーニング手順',
      'ko': '개인 엔진 훈련 과정',
      'nl': 'Trainingsstroom voor persoonlijke engines',
      'ru': 'Процесс обучения личного движка',
    },
    'Choose your games': {
      'zh-Hans': '选择你的对局',
      'zh-Hant': '選擇你的對局',
      'de': 'Wähle deine Partien',
      'es': 'Elige tus partidas',
      'fr': 'Choisissez vos parties',
      'it': 'Scegli le tue partite',
      'ja': '対局を選択',
      'ko': '대국 선택',
      'nl': 'Kies je partijen',
      'ru': 'Выберите свои партии',
    },
    'Train safely in the cloud': {
      'zh-Hans': '在云端安全训练',
      'zh-Hant': '在雲端安全訓練',
      'de': 'Sicher in der Cloud trainieren',
      'es': 'Entrena de forma segura en la nube',
      'fr': 'Entraînez en toute sécurité dans le cloud',
      'it': 'Allena in sicurezza nel cloud',
      'ja': 'クラウドで安全にトレーニング',
      'ko': '클라우드에서 안전하게 훈련',
      'nl': 'Train veilig in de cloud',
      'ru': 'Безопасно обучайте в облаке',
    },
    'Play your engine': {
      'zh-Hans': '对弈你的引擎',
      'zh-Hant': '對弈你的引擎',
      'de': 'Spiele gegen deine Engine',
      'es': 'Juega contra tu motor',
      'fr': 'Jouez contre votre moteur',
      'it': 'Gioca contro il tuo motore',
      'ja': '自分のエンジンと対局',
      'ko': '내 엔진과 대국',
      'nl': 'Speel tegen je engine',
      'ru': 'Играйте со своим движком',
    },
    'Completed builds become Bot game choices.': {
      'zh-Hans': '完成后的构建会成为 Bot game 选项。',
      'zh-Hant': '完成後的建置會成為 Bot game 選項。',
      'de': 'Fertige Builds werden zu Bot game-Auswahlen.',
      'es':
          'Las compilaciones terminadas se convierten en opciones de Bot game.',
      'fr': 'Les builds terminés deviennent des choix de Bot game.',
      'it': 'Le build completate diventano scelte per Bot game.',
      'ja': '完了したビルドは Bot game の選択肢になります。',
      'ko': '완료된 빌드는 Bot game 선택지가 됩니다.',
      'nl': 'Voltooide builds worden keuzes voor Bot game.',
      'ru': 'Готовые сборки станут вариантами для Bot game.',
    },
    'Personal engines': {
      'zh-Hans': '个人引擎',
      'zh-Hant': '個人引擎',
      'de': 'Persönliche Engines',
      'es': 'Motores personales',
      'fr': 'Moteurs personnels',
      'it': 'Motori personali',
      'ja': '個人エンジン',
      'ko': '개인 엔진',
      'nl': 'Persoonlijke engines',
      'ru': 'Личные движки',
    },
    'Playable engine library': {
      'zh-Hans': '可玩的引擎库',
      'zh-Hant': '可玩的引擎庫',
      'de': 'Spielbare Engine-Bibliothek',
      'es': 'Biblioteca de motores jugables',
      'fr': 'Bibliothèque de moteurs jouables',
      'it': 'Libreria di motori giocabili',
      'ja': '対局できるエンジンライブラリ',
      'ko': '플레이 가능한 엔진 라이브러리',
      'nl': 'Bibliotheek met speelbare engines',
      'ru': 'Библиотека игровых движков',
    },
    'No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.':
        {
      'zh-Hans': '还没有可玩的个人引擎。构建完成并可用于 Bot game 后会显示在这里。',
      'zh-Hant': '還沒有可玩的個人引擎。建置完成並可用於 Bot game 後會顯示在這裡。',
      'de':
          'Noch keine spielbaren persönlichen Engines. Fertige Builds erscheinen hier, sobald sie für Bot game bereit sind.',
      'es':
          'Aún no hay motores personales jugables. Las compilaciones terminadas aparecerán aquí cuando estén listas para Bot game.',
      'fr':
          'Aucun moteur personnel jouable pour le moment. Les builds terminés apparaîtront ici lorsqu’ils seront prêts pour Bot game.',
      'it':
          'Non ci sono ancora motori personali giocabili. Le build completate appariranno qui quando saranno pronte per Bot game.',
      'ja': 'プレイ可能な個人エンジンはまだありません。Bot game で使えるようになると、完了したビルドがここに表示されます。',
      'ko': '아직 플레이 가능한 개인 엔진이 없습니다. 완료된 빌드가 Bot game에서 준비되면 여기에 표시됩니다.',
      'nl':
          'Er zijn nog geen speelbare persoonlijke engines. Voltooide builds verschijnen hier zodra ze klaar zijn voor Bot game.',
      'ru':
          'Пока нет игровых личных движков. Готовые сборки появятся здесь, когда будут готовы для Bot game.',
    },
    'Playable personal engines appear here and can be selected as Bot game choices when available.':
        {
      'zh-Hans': '可玩的个人引擎会显示在这里，可用时可作为 Bot game 选项。',
      'zh-Hant': '可玩的個人引擎會顯示在這裡，可用時可作為 Bot game 選項。',
      'de':
          'Spielbare persönliche Engines erscheinen hier und können als Bot game-Auswahl genutzt werden.',
      'es':
          'Los motores personales jugables aparecerán aquí y podrán seleccionarse como opciones de Bot game.',
      'fr':
          'Les moteurs personnels jouables apparaissent ici et peuvent être choisis dans Bot game lorsqu’ils sont disponibles.',
      'it':
          'I motori personali giocabili appaiono qui e possono essere scelti in Bot game quando disponibili.',
      'ja': 'プレイ可能な個人エンジンはここに表示され、利用可能になると Bot game の選択肢として選べます。',
      'ko': '플레이 가능한 개인 엔진은 여기에 표시되며, 사용할 수 있으면 Bot game 선택지로 고를 수 있습니다.',
      'nl':
          'Speelbare persoonlijke engines verschijnen hier en kunnen als Bot game-keuze worden geselecteerd.',
      'ru':
          'Игровые личные движки появятся здесь, и их можно будет выбрать в Bot game, когда они будут доступны.',
    },
    'Training, reports, and playable personal engines live in Engine Lab.': {
      'zh-Hans': '训练、报告和可玩的个人引擎都在 Engine Lab 中。',
      'zh-Hant': '訓練、報表和可玩的個人引擎都在 Engine Lab 中。',
      'de':
          'Training, Berichte und spielbare persönliche Engines befinden sich im Engine Lab.',
      'es':
          'El entrenamiento, los informes y los motores personales jugables están en Engine Lab.',
      'fr':
          'L’entraînement, les rapports et les moteurs personnels jouables se trouvent dans Engine Lab.',
      'it':
          'Allenamento, report e motori personali giocabili si trovano in Engine Lab.',
      'ja': 'トレーニング、レポート、プレイ可能な個人エンジンは Engine Lab にあります。',
      'ko': '훈련, 리포트, 플레이 가능한 개인 엔진은 Engine Lab에 있습니다.',
      'nl':
          'Training, rapporten en speelbare persoonlijke engines staan in Engine Lab.',
      'ru': 'Обучение, отчёты и игровые личные движки находятся в Engine Lab.',
    },
    'New personal engine': {
      'zh-Hans': '新建个人引擎',
      'zh-Hant': '新建個人引擎',
      'de': 'Neue persönliche Engine',
      'es': 'Nuevo motor personal',
      'fr': 'Nouveau moteur personnel',
      'it': 'Nuovo motore personale',
      'ja': '新しい個人エンジン',
      'ko': '새 개인 엔진',
      'nl': 'Nieuwe persoonlijke engine',
      'ru': 'Новый личный движок',
    },
    'Training cost': {
      'zh-Hans': '训练消耗',
      'zh-Hant': '訓練消耗',
      'de': 'Trainingskosten',
      'es': 'Coste de entrenamiento',
      'fr': 'Coût d’entraînement',
      'it': 'Costo allenamento',
      'ja': 'トレーニング費用',
      'ko': '훈련 비용',
      'nl': 'Trainingskosten',
      'ru': 'Стоимость обучения',
    },
    'Unlimited training': {
      'zh-Hans': '无限训练',
      'zh-Hant': '無限訓練',
      'de': 'Unbegrenztes Training',
      'es': 'Entrenamiento ilimitado',
      'fr': 'Entraînement illimité',
      'it': 'Allenamento illimitato',
      'ja': 'トレーニング無制限',
      'ko': '무제한 훈련',
      'nl': 'Onbeperkt trainen',
      'ru': 'Обучение без ограничений',
    },
    'No personal engines yet': {
      'zh-Hans': '还没有个人引擎',
      'zh-Hant': '還沒有個人引擎',
      'de': 'Noch keine persönlichen Engines',
      'es': 'Aún no hay motores personales',
      'fr': 'Aucun moteur personnel pour le moment',
      'it': 'Ancora nessun motore personale',
      'ja': '個人エンジンはまだありません',
      'ko': '아직 개인 엔진이 없습니다',
      'nl': 'Nog geen persoonlijke engines',
      'ru': 'Личных движков пока нет',
    },
    'Start training from Game Record, Lichess, or PGN files. Your real cloud jobs will appear here after they are created.':
        {
      'zh-Hans': '从 Game Record、Lichess 或 PGN 文件开始训练。创建后，真实云端任务会显示在这里。',
      'zh-Hant': '從 Game Record、Lichess 或 PGN 檔案開始訓練。建立後，真實雲端任務會顯示在這裡。',
      'de':
          'Starte Training aus Game Record, Lichess oder PGN-Dateien. Deine echten Cloud-Aufgaben erscheinen hier nach dem Erstellen.',
      'es':
          'Empieza el entrenamiento desde Game Record, Lichess o archivos PGN. Tus tareas reales en la nube aparecerán aquí al crearse.',
      'fr':
          'Lancez l’entraînement depuis Game Record, Lichess ou des fichiers PGN. Vos tâches cloud réelles apparaîtront ici après création.',
      'it':
          'Avvia l’allenamento da Game Record, Lichess o file PGN. I task cloud reali appariranno qui dopo la creazione.',
      'ja':
          'Game Record、Lichess、または PGN ファイルからトレーニングを開始します。作成後、実際のクラウドタスクがここに表示されます。',
      'ko':
          'Game Record, Lichess 또는 PGN 파일에서 훈련을 시작하세요. 생성된 실제 클라우드 작업은 여기에 표시됩니다.',
      'nl':
          'Start training vanuit Game Record, Lichess of PGN-bestanden. Je echte cloudtaken verschijnen hier nadat ze zijn gemaakt.',
      'ru':
          'Начните обучение из Game Record, Lichess или PGN-файлов. Реальные облачные задачи появятся здесь после создания.',
    },
    'Completed personal engines will show their real quality report here.': {
      'zh-Hans': '完成后的个人引擎会在这里显示真实质量报告。',
      'zh-Hant': '完成後的個人引擎會在這裡顯示真實品質報告。',
      'de':
          'Abgeschlossene persönliche Engines zeigen hier ihren echten Qualitätsbericht.',
      'es':
          'Los motores personales completados mostrarán aquí su informe de calidad real.',
      'fr':
          'Les moteurs personnels terminés afficheront ici leur vrai rapport qualité.',
      'it':
          'I motori personali completati mostreranno qui il report qualità reale.',
      'ja': '完了した個人エンジンの実際の品質レポートがここに表示されます。',
      'ko': '완료된 개인 엔진의 실제 품질 리포트가 여기에 표시됩니다.',
      'nl':
          'Voltooide persoonlijke engines tonen hier hun echte kwaliteitsrapport.',
      'ru':
          'Для готовых личных движков здесь будет показан реальный отчёт качества.',
    },
    'Engine details': {
      'zh-Hans': '引擎详情',
      'zh-Hant': '引擎詳情',
      'de': 'Engine-Details',
      'es': 'Detalles del motor',
      'fr': 'Détails du moteur',
      'it': 'Dettagli motore',
      'ja': 'エンジン詳細',
      'ko': '엔진 세부정보',
      'nl': 'Enginegegevens',
      'ru': 'Сведения о движке',
    },
    'Engine name': {
      'zh-Hans': '引擎名称',
      'zh-Hant': '引擎名稱',
      'de': 'Engine-Name',
      'es': 'Nombre del motor',
      'fr': 'Nom du moteur',
      'it': 'Nome motore',
      'ja': 'エンジン名',
      'ko': '엔진 이름',
      'nl': 'Enginenaam',
      'ru': 'Название движка',
    },
    'Training rules': {
      'zh-Hans': '训练规则',
      'zh-Hant': '訓練規則',
      'de': 'Trainingsregeln',
      'es': 'Reglas de entrenamiento',
      'fr': 'Règles d’entraînement',
      'it': 'Regole di allenamento',
      'ja': 'トレーニングルール',
      'ko': '훈련 규칙',
      'nl': 'Trainingsregels',
      'ru': 'Правила обучения',
    },
    'Start training': {
      'zh-Hans': '开始训练',
      'zh-Hant': '開始訓練',
      'de': 'Training starten',
      'es': 'Iniciar entrenamiento',
      'fr': 'Lancer l’entraînement',
      'it': 'Avvia allenamento',
      'ja': 'トレーニング開始',
      'ko': '훈련 시작',
      'nl': 'Training starten',
      'ru': 'Запустить обучение',
    },
    'Personal engine training started': {
      'zh-Hans': '个人引擎训练已开始',
      'zh-Hant': '個人引擎訓練已開始',
      'de': 'Training der persönlichen Engine gestartet',
      'es': 'Entrenamiento del motor personal iniciado',
      'fr': 'Entraînement du moteur personnel lancé',
      'it': 'Allenamento del motore personale avviato',
      'ja': '個人エンジンのトレーニングを開始しました',
      'ko': '개인 엔진 훈련이 시작되었습니다',
      'nl': 'Training van persoonlijke engine gestart',
      'ru': 'Обучение личного движка запущено',
    },
    'Personal engine training started. You can keep using the app while Chessnut trains it.':
        {
      'zh-Hans': '个人引擎训练已开始。Chessnut 训练时，你可以继续使用 App。',
      'zh-Hant': '個人引擎訓練已開始。Chessnut 訓練時，你可以繼續使用 App。',
      'de':
          'Training der persönlichen Engine gestartet. Du kannst die App weiter verwenden, während Chessnut trainiert.',
      'es':
          'Entrenamiento del motor personal iniciado. Puedes seguir usando la app mientras Chessnut entrena.',
      'fr':
          'Entraînement du moteur personnel lancé. Vous pouvez continuer à utiliser l’app pendant que Chessnut l’entraîne.',
      'it':
          'Allenamento del motore personale avviato. Puoi continuare a usare l’app mentre Chessnut lo allena.',
      'ja': '個人エンジンのトレーニングを開始しました。Chessnut がトレーニング中もアプリを使えます。',
      'ko': '개인 엔진 훈련이 시작되었습니다. Chessnut이 훈련하는 동안 앱을 계속 사용할 수 있습니다.',
      'nl':
          'Training van persoonlijke engine gestart. Je kunt de app blijven gebruiken terwijl Chessnut traint.',
      'ru':
          'Обучение личного движка запущено. Можно продолжать пользоваться приложением, пока Chessnut обучает его.',
    },
    'Unable to start personal engine training.': {
      'zh-Hans': '无法开始个人引擎训练。',
      'zh-Hant': '無法開始個人引擎訓練。',
      'de': 'Training der persönlichen Engine konnte nicht gestartet werden.',
      'es': 'No se pudo iniciar el entrenamiento del motor personal.',
      'fr': 'Impossible de lancer l’entraînement du moteur personnel.',
      'it': 'Impossibile avviare l’allenamento del motore personale.',
      'ja': '個人エンジンのトレーニングを開始できません。',
      'ko': '개인 엔진 훈련을 시작할 수 없습니다.',
      'nl': 'Kan training van persoonlijke engine niet starten.',
      'ru': 'Не удалось запустить обучение личного движка.',
    },
    'Personal engine training is unavailable. Check Premium, points, or try again later.':
        {
      'zh-Hans': '个人引擎训练暂不可用。请检查会员、积分，或稍后重试。',
      'zh-Hant': '個人引擎訓練暫不可用。請檢查會員、點數，或稍後重試。',
      'de':
          'Training der persönlichen Engine ist nicht verfügbar. Prüfe Premium, Punkte oder versuche es später erneut.',
      'es':
          'El entrenamiento del motor personal no está disponible. Revisa Premium, puntos o inténtalo más tarde.',
      'fr':
          'L’entraînement du moteur personnel est indisponible. Vérifiez Premium, les points ou réessayez plus tard.',
      'it':
          'L’allenamento del motore personale non è disponibile. Controlla Premium, punti o riprova più tardi.',
      'ja': '個人エンジンのトレーニングは利用できません。Premium、ポイントを確認するか、後でもう一度お試しください。',
      'ko': '개인 엔진 훈련을 사용할 수 없습니다. Premium, 포인트를 확인하거나 나중에 다시 시도하세요.',
      'nl':
          'Training van persoonlijke engine is niet beschikbaar. Controleer Premium, punten of probeer later opnieuw.',
      'ru':
          'Обучение личного движка недоступно. Проверьте Premium, баллы или повторите попытку позже.',
    },
    'A personal engine training job is already running. Please wait for it to finish before starting a new one.':
        {
      'zh-Hans': '已有个人引擎训练任务正在进行。请等待当前任务完成后再开始新的训练。',
      'zh-Hant': '已有個人引擎訓練任務正在進行。請等待目前任務完成後再開始新的訓練。',
      'de':
          'Es läuft bereits ein Training der persönlichen Engine. Bitte warte, bis es abgeschlossen ist, bevor du ein neues startest.',
      'es':
          'Ya hay un entrenamiento del motor personal en curso. Espera a que termine antes de iniciar uno nuevo.',
      'fr':
          'Un entraînement du moteur personnel est déjà en cours. Attendez qu’il se termine avant d’en lancer un nouveau.',
      'it':
          'È già in corso un allenamento del motore personale. Attendi che termini prima di avviarne uno nuovo.',
      'ja': '個人エンジンのトレーニングがすでに実行中です。完了してから新しいトレーニングを開始してください。',
      'ko': '개인 엔진 훈련 작업이 이미 진행 중입니다. 완료된 후 새 훈련을 시작하세요.',
      'nl':
          'Er loopt al een training van de persoonlijke engine. Wacht tot die klaar is voordat je een nieuwe start.',
      'ru':
          'Обучение личного движка уже выполняется. Дождитесь его завершения перед запуском нового.',
    },
    'Unable to check training progress.': {
      'zh-Hans': '无法检查训练进度。',
      'zh-Hant': '無法檢查訓練進度。',
      'de': 'Trainingsfortschritt konnte nicht geprüft werden.',
      'es': 'No se pudo comprobar el progreso del entrenamiento.',
      'fr': 'Impossible de vérifier la progression de l’entraînement.',
      'it': 'Impossibile controllare l’avanzamento dell’allenamento.',
      'ja': 'トレーニングの進行状況を確認できません。',
      'ko': '훈련 진행 상황을 확인할 수 없습니다.',
      'nl': 'Kan trainingsvoortgang niet controleren.',
      'ru': 'Не удалось проверить ход обучения.',
    },
    'Unable to cancel personal engine training.': {
      'zh-Hans': '无法取消个人引擎训练。',
      'zh-Hant': '無法取消個人引擎訓練。',
      'de': 'Training der persönlichen Engine konnte nicht abgebrochen werden.',
      'es': 'No se pudo cancelar el entrenamiento del motor personal.',
      'fr': 'Impossible d’annuler l’entraînement du moteur personnel.',
      'it': 'Impossibile annullare l’allenamento del motore personale.',
      'ja': '個人エンジンのトレーニングをキャンセルできません。',
      'ko': '개인 엔진 훈련을 취소할 수 없습니다.',
      'nl': 'Kan training van persoonlijke engine niet annuleren.',
      'ru': 'Не удалось отменить обучение личного движка.',
    },
    'Unable to start personal engine training from these games.': {
      'zh-Hans': '无法用这些对局开始个人引擎训练。',
      'zh-Hant': '無法用這些對局開始個人引擎訓練。',
      'de':
          'Training der persönlichen Engine konnte mit diesen Partien nicht gestartet werden.',
      'es':
          'No se pudo iniciar el entrenamiento del motor personal con estas partidas.',
      'fr':
          'Impossible de lancer l’entraînement du moteur personnel avec ces parties.',
      'it':
          'Impossibile avviare l’allenamento del motore personale con queste partite.',
      'ja': 'これらの対局では個人エンジンのトレーニングを開始できません。',
      'ko': '이 대국으로 개인 엔진 훈련을 시작할 수 없습니다.',
      'nl':
          'Kan training van persoonlijke engine niet starten met deze partijen.',
      'ru': 'Не удалось запустить обучение личного движка по этим партиям.',
    },
    'Training needs attention': {
      'zh-Hans': '训练需要处理',
      'zh-Hant': '訓練需要處理',
      'de': 'Training benötigt Aufmerksamkeit',
      'es': 'El entrenamiento requiere atención',
      'fr': 'L’entraînement nécessite votre attention',
      'it': 'L’allenamento richiede attenzione',
      'ja': 'トレーニングの確認が必要です',
      'ko': '훈련에 확인이 필요합니다',
      'nl': 'Training vereist aandacht',
      'ru': 'Обучение требует внимания',
    },
    'Training failed': {
      'zh-Hans': '训练失败',
      'zh-Hant': '訓練失敗',
      'de': 'Training fehlgeschlagen',
      'es': 'El entrenamiento falló',
      'fr': 'Échec de l’entraînement',
      'it': 'Allenamento non riuscito',
      'ja': 'トレーニングに失敗しました',
      'ko': '훈련 실패',
      'nl': 'Training mislukt',
      'ru': 'Обучение не выполнено',
    },
    'Training canceled': {
      'zh-Hans': '训练已取消',
      'zh-Hant': '訓練已取消',
      'de': 'Training abgebrochen',
      'es': 'Entrenamiento cancelado',
      'fr': 'Entraînement annulé',
      'it': 'Allenamento annullato',
      'ja': 'トレーニングをキャンセルしました',
      'ko': '훈련 취소됨',
      'nl': 'Training geannuleerd',
      'ru': 'Обучение отменено',
    },
    'Unlimited personal engine training': {
      'zh-Hans': '无限个人引擎训练',
      'zh-Hant': '無限個人引擎訓練',
      'de': 'Unbegrenztes Training persönlicher Engines',
      'es': 'Entrenamiento ilimitado de motores personales',
      'fr': 'Entraînement illimité des moteurs personnels',
      'it': 'Allenamento illimitato dei motori personali',
      'ja': '個人エンジントレーニング無制限',
      'ko': '개인 엔진 훈련 무제한',
      'nl': 'Onbeperkte training van persoonlijke engines',
      'ru': 'Обучение личных движков без ограничений',
    },
    'No 500-point charge for personal engine training.': {
      'zh-Hans': '个人引擎训练不再消耗 500 积分。',
      'zh-Hant': '個人引擎訓練不再消耗 500 點數。',
      'de': 'Keine 500-Punkte-Gebühr für persönliches Engine-Training.',
      'es': 'Sin cargo de 500 puntos por entrenar motores personales.',
      'fr': 'Aucun coût de 500 points pour l’entraînement du moteur personnel.',
      'it': 'Nessun costo di 500 punti per allenare motori personali.',
      'ja': '個人エンジンのトレーニングで 500 ポイントは消費されません。',
      'ko': '개인 엔진 훈련에는 500포인트가 차감되지 않습니다.',
      'nl': 'Geen 500-puntenkosten voor persoonlijke engine-training.',
      'ru': 'Без списания 500 баллов за обучение личного движка.',
    },
    'Unlimited Grandeur and personal engine training': {
      'zh-Hans': 'Grandeur 和个人引擎训练无限使用',
      'zh-Hant': 'Grandeur 和個人引擎訓練無限使用',
      'de': 'Grandeur und persönliches Engine-Training unbegrenzt',
      'es': 'Grandeur y entrenamiento de motores personales ilimitados',
      'fr': 'Grandeur et entraînement des moteurs personnels illimités',
      'it': 'Grandeur e allenamento dei motori personali illimitati',
      'ja': 'Grandeur と個人エンジントレーニングが無制限',
      'ko': 'Grandeur 및 개인 엔진 훈련 무제한',
      'nl': 'Grandeur en persoonlijke engine-training onbeperkt',
      'ru': 'Grandeur и обучение личного движка без ограничений',
    },
    'Refresh training status': {
      'zh-Hans': '刷新训练状态',
      'zh-Hant': '重新整理訓練狀態',
      'de': 'Trainingsstatus aktualisieren',
      'es': 'Actualizar estado del entrenamiento',
      'fr': 'Actualiser l’état de l’entraînement',
      'it': 'Aggiorna stato allenamento',
      'ja': 'トレーニング状況を更新',
      'ko': '훈련 상태 새로고침',
      'nl': 'Trainingsstatus vernieuwen',
      'ru': 'Обновить статус обучения',
    },
    'Training / pending': {
      'zh-Hans': '训练中 / 等待中',
      'zh-Hant': '訓練中 / 等待中',
      'de': 'Training / ausstehend',
      'es': 'Entrenando / pendiente',
      'fr': 'Entraînement / en attente',
      'it': 'Allenamento / in attesa',
      'ja': 'トレーニング中 / 待機中',
      'ko': '훈련 중 / 대기 중',
      'nl': 'Training / in behandeling',
      'ru': 'Обучение / ожидание',
    },
    'Premium active / Grandeur and personal engine training unlimited': {
      'zh-Hans': 'Premium 已生效 / Grandeur 和个人引擎训练不限量',
      'zh-Hant': 'Premium 已生效 / Grandeur 和個人引擎訓練不限量',
      'de':
          'Premium aktiv / Grandeur und persönliches Engine-Training unbegrenzt',
      'es':
          'Premium activo / Grandeur y entrenamiento de motor personal ilimitados',
      'fr':
          'Premium actif / Grandeur et entraînement de moteur personnel illimités',
      'it':
          'Premium attivo / Grandeur e allenamento del motore personale illimitati',
      'ja': 'Premium 有効 / Grandeur と個人エンジンのトレーニングが無制限',
      'ko': 'Premium 활성 / Grandeur 및 개인 엔진 훈련 무제한',
      'nl':
          'Premium actief / Grandeur en persoonlijke engine-training onbeperkt',
      'ru': 'Premium активен / Grandeur и обучение личного движка без лимита',
    },
    'Checked in today / Grandeur 100 / personal engine training 500': {
      'zh-Hans': '今日已签到 / Grandeur 100 / 个人引擎训练 500',
      'zh-Hant': '今日已簽到 / Grandeur 100 / 個人引擎訓練 500',
      'de':
          'Heute eingecheckt / Grandeur 100 / persönliches Engine-Training 500',
      'es':
          'Check-in de hoy hecho / Grandeur 100 / entrenamiento de motor personal 500',
      'fr':
          'Pointage du jour effectué / Grandeur 100 / entraînement de moteur personnel 500',
      'it':
          'Check-in di oggi completato / Grandeur 100 / allenamento motore personale 500',
      'ja': '本日のチェックイン済み / Grandeur 100 / 個人エンジンのトレーニング 500',
      'ko': '오늘 체크인 완료 / Grandeur 100 / 개인 엔진 훈련 500',
      'nl':
          'Vandaag ingecheckt / Grandeur 100 / persoonlijke engine-training 500',
      'ru':
          'Сегодня отметка получена / Grandeur 100 / обучение личного движка 500',
    },
    'Daily check-in available / Grandeur 100 / personal engine training 500': {
      'zh-Hans': '可领取每日签到 / Grandeur 100 / 个人引擎训练 500',
      'zh-Hant': '可領取每日簽到 / Grandeur 100 / 個人引擎訓練 500',
      'de':
          'Täglicher Check-in verfügbar / Grandeur 100 / persönliches Engine-Training 500',
      'es':
          'Check-in diario disponible / Grandeur 100 / entrenamiento de motor personal 500',
      'fr':
          'Pointage quotidien disponible / Grandeur 100 / entraînement de moteur personnel 500',
      'it':
          'Check-in giornaliero disponibile / Grandeur 100 / allenamento motore personale 500',
      'ja': 'デイリーチェックイン利用可 / Grandeur 100 / 個人エンジンのトレーニング 500',
      'ko': '일일 체크인 가능 / Grandeur 100 / 개인 엔진 훈련 500',
      'nl':
          'Dagelijkse check-in beschikbaar / Grandeur 100 / persoonlijke engine-training 500',
      'ru':
          'Доступна ежедневная отметка / Grandeur 100 / обучение личного движка 500',
    },
    'Grandeur and personal engine training become unlimited.': {
      'zh-Hans': 'Grandeur 和个人引擎训练将不限量。',
      'zh-Hant': 'Grandeur 和個人引擎訓練將不限量。',
      'de': 'Grandeur und persönliches Engine-Training werden unbegrenzt.',
      'es':
          'Grandeur y el entrenamiento de motor personal pasan a ser ilimitados.',
      'fr':
          'Grandeur et l’entraînement de moteur personnel deviennent illimités.',
      'it':
          'Grandeur e l’allenamento del motore personale diventano illimitati.',
      'ja': 'Grandeur と個人エンジンのトレーニングが無制限になります。',
      'ko': 'Grandeur와 개인 엔진 훈련이 무제한이 됩니다.',
      'nl': 'Grandeur en persoonlijke engine-training worden onbeperkt.',
      'ru': 'Grandeur и обучение личного движка станут безлимитными.',
    },
    'Start training when the usable game count is enough.': {
      'zh-Hans': '可用对局数量足够后即可开始训练。',
      'zh-Hant': '可用對局數量足夠後即可開始訓練。',
      'de':
          'Starte das Training, sobald genügend nutzbare Partien vorhanden sind.',
      'es':
          'Inicia el entrenamiento cuando haya suficientes partidas utilizables.',
      'fr':
          'Lancez l’entraînement lorsque le nombre de parties utilisables est suffisant.',
      'it':
          'Avvia l’allenamento quando ci sono abbastanza partite utilizzabili.',
      'ja': '利用可能な対局数が十分になるとトレーニングを開始できます。',
      'ko': '사용 가능한 대국 수가 충분하면 훈련을 시작하세요.',
      'nl': 'Start de training zodra er genoeg bruikbare partijen zijn.',
      'ru': 'Начните обучение, когда будет достаточно подходящих партий.',
    },
    'Engine Lab weights': {
      'zh-Hans': 'Engine Lab 权重',
      'zh-Hant': 'Engine Lab 權重',
      'de': 'Engine-Lab-Gewichte',
      'es': 'Pesos de Engine Lab',
      'fr': 'Poids Engine Lab',
      'it': 'Pesi Engine Lab',
      'ja': 'Engine Lab の重み',
      'ko': 'Engine Lab 가중치',
      'nl': 'Engine Lab-gewichten',
      'ru': 'Веса Engine Lab',
    },
    'No downloaded LC0 weights yet. Finished Engine Lab builds will appear here when their weight file is available.':
        {
      'zh-Hans': '还没有下载的 LC0 权重。Engine Lab 构建完成并生成权重文件后会显示在这里。',
      'zh-Hant': '還沒有下載的 LC0 權重。Engine Lab 構建完成並生成權重檔後會顯示在這裡。',
      'de':
          'Noch keine heruntergeladenen LC0-Gewichte. Fertige Engine-Lab-Builds erscheinen hier, sobald ihre Gewichtsdatei verfügbar ist.',
      'es':
          'Aún no hay pesos LC0 descargados. Las compilaciones de Engine Lab aparecerán aquí cuando el archivo de pesos esté disponible.',
      'fr':
          'Aucun poids LC0 téléchargé pour l’instant. Les builds Engine Lab terminés apparaîtront ici quand leur fichier sera disponible.',
      'it':
          'Nessun peso LC0 scaricato. Le build Engine Lab completate appariranno qui quando il file pesi sarà disponibile.',
      'ja':
          'ダウンロード済みの LC0 重みはまだありません。Engine Lab のビルドが完了し、重みファイルが利用可能になるとここに表示されます。',
      'ko':
          '아직 다운로드한 LC0 가중치가 없습니다. Engine Lab 빌드가 완료되고 가중치 파일이 준비되면 여기에 표시됩니다.',
      'nl':
          'Nog geen LC0-gewichten gedownload. Voltooide Engine Lab-builds verschijnen hier zodra hun gewichtbestand beschikbaar is.',
      'ru':
          'Загруженных весов LC0 пока нет. Завершённые сборки Engine Lab появятся здесь, когда файл весов будет доступен.',
    },
    'Manage in Engine Lab': {
      'zh-Hans': '在 Engine Lab 中管理',
      'zh-Hant': '在 Engine Lab 中管理',
      'de': 'In Engine Lab verwalten',
      'es': 'Gestionar en Engine Lab',
      'fr': 'Gérer dans Engine Lab',
      'it': 'Gestisci in Engine Lab',
      'ja': 'Engine Lab で管理',
      'ko': 'Engine Lab에서 관리',
      'nl': 'Beheren in Engine Lab',
      'ru': 'Управлять в Engine Lab',
    },
    'Training, reports, and downloaded LC0 weights live in Engine Lab.': {
      'zh-Hans': '训练任务、报告和已下载的 LC0 权重都在 Engine Lab 中管理。',
      'zh-Hant': '訓練任務、報告和已下載的 LC0 權重都在 Engine Lab 中管理。',
      'de':
          'Training, Reports und heruntergeladene LC0-Gewichte liegen in Engine Lab.',
      'es':
          'El entrenamiento, los informes y los pesos LC0 descargados están en Engine Lab.',
      'fr':
          'L’entraînement, les rapports et les poids LC0 téléchargés se trouvent dans Engine Lab.',
      'it':
          'Addestramento, report e pesi LC0 scaricati si trovano in Engine Lab.',
      'ja': 'トレーニング、レポート、ダウンロード済み LC0 重みは Engine Lab にあります。',
      'ko': '훈련, 보고서, 다운로드한 LC0 가중치는 Engine Lab에 있습니다.',
      'nl':
          'Training, rapporten en gedownloade LC0-gewichten staan in Engine Lab.',
      'ru': 'Обучение, отчёты и загруженные веса LC0 находятся в Engine Lab.',
    },
    'Sign in required': {
      'zh-Hans': '需要登录',
      'zh-Hant': '需要登入',
      'de': 'Anmeldung erforderlich',
      'es': 'Inicio de sesión requerido',
      'fr': 'Connexion requise',
      'it': 'Accesso richiesto',
      'ja': 'ログインが必要です',
      'ko': '로그인이 필요합니다',
      'nl': 'Inloggen vereist',
      'ru': 'Требуется вход',
    },
    'Grandeur review uses your wallet balance.': {
      'zh-Hans': 'Grandeur 复盘会使用你的钱包余额。',
      'zh-Hant': 'Grandeur 復盤會使用你的錢包餘額。',
      'de': 'Die Grandeur-Review nutzt dein Wallet-Guthaben.',
      'es': 'La revisión Grandeur usa tu saldo del wallet.',
      'fr': 'La revue Grandeur utilise votre solde wallet.',
      'it': 'La review Grandeur usa il saldo wallet.',
      'ja': 'Grandeur レビューはウォレット残高を使用します。',
      'ko': 'Grandeur 리뷰는 지갑 잔액을 사용합니다.',
      'nl': 'De Grandeur-review gebruikt je walletsaldo.',
      'ru': 'Разбор Grandeur использует баланс кошелька.',
    },
    'Current move': {
      'zh-Hans': '当前着法',
      'zh-Hant': '目前著法',
      'de': 'Aktueller Zug',
      'es': 'Jugada actual',
      'fr': 'Coup actuel',
      'it': 'Mossa attuale',
      'ja': '現在の手',
      'ko': '현재 수',
      'nl': 'Huidige zet',
      'ru': 'Текущий ход',
    },
    'This record cannot be deleted from the cloud.': {
      'zh-Hans': '这条记录不能从云端删除。',
      'zh-Hant': '這筆記錄不能從雲端刪除。',
      'de': 'Dieser Eintrag kann nicht aus der Cloud gelöscht werden.',
      'es': 'Este registro no se puede eliminar de la nube.',
      'fr': 'Cette partie ne peut pas être supprimée du cloud.',
      'it': 'Questo record non può essere eliminato dal cloud.',
      'ja': 'この記録はクラウドから削除できません。',
      'ko': '이 기록은 클라우드에서 삭제할 수 없습니다.',
      'nl': 'Dit record kan niet uit de cloud worden verwijderd.',
      'ru': 'Эту запись нельзя удалить из облака.',
    },
    'Invalid FEN': {
      'zh-Hans': 'FEN 无效',
      'zh-Hant': 'FEN 無效',
      'de': 'Ungültige FEN',
      'es': 'FEN no válido',
      'fr': 'FEN invalide',
      'it': 'FEN non valido',
      'ja': '無効な FEN',
      'ko': '유효하지 않은 FEN',
      'nl': 'Ongeldige FEN',
      'ru': 'Недопустимый FEN',
    },
    'Piece pairing will use the connected Chessnut Move and save the selected channel to its board profile.':
        {
      'zh-Hans': '棋子配对会使用已连接的 Chessnut Move，并把所选通道保存到棋盘配置。',
      'zh-Hant': '棋子配對會使用已連接的 Chessnut Move，並把所選通道保存到棋盤設定。',
      'de':
          'Die Figurenkopplung nutzt den verbundenen Chessnut Move und speichert den gewählten Kanal im Brettprofil.',
      'es':
          'El emparejamiento de piezas usará el Chessnut Move conectado y guardará el canal elegido en su perfil.',
      'fr':
          'L’appairage des pièces utilisera le Chessnut Move connecté et enregistrera le canal choisi dans son profil.',
      'it':
          'L’abbinamento pezzi userà il Chessnut Move connesso e salverà il canale scelto nel profilo.',
      'ja': '駒のペアリングは接続中の Chessnut Move を使い、選択したチャンネルをボードプロファイルに保存します。',
      'ko': '기물 페어링은 연결된 Chessnut Move를 사용하고 선택한 채널을 보드 프로필에 저장합니다.',
      'nl':
          'Stukkoppeling gebruikt de verbonden Chessnut Move en bewaart het gekozen kanaal in het bordprofiel.',
      'ru':
          'Привязка фигур использует подключённый Chessnut Move и сохранит выбранный канал в профиле доски.',
    },
    'Press clock switch': {
      'zh-Hans': '按下棋钟 switch',
      'zh-Hant': '按下棋鐘 switch',
      'de': 'Uhr-switch drücken',
      'es': 'Pulsa el switch del reloj',
      'fr': 'Appuyez sur le switch de la pendule',
      'it': 'Premi lo switch dell’orologio',
      'ja': '時計の switch を押す',
      'ko': '시계 switch 누르기',
      'nl': 'Druk op de klok-switch',
      'ru': 'Нажмите switch часов',
    },
    'Loading subtitles and board checkpoints.': {
      'zh-Hans': '正在加载字幕和棋盘检查点。',
      'zh-Hant': '正在載入字幕和棋盤檢查點。',
      'de': 'Untertitel und Brett-Checkpoints werden geladen.',
      'es': 'Cargando subtítulos y puntos de tablero.',
      'fr': 'Chargement des sous-titres et étapes échiquier.',
      'it': 'Caricamento sottotitoli e checkpoint scacchiera.',
      'ja': '字幕とボードチェックポイントを読み込み中です。',
      'ko': '자막과 보드 체크포인트를 불러오는 중입니다.',
      'nl': 'Ondertitels en bordcheckpoints laden.',
      'ru': 'Загрузка субтитров и проверок доски.',
    },
    'Refresh records': {
      'zh-Hans': '刷新记录',
      'zh-Hant': '重新整理記錄',
      'de': 'Einträge aktualisieren',
      'es': 'Actualizar registros',
      'fr': 'Actualiser les parties',
      'it': 'Aggiorna record',
      'ja': '記録を更新',
      'ko': '기록 새로고침',
      'nl': 'Records vernieuwen',
      'ru': 'Обновить записи',
    },
    'No cloud games found': {
      'zh-Hans': '未找到云端对局',
      'zh-Hant': '找不到雲端對局',
      'de': 'Keine Cloud-Partien gefunden',
      'es': 'No se encontraron partidas en la nube',
      'fr': 'Aucune partie cloud trouvée',
      'it': 'Nessuna partita cloud trovata',
      'ja': 'クラウド対局が見つかりません',
      'ko': '클라우드 게임을 찾을 수 없습니다',
      'nl': 'Geen cloudpartijen gevonden',
      'ru': 'Облачные партии не найдены',
    },
    'Try fewer filters or import games from Lichess first.': {
      'zh-Hans': '减少筛选条件，或先从 Lichess 导入对局。',
      'zh-Hant': '減少篩選條件，或先從 Lichess 匯入對局。',
      'de': 'Nutze weniger Filter oder importiere zuerst Partien von Lichess.',
      'es': 'Usa menos filtros o importa partidas de Lichess primero.',
      'fr': 'Réduisez les filtres ou importez d’abord des parties Lichess.',
      'it': 'Usa meno filtri o importa prima partite da Lichess.',
      'ja': 'フィルターを減らすか、先に Lichess から対局をインポートしてください。',
      'ko': '필터를 줄이거나 먼저 Lichess에서 게임을 가져오세요.',
      'nl': 'Gebruik minder filters of importeer eerst partijen van Lichess.',
      'ru': 'Уменьшите фильтры или сначала импортируйте партии из Lichess.',
    },
    'Ignore continue reminder': {
      'zh-Hans': '忽略继续提醒',
      'zh-Hant': '忽略繼續提醒',
      'de': 'Fortsetzen-Erinnerung ausblenden',
      'es': 'Ignorar recordatorio',
      'fr': 'Ignorer le rappel',
      'it': 'Ignora promemoria',
      'ja': '再開リマインダーを非表示',
      'ko': '이어하기 알림 무시',
      'nl': 'Vervolgmelding negeren',
      'ru': 'Скрыть напоминание',
    },
    'Show files and ranks on virtual boards': {
      'zh-Hans': '在虚拟棋盘上显示坐标',
      'zh-Hant': '在虛擬棋盤上顯示座標',
      'de': 'Koordinaten auf virtuellen Brettern anzeigen',
      'es': 'Mostrar coordenadas en tableros virtuales',
      'fr': 'Afficher les coordonnées sur les échiquiers virtuels',
      'it': 'Mostra coordinate sulle scacchiere virtuali',
      'ja': '仮想ボードに座標を表示',
      'ko': '가상 보드에 좌표 표시',
      'nl': 'Coördinaten op virtuele borden tonen',
      'ru': 'Показывать координаты на виртуальных досках',
    },
    'Board Settings lets you choose Direct control or Web control for physical board moves.':
        {
      'zh-Hans': '可在 Board Settings 中选择实体棋盘走子的 Direct control 或 Web control。',
      'zh-Hant': '可在 Board Settings 中選擇實體棋盤走子的 Direct control 或 Web control。',
      'de':
          'In Board Settings kannst du Direct control oder Web control für physische Brettzüge wählen.',
      'es':
          'En Board Settings puedes elegir Direct control o Web control para jugadas del tablero físico.',
      'fr':
          'Dans Board Settings, choisissez Direct control ou Web control pour les coups du plateau physique.',
      'it':
          'In Board Settings puoi scegliere Direct control o Web control per le mosse del tabellone fisico.',
      'ja': 'Board Settings で物理ボードの手を Direct control または Web control にできます。',
      'ko':
          'Board Settings에서 실제 보드 수에 Direct control 또는 Web control을 선택할 수 있습니다.',
      'nl':
          'In Board Settings kies je Direct control of Web control voor fysieke bordzetten.',
      'ru':
          'В Board Settings можно выбрать Direct control или Web control для ходов с физической доски.',
    },
    'Close authorization': {
      'zh-Hans': '关闭授权',
      'zh-Hant': '關閉授權',
      'de': 'Autorisierung schließen',
      'es': 'Cerrar autorización',
      'fr': 'Fermer l’autorisation',
      'it': 'Chiudi autorizzazione',
      'ja': '認証を閉じる',
      'ko': '인증 닫기',
      'nl': 'Autorisatie sluiten',
      'ru': 'Закрыть авторизацию',
    },
    'Lichess authorization complete.': {
      'zh-Hans': 'Lichess 授权已完成。',
      'zh-Hant': 'Lichess 授權已完成。',
      'de': 'Lichess-Autorisierung abgeschlossen.',
      'es': 'Autorizacion de Lichess completada.',
      'fr': 'Autorisation Lichess terminee.',
      'it': 'Autorizzazione Lichess completata.',
      'ja': 'Lichess 認証が完了しました。',
      'ko': 'Lichess 인증이 완료되었습니다.',
      'nl': 'Lichess-autorisatie voltooid.',
      'ru': 'Авторизация Lichess завершена.',
    },
    'Returning to Chessnut...': {
      'zh-Hans': '正在返回 Chessnut...',
      'zh-Hant': '正在返回 Chessnut...',
      'de': 'Zurueck zu Chessnut...',
      'es': 'Volviendo a Chessnut...',
      'fr': 'Retour a Chessnut...',
      'it': 'Ritorno a Chessnut...',
      'ja': 'Chessnut に戻っています...',
      'ko': 'Chessnut으로 돌아가는 중...',
      'nl': 'Terug naar Chessnut...',
      'ru': 'Возврат в Chessnut...',
    },
    'Return to Chessnut after approving the Lichess authorization. If the page opened in your browser, tap this after it says the authorization succeeded.':
        {
      'zh-Hans': '完成 Lichess 授权后返回 Chessnut。如果页面在浏览器中打开，请在显示授权成功后点击这里。',
      'zh-Hant': '完成 Lichess 授權後返回 Chessnut。如果頁面在瀏覽器中打開，請在顯示授權成功後點擊這裡。',
      'de':
          'Kehre nach der Lichess-Autorisierung zu Chessnut zurück. Wenn die Seite im Browser geöffnet wurde, tippe hier, sobald die Autorisierung erfolgreich ist.',
      'es':
          'Vuelve a Chessnut tras aprobar la autorización de Lichess. Si se abrió en el navegador, toca aquí cuando indique que se completó.',
      'fr':
          'Revenez à Chessnut après avoir approuvé Lichess. Si la page s’est ouverte dans le navigateur, appuyez ici quand l’autorisation réussit.',
      'it':
          'Torna a Chessnut dopo aver approvato Lichess. Se la pagina si è aperta nel browser, tocca qui quando l’autorizzazione riesce.',
      'ja': 'Lichess 認証を承認したら Chessnut に戻ってください。ブラウザで開いた場合は、成功表示後にここをタップします。',
      'ko':
          'Lichess 인증을 승인한 뒤 Chessnut으로 돌아오세요. 브라우저에서 열렸다면 성공 메시지가 나온 뒤 여기를 누르세요.',
      'nl':
          'Keer terug naar Chessnut na de Lichess-autorisatie. Opende de pagina in je browser, tik dan hier na de succesmelding.',
      'ru':
          'Вернитесь в Chessnut после подтверждения Lichess. Если страница открылась в браузере, нажмите здесь после сообщения об успехе.',
    },
    'Open in browser': {
      'zh-Hans': '在浏览器打开',
      'zh-Hant': '在瀏覽器開啟',
      'de': 'Im Browser öffnen',
      'es': 'Abrir en navegador',
      'fr': 'Ouvrir dans le navigateur',
      'it': 'Apri nel browser',
      'ja': 'ブラウザで開く',
      'ko': '브라우저에서 열기',
      'nl': 'Openen in browser',
      'ru': 'Открыть в браузере',
    },
    'I have authorized': {
      'zh-Hans': '我已完成授权',
      'zh-Hant': '我已完成授權',
      'de': 'Ich habe autorisiert',
      'es': 'Ya autoricé',
      'fr': 'J’ai autorisé',
      'it': 'Ho autorizzato',
      'ja': '認証しました',
      'ko': '인증 완료',
      'nl': 'Ik heb geautoriseerd',
      'ru': 'Авторизация выполнена',
    },
    'Lichess authorization could not open.': {
      'zh-Hans': '无法打开 Lichess 授权。',
      'zh-Hant': '無法開啟 Lichess 授權。',
      'de': 'Lichess-Autorisierung konnte nicht geöffnet werden.',
      'es': 'No se pudo abrir la autorización de Lichess.',
      'fr': 'Impossible d’ouvrir l’autorisation Lichess.',
      'it': 'Impossibile aprire l’autorizzazione Lichess.',
      'ja': 'Lichess 認証を開けませんでした。',
      'ko': 'Lichess 인증을 열 수 없습니다.',
      'nl': 'Lichess-autorisatie kon niet worden geopend.',
      'ru': 'Не удалось открыть авторизацию Lichess.',
    },
    'Auto-renewing plans get the best price': {
      'zh-Hans': '自动续订可获得最优惠价格',
      'zh-Hant': '自動續訂可獲得最優惠價格',
      'de': 'Automatisch verlängernde Pläne haben den besten Preis',
      'es': 'Los planes renovables tienen el mejor precio',
      'fr': 'Les abonnements auto-renouvelés ont le meilleur prix',
      'it': 'I piani con rinnovo automatico hanno il prezzo migliore',
      'ja': '自動更新プランが最もお得です',
      'ko': '자동 갱신 플랜이 가장 저렴합니다',
      'nl': 'Automatisch verlengende plannen hebben de beste prijs',
      'ru': 'Автопродление даёт лучшую цену',
    },
    'Restore purchase': {
      'zh-Hans': '恢复购买',
      'zh-Hant': '恢復購買',
      'de': 'Kauf wiederherstellen',
      'es': 'Restaurar compra',
      'fr': 'Restaurer l’achat',
      'it': 'Ripristina acquisto',
      'ja': '購入を復元',
      'ko': '구매 복원',
      'nl': 'Aankoop herstellen',
      'ru': 'Восстановить покупку',
    },
    'Best price': {
      'zh-Hans': '最优惠',
      'zh-Hant': '最優惠',
      'de': 'Bester Preis',
      'es': 'Mejor precio',
      'fr': 'Meilleur prix',
      'it': 'Miglior prezzo',
      'ja': '最安価格',
      'ko': '최저가',
      'nl': 'Beste prijs',
      'ru': 'Лучшая цена',
    },
    'Store restore failed. Please try again.': {
      'zh-Hans': '恢复购买失败，请重试。',
      'zh-Hant': '恢復購買失敗，請重試。',
      'de': 'Kaufwiederherstellung fehlgeschlagen. Bitte erneut versuchen.',
      'es': 'No se pudo restaurar la compra. Inténtalo de nuevo.',
      'fr': 'La restauration de l’achat a échoué. Réessayez.',
      'it': 'Ripristino acquisto non riuscito. Riprova.',
      'ja': '購入の復元に失敗しました。もう一度お試しください。',
      'ko': '구매 복원에 실패했습니다. 다시 시도하세요.',
      'nl': 'Aankoop herstellen mislukt. Probeer opnieuw.',
      'ru': 'Не удалось восстановить покупку. Повторите попытку.',
    },
    'Direct control': {
      'zh-Hans': '直接控制',
      'zh-Hant': '直接控制',
      'de': 'Direktsteuerung',
      'es': 'Control directo',
      'fr': 'Contrôle direct',
      'it': 'Controllo diretto',
      'ja': '直接制御',
      'ko': '직접 제어',
      'nl': 'Directe besturing',
      'ru': 'Прямое управление',
    },
    'Web control': {
      'zh-Hans': '网页控制',
      'zh-Hant': '網頁控制',
      'de': 'Websteuerung',
      'es': 'Control web',
      'fr': 'Contrôle web',
      'it': 'Controllo web',
      'ja': 'Web 制御',
      'ko': '웹 제어',
      'nl': 'Webbesturing',
      'ru': 'Веб-управление',
    },
    'Faster when supported, with automatic fallback.': {
      'zh-Hans': '支持时速度更快，并会自动降级。',
      'zh-Hant': '支援時速度更快，並會自動降級。',
      'de': 'Schneller, wenn unterstützt, mit automatischem Fallback.',
      'es': 'Más rápido si se admite, con respaldo automático.',
      'fr': 'Plus rapide si pris en charge, avec repli automatique.',
      'it': 'Più veloce se supportato, con fallback automatico.',
      'ja': '対応時は高速で、自動フォールバックします。',
      'ko': '지원되는 경우 더 빠르며 자동으로 대체됩니다.',
      'nl': 'Sneller indien ondersteund, met automatische fallback.',
      'ru': 'Быстрее при поддержке, с автоматическим резервом.',
    },
    'More compatible with website changes.': {
      'zh-Hans': '对网站变化兼容性更好。',
      'zh-Hant': '對網站變化相容性更好。',
      'de': 'Kompatibler mit Website-Änderungen.',
      'es': 'Más compatible con cambios del sitio web.',
      'fr': 'Plus compatible avec les changements du site.',
      'it': 'Più compatibile con le modifiche del sito.',
      'ja': 'サイト変更への互換性が高めです。',
      'ko': '웹사이트 변경에 더 잘 대응합니다.',
      'nl': 'Compatibeler met wijzigingen aan de website.',
      'ru': 'Лучше совместимо с изменениями сайта.',
    },
    'Modern motion': {
      'zh-Hans': '现代动效',
      'zh-Hant': '現代動效',
      'de': 'Moderne Bewegung',
      'es': 'Movimiento moderno',
      'fr': 'Animations modernes',
      'it': 'Movimento moderno',
      'ja': 'モダンモーション',
      'ko': '모던 모션',
      'nl': 'Moderne beweging',
      'ru': 'Современная анимация',
    },
    'Tap to use': {
      'zh-Hans': '点击使用',
      'zh-Hant': '點擊使用',
      'de': 'Zum Nutzen tippen',
      'es': 'Toca para usar',
      'fr': 'Touchez pour utiliser',
      'it': 'Tocca per usare',
      'ja': 'タップして使用',
      'ko': '탭하여 사용',
      'nl': 'Tik om te gebruiken',
      'ru': 'Нажмите, чтобы выбрать',
    },
    'Training modes': {
      'zh-Hans': '训练模式',
      'zh-Hant': '訓練模式',
      'de': 'Trainingsmodi',
      'es': 'Modos de entrenamiento',
      'fr': 'Modes d’entraînement',
      'it': 'Modalità di allenamento',
      'ja': 'トレーニングモード',
      'ko': '훈련 모드',
      'nl': 'Trainingsmodi',
      'ru': 'Режимы тренировки',
    },
    '4 tools': {
      'zh-Hans': '4 个工具',
      'zh-Hant': '4 個工具',
      'de': '4 Tools',
      'es': '4 herramientas',
      'fr': '4 outils',
      'it': '4 strumenti',
      'ja': '4 つのツール',
      'ko': '도구 4개',
      'nl': '4 hulpmiddelen',
      'ru': '4 инструмента',
    },
    'pts': {
      'zh-Hans': '积分',
      'zh-Hant': '積分',
      'de': 'Pkt.',
      'es': 'puntos',
      'fr': 'points',
      'it': 'pt',
      'ja': 'ポイント',
      'ko': '포인트',
      'nl': 'ptn',
      'ru': 'баллы',
    },
    'The game was imported, but Chessnut could not confirm it was cleared from board storage.':
        {
      'zh-Hans': '棋局已导入，但 Chessnut 无法确认它已从棋盘存储中清除。',
      'zh-Hant': '棋局已匯入，但 Chessnut 無法確認它已從棋盤儲存中清除。',
      'de':
          'Die Partie wurde importiert, aber Chessnut konnte nicht bestätigen, dass sie aus dem Brettspeicher gelöscht wurde.',
      'es':
          'La partida se importó, pero Chessnut no pudo confirmar que se borrara del almacenamiento del tablero.',
      'fr':
          'La partie a été importée, mais Chessnut n’a pas pu confirmer sa suppression du stockage de l’échiquier.',
      'it':
          'La partita è stata importata, ma Chessnut non ha potuto confermare che sia stata rimossa dalla memoria della scacchiera.',
      'ja': '対局はインポートされましたが、ボードの保存領域から消去されたことを Chessnut が確認できませんでした。',
      'ko': '게임은 가져왔지만 Chessnut이 보드 저장소에서 삭제되었는지 확인할 수 없습니다.',
      'nl':
          'De partij is geïmporteerd, maar Chessnut kon niet bevestigen dat deze uit de bordopslag is gewist.',
      'ru':
          'Партия импортирована, но Chessnut не смог подтвердить, что она удалена из памяти доски.',
    },
    'This board record has too few positions to build a game.': {
      'zh-Hans': '这条棋盘记录的位置太少，无法生成一盘棋局。',
      'zh-Hant': '這筆棋盤記錄的位置太少，無法建立一盤棋局。',
      'de':
          'Dieser Bretteintrag enthält zu wenige Stellungen, um eine Partie zu erstellen.',
      'es':
          'Este registro del tablero tiene muy pocas posiciones para crear una partida.',
      'fr':
          'Cet enregistrement de l’échiquier contient trop peu de positions pour créer une partie.',
      'it':
          'Questo record della scacchiera contiene troppe poche posizioni per creare una partita.',
      'ja': 'このボード記録は局面数が少なすぎるため、対局を作成できません。',
      'ko': '이 보드 기록은 게임을 만들기에 포지션이 너무 적습니다.',
      'nl':
          'Deze bordregistratie heeft te weinig stellingen om een partij te maken.',
      'ru': 'В этой записи доски слишком мало позиций, чтобы создать партию.',
    },
    'This board record could not be read as a legal game.': {
      'zh-Hans': '无法将这条棋盘记录读取为合法棋局。',
      'zh-Hant': '無法將這筆棋盤記錄讀取為合法棋局。',
      'de':
          'Dieser Bretteintrag konnte nicht als legale Partie gelesen werden.',
      'es': 'Este registro del tablero no se pudo leer como una partida legal.',
      'fr':
          'Cet enregistrement de l’échiquier n’a pas pu être lu comme une partie légale.',
      'it':
          'Questo record della scacchiera non può essere letto come una partita legale.',
      'ja': 'このボード記録を合法な対局として読み取れませんでした。',
      'ko': '이 보드 기록을 합법적인 게임으로 읽을 수 없습니다.',
      'nl':
          'Deze bordregistratie kon niet als een legale partij worden gelezen.',
      'ru': 'Эту запись доски не удалось прочитать как допустимую партию.',
    },
    'A board game could not be imported.': {
      'zh-Hans': '有一盘棋盘棋局无法导入。',
      'zh-Hant': '有一盤棋盤棋局無法匯入。',
      'de': 'Eine Brettpartie konnte nicht importiert werden.',
      'es': 'No se pudo importar una partida del tablero.',
      'fr': 'Une partie de l’échiquier n’a pas pu être importée.',
      'it': 'Non è stato possibile importare una partita dalla scacchiera.',
      'ja': 'ボード上の対局をインポートできませんでした。',
      'ko': '보드 게임을 가져올 수 없습니다.',
      'nl': 'Een bordpartij kon niet worden geïmporteerd.',
      'ru': 'Не удалось импортировать партию с доски.',
    },
  };
  return translations[text]?[key];
}

String? _boardStorageImportTranslations(String text, String key) {
  final foundEveryReadable = RegExp(
          r'^Found (\d+) saved games? on the board\. Chessnut will import every readable game\.$')
      .firstMatch(text);
  if (foundEveryReadable != null) {
    final count = foundEveryReadable.group(1)!;
    return switch (key) {
      'zh-Hans' => '在棋盘上找到 $count 盘已保存棋局。Chessnut 将导入所有可读取的棋局。',
      'zh-Hant' => '在棋盤上找到 $count 盤已儲存棋局。Chessnut 將匯入所有可讀取的棋局。',
      'de' =>
        '$count gespeicherte Partie(n) auf dem Brett gefunden. Chessnut importiert jede lesbare Partie.',
      'es' =>
        'Se encontraron $count partidas guardadas en el tablero. Chessnut importará todas las partidas legibles.',
      'fr' =>
        '$count parties enregistrées trouvées sur l’échiquier. Chessnut importera toutes les parties lisibles.',
      'it' =>
        'Trovate $count partite salvate sulla scacchiera. Chessnut importerà tutte le partite leggibili.',
      'ja' => 'ボード上に保存済み対局が $count 件見つかりました。Chessnut は読み取れるすべての対局をインポートします。',
      'ko' => '보드에서 저장된 게임 $count개를 찾았습니다. Chessnut은 읽을 수 있는 모든 게임을 가져옵니다.',
      'nl' =>
        '$count opgeslagen partijen op het bord gevonden. Chessnut importeert elke leesbare partij.',
      'ru' =>
        'На доске найдено сохраненных партий: $count. Chessnut импортирует все читаемые партии.',
      _ => null,
    };
  }

  final importAfterTap =
      RegExp(r'^(\d+) saved games? will be imported after you tap Import\.$')
          .firstMatch(text);
  if (importAfterTap != null) {
    final count = importAfterTap.group(1)!;
    return switch (key) {
      'zh-Hans' => '点击“导入”后将导入 $count 盘已保存棋局。',
      'zh-Hant' => '點擊「匯入」後將匯入 $count 盤已儲存棋局。',
      'de' => '$count gespeicherte Partie(n) werden nach Import importiert.',
      'es' =>
        '$count partidas guardadas se importarán después de tocar Importar.',
      'fr' =>
        '$count parties enregistrées seront importées après avoir touché Importer.',
      'it' =>
        '$count partite salvate verranno importate dopo aver toccato Importa.',
      'ja' => 'インポートをタップすると、保存済み対局 $count 件をインポートします。',
      'ko' => 'Import를 누르면 저장된 게임 $count개를 가져옵니다.',
      'nl' =>
        '$count opgeslagen partijen worden geïmporteerd nadat je op Import tikt.',
      'ru' =>
        'Сохраненных партий будет импортировано после нажатия Import: $count.',
      _ => null,
    };
  }

  final foundSavedGames = RegExp(
          r'^Found (\d+) saved games? on the board\. Chessnut will import the next readable game first\.$')
      .firstMatch(text);
  if (foundSavedGames != null) {
    final count = foundSavedGames.group(1)!;
    return switch (key) {
      'zh-Hans' => '在棋盘上找到 $count 盘已保存棋局。Chessnut 将优先导入下一盘可读取棋局。',
      'zh-Hant' => '在棋盤上找到 $count 盤已儲存棋局。Chessnut 將優先匯入下一盤可讀取棋局。',
      'de' =>
        '$count gespeicherte Partie(n) auf dem Brett gefunden. Chessnut importiert zuerst die nächste lesbare Partie.',
      'es' =>
        'Se encontraron $count partidas guardadas en el tablero. Chessnut importará primero la siguiente partida legible.',
      'fr' =>
        '$count parties enregistrées trouvées sur l’échiquier. Chessnut importera d’abord la prochaine partie lisible.',
      'it' =>
        'Trovate $count partite salvate sulla scacchiera. Chessnut importerà prima la prossima partita leggibile.',
      'ja' => 'ボード上に保存済み対局が $count 件見つかりました。Chessnut は次に読み取れる対局を先にインポートします。',
      'ko' =>
        '보드에서 저장된 게임 $count개를 찾았습니다. Chessnut은 다음으로 읽을 수 있는 게임을 먼저 가져옵니다.',
      'nl' =>
        '$count opgeslagen partijen op het bord gevonden. Chessnut importeert eerst de volgende leesbare partij.',
      'ru' =>
        'На доске найдено сохраненных партий: $count. Chessnut сначала импортирует следующую читаемую партию.',
      _ => null,
    };
  }

  final importResult =
      RegExp(r'^(\d+) games? imported\. (\d+) skipped, (\d+) failed\.$')
          .firstMatch(text);
  if (importResult != null) {
    final imported = importResult.group(1)!;
    final skipped = importResult.group(2)!;
    final failed = importResult.group(3)!;
    return switch (key) {
      'zh-Hans' => '已导入 $imported 盘。跳过 $skipped 盘，失败 $failed 盘。',
      'zh-Hant' => '已匯入 $imported 盤。略過 $skipped 盤，失敗 $failed 盤。',
      'de' =>
        '$imported importiert. $skipped übersprungen, $failed fehlgeschlagen.',
      'es' => '$imported importadas. $skipped omitidas, $failed fallidas.',
      'fr' => '$imported importées. $skipped ignorées, $failed en échec.',
      'it' => '$imported importate. $skipped saltate, $failed non riuscite.',
      'ja' => '$imported 件をインポートしました。$skipped 件スキップ、$failed 件失敗。',
      'ko' => '$imported개를 가져왔습니다. $skipped개 건너뜀, $failed개 실패.',
      'nl' => '$imported geïmporteerd. $skipped overgeslagen, $failed mislukt.',
      'ru' => 'Импортировано: $imported. Пропущено: $skipped, ошибок: $failed.',
      _ => null,
    };
  }

  final plyDetected = RegExp(
          r'^(\d+) ply detected\. Duplicate games will be skipped automatically\.$')
      .firstMatch(text);
  if (plyDetected != null) {
    final ply = plyDetected.group(1)!;
    return switch (key) {
      'zh-Hans' => '检测到 $ply 个半回合。重复棋局会自动跳过。',
      'zh-Hant' => '偵測到 $ply 個半回合。重複棋局會自動略過。',
      'de' =>
        '$ply Halbzüge erkannt. Doppelte Partien werden automatisch übersprungen.',
      'es' =>
        '$ply medias jugadas detectadas. Las partidas duplicadas se omiten automáticamente.',
      'fr' =>
        '$ply demi-coups détectés. Les doublons seront ignorés automatiquement.',
      'it' =>
        '$ply mezze mosse rilevate. Le partite duplicate saranno saltate automaticamente.',
      'ja' => '$ply プライを検出しました。重複する対局は自動的にスキップされます。',
      'ko' => '$ply ply를 감지했습니다. 중복 게임은 자동으로 건너뜁니다.',
      'nl' =>
        '$ply halve zetten gevonden. Dubbele partijen worden automatisch overgeslagen.',
      'ru' =>
        'Обнаружено полуходов: $ply. Дубликаты будут пропущены автоматически.',
      _ => null,
    };
  }

  final illegalMove = RegExp(
    r'^Move (\d+) could not be converted into a legal chess move\.$',
  ).firstMatch(text);
  if (illegalMove != null) {
    final move = illegalMove.group(1)!;
    return switch (key) {
      'zh-Hans' => '第 $move 步无法转换为合法的国际象棋着法。',
      'zh-Hant' => '第 $move 步無法轉換為合法的西洋棋著法。',
      'de' =>
        'Zug $move konnte nicht in einen legalen Schachzug umgewandelt werden.',
      'es' =>
        'La jugada $move no se pudo convertir en una jugada legal de ajedrez.',
      'fr' => 'Le coup $move n’a pas pu être converti en coup d’échecs légal.',
      'it' => 'La mossa $move non può essere convertita in una mossa legale.',
      'ja' => '$move 手目を合法手に変換できませんでした。',
      'ko' => '$move번째 수를 합법적인 체스 수로 변환할 수 없습니다.',
      'nl' => 'Zet $move kon niet worden omgezet naar een legale schaakzet.',
      'ru' => 'Ход $move не удалось преобразовать в допустимый шахматный ход.',
      _ => null,
    };
  }

  const translations = <String, Map<String, String>>{
    'Saved games': {
      'zh-Hans': '已保存棋局',
      'zh-Hant': '已儲存棋局',
      'de': 'Gespeicherte Partien',
      'es': 'Partidas guardadas',
      'fr': 'Parties enregistrées',
      'it': 'Partite salvate',
      'ja': '保存済み対局',
      'ko': '저장된 게임',
      'nl': 'Opgeslagen partijen',
      'ru': 'Сохраненные партии',
    },
    'Import OTB': {
      'zh-Hans': '导入 OTB',
      'zh-Hant': '匯入 OTB',
      'de': 'OTB importieren',
      'es': 'Importar OTB',
      'fr': 'Importer OTB',
      'it': 'Importa OTB',
      'ja': 'OTBをインポート',
      'ko': 'OTB 가져오기',
      'nl': 'OTB importeren',
      'ru': 'Импорт OTB',
    },
    'Import saved board games': {
      'zh-Hans': '导入棋盘保存的棋局',
      'zh-Hant': '匯入棋盤儲存的棋局',
      'de': 'Gespeicherte Brettpartien importieren',
      'es': 'Importar partidas guardadas del tablero',
      'fr': 'Importer les parties enregistrées sur l’échiquier',
      'it': 'Importa partite salvate sulla scacchiera',
      'ja': 'ボードに保存された対局をインポート',
      'ko': '보드에 저장된 게임 가져오기',
      'nl': 'Opgeslagen bordpartijen importeren',
      'ru': 'Импорт сохраненных партий с доски',
    },
    'Connect a Chessnut board before importing saved games.': {
      'zh-Hans': '请先连接 Chessnut 棋盘，再导入已保存棋局。',
      'zh-Hant': '請先連接 Chessnut 棋盤，再匯入已儲存棋局。',
      'de':
          'Verbinde ein Chessnut-Brett, bevor du gespeicherte Partien importierst.',
      'es': 'Conecta un tablero Chessnut antes de importar partidas guardadas.',
      'fr':
          'Connectez un échiquier Chessnut avant d’importer les parties enregistrées.',
      'it':
          'Collega una scacchiera Chessnut prima di importare le partite salvate.',
      'ja': '保存済み対局をインポートする前に Chessnut ボードを接続してください。',
      'ko': '저장된 게임을 가져오기 전에 Chessnut 보드를 연결하세요.',
      'nl':
          'Verbind een Chessnut-bord voordat je opgeslagen partijen importeert.',
      'ru': 'Подключите доску Chessnut перед импортом сохраненных партий.',
    },
    'Sign in before importing saved board games.': {
      'zh-Hans': '请先登录，再导入棋盘保存的棋局。',
      'zh-Hant': '請先登入，再匯入棋盤儲存的棋局。',
      'de': 'Melde dich an, bevor du gespeicherte Brettpartien importierst.',
      'es': 'Inicia sesión antes de importar partidas guardadas del tablero.',
      'fr':
          'Connectez-vous avant d’importer les parties enregistrées sur l’échiquier.',
      'it': 'Accedi prima di importare le partite salvate sulla scacchiera.',
      'ja': 'ボードに保存された対局をインポートする前にサインインしてください。',
      'ko': '보드에 저장된 게임을 가져오기 전에 로그인하세요.',
      'nl': 'Meld je aan voordat je opgeslagen bordpartijen importeert.',
      'ru': 'Войдите в аккаунт перед импортом сохранённых партий с доски.',
    },
    'Connect a board that supports saved game import.': {
      'zh-Hans': '请连接支持导入已保存棋局的棋盘。',
      'zh-Hant': '請連接支援匯入已儲存棋局的棋盤。',
      'de':
          'Verbinde ein Brett, das den Import gespeicherter Partien unterstützt.',
      'es':
          'Conecta un tablero compatible con la importación de partidas guardadas.',
      'fr':
          'Connectez un échiquier compatible avec l’import de parties enregistrées.',
      'it':
          'Collega una scacchiera che supporti l’importazione delle partite salvate.',
      'ja': '保存済み対局のインポートに対応したボードを接続してください。',
      'ko': '저장된 게임 가져오기를 지원하는 보드를 연결하세요.',
      'nl': 'Verbind een bord dat import van opgeslagen partijen ondersteunt.',
      'ru': 'Подключите доску, которая поддерживает импорт сохранённых партий.',
    },
    'Saved game import is available through the Chessnut USB board service in this build.':
        {
      'zh-Hans': '此版本可通过 Chessnut USB 棋盘服务导入已保存棋局。',
      'zh-Hant': '此版本可透過 Chessnut USB 棋盤服務匯入已儲存棋局。',
      'de':
          'Der Import gespeicherter Partien ist in diesem Build über den Chessnut-USB-Brettdienst verfügbar.',
      'es':
          'La importación de partidas guardadas está disponible mediante el servicio USB de tablero Chessnut en esta versión.',
      'fr':
          'Dans cette version, l’import des parties enregistrées passe par le service d’échiquier USB Chessnut.',
      'it':
          'In questa build l’importazione delle partite salvate è disponibile tramite il servizio USB della scacchiera Chessnut.',
      'ja': 'このビルドでは、Chessnut USB ボードサービス経由で保存済み対局をインポートできます。',
      'ko': '이 빌드에서는 Chessnut USB 보드 서비스를 통해 저장된 게임을 가져올 수 있습니다.',
      'nl':
          'In deze build is import van opgeslagen partijen beschikbaar via de Chessnut USB-bordservice.',
      'ru':
          'В этой сборке импорт сохраненных партий доступен через USB-сервис доски Chessnut.',
    },
    'Reading board storage count.': {
      'zh-Hans': '正在读取棋盘存储数量。',
      'zh-Hant': '正在讀取棋盤儲存數量。',
      'de': 'Brettspeicher wird gezählt.',
      'es': 'Leyendo el recuento del almacenamiento del tablero.',
      'fr': 'Lecture du nombre de parties stockées sur l’échiquier.',
      'it': 'Lettura del conteggio nella memoria della scacchiera.',
      'ja': 'ボードストレージの件数を読み取っています。',
      'ko': '보드 저장 개수를 읽는 중입니다.',
      'nl': 'Aantal in bordopslag lezen.',
      'ru': 'Чтение количества партий в памяти доски.',
    },
    'Chessnut could not read the board storage count.': {
      'zh-Hans': 'Chessnut 无法读取棋盘存储数量。',
      'zh-Hant': 'Chessnut 無法讀取棋盤儲存數量。',
      'de': 'Chessnut konnte die Anzahl im Brettspeicher nicht lesen.',
      'es': 'Chessnut no pudo leer el recuento del almacenamiento del tablero.',
      'fr':
          'Chessnut n’a pas pu lire le nombre de parties stockées sur l’échiquier.',
      'it':
          'Chessnut non ha potuto leggere il conteggio nella memoria della scacchiera.',
      'ja': 'Chessnut はボードストレージの件数を読み取れませんでした。',
      'ko': 'Chessnut이 보드 저장 개수를 읽을 수 없습니다.',
      'nl': 'Chessnut kon het aantal in de bordopslag niet lezen.',
      'ru': 'Chessnut не удалось прочитать количество партий в памяти доски.',
    },
    'No saved games were found on the connected board.': {
      'zh-Hans': '已连接棋盘上没有找到已保存棋局。',
      'zh-Hant': '已連接棋盤上沒有找到已儲存棋局。',
      'de':
          'Auf dem verbundenen Brett wurden keine gespeicherten Partien gefunden.',
      'es': 'No se encontraron partidas guardadas en el tablero conectado.',
      'fr':
          'Aucune partie enregistrée n’a été trouvée sur l’échiquier connecté.',
      'it': 'Nessuna partita salvata trovata sulla scacchiera collegata.',
      'ja': '接続中のボードに保存済み対局は見つかりませんでした。',
      'ko': '연결된 보드에서 저장된 게임을 찾을 수 없습니다.',
      'nl': 'Er zijn geen opgeslagen partijen gevonden op het verbonden bord.',
      'ru': 'На подключенной доске не найдено сохраненных партий.',
    },
    'Checking board storage': {
      'zh-Hans': '正在检查棋盘存储',
      'zh-Hant': '正在檢查棋盤儲存',
      'de': 'Brettspeicher prüfen',
      'es': 'Comprobando almacenamiento del tablero',
      'fr': 'Vérification du stockage de l’échiquier',
      'it': 'Controllo memoria scacchiera',
      'ja': 'ボードストレージを確認中',
      'ko': '보드 저장소 확인 중',
      'nl': 'Bordopslag controleren',
      'ru': 'Проверка памяти доски',
    },
    'Cannot read storage count': {
      'zh-Hans': '无法读取存储数量',
      'zh-Hant': '無法讀取儲存數量',
      'de': 'Anzahl nicht lesbar',
      'es': 'No se puede leer el recuento',
      'fr': 'Nombre illisible',
      'it': 'Conteggio non leggibile',
      'ja': '件数を読み取れません',
      'ko': '저장 개수를 읽을 수 없음',
      'nl': 'Aantal niet leesbaar',
      'ru': 'Не удалось прочитать количество',
    },
    'Saved games found': {
      'zh-Hans': '找到已保存棋局',
      'zh-Hant': '找到已儲存棋局',
      'de': 'Gespeicherte Partien gefunden',
      'es': 'Partidas guardadas encontradas',
      'fr': 'Parties enregistrées trouvées',
      'it': 'Partite salvate trovate',
      'ja': '保存済み対局が見つかりました',
      'ko': '저장된 게임 발견',
      'nl': 'Opgeslagen partijen gevonden',
      'ru': 'Найдены сохраненные партии',
    },
    'No saved games found': {
      'zh-Hans': '未找到已保存棋局',
      'zh-Hant': '未找到已儲存棋局',
      'de': 'Keine gespeicherten Partien gefunden',
      'es': 'No se encontraron partidas guardadas',
      'fr': 'Aucune partie enregistrée trouvée',
      'it': 'Nessuna partita salvata trovata',
      'ja': '保存済み対局は見つかりません',
      'ko': '저장된 게임 없음',
      'nl': 'Geen opgeslagen partijen gevonden',
      'ru': 'Сохраненные партии не найдены',
    },
    'Chessnut is checking how many games are saved on the board.': {
      'zh-Hans': 'Chessnut 正在检查棋盘上保存了多少盘棋局。',
      'zh-Hant': 'Chessnut 正在檢查棋盤上儲存了多少盤棋局。',
      'de': 'Chessnut prüft, wie viele Partien auf dem Brett gespeichert sind.',
      'es':
          'Chessnut está comprobando cuántas partidas hay guardadas en el tablero.',
      'fr':
          'Chessnut vérifie combien de parties sont enregistrées sur l’échiquier.',
      'it':
          'Chessnut sta controllando quante partite sono salvate sulla scacchiera.',
      'ja': 'Chessnut はボードに保存された対局数を確認しています。',
      'ko': 'Chessnut이 보드에 저장된 게임 수를 확인하고 있습니다.',
      'nl':
          'Chessnut controleert hoeveel partijen op het bord zijn opgeslagen.',
      'ru': 'Chessnut проверяет, сколько партий сохранено на доске.',
    },
    'Try again after confirming the board is still connected.': {
      'zh-Hans': '确认棋盘仍保持连接后再试一次。',
      'zh-Hant': '確認棋盤仍保持連線後再試一次。',
      'de': 'Versuche es erneut, nachdem du die Brettverbindung geprüft hast.',
      'es': 'Inténtalo de nuevo tras confirmar que el tablero sigue conectado.',
      'fr':
          'Réessayez après avoir vérifié que l’échiquier est toujours connecté.',
      'it':
          'Riprova dopo aver confermato che la scacchiera è ancora collegata.',
      'ja': 'ボードが接続されたままであることを確認してから再試行してください。',
      'ko': '보드가 계속 연결되어 있는지 확인한 뒤 다시 시도하세요.',
      'nl':
          'Probeer opnieuw nadat je hebt bevestigd dat het bord verbonden is.',
      'ru': 'Повторите попытку после проверки подключения доски.',
    },
    'The connected board does not report any saved games.': {
      'zh-Hans': '已连接棋盘未报告任何已保存棋局。',
      'zh-Hant': '已連接棋盤未回報任何已儲存棋局。',
      'de': 'Das verbundene Brett meldet keine gespeicherten Partien.',
      'es': 'El tablero conectado no informa de partidas guardadas.',
      'fr': 'L’échiquier connecté ne signale aucune partie enregistrée.',
      'it': 'La scacchiera collegata non segnala partite salvate.',
      'ja': '接続中のボードから保存済み対局は報告されていません。',
      'ko': '연결된 보드가 저장된 게임을 보고하지 않습니다.',
      'nl': 'Het verbonden bord meldt geen opgeslagen partijen.',
      'ru': 'Подключенная доска не сообщает о сохраненных партиях.',
    },
    'Pull stored games from the connected board into Game Record.': {
      'zh-Hans': '把已连接棋盘中保存的棋局导入 Game Record。',
      'zh-Hant': '將已連接棋盤中儲存的棋局匯入 Game Record。',
      'de':
          'Importiere gespeicherte Partien vom verbundenen Brett in Game Record.',
      'es':
          'Importa en Game Record las partidas guardadas en el tablero conectado.',
      'fr':
          'Importez dans Game Record les parties stockées sur l’échiquier connecté.',
      'it':
          'Importa in Game Record le partite salvate sulla scacchiera collegata.',
      'ja': '接続中のボードに保存された対局を Game Record に取り込みます。',
      'ko': '연결된 보드에 저장된 게임을 Game Record로 가져옵니다.',
      'nl': 'Haal opgeslagen partijen van het verbonden bord naar Game Record.',
      'ru':
          'Импортируйте сохранённые партии с подключённой доски в Game Record.',
    },
    'Clear imported game from board': {
      'zh-Hans': '从棋盘清除已导入棋局',
      'zh-Hant': '從棋盤清除已匯入棋局',
      'de': 'Importierte Partie vom Brett löschen',
      'es': 'Borrar del tablero la partida importada',
      'fr': 'Effacer de l’échiquier la partie importée',
      'it': 'Cancella dalla scacchiera la partita importata',
      'ja': 'インポート済み対局をボードから消去',
      'ko': '가져온 게임을 보드에서 지우기',
      'nl': 'Geïmporteerde partij van bord wissen',
      'ru': 'Очистить импортированную партию на доске',
    },
    'Optional. Leave this off until you confirm the game appears in Game records.':
        {
      'zh-Hans': '可选。建议先关闭，确认棋局出现在 Game records 后再使用。',
      'zh-Hant': '可選。建議先關閉，確認棋局出現在 Game records 後再使用。',
      'de':
          'Optional. Lass dies aus, bis du bestätigt hast, dass die Partie in Game records erscheint.',
      'es':
          'Opcional. Déjalo desactivado hasta confirmar que la partida aparece en Game records.',
      'fr':
          'Facultatif. Laissez cette option désactivée jusqu’à confirmer que la partie apparaît dans Game records.',
      'it':
          'Opzionale. Lascialo disattivato finché non confermi che la partita appare in Game records.',
      'ja': '任意です。対局が Game records に表示されるまでオフのままにしてください。',
      'ko': '선택 사항입니다. 게임이 Game records에 나타나는 것을 확인할 때까지 꺼 두세요.',
      'nl':
          'Optioneel. Laat dit uit totdat je bevestigt dat de partij in Game records staat.',
      'ru':
          'Необязательно. Оставьте выключенным, пока не убедитесь, что партия появилась в Game records.',
    },
    'Importing': {
      'zh-Hans': '正在导入',
      'zh-Hant': '正在匯入',
      'de': 'Import läuft',
      'es': 'Importando',
      'fr': 'Importation',
      'it': 'Importazione',
      'ja': 'インポート中',
      'ko': '가져오는 중',
      'nl': 'Importeren',
      'ru': 'Импорт',
    },
    'Clear': {
      'zh-Hans': '清除',
      'zh-Hant': '清除',
      'de': 'Löschen',
      'es': 'Borrar',
      'fr': 'Effacer',
      'it': 'Cancella',
      'ja': '消去',
      'ko': '지우기',
      'nl': 'Wissen',
      'ru': 'Очистить',
    },
    'Board games imported': {
      'zh-Hans': '棋盘棋局已导入',
      'zh-Hant': '棋盤棋局已匯入',
      'de': 'Brettpartien importiert',
      'es': 'Partidas del tablero importadas',
      'fr': 'Parties de l’échiquier importées',
      'it': 'Partite della scacchiera importate',
      'ja': 'ボード対局をインポートしました',
      'ko': '보드 게임을 가져왔습니다',
      'nl': 'Bordpartijen geïmporteerd',
      'ru': 'Партии с доски импортированы',
    },
    'No readable saved game': {
      'zh-Hans': '没有可读取的已保存棋局',
      'zh-Hant': '沒有可讀取的已儲存棋局',
      'de': 'Keine lesbare gespeicherte Partie',
      'es': 'No hay partidas guardadas legibles',
      'fr': 'Aucune partie enregistrée lisible',
      'it': 'Nessuna partita salvata leggibile',
      'ja': '読み取れる保存済み対局がありません',
      'ko': '읽을 수 있는 저장된 게임 없음',
      'nl': 'Geen leesbare opgeslagen partij',
      'ru': 'Нет читаемой сохраненной партии',
    },
    'Ready to import': {
      'zh-Hans': '可以导入',
      'zh-Hant': '可以匯入',
      'de': 'Bereit zum Import',
      'es': 'Listo para importar',
      'fr': 'Prêt à importer',
      'it': 'Pronto per l’importazione',
      'ja': 'インポート準備完了',
      'ko': '가져올 준비 완료',
      'nl': 'Klaar om te importeren',
      'ru': 'Готово к импорту',
    },
    'Already imported': {
      'zh-Hans': '已导入',
      'zh-Hant': '已匯入',
      'de': 'Bereits importiert',
      'es': 'Ya importada',
      'fr': 'Déjà importée',
      'it': 'Già importata',
      'ja': 'インポート済み',
      'ko': '이미 가져옴',
      'nl': 'Al geïmporteerd',
      'ru': 'Уже импортировано',
    },
    'Cannot import': {
      'zh-Hans': '无法导入',
      'zh-Hant': '無法匯入',
      'de': 'Import nicht möglich',
      'es': 'No se puede importar',
      'fr': 'Import impossible',
      'it': 'Impossibile importare',
      'ja': 'インポート不可',
      'ko': '가져올 수 없음',
      'nl': 'Kan niet importeren',
      'ru': 'Нельзя импортировать',
    },
    'This saved game cannot be imported': {
      'zh-Hans': '这盘已保存棋局无法导入',
      'zh-Hant': '這盤已儲存棋局無法匯入',
      'de': 'Diese gespeicherte Partie kann nicht importiert werden',
      'es': 'Esta partida guardada no se puede importar',
      'fr': 'Cette partie enregistrée ne peut pas être importée',
      'it': 'Questa partita salvata non può essere importata',
      'ja': 'この保存済み対局はインポートできません',
      'ko': '이 저장된 게임은 가져올 수 없습니다',
      'nl': 'Deze opgeslagen partij kan niet worden geïmporteerd',
      'ru': 'Эту сохраненную партию нельзя импортировать',
    },
    'No saved board game is ready on the connected board.': {
      'zh-Hans': '已连接棋盘上没有可导入的已保存棋局。',
      'zh-Hant': '已連接棋盤上沒有可匯入的已儲存棋局。',
      'de': 'Auf dem verbundenen Brett ist keine gespeicherte Partie bereit.',
      'es': 'No hay ninguna partida guardada lista en el tablero conectado.',
      'fr': 'Aucune partie enregistrée n’est prête sur l’échiquier connecté.',
      'it': 'Nessuna partita salvata è pronta sulla scacchiera collegata.',
      'ja': '接続中のボードに準備できている保存済み対局はありません。',
      'ko': '연결된 보드에 준비된 저장 게임이 없습니다.',
      'nl': 'Er staat geen opgeslagen bordpartij klaar op het verbonden bord.',
      'ru': 'На подключенной доске нет готовой сохраненной партии.',
    },
    'This saved game already exists in Game records and will be skipped.': {
      'zh-Hans': '这盘已保存棋局已存在于 Game records，将会跳过。',
      'zh-Hant': '這盤已儲存棋局已存在於 Game records，將會略過。',
      'de':
          'Diese gespeicherte Partie existiert bereits in Game records und wird übersprungen.',
      'es': 'Esta partida guardada ya existe en Game records y se omitirá.',
      'fr':
          'Cette partie enregistrée existe déjà dans Game records et sera ignorée.',
      'it': 'Questa partita salvata esiste già in Game records e sarà saltata.',
      'ja': 'この保存済み対局はすでに Game records にあるためスキップされます。',
      'ko': '이 저장된 게임은 이미 Game records에 있으므로 건너뜁니다.',
      'nl':
          'Deze opgeslagen partij bestaat al in Game records en wordt overgeslagen.',
      'ru': 'Эта сохраненная партия уже есть в Game records и будет пропущена.',
    },
  };
  return translations[text]?[key];
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return const {
      'en',
      'zh',
      'de',
      'es',
      'fr',
      'it',
      'ja',
      'ko',
      'nl',
      'ru',
      'pt',
      'pl',
      'ro',
      'cs',
      'ar',
      'he',
    }.contains(locale.languageCode);
  }

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(AppStrings(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}

String? _criticalVisibleTranslations(String text, String key) {
  final visibleSweep = _visibleSweepTranslations(text, key);
  if (visibleSweep != null) return visibleSweep;

  const translations = <String, Map<String, String>>{
    'Continue online game': {
      'zh-Hans': '继续在线对局',
      'zh-Hant': '繼續線上對局',
      'de': 'Online-Partie fortsetzen',
      'es': 'Continuar partida online',
      'fr': 'Reprendre la partie en ligne',
      'it': 'Continua partita online',
      'ja': 'オンライン対局を続ける',
      'ko': '온라인 대국 계속하기',
      'nl': 'Online partij hervatten',
      'ru': 'Продолжить онлайн-партию',
    },
    'Continue bot game': {
      'zh-Hans': '继续机器人对局',
      'zh-Hant': '繼續機器人對局',
      'de': 'Bot-Partie fortsetzen',
      'es': 'Continuar partida contra bot',
      'fr': 'Reprendre la partie contre le bot',
      'it': 'Continua partita contro bot',
      'ja': 'Bot対局を続ける',
      'ko': '봇 대국 계속하기',
      'nl': 'Botpartij hervatten',
      'ru': 'Продолжить игру с ботом',
    },
    'Resume': {
      'zh-Hans': '继续',
      'zh-Hant': '繼續',
      'de': 'Fortsetzen',
      'es': 'Continuar',
      'fr': 'Reprendre',
      'it': 'Riprendi',
      'ja': '再開',
      'ko': '계속',
      'nl': 'Hervatten',
      'ru': 'Продолжить',
    },
    'Checking': {
      'zh-Hans': '检查中',
      'zh-Hant': '檢查中',
      'de': 'Prüfung',
      'es': 'Comprobando',
      'fr': 'Vérification',
      'it': 'Controllo',
      'ja': '確認中',
      'ko': '확인 중',
      'nl': 'Controleren',
      'ru': 'Проверка',
    },
    'Stockfish analysis failed. Please try again.': {
      'zh-Hans': 'Stockfish 分析失败，请重试。',
      'zh-Hant': 'Stockfish 分析失敗，請重試。',
      'de': 'Stockfish-Analyse fehlgeschlagen. Bitte erneut versuchen.',
      'es': 'El análisis de Stockfish falló. Inténtalo de nuevo.',
      'fr': 'L’analyse Stockfish a échoué. Réessayez.',
      'it': 'Analisi Stockfish non riuscita. Riprova.',
      'ja': 'Stockfish の分析に失敗しました。もう一度お試しください。',
      'ko': 'Stockfish 분석에 실패했습니다. 다시 시도해 주세요.',
      'nl': 'Stockfish-analyse mislukt. Probeer opnieuw.',
      'ru': 'Анализ Stockfish не удался. Повторите попытку.',
    },
    'Stockfish is not ready on this device. Showing a quick local review instead.':
        {
      'zh-Hans': '这台设备上的 Stockfish 尚未准备好，先显示快速本地复盘。',
      'zh-Hant': '這台裝置上的 Stockfish 尚未準備好，先顯示快速本機複盤。',
      'de':
          'Stockfish ist auf diesem Gerät noch nicht bereit. Stattdessen wird eine schnelle lokale Analyse angezeigt.',
      'es':
          'Stockfish no está listo en este dispositivo. Se mostrará una revisión local rápida.',
      'fr':
          'Stockfish n’est pas encore prêt sur cet appareil. Une analyse locale rapide s’affiche à la place.',
      'it':
          'Stockfish non è ancora pronto su questo dispositivo. Mostro invece una revisione locale rapida.',
      'ja': 'この端末では Stockfish の準備ができていません。代わりに簡易ローカルレビューを表示します。',
      'ko': '이 기기에서 Stockfish가 아직 준비되지 않았습니다. 빠른 로컬 복기를 대신 표시합니다.',
      'nl':
          'Stockfish is nog niet klaar op dit apparaat. Er wordt een snelle lokale review getoond.',
      'ru':
          'Stockfish на этом устройстве ещё не готов. Будет показан быстрый локальный разбор.',
    },
    'This PGN could not be read. Check the PGN text and try again.': {
      'zh-Hans': '无法读取这份 PGN。请检查 PGN 文本后重试。',
      'zh-Hant': '無法讀取這份 PGN。請檢查 PGN 文字後重試。',
      'de':
          'Diese PGN konnte nicht gelesen werden. Prüfe den PGN-Text und versuche es erneut.',
      'es':
          'No se pudo leer este PGN. Revisa el texto PGN e inténtalo de nuevo.',
      'fr': 'Impossible de lire ce PGN. Vérifiez le texte PGN et réessayez.',
      'it': 'Impossibile leggere questo PGN. Controlla il testo PGN e riprova.',
      'ja': 'この PGN を読み取れませんでした。PGN テキストを確認してもう一度お試しください。',
      'ko': '이 PGN을 읽을 수 없습니다. PGN 텍스트를 확인하고 다시 시도해 주세요.',
      'nl':
          'Deze PGN kon niet worden gelezen. Controleer de PGN-tekst en probeer opnieuw.',
      'ru':
          'Не удалось прочитать этот PGN. Проверьте текст PGN и повторите попытку.',
    },
    'This PGN has no playable moves. Check the PGN text and try again.': {
      'zh-Hans': '这份 PGN 没有可复盘的着法。请检查 PGN 文本后重试。',
      'zh-Hant': '這份 PGN 沒有可複盤的著法。請檢查 PGN 文字後重試。',
      'de':
          'Diese PGN enthält keine spielbaren Züge. Prüfe den PGN-Text und versuche es erneut.',
      'es':
          'Este PGN no tiene jugadas reproducibles. Revisa el texto PGN e inténtalo de nuevo.',
      'fr':
          'Ce PGN ne contient aucun coup jouable. Vérifiez le texte PGN et réessayez.',
      'it':
          'Questo PGN non contiene mosse riproducibili. Controlla il testo PGN e riprova.',
      'ja': 'この PGN には再生できる手がありません。PGN テキストを確認してもう一度お試しください。',
      'ko': '이 PGN에는 재생할 수 있는 수가 없습니다. PGN 텍스트를 확인하고 다시 시도해 주세요.',
      'nl':
          'Deze PGN bevat geen speelbare zetten. Controleer de PGN-tekst en probeer opnieuw.',
      'ru':
          'В этом PGN нет ходов для воспроизведения. Проверьте текст PGN и повторите попытку.',
    },
    'This PGN includes a move Chessnut cannot read. Check the move list and try again.':
        {
      'zh-Hans': '这份 PGN 包含 Chessnut 无法读取的着法。请检查着法列表后重试。',
      'zh-Hant': '這份 PGN 包含 Chessnut 無法讀取的著法。請檢查著法列表後重試。',
      'de':
          'Diese PGN enthält einen Zug, den Chessnut nicht lesen kann. Prüfe die Zugliste und versuche es erneut.',
      'es':
          'Este PGN incluye una jugada que Chessnut no puede leer. Revisa la lista de jugadas e inténtalo de nuevo.',
      'fr':
          'Ce PGN contient un coup que Chessnut ne peut pas lire. Vérifiez la liste des coups et réessayez.',
      'it':
          'Questo PGN contiene una mossa che Chessnut non riesce a leggere. Controlla la lista mosse e riprova.',
      'ja': 'この PGN には Chessnut が読み取れない手があります。手順リストを確認してもう一度お試しください。',
      'ko': '이 PGN에는 Chessnut이 읽을 수 없는 수가 있습니다. 수 목록을 확인하고 다시 시도해 주세요.',
      'nl':
          'Deze PGN bevat een zet die Chessnut niet kan lezen. Controleer de zettenlijst en probeer opnieuw.',
      'ru':
          'В этом PGN есть ход, который Chessnut не может прочитать. Проверьте список ходов и повторите попытку.',
    },
    'Could not start the Lichess game search. Check your connection and authorize Lichess again.':
        {
      'zh-Hans': '无法开始搜索 Lichess 对局。请检查网络，并重新授权 Lichess。',
      'zh-Hant': '無法開始搜尋 Lichess 對局。請檢查網路，並重新授權 Lichess。',
      'de':
          'Lichess-Partiesuche konnte nicht gestartet werden. Prüfe die Verbindung und autorisiere Lichess erneut.',
      'es':
          'No se pudo iniciar la búsqueda de partida en Lichess. Revisa la conexión y autoriza Lichess de nuevo.',
      'fr':
          'Impossible de lancer la recherche de partie Lichess. Vérifiez la connexion et autorisez Lichess à nouveau.',
      'it':
          'Impossibile avviare la ricerca partita Lichess. Controlla la connessione e autorizza di nuovo Lichess.',
      'ja': 'Lichess の対局検索を開始できませんでした。接続を確認し、Lichess を再認証してください。',
      'ko': 'Lichess 게임 검색을 시작할 수 없습니다. 연결을 확인하고 Lichess를 다시 인증해 주세요.',
      'nl':
          'Kan de Lichess-partijzoeker niet starten. Controleer je verbinding en autoriseer Lichess opnieuw.',
      'ru':
          'Не удалось начать поиск партии Lichess. Проверьте подключение и снова авторизуйте Lichess.',
    },
    'Looking for a Lichess game...': {
      'zh-Hans': '正在寻找 Lichess 对局...',
      'zh-Hant': '正在尋找 Lichess 對局...',
      'de': 'Lichess-Partie wird gesucht...',
      'es': 'Buscando una partida en Lichess...',
      'fr': 'Recherche d’une partie Lichess...',
      'it': 'Ricerca di una partita Lichess...',
      'ja': 'Lichess の対局を探しています...',
      'ko': 'Lichess 게임을 찾는 중...',
      'nl': 'Lichess-partij zoeken...',
      'ru': 'Поиск партии Lichess...',
    },
    'Still looking for a game. You can wait a little longer or try again.': {
      'zh-Hans': '仍在寻找对局。你可以再等一会儿，或稍后重试。',
      'zh-Hant': '仍在尋找對局。你可以再等一會兒，或稍後重試。',
      'de':
          'Es wird noch gesucht. Du kannst etwas länger warten oder es erneut versuchen.',
      'es':
          'Seguimos buscando partida. Puedes esperar un poco más o intentarlo de nuevo.',
      'fr':
          'La recherche continue. Vous pouvez patienter encore un peu ou réessayer.',
      'it':
          'Sto ancora cercando una partita. Puoi aspettare ancora un po’ o riprovare.',
      'ja': 'まだ対局を探しています。もう少し待つか、もう一度お試しください。',
      'ko': '아직 게임을 찾고 있습니다. 조금 더 기다리거나 다시 시도할 수 있습니다.',
      'nl':
          'Er wordt nog gezocht. Je kunt iets langer wachten of opnieuw proberen.',
      'ru':
          'Поиск партии продолжается. Можно подождать ещё немного или повторить попытку.',
    },
    'Google sign in did not finish. Please try again.': {
      'zh-Hans': 'Google 登录未完成，请重试。',
      'zh-Hant': 'Google 登入未完成，請重試。',
      'de':
          'Google-Anmeldung wurde nicht abgeschlossen. Bitte erneut versuchen.',
      'es': 'El inicio de sesión con Google no terminó. Inténtalo de nuevo.',
      'fr': 'La connexion Google n’est pas terminée. Réessayez.',
      'it': 'Accesso Google non completato. Riprova.',
      'ja': 'Google ログインが完了しませんでした。もう一度お試しください。',
      'ko': 'Google 로그인이 완료되지 않았습니다. 다시 시도해 주세요.',
      'nl': 'Google-aanmelding is niet voltooid. Probeer opnieuw.',
      'ru': 'Вход через Google не завершён. Повторите попытку.',
    },
    'Apple sign in did not finish. Please try again.': {
      'zh-Hans': 'Apple 登录未完成，请重试。',
      'zh-Hant': 'Apple 登入未完成，請重試。',
      'de':
          'Apple-Anmeldung wurde nicht abgeschlossen. Bitte erneut versuchen.',
      'es': 'El inicio de sesión con Apple no terminó. Inténtalo de nuevo.',
      'fr': 'La connexion Apple n’est pas terminée. Réessayez.',
      'it': 'Accesso Apple non completato. Riprova.',
      'ja': 'Apple ログインが完了しませんでした。もう一度お試しください。',
      'ko': 'Apple 로그인이 완료되지 않았습니다. 다시 시도해 주세요.',
      'nl': 'Apple-aanmelding is niet voltooid. Probeer opnieuw.',
      'ru': 'Вход через Apple не завершён. Повторите попытку.',
    },
    'Courses could not load': {
      'zh-Hans': '课程无法加载',
      'zh-Hant': '課程無法載入',
      'de': 'Kurse konnten nicht geladen werden',
      'es': 'No se pudieron cargar los cursos',
      'fr': 'Impossible de charger les cours',
      'it': 'Impossibile caricare i corsi',
      'ja': 'コースを読み込めませんでした',
      'ko': '강좌를 불러올 수 없습니다',
      'nl': 'Kan cursussen niet laden',
      'ru': 'Не удалось загрузить курсы',
    },
    'Check your connection and try refreshing the course library.': {
      'zh-Hans': '请检查网络连接，然后刷新课程库。',
      'zh-Hant': '請檢查網路連線，然後重新整理課程庫。',
      'de': 'Prüfe die Verbindung und aktualisiere die Kursbibliothek.',
      'es': 'Revisa la conexión e intenta actualizar la biblioteca de cursos.',
      'fr':
          'Vérifiez la connexion et essayez d’actualiser la bibliothèque de cours.',
      'it': 'Controlla la connessione e prova ad aggiornare la libreria corsi.',
      'ja': '接続を確認し、コースライブラリを更新してください。',
      'ko': '연결을 확인하고 강좌 라이브러리를 새로고침해 주세요.',
      'nl': 'Controleer je verbinding en vernieuw de cursusbibliotheek.',
      'ru': 'Проверьте подключение и обновите библиотеку курсов.',
    },
    'Lesson could not load': {
      'zh-Hans': '课时无法加载',
      'zh-Hant': '課堂無法載入',
      'de': 'Lektion konnte nicht geladen werden',
      'es': 'No se pudo cargar la lección',
      'fr': 'Impossible de charger la leçon',
      'it': 'Impossibile caricare la lezione',
      'ja': 'レッスンを読み込めませんでした',
      'ko': '레슨을 불러올 수 없습니다',
      'nl': 'Kan les niet laden',
      'ru': 'Не удалось загрузить урок',
    },
    'Check your connection and try opening this lesson again.': {
      'zh-Hans': '请检查网络连接，然后重新打开这节课。',
      'zh-Hant': '請檢查網路連線，然後重新開啟這堂課。',
      'de': 'Prüfe die Verbindung und öffne diese Lektion erneut.',
      'es': 'Revisa la conexión e intenta abrir esta lección de nuevo.',
      'fr': 'Vérifiez la connexion et essayez de rouvrir cette leçon.',
      'it':
          'Controlla la connessione e prova ad aprire di nuovo questa lezione.',
      'ja': '接続を確認し、このレッスンをもう一度開いてください。',
      'ko': '연결을 확인하고 이 레슨을 다시 열어 주세요.',
      'nl': 'Controleer je verbinding en open deze les opnieuw.',
      'ru': 'Проверьте подключение и снова откройте этот урок.',
    },
    'Video could not load. Check your connection and try again.': {
      'zh-Hans': '视频无法加载。请检查网络连接后重试。',
      'zh-Hant': '影片無法載入。請檢查網路連線後重試。',
      'de':
          'Video konnte nicht geladen werden. Prüfe die Verbindung und versuche es erneut.',
      'es':
          'No se pudo cargar el video. Revisa la conexión e inténtalo de nuevo.',
      'fr':
          'Impossible de charger la vidéo. Vérifiez la connexion et réessayez.',
      'it':
          'Impossibile caricare il video. Controlla la connessione e riprova.',
      'ja': '動画を読み込めませんでした。接続を確認してもう一度お試しください。',
      'ko': '동영상을 불러올 수 없습니다. 연결을 확인하고 다시 시도해 주세요.',
      'nl':
          'Kan video niet laden. Controleer je verbinding en probeer opnieuw.',
      'ru':
          'Не удалось загрузить видео. Проверьте подключение и повторите попытку.',
    },
    'Copy failed. Please try again.': {
      'zh-Hans': '复制失败，请重试。',
      'zh-Hant': '複製失敗，請重試。',
      'de': 'Kopieren fehlgeschlagen. Bitte erneut versuchen.',
      'es': 'No se pudo copiar. Inténtalo de nuevo.',
      'fr': 'La copie a échoué. Réessayez.',
      'it': 'Copia non riuscita. Riprova.',
      'ja': 'コピーに失敗しました。もう一度お試しください。',
      'ko': '복사에 실패했습니다. 다시 시도해 주세요.',
      'nl': 'Kopiëren mislukt. Probeer opnieuw.',
      'ru': 'Не удалось скопировать. Повторите попытку.',
    },
    'Inbox is not available right now. Check your connection and try again.': {
      'zh-Hans': '收件箱暂时不可用。请检查网络连接后重试。',
      'zh-Hant': '收件匣暫時不可用。請檢查網路連線後重試。',
      'de':
          'Posteingang ist gerade nicht verfügbar. Prüfe die Verbindung und versuche es erneut.',
      'es':
          'El buzón no está disponible ahora. Revisa la conexión e inténtalo de nuevo.',
      'fr':
          'La boîte de réception est indisponible pour le moment. Vérifiez la connexion et réessayez.',
      'it':
          'La posta in arrivo non è disponibile al momento. Controlla la connessione e riprova.',
      'ja': '受信箱は現在利用できません。接続を確認してもう一度お試しください。',
      'ko': '받은편지함을 지금 사용할 수 없습니다. 연결을 확인하고 다시 시도해 주세요.',
      'nl':
          'Inbox is nu niet beschikbaar. Controleer je verbinding en probeer opnieuw.',
      'ru':
          'Входящие сейчас недоступны. Проверьте подключение и повторите попытку.',
    },
    'Message status could not be updated. Please try again.': {
      'zh-Hans': '无法更新消息状态，请重试。',
      'zh-Hant': '無法更新訊息狀態，請重試。',
      'de':
          'Nachrichtenstatus konnte nicht aktualisiert werden. Bitte erneut versuchen.',
      'es': 'No se pudo actualizar el estado del mensaje. Inténtalo de nuevo.',
      'fr': 'Impossible de mettre à jour l’état du message. Réessayez.',
      'it': 'Impossibile aggiornare lo stato del messaggio. Riprova.',
      'ja': 'メッセージの状態を更新できませんでした。もう一度お試しください。',
      'ko': '메시지 상태를 업데이트할 수 없습니다. 다시 시도해 주세요.',
      'nl': 'Kan berichtstatus niet bijwerken. Probeer opnieuw.',
      'ru': 'Не удалось обновить статус сообщения. Повторите попытку.',
    },
    'Lichess sign-in status could not be checked. Please try again later.': {
      'zh-Hans': '无法检查 Lichess 登录状态。请稍后重试。',
      'zh-Hant': '無法檢查 Lichess 登入狀態。請稍後重試。',
      'de':
          'Lichess-Anmeldestatus konnte nicht geprüft werden. Bitte später erneut versuchen.',
      'es':
          'No se pudo comprobar el estado de inicio de sesión en Lichess. Inténtalo más tarde.',
      'fr':
          'Impossible de vérifier l’état de connexion Lichess. Réessayez plus tard.',
      'it':
          'Impossibile controllare lo stato di accesso Lichess. Riprova più tardi.',
      'ja': 'Lichess のログイン状態を確認できませんでした。後でもう一度お試しください。',
      'ko': 'Lichess 로그인 상태를 확인할 수 없습니다. 나중에 다시 시도해 주세요.',
      'nl':
          'Kan Lichess-aanmeldstatus niet controleren. Probeer het later opnieuw.',
      'ru':
          'Не удалось проверить статус входа Lichess. Повторите попытку позже.',
    },
    'Linked account update failed. Please try again.': {
      'zh-Hans': '绑定账号更新失败，请重试。',
      'zh-Hant': '綁定帳號更新失敗，請重試。',
      'de':
          'Aktualisierung des verknüpften Kontos fehlgeschlagen. Bitte erneut versuchen.',
      'es': 'No se pudo actualizar la cuenta vinculada. Inténtalo de nuevo.',
      'fr': 'La mise à jour du compte lié a échoué. Réessayez.',
      'it': 'Aggiornamento account collegato non riuscito. Riprova.',
      'ja': '連携アカウントの更新に失敗しました。もう一度お試しください。',
      'ko': '연결된 계정 업데이트에 실패했습니다. 다시 시도해 주세요.',
      'nl': 'Bijwerken van gekoppeld account mislukt. Probeer opnieuw.',
      'ru': 'Не удалось обновить связанный аккаунт. Повторите попытку.',
    },
    'Profile update is not available right now. Please try again later.': {
      'zh-Hans': '个人资料暂时无法更新。请稍后重试。',
      'zh-Hant': '個人資料暫時無法更新。請稍後重試。',
      'de':
          'Profilaktualisierung ist gerade nicht verfügbar. Bitte später erneut versuchen.',
      'es':
          'La actualización del perfil no está disponible ahora. Inténtalo más tarde.',
      'fr':
          'La mise à jour du profil est indisponible pour le moment. Réessayez plus tard.',
      'it':
          'L’aggiornamento del profilo non è disponibile al momento. Riprova più tardi.',
      'ja': 'プロフィール更新は現在利用できません。後でもう一度お試しください。',
      'ko': '프로필 업데이트를 지금 사용할 수 없습니다. 나중에 다시 시도해 주세요.',
      'nl':
          'Profiel bijwerken is nu niet beschikbaar. Probeer het later opnieuw.',
      'ru': 'Обновление профиля сейчас недоступно. Повторите попытку позже.',
    },
    'Profile update failed. Check your connection and try again.': {
      'zh-Hans': '个人资料更新失败。请检查网络连接后重试。',
      'zh-Hant': '個人資料更新失敗。請檢查網路連線後重試。',
      'de':
          'Profilaktualisierung fehlgeschlagen. Prüfe die Verbindung und versuche es erneut.',
      'es':
          'No se pudo actualizar el perfil. Revisa la conexión e inténtalo de nuevo.',
      'fr':
          'La mise à jour du profil a échoué. Vérifiez la connexion et réessayez.',
      'it':
          'Aggiornamento profilo non riuscito. Controlla la connessione e riprova.',
      'ja': 'プロフィールの更新に失敗しました。接続を確認してもう一度お試しください。',
      'ko': '프로필 업데이트에 실패했습니다. 연결을 확인하고 다시 시도해 주세요.',
      'nl':
          'Profiel bijwerken mislukt. Controleer je verbinding en probeer opnieuw.',
      'ru':
          'Не удалось обновить профиль. Проверьте подключение и повторите попытку.',
    },
    'Maia3 Human Review is preparing...': {
      'zh-Hans': 'Maia3 Human Review 正在准备...',
      'zh-Hant': 'Maia3 Human Review 正在準備...',
      'de': 'Maia3 Human Review wird vorbereitet...',
      'es': 'Maia3 Human Review se está preparando...',
      'fr': 'Maia3 Human Review se prépare...',
      'it': 'Maia3 Human Review è in preparazione...',
      'ja': 'Maia3 Human Review を準備しています...',
      'ko': 'Maia3 Human Review를 준비 중입니다...',
      'nl': 'Maia3 Human Review wordt voorbereid...',
      'ru': 'Maia3 Human Review готовится...',
    },
    'Maia3 Human Review ready.': {
      'zh-Hans': 'Maia3 Human Review 已就绪。',
      'zh-Hant': 'Maia3 Human Review 已就緒。',
      'de': 'Maia3 Human Review ist bereit.',
      'es': 'Maia3 Human Review está listo.',
      'fr': 'Maia3 Human Review est prêt.',
      'it': 'Maia3 Human Review è pronto.',
      'ja': 'Maia3 Human Review の準備ができました。',
      'ko': 'Maia3 Human Review가 준비되었습니다.',
      'nl': 'Maia3 Human Review is klaar.',
      'ru': 'Maia3 Human Review готов.',
    },
    'Maia3 Human Review': {
      'zh-Hans': 'Maia3 人类风格复盘',
      'zh-Hant': 'Maia3 人類風格複盤',
      'de': 'Maia3-Menschenanalyse',
      'es': 'Revisión humana Maia3',
      'fr': 'Revue humaine Maia3',
      'it': 'Revisione umana Maia3',
      'ja': 'Maia3 人間風レビュー',
      'ko': 'Maia3 인간형 복기',
      'nl': 'Maia3-mensenreview',
      'ru': 'Человеческий разбор Maia3',
    },
    'Human move model': {
      'zh-Hans': '人类走法模型',
      'zh-Hant': '人類著法模型',
      'de': 'Modell menschlicher Züge',
      'es': 'Modelo de jugadas humanas',
      'fr': 'Modèle de coups humains',
      'it': 'Modello delle mosse umane',
      'ja': '人間の指し手モデル',
      'ko': '인간 수 모델',
      'nl': 'Model voor menselijke zetten',
      'ru': 'Модель человеческих ходов',
    },
    'Maia3 estimates likely human choices, not engine-best moves.': {
      'zh-Hans': 'Maia3 估计人类可能选择的走法，而不是引擎的最佳着法。',
      'zh-Hant': 'Maia3 估計人類可能選擇的著法，而不是引擎的最佳著法。',
      'de':
          'Maia3 schätzt wahrscheinliche menschliche Züge, nicht die besten Engine-Züge.',
      'es':
          'Maia3 estima las jugadas que probablemente elegiría una persona, no las mejores del motor.',
      'fr':
          'Maia3 estime les coups probablement choisis par un humain, pas les meilleurs coups du moteur.',
      'it':
          'Maia3 stima le mosse che probabilmente sceglierebbe una persona, non le migliori del motore.',
      'ja': 'Maia3 は人間が選びそうな手を推定し、エンジンの最善手を示すものではありません。',
      'ko': 'Maia3는 사람이 선택할 가능성이 높은 수를 추정하며, 엔진의 최선 수를 제시하지 않습니다.',
      'nl':
          'Maia3 schat waarschijnlijke menselijke keuzes, niet de beste enginezetten.',
      'ru':
          'Maia3 оценивает вероятный выбор человека, а не лучшие ходы движка.',
    },
    'Human move probabilities': {
      'zh-Hans': '人类走法概率',
      'zh-Hant': '人類走法機率',
      'de': 'Wahrscheinlichkeiten menschlicher Züge',
      'es': 'Probabilidades de jugadas humanas',
      'fr': 'Probabilités de coups humains',
      'it': 'Probabilità delle mosse umane',
      'ja': '人間の指し手確率',
      'ko': '인간 수 확률',
      'nl': 'Kans op menselijke zetten',
      'ru': 'Вероятности человеческих ходов',
    },
    'Human likelihood': {
      'zh-Hans': '人类可能性',
      'zh-Hant': '人類可能性',
      'de': 'Menschliche Wahrscheinlichkeit',
      'es': 'Probabilidad humana',
      'fr': 'Probabilité humaine',
      'it': 'Probabilità umana',
      'ja': '人間らしさ',
      'ko': '인간 가능성',
      'nl': 'Menselijke waarschijnlijkheid',
      'ru': 'Человеческая вероятность',
    },
    'Maia3 estimates what humans at this strength are likely to play.': {
      'zh-Hans': 'Maia3 会估计这个强度的人类棋手更可能怎么走。',
      'zh-Hant': 'Maia3 會估計這個強度的人類棋手更可能怎麼走。',
      'de':
          'Maia3 schätzt, welche Züge Menschen dieser Spielstärke wahrscheinlich wählen.',
      'es':
          'Maia3 estima qué jugadas suelen elegir los humanos de esta fuerza.',
      'fr':
          'Maia3 estime les coups que les joueurs humains de ce niveau sont susceptibles de jouer.',
      'it':
          'Maia3 stima quali mosse giocherebbero più probabilmente umani di questa forza.',
      'ja': 'Maia3 は、この強さの人間が指しそうな手を推定します。',
      'ko': 'Maia3는 이 실력대의 인간이 둘 가능성이 높은 수를 추정합니다.',
      'nl':
          'Maia3 schat welke zetten mensen van deze sterkte waarschijnlijk spelen.',
      'ru': 'Maia3 оценивает, какие ходы вероятнее выберут люди такой силы.',
    },
    'Human match': {
      'zh-Hans': '人类匹配度',
      'zh-Hant': '人類匹配度',
      'de': 'Menschliche Übereinstimmung',
      'es': 'Coincidencia humana',
      'fr': 'Correspondance humaine',
      'it': 'Corrispondenza umana',
      'ja': '人間との一致度',
      'ko': '인간 일치도',
      'nl': 'Menselijke overeenkomst',
      'ru': 'Совпадение с человеком',
    },
    'More typical side': {
      'zh-Hans': '更典型的一方',
      'zh-Hant': '更典型的一方',
      'de': 'Typischere Seite',
      'es': 'Bando más típico',
      'fr': 'Camp plus typique',
      'it': 'Lato più tipico',
      'ja': 'より典型的な側',
      'ko': '더 전형적인 쪽',
      'nl': 'Typischere kant',
      'ru': 'Более типичная сторона',
    },
    'Move likelihood': {
      'zh-Hans': '走法可能性',
      'zh-Hant': '走法可能性',
      'de': 'Zugwahrscheinlichkeit',
      'es': 'Probabilidad de jugada',
      'fr': 'Probabilité du coup',
      'it': 'Probabilità della mossa',
      'ja': '指し手の確率',
      'ko': '수 가능성',
      'nl': 'Zetwaarschijnlijkheid',
      'ru': 'Вероятность хода',
    },
    'Candidate moves are human probabilities, not best-move scores.': {
      'zh-Hans': '候选着法展示的是人类概率，不是最佳着法评分。',
      'zh-Hant': '候選著法顯示的是人類機率，不是最佳著法評分。',
      'de':
          'Kandidatenzüge zeigen menschliche Wahrscheinlichkeiten, keine Bestzug-Wertungen.',
      'es':
          'Las jugadas candidatas son probabilidades humanas, no puntuaciones de mejor jugada.',
      'fr':
          'Les coups candidats sont des probabilités humaines, pas des scores de meilleur coup.',
      'it':
          'Le mosse candidate sono probabilità umane, non punteggi della mossa migliore.',
      'ja': '候補手は人間が指す確率であり、最善手スコアではありません。',
      'ko': '후보 수는 인간 확률이며 최선 수 점수가 아닙니다.',
      'nl':
          'Kandidaatzetten zijn menselijke kansen, geen scores voor beste zetten.',
      'ru':
          'Ходы-кандидаты показывают человеческие вероятности, а не оценки лучшего хода.',
    },
    'Select a move after Maia3 finishes to see human move probabilities.': {
      'zh-Hans': 'Maia3 完成后选择一步棋，即可查看人类走法概率。',
      'zh-Hant': 'Maia3 完成後選擇一步棋，即可查看人類走法機率。',
      'de':
          'Wähle nach Abschluss von Maia3 einen Zug, um menschliche Zugwahrscheinlichkeiten zu sehen.',
      'es':
          'Selecciona una jugada cuando Maia3 termine para ver probabilidades humanas.',
      'fr':
          'Sélectionnez un coup après Maia3 pour voir les probabilités humaines.',
      'it': 'Seleziona una mossa dopo Maia3 per vedere le probabilità umane.',
      'ja': 'Maia3 の完了後に手を選ぶと、人間の指し手確率を確認できます。',
      'ko': 'Maia3가 끝난 뒤 수를 선택하면 인간 수 확률을 볼 수 있습니다.',
      'nl': 'Selecteer na Maia3 een zet om menselijke zetkansen te bekijken.',
      'ru':
          'После завершения Maia3 выберите ход, чтобы увидеть человеческие вероятности.',
    },
    'Played move': {
      'zh-Hans': '实战着法',
      'zh-Hant': '實戰著法',
      'de': 'Gespielter Zug',
      'es': 'Jugada realizada',
      'fr': 'Coup joué',
      'it': 'Mossa giocata',
      'ja': '実戦の手',
      'ko': '실전 수',
      'nl': 'Gespeelde zet',
      'ru': 'Сыгранный ход',
    },
    'Filters': {
      'zh-Hans': '筛选',
      'zh-Hant': '篩選',
      'de': 'Filter',
      'es': 'Filtros',
      'fr': 'Filtres',
      'it': 'Filtri',
      'ja': 'フィルター',
      'ko': '필터',
      'nl': 'Filteropties',
      'ru': 'Фильтры',
    },
    '3 active': {
      'zh-Hans': '3 个已启用',
      'zh-Hant': '3 個已啟用',
      'de': '3 aktiv',
      'es': '3 activos',
      'fr': '3 actifs',
      'it': '3 attivi',
      'ja': '3 件有効',
      'ko': '3개 활성',
      'nl': '3 actief',
      'ru': '3 активны',
    },
    'Since': {
      'zh-Hans': '开始日期',
      'zh-Hant': '開始日期',
      'de': 'Seit',
      'es': 'Desde',
      'fr': 'Depuis',
      'it': 'Da',
      'ja': '開始日',
      'ko': '시작일',
      'nl': 'Sinds',
      'ru': 'С',
    },
    'Until': {
      'zh-Hans': '结束日期',
      'zh-Hant': '結束日期',
      'de': 'Bis',
      'es': 'Hasta',
      'fr': 'Jusqu’à',
      'it': 'Fino a',
      'ja': '終了日',
      'ko': '종료일',
      'nl': 'Tot',
      'ru': 'До',
    },
    'Import at least 1 game.': {
      'zh-Hans': '至少导入 1 盘棋。',
      'zh-Hant': '至少匯入 1 盤棋。',
      'de': 'Importiere mindestens 1 Partie.',
      'es': 'Importa al menos 1 partida.',
      'fr': 'Importez au moins 1 partie.',
      'it': 'Importa almeno 1 partita.',
      'ja': '少なくとも 1 局をインポートしてください。',
      'ko': '최소 1판을 가져오세요.',
      'nl': 'Importeer minstens 1 partij.',
      'ru': 'Импортируйте минимум 1 партию.',
    },
    'Summary': {
      'zh-Hans': '总结',
      'zh-Hant': '總結',
      'de': 'Zusammenfassung',
      'es': 'Resumen',
      'fr': 'Résumé',
      'it': 'Riepilogo',
      'ja': 'サマリー',
      'ko': '요약',
      'nl': 'Samenvatting',
      'ru': 'Сводка',
    },
    'Close Grandeur': {
      'zh-Hans': '关闭 Grandeur',
      'zh-Hant': '關閉 Grandeur',
      'de': 'Grandeur schließen',
      'es': 'Cerrar Grandeur',
      'fr': 'Fermer Grandeur',
      'it': 'Chiudi Grandeur',
      'ja': 'Grandeur を閉じる',
      'ko': 'Grandeur 닫기',
      'nl': 'Grandeur sluiten',
      'ru': 'Закрыть Grandeur',
    },
    'Statistics List': {
      'zh-Hans': '统计列表',
      'zh-Hant': '統計列表',
      'de': 'Statistikliste',
      'es': 'Lista de estadísticas',
      'fr': 'Liste des statistiques',
      'it': 'Elenco statistiche',
      'ja': '統計リスト',
      'ko': '통계 목록',
      'nl': 'Statistiekenlijst',
      'ru': 'Список статистики',
    },
    'Accuracy and move quality by side': {
      'zh-Hans': '双方准确率与着法质量',
      'zh-Hant': '雙方準確率與著法品質',
      'de': 'Genauigkeit und Zugqualität je Seite',
      'es': 'Precisión y calidad de jugadas por bando',
      'fr': 'Précision et qualité des coups par camp',
      'it': 'Precisione e qualità mosse per lato',
      'ja': '陣営別の精度と手の質',
      'ko': '양측의 정확도와 수 품질',
      'nl': 'Nauwkeurigheid en zetkwaliteit per kant',
      'ru': 'Точность и качество ходов по сторонам',
    },
    'Loading mistakes from your saved reviews...': {
      'zh-Hans': '正在从已保存复盘中加载错题...',
      'zh-Hant': '正在從已保存複盤中載入錯題...',
      'de': 'Fehler aus deinen gespeicherten Analysen werden geladen...',
      'es': 'Cargando errores desde tus revisiones guardadas...',
      'fr': 'Chargement des erreurs depuis vos revues enregistrées...',
      'it': 'Caricamento errori dalle revisioni salvate...',
      'ja': '保存済みレビューからミスを読み込んでいます...',
      'ko': '저장된 복기에서 실수를 불러오는 중...',
      'nl': 'Fouten uit je opgeslagen reviews laden...',
      'ru': 'Загрузка ошибок из сохранённых разборов...',
    },
    'No review mistakes yet': {
      'zh-Hans': '还没有复盘错题',
      'zh-Hant': '還沒有複盤錯題',
      'de': 'Noch keine Analysefehler',
      'es': 'Aún no hay errores de revisión',
      'fr': 'Aucune erreur de revue pour le moment',
      'it': 'Nessun errore di revisione ancora',
      'ja': 'レビューのミスはまだありません',
      'ko': '아직 복기 실수가 없습니다',
      'nl': 'Nog geen reviewfouten',
      'ru': 'Пока нет ошибок из разборов',
    },
    'Run a Standard report from Game Review. Mistakes and blunders will appear here automatically.':
        {
      'zh-Hans': '在 Game Review 中生成 Standard report 后，失误和漏着会自动出现在这里。',
      'zh-Hant': '在 Game Review 中生成 Standard report 後，失誤和漏著會自動出現在這裡。',
      'de':
          'Erstelle in Game Review einen Standard report. Fehler und Patzer erscheinen hier automatisch.',
      'es':
          'Genera un Standard report desde Game Review. Los errores y blunders aparecerán aquí automáticamente.',
      'fr':
          'Lancez un Standard report depuis Game Review. Les erreurs et blunders apparaîtront ici automatiquement.',
      'it':
          'Esegui uno Standard report da Game Review. Errori e blunder compariranno qui automaticamente.',
      'ja': 'Game Review で Standard report を実行すると、ミスと blunder が自動的にここに表示されます。',
      'ko': 'Game Review에서 Standard report를 실행하면 실수와 blunder가 여기에 자동으로 표시됩니다.',
      'nl':
          'Maak een Standard report vanuit Game Review. Fouten en blunders verschijnen hier automatisch.',
      'ru':
          'Запустите Standard report из Game Review. Ошибки и blunder появятся здесь автоматически.',
    },
    'Analyze a game': {
      'zh-Hans': '分析一盘棋',
      'zh-Hant': '分析一盤棋',
      'de': 'Partie analysieren',
      'es': 'Analizar una partida',
      'fr': 'Analyser une partie',
      'it': 'Analizza una partita',
      'ja': '対局を分析',
      'ko': '게임 분석',
      'nl': 'Partij analyseren',
      'ru': 'Проанализировать партию',
    },
    'No due reviews right now. New analysis mistakes will appear here.': {
      'zh-Hans': '现在没有到期复习。新的分析错题会显示在这里。',
      'zh-Hant': '現在沒有到期複習。新的分析錯題會顯示在這裡。',
      'de':
          'Derzeit sind keine Wiederholungen fällig. Neue Analysefehler erscheinen hier.',
      'es':
          'No hay revisiones pendientes ahora. Los nuevos errores de análisis aparecerán aquí.',
      'fr':
          'Aucune révision n’est due pour le moment. Les nouvelles erreurs d’analyse apparaîtront ici.',
      'it':
          'Nessuna revisione in scadenza. I nuovi errori di analisi compariranno qui.',
      'ja': '今すぐ復習する項目はありません。新しい分析ミスはここに表示されます。',
      'ko': '지금 복습할 항목이 없습니다. 새 분석 실수는 여기에 표시됩니다.',
      'nl':
          'Er zijn nu geen reviews gepland. Nieuwe analysefouten verschijnen hier.',
      'ru': 'Сейчас нет повторений. Новые ошибки анализа появятся здесь.',
    },
    'Replay the position before the mistake and find the better move.': {
      'zh-Hans': '回到失误前的局面，找出更好的走法。',
      'zh-Hant': '回到失誤前的局面，找出更好的走法。',
      'de':
          'Spiele die Stellung vor dem Fehler nach und finde den besseren Zug.',
      'es':
          'Reproduce la posición antes del error y encuentra la mejor jugada.',
      'fr': 'Rejouez la position avant l’erreur et trouvez le meilleur coup.',
      'it': 'Rigioca la posizione prima dell’errore e trova la mossa migliore.',
      'ja': 'ミスの前の局面を再現し、より良い手を見つけましょう。',
      'ko': '실수 직전의 포지션을 다시 보고 더 나은 수를 찾아보세요.',
      'nl': 'Speel de stelling vóór de fout opnieuw en vind de betere zet.',
      'ru': 'Повторите позицию перед ошибкой и найдите лучший ход.',
    },
    'Total saved': {
      'zh-Hans': '已保存总数',
      'zh-Hant': '已保存總數',
      'de': 'Insgesamt gespeichert',
      'es': 'Total guardado',
      'fr': 'Total enregistré',
      'it': 'Totale salvati',
      'ja': '保存済み合計',
      'ko': '총 저장 수',
      'nl': 'Totaal opgeslagen',
      'ru': 'Всего сохранено',
    },
    'No active themes': {
      'zh-Hans': '没有启用主题',
      'zh-Hant': '沒有啟用主題',
      'de': 'Keine aktiven Themen',
      'es': 'No hay temas activos',
      'fr': 'Aucun thème actif',
      'it': 'Nessun tema attivo',
      'ja': '有効なテーマなし',
      'ko': '활성 테마 없음',
      'nl': 'Geen actieve thema’s',
      'ru': 'Нет активных тем',
    },
    'Best move: Qh7#': {
      'zh-Hans': '最佳着法：Qh7#',
      'zh-Hant': '最佳著法：Qh7#',
      'de': 'Bester Zug: Qh7#',
      'es': 'Mejor jugada: Qh7#',
      'fr': 'Meilleur coup : Qh7#',
      'it': 'Mossa migliore: Qh7#',
      'ja': '最善手: Qh7#',
      'ko': '최선 수: Qh7#',
      'nl': 'Beste zet: Qh7#',
      'ru': 'Лучший ход: Qh7#',
    },
    'All caught up. New review mistakes will appear when they are due.': {
      'zh-Hans': '都复习完了。新的错题到期后会显示在这里。',
      'zh-Hant': '都複習完了。新的錯題到期後會顯示在這裡。',
      'de':
          'Alles erledigt. Neue Reviewfehler erscheinen, sobald sie fällig sind.',
      'es':
          'Todo al día. Los nuevos errores aparecerán cuando toque repasarlos.',
      'fr':
          'Tout est à jour. Les nouvelles erreurs apparaîtront quand elles seront dues.',
      'it':
          'Tutto aggiornato. I nuovi errori compariranno quando saranno da ripassare.',
      'ja': 'すべて完了です。新しいミスは復習時期になると表示されます。',
      'ko': '모두 완료했습니다. 새 복기 실수는 복습 시점에 표시됩니다.',
      'nl':
          'Alles bijgewerkt. Nieuwe reviewfouten verschijnen wanneer ze aan de beurt zijn.',
      'ru':
          'Всё повторено. Новые ошибки появятся, когда придёт время повторения.',
    },
    'Correct. This position is scheduled for later review.': {
      'zh-Hans': '正确。这道局面已安排稍后复习。',
      'zh-Hant': '正確。這個局面已安排稍後複習。',
      'de':
          'Richtig. Diese Stellung ist für eine spätere Wiederholung geplant.',
      'es':
          'Correcto. Esta posición queda programada para repasarla más tarde.',
      'fr':
          'Correct. Cette position est programmée pour une révision ultérieure.',
      'it':
          'Corretto. Questa posizione è programmata per una revisione futura.',
      'ja': '正解です。この局面は後で復習するように設定されました。',
      'ko': '정답입니다. 이 포지션은 나중에 복습하도록 예약되었습니다.',
      'nl': 'Correct. Deze stelling is ingepland voor latere review.',
      'ru': 'Верно. Эта позиция запланирована для повторения позже.',
    },
    'Try again, or compare with the best move above.': {
      'zh-Hans': '再试一次，或对照上方最佳着法。',
      'zh-Hant': '再試一次，或對照上方最佳著法。',
      'de': 'Versuche es erneut oder vergleiche mit dem besten Zug oben.',
      'es': 'Inténtalo de nuevo o compara con la mejor jugada de arriba.',
      'fr': 'Réessayez ou comparez avec le meilleur coup ci-dessus.',
      'it': 'Riprova o confronta con la mossa migliore sopra.',
      'ja': 'もう一度試すか、上の最善手と比べてください。',
      'ko': '다시 시도하거나 위의 최선 수와 비교해 보세요.',
      'nl': 'Probeer opnieuw of vergelijk met de beste zet hierboven.',
      'ru': 'Попробуйте снова или сравните с лучшим ходом выше.',
    },
  };
  return translations[text]?[key];
}

String? _termsPrivacyTranslations(String text, String key) {
  const t = <String, Map<String, String>>{
    'Service changes and availability': {
      'zh-Hans': '服务变更与可用性',
      'zh-Hant': '服務變更與可用性',
      'de': 'Serviceänderungen und Verfügbarkeit',
      'es': 'Cambios y disponibilidad del servicio',
      'fr': 'Évolution et disponibilité du service',
      'it': 'Modifiche e disponibilità del servizio',
      'ja': 'サービスの変更と利用可能性',
      'ko': '서비스 변경 및 이용 가능성',
      'nl': 'Servicewijzigingen en beschikbaarheid',
      'ru': 'Изменения и доступность сервиса',
    },
    'Features, prices, rewards, supported boards, engine options, and online services may be updated, suspended, or discontinued as the product evolves, when required by platform rules, or during maintenance. We work to keep Chessnut reliable, but the service is provided as available and may be affected by networks, devices, app stores, or third-party services.':
        {
      'zh-Hans':
          '随着产品发展、平台规则要求或维护需要，功能、价格、奖励、支持的棋盘、引擎选项和在线服务可能会更新、暂停或停止。我们会努力保持 Chessnut 稳定可靠，但服务按实际可用状态提供，也可能受到网络、设备、应用商店或第三方服务的影响。',
      'zh-Hant':
          '隨著產品發展、平台規則要求或維護需要，功能、價格、獎勵、支援的棋盤、引擎選項和線上服務可能會更新、暫停或停止。我們會努力保持 Chessnut 穩定可靠，但服務按實際可用狀態提供，也可能受到網路、裝置、應用商店或第三方服務的影響。',
      'de':
          'Funktionen, Preise, Prämien, unterstützte Bretter, Engine-Optionen und Online-Dienste können aktualisiert, pausiert oder eingestellt werden, wenn sich das Produkt weiterentwickelt, Plattformregeln es erfordern oder Wartungen stattfinden. Wir arbeiten daran, Chessnut zuverlässig zu halten, stellen den Dienst aber nach Verfügbarkeit bereit. Er kann durch Netzwerke, Geräte, App-Stores oder Drittanbieterdienste beeinflusst werden.',
      'es':
          'Las funciones, precios, recompensas, tableros compatibles, opciones de motor y servicios en línea pueden actualizarse, suspenderse o dejar de ofrecerse a medida que el producto evoluciona, cuando lo exijan las reglas de la plataforma o durante el mantenimiento. Trabajamos para que Chessnut sea fiable, pero el servicio se ofrece según disponibilidad y puede verse afectado por redes, dispositivos, tiendas de apps o servicios de terceros.',
      'fr':
          'Les fonctions, prix, récompenses, échiquiers compatibles, options de moteur et services en ligne peuvent être mis à jour, suspendus ou arrêtés à mesure que le produit évolue, si les règles des plateformes l’exigent ou pendant la maintenance. Nous faisons notre possible pour garder Chessnut fiable, mais le service est fourni selon sa disponibilité et peut être affecté par les réseaux, les appareils, les boutiques d’apps ou des services tiers.',
      'it':
          'Funzioni, prezzi, premi, scacchiere supportate, opzioni del motore e servizi online possono essere aggiornati, sospesi o interrotti con l’evoluzione del prodotto, quando richiesto dalle regole della piattaforma o durante la manutenzione. Lavoriamo per mantenere Chessnut affidabile, ma il servizio è fornito secondo disponibilità e può dipendere da reti, dispositivi, app store o servizi di terze parti.',
      'ja':
          '機能、価格、リワード、対応ボード、エンジン設定、オンラインサービスは、製品の進化、プラットフォーム規則の要請、またはメンテナンスにより、更新、一時停止、終了される場合があります。Chessnut を信頼できるサービスに保つよう努めていますが、サービスは利用可能な範囲で提供され、ネットワーク、端末、アプリストア、第三者サービスの影響を受けることがあります。',
      'ko':
          '기능, 가격, 보상, 지원 보드, 엔진 옵션, 온라인 서비스는 제품이 발전하거나 플랫폼 규칙상 필요하거나 유지보수 중일 때 업데이트, 일시 중단 또는 종료될 수 있습니다. Chessnut이 안정적으로 운영되도록 노력하지만, 서비스는 이용 가능한 상태로 제공되며 네트워크, 기기, 앱 스토어 또는 제3자 서비스의 영향을 받을 수 있습니다.',
      'nl':
          'Functies, prijzen, beloningen, ondersteunde borden, engine-opties en online diensten kunnen worden bijgewerkt, gepauzeerd of stopgezet naarmate het product verandert, wanneer platformregels dit vereisen of tijdens onderhoud. We doen ons best om Chessnut betrouwbaar te houden, maar de service wordt geleverd voor zover beschikbaar en kan worden beïnvloed door netwerken, apparaten, appstores of diensten van derden.',
      'ru':
          'Функции, цены, награды, поддерживаемые доски, параметры движков и онлайн-сервисы могут обновляться, приостанавливаться или прекращаться по мере развития продукта, по требованиям правил платформ или во время обслуживания. Мы стараемся поддерживать надежность Chessnut, но сервис предоставляется по мере доступности и может зависеть от сетей, устройств, магазинов приложений или сторонних сервисов.',
    },
    'Optional tools and third-party links': {
      'zh-Hans': '可选工具与第三方链接',
      'zh-Hant': '選用工具與第三方連結',
      'de': 'Optionale Tools und Links Dritter',
      'es': 'Herramientas opcionales y enlaces de terceros',
      'fr': 'Outils optionnels et liens tiers',
      'it': 'Strumenti opzionali e link di terze parti',
      'ja': '任意ツールと第三者リンク',
      'ko': '선택 도구 및 제3자 링크',
      'nl': 'Optionele tools en links van derden',
      'ru': 'Дополнительные инструменты и сторонние ссылки',
    },
    'The app may connect to optional services such as Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, email providers, cloud hosting, and open-source chess engines. Those tools are provided by separate organizations and may have their own terms, privacy notices, availability, billing rules, and fair-play requirements.':
        {
      'zh-Hans':
          'App 可能会连接到可选服务，例如 Lichess、Chess.com、Apple App Store、Google Play、Cloudflare Turnstile、邮箱服务商、云托管和开源国际象棋引擎。这些工具由不同组织提供，可能有各自的条款、隐私说明、可用性、计费规则和公平竞赛要求。',
      'zh-Hant':
          'App 可能會連接到選用服務，例如 Lichess、Chess.com、Apple App Store、Google Play、Cloudflare Turnstile、電子郵件服務商、雲端託管和開源國際象棋引擎。這些工具由不同組織提供，可能有各自的條款、隱私說明、可用性、計費規則和公平競賽要求。',
      'de':
          'Die App kann optionale Dienste wie Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, E-Mail-Anbieter, Cloud-Hosting und Open-Source-Schachengines verbinden. Diese Tools werden von eigenen Organisationen bereitgestellt und können eigene Bedingungen, Datenschutzhinweise, Verfügbarkeiten, Abrechnungsregeln und Fair-Play-Anforderungen haben.',
      'es':
          'La app puede conectarse a servicios opcionales como Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, proveedores de correo, alojamiento en la nube y motores de ajedrez de código abierto. Esas herramientas las ofrecen organizaciones independientes y pueden tener sus propios términos, avisos de privacidad, disponibilidad, reglas de cobro y requisitos de juego limpio.',
      'fr':
          'L’app peut se connecter à des services optionnels comme Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, des fournisseurs d’e-mail, de l’hébergement cloud et des moteurs d’échecs open source. Ces outils sont fournis par des organisations distinctes et peuvent avoir leurs propres conditions, avis de confidentialité, disponibilités, règles de facturation et exigences de fair-play.',
      'it':
          'L’app può collegarsi a servizi opzionali come Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, provider email, hosting cloud e motori scacchistici open source. Questi strumenti sono forniti da organizzazioni separate e possono avere termini, informative privacy, disponibilità, regole di fatturazione e requisiti di fair play propri.',
      'ja':
          'アプリは、Lichess、Chess.com、Apple App Store、Google Play、Cloudflare Turnstile、メールプロバイダー、クラウドホスティング、オープンソースのチェスエンジンなどの任意サービスに接続する場合があります。これらのツールは別組織が提供しており、それぞれ独自の規約、プライバシー通知、提供状況、課金ルール、フェアプレー要件を持つ場合があります。',
      'ko':
          '앱은 Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, 이메일 제공업체, 클라우드 호스팅, 오픈소스 체스 엔진 같은 선택 서비스에 연결될 수 있습니다. 이러한 도구는 별도 조직이 제공하며 자체 약관, 개인정보 안내, 이용 가능성, 결제 규칙, 페어플레이 요구사항이 있을 수 있습니다.',
      'nl':
          'De app kan verbinding maken met optionele diensten zoals Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, e-mailproviders, cloudhosting en open-source schaakengines. Deze tools worden geleverd door afzonderlijke organisaties en kunnen eigen voorwaarden, privacyverklaringen, beschikbaarheid, betaalregels en fair-playvereisten hebben.',
      'ru':
          'Приложение может подключаться к дополнительным сервисам, таким как Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, почтовые провайдеры, облачный хостинг и шахматные движки с открытым исходным кодом. Эти инструменты предоставляются отдельными организациями и могут иметь собственные условия, уведомления о конфиденциальности, доступность, правила оплаты и требования честной игры.',
    },
    'Prohibited uses': {
      'zh-Hans': '禁止用途',
      'zh-Hant': '禁止用途',
      'de': 'Unzulässige Nutzung',
      'es': 'Usos prohibidos',
      'fr': 'Usages interdits',
      'it': 'Usi vietati',
      'ja': '禁止される利用',
      'ko': '금지된 사용',
      'nl': 'Verboden gebruik',
      'ru': 'Запрещенное использование',
    },
    'Do not use Chessnut for illegal activity, harassment, cheating, unauthorized engine assistance in online games, infringement, spam, scraping, attacking the service, bypassing security, reverse engineering beyond what law allows, or uploading malicious or misleading content. We may limit or terminate access if the service is abused or fair-play rules are violated.':
        {
      'zh-Hans':
          '请勿将 Chessnut 用于违法活动、骚扰、作弊、在线对局中未经允许的引擎辅助、侵权、垃圾信息、抓取数据、攻击服务、绕过安全措施、超出法律允许范围的逆向工程，或上传恶意或误导性内容。如果服务被滥用或公平竞赛规则被违反，我们可能会限制或终止访问。',
      'zh-Hant':
          '請勿將 Chessnut 用於違法活動、騷擾、作弊、線上對局中未經允許的引擎輔助、侵權、垃圾訊息、抓取資料、攻擊服務、繞過安全措施、超出法律允許範圍的逆向工程，或上傳惡意或誤導性內容。如果服務被濫用或公平競賽規則被違反，我們可能會限制或終止存取。',
      'de':
          'Verwende Chessnut nicht für rechtswidrige Aktivitäten, Belästigung, Betrug, unerlaubte Engine-Hilfe in Online-Partien, Rechtsverletzungen, Spam, Scraping, Angriffe auf den Dienst, Umgehung von Sicherheitsmaßnahmen, Reverse Engineering über das gesetzlich Erlaubte hinaus oder das Hochladen schädlicher oder irreführender Inhalte. Wir können den Zugriff beschränken oder beenden, wenn der Dienst missbraucht wird oder Fair-Play-Regeln verletzt werden.',
      'es':
          'No uses Chessnut para actividades ilegales, acoso, trampas, ayuda de motor no autorizada en partidas en línea, infracciones, spam, scraping, ataques al servicio, evasión de seguridad, ingeniería inversa más allá de lo permitido por la ley ni para subir contenido malicioso o engañoso. Podemos limitar o cancelar el acceso si se abusa del servicio o se incumplen las reglas de juego limpio.',
      'fr':
          'N’utilisez pas Chessnut pour des activités illégales, du harcèlement, de la triche, une aide moteur non autorisée dans des parties en ligne, des atteintes aux droits, du spam, du scraping, des attaques contre le service, le contournement de la sécurité, de l’ingénierie inverse au-delà de ce que la loi permet, ou l’envoi de contenus malveillants ou trompeurs. Nous pouvons limiter ou résilier l’accès si le service est abusé ou si les règles de fair-play sont violées.',
      'it':
          'Non usare Chessnut per attività illegali, molestie, cheating, assistenza non autorizzata del motore nelle partite online, violazioni, spam, scraping, attacchi al servizio, aggiramento della sicurezza, reverse engineering oltre quanto consentito dalla legge o caricamento di contenuti dannosi o fuorvianti. Possiamo limitare o terminare l’accesso se il servizio viene abusato o se vengono violate le regole di fair play.',
      'ja':
          'Chessnut を、違法行為、嫌がらせ、不正行為、オンライン対局で許可されていないエンジン支援、権利侵害、スパム、スクレイピング、サービス攻撃、セキュリティ回避、法律で認められる範囲を超えたリバースエンジニアリング、または悪意ある内容や誤解を招く内容のアップロードに使用しないでください。サービスが悪用された場合、またはフェアプレー規則に違反した場合、アクセスを制限または終了することがあります。',
      'ko':
          'Chessnut을 불법 활동, 괴롭힘, 부정행위, 온라인 대국에서 허용되지 않은 엔진 보조, 권리 침해, 스팸, 스크래핑, 서비스 공격, 보안 우회, 법이 허용하는 범위를 넘는 리버스 엔지니어링, 악성 또는 오해의 소지가 있는 콘텐츠 업로드에 사용하지 마세요. 서비스가 남용되거나 페어플레이 규칙이 위반되면 접근을 제한하거나 종료할 수 있습니다.',
      'nl':
          'Gebruik Chessnut niet voor illegale activiteiten, intimidatie, valsspelen, ongeoorloofde engine-hulp in online partijen, inbreuk, spam, scraping, aanvallen op de service, het omzeilen van beveiliging, reverse engineering buiten wat de wet toestaat, of het uploaden van schadelijke of misleidende inhoud. We kunnen toegang beperken of beëindigen als de service wordt misbruikt of fair-playregels worden geschonden.',
      'ru':
          'Не используйте Chessnut для незаконной деятельности, преследования, мошенничества, неразрешенной помощи движка в онлайн-партиях, нарушения прав, спама, сбора данных, атак на сервис, обхода защиты, обратной разработки сверх разрешенного законом, а также загрузки вредоносного или вводящего в заблуждение контента. Мы можем ограничить или прекратить доступ, если сервисом злоупотребляют или нарушаются правила честной игры.',
    },
    'Disclaimer and limitation of liability': {
      'zh-Hans': '免责声明与责任限制',
      'zh-Hant': '免責聲明與責任限制',
      'de': 'Haftungsausschluss und Haftungsbeschränkung',
      'es': 'Descargo de responsabilidad y límite de responsabilidad',
      'fr': 'Avertissement et limitation de responsabilité',
      'it': 'Esclusione e limitazione di responsabilità',
      'ja': '免責事項と責任の制限',
      'ko': '면책 및 책임 제한',
      'nl': 'Disclaimer en beperking van aansprakelijkheid',
      'ru': 'Отказ от гарантий и ограничение ответственности',
    },
    'Chess analysis, engine suggestions, puzzle results, ratings, and training feedback are informational and may be incomplete or inaccurate. To the maximum extent permitted by law, Chessnut and its service providers are not responsible for indirect, incidental, special, consequential, or punitive damages, lost data, lost revenue, or losses caused by unavailable networks, third-party services, or unsupported use.':
        {
      'zh-Hans':
          '棋局分析、引擎建议、题目结果、评分和训练反馈仅供参考，可能不完整或不准确。在法律允许的最大范围内，Chessnut 及其服务提供商不对间接、偶发、特殊、后果性或惩罚性损害、数据丢失、收入损失，或因网络不可用、第三方服务或不受支持的使用造成的损失负责。',
      'zh-Hant':
          '棋局分析、引擎建議、題目結果、評分和訓練回饋僅供參考，可能不完整或不準確。在法律允許的最大範圍內，Chessnut 及其服務提供商不對間接、偶發、特殊、衍生或懲罰性損害、資料遺失、收入損失，或因網路不可用、第三方服務或不受支援的使用造成的損失負責。',
      'de':
          'Schachanalysen, Engine-Vorschläge, Puzzle-Ergebnisse, Bewertungen und Trainingsfeedback dienen der Information und können unvollständig oder ungenau sein. Soweit gesetzlich zulässig, haften Chessnut und seine Dienstleister nicht für indirekte, zufällige, besondere, Folge- oder Strafschäden, Datenverlust, entgangene Einnahmen oder Verluste durch nicht verfügbare Netzwerke, Drittanbieterdienste oder nicht unterstützte Nutzung.',
      'es':
          'Los análisis de ajedrez, sugerencias del motor, resultados de puzzles, ratings y comentarios de entrenamiento son informativos y pueden ser incompletos o inexactos. En la máxima medida permitida por la ley, Chessnut y sus proveedores de servicios no son responsables de daños indirectos, incidentales, especiales, consecuentes o punitivos, pérdida de datos, pérdida de ingresos ni pérdidas causadas por redes no disponibles, servicios de terceros o usos no compatibles.',
      'fr':
          'Les analyses d’échecs, suggestions de moteur, résultats de puzzles, classements et retours d’entraînement sont fournis à titre informatif et peuvent être incomplets ou inexacts. Dans toute la mesure permise par la loi, Chessnut et ses prestataires ne sont pas responsables des dommages indirects, accessoires, spéciaux, consécutifs ou punitifs, des pertes de données, pertes de revenus ou pertes causées par des réseaux indisponibles, des services tiers ou une utilisation non prise en charge.',
      'it':
          'Analisi scacchistiche, suggerimenti del motore, risultati dei puzzle, rating e feedback di allenamento sono informazioni di supporto e possono essere incompleti o imprecisi. Nella misura massima consentita dalla legge, Chessnut e i suoi fornitori di servizi non sono responsabili per danni indiretti, incidentali, speciali, consequenziali o punitivi, perdita di dati, mancati ricavi o perdite causate da reti non disponibili, servizi di terze parti o uso non supportato.',
      'ja':
          'チェス分析、エンジンの提案、パズル結果、レーティング、トレーニングフィードバックは情報提供を目的としたものであり、不完全または不正確な場合があります。法律で認められる最大限の範囲で、Chessnut およびそのサービス提供者は、間接的、偶発的、特別、結果的、懲罰的損害、データ損失、収益損失、または利用できないネットワーク、第三者サービス、サポート対象外の使用による損失について責任を負いません。',
      'ko':
          '체스 분석, 엔진 제안, 퍼즐 결과, 레이팅, 훈련 피드백은 참고용 정보이며 불완전하거나 부정확할 수 있습니다. 법이 허용하는 최대 범위에서 Chessnut 및 그 서비스 제공자는 간접적, 우발적, 특별, 결과적 또는 징벌적 손해, 데이터 손실, 수익 손실, 이용 불가능한 네트워크, 제3자 서비스 또는 지원되지 않는 사용으로 인한 손실에 대해 책임지지 않습니다.',
      'nl':
          'Schaakanalyses, engine-suggesties, puzzelresultaten, ratings en trainingsfeedback zijn informatief en kunnen onvolledig of onnauwkeurig zijn. Voor zover wettelijk toegestaan zijn Chessnut en zijn dienstverleners niet verantwoordelijk voor indirecte, incidentele, bijzondere, gevolg- of punitieve schade, verloren data, gederfde inkomsten of verliezen door niet-beschikbare netwerken, diensten van derden of niet-ondersteund gebruik.',
      'ru':
          'Шахматный анализ, подсказки движка, результаты задач, рейтинги и тренировочная обратная связь носят информационный характер и могут быть неполными или неточными. В максимальной степени, разрешенной законом, Chessnut и его поставщики услуг не несут ответственности за косвенный, случайный, специальный, последующий или штрафной ущерб, потерю данных, потерю дохода или убытки, вызванные недоступностью сетей, сторонними сервисами или неподдерживаемым использованием.',
    },
    'Governing law and contact': {
      'zh-Hans': '适用法律与联系方式',
      'zh-Hant': '適用法律與聯絡方式',
      'de': 'Geltendes Recht und Kontakt',
      'es': 'Ley aplicable y contacto',
      'fr': 'Droit applicable et contact',
      'it': 'Legge applicabile e contatti',
      'ja': '準拠法と連絡先',
      'ko': '준거법 및 연락처',
      'nl': 'Toepasselijk recht en contact',
      'ru': 'Применимое право и контакты',
    },
    'These app terms are intended to work with the published Chessnut website terms. Where applicable, the website terms state that separate service agreements are governed by the laws of Hong Kong. Questions about these terms, privacy, open-source notices, or app services can be sent to contact@chessnutech.com.':
        {
      'zh-Hans':
          '这些 App 条款旨在与已发布的 Chessnut 网站条款配合适用。在适用情况下，网站条款说明单独的服务协议受 Hong Kong 法律管辖。有关这些条款、隐私、开源声明或 App 服务的问题，可发送至 contact@chessnutech.com。',
      'zh-Hant':
          '這些 App 條款旨在與已發布的 Chessnut 網站條款配合適用。在適用情況下，網站條款說明單獨的服務協議受 Hong Kong 法律管轄。有關這些條款、隱私、開源聲明或 App 服務的問題，可寄送至 contact@chessnutech.com。',
      'de':
          'Diese App-Bedingungen sollen zusammen mit den veröffentlichten Bedingungen der Chessnut-Website gelten. Soweit anwendbar, sehen die Website-Bedingungen vor, dass separate Servicevereinbarungen dem Recht von Hong Kong unterliegen. Fragen zu diesen Bedingungen, zum Datenschutz, zu Open-Source-Hinweisen oder zu App-Diensten können an contact@chessnutech.com gesendet werden.',
      'es':
          'Estos términos de la app están pensados para funcionar junto con los términos publicados en el sitio web de Chessnut. Cuando corresponda, los términos del sitio web indican que los acuerdos de servicio separados se rigen por las leyes de Hong Kong. Las preguntas sobre estos términos, privacidad, avisos de código abierto o servicios de la app pueden enviarse a contact@chessnutech.com.',
      'fr':
          'Ces conditions de l’app sont destinées à fonctionner avec les conditions publiées sur le site web de Chessnut. Le cas échéant, les conditions du site indiquent que les accords de service distincts sont régis par les lois de Hong Kong. Les questions sur ces conditions, la confidentialité, les avis open source ou les services de l’app peuvent être envoyées à contact@chessnutech.com.',
      'it':
          'Questi termini dell’app sono pensati per funzionare insieme ai termini pubblicati sul sito web Chessnut. Ove applicabile, i termini del sito indicano che gli accordi di servizio separati sono regolati dalle leggi di Hong Kong. Domande su questi termini, privacy, avvisi open source o servizi dell’app possono essere inviate a contact@chessnutech.com.',
      'ja':
          'これらのアプリ規約は、公開されている Chessnut ウェブサイト規約とあわせて機能することを意図しています。該当する場合、ウェブサイト規約では、個別のサービス契約は Hong Kong の法律に準拠すると定めています。これらの規約、プライバシー、オープンソース通知、またはアプリサービスに関する質問は contact@chessnutech.com までお送りください。',
      'ko':
          '이 앱 약관은 게시된 Chessnut 웹사이트 약관과 함께 적용되도록 마련되었습니다. 해당되는 경우, 웹사이트 약관은 별도 서비스 계약이 Hong Kong 법률의 적용을 받는다고 명시합니다. 이 약관, 개인정보, 오픈소스 고지 또는 앱 서비스에 관한 질문은 contact@chessnutech.com으로 보낼 수 있습니다.',
      'nl':
          'Deze appvoorwaarden zijn bedoeld om samen te werken met de gepubliceerde voorwaarden op de Chessnut-website. Waar van toepassing vermelden de websitevoorwaarden dat afzonderlijke serviceovereenkomsten worden beheerst door de wetten van Hong Kong. Vragen over deze voorwaarden, privacy, open-sourcekennisgevingen of appdiensten kunnen worden gestuurd naar contact@chessnutech.com.',
      'ru':
          'Эти условия приложения предназначены для применения вместе с опубликованными условиями сайта Chessnut. Там, где применимо, условия сайта указывают, что отдельные соглашения об услугах регулируются законодательством Hong Kong. Вопросы об этих условиях, конфиденциальности, уведомлениях об открытом исходном коде или сервисах приложения можно отправлять на contact@chessnutech.com.',
    },
    'Language and AI-assisted translation': {
      'zh-Hans': '语言与 AI 辅助翻译',
      'zh-Hant': '語言與 AI 輔助翻譯',
      'de': 'Sprache und AI-gestützte Übersetzung',
      'es': 'Idioma y traducción asistida por AI',
      'fr': 'Langue et traduction assistée par AI',
      'it': 'Lingua e traduzione assistita da AI',
      'ja': '言語と AI 支援翻訳',
      'ko': '언어 및 AI 지원 번역',
      'nl': 'Taal en AI-ondersteunde vertaling',
      'ru': 'Язык и перевод с помощью AI',
    },
    'Some app text, policy summaries, support content, and notices may be translated with AI assistance. We work to review important text, but translations may occasionally be incomplete, inaccurate, or less natural than the English source. If a translation is unclear or conflicts with the English version, the English version controls. You can report translation issues at contact@chessnutech.com.':
        {
      'zh-Hans':
          '部分 App 文案、政策摘要、支持内容和通知可能会借助 AI 翻译。我们会努力审核重要文本，但翻译偶尔可能不完整、不准确，或不如英文原文自然。如果译文不清楚或与英文版本冲突，以英文版本为准。你可以通过 contact@chessnutech.com 反馈翻译问题。',
      'zh-Hant':
          '部分 App 文案、政策摘要、支援內容和通知可能會借助 AI 翻譯。我們會努力審核重要文字，但翻譯偶爾可能不完整、不準確，或不如英文原文自然。如果譯文不清楚或與英文版本衝突，以英文版本為準。你可以透過 contact@chessnutech.com 回報翻譯問題。',
      'de':
          'Einige App-Texte, Zusammenfassungen von Richtlinien, Supportinhalte und Hinweise können mit AI-Unterstützung übersetzt werden. Wir bemühen uns, wichtige Texte zu prüfen, aber Übersetzungen können gelegentlich unvollständig, ungenau oder weniger natürlich als die englische Quelle sein. Wenn eine Übersetzung unklar ist oder der englischen Version widerspricht, gilt die englische Version. Übersetzungsprobleme kannst du an contact@chessnutech.com melden.',
      'es':
          'Algunos textos de la app, resúmenes de políticas, contenido de soporte y avisos pueden traducirse con ayuda de AI. Trabajamos para revisar los textos importantes, pero las traducciones pueden ser incompletas, inexactas o menos naturales que la fuente en inglés. Si una traducción no es clara o entra en conflicto con la versión en inglés, prevalece la versión en inglés. Puedes informar problemas de traducción en contact@chessnutech.com.',
      'fr':
          'Certains textes de l’app, résumés de politiques, contenus d’assistance et avis peuvent être traduits avec l’aide de AI. Nous nous efforçons de relire les textes importants, mais les traductions peuvent parfois être incomplètes, inexactes ou moins naturelles que la source anglaise. Si une traduction n’est pas claire ou contredit la version anglaise, la version anglaise prévaut. Vous pouvez signaler les problèmes de traduction à contact@chessnutech.com.',
      'it':
          'Alcuni testi dell’app, riepiloghi delle policy, contenuti di supporto e avvisi possono essere tradotti con l’aiuto di AI. Cerchiamo di rivedere i testi importanti, ma le traduzioni possono a volte essere incomplete, imprecise o meno naturali della fonte inglese. Se una traduzione non è chiara o è in conflitto con la versione inglese, prevale la versione inglese. Puoi segnalare problemi di traduzione a contact@chessnutech.com.',
      'ja':
          '一部のアプリ内テキスト、ポリシー概要、サポート内容、通知は AI の支援により翻訳される場合があります。重要な文章は確認するよう努めていますが、翻訳が不完全、不正確、または英語原文より自然でない場合があります。翻訳が不明確な場合、または英語版と矛盾する場合は、英語版が優先されます。翻訳の問題は contact@chessnutech.com まで報告できます。',
      'ko':
          '일부 앱 문구, 정책 요약, 지원 콘텐츠 및 공지는 AI의 도움으로 번역될 수 있습니다. 중요한 문구는 검토하려고 노력하지만, 번역이 때때로 불완전하거나 부정확하거나 영어 원문보다 자연스럽지 않을 수 있습니다. 번역이 불명확하거나 영어 버전과 충돌하는 경우 영어 버전이 우선합니다. 번역 문제는 contact@chessnutech.com으로 신고할 수 있습니다.',
      'nl':
          'Sommige appteksten, beleidssamenvattingen, supportinhoud en kennisgevingen kunnen met AI-hulp worden vertaald. We proberen belangrijke teksten te beoordelen, maar vertalingen kunnen soms onvolledig, onnauwkeurig of minder natuurlijk zijn dan de Engelse bron. Als een vertaling onduidelijk is of in strijd is met de Engelse versie, geldt de Engelse versie. Je kunt vertaalproblemen melden via contact@chessnutech.com.',
      'ru':
          'Некоторые тексты приложения, краткие описания политик, материалы поддержки и уведомления могут переводиться с помощью AI. Мы стараемся проверять важные тексты, но переводы иногда могут быть неполными, неточными или менее естественными, чем английский источник. Если перевод неясен или противоречит английской версии, преимущественную силу имеет английская версия. О проблемах перевода можно сообщить на contact@chessnutech.com.',
    },
    'Information we collect': {
      'zh-Hans': '我们收集的信息',
      'zh-Hant': '我們收集的資訊',
      'de': 'Welche Informationen wir erfassen',
      'es': 'Información que recopilamos',
      'fr': 'Informations que nous collectons',
      'it': 'Informazioni che raccogliamo',
      'ja': '収集する情報',
      'ko': '수집하는 정보',
      'nl': 'Informatie die we verzamelen',
      'ru': 'Какие сведения мы собираем',
    },
    'Depending on the features you use, Chessnut may collect account details such as username, email, avatar, login method, membership, wallet points, purchases, and support messages; game data such as PGN, FEN, SAN moves, results, analysis history, puzzle progress, and imported records; board and device data such as Bluetooth connection status, board model, battery, firmware, clock state, app settings, diagnostics, logs, screenshots, or videos you choose to attach to bug reports.':
        {
      'zh-Hans':
          '根据你使用的功能，Chessnut 可能会收集账户信息，例如用户名、邮箱、头像、登录方式、会员、钱包积分、购买记录和客服消息；对局数据，例如 PGN、FEN、SAN 着法、结果、分析历史、题目进度和导入记录；棋盘和设备数据，例如 Bluetooth 连接状态、棋盘型号、电量、固件、棋钟状态、App 设置、诊断、日志，以及你选择附加到问题报告的截图或视频。',
      'zh-Hant':
          '根據你使用的功能，Chessnut 可能會收集帳戶資訊，例如使用者名稱、電子郵件、頭像、登入方式、會員、錢包積分、購買記錄和客服訊息；對局資料，例如 PGN、FEN、SAN 著法、結果、分析歷史、題目進度和匯入記錄；棋盤和裝置資料，例如 Bluetooth 連線狀態、棋盤型號、電量、韌體、棋鐘狀態、App 設定、診斷、日誌，以及你選擇附加到問題回報的截圖或影片。',
      'de':
          'Je nach genutzten Funktionen kann Chessnut Kontodaten wie Benutzername, E-Mail, Avatar, Anmeldemethode, Mitgliedschaft, Wallet-Punkte, Käufe und Supportnachrichten erfassen; Spieldaten wie PGN, FEN, SAN-Züge, Ergebnisse, Analyseverlauf, Puzzle-Fortschritt und importierte Datensätze; sowie Brett- und Gerätedaten wie Bluetooth-Verbindungsstatus, Brettmodell, Akku, Firmware, Uhrstatus, App-Einstellungen, Diagnosen, Logs, Screenshots oder Videos, die du an Fehlerberichte anhängst.',
      'es':
          'Según las funciones que uses, Chessnut puede recopilar datos de cuenta como nombre de usuario, correo, avatar, método de inicio de sesión, membresía, puntos del wallet, compras y mensajes de soporte; datos de partidas como PGN, FEN, jugadas SAN, resultados, historial de análisis, progreso de puzzles y registros importados; datos del tablero y dispositivo como estado de conexión Bluetooth, modelo del tablero, batería, firmware, estado del reloj, ajustes de la app, diagnósticos, logs, capturas de pantalla o videos que decidas adjuntar a reportes de errores.',
      'fr':
          'Selon les fonctions que vous utilisez, Chessnut peut collecter des informations de compte comme le nom d’utilisateur, l’e-mail, l’avatar, la méthode de connexion, l’abonnement, les points du wallet, les achats et les messages au support ; des données de partie comme PGN, FEN, coups SAN, résultats, historique d’analyse, progression des puzzles et dossiers importés ; ainsi que des données d’échiquier et d’appareil comme l’état de connexion Bluetooth, le modèle d’échiquier, la batterie, le firmware, l’état de la pendule, les réglages de l’app, diagnostics, logs, captures d’écran ou vidéos que vous choisissez de joindre aux rapports de bug.',
      'it':
          'A seconda delle funzioni che usi, Chessnut può raccogliere dati dell’account come nome utente, email, avatar, metodo di accesso, abbonamento, punti wallet, acquisti e messaggi di supporto; dati di partita come PGN, FEN, mosse SAN, risultati, cronologia analisi, progressi puzzle e record importati; dati di scacchiera e dispositivo come stato della connessione Bluetooth, modello della scacchiera, batteria, firmware, stato dell’orologio, impostazioni app, diagnostica, log, screenshot o video che scegli di allegare ai report di bug.',
      'ja':
          '使用する機能に応じて、Chessnut はユーザー名、メール、アバター、ログイン方法、メンバーシップ、ウォレットポイント、購入、サポートメッセージなどのアカウント情報、PGN、FEN、SAN の指し手、結果、分析履歴、パズル進捗、インポート記録などの対局データ、Bluetooth 接続状態、ボードモデル、バッテリー、ファームウェア、クロック状態、アプリ設定、診断、ログ、バグ報告に添付することを選んだスクリーンショットや動画などのボードおよび端末データを収集する場合があります。',
      'ko':
          '사용하는 기능에 따라 Chessnut은 사용자 이름, 이메일, 아바타, 로그인 방식, 멤버십, 지갑 포인트, 구매 내역, 지원 메시지 같은 계정 정보, PGN, FEN, SAN 수, 결과, 분석 기록, 퍼즐 진행률, 가져온 기록 같은 대국 데이터, Bluetooth 연결 상태, 보드 모델, 배터리, 펌웨어, 시계 상태, 앱 설정, 진단, 로그, 버그 보고서에 첨부하기로 선택한 스크린샷 또는 동영상 같은 보드 및 기기 데이터를 수집할 수 있습니다.',
      'nl':
          'Afhankelijk van de functies die je gebruikt kan Chessnut accountgegevens verzamelen zoals gebruikersnaam, e-mail, avatar, inlogmethode, lidmaatschap, wallet-punten, aankopen en supportberichten; partijgegevens zoals PGN, FEN, SAN-zetten, resultaten, analysegeschiedenis, puzzelvoortgang en geïmporteerde records; en bord- en apparaatgegevens zoals Bluetooth-verbindingsstatus, bordmodel, batterij, firmware, klokstatus, appinstellingen, diagnostiek, logs, screenshots of video’s die je aan bugrapporten toevoegt.',
      'ru':
          'В зависимости от используемых функций Chessnut может собирать данные аккаунта, такие как имя пользователя, email, аватар, способ входа, членство, баллы кошелька, покупки и сообщения поддержки; данные партий, такие как PGN, FEN, ходы SAN, результаты, история анализа, прогресс задач и импортированные записи; данные доски и устройства, такие как статус подключения Bluetooth, модель доски, батарея, прошивка, состояние часов, настройки приложения, диагностика, логи, скриншоты или видео, которые вы решите приложить к отчетам об ошибках.',
    },
    'How we use information': {
      'zh-Hans': '我们如何使用信息',
      'zh-Hant': '我們如何使用資訊',
      'de': 'Wie wir Informationen verwenden',
      'es': 'Cómo usamos la información',
      'fr': 'Comment nous utilisons les informations',
      'it': 'Come usiamo le informazioni',
      'ja': '情報の利用方法',
      'ko': '정보 사용 방식',
      'nl': 'Hoe we informatie gebruiken',
      'ru': 'Как мы используем сведения',
    },
    'We use information to create and secure your account, sync game records and settings, connect Chessnut boards, run bot games and online play, import Lichess or Chess.com history at your request, generate analysis and training reports, process membership and wallet features, provide support, troubleshoot bugs, prevent abuse, improve reliability, and send service messages you request or need to receive.':
        {
      'zh-Hans':
          '我们使用信息来创建并保护你的账户，同步对局记录和设置，连接 Chessnut 棋盘，运行机器人对局和在线对局，按你的请求导入 Lichess 或 Chess.com 历史记录，生成分析和训练报告，处理会员和钱包功能，提供支持，排查问题，防止滥用，提高可靠性，并发送你请求或需要接收的服务消息。',
      'zh-Hant':
          '我們使用資訊來建立並保護你的帳戶，同步對局記錄和設定，連接 Chessnut 棋盤，執行機器人對局和線上對局，依你的要求匯入 Lichess 或 Chess.com 歷史記錄，產生分析和訓練報告，處理會員和錢包功能，提供支援，排查問題，防止濫用，提高可靠性，並傳送你要求或需要接收的服務訊息。',
      'de':
          'Wir verwenden Informationen, um dein Konto zu erstellen und zu schützen, Partien und Einstellungen zu synchronisieren, Chessnut-Bretter zu verbinden, Bot-Partien und Online-Spiel zu betreiben, auf deinen Wunsch Lichess- oder Chess.com-Verläufe zu importieren, Analyse- und Trainingsberichte zu erstellen, Mitgliedschafts- und Wallet-Funktionen zu verarbeiten, Support zu leisten, Fehler zu beheben, Missbrauch zu verhindern, die Zuverlässigkeit zu verbessern und Servicenachrichten zu senden, die du anforderst oder erhalten musst.',
      'es':
          'Usamos la información para crear y proteger tu cuenta, sincronizar registros de partidas y ajustes, conectar tableros Chessnut, ejecutar partidas contra bots y juego en línea, importar historial de Lichess o Chess.com cuando lo solicites, generar informes de análisis y entrenamiento, procesar membresía y funciones del wallet, ofrecer soporte, solucionar errores, prevenir abusos, mejorar la fiabilidad y enviar mensajes de servicio que solicites o necesites recibir.',
      'fr':
          'Nous utilisons les informations pour créer et sécuriser votre compte, synchroniser les parties et réglages, connecter les échiquiers Chessnut, gérer les parties contre bots et le jeu en ligne, importer l’historique Lichess ou Chess.com à votre demande, générer des rapports d’analyse et d’entraînement, traiter l’abonnement et les fonctions de wallet, fournir l’assistance, résoudre les bugs, prévenir les abus, améliorer la fiabilité et envoyer les messages de service que vous demandez ou devez recevoir.',
      'it':
          'Usiamo le informazioni per creare e proteggere il tuo account, sincronizzare partite e impostazioni, collegare le scacchiere Chessnut, gestire partite contro bot e gioco online, importare la cronologia Lichess o Chess.com su tua richiesta, generare report di analisi e allenamento, gestire abbonamento e funzioni wallet, fornire supporto, risolvere bug, prevenire abusi, migliorare l’affidabilità e inviare messaggi di servizio che richiedi o devi ricevere.',
      'ja':
          '情報は、アカウントの作成と保護、対局記録と設定の同期、Chessnut ボードの接続、ボット対局とオンライン対局の運営、リクエストに応じた Lichess または Chess.com 履歴のインポート、分析およびトレーニングレポートの生成、メンバーシップとウォレット機能の処理、サポート提供、不具合調査、悪用防止、信頼性向上、あなたが依頼した、または受け取る必要があるサービスメッセージの送信に使用します。',
      'ko':
          '당사는 정보를 사용해 계정을 만들고 보호하며, 대국 기록과 설정을 동기화하고, Chessnut 보드를 연결하고, 봇 대국과 온라인 플레이를 운영하고, 요청 시 Lichess 또는 Chess.com 기록을 가져오고, 분석 및 훈련 보고서를 생성하고, 멤버십과 지갑 기능을 처리하고, 지원을 제공하고, 버그를 해결하고, 남용을 방지하고, 안정성을 개선하며, 사용자가 요청했거나 받아야 하는 서비스 메시지를 보냅니다.',
      'nl':
          'We gebruiken informatie om je account aan te maken en te beveiligen, partijrecords en instellingen te synchroniseren, Chessnut-borden te verbinden, botpartijen en online spelen mogelijk te maken, op jouw verzoek Lichess- of Chess.com-geschiedenis te importeren, analyse- en trainingsrapporten te maken, lidmaatschap en wallet-functies te verwerken, support te bieden, bugs op te lossen, misbruik te voorkomen, betrouwbaarheid te verbeteren en servicemeldingen te sturen die je aanvraagt of moet ontvangen.',
      'ru':
          'Мы используем сведения, чтобы создавать и защищать ваш аккаунт, синхронизировать записи партий и настройки, подключать доски Chessnut, запускать партии с ботами и онлайн-игру, импортировать историю Lichess или Chess.com по вашему запросу, создавать отчеты анализа и тренировок, обрабатывать членство и функции кошелька, оказывать поддержку, устранять ошибки, предотвращать злоупотребления, повышать надежность и отправлять сервисные сообщения, которые вы запросили или должны получить.',
    },
    'Sharing and third-party processors': {
      'zh-Hans': '共享与第三方处理方',
      'zh-Hant': '分享與第三方處理方',
      'de': 'Weitergabe und Drittverarbeiter',
      'es': 'Compartir datos y encargados externos',
      'fr': 'Partage et prestataires tiers',
      'it': 'Condivisione e responsabili di terze parti',
      'ja': '共有と第三者処理者',
      'ko': '공유 및 제3자 처리업체',
      'nl': 'Delen en externe verwerkers',
      'ru': 'Передача данных и сторонние обработчики',
    },
    'We share data only as needed to operate the app, comply with law, protect rights, or deliver features you choose. Processors may include hosting, storage, email, analytics, diagnostics, payment platforms such as Apple and Google, Cloudflare verification, Lichess or Chess.com when you connect or import data, and Maia or Stockfish services for requested chess analysis. We do not sell your personal information from the app.':
        {
      'zh-Hans':
          '我们只在运营 App、遵守法律、保护权利或提供你选择的功能所需范围内共享数据。处理方可能包括托管、存储、邮箱、分析、诊断、Apple 和 Google 等支付平台、Cloudflare 验证、你连接或导入数据时的 Lichess 或 Chess.com，以及用于你请求的棋局分析的 Maia 或 Stockfish 服务。我们不会出售来自 App 的个人信息。',
      'zh-Hant':
          '我們只在營運 App、遵守法律、保護權利或提供你選擇的功能所需範圍內分享資料。處理方可能包括託管、儲存、電子郵件、分析、診斷、Apple 和 Google 等付款平台、Cloudflare 驗證、你連接或匯入資料時的 Lichess 或 Chess.com，以及用於你要求的棋局分析的 Maia 或 Stockfish 服務。我們不會出售來自 App 的個人資訊。',
      'de':
          'Wir geben Daten nur weiter, soweit dies für den Betrieb der App, die Einhaltung von Gesetzen, den Schutz von Rechten oder die Bereitstellung der von dir gewählten Funktionen nötig ist. Verarbeiter können Hosting, Speicher, E-Mail, Analytics, Diagnosen, Zahlungsplattformen wie Apple und Google, Cloudflare-Verifizierung, Lichess oder Chess.com bei Verbindung oder Datenimport sowie Maia- oder Stockfish-Dienste für angeforderte Schachanalysen umfassen. Wir verkaufen keine personenbezogenen Daten aus der App.',
      'es':
          'Compartimos datos solo cuando es necesario para operar la app, cumplir la ley, proteger derechos o entregar funciones que elijas. Los encargados pueden incluir alojamiento, almacenamiento, correo, analítica, diagnósticos, plataformas de pago como Apple y Google, verificación de Cloudflare, Lichess o Chess.com cuando conectas o importas datos, y servicios de Maia o Stockfish para el análisis de ajedrez que solicites. No vendemos tu información personal de la app.',
      'fr':
          'Nous partageons les données uniquement lorsque c’est nécessaire pour faire fonctionner l’app, respecter la loi, protéger des droits ou fournir les fonctions que vous choisissez. Les prestataires peuvent inclure l’hébergement, le stockage, l’e-mail, l’analytics, les diagnostics, les plateformes de paiement comme Apple et Google, la vérification Cloudflare, Lichess ou Chess.com lorsque vous connectez ou importez des données, ainsi que les services Maia ou Stockfish pour l’analyse d’échecs demandée. Nous ne vendons pas vos informations personnelles issues de l’app.',
      'it':
          'Condividiamo dati solo quando serve per far funzionare l’app, rispettare la legge, proteggere diritti o fornire le funzioni che scegli. I responsabili possono includere hosting, archiviazione, email, analytics, diagnostica, piattaforme di pagamento come Apple e Google, verifica Cloudflare, Lichess o Chess.com quando colleghi o importi dati, e servizi Maia o Stockfish per le analisi scacchistiche richieste. Non vendiamo le tue informazioni personali provenienti dall’app.',
      'ja':
          'データは、アプリの運営、法令遵守、権利保護、またはあなたが選択した機能の提供に必要な場合にのみ共有します。処理者には、ホスティング、ストレージ、メール、分析、診断、Apple や Google などの決済プラットフォーム、Cloudflare 認証、接続またはデータインポート時の Lichess または Chess.com、依頼されたチェス分析のための Maia または Stockfish サービスが含まれる場合があります。アプリから得た個人情報を販売することはありません。',
      'ko':
          '당사는 앱 운영, 법 준수, 권리 보호 또는 사용자가 선택한 기능 제공에 필요한 경우에만 데이터를 공유합니다. 처리업체에는 호스팅, 저장소, 이메일, 분석, 진단, Apple 및 Google 같은 결제 플랫폼, Cloudflare 인증, 사용자가 연결하거나 데이터를 가져올 때의 Lichess 또는 Chess.com, 요청한 체스 분석을 위한 Maia 또는 Stockfish 서비스가 포함될 수 있습니다. 당사는 앱에서 얻은 개인정보를 판매하지 않습니다.',
      'nl':
          'We delen gegevens alleen voor zover nodig om de app te laten werken, aan de wet te voldoen, rechten te beschermen of functies te leveren die jij kiest. Verwerkers kunnen hosting, opslag, e-mail, analytics, diagnostiek, betaalplatformen zoals Apple en Google, Cloudflare-verificatie, Lichess of Chess.com wanneer je koppelt of data importeert, en Maia- of Stockfish-diensten voor gevraagde schaakanalyse omvatten. We verkopen je persoonlijke informatie uit de app niet.',
      'ru':
          'Мы передаем данные только в той мере, в какой это нужно для работы приложения, соблюдения закона, защиты прав или предоставления выбранных вами функций. Обработчики могут включать хостинг, хранение, email, аналитику, диагностику, платежные платформы, такие как Apple и Google, проверку Cloudflare, Lichess или Chess.com при подключении или импорте данных, а также сервисы Maia или Stockfish для запрошенного шахматного анализа. Мы не продаем вашу личную информацию из приложения.',
    },
    'Retention and deletion': {
      'zh-Hans': '保留与删除',
      'zh-Hant': '保留與刪除',
      'de': 'Aufbewahrung und Löschung',
      'es': 'Conservación y eliminación',
      'fr': 'Conservation et suppression',
      'it': 'Conservazione ed eliminazione',
      'ja': '保持と削除',
      'ko': '보관 및 삭제',
      'nl': 'Bewaren en verwijderen',
      'ru': 'Хранение и удаление',
    },
    'We keep account, purchase, wallet, game record, analysis, and diagnostic information while your account is active or as needed for the feature, support, security, legal, tax, or backup purposes. You may delete records or request account deletion where available. Some backup, fraud-prevention, legal, or transaction records may be kept for a limited period when required.':
        {
      'zh-Hans':
          '在你的账户处于活跃状态期间，或出于功能、支持、安全、法律、税务或备份需要时，我们会保留账户、购买、钱包、对局记录、分析和诊断信息。你可以在可用的地方删除记录或请求删除账户。某些备份、防欺诈、法律或交易记录可能会在必要时保留一段有限时间。',
      'zh-Hant':
          '在你的帳戶處於有效狀態期間，或出於功能、支援、安全、法律、稅務或備份需要時，我們會保留帳戶、購買、錢包、對局記錄、分析和診斷資訊。你可以在可用的地方刪除記錄或要求刪除帳戶。某些備份、防詐欺、法律或交易記錄可能會在必要時保留一段有限時間。',
      'de':
          'Wir bewahren Konto-, Kauf-, Wallet-, Partien-, Analyse- und Diagnoseinformationen auf, solange dein Konto aktiv ist oder soweit dies für Funktionen, Support, Sicherheit, rechtliche, steuerliche oder Sicherungszwecke nötig ist. Du kannst Datensätze löschen oder, wo verfügbar, die Löschung deines Kontos anfordern. Einige Backup-, Betrugspräventions-, Rechts- oder Transaktionsdaten können bei Bedarf für begrenzte Zeit aufbewahrt werden.',
      'es':
          'Conservamos información de cuenta, compras, wallet, registros de partidas, análisis y diagnósticos mientras tu cuenta esté activa o según sea necesario para funciones, soporte, seguridad, fines legales, fiscales o de copia de seguridad. Puedes eliminar registros o solicitar la eliminación de la cuenta cuando esté disponible. Algunos registros de respaldo, prevención de fraude, legales o de transacciones pueden conservarse durante un periodo limitado cuando sea necesario.',
      'fr':
          'Nous conservons les informations de compte, d’achat, de wallet, de parties, d’analyse et de diagnostic tant que votre compte est actif ou selon les besoins de la fonction, de l’assistance, de la sécurité, des obligations légales ou fiscales, ou des sauvegardes. Vous pouvez supprimer des enregistrements ou demander la suppression du compte lorsque cette option est disponible. Certaines sauvegardes et certains enregistrements de prévention de la fraude, légaux ou transactionnels peuvent être conservés pendant une durée limitée si nécessaire.',
      'it':
          'Conserviamo informazioni su account, acquisti, wallet, record di partita, analisi e diagnostica mentre il tuo account è attivo o quando servono per funzioni, supporto, sicurezza, obblighi legali, fiscali o backup. Puoi eliminare record o richiedere l’eliminazione dell’account dove disponibile. Alcuni record di backup, prevenzione frodi, legali o di transazione possono essere conservati per un periodo limitato quando necessario.',
      'ja':
          'アカウントが有効な間、または機能、サポート、セキュリティ、法的、税務、バックアップの目的で必要な場合、アカウント、購入、ウォレット、対局記録、分析、診断情報を保持します。利用可能な場合、記録の削除やアカウント削除をリクエストできます。一部のバックアップ、不正防止、法的、取引記録は、必要に応じて一定期間保持される場合があります。',
      'ko':
          '계정이 활성 상태인 동안 또는 기능, 지원, 보안, 법적, 세무, 백업 목적에 필요한 동안 계정, 구매, 지갑, 대국 기록, 분석, 진단 정보를 보관합니다. 가능한 경우 기록을 삭제하거나 계정 삭제를 요청할 수 있습니다. 일부 백업, 사기 방지, 법적 또는 거래 기록은 필요할 때 제한된 기간 동안 보관될 수 있습니다.',
      'nl':
          'We bewaren account-, aankoop-, wallet-, partijrecord-, analyse- en diagnostische informatie zolang je account actief is of zolang dit nodig is voor functies, support, beveiliging, wettelijke, fiscale of back-updoeleinden. Je kunt records verwijderen of, waar beschikbaar, accountverwijdering aanvragen. Sommige back-up-, fraudepreventie-, juridische of transactierecords kunnen indien nodig voor een beperkte periode worden bewaard.',
      'ru':
          'Мы храним сведения об аккаунте, покупках, кошельке, записях партий, анализе и диагностике, пока ваш аккаунт активен или пока это нужно для функций, поддержки, безопасности, юридических, налоговых целей или резервного копирования. Вы можете удалять записи или запрашивать удаление аккаунта там, где это доступно. Некоторые резервные, антифродовые, юридические или транзакционные записи могут храниться ограниченное время, когда это необходимо.',
    },
    'Your privacy rights': {
      'zh-Hans': '你的隐私权利',
      'zh-Hant': '你的隱私權利',
      'de': 'Deine Datenschutzrechte',
      'es': 'Tus derechos de privacidad',
      'fr': 'Vos droits en matière de confidentialité',
      'it': 'I tuoi diritti privacy',
      'ja': 'プライバシーに関する権利',
      'ko': '개인정보 권리',
      'nl': 'Je privacyrechten',
      'ru': 'Ваши права на конфиденциальность',
    },
    'Depending on where you live, you may have rights to access, correct, export, restrict, object to, or delete personal information. You may also withdraw consent for optional features where consent is the basis for processing. To exercise privacy rights, ask questions, or make a complaint, contact contact@chessnutech.com.':
        {
      'zh-Hans':
          '根据你所在地区，你可能有权访问、更正、导出、限制、反对或删除个人信息。如果可选功能以同意作为处理依据，你也可以撤回同意。如需行使隐私权利、提出问题或投诉，请联系 contact@chessnutech.com。',
      'zh-Hant':
          '根據你所在地區，你可能有權存取、更正、匯出、限制、反對或刪除個人資訊。如果選用功能以同意作為處理依據，你也可以撤回同意。如需行使隱私權利、提出問題或申訴，請聯絡 contact@chessnutech.com。',
      'de':
          'Je nach deinem Wohnort hast du möglicherweise das Recht, personenbezogene Daten einzusehen, zu berichtigen, zu exportieren, einzuschränken, der Verarbeitung zu widersprechen oder sie zu löschen. Du kannst außerdem deine Einwilligung für optionale Funktionen widerrufen, wenn die Verarbeitung auf Einwilligung beruht. Um Datenschutzrechte auszuüben, Fragen zu stellen oder eine Beschwerde einzureichen, kontaktiere contact@chessnutech.com.',
      'es':
          'Según dónde vivas, puedes tener derechos para acceder, corregir, exportar, restringir, oponerte o eliminar información personal. También puedes retirar el consentimiento para funciones opcionales cuando el consentimiento sea la base del tratamiento. Para ejercer derechos de privacidad, hacer preguntas o presentar una queja, contacta con contact@chessnutech.com.',
      'fr':
          'Selon votre lieu de résidence, vous pouvez avoir le droit d’accéder à vos informations personnelles, de les corriger, les exporter, en limiter le traitement, vous y opposer ou les supprimer. Vous pouvez aussi retirer votre consentement pour les fonctions optionnelles lorsque le consentement est la base du traitement. Pour exercer vos droits, poser une question ou déposer une plainte, contactez contact@chessnutech.com.',
      'it':
          'A seconda di dove vivi, potresti avere il diritto di accedere, correggere, esportare, limitare, opporti o eliminare informazioni personali. Puoi anche revocare il consenso per le funzioni opzionali quando il consenso è la base del trattamento. Per esercitare i diritti privacy, fare domande o presentare un reclamo, contatta contact@chessnutech.com.',
      'ja':
          'お住まいの地域によっては、個人情報へのアクセス、訂正、エクスポート、制限、異議申し立て、削除を行う権利がある場合があります。同意が処理の根拠となる任意機能については、同意を撤回することもできます。プライバシー権利の行使、質問、苦情は contact@chessnutech.com までご連絡ください。',
      'ko':
          '거주 지역에 따라 개인정보에 접근, 수정, 내보내기, 제한, 반대 또는 삭제할 권리가 있을 수 있습니다. 동의가 처리 근거인 선택 기능에 대해서는 동의를 철회할 수도 있습니다. 개인정보 권리를 행사하거나 질문하거나 불만을 제기하려면 contact@chessnutech.com으로 연락하세요.',
      'nl':
          'Afhankelijk van waar je woont kun je rechten hebben om persoonlijke informatie in te zien, te corrigeren, te exporteren, te beperken, bezwaar te maken of te verwijderen. Je kunt ook toestemming voor optionele functies intrekken wanneer toestemming de basis voor verwerking is. Neem contact op via contact@chessnutech.com om privacyrechten uit te oefenen, vragen te stellen of een klacht in te dienen.',
      'ru':
          'В зависимости от места проживания у вас могут быть права на доступ, исправление, экспорт, ограничение, возражение против обработки или удаление личной информации. Вы также можете отозвать согласие для дополнительных функций, если согласие является основанием обработки. Чтобы воспользоваться правами на конфиденциальность, задать вопросы или подать жалобу, свяжитесь с contact@chessnutech.com.',
    },
    'Cookies, analytics, and diagnostics': {
      'zh-Hans': 'Cookie、分析与诊断',
      'zh-Hant': 'Cookie、分析與診斷',
      'de': 'Cookies, Analytics und Diagnosen',
      'es': 'Cookies, analítica y diagnósticos',
      'fr': 'Cookies, analytics et diagnostics',
      'it': 'Cookie, analytics e diagnostica',
      'ja': 'Cookie、分析、診断',
      'ko': '쿠키, 분석 및 진단',
      'nl': 'Cookies, analytics en diagnostiek',
      'ru': 'Cookies, аналитика и диагностика',
    },
    'Our website may use cookies, local storage, analytics, advertising, and similar technologies as described in the website privacy policy. The app may use local storage, crash diagnostics, performance logs, and security telemetry to keep you signed in, remember preferences, investigate problems, and improve the service.':
        {
      'zh-Hans':
          '我们的网站可能会按照网站隐私政策所述使用 Cookie、本地存储、分析、广告和类似技术。App 可能会使用本地存储、崩溃诊断、性能日志和安全遥测，以保持你的登录状态、记住偏好、调查问题并改进服务。',
      'zh-Hant':
          '我們的網站可能會按照網站隱私政策所述使用 Cookie、本機儲存、分析、廣告和類似技術。App 可能會使用本機儲存、當機診斷、效能日誌和安全遙測，以保持你的登入狀態、記住偏好、調查問題並改進服務。',
      'de':
          'Unsere Website kann Cookies, lokalen Speicher, Analytics, Werbung und ähnliche Technologien verwenden, wie in der Datenschutzerklärung der Website beschrieben. Die App kann lokalen Speicher, Absturzdiagnosen, Leistungslogs und Sicherheitstelemetrie verwenden, um dich angemeldet zu halten, Einstellungen zu merken, Probleme zu untersuchen und den Dienst zu verbessern.',
      'es':
          'Nuestro sitio web puede usar cookies, almacenamiento local, analítica, publicidad y tecnologías similares según se describe en la política de privacidad del sitio web. La app puede usar almacenamiento local, diagnósticos de fallos, logs de rendimiento y telemetría de seguridad para mantener tu sesión, recordar preferencias, investigar problemas y mejorar el servicio.',
      'fr':
          'Notre site web peut utiliser des cookies, le stockage local, l’analytics, la publicité et des technologies similaires comme décrit dans la politique de confidentialité du site. L’app peut utiliser le stockage local, les diagnostics de crash, les logs de performance et la télémétrie de sécurité pour vous garder connecté, mémoriser vos préférences, enquêter sur les problèmes et améliorer le service.',
      'it':
          'Il nostro sito web può usare cookie, archiviazione locale, analytics, pubblicità e tecnologie simili come descritto nella privacy policy del sito. L’app può usare archiviazione locale, diagnostica dei crash, log delle prestazioni e telemetria di sicurezza per mantenere l’accesso, ricordare le preferenze, indagare problemi e migliorare il servizio.',
      'ja':
          '当社ウェブサイトは、ウェブサイトのプライバシーポリシーに記載されているとおり、Cookie、ローカルストレージ、分析、広告、および類似技術を使用する場合があります。アプリは、ログイン状態の維持、設定の記憶、問題調査、サービス改善のために、ローカルストレージ、クラッシュ診断、パフォーマンスログ、セキュリティテレメトリを使用する場合があります。',
      'ko':
          '당사 웹사이트는 웹사이트 개인정보처리방침에 설명된 대로 Cookie, 로컬 저장소, 분석, 광고 및 유사 기술을 사용할 수 있습니다. 앱은 로그인 상태 유지, 환경설정 기억, 문제 조사, 서비스 개선을 위해 로컬 저장소, 충돌 진단, 성능 로그 및 보안 텔레메트리를 사용할 수 있습니다.',
      'nl':
          'Onze website kan cookies, lokale opslag, analytics, advertenties en vergelijkbare technologieën gebruiken zoals beschreven in het privacybeleid van de website. De app kan lokale opslag, crashdiagnostiek, prestatielogs en beveiligingstelemetrie gebruiken om je ingelogd te houden, voorkeuren te onthouden, problemen te onderzoeken en de service te verbeteren.',
      'ru':
          'Наш сайт может использовать cookies, локальное хранилище, аналитику, рекламу и похожие технологии, как описано в политике конфиденциальности сайта. Приложение может использовать локальное хранилище, диагностику сбоев, журналы производительности и телеметрию безопасности, чтобы сохранять вход, запоминать настройки, исследовать проблемы и улучшать сервис.',
    },
    'Children and security': {
      'zh-Hans': '儿童与安全',
      'zh-Hant': '兒童與安全',
      'de': 'Kinder und Sicherheit',
      'es': 'Menores y seguridad',
      'fr': 'Enfants et sécurité',
      'it': 'Minori e sicurezza',
      'ja': '子どもとセキュリティ',
      'ko': '아동 및 보안',
      'nl': 'Kinderen en beveiliging',
      'ru': 'Дети и безопасность',
    },
    'Chessnut is designed for general chess users and is not directed at children below the age required by local law to create an online account without guardian consent. We use reasonable technical and organizational measures to protect information, but no networked service can be guaranteed completely secure.':
        {
      'zh-Hans':
          'Chessnut 面向一般国际象棋用户设计，并非面向未达到当地法律规定、可在无监护人同意下创建在线账户年龄的儿童。我们会采取合理的技术和组织措施保护信息，但任何联网服务都无法保证完全安全。',
      'zh-Hant':
          'Chessnut 面向一般國際象棋使用者設計，並非面向未達到當地法律規定、可在無監護人同意下建立線上帳戶年齡的兒童。我們會採取合理的技術和組織措施保護資訊，但任何連網服務都無法保證完全安全。',
      'de':
          'Chessnut ist für allgemeine Schachnutzer gedacht und richtet sich nicht an Kinder unter dem Alter, das nach lokalem Recht erforderlich ist, um ohne Zustimmung eines Erziehungsberechtigten ein Online-Konto zu erstellen. Wir nutzen angemessene technische und organisatorische Maßnahmen zum Schutz von Informationen, aber kein vernetzter Dienst kann vollständig sicher garantiert werden.',
      'es':
          'Chessnut está diseñado para usuarios generales de ajedrez y no está dirigido a menores que no alcancen la edad exigida por la ley local para crear una cuenta en línea sin consentimiento de un tutor. Usamos medidas técnicas y organizativas razonables para proteger la información, pero ningún servicio conectado a la red puede garantizarse como completamente seguro.',
      'fr':
          'Chessnut est conçu pour les utilisateurs d’échecs en général et ne s’adresse pas aux enfants n’ayant pas l’âge requis par la loi locale pour créer un compte en ligne sans consentement d’un responsable légal. Nous utilisons des mesures techniques et organisationnelles raisonnables pour protéger les informations, mais aucun service en réseau ne peut être garanti comme totalement sécurisé.',
      'it':
          'Chessnut è pensato per utenti generali di scacchi e non è rivolto a minori sotto l’età richiesta dalla legge locale per creare un account online senza il consenso di un tutore. Usiamo misure tecniche e organizzative ragionevoli per proteggere le informazioni, ma nessun servizio in rete può essere garantito completamente sicuro.',
      'ja':
          'Chessnut は一般のチェスユーザー向けに設計されており、保護者の同意なしにオンラインアカウントを作成できる年齢として現地法が定める年齢に満たない子どもを対象としていません。情報を保護するために合理的な技術的および組織的措置を講じていますが、ネットワーク接続サービスが完全に安全であることは保証できません。',
      'ko':
          'Chessnut은 일반 체스 사용자를 위해 설계되었으며, 보호자 동의 없이 온라인 계정을 만들 수 있도록 현지 법에서 요구하는 연령 미만의 아동을 대상으로 하지 않습니다. 당사는 정보를 보호하기 위해 합리적인 기술적 및 조직적 조치를 사용하지만, 네트워크 서비스가 완전히 안전하다고 보장할 수는 없습니다.',
      'nl':
          'Chessnut is ontworpen voor algemene schaakgebruikers en is niet gericht op kinderen onder de leeftijd die lokale wetgeving vereist om zonder toestemming van een voogd een online account aan te maken. We gebruiken redelijke technische en organisatorische maatregelen om informatie te beschermen, maar geen enkele netwerkdienst kan volledig veilig worden gegarandeerd.',
      'ru':
          'Chessnut предназначен для обычных пользователей шахмат и не направлен на детей младше возраста, установленного местным законом для создания онлайн-аккаунта без согласия опекуна. Мы применяем разумные технические и организационные меры для защиты информации, но ни один сетевой сервис не может быть гарантированно полностью безопасным.',
    },
    'Policy changes and contact': {
      'zh-Hans': '政策变更与联系方式',
      'zh-Hant': '政策變更與聯絡方式',
      'de': 'Änderungen der Richtlinie und Kontakt',
      'es': 'Cambios de la política y contacto',
      'fr': 'Modifications de la politique et contact',
      'it': 'Modifiche alla policy e contatti',
      'ja': 'ポリシー変更と連絡先',
      'ko': '정책 변경 및 연락처',
      'nl': 'Beleidswijzigingen en contact',
      'ru': 'Изменения политики и контакты',
    },
    'We may update this policy when our app, website, data practices, partners, or legal requirements change. The latest website privacy policy is available at https://www.chessnutech.com/pages/privacy-policy. For privacy questions or complaints, email contact@chessnutech.com.':
        {
      'zh-Hans':
          '当我们的 App、网站、数据处理方式、合作伙伴或法律要求发生变化时，我们可能会更新本政策。最新的网站隐私政策可在 https://www.chessnutech.com/pages/privacy-policy 查看。如有隐私问题或投诉，请发送邮件至 contact@chessnutech.com。',
      'zh-Hant':
          '當我們的 App、網站、資料處理方式、合作夥伴或法律要求發生變化時，我們可能會更新本政策。最新的網站隱私政策可在 https://www.chessnutech.com/pages/privacy-policy 查看。如有隱私問題或申訴，請寄送電子郵件至 contact@chessnutech.com。',
      'de':
          'Wir können diese Richtlinie aktualisieren, wenn sich unsere App, Website, Datenpraktiken, Partner oder rechtlichen Anforderungen ändern. Die aktuelle Datenschutzrichtlinie der Website ist unter https://www.chessnutech.com/pages/privacy-policy verfügbar. Für Datenschutzfragen oder Beschwerden sende eine E-Mail an contact@chessnutech.com.',
      'es':
          'Podemos actualizar esta política cuando cambien nuestra app, sitio web, prácticas de datos, socios o requisitos legales. La política de privacidad más reciente del sitio web está disponible en https://www.chessnutech.com/pages/privacy-policy. Para preguntas o quejas de privacidad, escribe a contact@chessnutech.com.',
      'fr':
          'Nous pouvons mettre à jour cette politique lorsque notre app, notre site web, nos pratiques en matière de données, nos partenaires ou les exigences légales changent. La dernière politique de confidentialité du site web est disponible sur https://www.chessnutech.com/pages/privacy-policy. Pour toute question ou plainte relative à la confidentialité, écrivez à contact@chessnutech.com.',
      'it':
          'Possiamo aggiornare questa policy quando cambiano la nostra app, il sito web, le pratiche sui dati, i partner o i requisiti legali. L’ultima privacy policy del sito web è disponibile su https://www.chessnutech.com/pages/privacy-policy. Per domande o reclami sulla privacy, scrivi a contact@chessnutech.com.',
      'ja':
          '当社のアプリ、ウェブサイト、データの取り扱い、パートナー、または法的要件が変更された場合、このポリシーを更新することがあります。最新のウェブサイトプライバシーポリシーは https://www.chessnutech.com/pages/privacy-policy で確認できます。プライバシーに関する質問や苦情は contact@chessnutech.com までメールでお送りください。',
      'ko':
          '앱, 웹사이트, 데이터 관행, 파트너 또는 법적 요구사항이 변경되면 이 정책을 업데이트할 수 있습니다. 최신 웹사이트 개인정보처리방침은 https://www.chessnutech.com/pages/privacy-policy 에서 확인할 수 있습니다. 개인정보 관련 질문이나 불만은 contact@chessnutech.com으로 이메일을 보내세요.',
      'nl':
          'We kunnen dit beleid bijwerken wanneer onze app, website, gegevenspraktijken, partners of wettelijke vereisten veranderen. Het nieuwste privacybeleid van de website is beschikbaar op https://www.chessnutech.com/pages/privacy-policy. Voor privacyvragen of klachten kun je e-mailen naar contact@chessnutech.com.',
      'ru':
          'Мы можем обновлять эту политику при изменении нашего приложения, сайта, практик работы с данными, партнеров или юридических требований. Актуальная политика конфиденциальности сайта доступна по адресу https://www.chessnutech.com/pages/privacy-policy. По вопросам или жалобам о конфиденциальности пишите на contact@chessnutech.com.',
    },
  };
  return t[text]?[key];
}

String? _freshVisibleTranslations(String text, String key) {
  const zhHans = <String, String>{
    'ACCOUNT': '账户',
    'Account': '账户',
    'Account settings': '账户设置',
    'Profile, security, data': '资料、安全与数据',
    'Me': '我',
    'Welcome': '欢迎',
    'Sign in': '登录',
    'Sign in / register': '登录 / 注册',
    'Continue as guest': '以游客身份继续',
    'Stay as guest': '继续游客模式',
    'Sign in or create an account': '登录或创建账户',
    'Create': '创建',
    'Create account': '创建账户',
    'Create your Chessnut ID': '创建你的 Chessnut ID',
    'Reset password': '重置密码',
    'Sign in to Chessnut': '登录 Chessnut',
    'Create an account after a quick Turnstile human check. No email code required.':
        '通过 Turnstile 快速人机验证后即可创建账户，无需邮箱验证码。',
    'Send a secure one-time reset link. If it never arrives, support can verify your account and issue a new link.':
        '发送安全的一次性重置链接。如果一直未收到，客服可以验证你的账户并重新发送链接。',
    'Sync points, records, Grandeur credits, and board preferences across devices.':
        '在多台设备间同步积分、对局记录、Grandeur 点数和棋盘偏好。',
    'Secure': '安全',
    'or continue with': '或使用以下方式继续',
    'Continue with Apple': '使用 Apple 继续',
    'Continue with Google': '使用 Google 继续',
    'Continue with Meta': '使用 Meta 继续',
    'Email or account': '邮箱或账户',
    'Enter your email or Chessnut ID.': '请输入邮箱或 Chessnut ID。',
    'Password': '密码',
    'Use the password for your Chessnut account.': '使用你的 Chessnut 账户密码。',
    'Remember password': '记住密码',
    'Forgot?': '忘记了？',
    'Signing in': '正在登录',
    'Use phone verification code': '使用手机验证码',
    'Phone number': '手机号',
    'Mainland China phone number, for example 13812345678.':
        '中国大陆手机号，例如 13812345678。',
    'SMS code': '短信验证码',
    'Code sent. It expires in 5 minutes.': '验证码已发送，5 分钟内有效。',
    'Send a code to sign in or create an account.': '发送验证码以登录或创建账户。',
    'Sending': '正在发送',
    'Send code': '发送验证码',
    'Use email and password': '使用邮箱和密码',
    'Username': '用户名',
    'Email': '邮箱',
    'Choose the name shown in records and online play.': '选择在对局记录和线上对局中显示的名称。',
    'Used for sign in, receipts, and password recovery.': '用于登录、收据和找回密码。',
    'Creating account': '正在创建账户',
    'Use at least 8 characters and any 2 character types.':
        '至少 8 个字符，并包含任意 2 类字符。',
    'Use 8+ characters and at least two types: uppercase, lowercase, number, or symbol.':
        '请使用 8 个以上字符，并至少包含两类：大写字母、小写字母、数字或符号。',
    '8+ characters': '8 个以上字符',
    'Choose any 2': '任选 2 类',
    'Uppercase': '大写字母',
    'Lowercase': '小写字母',
    'Number': '数字',
    'Symbol': '符号',
    'Password meets the rules': '密码符合规则',
    'Password needs attention': '密码需要调整',
    'Reset email': '重置邮箱',
    'Enter the email linked to your account.': '请输入绑定账户的邮箱。',
    'Password reset email sent': '重置密码邮件已发送',
    'Reset link by email': '通过邮箱发送重置链接',
    'We will send a one-time reset link if this email belongs to a Chessnut account.':
        '如果该邮箱属于 Chessnut 账户，我们会发送一次性重置链接。',
    'Open the link from your inbox to set a new password. The message may take a moment to arrive.':
        '打开邮箱中的链接来设置新密码。邮件可能需要一点时间送达。',
    'Sending reset link': '正在发送重置链接',
    'Resend reset link': '重新发送重置链接',
    'Send reset link': '发送重置链接',
    'Back to sign in': '返回登录',
    'Support verifies ownership before issuing a new link.':
        '客服会先验证账户归属，再发送新的重置链接。',
    'Check your inbox for the secure reset link.': '请在收件箱查看安全重置链接。',
    'Contact support': '联系客服',
    'If the reset link does not arrive, contact Chessnut support. After account ownership is verified, support can generate a new reset link.':
        '如果没有收到重置链接，请联系 Chessnut 客服。验证账户归属后，客服可以生成新的重置链接。',
    'Turnstile verification': 'Turnstile 人机验证',
    'Human verified': '已通过人机验证',
    'Connecting to Cloudflare Turnstile...': '正在连接 Cloudflare Turnstile...',
    'Complete this check to confirm this signup is not automated.':
        '完成此检查以确认本次注册不是自动化操作。',
    'Verifying': '正在验证',
    'Verify I am not a robot': '验证我不是机器人',
    'I agree to': '我同意',
    'and': '和',
    'Terms of Use': '使用条款',
    'Privacy Policy': '隐私政策',
    'Got it': '知道了',
    'Dismiss error': '关闭错误提示',
    'Sign-in setup needed': '需要配置登录',
    'Sign-in method unavailable': '登录方式不可用',
    'Connection issue': '连接异常',
    'Sign-in cancelled': '登录已取消',
    'Sign-in needs attention': '登录需要处理',
    'Enter your email or account and password.': '请输入邮箱/账户和密码。',
    'Sign in failed.': '登录失败。',
    'Enter your phone number.': '请输入手机号。',
    'SMS verification code could not be sent. Please try again later.':
        '短信验证码发送失败，请稍后重试。',
    'Enter your phone number and verification code.': '请输入手机号和验证码。',
    'Cloudflare Turnstile verification failed.': 'Cloudflare Turnstile 验证失败。',
    'Enter username, email, and password.': '请输入用户名、邮箱和密码。',
    'Complete Turnstile verification first.': '请先完成人机验证。',
    'Account creation failed.': '账户创建失败。',
    'Enter your account email.': '请输入账户邮箱。',
    'Unable to send reset link.': '无法发送重置链接。',
    'Sign in did not finish. Please try again.': '登录未完成，请重试。',
    'Please agree to the Terms of Use and Privacy Policy.': '请先同意使用条款和隐私政策。',
    'Wallet': '钱包',
    'Tap to view details': '点击查看详情',
    'Daily points': '每日积分',
    'Account ledger': '账户流水',
    'Loading account wallet...': '正在加载账户钱包...',
    'Loading wallet ledger': '正在加载钱包流水',
    'Wallet unavailable.': '钱包不可用。',
    'Wallet is not available right now. Check your connection and try again.':
        '钱包暂不可用，请检查网络后重试。',
    'Wallet cloud sync is temporarily unavailable. Daily points are saved on this device.':
        '钱包云同步暂不可用。每日积分已保存在本设备。',
    'Wallet test tools are unavailable.': '钱包测试工具不可用。',
    'Sign in to sync points and profile.': '登录后同步积分和个人资料。',
    'Sign in to sync points, membership, and ledger.': '登录后同步积分、会员和流水。',
    'daily reward claimed today': '今日每日奖励已领取',
    'daily reward available': '每日奖励可领取',
    'points': '积分',
    'pts': '积分',
    'Premium active / Grandeur and personal engine training unlimited':
        'Premium 已激活 / Grandeur 和个人引擎训练不限量',
    'Checked in today / Grandeur 100 / personal engine training 500':
        '今日已签到 / Grandeur 100 / 个人引擎训练 500',
    'Daily check-in available / Grandeur 100 / personal engine training 500':
        '每日签到可领取 / Grandeur 100 / 个人引擎训练 500',
    'Premium removes point costs': 'Premium 免积分消耗',
    'Grandeur and personal engine training become unlimited.':
        'Grandeur 和个人引擎训练将不限量。',
    'Upgrade membership': '升级会员',
    'Unlimited Grandeur and personal engine training': 'Grandeur 和个人引擎训练不限量',
    'No point activity yet.': '暂无积分记录。',
    'Daily tasks': '每日任务',
    'Daily Tasks': '每日任务',
    'Earn points through real Chessnut workflows': '通过真实 Chessnut 使用流程获得积分',
    'tasks completed today': '今日已完成任务',
    'A compact daily loop for learning, playing, reviewing, and sharing games.':
        '一套紧凑的每日流程：学习、对局、复盘并分享对局。',
    'Check in': '签到',
    'Claim once per day. Refreshes at local noon after 24 hours.':
        '每日可领取一次。24 小时后在本地中午刷新。',
    'Finish one bot or online game': '完成一盘机器人或线上对局',
    'Play a complete Chessnut game with bot or online mode.':
        '使用机器人或线上模式完成一盘 Chessnut 对局。',
    'Play one puzzle': '完成一道谜题',
    'Solve a tactical puzzle from the training area.': '完成训练区的一道战术题。',
    'Share one game': '分享一盘对局',
    'Share a live or recorded game link with a friend.': '向朋友分享一条直播或已记录对局链接。',
    'Share one report': '分享一份报告',
    'Share a Standard or Grandeur report image.':
        '分享一张 Standard 或 Grandeur 报告图片。',
    'Run one game analysis': '运行一次对局分析',
    'Review a PGN with Stockfish or Grandeur.':
        '使用 Stockfish 或 Grandeur 复盘一个 PGN。',
    'Completed today': '今日已完成',
    'Done': '完成',
    'Go': '前往',
    'Claim': '领取',
    'Claimed': '已领取',
    'Claiming...': '正在领取...',
    'All daily tasks completed.': '每日任务已全部完成。',
    'Sign in to claim points and keep your streak.': '登录后领取积分并保持连续记录。',
    'Check in and finish today\'s chess goals.': '签到并完成今天的国际象棋目标。',
    'Progress synced. Keep the streak moving.': '进度已同步，继续保持连续记录。',
    'Check-in ready': '可签到',
    'Checked in today': '今日已签到',
    'The check-in task refreshes at local noon, and still requires at least 24 hours since the last claim.':
        '签到任务会在本地中午刷新，并且距离上次领取仍需至少 24 小时。',
    'Come back after the next valid refresh window to claim again.':
        '下一个有效刷新窗口后再回来领取。',
    'Sound effects': '音效',
    'Master switch for all app sounds': '控制 App 所有声音的总开关',
    'From/to voice': '起止格语音',
    'Speak opponent move squares, such as e7 to e5': '播报对手走棋格，例如 e7 到 e5',
    'Move sounds': '走棋音效',
    'Play move, capture, and check effects': '播放走棋、吃子和将军音效',
    'Result sounds': '结果音效',
    'Play victory, defeat, and draw sounds': '播放胜利、失败和平局音效',
    'Key action sounds': '关键操作音效',
    'Play game start, hint, and confirm sounds': '播放开局、提示和确认音效',
    'Clock Switch': '棋钟开关',
    'Automatic switch press': '自动按钟',
    'Choose when the clock hardware switch is pressed for you.':
        '选择何时由系统代你按下棋钟硬件开关。',
    'Off': '关闭',
    'Opponent move only': '仅对手走棋后自动',
    'Both sides': '双方走棋后都自动',
    'Opponent move mode': '对手走棋模式',
    'Controls AI and online opponent clock presses.': '控制 AI 和线上对手走棋后的按钟方式。',
    'Aggressive': '快速',
    'Leisure': '稳妥',
    'Aggressive mode': '快速模式',
    'Press as soon as the opponent move arrives.': '对手走法到达后立即按钟。',
    'Leisure mode': '稳妥模式',
    'Wait until the board matches the opponent move.': '等待棋盘与对手走法一致后再按钟。',
    'Confirm moves with switch': '用开关确认走子',
    'Hold board moves until the clock switch is pressed.':
        '棋盘走子会先等待，直到按下棋钟开关后再确认。',
    'Clock switch details': '棋钟开关说明',
    'Stockfish strength from 600 to 3190.': 'Stockfish 强度范围为 600 到 3190。',
    'Edit profile': '编辑资料',
    'Choose how you appear in Chessnut.': '设置你在 Chessnut 中的显示方式。',
    'Cancel': '取消',
    'Saving': '正在保存',
    'Save profile': '保存资料',
    'Enter a username.': '请输入用户名。',
    'Profile updated.': '资料已更新。',
    'Profile update failed. Check your connection and try again.':
        '资料更新失败，请检查网络后重试。',
    'Linked accounts': '已关联账户',
    'Linked': '已关联',
    'Not linked': '未关联',
    'Link': '关联',
    'Unlink': '取消关联',
    'Linked account updated.': '关联账户已更新。',
    'Linked account update failed. Please try again.': '关联账户更新失败，请重试。',
    'Sign in before authorizing Lichess.': '授权 Lichess 前请先登录。',
    'Lichess authorization is not available right now. Please try again later.':
        'Lichess 授权暂不可用，请稍后重试。',
    'Lichess authorization could not open. Try again later.':
        '无法打开 Lichess 授权，请稍后重试。',
    'Lichess authorized.': 'Lichess 已授权。',
    'Lichess authorization was not completed. Try again when the Lichess page finishes.':
        'Lichess 授权未完成，请在 Lichess 页面完成后重试。',
    'Lichess sign-in status could not be checked. Please try again later.':
        '无法检查 Lichess 登录状态，请稍后重试。',
    'Lichess authorized': 'Lichess 已授权',
    'Keep linked': '保持关联',
    'Unlink Lichess': '取消关联 Lichess',
    'Connected as': '当前关联为',
    'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.':
        '你的 Chessnut 账户已关联 Lichess。可以保持当前关联；如果要授权其他 Lichess 账户，也可以取消关联。',
    'Lichess account unlinked.': 'Lichess 账户已取消关联。',
    'Game Record': '对局记录',
    'Engine Lab': '引擎实验室',
    'Practice': '练习',
    'Lessons & puzzles': '课程与谜题',
    'Interactive Courses': '互动课程',
    'Video lessons with board checkpoints': '带棋盘检查点的视频课程',
    'Watch': '观看',
    'Video': '视频',
    'Pause': '暂停',
    'Checkpoint': '检查点',
    'Board': '棋盘',
    'Lights': '灯光',
    'Open course library': '打开课程库',
    'Training modes': '训练模式',
    '4 tools': '4 个工具',
    'Board analyzer': '棋盘分析器',
    'Live Stockfish board': '实时 Stockfish 棋盘',
    'Puzzle storm': '谜题风暴',
    'Fast pattern training': '快速棋形训练',
    'Puzzle themes': '谜题主题',
    'Practice by motif': '按主题练习',
    'Mistake book': '错题本',
    'From your games': '来自你的对局',
    'Practice flow': '练习流程',
    '15 min': '15 分钟',
    'Warm up with tactics': '用战术热身',
    'Quick tactics': '快速战术',
    'Review one weak spot': '复盘一个薄弱点',
    'Personal review': '个人复习',
    'Analyze freely': '自由分析',
    'Free analysis': '自由分析',
    'Train your chess style': '训练你的棋风',
    'Train engines from your own games': '用你的对局训练引擎',
    'Choose your games, let Chessnut train in the cloud, then play against your personal engine.':
        '选择你的对局，让 Chessnut 在云端训练，然后与你的个人引擎对弈。',
    'Personal engine training flow': '个人引擎训练流程',
    'Choose your games': '选择你的对局',
    'Use Game Record filters or paste a multi-game PGN batch.':
        '使用对局记录筛选，或粘贴包含多盘对局的 PGN。',
    'Train safely in the cloud': '在云端安全训练',
    'Chessnut trains with most games and keeps a smaller set to check quality.':
        'Chessnut 会使用大部分对局训练，并保留少量对局检查质量。',
    'Play your model': '试玩你的模型',
    'Finished engines appear in Bot game when they pass quality checks.':
        '通过质量检查后，完成的引擎会出现在 Bot game 中。',
    'Premium unlimited': 'Premium 不限量',
    'Standard plan': '标准方案',
    'Engine report': '引擎报告',
    'Open report': '打开报告',
    'Open': '打开',
    'Building': '构建中',
    'Download': '下载',
    'Model Accuracy': '模型准确率',
    'Model Fitting Degree': '模型拟合度',
    'Data Effectiveness': '数据有效性',
    'PGN samples': 'PGN 示例',
    'Target': '目标',
    'Playable engine library': '可用引擎库',
    'No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.':
        '还没有可用的个人引擎。构建完成并可用于 Bot game 后会显示在这里。',
    'PGN sync': 'PGN 同步',
    'Models': '模型',
    'Authorizing...': '正在授权...',
    'Checking...': '正在检查...',
    'Authorized': '已授权',
    'Authorize Lichess': '授权 Lichess',
    'Sign out?': '退出登录？',
    'You will return to the login screen. Your saved games remain on this device.':
        '你将返回登录页面。已保存的棋局仍会保留在此设备上。',
    'Sign out': '退出登录',
    'Return to login': '返回登录',
    'Delete account': '删除账户',
    'Password confirmation required': '需要确认密码',
  };

  const zhHant = <String, String>{
    'ACCOUNT': '帳戶',
    'Account': '帳戶',
    'Account settings': '帳戶設定',
    'Profile, security, data': '個人資料、安全性與資料',
    'Me': '我',
    'Welcome': '歡迎',
    'Sign in': '登入',
    'Sign in / register': '登入 / 註冊',
    'Continue as guest': '以訪客繼續',
    'Stay as guest': '繼續訪客模式',
    'Sign in or create an account': '登入或建立帳戶',
    'Create': '建立',
    'Create account': '建立帳戶',
    'Create your Chessnut ID': '建立你的 Chessnut ID',
    'Reset password': '重設密碼',
    'Sign in to Chessnut': '登入 Chessnut',
    'Email or account': '電子郵件或帳戶',
    'Password': '密碼',
    'Remember password': '記住密碼',
    'Forgot?': '忘記了？',
    'Signing in': '正在登入',
    'Use phone verification code': '使用手機驗證碼',
    'Phone number': '手機號碼',
    'SMS code': '簡訊驗證碼',
    'Sending': '正在傳送',
    'Send code': '傳送驗證碼',
    'Use email and password': '使用電子郵件和密碼',
    'Username': '使用者名稱',
    'Email': '電子郵件',
    'Creating account': '正在建立帳戶',
    '8+ characters': '8 個以上字元',
    'Choose any 2': '任選 2 類',
    'Uppercase': '大寫字母',
    'Lowercase': '小寫字母',
    'Number': '數字',
    'Symbol': '符號',
    'Reset email': '重設電子郵件',
    'Back to sign in': '返回登入',
    'Turnstile verification': 'Turnstile 真人驗證',
    'Human verified': '已通過真人驗證',
    'Verifying': '正在驗證',
    'Verify I am not a robot': '驗證我不是機器人',
    'I agree to': '我同意',
    'and': '和',
    'Terms of Use': '使用條款',
    'Privacy Policy': '隱私權政策',
    'Got it': '知道了',
    'Wallet': '錢包',
    'Tap to view details': '點擊查看詳情',
    'Daily points': '每日點數',
    'Account ledger': '帳戶明細',
    'Loading account wallet...': '正在載入帳戶錢包...',
    'Loading wallet ledger': '正在載入錢包明細',
    'Wallet unavailable.': '錢包不可用。',
    'Wallet cloud sync is temporarily unavailable. Daily points are saved on this device.':
        '錢包雲端同步暫不可用。每日積分已保存在本裝置。',
    'Sign in to sync points and profile.': '登入後同步點數和個人資料。',
    'Sign in to sync points, membership, and ledger.': '登入後同步點數、會員和明細。',
    'daily reward claimed today': '今日每日獎勵已領取',
    'daily reward available': '每日獎勵可領取',
    'points': '點',
    'pts': '點',
    'Upgrade membership': '升級會員',
    'No point activity yet.': '暫無點數記錄。',
    'Daily tasks': '每日任務',
    'Daily Tasks': '每日任務',
    'Earn points through real Chessnut workflows': '透過真實 Chessnut 使用流程獲得點數',
    'tasks completed today': '今日已完成任務',
    'Check in': '簽到',
    'Completed today': '今日已完成',
    'Done': '完成',
    'Go': '前往',
    'Claim': '領取',
    'Claimed': '已領取',
    'Claiming...': '正在領取...',
    'All daily tasks completed.': '每日任務已全部完成。',
    'Check-in ready': '可簽到',
    'Checked in today': '今日已簽到',
    'Sound effects': '音效',
    'Master switch for all app sounds': '控制 App 所有聲音的總開關',
    'From/to voice': '起止格語音',
    'Move sounds': '走棋音效',
    'Result sounds': '結果音效',
    'Key action sounds': '關鍵操作音效',
    'Clock Switch': '棋鐘開關',
    'Automatic switch press': '自動按鐘',
    'Off': '關閉',
    'Opponent move only': '僅對手走棋後自動',
    'Both sides': '雙方走棋後都自動',
    'Opponent move mode': '對手走棋模式',
    'Aggressive': '快速',
    'Leisure': '穩妥',
    'Aggressive mode': '快速模式',
    'Leisure mode': '穩妥模式',
    'Confirm moves with switch': '用開關確認走子',
    'Clock switch details': '棋鐘開關說明',
    'Stockfish strength from 600 to 3190.': 'Stockfish 棋力範圍為 600 到 3190。',
    'Edit profile': '編輯個人資料',
    'Cancel': '取消',
    'Saving': '正在儲存',
    'Save profile': '儲存個人資料',
    'Linked accounts': '已連結帳戶',
    'Linked': '已連結',
    'Not linked': '未連結',
    'Link': '連結',
    'Unlink': '取消連結',
    'Lichess authorized': 'Lichess 已授權',
    'Keep linked': '保持連結',
    'Unlink Lichess': '取消連結 Lichess',
    'Connected as': '目前連結為',
    'Game Record': '對局記錄',
    'Engine Lab': '引擎實驗室',
    'Practice': '練習',
    'Lessons & puzzles': '課程與謎題',
    'Interactive Courses': '互動課程',
    'Video lessons with board checkpoints': '帶棋盤檢查點的影片課程',
    'Watch': '觀看',
    'Video': '影片',
    'Pause': '暫停',
    'Checkpoint': '檢查點',
    'Board': '棋盤',
    'Lights': '燈光',
    'Open course library': '開啟課程庫',
    'Training modes': '訓練模式',
    '4 tools': '4 個工具',
    'Board analyzer': '棋盤分析器',
    'Live Stockfish board': '即時 Stockfish 棋盤',
    'Puzzle storm': '謎題風暴',
    'Fast pattern training': '快速棋形訓練',
    'Puzzle themes': '謎題主題',
    'Practice by motif': '按主題練習',
    'Mistake book': '錯題本',
    'From your games': '來自你的對局',
    'Practice flow': '練習流程',
    '15 min': '15 分鐘',
    'Warm up with tactics': '用戰術暖身',
    'Quick tactics': '快速戰術',
    'Review one weak spot': '複盤一個弱點',
    'Personal review': '個人複習',
    'Analyze freely': '自由分析',
    'Free analysis': '自由分析',
    'Train your chess style': '訓練你的棋風',
    'Train engines from your own games': '用你的對局訓練引擎',
    'Choose your games, let Chessnut train in the cloud, then play against your personal engine.':
        '選擇你的對局，讓 Chessnut 在雲端訓練，然後與你的個人引擎對弈。',
    'Personal engine training flow': '個人引擎訓練流程',
    'Choose your games': '選擇你的對局',
    'Use Game Record filters or paste a multi-game PGN batch.':
        '使用對局記錄篩選，或貼上包含多盤對局的 PGN。',
    'Train safely in the cloud': '在雲端安全訓練',
    'Chessnut trains with most games and keeps a smaller set to check quality.':
        'Chessnut 會使用大部分對局訓練，並保留少量對局檢查品質。',
    'Play your model': '試玩你的模型',
    'Finished engines appear in Bot game when they pass quality checks.':
        '通過品質檢查後，完成的引擎會出現在 Bot game 中。',
    'Premium unlimited': 'Premium 不限量',
    'Standard plan': '標準方案',
    'Engine report': '引擎報告',
    'Open report': '開啟報告',
    'Open': '開啟',
    'Building': '構建中',
    'Download': '下載',
    'Model Accuracy': '模型準確率',
    'Model Fitting Degree': '模型擬合度',
    'Data Effectiveness': '資料有效性',
    'PGN samples': 'PGN 範例',
    'Target': '目標',
    'Playable engine library': '可用引擎庫',
    'No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.':
        '還沒有可用的個人引擎。構建完成並可用於 Bot game 後會顯示在這裡。',
    'PGN sync': 'PGN 同步',
    'Models': '模型',
    'Authorizing...': '正在授權...',
    'Checking...': '正在檢查...',
    'Authorized': '已授權',
    'Authorize Lichess': '授權 Lichess',
    'Sign out?': '登出？',
    'Sign out': '登出',
    'Return to login': '返回登入',
    'Delete account': '刪除帳戶',
    'Password confirmation required': '需要確認密碼',
  };

  return switch (key) {
    'zh-Hans' => zhHans[text],
    'zh-Hant' => zhHant[text] ?? zhHans[text],
    _ => null,
  };
}

String? _translatePatterns(String text, String key) {
  final direct = _manualDirectTranslations(text, key);
  if (direct != null) return direct;
  final reviewAnalysis = _reviewAnalysisTranslations(text, key);
  if (reviewAnalysis != null) return reviewAnalysis;

  final botPositionAndSide = RegExp(
    r'^(.+) / (Random side|White side|Black side)$',
  ).firstMatch(text);
  if (botPositionAndSide != null) {
    final position = _translateBotGamePart(botPositionAndSide.group(1)!, key);
    final side = _translateBotGamePart(botPositionAndSide.group(2)!, key);
    if (position != null || side != null) {
      return '${position ?? botPositionAndSide.group(1)!} / '
          '${side ?? botPositionAndSide.group(2)!}';
    }
  }

  final botThinkingTime = RegExp(r'^(.+) / thinking (.+)$').firstMatch(text);
  if (botThinkingTime != null) {
    final source = _translateBotGamePart(botThinkingTime.group(1)!, key);
    final thinkingTime = _translateBotGamePart('Thinking time', key);
    if (source != null || thinkingTime != null) {
      return '${source ?? botThinkingTime.group(1)!} / '
          '${thinkingTime ?? 'thinking'} ${botThinkingTime.group(2)!}';
    }
  }

  final botEngineAndTime = RegExp(r'^(.+) / (Unlimited)$').firstMatch(text);
  if (botEngineAndTime != null) {
    final time = _translateBotGamePart(botEngineAndTime.group(2)!, key);
    if (time != null) return '${botEngineAndTime.group(1)!} / $time';
  }

  final targetLabel = RegExp(r'^Target (.+)$').firstMatch(text);
  if (targetLabel != null) {
    final target = targetLabel.group(1)!;
    return switch (key) {
      'zh-Hans' => '目标 $target',
      'zh-Hant' => '目標 $target',
      _ => null,
    };
  }

  final clockSwitchStatus =
      RegExp(r'^(Off|Opponent move only|Both sides) / (Aggressive|Leisure)$')
          .firstMatch(text);
  if (clockSwitchStatus != null) {
    final mode = _freshVisibleTranslations(clockSwitchStatus.group(1)!, key) ??
        generatedAppLocalizedMap(key)[clockSwitchStatus.group(1)!] ??
        clockSwitchStatus.group(1)!;
    final timing =
        _freshVisibleTranslations(clockSwitchStatus.group(2)!, key) ??
            generatedAppLocalizedMap(key)[clockSwitchStatus.group(2)!] ??
            clockSwitchStatus.group(2)!;
    return '$mode / $timing';
  }

  final completedTasks = RegExp(r'^(\d+)/(\d+) done$').firstMatch(text);
  if (completedTasks != null) {
    final completed = completedTasks.group(1)!;
    final total = completedTasks.group(2)!;
    return switch (key) {
      'zh-Hans' => '$completed/$total 已完成',
      'zh-Hant' => '$completed/$total 已完成',
      'de' => '$completed/$total erledigt',
      'es' => '$completed/$total completadas',
      'fr' => '$completed/$total terminées',
      'it' => '$completed/$total completate',
      'ja' => '$completed/$total 完了',
      'ko' => '$completed/$total 완료',
      'nl' => '$completed/$total klaar',
      'ru' => '$completed/$total выполнено',
      _ => null,
    };
  }

  final dailyCheckInPoints =
      RegExp(r'^Daily check-in \+(\d+) points$').firstMatch(text);
  if (dailyCheckInPoints != null) {
    final points = dailyCheckInPoints.group(1)!;
    return switch (key) {
      'zh-Hans' => '每日签到 +$points 积分',
      'zh-Hant' => '每日簽到 +$points 點',
      'de' => 'Täglicher Check-in +$points Punkte',
      'es' => 'Registro diario +$points puntos',
      'fr' => 'Check-in quotidien +$points points',
      'it' => 'Check-in giornaliero +$points punti',
      'ja' => 'デイリーチェックイン +$points ポイント',
      'ko' => '일일 출석 +$points 포인트',
      'nl' => 'Dagelijkse check-in +$points punten',
      'ru' => 'Ежедневная отметка +$points очков',
      _ => null,
    };
  }

  final careerChallengePoints =
      RegExp(r'^Career challenge complete \+(\d+) points$').firstMatch(text);
  if (careerChallengePoints != null) {
    final points = careerChallengePoints.group(1)!;
    return switch (key) {
      'zh-Hans' => '完成 Career 挑战 +$points 积分',
      'zh-Hant' => '完成 Career 挑戰 +$points 點',
      'de' => 'Career-Herausforderung abgeschlossen +$points Punkte',
      'es' => 'Desafio de Career completado +$points puntos',
      'fr' => 'Defi Career termine +$points points',
      'it' => 'Sfida Career completata +$points punti',
      'ja' => 'Career チャレンジ完了 +$points ポイント',
      'ko' => 'Career 도전 완료 +$points 포인트',
      'nl' => 'Career-uitdaging voltooid +$points punten',
      'ru' => 'Испытание Career завершено +$points очков',
      _ => null,
    };
  }

  final walletPoints = RegExp(r'^([+-]?\d+) points$').firstMatch(text);
  if (walletPoints != null) {
    final points = walletPoints.group(1)!;
    return switch (key) {
      'zh-Hans' => '$points 积分',
      'zh-Hant' => '$points 點',
      'de' => '$points Punkte',
      'es' => '$points puntos',
      'fr' => '$points points',
      'it' => '$points punti',
      'ja' => '$points ポイント',
      'ko' => '$points 포인트',
      'nl' => '$points punten',
      'ru' => '$points очков',
      _ => null,
    };
  }

  final guestSync = RegExp(r'^(.+) sync after you sign in\.$').firstMatch(text);
  if (guestSync != null) {
    final feature = _translatePatterns(guestSync.group(1)!, key) ??
        _freshVisibleTranslations(guestSync.group(1)!, key) ??
        generatedAppLocalizedMap(key)[guestSync.group(1)!] ??
        guestSync.group(1)!;
    return switch (key) {
      'zh-Hans' => '登录后同步$feature。',
      'zh-Hant' => '登入後同步$feature。',
      'de' => '$feature wird nach der Anmeldung synchronisiert.',
      'es' => '$feature se sincroniza después de iniciar sesión.',
      'fr' => '$feature se synchronise après la connexion.',
      'it' => '$feature si sincronizza dopo l’accesso.',
      'ja' => 'サインイン後に$featureを同期します。',
      'ko' => '로그인 후 $feature 동기화',
      'nl' => '$feature synchroniseert na inloggen.',
      'ru' => '$feature синхронизируется после входа.',
      _ => null,
    };
  }

  final selectedRecords = RegExp(r'^(\d+) selected$').firstMatch(text);
  if (selectedRecords != null) {
    final count = selectedRecords.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 条已选',
      'zh-Hant' => '已選 $count 筆',
      'de' => '$count ausgewählt',
      'es' => count == '1' ? '$count seleccionado' : '$count seleccionados',
      'fr' => count == '1' ? '$count sélectionné' : '$count sélectionnés',
      'it' => count == '1' ? '$count selezionato' : '$count selezionati',
      'ja' => '$count 件選択中',
      'ko' => '$count개 선택됨',
      'nl' => '$count geselecteerd',
      'ru' => 'Выбрано: $count',
      _ => null,
    };
  }

  final deleteRecords = RegExp(r'^Delete (\d+) records?$').firstMatch(text);
  if (deleteRecords != null) {
    final count = deleteRecords.group(1)!;
    return switch (key) {
      'zh-Hans' => '删除 $count 条记录',
      'zh-Hant' => '刪除 $count 筆記錄',
      'de' =>
        count == '1' ? '$count Eintrag löschen' : '$count Einträge löschen',
      'es' =>
        count == '1' ? 'Eliminar $count registro' : 'Eliminar $count registros',
      'fr' =>
        count == '1' ? 'Supprimer $count partie' : 'Supprimer $count parties',
      'it' => 'Elimina $count record',
      'ja' => '$count 件の記録を削除',
      'ko' => '기록 $count개 삭제',
      'nl' => count == '1'
          ? '$count record verwijderen'
          : '$count records verwijderen',
      'ru' => count == '1' ? 'Удалить $count запись' : 'Удалить $count записи',
      _ => null,
    };
  }

  final deletedRecords =
      RegExp(r'^(\d+) game records deleted\.$').firstMatch(text);
  if (deletedRecords != null) {
    final count = deletedRecords.group(1)!;
    return switch (key) {
      'zh-Hans' => '已删除 $count 条 Game Record。',
      'zh-Hant' => '已刪除 $count 筆 Game Record。',
      'de' => count == '1'
          ? '$count Game Record gelöscht.'
          : '$count Game Records gelöscht.',
      'es' => count == '1'
          ? '$count Game Record eliminado.'
          : '$count Game Records eliminados.',
      'fr' => count == '1'
          ? '$count Game Record supprimé.'
          : '$count Game Records supprimés.',
      'it' => count == '1'
          ? '$count Game Record eliminato.'
          : '$count Game Records eliminati.',
      'ja' => '$count 件の Game Record を削除しました。',
      'ko' => 'Game Record $count개가 삭제되었습니다.',
      'nl' => count == '1'
          ? '$count Game Record verwijderd.'
          : '$count Game Records verwijderd.',
      'ru' => count == '1'
          ? 'Удалена $count Game Record.'
          : 'Удалены $count Game Records.',
      _ => null,
    };
  }

  if (text ==
      'Practice with curated positions from the public Lichess puzzle set. Each run mixes themes and difficulty so the next tactic stays fresh.') {
    return switch (key) {
      'zh-Hans' => '使用来自 Lichess 公开题库的精选局面练习。每次风暴都会混合不同主题和难度，让下一道战术保持新鲜感。',
      'zh-Hant' => '使用來自 Lichess 公開題庫的精選局面練習。每次風暴都會混合不同主題與難度，讓下一道戰術保持新鮮感。',
      'de' =>
        'Trainiere mit kuratierten Stellungen aus dem öffentlichen Lichess-Aufgabensatz. Jeder Durchlauf mischt Themen und Schwierigkeit, damit die nächste Taktik frisch bleibt.',
      'es' =>
        'Practica con posiciones seleccionadas del conjunto público de problemas de Lichess. Cada ronda mezcla temas y dificultad para que la siguiente táctica siga siendo fresca.',
      'fr' =>
        'Entraînez-vous avec des positions sélectionnées dans la base publique de puzzles Lichess. Chaque run mélange thèmes et difficulté pour garder la tactique suivante stimulante.',
      'it' =>
        'Allenati con posizioni selezionate dal set pubblico di puzzle Lichess. Ogni run mescola temi e difficoltà, così la tattica successiva resta sempre nuova.',
      'ja' => 'Lichess の公開パズルセットから選んだ局面で練習します。各ランではテーマと難易度を組み合わせ、次の戦術を新鮮に保ちます。',
      'ko' =>
        'Lichess 공개 퍼즐 세트에서 선별한 포지션으로 연습합니다. 매 실행마다 테마와 난이도를 섞어 다음 전술을 새롭게 유지합니다.',
      'nl' =>
        'Oefen met geselecteerde stellingen uit de openbare Lichess-puzzelset. Elke run mengt thema’s en moeilijkheid, zodat de volgende tactiek fris blijft.',
      'ru' =>
        'Тренируйтесь на отобранных позициях из публичного набора задач Lichess. Каждый запуск смешивает темы и сложность, чтобы следующая тактика оставалась свежей.',
      _ => null,
    };
  }

  final modelConnected = RegExp(r'^(Chessnut .+) connected$').firstMatch(text);
  if (modelConnected != null) {
    final model = modelConnected.group(1)!;
    return switch (key) {
      'zh-Hans' => '$model 已连接',
      'zh-Hant' => '$model 已連線',
      'de' => '$model verbunden',
      'es' => '$model conectado',
      'fr' => '$model connecté',
      'it' => '$model connesso',
      'ja' => '$model 接続済み',
      'ko' => '$model 연결됨',
      'nl' => '$model verbonden',
      'ru' => '$model подключена',
      _ => null,
    };
  }

  final unreadMessages = RegExp(r'^(\d+) unread messages$').firstMatch(text);
  if (unreadMessages != null) {
    final count = unreadMessages.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 条未读消息',
      'zh-Hant' => '$count 則未讀訊息',
      'de' => '$count ungelesene Nachrichten',
      'es' => '$count mensajes no leídos',
      'fr' => '$count messages non lus',
      'it' => '$count messaggi non letti',
      'ja' => '$count 件の未読メッセージ',
      'ko' => '읽지 않은 메시지 $count개',
      'nl' => '$count ongelezen berichten',
      'ru' => '$count непрочитанных сообщений',
      _ => null,
    };
  }

  final singleUnreadMessage = RegExp(r'^1 unread message$').firstMatch(text);
  if (singleUnreadMessage != null) {
    return switch (key) {
      'zh-Hans' => '1 条未读消息',
      'zh-Hant' => '1 則未讀訊息',
      'de' => '1 ungelesene Nachricht',
      'es' => '1 mensaje no leído',
      'fr' => '1 message non lu',
      'it' => '1 messaggio non letto',
      'ja' => '未読メッセージ 1 件',
      'ko' => '읽지 않은 메시지 1개',
      'nl' => '1 ongelezen bericht',
      'ru' => '1 непрочитанное сообщение',
      _ => null,
    };
  }

  final games = RegExp(r'^Build from (\d+) games$').firstMatch(text);
  if (games != null) {
    final count = games.group(1)!;
    return switch (key) {
      'zh-Hans' => '从 $count 盘对局构建',
      'zh-Hant' => '從 $count 盤對局建立',
      'de' => 'Aus $count Partien erstellen',
      'es' => 'Crear con $count partidas',
      'fr' => 'Créer avec $count parties',
      'it' => 'Crea da $count partite',
      'ja' => '$count 局から構築',
      'ko' => '$count 대국으로 빌드',
      'nl' => 'Bouwen uit $count partijen',
      'ru' => 'Создать из $count партий',
      _ => null,
    };
  }

  final visible = RegExp(r'^Select visible \((\d+)\)$').firstMatch(text);
  if (visible != null) {
    final count = visible.group(1)!;
    return switch (key) {
      'zh-Hans' => '选择可见项 ($count)',
      'zh-Hant' => '選擇可見項目 ($count)',
      'de' => 'Sichtbare auswählen ($count)',
      'es' => 'Seleccionar visibles ($count)',
      'fr' => 'Sélectionner les éléments visibles ($count)',
      'it' => 'Seleziona visibili ($count)',
      'ja' => '表示中を選択 ($count)',
      'ko' => '표시 항목 선택 ($count)',
      'nl' => 'Zichtbare kiezen ($count)',
      'ru' => 'Выбрать видимые ($count)',
      _ => null,
    };
  }

  final continueWith = RegExp(r'^Continue with (.+)$').firstMatch(text);
  if (continueWith != null) {
    final provider = continueWith.group(1)!;
    return switch (key) {
      'zh-Hans' => '使用 $provider 继续',
      'zh-Hant' => '使用 $provider 繼續',
      'de' => 'Mit $provider fortfahren',
      'es' => 'Continuar con $provider',
      'fr' => 'Continuer avec $provider',
      'it' => 'Continua con $provider',
      'ja' => '$provider で続行',
      'ko' => '$provider로 계속',
      'nl' => 'Doorgaan met $provider',
      'ru' => 'Продолжить с $provider',
      _ => null,
    };
  }

  final openings = RegExp(r'^(\d+) openings$').firstMatch(text);
  if (openings != null) {
    final count = openings.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 个开局',
      'zh-Hant' => '$count 個開局',
      'de' => '$count Eröffnungen',
      'es' => '$count aperturas',
      'fr' => '$count ouvertures',
      'it' => '$count aperture',
      'ja' => '$count 件のオープニング',
      'ko' => '$count개 오프닝',
      'nl' => '$count openingen',
      'ru' => '$count дебютов',
      _ => null,
    };
  }

  final plies = RegExp(r'^(\d+) plies$').firstMatch(text);
  if (plies != null) {
    final count = plies.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 个半回合',
      'zh-Hant' => '$count 個半回合',
      'de' => '$count Halbzüge',
      'es' => '$count medias jugadas',
      'fr' => '$count demi-coups',
      'it' => '$count semimosse',
      'ja' => '$count プライ',
      'ko' => '$count 플라이',
      'nl' => '$count halve zetten',
      'ru' => '$count полуходов',
      _ => null,
    };
  }

  final detectedGames = RegExp(r'^Detected (\d+) games$').firstMatch(text);
  if (detectedGames != null) {
    final count = detectedGames.group(1)!;
    return switch (key) {
      'zh-Hans' => '识别到 $count 盘对局',
      'zh-Hant' => '辨識到 $count 盤對局',
      'de' => '$count Partien erkannt',
      'es' => '$count partidas detectadas',
      'fr' => '$count parties détectées',
      'it' => '$count partite rilevate',
      'ja' => '$count 局を検出',
      'ko' => '$count 대국 감지됨',
      'nl' => '$count partijen herkend',
      'ru' => 'Обнаружено партий: $count',
      _ => null,
    };
  }

  final foundGames = RegExp(r'^Found (\d+) games$').firstMatch(text);
  if (foundGames != null) {
    final count = foundGames.group(1)!;
    return switch (key) {
      'zh-Hans' => '找到 $count 盘对局',
      'zh-Hant' => '找到 $count 盤對局',
      'de' => '$count Partien gefunden',
      'es' => '$count partidas encontradas',
      'fr' => '$count parties trouvées',
      'it' => '$count partite trovate',
      'ja' => '$count 局が見つかりました',
      'ko' => '$count 대국 찾음',
      'nl' => '$count partijen gevonden',
      'ru' => 'Найдено партий: $count',
      _ => null,
    };
  }

  final moments = RegExp(r'^(\d+) moments$').firstMatch(text);
  if (moments != null) {
    final count = moments.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 个关键时刻',
      'zh-Hant' => '$count 個關鍵時刻',
      'de' => '$count Schlüsselmomente',
      'es' => '$count momentos clave',
      'fr' => '$count moments clés',
      'it' => '$count momenti chiave',
      'ja' => '$count 件の重要局面',
      'ko' => '$count개 핵심 순간',
      'nl' => '$count sleutelmomenten',
      'ru' => '$count ключевых моментов',
      _ => null,
    };
  }

  final lessonsWithCheckpoints =
      RegExp(r'^(\d+) lessons with board checkpoints$').firstMatch(text);
  if (lessonsWithCheckpoints != null) {
    final count = lessonsWithCheckpoints.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 节含棋盘检查点的课程',
      'zh-Hant' => '$count 堂含棋盤檢查點的課程',
      'de' => '$count Lektionen mit Brett-Checkpoints',
      'es' => '$count lecciones con puntos de control del tablero',
      'fr' => '$count leçons avec points de contrôle sur l’échiquier',
      'it' => '$count lezioni con checkpoint sulla scacchiera',
      'ja' => 'ボードチェックポイント付き $count レッスン',
      'ko' => '보드 체크포인트가 있는 $count개 레슨',
      'nl' => '$count lessen met bordcheckpoints',
      'ru' => '$count уроков с контрольными точками на доске',
      _ => null,
    };
  }

  final legacyModelBuildFromPersonalEngine =
      RegExp(r'^Model Build from (\d+) games$').firstMatch(text);
  if (legacyModelBuildFromPersonalEngine != null) {
    final count = legacyModelBuildFromPersonalEngine.group(1)!;
    return switch (key) {
      'zh-Hans' => '用 $count 盘对局训练个人引擎',
      'zh-Hant' => '用 $count 盤對局訓練個人引擎',
      'de' => 'Persönliche Engine mit $count Partien trainieren',
      'es' => 'Entrenar un motor personal con $count partidas',
      'fr' => 'Entraîner un moteur personnel avec $count parties',
      'it' => 'Allena un motore personale con $count partite',
      'ja' => '$count 局で個人エンジンをトレーニング',
      'ko' => '$count개 대국으로 개인 엔진 훈련',
      'nl' => 'Persoonlijke engine trainen met $count partijen',
      'ru' => 'Обучить личный движок на $count партиях',
      _ => null,
    };
  }

  final personalTrainingReady = RegExp(
    r'^(\d+) games are ready for personal engine training\.$',
  ).firstMatch(text);
  if (personalTrainingReady != null) {
    final count = personalTrainingReady.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 盘对局已可用于训练个人引擎。',
      'zh-Hant' => '$count 盤對局已可用於訓練個人引擎。',
      'de' =>
        '$count Partien sind bereit für das Training deiner persönlichen Engine.',
      'es' => '$count partidas están listas para entrenar tu motor personal.',
      'fr' =>
        '$count parties sont prêtes pour entraîner votre moteur personnel.',
      'it' =>
        '$count partite sono pronte per allenare il tuo motore personale.',
      'ja' => '$count 局を個人エンジンのトレーニングに使えます。',
      'ko' => '$count개 대국을 개인 엔진 훈련에 사용할 수 있습니다.',
      'nl' =>
        '$count partijen zijn klaar voor training van je persoonlijke engine.',
      'ru' => '$count партий готовы для обучения личного движка.',
      _ => null,
    };
  }

  final modelBuildFrom =
      RegExp(r'^Model Build from (\d+) games$').firstMatch(text);
  if (modelBuildFrom != null) {
    final count = modelBuildFrom.group(1)!;
    return switch (key) {
      'zh-Hans' => '从 $count 盘对局构建模型',
      'zh-Hant' => '從 $count 盤對局建立模型',
      'de' => 'Modell aus $count Partien erstellen',
      'es' => 'Crear modelo con $count partidas',
      'fr' => 'Créer un modèle avec $count parties',
      'it' => 'Crea modello da $count partite',
      'ja' => '$count 局からモデルを構築',
      'ko' => '$count 대국으로 모델 빌드',
      'nl' => 'Model bouwen uit $count partijen',
      'ru' => 'Сборка модели из $count партий',
      _ => null,
    };
  }

  final cloudRecordPage = RegExp(
    r'^Page (\d+) of (\d+)\. Analysis filters use reports already saved on this device\.$',
  ).firstMatch(text);
  if (cloudRecordPage != null) {
    final page = cloudRecordPage.group(1)!;
    final total = cloudRecordPage.group(2)!;
    return switch (key) {
      'zh-Hans' => '第 $page 页，共 $total 页。分析筛选会使用已保存在此设备上的报告。',
      'zh-Hant' => '第 $page 頁，共 $total 頁。分析篩選會使用已儲存在此裝置上的報告。',
      'de' =>
        'Seite $page von $total. Analysefilter nutzen Berichte, die auf diesem Gerät gespeichert sind.',
      'es' =>
        'Página $page de $total. Los filtros de análisis usan informes guardados en este dispositivo.',
      'fr' =>
        'Page $page sur $total. Les filtres d’analyse utilisent les rapports enregistrés sur cet appareil.',
      'it' =>
        'Pagina $page di $total. I filtri di analisi usano i report salvati su questo dispositivo.',
      'ja' => '$total ページ中 $page ページ。分析フィルターはこの端末に保存済みのレポートを使います。',
      'ko' => '$total페이지 중 $page페이지. 분석 필터는 이 기기에 저장된 보고서를 사용합니다.',
      'nl' =>
        'Pagina $page van $total. Analysefilters gebruiken rapporten die op dit apparaat zijn opgeslagen.',
      'ru' =>
        'Страница $page из $total. Фильтры анализа используют отчёты, сохранённые на этом устройстве.',
      _ => null,
    };
  }

  final modelBuildMinimum = RegExp(
    r'^Use at least (\d+) usable PGN games\. Loosen filters or import more games before starting a build\.$',
  ).firstMatch(text);
  if (modelBuildMinimum != null) {
    final count = modelBuildMinimum.group(1)!;
    return switch (key) {
      'zh-Hans' => '至少需要 $count 盘可用 PGN 对局。请放宽筛选条件，或先导入更多对局再开始构建。',
      'zh-Hant' => '至少需要 $count 盤可用 PGN 對局。請放寬篩選條件，或先匯入更多對局再開始建立。',
      'de' =>
        'Nutze mindestens $count verwendbare PGN-Partien. Lockere die Filter oder importiere mehr Partien, bevor du den Build startest.',
      'es' =>
        'Usa al menos $count partidas PGN utilizables. Relaja los filtros o importa más partidas antes de iniciar el build.',
      'fr' =>
        'Utilisez au moins $count parties PGN exploitables. Assouplissez les filtres ou importez plus de parties avant de lancer le build.',
      'it' =>
        'Usa almeno $count partite PGN utilizzabili. Allarga i filtri o importa più partite prima di avviare il build.',
      'ja' =>
        '使用可能な PGN 対局が少なくとも $count 局必要です。ビルド開始前にフィルターを緩めるか、対局を追加でインポートしてください。',
      'ko' =>
        '사용 가능한 PGN 대국이 최소 $count개 필요합니다. 빌드를 시작하기 전에 필터를 완화하거나 대국을 더 가져오세요.',
      'nl' =>
        'Gebruik minstens $count bruikbare PGN-partijen. Maak filters ruimer of importeer meer partijen voordat je de build start.',
      'ru' =>
        'Нужно минимум $count пригодных PGN-партий. Ослабьте фильтры или импортируйте больше партий перед запуском сборки.',
      _ => null,
    };
  }

  final legacyModelBuildStartedPersonalEngine =
      RegExp(r'^Model Build started from (\d+) games\.$').firstMatch(text);
  if (legacyModelBuildStartedPersonalEngine != null) {
    final count = legacyModelBuildStartedPersonalEngine.group(1)!;
    return switch (key) {
      'zh-Hans' => '已用 $count 盘对局开始训练个人引擎。',
      'zh-Hant' => '已用 $count 盤對局開始訓練個人引擎。',
      'de' => 'Persönliches Engine-Training mit $count Partien gestartet.',
      'es' => 'Entrenamiento de motor personal iniciado con $count partidas.',
      'fr' => 'Entraînement du moteur personnel lancé avec $count parties.',
      'it' => 'Allenamento del motore personale avviato con $count partite.',
      'ja' => '$count 局で個人エンジンのトレーニングを開始しました。',
      'ko' => '$count개 대국으로 개인 엔진 훈련을 시작했습니다.',
      'nl' => 'Training van persoonlijke engine gestart met $count partijen.',
      'ru' => 'Обучение личного движка начато на $count партиях.',
      _ => null,
    };
  }

  final personalTrainingStarted = RegExp(
    r'^Personal engine training started from (\d+) games\.$',
  ).firstMatch(text);
  if (personalTrainingStarted != null) {
    final count = personalTrainingStarted.group(1)!;
    return switch (key) {
      'zh-Hans' => '已用 $count 盘对局开始训练个人引擎。',
      'zh-Hant' => '已用 $count 盤對局開始訓練個人引擎。',
      'de' => 'Persönliches Engine-Training mit $count Partien gestartet.',
      'es' => 'Entrenamiento de motor personal iniciado con $count partidas.',
      'fr' => 'Entraînement du moteur personnel lancé avec $count parties.',
      'it' => 'Allenamento del motore personale avviato con $count partite.',
      'ja' => '$count 局で個人エンジンのトレーニングを開始しました。',
      'ko' => '$count개 대국으로 개인 엔진 훈련을 시작했습니다.',
      'nl' => 'Training van persoonlijke engine gestart met $count partijen.',
      'ru' => 'Обучение личного движка начато на $count партиях.',
      _ => null,
    };
  }

  final modelBuildTitle =
      RegExp(r'^Model Build started from (\d+) games\.$').firstMatch(text);
  if (modelBuildTitle != null) {
    final count = modelBuildTitle.group(1)!;
    return switch (key) {
      'zh-Hans' => '已用 $count 盘对局开始 Model Build。',
      'zh-Hant' => '已用 $count 盤對局開始 Model Build。',
      'de' => 'Model Build mit $count Partien gestartet.',
      'es' => 'Model Build iniciado con $count partidas.',
      'fr' => 'Model Build lancé avec $count parties.',
      'it' => 'Model Build avviato con $count partite.',
      'ja' => '$count 局で Model Build を開始しました。',
      'ko' => '$count개 대국으로 Model Build를 시작했습니다.',
      'nl' => 'Model Build gestart met $count partijen.',
      'ru' => 'Model Build запущен по $count партиям.',
      _ => null,
    };
  }

  final legacyModelBuildSelectionPersonalEngine = RegExp(
    r'^Select at least (\d+) PGN games for a Model Build\. (\d+)\+ games is recommended\.$',
  ).firstMatch(text);
  if (legacyModelBuildSelectionPersonalEngine != null) {
    final minimum = legacyModelBuildSelectionPersonalEngine.group(1)!;
    final recommended = legacyModelBuildSelectionPersonalEngine.group(2)!;
    return switch (key) {
      'zh-Hans' => '请至少选择 $minimum 盘 PGN 对局来训练个人引擎。建议使用 $recommended 盘以上。',
      'zh-Hant' => '請至少選擇 $minimum 盤 PGN 對局來訓練個人引擎。建議使用 $recommended 盤以上。',
      'de' =>
        'Wähle mindestens $minimum PGN-Partien für persönliches Engine-Training. $recommended+ Partien werden empfohlen.',
      'es' =>
        'Selecciona al menos $minimum partidas PGN para entrenar un motor personal. Se recomiendan $recommended o más.',
      'fr' =>
        'Sélectionnez au moins $minimum parties PGN pour entraîner un moteur personnel. $recommended parties ou plus sont recommandées.',
      'it' =>
        'Seleziona almeno $minimum partite PGN per allenare un motore personale. Sono consigliate $recommended o più partite.',
      'ja' =>
        '個人エンジンをトレーニングするには、少なくとも $minimum 局の PGN 対局を選んでください。$recommended 局以上をおすすめします。',
      'ko' =>
        '개인 엔진을 훈련하려면 PGN 대국을 최소 $minimum개 선택하세요. $recommended개 이상을 권장합니다.',
      'nl' =>
        'Selecteer minstens $minimum PGN-partijen om een persoonlijke engine te trainen. $recommended+ partijen wordt aanbevolen.',
      'ru' =>
        'Выберите минимум $minimum PGN-партий для обучения личного движка. Рекомендуется $recommended или больше.',
      _ => null,
    };
  }

  final modelBuildSelection = RegExp(
    r'^Select at least (\d+) PGN games for a Model Build\. (\d+)\+ games is recommended\.$',
  ).firstMatch(text);
  if (modelBuildSelection != null) {
    final minimum = modelBuildSelection.group(1)!;
    final recommended = modelBuildSelection.group(2)!;
    return switch (key) {
      'zh-Hans' =>
        '请至少选择 $minimum 盘 PGN 对局来进行 Model Build。建议使用 $recommended 盘以上。',
      'zh-Hant' =>
        '請至少選擇 $minimum 盤 PGN 對局來進行 Model Build。建議使用 $recommended 盤以上。',
      'de' =>
        'Wähle mindestens $minimum PGN-Partien für einen Model Build. $recommended+ Partien werden empfohlen.',
      'es' =>
        'Selecciona al menos $minimum partidas PGN para un Model Build. Se recomiendan $recommended o más.',
      'fr' =>
        'Sélectionnez au moins $minimum parties PGN pour un Model Build. $recommended parties ou plus sont recommandées.',
      'it' =>
        'Seleziona almeno $minimum partite PGN per un Model Build. Sono consigliate $recommended o più partite.',
      'ja' =>
        'Model Build には少なくとも $minimum 局の PGN 対局を選んでください。$recommended 局以上をおすすめします。',
      'ko' =>
        'Model Build에는 PGN 대국을 최소 $minimum개 선택하세요. $recommended개 이상을 권장합니다.',
      'nl' =>
        'Selecteer minstens $minimum PGN-partijen voor een Model Build. $recommended+ partijen wordt aanbevolen.',
      'ru' =>
        'Выберите минимум $minimum PGN-партий для Model Build. Рекомендуется $recommended или больше.',
      _ => null,
    };
  }

  final legacyModelBuildNameMinimumPersonalEngine = RegExp(
    r'^Add a model name and at least (\d+) PGN games before starting the build\.$',
  ).firstMatch(text);
  if (legacyModelBuildNameMinimumPersonalEngine != null) {
    final count = legacyModelBuildNameMinimumPersonalEngine.group(1)!;
    return switch (key) {
      'zh-Hans' => '请填写引擎名称，并至少添加 $count 盘 PGN 对局后再开始训练。',
      'zh-Hant' => '請填寫引擎名稱，並至少加入 $count 盤 PGN 對局後再開始訓練。',
      'de' =>
        'Gib einen Engine-Namen ein und füge mindestens $count PGN-Partien hinzu, bevor du das Training startest.',
      'es' =>
        'Añade un nombre de motor y al menos $count partidas PGN antes de iniciar el entrenamiento.',
      'fr' =>
        'Ajoutez un nom de moteur et au moins $count parties PGN avant de lancer l’entraînement.',
      'it' =>
        'Aggiungi un nome motore e almeno $count partite PGN prima di avviare l’allenamento.',
      'ja' => 'トレーニングを始める前に、エンジン名を入力し、少なくとも $count 局の PGN 対局を追加してください。',
      'ko' => '훈련을 시작하기 전에 엔진 이름과 PGN 대국 최소 $count개를 추가하세요.',
      'nl' =>
        'Voeg een enginenaam en minstens $count PGN-partijen toe voordat je de training start.',
      'ru' =>
        'Добавьте название движка и минимум $count PGN-партий перед началом обучения.',
      _ => null,
    };
  }

  final personalEngineNameMinimum = RegExp(
    r'^Add an engine name and at least (\d+) PGN games before starting training\.$',
  ).firstMatch(text);
  if (personalEngineNameMinimum != null) {
    final count = personalEngineNameMinimum.group(1)!;
    return switch (key) {
      'zh-Hans' => '请填写引擎名称，并至少添加 $count 盘 PGN 对局后再开始训练。',
      'zh-Hant' => '請填寫引擎名稱，並至少加入 $count 盤 PGN 對局後再開始訓練。',
      'de' =>
        'Gib einen Engine-Namen ein und füge mindestens $count PGN-Partien hinzu, bevor du das Training startest.',
      'es' =>
        'Añade un nombre de motor y al menos $count partidas PGN antes de iniciar el entrenamiento.',
      'fr' =>
        'Ajoutez un nom de moteur et au moins $count parties PGN avant de lancer l’entraînement.',
      'it' =>
        'Aggiungi un nome motore e almeno $count partite PGN prima di avviare l’allenamento.',
      'ja' => 'トレーニングを始める前に、エンジン名を入力し、少なくとも $count 局の PGN 対局を追加してください。',
      'ko' => '훈련을 시작하기 전에 엔진 이름과 PGN 대국 최소 $count개를 추가하세요.',
      'nl' =>
        'Voeg een enginenaam en minstens $count PGN-partijen toe voordat je de training start.',
      'ru' =>
        'Добавьте название движка и минимум $count PGN-партий перед началом обучения.',
      _ => null,
    };
  }

  final modelBuildNameMinimum = RegExp(
    r'^Add a model name and at least (\d+) PGN games before starting the build\.$',
  ).firstMatch(text);
  if (modelBuildNameMinimum != null) {
    final count = modelBuildNameMinimum.group(1)!;
    return switch (key) {
      'zh-Hans' => '请填写模型名称，并至少添加 $count 盘 PGN 对局后再开始构建。',
      'zh-Hant' => '請填寫模型名稱，並至少加入 $count 盤 PGN 對局後再開始建立。',
      'de' =>
        'Gib einen Modellnamen ein und füge mindestens $count PGN-Partien hinzu, bevor du den Build startest.',
      'es' =>
        'Añade un nombre de modelo y al menos $count partidas PGN antes de iniciar el build.',
      'fr' =>
        'Ajoutez un nom de modèle et au moins $count parties PGN avant de lancer le build.',
      'it' =>
        'Aggiungi un nome modello e almeno $count partite PGN prima di avviare il build.',
      'ja' => 'ビルド開始前にモデル名を入力し、少なくとも $count 局の PGN 対局を追加してください。',
      'ko' => '빌드를 시작하기 전에 모델 이름과 PGN 대국 최소 $count개를 추가하세요.',
      'nl' =>
        'Voeg een modelnaam en minstens $count PGN-partijen toe voordat je de build start.',
      'ru' =>
        'Добавьте имя модели и минимум $count PGN-партий перед запуском сборки.',
      _ => null,
    };
  }

  final providerSignIn = RegExp(
    r'^Chessnut could not complete (.+) sign in\. Try again or use email sign in\.$',
  ).firstMatch(text);
  if (providerSignIn != null) {
    final provider = providerSignIn.group(1)!;
    return switch (key) {
      'zh-Hans' => 'Chessnut 无法完成 $provider 登录。请重试，或使用邮箱登录。',
      'zh-Hant' => 'Chessnut 無法完成 $provider 登入。請重試，或使用信箱登入。',
      'de' =>
        'Chessnut konnte die Anmeldung mit $provider nicht abschließen. Versuche es erneut oder melde dich per E-Mail an.',
      'es' =>
        'Chessnut no pudo completar el inicio de sesión con $provider. Inténtalo de nuevo o usa el correo electrónico.',
      'fr' =>
        'Chessnut n’a pas pu terminer la connexion avec $provider. Réessayez ou utilisez la connexion par e-mail.',
      'it' =>
        'Chessnut non ha completato l’accesso con $provider. Riprova o usa l’accesso via email.',
      'ja' => 'Chessnut は $provider でのサインインを完了できませんでした。再試行するか、メールでサインインしてください。',
      'ko' => 'Chessnut이 $provider 로그인을 완료하지 못했습니다. 다시 시도하거나 이메일 로그인을 사용하세요.',
      'nl' =>
        'Chessnut kon aanmelden met $provider niet voltooien. Probeer opnieuw of meld je aan met e-mail.',
      'ru' =>
        'Chessnut не удалось завершить вход через $provider. Повторите попытку или войдите по e-mail.',
      _ => null,
    };
  }

  final lichessReady = RegExp(
    r'^Lichess is authorized\. Find (.+) game and Chessnut will sync moves to your board\.$',
  ).firstMatch(text);
  if (lichessReady != null) {
    final time = lichessReady.group(1)!;
    return switch (key) {
      'zh-Hans' => 'Lichess 已授权。匹配到 $time 对局后，Chessnut 会把走法同步到你的棋盘。',
      'zh-Hant' => 'Lichess 已授權。配對到 $time 對局後，Chessnut 會把著法同步到你的棋盤。',
      'de' =>
        'Lichess ist autorisiert. Suche eine $time-Partie; Chessnut synchronisiert die Züge mit deinem Brett.',
      'es' =>
        'Lichess está autorizado. Busca una partida $time y Chessnut sincronizará las jugadas con tu tablero.',
      'fr' =>
        'Lichess est autorisé. Lancez une partie $time et Chessnut synchronisera les coups avec votre échiquier.',
      'it' =>
        'Lichess è autorizzato. Cerca una partita $time e Chessnut sincronizzerà le mosse con la scacchiera.',
      'ja' => 'Lichess は認証済みです。$time の対局を探すと、Chessnut が指し手をボードに同期します。',
      'ko' => 'Lichess 인증이 완료되었습니다. $time 대국을 찾으면 Chessnut이 수를 보드에 동기화합니다.',
      'nl' =>
        'Lichess is gemachtigd. Zoek een $time-partij; Chessnut synchroniseert de zetten met je bord.',
      'ru' =>
        'Lichess авторизован. Найдите партию $time, и Chessnut синхронизирует ходы с доской.',
      _ => null,
    };
  }

  final lichessMatched = RegExp(
    r'^Lichess is authorized\. Once a (.+) game is matched, Chessnut will sync moves to your board\.$',
  ).firstMatch(text);
  if (lichessMatched != null) {
    final time = lichessMatched.group(1)!;
    return switch (key) {
      'zh-Hans' => 'Lichess 已授权。匹配到 $time 对局后，Chessnut 会把走法同步到你的棋盘。',
      'zh-Hant' => 'Lichess 已授權。配對到 $time 對局後，Chessnut 會把著法同步到你的棋盤。',
      'de' =>
        'Lichess ist autorisiert. Sobald eine $time-Partie gefunden wurde, synchronisiert Chessnut die Züge mit deinem Brett.',
      'es' =>
        'Lichess está autorizado. Cuando se empareje una partida $time, Chessnut sincronizará las jugadas con tu tablero.',
      'fr' =>
        'Lichess est autorisé. Quand une partie $time est trouvée, Chessnut synchronise les coups avec votre échiquier.',
      'it' =>
        'Lichess è autorizzato. Quando viene abbinata una partita $time, Chessnut sincronizza le mosse con la scacchiera.',
      'ja' => 'Lichess は認証済みです。$time の対局がマッチすると、Chessnut が指し手をボードに同期します。',
      'ko' => 'Lichess 인증이 완료되었습니다. $time 대국이 매칭되면 Chessnut이 수를 보드에 동기화합니다.',
      'nl' =>
        'Lichess is gemachtigd. Zodra een $time-partij is gevonden, synchroniseert Chessnut de zetten met je bord.',
      'ru' =>
        'Lichess авторизован. Когда партия $time будет найдена, Chessnut синхронизирует ходы с доской.',
      _ => null,
    };
  }

  final onlineSearch = RegExp(r'^Online search: (.+)$').firstMatch(text);
  if (onlineSearch != null) {
    final time = onlineSearch.group(1)!;
    return switch (key) {
      'zh-Hans' => '线上搜索：$time',
      'zh-Hant' => '線上搜尋：$time',
      'de' => 'Online-Suche: $time',
      'es' => 'Búsqueda en línea: $time',
      'fr' => 'Recherche en ligne : $time',
      'it' => 'Ricerca online: $time',
      'ja' => 'オンライン検索：$time',
      'ko' => '온라인 검색: $time',
      'nl' => 'Online zoeken: $time',
      'ru' => 'Онлайн-поиск: $time',
      _ => null,
    };
  }

  final findLichessGame = RegExp(r'^Find (.+) game$').firstMatch(text);
  if (findLichessGame != null) {
    final time = findLichessGame.group(1)!;
    return switch (key) {
      'zh-Hans' => '寻找 $time 对局',
      'zh-Hant' => '尋找 $time 對局',
      'de' => '$time-Partie suchen',
      'es' => 'Buscar partida $time',
      'fr' => 'Trouver une partie $time',
      'it' => 'Cerca partita $time',
      'ja' => '$time の対局を探す',
      'ko' => '$time 대국 찾기',
      'nl' => '$time-partij zoeken',
      'ru' => 'Найти партию $time',
      _ => null,
    };
  }

  final signedInLichess = RegExp(
    r'^Signed in as (.+)\. Ready to play on Lichess\.$',
  ).firstMatch(text);
  if (signedInLichess != null) {
    final name = signedInLichess.group(1)!;
    return switch (key) {
      'zh-Hans' => '已以 $name 登录。可以在 Lichess 上开始对局。',
      'zh-Hant' => '已以 $name 登入。可以在 Lichess 上開始對局。',
      'de' => 'Angemeldet als $name. Bereit für Lichess-Partien.',
      'es' => 'Sesión iniciada como $name. Listo para jugar en Lichess.',
      'fr' => 'Connecté en tant que $name. Prêt à jouer sur Lichess.',
      'it' => 'Accesso effettuato come $name. Pronto per giocare su Lichess.',
      'ja' => '$name としてサインイン済みです。Lichess で対局できます。',
      'ko' => '$name으로 로그인했습니다. Lichess에서 플레이할 준비가 되었습니다.',
      'nl' => 'Aangemeld als $name. Klaar om op Lichess te spelen.',
      'ru' => 'Вход выполнен как $name. Можно играть на Lichess.',
      _ => null,
    };
  }

  final importProgress = RegExp(
    r'^(\d+(?:/\d+)?) processed / (\d+) new / (\d+) skipped / (\d+) failed(?: (.+))?$',
  ).firstMatch(text);
  if (importProgress != null) {
    final processed = importProgress.group(1)!;
    final inserted = importProgress.group(2)!;
    final skipped = importProgress.group(3)!;
    final failed = importProgress.group(4)!;
    final suffix = importProgress.group(5);
    final translatedSuffix =
        suffix == null ? null : _translatePatterns(suffix, key);
    final status = switch (key) {
      'zh-Hans' => '已处理 $processed / 新增 $inserted / 跳过 $skipped / 失败 $failed',
      'zh-Hant' => '已處理 $processed / 新增 $inserted / 略過 $skipped / 失敗 $failed',
      'de' =>
        '$processed verarbeitet / $inserted neu / $skipped übersprungen / $failed fehlgeschlagen',
      'es' =>
        '$processed procesadas / $inserted nuevas / $skipped omitidas / $failed fallidas',
      'fr' =>
        '$processed traitées / $inserted nouvelles / $skipped ignorées / $failed échouées',
      'it' =>
        '$processed elaborate / $inserted nuove / $skipped ignorate / $failed non riuscite',
      'ja' => '$processed 処理済み / $inserted 新規 / $skipped スキップ / $failed 失敗',
      'ko' => '$processed 처리 / $inserted 신규 / $skipped 건너뜀 / $failed 실패',
      'nl' =>
        '$processed verwerkt / $inserted nieuw / $skipped overgeslagen / $failed mislukt',
      'ru' =>
        '$processed обработано / $inserted новых / $skipped пропущено / $failed с ошибкой',
      _ => null,
    };
    if (status == null) return null;
    if (suffix == null) return status;
    return '$status ${translatedSuffix ?? suffix}';
  }

  final modelBuildProgress = RegExp(
    r'^(\d+)/(\d+) checked / (\d+) usable / (\d+) skipped / (\d+) failed(?: (.+))?$',
  ).firstMatch(text);
  if (modelBuildProgress != null) {
    final checked = modelBuildProgress.group(1)!;
    final total = modelBuildProgress.group(2)!;
    final usable = modelBuildProgress.group(3)!;
    final skipped = modelBuildProgress.group(4)!;
    final failed = modelBuildProgress.group(5)!;
    final suffix = modelBuildProgress.group(6);
    final translatedSuffix =
        suffix == null ? null : _translatePatterns(suffix, key);
    final status = switch (key) {
      'zh-Hans' =>
        '已检查 $checked/$total / 可用 $usable / 跳过 $skipped / 失败 $failed',
      'zh-Hant' =>
        '已檢查 $checked/$total / 可用 $usable / 略過 $skipped / 失敗 $failed',
      'de' =>
        '$checked/$total geprüft / $usable nutzbar / $skipped übersprungen / $failed fehlgeschlagen',
      'es' =>
        '$checked/$total revisadas / $usable utilizables / $skipped omitidas / $failed fallidas',
      'fr' =>
        '$checked/$total vérifiées / $usable utilisables / $skipped ignorées / $failed échouées',
      'it' =>
        '$checked/$total controllate / $usable utilizzabili / $skipped ignorate / $failed non riuscite',
      'ja' =>
        '$checked/$total 確認済み / $usable 使用可能 / $skipped スキップ / $failed 失敗',
      'ko' => '$checked/$total 확인 / $usable 사용 가능 / $skipped 건너뜀 / $failed 실패',
      'nl' =>
        '$checked/$total gecontroleerd / $usable bruikbaar / $skipped overgeslagen / $failed mislukt',
      'ru' =>
        '$checked/$total проверено / $usable пригодно / $skipped пропущено / $failed с ошибкой',
      _ => null,
    };
    if (status == null) return null;
    if (suffix == null) return status;
    return '$status ${translatedSuffix ?? suffix}';
  }

  final lichessRetry =
      RegExp(r'^Waiting for Lichess until (.+)\.$').firstMatch(text);
  if (lichessRetry != null) {
    final time = lichessRetry.group(1)!;
    return switch (key) {
      'zh-Hans' => '等待 Lichess 至 $time。',
      'zh-Hant' => '等待 Lichess 至 $time。',
      'de' => 'Warten auf Lichess bis $time.',
      'es' => 'Esperando a Lichess hasta $time.',
      'fr' => 'En attente de Lichess jusqu’à $time.',
      'it' => 'In attesa di Lichess fino a $time.',
      'ja' => '$time まで Lichess を待機しています。',
      'ko' => '$time까지 Lichess를 기다리는 중입니다.',
      'nl' => 'Wachten op Lichess tot $time.',
      'ru' => 'Ожидание Lichess до $time.',
      _ => null,
    };
  }

  final noOpenings = RegExp(r'^No openings match "(.+)"$').firstMatch(text);
  if (noOpenings != null) {
    final query = noOpenings.group(1)!;
    return switch (key) {
      'zh-Hans' => '没有匹配“$query”的开局',
      'zh-Hant' => '沒有符合「$query」的開局',
      'de' => 'Keine Eröffnung passt zu „$query“',
      'es' => 'Ninguna apertura coincide con “$query”',
      'fr' => 'Aucune ouverture ne correspond à « $query »',
      'it' => 'Nessuna apertura corrisponde a “$query”',
      'ja' => '「$query」に一致するオープニングはありません',
      'ko' => '“$query”와 일치하는 오프닝이 없습니다',
      'nl' => 'Geen openingen voor “$query”',
      'ru' => 'Нет дебютов по запросу «$query»',
      _ => null,
    };
  }

  final bestMove = RegExp(r'^Best move: (.+)$').firstMatch(text);
  if (bestMove != null) {
    final move = bestMove.group(1)!;
    return switch (key) {
      'zh-Hans' => '最佳着法：$move',
      'zh-Hant' => '最佳著法：$move',
      'de' => 'Bester Zug: $move',
      'es' => 'Mejor jugada: $move',
      'fr' => 'Meilleur coup : $move',
      'it' => 'Mossa migliore: $move',
      'ja' => '最善手：$move',
      'ko' => '최선의 수: $move',
      'nl' => 'Beste zet: $move',
      'ru' => 'Лучший ход: $move',
      _ => null,
    };
  }

  final plainPositions = RegExp(r'^(\d+) / (\d+) positions$').firstMatch(text);
  if (plainPositions != null) {
    final done = plainPositions.group(1)!;
    final total = plainPositions.group(2)!;
    return switch (key) {
      'zh-Hans' => '$done / $total 个局面',
      'zh-Hant' => '$done / $total 個局面',
      'de' => '$done / $total Stellungen',
      'es' => '$done / $total posiciones',
      'fr' => '$done / $total positions',
      'it' => '$done / $total posizioni',
      'ja' => '$done / $total 局面',
      'ko' => '$done / $total 포지션',
      'nl' => '$done / $total stellingen',
      'ru' => '$done / $total позиций',
      _ => null,
    };
  }

  final pgnPositions =
      RegExp(r'^(\d+) / (\d+) PGN positions evaluated\.$').firstMatch(text);
  if (pgnPositions != null) {
    final done = pgnPositions.group(1)!;
    final total = pgnPositions.group(2)!;
    return switch (key) {
      'zh-Hans' => '已评估 $done / $total 个 PGN 局面。',
      'zh-Hant' => '已評估 $done / $total 個 PGN 局面。',
      'de' => '$done / $total PGN-Stellungen bewertet.',
      'es' => '$done / $total posiciones PGN evaluadas.',
      'fr' => '$done / $total positions PGN évaluées.',
      'it' => '$done / $total posizioni PGN valutate.',
      'ja' => '$done / $total の PGN 局面を評価しました。',
      'ko' => '$done / $total PGN 포지션 평가 완료.',
      'nl' => '$done / $total PGN-stellingen geëvalueerd.',
      'ru' => 'Оценено $done / $total позиций PGN.',
      _ => null,
    };
  }

  final percentComplete = RegExp(r'^(\d+)% complete$').firstMatch(text);
  if (percentComplete != null) {
    final percent = percentComplete.group(1)!;
    return switch (key) {
      'zh-Hans' => '已完成 $percent%',
      'zh-Hant' => '已完成 $percent%',
      'de' => '$percent % fertig',
      'es' => '$percent % completado',
      'fr' => '$percent % terminé',
      'it' => '$percent% completato',
      'ja' => '$percent% 完了',
      'ko' => '$percent% 완료',
      'nl' => '$percent% voltooid',
      'ru' => 'Готово $percent%',
      _ => null,
    };
  }

  final resumeAt = RegExp(r'^Resume at (.+)$').firstMatch(text);
  if (resumeAt != null) {
    final label = resumeAt.group(1)!;
    return switch (key) {
      'zh-Hans' => '从 $label 继续',
      'zh-Hant' => '從 $label 繼續',
      'de' => 'Weiter bei $label',
      'es' => 'Retomar en $label',
      'fr' => 'Reprendre à $label',
      'it' => 'Riprendi da $label',
      'ja' => '$label から再開',
      'ko' => '$label에서 이어서 하기',
      'nl' => 'Hervatten bij $label',
      'ru' => 'Продолжить с $label',
      _ => null,
    };
  }

  final addMoreFiles = RegExp(r'^Add more files \((\d+)/4\)$').firstMatch(text);
  if (addMoreFiles != null) {
    final count = addMoreFiles.group(1)!;
    return switch (key) {
      'zh-Hans' => '继续添加文件（$count/4）',
      'zh-Hant' => '繼續新增檔案（$count/4）',
      'de' => 'Weitere Dateien hinzufügen ($count/4)',
      'es' => 'Añadir más archivos ($count/4)',
      'fr' => 'Ajouter des fichiers ($count/4)',
      'it' => 'Aggiungi altri file ($count/4)',
      'ja' => 'ファイルを追加（$count/4）',
      'ko' => '파일 더 추가 ($count/4)',
      'nl' => 'Meer bestanden toevoegen ($count/4)',
      'ru' => 'Добавить файлы ($count/4)',
      _ => null,
    };
  }

  final activeFilters = RegExp(r'^(\d+) active$').firstMatch(text);
  if (activeFilters != null) {
    final count = activeFilters.group(1)!;
    return switch (key) {
      'zh-Hans' => '$count 个已启用',
      'zh-Hant' => '$count 個已啟用',
      'de' => '$count aktiv',
      'es' => '$count activos',
      'fr' => '$count actifs',
      'it' => '$count attivi',
      'ja' => '$count 件有効',
      'ko' => '$count개 활성',
      'nl' => '$count actief',
      'ru' => 'Активно: $count',
      _ => null,
    };
  }

  final lichessEnded =
      RegExp(r'^This Lichess game has ended: (.+)\.$').firstMatch(text);
  if (lichessEnded != null) {
    final result = lichessEnded.group(1)!;
    return switch (key) {
      'zh-Hans' => '这盘 Lichess 对局已结束：$result。',
      'zh-Hant' => '這盤 Lichess 對局已結束：$result。',
      'de' => 'Diese Lichess-Partie ist beendet: $result.',
      'es' => 'Esta partida de Lichess terminó: $result.',
      'fr' => 'Cette partie Lichess est terminée : $result.',
      'it' => 'Questa partita Lichess è terminata: $result.',
      'ja' => 'この Lichess 対局は終了しました：$result。',
      'ko' => '이 Lichess 게임이 종료되었습니다: $result.',
      'nl' => 'Deze Lichess-partij is afgelopen: $result.',
      'ru' => 'Партия Lichess завершена: $result.',
      _ => null,
    };
  }

  final channelLabel = RegExp(r'^Channel (\d+)$').firstMatch(text);
  if (channelLabel != null) {
    final channel = channelLabel.group(1)!;
    return switch (key) {
      'zh-Hans' => '通道 $channel',
      'zh-Hant' => '通道 $channel',
      'de' => 'Kanal $channel',
      'es' => 'Canal $channel',
      'fr' => 'Canal $channel',
      'it' => 'Canale $channel',
      'ja' => 'チャンネル $channel',
      'ko' => '채널 $channel',
      'nl' => 'Kanaal $channel',
      'ru' => 'Канал $channel',
      _ => null,
    };
  }

  final detectedPieces = RegExp(r'^(\d+) detected$').firstMatch(text);
  if (detectedPieces != null) {
    final count = detectedPieces.group(1)!;
    return switch (key) {
      'zh-Hans' => '已识别 $count 个',
      'zh-Hant' => '已識別 $count 個',
      'de' => '$count erkannt',
      'es' => '$count detectadas',
      'fr' => '$count détectés',
      'it' => '$count rilevati',
      'ja' => '$count 個検出',
      'ko' => '$count개 감지됨',
      'nl' => '$count gedetecteerd',
      'ru' => 'Обнаружено: $count',
      _ => null,
    };
  }

  final disabledByBuzzer = RegExp(
    r'^(.+) disabled by the buzzer master switch$',
  ).firstMatch(text);
  if (disabledByBuzzer != null) {
    final label = _translatePatterns(disabledByBuzzer.group(1)!, key) ??
        disabledByBuzzer.group(1)!;
    return switch (key) {
      'zh-Hans' => '$label 已被提示音总开关关闭',
      'zh-Hant' => '$label 已被提示音總開關關閉',
      'de' => '$label ist durch den Signalton-Hauptschalter deaktiviert',
      'es' => '$label está desactivado por el interruptor general de sonido',
      'fr' => '$label est désactivé par l’interrupteur général des sons',
      'it' => '$label è disattivato dall’interruttore generale dei suoni',
      'ja' => '$label は通知音の全体スイッチで無効です',
      'ko' => '$label은 알림음 전체 스위치로 꺼져 있습니다',
      'nl' => '$label is uitgeschakeld door de hoofdschakelaar voor geluid',
      'ru' => '$label отключено главным переключателем звука',
      _ => null,
    };
  }

  return null;
}

String? _reviewAnalysisTranslations(String text, String key) {
  String? withMove(
    RegExp regex, {
    required String Function(String move) zhHans,
    required String Function(String move) zhHant,
    required String Function(String move) de,
    required String Function(String move) es,
    required String Function(String move) fr,
    required String Function(String move) it,
    required String Function(String move) ja,
    required String Function(String move) ko,
    required String Function(String move) nl,
    required String Function(String move) ru,
  }) {
    final match = regex.firstMatch(text);
    if (match == null) return null;
    final move = match.group(1)!;
    return switch (key) {
      'zh-Hans' => zhHans(move),
      'zh-Hant' => zhHant(move),
      'de' => de(move),
      'es' => es(move),
      'fr' => fr(move),
      'it' => it(move),
      'ja' => ja(move),
      'ko' => ko(move),
      'nl' => nl(move),
      'ru' => ru(move),
      _ => null,
    };
  }

  final dynamicSummary = withMove(
    RegExp(
        r'^(.+) is still inside the opening book for this lightweight review\.$'),
    zhHans: (move) => '$move 仍在本次快速复盘的开局库中。',
    zhHant: (move) => '$move 仍在本次快速復盤的開局庫中。',
    de: (move) =>
        '$move liegt in dieser schnellen Analyse noch im Eröffnungsbuch.',
    es: (move) =>
        '$move sigue dentro del libro de aperturas de esta revisión rápida.',
    fr: (move) =>
        '$move reste dans le répertoire d’ouverture de cette revue rapide.',
    it: (move) =>
        '$move è ancora nel libro di apertura di questa revisione rapida.',
    ja: (move) => '$move はこの簡易レビューではまだ定跡内です。',
    ko: (move) => '$move는 이번 빠른 리뷰에서 아직 오프닝북 안에 있습니다.',
    nl: (move) => '$move zit in deze snelle review nog in het openingsboek.',
    ru: (move) =>
        '$move ещё находится в дебютной книге для этого быстрого разбора.',
  );
  if (dynamicSummary != null) return dynamicSummary;

  final tacticalSummary = withMove(
    RegExp(
        r'^(.+) creates a tactical or strategic turning point worth reviewing\.$'),
    zhHans: (move) => '$move 制造了值得复盘的战术或战略转折点。',
    zhHant: (move) => '$move 製造了值得復盤的戰術或戰略轉折點。',
    de: (move) =>
        '$move erzeugt einen taktischen oder strategischen Wendepunkt.',
    es: (move) => '$move crea un punto de inflexión táctico o estratégico.',
    fr: (move) => '$move crée un tournant tactique ou stratégique à revoir.',
    it: (move) => '$move crea una svolta tattica o strategica da rivedere.',
    ja: (move) => '$move は見直す価値のある戦術的または戦略的な転機を作ります。',
    ko: (move) => '$move는 검토할 만한 전술적 또는 전략적 전환점을 만듭니다.',
    nl: (move) => '$move creëert een tactisch of strategisch kantelpunt.',
    ru: (move) =>
        '$move создаёт тактический или стратегический поворотный момент.',
  );
  if (tacticalSummary != null) return tacticalSummary;

  final activitySummary = withMove(
    RegExp(r'^(.+) improves piece activity while keeping the plan clear\.$'),
    zhHans: (move) => '$move 提升了子力活跃度，同时计划仍然清晰。',
    zhHant: (move) => '$move 提升了子力活躍度，同時計畫仍然清晰。',
    de: (move) =>
        '$move verbessert die Figurenaktivität und hält den Plan klar.',
    es: (move) =>
        '$move mejora la actividad de las piezas y mantiene claro el plan.',
    fr: (move) =>
        '$move améliore l’activité des pièces tout en gardant un plan clair.',
    it: (move) =>
        '$move migliora l’attività dei pezzi mantenendo chiaro il piano.',
    ja: (move) => '$move は駒の働きを高めつつ、方針を明確に保ちます。',
    ko: (move) => '$move는 기물 활동성을 높이면서 계획을 분명하게 유지합니다.',
    nl: (move) => '$move verbetert de stukactiviteit en houdt het plan helder.',
    ru: (move) => '$move улучшает активность фигур и сохраняет понятный план.',
  );
  if (activitySummary != null) return activitySummary;

  final bestSummary = withMove(
    RegExp(r'^(.+) matches the strongest candidate in this review pass\.$'),
    zhHans: (move) => '$move 符合本次复盘中的最强候选着。',
    zhHant: (move) => '$move 符合本次復盤中的最強候選著。',
    de: (move) =>
        '$move entspricht dem stärksten Kandidaten in dieser Analyse.',
    es: (move) =>
        '$move coincide con la candidata más fuerte de esta revisión.',
    fr: (move) => '$move correspond au meilleur candidat de cette revue.',
    it: (move) =>
        '$move coincide con la candidata più forte di questa revisione.',
    ja: (move) => '$move はこのレビューで最も強い候補手と一致します。',
    ko: (move) => '$move는 이번 리뷰에서 가장 강한 후보 수와 일치합니다.',
    nl: (move) =>
        '$move komt overeen met de sterkste kandidaat in deze review.',
    ru: (move) => '$move совпадает с сильнейшим кандидатом в этом разборе.',
  );
  if (bestSummary != null) return bestSummary;

  final inaccuracySummary = withMove(
    RegExp(r'^(.+) is playable, but there may be a cleaner plan\.$'),
    zhHans: (move) => '$move 可以下，但可能有更简洁的计划。',
    zhHant: (move) => '$move 可以下，但可能有更簡潔的計畫。',
    de: (move) =>
        '$move ist spielbar, aber es gibt vielleicht einen saubereren Plan.',
    es: (move) => '$move es jugable, pero puede haber un plan más limpio.',
    fr: (move) =>
        '$move est jouable, mais un plan plus propre existe peut-être.',
    it: (move) => '$move è giocabile, ma potrebbe esserci un piano più pulito.',
    ja: (move) => '$move は指せますが、より明快なプランがあるかもしれません。',
    ko: (move) => '$move는 가능하지만 더 깔끔한 계획이 있을 수 있습니다.',
    nl: (move) => '$move is speelbaar, maar er is mogelijk een schoner plan.',
    ru: (move) => '$move играбелен, но может быть более чистый план.',
  );
  if (inaccuracySummary != null) return inaccuracySummary;

  final mistakeSummary = withMove(
    RegExp(r'^(.+) changes the evaluation enough to deserve a closer look\.$'),
    zhHans: (move) => '$move 对评分影响较大，值得仔细复盘。',
    zhHant: (move) => '$move 對評分影響較大，值得仔細復盤。',
    de: (move) =>
        '$move verändert die Bewertung deutlich genug für einen genaueren Blick.',
    es: (move) =>
        '$move cambia bastante la evaluación y merece una revisión más cercana.',
    fr: (move) =>
        '$move change assez l’évaluation pour mériter un examen attentif.',
    it: (move) =>
        '$move cambia abbastanza la valutazione da meritare un controllo.',
    ja: (move) => '$move は評価を大きく変えるため、詳しく確認する価値があります。',
    ko: (move) => '$move는 평가를 크게 바꾸므로 더 자세히 볼 필요가 있습니다.',
    nl: (move) => '$move verandert de evaluatie genoeg om nader te bekijken.',
    ru: (move) =>
        '$move заметно меняет оценку и заслуживает более внимательного разбора.',
  );
  if (mistakeSummary != null) return mistakeSummary;

  final missedWinSummary = withMove(
    RegExp(
        r'^(.+) lets a winning chance slip away; compare it with the engine line\.$'),
    zhHans: (move) => '$move 错过了获胜机会；请和引擎路线对比。',
    zhHant: (move) => '$move 錯過了獲勝機會；請和引擎路線對比。',
    de: (move) =>
        '$move lässt eine Gewinnchance aus; vergleiche mit der Engine-Variante.',
    es: (move) =>
        '$move deja escapar una opción ganadora; compárala con la línea del motor.',
    fr: (move) =>
        '$move laisse passer une chance de gain ; comparez avec la ligne du moteur.',
    it: (move) =>
        '$move lascia sfuggire una chance vincente; confrontala con la linea del motore.',
    ja: (move) => '$move は勝機を逃します。エンジンの手順と比べてください。',
    ko: (move) => '$move는 이길 기회를 놓칩니다. 엔진 라인과 비교해 보세요.',
    nl: (move) =>
        '$move laat een winstkans glippen; vergelijk met de enginevariant.',
    ru: (move) => '$move упускает шанс на победу; сравните с линией движка.',
  );
  if (missedWinSummary != null) return missedWinSummary;

  final blunderSummary = withMove(
    RegExp(r'^(.+) likely drops material or allows a forcing tactic\.$'),
    zhHans: (move) => '$move 很可能丢子，或允许对方形成强制战术。',
    zhHant: (move) => '$move 很可能丟子，或允許對方形成強制戰術。',
    de: (move) =>
        '$move verliert wahrscheinlich Material oder erlaubt eine zwingende Taktik.',
    es: (move) =>
        '$move probablemente pierde material o permite una táctica forzada.',
    fr: (move) =>
        '$move perd probablement du matériel ou autorise une tactique forcée.',
    it: (move) =>
        '$move probabilmente perde materiale o consente una tattica forzante.',
    ja: (move) => '$move は駒損、または強制的な戦術を許す可能性があります。',
    ko: (move) => '$move는 기물을 잃거나 강제 전술을 허용할 가능성이 큽니다.',
    nl: (move) =>
        '$move verliest waarschijnlijk materiaal of laat een dwingende tactiek toe.',
    ru: (move) =>
        '$move, вероятно, теряет материал или допускает форсированную тактику.',
  );
  if (blunderSummary != null) return blunderSummary;

  final quietSummary = withMove(
    RegExp(r'^(.+) keeps the game flowing without a major evaluation swing\.$'),
    zhHans: (move) => '$move 让局面继续推进，没有造成明显评分波动。',
    zhHant: (move) => '$move 讓局面繼續推進，沒有造成明顯評分波動。',
    de: (move) =>
        '$move hält die Partie im Fluss, ohne große Bewertungsänderung.',
    es: (move) =>
        '$move mantiene la partida fluida sin gran cambio de evaluación.',
    fr: (move) => '$move garde la partie fluide sans grand écart d’évaluation.',
    it: (move) =>
        '$move mantiene la partita fluida senza grandi oscillazioni di valutazione.',
    ja: (move) => '$move は大きな評価変動なくゲームを進めます。',
    ko: (move) => '$move는 큰 평가 변화 없이 게임을 이어갑니다.',
    nl: (move) =>
        '$move houdt de partij gaande zonder grote evaluatieschommeling.',
    ru: (move) => '$move продолжает игру без большого скачка оценки.',
  );
  if (quietSummary != null) return quietSummary;

  final stockfishQueue =
      RegExp(r'^Stockfish queue: (.+) from (.+)$').firstMatch(text);
  if (stockfishQueue != null) {
    final san = stockfishQueue.group(1)!;
    final uci = stockfishQueue.group(2)!;
    return switch (key) {
      'zh-Hans' => 'Stockfish 队列：$san，来自 $uci',
      'zh-Hant' => 'Stockfish 佇列：$san，來自 $uci',
      'de' => 'Stockfish-Warteschlange: $san aus $uci',
      'es' => 'Cola de Stockfish: $san desde $uci',
      'fr' => 'File Stockfish : $san depuis $uci',
      'it' => 'Coda Stockfish: $san da $uci',
      'ja' => 'Stockfish キュー：$san（$uci から）',
      'ko' => 'Stockfish 대기열: $san, $uci에서',
      'nl' => 'Stockfish-wachtrij: $san vanaf $uci',
      'ru' => 'Очередь Stockfish: $san из $uci',
      _ => null,
    };
  }

  final prefixedMove =
      RegExp(r'^(Best|Book|Cleaner|Better|Tactic): (.+)$').firstMatch(text);
  if (prefixedMove != null) {
    final prefix = prefixedMove.group(1)!;
    final move = prefixedMove.group(2)!;
    final translatedPrefix = generatedAppLocalizedMap(key)[prefix] ??
        _manualDirectTranslations(prefix, key) ??
        prefix;
    return '$translatedPrefix: $move';
  }

  return null;
}

String? _translateBotGamePart(String text, String key) {
  return _freshVisibleTranslations(text, key) ??
      _criticalVisibleTranslations(text, key) ??
      recentFeatureTranslation(text, key) ??
      generatedAppLocalizedMap(key)[text] ??
      _manualDirectTranslations(text, key);
}

String? _manualOverrideTranslations(String text, String key) {
  const translations = <String, Map<String, String>>{
    'This game ended before any playable moves, so there is no position to analyze.':
        {
      'zh-Hans':
          '\u8fd9\u76d8\u68cb\u8fd8\u6ca1\u6709\u53ef\u5206\u6790\u7684\u7740\u6cd5\u5c31\u5df2\u7ed3\u675f\uff0c\u65e0\u6cd5\u8fdb\u5165\u5206\u6790\u3002',
      'zh-Hant':
          '\u9019\u76e4\u68cb\u9084\u6c92\u6709\u53ef\u5206\u6790\u7684\u8457\u6cd5\u5c31\u5df2\u7d50\u675f\uff0c\u7121\u6cd5\u9032\u5165\u5206\u6790\u3002',
    },
    'Remind me in 1 day': {
      'zh-Hans': '\u0031\u5929\u540e\u63d0\u9192\u6211',
      'zh-Hant': '\u0031\u5929\u5f8c\u63d0\u9192\u6211',
      'de': 'In 1 Tag erinnern',
      'es': 'Recordarme en 1 dia',
      'fr': 'Me le rappeler dans 1 jour',
      'it': 'Ricordamelo tra 1 giorno',
      'ja': '\u0031\u65e5\u5f8c\u306b\u901a\u77e5',
      'ko': '\u0031\uc77c \ud6c4 \uc54c\ub9bc',
      'nl': 'Herinner mij over 1 dag',
      'ru':
          '\u041d\u0430\u043f\u043e\u043c\u043d\u0438\u0442\u044c \u0447\u0435\u0440\u0435\u0437 1 \u0434\u0435\u043d\u044c',
    },
    "Don't remind me again for this update": {
      'zh-Hans': '\u8fd9\u4e2a\u66f4\u65b0\u4e0d\u518d\u63d0\u9192',
      'zh-Hant': '\u9019\u500b\u66f4\u65b0\u4e0d\u518d\u63d0\u9192',
      'de': 'Fuer dieses Update nicht mehr erinnern',
      'es': 'No recordarme mas esta actualizacion',
      'fr': 'Ne plus me rappeler cette mise a jour',
      'it': 'Non ricordarmi piu questo aggiornamento',
      'ja':
          '\u3053\u306e\u66f4\u65b0\u306f\u4eca\u5f8c\u901a\u77e5\u3057\u306a\u3044',
      'ko':
          '\uc774 \uc5c5\ub370\uc774\ud2b8\ub294 \ub2e4\uc2dc \uc54c\ub9ac\uc9c0 \uc54a\uae30',
      'nl': 'Niet meer herinneren voor deze update',
      'ru':
          '\u041d\u0435 \u043d\u0430\u043f\u043e\u043c\u0438\u043d\u0430\u0442\u044c \u043e\u0431 \u044d\u0442\u043e\u043c \u043e\u0431\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u0438',
    },
    'Google Play update is not available right now.': {
      'zh-Hans': 'Google Play \u66f4\u65b0\u73b0\u5728\u4e0d\u53ef\u7528\u3002',
      'zh-Hant': 'Google Play \u66f4\u65b0\u76ee\u524d\u4e0d\u53ef\u7528\u3002',
      'de': 'Google Play Update ist derzeit nicht verfuegbar.',
      'es': 'La actualizacion de Google Play no esta disponible ahora.',
      'fr': 'La mise a jour Google Play n est pas disponible pour le moment.',
      'it': 'L aggiornamento Google Play non e disponibile in questo momento.',
      'ja':
          '\u73fe\u5728 Google Play \u306e\u66f4\u65b0\u306f\u5229\u7528\u3067\u304d\u307e\u305b\u3093\u3002',
      'ko':
          '\ud604\uc7ac Google Play \uc5c5\ub370\uc774\ud2b8\ub97c \uc0ac\uc6a9\ud560 \uc218 \uc5c6\uc2b5\ub2c8\ub2e4.',
      'nl': 'Google Play-update is nu niet beschikbaar.',
      'ru':
          '\u041e\u0431\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u0435 Google Play \u0441\u0435\u0439\u0447\u0430\u0441 \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u043d\u043e.',
    },
    'Install Chessnut Next from Google Play to use in-app updates.': {
      'zh-Hans':
          '\u8bf7\u5148\u4ece Google Play \u5b89\u88c5 Chessnut Next\uff0c\u518d\u4f7f\u7528\u5e94\u7528\u5185\u66f4\u65b0\u3002',
      'zh-Hant':
          '\u8acb\u5148\u5f9e Google Play \u5b89\u88dd Chessnut Next\uff0c\u518d\u4f7f\u7528\u61c9\u7528\u5167\u66f4\u65b0\u3002',
    },
    'Game Review': {
      'zh-Hans': '\u5bf9\u5c40\u590d\u76d8',
      'zh-Hant': '\u5c0d\u5c40\u8907\u76e4',
      'de': 'Partieanalyse',
      'es': 'Revision de partida',
      'fr': 'Revue de partie',
      'it': 'Revisione partita',
      'ja': '\u5bfe\u5c40\u30ec\u30d3\u30e5\u30fc',
      'ko': '\ub300\uad6d \ub9ac\ubdf0',
      'nl': 'Partijreview',
      'ru':
          '\u041e\u0431\u0437\u043e\u0440 \u043f\u0430\u0440\u0442\u0438\u0438',
    },
    'Game history': {
      'zh-Hans': '\u5bf9\u5c40\u5386\u53f2',
      'zh-Hant': '\u5c0d\u5c40\u6b77\u53f2',
      'de': 'Partieverlauf',
      'es': 'Historial de partidas',
      'fr': 'Historique des parties',
      'it': 'Cronologia partite',
      'ja': '\u5bfe\u5c40\u5c65\u6b74',
      'ko': '\ub300\uad6d \uae30\ub85d',
      'nl': 'Partijgeschiedenis',
      'ru':
          '\u0418\u0441\u0442\u043e\u0440\u0438\u044f \u043f\u0430\u0440\u0442\u0438\u0439',
    },
    'Complete daily activities to earn Chessnut points': {
      'zh-Hans': '完成每日活动，赚取 Chessnut 积分',
      'zh-Hant': '完成每日活動，賺取 Chessnut 積分',
      'de': 'Erledige tägliche Aktivitäten und verdiene Chessnut-Punkte.',
      'es': 'Completa actividades diarias para ganar puntos Chessnut.',
      'fr':
          'Terminez des activités quotidiennes pour gagner des points Chessnut.',
      'it': 'Completa attività giornaliere per guadagnare punti Chessnut.',
      'ja': '毎日のアクティビティを完了して Chessnut ポイントを獲得しましょう。',
      'ko': '매일 활동을 완료하고 Chessnut 포인트를 받으세요.',
      'nl': 'Voltooi dagelijkse activiteiten en verdien Chessnut-punten.',
      'ru': 'Выполняйте ежедневные задания и получайте очки Chessnut.',
    },
    'Complete one Career challenge': {
      'zh-Hans': '\u5b8c\u6210\u4e00\u573a Career \u6311\u6218',
      'zh-Hant': '\u5b8c\u6210\u4e00\u5834 Career \u6311\u6230',
      'de': 'Schliesse eine Career-Herausforderung ab.',
      'es': 'Completa un desafio de Career.',
      'fr': 'Terminez un defi Career.',
      'it': 'Completa una sfida Career.',
      'ja':
          'Career \u30c1\u30e3\u30ec\u30f3\u30b8\u30921\u56de\u5b8c\u4e86\u3059\u308b',
      'ko': 'Career \ub3c4\uc804\uc744 1\ud68c \uc644\ub8cc\ud558\uae30',
      'nl': 'Voltooi een Career-uitdaging.',
      'ru':
          '\u0417\u0430\u0432\u0435\u0440\u0448\u0438\u0442\u0435 \u043e\u0434\u043d\u043e \u0438\u0441\u043f\u044b\u0442\u0430\u043d\u0438\u0435 Career.',
    },
    'Finish a Career Mode challenge game.': {
      'zh-Hans':
          '\u5b8c\u6210\u4e00\u5c40 Career Mode \u6311\u6218\u5bf9\u5c40\u3002',
      'zh-Hant':
          '\u5b8c\u6210\u4e00\u5c40 Career Mode \u6311\u6230\u5c0d\u5c40\u3002',
      'de': 'Beende eine Career-Mode-Herausforderungspartie.',
      'es': 'Termina una partida de desafio de Career Mode.',
      'fr': 'Terminez une partie defi du mode Career.',
      'it': 'Termina una partita sfida della modalita Career.',
      'ja':
          'Career \u30e2\u30fc\u30c9\u306e\u30c1\u30e3\u30ec\u30f3\u30b8\u5bfe\u5c40\u30921\u5c40\u7d42\u3048\u308b\u3002',
      'ko':
          'Career \ubaa8\ub4dc \ub3c4\uc804 \uac8c\uc784 \ud55c \ud310\uc744 \ub05d\ub0b4\uae30.',
      'nl': 'Beeindig een Career Mode-uitdagingspartij.',
      'ru':
          '\u0417\u0430\u0432\u0435\u0440\u0448\u0438\u0442\u0435 \u043e\u0434\u043d\u0443 \u043f\u0430\u0440\u0442\u0438\u044e-\u0438\u0441\u043f\u044b\u0442\u0430\u043d\u0438\u0435 \u0432 \u0440\u0435\u0436\u0438\u043c\u0435 Career.',
    },
    'A compact daily loop for learning, playing, Career challenges, and reviews.':
        {
      'zh-Hans':
          '\u4e00\u5957\u7d27\u51d1\u7684\u6bcf\u65e5\u6d41\u7a0b\uff1a\u5b66\u4e60\u3001\u5bf9\u5c40\u3001Career \u6311\u6218\u548c\u590d\u76d8\u3002',
      'zh-Hant':
          '\u4e00\u5957\u7dca\u6e4a\u7684\u6bcf\u65e5\u6d41\u7a0b\uff1a\u5b78\u7fd2\u3001\u5c0d\u5c40\u3001Career \u6311\u6230\u548c\u8986\u76e4\u3002',
      'de':
          'Ein kompakter Tagesablauf zum Lernen, Spielen, fuer Career-Herausforderungen und Reviews.',
      'es':
          'Un ciclo diario compacto para aprender, jugar, retos de Career y revisiones.',
      'fr':
          'Une boucle quotidienne compacte pour apprendre, jouer, relever des defis Career et faire des revues.',
      'it':
          'Un ciclo quotidiano compatto per imparare, giocare, fare sfide Career e rivedere le partite.',
      'ja':
          '\u5b66\u7fd2\u3001\u5bfe\u5c40\u3001Career \u30c1\u30e3\u30ec\u30f3\u30b8\u3001\u30ec\u30d3\u30e5\u30fc\u3092\u307e\u3068\u3081\u305f\u30b3\u30f3\u30d1\u30af\u30c8\u306a\u6bce\u65e5\u306e\u6d41\u308c\u3067\u3059\u3002',
      'ko':
          '\ud559\uc2b5, \ub300\uad6d, Career \ub3c4\uc804, \ubcf5\uae30\ub97c \uc704\ud55c \uac04\uacb0\ud55c \uc77c\uc77c \ub8e8\ud504\uc785\ub2c8\ub2e4.',
      'nl':
          'Een compacte dagelijkse routine voor leren, spelen, Career-uitdagingen en reviews.',
      'ru':
          '\u041a\u043e\u043c\u043f\u0430\u043a\u0442\u043d\u044b\u0439 \u0435\u0436\u0435\u0434\u043d\u0435\u0432\u043d\u044b\u0439 \u0446\u0438\u043a\u043b \u0434\u043b\u044f \u043e\u0431\u0443\u0447\u0435\u043d\u0438\u044f, \u0438\u0433\u0440\u044b, \u0438\u0441\u043f\u044b\u0442\u0430\u043d\u0438\u0439 Career \u0438 \u0440\u0430\u0437\u0431\u043e\u0440\u0430 \u043f\u0430\u0440\u0442\u0438\u0439.',
    },
    'Voice moves require a network connection. Choose the correct speech language to improve recognition success.':
        {
      'zh-Hans': '语音走棋需要网络连接。选择正确的语音语言可以提高识别成功率。',
      'zh-Hant': '語音走棋需要網路連線。選擇正確的語音語言可以提高識別成功率。',
      'de':
          'Sprachzüge benötigen eine Netzwerkverbindung. Wähle die richtige Sprache, um die Erkennung zu verbessern.',
      'es':
          'Los movimientos por voz requieren conexión de red. Elige el idioma correcto para mejorar el reconocimiento.',
      'fr':
          'Les coups vocaux nécessitent une connexion réseau. Choisis la bonne langue pour mieux les reconnaître.',
      'it':
          'Le mosse vocali richiedono una connessione di rete. Scegli la lingua corretta per migliorare il riconoscimento.',
      'ja': '音声指し手にはネットワーク接続が必要です。正しい音声言語を選ぶと認識精度が上がります。',
      'ko': '음성 수에는 네트워크 연결이 필요합니다. 올바른 음성 언어를 선택하면 인식 성공률이 높아집니다.',
      'nl':
          'Spraakzetten vereisen een netwerkverbinding. Kies de juiste taal om de herkenning te verbeteren.',
      'ru':
          'Голосовые ходы требуют подключения к сети. Выберите правильный язык, чтобы повысить точность распознавания.',
    },
    'Chessnut uses the microphone only while voice moves are on.': {
      'zh-Hans': 'Chessnut 只会在语音走棋开启时使用麦克风。',
      'zh-Hant': 'Chessnut 只會在語音走棋開啟時使用麥克風。',
      'de': 'Chessnut verwendet das Mikrofon nur, wenn Sprachzüge aktiv sind.',
      'es':
          'Chessnut usa el micrófono solo cuando los movimientos por voz están activados.',
      'fr':
          'Chessnut utilise le micro uniquement lorsque les coups vocaux sont activés.',
      'it':
          'Chessnut usa il microfono solo quando le mosse vocali sono attive.',
      'ja': 'Chessnut は音声走棋が有効なときだけマイクを使います。',
      'ko': 'Chessnut은 음성 수가 켜져 있을 때만 마이크를 사용합니다.',
      'nl':
          'Chessnut gebruikt de microfoon alleen wanneer spraakzetten aan staan.',
      'ru':
          'Chessnut использует микрофон только когда включены голосовые ходы.',
    },
    'Voice moves use online speech recognition. Check your network connection and try again.':
        {
      'zh-Hans': '语音走棋使用在线语音识别。请检查网络连接后重试。',
      'zh-Hant': '語音走棋使用線上語音辨識。請檢查網路連線後再試一次。',
      'de':
          'Sprachzüge nutzen Online-Spracherkennung. Prüfe die Netzwerkverbindung und versuche es erneut.',
      'es':
          'Los movimientos por voz usan reconocimiento de voz en línea. Revisa la conexión e inténtalo de nuevo.',
      'fr':
          'Les coups vocaux utilisent la reconnaissance vocale en ligne. Vérifie la connexion réseau, puis réessaie.',
      'it':
          'Le mosse vocali usano il riconoscimento vocale online. Controlla la connessione di rete e riprova.',
      'ja': '音声走棋はオンライン音声認識を使います。ネットワーク接続を確認してもう一度試してください。',
      'ko': '음성 수는 온라인 음성 인식을 사용합니다. 네트워크 연결을 확인한 뒤 다시 시도하세요.',
      'nl':
          'Spraakzetten gebruiken online spraakherkenning. Controleer je netwerkverbinding en probeer het opnieuw.',
      'ru':
          'Голосовые ходы используют онлайн-распознавание речи. Проверьте подключение к сети и попробуйте снова.',
    },
    'Deep analyst': {
      'zh-Hans': '深度分析师',
      'zh-Hant': '深度分析師',
      'de': 'Tiefer Analyst',
      'es': 'Analista profundo',
      'fr': 'Analyste approfondi',
      'it': 'Analista approfondito',
      'ja': '深掘り分析',
      'ko': '심층 분석가',
      'nl': 'Diepe analist',
      'ru': 'Глубокий аналитик',
    },
    'Calm, careful, detailed': {
      'zh-Hans': '沉稳、细致、详细',
      'zh-Hant': '沉穩、細緻、詳細',
      'de': 'Ruhig, sorgfältig, detailliert',
      'es': 'Calmo, cuidadoso y detallado',
      'fr': 'Calme, attentif et détaillé',
      'it': 'Calmo, attento e dettagliato',
      'ja': '落ち着きがあり、丁寧で、詳細',
      'ko': '차분하고, 꼼꼼하고, 자세한',
      'nl': 'Rustig, zorgvuldig en gedetailleerd',
      'ru': 'Спокойно, внимательно и подробно',
    },
    'About 2 min': {
      'zh-Hans': '约 2 分钟',
      'zh-Hant': '約 2 分鐘',
      'de': 'Ca. 2 Min.',
      'es': 'Unos 2 min',
      'fr': 'Environ 2 min',
      'it': 'Circa 2 min',
      'ja': '約2分',
      'ko': '약 2분',
      'nl': 'Ongeveer 2 min',
      'ru': 'Около 2 мин',
    },
    'A full-game study with patient explanations, turning points, plans, missed chances, move quality, and concrete training takeaways. Best when you want the richest report and can wait longer.':
        {
      'zh-Hans': '完整研究整盘棋局，耐心讲解转折点、计划、错失机会、走子质量和具体训练建议。适合想要最详细报告、也愿意多等一会儿的时候。',
      'zh-Hant': '完整研究整盤棋局，耐心講解轉折點、計劃、錯失機會、走子品質和具體訓練建議。適合想要最詳細報告、也願意多等一會兒的時候。',
      'de':
          'Eine vollständige Partieanalyse mit ruhigen Erklärungen zu Wendepunkten, Plänen, verpassten Chancen, Zugqualität und konkreten Trainingshinweisen. Ideal, wenn du den reichsten Bericht willst und länger warten kannst.',
      'es':
          'Un estudio completo de la partida con explicaciones pacientes sobre puntos de giro, planes, oportunidades perdidas, calidad de jugadas y consejos concretos de entrenamiento. Ideal si quieres el informe más rico y puedes esperar más.',
      'fr':
          'Une étude complète de la partie avec des explications patientes sur les tournants, les plans, les occasions manquées, la qualité des coups et des pistes concrètes d’entraînement. Idéal si tu veux le rapport le plus riche et peux attendre davantage.',
      'it':
          "Uno studio dell'intera partita con spiegazioni pazienti su svolte, piani, occasioni mancate, qualità delle mosse e consigli concreti di allenamento. Ideale quando vuoi il report più ricco e puoi aspettare più a lungo.",
      'ja':
          '対局全体をじっくり分析し、転機、計画、逃した好機、着手の質、具体的な練習ポイントを丁寧に説明します。最も充実した報告がほしくて、少し長く待てるときに向いています。',
      'ko':
          '한 판 전체를 차분히 분석해 전환점, 계획, 놓친 기회, 수의 질, 구체적인 훈련 포인트를 자세히 설명합니다. 가장 풍부한 보고서를 원하고 조금 더 기다릴 수 있을 때 좋습니다.',
      'nl':
          'Een volledige partijstudie met rustige uitleg over kantelpunten, plannen, gemiste kansen, zetkwaliteit en concrete trainingspunten. Het beste wanneer je het rijkste rapport wilt en langer kunt wachten.',
      'ru':
          'Полный разбор партии с подробными объяснениями переломных моментов, планов, упущенных шансов, качества ходов и конкретных советов для тренировки. Подходит, если нужен самый подробный отчёт и можно подождать дольше.',
    },
    'Rapid coach': {
      'zh-Hans': '快速教练',
      'zh-Hant': '快速教練',
      'de': 'Schneller Coach',
      'es': 'Entrenador rápido',
      'fr': 'Coach rapide',
      'it': 'Coach rapido',
      'ja': '高速コーチ',
      'ko': '빠른 코치',
      'nl': 'Snelle coach',
      'ru': 'Быстрый тренер',
    },
    'Faster, focused review': {
      'zh-Hans': '更快、更聚焦的复盘',
      'zh-Hant': '更快、更聚焦的覆盤',
      'de': 'Schnellere, fokussierte Analyse',
      'es': 'Revisión más rápida y centrada',
      'fr': 'Revue plus rapide et ciblée',
      'it': 'Revisione più rapida e mirata',
      'ja': 'より速く、焦点を絞ったレビュー',
      'ko': '더 빠르고 집중된 검토',
      'nl': 'Snellere, gerichte review',
      'ru': 'Более быстрый и сфокусированный разбор',
    },
    'About 30 sec': {
      'zh-Hans': '约 30 秒',
      'zh-Hant': '約 30 秒',
      'de': 'Ca. 30 Sek.',
      'es': 'Unos 30 s',
      'fr': 'Environ 30 s',
      'it': 'Circa 30 s',
      'ja': '約30秒',
      'ko': '약 30초',
      'nl': 'Ongeveer 30 sec',
      'ru': 'Около 30 с',
    },
    'Highlights the most important moments first, keeps explanations shorter, and gives clear next steps. Good for quickly understanding what changed the game.':
        {
      'zh-Hans': '优先突出最重要的时刻，解释更短，并给出清晰的下一步建议。适合快速理解这盘棋是如何变化的。',
      'zh-Hant': '優先突出最重要的時刻，解釋更短，並給出清晰的下一步建議。適合快速理解這盤棋是如何變化的。',
      'de':
          'Hebt die wichtigsten Momente zuerst hervor, hält Erklärungen kürzer und gibt klare nächste Schritte. Gut, um schnell zu verstehen, was die Partie verändert hat.',
      'es':
          'Destaca primero los momentos más importantes, mantiene las explicaciones más breves y da pasos siguientes claros. Bueno para entender rápido qué cambió la partida.',
      'fr':
          "Met d'abord en avant les moments les plus importants, garde les explications plus courtes et donne des prochaines étapes claires. Pratique pour comprendre vite ce qui a changé la partie.",
      'it':
          'Evidenzia prima i momenti più importanti, mantiene spiegazioni più brevi e offre passi successivi chiari. Utile per capire rapidamente cosa ha cambiato la partita.',
      'ja': '最も重要な場面を先に示し、説明は短めに、次に何をすべきかも分かりやすく伝えます。対局を素早く理解したいときに向いています。',
      'ko': '가장 중요한 순간을 먼저 보여주고 설명은 짧게, 다음 단계는 분명하게 제시합니다. 빠르게 이해하고 싶을 때 좋습니다.',
      'nl':
          'Toont eerst de belangrijkste momenten, houdt uitleg korter en geeft duidelijke volgende stappen. Goed om snel te begrijpen wat de partij veranderde.',
      'ru':
          'Сначала выделяет самые важные моменты, даёт более короткие объяснения и понятные следующие шаги. Полезно, чтобы быстро понять, что изменило партию.',
    },
    'Friendly guide': {
      'zh-Hans': '友好向导',
      'zh-Hant': '友善嚮導',
      'de': 'Freundlicher Guide',
      'es': 'Guía amable',
      'fr': 'Guide bienveillant',
      'it': 'Guida amichevole',
      'ja': 'やさしいガイド',
      'ko': '친절한 가이드',
      'nl': 'Vriendelijke gids',
      'ru': 'Дружелюбный наставник',
    },
    'Beginner and kid friendly': {
      'zh-Hans': '适合初学者和小朋友',
      'zh-Hant': '適合初學者和小朋友',
      'de': 'Für Einsteiger und Kinder geeignet',
      'es': 'Ideal para principiantes y niños',
      'fr': 'Adapté aux débutants et aux enfants',
      'it': 'Adatto a principianti e bambini',
      'ja': '初心者や子ども向け',
      'ko': '초보자와 어린이에게 친화적',
      'nl': 'Geschikt voor beginners en kinderen',
      'ru': 'Подходит для новичков и детей',
    },
    'Guided': {
      'zh-Hans': '引导式',
      'zh-Hant': '引導式',
      'de': 'Angeleitet',
      'es': 'Guiado',
      'fr': 'Guidé',
      'it': 'Guidato',
      'ja': 'ガイド付き',
      'ko': '안내형',
      'nl': 'Begeleid',
      'ru': 'С подсказками',
    },
    'Uses plain language, encouragement, and guiding questions. It explains ideas gently so newer players can understand mistakes, strong moves, and better habits.':
        {
      'zh-Hans': '使用通俗语言、鼓励和引导式问题，温和地解释概念，帮助新手理解失误、强手和更好的习惯。',
      'zh-Hant': '使用通俗語言、鼓勵和引導式問題，溫和地解釋概念，幫助新手理解失誤、強手和更好的習慣。',
      'de':
          'Verwendet einfache Sprache, Ermutigung und leitende Fragen. Ideen werden sanft erklärt, damit neue Spieler Fehler, starke Züge und bessere Gewohnheiten verstehen.',
      'es':
          'Usa lenguaje sencillo, ánimo y preguntas guiadas. Explica las ideas con suavidad para que los jugadores nuevos entiendan errores, buenas jugadas y mejores hábitos.',
      'fr':
          'Utilise un langage simple, des encouragements et des questions guidées. Les idées sont expliquées en douceur pour aider les nouveaux joueurs à comprendre les erreurs, les bons coups et de meilleures habitudes.',
      'it':
          'Usa linguaggio semplice, incoraggiamento e domande guidate. Spiega le idee con delicatezza, così i nuovi giocatori capiscono errori, mosse forti e abitudini migliori.',
      'ja':
          'やさしい言葉、励まし、誘導する質問を使います。考え方をやわらかく説明し、新しいプレイヤーがミス、強い手、良い習慣を理解しやすくします。',
      'ko':
          '쉬운 언어, 격려, 안내 질문을 사용합니다. 개념을 부드럽게 설명해 새 플레이어가 실수, 좋은 수, 더 나은 습관을 이해하도록 돕습니다.',
      'nl':
          'Gebruikt eenvoudige taal, aanmoediging en begeleidende vragen. Ideeen worden rustig uitgelegd zodat nieuwe spelers fouten, sterke zetten en betere gewoontes begrijpen.',
      'ru':
          'Использует простой язык, поддержку и наводящие вопросы. Мягко объясняет идеи, чтобы новым игрокам было проще понять ошибки, сильные ходы и лучшие привычки.',
    },
    'Summary in progress': {
      'zh-Hans': '总结生成中',
      'zh-Hant': '總結生成中',
      'de': 'Zusammenfassung läuft',
      'es': 'Resumen en curso',
      'fr': 'Résumé en cours',
      'it': 'Riepilogo in corso',
      'ja': '要約を生成中',
      'ko': '요약 생성 중',
      'nl': 'Samenvatting bezig',
      'ru': 'Сводка создаётся',
    },
    'The Grandeur summary is still being generated. The full-game summary will appear here when the report is ready.':
        {
      'zh-Hans': 'Grandeur 总结仍在生成中。报告准备好后，这里会显示全局总结。',
      'zh-Hant': 'Grandeur 總結仍在生成中。報告準備好後，這裡會顯示全局總結。',
      'de':
          'Die Grandeur-Zusammenfassung wird noch erstellt. Sobald der Bericht bereit ist, erscheint hier die Zusammenfassung der ganzen Partie.',
      'es':
          'El resumen de Grandeur aún se está generando. Cuando el informe esté listo, aparecerá aquí el resumen de toda la partida.',
      'fr':
          'Le résumé Grandeur est encore en génération. Quand le rapport sera prêt, le résumé complet de la partie apparaîtra ici.',
      'it':
          "Il riepilogo Grandeur è ancora in generazione. Quando il report sarà pronto, qui apparirà il riepilogo dell'intera partita.",
      'ja': 'Grandeur の要約はまだ生成中です。レポートが準備できると、ここに全体の要約が表示されます。',
      'ko': 'Grandeur 요약은 아직 생성 중입니다. 보고서가 준비되면 여기에서 전체 요약을 볼 수 있습니다.',
      'nl':
          'De Grandeur-samenvatting wordt nog gemaakt. Zodra het rapport klaar is, verschijnt hier de samenvatting van de hele partij.',
      'ru':
          'Сводка Grandeur еще создается. Когда отчет будет готов, здесь появится сводка всей партии.',
    },
    'Review a full PGN with Stockfish, Maia, and Grandeur to find strong moves, weak moves, turning points, and understand the game.':
        {
      'zh-Hans':
          '\u7528 Stockfish\u3001Maia \u548c Grandeur \u5206\u6790\u5168\u76d8\u68cb\u5c40\uff0c\u627e\u51fa\u5f3a\u624b\u3001\u5f31\u624b\u548c\u8f6c\u6298\u70b9\uff0c\u5e2e\u52a9\u4f60\u66f4\u597d\u7406\u89e3\u68cb\u5c40\u3002',
      'zh-Hant':
          '\u7528 Stockfish\u3001Maia \u548c Grandeur \u5206\u6790\u5168\u76e4\u68cb\u5c40\uff0c\u627e\u51fa\u5f37\u624b\u3001\u5f31\u624b\u548c\u8f49\u6298\u9ede\uff0c\u5e6b\u52a9\u4f60\u66f4\u597d\u7406\u89e3\u68cb\u5c40\u3002',
      'de':
          'Analysiere eine vollstaendige PGN mit Stockfish, Maia und Grandeur, um starke Zuege, schwache Zuege und Wendepunkte zu finden und die Partie besser zu verstehen.',
      'es':
          'Analiza una PGN completa con Stockfish, Maia y Grandeur para encontrar jugadas fuertes, jugadas debiles, puntos de giro y entender mejor la partida.',
      'fr':
          'Analyse une PGN complete avec Stockfish, Maia et Grandeur pour trouver les bons coups, les coups faibles, les tournants et mieux comprendre la partie.',
      'it':
          'Analizza un PGN completo con Stockfish, Maia e Grandeur per trovare mosse forti, mosse deboli, momenti chiave e capire meglio la partita.',
      'ja':
          'Stockfish\u3001Maia\u3001Grandeur \u3067 PGN \u5168\u4f53\u3092\u89e3\u6790\u3057\u3001\u597d\u624b\u3001\u60aa\u624b\u3001\u8ee2\u6298\u70b9\u3092\u898b\u3064\u3051\u3066\u5bfe\u5c40\u3092\u3088\u308a\u6df1\u304f\u7406\u89e3\u3057\u307e\u3059\u3002',
      'ko':
          'Stockfish, Maia, Grandeur\ub85c \uc804\uccb4 PGN\uc744 \ubd84\uc11d\ud574 \uac15\ud55c \uc218, \uc57d\ud55c \uc218, \uc804\ud658\uc810\uc744 \ucc3e\uace0 \ub300\uad6d\uc744 \ub354 \uc798 \uc774\ud574\ud569\ub2c8\ub2e4.',
      'nl':
          'Analyseer een volledige PGN met Stockfish, Maia en Grandeur om sterke zetten, zwakke zetten en kantelpunten te vinden en de partij beter te begrijpen.',
      'ru':
          '\u0410\u043d\u0430\u043b\u0438\u0437\u0438\u0440\u0443\u0439\u0442\u0435 \u0432\u0441\u044e PGN \u0441 Stockfish, Maia \u0438 Grandeur, \u0447\u0442\u043e\u0431\u044b \u043d\u0430\u0439\u0442\u0438 \u0441\u0438\u043b\u044c\u043d\u044b\u0435 \u0445\u043e\u0434\u044b, \u0441\u043b\u0430\u0431\u044b\u0435 \u0445\u043e\u0434\u044b, \u043f\u0435\u0440\u0435\u043b\u043e\u043c\u043d\u044b\u0435 \u043c\u043e\u043c\u0435\u043d\u0442\u044b \u0438 \u043b\u0443\u0447\u0448\u0435 \u043f\u043e\u043d\u044f\u0442\u044c \u043f\u0430\u0440\u0442\u0438\u044e.',
    },
    'Live analysis': {
      'zh-Hans': '\u5b9e\u65f6\u5206\u6790',
      'zh-Hant': '\u5373\u6642\u5206\u6790',
      'de': 'Live-Analyse',
      'es': 'Analisis en vivo',
      'fr': 'Analyse en direct',
      'it': 'Analisi live',
      'ja': '\u30e9\u30a4\u30d6\u89e3\u6790',
      'ko': '\uc2e4\uc2dc\uac04 \ubd84\uc11d',
      'nl': 'Live analyse',
      'ru':
          '\u0410\u043d\u0430\u043b\u0438\u0437 \u0432 \u0440\u0435\u0430\u043b\u044c\u043d\u043e\u043c \u0432\u0440\u0435\u043c\u0435\u043d\u0438',
    },
    'Voice moves': {
      'zh-Hans': '\u8bed\u97f3\u8d70\u68cb',
      'zh-Hant': '\u8a9e\u97f3\u8d70\u68cb',
    },
    'Use your voice to control piece movement on Chessnut Move.': {
      'zh-Hans':
          '\u7528\u58f0\u97f3\u63a7\u5236 Chessnut Move \u4e0a\u7684\u68cb\u5b50\u79fb\u52a8\u3002',
      'zh-Hant':
          '\u7528\u8072\u97f3\u63a7\u5236 Chessnut Move \u4e0a\u7684\u68cb\u5b50\u79fb\u52d5\u3002',
    },
    'Speech language': {
      'zh-Hans': '\u8bed\u97f3\u8bed\u79cd',
      'zh-Hant': '\u8a9e\u97f3\u8a9e\u7a2e',
    },
    'Auto': {
      'zh-Hans': '\u81ea\u52a8',
      'zh-Hant': '\u81ea\u52d5',
    },
    'Sound effects': {
      'zh-Hans': '音效',
      'zh-Hant': '音效',
      'de': 'Soundeffekte',
      'es': 'Efectos de sonido',
      'fr': 'Effets sonores',
      'it': 'Effetti sonori',
      'ja': 'サウンド効果',
      'ko': '효과음',
      'nl': 'Geluidseffecten',
      'ru': 'Звуковые эффекты',
    },
    'Master switch for all app sounds': {
      'zh-Hans': '控制 App 所有声音的总开关',
      'zh-Hant': '控制 App 所有聲音的總開關',
      'de': 'Hauptschalter fuer alle App-Toene',
      'es': 'Interruptor general para todos los sonidos de la app',
      'fr': 'Interrupteur general de tous les sons de l app',
      'it': 'Interruttore generale per tutti i suoni dell app',
      'ja': 'アプリ内のすべての音のメインスイッチ',
      'ko': '앱의 모든 소리를 제어하는 전체 스위치',
      'nl': 'Hoofdschakelaar voor alle appgeluiden',
      'ru': 'Главный переключатель всех звуков приложения',
    },
    'From/to voice': {
      'zh-Hans': '起止格语音',
      'zh-Hant': '起止格語音',
      'de': 'Von-/nach-Feld ansagen',
      'es': 'Voz de origen/destino',
      'fr': 'Voix case depart/arrivee',
      'it': 'Voce da/a casa',
      'ja': '移動元/移動先の音声',
      'ko': '출발/도착 칸 음성',
      'nl': 'Van/naar-spraak',
      'ru': 'Озвучивание полей от/до',
    },
    'Speak opponent move squares, such as e7 to e5': {
      'zh-Hans': '播报对手走棋格，例如 e7 到 e5',
      'zh-Hant': '播報對手走棋格，例如 e7 到 e5',
      'de': 'Felder des Gegnerzugs ansagen, z. B. e7 nach e5',
      'es': 'Anuncia las casillas del rival, por ejemplo e7 a e5',
      'fr': 'Annonce les cases du coup adverse, par exemple e7 vers e5',
      'it': 'Annuncia le case della mossa avversaria, ad esempio e7 a e5',
      'ja': '相手の着手のマスを読み上げます。例: e7 から e5',
      'ko': '상대 수의 칸을 읽어 줍니다. 예: e7에서 e5',
      'nl': 'Spreekt de velden van de tegenzet uit, zoals e7 naar e5',
      'ru': 'Озвучивает поля хода соперника, например e7 на e5',
    },
    'Move sounds': {
      'zh-Hans': '走棋音效',
      'zh-Hant': '走棋音效',
      'de': 'Zugtoene',
      'es': 'Sonidos de jugada',
      'fr': 'Sons des coups',
      'it': 'Suoni delle mosse',
      'ja': '着手音',
      'ko': '수 효과음',
      'nl': 'Zetgeluiden',
      'ru': 'Звуки ходов',
    },
    'Play move, capture, and check effects': {
      'zh-Hans': '播放走棋、吃子和将军音效',
      'zh-Hant': '播放走棋、吃子和將軍音效',
      'de': 'Zug-, Schlag- und Schachtoene abspielen',
      'es': 'Reproduce efectos de jugada, captura y jaque',
      'fr': 'Joue les sons de coup, capture et echec',
      'it': 'Riproduce effetti di mossa, cattura e scacco',
      'ja': '着手、駒取り、チェックの効果音を再生します',
      'ko': '착수, 잡기, 체크 효과음을 재생합니다',
      'nl': 'Speelt zet-, slag- en schaakgeluiden af',
      'ru': 'Воспроизводит звуки хода, взятия и шаха',
    },
    'Result sounds': {
      'zh-Hans': '结果音效',
      'zh-Hant': '結果音效',
      'de': 'Ergebnistoene',
      'es': 'Sonidos de resultado',
      'fr': 'Sons de resultat',
      'it': 'Suoni del risultato',
      'ja': '結果音',
      'ko': '결과 효과음',
      'nl': 'Resultaatgeluiden',
      'ru': 'Звуки результата',
    },
    'Play victory, defeat, and draw sounds': {
      'zh-Hans': '播放胜利、失败和平局音效',
      'zh-Hant': '播放勝利、失敗和平局音效',
      'de': 'Sieg-, Niederlagen- und Remistoene abspielen',
      'es': 'Reproduce sonidos de victoria, derrota y tablas',
      'fr': 'Joue les sons de victoire, defaite et nulle',
      'it': 'Riproduce suoni di vittoria, sconfitta e patta',
      'ja': '勝利、敗北、引き分けの音を再生します',
      'ko': '승리, 패배, 무승부 소리를 재생합니다',
      'nl': 'Speelt winst-, verlies- en remisegeluiden af',
      'ru': 'Воспроизводит звуки победы, поражения и ничьей',
    },
    'Key action sounds': {
      'zh-Hans': '关键操作音效',
      'zh-Hant': '關鍵操作音效',
      'de': 'Toene fuer Hauptaktionen',
      'es': 'Sonidos de acciones clave',
      'fr': 'Sons des actions cles',
      'it': 'Suoni delle azioni chiave',
      'ja': '主要操作音',
      'ko': '주요 동작 효과음',
      'nl': 'Geluiden voor belangrijke acties',
      'ru': 'Звуки ключевых действий',
    },
    'Play game start, hint, and confirm sounds': {
      'zh-Hans': '播放开局、提示和确认音效',
      'zh-Hant': '播放開局、提示和確認音效',
      'de': 'Spielstart-, Hinweis- und Bestaetigungstoene abspielen',
      'es': 'Reproduce sonidos de inicio, pista y confirmacion',
      'fr': 'Joue les sons de debut, indice et confirmation',
      'it': 'Riproduce suoni di avvio, suggerimento e conferma',
      'ja': '対局開始、ヒント、確認の音を再生します',
      'ko': '대국 시작, 힌트, 확인 소리를 재생합니다',
      'nl': 'Speelt start-, hint- en bevestigingsgeluiden af',
      'ru': 'Воспроизводит звуки начала игры, подсказки и подтверждения',
    },
    'Clock Switch': {
      'zh-Hans': '棋钟开关',
      'zh-Hant': '棋鐘開關',
      'de': 'Uhrschalter',
      'es': 'Interruptor del reloj',
      'fr': 'Bouton de pendule',
      'it': 'Interruttore orologio',
      'ja': 'クロックスイッチ',
      'ko': '시계 스위치',
      'nl': 'Klokschakelaar',
      'ru': 'Переключатель часов',
    },
    'Automatic switch press': {
      'zh-Hans': '自动按钟',
      'zh-Hant': '自動按鐘',
      'de': 'Automatischer Tastendruck',
      'es': 'Pulsacion automatica',
      'fr': 'Appui automatique',
      'it': 'Pressione automatica',
      'ja': '自動クロック押下',
      'ko': '자동 시계 누르기',
      'nl': 'Automatisch indrukken',
      'ru': 'Автоматическое нажатие',
    },
    'Choose when the clock hardware switch is pressed for you.': {
      'zh-Hans': '选择何时由系统代你按下棋钟硬件开关。',
      'zh-Hant': '選擇何時由系統代你按下棋鐘硬體開關。',
      'de':
          'Waehle, wann der Hardware-Schalter der Uhr fuer dich gedrueckt wird.',
      'es': 'Elige cuando se pulsa por ti el interruptor fisico del reloj.',
      'fr':
          'Choisissez quand le bouton materiel de la pendule est appuye pour vous.',
      'it':
          'Scegli quando viene premuto per te il pulsante fisico dell orologio.',
      'ja': 'クロックの物理スイッチをいつ自動で押すかを選びます。',
      'ko': '시계 하드웨어 스위치를 언제 대신 누를지 선택합니다.',
      'nl': 'Kies wanneer de fysieke klokschakelaar voor jou wordt ingedrukt.',
      'ru':
          'Выберите, когда аппаратная кнопка часов будет нажиматься автоматически.',
    },
    'Opponent move mode': {
      'zh-Hans': '对手走棋模式',
      'zh-Hant': '對手走棋模式',
      'de': 'Modus fuer Gegnerzug',
      'es': 'Modo de movimiento rival',
      'fr': 'Mode coup adverse',
      'it': 'Modalita mossa avversaria',
      'ja': '相手の着手モード',
      'ko': '상대 수 모드',
      'nl': 'Modus voor tegenzet',
      'ru': 'Режим хода соперника',
    },
    'Controls AI and online opponent clock presses.': {
      'zh-Hans': '控制 AI 和线上对手走棋后的按钟方式。',
      'zh-Hant': '控制 AI 和線上對手走棋後的按鐘方式。',
      'de': 'Steuert Uhrdruecke nach Zuegen von AI und Online-Gegnern.',
      'es': 'Controla las pulsaciones tras jugadas de AI y rivales online.',
      'fr': 'Controle les appuis apres les coups AI et adverses en ligne.',
      'it': 'Controlla le pressioni dopo le mosse AI e degli avversari online.',
      'ja': 'AI とオンライン相手の着手後のクロック押下を制御します。',
      'ko': 'AI 및 온라인 상대의 수 이후 시계 누르기를 제어합니다.',
      'nl': 'Regelt klokdrukken na zetten van AI en online tegenstanders.',
      'ru': 'Управляет нажатием часов после ходов AI и онлайн-соперника.',
    },
    'Aggressive': {
      'zh-Hans': '快速',
      'zh-Hant': '快速',
      'de': 'Schnell',
      'es': 'Rapido',
      'fr': 'Rapide',
      'it': 'Rapida',
      'ja': '高速',
      'ko': '빠름',
      'nl': 'Snel',
      'ru': 'Быстро',
    },
    'Leisure': {
      'zh-Hans': '稳妥',
      'zh-Hant': '穩妥',
      'de': 'Sicher',
      'es': 'Seguro',
      'fr': 'Securise',
      'it': 'Sicura',
      'ja': '安定',
      'ko': '안정',
      'nl': 'Zeker',
      'ru': 'Надежно',
    },
    'Aggressive mode': {
      'zh-Hans': '快速模式',
      'zh-Hant': '快速模式',
      'de': 'Schneller Modus',
      'es': 'Modo rapido',
      'fr': 'Mode rapide',
      'it': 'Modalita rapida',
      'ja': '高速モード',
      'ko': '빠른 모드',
      'nl': 'Snelle modus',
      'ru': 'Быстрый режим',
    },
    'Press as soon as the opponent move arrives.': {
      'zh-Hans': '对手走法到达后立即按钟。',
      'zh-Hant': '對手走法到達後立即按鐘。',
      'de': 'Drueckt, sobald der Gegnerzug eintrifft.',
      'es': 'Pulsa en cuanto llega la jugada rival.',
      'fr': 'Appuie des que le coup adverse arrive.',
      'it': 'Premi appena arriva la mossa avversaria.',
      'ja': '相手の着手が届いたらすぐ押します。',
      'ko': '상대 수가 도착하면 바로 누릅니다.',
      'nl': 'Drukt zodra de tegenzet binnenkomt.',
      'ru': 'Нажимает сразу после получения хода соперника.',
    },
    'Leisure mode': {
      'zh-Hans': '稳妥模式',
      'zh-Hant': '穩妥模式',
      'de': 'Sicherer Modus',
      'es': 'Modo seguro',
      'fr': 'Mode securise',
      'it': 'Modalita sicura',
      'ja': '安定モード',
      'ko': '안정 모드',
      'nl': 'Zekere modus',
      'ru': 'Надежный режим',
    },
    'Wait until the board matches the opponent move.': {
      'zh-Hans': '等待棋盘与对手走法一致后再按钟。',
      'zh-Hant': '等待棋盤與對手走法一致後再按鐘。',
      'de': 'Wartet, bis das Brett dem Gegnerzug entspricht.',
      'es': 'Espera hasta que el tablero coincida con la jugada rival.',
      'fr': 'Attend que le plateau corresponde au coup adverse.',
      'it': 'Attende che la scacchiera corrisponda alla mossa avversaria.',
      'ja': '盤面が相手の着手と一致するまで待ちます。',
      'ko': '보드가 상대 수와 일치할 때까지 기다립니다.',
      'nl': 'Wacht tot het bord overeenkomt met de tegenzet.',
      'ru': 'Ждет, пока доска совпадет с ходом соперника.',
    },
    'Confirm moves with switch': {
      'zh-Hans': '用开关确认走子',
      'zh-Hant': '用開關確認走子',
      'de': 'Zuege mit Schalter bestaetigen',
      'es': 'Confirmar jugadas con el interruptor',
      'fr': 'Confirmer les coups avec le bouton',
      'it': 'Conferma mosse con interruttore',
      'ja': 'スイッチで着手を確認',
      'ko': '스위치로 수 확인',
      'nl': 'Zetten bevestigen met schakelaar',
      'ru': 'Подтверждать ходы переключателем',
    },
    'Hold board moves until the clock switch is pressed.': {
      'zh-Hans': '棋盘走子会先等待，直到按下棋钟开关后再确认。',
      'zh-Hant': '棋盤走子會先等待，直到按下棋鐘開關後再確認。',
      'de': 'Brettzuege warten, bis der Uhrschalter gedrueckt wird.',
      'es': 'Retiene las jugadas del tablero hasta pulsar el reloj.',
      'fr':
          'Garde les coups du plateau en attente jusqu a l appui sur la pendule.',
      'it': 'Mantiene le mosse in attesa finche si preme l orologio.',
      'ja': 'クロックスイッチを押すまで盤上の着手を保留します。',
      'ko': '시계 스위치를 누를 때까지 보드 수를 보류합니다.',
      'nl': 'Houdt bordzetten vast tot de klokschakelaar is ingedrukt.',
      'ru': 'Удерживает ходы доски до нажатия переключателя часов.',
    },
    'Clock switch details': {
      'zh-Hans': '棋钟开关说明',
      'zh-Hant': '棋鐘開關說明',
      'de': 'Details zum Uhrschalter',
      'es': 'Detalles del interruptor del reloj',
      'fr': 'Details du bouton de pendule',
      'it': 'Dettagli interruttore orologio',
      'ja': 'クロックスイッチの詳細',
      'ko': '시계 스위치 설명',
      'nl': 'Details van klokschakelaar',
      'ru': 'Сведения о переключателе часов',
    },
    'Mandarin': {
      'zh-Hans': '\u666e\u901a\u8bdd',
      'zh-Hant': '\u666e\u901a\u8a71',
    },
    'Cantonese': {
      'zh-Hans': '\u7ca4\u8bed',
      'zh-Hant': '\u7cb5\u8a9e',
    },
    'Account settings': {
      'zh-Hans': '账户设置',
      'zh-Hant': '帳戶設定',
      'de': 'Kontoeinstellungen',
      'es': 'Ajustes de cuenta',
      'fr': 'Paramètres du compte',
      'it': 'Impostazioni account',
      'ja': 'アカウント設定',
      'ko': '계정 설정',
      'nl': 'Accountinstellingen',
      'ru': 'Настройки аккаунта',
    },
    'Off': {
      'zh-Hans': '关闭',
      'zh-Hant': '關閉',
      'de': 'Aus',
      'es': 'Desactivado',
      'fr': 'Désactivé',
      'it': 'Disattivato',
      'ja': 'オフ',
      'ko': '끄기',
      'nl': 'Uit',
      'ru': 'Выкл.',
    },
    'Online': {
      'zh-Hans': '在线',
      'zh-Hant': '線上',
      'de': 'Online',
      'es': 'En línea',
      'fr': 'En ligne',
      'it': 'Online',
      'ja': 'オンライン',
      'ko': '온라인',
      'nl': 'Online',
      'ru': 'Онлайн',
    },
    'Local': {
      'zh-Hans': '本地',
      'zh-Hant': '本機',
      'de': 'Lokal',
      'es': 'Local',
      'fr': 'Local',
      'it': 'Locale',
      'ja': 'ローカル',
      'ko': '로컬',
      'nl': 'Lokaal',
      'ru': 'Локально',
    },
    'Opponent move only': {
      'zh-Hans': '仅对手走棋后自动',
      'zh-Hant': '僅對手走棋後自動',
      'de': 'Nur nach Gegnerzug',
      'es': 'Solo tras mover el rival',
      'fr': 'Après le coup adverse seulement',
      'it': 'Solo dopo la mossa avversaria',
      'ja': '相手の着手後のみ',
      'ko': '상대 수 이후에만',
      'nl': 'Alleen na zet van tegenstander',
      'ru': 'Только после хода соперника',
    },
    'Both sides': {
      'zh-Hans': '双方走棋后都自动',
      'zh-Hant': '雙方走棋後都自動',
      'de': 'Beide Seiten',
      'es': 'Ambos lados',
      'fr': 'Les deux camps',
      'it': 'Entrambi i lati',
      'ja': '両側',
      'ko': '양쪽 모두',
      'nl': 'Beide kanten',
      'ru': 'Обе стороны',
    },
    'Modern motion': {
      'zh-Hans': '现代动效',
      'zh-Hant': '現代動效',
      'de': 'Moderne Animation',
      'es': 'Animación moderna',
      'fr': 'Animations modernes',
      'it': 'Animazioni moderne',
      'ja': 'モダンモーション',
      'ko': '모던 모션',
      'nl': 'Moderne beweging',
      'ru': 'Современная анимация',
    },
    'Classic chess club': {
      'zh-Hans': '经典棋社',
      'zh-Hant': '經典棋社',
      'de': 'Klassischer Schachclub',
      'es': 'Club de ajedrez clásico',
      'fr': 'Club d’échecs classique',
      'it': 'Circolo di scacchi classico',
      'ja': 'クラシックなチェスクラブ',
      'ko': '클래식 체스 클럽',
      'nl': 'Klassieke schaakclub',
      'ru': 'Классический шахматный клуб',
    },
    'Visual effects improve motion and polish, but can feel slower on older devices.':
        {
      'zh-Hans': '视觉效果会提升动效和细节质感，但在较旧设备上可能感觉更慢。',
      'zh-Hant': '視覺效果會提升動效和細節質感，但在較舊裝置上可能感覺較慢。',
      'de':
          'Visuelle Effekte verbessern Bewegung und Feinschliff, können sich auf älteren Geräten aber langsamer anfühlen.',
      'es':
          'Los efectos visuales mejoran el movimiento y el acabado, pero pueden sentirse más lentos en dispositivos antiguos.',
      'fr':
          'Les effets visuels améliorent l’animation et la finition, mais peuvent sembler plus lents sur les anciens appareils.',
      'it':
          'Gli effetti visivi migliorano movimento e finitura, ma sui dispositivi meno recenti possono sembrare più lenti.',
      'ja': '視覚効果で動きと質感は向上しますが、古い端末では遅く感じることがあります。',
      'ko': '시각 효과는 모션과 완성도를 높이지만 오래된 기기에서는 느리게 느껴질 수 있습니다.',
      'nl':
          'Visuele effecten maken beweging en afwerking mooier, maar kunnen op oudere apparaten trager aanvoelen.',
      'ru':
          'Визуальные эффекты улучшают движение и полировку, но на старых устройствах могут ощущаться медленнее.',
    },
    'Higher contrast, calmer motion, larger touch targets.': {
      'zh-Hans': '更高对比度、更克制的动效、更大的触控区域。',
      'zh-Hant': '更高對比度、更克制的動效、更大的觸控區域。',
      'de': 'Höherer Kontrast, ruhigere Bewegung, größere Touch-Flächen.',
      'es':
          'Mayor contraste, movimiento más calmado y zonas táctiles más grandes.',
      'fr':
          'Contraste plus élevé, animations plus calmes, zones tactiles plus grandes.',
      'it': 'Contrasto più alto, movimenti più calmi, aree touch più grandi.',
      'ja': '高いコントラスト、控えめな動き、大きなタップ領域。',
      'ko': '더 높은 대비, 더 차분한 모션, 더 큰 터치 영역.',
      'nl': 'Hoger contrast, rustigere beweging, grotere aanraakvlakken.',
      'ru': 'Выше контраст, спокойнее анимация, крупнее зоны касания.',
    },
    'Sign in to sync points and profile.': {
      'zh-Hans': '登录后同步积分和个人资料。',
      'zh-Hant': '登入後同步積分和個人資料。',
      'de': 'Melde dich an, um Punkte und Profil zu synchronisieren.',
      'es': 'Inicia sesión para sincronizar puntos y perfil.',
      'fr': 'Connectez-vous pour synchroniser les points et le profil.',
      'it': 'Accedi per sincronizzare punti e profilo.',
      'ja': 'ポイントとプロフィールを同期するにはサインインしてください。',
      'ko': '포인트와 프로필을 동기화하려면 로그인하세요.',
      'nl': 'Log in om punten en profiel te synchroniseren.',
      'ru': 'Войдите, чтобы синхронизировать очки и профиль.',
    },
    'Sign in to sync points, membership, and ledger.': {
      'zh-Hans': '登录后同步积分、会员和流水。',
      'zh-Hant': '登入後同步積分、會員和明細。',
      'de':
          'Melde dich an, um Punkte, Mitgliedschaft und Verlauf zu synchronisieren.',
      'es': 'Inicia sesión para sincronizar puntos, membresía y registro.',
      'fr':
          'Connectez-vous pour synchroniser points, abonnement et historique.',
      'it': 'Accedi per sincronizzare punti, abbonamento e registro.',
      'ja': 'ポイント、メンバーシップ、明細を同期するにはサインインしてください。',
      'ko': '포인트, 멤버십, 내역을 동기화하려면 로그인하세요.',
      'nl': 'Log in om punten, lidmaatschap en overzicht te synchroniseren.',
      'ru': 'Войдите, чтобы синхронизировать очки, подписку и историю.',
    },
    'Loading account wallet...': {
      'zh-Hans': '正在加载账户钱包...',
      'zh-Hant': '正在載入帳戶錢包...',
      'de': 'Account-Wallet wird geladen...',
      'es': 'Cargando monedero de la cuenta...',
      'fr': 'Chargement du portefeuille du compte...',
      'it': 'Caricamento wallet dell’account...',
      'ja': 'アカウントウォレットを読み込み中...',
      'ko': '계정 지갑을 불러오는 중...',
      'nl': 'Accountwallet laden...',
      'ru': 'Загрузка кошелька аккаунта...',
    },
    'Wallet unavailable.': {
      'zh-Hans': '钱包不可用。',
      'zh-Hant': '錢包不可用。',
      'de': 'Wallet nicht verfügbar.',
      'es': 'Monedero no disponible.',
      'fr': 'Portefeuille indisponible.',
      'it': 'Wallet non disponibile.',
      'ja': 'ウォレットを利用できません。',
      'ko': '지갑을 사용할 수 없습니다.',
      'nl': 'Wallet niet beschikbaar.',
      'ru': 'Кошелёк недоступен.',
    },
    'daily reward claimed today': {
      'zh-Hans': '今日每日奖励已领取',
      'zh-Hant': '今日每日獎勵已領取',
      'de': 'Tagesbelohnung heute abgeholt',
      'es': 'recompensa diaria reclamada hoy',
      'fr': 'récompense quotidienne récupérée aujourd’hui',
      'it': 'ricompensa giornaliera riscossa oggi',
      'ja': '本日のデイリー報酬は受け取り済み',
      'ko': '오늘 일일 보상 수령 완료',
      'nl': 'dagelijkse beloning vandaag geclaimd',
      'ru': 'ежедневная награда сегодня получена',
    },
    'daily reward available': {
      'zh-Hans': '每日奖励可领取',
      'zh-Hant': '每日獎勵可領取',
      'de': 'Tagesbelohnung verfügbar',
      'es': 'recompensa diaria disponible',
      'fr': 'récompense quotidienne disponible',
      'it': 'ricompensa giornaliera disponibile',
      'ja': 'デイリー報酬を受け取れます',
      'ko': '일일 보상 수령 가능',
      'nl': 'dagelijkse beloning beschikbaar',
      'ru': 'ежедневная награда доступна',
    },
    'points': {
      'zh-Hans': '积分',
      'zh-Hant': '積分',
      'de': 'Punkte',
      'es': 'puntos',
      'fr': 'points',
      'it': 'punti',
      'ja': 'ポイント',
      'ko': '포인트',
      'nl': 'punten',
      'ru': 'очки',
    },
    'pts': {
      'zh-Hans': '积分',
      'zh-Hant': '積分',
      'de': 'Pkt.',
      'es': 'pts',
      'fr': 'pts',
      'it': 'pt',
      'ja': 'pt',
      'ko': '점',
      'nl': 'ptn',
      'ru': 'очк.',
    },
    'Premium active / Grandeur and Model Builds unlimited': {
      'zh-Hans': 'Premium 已激活 / Grandeur 和模型构建不限量',
      'zh-Hant': 'Premium 已啟用 / Grandeur 和模型構建不限量',
      'de': 'Premium aktiv / Grandeur und Model Builds unbegrenzt',
      'es': 'Premium activo / Grandeur y Model Builds ilimitados',
      'fr': 'Premium actif / Grandeur et Model Builds illimités',
      'it': 'Premium attivo / Grandeur e Model Builds illimitati',
      'ja': 'Premium 有効 / Grandeur と Model Builds は無制限',
      'ko': 'Premium 활성화 / Grandeur 및 Model Builds 무제한',
      'nl': 'Premium actief / Grandeur en Model Builds onbeperkt',
      'ru': 'Premium активен / Grandeur и Model Builds без ограничений',
    },
    'Checked in today / Grandeur 100 / Model Build 500': {
      'zh-Hans': '今日已签到 / Grandeur 100 / Model Build 500',
      'zh-Hant': '今日已簽到 / Grandeur 100 / Model Build 500',
      'de': 'Heute eingecheckt / Grandeur 100 / Model Build 500',
      'es': 'Registro de hoy completado / Grandeur 100 / Model Build 500',
      'fr': 'Check-in effectué aujourd’hui / Grandeur 100 / Model Build 500',
      'it': 'Check-in effettuato oggi / Grandeur 100 / Model Build 500',
      'ja': '本日チェックイン済み / Grandeur 100 / Model Build 500',
      'ko': '오늘 체크인 완료 / Grandeur 100 / Model Build 500',
      'nl': 'Vandaag ingecheckt / Grandeur 100 / Model Build 500',
      'ru': 'Сегодня отмечено / Grandeur 100 / Model Build 500',
    },
    'Daily check-in available / Grandeur 100 / Model Build 500': {
      'zh-Hans': '每日签到可领取 / Grandeur 100 / Model Build 500',
      'zh-Hant': '每日簽到可領取 / Grandeur 100 / Model Build 500',
      'de': 'Täglicher Check-in verfügbar / Grandeur 100 / Model Build 500',
      'es': 'Registro diario disponible / Grandeur 100 / Model Build 500',
      'fr': 'Check-in quotidien disponible / Grandeur 100 / Model Build 500',
      'it': 'Check-in giornaliero disponibile / Grandeur 100 / Model Build 500',
      'ja': 'デイリーチェックイン可能 / Grandeur 100 / Model Build 500',
      'ko': '일일 체크인 가능 / Grandeur 100 / Model Build 500',
      'nl': 'Dagelijkse check-in beschikbaar / Grandeur 100 / Model Build 500',
      'ru': 'Доступна ежедневная отметка / Grandeur 100 / Model Build 500',
    },
    'Completed today': {
      'zh-Hans': '今日已完成',
      'zh-Hant': '今日已完成',
      'de': 'Heute erledigt',
      'es': 'Completado hoy',
      'fr': 'Terminé aujourd’hui',
      'it': 'Completato oggi',
      'ja': '本日完了',
      'ko': '오늘 완료',
      'nl': 'Vandaag voltooid',
      'ru': 'Сегодня выполнено',
    },
    'Done': {
      'zh-Hans': '完成',
      'zh-Hant': '完成',
      'de': 'Erledigt',
      'es': 'Hecho',
      'fr': 'Terminé',
      'it': 'Fatto',
      'ja': '完了',
      'ko': '완료',
      'nl': 'Klaar',
      'ru': 'Готово',
    },
    'Go': {
      'zh-Hans': '前往',
      'zh-Hant': '前往',
      'de': 'Los',
      'es': 'Ir',
      'fr': 'Aller',
      'it': 'Vai',
      'ja': '移動',
      'ko': '이동',
      'nl': 'Ga',
      'ru': 'Перейти',
    },
    'Claim': {
      'zh-Hans': '领取',
      'zh-Hant': '領取',
      'de': 'Abholen',
      'es': 'Reclamar',
      'fr': 'Récupérer',
      'it': 'Riscatta',
      'ja': '受け取る',
      'ko': '받기',
      'nl': 'Claimen',
      'ru': 'Получить',
    },
    'Claimed': {
      'zh-Hans': '已领取',
      'zh-Hant': '已領取',
      'de': 'Abgeholt',
      'es': 'Reclamado',
      'fr': 'Récupéré',
      'it': 'Riscattato',
      'ja': '受け取り済み',
      'ko': '수령 완료',
      'nl': 'Geclaimd',
      'ru': 'Получено',
    },
    'All daily tasks completed.': {
      'zh-Hans': '每日任务已全部完成。',
      'zh-Hant': '每日任務已全部完成。',
      'de': 'Alle täglichen Aufgaben sind erledigt.',
      'es': 'Todas las tareas diarias están completadas.',
      'fr': 'Toutes les tâches quotidiennes sont terminées.',
      'it': 'Tutte le attività giornaliere sono completate.',
      'ja': 'すべてのデイリータスクが完了しました。',
      'ko': '모든 일일 과제가 완료되었습니다.',
      'nl': 'Alle dagelijkse taken zijn voltooid.',
      'ru': 'Все ежедневные задания выполнены.',
    },
    'Sign in to claim points and keep your streak.': {
      'zh-Hans': '登录后领取积分并保持连续记录。',
      'zh-Hant': '登入後領取積分並保持連續紀錄。',
      'de': 'Melde dich an, um Punkte zu holen und deine Serie zu behalten.',
      'es': 'Inicia sesión para reclamar puntos y mantener tu racha.',
      'fr': 'Connectez-vous pour récupérer des points et garder votre série.',
      'it': 'Accedi per riscattare punti e mantenere la serie.',
      'ja': 'ポイントを受け取り、連続記録を維持するにはサインインしてください。',
      'ko': '포인트를 받고 연속 기록을 유지하려면 로그인하세요.',
      'nl': 'Log in om punten te claimen en je reeks vast te houden.',
      'ru': 'Войдите, чтобы получить очки и сохранить серию.',
    },
    'Check in and finish today\'s chess goals.': {
      'zh-Hans': '签到并完成今天的国际象棋目标。',
      'zh-Hant': '簽到並完成今天的國際象棋目標。',
      'de': 'Checke ein und erledige deine heutigen Schachziele.',
      'es': 'Regístrate y completa los objetivos de ajedrez de hoy.',
      'fr': 'Faites le check-in et terminez les objectifs d’échecs du jour.',
      'it': 'Fai il check-in e completa gli obiettivi di scacchi di oggi.',
      'ja': 'チェックインして、今日のチェス目標を完了しましょう。',
      'ko': '체크인하고 오늘의 체스 목표를 완료하세요.',
      'nl': 'Check in en voltooi de schaakdoelen van vandaag.',
      'ru': 'Отметьтесь и завершите сегодняшние шахматные цели.',
    },
    'Progress synced. Keep the streak moving.': {
      'zh-Hans': '进度已同步，继续保持连续记录。',
      'zh-Hant': '進度已同步，繼續保持連續紀錄。',
      'de': 'Fortschritt synchronisiert. Halte die Serie am Laufen.',
      'es': 'Progreso sincronizado. Mantén la racha activa.',
      'fr': 'Progression synchronisée. Gardez la série en route.',
      'it': 'Progressi sincronizzati. Continua la serie.',
      'ja': '進捗を同期しました。連続記録を続けましょう。',
      'ko': '진행 상황이 동기화되었습니다. 연속 기록을 이어가세요.',
      'nl': 'Voortgang gesynchroniseerd. Houd de reeks gaande.',
      'ru': 'Прогресс синхронизирован. Продолжайте серию.',
    },
    'Check-in ready': {
      'zh-Hans': '可签到',
      'zh-Hant': '可簽到',
      'de': 'Check-in bereit',
      'es': 'Registro listo',
      'fr': 'Check-in prêt',
      'it': 'Check-in pronto',
      'ja': 'チェックイン可能',
      'ko': '체크인 가능',
      'nl': 'Klaar om in te checken',
      'ru': 'Отметка доступна',
    },
    'Checked in today': {
      'zh-Hans': '今日已签到',
      'zh-Hant': '今日已簽到',
      'de': 'Heute eingecheckt',
      'es': 'Registrado hoy',
      'fr': 'Check-in effectué aujourd’hui',
      'it': 'Check-in effettuato oggi',
      'ja': '本日チェックイン済み',
      'ko': '오늘 체크인 완료',
      'nl': 'Vandaag ingecheckt',
      'ru': 'Сегодня отмечено',
    },
    'The check-in task refreshes at local noon, and still requires at least 24 hours since the last claim.':
        {
      'zh-Hans': '签到任务会在本地中午刷新，并且距离上次领取仍需至少 24 小时。',
      'zh-Hant': '簽到任務會在本地中午刷新，且距離上次領取仍需至少 24 小時。',
      'de':
          'Der Check-in wird mittags lokal erneuert und braucht weiter mindestens 24 Stunden seit der letzten Abholung.',
      'es':
          'La tarea de registro se renueva al mediodía local y requiere al menos 24 horas desde la última reclamación.',
      'fr':
          'La tâche de check-in se renouvelle à midi local et exige au moins 24 heures depuis la dernière récupération.',
      'it':
          'L’attività di check-in si aggiorna a mezzogiorno locale e richiede almeno 24 ore dall’ultimo riscatto.',
      'ja': 'チェックインタスクは現地時間の正午に更新され、前回の受け取りから少なくとも24時間が必要です。',
      'ko': '체크인 과제는 현지 정오에 갱신되며 마지막 수령 후 최소 24시간이 필요합니다.',
      'nl':
          'De check-in-taak ververst om lokale middag en vereist minstens 24 uur sinds de vorige claim.',
      'ru':
          'Задание отметки обновляется в местный полдень и требует минимум 24 часа с прошлого получения.',
    },
    'Come back after the next valid refresh window to claim again.': {
      'zh-Hans': '下一个有效刷新窗口后再回来领取。',
      'zh-Hant': '下一個有效刷新窗口後再回來領取。',
      'de': 'Komm nach dem nächsten gültigen Aktualisierungsfenster zurück.',
      'es':
          'Vuelve después de la próxima ventana válida para reclamar de nuevo.',
      'fr': 'Revenez après la prochaine fenêtre de renouvellement valide.',
      'it': 'Torna dopo la prossima finestra di aggiornamento valida.',
      'ja': '次の有効な更新タイミング後にもう一度受け取れます。',
      'ko': '다음 유효한 갱신 시간 이후에 다시 받으러 오세요.',
      'nl': 'Kom terug na het volgende geldige verversmoment.',
      'ru': 'Вернитесь после следующего допустимого окна обновления.',
    },
    'details': {
      'zh-Hans': '详情',
      'zh-Hant': '詳情',
      'de': 'Details',
      'es': 'detalles',
      'fr': 'détails',
      'it': 'dettagli',
      'ja': '詳細',
      'ko': '세부정보',
      'nl': 'details',
      'ru': 'подробнее',
    },
    'Select records to delete': {
      'zh-Hans': '选择要删除的记录',
      'zh-Hant': '選擇要刪除的記錄',
      'de': 'Zu löschende Einträge auswählen',
      'es': 'Selecciona registros para eliminar',
      'fr': 'Sélectionnez les parties à supprimer',
      'it': 'Seleziona i record da eliminare',
      'ja': '削除する記録を選択',
      'ko': '삭제할 기록 선택',
      'nl': 'Selecteer records om te verwijderen',
      'ru': 'Выберите записи для удаления',
    },
    'Delete selected records': {
      'zh-Hans': '删除所选记录',
      'zh-Hant': '刪除所選記錄',
      'de': 'Auswahl löschen',
      'es': 'Eliminar seleccionados',
      'fr': 'Supprimer la sélection',
      'it': 'Elimina selezionati',
      'ja': '選択した記録を削除',
      'ko': '선택한 기록 삭제',
      'nl': 'Selectie verwijderen',
      'ru': 'Удалить выбранные',
    },
    'Delete selected records?': {
      'zh-Hans': '删除所选记录？',
      'zh-Hant': '刪除所選記錄？',
      'de': 'Ausgewählte Einträge löschen?',
      'es': '¿Eliminar registros seleccionados?',
      'fr': 'Supprimer les parties sélectionnées ?',
      'it': 'Eliminare i record selezionati?',
      'ja': '選択した記録を削除しますか？',
      'ko': '선택한 기록을 삭제할까요?',
      'nl': 'Geselecteerde records verwijderen?',
      'ru': 'Удалить выбранные записи?',
    },
    'This removes the selected PGNs from your Chessnut account. This action cannot be undone.':
        {
      'zh-Hans': '这会从你的 Chessnut 账户中移除所选 PGN。此操作无法撤销。',
      'zh-Hant': '這會從你的 Chessnut 帳戶中移除所選 PGN。此操作無法復原。',
      'de':
          'Dies entfernt die ausgewählten PGNs aus deinem Chessnut Konto. Diese Aktion kann nicht rückgängig gemacht werden.',
      'es':
          'Esto elimina los PGNs seleccionados de tu cuenta de Chessnut. Esta acción no se puede deshacer.',
      'fr':
          'Cela supprime les PGNs sélectionnés de votre compte Chessnut. Cette action est irréversible.',
      'it':
          'Questo rimuove i PGNs selezionati dal tuo account Chessnut. L’azione non può essere annullata.',
      'ja': '選択した PGN が Chessnut アカウントから削除されます。この操作は元に戻せません。',
      'ko': '선택한 PGN이 Chessnut 계정에서 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
      'nl':
          'Dit verwijdert de geselecteerde PGNs uit je Chessnut account. Deze actie kan niet ongedaan worden gemaakt.',
      'ru':
          'Выбранные PGN будут удалены из вашей учетной записи Chessnut. Это действие нельзя отменить.',
    },
    'Selected record': {
      'zh-Hans': '已选记录',
      'zh-Hant': '已選記錄',
      'de': 'Ausgewählter Eintrag',
      'es': 'Registro seleccionado',
      'fr': 'Partie sélectionnée',
      'it': 'Record selezionato',
      'ja': '選択済みの記録',
      'ko': '선택된 기록',
      'nl': 'Geselecteerd record',
      'ru': 'Выбранная запись',
    },
    'Select record': {
      'zh-Hans': '选择记录',
      'zh-Hant': '選擇記錄',
      'de': 'Eintrag auswählen',
      'es': 'Seleccionar registro',
      'fr': 'Sélectionner la partie',
      'it': 'Seleziona record',
      'ja': '記録を選択',
      'ko': '기록 선택',
      'nl': 'Record selecteren',
      'ru': 'Выбрать запись',
    },
    'Sign out?': {
      'zh-Hans': '退出登录？',
      'zh-Hant': '登出？',
      'de': 'Abmelden?',
      'es': '¿Cerrar sesión?',
      'fr': 'Se déconnecter ?',
      'it': 'Uscire?',
      'ja': 'サインアウトしますか？',
      'ko': '로그아웃할까요?',
      'nl': 'Uitloggen?',
      'ru': 'Выйти?',
    },
    'You will return to the login screen. Your saved games remain on this device.':
        {
      'zh-Hans': '你将返回登录页面。已保存的棋局会保留在此设备上。',
      'zh-Hant': '你將返回登入畫面。已儲存的棋局會保留在此裝置上。',
      'de':
          'Du kehrst zum Anmeldebildschirm zurück. Deine gespeicherten Partien bleiben auf diesem Gerät.',
      'es':
          'Volverás a la pantalla de inicio de sesión. Tus partidas guardadas permanecerán en este dispositivo.',
      'fr':
          'Vous reviendrez à l’écran de connexion. Vos parties enregistrées restent sur cet appareil.',
      'it':
          'Tornerai alla schermata di accesso. Le partite salvate resteranno su questo dispositivo.',
      'ja': 'ログイン画面に戻ります。保存した対局はこのデバイスに残ります。',
      'ko': '로그인 화면으로 돌아갑니다. 저장된 게임은 이 기기에 그대로 남습니다.',
      'nl':
          'Je gaat terug naar het inlogscherm. Je opgeslagen partijen blijven op dit apparaat.',
      'ru':
          'Вы вернетесь на экран входа. Сохраненные партии останутся на этом устройстве.',
    },
    'Game still in progress': {
      'zh-Hans': '对局尚未结束',
      'zh-Hant': '對局尚未結束',
      'de': 'Partie läuft noch',
      'es': 'La partida sigue en curso',
      'fr': 'La partie est toujours en cours',
      'it': 'La partita è ancora in corso',
      'ja': '対局はまだ終了していません',
      'ko': '대국이 아직 끝나지 않았습니다',
      'nl': 'Partij is nog bezig',
      'ru': 'Партия ещё не завершена',
    },
    'Leave for now and continue later from Game Record, or resign to end the game as a loss.':
        {
      'zh-Hans': '暂时离开后，可从 Game Record 继续对局；也可以认输结束比赛并记为失败。',
      'zh-Hant': '暫時離開後，可從 Game Record 繼續對局；也可以認輸結束比賽並記為失敗。',
      'de':
          'Du kannst die Partie später über Game Record fortsetzen oder aufgeben, um sie als Niederlage zu beenden.',
      'es':
          'La partida no ha terminado. Puedes salir y retomarla desde Game Record, o rendirte para terminarla como derrota.',
      'fr':
          'La partie n’est pas terminée. Vous pouvez la reprendre plus tard depuis Game Record, ou abandonner pour la terminer en défaite.',
      'it':
          'La partita non è finita. Puoi lasciarla e riprenderla da Game Record, oppure abbandonare per chiuderla come sconfitta.',
      'ja':
          '対局はまだ終了していません。「一時退出」すると Game Record から再開できます。「投了して退出」すると敗北として終了します。',
      'ko':
          '대국이 아직 끝나지 않았습니다. 잠시 나가면 Game Record에서 이어갈 수 있고, 기권하면 패배로 즉시 종료됩니다.',
      'nl':
          'De partij is nog niet klaar. Verlaat nu en hervat later via Game Record, of geef op om de partij als verlies te beëindigen.',
      'ru':
          'Партия ещё не завершена. Можно временно выйти и продолжить из Game Record либо сдаться и завершить её поражением.',
    },
    'Leave for now and continue later from Game Record or Home. The online clock may keep running. You can also resign to end the game as a loss.':
        {
      'zh-Hans': '暂时离开后，可从 Game Record 或首页继续对局；线上棋钟可能会继续计时。也可以认输结束比赛并记为失败。',
      'zh-Hant': '暫時離開後，可從 Game Record 或首頁繼續對局；線上棋鐘可能會繼續計時。也可以認輸結束比賽並記為失敗。',
      'de':
          'Du kannst später über Game Record oder Home zurückkehren. Die Online-Uhr läuft möglicherweise weiter. Du kannst auch aufgeben.',
      'es':
          'La partida sigue en curso. Puedes retomarla desde Game Record o Inicio; el reloj online puede seguir corriendo. También puedes rendirte para terminarla como derrota.',
      'fr':
          'La partie est toujours en cours. Vous pourrez la reprendre depuis Game Record ou l’accueil ; la pendule en ligne peut continuer. Vous pouvez aussi abandonner.',
      'it':
          'La partita è ancora in corso. Puoi riprenderla da Game Record o Home; l’orologio online può continuare. Puoi anche abbandonare e registrare una sconfitta.',
      'ja':
          '対局はまだ進行中です。Game Record またはホームから戻れますが、オンライン時計は進み続ける場合があります。投了して敗北にすることもできます。',
      'ko':
          '대국이 아직 진행 중입니다. Game Record 또는 홈에서 다시 이어갈 수 있지만 온라인 시계는 계속 흐를 수 있습니다. 기권하면 패배로 종료됩니다.',
      'nl':
          'De partij loopt nog. Je kunt terugkeren via Game Record of Home; de online klok kan doorlopen. Je kunt ook opgeven.',
      'ru':
          'Партия ещё идёт. Можно вернуться через Game Record или главный экран; онлайн-часы могут идти дальше. Также можно сдаться и завершить партию поражением.',
    },
    'Leave for now': {
      'zh-Hans': '暂离',
      'zh-Hant': '暫離',
      'de': 'Jetzt verlassen',
      'es': 'Salir por ahora',
      'fr': 'Quitter pour l’instant',
      'it': 'Esci per ora',
      'ja': '一時退出',
      'ko': '잠시 나가기',
      'nl': 'Nu verlaten',
      'ru': 'Выйти сейчас',
    },
    'Resign and exit': {
      'zh-Hans': '认输并退出',
      'zh-Hant': '認輸並退出',
      'de': 'Aufgeben',
      'es': 'Rendirse',
      'fr': 'Abandonner',
      'it': 'Abbandona',
      'ja': '投了して退出',
      'ko': '기권하고 나가기',
      'nl': 'Opgeven',
      'ru': 'Сдаться',
    },
    'Confirm resignation?': {
      'zh-Hans': '确认认输？',
      'zh-Hant': '確認認輸？',
      'de': 'Aufgabe bestätigen?',
      'es': '¿Confirmar rendición?',
      'fr': 'Confirmer l’abandon ?',
      'it': 'Confermare l’abbandono?',
      'ja': '投了しますか？',
      'ko': '기권하시겠어요?',
      'nl': 'Opgeven bevestigen?',
      'ru': 'Подтвердить сдачу?',
    },
    'This will end the game immediately and record it as a loss. You cannot continue this game after resigning.':
        {
      'zh-Hans': '认输后这盘棋会立即结束并记录为失败，无法继续。',
      'zh-Hant': '認輸後這盤棋會立即結束並記錄為失敗，無法繼續。',
      'de':
          'Die Partie endet sofort und wird als Niederlage gespeichert. Danach kannst du sie nicht fortsetzen.',
      'es':
          'La partida terminará de inmediato y se guardará como derrota. No podrás continuarla después de rendirte.',
      'fr':
          'La partie se terminera immédiatement et sera enregistrée comme défaite. Vous ne pourrez plus la reprendre.',
      'it':
          'La partita finirà subito e verrà registrata come sconfitta. Non potrai riprenderla dopo l’abbandono.',
      'ja': 'この対局はすぐに終了し、敗北として記録されます。投了後は再開できません。',
      'ko': '이 대국은 즉시 종료되고 패배로 기록됩니다. 기권한 뒤에는 계속할 수 없습니다.',
      'nl':
          'De partij eindigt direct en wordt als verlies opgeslagen. Na opgeven kun je deze partij niet hervatten.',
      'ru':
          'Партия сразу завершится и будет записана как поражение. После сдачи продолжить её нельзя.',
    },
    'Confirm resign': {
      'zh-Hans': '确认认输',
      'zh-Hant': '確認認輸',
      'de': 'Aufgeben',
      'es': 'Rendirse',
      'fr': 'Abandonner',
      'it': 'Abbandona',
      'ja': '投了する',
      'ko': '기권하기',
      'nl': 'Opgeven',
      'ru': 'Сдаться',
    },
    'Analyze': {
      'zh-Hans': '分析',
      'zh-Hant': '分析',
      'de': 'Analysieren',
      'es': 'Analizar',
      'fr': 'Analyser',
      'it': 'Analizza',
      'ja': '分析',
      'ko': '분석',
      'nl': 'Analyseren',
      'ru': 'Анализ',
    },
    'Analyze game': {
      'zh-Hans': '分析本局',
      'zh-Hant': '分析本局',
      'de': 'Partie analysieren',
      'es': 'Analizar partida',
      'fr': 'Analyser la partie',
      'it': 'Analizza partita',
      'ja': 'この対局を分析',
      'ko': '이번 대국 분석',
      'nl': 'Partij analyseren',
      'ru': 'Анализ партии',
    },
    'Main menu': {
      'zh-Hans': '主菜单',
      'zh-Hant': '主選單',
      'de': 'Hauptmenü',
      'es': 'Menú principal',
      'fr': 'Menu principal',
      'it': 'Menu principale',
      'ja': 'メインメニュー',
      'ko': '메인 메뉴',
      'nl': 'Hoofdmenu',
      'ru': 'Главное меню',
    },
    'Terms of Use': {
      'zh-Hans': '使用条款',
      'zh-Hant': '使用條款',
      'de': 'Nutzungsbedingungen',
      'es': 'Términos de uso',
      'fr': 'Conditions d’utilisation',
      'it': 'Termini di utilizzo',
      'ja': '利用規約',
      'ko': '이용 약관',
      'nl': 'Gebruiksvoorwaarden',
      'ru': 'Условия использования',
    },
    'I agree to': {
      'zh-Hans': '我同意',
      'zh-Hant': '我同意',
      'de': 'Ich stimme zu',
      'es': 'Acepto',
      'fr': 'J’accepte',
      'it': 'Accetto',
      'ja': '同意します',
      'ko': '동의합니다',
      'nl': 'Ik ga akkoord met',
      'ru': 'Я принимаю',
    },
    'and': {
      'zh-Hans': '和',
      'zh-Hant': '和',
      'de': 'und',
      'es': 'y',
      'fr': 'et',
      'it': 'e',
      'ja': 'および',
      'ko': '및',
      'nl': 'en',
      'ru': 'и',
    },
    'Please agree to the Terms of Use and Privacy Policy.': {
      'zh-Hans': '请先同意《使用条款》和《隐私政策》。',
      'zh-Hant': '請先同意《使用條款》和《隱私權政策》。',
      'de':
          'Bitte stimme den Nutzungsbedingungen und der Datenschutzerklärung zu.',
      'es': 'Acepta los Términos de uso y la Política de privacidad.',
      'fr':
          'Veuillez accepter les Conditions d’utilisation et la Politique de confidentialité.',
      'it': 'Accetta i Termini di utilizzo e l’Informativa sulla privacy.',
      'ja': '利用規約とプライバシーポリシーに同意してください。',
      'ko': '이용 약관과 개인정보 처리방침에 동의해 주세요.',
      'nl': 'Ga akkoord met de gebruiksvoorwaarden en het privacybeleid.',
      'ru':
          'Пожалуйста, примите Условия использования и Политику конфиденциальности.',
    },
    'Chessnut account and engine services': {
      'zh-Hans': 'Chessnut 账号与引擎服务',
      'zh-Hant': 'Chessnut 帳號與引擎服務',
      'de': 'Chessnut-Konto und Engine-Dienste',
      'es': 'Cuenta Chessnut y servicios de motor',
      'fr': 'Compte Chessnut et services de moteurs',
      'it': 'Account Chessnut e servizi motore',
      'ja': 'Chessnut アカウントとエンジンサービス',
      'ko': 'Chessnut 계정 및 엔진 서비스',
      'nl': 'Chessnut-account en engine-diensten',
      'ru': 'Аккаунт Chessnut и сервисы движков',
    },
    'Account and fair play': {
      'zh-Hans': '账号与公平竞赛',
      'zh-Hant': '帳號與公平競賽',
      'de': 'Konto und Fair Play',
      'es': 'Cuenta y juego limpio',
      'fr': 'Compte et fair-play',
      'it': 'Account e fair play',
      'ja': 'アカウントとフェアプレー',
      'ko': '계정 및 페어플레이',
      'nl': 'Account en fair play',
      'ru': 'Аккаунт и честная игра',
    },
    'Use Chessnut for lawful chess play, training, records, and board services. Keep your account secure, do not abuse the service, and do not use engine assistance or move-quality lights during online games where it is not allowed.':
        {
      'zh-Hans':
          '请将 Chessnut 用于合法的国际象棋对局、训练、记录和棋盘服务。请妥善保护账号，不滥用服务，也不要在不允许使用引擎辅助的线上对局中使用引擎提示或着法质量灯。',
      'zh-Hant':
          '請將 Chessnut 用於合法的國際象棋對局、訓練、記錄和棋盤服務。請妥善保護帳號，不濫用服務，也不要在不允許使用引擎輔助的線上對局中使用引擎提示或著法品質燈。',
      'de':
          'Nutze Chessnut nur für rechtmäßiges Schachspielen, Training, Aufzeichnungen und Brettdienste. Schütze dein Konto, missbrauche den Dienst nicht und nutze keine Engine-Hilfe oder Zugqualitätslichter in Online-Partien, in denen dies nicht erlaubt ist.',
      'es':
          'Usa Chessnut para jugar ajedrez, entrenar, guardar registros y usar servicios del tablero de forma legal. Mantén tu cuenta segura, no abuses del servicio y no uses ayuda del motor ni luces de calidad de jugada en partidas en línea donde no esté permitido.',
      'fr':
          'Utilisez Chessnut pour jouer aux échecs, vous entraîner, conserver vos parties et utiliser les services du plateau dans un cadre légal. Protégez votre compte, n’abusez pas du service et n’utilisez pas d’aide moteur ni de lumières de qualité de coup dans les parties en ligne où cela est interdit.',
      'it':
          'Usa Chessnut per giocare a scacchi, allenarti, registrare partite e usare i servizi della scacchiera in modo lecito. Proteggi il tuo account, non abusare del servizio e non usare aiuti del motore o luci sulla qualità delle mosse nelle partite online dove non sono consentiti.',
      'ja':
          'Chessnut は、合法的なチェス対局、トレーニング、記録、ボードサービスのために使用してください。アカウントを安全に保ち、サービスを悪用せず、許可されていないオンライン対局ではエンジン支援や手の品質ライトを使用しないでください。',
      'ko':
          'Chessnut은 합법적인 체스 대국, 훈련, 기록 및 보드 서비스에 사용해 주세요. 계정을 안전하게 관리하고 서비스를 악용하지 말며, 허용되지 않는 온라인 대국에서 엔진 지원이나 수 품질 표시등을 사용하지 마세요.',
      'nl':
          'Gebruik Chessnut voor legaal schaken, training, partijregistratie en borddiensten. Houd je account veilig, misbruik de dienst niet en gebruik geen engine-hulp of zetkwaliteitslichten in online partijen waar dat niet is toegestaan.',
      'ru':
          'Используйте Chessnut для законной игры в шахматы, тренировок, записей партий и сервисов доски. Защищайте аккаунт, не злоупотребляйте сервисом и не используйте подсказки движка или индикаторы качества ходов в онлайн-партиях, где это запрещено.',
    },
    'Subscriptions, points, and services': {
      'zh-Hans': '订阅、积分与服务',
      'zh-Hant': '訂閱、積分與服務',
      'de': 'Abos, Punkte und Dienste',
      'es': 'Suscripciones, puntos y servicios',
      'fr': 'Abonnements, points et services',
      'it': 'Abbonamenti, punti e servizi',
      'ja': 'サブスクリプション、ポイント、サービス',
      'ko': '구독, 포인트 및 서비스',
      'nl': 'Abonnementen, punten en diensten',
      'ru': 'Подписки, баллы и сервисы',
    },
    'Premium membership, wallet points, analysis reports, cloud engines, online play, imports, and board features may depend on network availability, platform billing rules, and third-party services. Some features may change, pause, or become unavailable while we maintain the service.':
        {
      'zh-Hans':
          'Premium 会员、钱包积分、分析报告、云端引擎、在线对局、导入和棋盘功能可能依赖网络可用性、平台支付规则以及第三方服务。我们维护服务时，部分功能可能会调整、暂停或暂时不可用。',
      'zh-Hant':
          'Premium 會員、錢包積分、分析報告、雲端引擎、線上對局、匯入和棋盤功能可能依賴網路可用性、平台付款規則以及第三方服務。我們維護服務時，部分功能可能會調整、暫停或暫時不可用。',
      'de':
          'Premium-Mitgliedschaft, Wallet-Punkte, Analyseberichte, Cloud-Engines, Online-Spiel, Importe und Brettfunktionen können von Netzwerkverfügbarkeit, Plattform-Abrechnungsregeln und Drittanbieterdiensten abhängen. Einige Funktionen können sich ändern, pausieren oder während Wartungen vorübergehend nicht verfügbar sein.',
      'es':
          'La membresía Premium, los puntos del wallet, los informes de análisis, los motores en la nube, el juego en línea, las importaciones y las funciones del tablero pueden depender de la red, las reglas de cobro de la plataforma y servicios de terceros. Algunas funciones pueden cambiar, pausarse o no estar disponibles durante el mantenimiento.',
      'fr':
          'L’abonnement Premium, les points du wallet, les rapports d’analyse, les moteurs cloud, le jeu en ligne, les imports et les fonctions du plateau peuvent dépendre du réseau, des règles de facturation des plateformes et de services tiers. Certaines fonctions peuvent changer, être suspendues ou devenir temporairement indisponibles pendant la maintenance.',
      'it':
          'Abbonamento Premium, punti wallet, report di analisi, motori cloud, gioco online, importazioni e funzioni della scacchiera possono dipendere dalla rete, dalle regole di pagamento della piattaforma e da servizi di terze parti. Alcune funzioni possono cambiare, essere sospese o diventare temporaneamente non disponibili durante la manutenzione.',
      'ja':
          'Premium メンバーシップ、ウォレットポイント、分析レポート、クラウドエンジン、オンライン対局、インポート、ボード機能は、ネットワーク状況、プラットフォーム課金ルール、第三者サービスに依存する場合があります。メンテナンス中、一部機能は変更、一時停止、または利用不可になることがあります。',
      'ko':
          'Premium 멤버십, 지갑 포인트, 분석 보고서, 클라우드 엔진, 온라인 대국, 가져오기 및 보드 기능은 네트워크 상태, 플랫폼 결제 규칙, 타사 서비스에 따라 달라질 수 있습니다. 서비스 점검 중 일부 기능은 변경, 중단 또는 일시적으로 사용할 수 없게 될 수 있습니다.',
      'nl':
          'Premium-lidmaatschap, wallet-punten, analyserapporten, cloud-engines, online spelen, imports en bordfuncties kunnen afhangen van netwerkbeschikbaarheid, betaalregels van platformen en diensten van derden. Sommige functies kunnen tijdens onderhoud wijzigen, pauzeren of tijdelijk niet beschikbaar zijn.',
      'ru':
          'Premium-подписка, баллы кошелька, отчеты анализа, облачные движки, онлайн-игра, импорт и функции доски могут зависеть от сети, правил оплаты платформ и сторонних сервисов. Во время обслуживания некоторые функции могут изменяться, приостанавливаться или временно становиться недоступными.',
    },
    'Game data and diagnostics': {
      'zh-Hans': '对局数据与诊断',
      'zh-Hant': '對局資料與診斷',
      'de': 'Partiedaten und Diagnose',
      'es': 'Datos de partidas y diagnóstico',
      'fr': 'Données de parties et diagnostics',
      'it': 'Dati partita e diagnostica',
      'ja': '対局データと診断',
      'ko': '대국 데이터 및 진단',
      'nl': 'Partijgegevens en diagnose',
      'ru': 'Данные партий и диагностика',
    },
    'Chessnut may process account details, PGN/FEN game data, board connection status, device diagnostics, logs, and analysis history to provide sync, review, sharing, support, and troubleshooting features. See the Privacy Policy for more detail.':
        {
      'zh-Hans':
          'Chessnut 可能会处理账号信息、PGN/FEN 对局数据、棋盘连接状态、设备诊断、日志和分析历史，用于同步、复盘、分享、客服支持和故障排查。详情请查看《隐私政策》。',
      'zh-Hant':
          'Chessnut 可能會處理帳號資訊、PGN/FEN 對局資料、棋盤連線狀態、裝置診斷、日誌和分析歷史，用於同步、複盤、分享、客服支援和故障排查。詳情請查看《隱私權政策》。',
      'de':
          'Chessnut kann Kontodaten, PGN/FEN-Partiedaten, Brettverbindungsstatus, Gerätediagnosen, Logs und Analyseverlauf verarbeiten, um Synchronisierung, Analyse, Teilen, Support und Fehlerbehebung bereitzustellen. Weitere Details findest du in der Datenschutzerklärung.',
      'es':
          'Chessnut puede procesar datos de cuenta, PGN/FEN de partidas, estado de conexión del tablero, diagnósticos del dispositivo, registros e historial de análisis para ofrecer sincronización, revisión, uso compartido, soporte y solución de problemas. Consulta la Política de privacidad para más detalles.',
      'fr':
          'Chessnut peut traiter les informations de compte, les données PGN/FEN, l’état de connexion du plateau, les diagnostics d’appareil, les journaux et l’historique d’analyse afin d’assurer la synchronisation, la revue, le partage, le support et le dépannage. Consultez la Politique de confidentialité pour plus de détails.',
      'it':
          'Chessnut può trattare dati account, dati PGN/FEN, stato della connessione della scacchiera, diagnostica del dispositivo, log e cronologia analisi per offrire sincronizzazione, revisione, condivisione, supporto e risoluzione problemi. Consulta l’Informativa sulla privacy per i dettagli.',
      'ja':
          'Chessnut は、同期、レビュー、共有、サポート、トラブルシューティング機能を提供するため、アカウント情報、PGN/FEN 対局データ、ボード接続状態、デバイス診断、ログ、分析履歴を処理する場合があります。詳細はプライバシーポリシーをご確認ください。',
      'ko':
          'Chessnut은 동기화, 검토, 공유, 지원 및 문제 해결 기능 제공을 위해 계정 정보, PGN/FEN 대국 데이터, 보드 연결 상태, 기기 진단, 로그 및 분석 기록을 처리할 수 있습니다. 자세한 내용은 개인정보 처리방침을 확인하세요.',
      'nl':
          'Chessnut kan accountgegevens, PGN/FEN-partijgegevens, bordverbindingsstatus, apparaatdiagnose, logs en analysegeschiedenis verwerken voor synchronisatie, analyse, delen, support en probleemoplossing. Zie het privacybeleid voor meer informatie.',
      'ru':
          'Chessnut может обрабатывать данные аккаунта, PGN/FEN партий, статус подключения доски, диагностику устройства, журналы и историю анализа для синхронизации, разбора, обмена, поддержки и устранения неполадок. Подробнее см. в Политике конфиденциальности.',
    },
    'Maia3 review': {
      'zh-Hans': 'Maia3 复盘',
      'zh-Hant': 'Maia3 複盤',
      'de': 'Maia3-Analyse',
      'es': 'Revisión Maia3',
      'fr': 'Analyse Maia3',
      'it': 'Revisione Maia3',
      'ja': 'Maia3 レビュー',
      'ko': 'Maia3 복기',
      'nl': 'Maia3-review',
      'ru': 'Разбор Maia3',
    },
    'Maia and Maia 3': {
      'zh-Hans': 'Maia 与 Maia 3',
      'zh-Hant': 'Maia 與 Maia 3',
      'de': 'Maia und Maia 3',
      'es': 'Maia y Maia 3',
      'fr': 'Maia et Maia 3',
      'it': 'Maia e Maia 3',
      'ja': 'Maia と Maia 3',
      'ko': 'Maia 및 Maia 3',
      'nl': 'Maia en Maia 3',
      'ru': 'Maia и Maia 3',
    },
    'Cloud human model, official 600-2600 Elo range': {
      'zh-Hans': '云端人类模型，官方 600-2600 Elo 范围',
      'zh-Hant': '雲端人類模型，官方 600-2600 Elo 範圍',
      'de': 'Cloud-Modell menschlicher Züge, offizieller Elo-Bereich 600-2600',
      'es': 'Modelo humano en la nube, rango Elo oficial 600-2600',
      'fr': 'Modèle humain cloud, plage Elo officielle 600-2600',
      'it': 'Modello umano cloud, intervallo Elo ufficiale 600-2600',
      'ja': 'クラウド人間モデル、公式 600-2600 Elo 範囲',
      'ko': '클라우드 인간 모델, 공식 600-2600 Elo 범위',
      'nl': 'Cloudmodel voor menselijke zetten, officieel Elo-bereik 600-2600',
      'ru': 'Облачная человеческая модель, официальный диапазон Elo 600-2600',
    },
    'Target Elo': {
      'zh-Hans': '目标 Elo',
      'zh-Hant': '目標 Elo',
      'de': 'Ziel-Elo',
      'es': 'Elo objetivo',
      'fr': 'Elo cible',
      'it': 'Elo target',
      'ja': '目標 Elo',
      'ko': '목표 Elo',
      'nl': 'Doel-Elo',
      'ru': 'Целевой Elo',
    },
    'Official Maia 3 range, 600 to 2600.': {
      'zh-Hans': 'Maia 3 官方范围：600 到 2600。',
      'zh-Hant': 'Maia 3 官方範圍：600 到 2600。',
      'de': 'Offizieller Maia 3-Bereich: 600 bis 2600.',
      'es': 'Rango oficial de Maia 3: de 600 a 2600.',
      'fr': 'Plage officielle de Maia 3 : 600 à 2600.',
      'it': 'Intervallo ufficiale di Maia 3: da 600 a 2600.',
      'ja': 'Maia 3 の公式範囲: 600 から 2600。',
      'ko': 'Maia 3 공식 범위: 600에서 2600.',
      'nl': 'Officieel Maia 3-bereik: 600 tot 2600.',
      'ru': 'Официальный диапазон Maia 3: от 600 до 2600.',
    },
    'Maia 3 predicts likely human moves from 600 to 2600 Elo. Sign in and stay online to use it.':
        {
      'zh-Hans': 'Maia 3 会预测 600 到 2600 Elo 人类可能走出的棋步。请登录并保持在线以使用。',
      'zh-Hant': 'Maia 3 會預測 600 到 2600 Elo 人類可能走出的著法。請登入並保持線上以使用。',
      'de':
          'Maia 3 sagt wahrscheinliche menschliche Züge von 600 bis 2600 Elo voraus. Melde dich an und bleib online, um es zu nutzen.',
      'es':
          'Maia 3 predice jugadas humanas probables de 600 a 2600 Elo. Inicia sesión y mantente en línea para usarlo.',
      'fr':
          'Maia 3 prédit les coups humains probables de 600 à 2600 Elo. Connectez-vous et restez en ligne pour l’utiliser.',
      'it':
          'Maia 3 prevede mosse umane probabili da 600 a 2600 Elo. Accedi e resta online per usarlo.',
      'ja':
          'Maia 3 は 600 から 2600 Elo の人間らしい手を予測します。使用するにはサインインし、オンラインのままにしてください。',
      'ko':
          'Maia 3는 600에서 2600 Elo 사이의 인간이 둘 가능성이 높은 수를 예측합니다. 사용하려면 로그인하고 온라인 상태를 유지하세요.',
      'nl':
          'Maia 3 voorspelt waarschijnlijke menselijke zetten van 600 tot 2600 Elo. Log in en blijf online om het te gebruiken.',
      'ru':
          'Maia 3 предсказывает вероятные человеческие ходы от 600 до 2600 Elo. Войдите и оставайтесь онлайн, чтобы использовать ее.',
    },
    'Maia is a University of Toronto CSSLab human-like chess AI project. Chessnut may use Maia and Maia 3 for bot moves and human-style analysis. Maia estimates likely human moves and mistakes; it is not intended to be an absolute best-move engine. Official website: https://maiachess.com. Maia 3 source/model information: https://github.com/CSSLab/maia3.':
        {
      'zh-Hans':
          'Maia 是多伦多大学 CSSLab 的类人国际象棋 AI 项目。Chessnut 可能会将 Maia 和 Maia 3 用于 bot 走子和类人风格分析。Maia 估计人类可能选择的走法和失误，并不是绝对最佳着法引擎。官网：https://maiachess.com。Maia 3 源码/模型信息：https://github.com/CSSLab/maia3。',
      'zh-Hant':
          'Maia 是多倫多大學 CSSLab 的類人國際象棋 AI 專案。Chessnut 可能會將 Maia 和 Maia 3 用於 bot 著法和類人風格分析。Maia 估計人類可能選擇的著法和失誤，並不是絕對最佳著法引擎。官網：https://maiachess.com。Maia 3 原始碼/模型資訊：https://github.com/CSSLab/maia3。',
      'de':
          'Maia ist ein menschenähnliches Schach-KI-Projekt des CSSLab der University of Toronto. Chessnut kann Maia und Maia 3 für Bot-Züge und menschenähnliche Analysen verwenden. Maia schätzt wahrscheinliche menschliche Züge und Fehler; es ist kein absoluter Best-Move-Engine. Offizielle Website: https://maiachess.com. Maia-3-Quellcode/Modellinformationen: https://github.com/CSSLab/maia3.',
      'es':
          'Maia es un proyecto de IA de ajedrez de estilo humano del CSSLab de la Universidad de Toronto. Chessnut puede usar Maia y Maia 3 para jugadas de bots y análisis de estilo humano. Maia estima jugadas y errores humanos probables; no pretende ser un motor de mejor jugada absoluta. Sitio oficial: https://maiachess.com. Información de código/modelo de Maia 3: https://github.com/CSSLab/maia3.',
      'fr':
          'Maia est un projet d’IA d’échecs de style humain du CSSLab de l’Université de Toronto. Chessnut peut utiliser Maia et Maia 3 pour les coups des bots et l’analyse de style humain. Maia estime les coups et erreurs humains probables ; ce n’est pas un moteur de meilleur coup absolu. Site officiel : https://maiachess.com. Code source/informations modèle Maia 3 : https://github.com/CSSLab/maia3.',
      'it':
          'Maia è un progetto di IA scacchistica in stile umano del CSSLab dell’Università di Toronto. Chessnut può usare Maia e Maia 3 per mosse dei bot e analisi in stile umano. Maia stima mosse ed errori umani probabili; non è pensato come motore di migliore mossa assoluta. Sito ufficiale: https://maiachess.com. Codice/modelli Maia 3: https://github.com/CSSLab/maia3.',
      'ja':
          'Maia はトロント大学 CSSLab による人間らしいチェス AI プロジェクトです。Chessnut は bot の手や人間らしい分析に Maia および Maia 3 を使用する場合があります。Maia は人間が選びそうな手やミスを推定するもので、絶対的な最善手エンジンではありません。公式サイト: https://maiachess.com。Maia 3 のソース/モデル情報: https://github.com/CSSLab/maia3。',
      'ko':
          'Maia는 토론토대학교 CSSLab의 인간형 체스 AI 프로젝트입니다. Chessnut은 bot 수와 인간형 분석에 Maia 및 Maia 3를 사용할 수 있습니다. Maia는 인간이 둘 가능성이 높은 수와 실수를 예측하며, 절대적인 최선 수 엔진이 아닙니다. 공식 웹사이트: https://maiachess.com. Maia 3 소스/모델 정보: https://github.com/CSSLab/maia3.',
      'nl':
          'Maia is een mensachtige schaak-AI van het CSSLab van de University of Toronto. Chessnut kan Maia en Maia 3 gebruiken voor botzetten en mensachtige analyse. Maia schat waarschijnlijke menselijke zetten en fouten; het is geen engine voor de absoluut beste zet. Officiële website: https://maiachess.com. Maia 3-bron/modelinformatie: https://github.com/CSSLab/maia3.',
      'ru':
          'Maia — человекоподобный шахматный AI-проект CSSLab Университета Торонто. Chessnut может использовать Maia и Maia 3 для ходов ботов и анализа в человеческом стиле. Maia оценивает вероятные человеческие ходы и ошибки; это не движок абсолютного лучшего хода. Официальный сайт: https://maiachess.com. Исходный код/модели Maia 3: https://github.com/CSSLab/maia3.',
    },
    'Maia is a University of Toronto CSSLab human-like chess AI project. Chessnut may use Maia and Maia 3 for bot moves and human-style analysis. Maia estimates likely human moves and mistakes; it is not intended to be an absolute best-move engine. Maia 3 is published under AGPL-3.0. Official website: https://maiachess.com. Maia 3 source/model information: https://github.com/CSSLab/maia3.':
        {
      'zh-Hans':
          'Maia 是多伦多大学 CSSLab 的类人国际象棋 AI 项目。Chessnut 可能会将 Maia 和 Maia 3 用于 bot 走子和类人风格分析。Maia 估计人类可能选择的走法和失误，并不是绝对最佳着法引擎。Maia 3 基于 AGPL-3.0 发布。官网：https://maiachess.com。Maia 3 源码/模型信息：https://github.com/CSSLab/maia3。',
      'zh-Hant':
          'Maia 是多倫多大學 CSSLab 的類人國際象棋 AI 專案。Chessnut 可能會將 Maia 和 Maia 3 用於 bot 著法和類人風格分析。Maia 估計人類可能選擇的著法和失誤，並不是絕對最佳著法引擎。Maia 3 以 AGPL-3.0 發布。官網：https://maiachess.com。Maia 3 原始碼/模型資訊：https://github.com/CSSLab/maia3。',
      'de':
          'Maia ist ein menschenähnliches Schach-KI-Projekt des CSSLab der University of Toronto. Chessnut kann Maia und Maia 3 für Bot-Züge und menschenähnliche Analysen verwenden. Maia schätzt wahrscheinliche menschliche Züge und Fehler; es ist kein absoluter Best-Move-Engine. Maia 3 wird unter AGPL-3.0 veröffentlicht. Offizielle Website: https://maiachess.com. Maia-3-Quellcode/Modellinformationen: https://github.com/CSSLab/maia3.',
      'es':
          'Maia es un proyecto de IA de ajedrez de estilo humano del CSSLab de la Universidad de Toronto. Chessnut puede usar Maia y Maia 3 para jugadas de bots y análisis de estilo humano. Maia estima jugadas y errores humanos probables; no pretende ser un motor de mejor jugada absoluta. Maia 3 se publica bajo AGPL-3.0. Sitio oficial: https://maiachess.com. Información de código/modelo de Maia 3: https://github.com/CSSLab/maia3.',
      'fr':
          'Maia est un projet d’IA d’échecs de style humain du CSSLab de l’Université de Toronto. Chessnut peut utiliser Maia et Maia 3 pour les coups des bots et l’analyse de style humain. Maia estime les coups et erreurs humains probables ; ce n’est pas un moteur de meilleur coup absolu. Maia 3 est publié sous AGPL-3.0. Site officiel : https://maiachess.com. Code source/informations modèle Maia 3 : https://github.com/CSSLab/maia3.',
      'it':
          'Maia è un progetto di IA scacchistica in stile umano del CSSLab dell’Università di Toronto. Chessnut può usare Maia e Maia 3 per mosse dei bot e analisi in stile umano. Maia stima mosse ed errori umani probabili; non è pensato come motore di migliore mossa assoluta. Maia 3 è pubblicato sotto AGPL-3.0. Sito ufficiale: https://maiachess.com. Codice/modelli Maia 3: https://github.com/CSSLab/maia3.',
      'ja':
          'Maia はトロント大学 CSSLab による人間らしいチェス AI プロジェクトです。Chessnut は bot の手や人間らしい分析に Maia および Maia 3 を使用する場合があります。Maia は人間が選びそうな手やミスを推定するもので、絶対的な最善手エンジンではありません。Maia 3 は AGPL-3.0 で公開されています。公式サイト: https://maiachess.com。Maia 3 のソース/モデル情報: https://github.com/CSSLab/maia3。',
      'ko':
          'Maia는 토론토대학교 CSSLab의 인간형 체스 AI 프로젝트입니다. Chessnut은 bot 수와 인간형 분석에 Maia 및 Maia 3를 사용할 수 있습니다. Maia는 인간이 둘 가능성이 높은 수와 실수를 예측하며, 절대적인 최선 수 엔진이 아닙니다. Maia 3는 AGPL-3.0으로 공개됩니다. 공식 웹사이트: https://maiachess.com. Maia 3 소스/모델 정보: https://github.com/CSSLab/maia3.',
      'nl':
          'Maia is een mensachtige schaak-AI van het CSSLab van de University of Toronto. Chessnut kan Maia en Maia 3 gebruiken voor botzetten en mensachtige analyse. Maia schat waarschijnlijke menselijke zetten en fouten; het is geen engine voor de absoluut beste zet. Maia 3 wordt gepubliceerd onder AGPL-3.0. Officiële website: https://maiachess.com. Maia 3-bron/modelinformatie: https://github.com/CSSLab/maia3.',
      'ru':
          'Maia — человекоподобный шахматный AI-проект CSSLab Университета Торонто. Chessnut может использовать Maia и Maia 3 для ходов ботов и анализа в человеческом стиле. Maia оценивает вероятные человеческие ходы и ошибки; это не движок абсолютного лучшего хода. Maia 3 опубликована под AGPL-3.0. Официальный сайт: https://maiachess.com. Исходный код/модели Maia 3: https://github.com/CSSLab/maia3.',
    },
    'Stockfish': {
      'zh-Hans': 'Stockfish',
      'zh-Hant': 'Stockfish',
      'de': 'Stockfish',
      'es': 'Stockfish',
      'fr': 'Stockfish',
      'it': 'Stockfish',
      'ja': 'Stockfish',
      'ko': 'Stockfish',
      'nl': 'Stockfish',
      'ru': 'Stockfish',
    },
    'Stockfish is a third-party open-source chess engine used for engine evaluation, analysis reports, score estimates, and training feedback where fair-play rules permit. Official website: https://stockfishchess.org. Source and license information: https://github.com/official-stockfish/Stockfish.':
        {
      'zh-Hans':
          'Stockfish 是第三方开源国际象棋引擎，在公平竞赛规则允许的场景下用于引擎评估、分析报告、分数估计和训练反馈。官网：https://stockfishchess.org。源码和许可信息：https://github.com/official-stockfish/Stockfish。',
      'zh-Hant':
          'Stockfish 是第三方開源國際象棋引擎，在公平競賽規則允許的場景下用於引擎評估、分析報告、分數估計和訓練回饋。官網：https://stockfishchess.org。原始碼和授權資訊：https://github.com/official-stockfish/Stockfish。',
      'de':
          'Stockfish ist eine Open-Source-Schachengine eines Drittanbieters, die dort, wo Fair-Play-Regeln es erlauben, für Engine-Bewertung, Analyseberichte, Schätzungen und Trainingsfeedback verwendet wird. Offizielle Website: https://stockfishchess.org. Quellcode und Lizenzinformationen: https://github.com/official-stockfish/Stockfish.',
      'es':
          'Stockfish es un motor de ajedrez de código abierto de terceros usado para evaluación, informes de análisis, estimaciones de puntuación y feedback de entrenamiento cuando las reglas de juego limpio lo permiten. Sitio oficial: https://stockfishchess.org. Código y licencia: https://github.com/official-stockfish/Stockfish.',
      'fr':
          'Stockfish est un moteur d’échecs open source tiers utilisé pour l’évaluation moteur, les rapports d’analyse, les estimations de score et le retour d’entraînement lorsque les règles de fair-play le permettent. Site officiel : https://stockfishchess.org. Code source et licence : https://github.com/official-stockfish/Stockfish.',
      'it':
          'Stockfish è un motore scacchistico open source di terze parti usato per valutazioni, report di analisi, stime del punteggio e feedback di allenamento dove le regole di fair play lo consentono. Sito ufficiale: https://stockfishchess.org. Codice e licenza: https://github.com/official-stockfish/Stockfish.',
      'ja':
          'Stockfish は第三者のオープンソースチェスエンジンで、フェアプレールールが許可する場面で、エンジン評価、分析レポート、スコア推定、トレーニングフィードバックに使用されます。公式サイト: https://stockfishchess.org。ソースとライセンス情報: https://github.com/official-stockfish/Stockfish。',
      'ko':
          'Stockfish는 타사 오픈소스 체스 엔진으로, 페어플레이 규칙이 허용하는 경우 엔진 평가, 분석 보고서, 점수 추정 및 훈련 피드백에 사용됩니다. 공식 웹사이트: https://stockfishchess.org. 소스 및 라이선스 정보: https://github.com/official-stockfish/Stockfish.',
      'nl':
          'Stockfish is een externe open-source schaakengine die, waar fair-playregels dit toestaan, wordt gebruikt voor engine-evaluatie, analyserapporten, score-inschattingen en trainingsfeedback. Officiële website: https://stockfishchess.org. Broncode en licentie: https://github.com/official-stockfish/Stockfish.',
      'ru':
          'Stockfish — сторонний шахматный движок с открытым исходным кодом, используемый для оценки движком, отчетов анализа, оценок счета и тренировочной обратной связи там, где это разрешено правилами честной игры. Официальный сайт: https://stockfishchess.org. Исходный код и лицензия: https://github.com/official-stockfish/Stockfish.',
    },
    'Stockfish is a third-party GPL-licensed open-source chess engine used for engine evaluation, analysis reports, score estimates, and training feedback where fair-play rules permit. Official website: https://stockfishchess.org. Source and license information: https://github.com/official-stockfish/Stockfish.':
        {
      'zh-Hans':
          'Stockfish 是第三方 GPL 许可的开源国际象棋引擎，在公平竞赛规则允许的场景下用于引擎评估、分析报告、分数估计和训练反馈。官网：https://stockfishchess.org。源码和许可信息：https://github.com/official-stockfish/Stockfish。',
      'zh-Hant':
          'Stockfish 是第三方 GPL 授權的開源國際象棋引擎，在公平競賽規則允許的場景下用於引擎評估、分析報告、分數估計和訓練回饋。官網：https://stockfishchess.org。原始碼和授權資訊：https://github.com/official-stockfish/Stockfish。',
      'de':
          'Stockfish ist eine GPL-lizenzierte Open-Source-Schachengine eines Drittanbieters, die dort, wo Fair-Play-Regeln es erlauben, für Engine-Bewertung, Analyseberichte, Schätzungen und Trainingsfeedback verwendet wird. Offizielle Website: https://stockfishchess.org. Quellcode und Lizenzinformationen: https://github.com/official-stockfish/Stockfish.',
      'es':
          'Stockfish es un motor de ajedrez de código abierto de terceros con licencia GPL, usado para evaluación, informes de análisis, estimaciones de puntuación y feedback de entrenamiento cuando las reglas de juego limpio lo permiten. Sitio oficial: https://stockfishchess.org. Código y licencia: https://github.com/official-stockfish/Stockfish.',
      'fr':
          'Stockfish est un moteur d’échecs open source tiers sous licence GPL, utilisé pour l’évaluation moteur, les rapports d’analyse, les estimations de score et le retour d’entraînement lorsque les règles de fair-play le permettent. Site officiel : https://stockfishchess.org. Code source et licence : https://github.com/official-stockfish/Stockfish.',
      'it':
          'Stockfish è un motore scacchistico open source di terze parti con licenza GPL, usato per valutazioni, report di analisi, stime del punteggio e feedback di allenamento dove le regole di fair play lo consentono. Sito ufficiale: https://stockfishchess.org. Codice e licenza: https://github.com/official-stockfish/Stockfish.',
      'ja':
          'Stockfish は GPL ライセンスの第三者オープンソースチェスエンジンで、フェアプレールールが許可する場面で、エンジン評価、分析レポート、スコア推定、トレーニングフィードバックに使用されます。公式サイト: https://stockfishchess.org。ソースとライセンス情報: https://github.com/official-stockfish/Stockfish。',
      'ko':
          'Stockfish는 GPL 라이선스의 타사 오픈소스 체스 엔진으로, 페어플레이 규칙이 허용하는 경우 엔진 평가, 분석 보고서, 점수 추정 및 훈련 피드백에 사용됩니다. 공식 웹사이트: https://stockfishchess.org. 소스 및 라이선스 정보: https://github.com/official-stockfish/Stockfish.',
      'nl':
          'Stockfish is een externe GPL-gelicentieerde open-source schaakengine die, waar fair-playregels dit toestaan, wordt gebruikt voor engine-evaluatie, analyserapporten, score-inschattingen en trainingsfeedback. Officiële website: https://stockfishchess.org. Broncode en licentie: https://github.com/official-stockfish/Stockfish.',
      'ru':
          'Stockfish — сторонний шахматный движок с открытым исходным кодом под лицензией GPL, используемый для оценки движком, отчетов анализа, оценок счета и тренировочной обратной связи там, где это разрешено правилами честной игры. Официальный сайт: https://stockfishchess.org. Исходный код и лицензия: https://github.com/official-stockfish/Stockfish.',
    },
    'Third-party licenses': {
      'zh-Hans': '第三方许可',
      'zh-Hant': '第三方授權',
      'de': 'Lizenzen Dritter',
      'es': 'Licencias de terceros',
      'fr': 'Licences tierces',
      'it': 'Licenze di terze parti',
      'ja': '第三者ライセンス',
      'ko': '타사 라이선스',
      'nl': 'Licenties van derden',
      'ru': 'Сторонние лицензии',
    },
    'Maia, Maia 3, Stockfish, Lichess, Chess.com, app stores, and other integrations are separate third-party projects or services with their own terms and licenses. Chessnut provides notices and source links where required, but those third-party terms remain separate from these Chessnut Terms of Use.':
        {
      'zh-Hans':
          'Maia、Maia 3、Stockfish、Lichess、Chess.com、应用商店以及其他集成均为独立第三方项目或服务，有各自的条款和许可。Chessnut 会在需要时提供声明和源码链接，但这些第三方条款与本 Chessnut 使用条款相互独立。',
      'zh-Hant':
          'Maia、Maia 3、Stockfish、Lichess、Chess.com、應用商店以及其他整合均為獨立第三方專案或服務，有各自的條款和授權。Chessnut 會在需要時提供聲明和原始碼連結，但這些第三方條款與本 Chessnut 使用條款相互獨立。',
      'de':
          'Maia, Maia 3, Stockfish, Lichess, Chess.com, App-Stores und andere Integrationen sind separate Drittprojekte oder -dienste mit eigenen Bedingungen und Lizenzen. Chessnut stellt Hinweise und Quelllinks bereit, wo dies erforderlich ist; diese Drittbedingungen bleiben jedoch getrennt von diesen Chessnut-Nutzungsbedingungen.',
      'es':
          'Maia, Maia 3, Stockfish, Lichess, Chess.com, las tiendas de apps y otras integraciones son proyectos o servicios de terceros independientes con sus propios términos y licencias. Chessnut proporciona avisos y enlaces de código cuando corresponde, pero esos términos de terceros son independientes de estos Términos de uso de Chessnut.',
      'fr':
          'Maia, Maia 3, Stockfish, Lichess, Chess.com, les stores d’apps et les autres intégrations sont des projets ou services tiers distincts avec leurs propres conditions et licences. Chessnut fournit les avis et liens sources lorsque nécessaire, mais ces conditions tierces restent séparées des présentes Conditions d’utilisation de Chessnut.',
      'it':
          'Maia, Maia 3, Stockfish, Lichess, Chess.com, app store e altre integrazioni sono progetti o servizi di terze parti separati con termini e licenze propri. Chessnut fornisce avvisi e link al codice quando richiesto, ma tali termini di terze parti restano separati da questi Termini di utilizzo Chessnut.',
      'ja':
          'Maia、Maia 3、Stockfish、Lichess、Chess.com、アプリストア、その他の連携は、それぞれ独自の規約とライセンスを持つ第三者プロジェクトまたはサービスです。Chessnut は必要に応じて通知とソースリンクを提供しますが、それら第三者の規約は本 Chessnut 利用規約とは別のものです。',
      'ko':
          'Maia, Maia 3, Stockfish, Lichess, Chess.com, 앱 스토어 및 기타 연동은 각각 자체 약관과 라이선스를 가진 별도의 타사 프로젝트 또는 서비스입니다. Chessnut은 필요한 경우 고지와 소스 링크를 제공하지만, 해당 타사 약관은 본 Chessnut 이용 약관과 별개입니다.',
      'nl':
          'Maia, Maia 3, Stockfish, Lichess, Chess.com, appstores en andere integraties zijn afzonderlijke projecten of diensten van derden met eigen voorwaarden en licenties. Chessnut geeft waar nodig kennisgevingen en bronlinks, maar die voorwaarden van derden staan los van deze Chessnut-gebruiksvoorwaarden.',
      'ru':
          'Maia, Maia 3, Stockfish, Lichess, Chess.com, магазины приложений и другие интеграции являются отдельными сторонними проектами или сервисами со своими условиями и лицензиями. Chessnut предоставляет уведомления и ссылки на исходный код, где это требуется, но такие сторонние условия остаются отдельными от настоящих Условий использования Chessnut.',
    },
    'Account sync': {
      'zh-Hans': '账号同步',
      'zh-Hant': '帳號同步',
      'de': 'Kontosynchronisierung',
      'es': 'Sincronización de cuenta',
      'fr': 'Synchronisation du compte',
      'it': 'Sincronizzazione account',
      'ja': 'アカウント同期',
      'ko': '계정 동기화',
      'nl': 'Accountsynchronisatie',
      'ru': 'Синхронизация аккаунта',
    },
    'Chessnut uses your account to sync game records, board preferences, puzzle progress, points, membership, and analysis history across your devices.':
        {
      'zh-Hans': 'Chessnut 使用你的账号在不同设备间同步对局记录、棋盘偏好、Puzzle 进度、积分、会员和分析历史。',
      'zh-Hant': 'Chessnut 使用你的帳號在不同裝置間同步對局記錄、棋盤偏好、Puzzle 進度、積分、會員和分析歷史。',
      'de':
          'Chessnut verwendet dein Konto, um Partien, Bretteinstellungen, Puzzle-Fortschritt, Punkte, Mitgliedschaft und Analyseverlauf geräteübergreifend zu synchronisieren.',
      'es':
          'Chessnut usa tu cuenta para sincronizar registros de partidas, preferencias del tablero, progreso de puzzles, puntos, membresía e historial de análisis entre dispositivos.',
      'fr':
          'Chessnut utilise votre compte pour synchroniser les parties, préférences du plateau, progression des puzzles, points, abonnement et historique d’analyse entre vos appareils.',
      'it':
          'Chessnut usa il tuo account per sincronizzare partite, preferenze della scacchiera, progressi puzzle, punti, abbonamento e cronologia analisi tra dispositivi.',
      'ja':
          'Chessnut は、対局記録、ボード設定、Puzzle の進捗、ポイント、メンバーシップ、分析履歴をデバイス間で同期するためにアカウントを使用します。',
      'ko':
          'Chessnut은 대국 기록, 보드 설정, Puzzle 진행도, 포인트, 멤버십 및 분석 기록을 기기 간에 동기화하기 위해 계정을 사용합니다.',
      'nl':
          'Chessnut gebruikt je account om partijrecords, bordvoorkeuren, puzzelvoortgang, punten, lidmaatschap en analysegeschiedenis tussen apparaten te synchroniseren.',
      'ru':
          'Chessnut использует ваш аккаунт для синхронизации записей партий, настроек доски, прогресса Puzzle, баллов, подписки и истории анализа между устройствами.',
    },
    'Board and game data': {
      'zh-Hans': '棋盘与对局数据',
      'zh-Hant': '棋盤與對局資料',
      'de': 'Brett- und Partiedaten',
      'es': 'Datos del tablero y partidas',
      'fr': 'Données du plateau et des parties',
      'it': 'Dati scacchiera e partite',
      'ja': 'ボードと対局データ',
      'ko': '보드 및 대국 데이터',
      'nl': 'Bord- en partijgegevens',
      'ru': 'Данные доски и партий',
    },
    'Chessnut uses open-source chess engines and libraries. The package includes license notices, and corresponding source links are listed below.':
        {
      'zh-Hans': 'Chessnut 使用开源国际象棋引擎和库。本包包含许可说明，并在下方列出对应的源码链接。',
      'zh-Hant': 'Chessnut 使用開源西洋棋引擎和函式庫。本套件包含授權說明，並在下方列出對應的原始碼連結。',
      'de':
          'Chessnut nutzt Open-Source-Schachengines und -Bibliotheken. Dieses Paket enthält Lizenzhinweise; die zugehörigen Quellcode-Links sind unten aufgeführt.',
      'es':
          'Chessnut usa motores y bibliotecas de ajedrez de código abierto. El paquete incluye avisos de licencia y abajo se muestran los enlaces de código fuente correspondientes.',
      'fr':
          'Chessnut utilise des moteurs et bibliothèques d’échecs open source. Le paquet inclut les avis de licence et les liens de code source correspondants ci-dessous.',
      'it':
          'Chessnut usa motori e librerie scacchistiche open source. Il pacchetto include le note di licenza e i link al codice sorgente corrispondenti qui sotto.',
      'ja':
          'Chessnut はオープンソースのチェスエンジンとライブラリを使用しています。このパッケージにはライセンス表記が含まれ、対応するソースリンクを下に掲載しています。',
      'ko':
          'Chessnut은 오픈 소스 체스 엔진과 라이브러리를 사용합니다. 이 패키지에는 라이선스 고지가 포함되며, 해당 소스 링크가 아래에 표시됩니다.',
      'nl':
          'Chessnut gebruikt open-source schaakengines en bibliotheken. Dit pakket bevat licentiekennisgevingen; de bijbehorende bronlinks staan hieronder.',
      'ru':
          'Chessnut использует шахматные движки и библиотеки с открытым кодом. Пакет включает сведения о лицензиях, а соответствующие ссылки на исходный код приведены ниже.',
    },
    'Open-source notices': {
      'zh-Hans': '开源许可说明',
      'zh-Hant': '開源授權說明',
      'de': 'Open-Source-Hinweise',
      'es': 'Avisos de código abierto',
      'fr': 'Mentions open source',
      'it': 'Note open source',
      'ja': 'オープンソース情報',
      'ko': '오픈 소스 고지',
      'nl': 'Open-sourcevermeldingen',
      'ru': 'Сведения об открытом коде',
    },
    'Chess engine used for evaluation, hints, bots, and analysis.': {
      'zh-Hans': '用于评估、提示、机器人对局和分析的国际象棋引擎。',
      'zh-Hant': '用於評估、提示、機器人對局與分析的西洋棋引擎。',
      'de': 'Schachengine für Bewertung, Hinweise, Bots und Analyse.',
      'es': 'Motor de ajedrez usado para evaluación, pistas, bots y análisis.',
      'fr':
          'Moteur d’échecs utilisé pour l’évaluation, les indices, les bots et l’analyse.',
      'it':
          'Motore scacchistico usato per valutazione, suggerimenti, bot e analisi.',
      'ja': '評価、ヒント、Bot 対局、分析に使用するチェスエンジンです。',
      'ko': '평가, 힌트, 봇 대국, 분석에 사용하는 체스 엔진입니다.',
      'nl': 'Schaakengine voor evaluatie, hints, bots en analyse.',
      'ru': 'Шахматный движок для оценки, подсказок, ботов и анализа.',
    },
    'Neural-network chess engine used for LC0 and Maia-compatible play.': {
      'zh-Hans': '用于 LC0 和兼容 Maia 对局的神经网络国际象棋引擎。',
      'zh-Hant': '用於 LC0 與相容 Maia 對局的神經網路西洋棋引擎。',
      'de': 'Neuronale Schachengine für LC0 und Maia-kompatibles Spiel.',
      'es':
          'Motor de ajedrez de red neuronal usado para LC0 y juego compatible con Maia.',
      'fr':
          'Moteur d’échecs à réseau neuronal utilisé pour LC0 et le jeu compatible avec Maia.',
      'it':
          'Motore scacchistico a rete neurale usato per LC0 e gioco compatibile con Maia.',
      'ja': 'LC0 と Maia 互換の対局に使用するニューラルネットワーク型チェスエンジンです。',
      'ko': 'LC0 및 Maia 호환 대국에 사용하는 신경망 체스 엔진입니다.',
      'nl': 'Neuraal-netwerk schaakengine voor LC0 en Maia-compatibel spel.',
      'ru':
          'Нейросетевой шахматный движок для LC0 и партий, совместимых с Maia.',
    },
    'Chess rules, move generation, FEN, and PGN handling.': {
      'zh-Hans': '处理国际象棋规则、走法生成、FEN 和 PGN。',
      'zh-Hant': '處理西洋棋規則、著法產生、FEN 與 PGN。',
      'de': 'Schachregeln, Zuggenerierung sowie FEN- und PGN-Verarbeitung.',
      'es': 'Reglas de ajedrez, generación de jugadas y manejo de FEN y PGN.',
      'fr': 'Règles d’échecs, génération de coups et traitement FEN et PGN.',
      'it':
          'Regole degli scacchi, generazione delle mosse e gestione di FEN e PGN.',
      'ja': 'チェスルール、合法手生成、FEN、PGN の処理。',
      'ko': '체스 규칙, 수 생성, FEN 및 PGN 처리.',
      'nl': 'Schaakregels, zetgeneratie en verwerking van FEN en PGN.',
      'ru': 'Правила шахмат, генерация ходов, обработка FEN и PGN.',
    },
    'Chess board UI used by the virtual board.': {
      'zh-Hans': '虚拟棋盘使用的国际象棋棋盘界面。',
      'zh-Hant': '虛擬棋盤使用的西洋棋棋盤介面。',
      'de': 'Schachbrett-Oberfläche für das virtuelle Brett.',
      'es': 'Interfaz de tablero de ajedrez usada por el tablero virtual.',
      'fr': 'Interface d’échiquier utilisée par le plateau virtuel.',
      'it': 'Interfaccia della scacchiera usata dalla scacchiera virtuale.',
      'ja': '仮想ボードで使用するチェス盤 UI です。',
      'ko': '가상 보드에서 사용하는 체스판 UI입니다.',
      'nl': 'Schaakbordinterface voor het virtuele bord.',
      'ru': 'Интерфейс шахматной доски для виртуальной доски.',
    },
    'Licenses and Maia 3 source code': {
      'zh-Hans': '许可协议与 Maia 3 源码',
      'zh-Hant': '授權條款與 Maia 3 原始碼',
      'de': 'Lizenzen und Maia-3-Quellcode',
      'es': 'Licencias y código fuente de Maia 3',
      'fr': 'Licences et code source Maia 3',
      'it': 'Licenze e codice sorgente Maia 3',
      'ja': 'ライセンスと Maia 3 ソースコード',
      'ko': '라이선스 및 Maia 3 소스 코드',
      'nl': 'Licenties en Maia 3-broncode',
      'ru': 'Лицензии и исходный код Maia 3',
    },
    'Maia 3 inference service': {
      'zh-Hans': 'Maia 3 推理服务',
      'zh-Hant': 'Maia 3 推理服務',
      'de': 'Maia-3-Inferenzdienst',
      'es': 'Servicio de inferencia Maia 3',
      'fr': 'Service d’inférence Maia 3',
      'it': 'Servizio di inferenza Maia 3',
      'ja': 'Maia 3 推論サービス',
      'ko': 'Maia 3 추론 서비스',
      'nl': 'Maia 3-inferentieservice',
      'ru': 'Сервис инференса Maia 3',
    },
    'Maia 1 weights': {
      'zh-Hans': 'Maia 1 权重',
      'zh-Hant': 'Maia 1 權重',
      'de': 'Maia-1-Gewichte',
      'es': 'Pesos de Maia 1',
      'fr': 'Poids Maia 1',
      'it': 'Pesi Maia 1',
      'ja': 'Maia 1 重み',
      'ko': 'Maia 1 가중치',
      'nl': 'Maia 1-gewichten',
      'ru': 'Веса Maia 1',
    },
    'See Maia Chess project notices': {
      'zh-Hans': '查看 Maia Chess 项目说明',
      'zh-Hant': '查看 Maia Chess 專案說明',
      'de': 'Siehe Hinweise des Maia Chess-Projekts',
      'es': 'Consulta los avisos del proyecto Maia Chess',
      'fr': 'Voir les mentions du projet Maia Chess',
      'it': 'Vedi le note del progetto Maia Chess',
      'ja': 'Maia Chess プロジェクトの表記を参照',
      'ko': 'Maia Chess 프로젝트 고지 참조',
      'nl': 'Zie de vermeldingen van het Maia Chess-project',
      'ru': 'См. сведения проекта Maia Chess',
    },
    'Human-like chess model weights for Maia bot play.': {
      'zh-Hans': '用于 Maia 机器人对局、模拟人类风格的国际象棋模型权重。',
      'zh-Hant': '用於 Maia 機器人對局、模擬人類風格的西洋棋模型權重。',
      'de': 'Menschlich wirkende Schachmodell-Gewichte für Maia-Bot-Partien.',
      'es':
          'Pesos de modelo de ajedrez de estilo humano para partidas contra el bot Maia.',
      'fr':
          'Poids de modèle d’échecs au style humain pour les parties contre le bot Maia.',
      'it':
          'Pesi del modello scacchistico in stile umano per le partite contro il bot Maia.',
      'ja': 'Maia Bot 対局向けの、人間らしいチェスモデル重みです。',
      'ko': 'Maia 봇 대국을 위한 인간다운 체스 모델 가중치입니다.',
      'nl': 'Mensachtig schaakmodelgewicht voor Maia-botpartijen.',
      'ru': 'Веса шахматной модели в человеческом стиле для игры с ботом Maia.',
    },
    'Independent cloud service for Maia 3 bot moves and human review. The service source is published separately.':
        {
      'zh-Hans': '为 Maia 3 机器人走棋和真人复盘提供支持的独立云端服务。该服务源码单独发布。',
      'zh-Hant': '支援 Maia 3 機器人著法與真人複盤的獨立雲端服務。該服務原始碼另行發布。',
      'de':
          'Unabhängiger Cloud-Dienst für Maia-3-Bot-Züge und menschliche Reviews. Der Quellcode des Dienstes wird separat veröffentlicht.',
      'es':
          'Servicio independiente en la nube para jugadas del bot Maia 3 y revisión humana. El código fuente del servicio se publica por separado.',
      'fr':
          'Service cloud indépendant pour les coups du bot Maia 3 et la revue humaine. Le code source du service est publié séparément.',
      'it':
          'Servizio cloud indipendente per le mosse del bot Maia 3 e la revisione umana. Il codice sorgente del servizio è pubblicato separatamente.',
      'ja': 'Maia 3 の Bot 着手と人間レビューを支える独立クラウドサービスです。サービスのソースコードは別途公開されています。',
      'ko': 'Maia 3 봇 수와 인간 리뷰를 제공하는 독립 클라우드 서비스입니다. 이 서비스의 소스 코드는 별도로 공개됩니다.',
      'nl':
          'Onafhankelijke clouddienst voor Maia 3-botzetten en menselijke review. De broncode van de dienst wordt apart gepubliceerd.',
      'ru':
          'Независимый облачный сервис для ходов бота Maia 3 и анализа человеческой игры. Исходный код сервиса публикуется отдельно.',
    },
    'Maia 3 is integrated through an independent cloud service. That service is published under AGPL-3.0, while the Chessnut app and main backend communicate with it only through network APIs.':
        {
      'zh-Hans':
          'Maia 3 通过独立云端服务接入。该服务按 AGPL-3.0 开源发布，Chessnut App 和主后端只通过网络 API 与它通信。',
      'zh-Hant':
          'Maia 3 透過獨立雲端服務接入。該服務依 AGPL-3.0 開源發布，Chessnut App 與主後端只透過網路 API 與它通訊。',
      'de':
          'Maia 3 ist über einen unabhängigen Cloud-Dienst integriert. Dieser Dienst wird unter AGPL-3.0 veröffentlicht; die Chessnut-App und das Haupt-Backend kommunizieren nur über Netzwerk-APIs damit.',
      'es':
          'Maia 3 se integra mediante un servicio independiente en la nube. Ese servicio se publica bajo AGPL-3.0, mientras que la app Chessnut y el backend principal solo se comunican con él mediante API de red.',
      'fr':
          'Maia 3 est intégré via un service cloud indépendant. Ce service est publié sous AGPL-3.0, tandis que l’app Chessnut et le backend principal communiquent avec lui uniquement par API réseau.',
      'it':
          'Maia 3 è integrato tramite un servizio cloud indipendente. Quel servizio è pubblicato con licenza AGPL-3.0, mentre l’app Chessnut e il backend principale comunicano con esso solo tramite API di rete.',
      'ja':
          'Maia 3 は独立したクラウドサービスとして連携されています。このサービスは AGPL-3.0 で公開され、Chessnut アプリとメインバックエンドはネットワーク API のみで通信します。',
      'ko':
          'Maia 3는 독립적인 클라우드 서비스로 연동됩니다. 이 서비스는 AGPL-3.0으로 공개되며, Chessnut 앱과 메인 백엔드는 네트워크 API로만 통신합니다.',
      'nl':
          'Maia 3 is geïntegreerd via een onafhankelijke clouddienst. Die dienst wordt gepubliceerd onder AGPL-3.0, terwijl de Chessnut-app en de hoofdbackend er alleen via netwerk-API’s mee communiceren.',
      'ru':
          'Maia 3 интегрирован через независимый облачный сервис. Этот сервис публикуется под AGPL-3.0, а приложение Chessnut и основной backend взаимодействуют с ним только через сетевые API.',
    },
    'Open source code': {
      'zh-Hans': '打开源码',
      'zh-Hant': '開啟原始碼',
      'de': 'Quellcode öffnen',
      'es': 'Abrir código fuente',
      'fr': 'Ouvrir le code source',
      'it': 'Apri codice sorgente',
      'ja': 'ソースコードを開く',
      'ko': '소스 코드 열기',
      'nl': 'Broncode openen',
      'ru': 'Открыть исходный код',
    },
    'Could not open the source link. Please try again later.': {
      'zh-Hans': '无法打开源码链接，请稍后再试。',
      'zh-Hant': '無法開啟原始碼連結，請稍後再試。',
      'de':
          'Der Quellcode-Link konnte nicht geöffnet werden. Bitte versuche es später erneut.',
      'es':
          'No se pudo abrir el enlace del código fuente. Inténtalo más tarde.',
      'fr': 'Impossible d’ouvrir le lien du code source. Réessayez plus tard.',
      'it': 'Impossibile aprire il link al codice sorgente. Riprova più tardi.',
      'ja': 'ソースコードのリンクを開けませんでした。後でもう一度お試しください。',
      'ko': '소스 코드 링크를 열 수 없습니다. 나중에 다시 시도하세요.',
      'nl': 'Kan de broncodelink niet openen. Probeer het later opnieuw.',
      'ru': 'Не удалось открыть ссылку на исходный код. Попробуйте позже.',
    },
    'Purchase was not completed. You can try again when ready.': {
      'zh-Hans': '购买未完成。准备好后可以再次尝试。',
      'zh-Hant': '購買未完成。準備好後可以再次嘗試。',
      'de':
          'Der Kauf wurde nicht abgeschlossen. Versuche es erneut, wenn du bereit bist.',
      'es':
          'La compra no se completó. Puedes intentarlo de nuevo cuando quieras.',
      'fr':
          'L’achat n’a pas été finalisé. Vous pouvez réessayer quand vous voulez.',
      'it': 'L’acquisto non è stato completato. Puoi riprovare quando vuoi.',
      'ja': '購入は完了していません。準備ができたらもう一度お試しください。',
      'ko': '구매가 완료되지 않았습니다. 준비되면 다시 시도할 수 있습니다.',
      'nl':
          'De aankoop is niet voltooid. Je kunt het opnieuw proberen wanneer je wilt.',
      'ru': 'Покупка не завершена. Попробуйте снова, когда будете готовы.',
    },
    'Selected': {
      'zh-Hans': '已选择',
      'zh-Hant': '已選擇',
      'de': 'Ausgewählt',
      'es': 'Seleccionado',
      'fr': 'Sélectionné',
      'it': 'Selezionato',
      'ja': '選択中',
      'ko': '선택됨',
      'nl': 'Geselecteerd',
      'ru': 'Выбрано',
    },
    'Move quality lights': {
      'zh-Hans': '落子质量灯效',
      'zh-Hant': '落子品質燈效',
      'de': 'Zugqualitaets-Lichter',
      'es': 'Luces de calidad de jugada',
      'fr': 'Voyants de qualite du coup',
      'it': 'Luci qualita mossa',
      'ja': '手の品質ライト',
      'ko': '수 품질 표시등',
      'nl': 'Zetkwaliteitlichten',
      'ru': 'Подсветка качества хода',
    },
    'Choose a target': {
      'zh-Hans': '选择落点',
      'zh-Hant': '選擇落點',
      'de': 'Zielfeld wählen',
      'es': 'Elige una casilla',
      'fr': 'Choisissez une case',
      'it': 'Scegli una casa',
      'ja': '移動先を選択',
      'ko': '도착 칸 선택',
      'nl': 'Kies een doelveld',
      'ru': 'Выберите поле',
    },
    'Use color LEDs when a piece is lifted': {
      'zh-Hans': '抬起棋子时用彩色灯提示',
      'zh-Hant': '抬起棋子時用彩色燈提示',
      'de': 'Farben zeigen Ziele beim Anheben einer Figur',
      'es': 'Usa colores al levantar una pieza',
      'fr': 'Utilise les couleurs quand une piece est levee',
      'it': 'Usa colori quando sollevi un pezzo',
      'ja': '駒を持ち上げた時に色で表示',
      'ko': '기물을 들면 색상 LED로 표시',
      'nl': 'Gebruik kleuren wanneer een stuk wordt opgetild',
      'ru': 'Цвета при поднятии фигуры',
    },
    'Bot games only. Color LEDs rate moves when a piece is lifted.': {
      'zh-Hans': '仅电脑对局使用。抬起棋子时用彩色 LED 标记走法质量。',
      'zh-Hant': '僅電腦對局使用。抬起棋子時用彩色 LED 標記著法品質。',
      'de':
          'Nur Bot-Partien. Farb-LEDs bewerten Zuege, wenn eine Figur angehoben wird.',
      'es':
          'Solo partidas contra bot. Los LED de color valoran la jugada al levantar una pieza.',
      'fr':
          'Parties contre bot uniquement. Les LED couleur evaluent le coup quand une piece est levee.',
      'it':
          'Solo partite contro bot. I LED colorati valutano la mossa quando sollevi un pezzo.',
      'ja': 'Bot対局専用です。駒を持ち上げるとカラーLEDで手の質を示します。',
      'ko': '봇 대국 전용입니다. 기물을 들면 컬러 LED로 수의 품질을 표시합니다.',
      'nl':
          'Alleen botpartijen. Kleur-LEDs beoordelen zetten wanneer je een stuk optilt.',
      'ru':
          'Только игры с ботом. Цветные LED оценивают ход, когда фигура поднята.',
    },
    'Show scorebar': {
      'zh-Hans': '显示评分条',
      'zh-Hant': '顯示評分條',
      'de': 'Scorebar anzeigen',
      'es': 'Mostrar barra de evaluacion',
      'fr': 'Afficher la barre d evaluation',
      'it': 'Mostra barra valutazione',
      'ja': '評価バーを表示',
      'ko': '평가 바 표시',
      'nl': 'Scorebalk tonen',
      'ru': 'Показать шкалу оценки',
    },
    'Hide scorebar': {
      'zh-Hans': '隐藏评分条',
      'zh-Hant': '隱藏評分條',
      'de': 'Scorebar ausblenden',
      'es': 'Ocultar barra de evaluacion',
      'fr': 'Masquer la barre d evaluation',
      'it': 'Nascondi barra valutazione',
      'ja': '評価バーを非表示',
      'ko': '평가 바 숨기기',
      'nl': 'Scorebalk verbergen',
      'ru': 'Скрыть шкалу оценки',
    },
    'Show scorebar?': {
      'zh-Hans': '显示评分条？',
      'zh-Hant': '顯示評分條？',
      'de': 'Scorebar anzeigen?',
      'es': 'Mostrar barra de evaluacion?',
      'fr': 'Afficher la barre d evaluation ?',
      'it': 'Mostrare la barra valutazione?',
      'ja': '評価バーを表示しますか？',
      'ko': '평가 바를 표시할까요?',
      'nl': 'Scorebalk tonen?',
      'ru': 'Показать шкалу оценки?',
    },
    'Hide scorebar?': {
      'zh-Hans': '隐藏评分条？',
      'zh-Hant': '隱藏評分條？',
      'de': 'Scorebar ausblenden?',
      'es': 'Ocultar barra de evaluacion?',
      'fr': 'Masquer la barre d evaluation ?',
      'it': 'Nascondere la barra valutazione?',
      'ja': '評価バーを非表示にしますか？',
      'ko': '평가 바를 숨길까요?',
      'nl': 'Scorebalk verbergen?',
      'ru': 'Скрыть шкалу оценки?',
    },
    'Display the live Stockfish scorebar during bot games.': {
      'zh-Hans': '在电脑对局中显示实时 Stockfish 评分条。',
      'zh-Hant': '在電腦對局中顯示即時 Stockfish 評分條。',
      'de': 'Zeigt die Live-Stockfish-Scorebar in Bot-Partien.',
      'es': 'Muestra la barra Stockfish en vivo contra bots.',
      'fr': 'Affiche la barre Stockfish en direct contre les bots.',
      'it': 'Mostra la barra Stockfish live contro i bot.',
      'ja': 'Bot対局中にStockfishの評価バーを表示します。',
      'ko': '봇 대국 중 Stockfish 평가 바를 표시합니다.',
      'nl': 'Toont de live Stockfish-scorebalk in botpartijen.',
      'ru': 'Показывает шкалу Stockfish в партиях с ботом.',
    },
    'Hide the live Stockfish scorebar during bot games.': {
      'zh-Hans': '在电脑对局中隐藏实时 Stockfish 评分条。',
      'zh-Hant': '在電腦對局中隱藏即時 Stockfish 評分條。',
      'de': 'Blendet die Live-Stockfish-Scorebar in Bot-Partien aus.',
      'es': 'Oculta la barra Stockfish en vivo contra bots.',
      'fr': 'Masque la barre Stockfish en direct contre les bots.',
      'it': 'Nasconde la barra Stockfish live contro i bot.',
      'ja': 'Bot対局中のStockfish評価バーを非表示にします。',
      'ko': '봇 대국 중 Stockfish 평가 바를 숨깁니다.',
      'nl': 'Verbergt de live Stockfish-scorebalk in botpartijen.',
      'ru': 'Скрывает шкалу Stockfish в партиях с ботом.',
    },
    'Choose from Game Record': {
      'zh-Hans': '从对局记录选择',
      'zh-Hant': '從對局記錄選擇',
      'de': 'Aus Partieverlauf wählen',
      'es': 'Elegir del historial de partidas',
      'fr': 'Choisir dans l’historique des parties',
      'it': 'Scegli dalla cronologia partite',
      'ja': '対局記録から選択',
      'ko': '게임 기록에서 선택',
      'nl': 'Kiezen uit partijgeschiedenis',
      'ru': 'Выбрать из истории партий',
    },
    'Filter your saved games here, preview the usable PGNs, then start the build without leaving Engine Lab.':
        {
      'zh-Hans': '在这里筛选已保存的棋局，预览可用 PGN 数量，然后无需离开引擎实验室即可开始构建。',
      'zh-Hant': '在這裡篩選已儲存的棋局，預覽可用 PGN 數量，然後無需離開引擎實驗室即可開始建置。',
      'de':
          'Filtere hier gespeicherte Partien, prüfe die verwendbaren PGNs und starte den Build direkt im Engine Lab.',
      'es':
          'Filtra aquí tus partidas guardadas, revisa los PGN utilizables e inicia la creación sin salir de Engine Lab.',
      'fr':
          'Filtrez ici vos parties enregistrées, vérifiez les PGN utilisables, puis lancez la création sans quitter Engine Lab.',
      'it':
          'Filtra qui le partite salvate, controlla i PGN utilizzabili e avvia la creazione senza uscire da Engine Lab.',
      'ja': '保存済みの対局を絞り込み、使用可能な PGN 数を確認して、Engine Lab 内でそのままビルドを開始できます。',
      'ko': '저장된 게임을 필터링하고 사용 가능한 PGN 수를 확인한 뒤 Engine Lab에서 바로 빌드를 시작하세요.',
      'nl':
          'Filter hier opgeslagen partijen, bekijk de bruikbare PGN’s en start de build zonder Engine Lab te verlaten.',
      'ru':
          'Отфильтруйте сохранённые партии, проверьте доступные PGN и запустите сборку, не выходя из Engine Lab.',
    },
    'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.':
        {
      'zh-Hans': '在这里筛选已保存的棋局，预览可用 PGN，然后无需离开 Engine Lab 即可开始训练。',
      'zh-Hant': '在這裡篩選已儲存的棋局，預覽可用 PGN，然後不用離開 Engine Lab 即可開始訓練。',
      'de':
          'Filtere hier gespeicherte Partien, prüfe die verwendbaren PGNs und starte das Training direkt im Engine Lab.',
      'es':
          'Filtra aquí tus partidas guardadas, revisa los PGN utilizables e inicia el entrenamiento sin salir de Engine Lab.',
      'fr':
          'Filtrez ici vos parties enregistrées, vérifiez les PGN utilisables, puis lancez l’entraînement sans quitter Engine Lab.',
      'it':
          'Filtra qui le partite salvate, controlla i PGN utilizzabili e avvia l’allenamento senza uscire da Engine Lab.',
      'ja': '保存済みの対局をここで絞り込み、使える PGN を確認して、Engine Lab を離れずにトレーニングを開始できます。',
      'ko':
          '저장된 대국을 여기서 필터링하고 사용 가능한 PGN을 미리 확인한 뒤 Engine Lab을 나가지 않고 훈련을 시작하세요.',
      'nl':
          'Filter hier opgeslagen partijen, bekijk de bruikbare PGN’s en start de training zonder Engine Lab te verlaten.',
      'ru':
          'Отфильтруйте сохранённые партии, проверьте пригодные PGN и запустите обучение, не выходя из Engine Lab.',
    },
    'Search player or event': {
      'zh-Hans': '搜索棋手或赛事',
      'zh-Hant': '搜尋棋手或賽事',
      'de': 'Spieler oder Ereignis suchen',
      'es': 'Buscar jugador o evento',
      'fr': 'Rechercher un joueur ou un événement',
      'it': 'Cerca giocatore o evento',
      'ja': 'プレイヤーまたは大会を検索',
      'ko': '선수 또는 이벤트 검색',
      'nl': 'Speler of evenement zoeken',
      'ru': 'Поиск игрока или события',
    },
    'Min moves': {
      'zh-Hans': '最少回合数',
      'zh-Hant': '最少回合數',
      'de': 'Mindestzüge',
      'es': 'Movimientos mínimos',
      'fr': 'Nombre minimum de coups',
      'it': 'Mosse minime',
      'ja': '最少手数',
      'ko': '최소 수',
      'nl': 'Minimumzetten',
      'ru': 'Минимум ходов',
    },
    'Max games': {
      'zh-Hans': '最大棋局数',
      'zh-Hant': '最大棋局數',
      'de': 'Maximale Partien',
      'es': 'Máximo de partidas',
      'fr': 'Nombre maximal de parties',
      'it': 'Partite massime',
      'ja': '最大対局数',
      'ko': '최대 게임 수',
      'nl': 'Maximumaantal partijen',
      'ru': 'Максимум партий',
    },
    'Preview matching games': {
      'zh-Hans': '预览匹配棋局',
      'zh-Hant': '預覽符合條件的棋局',
      'de': 'Passende Partien prüfen',
      'es': 'Previsualizar partidas coincidentes',
      'fr': 'Prévisualiser les parties correspondantes',
      'it': 'Anteprima delle partite corrispondenti',
      'ja': '一致する対局を確認',
      'ko': '일치하는 게임 미리보기',
      'nl': 'Overeenkomende partijen bekijken',
      'ru': 'Предпросмотр подходящих партий',
    },
    'Preview ready': {
      'zh-Hans': '预览已就绪',
      'zh-Hant': '預覽已就緒',
      'de': 'Vorschau bereit',
      'es': 'Vista previa lista',
      'fr': 'Aperçu prêt',
      'it': 'Anteprima pronta',
      'ja': 'プレビュー完了',
      'ko': '미리보기 준비 완료',
      'nl': 'Voorbeeld gereed',
      'ru': 'Предпросмотр готов',
    },
    'Preparing preview': {
      'zh-Hans': '正在准备预览',
      'zh-Hant': '正在準備預覽',
      'de': 'Vorschau wird vorbereitet',
      'es': 'Preparando vista previa',
      'fr': 'Préparation de l’aperçu',
      'it': 'Preparazione anteprima',
      'ja': 'プレビューを準備中',
      'ko': '미리보기 준비 중',
      'nl': 'Voorbeeld voorbereiden',
      'ru': 'Подготовка предпросмотра',
    },
    'Game Record preview': {
      'zh-Hans': '对局记录预览',
      'zh-Hant': '對局記錄預覽',
      'de': 'Vorschau des Partieverlaufs',
      'es': 'Vista previa del historial de partidas',
      'fr': 'Aperçu de l’historique des parties',
      'it': 'Anteprima cronologia partite',
      'ja': '対局記録プレビュー',
      'ko': '게임 기록 미리보기',
      'nl': 'Voorbeeld van partijgeschiedenis',
      'ru': 'Предпросмотр истории партий',
    },
    'Video lessons with board checkpoints': {
      'zh-Hans': '带棋盘检查点的视频课程',
      'zh-Hant': '帶棋盤檢查點的影片課程',
      'de': 'Videolektionen mit Brett-Checkpoints',
      'es': 'Lecciones en video con puntos de control en el tablero',
      'fr': 'Leçons vidéo avec checkpoints sur l’échiquier',
      'it': 'Lezioni video con checkpoint sulla scacchiera',
      'ja': '盤面チェックポイント付き動画レッスン',
      'ko': '보드 체크포인트가 있는 영상 강좌',
      'nl': 'Videolessen met bordcheckpoints',
      'ru': 'Видеоуроки с контрольными точками на доске',
    },
    'Open course library': {
      'zh-Hans': '打开课程库',
      'zh-Hant': '開啟課程庫',
      'de': 'Kursbibliothek öffnen',
      'es': 'Abrir biblioteca de cursos',
      'fr': 'Ouvrir la bibliothèque de cours',
      'it': 'Apri la libreria dei corsi',
      'ja': 'コースライブラリを開く',
      'ko': '강좌 라이브러리 열기',
      'nl': 'Cursusbibliotheek openen',
      'ru': 'Открыть библиотеку курсов',
    },
    'Training modes': {
      'zh-Hans': '训练模式',
      'zh-Hant': '訓練模式',
      'de': 'Trainingsmodi',
      'es': 'Modos de entrenamiento',
      'fr': 'Modes d’entraînement',
      'it': 'Modalità di allenamento',
      'ja': 'トレーニングモード',
      'ko': '훈련 모드',
      'nl': 'Trainingsmodi',
      'ru': 'Режимы тренировки',
    },
    'Practice flow': {
      'zh-Hans': '练习流程',
      'zh-Hant': '練習流程',
      'de': 'Übungsablauf',
      'es': 'Flujo de práctica',
      'fr': 'Parcours d’entraînement',
      'it': 'Flusso di pratica',
      'ja': '練習フロー',
      'ko': '연습 흐름',
      'nl': 'Oefenflow',
      'ru': 'Ход тренировки',
    },
    'Warm up with tactics': {
      'zh-Hans': '用战术热身',
      'zh-Hant': '用戰術暖身',
      'de': 'Mit Taktik aufwärmen',
      'es': 'Calienta con táctica',
      'fr': 'Échauffement tactique',
      'it': 'Riscaldati con la tattica',
      'ja': '戦術でウォームアップ',
      'ko': '전술로 워밍업',
      'nl': 'Warm op met tactiek',
      'ru': 'Разминка тактикой',
    },
    'Quick tactics': {
      'zh-Hans': '快速战术',
      'zh-Hant': '快速戰術',
      'de': 'Schnelle Taktik',
      'es': 'Táctica rápida',
      'fr': 'Tactique rapide',
      'it': 'Tattiche rapide',
      'ja': 'クイック戦術',
      'ko': '빠른 전술',
      'nl': 'Snelle tactiek',
      'ru': 'Быстрая тактика',
    },
    'Review one weak spot': {
      'zh-Hans': '复盘一个薄弱点',
      'zh-Hant': '複盤一個弱點',
      'de': 'Eine Schwäche wiederholen',
      'es': 'Repasa un punto débil',
      'fr': 'Revoir un point faible',
      'it': 'Rivedi un punto debole',
      'ja': '弱点を一つ復習',
      'ko': '약점 하나 복습',
      'nl': 'Bekijk één zwak punt',
      'ru': 'Разберите одно слабое место',
    },
    'Personal review': {
      'zh-Hans': '个人复习',
      'zh-Hant': '個人複習',
      'de': 'Persönliche Wiederholung',
      'es': 'Repaso personal',
      'fr': 'Révision personnelle',
      'it': 'Revisione personale',
      'ja': '個人レビュー',
      'ko': '개인 복습',
      'nl': 'Persoonlijke review',
      'ru': 'Личный разбор',
    },
    'Analyze freely': {
      'zh-Hans': '自由分析',
      'zh-Hant': '自由分析',
      'de': 'Frei analysieren',
      'es': 'Analiza libremente',
      'fr': 'Analyser librement',
      'it': 'Analizza liberamente',
      'ja': '自由に分析',
      'ko': '자유 분석',
      'nl': 'Vrij analyseren',
      'ru': 'Свободный анализ',
    },
    'Free analysis': {
      'zh-Hans': '自由分析',
      'zh-Hant': '自由分析',
      'de': 'Freie Analyse',
      'es': 'Análisis libre',
      'fr': 'Analyse libre',
      'it': 'Analisi libera',
      'ja': '自由分析',
      'ko': '자유 분석',
      'nl': 'Vrije analyse',
      'ru': 'Свободный анализ',
    },
    'Short guided session': {
      'zh-Hans': '简短引导练习',
      'zh-Hant': '簡短引導練習',
      'de': 'Kurze geführte Einheit',
      'es': 'Sesión guiada breve',
      'fr': 'Courte session guidée',
      'it': 'Breve sessione guidata',
      'ja': '短いガイド練習',
      'ko': '짧은 가이드 세션',
      'nl': 'Korte begeleide sessie',
      'ru': 'Короткая тренировка с подсказками',
    },
    '5 tools': {
      'zh-Hans': '5 个工具',
      'zh-Hant': '5 個工具',
      'de': '5 Werkzeuge',
      'es': '5 herramientas',
      'fr': '5 outils',
      'it': '5 strumenti',
      'ja': '5つのツール',
      'ko': '도구 5개',
      'nl': '5 tools',
      'ru': '5 инструментов',
    },
    '15 min': {
      'zh-Hans': '15 分钟',
      'zh-Hant': '15 分鐘',
      'de': '15 Min.',
      'es': '15 min',
      'fr': '15 min',
      'it': '15 min',
      'ja': '15分',
      'ko': '15분',
      'nl': '15 min',
      'ru': '15 мин',
    },
    'Watch': {
      'zh-Hans': '观看',
      'zh-Hant': '觀看',
      'de': 'Ansehen',
      'es': 'Ver',
      'fr': 'Regarder',
      'it': 'Guarda',
      'ja': '視聴',
      'ko': '보기',
      'nl': 'Kijken',
      'ru': 'Смотреть',
    },
    'Lights': {
      'zh-Hans': '灯光',
      'zh-Hant': '燈光',
      'de': 'Lichter',
      'es': 'Luces',
      'fr': 'Lumières',
      'it': 'Luci',
      'ja': 'ライト',
      'ko': '라이트',
      'nl': 'Lichten',
      'ru': 'Подсветка',
    },
  };
  return translations[text]?[key];
}

String? _manualDirectTranslations(String text, String key) {
  final releaseCleanup = _releaseCleanupTranslations(text, key);
  if (releaseCleanup != null) return releaseCleanup;

  const translations = <String, Map<String, String>>{
    // Grandeur summary statistics.  These labels are rendered from the
    // backend's tag definitions, so keep every supported locale here rather
    // than leaving the newer Accurate/Normal labels in English.
    'Accurate': {
      'zh-Hans': '准确',
      'zh-Hant': '準確',
      'de': 'Genau',
      'es': 'Precisa',
      'fr': 'Précis',
      'it': 'Preciso',
      'ja': '正確',
      'ko': '정확함',
      'nl': 'Accuraat',
      'ru': 'Точный',
      'pt': 'Preciso',
      'pl': 'Dokładny',
      'ro': 'Precisă',
      'cs': 'Přesný',
      'ar': 'دقيق',
      'he': 'מדויק',
    },
    'Normal': {
      'zh-Hans': '正常',
      'zh-Hant': '正常',
      'de': 'Normal',
      'es': 'Normal',
      'fr': 'Normal',
      'it': 'Normale',
      'ja': '通常',
      'ko': '보통',
      'nl': 'Normaal',
      'ru': 'Обычный',
      'pt': 'Normal',
      'pl': 'Normalny',
      'ro': 'Normal',
      'cs': 'Normální',
      'ar': 'عادي',
      'he': 'רגיל',
    },
    'Statistics List': {
      'zh-Hans': '统计列表',
      'zh-Hant': '統計列表',
      'de': 'Statistikliste',
      'es': 'Lista de estadísticas',
      'fr': 'Liste des statistiques',
      'it': 'Elenco statistiche',
      'ja': '統計リスト',
      'ko': '통계 목록',
      'nl': 'Statistiekenlijst',
      'ru': 'Список статистики',
      'pt': 'Lista de estatísticas',
      'pl': 'Lista statystyk',
      'ro': 'Lista statisticilor',
      'cs': 'Seznam statistik',
      'ar': 'قائمة الإحصاءات',
      'he': 'רשימת הסטטיסטיקות',
    },
    'Copy URL': {
      'zh-Hans': '复制URL',
      'zh-Hant': '複製URL',
    },
    'URL copied': {
      'zh-Hans': 'URL已复制',
      'zh-Hant': 'URL已複製',
    },
    'Connected': {
      'zh-Hans': '已连接',
      'zh-Hant': '已連線',
      'de': 'Verbunden',
      'es': 'Conectado',
      'fr': 'Connecté',
      'it': 'Connesso',
      'ja': '接続済み',
      'ko': '연결됨',
      'nl': 'Verbonden',
      'ru': 'Подключено',
    },
    'Disconnected': {
      'zh-Hans': '已断开',
      'zh-Hant': '已斷線',
      'de': 'Getrennt',
      'es': 'Desconectado',
      'fr': 'Déconnecté',
      'it': 'Disconnesso',
      'ja': '未接続',
      'ko': '연결 해제됨',
      'nl': 'Niet verbonden',
      'ru': 'Отключено',
    },
    'FEN position': {
      'zh-Hans': 'FEN 局面',
      'zh-Hant': 'FEN 局面',
      'de': 'FEN-Stellung',
      'es': 'Posición FEN',
      'fr': 'Position FEN',
      'it': 'Posizione FEN',
      'ja': 'FEN 局面',
      'ko': 'FEN 포지션',
      'nl': 'FEN-stelling',
      'ru': 'Позиция FEN',
    },
    'All analysis reports': {
      'zh-Hans': '全部分析报告',
      'zh-Hant': '全部分析報告',
      'de': 'Alle Analyseberichte',
      'es': 'Todos los informes de análisis',
      'fr': 'Tous les rapports d’analyse',
      'it': 'Tutti i report di analisi',
      'ja': 'すべての分析レポート',
      'ko': '모든 분석 보고서',
      'nl': 'Alle analyserapporten',
      'ru': 'Все отчёты анализа',
    },
    'No analysis': {
      'zh-Hans': '未分析',
      'zh-Hant': '未分析',
      'de': 'Nicht analysiert',
      'es': 'Sin análisis',
      'fr': 'Non analysé',
      'it': 'Non analizzata',
      'ja': '未分析',
      'ko': '분석 안 됨',
      'nl': 'Niet geanalyseerd',
      'ru': 'Без анализа',
    },
    'Standard analysis': {
      'zh-Hans': '普通分析',
      'zh-Hant': '一般分析',
      'de': 'Standardanalyse',
      'es': 'Análisis estándar',
      'fr': 'Analyse standard',
      'it': 'Analisi standard',
      'ja': '標準分析',
      'ko': '표준 분석',
      'nl': 'Standaardanalyse',
      'ru': 'Стандартный анализ',
    },
    'Analysis type': {
      'zh-Hans': '分析类型',
      'zh-Hant': '分析類型',
      'de': 'Analysetyp',
      'es': 'Tipo de análisis',
      'fr': 'Type d’analyse',
      'it': 'Tipo di analisi',
      'ja': '分析タイプ',
      'ko': '분석 유형',
      'nl': 'Analysetype',
      'ru': 'Тип анализа',
    },
    'Bug report sent. Thank you for helping us fix it.': {
      'zh-Hans': '错误报告已发送，感谢你帮助我们修复。',
      'zh-Hant': '錯誤報告已送出，感謝你幫助我們修復。',
      'de': 'Fehlerbericht gesendet. Danke fürs Helfen bei der Behebung.',
      'es': 'Informe de error enviado. Gracias por ayudarnos a arreglarlo.',
      'fr': 'Rapport de bug envoyé. Merci de nous aider à le corriger.',
      'it': 'Segnalazione inviata. Grazie per aiutarci a correggerlo.',
      'ja': 'バグ報告を送信しました。修正にご協力ありがとうございます。',
      'ko': '버그 보고가 전송되었습니다. 수정에 도와주셔서 감사합니다.',
      'nl': 'Foutmelding verzonden. Bedankt om ons te helpen het te fixen.',
      'ru':
          'Сообщение об ошибке отправлено. Спасибо, что помогаете нам исправлять её.',
    },
    'Could not send the report. Please try again.': {
      'zh-Hans': '无法发送报告，请重试。',
      'zh-Hant': '無法送出報告，請重試。',
      'de':
          'Der Bericht konnte nicht gesendet werden. Bitte versuche es erneut.',
      'es': 'No se pudo enviar el informe. Inténtalo de nuevo.',
      'fr': "Impossible d'envoyer le rapport. Réessayez.",
      'it': 'Impossibile inviare la segnalazione. Riprova.',
      'ja': 'レポートを送信できませんでした。もう一度お試しください。',
      'ko': '보고서를 보낼 수 없습니다. 다시 시도하세요.',
      'nl': 'Kan het rapport niet verzenden. Probeer het opnieuw.',
      'ru': 'Не удалось отправить отчёт. Попробуйте ещё раз.',
    },
    'Go to Daily Tasks': {
      'zh-Hans': '前往每日任务',
      'zh-Hant': '前往每日任務',
      'de': 'Zu den täglichen Aufgaben',
      'es': 'Ir a tareas diarias',
      'fr': 'Aller aux tâches quotidiennes',
      'it': 'Vai alle attività giornaliere',
      'ja': 'デイリータスクへ',
      'ko': '일일 과제로 이동',
      'nl': 'Naar dagelijkse taken',
      'ru': 'Перейти к ежедневным заданиям',
    },
    'Go to Daily Tasks to earn points, then return to Analysis.': {
      'zh-Hans': '先去每日任务赚取积分，再返回分析。',
      'zh-Hant': '先去每日任務賺取積分，再返回分析。',
      'de':
          'Verdiene Punkte bei den täglichen Aufgaben und kehre dann zur Analyse zurück.',
      'es': 'Gana puntos en tareas diarias y luego vuelve al análisis.',
      'fr':
          "Gagnez des points dans les tâches quotidiennes, puis revenez à l’analyse.",
      'it':
          'Guadagna punti nelle attività giornaliere e poi torna all’analisi.',
      'ja': 'デイリータスクでポイントを獲得してから、分析に戻ってください。',
      'ko': '일일 과제에서 포인트를 얻은 뒤 분석으로 돌아가세요.',
      'nl':
          'Verdien punten bij de dagelijkse taken en keer daarna terug naar Analyse.',
      'ru':
          'Заработайте очки в ежедневных заданиях, затем вернитесь к анализу.',
    },
    'Grandeur review costs 100 wallet points.': {
      'zh-Hans': 'Grandeur 复盘消耗 100 钱包积分。',
      'zh-Hant': 'Grandeur 複盤消耗 100 錢包積分。',
      'de': 'Grandeur-Analyse kostet 100 Wallet-Punkte.',
      'es': 'La revisión Grandeur cuesta 100 puntos de cartera.',
      'fr': 'La revue Grandeur coûte 100 points de portefeuille.',
      'it': 'La revisione Grandeur costa 100 punti portafoglio.',
      'ja': 'Grandeur のレビューにはウォレット 100 ポイントが必要です。',
      'ko': 'Grandeur 검토에는 지갑 포인트 100점이 필요합니다.',
      'nl': 'Grandeur-analyse kost 100 walletpunten.',
      'ru': 'Проверка Grandeur стоит 100 очков кошелька.',
    },
    'Grandeur Summary': {
      'zh-Hans': 'Grandeur 总结',
      'zh-Hant': 'Grandeur 總結',
      'de': 'Grandeur-Zusammenfassung',
      'es': 'Resumen de Grandeur',
      'fr': 'Résumé Grandeur',
      'it': 'Riepilogo Grandeur',
      'ja': 'Grandeur サマリー',
      'ko': 'Grandeur 요약',
      'nl': 'Grandeur-samenvatting',
      'ru': 'Сводка Grandeur',
    },
    'Position ready.': {
      'zh-Hans': '局面已就绪。',
      'zh-Hant': '局面已就緒。',
      'de': 'Stellung bereit.',
      'es': 'Posición lista.',
      'fr': 'Position prête.',
      'it': 'Posizione pronta.',
      'ja': '局面の準備ができました。',
      'ko': '포지션이 준비되었습니다.',
      'nl': 'Stelling gereed.',
      'ru': 'Позиция готова.',
    },
    'FEN loaded.': {
      'zh-Hans': 'FEN 已载入。',
      'zh-Hant': 'FEN 已載入。',
      'de': 'FEN geladen.',
      'es': 'FEN cargado.',
      'fr': 'FEN chargé.',
      'it': 'FEN caricato.',
      'ja': 'FEN を読み込みました。',
      'ko': 'FEN을 불러왔습니다.',
      'nl': 'FEN geladen.',
      'ru': 'FEN загружен.',
    },
    'FEN load failed.': {
      'zh-Hans': 'FEN 载入失败。',
      'zh-Hant': 'FEN 載入失敗。',
      'de': 'FEN-Laden fehlgeschlagen.',
      'es': 'Error al cargar FEN.',
      'fr': 'Échec du chargement du FEN.',
      'it': 'Caricamento FEN non riuscito.',
      'ja': 'FEN の読み込みに失敗しました。',
      'ko': 'FEN 불러오기에 실패했습니다.',
      'nl': 'FEN laden mislukt.',
      'ru': 'Не удалось загрузить FEN.',
    },
    'Move the pieces to start analysis.': {
      'zh-Hans': '移动棋子开始分析。',
      'zh-Hant': '移動棋子開始分析。',
      'de': 'Ziehe die Figuren, um die Analyse zu starten.',
      'es': 'Mueve las piezas para comenzar el análisis.',
      'fr': 'Déplacez les pièces pour lancer l’analyse.',
      'it': 'Sposta i pezzi per avviare l’analisi.',
      'ja': '駒を動かして分析を開始してください。',
      'ko': '기물을 움직여 분석을 시작하세요.',
      'nl': 'Zet de stukken om de analyse te starten.',
      'ru': 'Переместите фигуры, чтобы начать анализ.',
    },
    'Stockfish live analysis ready.': {
      'zh-Hans': 'Stockfish 实时分析已就绪。',
      'zh-Hant': 'Stockfish 即時分析已就緒。',
      'de': 'Stockfish-Liveanalyse ist bereit.',
      'es': 'El análisis en vivo de Stockfish está listo.',
      'fr': 'L’analyse en direct de Stockfish est prête.',
      'it': 'L’analisi live di Stockfish è pronta.',
      'ja': 'Stockfish のライブ解析の準備ができました。',
      'ko': 'Stockfish 실시간 분석이 준비되었습니다.',
      'nl': 'Stockfish-liveanalyse is klaar.',
      'ru': 'Живой анализ Stockfish готов.',
    },
    'Selected PGN files': {
      'zh-Hans': '已选择的 PGN 文件',
      'zh-Hant': '已選取的 PGN 檔案',
      'de': 'Ausgewählte PGN-Dateien',
      'es': 'Archivos PGN seleccionados',
      'fr': 'Fichiers PGN sélectionnés',
      'it': 'File PGN selezionati',
      'ja': '選択した PGN ファイル',
      'ko': '선택한 PGN 파일',
      'nl': 'Geselecteerde PGN-bestanden',
      'ru': 'Выбранные PGN-файлы',
    },
    'Choose PGN files': {
      'zh-Hans': '选择 PGN 文件',
      'zh-Hant': '選擇 PGN 檔案',
      'de': 'PGN-Dateien wählen',
      'es': 'Elegir archivos PGN',
      'fr': 'Choisir des fichiers PGN',
      'it': 'Scegli file PGN',
      'ja': 'PGN ファイルを選択',
      'ko': 'PGN 파일 선택',
      'nl': 'PGN-bestanden kiezen',
      'ru': 'Выбрать PGN-файлы',
    },
    'Model details': {
      'zh-Hans': '模型详情',
      'zh-Hant': '模型詳情',
      'de': 'Modelldetails',
      'es': 'Detalles del modelo',
      'fr': 'Détails du modèle',
      'it': 'Dettagli del modello',
      'ja': 'モデルの詳細',
      'ko': '모델 세부정보',
      'nl': 'Modeldetails',
      'ru': 'Сведения о модели',
    },
    'Build rules': {
      'zh-Hans': '构建规则',
      'zh-Hant': '建置規則',
      'de': 'Build-Regeln',
      'es': 'Reglas de compilación',
      'fr': 'Règles de build',
      'it': 'Regole di build',
      'ja': 'ビルド規則',
      'ko': '빌드 규칙',
      'nl': 'Buildregels',
      'ru': 'Правила сборки',
    },
    'Share one report': {
      'zh-Hans': '分享一份报告',
      'zh-Hant': '分享一份報告',
      'de': 'Einen Bericht teilen',
      'es': 'Compartir un informe',
      'fr': 'Partager un rapport',
      'it': 'Condividi un report',
      'ja': 'レポートを1件共有',
      'ko': '리포트 1개 공유',
      'nl': 'Eén rapport delen',
      'ru': 'Поделиться одним отчетом',
    },
    'Share a Standard or Grandeur report image.': {
      'zh-Hans': '分享 Standard 或 Grandeur 报告图片。',
      'zh-Hant': '分享 Standard 或 Grandeur 報告圖片。',
      'de': 'Teile ein Standard- oder Grandeur-Berichtsbild.',
      'es': 'Comparte una imagen de informe Standard o Grandeur.',
      'fr': 'Partagez une image de rapport Standard ou Grandeur.',
      'it': 'Condividi un’immagine del report Standard o Grandeur.',
      'ja': 'StandardまたはGrandeurのレポート画像を共有します。',
      'ko': 'Standard 또는 Grandeur 리포트 이미지를 공유하세요.',
      'nl': 'Deel een Standard- of Grandeur-rapportafbeelding.',
      'ru': 'Поделитесь изображением отчета Standard или Grandeur.',
    },
    'Share a report or game': {
      'zh-Hans': '分享报告或对局',
      'zh-Hant': '分享報告或對局',
      'de': 'Bericht oder Partie teilen',
      'es': 'Compartir informe o partida',
      'fr': 'Partager un rapport ou une partie',
      'it': 'Condividi rapporto o partita',
      'ja': 'レポートまたは対局を共有',
      'ko': '보고서 또는 대국 공유',
      'nl': 'Rapport of partij delen',
      'ru': 'Поделиться отчетом или партией',
    },
    'Share a report image, live link, or recorded game.': {
      'zh-Hans': '分享报告长图、实时链接或已记录的对局。',
      'zh-Hant': '分享報告長圖、即時連結或已記錄的對局。',
      'de':
          'Teile ein Berichtsbild, einen Live-Link oder eine gespeicherte Partie.',
      'es':
          'Comparte una imagen del informe, un enlace en vivo o una partida guardada.',
      'fr':
          'Partagez une image du rapport, un lien en direct ou une partie enregistrée.',
      'it':
          'Condividi un’immagine del rapporto, un link live o una partita registrata.',
      'ja': 'レポート画像、ライブリンク、または保存済みの対局を共有します。',
      'ko': '보고서 이미지, 실시간 링크 또는 저장된 대국을 공유합니다.',
      'nl': 'Deel een rapportafbeelding, live-link of opgeslagen partij.',
      'ru':
          'Поделитесь изображением отчета, live-ссылкой или сохраненной партией.',
    },
    'Report image ready to share.': {
      'zh-Hans': '报告图片已准备好分享。',
      'zh-Hant': '報告圖片已準備好分享。',
      'de': 'Berichtsbild ist bereit zum Teilen.',
      'es': 'La imagen del informe está lista para compartir.',
      'fr': 'L’image du rapport est prête à être partagée.',
      'it': 'L’immagine del rapporto è pronta per la condivisione.',
      'ja': 'レポート画像を共有できます。',
      'ko': '보고서 이미지를 공유할 준비가 되었습니다.',
      'nl': 'Rapportafbeelding is klaar om te delen.',
      'ru': 'Изображение отчета готово к отправке.',
    },
    'Unable to share report image.': {
      'zh-Hans': '无法分享报告图片。',
      'zh-Hant': '無法分享報告圖片。',
      'de': 'Berichtsbild kann nicht geteilt werden.',
      'es': 'No se pudo compartir la imagen del informe.',
      'fr': 'Impossible de partager l’image du rapport.',
      'it': 'Impossibile condividere l’immagine del rapporto.',
      'ja': 'レポート画像を共有できません。',
      'ko': '보고서 이미지를 공유할 수 없습니다.',
      'nl': 'Kan rapportafbeelding niet delen.',
      'ru': 'Не удалось поделиться изображением отчета.',
    },
    'Share report image': {
      'zh-Hans': '分享报告图片',
      'zh-Hant': '分享報告圖片',
      'de': 'Berichtsbild teilen',
      'es': 'Compartir imagen del informe',
      'fr': 'Partager l’image du rapport',
      'it': 'Condividi immagine del rapporto',
      'ja': 'レポート画像を共有',
      'ko': '보고서 이미지 공유',
      'nl': 'Rapportafbeelding delen',
      'ru': 'Поделиться изображением отчета',
    },
  };
  return translations[text]?[key];
}

String? _releaseCleanupTranslations(String text, String key) {
  const translations = <String, Map<String, String>>{
    'Use at least 8 characters and any 2 character types.': {
      'zh-Hans': '至少 8 个字符，任选 2 类字符。',
      'zh-Hant': '至少 8 個字元，任選 2 類字元。',
      'de': 'Mind. 8 Zeichen und 2 Zeichentypen.',
      'es': 'Mín. 8 caracteres y 2 tipos.',
      'fr': '8 caractères min. et 2 types.',
      'it': 'Min. 8 caratteri e 2 tipi.',
      'ja': '8文字以上、任意の2種類',
      'ko': '8자 이상, 문자 유형 2가지',
      'nl': 'Min. 8 tekens en 2 typen.',
      'ru': 'От 8 символов и 2 типа.',
    },
    'Choose any 2': {
      'zh-Hans': '任选 2 类',
      'zh-Hant': '任選 2 類',
      'de': '2 wählen',
      'es': 'Elige 2',
      'fr': 'Choisir 2',
      'it': 'Scegli 2',
      'ja': '2種類選択',
      'ko': '2가지 선택',
      'nl': 'Kies 2',
      'ru': 'Выберите 2',
    },
    'Password meets the rules': {
      'zh-Hans': '密码符合要求',
      'zh-Hant': '密碼符合要求',
      'de': 'Passwort erfüllt die Regeln',
      'es': 'La contraseña cumple las reglas',
      'fr': 'Le mot de passe respecte les règles',
      'it': 'La password rispetta le regole',
      'ja': 'パスワードは条件を満たしています',
      'ko': '비밀번호가 규칙을 충족합니다',
      'nl': 'Wachtwoord voldoet aan de regels',
      'ru': 'Пароль соответствует правилам',
    },
    'Password needs attention': {
      'zh-Hans': '密码需调整',
      'zh-Hant': '密碼需調整',
      'de': 'Passwort prüfen',
      'es': 'Revisa la contraseña',
      'fr': 'Mot de passe à vérifier',
      'it': 'Controlla la password',
      'ja': 'パスワードを確認してください',
      'ko': '비밀번호 확인 필요',
      'nl': 'Controleer wachtwoord',
      'ru': 'Проверьте пароль',
    },
    'Use 8+ characters and at least two types: uppercase, lowercase, number, or symbol.':
        {
      'zh-Hans': '请使用至少 8 个字符，并包含大写字母、小写字母、数字或符号中的任意两类。',
      'zh-Hant': '請使用至少 8 個字元，並包含大寫字母、小寫字母、數字或符號中的任意兩類。',
      'de':
          'Nutze mindestens 8 Zeichen und zwei Arten: Großbuchstaben, Kleinbuchstaben, Zahlen oder Symbole.',
      'es':
          'Usa al menos 8 caracteres y dos tipos: mayúsculas, minúsculas, números o símbolos.',
      'fr':
          'Utilisez au moins 8 caractères et deux types : majuscules, minuscules, chiffres ou symboles.',
      'it':
          'Usa almeno 8 caratteri e due tipi: maiuscole, minuscole, numeri o simboli.',
      'ja': '8文字以上で、大文字・小文字・数字・記号のうち2種類以上を含めてください。',
      'ko': '8자 이상이며 대문자, 소문자, 숫자, 기호 중 두 종류 이상을 포함하세요.',
      'nl':
          'Gebruik minimaal 8 tekens en twee typen: hoofdletters, kleine letters, cijfers of symbolen.',
      'ru':
          'Используйте минимум 8 символов и два типа: заглавные, строчные, цифры или символы.',
    },
    '8+ characters': {
      'zh-Hans': '至少 8 位',
      'zh-Hant': '至少 8 位',
      'de': '8+ Zeichen',
      'es': '8+ caracteres',
      'fr': '8+ caractères',
      'it': '8+ caratteri',
      'ja': '8文字以上',
      'ko': '8자 이상',
      'nl': '8+ tekens',
      'ru': '8+ символов',
    },
    'At least two character types': {
      'zh-Hans': '至少两类字符',
      'zh-Hant': '至少兩類字元',
      'de': 'Mindestens zwei Zeichentypen',
      'es': 'Al menos dos tipos',
      'fr': 'Au moins deux types',
      'it': 'Almeno due tipi',
      'ja': '2種類以上',
      'ko': '두 종류 이상',
      'nl': 'Minstens twee typen',
      'ru': 'Минимум два типа',
    },
    'Uppercase': {
      'zh-Hans': '大写字母',
      'zh-Hant': '大寫字母',
      'de': 'Großbuchstaben',
      'es': 'Mayúsculas',
      'fr': 'Majuscules',
      'it': 'Maiuscole',
      'ja': '大文字',
      'ko': '대문자',
      'nl': 'Hoofdletters',
      'ru': 'Заглавные',
    },
    'Lowercase': {
      'zh-Hans': '小写字母',
      'zh-Hant': '小寫字母',
      'de': 'Kleinbuchstaben',
      'es': 'Minúsculas',
      'fr': 'Minuscules',
      'it': 'Minuscole',
      'ja': '小文字',
      'ko': '소문자',
      'nl': 'Kleine letters',
      'ru': 'Строчные',
    },
    'Number': {
      'zh-Hans': '数字',
      'zh-Hant': '數字',
      'de': 'Zahl',
      'es': 'Número',
      'fr': 'Chiffre',
      'it': 'Numero',
      'ja': '数字',
      'ko': '숫자',
      'nl': 'Cijfer',
      'ru': 'Цифра',
    },
    'Symbol': {
      'zh-Hans': '符号',
      'zh-Hant': '符號',
      'de': 'Sonderzeichen',
      'es': 'Símbolo',
      'fr': 'Symbole',
      'it': 'Simbolo',
      'ja': '記号',
      'ko': '기호',
      'nl': 'Symbool',
      'ru': 'Символ',
    },
    'Choose one theme below the board.': {
      'zh-Hans': '在棋盘下方选择一个主题。',
      'zh-Hant': '在棋盤下方選擇一個主題。',
      'de': 'Wähle unter dem Brett ein Thema.',
      'es': 'Elige un tema debajo del tablero.',
      'fr': 'Choisissez un thème sous l’échiquier.',
      'it': 'Scegli un tema sotto la scacchiera.',
      'ja': '盤の下でテーマを1つ選びます。',
      'ko': '보드 아래에서 테마 하나를 선택하세요.',
      'nl': 'Kies één thema onder het bord.',
      'ru': 'Выберите одну тему под доской.',
    },
    'This theme is not available yet. Try another theme.': {
      'zh-Hans': '这个主题暂不可用，请试试其他主题。',
      'zh-Hant': '這個主題暫不可用，請試試其他主題。',
      'de': 'Dieses Thema ist noch nicht verfügbar. Wähle ein anderes.',
      'es': 'Este tema aún no está disponible. Prueba otro.',
      'fr': 'Ce thème n’est pas encore disponible. Essayez-en un autre.',
      'it': 'Questo tema non è ancora disponibile. Provane un altro.',
      'ja': 'このテーマはまだ利用できません。別のテーマをお試しください。',
      'ko': '이 테마는 아직 사용할 수 없습니다. 다른 테마를 시도하세요.',
      'nl': 'Dit thema is nog niet beschikbaar. Probeer een ander thema.',
      'ru': 'Эта тема пока недоступна. Попробуйте другую.',
    },
    'More puzzle themes available for this session': {
      'zh-Hans': '本次练习可用的更多题目主题',
      'zh-Hant': '本次練習可用的更多題目主題',
      'de': 'Weitere Aufgabenthemen für diese Sitzung',
      'es': 'Más temas de problemas para esta sesión',
      'fr': 'Plus de thèmes de puzzles pour cette session',
      'it': 'Altri temi di puzzle per questa sessione',
      'ja': 'このセッションで使える追加パズルテーマ',
      'ko': '이번 세션에서 사용할 수 있는 추가 퍼즐 테마',
      'nl': 'Meer puzzelthema’s voor deze sessie',
      'ru': 'Больше тем задач для этой сессии',
    },
    'Fresh puzzle theme from the live library.': {
      'zh-Hans': '来自在线题库的新主题。',
      'zh-Hant': '來自線上題庫的新主題。',
      'de': 'Frisches Aufgabenthema aus der Online-Bibliothek.',
      'es': 'Tema nuevo desde la biblioteca en línea.',
      'fr': 'Nouveau thème depuis la bibliothèque en ligne.',
      'it': 'Nuovo tema dalla libreria online.',
      'ja': 'オンラインライブラリからの新しいパズルテーマです。',
      'ko': '온라인 라이브러리에서 가져온 새로운 퍼즐 테마입니다.',
      'nl': 'Nieuw puzzelthema uit de online bibliotheek.',
      'ru': 'Новая тема задач из онлайн-библиотеки.',
    },
    'Local QA wallet tools': {
      'zh-Hans': '本地 QA 钱包工具',
      'zh-Hant': '本地 QA 錢包工具',
      'de': 'Lokale QA-Wallet-Tools',
      'es': 'Herramientas locales de QA para wallet',
      'fr': 'Outils wallet QA locaux',
      'it': 'Strumenti wallet QA locali',
      'ja': 'ローカルQAウォレットツール',
      'ko': '로컬 QA 지갑 도구',
      'nl': 'Lokale QA-wallettools',
      'ru': 'Локальные QA-инструменты кошелька',
    },
    'Hidden unless the local QA build flag is enabled.': {
      'zh-Hans': '仅在启用本地 QA 构建开关时显示。',
      'zh-Hant': '僅在啟用本地 QA 建置開關時顯示。',
      'de': 'Nur sichtbar, wenn der lokale QA-Build-Schalter aktiv ist.',
      'es': 'Solo aparece si el flag local de QA está activado.',
      'fr': 'Visible seulement si l’option de build QA locale est activée.',
      'it': 'Visibile solo se il flag build QA locale è attivo.',
      'ja': 'ローカルQAビルドフラグが有効な場合だけ表示されます。',
      'ko': '로컬 QA 빌드 플래그가 켜진 경우에만 표시됩니다.',
      'nl': 'Alleen zichtbaar als de lokale QA-buildvlag aanstaat.',
      'ru': 'Отображается только при включённом локальном QA-флаге сборки.',
    },
    'Your Chessnut Move firmware is current. If an update becomes available, it will appear here.':
        {
      'zh-Hans': '你的 Chessnut Move 固件已是最新版本。有可用更新时会显示在这里。',
      'zh-Hant': '你的 Chessnut Move 韌體已是最新版本。有可用更新時會顯示在這裡。',
      'de':
          'Deine Chessnut Move-Firmware ist aktuell. Verfügbare Updates erscheinen hier.',
      'es':
          'El firmware de tu Chessnut Move está actualizado. Si hay una actualización, aparecerá aquí.',
      'fr':
          'Le firmware de votre Chessnut Move est à jour. Les mises à jour disponibles apparaîtront ici.',
      'it':
          'Il firmware di Chessnut Move è aggiornato. Gli aggiornamenti disponibili appariranno qui.',
      'ja': 'Chessnut Move のファームウェアは最新です。更新が利用可能になるとここに表示されます。',
      'ko': 'Chessnut Move 펌웨어가 최신입니다. 업데이트가 있으면 여기에 표시됩니다.',
      'nl':
          'Je Chessnut Move-firmware is actueel. Beschikbare updates verschijnen hier.',
      'ru':
          'Прошивка Chessnut Move актуальна. Если появится обновление, оно будет показано здесь.',
    },
    'Chessnut trains with most games and keeps a smaller set to check quality.':
        {
      'zh-Hans': 'Chessnut 会用大多数对局训练，并保留一小部分用于检查质量。',
      'zh-Hant': 'Chessnut 會用大多數對局訓練，並保留一小部分用於檢查品質。',
      'de':
          'Chessnut trainiert mit den meisten Partien und behält eine kleinere Gruppe zur Qualitätsprüfung.',
      'es':
          'Chessnut entrena con la mayoría de partidas y reserva un grupo menor para comprobar la calidad.',
      'fr':
          'Chessnut entraîne avec la plupart des parties et garde un plus petit ensemble pour vérifier la qualité.',
      'it':
          'Chessnut si allena con la maggior parte delle partite e ne conserva un gruppo più piccolo per controllare la qualità.',
      'ja': 'Chessnut は大半の対局でトレーニングし、品質確認用に小さなセットを残します。',
      'ko': 'Chessnut은 대부분의 대국으로 훈련하고, 품질 확인용으로 작은 세트를 남깁니다.',
      'nl':
          'Chessnut traint met de meeste partijen en bewaart een kleinere set voor kwaliteitscontrole.',
      'ru':
          'Chessnut обучается на большинстве партий и оставляет меньший набор для проверки качества.',
    },
    'Completed builds become Bot game engine choices.': {
      'zh-Hans': '完成后的模型会出现在 Bot game 的引擎选项中。',
      'zh-Hant': '完成後的模型會出現在 Bot game 的引擎選項中。',
      'de': 'Fertige Builds werden Engine-Optionen im Bot game.',
      'es': 'Los builds completados aparecen como motores en Bot game.',
      'fr': 'Les builds terminés deviennent des choix de moteur dans Bot game.',
      'it': 'I build completati diventano motori selezionabili in Bot game.',
      'ja': '完了したビルドは Bot game のエンジン選択肢になります。',
      'ko': '완료된 빌드는 Bot game 엔진 선택지로 표시됩니다.',
      'nl': 'Voltooide builds worden enginekeuzes in Bot game.',
      'ru': 'Готовые сборки появляются как движки в Bot game.',
    },
    'Cloud sync': {
      'zh-Hans': '云端同步',
      'zh-Hant': '雲端同步',
      'de': 'Cloud-Sync',
      'es': 'Sincronización en la nube',
      'fr': 'Synchronisation cloud',
      'it': 'Sincronizzazione cloud',
      'ja': 'クラウド同期',
      'ko': '클라우드 동기화',
      'nl': 'Cloudsynchronisatie',
      'ru': 'Облачная синхронизация',
    },
    'This quality score estimates how well the model predicts held-out games. Use it as the first signal for whether the model is useful in real play.':
        {
      'zh-Hans': '这个质量分估算模型预测留出对局的效果，可作为判断实战可用性的第一参考。',
      'zh-Hant': '這個品質分估算模型預測留出對局的效果，可作為判斷實戰可用性的第一參考。',
      'de':
          'Diese Qualitätszahl schätzt, wie gut das Modell zurückgehaltene Partien vorhersagt. Nutze sie als erstes Signal für den praktischen Nutzen.',
      'es':
          'Esta puntuación estima qué tan bien el modelo predice partidas reservadas. Úsala como primera señal de utilidad en juego real.',
      'fr':
          'Ce score estime la qualité de prédiction sur des parties réservées. Utilisez-le comme premier signal d’utilité en jeu réel.',
      'it':
          'Questo punteggio stima quanto bene il modello prevede partite escluse dall’allenamento. Usalo come primo segnale di utilità nel gioco reale.',
      'ja': 'この品質スコアは、除外した対局をモデルがどれだけ予測できるかを示します。実戦で役立つかの最初の目安です。',
      'ko':
          '이 품질 점수는 모델이 보류된 대국을 얼마나 잘 예측하는지 추정합니다. 실제 플레이에 유용한지 판단하는 첫 신호로 사용하세요.',
      'nl':
          'Deze kwaliteitsscore schat hoe goed het model achtergehouden partijen voorspelt. Gebruik dit als eerste signaal voor bruikbaarheid in echte partijen.',
      'ru':
          'Эта оценка показывает, насколько хорошо модель предсказывает отложенные партии. Используйте её как первый ориентир пользы в реальной игре.',
    },
    'Downloaded weights appear here and can be selected as Bot game engine choices when available.':
        {
      'zh-Hans': '已下载的权重会显示在这里，可用时可以作为 Bot game 引擎选择。',
      'zh-Hant': '已下載的權重會顯示在這裡，可用時可以作為 Bot game 引擎選擇。',
      'de':
          'Heruntergeladene Gewichte erscheinen hier und können als Bot game-Engine gewählt werden.',
      'es':
          'Los pesos descargados aparecerán aquí y podrán elegirse como motores de Bot game.',
      'fr':
          'Les poids téléchargés apparaissent ici et peuvent être choisis comme moteur Bot game.',
      'it':
          'I pesi scaricati appaiono qui e possono essere scelti come motori in Bot game.',
      'ja': 'ダウンロード済みの重みはここに表示され、利用可能なら Bot game のエンジンとして選べます。',
      'ko': '다운로드한 가중치는 여기에 표시되며, 사용 가능할 때 Bot game 엔진으로 선택할 수 있습니다.',
      'nl':
          'Gedownloade gewichten verschijnen hier en kunnen als Bot game-engine worden gekozen.',
      'ru':
          'Загруженные веса появятся здесь и будут доступны как движки Bot game.',
    },
    'Chessnut checks your uploaded games for style consistency and keeps a separate quality check set before the model is offered for play.':
        {
      'zh-Hans': 'Chessnut 会检查上传对局的风格一致性，并保留独立质量检查集，再开放模型试玩。',
      'zh-Hant': 'Chessnut 會檢查上傳對局的風格一致性，並保留獨立品質檢查集，再開放模型試玩。',
      'de':
          'Chessnut prüft deine hochgeladenen Partien auf Stil-Konsistenz und nutzt vor dem Spielen eine eigene Qualitätsprüfung.',
      'es':
          'Chessnut comprueba la coherencia de estilo de tus partidas subidas y reserva un control de calidad antes de ofrecer el modelo.',
      'fr':
          'Chessnut vérifie la cohérence de style des parties envoyées et garde un jeu de contrôle qualité avant de proposer le modèle.',
      'it':
          'Chessnut controlla la coerenza di stile delle partite caricate e conserva un set di qualità separato prima di offrire il modello.',
      'ja': 'Chessnut はアップロードした対局のスタイル一貫性を確認し、別の品質確認セットを使ってからモデルを提供します。',
      'ko': 'Chessnut은 업로드한 대국의 스타일 일관성을 확인하고, 별도 품질 확인 세트를 거친 뒤 모델을 제공합니다.',
      'nl':
          'Chessnut controleert je geüploade partijen op stijlconsistentie en gebruikt een aparte kwaliteitsset voordat het model speelbaar is.',
      'ru':
          'Chessnut проверяет загруженные партии на единый стиль и использует отдельный набор контроля качества перед доступом к модели.',
    },
    'Expected move prediction quality on games kept out of training.': {
      'zh-Hans': '在未参与训练的对局上预估走法预测质量。',
      'zh-Hant': '在未參與訓練的對局上預估走法預測品質。',
      'de': 'Erwartete Zugvorhersage auf Partien außerhalb des Trainings.',
      'es':
          'Calidad esperada de predicción de jugadas en partidas fuera del entrenamiento.',
      'fr':
          'Qualité attendue de prédiction des coups sur les parties exclues de l’entraînement.',
      'it':
          'Qualità attesa della previsione mosse sulle partite escluse dall’allenamento.',
      'ja': 'トレーニングから除外した対局での着手予測品質です。',
      'ko': '훈련에서 제외한 대국에 대한 예상 수 예측 품질입니다.',
      'nl': 'Verwachte zetvoorspelling op partijen buiten de training.',
      'ru': 'Ожидаемое качество предсказания ходов на партиях вне обучения.',
    },
    'Whether the uploaded games follow one clear style.': {
      'zh-Hans': '上传的对局是否呈现清晰一致的风格。',
      'zh-Hant': '上傳的對局是否呈現清晰一致的風格。',
      'de': 'Ob die hochgeladenen Partien einem klaren Stil folgen.',
      'es': 'Si las partidas subidas siguen un estilo claro.',
      'fr': 'Indique si les parties envoyées suivent un style clair.',
      'it': 'Indica se le partite caricate seguono uno stile chiaro.',
      'ja': 'アップロードした対局が明確なスタイルに沿っているかを示します。',
      'ko': '업로드한 대국이 하나의 명확한 스타일을 따르는지 보여줍니다.',
      'nl': 'Of de geüploade partijen één duidelijke stijl volgen.',
      'ru': 'Показывает, следуют ли загруженные партии единому стилю.',
    },
    'How useful the held-out games are for checking the model.': {
      'zh-Hans': '留出对局对检查模型质量的帮助程度。',
      'zh-Hant': '留出對局對檢查模型品質的幫助程度。',
      'de':
          'Wie hilfreich die zurückgehaltenen Partien zur Modellprüfung sind.',
      'es':
          'Qué tan útiles son las partidas reservadas para comprobar el modelo.',
      'fr': 'Utilité des parties réservées pour vérifier le modèle.',
      'it':
          'Quanto sono utili le partite riservate per controllare il modello.',
      'ja': '保留した対局がモデル確認にどれだけ役立つかを示します。',
      'ko': '보류된 대국이 모델 확인에 얼마나 유용한지 보여줍니다.',
      'nl': 'Hoe nuttig de achtergehouden partijen zijn voor modelcontrole.',
      'ru': 'Насколько отложенные партии полезны для проверки модели.',
    },
    'Report generated from your training games and quality checks.': {
      'zh-Hans': '根据你的训练对局和质量检查生成的报告。',
      'zh-Hant': '根據你的訓練對局和品質檢查產生的報告。',
      'de': 'Bericht aus deinen Trainingspartien und Qualitätsprüfungen.',
      'es':
          'Informe generado con tus partidas de entrenamiento y controles de calidad.',
      'fr':
          'Rapport généré depuis vos parties d’entraînement et contrôles qualité.',
      'it':
          'Report generato dalle tue partite di allenamento e dai controlli qualità.',
      'ja': 'トレーニング対局と品質確認から生成されたレポートです。',
      'ko': '훈련 대국과 품질 확인을 바탕으로 생성된 보고서입니다.',
      'nl': 'Rapport uit je trainingspartijen en kwaliteitscontroles.',
      'ru': 'Отчет, созданный по вашим учебным партиям и проверкам качества.',
    },
    'Theme not available yet': {
      'zh-Hans': '主题暂不可用',
      'zh-Hant': '主題暫不可用',
      'de': 'Thema noch nicht verfügbar',
      'es': 'Tema aún no disponible',
      'fr': 'Thème pas encore disponible',
      'it': 'Tema non ancora disponibile',
      'ja': 'テーマはまだ利用できません',
      'ko': '테마를 아직 사용할 수 없음',
      'nl': 'Thema nog niet beschikbaar',
      'ru': 'Тема пока недоступна',
    },
    'Games played on Chessnut will appear here after they sync.': {
      'zh-Hans': '在 Chessnut 上进行的对局同步后会显示在这里。',
      'zh-Hant': '在 Chessnut 上進行的對局同步後會顯示在這裡。',
      'de':
          'Auf Chessnut gespielte Partien erscheinen nach der Synchronisierung hier.',
      'es':
          'Las partidas jugadas en Chessnut aparecerán aquí tras sincronizarse.',
      'fr':
          'Les parties jouées sur Chessnut apparaîtront ici après synchronisation.',
      'it':
          'Le partite giocate su Chessnut appariranno qui dopo la sincronizzazione.',
      'ja': 'Chessnut でプレイした対局は同期後にここへ表示されます。',
      'ko': 'Chessnut에서 플레이한 대국은 동기화 후 여기에 표시됩니다.',
      'nl':
          'Op Chessnut gespeelde partijen verschijnen hier na synchronisatie.',
      'ru': 'Партии, сыгранные в Chessnut, появятся здесь после синхронизации.',
    },
    'The app fetches public Lichess PGNs directly, then uploads the loaded PGNs when training starts.':
        {
      'zh-Hans': 'APP 会直接获取公开的 Lichess PGN，训练开始时再上传已加载的 PGN。',
      'zh-Hant': 'APP 會直接取得公開的 Lichess PGN，訓練開始時再上傳已載入的 PGN。',
      'de':
          'Die App lädt öffentliche Lichess-PGNs direkt und lädt die geladenen PGNs beim Trainingsstart hoch.',
      'es':
          'La app obtiene directamente PGN públicos de Lichess y sube los PGN cargados al iniciar el entrenamiento.',
      'fr':
          'L’app récupère directement les PGN publics de Lichess, puis importe les PGN chargés au lancement de l’entraînement.',
      'it':
          'L’app recupera direttamente i PGN pubblici di Lichess e carica quelli già letti quando inizi l’allenamento.',
      'ja': 'アプリが公開 Lichess PGN を直接取得し、トレーニング開始時に読み込み済み PGN をアップロードします。',
      'ko': '앱이 공개 Lichess PGN을 직접 가져오고, 훈련 시작 시 불러온 PGN을 업로드합니다.',
      'nl':
          'De app haalt openbare Lichess-PGN’s rechtstreeks op en uploadt de geladen PGN’s wanneer de training start.',
      'ru':
          'Приложение напрямую загружает публичные PGN Lichess, а при запуске тренировки отправляет уже загруженные PGN.',
    },
    'Grandeur is temporarily unavailable. Please try again later.': {
      'zh-Hans': 'Grandeur 暂时不可用，请稍后重试。',
      'zh-Hant': 'Grandeur 暫時不可用，請稍後重試。',
      'de':
          'Grandeur ist vorübergehend nicht verfügbar. Bitte später erneut versuchen.',
      'es': 'Grandeur no está disponible temporalmente. Inténtalo más tarde.',
      'fr': 'Grandeur est temporairement indisponible. Réessayez plus tard.',
      'it': 'Grandeur non è temporaneamente disponibile. Riprova più tardi.',
      'ja': 'Grandeur は一時的に利用できません。後でもう一度お試しください。',
      'ko': 'Grandeur를 일시적으로 사용할 수 없습니다. 나중에 다시 시도하세요.',
      'nl':
          'Grandeur is tijdelijk niet beschikbaar. Probeer het later opnieuw.',
      'ru': 'Grandeur временно недоступен. Повторите попытку позже.',
    },
    'The Grandeur summary is still being generated. Once it is ready, this page will show the full-game summary.':
        {
      'zh-Hans': 'Grandeur 总结仍在生成中。完成后，本页会显示整盘总结。',
      'zh-Hant': 'Grandeur 總結仍在產生中。完成後，本頁會顯示整盤總結。',
      'de':
          'Die Grandeur-Zusammenfassung wird noch erstellt. Danach erscheint hier die Zusammenfassung der ganzen Partie.',
      'es':
          'El resumen Grandeur aún se está generando. Cuando termine, esta página mostrará el resumen completo.',
      'fr':
          'Le résumé Grandeur est en cours de génération. Une fois prêt, le résumé complet apparaîtra ici.',
      'it':
          'Il riepilogo Grandeur è ancora in generazione. Quando sarà pronto, qui apparirà il riepilogo completo.',
      'ja': 'Grandeur サマリーを生成中です。完了すると、このページに対局全体のまとめが表示されます。',
      'ko': 'Grandeur 요약을 생성 중입니다. 완료되면 이 페이지에 전체 대국 요약이 표시됩니다.',
      'nl':
          'De Grandeur-samenvatting wordt nog gemaakt. Daarna verschijnt hier de samenvatting van de hele partij.',
      'ru':
          'Сводка Grandeur ещё создаётся. После завершения здесь появится итог по всей партии.',
    },
    'The Grandeur coach report is still being generated. Once it is ready, this card will show the move commentary.':
        {
      'zh-Hans': 'Grandeur 教练报告仍在生成中。完成后，此处会显示着法讲解。',
      'zh-Hant': 'Grandeur 教練報告仍在產生中。完成後，此處會顯示著法講解。',
      'de':
          'Der Grandeur-Coachbericht wird noch erstellt. Danach erscheint hier der Zugkommentar.',
      'es':
          'El informe del entrenador Grandeur aún se está generando. Cuando termine, aquí aparecerá el comentario de la jugada.',
      'fr':
          'Le rapport du coach Grandeur est en cours de génération. Le commentaire du coup apparaîtra ici.',
      'it':
          'Il report del coach Grandeur è ancora in generazione. Qui apparirà il commento della mossa.',
      'ja': 'Grandeur コーチレポートを生成中です。完了すると、ここに着手コメントが表示されます。',
      'ko': 'Grandeur 코치 보고서를 생성 중입니다. 완료되면 여기에 수 해설이 표시됩니다.',
      'nl':
          'Het Grandeur-coachrapport wordt nog gemaakt. Daarna verschijnt hier het zetcommentaar.',
      'ru':
          'Отчёт тренера Grandeur ещё создаётся. После завершения здесь появится комментарий к ходу.',
    },
    'LC0 uses trained weights from your local model library.': {
      'zh-Hans': 'LC0 使用本地模型库中的已训练权重。',
      'zh-Hant': 'LC0 使用本地模型庫中的已訓練權重。',
      'de':
          'LC0 verwendet trainierte Gewichte aus deiner lokalen Modellbibliothek.',
      'es': 'LC0 usa pesos entrenados de tu biblioteca local de modelos.',
      'fr':
          'LC0 utilise les poids entraînés de votre bibliothèque locale de modèles.',
      'it': 'LC0 usa i pesi addestrati della libreria modelli locale.',
      'ja': 'LC0 はローカルモデルライブラリの学習済み重みを使用します。',
      'ko': 'LC0는 로컬 모델 라이브러리의 훈련된 가중치를 사용합니다.',
      'nl': 'LC0 gebruikt getrainde gewichten uit je lokale modelbibliotheek.',
      'ru': 'LC0 использует обученные веса из локальной библиотеки моделей.',
    },
    'Choose from 100ms to 60s. Auto adapts when clocks are active.': {
      'zh-Hans': '可选择 100 毫秒至 60 秒。启用棋钟时，自动模式会自适应。',
      'zh-Hant': '可選擇 100 毫秒至 60 秒。啟用棋鐘時，自動模式會自適應。',
      'de': 'Wähle 100 ms bis 60 s. Auto passt sich bei aktiver Uhr an.',
      'es':
          'Elige entre 100 ms y 60 s. Auto se adapta cuando el reloj está activo.',
      'fr':
          'Choisissez de 100 ms à 60 s. Auto s’adapte lorsque la pendule est active.',
      'it':
          'Scegli da 100 ms a 60 s. Auto si adatta quando l’orologio è attivo.',
      'ja': '100ms から 60秒まで選べます。時計使用時は自動モードが調整します。',
      'ko': '100ms부터 60초까지 선택할 수 있습니다. 시계 사용 시 자동 모드가 조정됩니다.',
      'nl': 'Kies van 100 ms tot 60 s. Auto past zich aan bij actieve klokken.',
      'ru':
          'Выберите от 100 мс до 60 с. Авто адаптируется при включённых часах.',
    },
    'QA wallet tools are unavailable.': {
      'zh-Hans': 'QA 钱包工具不可用。',
      'zh-Hant': 'QA 錢包工具不可用。',
      'de': 'QA-Wallet-Tools sind nicht verfügbar.',
      'es': 'Las herramientas QA de wallet no están disponibles.',
      'fr': 'Les outils wallet QA sont indisponibles.',
      'it': 'Gli strumenti wallet QA non sono disponibili.',
      'ja': 'QAウォレットツールを利用できません。',
      'ko': 'QA 지갑 도구를 사용할 수 없습니다.',
      'nl': 'QA-wallettools zijn niet beschikbaar.',
      'ru': 'QA-инструменты кошелька недоступны.',
    },
    'Wallet test tools are unavailable.': {
      'zh-Hans': '钱包测试工具不可用。',
      'zh-Hant': '錢包測試工具不可用。',
      'de': 'Wallet-Testtools sind nicht verfügbar.',
      'es': 'Las herramientas de prueba de la cartera no están disponibles.',
      'fr': 'Les outils de test du portefeuille sont indisponibles.',
      'it': 'Gli strumenti di test del wallet non sono disponibili.',
      'ja': 'ウォレットのテストツールを利用できません。',
      'ko': '지갑 테스트 도구를 사용할 수 없습니다.',
      'nl': 'Wallettesttools zijn niet beschikbaar.',
      'ru': 'Инструменты тестирования кошелька недоступны.',
    },
    'Chess.com board could not open in the app': {
      'zh-Hans': '无法在 App 内打开 Chess.com 棋盘',
      'zh-Hant': '無法在 App 內開啟 Chess.com 棋盤',
      'de': 'Das Chess.com-Brett konnte in der App nicht geöffnet werden',
      'es': 'No se pudo abrir el tablero de Chess.com en la app',
      'fr': 'Impossible d’ouvrir l’échiquier Chess.com dans l’app',
      'it': 'Impossibile aprire la scacchiera Chess.com nell’app',
      'ja': 'アプリ内で Chess.com のボードを開けませんでした',
      'ko': '앱에서 Chess.com 보드를 열 수 없습니다',
      'nl': 'Het Chess.com-bord kon niet in de app worden geopend',
      'ru': 'Не удалось открыть доску Chess.com в приложении',
    },
    'Sign-in method unavailable': {
      'zh-Hans': '此登录方式暂不可用',
      'zh-Hant': '此登入方式暫不可用',
      'de': 'Diese Anmeldemethode ist nicht verfügbar',
      'es': 'Este método de inicio de sesión no está disponible',
      'fr': 'Cette méthode de connexion est indisponible',
      'it': 'Questo metodo di accesso non è disponibile',
      'ja': 'このサインイン方法は利用できません',
      'ko': '이 로그인 방법은 사용할 수 없습니다',
      'nl': 'Deze aanmeldmethode is niet beschikbaar',
      'ru': 'Этот способ входа недоступен',
    },
    'Importing Lichess history': {
      'zh-Hans': '正在导入 Lichess 历史对局',
      'zh-Hant': '正在匯入 Lichess 歷史對局',
      'de': 'Lichess-Verlauf wird importiert',
      'es': 'Importando historial de Lichess',
      'fr': 'Import de l’historique Lichess',
      'it': 'Importazione cronologia Lichess',
      'ja': 'Lichess 履歴をインポート中',
      'ko': 'Lichess 기록 가져오는 중',
      'nl': 'Lichess-geschiedenis importeren',
      'ru': 'Импорт истории Lichess',
    },
    'Records have been refreshed.': {
      'zh-Hans': '对局记录已刷新。',
      'zh-Hant': '對局記錄已重新整理。',
      'de': 'Partien wurden aktualisiert.',
      'es': 'Los registros se actualizaron.',
      'fr': 'Les parties ont été actualisées.',
      'it': 'Le partite sono state aggiornate.',
      'ja': '対局記録を更新しました。',
      'ko': '대국 기록을 새로 고쳤습니다.',
      'nl': 'Partijen zijn bijgewerkt.',
      'ru': 'Записи партий обновлены.',
    },
    'You can leave this page and refresh records later.': {
      'zh-Hans': '你可以离开此页面，稍后再刷新对局记录。',
      'zh-Hant': '你可以離開此頁面，稍後再重新整理對局記錄。',
      'de':
          'Du kannst diese Seite verlassen und die Partien später aktualisieren.',
      'es': 'Puedes salir de esta página y actualizar las partidas más tarde.',
      'fr':
          'Vous pouvez quitter cette page et actualiser les parties plus tard.',
      'it': 'Puoi lasciare questa pagina e aggiornare le partite più tardi.',
      'ja': 'このページを離れ、後で対局記録を更新できます。',
      'ko': '이 페이지를 나가고 나중에 대국 기록을 새로 고칠 수 있습니다.',
      'nl': 'Je kunt deze pagina verlaten en de partijen later vernieuwen.',
      'ru': 'Можно покинуть страницу и обновить партии позже.',
    },
    'Collecting matching games': {
      'zh-Hans': '正在收集符合条件的对局',
      'zh-Hant': '正在收集符合條件的對局',
      'de': 'Passende Partien werden gesammelt',
      'es': 'Recopilando partidas coincidentes',
      'fr': 'Collecte des parties correspondantes',
      'it': 'Raccolta delle partite corrispondenti',
      'ja': '条件に合う対局を収集中',
      'ko': '조건에 맞는 대국 수집 중',
      'nl': 'Passende partijen verzamelen',
      'ru': 'Сбор подходящих партий',
    },
    'Building / pending': {
      'zh-Hans': '构建中 / 待开始',
      'zh-Hant': '建立中 / 待開始',
      'de': 'Wird erstellt / ausstehend',
      'es': 'Creando / pendiente',
      'fr': 'Création / en attente',
      'it': 'Creazione / in attesa',
      'ja': 'ビルド中 / 待機中',
      'ko': '빌드 중 / 대기 중',
      'nl': 'Bouwen / in afwachting',
      'ru': 'Сборка / ожидает',
    },
    'Pending': {
      'zh-Hans': '待开始',
      'zh-Hant': '待開始',
      'de': 'Ausstehend',
      'es': 'Pendiente',
      'fr': 'En attente',
      'it': 'In attesa',
      'ja': '待機中',
      'ko': '대기 중',
      'nl': 'In afwachting',
      'ru': 'Ожидает',
    },
    'Start build': {
      'zh-Hans': '开始构建',
      'zh-Hant': '開始建立',
      'de': 'Build starten',
      'es': 'Iniciar build',
      'fr': 'Lancer le build',
      'it': 'Avvia build',
      'ja': 'ビルド開始',
      'ko': '빌드 시작',
      'nl': 'Build starten',
      'ru': 'Запустить сборку',
    },
    'Start Model Build': {
      'zh-Hans': '开始 Model Build',
      'zh-Hant': '開始 Model Build',
      'de': 'Model Build starten',
      'es': 'Iniciar Model Build',
      'fr': 'Lancer Model Build',
      'it': 'Avvia Model Build',
      'ja': 'Model Build を開始',
      'ko': 'Model Build 시작',
      'nl': 'Model Build starten',
      'ru': 'Запустить Model Build',
    },
    'Model Build started': {
      'zh-Hans': 'Model Build 已开始',
      'zh-Hant': 'Model Build 已開始',
      'de': 'Model Build gestartet',
      'es': 'Model Build iniciado',
      'fr': 'Model Build lancé',
      'it': 'Model Build avviato',
      'ja': 'Model Build を開始しました',
      'ko': 'Model Build 시작됨',
      'nl': 'Model Build gestart',
      'ru': 'Model Build запущен',
    },
    'Model Build preparing': {
      'zh-Hans': 'Model Build 正在准备',
      'zh-Hant': 'Model Build 正在準備',
      'de': 'Model Build wird vorbereitet',
      'es': 'Preparando Model Build',
      'fr': 'Préparation de Model Build',
      'it': 'Preparazione Model Build',
      'ja': 'Model Build を準備中',
      'ko': 'Model Build 준비 중',
      'nl': 'Model Build voorbereiden',
      'ru': 'Подготовка Model Build',
    },
    'Model Build started. You can keep using the app while Chessnut trains it.':
        {
      'zh-Hans': 'Model Build 已开始。Chessnut 训练时，你可以继续使用 App。',
      'zh-Hant': 'Model Build 已開始。Chessnut 訓練時，你可以繼續使用 App。',
      'de':
          'Model Build gestartet. Du kannst die App weiter verwenden, während Chessnut trainiert.',
      'es':
          'Model Build iniciado. Puedes seguir usando la app mientras Chessnut entrena.',
      'fr':
          'Model Build lancé. Vous pouvez continuer à utiliser l’app pendant que Chessnut entraîne le modèle.',
      'it':
          'Model Build avviato. Puoi continuare a usare l’app mentre Chessnut lo allena.',
      'ja': 'Model Build を開始しました。Chessnut がトレーニング中もアプリを使えます。',
      'ko': 'Model Build가 시작되었습니다. Chessnut이 훈련하는 동안 앱을 계속 사용할 수 있습니다.',
      'nl':
          'Model Build gestart. Je kunt de app blijven gebruiken terwijl Chessnut traint.',
      'ru':
          'Model Build запущен. Можно продолжать пользоваться приложением, пока Chessnut обучает модель.',
    },
    'Unable to start Model Build.': {
      'zh-Hans': '无法开始 Model Build。',
      'zh-Hant': '無法開始 Model Build。',
      'de': 'Model Build konnte nicht gestartet werden.',
      'es': 'No se pudo iniciar Model Build.',
      'fr': 'Impossible de lancer Model Build.',
      'it': 'Impossibile avviare Model Build.',
      'ja': 'Model Build を開始できません。',
      'ko': 'Model Build를 시작할 수 없습니다.',
      'nl': 'Kan Model Build niet starten.',
      'ru': 'Не удалось запустить Model Build.',
    },
    'Unable to start Model Build from these filters.': {
      'zh-Hans': '无法用这些筛选条件开始 Model Build。',
      'zh-Hant': '無法用這些篩選條件開始 Model Build。',
      'de': 'Model Build konnte mit diesen Filtern nicht gestartet werden.',
      'es': 'No se pudo iniciar Model Build con estos filtros.',
      'fr': 'Impossible de lancer Model Build avec ces filtres.',
      'it': 'Impossibile avviare Model Build con questi filtri.',
      'ja': 'このフィルターでは Model Build を開始できません。',
      'ko': '이 필터로 Model Build를 시작할 수 없습니다.',
      'nl': 'Kan Model Build niet starten met deze filters.',
      'ru': 'Не удалось запустить Model Build с этими фильтрами.',
    },
    'Model Build is unavailable. Check Premium, points, or try again later.': {
      'zh-Hans': 'Model Build 暂不可用。请检查会员、积分，或稍后重试。',
      'zh-Hant': 'Model Build 暫不可用。請檢查會員、積分，或稍後重試。',
      'de':
          'Model Build ist nicht verfügbar. Prüfe Premium, Punkte oder versuche es später erneut.',
      'es':
          'Model Build no está disponible. Revisa Premium, puntos o inténtalo más tarde.',
      'fr':
          'Model Build est indisponible. Vérifiez Premium, les points ou réessayez plus tard.',
      'it':
          'Model Build non è disponibile. Controlla Premium, punti o riprova più tardi.',
      'ja': 'Model Build は利用できません。Premium、ポイントを確認するか、後でもう一度お試しください。',
      'ko': 'Model Build를 사용할 수 없습니다. Premium, 포인트를 확인하거나 나중에 다시 시도하세요.',
      'nl':
          'Model Build is niet beschikbaar. Controleer Premium, punten of probeer later opnieuw.',
      'ru':
          'Model Build недоступен. Проверьте Premium, баллы или повторите попытку позже.',
    },
    'Use one clean PGN source, start training, then play the model in Bot game.':
        {
      'zh-Hans': '使用一个干净的 PGN 来源，开始训练后即可在 Bot game 中使用该模型。',
      'zh-Hant': '使用一個乾淨的 PGN 來源，開始訓練後即可在 Bot game 中使用該模型。',
      'de':
          'Nutze eine saubere PGN-Quelle, starte das Training und spiele das Modell dann in Bot game.',
      'es':
          'Usa una fuente PGN limpia, inicia el entrenamiento y luego juega con el modelo en Bot game.',
      'fr':
          'Utilisez une source PGN propre, lancez l’entraînement, puis jouez le modèle dans Bot game.',
      'it':
          'Usa una fonte PGN pulita, avvia l’allenamento e poi gioca il modello in Bot game.',
      'ja': 'クリーンな PGN ソースを1つ使い、トレーニング開始後に Bot game でモデルをプレイできます。',
      'ko': '깔끔한 PGN 소스 하나를 사용해 훈련을 시작한 뒤 Bot game에서 모델로 플레이하세요.',
      'nl':
          'Gebruik één schone PGN-bron, start de training en speel het model daarna in Bot game.',
      'ru':
          'Используйте один чистый источник PGN, запустите обучение, затем играйте моделью в Bot game.',
    },
    'Train in the cloud': {
      'zh-Hans': '云端训练',
      'zh-Hant': '雲端訓練',
      'de': 'In der Cloud trainieren',
      'es': 'Entrenar en la nube',
      'fr': 'Entraîner dans le cloud',
      'it': 'Allena nel cloud',
      'ja': 'クラウドでトレーニング',
      'ko': '클라우드에서 훈련',
      'nl': 'Trainen in de cloud',
      'ru': 'Обучение в облаке',
    },
    'Use one source only. Choose games from the same player or style. Training continues in the background after submission.':
        {
      'zh-Hans': '只使用一种来源。请选择来自同一棋手或同一风格的对局。提交后训练会在后台继续。',
      'zh-Hant': '只使用一種來源。請選擇來自同一棋手或同一風格的對局。提交後訓練會在背景繼續。',
      'de':
          'Nutze nur eine Quelle. Wähle Partien desselben Spielers oder Stils. Nach dem Absenden läuft das Training im Hintergrund weiter.',
      'es':
          'Usa una sola fuente. Elige partidas del mismo jugador o estilo. Tras enviar, el entrenamiento continúa en segundo plano.',
      'fr':
          'Utilisez une seule source. Choisissez des parties du même joueur ou du même style. Après l’envoi, l’entraînement continue en arrière-plan.',
      'it':
          'Usa una sola fonte. Scegli partite dello stesso giocatore o stile. Dopo l’invio, l’allenamento continua in background.',
      'ja': 'ソースは1つだけ使ってください。同じプレイヤーまたはスタイルの対局を選びます。送信後、トレーニングはバックグラウンドで続きます。',
      'ko':
          '소스는 하나만 사용하세요. 같은 플레이어 또는 같은 스타일의 대국을 선택하세요. 제출 후 훈련은 백그라운드에서 계속됩니다.',
      'nl':
          'Gebruik slechts één bron. Kies partijen van dezelfde speler of stijl. Na verzenden loopt de training op de achtergrond door.',
      'ru':
          'Используйте только один источник. Выбирайте партии одного игрока или стиля. После отправки обучение продолжится в фоне.',
    },
    'Cloud records': {
      'zh-Hans': '云端记录',
      'zh-Hant': '雲端記錄',
      'de': 'Cloud-Partien',
      'es': 'Registros en la nube',
      'fr': 'Parties cloud',
      'it': 'Record cloud',
      'ja': 'クラウド記録',
      'ko': '클라우드 기록',
      'nl': 'Cloudrecords',
      'ru': 'Облачные записи',
    },
    'Analysis filters use reports already saved on this device.': {
      'zh-Hans': '分析筛选会使用已保存在此设备上的报告。',
      'zh-Hant': '分析篩選會使用已儲存在此裝置上的報告。',
      'de':
          'Analysefilter nutzen Berichte, die auf diesem Gerät gespeichert sind.',
      'es':
          'Los filtros de análisis usan informes guardados en este dispositivo.',
      'fr':
          'Les filtres d’analyse utilisent les rapports enregistrés sur cet appareil.',
      'it': 'I filtri di analisi usano i report salvati su questo dispositivo.',
      'ja': '分析フィルターはこの端末に保存済みのレポートを使います。',
      'ko': '분석 필터는 이 기기에 저장된 보고서를 사용합니다.',
      'nl':
          'Analysefilters gebruiken rapporten die op dit apparaat zijn opgeslagen.',
      'ru':
          'Фильтры анализа используют отчёты, сохранённые на этом устройстве.',
    },
    'Chessnut keeps working in the background.': {
      'zh-Hans': 'Chessnut 会在后台继续处理。',
      'zh-Hant': 'Chessnut 會在背景繼續處理。',
      'de': 'Chessnut arbeitet im Hintergrund weiter.',
      'es': 'Chessnut sigue trabajando en segundo plano.',
      'fr': 'Chessnut continue en arrière-plan.',
      'it': 'Chessnut continua a lavorare in background.',
      'ja': 'Chessnut はバックグラウンドで処理を続けます。',
      'ko': 'Chessnut이 백그라운드에서 계속 처리합니다.',
      'nl': 'Chessnut werkt op de achtergrond verder.',
      'ru': 'Chessnut продолжает работу в фоне.',
    },
    'Open Engine Lab to view the pending build.': {
      'zh-Hans': '打开 Engine Lab 查看待完成的构建。',
      'zh-Hant': '開啟 Engine Lab 查看待完成的建立。',
      'de': 'Öffne Engine Lab, um den ausstehenden Build anzusehen.',
      'es': 'Abre Engine Lab para ver el build pendiente.',
      'fr': 'Ouvrez Engine Lab pour voir le build en attente.',
      'it': 'Apri Engine Lab per vedere il build in attesa.',
      'ja': 'Engine Lab を開いて待機中のビルドを確認します。',
      'ko': 'Engine Lab을 열어 대기 중인 빌드를 확인하세요.',
      'nl': 'Open Engine Lab om de build in afwachting te bekijken.',
      'ru': 'Откройте Engine Lab, чтобы посмотреть ожидающую сборку.',
    },
    'Confirm to start training from these games.': {
      'zh-Hans': '确认后将使用这些对局开始训练。',
      'zh-Hant': '確認後將使用這些對局開始訓練。',
      'de': 'Bestätige, um das Training mit diesen Partien zu starten.',
      'es': 'Confirma para iniciar el entrenamiento con estas partidas.',
      'fr': 'Confirmez pour lancer l’entraînement avec ces parties.',
      'it': 'Conferma per avviare l’allenamento con queste partite.',
      'ja': '確認すると、これらの対局でトレーニングを開始します。',
      'ko': '확인하면 이 대국들로 훈련을 시작합니다.',
      'nl': 'Bevestig om training met deze partijen te starten.',
      'ru': 'Подтвердите запуск обучения по этим партиям.',
    },
    'Store purchase is unavailable on this device. Install the official test or store version, sign in to the store, then try again.':
        {
      'zh-Hans': '此设备暂时无法购买。请安装官方测试版或商店版本，登录应用商店后再试。',
      'zh-Hant': '此裝置暫時無法購買。請安裝官方測試版或商店版本，登入應用商店後再試。',
      'de':
          'Käufe sind auf diesem Gerät nicht verfügbar. Installiere die offizielle Test- oder Store-Version, melde dich im Store an und versuche es erneut.',
      'es':
          'La compra no está disponible en este dispositivo. Instala la versión oficial de prueba o de la tienda, inicia sesión en la tienda e inténtalo de nuevo.',
      'fr':
          'L’achat n’est pas disponible sur cet appareil. Installez la version officielle de test ou du store, connectez-vous au store, puis réessayez.',
      'it':
          'L’acquisto non è disponibile su questo dispositivo. Installa la versione ufficiale di test o store, accedi allo store e riprova.',
      'ja': 'この端末では購入を利用できません。公式テスト版またはストア版をインストールし、ストアにサインインして再試行してください。',
      'ko':
          '이 기기에서는 구매를 사용할 수 없습니다. 공식 테스트 또는 스토어 버전을 설치하고 스토어에 로그인한 뒤 다시 시도하세요.',
      'nl':
          'Aankopen zijn niet beschikbaar op dit apparaat. Installeer de officiële test- of storeversie, meld je aan bij de store en probeer opnieuw.',
      'ru':
          'Покупки недоступны на этом устройстве. Установите официальную тестовую или магазинную версию, войдите в магазин и повторите попытку.',
    },
    'This Premium plan is not available in the store yet. Try another plan or come back later.':
        {
      'zh-Hans': '此 Premium 方案暂未在商店开放。请试试其他方案，或稍后再来。',
      'zh-Hant': '此 Premium 方案暫未在商店開放。請試試其他方案，或稍後再來。',
      'de':
          'Dieser Premium-Tarif ist noch nicht im Store verfügbar. Wähle einen anderen Tarif oder versuche es später erneut.',
      'es':
          'Este plan Premium aún no está disponible en la tienda. Prueba otro plan o vuelve más tarde.',
      'fr':
          'Cette offre Premium n’est pas encore disponible dans le store. Essayez une autre offre ou revenez plus tard.',
      'it':
          'Questo piano Premium non è ancora disponibile nello store. Prova un altro piano o torna più tardi.',
      'ja': 'この Premium プランはまだストアで利用できません。別のプランを試すか、後でもう一度ご確認ください。',
      'ko': '이 Premium 플랜은 아직 스토어에서 사용할 수 없습니다. 다른 플랜을 시도하거나 나중에 다시 확인하세요.',
      'nl':
          'Dit Premium-abonnement is nog niet beschikbaar in de store. Probeer een ander abonnement of kom later terug.',
      'ru':
          'Этот план Premium пока недоступен в магазине. Попробуйте другой план или вернитесь позже.',
    },
    'The store could not start this purchase. Check your store account and payment setup, then try again.':
        {
      'zh-Hans': '商店无法开始购买。请检查商店账号和付款设置后重试。',
      'zh-Hant': '商店無法開始購買。請檢查商店帳號和付款設定後重試。',
      'de':
          'Der Store konnte den Kauf nicht starten. Prüfe dein Store-Konto und die Zahlungsdaten und versuche es erneut.',
      'es':
          'La tienda no pudo iniciar esta compra. Revisa tu cuenta de la tienda y la configuración de pago, luego inténtalo de nuevo.',
      'fr':
          'Le store n’a pas pu lancer cet achat. Vérifiez votre compte store et le paiement, puis réessayez.',
      'it':
          'Lo store non ha potuto avviare l’acquisto. Controlla account store e pagamento, poi riprova.',
      'ja': 'ストアで購入を開始できませんでした。ストアアカウントと支払い設定を確認して、もう一度お試しください。',
      'ko': '스토어에서 구매를 시작할 수 없습니다. 스토어 계정과 결제 설정을 확인한 뒤 다시 시도하세요.',
      'nl':
          'De store kon deze aankoop niet starten. Controleer je store-account en betaalinstellingen en probeer opnieuw.',
      'ru':
          'Магазин не смог начать покупку. Проверьте аккаунт магазина и платёжные настройки, затем повторите попытку.',
    },
    'Purchase failed. Check your store account and try again.': {
      'zh-Hans': '购买失败。请检查商店账号后重试。',
      'zh-Hant': '購買失敗。請檢查商店帳號後重試。',
      'de':
          'Kauf fehlgeschlagen. Prüfe dein Store-Konto und versuche es erneut.',
      'es':
          'La compra falló. Revisa tu cuenta de la tienda e inténtalo de nuevo.',
      'fr': 'L’achat a échoué. Vérifiez votre compte store, puis réessayez.',
      'it': 'Acquisto non riuscito. Controlla l’account store e riprova.',
      'ja': '購入に失敗しました。ストアアカウントを確認して、もう一度お試しください。',
      'ko': '구매에 실패했습니다. 스토어 계정을 확인하고 다시 시도하세요.',
      'nl': 'Aankoop mislukt. Controleer je store-account en probeer opnieuw.',
      'ru':
          'Покупка не удалась. Проверьте аккаунт магазина и повторите попытку.',
    },
    'Restore failed. Check your store account and try again.': {
      'zh-Hans': '恢复购买失败。请检查商店账号后重试。',
      'zh-Hant': '恢復購買失敗。請檢查商店帳號後重試。',
      'de':
          'Wiederherstellung fehlgeschlagen. Prüfe dein Store-Konto und versuche es erneut.',
      'es':
          'No se pudo restaurar. Revisa tu cuenta de la tienda e inténtalo de nuevo.',
      'fr':
          'La restauration a échoué. Vérifiez votre compte store, puis réessayez.',
      'it': 'Ripristino non riuscito. Controlla l’account store e riprova.',
      'ja': '購入の復元に失敗しました。ストアアカウントを確認して、もう一度お試しください。',
      'ko': '복원에 실패했습니다. 스토어 계정을 확인하고 다시 시도하세요.',
      'nl':
          'Herstellen mislukt. Controleer je store-account en probeer opnieuw.',
      'ru':
          'Восстановление не удалось. Проверьте аккаунт магазина и повторите попытку.',
    },
    'Sign-in service is unavailable. Please try again later.': {
      'zh-Hans': '登录服务暂不可用，请稍后重试。',
      'zh-Hant': '登入服務暫不可用，請稍後重試。',
      'de':
          'Anmeldung ist derzeit nicht verfügbar. Bitte später erneut versuchen.',
      'es': 'El inicio de sesión no está disponible. Inténtalo más tarde.',
      'fr':
          'La connexion est indisponible pour le moment. Réessayez plus tard.',
      'it': 'L’accesso non è disponibile al momento. Riprova più tardi.',
      'ja': 'サインインサービスは現在利用できません。後でもう一度お試しください。',
      'ko': '로그인 서비스를 사용할 수 없습니다. 나중에 다시 시도하세요.',
      'nl': 'Aanmelden is nu niet beschikbaar. Probeer het later opnieuw.',
      'ru': 'Вход сейчас недоступен. Повторите попытку позже.',
    },
    'Sign in did not finish. Please try again.': {
      'zh-Hans': '登录未完成，请重试。',
      'zh-Hant': '登入未完成，請重試。',
      'de': 'Anmeldung wurde nicht abgeschlossen. Bitte erneut versuchen.',
      'es': 'El inicio de sesión no terminó. Inténtalo de nuevo.',
      'fr': 'La connexion n’est pas terminée. Réessayez.',
      'it': 'Accesso non completato. Riprova.',
      'ja': 'サインインが完了しませんでした。もう一度お試しください。',
      'ko': '로그인이 완료되지 않았습니다. 다시 시도하세요.',
      'nl': 'Aanmelden is niet voltooid. Probeer opnieuw.',
      'ru': 'Вход не завершён. Повторите попытку.',
    },
    'Apple sign in is not available on this device yet.': {
      'zh-Hans': '此设备暂不支持 Apple 登录。',
      'zh-Hant': '此裝置暫不支援 Apple 登入。',
      'de': 'Apple-Anmeldung ist auf diesem Gerät noch nicht verfügbar.',
      'es': 'Apple Sign In aún no está disponible en este dispositivo.',
      'fr': 'La connexion Apple n’est pas encore disponible sur cet appareil.',
      'it':
          'L’accesso con Apple non è ancora disponibile su questo dispositivo.',
      'ja': 'この端末では Apple サインインをまだ利用できません。',
      'ko': '이 기기에서는 아직 Apple 로그인을 사용할 수 없습니다.',
      'nl': 'Apple-aanmelding is nog niet beschikbaar op dit apparaat.',
      'ru': 'Вход через Apple пока недоступен на этом устройстве.',
    },
    'Google sign in is not ready yet. Please use another sign-in method.': {
      'zh-Hans': 'Google 登录尚未准备好，请使用其他登录方式。',
      'zh-Hant': 'Google 登入尚未準備好，請使用其他登入方式。',
      'de':
          'Google-Anmeldung ist noch nicht bereit. Bitte nutze eine andere Methode.',
      'es':
          'Google Sign In aún no está listo. Usa otro método de inicio de sesión.',
      'fr':
          'La connexion Google n’est pas encore prête. Utilisez une autre méthode.',
      'it': 'L’accesso con Google non è ancora pronto. Usa un altro metodo.',
      'ja': 'Google サインインはまだ準備できていません。別のサインイン方法を使用してください。',
      'ko': 'Google 로그인이 아직 준비되지 않았습니다. 다른 로그인 방법을 사용하세요.',
      'nl':
          'Google-aanmelding is nog niet klaar. Gebruik een andere aanmeldmethode.',
      'ru': 'Вход через Google ещё не готов. Используйте другой способ входа.',
    },
    'Google sign in is not available on this device yet.': {
      'zh-Hans': '此设备暂不支持 Google 登录。',
      'zh-Hant': '此裝置暫不支援 Google 登入。',
      'de': 'Google-Anmeldung ist auf diesem Gerät noch nicht verfügbar.',
      'es': 'Google Sign In aún no está disponible en este dispositivo.',
      'fr': 'La connexion Google n’est pas encore disponible sur cet appareil.',
      'it':
          'L’accesso con Google non è ancora disponibile su questo dispositivo.',
      'ja': 'この端末では Google サインインをまだ利用できません。',
      'ko': '이 기기에서는 아직 Google 로그인을 사용할 수 없습니다.',
      'nl': 'Google-aanmelding is nog niet beschikbaar op dit apparaat.',
      'ru': 'Вход через Google пока недоступен на этом устройстве.',
    },
    'Meta sign in is not available yet. Please use another sign-in method.': {
      'zh-Hans': 'Meta 登录暂不可用，请使用其他登录方式。',
      'zh-Hant': 'Meta 登入暫不可用，請使用其他登入方式。',
      'de':
          'Meta-Anmeldung ist noch nicht verfügbar. Bitte nutze eine andere Methode.',
      'es':
          'Meta Sign In aún no está disponible. Usa otro método de inicio de sesión.',
      'fr':
          'La connexion Meta n’est pas encore disponible. Utilisez une autre méthode.',
      'it': 'L’accesso con Meta non è ancora disponibile. Usa un altro metodo.',
      'ja': 'Meta サインインはまだ利用できません。別のサインイン方法を使用してください。',
      'ko': 'Meta 로그인을 아직 사용할 수 없습니다. 다른 로그인 방법을 사용하세요.',
      'nl':
          'Meta-aanmelding is nog niet beschikbaar. Gebruik een andere aanmeldmethode.',
      'ru': 'Вход через Meta пока недоступен. Используйте другой способ входа.',
    },
    'Wallet is not available right now. Check your connection and try again.': {
      'zh-Hans': '钱包暂不可用。请检查网络后重试。',
      'zh-Hant': '錢包暫不可用。請檢查網路後重試。',
      'de':
          'Wallet ist gerade nicht verfügbar. Prüfe die Verbindung und versuche es erneut.',
      'es':
          'La wallet no está disponible ahora. Revisa la conexión e inténtalo de nuevo.',
      'fr':
          'Le wallet est indisponible pour le moment. Vérifiez la connexion et réessayez.',
      'it':
          'Il wallet non è disponibile ora. Controlla la connessione e riprova.',
      'ja': 'ウォレットは現在利用できません。接続を確認して、もう一度お試しください。',
      'ko': '지갑을 지금 사용할 수 없습니다. 연결을 확인하고 다시 시도하세요.',
      'nl':
          'Wallet is nu niet beschikbaar. Controleer je verbinding en probeer opnieuw.',
      'ru':
          'Кошелёк сейчас недоступен. Проверьте подключение и повторите попытку.',
    },
    'Verification is not available right now. Please try again later.': {
      'zh-Hans': '验证暂不可用，请稍后重试。',
      'zh-Hant': '驗證暫不可用，請稍後重試。',
      'de':
          'Verifizierung ist gerade nicht verfügbar. Bitte später erneut versuchen.',
      'es': 'La verificación no está disponible ahora. Inténtalo más tarde.',
      'fr':
          'La vérification est indisponible pour le moment. Réessayez plus tard.',
      'it': 'La verifica non è disponibile ora. Riprova più tardi.',
      'ja': '認証は現在利用できません。後でもう一度お試しください。',
      'ko': '인증을 지금 사용할 수 없습니다. 나중에 다시 시도하세요.',
      'nl': 'Verificatie is nu niet beschikbaar. Probeer het later opnieuw.',
      'ru': 'Проверка сейчас недоступна. Повторите попытку позже.',
    },
    'Saving Stockfish report...': {
      'zh-Hans': '正在保存 Stockfish 报告...',
      'zh-Hant': '正在儲存 Stockfish 報告...',
      'de': 'Stockfish-Bericht wird gespeichert...',
      'es': 'Guardando informe Stockfish...',
      'fr': 'Enregistrement du rapport Stockfish...',
      'it': 'Salvataggio report Stockfish...',
      'ja': 'Stockfish レポートを保存中...',
      'ko': 'Stockfish 보고서 저장 중...',
      'nl': 'Stockfish-rapport opslaan...',
      'ru': 'Сохранение отчёта Stockfish...',
    },
    'Grandeur review is preparing. You can come back later.': {
      'zh-Hans': 'Grandeur 复盘正在准备。你可以稍后再回来查看。',
      'zh-Hant': 'Grandeur 複盤正在準備。你可以稍後再回來查看。',
      'de': 'Grandeur-Review wird vorbereitet. Du kannst später wiederkommen.',
      'es': 'La revisión Grandeur se está preparando. Puedes volver más tarde.',
      'fr': 'La revue Grandeur se prépare. Vous pouvez revenir plus tard.',
      'it': 'La revisione Grandeur è in preparazione. Puoi tornare più tardi.',
      'ja': 'Grandeur レビューを準備中です。後で戻って確認できます。',
      'ko': 'Grandeur 리뷰를 준비 중입니다. 나중에 다시 확인할 수 있습니다.',
      'nl': 'Grandeur-review wordt voorbereid. Je kunt later terugkomen.',
      'ru': 'Обзор Grandeur готовится. Можно вернуться позже.',
    },
    'Chessnut checks membership and wallet balance.': {
      'zh-Hans': 'Chessnut 会检查会员状态和钱包积分。',
      'zh-Hant': 'Chessnut 會檢查會員狀態和錢包積分。',
      'de': 'Chessnut prüft Mitgliedschaft und Wallet-Guthaben.',
      'es': 'Chessnut comprueba la membresía y el saldo de wallet.',
      'fr': 'Chessnut vérifie l’abonnement et le solde du wallet.',
      'it': 'Chessnut controlla abbonamento e saldo wallet.',
      'ja': 'Chessnut がメンバーシップとウォレット残高を確認します。',
      'ko': 'Chessnut이 멤버십과 지갑 잔액을 확인합니다.',
      'nl': 'Chessnut controleert lidmaatschap en walletsaldo.',
      'ru': 'Chessnut проверяет подписку и баланс кошелька.',
    },
    'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.':
        {
      'zh-Hans':
          'Grandeur 通常消耗 100 钱包积分。会员会自动按 0 积分处理。如果积分不足，可以通过 Daily Tasks 赚取。',
      'zh-Hant':
          'Grandeur 通常消耗 100 錢包積分。會員會自動按 0 積分處理。如果積分不足，可以透過 Daily Tasks 賺取。',
      'de':
          'Grandeur kostet normalerweise 100 Wallet-Punkte. Mitglieder zahlen automatisch 0 Punkte. Wenn Punkte fehlen, kannst du sie über Daily Tasks verdienen.',
      'es':
          'Grandeur normalmente cuesta 100 puntos de wallet. Los miembros pagan 0 puntos automáticamente. Si no tienes suficientes puntos, puedes ganar más en Daily Tasks.',
      'fr':
          'Grandeur coûte normalement 100 points wallet. Les membres paient automatiquement 0 point. S’il vous manque des points, gagnez-en dans Daily Tasks.',
      'it':
          'Grandeur costa normalmente 100 punti wallet. I membri pagano automaticamente 0 punti. Se non hai abbastanza punti, puoi guadagnarne con Daily Tasks.',
      'ja':
          'Grandeur は通常 100 ウォレットポイントです。メンバーは自動的に 0 ポイントになります。ポイントが足りない場合は Daily Tasks で獲得できます。',
      'ko':
          'Grandeur는 보통 지갑 포인트 100점이 필요합니다. 멤버는 자동으로 0점 처리됩니다. 포인트가 부족하면 Daily Tasks에서 더 얻을 수 있습니다.',
      'nl':
          'Grandeur kost normaal 100 walletpunten. Leden betalen automatisch 0 punten. Als je te weinig punten hebt, kun je meer verdienen via Daily Tasks.',
      'ru':
          'Grandeur обычно стоит 100 баллов кошелька. Для участников стоимость автоматически 0 баллов. Если баллов не хватает, их можно заработать в Daily Tasks.',
    },
    'You can leave this page. Chessnut will keep working and save the report when it is ready.':
        {
      'zh-Hans': '你可以离开此页面。Chessnut 会继续处理，并在报告完成后保存。',
      'zh-Hant': '你可以離開此頁面。Chessnut 會繼續處理，並在報告完成後儲存。',
      'de':
          'Du kannst diese Seite verlassen. Chessnut arbeitet weiter und speichert den Bericht, sobald er fertig ist.',
      'es':
          'Puedes salir de esta página. Chessnut seguirá trabajando y guardará el informe cuando esté listo.',
      'fr':
          'Vous pouvez quitter cette page. Chessnut continuera et enregistrera le rapport une fois prêt.',
      'it':
          'Puoi lasciare questa pagina. Chessnut continuerà a lavorare e salverà il report quando sarà pronto.',
      'ja': 'このページを離れても大丈夫です。Chessnut が処理を続け、準備できたらレポートを保存します。',
      'ko': '이 페이지를 나가도 됩니다. Chessnut이 계속 작업하고 보고서가 준비되면 저장합니다.',
      'nl':
          'Je kunt deze pagina verlaten. Chessnut werkt verder en slaat het rapport op zodra het klaar is.',
      'ru':
          'Можно покинуть страницу. Chessnut продолжит работу и сохранит отчёт, когда он будет готов.',
    },
    'Chessnut will turn this PGN into a review board, move list, and analysis report.':
        {
      'zh-Hans': 'Chessnut 会把这份 PGN 转成复盘棋盘、走法列表和分析报告。',
      'zh-Hant': 'Chessnut 會把這份 PGN 轉成複盤棋盤、著法列表和分析報告。',
      'de':
          'Chessnut verwandelt dieses PGN in ein Review-Brett, eine Zugliste und einen Analysebericht.',
      'es':
          'Chessnut convertirá este PGN en tablero de revisión, lista de jugadas e informe de análisis.',
      'fr':
          'Chessnut transformera ce PGN en échiquier de revue, liste de coups et rapport d’analyse.',
      'it':
          'Chessnut trasformerà questo PGN in scacchiera di revisione, lista mosse e report di analisi.',
      'ja': 'Chessnut がこの PGN をレビュー用ボード、手順リスト、分析レポートに変換します。',
      'ko': 'Chessnut이 이 PGN을 리뷰 보드, 수 목록, 분석 보고서로 바꿉니다.',
      'nl':
          'Chessnut zet deze PGN om in een reviewbord, zettenlijst en analyserapport.',
      'ru':
          'Chessnut превратит этот PGN в доску разбора, список ходов и аналитический отчёт.',
    },
    'Grandeur report is preparing.': {
      'zh-Hans': 'Grandeur 报告正在准备。',
      'zh-Hant': 'Grandeur 報告正在準備。',
      'de': 'Grandeur-Bericht wird vorbereitet.',
      'es': 'Preparando informe Grandeur.',
      'fr': 'Préparation du rapport Grandeur.',
      'it': 'Preparazione report Grandeur.',
      'ja': 'Grandeur レポートを準備中です。',
      'ko': 'Grandeur 보고서를 준비 중입니다.',
      'nl': 'Grandeur-rapport voorbereiden.',
      'ru': 'Подготовка отчёта Grandeur.',
    },
    'Grandeur report is generating. You can leave this page and reopen the report later.':
        {
      'zh-Hans': 'Grandeur 报告正在生成。你可以离开此页面，稍后重新打开报告。',
      'zh-Hant': 'Grandeur 報告正在產生。你可以離開此頁面，稍後重新開啟報告。',
      'de':
          'Grandeur-Bericht wird erstellt. Du kannst die Seite verlassen und den Bericht später erneut öffnen.',
      'es':
          'El informe Grandeur se está generando. Puedes salir de esta página y volver al informe más tarde.',
      'fr':
          'Le rapport Grandeur est en cours de génération. Vous pouvez quitter cette page et le rouvrir plus tard.',
      'it':
          'Il report Grandeur è in generazione. Puoi lasciare questa pagina e riaprire il report più tardi.',
      'ja': 'Grandeur レポートを生成中です。このページを離れて、後でレポートを再度開けます。',
      'ko': 'Grandeur 보고서를 생성 중입니다. 이 페이지를 나가고 나중에 보고서를 다시 열 수 있습니다.',
      'nl':
          'Grandeur-rapport wordt gemaakt. Je kunt deze pagina verlaten en het rapport later opnieuw openen.',
      'ru':
          'Отчёт Grandeur создаётся. Можно покинуть страницу и открыть отчёт позже.',
    },
    'Grandeur is taking longer than expected. Your report is saved; reopen it later to continue checking.':
        {
      'zh-Hans': 'Grandeur 用时比预期更久。报告已保存，稍后重新打开即可继续查看。',
      'zh-Hant': 'Grandeur 用時比預期更久。報告已儲存，稍後重新開啟即可繼續查看。',
      'de':
          'Grandeur dauert länger als erwartet. Dein Bericht ist gespeichert; öffne ihn später erneut.',
      'es':
          'Grandeur tarda más de lo esperado. Tu informe está guardado; vuelve a abrirlo más tarde.',
      'fr':
          'Grandeur prend plus de temps que prévu. Votre rapport est enregistré ; rouvrez-le plus tard.',
      'it':
          'Grandeur sta impiegando più del previsto. Il report è salvato; riaprilo più tardi.',
      'ja': 'Grandeur に予想より時間がかかっています。レポートは保存済みなので、後で開いて確認できます。',
      'ko': 'Grandeur가 예상보다 오래 걸립니다. 보고서는 저장되었으니 나중에 다시 열어 확인하세요.',
      'nl':
          'Grandeur duurt langer dan verwacht. Je rapport is opgeslagen; open het later opnieuw.',
      'ru':
          'Grandeur занимает больше времени, чем ожидалось. Отчёт сохранён; откройте его позже.',
    },
    'Grandeur analysis failed. Please try again.': {
      'zh-Hans': 'Grandeur 分析失败，请重试。',
      'zh-Hant': 'Grandeur 分析失敗，請重試。',
      'de': 'Grandeur-Analyse fehlgeschlagen. Bitte erneut versuchen.',
      'es': 'El análisis Grandeur falló. Inténtalo de nuevo.',
      'fr': 'L’analyse Grandeur a échoué. Réessayez.',
      'it': 'Analisi Grandeur non riuscita. Riprova.',
      'ja': 'Grandeur 分析に失敗しました。もう一度お試しください。',
      'ko': 'Grandeur 분석에 실패했습니다. 다시 시도하세요.',
      'nl': 'Grandeur-analyse mislukt. Probeer opnieuw.',
      'ru': 'Анализ Grandeur не удался. Повторите попытку.',
    },
    'Find opponents and sync board moves': {
      'zh-Hans': '寻找对手并同步棋盘走法',
      'zh-Hant': '尋找對手並同步棋盤著法',
      'de': 'Gegner suchen und Brettzüge synchronisieren',
      'es': 'Buscar rivales y sincronizar jugadas del tablero',
      'fr': 'Trouver des adversaires et synchroniser les coups',
      'it': 'Trova avversari e sincronizza le mosse',
      'ja': '対戦相手を探し、ボードの手を同期',
      'ko': '상대를 찾고 보드 수 동기화',
      'nl': 'Tegenstanders zoeken en bordzetten synchroniseren',
      'ru': 'Поиск соперников и синхронизация ходов доски',
    },
    'Lichess online game': {
      'zh-Hans': 'Lichess 线上对局',
      'zh-Hant': 'Lichess 線上對局',
      'de': 'Lichess-Onlinepartie',
      'es': 'Partida en línea Lichess',
      'fr': 'Partie en ligne Lichess',
      'it': 'Partita online Lichess',
      'ja': 'Lichess オンライン対局',
      'ko': 'Lichess 온라인 대국',
      'nl': 'Lichess-onlinepartij',
      'ru': 'Онлайн-партия Lichess',
    },
    'Authorize Lichess first so Chessnut can start online games and sync moves to your board.':
        {
      'zh-Hans': '请先授权 Lichess，这样 Chessnut 才能开始线上对局并同步走法到你的棋盘。',
      'zh-Hant': '請先授權 Lichess，這樣 Chessnut 才能開始線上對局並同步著法到你的棋盤。',
      'de':
          'Autorisiere zuerst Lichess, damit Chessnut Onlinepartien starten und Züge mit deinem Brett synchronisieren kann.',
      'es':
          'Autoriza Lichess primero para que Chessnut pueda iniciar partidas en línea y sincronizar jugadas con tu tablero.',
      'fr':
          'Autorisez d’abord Lichess pour que Chessnut puisse lancer des parties en ligne et synchroniser les coups avec votre échiquier.',
      'it':
          'Autorizza prima Lichess così Chessnut può avviare partite online e sincronizzare le mosse con la scacchiera.',
      'ja': 'まず Lichess を認証してください。Chessnut がオンライン対局を開始し、指し手をボードに同期できます。',
      'ko': '먼저 Lichess를 인증하세요. 그래야 Chessnut이 온라인 대국을 시작하고 수를 보드에 동기화할 수 있습니다.',
      'nl':
          'Autoriseer eerst Lichess zodat Chessnut online partijen kan starten en zetten met je bord kan synchroniseren.',
      'ru':
          'Сначала авторизуйте Lichess, чтобы Chessnut мог запускать онлайн-партии и синхронизировать ходы с доской.',
    },
    'Finding game...': {
      'zh-Hans': '正在寻找对局...',
      'zh-Hant': '正在尋找對局...',
      'de': 'Partie suchen...',
      'es': 'Buscando partida...',
      'fr': 'Recherche de partie...',
      'it': 'Ricerca partita...',
      'ja': '対局を検索中...',
      'ko': '대국 찾는 중...',
      'nl': 'Partij zoeken...',
      'ru': 'Поиск партии...',
    },
    'Authorize Lichess before starting an online game.': {
      'zh-Hans': '开始线上对局前，请先授权 Lichess。',
      'zh-Hant': '開始線上對局前，請先授權 Lichess。',
      'de': 'Autorisiere Lichess, bevor du eine Onlinepartie startest.',
      'es': 'Autoriza Lichess antes de iniciar una partida en línea.',
      'fr': 'Autorisez Lichess avant de lancer une partie en ligne.',
      'it': 'Autorizza Lichess prima di avviare una partita online.',
      'ja': 'オンライン対局を始める前に Lichess を認証してください。',
      'ko': '온라인 대국을 시작하기 전에 Lichess를 인증하세요.',
      'nl': 'Autoriseer Lichess voordat je een online partij start.',
      'ru': 'Авторизуйте Lichess перед началом онлайн-партии.',
    },
    'Your Lichess sign-in expired. Authorize again before playing.': {
      'zh-Hans': '你的 Lichess 登录已过期。请重新授权后再开始对局。',
      'zh-Hant': '你的 Lichess 登入已過期。請重新授權後再開始對局。',
      'de':
          'Deine Lichess-Anmeldung ist abgelaufen. Autorisiere erneut vor dem Spielen.',
      'es':
          'Tu inicio de sesión de Lichess expiró. Autoriza de nuevo antes de jugar.',
      'fr':
          'Votre connexion Lichess a expiré. Autorisez à nouveau avant de jouer.',
      'it':
          'L’accesso a Lichess è scaduto. Autorizza di nuovo prima di giocare.',
      'ja': 'Lichess のサインイン期限が切れました。対局前に再認証してください。',
      'ko': 'Lichess 로그인이 만료되었습니다. 플레이 전에 다시 인증하세요.',
      'nl':
          'Je Lichess-aanmelding is verlopen. Autoriseer opnieuw voordat je speelt.',
      'ru': 'Вход в Lichess истёк. Авторизуйте заново перед игрой.',
    },
    'Authorize Lichess so Chessnut can start online games and sync your board moves.':
        {
      'zh-Hans': '授权 Lichess 后，Chessnut 才能开始线上对局并同步你的棋盘走法。',
      'zh-Hant': '授權 Lichess 後，Chessnut 才能開始線上對局並同步你的棋盤著法。',
      'de':
          'Autorisiere Lichess, damit Chessnut Onlinepartien starten und deine Brettzüge synchronisieren kann.',
      'es':
          'Autoriza Lichess para que Chessnut pueda iniciar partidas en línea y sincronizar tus jugadas del tablero.',
      'fr':
          'Autorisez Lichess pour que Chessnut puisse lancer des parties en ligne et synchroniser vos coups.',
      'it':
          'Autorizza Lichess così Chessnut può avviare partite online e sincronizzare le mosse della scacchiera.',
      'ja': 'Lichess を認証すると、Chessnut がオンライン対局を開始し、ボードの指し手を同期できます。',
      'ko': 'Lichess를 인증하면 Chessnut이 온라인 대국을 시작하고 보드 수를 동기화할 수 있습니다.',
      'nl':
          'Autoriseer Lichess zodat Chessnut online partijen kan starten en je bordzetten kan synchroniseren.',
      'ru':
          'Авторизуйте Lichess, чтобы Chessnut мог запускать онлайн-партии и синхронизировать ходы доски.',
    },
    'Authorized': {
      'zh-Hans': '已授权',
      'zh-Hant': '已授權',
      'de': 'Autorisiert',
      'es': 'Autorizado',
      'fr': 'Autorisé',
      'it': 'Autorizzato',
      'ja': '認証済み',
      'ko': '인증됨',
      'nl': 'Geautoriseerd',
      'ru': 'Авторизовано',
    },
    'Sign-in needed': {
      'zh-Hans': '需要登录',
      'zh-Hant': '需要登入',
      'de': 'Anmeldung nötig',
      'es': 'Requiere inicio de sesión',
      'fr': 'Connexion requise',
      'it': 'Accesso richiesto',
      'ja': 'サインインが必要',
      'ko': '로그인 필요',
      'nl': 'Aanmelden vereist',
      'ru': 'Требуется вход',
    },
    'Play permission': {
      'zh-Hans': '对局权限',
      'zh-Hant': '對局權限',
      'de': 'Spielberechtigung',
      'es': 'Permiso para jugar',
      'fr': 'Autorisation de jouer',
      'it': 'Permesso di gioco',
      'ja': '対局権限',
      'ko': '플레이 권한',
      'nl': 'Speeltoestemming',
      'ru': 'Разрешение на игру',
    },
    'Ready to play': {
      'zh-Hans': '可开始对局',
      'zh-Hant': '可開始對局',
      'de': 'Spielbereit',
      'es': 'Listo para jugar',
      'fr': 'Prêt à jouer',
      'it': 'Pronto a giocare',
      'ja': '対局準備完了',
      'ko': '플레이 준비됨',
      'nl': 'Klaar om te spelen',
      'ru': 'Готово к игре',
    },
    'Authorize': {
      'zh-Hans': '授权',
      'zh-Hant': '授權',
      'de': 'Autorisieren',
      'es': 'Autorizar',
      'fr': 'Autoriser',
      'it': 'Autorizza',
      'ja': '認証',
      'ko': '인증',
      'nl': 'Autoriseren',
      'ru': 'Авторизовать',
    },
    'Verification took too long. Check your connection and try again.': {
      'zh-Hans': '验证超时。请检查网络后重试。',
      'zh-Hant': '驗證逾時。請檢查網路後重試。',
      'de':
          'Die Verifizierung dauert zu lange. Prüfe die Verbindung und versuche es erneut.',
      'es':
          'La verificación tardó demasiado. Revisa la conexión e inténtalo de nuevo.',
      'fr':
          'La vérification prend trop de temps. Vérifiez la connexion et réessayez.',
      'it':
          'La verifica sta richiedendo troppo tempo. Controlla la connessione e riprova.',
      'ja': '確認に時間がかかりすぎています。接続を確認してもう一度お試しください。',
      'ko': '인증 시간이 너무 오래 걸립니다. 연결을 확인하고 다시 시도하세요.',
      'nl':
          'Verificatie duurt te lang. Controleer je verbinding en probeer opnieuw.',
      'ru':
          'Проверка занимает слишком много времени. Проверьте подключение и повторите попытку.',
    },
    'Verification could not open. Check your connection and try again.': {
      'zh-Hans': '无法打开验证。请检查网络后重试。',
      'zh-Hant': '無法開啟驗證。請檢查網路後重試。',
      'de':
          'Verifizierung konnte nicht geöffnet werden. Prüfe die Verbindung und versuche es erneut.',
      'es':
          'No se pudo abrir la verificación. Revisa la conexión e inténtalo de nuevo.',
      'fr':
          'Impossible d’ouvrir la vérification. Vérifiez la connexion et réessayez.',
      'it':
          'Impossibile aprire la verifica. Controlla la connessione e riprova.',
      'ja': '確認を開けませんでした。接続を確認してもう一度お試しください。',
      'ko': '인증을 열 수 없습니다. 연결을 확인하고 다시 시도하세요.',
      'nl':
          'Kan verificatie niet openen. Controleer je verbinding en probeer opnieuw.',
      'ru':
          'Не удалось открыть проверку. Проверьте подключение и повторите попытку.',
    },
    'Verification failed. Please try again.': {
      'zh-Hans': '验证失败。请重试。',
      'zh-Hant': '驗證失敗。請重試。',
      'de': 'Verifizierung fehlgeschlagen. Bitte erneut versuchen.',
      'es': 'La verificación falló. Inténtalo de nuevo.',
      'fr': 'La vérification a échoué. Réessayez.',
      'it': 'Verifica non riuscita. Riprova.',
      'ja': '確認に失敗しました。もう一度お試しください。',
      'ko': '인증에 실패했습니다. 다시 시도하세요.',
      'nl': 'Verificatie mislukt. Probeer opnieuw.',
      'ru': 'Проверка не удалась. Повторите попытку.',
    },
    'Verification was incomplete. Please try again.': {
      'zh-Hans': '验证未完成。请重试。',
      'zh-Hant': '驗證未完成。請重試。',
      'de': 'Verifizierung wurde nicht abgeschlossen. Bitte erneut versuchen.',
      'es': 'La verificación no se completó. Inténtalo de nuevo.',
      'fr': 'La vérification n’est pas terminée. Réessayez.',
      'it': 'Verifica non completata. Riprova.',
      'ja': '確認が完了していません。もう一度お試しください。',
      'ko': '인증이 완료되지 않았습니다. 다시 시도하세요.',
      'nl': 'Verificatie is niet voltooid. Probeer opnieuw.',
      'ru': 'Проверка не завершена. Повторите попытку.',
    },
    'Verification was cancelled.': {
      'zh-Hans': '验证已取消。',
      'zh-Hant': '驗證已取消。',
      'de': 'Verifizierung abgebrochen.',
      'es': 'Verificación cancelada.',
      'fr': 'Vérification annulée.',
      'it': 'Verifica annullata.',
      'ja': '確認がキャンセルされました。',
      'ko': '인증이 취소되었습니다.',
      'nl': 'Verificatie geannuleerd.',
      'ru': 'Проверка отменена.',
    },
    'Verification could not open in the app': {
      'zh-Hans': '无法在 App 内打开验证',
      'zh-Hant': '無法在 App 內開啟驗證',
      'de': 'Verifizierung konnte in der App nicht geöffnet werden',
      'es': 'No se pudo abrir la verificación en la app',
      'fr': 'Impossible d’ouvrir la vérification dans l’app',
      'it': 'Impossibile aprire la verifica nell’app',
      'ja': 'アプリ内で確認を開けませんでした',
      'ko': '앱 안에서 인증을 열 수 없습니다',
      'nl': 'Kan verificatie niet openen in de app',
      'ru': 'Не удалось открыть проверку в приложении',
    },
    'Verification could not open in the app. Continue to try another way.': {
      'zh-Hans': '无法在 App 内打开验证。请继续尝试其他方式。',
      'zh-Hant': '無法在 App 內開啟驗證。請繼續嘗試其他方式。',
      'de':
          'Verifizierung konnte in der App nicht geöffnet werden. Fahre fort und versuche einen anderen Weg.',
      'es':
          'No se pudo abrir la verificación en la app. Continúa para probar otra forma.',
      'fr':
          'Impossible d’ouvrir la vérification dans l’app. Continuez pour essayer autrement.',
      'it':
          'Impossibile aprire la verifica nell’app. Continua per provare un altro modo.',
      'ja': 'アプリ内で確認を開けませんでした。別の方法を試してください。',
      'ko': '앱 안에서 인증을 열 수 없습니다. 다른 방법을 계속 시도하세요.',
      'nl':
          'Kan verificatie niet openen in de app. Ga door om een andere manier te proberen.',
      'ru':
          'Не удалось открыть проверку в приложении. Продолжите и попробуйте другой способ.',
    },
    'Verification could not open in the app. Try the browser verification.': {
      'zh-Hans': '无法在 App 内打开验证。请尝试浏览器验证。',
      'zh-Hant': '無法在 App 內開啟驗證。請嘗試瀏覽器驗證。',
      'de':
          'Verifizierung konnte in der App nicht geöffnet werden. Versuche die Browser-Verifizierung.',
      'es':
          'No se pudo abrir la verificación en la app. Prueba la verificación en el navegador.',
      'fr':
          'Impossible d’ouvrir la vérification dans l’app. Essayez la vérification dans le navigateur.',
      'it':
          'Impossibile aprire la verifica nell’app. Prova la verifica nel browser.',
      'ja': 'アプリ内で確認を開けませんでした。ブラウザーでの確認をお試しください。',
      'ko': '앱 안에서 인증을 열 수 없습니다. 브라우저 인증을 시도하세요.',
      'nl':
          'Kan verificatie niet openen in de app. Probeer verificatie in de browser.',
      'ru':
          'Не удалось открыть проверку в приложении. Попробуйте проверку в браузере.',
    },
    'Authorization could not open in the app. Opening Lichess in your browser.':
        {
      'zh-Hans': '无法在 App 内打开授权。正在浏览器中打开 Lichess。',
      'zh-Hant': '無法在 App 內開啟授權。正在瀏覽器中開啟 Lichess。',
      'de':
          'Autorisierung konnte in der App nicht geöffnet werden. Lichess wird im Browser geöffnet.',
      'es':
          'No se pudo abrir la autorización en la app. Se abrirá Lichess en el navegador.',
      'fr':
          'Impossible d’ouvrir l’autorisation dans l’app. Lichess va s’ouvrir dans le navigateur.',
      'it':
          'Impossibile aprire l’autorizzazione nell’app. Apro Lichess nel browser.',
      'ja': 'アプリ内で認証を開けませんでした。ブラウザーで Lichess を開きます。',
      'ko': '앱 안에서 인증을 열 수 없습니다. 브라우저에서 Lichess를 엽니다.',
      'nl':
          'Kan autorisatie niet openen in de app. Lichess wordt in je browser geopend.',
      'ru':
          'Не удалось открыть авторизацию в приложении. Lichess откроется в браузере.',
    },
    'Authorization could not open in the app. Check WebView2 and try again.': {
      'zh-Hans': '无法在 App 内打开授权。请检查 WebView2 后重试。',
      'zh-Hant': '無法在 App 內開啟授權。請檢查 WebView2 後重試。',
      'de':
          'Autorisierung konnte in der App nicht geoeffnet werden. Pruefe WebView2 und versuche es erneut.',
      'es':
          'No se pudo abrir la autorizacion en la app. Revisa WebView2 e intentalo de nuevo.',
      'fr':
          'Impossible d’ouvrir l’autorisation dans l’app. Verifiez WebView2 puis reessayez.',
      'it':
          'Impossibile aprire l’autorizzazione nell’app. Controlla WebView2 e riprova.',
      'ja': 'アプリ内で認証を開けません。WebView2 を確認してもう一度お試しください。',
      'ko': '앱 안에서 인증을 열 수 없습니다. WebView2를 확인한 뒤 다시 시도하세요.',
      'nl':
          'Kan autorisatie niet openen in de app. Controleer WebView2 en probeer opnieuw.',
      'ru':
          'Не удалось открыть авторизацию в приложении. Проверьте WebView2 и попробуйте снова.',
    },
    'Lichess authorization is not available right now. Please try again later.':
        {
      'zh-Hans': 'Lichess 授权暂时不可用。请稍后重试。',
      'zh-Hant': 'Lichess 授權暫時不可用。請稍後再試。',
      'de':
          'Lichess-Autorisierung ist derzeit nicht verfügbar. Bitte versuche es später erneut.',
      'es':
          'La autorización de Lichess no está disponible ahora. Inténtalo de nuevo más tarde.',
      'fr':
          'L’autorisation Lichess est indisponible pour le moment. Réessayez plus tard.',
      'it':
          'L’autorizzazione Lichess non è disponibile al momento. Riprova più tardi.',
      'ja': 'Lichess 認証は現在利用できません。しばらくしてからもう一度お試しください。',
      'ko': '현재 Lichess 인증을 사용할 수 없습니다. 나중에 다시 시도하세요.',
      'nl':
          'Lichess-autorisatie is nu niet beschikbaar. Probeer het later opnieuw.',
      'ru': 'Авторизация Lichess сейчас недоступна. Повторите попытку позже.',
    },
    'Lichess authorization could not open. Try again later.': {
      'zh-Hans': '无法打开 Lichess 授权。请稍后重试。',
      'zh-Hant': '無法開啟 Lichess 授權。請稍後再試。',
      'de':
          'Lichess-Autorisierung konnte nicht geöffnet werden. Bitte versuche es später erneut.',
      'es':
          'No se pudo abrir la autorización de Lichess. Inténtalo de nuevo más tarde.',
      'fr': 'Impossible d’ouvrir l’autorisation Lichess. Réessayez plus tard.',
      'it': 'Impossibile aprire l’autorizzazione Lichess. Riprova più tardi.',
      'ja': 'Lichess 認証を開けませんでした。しばらくしてからもう一度お試しください。',
      'ko': 'Lichess 인증을 열 수 없습니다. 나중에 다시 시도하세요.',
      'nl': 'Kan Lichess-autorisatie niet openen. Probeer het later opnieuw.',
      'ru': 'Не удалось открыть авторизацию Lichess. Повторите попытку позже.',
    },
    'Opening Lichess authorization...': {
      'zh-Hans': '正在打开 Lichess 授权...',
      'zh-Hant': '正在開啟 Lichess 授權...',
      'de': 'Lichess-Autorisierung wird geöffnet...',
      'es': 'Abriendo autorización de Lichess...',
      'fr': 'Ouverture de l’autorisation Lichess...',
      'it': 'Apertura autorizzazione Lichess...',
      'ja': 'Lichess 認証を開いています...',
      'ko': 'Lichess 인증을 여는 중...',
      'nl': 'Lichess-autorisatie openen...',
      'ru': 'Открытие авторизации Lichess...',
    },
    'Describe the issue and attach anything that helps us reproduce it. App logs and device details are included by default.':
        {
      'zh-Hans': '请描述问题，并附上任何有助于我们复现的内容。默认会包含应用日志和设备信息。',
      'zh-Hant': '請描述問題，並附上任何有助於我們重現的內容。預設會包含應用日誌和裝置資訊。',
      'de':
          'Beschreibe das Problem und füge alles hinzu, was uns beim Nachstellen hilft. App-Logs und Gerätedetails sind standardmäßig enthalten.',
      'es':
          'Describe el problema y adjunta cualquier cosa que nos ayude a reproducirlo. Los logs de la app y detalles del dispositivo se incluyen por defecto.',
      'fr':
          'Décrivez le problème et joignez tout ce qui peut nous aider à le reproduire. Les logs de l’app et les détails de l’appareil sont inclus par défaut.',
      'it':
          'Descrivi il problema e allega tutto ciò che ci aiuta a riprodurlo. Log dell’app e dettagli del dispositivo sono inclusi per impostazione predefinita.',
      'ja': '問題を説明し、再現に役立つものを添付してください。アプリログと端末情報はデフォルトで含まれます。',
      'ko': '문제를 설명하고 재현에 도움이 되는 자료를 첨부하세요. 앱 로그와 기기 정보는 기본으로 포함됩니다.',
      'nl':
          'Beschrijf het probleem en voeg alles toe dat helpt om het te reproduceren. App-logs en apparaatgegevens worden standaard meegestuurd.',
      'ru':
          'Опишите проблему и приложите всё, что поможет её воспроизвести. Логи приложения и данные устройства включены по умолчанию.',
    },
    'Include app logs and device details': {
      'zh-Hans': '包含应用日志和设备信息',
      'zh-Hant': '包含應用日誌和裝置資訊',
      'de': 'App-Logs und Gerätedetails einschließen',
      'es': 'Incluir logs de la app y detalles del dispositivo',
      'fr': 'Inclure les logs de l’app et les détails de l’appareil',
      'it': 'Includi log dell’app e dettagli dispositivo',
      'ja': 'アプリログと端末情報を含める',
      'ko': '앱 로그 및 기기 정보 포함',
      'nl': 'App-logs en apparaatgegevens opnemen',
      'ru': 'Включить логи приложения и данные устройства',
    },
    'Includes app version, device type, current screen, board status, and recent logs.':
        {
      'zh-Hans': '包含应用版本、设备类型、当前页面、棋盘状态和最近日志。',
      'zh-Hant': '包含應用版本、裝置類型、目前頁面、棋盤狀態和最近日誌。',
      'de':
          'Enthält App-Version, Gerätetyp, aktuellen Bildschirm, Brettstatus und aktuelle Logs.',
      'es':
          'Incluye versión de la app, tipo de dispositivo, pantalla actual, estado del tablero y logs recientes.',
      'fr':
          'Inclut la version de l’app, le type d’appareil, l’écran actuel, l’état de l’échiquier et les logs récents.',
      'it':
          'Include versione app, tipo dispositivo, schermata corrente, stato scacchiera e log recenti.',
      'ja': 'アプリバージョン、端末タイプ、現在の画面、ボード状態、最近のログを含みます。',
      'ko': '앱 버전, 기기 유형, 현재 화면, 보드 상태, 최근 로그를 포함합니다.',
      'nl':
          'Bevat appversie, apparaattype, huidig scherm, bordstatus en recente logs.',
      'ru':
          'Включает версию приложения, тип устройства, текущий экран, статус доски и последние логи.',
    },
  };
  return translations[text]?[key];
}
