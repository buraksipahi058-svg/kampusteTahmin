abstract final class Routes {
  static const auth = '/giris';
  static const loading = '/yukleniyor';
  static const createProfile = '/profil-olustur';
  static const bets = '/bahisler';
  static const games = '/oyunlar';
  static const market = '/market';
  static const leaderboard = '/liderlik';
  static const profile = '/profil';
  static const verifyEmail = '/okul-maili';
  static const createSocialBet = '/sosyal-bahis-ac';
  static const quests = '/gorevler';
  static const achievements = '/basarimlar';
  static const notifications = '/bildirimler';
  // Oyunlar sekmesindeki kartların açtığı ekranlar.
  static const dailyPredictions = '/gunun-tahmini';
  static const duels = '/duellolar';
  static const campus = '/kampus-gorevleri';
  static const word = '/kampus-kelimesi';
  static const campusScanPattern = '/kampus-gorevleri/:id/okut';
  static String campusScan(String taskId) => '/kampus-gorevleri/$taskId/okut';
  static const campusPhotoPattern = '/kampus-gorevleri/:id/foto';
  static String campusPhoto(String taskId) => '/kampus-gorevleri/$taskId/foto';

  /// Alt sekmelerin yolları (bildirim linki bunlardan biriyse sekmeye geçilir, değilse ekran açılır).
  static const tabs = {bets, games, market, leaderboard, profile};
  static const history = '/gecmis';
  static const privacy = '/kvkk';
  static const terms = '/kosullar';
  static const changePassword = '/sifre';
  static const tutorial = '/nasil-oynanir';
  static const duelPlayPattern = '/duello/:id';
  static String duelPlay(String betId) => '/duello/$betId';
  static const duelReviewPattern = '/duello/:id/cevaplar';
  static String duelReview(String betId) => '/duello/$betId/cevaplar';
  static const personPattern = '/kisi/:id';
  static String person(String userId) => '/kisi/$userId';
}
