/// Mappa brand → logo in `assets/brands/`.
///
/// La chiave è il nome del brand "compattato" (minuscolo, solo lettere e
/// cifre, senza spazi/punti/trattini/apostrofi), così il match con il campo
/// `Bandiera` del CSV MIMIT regge indipendentemente da come sono scritti
/// spaziatura e punteggiatura (es. "D.B. Carburanti", "Dis.Car", "Dill's").
///
/// Per aggiungere un nuovo logo: metti il PNG (sfondo trasparente, quadrato,
/// almeno 256x256) in `assets/brands/` e aggiungi una riga qui sotto.
/// Se il brand non è in mappa (o `station.brand` è null/"Pompe Bianche"),
/// il chiamante deve mostrare il pin generico.
class BrandAssets {
  BrandAssets._();

  static const String _basePath = 'assets/brands';

  static const Map<String, String> _fileByKey = {
    'afpetroli': 'af-petroli.png',
    'agipeni': 'agip-eni.png',
    'agip': 'agip-eni.png',
    'eni': 'agip-eni.png',
    'ala': 'ala.png',
    'apiip': 'api-ip.png',
    'api': 'api-ip.png',
    'ip': 'api-ip.png',
    'aquila': 'aquila.png',
    'bc': 'bc.png',
    'beyfin': 'beyfin.png',
    'bpetrol': 'bpetrol.png',
    'coil': 'coil.png',
    'conad': 'conad.png',
    'costantin': 'costantin.png',
    'dbcarburanti': 'dbcarburanti.png',
    'dills': 'dill-s.png',
    'discar': 'dis-car.png',
    'ego': 'ego.png',
    'enercoop': 'enercoop.png',
    'energas': 'energas.png',
    'enerpetroli': 'enerpetroli.png',
    'eos': 'eos.png',
    'esso': 'esso.png',
    'europam': 'europam.png',
    'giap': 'giap.png',
    'gnp': 'gnp.png',
    'ibleapetroli': 'iblea-petroli.png',
    'icm': 'icm.png',
    'italapetroli': 'itala-petroli.png',
    'italianacarburanti': 'italiana-carburanti.png',
    'keropetrol': 'keropetrol.png',
    'loro': 'loro.png',
    'lukoil': 'lukoil.png',
    'mengapetroli': 'menga-petroli.png',
    'nobileoil': 'nobile-oil.png',
    'oilitalia': 'oil-italia.png',
    'petrolcompany': 'petrol-company.png',
    'petrolgamma': 'petrol-gamma.png',
    'q8': 'q8.png',
    'retitalia': 'retitalia.png',
    'sanmarcopetroli': 'san-marco-petroli.png',
    'sarnioil': 'sarni-oil.png',
    'sepa': 'sepa.png',
    'shell': 'shell.png',
    'siafuel': 'sia-fuel.png',
    'sicilpetroli': 'sicilpetroli.png',
    'simonettipetroli': 'simonetti-petroli.png',
    'smaf': 'smaf.png',
    'sommesepetroli': 'sommese-petroli.png',
    'tamoil': 'tamoil.png',
    'toil': 'toil.png',
    'vega': 'vega.png',
  };

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Ritorna il path dell'asset del logo per [brand], o `null` se il brand
  /// non ha un logo mappato (in tal caso va usato il pin generico).
  static String? logoAssetFor(String? brand) {
    if (brand == null) return null;
    final key = _normalize(brand);
    if (key.isEmpty) return null;
    return _fileByKey.containsKey(key) ? '$_basePath/${_fileByKey[key]}' : null;
  }
}
