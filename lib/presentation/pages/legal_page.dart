import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Informativa sulla Privacy',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              'Informativa sulla Privacy',
              'Ultimo aggiornamento: maggio 2025\n\n'
              'La presente informativa descrive come Mappa Benzinai ("l\'app", "noi") '
              'raccoglie, utilizza e protegge i tuoi dati personali in conformità al '
              'Regolamento Generale sulla Protezione dei Dati (GDPR – Reg. UE 2016/679) '
              'e al D.Lgs. 196/2003 (Codice Privacy italiano).',
            ),
            _section(
              '1. Titolare del Trattamento',
              'Il titolare del trattamento dei dati è Pietro Plati, raggiungibile '
              'all\'indirizzo: plati.pietro@gmail.com\n\n'
              'Per qualsiasi questione relativa alla privacy puoi scrivere a questo indirizzo.',
            ),
            _section(
              '2. Dati Raccolti',
              'Raccogliamo esclusivamente i dati necessari al funzionamento dell\'app:\n\n'
              '• Indirizzo e-mail e nome (solo se ti registri)\n'
              '• Password (conservata in forma cifrata da Firebase Auth)\n'
              '• Posizione geografica (GPS, solo mentre usi l\'app e solo con il tuo consenso)\n'
              '• Stazioni preferite salvate\n'
              '• Profili veicolo (tipo carburante, consumo, capienza serbatoio)\n'
              '• Storico rifornimenti inseriti manualmente\n\n'
              'Gli utenti anonimi (senza registrazione) non forniscono dati personali '
              'identificabili. Viene assegnato un ID anonimo temporaneo da Firebase.',
            ),
            _section(
              '3. Finalità e Base Giuridica del Trattamento',
              '• Erogazione del servizio (art. 6 par. 1 lett. b GDPR): mostrarti le stazioni '
              'vicine, salvare preferiti e profilo veicolo.\n\n'
              '• Consenso (art. 6 par. 1 lett. a GDPR): accesso alla posizione GPS. '
              'Puoi revocare il consenso in qualsiasi momento dalle impostazioni del dispositivo.\n\n'
              '• Legittimo interesse (art. 6 par. 1 lett. f GDPR): prevenzione di abusi '
              'e miglioramento del servizio tramite log tecnici anonimi.',
            ),
            _section(
              '4. Conservazione dei Dati',
              'I tuoi dati sono conservati finché mantieni un account attivo. '
              'Puoi eliminare il tuo account in qualsiasi momento dalla sezione Profilo '
              'dell\'app: tutti i tuoi dati saranno cancellati definitivamente entro 30 giorni.\n\n'
              'I dati di posizione non vengono mai memorizzati sui nostri server: '
              'vengono usati solo in tempo reale sul tuo dispositivo.',
            ),
            _section(
              '5. Condivisione dei Dati con Terze Parti',
              'Non vendiamo né cediamo i tuoi dati a terzi a fini commerciali.\n\n'
              'I dati sono trattati dai seguenti sub-responsabili:\n\n'
              '• Google Firebase (Firebase Auth, Cloud Firestore) – Google LLC, USA. '
              'Il trasferimento è disciplinato dalle Standard Contractual Clauses della CE.\n\n'
              '• OpenStreetMap Foundation – per le mappe. I tile OSM sono caricati '
              'senza trasferimento di dati personali.\n\n'
              '• Ministero dell\'Ambiente e della Sicurezza Energetica (MIMIT) – dati '
              'pubblici sui prezzi carburanti, nessun dato personale condiviso.',
            ),
            _section(
              '6. I Tuoi Diritti (GDPR)',
              'Hai il diritto di:\n\n'
              '• Accedere ai tuoi dati (art. 15)\n'
              '• Rettificare dati inesatti (art. 16)\n'
              '• Cancellare i tuoi dati ("diritto all\'oblio", art. 17)\n'
              '• Limitare il trattamento (art. 18)\n'
              '• Portabilità dei dati (art. 20)\n'
              '• Opporti al trattamento (art. 21)\n\n'
              'Per esercitare questi diritti, scrivici a plati.pietro@gmail.com. '
              'Risponderemo entro 30 giorni. Hai inoltre il diritto di proporre reclamo '
              'al Garante per la Protezione dei Dati Personali (www.garanteprivacy.it).',
            ),
            _section(
              '7. Sicurezza',
              'Utilizziamo Firebase Authentication per la gestione delle credenziali, '
              'che cifra le password. Le comunicazioni avvengono sempre tramite HTTPS. '
              'Le regole Firestore garantiscono che ogni utente acceda solo ai propri dati.',
            ),
            _section(
              '8. Minori',
              'L\'app non è destinata a minori di 13 anni. Non raccogliamo '
              'consapevolmente dati di minori. Se vieni a conoscenza di dati di un minore '
              'inseriti nell\'app, contattaci per la loro immediata cancellazione.',
            ),
            _section(
              '9. Modifiche alla Privacy Policy',
              'Potremmo aggiornare questa informativa. In caso di modifiche sostanziali '
              'ti avviseremo tramite una notifica nell\'app. La data in cima al documento '
              'indica l\'ultima revisione.',
            ),
            _section(
              '10. Attribuzione Dati Geografici',
              'I dati cartografici sono forniti da © OpenStreetMap contributors, '
              'disponibili sotto licenza ODbL (Open Database Licence). '
              'I prezzi carburanti provengono dal dataset pubblico del Ministero '
              'dell\'Ambiente e della Sicurezza Energetica (MIMIT).',
            ),
            const SizedBox(height: 8),
            Text(
              'Contatti: plati.pietro@gmail.com',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
