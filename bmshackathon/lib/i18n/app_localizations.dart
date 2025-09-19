import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageScope extends InheritedNotifier<ValueNotifier<Locale>> {
  static const _prefsKey = 'selected_locale_code';
  LanguageScope({super.key, required this.child, Locale? initialLocale})
      : super(
          notifier: ValueNotifier<Locale>(initialLocale ?? const Locale('en')),
          child: child,
        );

  final Widget child;

  static Locale of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()!
          .notifier!
          .value;

  static void setLocale(BuildContext context, Locale locale) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LanguageScope>()!.notifier!;
    scope.value = locale;
    // persist selection
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefsKey, locale.languageCode);
    });
  }

  static Future<Locale?> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == null) return null;
    try {
      return AppLocalizations.supported
          .firstWhere((l) => l.languageCode == code);
    } catch (_) {
      return null;
    }
  }
}

class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      AppLocalizations(LanguageScope.of(context));

  static const supported = [
    Locale('en'),
    Locale('hi'),
    Locale('es'),
    Locale('fr'),
  ];

  static const _strings = <String, Map<String, String>>{
    'app_title': {
      'en': 'Health Assistant App',
      'hi': 'हेल्थ असिस्टेंट ऐप',
      'es': 'Aplicación Asistente de Salud',
      'fr': 'Application Assistant Santé',
    },
    'welcome': {
      'en': 'Welcome',
      'hi': 'स्वागत है',
      'es': 'Bienvenido',
      'fr': 'Bienvenue',
    },
    'select_language': {
      'en': 'Select Language',
      'hi': 'भाषा चुनें',
      'es': 'Seleccionar idioma',
      'fr': 'Choisir la langue',
    },
    'continue_to_chatbot': {
      'en': 'Continue to Chatbot',
      'hi': 'चैटबॉट पर जाएं',
      'es': 'Continuar al Chatbot',
      'fr': 'Continuer vers le Chatbot',
    },
    'chatbot': {
      'en': 'Chatbot',
      'hi': 'चैटबॉट',
      'es': 'Chatbot',
      'fr': 'Chatbot',
    },
    'composer_hint': {
      'en': 'Type a message',
      'hi': 'संदेश लिखें',
      'es': 'Escribe un mensaje',
      'fr': 'Écrire un message',
    },
    'you_said': {
      'en': 'You said',
      'hi': 'आपने कहा',
      'es': 'Dijiste',
      'fr': 'Vous avez dit',
    },
    'start_triage': {
      'en': 'Start Triage',
      'hi': 'ट्रायेज शुरू करें',
      'es': 'Iniciar triaje',
      'fr': 'Commencer le triage',
    },
    'symptom_triage': {
      'en': 'Symptom Triage',
      'hi': 'लक्षण ट्रायेज',
      'es': 'Triaje de síntomas',
      'fr': 'Triage des symptômes',
    },
    'question': {
      'en': 'Question',
      'hi': 'प्रश्न',
      'es': 'Pregunta',
      'fr': 'Question',
    },
    'of': {
      'en': 'of',
      'hi': 'में से',
      'es': 'de',
      'fr': 'sur',
    },
    'q1': {
      'en': 'Are you experiencing severe chest pain or shortness of breath?',
      'hi': 'क्या आपको तेज़ सीने में दर्द या सांस लेने में तकलीफ है?',
      'es': '¿Tiene dolor torácico intenso o falta de aire?',
      'fr': 'Avez-vous de fortes douleurs thoraciques ou un essoufflement ?',
    },
    'q1_opt1': {
      'en': 'Yes, severe',
      'hi': 'हाँ, गंभीर',
      'es': 'Sí, severo',
      'fr': 'Oui, sévère',
    },
    'q1_opt2': {
      'en': 'Mild discomfort',
      'hi': 'हल्की तकलीफ',
      'es': 'Molestia leve',
      'fr': 'Gêne légère',
    },
    'q1_opt3': {
      'en': 'No',
      'hi': 'नहीं',
      'es': 'No',
      'fr': 'Non',
    },
    'q2': {
      'en': 'Do you have a high fever (above 39°C) lasting more than 2 days?',
      'hi': 'क्या आपको 2 दिनों से अधिक समय से 39°C से ऊपर बुखार है?',
      'es': '¿Tiene fiebre alta (más de 39°C) por más de 2 días?',
      'fr': 'Avez-vous une forte fièvre (plus de 39°C) depuis plus de 2 jours ?',
    },
    'q2_opt1': {
      'en': 'Yes',
      'hi': 'हाँ',
      'es': 'Sí',
      'fr': 'Oui',
    },
    'q2_opt2': {
      'en': 'No',
      'hi': 'नहीं',
      'es': 'No',
      'fr': 'Non',
    },
    'q3': {
      'en': 'Any recent injury with bleeding or suspected fracture?',
      'hi': 'क्या हाल ही में चोट लगी है जिसमें खून बह रहा हो या हड्डी टूटने का शक हो?',
      'es': '¿Alguna lesión reciente con sangrado o sospecha de fractura?',
      'fr': 'Blessure récente avec saignement ou fracture suspectée ?',
    },
    'q3_opt1': {
      'en': 'Yes',
      'hi': 'हाँ',
      'es': 'Sí',
      'fr': 'Oui',
    },
    'q3_opt2': {
      'en': 'Not sure',
      'hi': 'पक्का नहीं',
      'es': 'No estoy seguro',
      'fr': 'Pas sûr',
    },
    'q3_opt3': {
      'en': 'No',
      'hi': 'नहीं',
      'es': 'No',
      'fr': 'Non',
    },
    'q4': {
      'en': 'Rate your pain level',
      'hi': 'अपने दर्द के स्तर को रेट करें',
      'es': 'Califique su nivel de dolor',
      'fr': 'Évaluez votre niveau de douleur',
    },
    'q4_opt1': {
      'en': 'Severe',
      'hi': 'गंभीर',
      'es': 'Severo',
      'fr': 'Sévère',
    },
    'q4_opt2': {
      'en': 'Moderate',
      'hi': 'मध्यम',
      'es': 'Moderado',
      'fr': 'Modéré',
    },
    'q4_opt3': {
      'en': 'Mild/None',
      'hi': 'हल्का/नहीं',
      'es': 'Leve/Ninguno',
      'fr': 'Léger/Aucun',
    },
    'see_results': {
      'en': 'See Results',
      'hi': 'परिणाम देखें',
      'es': 'Ver resultados',
      'fr': 'Voir les résultats',
    },
    'triage_results': {
      'en': 'Triage Results',
      'hi': 'ट्रायेज परिणाम',
      'es': 'Resultados del triaje',
      'fr': 'Résultats du triage',
    },
    'triage_complete': {
      'en': 'Triage Complete',
      'hi': 'ट्रायेज पूर्ण',
      'es': 'Triaje completado',
      'fr': 'Triage terminé',
    },
    'result_label': {
      'en': 'Result',
      'hi': 'परिणाम',
      'es': 'Resultado',
      'fr': 'Résultat',
    },
    'emergency': {
      'en': 'Emergency',
      'hi': 'आपातकाल',
      'es': 'Emergencia',
      'fr': 'Urgence',
    },
    'urgent': {
      'en': 'Urgent',
      'hi': 'तत्काल',
      'es': 'Urgente',
      'fr': 'Urgent',
    },
    'self_care': {
      'en': 'Self-care',
      'hi': 'स्व-देखभाल',
      'es': 'Autocuidado',
      'fr': 'Auto-soins',
    },
    'emergency_message': {
      'en': 'Your symptoms may require immediate medical attention. Consider calling emergency services or going to the nearest ER.',
      'hi': 'आपके लक्षण तत्काल चिकित्सा सहायता की आवश्यकता का संकेत देते हैं। आपातकालीन सेवाओं को कॉल करने या निकटतम आपातकाल कक्ष में जाने पर विचार करें।',
      'es': 'Sus síntomas pueden requerir atención médica inmediata. Considere llamar a emergencias o ir a la sala de urgencias más cercana.',
      'fr': 'Vos symptômes peuvent nécessiter une attention médicale immédiate. Envisagez d’appeler les urgences ou d’aller au service d’urgence le plus proche.',
    },
    'urgent_message': {
      'en': 'Your symptoms suggest you should see a clinician soon. Consider visiting an urgent care clinic within 24 hours.',
      'hi': 'आपके लक्षण संकेत देते हैं कि आपको जल्द ही चिकित्सक से मिलना चाहिए। 24 घंटों के भीतर अर्जेंट केयर क्लिनिक जाने पर विचार करें।',
      'es': 'Sus síntomas sugieren que debe ver a un médico pronto. Considere visitar una clínica de atención urgente dentro de 24 horas.',
      'fr': 'Vos symptômes suggèrent que vous devriez voir un clinicien bientôt. Envisagez de consulter dans une clinique sans rendez-vous dans les 24 heures.',
    },
    'self_care_message': {
      'en': 'Your symptoms may be managed with self-care. Monitor your condition and seek care if symptoms worsen.',
      'hi': 'आपके लक्षण आत्म-देखभाल से प्रबंधित किए जा सकते हैं। अपनी स्थिति पर नज़र रखें और लक्षण बढ़ने पर देखभाल लें।',
      'es': 'Sus síntomas pueden manejarse con autocuidado. Controle su condición y busque atención si los síntomas empeoran.',
      'fr': 'Vos symptômes peuvent être gérés par l’auto-soin. Surveillez votre état et consultez si les symptômes s’aggravent.',
    },
    'nearby_clinics': {
      'en': 'Nearby Clinics',
      'hi': 'नज़दीकी क्लीनिक',
      'es': 'Clínicas cercanas',
      'fr': 'Cliniques à proximité',
    },
    'open_nearby_clinics': {
      'en': 'Open Nearby Clinics in Google Maps',
      'hi': 'गूगल मैप्स में नज़दीकी क्लीनिक खोलें',
      'es': 'Abrir clínicas cercanas en Google Maps',
      'fr': 'Ouvrir les cliniques à proximité dans Google Maps',
    },
    'map_hint': {
      'en': 'Pan and zoom the map. Tap the map button to view full results in Google Maps.',
      'hi': 'मानचित्र को पैन और ज़ूम करें। पूरे परिणाम गूगल मैप्स में देखने के लिए मैप बटन दबाएँ।',
      'es': 'Desplázate y acerca el mapa. Toca el botón del mapa para ver todos los resultados en Google Maps.',
      'fr': 'Déplacez et zoomez sur la carte. Appuyez sur le bouton carte pour voir tous les résultats dans Google Maps.',
    },
    'map_placeholder': {
      'en': 'Map Placeholder',
      'hi': 'मानचित्र प्लेसहोल्डर',
      'es': 'Marcador de mapa',
      'fr': 'Espace réservé à la carte',
    },
    'bot_welcome': {
      'en': "Hi! I'm your Health Assistant. Send a message or tap the stethoscope button to start triage.",
      'hi': 'नमस्ते! मैं आपका हेल्थ असिस्टेंट हूँ। संदेश भेजें या ट्रायेज शुरू करने के लिए स्टेथोस्कोप बटन दबाएँ।',
      'es': '¡Hola! Soy tu Asistente de Salud. Envía un mensaje o toca el botón de estetoscopio para comenzar el triaje.',
      'fr': 'Salut ! Je suis votre Assistant Santé. Envoyez un message ou appuyez sur le bouton stéthoscope pour commencer le triage.',
    },
    'settings_title': {
      'en': 'Settings',
      'hi': 'सेटिंग्स',
      'es': 'Configuración',
      'fr': 'Paramètres',
    },
    'language_label': {
      'en': 'Language',
      'hi': 'भाषा',
      'es': 'Idioma',
      'fr': 'Langue',
    },
    'allow_storage_title': {
      'en': 'Allow local storage (encrypted)',
      'hi': 'लोकल स्टोरेज की अनुमति (एन्क्रिप्टेड)',
      'es': 'Permitir almacenamiento local (cifrado)',
      'fr': 'Autoriser le stockage local (chiffré)',
    },
    'allow_storage_subtitle': {
      'en': 'Store chat history securely on this device',
      'hi': 'इस डिवाइस पर चैट इतिहास सुरक्षित रूप से सहेजें',
      'es': 'Guardar el historial de chat de forma segura en este dispositivo',
      'fr': 'Stocker l’historique des discussions en toute sécurité sur cet appareil',
    },
    'allow_mic_title': {
      'en': 'Allow microphone',
      'hi': 'माइक्रोफ़ोन की अनुमति दें',
      'es': 'Permitir micrófono',
      'fr': 'Autoriser le microphone',
    },
    'allow_mic_subtitle': {
      'en': 'Use voice input for messages',
      'hi': 'संदेशों के लिए वॉइस इनपुट का उपयोग करें',
      'es': 'Usar entrada de voz para mensajes',
      'fr': 'Utiliser la saisie vocale pour les messages',
    },
    'allow_location_title': {
      'en': 'Allow location',
      'hi': 'स्थान की अनुमति दें',
      'es': 'Permitir ubicación',
      'fr': 'Autoriser la localisation',
    },
    'allow_location_subtitle': {
      'en': 'Find nearby facilities and directions',
      'hi': 'नज़दीकी सुविधाएँ और दिशाएँ खोजें',
      'es': 'Encontrar instalaciones cercanas y direcciones',
      'fr': 'Trouver les établissements à proximité et les itinéraires',
    },
    'clear_all_data': {
      'en': 'Clear all data',
      'hi': 'सभी डेटा साफ़ करें',
      'es': 'Borrar todos los datos',
      'fr': 'Effacer toutes les données',
    },
    'clearing': {
      'en': 'Clearing...',
      'hi': 'साफ़ किया जा रहा है...',
      'es': 'Borrando...',
      'fr': 'Nettoyage...',
    },
    'save_settings': {
      'en': 'Save settings',
      'hi': 'सेटिंग्स सहेजें',
      'es': 'Guardar configuración',
      'fr': 'Enregistrer les paramètres',
    },
    'saving': {
      'en': 'Saving...',
      'hi': 'सहेजा जा रहा है...',
      'es': 'Guardando...',
      'fr': 'Enregistrement...',
    },
    'all_data_cleared': {
      'en': 'All local data cleared',
      'hi': 'सारा स्थानीय डेटा साफ़ कर दिया गया',
      'es': 'Todos los datos locales se han borrado',
      'fr': 'Toutes les données locales ont été effacées',
    },
    'ai_advice': {
      'en': 'AI Advice',
      'hi': 'एआई सलाह',
      'es': 'Consejo de IA',
      'fr': 'Conseil IA',
    },
    'confidence': {
      'en': 'Confidence',
      'hi': 'विश्वास स्तर',
      'es': 'Confianza',
      'fr': 'Confiance',
    },
    'save_pdf': {
      'en': 'Save PDF',
      'hi': 'पीडीएफ सहेजें',
      'es': 'Guardar PDF',
      'fr': 'Enregistrer le PDF',
    },
    'share_pdf': {
      'en': 'Share PDF',
      'hi': 'पीडीएफ साझा करें',
      'es': 'Compartir PDF',
      'fr': 'Partager le PDF',
    },
    'send': {
      'en': 'Send',
      'hi': 'भेजें',
      'es': 'Enviar',
      'fr': 'Envoyer',
    },
  };

  String t(String key) => _strings[key]?[locale.languageCode] ??
      _strings[key]?["en"] ?? key;
}
