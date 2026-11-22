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
  static const history = '/gecmis';
  static const privacy = '/kvkk';
  static const changePassword = '/sifre';
  static const duelPlayPattern = '/duello/:id';
  static String duelPlay(String betId) => '/duello/$betId';
}
